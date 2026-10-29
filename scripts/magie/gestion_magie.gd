class_name GestionMagie
extends Node3D
## Moteur des VISUELS de la magie (aucune logique de jeu) : un seul nœud « GestionMagie » par scène, créé à la demande par
## EffetsMagie (API publique : scripts/magie/effets_magie.gd ; doc : docs/MAGIE_EFFETS.md).
## Il possède :
##   - un pool d'émetteurs GPUParticles3D (particules = carrés de pixels, shaders/magie_part_*.gdshader), plafonné en
##     nombre d'émetteurs (MAX_EMETTEURS) et en particules vivantes (MAX_PARTICULES) ;
##   - un pool de MAX_LUMIERES OmniLight3D sans ombre, attribuées chaque image aux demandes les plus fortes ;
##   - les éclairs (traits pixel à largeur d'écran fixe, shaders/magie_trait.gdshader), plafonnés à MAX_ECLAIRS ;
##   - les cristaux (pics de nova, épines obscures) en MultiMesh (MAX_PICS par palette) ;
##   - les disques au sol (onde de choc, cercle runique, vortex), plafonnés à MAX_DISQUES ;
##   - l'état des effets persistants : auras des mains, jets canalisés, traînées des projectiles, statuts, enchantements,
##     zones, double incantation.
## Il tourne APRÈS les mains (process_priority) pour suivre le viewmodel sans retard d'une image.

const SH_ADD := preload("res://shaders/magie_part_add.gdshader")
const SH_MIX := preload("res://shaders/magie_part_mix.gdshader")
const SH_TRAIT := preload("res://shaders/magie_trait.gdshader")
const SH_CRISTAL := preload("res://shaders/magie_cristal.gdshader")
const SH_SOL := preload("res://shaders/magie_sol.gdshader")
const SH_SOL_MIX := preload("res://shaders/magie_sol_mix.gdshader")
const SH_VOILE := preload("res://shaders/magie_voile.gdshader")
const SH_TEINTE := preload("res://shaders/magie_teinte.gdshader")
const SH_COEUR := preload("res://shaders/magie_coeur.gdshader")
const SH_COEUR_ADD := preload("res://shaders/magie_coeur_add.gdshader")
const SH_FLUX := preload("res://shaders/magie_flux.gdshader")
const SH_AURA := preload("res://shaders/magie_aura.gdshader")
const SH_VAGUE := preload("res://shaders/magie_vague.gdshader")
const SH_VAGUE_PROC := preload("res://shaders/magie_vague_process.gdshader")
const SH_GIVRE := preload("res://shaders/magie_givre.gdshader")
const SH_GIVRE_PROC := preload("res://shaders/magie_givre_process.gdshader")
## Formes du souffle de givre : atlas 4×3 de 128² tiré du Kenney Particle Pack (CC0, outils/generer_atlas_givre.gd) :
## rangée 0 = volumes de souffle (smoke), rangée 1 = tourbillons (twirl) + brume, rangée 2 = scintillements (star).
const ATLAS_GIVRE := preload("res://assets/magie/givre_kenney_atlas.png")
## Formes des bouffées : atlas 4×3 de 128² tiré du Kenney Particle Pack (CC0, assets/LICENCES.md) : rangée 0 = volumes
## de flamme (flame_01-04), rangée 1 = fumée (smoke_03-06), rangée 2 = langues (flame_05-06), braises (fire_01), fumée.
## (Plus lu par la vague depuis le 2026-10-29 soir : le dessin est un champ de feu partagé, voir magie_vague.gdshader.)
const ATLAS_FEU := preload("res://assets/magie/feu_kenney_atlas.png")
## Bruit fractal périodique de la vague (64², 4 canaux indépendants ; outils/generer_bruit_vague.gd).
const BRUIT_VAGUE := preload("res://assets/magie/bruit_vague.png")
## Jet électrique (couche fine) : DÉCHARGE d'éclats texturés qui crépitent le long de l'arc (magie_decharge*.gdshader).
const SH_DECHARGE := preload("res://shaders/magie_decharge.gdshader")
const SH_DECHARGE_PROC := preload("res://shaders/magie_decharge_process.gdshader")
## Faisceau épais de l'arc électrique (couche fine) : corps d'un seul tenant, brins tressés et fourches (magie_faisceau).
const SH_FAISCEAU := preload("res://shaders/magie_faisceau.gdshader")
const FAISCEAU_SEG := 48
## Formes des éclats : atlas 4×2 de 128² tiré du Kenney Particle Pack (CC0, assets/LICENCES.md) : rangée 0 = traits
## d'éclair (spark_05, spark_06, spark_07 redressé, trace_03), rangée 1 = nuages d'éclairs (spark_01, 02, 04), éclat star_04.
const ATLAS_ELEC := preload("res://assets/magie/elec_kenney_atlas.png")
## Shaders des visuels qui passent dans la couche fine (CoucheMagie.CALQUE) ; le voile (material_overlay des cibles) reste
## dans le rendu du monde.
const SHADERS_COUCHE := [SH_ADD, SH_MIX, SH_TRAIT, SH_CRISTAL, SH_SOL, SH_SOL_MIX, SH_COEUR, SH_COEUR_ADD, SH_FLUX, SH_AURA, SH_VAGUE, SH_DECHARGE, SH_GIVRE, SH_FAISCEAU]
## Palettes du flux procédural des jets (couche fine) : cœur → bord (ténèbres : rehaut → cœur noir).
const FLUX := {
	"feu": ["#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f", "#5a1a1c"],
	"glace": ["#ffffff", "#e8f6ff", "#a8d8f8", "#5f9fe8", "#2f5fb8", "#1b2c5a"],
	"tenebres": ["#ffe8ff", "#d08aff", "#9a3ae0", "#5a1a8a", "#2a0e3e", "#0c0614"],
	"soin": ["#fffbe8", "#fff4c0", "#f0d070", "#b8d060", "#5f9a3a", "#3a5a1a"],
}
## Palettes des auras / boules procédurales (couche fine), même ordre.
const AURA_PAL := {
	"feu": ["#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f", "#5a1a1c"],
	"glace": ["#ffffff", "#e8f6ff", "#a8d8f8", "#5f9fe8", "#2f5fb8", "#1b2c5a"],
	"electricite": ["#ffffff", "#f0f2ff", "#b4c0ff", "#7a7af0", "#4a3ad0", "#2a1a6a"],
	"tenebres": ["#ffe8ff", "#f0d0ff", "#d08aff", "#9a3ae0", "#5a1a8a", "#06030c"],
	"soin": ["#fffbe8", "#fff4c0", "#f0d070", "#b8d060", "#5f9a3a", "#3a5a1a"],
	"protection": ["#ffffff", "#eaf8ff", "#b8e0f0", "#7ab0d8", "#3a6a9a", "#1a3050"],
}
## Jet de flammes (couche fine) : VAGUE de bouffées qui avancent réellement dans l'espace (magie_vague*.gdshader).
## Portée visuelle en champ libre (m), durée de vie d'une bouffée (s), freinage (1/s), bouffées vivantes.
const VAGUE_PORTEE := 10.5
const VAGUE_VIE := 1.15
const VAGUE_TRAINE := 1.25
const VAGUE_N := 88
## Amorce du jet de flammes (s) : à sa création, la vague est simulée d'avance sur cette durée (GPUParticles3D.preprocess),
## le jet est donc PLEIN dès sa première image (avant : ~0,2 s de trou, les premières bouffées sortaient de la paume).
const VAGUE_AMORCE := 0.45
## Décharge électrique : éclats vivants (3 à 5 images chacun) et durée de vie d'un éclat (s).
const DECHARGE_N := 64
const DECHARGE_VIE := 0.13
## Jet de glace (couche fine) : SOUFFLE DE GIVRE, mêmes principes que la vague (magie_givre*.gdshader) : bouffées de
## souffle qui roulent et cristaux qui tournoient puis s'accrochent au point touché. Portée (m), vie (s), freinage (1/s),
## particules vivantes (dont GIVRE_CRISTAUX de cristaux).
const GIVRE_PORTEE := 8.5
const GIVRE_VIE := 1.05
const GIVRE_TRAINE := 1.5
const GIVRE_N := 120
const GIVRE_CRISTAUX := 0.25
## Palette du souffle : cœur blanc → cyan → bleu profond.
const GIVRE_PAL := ["#ffffff", "#e4f8ff", "#9fe2ff", "#4fa6e8", "#2a5cc0", "#172a66"]
## Couches de particules qui accompagnent le souffle de givre (poudre scintillante, éclats de cristal 3D, foyer de la paume).
const GIVRE_COMPAGNONS := ["glace_fin_jet_poudre", "glace_fin_jet_cristaux", "glace_paume"]
const AURA_ECOLE := {"feu": 0, "glace": 1, "electricite": 2, "tenebres": 3, "soin": 4, "protection": 5}
## Rayon (m) de la boule de feu tenue au creux de la main (cœur de l'aura de feu).
const AURA_BOULE := 0.095
## Tenue « runes » (main gantée agrandie, MainSort.ECHELLE_MAIN_TENUE) : la boule tenue grandit d'autant.
const BOULE_TENUE := 0.8
## Calque de rendu 18 des avant-bras FPS (= AvantBras.CALQUE, branche fps/avant_bras_*) : la lumière des auras ne l'éclaire
## pas (gants brûlés en orange) ; valeur recopiée ici pour ne pas dépendre de la classe tant que le rig n'est pas fusionné.
const CALQUE_AVANT_BRAS := 1 << 17
## Rayon (m) de l'aura procédurale de la main, par école (paume à ~0,45 m de l'œil).
const AURA_RAYON := {"feu": 0.12, "glace": 0.12, "electricite": 0.11, "tenebres": 0.12, "soin": 0.09, "protection": 0.09}

const MAX_PARTICULES := 3000
const MAX_EMETTEURS := 64
## Couche fine (détail des sorts Moyen / Élevé) : particules plus petites et plus nombreuses, couches en plus
## (PresetsMagie.FIN) ; plafonds relevés en conséquence (coût mesuré : docs/MAGIE_EFFETS.md).
const MAX_PARTICULES_FIN := 4500
const MAX_EMETTEURS_FIN := 110
const MAX_LUMIERES := 4
const MAX_ECLAIRS := 20
const MAX_PICS := 48
const MAX_DISQUES := 16
const MAX_STATUTS := 12
const MAX_PROJECTILES := 24
const POOL_GARDE := 24
## Échelle de départ d'un projectile cristal (il naît petit dans la paume, voir _cristal_echelle).
const CRISTAL_GERME := 0.12
## Distance à l'œil (m) à partir de laquelle un cristal lancé par le joueur a sa pleine taille (_cristal_echelle).
const CRISTAL_OEIL := 2.8

## Couleurs des lumières dynamiques par école.
const LUMIERE := {
	"feu": Color(1.0, 0.55, 0.2), "glace": Color(0.45, 0.7, 1.0), "electricite": Color(0.55, 0.5, 1.0),
	"tenebres": Color(0.62, 0.25, 1.0), "soin": Color(1.0, 0.85, 0.45), "protection": Color(0.6, 0.8, 1.0),
}
## Palettes des cristaux : ombre, milieu, clair, reflet.
const CRISTAUX := {
	"glace": ["#1b2c5a", "#2f5fb8", "#7ab8f0", "#e8f6ff"],
	"tenebres": ["#0c0614", "#2a0e3e", "#5a1a8a", "#c070ff"],
	"corrompu": ["#1a0a30", "#3a2a7a", "#7a5ad0", "#e0b0ff"],
	"electricite": ["#2a1a6a", "#4a3ad0", "#9aa8ff", "#f0f2ff"],
	"feu": ["#5a1a1c", "#b3341f", "#fcb53a", "#fff0a8"],
	"soin": ["#3a5a1a", "#8ab040", "#f0d070", "#fff4c0"],
	"protection": ["#1a3050", "#3a6a9a", "#b8e0f0", "#eaf8ff"],
}
## Éclairs : [halo, cœur] par teinte.
const ARCS := {
	"electricite": ["#4a3ad0", "#f0f2ff"], "tenebres": ["#6a1aa0", "#f0c8ff"], "glace": ["#2f5fb8", "#e8f6ff"],
	"feu": ["#ec6a1f", "#fff0a8"], "drain": ["#7a1ad0", "#e8a8ff"], "soin": ["#8ab040", "#fff4c0"],
	"protection": ["#3a6a9a", "#eaf8ff"], "violet": ["#7a2ad0", "#f0d0ff"],
}

static var instance: GestionMagie

var horloge := 0.0
var rng := RandomNumberGenerator.new()
## Compteurs de refus (plafonds atteints), lus par les tests.
var refus := 0

var _libres: Array[GPUParticles3D] = []
var _emetteurs: Array = []        # {p, n, fin}
var _budget := 0
var _pms := {}
var _mats := {}
var _quad := QuadMesh.new()
var _mesh_eclat: ArrayMesh
var _mesh_pic: ArrayMesh
var _mesh_flux: ArrayMesh
var _mesh_faisceau: ArrayMesh
var _bouffees: Array = []         # {mi, t0, duree, r0, r1, f0} : boules procédurales qui grossissent et s'éteignent
var _lumieres: Array[OmniLight3D] = []
var _demandes := {}               # cle -> {pos, noeud, couleur, energie, portee, prio, debut, fin, duree}
var _eclairs: Array = []          # {mi, im, fin, regen, prochain, gen, alpha}
var _libres_eclairs: Array[MeshInstance3D] = []
var _pics: Array = []             # {pal, pos, base, l, h, t0, monte, fin}
var _mm := {}                     # pal -> MultiMeshInstance3D
var _disques: Array = []          # {mi, mat, t0, duree, r0, r1, op, suivre}
var _auras := {}
## Échelle des auras par main (id du nœud porteur -> facteur) : la tenue « runes » des avant-bras (MainSort) resserre les
## flammes autour de la boule tenue, comme sur les références (bras_feu_1100.jpg) ; 1 par défaut.
var echelles_aura := {}
var _jets := {}
var _projectiles: Array = []
var _statuts := {}
var _enchants := {}
var _zones: Array = []
var _double := {}
var _double_vis := {}
var _sphere: SphereMesh
var _plan := PlaneMesh.new()
var _quad_sol := QuadMesh.new()
var _teinte_calque: CanvasLayer
var _teinte_mat: ShaderMaterial
var _teinte_v := 0.0
var _teinte_cible := 0.0
var _teinte_c := Color.BLACK
var _soleil: DirectionalLight3D = null   # lumière directionnelle de la scène (_jour)
var _soleil_cherche := -10.0
## Couche fine (option « Détail des sorts ») : null en rétro / sans fenêtre.
var couche: CoucheMagie
## Vrai quand la couche fine dessine les sorts : réglages PresetsMagie.FIN (lu à chaque émission).
var fin_actif := false
var _sans_suite := false
## Mise au point (galerie --sans-particules) : émetteurs cachés, pour juger flux, arcs et cristaux seuls.
static var masquer_particules := false
## Mise au point (galerie --sans-procedural) : couche fine sans flux ni auras procédurales (mesure de leur coût).
static var sans_procedural := false
## Tests sans fenêtre (outils/test_effets_magie.gd) : réglages de la couche fine même sans couche (pas de rendu headless).
static var forcer_fin := false
var _proc: Array = []             # visuels procéduraux de la couche fine (flux, auras, boules) : comptés par stats()

# ====================================================================== cycle de vie

static func obtenir() -> GestionMagie:
	if instance != null and is_instance_valid(instance) and not instance.is_queued_for_deletion():
		return instance
	var arbre := Engine.get_main_loop() as SceneTree
	var g := GestionMagie.new()
	g.name = "GestionMagie"
	instance = g
	if arbre != null:
		var s: Node = arbre.current_scene if arbre.current_scene != null else arbre.root
		if s.is_node_ready():
			s.add_child(g)
		else:
			s.add_child.call_deferred(g)
	return g

func _init() -> void:
	process_priority = 100
	if CoucheMagie.possible():
		couche = CoucheMagie.new()
		couche.name = "Couche"
		add_child(couche)
	rng.randomize()
	_quad.size = Vector2.ONE
	_plan.size = Vector2(2, 2)
	_quad_sol.size = Vector2(2, 2)
	_sphere = SphereMesh.new()
	_sphere.radius = 0.5
	_sphere.height = 1.0
	_sphere.radial_segments = 8
	_sphere.rings = 4
	_mesh_eclat = _creer_eclat()
	_mesh_pic = _creer_pic()
	_mesh_flux = _creer_flux()
	for i in MAX_LUMIERES:
		var l := OmniLight3D.new()
		l.shadow_enabled = false
		l.visible = false
		l.light_specular = 0.2
		l.distance_fade_enabled = true
		l.distance_fade_begin = 25.0
		l.distance_fade_length = 10.0
		add_child(l)
		_lumieres.append(l)

func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(_noeud_ajoute):
		get_tree().node_added.connect(_noeud_ajoute)

func _exit_tree() -> void:
	if instance == self:
		instance = null
	if get_tree().node_added.is_connected(_noeud_ajoute):
		get_tree().node_added.disconnect(_noeud_ajoute)

## Tout visuel de la magie (où qu'il soit accroché : main, cible, projectile) passe sur le calque de la couche fine.
func _noeud_ajoute(n: Node) -> void:
	var g := n as GeometryInstance3D
	if g == null:
		return
	var mo := g.material_override as ShaderMaterial
	if mo != null and SHADERS_COUCHE.has(mo.shader):
		g.layers = CoucheMagie.CALQUE

## Détail des sorts : rétro (0), moyen (1), élevé (2) ; utilisé par le menu des options.
static func regler_detail(niveau: int) -> void:
	if instance != null and is_instance_valid(instance) and instance.couche != null:
		instance.couche.regler(niveau)
		instance._pms.clear()

func _process(dt: float) -> void:
	horloge += dt
	fin_actif = forcer_fin or (couche != null and couche.fine())
	_maj_auras()
	_maj_jets()
	_maj_projectiles()
	_maj_statuts()
	_maj_enchants()
	_maj_zones()
	_maj_double()
	_maj_eclairs()
	_maj_pics()
	_maj_disques()
	_maj_bouffees()
	_maj_emetteurs()
	_maj_lumieres()
	_maj_teinte(dt)
	if couche != null and (not _emetteurs.is_empty() or not _eclairs.is_empty() or not _pics.is_empty() or not _disques.is_empty() or not _projectiles.is_empty() or not _auras.is_empty() or not _bouffees.is_empty() or not _jets.is_empty()):
		couche.demander()

## Compteurs (tests, débogage).
func stats() -> Dictionary:
	var lum := 0
	for l in _lumieres:
		if l.visible:
			lum += 1
	return {"emetteurs": _emetteurs.size(), "particules": _budget, "lumieres": lum, "demandes_lumiere": _demandes.size(),
		"eclairs": _eclairs.size(), "pics": _pics.size(), "disques": _disques.size(), "statuts": _statuts.size(),
		"auras": _auras.size(), "jets": _jets.size(), "projectiles": _projectiles.size(), "enchants": _enchants.size(),
		"zones": _zones.size(), "refus": refus, "pool": _libres.size(), "proceduraux": _compter_proc(), "bouffees": _bouffees.size()}

func _compter_proc() -> int:
	var n := 0
	var vivants: Array = []
	for x in _proc:
		if is_instance_valid(x) and not (x as Node).is_queued_for_deletion():
			vivants.append(x)
			n += 1
	_proc = vivants
	return n

## Éteint tout (changement de scène, tests).
func tout_arreter() -> void:
	ImpactCorps.arreter_tout()   # feu (et autres écoles) sur les corps : scripts/magie/impact_corps.gd
	for a in _auras.values():
		_aura_eteindre(a)
	_auras.clear()
	for j in _jets.values():
		_jet_arreter(j)
	_jets.clear()
	for k in _statuts.keys():
		_statut_retirer(k)
	for k in _enchants.keys():
		_enchant_retirer(k)
	_zones.clear()
	_double.clear()
	_maj_double()
	for e in _emetteurs:
		if is_instance_valid(e.p):
			e.p.emitting = false
		e.fin = minf(e.fin, horloge)
	for e in _eclairs:
		e.fin = horloge
	_pics.clear()
	for d in _disques:
		d.duree = 0.0
	for b in _bouffees:
		b.duree = 0.0
	_demandes.clear()

# ====================================================================== émetteurs de particules

func _nouveau_part() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.fixed_fps = 0
	p.interpolate = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.draw_pass_1 = _quad
	return p

