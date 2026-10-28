class_name GerbePixels
extends Node3D
## GERBES DE GROS PIXELS CARRÉS (retour des coups, lot L6) : éclats d'os beiges, sang sombre, étincelles filantes, échardes,
## poussière de pierre — chaque éclat est un carré de 3 à 8 px d'écran (shaders/gerbe_pixels*.gdshader), couleur tirée de la
## palette de la matière, freiné par l'air puis retombant (amorti + gravité).
## RÉUTILISABLE (corps à corps aujourd'hui ; la magie peut s'en servir) :
##   GerbePixels.emettre(noeud, point, direction, "os", force)      noeud : n'importe quel nœud dans l'arbre de la scène
##   GerbePixels.MATIERES                                          réglages par matière (ajouter une entrée = une nouvelle gerbe)
##   GerbePixels.force_de(nom_profil_impact)                        "leger" 1 … "finisher" 2,8 (ProfilImpact)
##   GerbePixels.obtenir(noeud)                                     crée le pool à l'avance (chargement, apparition d'un ennemi)
##   GerbePixels.vitrine(parent)                                    préchauffe (PrechauffeCombat.vitrine : shaders compilés)
## Aucune allocation par coup : un seul nœud « GerbesPixels » par scène tient un POOL de TAILLE_POOL émetteurs GPUParticles3D
## de PARTICULES particules chacun (amount ne change jamais : le nombre voulu passe par amount_ratio, sans réallocation) ;
## matériaux de processus (un par matière et par palier de force) et quads partagés, créés une fois. Un coup reprend
## l'émetteur libre (ou le plus ancien), change ses ressources, son repère et relance (restart).
## `direction` = sens principal de la gerbe (normale de la surface + mouvement de la lame) ; l'écart est un cône autour.

const SH_MIX := preload("res://shaders/gerbe_pixels.gdshader")
const SH_ADD := preload("res://shaders/gerbe_pixels_add.gdshader")
const NOM := "GerbesPixels"
const TAILLE_POOL := 16
const PARTICULES := 48
## Seuil du palier « fort » (coup lourd, critique, finisher) : gerbe plus rapide, éclats plus gros, vie plus longue.
const SEUIL_FORT := 1.6

## Réglages par matière : couleurs (palette du jeu, tirées au hasard par éclat), nombre d'éclats d'un coup léger, taille (m,
## avant arrondi en pixels), vitesse (m/s), écart du cône (°), gravité (m/s²), amorti (ralentissement, m/s²), durée (s),
## additif (lumineux : étincelles, avec traînée).
const MATIERES := {
	# os de squelette : blanc cassé et beiges de Palette.OSSEMENT, quelques éclats plus sombres (moelle sèche)
	"os": {"couleurs": ["#efe7d0", "#efe7d0", "#d2c9ad", "#b3aa8f", "#8f8670"], "n": 20, "taille": [0.05, 0.09],
		"vitesse": [1.2, 3.2], "ecart": 60.0, "gravite": 8.0, "amorti": 2.6, "duree": 0.85},
	# draugr : chair desséchée sur l'os — éclats d'os beiges et grumeaux de sang noirci
	"draugr": {"couleurs": ["#d2c9ad", "#b3aa8f", "#8f8670", "#4a1210", "#2e0807"], "n": 15, "taille": [0.045, 0.085],
		"vitesse": [1.2, 3.0], "ecart": 55.0, "gravite": 9.0, "amorti": 2.6, "duree": 0.8},
	# chair vivante (bandits, mage, troll) : sang sombre, en paliers (Sang : sang « Laine rouge » du jeu)
	"sang": {"couleurs": ["#7a1c1c", "#5e0e0c", "#460806", "#2e0504"], "n": 9, "taille": [0.04, 0.075],
		"vitesse": [1.2, 3.0], "ecart": 45.0, "gravite": 12.0, "amorti": 1.8, "duree": 0.7},
	# métal (cotte, casque, umbo, lame contre lame) : étincelles de la palette du feu, filantes
	"etincelles": {"couleurs": ["#fffbe8", "#fff0a8", "#fff0a8", "#fcb53a", "#ec6a1f"], "n": 12, "taille": [0.02, 0.035],
		"vitesse": [2.4, 5.0], "ecart": 60.0, "gravite": 7.0, "amorti": 3.5, "duree": 0.45, "add": true},
	# bois (bouclier, mannequin) : échardes de Palette.PLANCHES / FOIN
	"bois": {"couleurs": ["#947e46", "#7a6636", "#4b3b2b", "#3a2d21"], "n": 12, "taille": [0.04, 0.075],
		"vitesse": [1.3, 3.0], "ecart": 50.0, "gravite": 9.0, "amorti": 2.0, "duree": 0.7},
	# pierre (lame contre un mur) : gravillons de Palette.ROCHE
	"pierre": {"couleurs": ["#8a96ad", "#6d7480", "#565c67", "#41464f"], "n": 8, "taille": [0.035, 0.06],
		"vitesse": [1.2, 2.8], "ecart": 50.0, "gravite": 9.0, "amorti": 2.4, "duree": 0.6},
	# sang coupé (option gore à 0) : poussière de tissu et de chair sèche, neutre
	"poussiere": {"couleurs": ["#8f8670", "#6b6452", "#52453f", "#443a39"], "n": 10, "taille": [0.04, 0.075],
		"vitesse": [1.0, 2.6], "ecart": 55.0, "gravite": 6.0, "amorti": 3.0, "duree": 0.7},
}
const FORCES := {"leger": 1.0, "moyen": 1.3, "lourd": 1.8, "critique": 2.3, "finisher": 2.8}

