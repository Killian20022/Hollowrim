class_name ImpactCorps
extends Node3D
## SOCLE « impact des sorts sur les corps » (doc : docs/MAGIE_IMPACT_CORPS.md). Visuels seulement, aucune logique de jeu.
##
## Un FOYER = un corps touché par une école (feu ; glace, électricité, ténèbres à brancher par l'agent B) :
##   - SurfaceCorps : points échantillonnés sur les maillages du corps, qui suivent ses os (animation, ragdoll) ;
##   - 6 émetteurs GPU (shaders/magie_corps_part.gdshader) qui émettent DEPUIS cette surface, chacun selon un « mode »
##     (langues, contour, éclaboussure, escarbilles, fumée, sol) et un réglage de l'école ;
##   - le voile partagé (shaders/magie_corps.gdshader, material_overlay) piloté par paramètres d'instance.
## Tout est créé UNE fois (pool de MAX_FOYERS foyers, préchauffé au chargement) : un impact n'alloue ni nœud, ni matériau,
## ni texture (test : outils/test_impact_corps.gd). Les particules réservées comptent dans le budget de GestionMagie
## (MAX_PARTICULES / MAX_PARTICULES_FIN) : jamais de dépassement, la réserve est réduite si le plafond est proche.
##
## Comportements par école (scripts statiques, enregistrés dans COMPORTEMENTS) : FeuCorps (scripts/magie/feu_corps.gd) ;
## agent B : ElecCorps (elec_corps.gd), GlaceCorps (glace_corps.gd), OmbreCorps (ombre_corps.gd).
## Interface d'un comportement : REGLAGES (6 réglages, un par émetteur), debut(ic, f), jet(ic, f, info),
## statut(ic, f, statut, duree) -> bool, embraser(ic, f, point, dir, force, duree), maj(ic, f, dt) -> bool (faux = fini).
##
## Points d'accroche dans GestionMagie (une ligne chacun) : _jet_gerbe → ImpactCorps.jet_gerbe(gm, j) ;
## statut_cible → ImpactCorps.statut(gm, cible, statut, duree) ; tout_arreter → ImpactCorps.arreter_tout() ;
## vitrine_prechauffe → ImpactCorps.vitrine(gm, v) ; impact (agent B : projectiles, chaîne) → ImpactCorps.impact(gm, …).
##
## Ajouts de l'agent B (additifs, docs/MAGIE_IMPACT_CORPS.md « Extensions ») : arcs sur le corps (maillage fixe + texture de
## sous-segments, shaders/magie_corps_arcs.gdshader), coque par école (constante COQUE du comportement), canaux d'instance
## mc_ecoles / mc_pt fusionnés par corps (ecoles()), impact ponctuel trouvé par la position (impact()), impulsion (jet
## virtuel bref : boule de feu), statuts gel / choc / corruption, modes de particules 6..8, pool de 8 foyers.

const SH_PART := preload("res://shaders/magie_corps_part.gdshader")
const SH_VOILE := preload("res://shaders/magie_corps.gdshader")
const SH_COQUE := preload("res://shaders/magie_corps_coque.gdshader")
const SH_COQUE_ECOLES := preload("res://shaders/magie_corps_coque_ecoles.gdshader")
const SH_ARCS := preload("res://shaders/magie_corps_arcs.gdshader")
## 8 foyers (4 au départ) : 3 corps × (feu + une autre école) sans que l'un chasse l'autre (agent B).
const MAX_FOYERS := 8
## Sous-segments d'arcs par foyer (maillage fixe partagé ; texture de 2 texels par sous-segment).
const MAX_SEGMENTS := 160
const EMETTEURS := 6
const MODES := {"langues": 0, "contour": 1, "eclabousse": 2, "escarbilles": 3, "fumee": 4, "sol": 5,
	"aspire": 6, "givre": 7, "fonte": 8}
## Accélération (m/s², au centre du répulseur) qui écarte les particules du jet du corps.
const FORCE_REPOUSSE := 160.0
## Durée de vie des particules du jet quand il touche un corps (× celle qui les arrête au centre du corps).
const PROLONGE_JET := 1.15
## Maillages voilés par corps au plus (une passe de plus par maillage).
const MAX_VOILES := 12
const COMPORTEMENTS := {"feu": preload("res://scripts/magie/feu_corps.gd"),
	"electricite": preload("res://scripts/magie/elec_corps.gd"), "glace": preload("res://scripts/magie/glace_corps.gd"),
	"tenebres": preload("res://scripts/magie/ombre_corps.gd")}
## Statut (Statuts / EffetsMagie.statut_cible) → école qui le rend sur le corps.
const STATUTS := {"brulure": "feu", "gel": "glace", "choc": "electricite", "corruption": "tenebres"}

## Faux = rendu d'avant (gerbe en boîte, voile de statut) : planches « avant » (--sans-impact-corps).
static var actif := true
## Temps CPU cumulé de _process (µs) et nombre d'images (mesure : outils/perf_impact_ecoles.gd).
static var duree_maj_us := 0
static var images_maj := 0
static var instance: ImpactCorps

## Ce qui a été créé par ce module (nœuds, matériaux, textures) : figé après la préchauffe (lu par le test).
var crees := 0
var gm: GestionMagie
var foyers: Array = []                 # Foyer
var mat_voile: ShaderMaterial
var mat_coque: ShaderMaterial
var mat_coques := {}                   # école (agent B) -> ShaderMaterial de magie_corps_coque_ecoles
var mesh_arcs: ArrayMesh
var _impulsions: Array = []            # {f, info, fin} : jets virtuels brefs (impact d'une boule de feu)
var _consts := {}                      # école -> constantes du comportement (COQUE, ARCS…)
var _rampes := {}
var _voiles := {}                      # id du maillage -> nombre de foyers qui l'utilisent
var _niveau := -1                      # 0 rétro, 1 fin : les émetteurs sont reconfigurés au changement
var rng := RandomNumberGenerator.new()
var _scan := 0.0
var _a_preparer: Array = []            # cibles dont les maillages ne sont pas encore lus

class Emetteur:
	var p: GPUParticles3D
	var mat: ShaderMaterial
	var u: Dictionary                  # uniformes communs du foyer (même dictionnaire pour ses 6 émetteurs)
	var reglage: Dictionary = {}
	var n := 0                         # particules (amount)
	var ratio := 0.0                   # part active (amount_ratio)
	var reserve := 0                   # réservé dans le budget de GestionMagie
	var vie := 0.5