## Lance un émetteur du réglage `nom` (PresetsMagie.R) sous `parent` (null = ce nœud, repère du monde) avec le repère
## local `xf`. Persistant : émet jusqu'à arreter(). Renvoie null si un plafond est atteint.
func emettre(nom: String, parent: Node, xf: Transform3D, persistant := false, k_n := 1.0, vie := -1.0, pm_perso: ParticleProcessMaterial = null) -> GPUParticles3D:
	var d: Dictionary = PresetsMagie.R.get(nom, {})
	if d.is_empty():
		push_warning("EffetsMagie : réglage inconnu « %s »" % nom)
		return null
	fin_actif = forcer_fin or (couche != null and couche.fine())
	var f: Dictionary = PresetsMagie.fin(nom) if fin_actif else {}
	var n := maxi(1, int(round(float(d.n) * k_n * float(f.get("n", 1.0)))))
	if _emetteurs.size() >= (MAX_EMETTEURS_FIN if fin_actif else MAX_EMETTEURS):
		if persistant or not _liberer_ponctuel():
			refus += 1
			return null
	var reste := (MAX_PARTICULES_FIN if fin_actif else MAX_PARTICULES) - _budget
	if n > reste:
		n = reste
		if n < (2 if persistant else 4):
			refus += 1
			return null
	var p: GPUParticles3D = _libres.pop_back() if not _libres.is_empty() else _nouveau_part()
	p.amount = n
	p.lifetime = vie if vie > 0.0 else float(d.vie)
	p.one_shot = not persistant
	p.explosiveness = float(d.get("expl", 0.0))
	p.randomness = float(d.get("alea", 0.25))
	p.local_coords = bool(d.get("local", false))
	p.amount_ratio = 1.0
	p.speed_scale = 1.0
	p.process_material = pm_perso if pm_perso != null else _pm(nom, d)
	if String(d.get("mesh", "quad")) == "eclat":
		p.draw_pass_1 = _mesh_eclat
		p.material_override = _mat_cristal(String(d.get("pal", "glace")))
	else:
		p.draw_pass_1 = _quad
		var gros: Vector2 = f.get("gros", Vector2.ZERO)
		p.material_override = _mat_part(bool(d.get("add", false)), float(d.get("cap", 6.0)), float(d.get("eclat", 1.3)),
			0.0 if gros != Vector2.ZERO else _etire(nom, d), gros)
	# les couches additives (cœurs, étincelles) passent par-dessus les corps opaques du même effet
	p.sorting_offset = 0.5 if bool(d.get("add", false)) else 0.0
	var ext := 2.0 if p.local_coords else 14.0
	p.visibility_aabb = AABB(Vector3.ONE * -ext, Vector3.ONE * ext * 2.0)
	var cible: Node = parent if parent != null else self
	if p.get_parent() != cible:
		if p.get_parent() != null:
			p.get_parent().remove_child(p)
		cible.add_child(p)
	p.transform = xf
	p.visible = not masquer_particules
	p.restart()
	p.emitting = true
	var t_fin := INF if persistant else horloge + p.lifetime * (1.0 + p.randomness) + 0.25
	var e := {"p": p, "n": n, "fin": t_fin, "suite": []}
	_emetteurs.append(e)
	_budget += n
	# couche fine : couches compagnes (étincelles, filaments, poudre…) qui suivent cet émetteur (_maj_emetteurs)
	if fin_actif and not _sans_suite and f.has("avec"):
		_sans_suite = true
		for nc: String in f.avec:
			var dc: Dictionary = PresetsMagie.R.get(nc, {})
			if dc.is_empty():
				continue
			var ratio := float(dc.vie) / maxf(float(d.vie), 0.01)
			var vc := (vie * ratio) if vie > 0.0 else -1.0
			# palier « gros pixels » : les couches compagnes (étincelles, poudre) aussi GROS_DIVISE fois moins nombreuses
			var kc := k_n / PresetsMagie.GROS_DIVISE if f.has("gros") else k_n
			var pc := emettre(nc, cible, xf, persistant, kc, vc, _pm_compagnon(nc, dc, p.process_material as ParticleProcessMaterial, d))
			if pc != null:
				e.suite.append({"p": pc, "ratio": ratio})
		_sans_suite = false
	return p

## Matériau d'une couche compagne : même forme d'émission que l'émetteur suivi (boîte d'une cible, rayon d'une zone,
## cône d'un jet), le reste vient de son propre réglage.
func _pm_compagnon(nom: String, dc: Dictionary, pm: ParticleProcessMaterial, d: Dictionary) -> ParticleProcessMaterial:
	var sur := {}
	if pm == null:
		return _pm(nom, dc)
	if not dc.has("forme") or bool(dc.get("herite", false)):
		match pm.emission_shape:
			ParticleProcessMaterial.EMISSION_SHAPE_BOX:
				sur.forme = "boite"
				var x := pm.emission_box_extents
				sur.ext = Vector3(snappedf(x.x, 0.01), snappedf(x.y, 0.01), snappedf(x.z, 0.01))
			ParticleProcessMaterial.EMISSION_SHAPE_SPHERE:
				sur.forme = "sphere"
				sur.r = snappedf(pm.emission_sphere_radius, 0.01)
			ParticleProcessMaterial.EMISSION_SHAPE_RING:
				sur.forme = "disque" if pm.emission_ring_inner_radius <= 0.0 else "anneau"
				sur.r = snappedf(pm.emission_ring_radius, 0.05)
	elif String(dc.forme) == String(d.get("forme", "")) and dc.has("r") and pm.emission_shape != ParticleProcessMaterial.EMISSION_SHAPE_BOX:
		var r0 := float(d.get("r", 0.0))
		var rp := pm.emission_ring_radius if pm.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_RING else pm.emission_sphere_radius
		if r0 > 0.0 and absf(rp - r0) > 0.01:
			sur.r = snappedf(float(dc.r) * rp / r0, 0.05)
	if dc.has("ecart") and d.has("ecart") and float(d.ecart) > 0.0 and absf(pm.spread - float(d.ecart)) > 0.5:
		sur.ecart = snappedf(float(dc.ecart) * pm.spread / float(d.ecart), 0.5)
	return _pm(nom, dc, sur)

## Arrête un émetteur persistant : ses particules finissent leur vie, puis il retourne au pool.
func arreter(p: Variant) -> void:
	if p == null or not is_instance_valid(p):
		return   # un émetteur libéré avec son parent est retiré par _maj_emetteurs
	if not (p is GPUParticles3D):
		(p as Node).queue_free()   # visuel procédural de la couche fine (gerbe), sans particules à laisser finir
		return
	var g := p as GPUParticles3D
	for e in _emetteurs:
		if is_instance_valid(e.p) and e.p == g:
			g.emitting = false
			e.fin = minf(e.fin, horloge + g.lifetime * (1.0 + g.randomness) + 0.1)
			for sc in e.suite:
				arreter(sc.p)
			return

func _liberer_ponctuel() -> bool:
	# plafond d'émetteurs : le plus ancien ponctuel cède sa place
	var meilleur := -1
	for i in _emetteurs.size():
		if _emetteurs[i].fin < INF and (meilleur < 0 or _emetteurs[i].fin < _emetteurs[meilleur].fin):
			meilleur = i
	if meilleur < 0:
		return false
	_rendre(meilleur)
	return true

func _rendre(i: int) -> void:
	var e: Dictionary = _emetteurs[i]
	_emetteurs.remove_at(i)
	_budget -= int(e.n)
	for sc in e.suite:
		arreter(sc.p)
	if not is_instance_valid(e.p) or (e.p as Node).is_queued_for_deletion():
		return
	var p: GPUParticles3D = e.p
	p.emitting = false
	p.visible = false
	if p.get_parent() != self:
		if p.get_parent() != null:
			p.get_parent().remove_child(p)
		add_child(p)
	if _libres.size() < POOL_GARDE:
		_libres.append(p)
	else:
		p.queue_free()

func _maj_emetteurs() -> void:
	# couches compagnes : même repère, même émission et même durée de vie relative que l'émetteur suivi
	for e in _emetteurs:
		if e.suite.is_empty() or not is_instance_valid(e.p):
			continue
		var p: GPUParticles3D = e.p
		for sc in e.suite:
			var c: Variant = sc.p
			if not is_instance_valid(c) or (c as Node).get_parent() != p.get_parent():
				continue
			var g := c as GPUParticles3D
			g.transform = p.transform
			if g.emitting != p.emitting:
				g.emitting = p.emitting
			g.amount_ratio = p.amount_ratio
			var vie := p.lifetime * float(sc.ratio)
			if absf(g.lifetime - vie) > vie * 0.18:
				g.lifetime = vie
	var i := _emetteurs.size() - 1
	while i >= 0:
		var e: Dictionary = _emetteurs[i]
		if horloge >= e.fin or not is_instance_valid(e.p) or not (e.p as Node).is_inside_tree() and e.fin < INF:
			_rendre(i)
		i -= 1

## ParticleProcessMaterial partagé d'un réglage (cache) ; `r` (rayon) / `ext` (boîte) / `ecart` surchargent le réglage
## (copie mise en cache par valeur arrondie).
func _pm(nom: String, d: Dictionary, sur := {}) -> ParticleProcessMaterial:
	fin_actif = forcer_fin or (couche != null and couche.fine())
	var cle := nom
	for k in sur:
		cle += "|%s=%s" % [k, str(sur[k])]
	if fin_actif:
		cle += "#fin"
	if _pms.has(cle):
		return _pms[cle]
	var dd := d.duplicate()
	dd.merge(sur, true)
	if fin_actif:
		# couche fine : particules plus petites (elles sont plus nombreuses, voir emettre)
		var f: Dictionary = PresetsMagie.fin(nom)
		dd.taille = (dd.get("taille", Vector2(0.03, 0.05)) as Vector2) * float(f.get("t", 1.0))
		for k in f.get("sur", {}):
			dd[k] = f.sur[k]
		if f.has("etire"):
			dd.etire = f.etire
		if f.has("gros") and PresetsMagie.GROS.has(nom):
			# palier « gros pixels » (PresetsMagie.GROS) : carrés plus gros qui rétrécissent, cœur clair puis ton de l'école
			dd.taille = PresetsMagie.GROS[nom].taille
			dd.courbe = "descend"
			dd.rampe = PresetsMagie.rampe_gros(nom)
			dd.erase("etire")
	var pm := ParticleProcessMaterial.new()
	pm.direction = dd.get("dir", Vector3.UP)
	pm.spread = float(dd.get("ecart", 0.0))
	var v: Vector2 = dd.get("vit", Vector2.ZERO)
	pm.initial_velocity_min = v.x
	pm.initial_velocity_max = v.y
	pm.gravity = dd.get("grav", Vector3.ZERO)
	var am: Vector2 = dd.get("amort", Vector2.ZERO)
	pm.damping_min = am.x
	pm.damping_max = am.y
	var ra: Vector2 = dd.get("radial", Vector2.ZERO)
	pm.radial_accel_min = ra.x
	pm.radial_accel_max = ra.y
	var rv: Vector2 = dd.get("radiale_v", Vector2.ZERO)
	pm.radial_velocity_min = rv.x
	pm.radial_velocity_max = rv.y
	var t: Vector2 = dd.get("taille", Vector2(0.03, 0.05))
	pm.scale_min = t.x
	pm.scale_max = t.y
	var courbe := String(dd.get("courbe", "plat"))
	if courbe != "plat":
		var c := Curve.new()
		match courbe:
			"monte":
				c.add_point(Vector2(0, 0.35))
				c.add_point(Vector2(1, 1.0))
			"descend":
				c.add_point(Vector2(0, 1.0))
				c.add_point(Vector2(1, 0.2))
			"bosse":
				c.add_point(Vector2(0, 0.3))
				c.add_point(Vector2(0.35, 1.0))
				c.add_point(Vector2(1, 0.45))
		var ct := CurveTexture.new()
		ct.curve = c
		pm.scale_curve = ct
	var r := float(dd.get("r", 0.0))
	match String(dd.get("forme", "point")):
		"sphere":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = r
		"surface":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
			pm.emission_sphere_radius = r
		"boite":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = dd.get("ext", Vector3(0.25, 0.8, 0.25))
		"anneau":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			pm.emission_ring_axis = dd.get("axe", Vector3.UP)
			pm.emission_ring_radius = r
			pm.emission_ring_inner_radius = r * 0.92
			pm.emission_ring_height = 0.02
		"disque":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			pm.emission_ring_axis = Vector3.UP
			pm.emission_ring_radius = r
			pm.emission_ring_inner_radius = 0.0
			pm.emission_ring_height = 0.05
	pm.particle_flag_align_y = String(dd.get("mesh", "quad")) == "eclat" or float(dd.get("etire", 0.0)) > 0.0
	if dd.has("turb"):
		# turbulence (bruit GPU) : flammes et fumées qui ondulent au lieu de filer droit
		var tu: Vector2 = dd.turb
		pm.turbulence_enabled = true
		pm.turbulence_influence_min = tu.x
		pm.turbulence_influence_max = tu.y
		pm.turbulence_noise_scale = float(dd.get("turb_echelle", 2.0))
		pm.turbulence_noise_strength = float(dd.get("turb_force", 1.0))
		pm.turbulence_noise_speed = Vector3(0, 0.6, 0)
	if dd.has("rampe"):
		# gros pixels : paliers francs de la rampe, sans palier intermédiaire de la couche fine (pas de cœur délavé)
		pm.color_ramp = _rampe(dd.rampe, bool(dd.get("garde_fin", false)), fin_actif and not PresetsMagie.fin(nom).has("gros"))
	_pms[cle] = pm
	return pm

## Rampe EN PALIERS (interpolation constante) : quelques couleurs franches, puis un palier transparent.
static func _rampe(couleurs: Array, garde_fin: bool, fine := false) -> GradientTexture1D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var cs: Array[Color] = []
	for i in couleurs.size():
		var c: Color = Color(couleurs[i]) if couleurs[i] is String else couleurs[i]
		# couche fine : un palier intermédiaire entre deux couleurs (dégradé plus riche, toujours en paliers francs)
		if fine and i > 0:
			cs.append(cs[cs.size() - 1].lerp(c, 0.5))
		cs.append(c)
	if not garde_fin:
		var der := cs[cs.size() - 1]
		cs.append(Color(der, 0.0))
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in cs.size():
		offs.append(float(i) / float(cs.size()))
		cols.append(cs[i])
	g.offsets = offs
	g.colors = cols
	var gt := GradientTexture1D.new()
	gt.gradient = g
	gt.width = 64
	return gt

## Étirement (traînée) d'un réglage : clé « etire », en couche fine seulement (le rendu rétro reste en carrés).
func _etire(nom: String, d: Dictionary) -> float:
	if not fin_actif:
		return 0.0
	var f: Dictionary = PresetsMagie.fin(nom)
	return float(f.get("etire", d.get("etire", 0.0)))

## `gros` : palier « gros pixels » (PresetsMagie.GROS, taille min / max en pixels du monde) ; nul = particule ordinaire.
func _mat_part(add: bool, cap: float, eclat: float, etire := 0.0, gros := Vector2.ZERO) -> ShaderMaterial:
	var cle := "p%s|%s|%s|%s|%s" % [add, cap, eclat, etire, gros]
	if not _mats.has(cle):
		var m := ShaderMaterial.new()
		m.shader = SH_ADD if add else SH_MIX
		m.set_shader_parameter("taille_max", cap)
		m.set_shader_parameter("eclat", eclat)
		m.set_shader_parameter("etire", etire)
		m.set_shader_parameter("gros_px", gros)
		_mats[cle] = m
	return _mats[cle]

func _mat_cristal(pal: String, multimesh := false) -> ShaderMaterial:
	var cle := "c%s|%s" % [pal, multimesh]
	if not _mats.has(cle):
		var m := ShaderMaterial.new()
		m.shader = SH_CRISTAL
		var c: Array = CRISTAUX.get(pal, CRISTAUX.glace)
		m.set_shader_parameter("c_ombre", Color(c[0]))
		m.set_shader_parameter("c_milieu", Color(c[1]))
		m.set_shader_parameter("c_clair", Color(c[2]))
		m.set_shader_parameter("c_reflet", Color(c[3]))
		m.set_shader_parameter("eclat", 1.15)
		m.set_shader_parameter("multimesh", multimesh)
		_mats[cle] = m
	return _mats[cle]

func _mat_coeur(couleur: Color, add := true, eclat := 1.5) -> Material:
	# matériau « particule » réutilisé pour les cœurs pleins (sphères lumineuses des projectiles)
	var cle := "s%s|%s|%s" % [couleur.to_html(), add, eclat]
	if not _mats.has(cle):
		# shader (et non StandardMaterial3D) : occlusion de la couche fine, additif sans opacité (magie_coeur.gdshaderinc)
		var m := ShaderMaterial.new()
		m.shader = SH_COEUR_ADD if add else SH_COEUR
		var c := Color(couleur.r * eclat, couleur.g * eclat, couleur.b * eclat).srgb_to_linear()   # comme albedo_color
		m.set_shader_parameter("couleur", Color(c.r, c.g, c.b, couleur.a))
		_mats[cle] = m
	return _mats[cle]

# ====================================================================== lumières (pool)

## Demande de lumière : persistante (duree <= 0, à renouveler chaque image) ou éclair bref qui décroît (duree > 0).
## `masque` : calques éclairés (light_cull_mask) ; les auras des mains excluent les avant-bras FPS (CALQUE_AVANT_BRAS),
## éclairés par leur propre lueur, courte (RunesOrbite) : une lumière de 4 m posée DANS la paume les brûlait à blanc.
func lumiere(cle: String, pos: Vector3, couleur: Color, energie: float, portee: float, prio: float, duree := -1.0, masque := 0xFFFFF) -> void:
	var fin := horloge + (duree if duree > 0.0 else 0.12)
	_demandes[cle] = {"pos": pos, "couleur": couleur, "energie": energie, "portee": portee, "prio": prio,
		"debut": horloge, "fin": fin, "duree": duree, "masque": masque}

func _maj_lumieres() -> void:
	var liste: Array = []
	for cle in _demandes.keys():
		var d: Dictionary = _demandes[cle]
		if horloge > d.fin:
			_demandes.erase(cle)
			continue
		var e := float(d.energie)
		if d.duree > 0.0:
			var k := clampf((horloge - d.debut) / d.duree, 0.0, 1.0)
			e *= (1.0 - k) * (1.0 - k)
		liste.append([float(d.prio) * (0.5 + e), d, e])
	liste.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in MAX_LUMIERES:
		var l := _lumieres[i]
		if i < liste.size():
			var d: Dictionary = liste[i][1]
			l.visible = true
			l.position = d.pos
			l.light_color = d.couleur
			l.light_energy = liste[i][2]
			l.omni_range = d.portee
			l.light_cull_mask = int(d.get("masque", 0xFFFFF))
		else:
			l.visible = false

# ====================================================================== teinte d'écran (discrète, pendant les jets)

## Demande de teinte (à renouveler chaque image) : halo coloré léger sur les bords de l'écran, couleur de l'école.
func _teinte_demande(ecole: String, k: float) -> void:
	if k > _teinte_cible:
		_teinte_cible = k
		_teinte_c = LUMIERE.get(ecole, LUMIERE.feu)

func _maj_teinte(dt: float) -> void:
	var cible := minf(_teinte_cible, 1.5)
	_teinte_cible = 0.0
	_teinte_v = move_toward(_teinte_v, cible, dt * (5.0 if cible > _teinte_v else 2.5))
	if _teinte_v <= 0.001:
		if _teinte_calque != null:
			_teinte_calque.visible = false
		return
	if _teinte_calque == null:
		_teinte_calque = CanvasLayer.new()
		_teinte_calque.layer = 1
		var r := ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_teinte_mat = ShaderMaterial.new()
		_teinte_mat.shader = SH_TEINTE
		r.material = _teinte_mat
		_teinte_calque.add_child(r)
		add_child(_teinte_calque)
	_teinte_calque.visible = true
	_teinte_mat.set_shader_parameter("teinte", _teinte_c)
	_teinte_mat.set_shader_parameter("force", _teinte_v * 0.11)

# ====================================================================== éclairs (traits pixel)

## Éclair : `gen` (Callable sans argument) renvoie un Array de [PackedVector3Array (polyligne), largeur, alpha] ;
## redessiné toutes les `regen` s jusqu'à `duree` (duree < 0 : persistant, à couper avec eclair_fin).
func eclair(parent: Node, teinte: String, largeur: float, duree: float, regen: float, gen: Callable) -> Dictionary:
	if _eclairs.size() >= MAX_ECLAIRS:
		refus += 1
		return {}
	var mi: MeshInstance3D = _libres_eclairs.pop_back() if not _libres_eclairs.is_empty() else null
	if mi == null:
		mi = MeshInstance3D.new()
		mi.mesh = ImmediateMesh.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0
	mi.material_override = _mat_trait(teinte, largeur)
	var cible: Node = parent if parent != null else self
	if mi.get_parent() != cible:
		if mi.get_parent() != null:
			mi.get_parent().remove_child(mi)
		cible.add_child(mi)
	mi.transform = Transform3D.IDENTITY
	mi.visible = true
	# dessiné au prochain passage de _maj_eclairs (même image : ce nœud passe après les mains et la logique)
	var e := {"mi": mi, "fin": INF if duree < 0.0 else horloge + duree, "regen": regen, "prochain": 0.0, "gen": gen}
	_eclairs.append(e)
	return e

func eclair_fin(e: Dictionary) -> void:
	if not e.is_empty():
		e.fin = horloge

func _mat_trait(teinte: String, largeur: float) -> ShaderMaterial:
	var cle := "t%s|%s" % [teinte, largeur]
	if not _mats.has(cle):
		var c: Array = ARCS.get(teinte, ARCS.electricite)
		var m := ShaderMaterial.new()
		m.shader = SH_TRAIT
		m.set_shader_parameter("halo", Color(c[0]))
		m.set_shader_parameter("coeur", Color(c[1]))
		m.set_shader_parameter("largeur_halo", 1.0 + 2.0 * largeur)
		m.set_shader_parameter("largeur_coeur", largeur)
		_mats[cle] = m
	return _mats[cle]

