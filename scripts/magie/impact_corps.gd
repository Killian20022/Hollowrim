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
## Lumières de la magie autour d'un corps en feu : pas plus près que RAYON_TEMPERE (m) de son centre, énergie plafonnée.
const RAYON_TEMPERE := 1.35
const ENERGIE_MAX_CORPS := 2.0
## Somme des énergie / distance² des lumières de la magie à moins de 2,6 m d'un corps en feu.
const ECLAIREMENT_MAX := 1.25
## Maillages voilés par corps au plus (une passe de plus par maillage).
const MAX_VOILES := 12
## (2026-10-28, perf) Fréquence des mises à jour (comportement, points, textures) d'un foyer : à chaque image s'il est
## TOUCHÉ (jet, impulsion : moins de TOUCHE_RECENT s), une image sur PERIODE_REPOS sinon (brûlure, choc, retombée,
## extinction), une sur PERIODE_LOIN au-delà de DIST_LOIN m de la caméra ; échelonné par foyer (pas tous la même image).
## Les transformées des coques et la position des émetteurs restent à jour à chaque image (rien ne décroche du corps).
const TOUCHE_RECENT := 0.05
const PERIODE_REPOS := 2
const PERIODE_LOIN := 3
const DIST_LOIN := 10.0
## Au-delà de ce nombre de foyers vivants, les foyers non touchés sont mis à jour à la cadence PERIODE_LOIN (budget CPU).
const FOYERS_PLEINS := 4
var _actifs_prec := 0
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
## Temps CPU passé dans ce module (µs, cumulé : _process + points d'accroche) et images comptées (mesures de coût).
static var cout_us := 0
static var cout_images := 0
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
## Préchauffe « à blanc » sur les VRAIS maillages (la vitrine du chargement n'a que des boîtes : le format de sommets d'un
## corps skinné donne d'autres pipelines au voile et à la coque). Une fois par format de maillage : quand un corps préparé
## est À L'ÉCRAN et qu'aucun sort n'est en cours, voile + coques posés à intensité nulle pendant quelques images.
static var chauffe_corps := true
static var _formats_chauds := {}
var _a_chauffer: Array = []
var _reverif_i := 0
## (2026-10-28) Préchauffe des LUMIÈRES : sur le moteur Mobile, une variante de pipeline dépend aussi du nombre de lumières
## omni qui touchent un objet ; la 1re lumière de la magie sur un gardien ou le sol autour de lui en compilait encore 1 à 3
## au premier sort (électricité 3, ténèbres 1, glace 1). Une fois par corps, quand il est à l'écran et qu'aucun sort n'est
## en cours : 1, puis 2, 3 et 4 lumières du pool de la magie, d'énergie quasi nulle, autour de lui pendant 4 images.
var _a_eclairer: Array = []
var _eclaire: Node3D = null
var _eclaire_n := 0
const ECLAIRE_IMAGES := 4
var _chauffe: Foyer = null
var _chauffe_n := 0
## (2026-10-28) préchauffe à blanc : matériaux de coque passés un à un (feu, puis chaque école B), chacun pendant
## que les lumières montent de 1 à 4 (variantes « voile/coque × nombre de lumières » du moteur Mobile)
var _chauffe_mats: Array = []
const CHAUFFE_IMAGES := ECLAIRE_IMAGES + 10   # + le temps que les lumières de la phase d'avant (0,12 s) s'éteignent
var _prets := {}                       # id des cibles déjà échantillonnées (plus de recherche de maillages)
var _surfaces := {}                    # id -> SurfaceCorps préparée d'avance (le premier impact ne la construit pas)
var _attente := 0.0
## Mise au point (outils de mesure) : imprime les lectures de maillages et les images lentes du module.
static var trace := false
## Faux = fréquence réduite / échelonnement / LOD par distance coupés (mesure avant / après dans la même séance).
static var lod := true
var _t_sections := PackedFloat64Array([0, 0, 0, 0, 0, 0])
var _t_n := 0
var _t_ecoles := {}
static var _prof := {}
static func prof(nom: String, t0: int) -> void:
	if not trace:
		return
	_prof[nom] = float(_prof.get(nom, 0.0)) + Time.get_ticks_usec() - t0                    # mise au point (trace) : temps du comportement par école