class Foyer:
	var id := 0
	var cible: Node3D
	var ecole := ""
	var surface: SurfaceCorps
	var em: Array = []                 # Emetteur × EMETTEURS
	var img_pos: Image
	var img_nor: Image
	var tex_pos: ImageTexture
	var tex_nor: ImageTexture
	var voiles: Array = []             # MeshInstance3D voilés par ce foyer
	var coques: Array = []             # MeshInstance3D du pool : copies skinnées (couche fine) des maillages voilés
	var repousse: GPUParticlesAttractorSphere3D   # répulseur : le jet (particules du jet) contourne le corps
	var arcs: MeshInstance3D           # arcs sur le corps (shaders/magie_corps_arcs.gdshader), agent B
	var mat_arcs: ShaderMaterial
	var img_segs: Image
	var tex_segs: ImageTexture
	var segs := PackedFloat32Array()
	var nb_segs := 0
	var nb_segs_prec := 0
	var avec_coque := true             # faux : école sans coque (les copies skinnées ne sont pas affichées)
	var u := {}                        # uniformes communs : dernière valeur (posée sur les émetteurs qui émettent)
	var ec_ecrit: Array = []           # derniers canaux des écoles B écrits (pas de réécriture s'ils n'ont pas changé)
	var d: Dictionary = {}             # état du comportement
	var t0 := 0.0
	var fin_particules := 0.0          # horloge après laquelle plus aucune particule n'est en vie
	var libre := true

	func origine() -> Vector3:
		return cible.global_position if is_instance_valid(cible) else Vector3.ZERO

# ====================================================================== accès

static func obtenir(g: GestionMagie = null) -> ImpactCorps:
	if instance != null and is_instance_valid(instance) and not instance.is_queued_for_deletion():
		return instance
	if g == null:
		g = GestionMagie.obtenir()
	var ic := ImpactCorps.new()
	ic.name = "ImpactCorps"
	ic.gm = g
	instance = ic
	g.add_child(ic)
	return ic

## Point d'accroche de GestionMagie._jet_gerbe : vrai si le corps visé est pris en charge (la gerbe en boîte n'est pas
## créée). Appelé à chaque image par chaque jet.
static func jet_gerbe(g: GestionMagie, j: Dictionary) -> bool:
	if not actif:
		return false
	var cible: Variant = j.get("cible")
	if cible == null or not g.valide(cible) or not COMPORTEMENTS.has(String(j.ecole)):
		return false
	var ic := obtenir(g)
	var f: Foyer = ic.foyer(cible, String(j.ecole))
	if f == null:
		return false
	# l'ancienne gerbe (boîte de particules + enveloppe procédurale posée devant le corps) n'est plus utilisée
	for p in j.gerbe:
		g.arreter(p)
	j.gerbe = []
	j.gerbe_cible = cible
	# le léchage du point touché (sphère de flammes au CENTRE du corps) est réservé aux surfaces
	j.t_bout = g.horloge
	var o: Vector3 = (j.origine as Node3D).global_position
	var fin: Vector3 = j.fin_pos
	var dbl: bool = j.dbl
	var kl := 1.6 if dbl else 1.0
	var ecart := clampf(rad_to_deg(atan2(float(j.largeur) * 0.5 * kl, maxf(float(j.portee), 0.5))) * 2.4, 8.0, 32.0)
	var l := o.distance_to(fin)
	# le jet ne meurt plus SUR le plan du corps : ses particules vont un peu au-delà (le répulseur les fait glisser autour
	# de la silhouette et ressortir sur les côtés). Au plus +15 % : sous la marge de 18 % de _jet_placer (pas de va-et-vient).
	for p in j.emit:
		if is_instance_valid(p) and (p as Node).has_meta("v_jet"):
			var vie := clampf(l / float((p as Node).get_meta("v_jet")), 0.08, 3.0) * PROLONGE_JET
			if absf((p as GPUParticles3D).lifetime - vie) > 0.01:
				(p as GPUParticles3D).lifetime = vie
	var rayon := clampf(l * tan(deg_to_rad(ecart * 0.5)) * 1.2, 0.25, 0.7) * (1.25 if dbl else 1.0)
	COMPORTEMENTS[f.ecole].jet(ic, f, {"o": o, "dir": (fin - o) / maxf(l, 0.001), "rayon": rayon, "dbl": dbl, "id": (j.origine as Node).get_instance_id(), "j": j})
	return true

## Point d'accroche de GestionMagie.statut_cible : vrai si le statut est rendu sur le corps par ce module.
static func statut(g: GestionMagie, cible: Node3D, nom: String, duree: float) -> bool:
	if not actif or cible == null or not is_instance_valid(cible):
		return false
	var ecole: String = STATUTS.get(nom, "")
	if ecole == "" or not COMPORTEMENTS.has(ecole):
		return false
	var ic := obtenir(g)
	if duree <= 0.0:
		var f0: Foyer = ic.trouver(cible, ecole)
		if f0 != null:
			COMPORTEMENTS[ecole].statut(ic, f0, nom, 0.0)
		return true
	var f: Foyer = ic.foyer(cible, ecole)
	if f == null:
		return false
	return COMPORTEMENTS[ecole].statut(ic, f, nom, duree)

## Impact ponctuel sur un corps (projectile, explosion) : l'école embrase / givre / électrise le corps autour du point.
## Pour l'agent B : boule de feu, lance de givre, trait d'ombre.
static func embraser(cible: Node3D, ecole: String, point: Vector3, direction: Vector3, force := 1.0, duree := 3.0) -> bool:
	if not actif or cible == null or not is_instance_valid(cible) or not COMPORTEMENTS.has(ecole):
		return false
	var ic := obtenir()
	var f: Foyer = ic.foyer(cible, ecole)
	if f == null:
		return false
	COMPORTEMENTS[ecole].embraser(ic, f, point, direction, force, duree)
	return true

## Point d'accroche de GestionMagie.impact (agent B) : un impact ponctuel (projectile, chaîne d'éclairs) dont la position
## est DANS un corps (colonne de la cible, comme ProjectileSort) est rendu sur ce corps : le sort s'étale sur sa surface
## depuis le point touché (éclaboussure tangente, givre, arcs, ombre), plus de bouffée ni de disque posés devant. Vrai = pris
## en charge (GestionMagie ne dessine pas l'impact d'avant). Les impacts sur le décor ne changent pas.
static func impact(g: GestionMagie, ecole: String, position: Vector3, normale: Vector3, force: float) -> bool:
	if not actif or not COMPORTEMENTS.has(ecole):
		return false
	var cible := corps_en(g, position)
	if cible == null:
		return false
	var dir := -normale.normalized() if normale.length() > 0.01 else (cible.global_position + Vector3.UP - position).normalized()
	var ic := obtenir(g)
	var f: Foyer = ic.foyer(cible, ecole)
	if f == null:
		return false
	if ecole == "feu":
		# boule de feu : souffle qui ENTOURE la silhouette = jet virtuel bref le long de la trajectoire (même rendu que le
		# jet : flux qui contourne le corps, langues de surface, cœur), puis la brûlure (API de FeuCorps)
		var o := position - dir * 1.6
		ic.impulsion(f, {"o": o, "dir": dir, "rayon": clampf(0.42 * sqrt(force), 0.35, 0.75), "dbl": force > 1.2, "id": -1 - ic.rng.randi_range(0, 1 << 20)}, 0.16 + 0.06 * minf(force, 2.0))
		COMPORTEMENTS.feu.embraser(ic, f, position, dir, force, 0.6)
		g.lumiere("impact_corps%d" % f.id, position - dir * 0.6 + Vector3.UP * 0.3, GestionMagie.LUMIERE.feu, 5.0 * clampf(force, 0.6, 1.6), 6.0, 6.0, 0.35)
		return true
	COMPORTEMENTS[ecole].embraser(ic, f, position, dir, force, 0.0)
	return true