func _eclair_dessiner(e: Dictionary) -> void:
	var mi: MeshInstance3D = e.mi
	var im: ImmediateMesh = mi.mesh
	im.clear_surfaces()
	var traits: Array = (e.gen as Callable).call()
	var vide := true
	for t in traits:
		if (t[0] as PackedVector3Array).size() >= 2:
			vide = false
			break
	if vide:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in traits:
		var pts: PackedVector3Array = t[0]
		var w := float(t[1])
		var a := float(t[2])
		for i in range(1, pts.size()):
			var p0 := pts[i - 1]
			var p1 := pts[i]
			var d := p1 - p0
			if d.length_squared() < 1e-10:
				continue
			d = d.normalized()
			for couche in [0.0, 1.0]:
				_sommet_trait(im, p0, d, couche, -1.0, w, a)
				_sommet_trait(im, p0, d, couche, 1.0, w, a)
				_sommet_trait(im, p1, d, couche, 1.0, w, a)
				_sommet_trait(im, p0, d, couche, -1.0, w, a)
				_sommet_trait(im, p1, d, couche, 1.0, w, a)
				_sommet_trait(im, p1, d, couche, -1.0, w, a)
	im.surface_end()

static func _sommet_trait(im: ImmediateMesh, p: Vector3, d: Vector3, couche: float, cote: float, w: float, a: float) -> void:
	im.surface_set_normal(d)
	im.surface_set_color(Color(1, 1, 1, a))
	im.surface_set_uv(Vector2(couche, cote))
	im.surface_set_uv2(Vector2(w, 0))
	im.surface_add_vertex(p)

func _maj_eclairs() -> void:
	var i := _eclairs.size() - 1
	while i >= 0:
		var e: Dictionary = _eclairs[i]
		var mi: Variant = e.mi
		if not is_instance_valid(mi) or horloge >= e.fin:
			_eclairs.remove_at(i)
			if is_instance_valid(mi):
				((mi as MeshInstance3D).mesh as ImmediateMesh).clear_surfaces()
				mi.visible = false
				if mi.get_parent() != self:
					if mi.get_parent() != null:
						mi.get_parent().remove_child(mi)
					add_child(mi)
				_libres_eclairs.append(mi)
		elif horloge >= e.prochain:
			e.prochain = horloge + float(e.regen)
			_eclair_dessiner(e)
		i -= 1

## Polyligne d'éclair de a à b : déplacement du milieu (perpendiculaire au hasard), `prof` subdivisions.
func foudre(a: Vector3, b: Vector3, ampl: float, prof := 4) -> PackedVector3Array:
	if fin_actif:
		prof += 1   # couche fine : un niveau de zigzag de plus (traits de 1 à 2 pixels fins)
	var pts := PackedVector3Array([a, b])
	var amp := ampl
	for _k in prof:
		var n := PackedVector3Array()
		for i in range(pts.size() - 1):
			var p0 := pts[i]
			var p1 := pts[i + 1]
			n.append(p0)
			var d := p1 - p0
			var perp := d.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))).normalized()
			n.append((p0 + p1) * 0.5 + perp * rng.randf_range(-amp, amp))
		n.append(pts[pts.size() - 1])
		pts = n
		amp *= 0.55
	return pts

## Ajoute à `traits` un éclair de a à b et `ramifs` branches courtes.
func foudre_ramifiee(traits: Array, a: Vector3, b: Vector3, ampl: float, largeur: float, ramifs: int, prof := 4) -> void:
	var p := foudre(a, b, ampl, prof)
	traits.append([p, largeur, 1.0])
	var l := a.distance_to(b)
	var dir := (b - a).normalized()
	# ramifications SYMÉTRIQUES autour du lien : écart perpendiculaire à l'axe, une sur deux de l'autre côté (angle + PI)
	# (avant : écart aléatoire 3D ajouté à l'axe → gerbe penchée du côté où part le lien, toujours le même dans la chaîne)
	var u := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := dir.cross(u)
	var ang := rng.randf() * TAU
	for _k in (ramifs * 2 if fin_actif else ramifs):
		var i := rng.randi_range(1, maxi(1, p.size() - 2))
		var o := p[i]
		ang += PI + rng.randf_range(-0.6, 0.6)
		var dev := u * cos(ang) + w * sin(ang)
		var fin := o + (dir * 0.6 + dev).normalized() * l * rng.randf_range(0.12, 0.3)
		var br := foudre(o, fin, l * 0.06, 2)
		traits.append([br, maxf(1.0, largeur - 1.0), 0.7])
		if fin_actif and br.size() > 3 and rng.randf() < 0.6:
			# couche fine : brindilles au bout des ramifications (arbre à trois niveaux)
			var o2 := br[br.size() / 2]
			var fin2 := o2 + (fin - o).normalized().slerp(dev, 0.5) * l * rng.randf_range(0.05, 0.12)
			traits.append([foudre(o2, fin2, l * 0.025, 1), 0.5, 0.6])

# ====================================================================== cristaux (MultiMesh)

## Pic de cristal : base en `pos`, axe `haut`, largeur `l`, hauteur `h` ; pousse en `monte` s après `delai`, se brise
## (fonte par cases) à `fin` (temps absolu de l'horloge).
func pic(pal: String, pos: Vector3, haut: Vector3, l: float, h: float, delai: float, monte: float, fin: float) -> void:
	if not _mm.has(pal):
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _mesh_pic
		mm.instance_count = MAX_PICS
		mm.visible_instance_count = 0
		mmi.multimesh = mm
		mmi.material_override = _mat_cristal(pal, true)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_mm[pal] = mmi
	var n := 0
	for p in _pics:
		if p.pal == pal:
			n += 1
	if n >= MAX_PICS:
		refus += 1
		return
	var y := haut.normalized()
	var x := y.cross(Vector3(0.3, 0.1, 1.0).normalized()).normalized()
	var base := Basis(x, y, x.cross(y)).rotated(y, rng.randf() * TAU)
	_pics.append({"pal": pal, "pos": pos, "base": base, "l": l, "h": h, "t0": horloge + delai, "monte": monte, "fin": fin})

func _maj_pics() -> void:
	var i := _pics.size() - 1
	while i >= 0:
		if horloge > _pics[i].fin + 0.45:
			_pics.remove_at(i)
		i -= 1
	var compte := {}
	for pal in _mm:
		compte[pal] = 0
	for p in _pics:
		var mmi: MultiMeshInstance3D = _mm[p.pal]
		var k := clampf((horloge - p.t0) / maxf(p.monte, 0.01), 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		var fonte := clampf((horloge - p.fin) / 0.4, 0.0, 1.0)
		var b: Basis = p.base.scaled_local(Vector3(p.l, maxf(p.h * k, 0.001), p.l))
		var idx: int = compte[p.pal]
		mmi.multimesh.set_instance_transform(idx, Transform3D(b, p.pos))
		mmi.multimesh.set_instance_custom_data(idx, Color(fonte, 0, 0, 0))
		compte[p.pal] = idx + 1
	for pal in _mm:
		(_mm[pal] as MultiMeshInstance3D).multimesh.visible_instance_count = compte[pal]

# ====================================================================== disques au sol / face caméra

## Disque : `reglages` = paramètres du shader magie_sol (couleur, coeur, anneau, epaisseur, remplissage, runes,
## spirale, eclat, texels, tourne) ; rayon r0 → r1 en `duree` s ; opacité qui s'éteint sur la fin (`fondu` part).
func disque(pos: Vector3, normale: Vector3, r0: float, r1: float, duree: float, reglages: Dictionary, mix := false, face_camera := false, fondu := 0.4) -> Dictionary:
	if _disques.size() >= MAX_DISQUES:
		refus += 1
		return {}
	var mi := MeshInstance3D.new()
	mi.mesh = _quad_sol if face_camera else _plan
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = SH_SOL_MIX if mix else SH_SOL
	for k in reglages:
		var v: Variant = reglages[k]
		m.set_shader_parameter(k, Color(v) if v is String else v)
	m.set_shader_parameter("face_camera", face_camera)
	mi.material_override = m
	add_child(mi)
	var y := normale.normalized() if normale.length() > 0.01 else Vector3.UP
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var base := Basis(x, y, x.cross(y))
	mi.transform = Transform3D(base.scaled_local(Vector3.ONE * maxf(r0, 0.001)), pos + y * 0.03)
	var d := {"mi": mi, "mat": m, "t0": horloge, "duree": duree, "r0": r0, "r1": r1, "op": float(reglages.get("opacite", 1.0)),
		"base": base, "pos": pos + y * 0.03, "fondu": fondu, "suivre": null}
	_disques.append(d)
	return d

func _maj_disques() -> void:
	var i := _disques.size() - 1
	while i >= 0:
		var d: Dictionary = _disques[i]
		var mi: Variant = d.mi
		var k := clampf((horloge - d.t0) / maxf(d.duree, 0.001), 0.0, 1.0)
		if k >= 1.0 or not is_instance_valid(mi):
			if is_instance_valid(mi):
				mi.queue_free()
			_disques.remove_at(i)
			i -= 1
			continue
		var r := lerpf(d.r0, d.r1, 1.0 - pow(1.0 - minf(k / 0.6, 1.0), 2.0))
		var pos: Vector3 = d.pos
		if d.suivre != null:
			if is_instance_valid(d.suivre) and (d.suivre as Node3D).is_inside_tree():
				pos = (d.suivre as Node3D).global_position
		(mi as MeshInstance3D).transform = Transform3D((d.base as Basis).scaled_local(Vector3.ONE * maxf(r, 0.001)), pos)
		var fondu := float(d.fondu)
		var op := float(d.op) * (1.0 if k < 1.0 - fondu else (1.0 - k) / maxf(fondu, 0.001))
		(d.mat as ShaderMaterial).set_shader_parameter("opacite", op)
		i -= 1

# ====================================================================== maillages

## Éclat de cristal (bipyramide hexagonale allongée sur -Z, longueur 1, facettes à plat).
static func _creer_eclat() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var avant := Vector3(0, 0, -0.75)
	var arriere := Vector3(0, 0, 0.25)
	var anneau: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0
		anneau.append(Vector3(cos(a) * (0.16 if i % 2 == 0 else 0.11), sin(a) * 0.14, 0.0))
	for i in 6:
		var p0 := anneau[i]
		var p1 := anneau[(i + 1) % 6]
		st.add_vertex(avant); st.add_vertex(p1); st.add_vertex(p0)
		st.add_vertex(arriere); st.add_vertex(p0); st.add_vertex(p1)
	st.generate_normals()
	return st.commit()

## Pic de cristal (pyramide hexagonale irrégulière, base sous le sol, hauteur 1 sur +Y).
static func _creer_pic() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var bas: Array[Vector3] = []
	var mil: Array[Vector3] = []
	var rr := [1.0, 0.8, 0.95, 0.75, 1.0, 0.85]
	for i in 6:
		var a := TAU * i / 6.0
		bas.append(Vector3(cos(a) * rr[i], -0.15, sin(a) * rr[i]))
		mil.append(Vector3(cos(a + 0.2) * rr[i] * 0.6, 0.45, sin(a + 0.2) * rr[i] * 0.6))
	var pointe := Vector3(0.12, 1.0, 0.05)
	for i in 6:
		var j := (i + 1) % 6
		st.add_vertex(bas[i]); st.add_vertex(mil[i]); st.add_vertex(mil[j])
		st.add_vertex(bas[i]); st.add_vertex(mil[j]); st.add_vertex(bas[j])
		st.add_vertex(mil[i]); st.add_vertex(pointe); st.add_vertex(mil[j])
	st.generate_normals()
	return st.commit()

func _boule(parent: Node3D, rayon: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * rayon * 2.0
	parent.add_child(mi)
	return mi

# ====================================================================== outils

static func base_vers(dir: Vector3) -> Basis:
	## Repère dont -Z regarde `dir`.
	var d := dir.normalized() if dir.length() > 0.0001 else Vector3.FORWARD
	var haut := Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(d, haut)

static func base_normale(n: Vector3) -> Basis:
	## Repère dont +Y suit la normale.
	var y := n.normalized() if n.length() > 0.0001 else Vector3.UP
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))

func valide(n: Variant) -> bool:
	return n != null and is_instance_valid(n) and (n as Node).is_inside_tree()

## Boîte englobante des visuels de `n` dans le repère de `n` (repli : silhouette humaine).
func boite(n: Node3D) -> AABB:
	var res := AABB()
	var vu := false
	var inv := n.global_transform.affine_inverse()
	var liste := n.find_children("*", "VisualInstance3D", true, false)
	var k := 0
	for v in liste:
		if k > 40:
			break
		# Label3D : texte flottant (dégâts du mannequin, noms) : sa boîte de billboard (cube de 1,5 m) gonflait la silhouette
		# → la gerbe en boîte du jet faisait un grand dôme de points autour de la cible
		if v is GPUParticles3D or v is OmniLight3D or v is Light3D or v is Label3D or not (v as Node3D).visible:
			continue
		k += 1
		var vi := v as VisualInstance3D
		var bb: AABB = (inv * vi.global_transform) * vi.get_aabb()
		if bb.size.length() > 6.0 or bb.size.length() < 0.001:
			continue
		res = bb if not vu else res.merge(bb)
		vu = true
	if not vu:
		return AABB(Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 1.8, 0.6))
	return res

func _exclus_depuis(n: Node) -> Array[RID]:
	var ex: Array[RID] = []
	var p := n
	while p != null:
		if p is CollisionObject3D:
			ex.append((p as CollisionObject3D).get_rid())
		p = p.get_parent()
	return ex

## Point d'arrivée d'un rayon visuel (collision ou portée).
func point_vise(depuis: Node3D, o: Vector3, dir: Vector3, portee: float) -> Dictionary:
	var fin := o + dir * portee
	if not depuis.is_inside_tree():
		return {"pos": fin, "touche": false, "normale": -dir}
	var q := PhysicsRayQueryParameters3D.create(o, fin, 0xFFFFFFFF, _exclus_depuis(depuis))
	var r := depuis.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return {"pos": fin, "touche": false, "normale": -dir}
	return {"pos": r.position, "touche": true, "normale": r.normal, "collider": r.collider}

func _ecole_ok(ecole: String) -> String:
	return ecole if LUMIERE.has(ecole) else "feu"

# ====================================================================== auras des mains

func aura_main(main: Node3D, ecole: String, intensite: float) -> void:
	if main == null or not is_instance_valid(main):
		return
	ecole = _ecole_ok(ecole)
	var id := main.get_instance_id()
	var a: Dictionary = _auras.get(id, {})
	if intensite <= 0.001:
		if not a.is_empty():
			_aura_eteindre(a)
			_auras.erase(id)
		return
	if not a.is_empty() and a.ecole != ecole:
		_aura_eteindre(a)
		a = {}
	if a.is_empty():
		a = _aura_creer(main, ecole)
		_auras[id] = a
	a.i = clampf(intensite, 0.0, 1.5)

func _aura_creer(main: Node3D, ecole: String) -> Dictionary:
	var ancre := Node3D.new()
	ancre.name = "AuraMagie"
	add_child(ancre)
	ancre.position = main.global_position
	var a := {"main": main, "ancre": ancre, "ecole": ecole, "i": 0.0, "emit": [], "eclair": {}, "disque": {}, "extra": [], "fine": null, "boule": null}
	var noms: Array = []
	match ecole:
		"feu": noms = ["feu_aura", "feu_aura_coeur", "feu_aura_braise"]
		"glace": noms = ["glace_aura", "glace_aura_cristal", "glace_aura_eclats"]
		"electricite": noms = ["elec_aura", "elec_aura_lueur"]
		"tenebres": noms = ["ten_aura", "ten_aura_lueur"]
		"soin": noms = ["soin_aura"]
		"protection": noms = ["prot_aura"]
	for nom in noms:
		var p := emettre(nom, ancre, Transform3D.IDENTITY, true)
		if p != null:
			a.emit.append(p)
	if fin_actif:
		# couche fine : l'aura est d'abord un motif procédural au pixel (flammes, givre, plasma, vortex) ; les
		# particules et les arcs en font les éclats autour
		a.fine = _aura_fine(ancre, ecole, AURA_RAYON.get(ecole, 0.09))
		# pas d'avance vers l'œil : la main (devant la paume en vue FPS) se découpe en silhouette dans les flammes
		(a.fine as MeshInstance3D).set_instance_shader_parameter("avance", 0.0)
		a.extra.append(a.fine)
		if ecole == "feu":
			# cœur : une boule de feu bouillonnante tenue au creux de la main, d'où partent les langues (référence
			# Jeux/references/avant_bras_magie/bras_feu_1100.jpg) ; les doigts la masquent en partie (profondeur)
			a.boule = _aura_fine(ancre, ecole, AURA_BOULE, 2)
			# le cœur lisse passe DEVANT les langues de la couche fine (même centre) : pas de flammes sombres sur le cœur
			(a.boule as MeshInstance3D).sorting_offset = 0.05
			a.extra.append(a.boule)
	if ecole == "electricite":
		a.eclair = eclair(ancre, "electricite", 2.0, -1.0, 0.05, _gen_aura_arcs.bind(a))
	elif ecole == "tenebres" and not fin_actif:
		# vortex noir et violet DANS la paume (spirale), bien visible en vue FPS
		var vortex := _vortex_main(ancre, 0.07)
		a.extra.append(vortex)
	elif ecole == "protection":
		var mi := MeshInstance3D.new()
		mi.mesh = _quad_sol
		var m := ShaderMaterial.new()
		m.shader = SH_SOL
		m.set_shader_parameter("couleur", Color("#7ab0d8"))
		m.set_shader_parameter("coeur", Color("#eaf8ff"))
		m.set_shader_parameter("anneau", 0.85)
		m.set_shader_parameter("epaisseur", 0.07)
		m.set_shader_parameter("runes", 0.9)
		m.set_shader_parameter("texels", 32.0)
		m.set_shader_parameter("tourne", 0.15)
		m.set_shader_parameter("opacite", 0.8)
		m.set_shader_parameter("face_camera", true)
		mi.material_override = m
		mi.scale = Vector3.ONE * 0.06
		ancre.add_child(mi)
		a.extra.append(mi)
	return a

func _vortex_main(parent: Node3D, rayon: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad_sol
	var m := ShaderMaterial.new()
	m.shader = SH_SOL_MIX
	m.set_shader_parameter("couleur", Color("#b050ff"))
	m.set_shader_parameter("coeur", Color("#06030c"))
	m.set_shader_parameter("anneau", 0.92)
	m.set_shader_parameter("epaisseur", 0.06)
	m.set_shader_parameter("spirale", 1.0)
	m.set_shader_parameter("texels", 28.0)
	m.set_shader_parameter("tourne", 0.8)
	m.set_shader_parameter("opacite", 1.0)
	m.set_shader_parameter("face_camera", true)
	mi.material_override = m
	mi.scale = Vector3.ONE * rayon
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _gen_aura_arcs(a: Dictionary) -> Array:
	var traits: Array = []
	var i := float(a.i)
	var dbl: bool = _double.get(a.ecole, false)
	var n := 3 + int(i * 5.0) + (2 if dbl else 0)
	if valide(a.main) and _jets.has((a.main as Node).get_instance_id()):
		# un arc part de cette main : quelques étincelles seulement autour de la paume (pas de pelote blanche)
		n = 2
		i = 0.0
	for _k in n:
		var o := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * 0.015
		var b := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.05, 0.11) * (1.0 + 0.4 * i)
		traits.append([foudre(o, b, 0.025, 3), 1.0 if rng.randf() < 0.5 else 0.6, 1.0])
	return traits

func _aura_eteindre(a: Dictionary) -> void:
	for p in a.emit:
		arreter(p)
	eclair_fin(a.eclair)
	for x in a.extra:
		if is_instance_valid(x):
			x.queue_free()
	a.extra.clear()
	var ancre: Node3D = a.ancre
	if is_instance_valid(ancre):
		# l'ancre reste le temps que les dernières particules (locales) s'éteignent
		var t := get_tree().create_timer(1.7, false) if is_inside_tree() else null
		if t != null:
			t.timeout.connect(ancre.queue_free)
		else:
			ancre.queue_free()

func _maj_auras() -> void:
	for id in _auras.keys():
		var a: Dictionary = _auras[id]
		var main: Variant = a.main
		if not valide(main):
			_aura_eteindre(a)
			_auras.erase(id)
			continue
		var ancre: Node3D = a.ancre
		var i := float(a.i)
		if _jets.has(id):
			# un jet part de cette main : l'aura se résorbe en un petit foyer dans la paume (c'est le jet qui naît
			# là) au lieu d'une boule de flammes qui couvre la naissance du flux
			i *= 0.4 if a.ecole == "feu" else 0.15
		var dbl: bool = _double.get(a.ecole, false)
		var k := (0.75 + 0.5 * minf(i, 1.0)) * (1.25 if dbl else 1.0)
		var ech: float = echelles_aura.get(id, 1.0)
		var tenue := echelles_aura.has(id)
		ancre.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), (main as Node3D).global_position)
		if a.fine != null and is_instance_valid(a.fine):
			var fm: MeshInstance3D = a.fine
			fm.set_instance_shader_parameter("rayon", float(AURA_RAYON.get(a.ecole, 0.09)) * k * ech)
			fm.set_instance_shader_parameter("force", clampf(0.25 + 0.75 * i, 0.0, 1.3))
		if a.boule != null and is_instance_valid(a.boule):
			var bm: MeshInstance3D = a.boule
			bm.set_instance_shader_parameter("rayon", AURA_BOULE * k * (BOULE_TENUE if tenue else 1.0))
			bm.set_instance_shader_parameter("force", clampf(0.7 + 0.4 * i, 0.0, 1.3))
		for n_e in a.emit.size():
			var p: GPUParticles3D = a.emit[n_e]
			if is_instance_valid(p):
				var ratio := clampf(0.3 + 0.7 * i, 0.05, 1.0)
				if tenue and a.ecole == "feu":
					# boule tenue : pas de traits blancs (flammèches étirées, cœur) devant le cœur lisse, des braises
					ratio *= [0.12, 0.0, 1.0][mini(n_e, 2)]
				p.amount_ratio = ratio
		var c: Color = LUMIERE[a.ecole]
		var scint := 1.0
		if a.ecole == "electricite":
			scint = 0.6 + 0.8 * rng.randf()
		elif a.ecole == "feu":
			scint = 0.9 + 0.2 * sin(horloge * 23.0) * sin(horloge * 7.0)
		lumiere("aura%d" % id, ancre.position + Vector3.UP * 0.05, c, (1.5 + 4.0 * i) * scint * (1.5 if dbl else 1.0), 4.5 + 3.5 * i, 2.0 + i, -1.0,
			0xFFFFF & ~CALQUE_AVANT_BRAS)