class Emetteur:
	var p: GPUParticles3D
	var mat: ShaderMaterial
	var u: Dictionary                  # uniformes communs du foyer (même dictionnaire pour ses 6 émetteurs)
	var reglage: Dictionary = {}
	var n := 0                         # particules (amount)
	var ratio := 0.0                   # part active (amount_ratio)
	var on := false                    # (perf) dernier `emitting` posé par ImpactCorps (évite de relire le nœud)
	var ar := -1.0                     # (perf) dernier amount_ratio posé
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
	var xf_repousse := Transform3D()      # dernière transformée posée sur le répulseur
	var ec_ecrit: Array = []           # derniers canaux des écoles B écrits (pas de réécriture s'ils n'ont pas changé)
	var d: Dictionary = {}             # état du comportement
	var params := PackedFloat32Array() # paramètres écrits à la suite des points (ImpactCorps.regler_*)
	var image := 0                     # mises à jour depuis l'activation (mises à jour espacées)
	var dt_acc := 0.0                  # temps cumulé depuis la dernière mise à jour du comportement (fréquence réduite)
	var nor_ecrit := -1                # SurfaceCorps.image_nor du dernier envoi des normales par ce foyer
	var nor_surface: SurfaceCorps      # … et la surface à laquelle il correspond
	var o_prec := Vector3.INF
	var xf_coques: Array[Transform3D] = []
	var canaux := {}                   # dernière valeur envoyée par canal du voile (envoi seulement si elle change)
	var t0 := 0.0
	var fin_particules := 0.0          # horloge après laquelle plus aucune particule n'est en vie
	var libre := true

	func origine() -> Vector3:
		return cible.global_position if is_instance_valid(cible) else Vector3.ZERO

# ====================================================================== accès

static var _args_lus := false
static func obtenir(g: GestionMagie = null) -> ImpactCorps:
	# (2026-10-28, perf) appelé par chaque jet à chaque image : les arguments ne sont lus qu'une fois
	if instance != null and _args_lus and is_instance_valid(instance) and not instance.is_queued_for_deletion():
		return instance
	_args_lus = true
	if OS.get_cmdline_user_args().has("--sans-impact-corps"):
		actif = false   # mise au point / mesure : rendu d'avant
	if OS.get_cmdline_user_args().has("--sans-chauffe-corps"):
		chauffe_corps = false   # mesure : sans la préchauffe à blanc sur les vrais maillages
	if OS.get_cmdline_user_args().has("--sans-lod"):
		lod = false   # mesure : tous les foyers mis à jour à chaque image (comme avant la réduction de fréquence)
	if OS.get_cmdline_user_args().has("--trace-impact"):
		trace = true   # mesure : coût par section toutes les 240 images, images lentes, lectures, préchauffes
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
	var t0 := Time.get_ticks_usec()
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
	var t := Time.get_ticks_usec() - t0
	cout_us += t
	if trace and t > 3000:
		print("ImpactCorps : accroche du jet lente %.1f ms" % (t / 1000.0))
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
		instance._finir_chauffe()
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
		f.params.resize(SurfaceCorps.TEXELS_PARAMS * 4)
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
	_finir_chauffe()
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
	var s: SurfaceCorps = _surfaces.get(cible.get_instance_id()) if _prets.has(cible.get_instance_id()) else null
	if s != null and s.cible != cible:
		s = null
	if s == null:
		s = SurfaceCorps.de(cible, false)
	if s == null:
		return null
	s.brancher()
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
		e.on = false
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
	f.nor_surface = null
	f.dt_acc = 0.0
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
	f.canaux.clear()
	f.o_prec = Vector3.INF
	f.xf_coques.resize(MAX_VOILES)
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
		f.xf_coques[f.voiles.size() - 1] = mi.global_transform
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
	var avant: Variant = f.canaux.get(canal)
	if avant != null and (avant as Vector4).is_equal_approx(valeur):
		return
	f.canaux[canal] = valeur
	for k in f.voiles.size():
		var mi: Variant = f.voiles[k]
		if is_instance_valid(mi):
			(mi as MeshInstance3D).set_instance_shader_parameter(canal, valeur)
			# (perf) la coque seulement si le foyer en a une (électricité : aucune ; avant, la coque cachée était réécrite)
			if f.avec_coque:
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
	if not ra.visible:
		ra.visible = true
	# (2026-10-28, perf) transformée et force posées seulement si elles changent (poser global_transform propage)
	var xf := Transform3D(Basis.from_scale((s.masse_demi * 1.35).snappedf(0.01)), (f.origine() + s.masse_centre).snappedf(0.01))
	if not xf.is_equal_approx(f.xf_repousse):
		f.xf_repousse = xf
		ra.global_transform = xf
	var fo := snappedf(-FORCE_REPOUSSE * k, 0.05)
	if ra.strength != fo:
		ra.strength = fo