## Point d'accroche de GestionMagie.zone (feu) : vrai si l'explosion part DANS un corps pris en charge (boule de feu) ;
## la boule d'explosion posée devant n'est alors pas dessinée (anneau au sol, flammes au sol et lumière restent).
static func zone_sur_corps(g: GestionMagie, p: Vector3) -> bool:
	return actif and corps_en(g, p) != null

## Point d'accroche de GestionMagie.chaine : chaque point (après le premier) qui tombe DANS un corps est remplacé par le
## point de sa surface tourné vers le point précédent (l'arc s'y pose au lieu de plonger au centre du corps).
## Renvoie, par point, vrai s'il a été posé sur un corps.
static func points_sur_corps(g: GestionMagie, pts: Array[Vector3]) -> Array[bool]:
	var sur: Array[bool] = []
	sur.resize(pts.size())
	sur.fill(false)
	if not actif or instance == null or not is_instance_valid(instance):
		return sur
	for i in range(1, pts.size()):
		var c := corps_en(g, pts[i])
		if c == null:
			continue
		# surface d'un foyer déjà ouvert sur ce corps (déjà à jour pour cette image) : aucune lecture ni création ici
		var s: SurfaceCorps = null
		for f: Foyer in instance.foyers:
			if not f.libre and f.cible == c and f.surface != null and f.surface.nb > 0:
				s = f.surface
				break
		if s == null:
			continue
		var o := c.global_position
		s.actualiser(o)
		var d := (pts[i] - pts[i - 1]).normalized()
		var k := s.point_vise(pts[i] - o - d * 1.5, d)
		if k >= 0:
			pts[i] = o + s.pos[k] + s.nor[k] * 0.04
			sur[i] = true
	return sur

## Corps (ennemi / cible) dont la colonne contient `p` (rayon 0,6 m, du sol à 2,3 m), le plus proche ; null sinon.
static func corps_en(g: GestionMagie, p: Vector3) -> Node3D:
	var meilleur: Node3D = null
	var dm := 0.6
	for grp in ["ennemis", "cibles_combat", "cibles_magie"]:
		for n in g.get_tree().get_nodes_in_group(grp):
			if not (n is Node3D) or not (n as Node3D).is_visible_in_tree():
				continue
			var b := (n as Node3D).global_position
			var h := p.y - b.y
			if h < -0.25 or h > 2.3:
				continue
			var dh := Vector2(p.x - b.x, p.z - b.z).length()
			if dh < dm:
				dm = dh
				meilleur = n
	return meilleur

## Point d'accroche de GestionMagie.tout_arreter.
static func arreter_tout() -> void:
	if instance != null and is_instance_valid(instance):
		for f: Foyer in instance.foyers:
			if not f.libre:
				instance.liberer(f, true)
		instance._impulsions.clear()

## Point d'accroche de GestionMagie.vitrine_prechauffe : crée le pool (si besoin) et pose dans la vitrine un émetteur par
## mode avec les VRAIS matériaux de dessin, plus le voile sur le shader des personnages (pipelines compilés au chargement).
static func vitrine(g: GestionMagie, v: Node3D) -> void:
	var ic := obtenir(g)
	ic._vitrine(v)

static func stats() -> Dictionary:
	if instance == null or not is_instance_valid(instance):
		return {"foyers": 0, "particules": 0, "crees": 0}
	var n := 0
	var r := 0
	for f: Foyer in instance.foyers:
		if not f.libre:
			n += 1
		for e: Emetteur in f.em:
			r += e.reserve
	return {"foyers": n, "particules": r, "crees": instance.crees, "lectures": SurfaceCorps.lectures}

# ====================================================================== cycle de vie

func _init() -> void:
	process_priority = 101   # après GestionMagie (100) : les jets de l'image sont déjà passés par jet_gerbe
	rng.randomize()

func _enter_tree() -> void:
	if foyers.is_empty():
		_creer_pool()

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _creer_pool() -> void:
	mat_voile = ShaderMaterial.new()
	mat_voile.shader = SH_VOILE
	mat_coque = ShaderMaterial.new()
	mat_coque.shader = SH_COQUE
	crees += 2
	# agent B : une coque par école (même shader, uniforme `ecole`), maillage des arcs partagé
	for ecole in COMPORTEMENTS:
		var nc := int(_const(ecole, "COQUE", -1))
		if nc >= 0:
			var mc := ShaderMaterial.new()
			mc.shader = SH_COQUE_ECOLES
			mc.set_shader_parameter("ecole", nc)
			mat_coques[ecole] = mc
			crees += 1
	mesh_arcs = _creer_mesh_arcs()
	crees += 1
	for i in MAX_FOYERS:
		var f := Foyer.new()
		f.id = i
		f.img_pos = SurfaceCorps.image()
		f.img_nor = SurfaceCorps.image()
		f.tex_pos = ImageTexture.create_from_image(f.img_pos)
		f.tex_nor = ImageTexture.create_from_image(f.img_nor)
		crees += 2
		for k in MAX_VOILES:
			var c := MeshInstance3D.new()
			c.name = "Coque%d_%d" % [i, k]
			c.visible = false
			c.layers = CoucheMagie.CALQUE
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.extra_cull_margin = 0.3
			c.material_override = mat_coque
			add_child(c)
			f.coques.append(c)
			crees += 1
		# arcs sur le corps (agent B) : maillage partagé, matériau et texture de sous-segments par foyer
		var ma := ShaderMaterial.new()
		ma.shader = SH_ARCS
		f.img_segs = Image.create_empty(MAX_SEGMENTS * 2, 1, false, Image.FORMAT_RGBAF)
		f.tex_segs = ImageTexture.create_from_image(f.img_segs)
		f.segs.resize(MAX_SEGMENTS * 8)
		ma.set_shader_parameter("pts", f.tex_pos)
		ma.set_shader_parameter("nrm", f.tex_nor)
		ma.set_shader_parameter("segs", f.tex_segs)
		var arcs := MeshInstance3D.new()
		arcs.name = "Arcs%d" % i
		arcs.mesh = mesh_arcs
		arcs.material_override = ma
		arcs.layers = CoucheMagie.CALQUE
		arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arcs.custom_aabb = AABB(Vector3(-10, -4, -10), Vector3(20, 10, 20))
		arcs.visible = false
		add_child(arcs)
		f.arcs = arcs
		f.mat_arcs = ma
		crees += 4
		var ra := GPUParticlesAttractorSphere3D.new()
		ra.name = "Repousse%d" % i
		ra.radius = 1.0
		ra.strength = 0.0
		ra.attenuation = 0.6
		ra.directionality = 0.0
		ra.visible = false
		add_child(ra)
		f.repousse = ra
		crees += 1
		for k in EMETTEURS:
			var e := Emetteur.new()
			var p := GPUParticles3D.new()
			p.name = "Corps%d_%d" % [i, k]
			p.local_coords = false
			p.one_shot = false
			p.emitting = false
			p.visible = false
			p.amount = 8
			p.fixed_fps = 0
			p.interpolate = false
			p.explosiveness = 0.0
			p.randomness = 0.0
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.draw_pass_1 = gm._quad
			p.visibility_aabb = AABB(Vector3(-3.0, -1.5, -3.0), Vector3(6.0, 5.0, 6.0))
			var m := ShaderMaterial.new()
			m.shader = SH_PART
			m.set_shader_parameter("pts", f.tex_pos)
			m.set_shader_parameter("nrm", f.tex_nor)
			p.process_material = m
			p.material_override = gm._mat_part(false, 6.0, 1.3)
			e.p = p
			e.mat = m
			e.u = f.u
			crees += 2
			f.em.append(e)
			add_child(p)
		foyers.append(f)
	_configurer_tous()
	# matériaux de dessin et rampes de TOUTES les écoles créés ici (pas au premier impact d'une école)
	for ecole in COMPORTEMENTS:
		for fin in [false, true]:
			for r0: Dictionary in COMPORTEMENTS[ecole].REGLAGES:
				if r0.is_empty():
					continue
				var r := r0.duplicate()
				if fin and r0.has("fin"):
					r.merge(r0.fin, true)
				elif not fin and r0.has("retro"):
					r.merge(r0.retro, true)
				var n0: int = gm._mats.size()
				gm._mat_part(r.get("add", false), float(r.get("cap", 6.0)), float(r.get("eclat", 1.4)), float(r.get("etire", 0.0)) if fin else 0.0)
				crees += gm._mats.size() - n0
				_rampe(r.get("rampe", PresetsMagie.FEU), fin)