# ====================================================================== jets canalisés

func jet(ecole: String, origine: Node3D, direction: Vector3, portee: float, largeur: float, actif: bool) -> void:
	if origine == null or not is_instance_valid(origine):
		return
	ecole = _ecole_ok(ecole)
	var id := origine.get_instance_id()
	var j: Dictionary = _jets.get(id, {})
	if not actif:
		if not j.is_empty():
			_jet_arreter(j)
			_jets.erase(id)
		return
	var dbl: bool = _double.get(ecole, false)
	# vague de flammes : un changement de portée (on vise un mur plus proche) ne recrée pas le jet (les bouffées en vol
	# disparaîtraient d'un coup) ; le plan d'arrêt suit le point touché
	var garde_portee: bool = not j.is_empty() and j.get("vague") != null
	if garde_portee:
		j.portee = portee
	if not j.is_empty() and (j.ecole != ecole or j.dbl != dbl or (not garde_portee and absf(float(j.portee) - portee) > portee * 0.2) or absf(float(j.largeur) - largeur) > maxf(largeur, 0.05) * 0.3):
		_jet_arreter(j)
		j = {}
	if j.is_empty():
		j = _jet_creer(ecole, origine, portee, largeur, dbl)
		_jets[id] = j
	j.dir = direction.normalized() if direction.length() > 0.0001 else Vector3.FORWARD
	j.vu = horloge
	_jet_placer(j)

func _jet_creer(ecole: String, origine: Node3D, portee: float, largeur: float, dbl: bool) -> Dictionary:
	var j := {"ecole": ecole, "origine": origine, "portee": portee, "largeur": largeur, "dbl": dbl, "emit": [], "eclair": {},
		"dir": Vector3.FORWARD, "vu": horloge, "fin_pos": Vector3.ZERO, "touche": false, "normale": Vector3.UP, "t_bout": 0.0, "t_rayon": -1.0,
		"suit_bout": [], "bouclier": {}, "cible": null, "gerbe": [], "gerbe_cible": null, "gerbe_bb": AABB(), "flash": null, "debut": horloge,
		"flux": null, "vague": null, "ecart": 10.0, "dir_vis": Vector3.ZERO, "t_maj": horloge, "eclabousse": null}
	var kl := 1.6 if dbl else 1.0
	# cône 2 à 3 fois plus large qu'un rayon « géométrique » : la flamme s'évase et noie la cible
	var ecart := clampf(rad_to_deg(atan2(largeur * 0.5 * kl, maxf(portee, 0.5))) * 2.4, 8.0, 32.0)
	var kn := 1.4 if dbl else 1.0
	if fin_actif and ecole == "feu":
		# couche fine : le corps du jet de flammes est une VAGUE de bouffées qui naissent dans la paume et avancent
		# réellement dans l'espace (elles grossissent, montent, roulent, refroidissent puis fument)
		j.vague = _vague_creer(dbl)
		j.ecart = ecart
	elif fin_actif and ecole == "electricite":
		j.decharge = _decharge_creer(dbl)
		# avec le faisceau épais, moins d'éclats (sinon, en double, deux jets empilent un gros blanc sur la cible)
		var dch: GPUParticles3D = j.decharge
		dch.amount = int(DECHARGE_N * (0.8 if dbl else 0.65))
		(dch.process_material as ShaderMaterial).set_shader_parameter("force", 1.1 if dbl else 1.0)
		j.faisceau = _faisceau_creer(dbl)
	elif fin_actif and ecole == "glace":
		# couche fine : le corps du jet de glace est un SOUFFLE DE GIVRE (même machinerie que la vague : j.vague)
		j.vague = _givre_creer(dbl)
		j.ecart = ecart
	elif fin_actif and FLUX.has(ecole):
		# couche fine : le corps du jet est un flux procédural continu (les particules en font les bords et les éclats)
		j.flux = _flux_creer(ecole)
		j.ecart = ecart
	match ecole:
		"feu", "glace", "soin":
			var noms: Array = {"feu": ["feu_jet_coeur", "feu_jet", "feu_jet_bord", "feu_jet_braise", "feu_jet_fumee", "feu_paume"],
				"glace": ["glace_jet", "glace_jet_corps", "glace_jet_cristal", "glace_jet_brume", "glace_paume"], "soin": ["soin_jet"]}[ecole]
			if j.vague != null:
				# couche fine : le CORPS du jet est le flux procédural (un seul volume qui coule) ; plus de gros carrés
				# opaques qui s'entassent (« un tas de flammes ») : seulement des langues fines, des escarbilles qui
				# s'échappent, tourbillonnent et retombent, et le foyer de la paume
				noms = ["feu_fin_jet_langues", "feu_fin_jet_escarbilles", "feu_fin_jet_retombee", "feu_paume"] if ecole == "feu" else GIVRE_COMPAGNONS
			for nom in noms:
				var d: Dictionary = PresetsMagie.R[nom]
				if nom.ends_with("paume"):
					var pp := emettre(nom, null, Transform3D.IDENTITY, true, kn)
					if pp != null:
						j.emit.append(pp)
					continue
				var v: Vector2 = d.vit
				var vm := (v.x + v.y) * 0.5
				var kv := 1.6 if nom.ends_with("fumee") or nom.ends_with("brume") else 1.2
				var pm := _pm(nom, d, {"ecart": snappedf(float(d.get("ecart", 9.0)) * ecart / 9.0, 0.5)})
				# escarbilles : vie propre (elles dépassent la cible, ralentissent, tourbillonnent, retombent)
				var libre := bool(d.get("libre", false))
				var p := emettre(nom, null, Transform3D.IDENTITY, true, kn, -1.0 if libre else portee / vm * kv, pm)
				if p != null:
					if not libre:
						p.set_meta("v_jet", vm / kv)
					j.emit.append(p)
		"electricite":
			if j.get("decharge") != null:
				j.eclair = eclair(null, "electricite", 1.5 if dbl else 1.0, -1.0, 0.033, _gen_jet_arc_vif.bind(j))
			else:
				j.eclair = eclair(null, "electricite", 2.4 if dbl else 2.0, -1.0, 0.033, _gen_jet_arc.bind(j))
			var pe := emettre("elec_paume", null, Transform3D.IDENTITY, true, kn)
			if pe != null:
				j.emit.append(pe)
			# éclat aveuglant dans la paume (sphère additive qui papillote)
			var f := Node3D.new()
			add_child(f)
			_boule(f, 0.5, _mat_coeur(Color("#f0f2ff"), true, 2.2))
			_boule(f, 1.0, _mat_coeur(Color("#7a7af0", 0.2), true, 1.4))
			j.flash = f
		"tenebres":
			j.eclair = eclair(null, "drain", 3.0 if dbl else 2.5, -1.0, 0.033, _gen_drain.bind(j))
			for nom in ["ten_drain_sombre", "ten_drain_rouge", "ten_drain_eclats"]:
				var p := emettre(nom, null, Transform3D.IDENTITY, true, kn)
				if p != null:
					j.emit.append(p)
					j.suit_bout.append(p)
		"protection":
			j.bouclier = disque(Vector3.ZERO, Vector3.FORWARD, largeur * 0.5 * kl, largeur * 0.5 * kl, 1e9,
				{"couleur": "#7ab0d8", "coeur": "#eaf8ff", "anneau": 0.88, "epaisseur": 0.06, "runes": 1.0, "remplissage": 0.25, "texels": 40.0, "tourne": 0.2, "eclat": 1.3}, false, false, 0.05)
	return j

## Point de la courbe d'un jet (Bézier quadratique) : part de la paume selon la visée actuelle, le bout suit la visée
## avec un retard (dir_vis, inertie) ; même courbe que le flux procédural (magie_flux.gdshader).
func _jet_courbe(o: Vector3, j: Dictionary, l: float, t: float) -> Vector3:
	var dv: Vector3 = j.dir_vis if j.dir_vis != Vector3.ZERO else j.dir
	var c := o + (j.dir as Vector3) * l * 0.5
	var bout: Vector3 = o + dv * l if not j.touche else j.fin_pos
	return o * (1.0 - t) * (1.0 - t) + c * 2.0 * (1.0 - t) * t + bout * t * t

## Arc d'éclair le long de la courbe du jet : 9 points de passage tirés au hasard autour de la courbe, puis zigzag fin
## entre eux (déplacement du point milieu) ; nerveux mais orienté (pas une pelote).
func _arc_courbe(o: Vector3, j: Dictionary, l: float, ampl: float, decal: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var n := 9
	var prec := o
	for i in range(1, n + 1):
		var t := float(i) / n
		var q := _jet_courbe(o, j, l, t) + decal * t * t
		if i < n:
			q += Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * ampl * (0.12 + 0.28 * t)
		# zigzag serré à haute fréquence (cf. electricite_fps_1100.jpg) plutôt que de grandes ondulations à angle droit
		var seg := foudre(prec, q, ampl * 0.6 * (0.3 + 0.7 * t), 3)
		if i > 1:
			seg.remove_at(0)
		pts.append_array(seg)
		prec = q
	return pts

func _gen_jet_arc(j: Dictionary) -> Array:
	var traits: Array = []
	var o: Vector3 = (j.origine as Node3D).global_position if valide(j.origine) else Vector3.ZERO
	var l := o.distance_to(j.fin_pos)
	if l < 0.05:
		return traits
	var dbl: bool = j.dbl
	# faisceau à la « Sparks » : 1 arc maître fin + 2 (3 en double) arcs plus fins qui se croisent autour, tous refaits
	# à chaque régénération (30 fois par seconde) ; branches COURTES tournées vers l'avant (pas de pelote au milieu)
	var dir: Vector3 = (j.fin_pos - o) / l
	var arcs := (5 if dbl else 4)
	for k in arcs:
		var decal := Vector3.ZERO
		if k > 0:
			decal = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * l * 0.025
		var p := _arc_courbe(o, j, l, l * (0.035 if k == 0 else 0.05), decal)
		traits.append([p, (1.0 if k == 0 else 0.5), 1.0 if k == 0 else 0.7])
		for _r in (3 if k == 0 else 1) * (2 if fin_actif else 1):
			# branches sur la seconde moitié du trajet seulement, longueur proportionnelle à la distance parcourue : près
			# de la paume (donc de la caméra) une branche de 50 cm couvrait un tiers de l'écran (grandes boucles)
			var i := rng.randi_range(p.size() * 2 / 5, maxi(p.size() * 2 / 5, p.size() - 3))
			var depart := p[i]
			var kt := float(i) / p.size()
			var dev := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			var fin := depart + (dir + dev * 0.8).normalized() * l * kt * rng.randf_range(0.03, 0.08)
			traits.append([foudre(depart, fin, l * 0.02, 3), 0.4, 0.6])
	if j.touche:
		# arrivée : petites fourches qui courent sur le corps de la cible
		for _k in 2:
			var b: Vector3 = j.fin_pos
			var fin: Vector3 = b + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.7, 0.45), rng.randf_range(-0.35, 0.35))
			traits.append([foudre(b, fin, 0.05, 3), 0.5, 0.7])
	return traits

## Arc maître de la décharge (couche fine) : la colonne vertébrale fine qui relie TOUJOURS la paume au bout (on voit
## où l'éclair frappe) ; les éclats texturés de la décharge (_decharge_*) lui donnent l'épaisseur et le crépitement.
## Refait 30 fois par seconde : 2 brins (3 en double) qui se croisent, éclat qui varie à chaque image (scintillement),
## une image sur huit environ réduite à un brin pâle (l'arc « hoquette ») ; fourches courtes vers l'avant et, sur la
## cible, des doigts qui courent sur le corps.
func _gen_jet_arc_vif(j: Dictionary) -> Array:
	var traits: Array = []
	var o: Vector3 = (j.origine as Node3D).global_position if valide(j.origine) else Vector3.ZERO
	var l := o.distance_to(j.fin_pos)
	if l < 0.05:
		return traits
	var dbl: bool = j.dbl
	var dir: Vector3 = (j.fin_pos - o) / l
	var hoquet := rng.randf() < 0.12
	var brins := 1 if hoquet else (3 if dbl else 2)
	for k in brins:
		var decal := Vector3.ZERO
		if k > 0:
			decal = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * l * 0.04
		var p := _arc_courbe(o, j, l, l * (0.03 if k == 0 else 0.045), decal)
		var a := 0.4 if hoquet else (rng.randf_range(0.7, 1.0) if k == 0 else rng.randf_range(0.3, 0.7))
		# avec le faisceau épais (magie_faisceau), les brins sont dessinés par le shader : ici seulement les fourches 3D
		if j.get("faisceau") == null:
			traits.append([p, 1.0 if k == 0 else 0.5, a])
		if hoquet:
			break
		for _r in (4 if k == 0 else 1):
			var i := rng.randi_range(p.size() * 2 / 5, maxi(p.size() * 2 / 5, p.size() - 3))
			var kt := float(i) / p.size()
			var dev := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			var fin := p[i] + (dir + dev * 0.9).normalized() * l * kt * rng.randf_range(0.04, 0.1)
			traits.append([foudre(p[i], fin, l * 0.02, 3), 0.5, 0.55])
	if j.touche:
		for _k in (4 if dbl else 3):
			var b: Vector3 = j.fin_pos
			var fin: Vector3 = b + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.8, 0.5), rng.randf_range(-0.4, 0.4))
			traits.append([foudre(b, fin, 0.06, 3), 0.5, rng.randf_range(0.5, 0.9)])
	return traits

func _gen_drain(j: Dictionary) -> Array:
	var traits: Array = []
	if not valide(j.origine):
		return traits
	var o: Vector3 = (j.origine as Node3D).global_position
	var b: Vector3 = j.fin_pos
	var axe := b - o
	var l := axe.length()
	if l < 0.05:
		return traits
	var dir := axe / l
	var x := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var y := dir.cross(x)
	var n := clampi(int(l * 9.0), 12, 60)
	var dbl: bool = j.dbl
	var brins := (3 if dbl else 2) + (1 if fin_actif else 0)
	# filaments fins qui ondulent comme de la fumée aspirée (2 à 3 ondulations sur le trajet, l'onde COURT de la cible
	# vers la main), écartés au milieu et resserrés aux deux bouts : pas de ressort régulier
	for brin in brins:
		var pts := PackedVector3Array()
		var fa := 1.3 + 0.4 * brin
		var fb := 1.0 + 0.3 * ((brin * 7) % 3)
		var ph := float(brin) * 2.399
		var amp := (0.09 + 0.05 * float(brin % 3)) * (1.3 if dbl else 1.0)
		for i in n + 1:
			var t := float(i) / n
			var env := pow(sin(t * PI), 0.8) * (1.0 - 0.55 * t)   # vu de la main, le bout lointain est raccourci
			var ox := sin(t * fa * TAU + horloge * 9.0 + ph) * amp * env
			var oy := sin(t * fb * TAU + horloge * 6.5 + ph * 1.7) * amp * 0.8 * env
			pts.append(_jet_courbe(o, j, l, t) + x * ox + y * oy)
		# couche fine : brins fins et discrets, c'est le flux procédural (fumée noire et lueur violette) qui fait le corps
		traits.append([pts, (0.4 if brin < 1 else 0.3) if fin_actif else (1.0 if brin < 2 else 0.6), 0.55 if fin_actif else 1.0])
	return traits

# ---------------------------------------------------------------------- flux procédural (couche fine)

## Ruban de 48 tranches (UV.x = position le long du jet, UV.y = côté) ; la forme est faite par magie_flux.gdshader.
func _creer_flux() -> ArrayMesh:
	var n := 48
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in n + 1:
		var t := float(i) / n
		for c in [-1.0, 1.0]:
			v.append(Vector3(c * 0.5, 0.0, -t))
			uv.append(Vector2(t, c))
	for i in n:
		var a := i * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _mat_flux(ecole: String) -> ShaderMaterial:
	var cle := "f" + ecole
	if not _mats.has(cle):
		var m := ShaderMaterial.new()
		m.shader = SH_FLUX
		var pal: Array = FLUX.get(ecole, FLUX.feu)
		for i in 6:
			m.set_shader_parameter("c%d" % i, Color(pal[i]))
		m.set_shader_parameter("ecole", {"feu": 0, "glace": 1, "tenebres": 2, "soin": 3}.get(ecole, 0))
		m.set_shader_parameter("vitesse", {"feu": 5.5, "glace": 5.5, "tenebres": 4.0, "soin": 4.0}.get(ecole, 6.0))
		m.set_shader_parameter("eclat", {"feu": 1.2, "glace": 1.1, "tenebres": 1.35, "soin": 1.0}.get(ecole, 1.1))
		m.set_shader_parameter("allonge", {"feu": 3.6, "tenebres": 2.6}.get(ecole, 1.0))
		m.set_shader_parameter("ouvre", {"feu": 1.4, "tenebres": 1.4}.get(ecole, 1.0))
		m.set_shader_parameter("evase", {"feu": 0.8}.get(ecole, 0.8))
		# feu : SPRAY (vagues de flamme qui sortent de la paume, gonflent et se déchirent), pas un rayon
		m.set_shader_parameter("bouffees", {"feu": 0.6}.get(ecole, 0.0))
		m.set_shader_parameter("marge", {"feu": 1.75}.get(ecole, 1.35))
		_mats[cle] = m
	return _mats[cle]

func _flux_creer(ecole: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.visible = not sans_procedural and not OS.get_cmdline_user_args().has("--sans-flux")
	mi.mesh = _mesh_flux
	mi.material_override = _mat_flux(ecole)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-2, -2, -12), Vector3(4, 4, 14))
	mi.set_instance_shader_parameter("graine", rng.randf() * 10.0)
	add_child(mi)
	_proc.append(mi)
	return mi

# ---------------------------------------------------------------------- vague de flammes (couche fine, jet de feu)

func _mat_vague() -> ShaderMaterial:
	if not _mats.has("vague"):
		var m := ShaderMaterial.new()
		m.shader = SH_VAGUE
		m.set_shader_parameter("bruit", BRUIT_VAGUE)
		var pal: Array = FLUX.feu
		for i in 6:
			m.set_shader_parameter("c%d" % i, Color(pal[i]))
		_mats["vague"] = m
	return _mats["vague"]