## Part active d'un émetteur (0 = éteint) ; la réserve dans le budget de GestionMagie suit, plafond respecté.
func activer(e: Emetteur, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if e.n <= 0:
		ratio = 0.0
	# (perf) état gardé dans l'émetteur (e.on, e.ar) : plus de lecture des propriétés du nœud à chaque appel
	if absf(ratio - e.ratio) < 0.01 and (ratio > 0.02) == e.on:
		return
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
		if absf(e.ar - ratio) > 0.02:
			e.ar = ratio
			e.p.amount_ratio = ratio
		if not e.on:
			if not e.p.visible:
				e.p.visible = not GestionMagie.masquer_particules
			for k in e.u:
				e.mat.set_shader_parameter(k, e.u[k])
			e.p.emitting = true
			e.on = true
	elif e.on:
		e.p.emitting = false
		e.on = false

func _reserver(e: Emetteur, n: int) -> void:
	if gm != null and is_instance_valid(gm):
		gm._budget += n - e.reserve
	e.reserve = n

## Uniforme commun aux 6 émetteurs d'un foyer. Compatibilité (API du socle d1bb7c6) : les paramètres qui changent à
## chaque image (dir_jet, k_jet, point_impact, rayon_jet, k_foyers, sol_y, foyers, nb_pts) ne sont plus des uniformes
## du shader : ils sont écrits dans la texture des points (regler_jet / regler_foyers, ou ce redirecteur).
func uniformes(f: Foyer, nom: String, valeur: Variant) -> void:
	var p := f.params
	match nom:
		"dir_jet":
			var v: Vector3 = valeur
			p[0] = v.x; p[1] = v.y; p[2] = v.z
		"k_jet":
			p[3] = float(valeur)
		"point_impact":
			var v: Vector3 = valeur
			p[4] = v.x; p[5] = v.y; p[6] = v.z
		"rayon_jet":
			p[7] = float(valeur)
		"k_foyers":
			p[8] = float(valeur)
		"sol_y":
			p[9] = float(valeur)
		"nb_pts":
			pass   # écrit par ImpactCorps à chaque image
		"foyers":
			var l: Array = valeur
			for k in 4:
				var v: Vector4 = l[k] if k < l.size() else Vector4.ZERO
				p[12 + k * 4] = v.x; p[13 + k * 4] = v.y; p[14 + k * 4] = v.z; p[15 + k * 4] = v.w
		"point_main":
			# (fusion) main du lanceur (monde ; ténèbres, mode 6 aspire) : texel P+7, réservé aux écoles de l'agent B
			var v: Vector3 = valeur
			p[28] = v.x; p[29] = v.y; p[30] = v.z
		_:
			# (agent B, perf) autre uniforme : gardé dans f.u et posé seulement s'il change, sur les émetteurs qui émettent ;
			# un émetteur qui s'allume (activer) reçoit d'un coup toutes les valeurs du foyer
			var prec: Variant = f.u.get(nom)
			if prec != null and typeof(prec) == typeof(valeur) and prec == valeur:
				return
			f.u[nom] = valeur
			for e: Emetteur in f.em:
				if e.on:
					e.mat.set_shader_parameter(nom, valeur)

## Paramètres du jet pour les émetteurs du foyer (écrits dans la texture des points, pas d'uniforme) : direction du jet
## (monde), part du jet 0..1, point d'impact (relatif à f.origine()), rayon du jet au contact.
func regler_jet(f: Foyer, dir: Vector3, k_jet: float, point: Vector3, rayon: float) -> void:
	var p := f.params
	p[0] = dir.x; p[1] = dir.y; p[2] = dir.z; p[3] = k_jet
	p[4] = point.x; p[5] = point.y; p[6] = point.z; p[7] = rayon

## Foyers de brûlure (jusqu'à 4 Vector4 : xyz relatif, w rayon ; 0 = éteint), leur force, hauteur du sol (relative).
func regler_foyers(f: Foyer, k_foyers: float, sol_y: float, liste: Array) -> void:
	var p := f.params
	p[8] = k_foyers; p[9] = sol_y
	for k in 4:
		var v: Vector4 = liste[k] if k < liste.size() else Vector4.ZERO
		p[12 + k * 4] = v.x; p[13 + k * 4] = v.y; p[14 + k * 4] = v.z; p[15 + k * 4] = v.w

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
	# (2026-10-28, perf) posés seulement s'ils changent (chaque set_shader_parameter refait le tampon du matériau)
	var sy := snappedf(minf(f.surface.bas, 0.0) + 0.02, 0.01)
	if f.d.get("_arc_sy") != sy:
		f.d["_arc_sy"] = sy
		f.mat_arcs.set_shader_parameter("sol_y", sy)
	if main != Vector3.INF:
		var pm := (main - f.origine()).snappedf(0.01)
		if f.d.get("_arc_pm") != pm:
			f.d["_arc_pm"] = pm
			f.mat_arcs.set_shader_parameter("point_main", pm)

## Vrai si `cible` brûle (foyer de feu sous le jet ou en brûlure) : une seule lumière par corps (budget).
func brule(cible: Node3D) -> bool:
	for f: Foyer in foyers:
		if not f.libre and f.cible == cible and f.ecole == "feu":
			return float(f.d.get("k_brule", 0.0)) > 0.05 or float(f.d.get("k_jet", 0.0)) > 0.05
	return false

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
		# (perf) point arrondi à 3 cm : sous le jet il bouge à chaque image, et chaque changement réécrit 2 paramètres
		# d'instance sur chaque maillage voilé ET sa coque
		var pt: Vector3 = (a[5] as Vector3).snappedf(0.03)
		var vp := Vector4(pt.x, pt.y, pt.z, float(a[6]))
		for f: Foyer in a[8]:
			if f.ec_ecrit.size() != 2:
				f.ec_ecrit = [Vector4.INF, Vector4.INF]
			# (2026-10-28, perf) chaque canal réécrit seulement s'il a changé (sous le jet le point bouge, pas les forces)
			if f.ec_ecrit[0] != v:
				f.ec_ecrit[0] = v
				voile(f, "mc_ecoles", v)
			if not (f.ec_ecrit[1] as Vector4).is_equal_approx(vp):
				f.ec_ecrit[1] = vp
				voile(f, "mc_pt", vp)

## Impulsion : jet VIRTUEL bref (info comme celle de jet_gerbe : o, dir, rayon, dbl, id) rejoué `duree` s sur le foyer :
## la boule de feu rend le même « souffle qui entoure la silhouette » que le jet, avec l'API de l'école.
func impulsion(f: Foyer, info: Dictionary, duree: float) -> void:
	_impulsions.append({"f": f, "info": info, "fin": gm.horloge + duree})

func _a_impulsion(f: Foyer) -> bool:
	for im: Dictionary in _impulsions:
		if im.f == f:
			return true
	return false

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
	var t0 := Time.get_ticks_usec()
	_maj()
	var t := Time.get_ticks_usec() - t0
	cout_us += t
	cout_images += 1
	duree_maj_us += t
	images_maj += 1
	if trace and t > 3000:
		print("ImpactCorps : image lente %.1f ms (%d foyers)" % [t / 1000.0, stats().foyers])

func _maj() -> void:
	var dt := get_process_delta_time()
	var niveau := 1 if (GestionMagie.forcer_fin or (gm.couche != null and gm.couche.fine())) else 0
	if niveau != _niveau:
		_configurer_tous()
	var actifs := 0
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cam_pos := cam.global_position if cam != null else Vector3.INF
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
		# fréquence de mise à jour : chaque image si le foyer est touché, sinon réduite (et plus encore s'il est loin)
		f.dt_acc += dt
		var touche := gm.horloge - float(f.d.get("vu", -INF)) < TOUCHE_RECENT or _a_impulsion(f)
		var periode := 1
		if not touche and lod:
			periode = PERIODE_LOIN if cam_pos != Vector3.INF and o.distance_squared_to(cam_pos) > DIST_LOIN * DIST_LOIN else PERIODE_REPOS
			# (2026-10-28, budget) plus de FOYERS_PLEINS foyers vivants (ex. feu + électricité sur 3 corps) : les foyers non
			# touchés passent à la cadence « loin » (une image sur 3) ; ceux sous le jet restent à chaque image
			if _actifs_prec > FOYERS_PLEINS:
				periode = maxi(periode, PERIODE_LOIN)
		# phase par CORPS (ses foyers feu + électricité partagent la même image : surface et octets calculés une fois)
		var a_jour := periode == 1 or (Engine.get_process_frames() + f.cible.get_instance_id() % 7) % periode == 0 or f.image < 2
		var ta := Time.get_ticks_usec()
		if a_jour:
			f.image += 1
			# touché : points à chaque image, normales une image sur deux ; au repos : tout, à chaque mise à jour (une image
			# sur PERIODE_REPOS : c'est la cadence « brûlure seule » d'avant, mais le comportement suit la même cadence)
			f.surface.actualiser(o, f.image % 2 == 0 or periode > 1)
		_t_sections[0] += Time.get_ticks_usec() - ta
		ta = Time.get_ticks_usec()
		# positions et transformées réécrites seulement si elles ont changé (poser global_transform notifie et propage)
		if not o.is_equal_approx(f.o_prec):
			f.o_prec = o
			for e: Emetteur in f.em:
				e.p.global_position = o
			if f.arcs.visible:
				f.arcs.global_position = o
		for k in (f.voiles.size() if f.avec_coque else 0):
			var mi: Variant = f.voiles[k]
			if is_instance_valid(mi):
				var xf: Transform3D = (mi as Node3D).global_transform
				var c: MeshInstance3D = f.coques[k]
				if not xf.is_equal_approx(f.xf_coques[k]):
					f.xf_coques[k] = xf
					c.global_transform = xf
				if a_jour:
					var vis := (mi as Node3D).is_visible_in_tree()
					if c.visible != vis:
						c.visible = vis
		_t_sections[1] += Time.get_ticks_usec() - ta
		if not a_jour:
			continue
		ta = Time.get_ticks_usec()
		_impulser(f)
		prof("impulser", ta)
		var vivant: bool = COMPORTEMENTS[f.ecole].maj(self, f, f.dt_acc)
		f.dt_acc = 0.0
		_t_sections[2] += Time.get_ticks_usec() - ta
		if trace:
			_t_ecoles[f.ecole] = float(_t_ecoles.get(f.ecole, 0.0)) + Time.get_ticks_usec() - ta
			_t_ecoles[f.ecole + " n"] = float(_t_ecoles.get(f.ecole + " n", 0.0)) + 1000.0
		if not vivant:
			liberer(f)
			continue
		ta = Time.get_ticks_usec()
		f.params[10] = float(f.surface.nb)
		f.surface.ecrire_pos(f.img_pos, f.params)
		f.tex_pos.update(f.img_pos)
		# normales : seulement si la surface les a recalculées depuis le dernier envoi de ce foyer
		if f.nor_ecrit != f.surface.image_nor or f.nor_surface != f.surface:
			f.nor_ecrit = f.surface.image_nor
			f.nor_surface = f.surface
			f.surface.ecrire_nor(f.img_nor)
			f.tex_nor.update(f.img_nor)
		_t_sections[3] += Time.get_ticks_usec() - ta
	_actifs_prec = actifs
	var tb := Time.get_ticks_usec()
	if actifs > 0:
		_ecrire_ecoles()
		prof("ecrire_ecoles", tb)
		var _tl := Time.get_ticks_usec()
		_temperer_lumieres()
		prof("temperer", _tl)
		if gm.couche != null:
			gm.couche.demander()
	_t_sections[4] += Time.get_ticks_usec() - tb
	tb = Time.get_ticks_usec()
	_preparer(dt)
	_t_sections[5] += Time.get_ticks_usec() - tb
	_t_n += 1
	if trace and _t_n >= 240:
		print("ImpactCorps : µs/image surface %.0f, placement %.0f, comportement %.0f, textures %.0f, lumières %.0f, préparation %.0f (%d foyers)" % [
			_t_sections[0] / _t_n, _t_sections[1] / _t_n, _t_sections[2] / _t_n, _t_sections[3] / _t_n, _t_sections[4] / _t_n, _t_sections[5] / _t_n, actifs])
		if not _t_ecoles.is_empty():
			print("ImpactCorps : comportement par école (µs/image) ", _t_ecoles.keys().map(func(e: String) -> String: return "%s %.0f" % [e, float(_t_ecoles[e]) / _t_n]))
			_t_ecoles.clear()
		if not _prof.is_empty():
			print("ImpactCorps : PROF ", _prof.keys().map(func(e: String) -> String: return "%s %.0f" % [e, float(_prof[e]) / _t_n]))
			_prof.clear()
		_t_sections = PackedFloat64Array([0, 0, 0, 0, 0, 0])
		_t_n = 0

## Lumières du pool de GestionMagie (déjà placées pour cette image : ce nœud passe après lui) trop près d'un corps en feu :
## la lumière du bout du jet est posée ~0,5 m devant le torse et brûlait le corps en blanc de près. Elle est reculée
## vers le lanceur et plafonnée : le corps est éclairé par le feu sans saturer (rien n'est modifié dans GestionMagie).
func _temperer_lumieres() -> void:
	# (perf) lumières visibles relevées une fois ; un corps qui porte plusieurs foyers (feu + électricité) traité une fois
	var vis: Array[OmniLight3D] = []
	for l: OmniLight3D in gm._lumieres:
		if l.visible:
			vis.append(l)
	if vis.is_empty():
		return
	var faits: Array[Node3D] = []
	for f: Foyer in foyers:
		if f.libre or f.surface == null or faits.has(f.cible):
			continue
		faits.append(f.cible)
		var c := f.origine() + f.surface.masse_centre
		var somme := 0.0
		var proches: Array[OmniLight3D] = []
		for l: OmniLight3D in vis:
			var v := l.position - c
			var dist := v.length()
			if dist < RAYON_TEMPERE:
				l.position = c + v / maxf(dist, 0.001) * RAYON_TEMPERE
				l.light_energy = minf(l.light_energy, ENERGIE_MAX_CORPS)
				dist = RAYON_TEMPERE
			if dist < 2.6:
				somme += l.light_energy / (dist * dist)
				proches.append(l)
		# éclairement total reçu par le corps plafonné (de près, la lumière de la main s'ajoute à celle du jet)
		if somme > ECLAIREMENT_MAX:
			var k := ECLAIREMENT_MAX / somme
			for l in proches:
				l.light_energy *= k

## Lecture des maillages en avance (au plus un par image) : ennemis proches pas encore échantillonnés, puis ceux touchés
## avant d'être prêts (le foyer tourne alors sur le repli en capsules, puis il est refait avec les vrais points).
func _preparer(dt: float) -> void:
	if _chauffe != null:
		_chauffe_n -= 1
		if gm.couche != null:
			gm.couche.demander()
		if _chauffe_n <= 0:
			if _chauffe_mats.is_empty() or not is_instance_valid(_chauffe.cible) or not gm._jets.is_empty() or not gm._projectiles.is_empty():
				_finir_chauffe()
			else:
				_chauffe_phase()
	if _eclaire != null:
		_eclairer_image()
	_scan -= dt
	if _scan <= 0.0:
		_scan = 0.5
		_reverif_i += 1
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		var deja: Array[Node3D] = []
		for g in ["ennemis", "cibles_magie", "cibles_combat"]:
			for n in get_tree().get_nodes_in_group(g):
				if not (n is Node3D) or _a_preparer.has(n) or _a_preparer.size() >= 16:
					continue
				if _prets.has(n.get_instance_id()):
					# (2026-10-28) un corps « prêt » peut montrer de nouvelles pièces (gardien réveillé : arme, bouclier, casque) :
					# un seul revérifié par passage (tour à tour), sinon ses maillages étaient lus PENDANT le 1er sort
					# (repli en capsules, images de 5 à 9 ms) et sa préchauffe venait après
					if not deja.has(n) and (cam == null or (n as Node3D).global_position.distance_to(cam.global_position) <= 30.0):
						deja.append(n)
					continue
				if cam != null and (n as Node3D).global_position.distance_to(cam.global_position) > 30.0:
					continue
				if SurfaceCorps.pret(n):
					_prets[n.get_instance_id()] = true
					_surfaces[n.get_instance_id()] = SurfaceCorps.de(n, false, false)
					_nettoyer_surfaces()
					_mettre_a_chauffer(n)
				else:
					_a_preparer.append(n)
		if not deja.is_empty():
			var n: Node3D = deja[_reverif_i % deja.size()]
			if not SurfaceCorps.pret(n):
				_prets.erase(n.get_instance_id())
				_a_preparer.append(n)
				if trace:
					print("ImpactCorps : nouvelles pièces sur %s, relues avant le sort" % n.name)
	# lecture d'un maillage = lecture du GPU (synchronisation) : jamais pendant un sort en cours, au plus une toutes les
	# 0,2 s ; les ennemis sont lus quand ils approchent (≤ 30 m), en général bien avant le premier sort
	_attente -= dt
	if not gm._jets.is_empty() or not gm._projectiles.is_empty():
		return
	if _chauffe == null and not _a_chauffer.is_empty():
		_chauffer_suivant()
	if _eclaire == null and _chauffe == null and not _a_eclairer.is_empty():
		_eclairer_suivant()
	if _attente > 0.0:
		return
	while not _a_preparer.is_empty():
		var c: Variant = _a_preparer[0]
		if not is_instance_valid(c) or not (c as Node).is_inside_tree():
			_a_preparer.pop_front()
			continue
		var t0 := Time.get_ticks_usec()
		if SurfaceCorps.preparer_un(c):
			_attente = 0.2
			if trace:
				print("ImpactCorps : maillage lu pour %s en %.1f ms" % [(c as Node).name, (Time.get_ticks_usec() - t0) / 1000.0])
			return
		_a_preparer.pop_front()
		_prets[(c as Node).get_instance_id()] = true
		_surfaces[(c as Node).get_instance_id()] = SurfaceCorps.de(c, false, false)
		_nettoyer_surfaces()
		_mettre_a_chauffer(c)
		# foyer en cours sur le repli : on refait sa surface avec les vrais points
		for f: Foyer in foyers:
			if not f.libre and f.cible == c and f.surface != null and f.surface.repli():
				var s := SurfaceCorps.de(c)
				if s != null:
					f.surface.lacher()
					f.surface = s
		return

static func _cles_format(c: Node3D) -> PackedStringArray:
	var cles := PackedStringArray()
	for mi in SurfaceCorps.maillages(c):
		var am := mi.mesh as ArrayMesh   # surface_get_format : ArrayMesh seulement (pas les maillages primitifs)
		if am == null:
			continue
		for i in mini(am.get_surface_count(), 4):
			var cle := "%d|%s" % [am.surface_get_format(i), mi.skin != null]
			if not _formats_chauds.has(cle) and not cles.has(cle):
				cles.append(cle)
	return cles

func _mettre_a_chauffer(c: Variant) -> void:
	if chauffe_corps and _a_eclairer.size() < 32 and not _a_eclairer.has(c):
		_a_eclairer.append(c)
	if chauffe_corps and actif and _a_chauffer.size() < 16 and not _a_chauffer.has(c) and not _cles_format(c).is_empty():
		_a_chauffer.append(c)

## Préchauffe à blanc du premier corps de la file qui est à l'écran (les autres attendent d'y être).
func _chauffer_suivant() -> void:
	var cam := get_viewport().get_camera_3d()
	var i := 0
	while i < _a_chauffer.size():
		var c: Variant = _a_chauffer[i]
		if not is_instance_valid(c) or not (c as Node).is_inside_tree() or _cles_format(c).is_empty():
			_a_chauffer.remove_at(i)
			continue
		var pos := (c as Node3D).global_position + Vector3.UP
		if cam != null and (not cam.is_position_in_frustum(pos) or pos.distance_to(cam.global_position) > 30.0):
			i += 1
			continue
		var x: Foyer = null
		for f: Foyer in foyers:
			if f.libre and gm.horloge >= f.fin_particules:
				x = f
				break
		if x == null:
			return
		_a_chauffer.remove_at(i)
		for cle in _cles_format(c):
			_formats_chauds[cle] = true
		x.cible = c
		x.avec_coque = true   # (électricité : pas de coque, mais la préchauffe passe toutes les coques) ; rétabli à la fin
		_voiler(x)   # voile et coques posés à intensité nulle (mc_feu = 0) : dessinés, donc pipelines compilés
		_chauffe = x
		_chauffe_mats = [mat_coque] + mat_coques.values()
		# arcs (électricité, filaments des ténèbres) : dessinés à opacité nulle près du corps, sous les mêmes lumières
		x.nb_segs = 0
		x.nb_segs_prec = MAX_SEGMENTS
		arcs_fin(x)
		x.arcs.global_position = x.origine()
		x.arcs.visible = true
		_a_eclairer.erase(c)   # ses lumières sont préchauffées avec le voile et chaque coque
		_chauffe_phase()
		if trace:
			print("ImpactCorps : préchauffe à blanc sur %s (%d maillages)" % [(c as Node).name, x.voiles.size()])
		return

## Préchauffe des lumières : premier corps de la file à l'écran et à portée de sort (≤ DIST_ECLAIRE m : les lumières
## doivent aussi toucher ce qui entoure le lanceur, ses mains, son arme).
const DIST_ECLAIRE := 12.0
func _eclairer_suivant() -> void:
	var cam := get_viewport().get_camera_3d()
	var i := 0
	while i < _a_eclairer.size():
		var c: Variant = _a_eclairer[i]
		if not is_instance_valid(c) or not (c as Node).is_inside_tree():
			_a_eclairer.remove_at(i)
			continue
		var pos := (c as Node3D).global_position + Vector3.UP
		if cam != null and (not cam.is_position_in_frustum(pos) or pos.distance_to(cam.global_position) > DIST_ECLAIRE):
			i += 1
			continue
		_a_eclairer.remove_at(i)
		_eclaire = c
		_eclaire_n = 0
		_eclairer_image()
		return

## Une image de la préchauffe des lumières : une lumière de plus (elles durent 0,12 s : 1, 2, 3 puis 4 ensemble), posées
## comme celles des sorts (au corps, puis vers le lanceur), énergie quasi nulle (invisible, mais le moteur la compte).
func _eclairer_image() -> void:
	if not is_instance_valid(_eclaire) or not _eclaire.is_inside_tree() or not gm._jets.is_empty() or not gm._projectiles.is_empty():
		_eclaire = null
		return
	var cam := get_viewport().get_camera_3d()
	var c := _eclaire.global_position + Vector3.UP * 1.1
	# (2026-10-28) du corps jusqu'aux mains du lanceur (la 4e à 0,5 m de la caméra) : les lumières des sorts touchent aussi
	# ses bras, son arme et le sol entre eux (avant : au plus 1,8 m devant le corps)
	var vers := cam.global_position - c if cam != null else Vector3.BACK * 2.0
	var pas := maxf(vers.length() - 0.5, 0.6) / float(ECLAIRE_IMAGES - 1)
	gm.lumiere("chauffe_lum%d" % _eclaire_n, c + vers.normalized() * (pas * _eclaire_n), GestionMagie.LUMIERE.feu, 0.002, 5.0, 0.01, 0.12)
	if gm.couche != null:
		gm.couche.demander()
	if trace and _eclaire_n == 0:
		print("ImpactCorps : préchauffe des lumières sur %s" % _eclaire.name)
	_eclaire_n += 1
	if _eclaire_n >= ECLAIRE_IMAGES:
		_eclaire = null

## Phase suivante de la préchauffe à blanc : coques du corps sur le matériau suivant, lumières de 1 à 4.
func _chauffe_phase() -> void:
	var m: Material = _chauffe_mats.pop_front()
	for c: MeshInstance3D in _chauffe.coques:
		if c.material_override != m:
			c.material_override = m
	_chauffe_n = CHAUFFE_IMAGES
	_eclaire = _chauffe.cible   # lumières : une de plus par image (_preparer), après l'extinction de celles de la phase d'avant
	_eclaire_n = 0
	if gm.couche != null:
		gm.couche.demander()

func _finir_chauffe() -> void:
	if _chauffe == null:
		return
	_chauffe_mats.clear()
	_chauffe.arcs.visible = false
	_devoiler(_chauffe)
	_chauffe.cible = null
	# matériau de coque et avec_coque de l'école du foyer rétablis (foyer jamais servi : école vide, coque du feu)
	var mc: Variant = mat_coques.get(_chauffe.ecole)
	_chauffe.avec_coque = _chauffe.ecole == "feu" or mc != null
	var m: Material = mc if mc != null else mat_coque
	for c: MeshInstance3D in _chauffe.coques:
		if c.material_override != m:
			c.material_override = m
	_chauffe = null

## Surfaces préparées des cibles disparues : libérées.
func _nettoyer_surfaces() -> void:
	if _surfaces.size() < 48:
		return
	for id in _surfaces.keys():
		var sc: SurfaceCorps = _surfaces[id]
		if sc == null or not is_instance_valid(sc.cible):
			_surfaces.erase(id)
			_prets.erase(id)

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
	var par := PackedFloat32Array()
	par.resize(SurfaceCorps.TEXELS_PARAMS * 4)
	par[2] = -1.0; par[3] = 1.0; par[5] = 1.0; par[7] = 0.5; par[8] = 1.0; par[10] = float(SurfaceCorps.LARGEUR)
	var octets := pts.to_byte_array()
	octets.append_array(par.to_byte_array())
	img.set_data(SurfaceCorps.TEXELS, 1, false, Image.FORMAT_RGBAF, octets)
	var tp := ImageTexture.create_from_image(img)
	octets = nrm.to_byte_array()
	octets.append_array(par.to_byte_array())
	img.set_data(SurfaceCorps.TEXELS, 1, false, Image.FORMAT_RGBAF, octets)
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
		# la vitrine n'est pas toujours dans l'arbre à cet instant (préchauffe du combat) : position locale, pas global_position
		var vd_pos := vd.global_position if vd.is_inside_tree() else (v.position + vd.position)
		var nc := 0
		# (la vitrine n'est pas encore dans l'arbre : pas de SurfaceCorps.maillages, qui exige is_visible_in_tree)
		for n in vd.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.visible or SurfaceCorps.IGNORES.has(String(mi.name)):
				continue
			if mi.material_overlay == null:
				mi.material_overlay = mat_voile
				mi.set_instance_shader_parameter("mc_feu", Vector4(vd_pos.x, 1.0, vd_pos.z, 1.0))
				mi.set_instance_shader_parameter("mc_ecoles", Vector4(0.6, 0.6, 0.6, 256.0 * 128.0 + 128.0))
				mi.set_instance_shader_parameter("mc_pt", Vector4(vd_pos.x, 1.0, vd_pos.z, 2.0))
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
				c.set_instance_shader_parameter("mc_pt", Vector4(vd_pos.x, 1.0, vd_pos.z, 2.0))
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
		# coque (couche fine) sur le même maillage
		var coque := MeshInstance3D.new()
		coque.mesh = boite
		coque.material_override = mat_coque
		coque.layers = CoucheMagie.CALQUE
		coque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		v.add_child(coque)
		coque.position = corps.position
		coque.set_instance_shader_parameter("mc_feu", Vector4(0, 0.5, 0.6, 1.0))
		coque.set_instance_shader_parameter("mc_autre", Vector4(0, 0, 0, 1.0))