## Constante facultative d'un comportement (COQUE, ARCS…), ou `defaut`.
func _const(ecole: String, nom: String, defaut: Variant) -> Variant:
	if not _consts.has(ecole):
		_consts[ecole] = (COMPORTEMENTS[ecole] as Script).get_script_constant_map()
	return (_consts[ecole] as Dictionary).get(nom, defaut)

## Maillage fixe des arcs : MAX_SEGMENTS sous-segments × 2 couches (tous les halos, puis tous les cœurs) × 6 sommets.
## UV = (couche, côté), UV2 = (n° du sous-segment, bout) ; les positions sont calculées par magie_corps_arcs.gdshader.
static func _creer_mesh_arcs() -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for couche in [0.0, 1.0]:
		for sg in MAX_SEGMENTS:
			for c: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(1, 1), Vector2(0, -1), Vector2(1, 1), Vector2(1, -1)]:
				v.append(Vector3.ZERO)
				uv.append(Vector2(couche, c.y))
				uv2.append(Vector2(sg, c.x))
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_TEX_UV2] = uv2
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m

## Réglages des émetteurs selon le niveau de détail (rétro / couche fine) : au changement de niveau seulement.
func _configurer_tous() -> void:
	gm.fin_actif = GestionMagie.forcer_fin or (gm.couche != null and gm.couche.fine())
	_niveau = 1 if gm.fin_actif else 0
	for f: Foyer in foyers:
		var ecole: String = f.ecole if f.ecole != "" else "feu"
		var regs: Array = COMPORTEMENTS[ecole].REGLAGES
		for k in EMETTEURS:
			configurer(f.em[k], regs[k] if k < regs.size() else {})

## Applique un réglage à un émetteur (paramètres fixes du shader, durée de vie, nombre, matériau de dessin).
## Clés : mode, n, vie, vitesse, gravite, amorti, ouvert, ecarte, turb, suit_jet, taille, courbe (0 plat, 1 descend,
## 2 bosse, 3 monte), alea, chaud, rampe, add, cap, eclat, etire ; sous-dictionnaire "fin" (couche fine) qui surcharge.
func configurer(e: Emetteur, r0: Dictionary) -> void:
	var r := r0.duplicate()
	if _niveau == 1 and r0.has("fin"):
		r.merge(r0.fin, true)
	elif _niveau == 0 and r0.has("retro"):
		r.merge(r0.retro, true)
	e.reglage = r
	if r.is_empty():
		e.n = 0
		return
	var moyen := gm.couche != null and gm.couche.fine() and gm.couche.niveau == 1
	var n := maxi(1, int(round(float(r.get("n", 32)) * (0.7 if moyen else 1.0))))
	if e.p.amount != n:
		e.p.amount = n
	e.n = n
	e.vie = float(r.get("vie", 0.5))
	e.p.lifetime = e.vie
	var m := e.mat
	m.set_shader_parameter("mode", int(MODES.get(String(r.get("mode", "langues")), 0)))
	m.set_shader_parameter("vitesse", r.get("vitesse", Vector2(0.5, 1.5)))
	m.set_shader_parameter("gravite", r.get("gravite", Vector3(0, 2, 0)))
	m.set_shader_parameter("amorti", r.get("amorti", Vector2(1, 2)))
	m.set_shader_parameter("ouvert", float(r.get("ouvert", 0.3)))
	m.set_shader_parameter("ecarte", float(r.get("ecarte", 0.02)))
	m.set_shader_parameter("turb", float(r.get("turb", 0.0)))
	m.set_shader_parameter("suit_jet", float(r.get("suit_jet", 0.35)))
	m.set_shader_parameter("taille", r.get("taille", Vector2(0.02, 0.05)))
	m.set_shader_parameter("courbe", int(r.get("courbe", 1)))
	m.set_shader_parameter("alea_vie", float(r.get("alea", 0.3)))
	m.set_shader_parameter("chaud", float(r.get("chaud", 0.4)))
	m.set_shader_parameter("rampe", _rampe(r.get("rampe", PresetsMagie.FEU), _niveau == 1))
	var add: bool = r.get("add", false)
	e.p.material_override = gm._mat_part(add, float(r.get("cap", 6.0)), float(r.get("eclat", 1.4)), float(r.get("etire", 0.0)) if _niveau == 1 else 0.0)
	e.p.sorting_offset = 0.5 if add else 0.0

func _rampe(couleurs: Array, fine: bool) -> GradientTexture1D:
	var cle := "%s|%s" % [str(couleurs), fine]
	if not _rampes.has(cle):
		_rampes[cle] = GestionMagie._rampe(couleurs, false, fine)
		crees += 1
	return _rampes[cle]

# ====================================================================== foyers

func trouver(cible: Node3D, ecole: String) -> Foyer:
	for f: Foyer in foyers:
		if not f.libre and f.cible == cible and f.ecole == ecole:
			return f
	return null