## Émetteur de la vague (un par jet : son plan d'arrêt lui est propre). Repère du MONDE : les bouffées parties gardent
## leur trajectoire quand la main tourne. Vitesse de sortie réglée pour que, freinées, elles portent à VAGUE_PORTEE.
func _vague_creer(dbl: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "VagueFlammes"
	p.amount = int(VAGUE_N * (1.2 if dbl else 1.0))
	p.lifetime = VAGUE_VIE
	p.preprocess = VAGUE_AMORCE
	p.local_coords = false
	p.fixed_fps = 0
	p.interpolate = false
	p.randomness = 0.0
	p.explosiveness = 0.0
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.draw_pass_1 = _quad
	p.visibility_aabb = AABB(Vector3.ONE * -14.0, Vector3.ONE * 28.0)
	var pm := ShaderMaterial.new()
	pm.shader = SH_VAGUE_PROC
	var k := VAGUE_TRAINE
	pm.set_shader_parameter("traine", k)
	pm.set_shader_parameter("vitesse", VAGUE_PORTEE * (1.15 if dbl else 1.0) * k / (1.0 - exp(-k * VAGUE_VIE)))
	pm.set_shader_parameter("ecart", 0.11 if dbl else 0.085)
	pm.set_shader_parameter("taille1", 0.8 if dbl else 0.75)
	p.process_material = pm
	# un matériau par jet : le champ partagé du dessin (magie_vague) suit l'axe de CE jet (double incantation : deux axes)
	p.material_override = _mat_vague().duplicate()
	p.visible = not sans_procedural and not OS.get_cmdline_user_args().has("--sans-flux")
	add_child(p)
	p.emitting = true
	_proc.append(p)
	return p

func _vague_placer(j: Dictionary, o: Vector3, b: Basis, fin: Vector3, vers: Vector3) -> void:
	var p: GPUParticles3D = j.vague
	var pm := p.process_material as ShaderMaterial
	# sous-pas d'émission : repère de l'image précédente (le shader interpole la naissance des bouffées entre les deux)
	var prec: Transform3D = j.get("vague_prec", Transform3D(b, o))
	pm.set_shader_parameter("prec_o", prec.origin)
	pm.set_shader_parameter("prec_base", prec.basis)
	pm.set_shader_parameter("pas", get_process_delta_time())
	p.global_transform = Transform3D(b, o)
	j.vague_prec = p.global_transform
	# plan d'arrêt : un peu avant la surface (la vague s'y écrase et la lèche), sur la cible : à son centre
	var touche: bool = j.touche
	pm.set_shader_parameter("arret", Vector4(fin.x, fin.y, fin.z, 1.0 if touche else 0.0))
	pm.set_shader_parameter("arret_dir", vers)
	var mv := p.material_override as ShaderMaterial
	if mv != null and mv.shader == SH_VAGUE:
		_vague_axe(j, mv, float(pm.get_shader_parameter("vitesse")), o, vers, o.distance_to(fin) if touche else VAGUE_PORTEE)

## Ligne médiane RÉELLE du jet de flammes, pour le dessin (magie_vague : champ partagé par toutes les bouffées). Une
## bouffée à x mètres de la paume est partie il y a a(x) secondes (freinage : x = v0/k·(1 - e^(-k·a))), de là où était la
## paume et dans la direction qu'elle visait alors : on garde l'historique des poses (≈ VAGUE_VIE) et on pose 8 points
## de x = 0 au bout (point touché, ou portée). En tournant, la ligne suit le cordon qui traîne, pas l'axe actuel.
func _vague_axe(j: Dictionary, mv: ShaderMaterial, v0: float, o: Vector3, vers: Vector3, longueur: float) -> void:
	var hist: Array = j.get("vague_hist", [])
	hist.append([horloge, o, vers])
	while hist.size() > 2 and horloge - float(hist[1][0]) > VAGUE_VIE + 0.1:
		hist.pop_front()
	j.vague_hist = hist
	var k := VAGUE_TRAINE
	var lg := clampf(longueur, 0.3, VAGUE_PORTEE)
	var pts := PackedVector3Array()
	var n := hist.size()
	var idx := n - 1
	for i in 8:
		var x := lg * i / 7.0
		var ta := horloge + log(maxf(1.0 - x * k / maxf(v0, 0.1), 0.05)) / k   # instant de départ
		while idx > 0 and float(hist[idx][0]) > ta:
			idx -= 1
		var po: Vector3 = hist[idx][1]
		var di: Vector3 = hist[idx][2]
		if idx < n - 1 and float(hist[idx][0]) <= ta:
			var h1: Array = hist[idx + 1]
			var f := clampf((ta - float(hist[idx][0])) / maxf(float(h1[0]) - float(hist[idx][0]), 0.0001), 0.0, 1.0)
			po = po.lerp(h1[1], f)
			di = di.lerp(h1[2], f).normalized()
		pts.append(po + di * x)
	mv.set_shader_parameter("jet_pts", pts)
	mv.set_shader_parameter("jet_long", lg)

# ---------------------------------------------------------------------- décharge électrique (couche fine, arc électrique)

func _mat_decharge() -> ShaderMaterial:
	if not _mats.has("decharge"):
		var m := ShaderMaterial.new()
		m.shader = SH_DECHARGE
		m.set_shader_parameter("formes", ATLAS_ELEC)
		_mats["decharge"] = m
	return _mats["decharge"]

## Émetteur des éclats d'un arc électrique (un par jet : sa courbe lui est propre). Les éclats sont recalculés chaque
## image sur la courbe actuelle (uniformes o, c, b) : ils collent à l'arc, rien n'est simulé sur le CPU.
func _decharge_creer(dbl: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "DechargeElec"
	p.amount = int(DECHARGE_N * (1.35 if dbl else 1.0))
	p.lifetime = DECHARGE_VIE
	p.local_coords = false
	p.fixed_fps = 0
	p.interpolate = false
	p.randomness = 0.0
	p.explosiveness = 0.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.draw_pass_1 = _quad
	p.visibility_aabb = AABB(Vector3.ONE * -14.0, Vector3.ONE * 28.0)
	var pm := ShaderMaterial.new()
	pm.shader = SH_DECHARGE_PROC
	pm.set_shader_parameter("force", 1.35 if dbl else 1.0)
	p.process_material = pm
	p.material_override = _mat_decharge()
	p.visible = not sans_procedural and not OS.get_cmdline_user_args().has("--sans-flux")
	add_child(p)
	p.emitting = true
	_proc.append(p)
	return p

## Courbe de la décharge = celle de l'arc maître (_jet_courbe : paume, contrôle sur la visée, bout en retard).
func _decharge_placer(j: Dictionary, o: Vector3, l: float) -> void:
	var p: GPUParticles3D = j.decharge
	var pm := p.process_material as ShaderMaterial
	var dv: Vector3 = j.dir_vis if j.dir_vis != Vector3.ZERO else j.dir
	p.global_position = o
	pm.set_shader_parameter("o", o)
	pm.set_shader_parameter("c", o + (j.dir as Vector3) * l * 0.5)
	pm.set_shader_parameter("b", o + dv * l if not j.touche else (j.fin_pos as Vector3))
	pm.set_shader_parameter("touche", 1.0 if j.touche else 0.0)

## Décharge PONCTUELLE (chaîne d'éclairs, impact) : émetteur à courbe fixe qui crépite `duree` s après `delai` s, puis
## s'éteint et se libère seul. `eclat` : o = c = b = point touché, traits en étoile autour de `normale`.
func _decharge_ponctuelle(o: Vector3, b: Vector3, duree: float, delai := 0.0, n := 40, force := 1.0, eclat := false, normale := Vector3.UP) -> void:
	if sans_procedural or not fin_actif:
		return
	var p := _decharge_creer(false)
	p.amount = n
	p.emitting = delai <= 0.0
	p.global_position = b
	var pm := p.process_material as ShaderMaterial
	pm.set_shader_parameter("o", o)
	pm.set_shader_parameter("c", o.lerp(b, 0.5) + Vector3.UP * o.distance_to(b) * 0.06)
	pm.set_shader_parameter("b", b)
	pm.set_shader_parameter("touche", 1.0)
	pm.set_shader_parameter("force", force)
	pm.set_shader_parameter("eclatement", 1.0 if eclat else 0.0)
	pm.set_shader_parameter("normale", normale.normalized())
	var tm := get_tree()
	if delai > 0.0:
		tm.create_timer(delai, false).timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.emitting = true)
	tm.create_timer(delai + duree, false).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false)
	tm.create_timer(delai + duree + DECHARGE_VIE + 0.1, false).timeout.connect(p.queue_free)

func _decharge_arreter(j: Dictionary) -> void:
	if j.get("decharge") != null and is_instance_valid(j.decharge):
		var dc: GPUParticles3D = j.decharge
		dc.emitting = false
		get_tree().create_timer(DECHARGE_VIE + 0.1, false).timeout.connect(dc.queue_free)
	j.erase("decharge")

# ---------------------------------------------------------------------- faisceau électrique (couche fine, arc électrique)

## Ruban fixe de FAISCEAU_SEG segments (UV.x = t le long de l'arc, UV.y = côté) : le shader le pose sur la courbe.
func _creer_faisceau() -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	for i in FAISCEAU_SEG:
		var t0 := float(i) / FAISCEAU_SEG
		var t1 := float(i + 1) / FAISCEAU_SEG
		for q in [[t0, -1.0], [t0, 1.0], [t1, 1.0], [t0, -1.0], [t1, 1.0], [t1, -1.0]]:
			v.append(Vector3.ZERO)
			uv.append(Vector2(q[0], q[1]))
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_TEX_UV] = uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m

## Corps épais de l'arc électrique (un par jet : matériau propre, ses uniformes sont la courbe de CE jet).
func _faisceau_creer(dbl: bool) -> MeshInstance3D:
	if _mesh_faisceau == null:
		_mesh_faisceau = _creer_faisceau()
	var mi := MeshInstance3D.new()
	mi.name = "FaisceauElec"
	mi.mesh = _mesh_faisceau
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -1e4, Vector3.ONE * 2e4)   # sommets posés par le shader
	var m := ShaderMaterial.new()
	m.shader = SH_FAISCEAU
	var pal: Array = AURA_PAL.electricite
	for i in 6:
		m.set_shader_parameter("c%d" % i, Color(pal[i]))
	m.set_shader_parameter("dbl", 1.0 if dbl else 0.0)
	m.set_shader_parameter("graine", rng.randf() * 100.0)
	mi.material_override = m
	mi.visible = not sans_procedural and not OS.get_cmdline_user_args().has("--sans-flux")
	add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	_proc.append(mi)
	return mi

## Même courbe que la décharge (_decharge_placer) et que l'arc maître CPU.
func _faisceau_placer(j: Dictionary, o: Vector3, l: float) -> void:
	var mi: MeshInstance3D = j.faisceau
	var m := mi.material_override as ShaderMaterial
	var dv: Vector3 = j.dir_vis if j.dir_vis != Vector3.ZERO else j.dir
	m.set_shader_parameter("arc_o", o)
	m.set_shader_parameter("arc_c", o + (j.dir as Vector3) * l * 0.5)
	m.set_shader_parameter("arc_b", o + dv * l if not j.touche else (j.fin_pos as Vector3))
	m.set_shader_parameter("touche", 1.0 if j.touche else 0.0)
	m.set_shader_parameter("force", clampf((horloge - float(j.debut)) / 0.08, 0.0, 1.0))
	m.set_shader_parameter("jour", _jour())

## Clarté du jour 0..1 (soleil blanc et fort : 1 ; lune bleutée, nuit, intérieur sans soleil : 0), pour le cœur de l'arc
## électrique (sur la neige de jour, l'additif blanc s'y perdait). La lumière directionnelle est cherchée une fois (puis
## au plus toutes les 5 s si la scène n'en a pas), sa couleur et son énergie sont lues à chaque image.
func _jour() -> float:
	if not is_instance_valid(_soleil) and horloge - _soleil_cherche > 5.0:
		_soleil_cherche = horloge
		var sc := get_tree().current_scene
		if sc != null:
			for n in sc.find_children("*", "DirectionalLight3D", true, false):
				if (n as DirectionalLight3D).is_visible_in_tree():
					_soleil = n
					break
	if not is_instance_valid(_soleil) or not _soleil.is_visible_in_tree():
		return 0.0
	return smoothstep(0.8, 1.15, _soleil.light_energy) * smoothstep(0.75, 0.9, _soleil.light_color.r)

# ---------------------------------------------------------------------- souffle de givre (couche fine, jet de glace)

func _mat_givre() -> ShaderMaterial:
	if not _mats.has("givre"):
		var m := ShaderMaterial.new()
		m.shader = SH_GIVRE
		m.set_shader_parameter("bruit", BRUIT_VAGUE)
		m.set_shader_parameter("formes", ATLAS_GIVRE)
		for i in 6:
			m.set_shader_parameter("c%d" % i, Color(GIVRE_PAL[i]))
		_mats["givre"] = m
	return _mats["givre"]

## Émetteur du souffle de givre (un par jet) : placé chaque image par _vague_placer (repère, sous-pas, plan d'arrêt),
## comme la vague de flammes ; _givre_placer règle en plus l'accroche des cristaux.
func _givre_creer(dbl: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "SouffleGivre"
	p.amount = int(GIVRE_N * (1.2 if dbl else 1.0))
	p.lifetime = GIVRE_VIE
	p.local_coords = false
	p.fixed_fps = 0
	p.interpolate = false
	p.randomness = 0.0
	p.explosiveness = 0.0
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.draw_pass_1 = _quad
	p.visibility_aabb = AABB(Vector3.ONE * -14.0, Vector3.ONE * 28.0)
	var pm := ShaderMaterial.new()
	pm.shader = SH_GIVRE_PROC
	var k := GIVRE_TRAINE
	pm.set_shader_parameter("traine", k)
	pm.set_shader_parameter("vitesse", GIVRE_PORTEE * (1.15 if dbl else 1.0) * k / (1.0 - exp(-k * GIVRE_VIE)))
	pm.set_shader_parameter("ecart", 0.13 if dbl else 0.1)
	pm.set_shader_parameter("taille1", 0.62 if dbl else 0.56)
	pm.set_shader_parameter("part_cristaux", GIVRE_CRISTAUX)
	p.process_material = pm
	p.material_override = _mat_givre()
	p.visible = not sans_procedural and not OS.get_cmdline_user_args().has("--sans-flux")
	add_child(p)
	p.emitting = true
	_proc.append(p)
	return p

## Accroche des cristaux : sur une cible, un peu devant son centre (à sa surface) ; sur un mur, contre la surface.
func _givre_placer(j: Dictionary) -> void:
	var pm := (j.vague as GPUParticles3D).process_material as ShaderMaterial
	pm.set_shader_parameter("colle", 0.28 if j.cible != null else 0.05)

## Impact de glace (couche fine) : bouffée de givre qui éclate depuis la surface (souffle qui roule et retombe, cristaux
## qui fusent et scintillent), même simulation que le souffle en salve unique. Libérée seule à la fin de sa vie.
func _givre_impact(pos: Vector3, normale: Vector3, f: float) -> void:
	if sans_procedural:
		return
	var p := GPUParticles3D.new()
	p.name = "ImpactGivre"
	p.amount = 30
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.randomness = 0.0
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.draw_pass_1 = _quad
	p.visibility_aabb = AABB(Vector3.ONE * -4.0, Vector3.ONE * 8.0)
	var pm := ShaderMaterial.new()
	pm.shader = SH_GIVRE_PROC
	var b := base_vers(normale if normale.length() > 0.01 else Vector3.UP)
	var kf := sqrt(f)
	pm.set_shader_parameter("vitesse", 4.5 * kf)
	pm.set_shader_parameter("traine", 3.5)
	pm.set_shader_parameter("ecart", 1.15)
	pm.set_shader_parameter("taille0", 0.08 * kf)
	pm.set_shader_parameter("taille1", 0.42 * kf)
	pm.set_shader_parameter("lourd", 1.4)
	pm.set_shader_parameter("turb", 2.0)
	pm.set_shader_parameter("part_cristaux", 0.4)
	pm.set_shader_parameter("prec_o", pos)
	pm.set_shader_parameter("prec_base", b)
	pm.set_shader_parameter("pas", 0.0)
	p.process_material = pm
	p.material_override = _mat_givre()
	add_child(p)
	p.global_transform = Transform3D(b, pos)
	p.emitting = true
	_proc.append(p)
	get_tree().create_timer(p.lifetime + 0.2, false).timeout.connect(p.queue_free)

func _mat_aura(ecole: String, forme := 0) -> ShaderMaterial:
	var cle := "a%s|%d" % [ecole, forme]
	if not _mats.has(cle):
		var m := ShaderMaterial.new()
		m.shader = SH_AURA
		var pal: Array = AURA_PAL.get(ecole, AURA_PAL.feu)
		for i in 6:
			m.set_shader_parameter("c%d" % i, Color(pal[i]))
		m.set_shader_parameter("ecole", AURA_ECOLE.get(ecole, 0))
		m.set_shader_parameter("forme", forme)
		m.set_shader_parameter("eclat", {"feu": 1.45, "glace": 1.3, "electricite": 1.6, "tenebres": 1.25}.get(ecole, 1.3))
		_mats[cle] = m
	return _mats[cle]

## Carré procédural (magie_aura.gdshader) sous `parent` ; rayon en mètres (paramètre d'instance, mis à jour par l'appelant).
func _aura_fine(parent: Node3D, ecole: String, rayon: float, forme := 0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.visible = not sans_procedural and not OS.get_cmdline_user_args().has("--sans-aura")
	mi.mesh = _quad
	mi.material_override = _mat_aura(ecole, forme)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	mi.set_instance_shader_parameter("rayon", rayon)
	mi.set_instance_shader_parameter("graine", rng.randf() * 10.0)
	mi.set_instance_shader_parameter("force", 1.0)
	parent.add_child(mi)
	_proc.append(mi)
	return mi

## Bouffée procédurale (couche fine) : boule de feu d'explosion, givre, plasma ou vortex qui grossit puis s'éteint.
func bouffee(ecole: String, pos: Vector3, r0: float, r1: float, duree: float, forme := 1) -> void:
	if not fin_actif or _bouffees.size() >= 12:
		return
	var mi := _aura_fine(self, ecole, r0, forme)
	mi.position = pos
	_bouffees.append({"mi": mi, "t0": horloge, "duree": duree, "r0": r0, "r1": r1})

func _maj_bouffees() -> void:
	var i := _bouffees.size() - 1
	while i >= 0:
		var b: Dictionary = _bouffees[i]
		var k := (horloge - float(b.t0)) / maxf(float(b.duree), 0.01)
		if k >= 1.0 or not is_instance_valid(b.mi):
			if is_instance_valid(b.mi):
				(b.mi as Node).queue_free()
			_bouffees.remove_at(i)
		else:
			var mi: MeshInstance3D = b.mi
			mi.set_instance_shader_parameter("rayon", lerpf(float(b.r0), float(b.r1), 1.0 - pow(1.0 - k, 2.5)))
			mi.set_instance_shader_parameter("force", clampf(1.25 - k * 1.1, 0.0, 1.25))
		i -= 1

## Cible du jet : ce que touche le rayon (corps mobile), sinon l'ennemi le plus proche de l'axe (groupes « ennemis »,
## « cibles_combat », « cibles_magie ») : le jet s'arrête sur lui et la gerbe l'enveloppe.
func _jet_cible(j: Dictionary, o: Vector3, dir: Vector3) -> void:
	var portee := float(j.portee)
	var r := point_vise(j.origine, o, dir, portee)
	var cible: Node3D = null
	var col: Variant = r.get("collider")
	if r.touche and col is Node3D and not (col is StaticBody3D) and not (col is CSGShape3D):
		cible = col
	if r.touche and col is Cassable and String(j.get("ecole", "")) != "soin":      # L5 : objet cassable brisé par le jet
		(col as Cassable).briser_sort(r.pos)
	var lim := o.distance_to(r.pos)
	if cible == null:
		var meilleur := 1e9
		for g in ["ennemis", "cibles_combat", "cibles_magie"]:
			for n in get_tree().get_nodes_in_group(g):
				if not (n is Node3D) or not (n as Node3D).is_visible_in_tree():
					continue
				var c := (n as Node3D).global_position + Vector3.UP * 1.0
				var t := (c - o).dot(dir)
				if t < 0.3 or t > lim + 0.5:
					continue
				var ecart := (o + dir * t).distance_to(c)
				if ecart < 0.9 and t < meilleur:
					meilleur = t
					cible = n
	j.cible = cible
	if cible != null:
		if j.gerbe_cible != cible:
			j.gerbe_bb = boite(cible)
		var bb: AABB = j.gerbe_bb if j.gerbe_cible == cible else boite(cible)
		var centre := cible.global_transform * bb.get_center()
		var t2 := maxf((centre - o).dot(dir), 0.3)
		j.fin_pos = o + dir * t2
		j.touche = true
		j.normale = -dir
	else:
		j.fin_pos = r.pos
		j.touche = r.touche
		j.normale = r.normale

func _jet_gerbe(j: Dictionary) -> void:
	if ImpactCorps.jet_gerbe(self, j):   # le corps visé prend feu depuis sa surface (scripts/magie/impact_corps.gd)
		return
	# gerbe qui ENVELOPPE le corps de la cible (flammes, givre, étincelles, fumée obscure sur toute la silhouette)
	var cible: Variant = j.cible
	if j.gerbe_cible != cible:
		for p in j.gerbe:
			arreter(p)
		j.gerbe = []
		j.gerbe_cible = cible
		if cible != null and valide(cible):
			var bb: AABB = j.gerbe_bb
			var ext := (bb.size * 0.45).max(Vector3(0.1, 0.2, 0.1))
			var exs := Vector3(snappedf(ext.x, 0.05), snappedf(ext.y, 0.05), snappedf(ext.z, 0.05))
			var noms: Array = {"feu": ["feu_gerbe", "feu_gerbe_braise"], "glace": ["glace_gerbe", "glace_gerbe_cristal"],
				"electricite": ["elec_gerbe"], "tenebres": ["ten_gerbe", "ten_gerbe_lueur"]}.get(j.ecole, [])
			if j.ecole == "electricite" and j.get("faisceau") != null:
				noms = []   # arc à faisceau : les fourches de la décharge sautent sur le corps (plus de traits droits étirés)
			for nom in noms:
				var p := emettre(nom, null, Transform3D.IDENTITY, true, 1.4 if j.dbl else 1.0, -1.0, _pm(nom, PresetsMagie.R[nom], {"ext": exs}))
				if p != null:
					j.gerbe.append(p)
			var deja := false   # double incantation : une seule enveloppe procédurale par cible
			for autre in _jets.values():
				if autre != j and autre.gerbe_cible == cible:
					for x in autre.gerbe:
						if is_instance_valid(x) and (x as Node).has_meta("gerbe_fine"):
							deja = true
			if fin_actif and j.ecole in ["feu", "glace"] and not deja:
				# couche fine : la cible est ENVELOPPÉE de flammes (ou de givre) procédurales, posées devant son corps
				var g := _aura_fine(self, j.ecole, maxf(bb.size.y, 0.6) * 0.62 * (1.2 if j.dbl else 1.0))
				g.set_instance_shader_parameter("avance", maxf(bb.size.x, bb.size.z) * 0.45)
				g.set_meta("gerbe_fine", true)
				g.set_meta("rayon0", maxf(bb.size.y, 0.6) * 0.62 * (1.2 if j.dbl else 1.0))
				j.gerbe.append(g)
	if cible != null and valide(cible):
		var centre: Vector3 = (cible as Node3D).global_transform * (j.gerbe_bb as AABB).get_center()
		for p in j.gerbe:
			if is_instance_valid(p):
				p.position = centre
				if (p as Node).has_meta("gerbe_fine"):
					# le motif de l'enveloppe est en pixels de la couche : cible PROCHE de l'œil = grand carré d'un grain
					# fin → rideau de points devant la cible (« dôme » à 1,75 m). De près : plus petite et plus resserrée.
					var cam := get_viewport().get_camera_3d()
					var kp := clampf((cam.global_position.distance_to(centre) - 1.5) / 2.0, 0.0, 1.0) if cam != null else 1.0
					var mg := p as MeshInstance3D
					mg.set_instance_shader_parameter("rayon", float(mg.get_meta("rayon0")) * lerpf(0.35, 1.0, kp))
					mg.set_instance_shader_parameter("force", clampf((horloge - float(j.debut)) / 0.4, 0.0, 1.0) * lerpf(0.55, 1.0, kp))

func _jet_placer(j: Dictionary) -> void:
	var origine: Node3D = j.origine
	if not valide(origine):
		return
	var o := origine.global_position
	var dir: Vector3 = j.dir
	if horloge - float(j.t_rayon) > 0.08:
		j.t_rayon = horloge
		_jet_cible(j, o, dir)
	var fin: Vector3 = j.fin_pos
	var l := o.distance_to(fin)
	var vers := (fin - o) / maxf(l, 0.001) if l > 0.05 else dir
	var b := base_vers(vers)
	for p in j.emit:
		if is_instance_valid(p) and not j.suit_bout.has(p):
			p.transform = Transform3D(b, o)
			# les particules s'éteignent DANS la cible : le jet remplit tout le trajet sans la traverser
			if p.has_meta("v_jet"):
				var vie := clampf(l / float(p.get_meta("v_jet")), 0.08, 3.0)
				if absf(p.lifetime - vie) > vie * 0.18:
					p.lifetime = vie
	# drain : les particules partent de la cible et remontent vers la main
	for p in j.suit_bout:
		if is_instance_valid(p):
			p.transform = Transform3D(base_vers(o - fin), fin)
			var vie := clampf(l / 5.75, 0.1, 2.0)
			if absf(p.lifetime - vie) > 0.15:
				p.lifetime = vie
	# inertie : le bout visuel suit la visée avec un retard (fluide), la naissance reste collée à la paume
	var dt_j := clampf(horloge - float(j.t_maj), 0.0, 0.1)
	j.t_maj = horloge
	var dv: Vector3 = j.dir_vis
	if dv == Vector3.ZERO:
		dv = vers
	dv = dv.slerp(vers, 1.0 - exp(-dt_j * 7.0)).normalized()
	if dv.angle_to(vers) > 0.4:   # au plus ~23° de traîne, même en tournant très vite
		dv = vers.slerp(dv, 0.4 / dv.angle_to(vers)).normalized()
	j.dir_vis = dv
	if j.flux != null and is_instance_valid(j.flux):
		var fx: MeshInstance3D = j.flux
		var kl := 1.25 if j.dbl else 1.0
		fx.transform = Transform3D(b, o)
		# contre un mur ou le sol, le flux s'arrête un peu avant la surface (sinon la profondeur le coupe net) et
		# s'y étale ; l'éclaboussure procédurale (_jet_eclabousse) lèche la surface
		var lv := maxf(l - (0.3 if j.touche and j.cible == null else 0.0), 0.1)
		fx.set_instance_shader_parameter("longueur", lv)
		fx.set_instance_shader_parameter("bout", b.transposed() * (dv * lv))
		# feu : cône de SPRAY bien ouvert (≈ 25° au sommet), les bouffées débordent encore un peu
		var rr := 0.6 if j.ecole == "tenebres" else clampf(l * tan(deg_to_rad(float(j.ecart) * 0.5)) * (2.4 if j.ecole == "feu" else 1.4), 0.55 if j.ecole == "feu" else 0.25, 1.3 if j.ecole == "feu" else 0.8)
		fx.set_instance_shader_parameter("r0", {"tenebres": 0.04, "feu": 0.045}.get(j.ecole, 0.02) * kl)
		# double feu : le spray est déjà large, à peine plus ouvert (sinon un mur de flammes masque toute la visée)
		fx.set_instance_shader_parameter("r1", rr * (kl if j.ecole != "feu" else (1.08 if j.dbl else 1.0)))
		# au contact d'une surface, la flamme s'étale (moins sur un corps : on doit voir la cible)
		var et := 0.0
		if j.touche:
			et = 0.55 if j.cible != null else 1.0
		fx.set_instance_shader_parameter("etale", lerpf(float(fx.get_meta("etale", 0.0)), et, 1.0 - exp(-dt_j * 8.0)))
		fx.set_meta("etale", lerpf(float(fx.get_meta("etale", 0.0)), et, 1.0 - exp(-dt_j * 8.0)))
		fx.set_instance_shader_parameter("force", clampf((horloge - float(j.debut)) / 0.12, 0.0, 1.0))
	if j.vague != null and is_instance_valid(j.vague):
		_vague_placer(j, o, b, fin, vers)
		if j.ecole == "glace":
			_givre_placer(j)
	if j.get("decharge") != null and is_instance_valid(j.decharge):
		_decharge_placer(j, o, l)
	if j.get("faisceau") != null and is_instance_valid(j.faisceau):
		_faisceau_placer(j, o, l)
	if not j.bouclier.is_empty():
		var d: Dictionary = j.bouclier
		d.pos = o + dir * 0.35
		d.base = GestionMagie.base_normale(dir)
	if j.flash != null and is_instance_valid(j.flash):
		(j.flash as Node3D).transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.012, 0.026) * (1.3 if j.dbl else 1.0)), o)
	_jet_gerbe(j)
	_jet_eclabousse(j, fin)
	# feu / glace / électricité : léchage au point touché
	if j.touche and horloge - float(j.t_bout) > 0.12:
		j.t_bout = horloge
		var bn := base_normale(j.normale)
		match j.ecole:
			"feu":
				emettre("feu_lechage", null, Transform3D(bn, fin), false)
			"glace":
				emettre("glace_bouffee", null, Transform3D(bn, fin), false)
			"electricite":
				# avec le faisceau (couche fine), les étincelles de la décharge (genre 2, ramifiées) suffisent : les
				# traits droits étirés de l'ancien système faisaient des bâtons blancs autour de la cible
				if j.get("faisceau") == null:
					emettre("elec_etincelles", null, Transform3D(bn, fin), false, 0.7)
	# lumière : forte sur la main (un peu devant, pour éclairer main et sol) et à l'arrivée, couleur de l'école
	var c: Color = LUMIERE[j.ecole]
	var kd := 1.2 if j.dbl else 1.0   # deux jets = deux lumières : multiplicateur modéré (neige surexposée sinon)
	var sc := 1.0
	if j.ecole == "electricite":
		sc = 0.55 + 0.9 * rng.randf()
	elif j.ecole == "feu":
		sc = 0.9 + 0.15 * sin(horloge * 21.0) * sin(horloge * 6.0)
	var id := origine.get_instance_id()
	lumiere("aura%d" % id, o + vers * 0.5, c, 5.0 * kd * sc, 7.5 + 1.5 * kd, 9.0)
	lumiere("jet%d" % id, fin - vers * minf(0.7, l * 0.3) + Vector3.UP * 0.3, c, 7.0 * kd * sc, 7.0 + 2.0 * kd, 8.0)
	_teinte_demande(j.ecole, 1.0 if not j.dbl else 1.4)