static var _pms := {}
static var _quad_mix: QuadMesh
static var _quad_add: QuadMesh
static var _instance: GerbePixels
## Compteur d'émissions (tests, mesures).
static var emissions := 0
## Faux = aucune gerbe (mesure de coût : outils/perf_retour_crypte.gd).
static var actif := true
## Temps CPU passé dans les émissions (µs, mesures : outils/perf_retour_crypte.gd).
static var cout_us := 0

var _emetteurs: Array[GPUParticles3D] = []
var _fin := PackedInt64Array()   # instant (ms) où chaque émetteur redevient libre
var _suivant := 0

static func force_de(nom_profil: String) -> float:
	return float(FORCES.get(nom_profil, 1.0))

## Gerbe de la matière `matiere` au point (voir MATIERES) ; `force` multiplie le nombre d'éclats (palier fort au-delà de 1,6).
static func emettre(n: Node, point: Vector3, direction: Vector3, matiere: String, force := 1.0) -> void:
	if not actif or n == null or not n.is_inside_tree():
		return
	var g := obtenir(n)
	if g != null:
		g._emettre(point, direction, matiere, force)

## Pool de la scène courante (créé à la première demande).
static func obtenir(n: Node) -> GerbePixels:
	if is_instance_valid(_instance) and _instance.is_inside_tree():
		return _instance
	if n == null or not n.is_inside_tree():
		return null
	var arbre := n.get_tree()
	var hote: Node = arbre.current_scene if arbre.current_scene != null else arbre.root
	var g := GerbePixels.new()
	g.name = NOM
	hote.add_child(g)
	_instance = g
	return g

func _ready() -> void:
	_preparer_ressources()
	for i in TAILLE_POOL:
		var p := GPUParticles3D.new()
		p.amount = PARTICULES
		p.one_shot = true
		p.emitting = false
		p.explosiveness = 1.0
		p.local_coords = false
		p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.process_material = _pm("os", false)
		p.draw_pass_1 = _quad_mix
		add_child(p)
		_emetteurs.append(p)
	_fin.resize(TAILLE_POOL)
	_fin.fill(0)

func _emettre(point: Vector3, direction: Vector3, matiere: String, force: float) -> void:
	var t_us := Time.get_ticks_usec()
	var m: Dictionary = MATIERES.get(matiere, MATIERES["poussiere"])
	var fort := force >= SEUIL_FORT
	var i := _prendre()
	var p := _emetteurs[i]
	var vie := float(m["duree"]) * (1.2 if fort else 1.0)
	# ressources changées SEULEMENT si différentes (chaque affectation repasse par le serveur de rendu)
	var pm := _pm(matiere if MATIERES.has(matiere) else "poussiere", fort)
	if p.process_material != pm:
		p.process_material = pm
	var q := _quad_add if bool(m.get("add", false)) else _quad_mix
	if p.draw_pass_1 != q:
		p.draw_pass_1 = q
	var ratio := clampf(roundf(float(m["n"]) * force) / PARTICULES, 3.0 / PARTICULES, 1.0)
	if not is_equal_approx(p.amount_ratio, ratio):
		p.amount_ratio = ratio
	if not is_equal_approx(p.lifetime, vie):
		p.lifetime = vie
	p.global_transform = Transform3D(_vers(direction), point)
	p.restart()
	_fin[i] = Time.get_ticks_msec() + int(vie * 1000.0) + 100
	emissions += 1
	cout_us += Time.get_ticks_usec() - t_us