## Foyer de `cible` pour `ecole` (pris dans le pool ; le plus avancé dans son extinction cède sa place si tout est pris).
func foyer(cible: Node3D, ecole: String) -> Foyer:
	var f := trouver(cible, ecole)
	if f != null:
		return f
	var libre: Foyer = null
	for x: Foyer in foyers:
		# de préférence un foyer libre déjà réglé pour cette école (pas de reconfiguration des émetteurs)
		if x.libre and gm.horloge >= x.fin_particules and (libre == null or x.ecole == ecole):
			libre = x
			if x.ecole == ecole:
				break
	if libre == null:
		for x: Foyer in foyers:
			if x.libre:
				libre = x
				break
	if libre == null:
		# le foyer le plus ancien sans jet cède sa place
		for x: Foyer in foyers:
			if libre == null or float(x.d.get("vu", 0.0)) < float(libre.d.get("vu", 0.0)):
				libre = x
		liberer(libre, true)
	var s := SurfaceCorps.de(cible, false)
	if s == null:
		return null
	if s.repli() and not _a_preparer.has(cible):
		_a_preparer.push_front(cible)
	f = libre
	f.libre = false
	f.cible = cible
	f.surface = s
	f.t0 = gm.horloge
	f.d = {}
	if f.ecole != ecole:
		f.ecole = ecole
		var regs: Array = COMPORTEMENTS[ecole].REGLAGES
		for k in EMETTEURS:
			configurer(f.em[k], regs[k] if k < regs.size() else {})
	f.ecole = ecole
	_regler_ecole(f)
	_voiler(f)
	COMPORTEMENTS[ecole].debut(self, f)
	return f

## Rend un foyer au pool : émetteurs coupés (les particules en vie finissent, sauf `net`), voile retiré, réserve rendue.
func liberer(f: Foyer, net := false) -> void:
	var fin := gm.horloge
	for e: Emetteur in f.em:
		e.p.emitting = false
		e.ratio = 0.0
		fin = maxf(fin, gm.horloge + e.vie * 1.4)
		if net:
			e.p.visible = false
		_reserver(e, 0)
	f.fin_particules = fin if not net else gm.horloge
	f.repousse.strength = 0.0
	f.repousse.visible = false
	f.arcs.visible = false
	f.nb_segs = 0
	f.ec_ecrit = []
	f.u.clear()
	if f.d.has("_ec"):
		# canaux des écoles B remis à zéro (un autre foyer du même corps les réécrit à l'image suivante)
		for mi in f.voiles:
			if is_instance_valid(mi):
				(mi as MeshInstance3D).set_instance_shader_parameter("mc_ecoles", Vector4.ZERO)
	_devoiler(f)
	f.libre = true
	f.cible = null
	if f.surface != null:
		f.surface.lacher()
	f.surface = null
	f.d = {}

func _voiler(f: Foyer) -> void:
	f.voiles.clear()
	for mi in SurfaceCorps.maillages(f.cible):
		if f.voiles.size() >= MAX_VOILES:
			break
		var id := mi.get_instance_id()
		if mi.material_overlay == null:
			mi.material_overlay = mat_voile
			var echelle := maxf(mi.global_basis.get_scale().x, 0.0001)
			mi.set_instance_shader_parameter("mc_mesh", Vector4(gm._grille_de(mi), 0.006 / echelle, 64.0 / echelle, 0.0))
			mi.set_instance_shader_parameter("mc_feu", Vector4.ZERO)
			mi.set_instance_shader_parameter("mc_dir", Vector4(0, 0, -1, 0))
			mi.set_instance_shader_parameter("mc_ecoles", Vector4.ZERO)
			mi.set_instance_shader_parameter("mc_pt", Vector4.ZERO)
			_voiles[id] = 1
		elif mi.material_overlay == mat_voile:
			_voiles[id] = int(_voiles.get(id, 0)) + 1
		else:
			continue   # un autre voile (statut d'une autre école, enchantement) : laissé tel quel
		f.voiles.append(mi)
		if not f.avec_coque:
			continue
		# coque de flammes : même maillage, même peau, même squelette (suit l'animation et le ragdoll)
		var c: MeshInstance3D = f.coques[f.voiles.size() - 1]
		c.mesh = mi.mesh
		c.skin = mi.skin
		var sq := mi.get_node_or_null(mi.skeleton) as Skeleton3D if mi.skin != null else null
		c.skeleton = c.get_path_to(sq) if sq != null else NodePath("")
		c.global_transform = mi.global_transform
		c.set_instance_shader_parameter("mc_mesh", Vector4(gm._grille_de(mi), 0.0, 64.0, 0.0))
		c.set_instance_shader_parameter("mc_feu", Vector4.ZERO)
		c.set_instance_shader_parameter("mc_ecoles", Vector4.ZERO)
		c.visible = true

func _devoiler(f: Foyer) -> void:
	for c: MeshInstance3D in f.coques:
		if c.visible or c.mesh != null:
			c.visible = false
			c.skeleton = NodePath("")
			c.skin = null
			c.mesh = null
	for mi in f.voiles:
		if not is_instance_valid(mi):
			continue
		var id: int = mi.get_instance_id()
		var k := int(_voiles.get(id, 1)) - 1
		if k <= 0:
			_voiles.erase(id)
			if mi.material_overlay == mat_voile:
				mi.material_overlay = null
		else:
			_voiles[id] = k
	f.voiles.clear()

## Canaux du voile d'un foyer (paramètres d'instance, aucun matériau touché).
func voile(f: Foyer, canal: String, valeur: Vector4) -> void:
	for k in f.voiles.size():
		var mi: Variant = f.voiles[k]
		if is_instance_valid(mi):
			(mi as MeshInstance3D).set_instance_shader_parameter(canal, valeur)
			(f.coques[k] as MeshInstance3D).set_instance_shader_parameter(canal, valeur)

## Répulseur du foyer : ellipsoïde du corps, force `k` (0 = éteint, 1 = sous le jet) : les particules du JET qui arrivent
## sur le corps sont poussées vers l'extérieur et glissent autour de la silhouette au lieu de s'entasser devant.
func repousser(f: Foyer, k: float) -> void:
	var ra := f.repousse
	if k <= 0.01:
		if ra.visible:
			ra.visible = false
			ra.strength = 0.0
		return
	var s := f.surface
	ra.visible = true
	ra.global_transform = Transform3D(Basis.from_scale(s.masse_demi * 1.35), f.origine() + s.masse_centre)
	ra.strength = -FORCE_REPOUSSE * k