## Couche fine : flammes (ou givre) procédurales qui lèchent la surface touchée par le jet (mur, sol), hors cible.
func _jet_eclabousse(j: Dictionary, fin: Vector3) -> void:
	var veut: bool = fin_actif and (j.flux != null or j.vague != null) and j.touche and j.cible == null and j.ecole in ["feu", "glace", "soin"]
	var e: Variant = j.eclabousse
	if not veut:
		if e != null and is_instance_valid(e):
			(e as Node).queue_free()
		j.eclabousse = null
		return
	if e == null or not is_instance_valid(e):
		e = _aura_fine(self, j.ecole, 0.4 * (1.2 if j.dbl else 1.0))
		j.eclabousse = e
	var mi: MeshInstance3D = e
	var n: Vector3 = j.normale
	mi.position = fin + n * 0.12 + Vector3.UP * 0.1
	mi.set_instance_shader_parameter("force", clampf((horloge - float(j.debut)) / 0.3, 0.0, 1.0))

func _jet_arreter(j: Dictionary) -> void:
	if j.get("eclabousse") != null and is_instance_valid(j.eclabousse):
		(j.eclabousse as Node).queue_free()
	j.eclabousse = null
	for p in j.emit:
		arreter(p)
	for p in j.gerbe:
		arreter(p)
	j.gerbe = []
	eclair_fin(j.eclair)
	if j.flash != null and is_instance_valid(j.flash):
		(j.flash as Node).queue_free()
	j.flash = null
	if j.flux != null and is_instance_valid(j.flux):
		(j.flux as Node).queue_free()
	j.flux = null
	if j.get("vague") != null and is_instance_valid(j.vague):
		# les bouffées déjà parties finissent leur vie (le jet s'éteint au bout, pas d'un coup)
		var vg: GPUParticles3D = j.vague
		vg.emitting = false
		get_tree().create_timer(VAGUE_VIE + 0.15, false).timeout.connect(vg.queue_free)
	j.vague = null
	_decharge_arreter(j)
	if j.get("faisceau") != null and is_instance_valid(j.faisceau):
		(j.faisceau as Node).queue_free()
	j.erase("faisceau")
	if not j.bouclier.is_empty():
		j.bouclier.duree = 0.0

func _maj_jets() -> void:
	for id in _jets.keys():
		var j: Dictionary = _jets[id]
		if not valide(j.origine) or horloge - float(j.vu) > 0.2:
			_jet_arreter(j)
			_jets.erase(id)
		else:
			_jet_placer(j)

# ====================================================================== projectiles

func projectile_visuel(ecole: String, forme: String) -> Node3D:
	ecole = _ecole_ok(ecole)
	var racine := Node3D.new()
	racine.name = "ProjectileMagie"
	var visuel := Node3D.new()
	visuel.name = "Visuel"
	racine.add_child(visuel)
	var pal: Array = PresetsMagie.R[PresetsMagie.de(ecole, "trainee")].rampe
	var dbl: bool = _double.get(ecole, false)
	var k := 1.4 if dbl else 1.0
	var coeur: Array = []
	match forme:
		"eclat", "lance":
			var lance := forme == "lance"
			var cp := "glace" if ecole == "glace" else ("tenebres" if ecole == "tenebres" else ecole)
			var mi := MeshInstance3D.new()
			mi.mesh = _mesh_eclat
			mi.material_override = _mat_cristal(cp)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.scale = (Vector3(1.6, 1.6, 4.0) if lance else Vector3(1.3, 1.3, 1.7)) * k
			visuel.add_child(mi)
			if lance:
				# cristaux latéraux en couronne vers l'arrière (lance de givre massive)
				for i in (8 if dbl else 6):
					var s := MeshInstance3D.new()
					s.mesh = _mesh_eclat
					s.material_override = mi.material_override
					s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					var a := TAU * i / (8.0 if dbl else 6.0)
					var lg := 1.1 if i % 2 == 0 else 0.75
					s.transform = Transform3D(Basis.from_euler(Vector3(sin(a) * 0.45, cos(a) * 0.45, 0)).scaled(Vector3(0.7, 0.7, lg) * k), Vector3(cos(a) * 0.16, sin(a) * 0.16, 0.35 + 0.2 * float(i % 2)) * k)
					visuel.add_child(s)
		"trait" when fin_actif:
			_aura_fine(visuel, "tenebres" if ecole == "tenebres" else ecole, 0.24 * k, 1)
			_boule(visuel, 0.07 * k, _mat_coeur(Color("#06030c"), false, 1.0))
			if ecole == "tenebres":
				coeur.append(emettre("ten_coeur", visuel, Transform3D.IDENTITY, true))
		"boule", "orbe" when fin_actif:
			_aura_fine(visuel, ecole, (0.3 if forme == "boule" else 0.18) * k, 1)
			if ecole == "feu":
				coeur.append(emettre("feu_boule_coeur", visuel, Transform3D.IDENTITY, true))
			elif ecole == "tenebres":
				coeur.append(emettre("ten_coeur", visuel, Transform3D.IDENTITY, true))
		"trait":
			_boule(visuel, 0.15 * k, _mat_coeur(Color(pal[2]).darkened(0.7), false, 1.0))
			_boule(visuel, 0.28 * k, _mat_coeur(Color(pal[1], 0.6), true, 1.6))
			_boule(visuel, 0.42 * k, _mat_coeur(Color(pal[2], 0.3), true, 1.2))
			if ecole == "tenebres":
				coeur.append(emettre("ten_coeur", visuel, Transform3D.IDENTITY, true))
		_:   # "boule", "orbe"
			_boule(visuel, (0.17 if forme == "boule" else 0.1) * k, _mat_coeur(Color(pal[0]), true, 1.8))
			_boule(visuel, (0.3 if forme == "boule" else 0.17) * k, _mat_coeur(Color(pal[2], 0.5), true, 1.2))
			if forme == "boule":
				_boule(visuel, 0.42 * k, _mat_coeur(Color(pal[3] if pal.size() > 3 else pal[2], 0.25), true, 1.1))
			if ecole == "feu":
				coeur.append(emettre("feu_boule_coeur", visuel, Transform3D.IDENTITY, true))
			elif ecole == "tenebres":
				coeur.append(emettre("ten_coeur", visuel, Transform3D.IDENTITY, true))
	if _projectiles.size() >= MAX_PROJECTILES:
		refus += 1
	else:
		var e := {"noeud": racine, "visuel": visuel, "ecole": ecole, "forme": forme, "emit": [], "coeur": coeur, "prec": null, "entre": false, "eclair": {}, "dbl": dbl}
		if forme in ["eclat", "lance"]:
			# cristal : sa queue dépasse de 0,25 × sa longueur DERRIÈRE le point de départ. Né dans la paume (~0,5 m de
			# l'œil), l'éclat (0,43 m de queue) ou la lance (1 m) traversait le plan proche de la caméra pendant la
			# première image : grand triangle bleu uni sur l'écran. Il naît donc petit et grandit à mesure qu'il
			# avance (_cristal_echelle) : la queue ne repasse jamais derrière la paume.
			e.queue = 0.25 * (4.0 if forme == "lance" else 1.7) * k
			e.depart = null
			visuel.scale = Vector3.ONE * CRISTAL_GERME
		_projectiles.append(e)
		if ecole == "electricite":
			e.eclair = eclair(visuel, "electricite", 1.0, -1.0, 0.05, _gen_orbe_arcs.bind(0.12 * k))
	return racine

## Échelle d'un projectile cristal (éclat, lance) : il grandit depuis la paume, sa queue (e.queue, m) ne dépasse jamais
## le point de départ (+ 5 cm). Pleine taille après ~0,4 m (éclat) / ~1 m (lance) : une image ou deux à 30 m/s.
func _cristal_echelle(e: Dictionary, pos: Vector3) -> float:
	if not e.has("queue"):
		return 1.0
	var cam := get_viewport().get_camera_3d()
	if e.depart == null:
		e.depart = pos
		# lancé par le joueur (né contre l'œil) : la taille suit aussi la distance à l'œil (voir plus bas)
		e.pres_oeil = cam != null and cam.global_position.distance_to(pos) < 1.2
	var ech := clampf(((pos - (e.depart as Vector3)).length() + 0.05) / float(e.queue), CRISTAL_GERME, 1.0)
	if e.get("pres_oeil", false) and cam != null:
		# à 34 m/s, l'éclat est encore à ~1-2 m de l'œil pendant ses 2 premières images : à pleine taille il couvrait un
		# grand pan d'écran près de la main. Il grandit jusqu'à CRISTAL_OEIL m de l'œil (taille apparente ~constante).
		ech = minf(ech, clampf((cam.global_position.distance_to(pos) - 0.35) / (CRISTAL_OEIL - 0.35), CRISTAL_GERME, 1.0))
	return ech

func _gen_orbe_arcs(r: float) -> Array:
	var traits: Array = []
	for _k in 4:
		var a := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * r * 0.3
		var b := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * r * rng.randf_range(1.0, 2.2)
		traits.append([foudre(a, b, r * 0.3, 3), 1.0, 1.0])
	return traits

func _maj_projectiles() -> void:
	var i := _projectiles.size() - 1
	while i >= 0:
		var e: Dictionary = _projectiles[i]
		var n: Variant = e.noeud
		var vivant: bool = n != null and is_instance_valid(n) and not (n as Node).is_queued_for_deletion()
		if vivant and (n as Node).is_inside_tree():
			var pos: Vector3 = (n as Node3D).global_position
			if not e.entre:
				e.entre = true
				var noms: Array = [PresetsMagie.de(e.ecole, "trainee")]
				if e.ecole == "feu":
					noms.append("feu_trainee_fumee")
					noms.append("feu_trainee_braise")
				elif e.ecole == "glace":
					noms.append("glace_trainee_brume")
					if e.forme == "lance":
						noms.append("glace_trainee_eclats")
				elif e.ecole == "tenebres":
					noms.append("ten_trainee_lueur")
				for nom in noms:
					var p := emettre(nom, null, Transform3D(Basis.IDENTITY, pos), true, 1.5 if e.forme == "lance" or e.dbl else 1.0)
					if p != null:
						e.emit.append(p)
			for p in e.emit:
				if is_instance_valid(p):
					p.position = pos
			var ech := _cristal_echelle(e, pos)
			if e.prec != null:
				var v: Vector3 = pos - (e.prec as Vector3)
				if v.length() > 0.0005:
					var vis: Node3D = e.visuel
					vis.global_basis = base_vers(v).scaled(Vector3.ONE * ech)
			elif ech != 1.0:
				(e.visuel as Node3D).scale = Vector3.ONE * ech
			e.prec = pos
			var c: Color = LUMIERE[e.ecole]
			lumiere("proj%d" % (n as Node).get_instance_id(), pos, c, 3.6 if e.forme in ["boule", "orbe", "trait"] else 2.2, 6.0, 3.0)
		elif not vivant or e.entre:
			for p in e.emit + e.coeur:
				arreter(p)
			eclair_fin(e.eclair)
			_projectiles.remove_at(i)
		i -= 1

# ====================================================================== impacts

func impact(ecole: String, position: Vector3, normale: Vector3, force: float) -> void:
	ecole = _ecole_ok(ecole)
	if ImpactCorps.impact(self, ecole, position, normale, force):   # dans un corps : rendu sur sa surface (impact_corps.gd)
		return
	var f := clampf(force, 0.3, 3.0)
	var b := base_normale(normale)
	var xf := Transform3D(b.scaled(Vector3.ONE * sqrt(f)), position)
	var c: Color = LUMIERE[ecole]
	var kn := clampf(0.6 + 0.4 * f, 0.5, 1.6)
	match ecole:
		"feu":
			bouffee("feu", position + b.y * 0.2, 0.12, 0.55 * sqrt(f), 0.42)
			emettre("feu_impact", null, xf, false, kn)
			emettre("feu_impact_braise", null, xf, false, kn)
			emettre("feu_impact_fumee", null, xf, false, kn)
			if not fin_actif:   # couche fine : la boule procédurale remplace l'onde en anneau
				disque(position, normale, 0.1, 1.7 * f, 0.45, {"couleur": "#ec6a1f", "coeur": "#fff0a8", "anneau": 0.85, "epaisseur": 0.14, "texels": 40.0})
		"glace":
			bouffee("glace", position + b.y * 0.15, 0.1, 0.5 * sqrt(f), 0.5)
			emettre("glace_impact", null, xf, false, kn)
			emettre("glace_impact_eclats", null, xf, false, kn)
			emettre("glace_impact_brume", null, xf, false, kn)
			emettre("glace_impact_poudre", null, xf, false, kn)
			if fin_actif:
				_givre_impact(position, normale, f)
			disque(position, normale, 0.1, 1.3 * f, 0.35, {"couleur": "#5f9fe8", "coeur": "#e8f6ff", "anneau": 0.85, "epaisseur": 0.1, "texels": 40.0})
			# cristaux qui JAILLISSENT de l'impact
			for k in 6 + int(f * 3.0):
				var a := rng.randf() * TAU
				var off := (b.x * cos(a) + b.z * sin(a)) * rng.randf_range(0.05, 0.4) * f
				var axe := (b.y + off.normalized() * rng.randf_range(0.4, 1.0)).normalized()
				pic("glace", position + off, axe, rng.randf_range(0.06, 0.12) * f, rng.randf_range(0.35, 0.8) * f, k * 0.015, 0.1, horloge + 1.3 + rng.randf() * 0.4)
		"electricite":
			bouffee("electricite", position + b.y * 0.15, 0.1, 0.45 * sqrt(f), 0.28)
			emettre("elec_impact", null, xf, false, kn)
			_decharge_ponctuelle(position, position + normale * 0.05, 0.26, 0.0, int(28 + 10 * f), sqrt(f), true, normale)
			disque(position, normale, 0.1, 1.4 * f, 0.3, {"couleur": "#7a7af0", "coeur": "#f0f2ff", "anneau": 0.9, "epaisseur": 0.06, "texels": 48.0, "eclat": 1.8})
			var centre := position + b.y * 0.05
			eclair(null, "electricite", 2.0, 0.3, 0.05, func() -> Array:
				var traits: Array = []
				for _k in 7:
					var a := rng.randf() * TAU
					var fin := centre + (b.x * cos(a) + b.z * sin(a)) * rng.randf_range(0.6, 1.4) * f + b.y * rng.randf_range(0.0, 0.4)
					foudre_ramifiee(traits, centre, fin, 0.12 * f, 1.0, 1, 4)
				return traits)
		"tenebres":
			bouffee("tenebres", position + b.y * 0.2, 0.55 * sqrt(f), 0.08, 0.55)   # implosion
			emettre("ten_impact", null, xf, false, kn)
			emettre("ten_impact_sombre", null, xf, false, kn)
			emettre("ten_impact_eclats", null, xf, false, kn)
			disque(position, normale, 0.1, 1.0 * f, 0.5, {"couleur": "#5a1a8a", "coeur": "#0c0614", "anneau": 0.8, "epaisseur": 0.15, "spirale": 0.8, "texels": 40.0}, true)
			for k in 4 + int(f * 2.0):
				var a := rng.randf() * TAU
				var off := (b.x * cos(a) + b.z * sin(a)) * rng.randf_range(0.05, 0.4) * f
				var axe := (b.y + off.normalized() * rng.randf_range(0.3, 0.9)).normalized()
				pic("tenebres", position + off, axe, rng.randf_range(0.03, 0.06) * f, rng.randf_range(0.25, 0.55) * f, k * 0.015, 0.1, horloge + 0.9 + rng.randf() * 0.3)
		"soin":
			emettre("soin_impact", null, xf, false, kn)
			disque(position, normale, 0.2, 1.0 * f, 0.9, {"couleur": "#b8d060", "coeur": "#fff4c0", "anneau": 0.85, "epaisseur": 0.08, "runes": 0.8, "texels": 40.0})
		"protection":
			emettre("prot_impact", null, xf, false, kn)
			disque(position, normale, 0.3, 1.0 * f, 0.6, {"couleur": "#7ab0d8", "coeur": "#eaf8ff", "anneau": 0.85, "epaisseur": 0.08, "runes": 1.0, "texels": 40.0})
	lumiere("impact%d" % rng.randi(), position + b.y * 0.4, c, 7.0 * clampf(f, 0.6, 2.0), 7.0 + 2.0 * f, 6.0, 0.45)