## Émetteur libre, sinon le plus ancien (tourniquet).
func _prendre() -> int:
	var t := Time.get_ticks_msec()
	for k in TAILLE_POOL:
		var i := (_suivant + k) % TAILLE_POOL
		if _fin[i] <= t:
			_suivant = (i + 1) % TAILLE_POOL
			return i
	var i := _suivant
	_suivant = (_suivant + 1) % TAILLE_POOL
	return i

## Base dont le +Y pointe vers `dir`.
static func _vers(dir: Vector3) -> Basis:
	var y := dir.normalized() if dir.length() > 0.001 else Vector3.UP
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))

static func _preparer_ressources() -> void:
	if _quad_mix != null:
		return
	_quad_mix = QuadMesh.new()
	var mm := ShaderMaterial.new()
	mm.shader = SH_MIX
	_quad_mix.material = mm
	_quad_add = QuadMesh.new()
	var ma := ShaderMaterial.new()
	ma.shader = SH_ADD
	ma.set_shader_parameter("eclat", 1.8)
	ma.set_shader_parameter("taille_min", 2.0)
	ma.set_shader_parameter("taille_max", 4.0)
	ma.set_shader_parameter("etire", 2.5)
	_quad_add.material = ma
	for nom: String in MATIERES:
		_pm(nom, false)
		_pm(nom, true)

## Matériau de processus d'une matière et d'un palier (partagé, créé une fois).
static func _pm(matiere: String, fort: bool) -> ParticleProcessMaterial:
	var cle := matiere + ("+" if fort else "")
	if _pms.has(cle):
		return _pms[cle]
	var m: Dictionary = MATIERES[matiere]
	var k := 1.35 if fort else 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = float(m["ecart"])
	pm.initial_velocity_min = float(m["vitesse"][0]) * k
	pm.initial_velocity_max = float(m["vitesse"][1]) * k
	pm.gravity = Vector3(0, -float(m["gravite"]), 0)
	pm.damping_min = float(m["amorti"]) * 0.6
	pm.damping_max = float(m["amorti"])
	pm.scale_min = float(m["taille"][0]) * (1.2 if fort else 1.0)
	pm.scale_max = float(m["taille"][1]) * (1.2 if fort else 1.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.04
	if bool(m.get("add", false)):
		pm.particle_flag_align_y = true   # traînée dans le sens de la vitesse (shader : etire)
	# chaque éclat tire une couleur de la palette (rampe EN PALIERS : pas de mélange entre deux teintes)
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var cs: Array = m["couleurs"]
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for j in cs.size():
		offs.append(float(j) / cs.size())
		cols.append(Color(cs[j]))
	g.offsets = offs
	g.colors = cols
	var gt := GradientTexture1D.new()
	gt.gradient = g
	gt.width = 64
	pm.color_initial_ramp = gt
	# opacité : pleine, puis s'éteint sur le dernier tiers (le shader la ramène à 3 paliers)
	var ga := Gradient.new()
	ga.set_color(0, Color(1, 1, 1, 1))
	ga.set_color(1, Color(1, 1, 1, 0))
	ga.add_point(0.62, Color(1, 1, 1, 1))
	var gta := GradientTexture1D.new()
	gta.gradient = ga
	gta.width = 32
	pm.color_ramp = gta
	_pms[cle] = pm
	return pm

## Préchauffe (PrechauffeCombat.vitrine) : un émetteur par shader, rendus hors écran avec les VRAIES ressources partagées.
static func vitrine(parent: Node3D) -> void:
	_preparer_ressources()
	var x := 0.0
	for q: QuadMesh in [_quad_mix, _quad_add]:
		var p := GPUParticles3D.new()
		p.amount = 8
		p.lifetime = 0.8
		p.preprocess = 0.3
		p.local_coords = false
		p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.process_material = _pm("os" if q == _quad_mix else "etincelles", false)
		p.draw_pass_1 = q
		parent.add_child(p)
		p.position = Vector3(-0.3 + x, 0.4, 0.3)
		p.emitting = true
		x += 0.6

## Émetteurs actifs (tests, mesures).
func actifs() -> int:
	var t := Time.get_ticks_msec()
	var n := 0
	for f in _fin:
		if f > t:
			n += 1
	return n