## Part active d'un émetteur (0 = éteint) ; la réserve dans le budget de GestionMagie suit, plafond respecté.
func activer(e: Emetteur, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if e.n <= 0:
		ratio = 0.0
	var voulu := int(ceil(float(e.n) * ratio))
	var cap := GestionMagie.MAX_PARTICULES_FIN if gm.fin_actif else GestionMagie.MAX_PARTICULES
	var dispo := cap - gm._budget + e.reserve
	if voulu > dispo:
		voulu = maxi(dispo, 0)
		ratio = float(voulu) / maxf(float(e.n), 1.0)
	_reserver(e, voulu)
	e.ratio = ratio
	var on := ratio > 0.02
	if on:
		if absf(e.p.amount_ratio - ratio) > 0.001:
			e.p.amount_ratio = ratio
		if not e.p.visible:
			e.p.visible = not GestionMagie.masquer_particules
		if not e.p.emitting:
			for k in e.u:
				e.mat.set_shader_parameter(k, e.u[k])
			e.p.emitting = true
	elif e.p.emitting:
		e.p.emitting = false

func _reserver(e: Emetteur, n: int) -> void:
	if gm != null and is_instance_valid(gm):
		gm._budget += n - e.reserve
	e.reserve = n

## Uniformes communs du jet / des foyers pour tous les émetteurs d'un foyer.
##
## (Agent B, perf) La valeur est gardée dans f.u et posée seulement si elle a changé, et seulement sur les émetteurs qui
## émettent ; un émetteur qui s'allume (activer) reçoit d'un coup toutes les valeurs du foyer. Coût CPU : ~6× moins
## d'appels set_shader_parameter qu'avant pour un foyer dont la moitié des émetteurs est éteinte.
func uniformes(f: Foyer, nom: StringName, valeur: Variant) -> void:
	var prec: Variant = f.u.get(nom)
	if prec != null and typeof(prec) == typeof(valeur) and prec == valeur:
		return
	f.u[nom] = valeur
	for e: Emetteur in f.em:
		if e.p.emitting:
			e.mat.set_shader_parameter(nom, valeur)

# ====================================================================== extensions de l'agent B (additives)

## Coque et arcs selon l'école du foyer (à sa prise dans le pool) : matériaux CRÉÉS au pool, seulement affectés ici.
func _regler_ecole(f: Foyer) -> void:
	var mc: Variant = mat_coques.get(f.ecole)
	f.avec_coque = f.ecole == "feu" or mc != null
	var m: Material = mat_coque if f.ecole == "feu" else mc
	for c: MeshInstance3D in f.coques:
		if m != null and c.material_override != m:
			c.material_override = m
	var a: Dictionary = _const(f.ecole, "ARCS", {})
	if not a.is_empty():
		var ma := f.mat_arcs
		ma.set_shader_parameter("halo", Color(a.get("halo", "#4a3ad0")))
		ma.set_shader_parameter("coeur", Color(a.get("coeur", "#f0f2ff")))
		ma.set_shader_parameter("largeur_halo", float(a.get("halo_px", 3.0)))
		ma.set_shader_parameter("largeur_coeur", float(a.get("coeur_px", 1.0)))
		ma.set_shader_parameter("eclat", float(a.get("eclat", 1.6)))
		ma.set_shader_parameter("sombre", bool(a.get("sombre", false)))
		ma.set_shader_parameter("ampl", float(a.get("ampl", 0.22)))
	f.arcs.visible = false
	f.nb_segs = 0
	f.nb_segs_prec = MAX_SEGMENTS   # la texture de l'ancien foyer est effacée au premier arcs_fin

## Arcs : arcs_debut(f), puis arc(…) pour chaque lien, puis arcs_fin(f) (écrit la texture). À appeler quand la FORME des
## arcs change (~20 fois par seconde) ; entre deux, le shader les garde accrochés aux points du corps à chaque image.
func arcs_debut(f: Foyer) -> void:
	f.nb_segs = 0

## Un lien du point `ia` au point `ib` (index de f.surface) en `noeuds` sous-segments. Genres : 0 rampe (surface), 1 sol,
## 2 brindille (ib ignoré), 3 main (filament vers point_main, ib ignoré), 4 saut (entre deux os). Faux = plus de place.
func arc(f: Foyer, ia: int, ib: int, genre: int, noeuds: int, graine: float, largeur := 1.0, alpha := 1.0) -> bool:
	if f.nb_segs + noeuds > MAX_SEGMENTS or ia < 0 or ia >= f.surface.nb:
		return false
	var g := float(genre + 16 * noeuds)
	var sg := f.segs
	for k in noeuds:
		var b := f.nb_segs * 8
		sg[b] = ia
		sg[b + 1] = ib
		sg[b + 2] = k
		sg[b + 3] = k + 1
		sg[b + 4] = graine
		sg[b + 5] = largeur
		sg[b + 6] = alpha
		sg[b + 7] = g
		f.nb_segs += 1
	f.segs = sg
	return true

func arcs_fin(f: Foyer) -> void:
	var sg := f.segs
	for k in range(f.nb_segs, mini(f.nb_segs_prec, MAX_SEGMENTS)):
		sg[k * 8 + 6] = 0.0
	f.segs = sg
	f.nb_segs_prec = f.nb_segs
	f.img_segs.set_data(MAX_SEGMENTS * 2, 1, false, Image.FORMAT_RGBAF, sg.to_byte_array())
	f.tex_segs.update(f.img_segs)
	var on := f.nb_segs > 0 and not GestionMagie.masquer_particules
	if on and not f.arcs.visible:
		f.arcs.global_position = f.origine()
	f.arcs.visible = on

## Vrai (une fois) quand la surface du foyer a été REMPLACÉE (repli en capsules → vrais maillages, lus après le premier
## impact) : les index de points gardés par le comportement ne désignent plus les mêmes points, il faut les retrouver
## (plus_proche) avec les positions d'avant.
func surface_changee(f: Foyer) -> bool:
	if f.d.get("_s") == f.surface:
		return false
	var avant: bool = f.d.has("_s")
	f.d["_s"] = f.surface
	return avant

## SurfaceCorps.point_vise (boucle sur tous les points, ~0,1 ms) refait au plus toutes les 0,08 s, ou plus tôt si le jet
## a tourné de plus de ~3° ou si son origine (relative au corps) a bougé de plus de 8 cm. (Agent B, perf.)
func point_vise(f: Foyer, o: Vector3, d: Vector3) -> int:
	var c: Variant = f.d.get("_pv")
	if c is Array and gm.horloge - float(c[0]) < 0.08 and (c[1] as Vector3).distance_to(o) < 0.08 and (c[2] as Vector3).dot(d) > 0.9985 and int(c[3]) < f.surface.nb:
		return int(c[3])
	var i := f.surface.point_vise(o, d)
	f.d["_pv"] = [gm.horloge, o, d, i]
	return i

## Index du point de `s` le plus proche de `p` (repère relatif) ; -1 si la surface est vide.
static func plus_proche(s: SurfaceCorps, p: Vector3) -> int:
	var m := -1
	var dm := INF
	for i in s.nb:
		var dd := s.pos[i].distance_squared_to(p)
		if dd < dm:
			dm = dd
			m = i
	return m

## Uniformes des arcs suivis à chaque image : hauteur du sol sous le corps, main du lanceur (monde ; drain).
func arcs_regler(f: Foyer, main := Vector3.INF) -> void:
	if f.surface == null:
		return
	f.mat_arcs.set_shader_parameter("sol_y", minf(f.surface.bas, 0.0) + 0.02)
	if main != Vector3.INF:
		f.mat_arcs.set_shader_parameter("point_main", main - f.origine())

## Canaux des écoles B sur le voile et la coque (fusionnés par corps à la fin de l'image : un corps gelé ET électrifié garde
## les deux). gel / choc / ombre / traces / paleur : 0..1 ; pt = point du monde (givre, arcs) ; rayon = rayon du givre (m).
func ecoles(f: Foyer, gel: float, choc: float, ombre: float, traces: float, paleur: float, pt: Vector3, rayon: float) -> void:
	f.d["_ec"] = [gel, choc, ombre, traces, paleur, pt, rayon]

func _ecrire_ecoles() -> void:
	var acc := {}
	for f: Foyer in foyers:
		if f.libre or not f.d.has("_ec") or f.ecole == "feu":
			continue
		var e: Array = f.d._ec
		var id := f.cible.get_instance_id()
		if not acc.has(id):
			acc[id] = [0.0, 0.0, 0.0, 0.0, 0.0, Vector3.ZERO, 0.0, -1.0, []]
		var a: Array = acc[id]
		for k in 5:
			a[k] = maxf(float(a[k]), float(e[k]))
		# point : celui du givre s'il y en a (il porte le rayon), sinon celui de l'école la plus forte
		var prio := float(e[0]) * 2.0 + maxf(float(e[1]), float(e[3])) + float(e[2]) * 0.5
		if prio > float(a[7]):
			a[7] = prio
			a[5] = e[5]
			a[6] = e[6]
		(a[8] as Array).append(f)
	for id in acc:
		var a: Array = acc[id]
		var w := 256.0 * roundf(clampf(float(a[3]), 0.0, 1.0) * 255.0) + roundf(clampf(float(a[4]), 0.0, 1.0) * 255.0)
		var v := Vector4(float(a[0]), float(a[1]), float(a[2]), w)
		var pt: Vector3 = a[5]
		var vp := Vector4(pt.x, pt.y, pt.z, float(a[6]))
		for f: Foyer in a[8]:
			if f.ec_ecrit.size() == 2 and f.ec_ecrit[0] == v and (f.ec_ecrit[1] as Vector4).is_equal_approx(vp):
				continue
			f.ec_ecrit = [v, vp]
			voile(f, "mc_ecoles", v)
			voile(f, "mc_pt", vp)

## Impulsion : jet VIRTUEL bref (info comme celle de jet_gerbe : o, dir, rayon, dbl, id) rejoué `duree` s sur le foyer :
## la boule de feu rend le même « souffle qui entoure la silhouette » que le jet, avec l'API de l'école.
func impulsion(f: Foyer, info: Dictionary, duree: float) -> void:
	_impulsions.append({"f": f, "info": info, "fin": gm.horloge + duree})

func _impulser(f: Foyer) -> void:
	if _impulsions.is_empty():
		return
	var i := _impulsions.size() - 1
	while i >= 0:
		var im: Dictionary = _impulsions[i]
		if im.f == f:
			if gm.horloge > float(im.fin) or f.libre:
				_impulsions.remove_at(i)
			else:
				COMPORTEMENTS[f.ecole].jet(self, f, im.info)
		i -= 1

func _process(_dt: float) -> void:
	if gm == null or not is_instance_valid(gm):
		return
	var t_us := Time.get_ticks_usec()
	_maj_module()
	duree_maj_us += Time.get_ticks_usec() - t_us
	images_maj += 1

func _maj_module() -> void:
	var dt := get_process_delta_time()
	var niveau := 1 if (GestionMagie.forcer_fin or (gm.couche != null and gm.couche.fine())) else 0
	if niveau != _niveau:
		_configurer_tous()
	var actifs := 0
	for f: Foyer in foyers:
		if f.libre:
			if gm.horloge >= f.fin_particules:
				for e: Emetteur in f.em:
					if e.p.visible and not e.p.emitting:
						e.p.visible = false
			continue
		if not is_instance_valid(f.cible) or not (f.cible as Node3D).is_inside_tree():
			liberer(f, true)
			continue
		actifs += 1
		var o := f.origine()
		f.surface.actualiser(o)
		f.surface.ecrire(f.img_pos, f.img_nor)
		f.tex_pos.update(f.img_pos)
		f.tex_nor.update(f.img_nor)
		# (agent B, perf) positions et transformées réécrites seulement si elles ont changé : poser global_transform
		# notifie et propage à chaque appel (~5 µs), pour 6 émetteurs et jusqu'à 12 coques par corps
		if f.d.get("_o") != o:
			f.d["_o"] = o
			for e: Emetteur in f.em:
				e.p.global_position = o
			if f.arcs.visible:
				f.arcs.global_position = o
		for k in (f.voiles.size() if f.avec_coque else 0):
			var mi: Variant = f.voiles[k]
			if is_instance_valid(mi):
				var c := f.coques[k] as MeshInstance3D
				var xm := (mi as Node3D).global_transform
				if not c.global_transform.is_equal_approx(xm):
					c.global_transform = xm
				var vis := (mi as Node3D).is_visible_in_tree()
				if c.visible != vis:
					c.visible = vis
		uniformes(f, "nb_pts", f.surface.nb)
		_impulser(f)
		if not COMPORTEMENTS[f.ecole].maj(self, f, dt):
			liberer(f)
	if actifs > 0:
		_ecrire_ecoles()
		if gm.couche != null:
			gm.couche.demander()
	_preparer(dt)

## Lecture des maillages en avance (au plus un par image) : ennemis proches pas encore échantillonnés, puis ceux touchés
## avant d'être prêts (le foyer tourne alors sur le repli en capsules, puis il est refait avec les vrais points).
func _preparer(dt: float) -> void:
	_scan -= dt
	if _scan <= 0.0:
		_scan = 0.5
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		for g in ["ennemis", "cibles_magie", "cibles_combat"]:
			for n in get_tree().get_nodes_in_group(g):
				if n is Node3D and not _a_preparer.has(n) and _a_preparer.size() < 16:
					if cam != null and (n as Node3D).global_position.distance_to(cam.global_position) > 30.0:
						continue
					if not SurfaceCorps.pret(n):
						_a_preparer.append(n)
	while not _a_preparer.is_empty():
		var c: Variant = _a_preparer[0]
		if not is_instance_valid(c) or not (c as Node).is_inside_tree():
			_a_preparer.pop_front()
			continue
		if SurfaceCorps.preparer_un(c):
			return
		_a_preparer.pop_front()
		# foyer en cours sur le repli : on refait sa surface avec les vrais points
		for f: Foyer in foyers:
			if not f.libre and f.cible == c and f.surface != null and f.surface.repli():
				var s := SurfaceCorps.de(c)
				if s != null:
					f.surface.lacher()
					f.surface = s
		return

## Préchauffe : un émetteur par mode (matériaux de dessin de chaque réglage) et le voile sur un matériau standard et sur
## le shader des personnages ; les VRAIES ressources du pool (même shader de particules, mêmes rampes).
func _vitrine(v: Node3D) -> void:
	var img := SurfaceCorps.image()
	var pts := PackedVector3Array()
	var nrm := PackedVector3Array()
	for i in SurfaceCorps.LARGEUR:
		var a := TAU * i / SurfaceCorps.LARGEUR
		pts.append(Vector3(cos(a) * 0.2, 0.2 + 1.2 * float(i % 16) / 16.0, sin(a) * 0.2))
		nrm.append(Vector3(cos(a), 0.0, sin(a)))
	img.set_data(SurfaceCorps.TEXELS, 1, false, Image.FORMAT_RGBAF, pts.to_byte_array())
	var tp := ImageTexture.create_from_image(img)
	img.set_data(SurfaceCorps.TEXELS, 1, false, Image.FORMAT_RGBAF, nrm.to_byte_array())
	var tn := ImageTexture.create_from_image(img)
	var k := 0
	for ecole in COMPORTEMENTS:
		for fin in [false, true]:
			for r0: Dictionary in COMPORTEMENTS[ecole].REGLAGES:
				var r := r0.duplicate()
				if fin and r0.has("fin"):
					r.merge(r0.fin, true)
				var p := GPUParticles3D.new()
				p.amount = 8
				p.lifetime = 0.5
				p.preprocess = 0.3
				p.local_coords = false
				p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
				p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				p.draw_pass_1 = gm._quad
				var m := ShaderMaterial.new()
				m.shader = SH_PART
				m.set_shader_parameter("pts", tp)
				m.set_shader_parameter("nrm", tn)
				m.set_shader_parameter("nb_pts", SurfaceCorps.LARGEUR)
				m.set_shader_parameter("k_jet", 1.0)
				m.set_shader_parameter("k_foyers", 1.0)
				m.set_shader_parameter("mode", int(MODES.get(String(r.get("mode", "langues")), 0)))
				m.set_shader_parameter("rampe", _rampe(r.get("rampe", PresetsMagie.FEU), fin))
				p.process_material = m
				var add: bool = r.get("add", false)
				p.material_override = gm._mat_part(add, float(r.get("cap", 6.0)), float(r.get("eclat", 1.4)), float(r.get("etire", 0.0)) if fin else 0.0)
				v.add_child(p)
				p.position = Vector3(-0.8 + 0.12 * (k % 12), 0.3 + 0.3 * float(k / 12), 0.6)
				p.emitting = true
				k += 1
	# agent B : arcs (maillage et matériau du pool) dans la couche fine, et un VRAI corps de draugr (maillages skinnés) qui
	# porte le voile et les coques de chaque école : les variantes skinnées des pipelines sont compilées au chargement
	# (sur des boîtes, le premier impact en compilait encore 2 à 11)
	var vd: Node3D = DraugrNordique.creer({})
	if vd != null:
		vd.name = "CorpsVitrine"
		v.add_child(vd)
		vd.position = Vector3(0.1, -0.3, -0.6)   # dans le champ des caméras de la préchauffe (PrechauffeRendu, CoucheMagie.amorcer)
		var nc := 0
		# (la vitrine n'est pas encore dans l'arbre : pas de SurfaceCorps.maillages, qui exige is_visible_in_tree)
		for n in vd.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.visible or SurfaceCorps.IGNORES.has(String(mi.name)):
				continue
			if mi.material_overlay == null:
				mi.material_overlay = mat_voile
				mi.set_instance_shader_parameter("mc_feu", Vector4(vd.global_position.x, 1.0, vd.global_position.z, 1.0))
				mi.set_instance_shader_parameter("mc_ecoles", Vector4(0.6, 0.6, 0.6, 256.0 * 128.0 + 128.0))
				mi.set_instance_shader_parameter("mc_pt", Vector4(vd.global_position.x, 1.0, vd.global_position.z, 2.0))
			var sq := mi.get_node_or_null(mi.skeleton) as Skeleton3D if mi.skin != null else null
			for m: Material in [mat_coque] + mat_coques.values():
				var c := MeshInstance3D.new()
				c.mesh = mi.mesh
				c.skin = mi.skin
				c.material_override = m
				c.layers = CoucheMagie.CALQUE
				c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.add_child(c)
				if sq != null:
					c.skeleton = c.get_path_to(sq)
				c.set_instance_shader_parameter("mc_feu", Vector4(0.0, 1.0, 0.0, 1.0))
				c.set_instance_shader_parameter("mc_ecoles", Vector4(1.0, 1.0, 1.0, 0.0))
				c.set_instance_shader_parameter("mc_pt", Vector4(vd.global_position.x, 1.0, vd.global_position.z, 2.0))
			nc += 1
			if nc >= 8:
				break
	var ar := MeshInstance3D.new()
	ar.mesh = mesh_arcs
	var mat_a := ShaderMaterial.new()
	mat_a.shader = SH_ARCS
	mat_a.set_shader_parameter("pts", tp)
	mat_a.set_shader_parameter("nrm", tn)
	mat_a.set_shader_parameter("segs", foyers[0].tex_segs)
	ar.material_override = mat_a
	ar.layers = CoucheMagie.CALQUE
	ar.custom_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	v.add_child(ar)
	ar.position = Vector3(0.0, 0.3, 0.6)
	for ecole in mat_coques:
		var cq := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.2, 0.3, 0.2)
		cq.mesh = bx
		cq.material_override = mat_coques[ecole]
		cq.layers = CoucheMagie.CALQUE
		v.add_child(cq)
		cq.position = Vector3(-0.4 - 0.3 * float(cq.get_index() % 3), 0.5, 0.6)
		cq.set_instance_shader_parameter("mc_ecoles", Vector4(1, 1, 1, 0))
		cq.set_instance_shader_parameter("mc_pt", Vector4(0, 0.5, 0.6, 2.0))
	# voile partagé : sur un matériau standard et sur le shader des personnages
	var sh_perso := load("res://shaders/perso.gdshader") as Shader
	for j in 2:
		var corps := MeshInstance3D.new()
		var boite := BoxMesh.new()
		boite.size = Vector3(0.2, 0.3, 0.2)
		corps.mesh = boite
		if j == 1 and sh_perso != null:
			var sm := ShaderMaterial.new()
			sm.shader = sh_perso
			corps.material_override = sm
		corps.material_overlay = mat_voile
		v.add_child(corps)
		corps.position = Vector3(0.4 + 0.3 * j, 0.5, 0.6)
		corps.set_instance_shader_parameter("mc_feu", Vector4(0, 0.5, 0.6, 1.0))
		corps.set_instance_shader_parameter("mc_dir", Vector4(0, 0, -1, 0.5))
		corps.set_instance_shader_parameter("mc_ecoles", Vector4(0.5, 0.5, 0.5, 256.0 * 128.0 + 128.0))