# ====================================================================== zones

func zone(ecole: String, position: Vector3, rayon: float, duree: float) -> void:
	ecole = _ecole_ok(ecole)
	var r := maxf(rayon, 0.3)
	var d := maxf(duree, 0.3)
	var z := {"ecole": ecole, "pos": position, "r": r, "duree": d, "t0": horloge, "emit": [], "prochain": horloge + 0.1, "fini": false, "eclair": {}}
	var rq := snappedf(r, 0.25)
	var base := Transform3D(Basis.IDENTITY, position)
	var kz := clampf(r / 2.5, 0.5, 2.0)
	match ecole:
		"feu":
			# explosion DANS un corps (boule de feu) : le souffle l'entoure déjà (ImpactCorps.impact) ; pas de boule posée devant
			if not ImpactCorps.zone_sur_corps(self, position):
				bouffee("feu", position + Vector3.UP * 0.6, 0.4, r * 0.75, 0.7)
				emettre("feu_explosion", null, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * kz), position + Vector3.UP * 0.4), false, kz)
			emettre("feu_explosion_fumee", null, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * kz), position + Vector3.UP * 0.5), false, kz)
			emettre("feu_impact_braise", null, base, false, 1.5)
			disque(position, Vector3.UP, 0.2, r * 1.15, 0.55, {"couleur": "#ec6a1f", "coeur": "#fff0a8", "anneau": 0.88, "epaisseur": 0.08, "texels": 64.0})
			disque(position, Vector3.UP, r, r, d, {"couleur": "#5a1a1c", "coeur": "#b3341f", "anneau": 0.95, "epaisseur": 0.05, "remplissage": 0.35, "texels": 48.0, "eclat": 1.0}, false, false, 0.3)
			for nom in ["feu_sol", "feu_sol_braise"]:
				var pd: Dictionary = PresetsMagie.R[nom]
				var p := emettre(nom, null, base, true, kz, -1.0, _pm(nom, pd, {"r": rq}))
				if p != null:
					z.emit.append(p)
		"glace":
			emettre("glace_nova_souffle", null, Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.25), false, kz, r / 6.0)
			disque(position, Vector3.UP, 0.2, r * 1.1, 0.45, {"couleur": "#a8d8f8", "coeur": "#e8f6ff", "anneau": 0.9, "epaisseur": 0.07, "texels": 64.0, "eclat": 1.6})
			disque(position, Vector3.UP, r, r, d, {"couleur": "#5f9fe8", "coeur": "#e8f6ff", "anneau": 0.94, "epaisseur": 0.04, "remplissage": 0.3, "runes": 0.5, "texels": 64.0, "eclat": 0.9}, false, false, 0.25)
			for nom in ["glace_nova_brume", "glace_scintille"]:
				var pd: Dictionary = PresetsMagie.R[nom]
				var p := emettre(nom, null, base, true, kz, -1.0, _pm(nom, pd, {"r": rq}))
				if p != null:
					z.emit.append(p)
			var nb := clampi(int(r * 7.0), 8, 32)
			for k in nb:
				var anneau := 0.55 if k % 3 == 0 else 0.92
				var a := TAU * k / nb + rng.randf_range(-0.15, 0.15)
				var dist := r * anneau * rng.randf_range(0.85, 1.05)
				var off := Vector3(cos(a), 0, sin(a)) * dist
				var axe := (Vector3.UP + off.normalized() * rng.randf_range(0.35, 0.8)).normalized()
				var h := rng.randf_range(0.6, 1.5) * (1.15 - anneau * 0.3) * kz
				pic("glace", position + off, axe, h * rng.randf_range(0.18, 0.28), h, dist / r * 0.22, 0.18, horloge + d - 0.3)
		"electricite":
			disque(position, Vector3.UP, 0.2, r, 0.3, {"couleur": "#7a7af0", "coeur": "#f0f2ff", "anneau": 0.9, "epaisseur": 0.06, "texels": 64.0, "eclat": 1.8})
			disque(position, Vector3.UP, r, r, d, {"couleur": "#4a3ad0", "coeur": "#b4c0ff", "anneau": 0.93, "epaisseur": 0.05, "remplissage": 0.12, "runes": 0.9, "texels": 64.0, "tourne": 0.1, "eclat": 1.4}, false, false, 0.2)
			var pd: Dictionary = PresetsMagie.R["elec_sol"]
			var p := emettre("elec_sol", null, base, true, kz, -1.0, _pm("elec_sol", pd, {"r": rq}))
			if p != null:
				z.emit.append(p)
			z.eclair = eclair(null, "electricite", 1.0, d, 0.07, _gen_anneau_arcs.bind(position, r))
		"tenebres":
			emettre("ten_eruption", null, base, false, kz, -1.0, _pm("ten_eruption", PresetsMagie.R["ten_eruption"], {"r": snappedf(r * 0.6, 0.25)}))
			emettre("ten_impact_sombre", null, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * kz), position), false, kz)
			disque(position, Vector3.UP, 0.3, r * 1.1, 0.5, {"couleur": "#9a3ae0", "coeur": "#d08aff", "anneau": 0.88, "epaisseur": 0.08, "texels": 64.0})
			disque(position, Vector3.UP, r, r, d, {"couleur": "#5a1a8a", "coeur": "#0c0614", "anneau": 0.95, "epaisseur": 0.05, "spirale": 0.9, "texels": 64.0, "eclat": 1.0}, true, false, 0.3)
			for nom in ["ten_sol", "ten_sol_sombre"]:
				var pd: Dictionary = PresetsMagie.R[nom]
				var p := emettre(nom, null, base, true, kz, -1.0, _pm(nom, pd, {"r": rq}))
				if p != null:
					z.emit.append(p)
			var nb := clampi(int(r * 6.0), 8, 28)
			for k in nb:
				var a := rng.randf() * TAU
				var dist := r * sqrt(rng.randf_range(0.04, 1.0))
				var off := Vector3(cos(a), 0, sin(a)) * dist
				var axe := (Vector3.UP + off.normalized() * rng.randf_range(0.1, 1.0) + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))).normalized()
				var h := rng.randf_range(0.8, 2.2) * kz
				pic("tenebres", position + off, axe, h * rng.randf_range(0.1, 0.16), h, rng.randf() * 0.25, 0.12, horloge + d - 0.3)
		"soin":
			disque(position, Vector3.UP, r, r, d, {"couleur": "#b8d060", "coeur": "#fff4c0", "anneau": 0.92, "epaisseur": 0.05, "remplissage": 0.15, "runes": 0.9, "texels": 64.0, "tourne": 0.05}, false, false, 0.3)
			var p := emettre("soin_sol", null, base, true, kz, -1.0, _pm("soin_sol", PresetsMagie.R["soin_sol"], {"r": rq}))
			if p != null:
				z.emit.append(p)
		"protection":
			disque(position, Vector3.UP, r, r, d, {"couleur": "#7ab0d8", "coeur": "#eaf8ff", "anneau": 0.92, "epaisseur": 0.05, "remplissage": 0.1, "runes": 1.0, "texels": 64.0, "tourne": -0.05}, false, false, 0.3)
			var p := emettre("prot_sol", null, base, true, kz, -1.0, _pm("prot_sol", PresetsMagie.R["prot_sol"], {"r": rq}))
			if p != null:
				z.emit.append(p)
	lumiere("zone%d" % rng.randi(), position + Vector3.UP * 0.8, LUMIERE[ecole], 7.0 * kz, r * 2.5 + 3.0, 8.0, 0.5)
	_zones.append(z)

func _gen_anneau_arcs(centre: Vector3, r: float) -> Array:
	var traits: Array = []
	for _k in 3:
		var a := rng.randf() * TAU
		var a2 := a + rng.randf_range(0.3, 0.9)
		var p0 := centre + Vector3(cos(a), 0.05, sin(a)) * r * 0.95
		var p1 := centre + Vector3(cos(a2), 0.05, sin(a2)) * r * 0.95
		traits.append([foudre(p0, p1, r * 0.06, 4), 1.0, 0.8])
	return traits

func _maj_zones() -> void:
	var i := _zones.size() - 1
	while i >= 0:
		var z: Dictionary = _zones[i]
		var t := horloge - float(z.t0)
		var pos: Vector3 = z.pos
		var r := float(z.r)
		var c: Color = LUMIERE[z.ecole]
		if t >= float(z.duree):
			for p in z.emit:
				arreter(p)
			if z.ecole == "glace":
				var pd: Dictionary = PresetsMagie.R["glace_eclats_zone"]
				emettre("glace_eclats_zone", null, Transform3D(Basis.IDENTITY, pos), false, clampf(r / 2.5, 0.5, 2.0), -1.0, _pm("glace_eclats_zone", pd, {"r": snappedf(r * 0.8, 0.25)}))
			_zones.remove_at(i)
			i -= 1
			continue
		var scint := 0.85 + 0.3 * sin(horloge * 17.0) * sin(horloge * 5.3)
		lumiere("zone_p%d" % i, pos + Vector3.UP * 0.9, c, 2.2 * scint, r * 2.0 + 2.0, 3.0)
		if z.ecole == "electricite" and horloge >= float(z.prochain):
			# tempête statique : éclairs du ciel sur un point du disque
			z.prochain = horloge + rng.randf_range(0.08, 0.22)
			var a := rng.randf() * TAU
			var sol := pos + Vector3(cos(a), 0, sin(a)) * r * sqrt(rng.randf())
			var ciel := sol + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(4.5, 6.5), rng.randf_range(-1.2, 1.2))
			var w := 2.0 if rng.randf() < 0.4 else 1.0
			eclair(null, "electricite", w, 0.14, 0.05, func() -> Array:
				var traits: Array = []
				foudre_ramifiee(traits, ciel, sol, 0.5, w, 3, 5)
				return traits)
			emettre("elec_etincelles", null, Transform3D(Basis.IDENTITY, sol), false, 0.6)
			lumiere("foudre", sol + Vector3.UP * 1.5, Color(0.75, 0.75, 1.0), 6.0, 7.0, 9.0, 0.15)
		i -= 1

# ====================================================================== chaîne d'éclairs

func chaine(ecole: String, points: Array) -> void:
	if points.size() < 2:
		return
	var pts: Array[Vector3] = []
	for p in points:
		pts.append(p)
	var sur_corps := ImpactCorps.points_sur_corps(self, pts)   # les arcs finissent SUR la surface des corps (impact_corps.gd)
	var teinte := "electricite" if ecole == "electricite" or not ARCS.has(ecole) else ecole
	var dbl: bool = _double.get("electricite", false)
	var t0 := horloge
	var pas := 0.06
	# propagation VISIBLE : chaque saut part 0,06 s après le précédent ; arcs épais, ramifiés
	eclair(null, teinte, 3.0 if dbl else 2.0, 0.45 + pas * (pts.size() - 2), 0.05, func() -> Array:
		var traits: Array = []
		var n := clampi(int((horloge - t0) / pas) + 1, 1, pts.size() - 1)
		for i in range(1, n + 1):
			var l := pts[i - 1].distance_to(pts[i])
			# lien qui finit sur un corps : peu de ramifications (les arcs du corps prennent le relais, pas de pelote autour)
			var sc: bool = sur_corps[i]
			foudre_ramifiee(traits, pts[i - 1], pts[i], l * 0.1, 1.0, 1 if sc else 3, 5)
			if not sc:
				foudre_ramifiee(traits, pts[i - 1], pts[i], l * 0.14, 0.6, 1, 5)
		return traits)
	if teinte == "electricite":
		# couche fine : chaque saut CRÉPITE aussi (éclats texturés de la décharge), au moment où l'arc l'atteint
		var total := 0.45 + pas * (pts.size() - 2)
		for i in range(1, pts.size()):
			_decharge_ponctuelle(pts[i - 1], pts[i], total - pas * (i - 1), pas * (i - 1), 36, 1.35 if dbl else 1.0)
	var sp := "elec_impact" if teinte == "electricite" else "violet_etincelles"
	for i in range(1, pts.size()):
		var xf := Transform3D(Basis.IDENTITY, pts[i])
		if i == 1:
			emettre(sp, null, xf, false, 0.5)
		else:
			get_tree().create_timer(pas * (i - 1), false).timeout.connect(func() -> void: emettre(sp, null, xf, false, 0.5))
	lumiere("chaine%d" % rng.randi(), pts[0].lerp(pts[pts.size() - 1], 0.5), LUMIERE.get(ecole, LUMIERE.electricite), 8.0, 9.0, 7.0, 0.45)

# ====================================================================== statuts des cibles

func statut_cible(cible: Node3D, statut: String, duree: float) -> void:
	if ImpactCorps.statut(self, cible, statut, duree):   # rendu sur la surface du corps (scripts/magie/impact_corps.gd)
		return
	if cible == null or not is_instance_valid(cible):
		return
	var cle := "%d:%s" % [cible.get_instance_id(), statut]
	if duree <= 0.0:
		_statut_retirer(cle)
		return
	if _statuts.has(cle):
		_statuts[cle].fin = horloge + duree
		return
	if _statuts.size() >= MAX_STATUTS:
		# le plus proche de sa fin cède sa place
		var pire := ""
		for k in _statuts:
			if pire == "" or _statuts[k].fin < _statuts[pire].fin:
				pire = k
		_statut_retirer(pire)
	var bb := boite(cible)
	var ext := (bb.size * 0.42).max(Vector3(0.08, 0.15, 0.08))
	var s := {"cible": cible, "statut": statut, "fin": horloge + duree, "emit": [], "voiles": [], "eclair": {}, "bb": bb}
	var noms: Array = {"brulure": ["brulure", "brulure_braise"], "gel": ["gel", "gel_brume"], "choc": ["choc"], "corruption": ["corruption", "corruption_lueur", "corruption_eclats"]}.get(statut, [])
	if statut == "choc" and fin_actif:
		noms = []   # couche fine : le choc = arcs ramifiés (_gen_choc) + voile ; plus de bâtons blancs étirés autour du corps
	for nom in noms:
		var pd: Dictionary = PresetsMagie.R[nom]
		var p := emettre(nom, null, Transform3D(Basis.IDENTITY, cible.global_transform * bb.get_center()), true, 1.0, -1.0,
			_pm(nom, pd, {"ext": Vector3(snappedf(ext.x, 0.05), snappedf(ext.y, 0.05), snappedf(ext.z, 0.05))}))
		if p != null:
			s.emit.append(p)
	var voile: Array = {"gel": [1, "#5f9fe8", "#e8f6ff", 0.7, 2], "choc": [3, "#7a7af0", "#f0f2ff", 0.8, 3], "corruption": [4, "#5a1a8a", "#d08aff", 0.6, 0], "brulure": [1, "#b3341f", "#fcb53a", 0.45, 1]}.get(statut, [])
	if not voile.is_empty():
		s.voiles = _voiler(cible, voile[0], Color(voile[1]), Color(voile[2]), voile[3], Vector3.UP, 0.4 if statut == "gel" else 0.0)
	if statut == "choc":
		s.eclair = eclair(null, "electricite", 2.0, -1.0, 0.08, _gen_choc.bind(s))
	_statuts[cle] = s

func _gen_choc(s: Dictionary) -> Array:
	var traits: Array = []
	if not valide(s.cible):
		return traits
	var bb: AABB = s.bb
	var xf: Transform3D = (s.cible as Node3D).global_transform
	for _k in 3:
		var p0 := xf * (bb.position + bb.size * Vector3(rng.randf(), rng.randf(), rng.randf()))
		var p1 := p0 + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.2, 0.45)
		traits.append([foudre(p0, p1, 0.06, 3), 1.0, 1.0])
	return traits

func _statut_retirer(cle: String) -> void:
	var s: Dictionary = _statuts.get(cle, {})
	if s.is_empty():
		return
	for p in s.emit:
		arreter(p)
	eclair_fin(s.eclair)
	_devoiler(s.voiles)
	_statuts.erase(cle)

func _maj_statuts() -> void:
	for cle in _statuts.keys():
		var s: Dictionary = _statuts[cle]
		if horloge >= float(s.fin) or not valide(s.cible):
			_statut_retirer(cle)
			continue
		var centre: Vector3 = (s.cible as Node3D).global_transform * (s.bb as AABB).get_center()
		for p in s.emit:
			if is_instance_valid(p):
				p.position = centre
		if s.statut == "brulure":
			lumiere("statut" + cle, centre, LUMIERE.feu, 1.2 + 0.3 * sin(horloge * 19.0), 3.0, 1.0)
		elif s.statut == "corruption":
			lumiere("statut" + cle, centre, LUMIERE.tenebres, 1.0 + 0.3 * sin(horloge * 5.0), 2.5, 0.8)

## Pose la couche additive magie_voile sur les maillages de `n` (seulement ceux sans material_overlay) ; renvoie
## [[maillage, ancien overlay]] pour la retirer.
func _voiler(n: Node3D, motif: int, couleur: Color, coeur: Color, force: float, axe: Vector3, fond := 0.0) -> Array:
	var res: Array = []
	var liste := n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		liste.append(n)
	for v in liste:
		var mi := v as MeshInstance3D
		if mi.material_overlay != null or not mi.visible or mi.mesh == null:
			continue
		var m := ShaderMaterial.new()
		m.shader = SH_VOILE
		m.set_shader_parameter("couleur", couleur)
		m.set_shader_parameter("coeur", coeur)
		m.set_shader_parameter("force", force)
		m.set_shader_parameter("motif", motif)
		m.set_shader_parameter("fond", fond)
		var g := _grille_de(mi)
		m.set_shader_parameter("grille", g)
		var echelle := mi.global_basis.get_scale().x
		m.set_shader_parameter("cases", 64.0 / maxf(echelle, 0.0001))
		m.set_shader_parameter("gonfle", 0.006 / maxf(echelle, 0.0001))
		var axe_local := (mi.global_basis.inverse() * (n.global_basis * axe)).normalized()
		m.set_shader_parameter("axe", axe_local)
		mi.material_overlay = m
		res.append(mi)
		if res.size() >= 24:
			break
	return res

func _grille_de(mi: MeshInstance3D) -> float:
	var mat: Material = mi.material_override
	if mat == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
		mat = mi.get_active_material(0)
	if mat is ShaderMaterial:
		var v: Variant = (mat as ShaderMaterial).get_shader_parameter("grille")
		if v != null:
			return float(v)
		var sh := (mat as ShaderMaterial).shader
		if sh != null and sh.code.contains("uniform float grille"):
			return 135.0
	return 0.0

func _devoiler(voiles: Array) -> void:
	for mi in voiles:
		if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay is ShaderMaterial and ((mi as MeshInstance3D).material_overlay as ShaderMaterial).shader == SH_VOILE:
			(mi as MeshInstance3D).material_overlay = null

# ====================================================================== enchantements d'arme

func enchant_arme(arme: Node3D, ecole: String, actif: bool) -> void:
	if arme == null or not is_instance_valid(arme):
		return
	var id := arme.get_instance_id()
	if _enchants.has(id):
		if actif and _enchants[id].ecole == ecole:
			return
		_enchant_retirer(id)
	if not actif:
		return
	ecole = _ecole_ok(ecole)
	var bb := boite(arme)
	var axe_i := 0
	for k in 3:
		if bb.size[k] > bb.size[axe_i]:
			axe_i = k
	var axe := Vector3.ZERO
	axe[axe_i] = 1.0
	# la lame : les 3/4 du côté le plus éloigné de l'origine (la poignée est près de l'origine de l'arme)
	var lo := bb.position[axe_i]
	var hi := bb.end[axe_i]
	var vers_haut := absf(hi) >= absf(lo)
	var l := bb.size[axe_i]
	var centre := bb.get_center()
	centre[axe_i] = (hi - l * 0.375) if vers_haut else (lo + l * 0.375)
	var ext := bb.size * 0.5
	ext[axe_i] = l * 0.375
	for k in 3:
		if k != axe_i:
			ext[k] = maxf(ext[k], 0.01)
	var e := {"arme": arme, "ecole": ecole, "emit": [], "voiles": [], "eclair": {}, "centre": centre, "ext": ext, "axe": axe if vers_haut else -axe}
	var noms: Array = {"feu": ["enchant_feu", "enchant_feu_braise"], "glace": ["enchant_glace", "enchant_glace_brume"], "electricite": ["enchant_elec"], "tenebres": ["enchant_ten", "enchant_ten_lueur"], "soin": ["soin_aura"], "protection": ["prot_aura"]}[ecole]
	var echelle := arme.global_basis.get_scale()
	var ext_m := ext * echelle
	for nom in noms:
		var pd: Dictionary = PresetsMagie.R[nom]
		var pm: ParticleProcessMaterial = null
		if String(pd.get("forme", "")) == "boite":
			pm = _pm(nom, pd, {"ext": Vector3(snappedf(ext_m.x, 0.01), snappedf(ext_m.y, 0.01), snappedf(ext_m.z, 0.01))})
		var p := emettre(nom, null, Transform3D(arme.global_basis.orthonormalized(), arme.global_transform * centre), true, 1.0, -1.0, pm)
		if p != null:
			e.emit.append(p)
	var voile: Array = {"feu": [1, "#ec6a1f", "#fff0a8", 0.75], "glace": [2, "#5f9fe8", "#e8f6ff", 0.6], "electricite": [3, "#7a7af0", "#f0f2ff", 0.8], "tenebres": [4, "#7a2ad0", "#d08aff", 0.6], "soin": [0, "#b8d060", "#fff4c0", 0.5], "protection": [0, "#7ab0d8", "#eaf8ff", 0.5]}[ecole]
	e.voiles = _voiler(arme, voile[0], Color(voile[1]), Color(voile[2]), voile[3], e.axe, 0.4)
	if ecole == "electricite":
		e.eclair = eclair(null, "electricite", 1.0, -1.0, 0.06, _gen_lame_arcs.bind(e))
	_enchants[id] = e

func _gen_lame_arcs(e: Dictionary) -> Array:
	var traits: Array = []
	if not valide(e.arme):
		return traits
	var xf: Transform3D = (e.arme as Node3D).global_transform
	var c: Vector3 = e.centre
	var ax: Vector3 = e.axe
	var ext: Vector3 = e.ext
	var demi := absf(ext.dot(ax.abs()))
	var a := xf * (c - ax * demi * rng.randf_range(0.6, 1.0))
	var b := xf * (c + ax * demi * rng.randf_range(0.7, 1.0))
	traits.append([foudre(a, b, 0.015, 4), 1.0, 1.0])
	for _k in 2:
		var o := xf * (c + ax * demi * rng.randf_range(-1.0, 1.0))
		traits.append([foudre(o, o + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.05, 0.12), 0.015, 2), 1.0, 0.8])
	return traits

func _enchant_retirer(id: int) -> void:
	var e: Dictionary = _enchants.get(id, {})
	if e.is_empty():
		return
	for p in e.emit:
		arreter(p)
	eclair_fin(e.eclair)
	_devoiler(e.voiles)
	_enchants.erase(id)

func _maj_enchants() -> void:
	for id in _enchants.keys():
		var e: Dictionary = _enchants[id]
		if not valide(e.arme):
			_enchant_retirer(id)
			continue
		var arme: Node3D = e.arme
		var xf := Transform3D(arme.global_basis.orthonormalized(), arme.global_transform * (e.centre as Vector3))
		for p in e.emit:
			if is_instance_valid(p):
				p.transform = xf
		var scint := 1.0 + (0.2 * sin(horloge * 21.0) if e.ecole == "feu" else (0.5 * rng.randf() - 0.25 if e.ecole == "electricite" else 0.0))
		lumiere("enchant%d" % id, xf.origin, LUMIERE[e.ecole], 1.1 * scint, 2.8, 1.5)

# ====================================================================== réactions entre écoles

func reaction(nom: String, position: Vector3, rayon: float) -> void:
	var r := maxf(rayon, 0.3)
	var kz := clampf(r / 2.0, 0.5, 2.0)
	var base := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * kz), position + Vector3.UP * 0.3)
	var rq := snappedf(r, 0.25)
	match nom:
		"vapeur":
			emettre("vapeur", null, base, false, kz)
			emettre("vapeur_gouttes", null, base, false, kz)
			disque(position, Vector3.UP, 0.2, r * 1.2, 0.5, {"couleur": "#c8d2dc", "coeur": "#f6f8ff", "anneau": 0.88, "epaisseur": 0.07, "texels": 56.0, "eclat": 1.2})
			lumiere("vapeur%d" % rng.randi(), position + Vector3.UP, Color(1.0, 0.9, 0.8), 3.0, r * 2.0 + 2.0, 5.0, 0.4)
		"decharge":
			emettre("glace_impact_eclats", null, base, false, kz)
			emettre("elec_impact", null, base, false, kz)
			disque(position, Vector3.UP, 0.2, r, 0.35, {"couleur": "#5f9fe8", "coeur": "#f0f2ff", "anneau": 0.9, "epaisseur": 0.06, "texels": 64.0, "eclat": 1.8})
			eclair(null, "glace", 1.0, 0.55, 0.05, _gen_radial.bind(position, r, 8, 0.05))
			lumiere("decharge%d" % rng.randi(), position + Vector3.UP * 0.5, Color(0.7, 0.8, 1.0), 8.0, r * 2.0 + 3.0, 9.0, 0.4)
		"decharge_incendiaire":
			emettre("feu_explosion", null, base, false, kz * 0.7)
			emettre("incendiaire_etincelles", null, base, false, kz)
			emettre("feu_impact_fumee", null, base, false, kz)
			disque(position, Vector3.UP, 0.2, r * 1.1, 0.4, {"couleur": "#ec6a1f", "coeur": "#fffbe8", "anneau": 0.88, "epaisseur": 0.08, "texels": 64.0, "eclat": 1.8})
			eclair(null, "feu", 1.0, 0.5, 0.05, _gen_radial.bind(position, r, 7, 0.4))
			lumiere("incendiaire%d" % rng.randi(), position + Vector3.UP * 0.6, Color(1.0, 0.75, 0.45), 9.0, r * 2.0 + 3.0, 9.0, 0.45)
		"cristaux_corrompus":
			var pd: Dictionary = PresetsMagie.R["corrompu_scintille"]
			emettre("corrompu_scintille", null, Transform3D(Basis.IDENTITY, position), false, kz, -1.0, _pm("corrompu_scintille", pd, {"r": rq}))
			emettre("ten_impact_sombre", null, base, false, kz)
			disque(position, Vector3.UP, 0.2, r, 0.5, {"couleur": "#7a5ad0", "coeur": "#e0b0ff", "anneau": 0.9, "epaisseur": 0.07, "texels": 64.0})
			var nb := clampi(int(r * 5.0), 6, 20)
			for k in nb:
				var a := rng.randf() * TAU
				var off := Vector3(cos(a), 0, sin(a)) * r * sqrt(rng.randf_range(0.05, 1.0))
				var axe := (Vector3.UP + off.normalized() * rng.randf_range(0.2, 0.8)).normalized()
				var h := rng.randf_range(0.7, 1.7) * kz
				pic("corrompu", position + off, axe, h * rng.randf_range(0.15, 0.25), h, rng.randf() * 0.2, 0.15, horloge + 2.2)
			lumiere("corrompu%d" % rng.randi(), position + Vector3.UP * 0.6, Color(0.7, 0.45, 1.0), 5.0, r * 2.0 + 2.0, 7.0, 0.8)
		"flammes_obscures":
			var z := {"ecole": "tenebres", "pos": position, "r": r, "duree": 2.0, "t0": horloge, "emit": [], "prochain": INF, "fini": false, "eclair": {}}
			for n2 in ["obscur_sol", "obscur_sombre"]:
				var pd: Dictionary = PresetsMagie.R[n2]
				var p := emettre(n2, null, Transform3D(Basis.IDENTITY, position), true, kz, -1.0, _pm(n2, pd, {"r": rq}))
				if p != null:
					z.emit.append(p)
			emettre("ten_eruption", null, Transform3D(Basis.IDENTITY, position), false, kz * 0.6, -1.0, _pm("ten_eruption", PresetsMagie.R["ten_eruption"], {"r": snappedf(r * 0.5, 0.25)}))
			disque(position, Vector3.UP, r, r, 2.0, {"couleur": "#6a1aa0", "coeur": "#0c0614", "anneau": 0.95, "epaisseur": 0.05, "remplissage": 0.4, "texels": 56.0, "eclat": 1.0}, true, false, 0.3)
			_zones.append(z)
			lumiere("obscur%d" % rng.randi(), position + Vector3.UP * 0.6, Color(0.7, 0.3, 1.0), 5.0, r * 2.0 + 2.0, 7.0, 0.6)
		"arcs_violets":
			emettre("violet_etincelles", null, base, false, kz)
			disque(position, Vector3.UP, 0.2, r, 0.35, {"couleur": "#7a2ad0", "coeur": "#f0d0ff", "anneau": 0.9, "epaisseur": 0.06, "texels": 64.0, "eclat": 1.7})
			eclair(null, "violet", 1.0, 0.6, 0.05, _gen_radial.bind(position, r, 6, 0.6))
			lumiere("violet%d" % rng.randi(), position + Vector3.UP * 0.6, Color(0.7, 0.4, 1.0), 7.0, r * 2.0 + 3.0, 8.0, 0.45)
		_:
			push_warning("EffetsMagie.reaction : réaction inconnue « %s »" % nom)

func _gen_radial(centre: Vector3, r: float, n: int, montee: float) -> Array:
	var traits: Array = []
	var o := centre + Vector3.UP * 0.08
	for _k in n:
		var a := rng.randf() * TAU
		var fin := centre + Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.5, 1.0) + Vector3.UP * rng.randf_range(0.02, montee)
		foudre_ramifiee(traits, o, fin, r * 0.08, 1.0, 1, 4)
	return traits

# ====================================================================== double incantation

func double(ecole: String, actif: bool) -> void:
	ecole = _ecole_ok(ecole)
	_double[ecole] = actif
	if not actif:
		_double.erase(ecole)

func _maj_double() -> void:
	for ecole in _double_vis.keys():
		if not _double.get(ecole, false):
			_double_fin(_double_vis[ecole])
			_double_vis.erase(ecole)
	for ecole in _double:
		var mains: Array = []
		for a in _auras.values():
			if a.ecole == ecole and valide(a.main):
				mains.append(a)
		var v: Dictionary = _double_vis.get(ecole, {})
		if mains.size() < 2:
			if not v.is_empty():
				_double_fin(v)
				_double_vis.erase(ecole)
			continue
		var p0: Vector3 = (mains[0].ancre as Node3D).position
		var p1: Vector3 = (mains[1].ancre as Node3D).position
		var milieu := (p0 + p1) * 0.5
		if v.is_empty():
			v = {"noeud": Node3D.new(), "emit": [], "eclair": {}, "p0": p0, "p1": p1}
			add_child(v.noeud)
			var n: Node3D = v.noeud
			match ecole:
				"tenebres":
					_vortex_main(n, 0.16)
				"glace":
					var p := emettre("glace_double_orbite", n, Transform3D.IDENTITY, true)
					if p != null:
						v.emit.append(p)
				"feu":
					var p := emettre("feu_aura", n, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 2.2), Vector3.ZERO), true, 1.5)
					if p != null:
						v.emit.append(p)
				"electricite":
					v.eclair = eclair(null, "electricite", 2.0, -1.0, 0.05, func() -> Array:
						var t: Array = []
						if not v.get("jette", false):
							foudre_ramifiee(t, v.p0, v.p1, (v.p0 as Vector3).distance_to(v.p1) * 0.15, 2.0, 2, 4)
						return t)
				_:
					var mi := MeshInstance3D.new()
					mi.mesh = _quad_sol
					var m := ShaderMaterial.new()
					m.shader = SH_SOL
					var pal: Array = PresetsMagie.R[PresetsMagie.de(ecole, "trainee")].rampe
					m.set_shader_parameter("couleur", Color(pal[2]))
					m.set_shader_parameter("coeur", Color(pal[0]))
					m.set_shader_parameter("runes", 1.0)
					m.set_shader_parameter("tourne", 0.3)
					m.set_shader_parameter("texels", 32.0)
					m.set_shader_parameter("face_camera", true)
					mi.material_override = m
					mi.scale = Vector3.ONE * 0.14
					n.add_child(mi)
			_double_vis[ecole] = v
		v.p0 = p0
		v.p1 = p1
		# pendant les jets des deux mains, rien entre les mains : le centre de l'écran reste dégagé pour les flux
		v.jette = _jets.has((mains[0].main as Node).get_instance_id()) or _jets.has((mains[1].main as Node).get_instance_id())
		(v.noeud as Node3D).visible = not v.jette
		for p in v.emit:
			if is_instance_valid(p):
				(p as GPUParticles3D).emitting = not v.jette
		(v.noeud as Node3D).position = milieu
		lumiere("double" + ecole, milieu, LUMIERE[ecole], 3.5, 6.0, 6.0)

func _double_fin(v: Dictionary) -> void:
	for p in v.emit:
		arreter(p)
	eclair_fin(v.eclair)
	var n: Node3D = v.noeud
	if is_instance_valid(n):
		# les émetteurs du pool sous ce nœud y retournent avant sa libération
		for e in _emetteurs:
			if is_instance_valid(e.p) and (e.p as Node).get_parent() == n:
				n.remove_child(e.p)
				add_child(e.p)
				e.fin = horloge
		n.queue_free()

# ====================================================================== préchauffage

## Compile une fois chaque réglage (particules hors de vue) : évite l'à-coup du premier sort.
func prechauffer() -> void:
	var loin := Transform3D(Basis.IDENTITY, Vector3(0, -500, 0))
	for nom in PresetsMagie.R:
		var p := emettre(nom, null, loin, false, 0.05, 0.05)
		if p == null:
			break
	pic("glace", loin.origin, Vector3.UP, 0.1, 0.1, 0.0, 0.05, horloge + 0.1)
	pic("tenebres", loin.origin, Vector3.UP, 0.1, 0.1, 0.0, 0.05, horloge + 0.1)
	pic("corrompu", loin.origin, Vector3.UP, 0.1, 0.1, 0.0, 0.05, horloge + 0.1)

## Vitrine pour le préchauffage du RENDU (PrechauffeCombat.vitrine, rendue hors écran par PrechauffeRendu pendant le
## chargement) : un petit émetteur par réglage (shaders de particules + draw passes), les cristaux (maillage d'éclat et
## MultiMesh des pics), un éclair (ImmediateMesh, magie_trait), les disques (magie_sol / magie_sol_mix, plan et face
## caméra), le voile (magie_voile en material_overlay, sur un matériau standard et sur perso.gdshader), les cœurs
## (magie_coeur additif et opaque) et la teinte d'écran (magie_teinte, force 0 = invisible). Sans cela, le premier
## sort payait la compilation de ses pipelines (même cause que « ça rame quand je frappe »). Matériaux tirés des caches
## de ce nœud : ils restent vivants après la vitrine (un shader dont le dernier matériau disparaît serait recompilé).
func vitrine_prechauffe(v: Node3D) -> void:
	if couche != null:
		couche.amorcer(v)
	ImpactCorps.vitrine(self, v)   # émetteurs de surface et voile des corps (scripts/magie/impact_corps.gd)
	var x := -1.0
	var k := 0
	for nom in PresetsMagie.R:
		var d: Dictionary = PresetsMagie.R[nom]
		var p := _nouveau_part()
		p.amount = 4
		p.lifetime = 0.6
		p.preprocess = 0.3
		p.local_coords = bool(d.get("local", false))
		p.process_material = _pm(nom, d)
		if String(d.get("mesh", "quad")) == "eclat":
			p.draw_pass_1 = _mesh_eclat
			p.material_override = _mat_cristal(String(d.get("pal", "glace")))
		else:
			p.material_override = _mat_part(bool(d.get("add", false)), float(d.get("cap", 6.0)), float(d.get("eclat", 1.3)))
		p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
		v.add_child(p)
		p.position = Vector3(x + 0.2 * (k % 10), 0.2 + 0.15 * (k / 10), -0.6)
		p.emitting = true
		k += 1
	# pics de cristal (MultiMesh + données perso)
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _mesh_pic
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * 0.2), Vector3.ZERO))
	mm.set_instance_custom_data(0, Color(1, 1, 0, 0))
	mmi.multimesh = mm
	mmi.material_override = _mat_cristal("glace", true)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(mmi)
	mmi.position = Vector3(0.8, 0.0, 0.0)
	# éclair (même format de sommets que _eclair_dessiner)
	var tr := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.5, 1.2, 0.0)
	var b := Vector3(0.5, 1.3, 0.0)
	var dir := (b - a).normalized()
	for couche in [0.0, 1.0]:
		for s in [[a, -1.0], [a, 1.0], [b, 1.0], [a, -1.0], [b, 1.0], [b, -1.0]]:
			_sommet_trait(im, s[0], dir, couche, s[1], 2.0, 1.0)
	im.surface_end()
	tr.mesh = im
	tr.material_override = _mat_trait("electricite", 2.0)
	tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(tr)
	# disques : plan au sol et face caméra, mélange additif et opaque
	var i := 0
	for face in [false, true]:
		for mix in [false, true]:
			var mi := MeshInstance3D.new()
			mi.mesh = _quad_sol if face else _plan
			var m := ShaderMaterial.new()
			m.shader = SH_SOL_MIX if mix else SH_SOL
			m.set_shader_parameter("face_camera", face)
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.scale = Vector3.ONE * 0.15
			v.add_child(mi)
			mi.position = Vector3(-0.6 + 0.35 * i, 0.9, 0.2)
			i += 1
	# voile (couche additive) sur un matériau standard et sur le shader des personnages
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
		v.add_child(corps)
		corps.position = Vector3(-0.3 + 0.6 * j, 0.5, 0.3)
		var vm := ShaderMaterial.new()   # comme _voiler (qui lit le repère global : la vitrine n'est pas encore dans l'arbre)
		vm.shader = SH_VOILE
		vm.set_shader_parameter("couleur", Color(0.5, 0.8, 1.0))
		vm.set_shader_parameter("force", 0.5)
		corps.material_overlay = vm
	# cœurs des projectiles (magie_coeur_add / magie_coeur)
	_boule(v, 0.1, _mat_coeur(Color("#fcb53a"), true, 1.8)).position = Vector3(0.3, 0.6, 0.0)
	_boule(v, 0.1, _mat_coeur(Color("#5a1a1c"), false, 1.0)).position = Vector3(0.5, 0.6, 0.0)
	# couche fine : flux des jets et auras / boules procédurales (magie_flux, magie_aura), une fois par école
	var fx := _flux_creer("feu")
	remove_child(fx)
	v.add_child(fx)
	fx.visible = true
	fx.position = Vector3(-0.4, 0.4, 0.0)
	fx.set_instance_shader_parameter("longueur", 0.6)
	var vg := _vague_creer(false)
	remove_child(vg)
	v.add_child(vg)
	vg.visible = true
	vg.position = Vector3(0.4, 0.4, 0.0)
	var dc := _decharge_creer(false)
	remove_child(dc)
	v.add_child(dc)
	dc.visible = true
	dc.position = Vector3(0.0, 0.4, 0.0)
	var vgg := _givre_creer(false)
	remove_child(vgg)
	v.add_child(vgg)
	vgg.visible = true
	vgg.position = Vector3(0.6, 0.4, 0.0)
	var fs := _faisceau_creer(false)
	remove_child(fs)
	v.add_child(fs)
	fs.visible = true
	var mf := fs.material_override as ShaderMaterial
	var vo := v.global_position if v.is_inside_tree() else Vector3.ZERO
	mf.set_shader_parameter("arc_o", vo + Vector3(-0.5, 0.8, 0.0))
	mf.set_shader_parameter("arc_c", vo + Vector3(0.0, 0.85, 0.0))
	mf.set_shader_parameter("arc_b", vo + Vector3(0.5, 0.8, 0.0))
	mf.set_shader_parameter("force", 1.0)
	var ia := 0
	for ec in AURA_ECOLE:
		var au := _aura_fine(v, ec, 0.06, ia % 2)
		au.visible = true
		au.position = Vector3(-0.5 + 0.15 * ia, 1.1, 0.0)
		ia += 1
	# teinte d'écran (canvas_item, additive : force 0 = rien d'affiché)
	var calque := CanvasLayer.new()
	calque.layer = 1
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tm := ShaderMaterial.new()
	tm.shader = SH_TEINTE
	tm.set_shader_parameter("force", 0.0)
	r.material = tm
	calque.add_child(r)
	v.add_child(calque)
