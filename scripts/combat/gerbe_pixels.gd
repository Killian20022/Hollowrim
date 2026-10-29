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
## Pool : 20 émetteurs de 64 particules (passe « intensité », 2026-10-28 : 16×48 avant). 64 = une gerbe de finisher sur l'os
## (24 × 2,8, plafonnée) ; 20 = 4 ennemis au contact (2 gerbes par coup chacun) + bouclier + effets d'ambiance (troll, mage).
const TAILLE_POOL := 20
const PARTICULES := 64
## Seuil du palier « fort » (coup lourd, critique, finisher) : gerbe plus rapide, éclats plus gros, vie plus longue.
const SEUIL_FORT := 1.6
## Éclat d'impact (toutes matières) : pendant les premiers instants de la vie, la couleur est multipliée (rampe HDR en paliers :
## os → blanc, sang → rouge vif) et le carré est agrandi ; puis il retombe à sa couleur de palette. Fractions de la vie.
const ECLAIR_FIN := [0.06, 0.15]          # fin du 1er palier (très clair), fin du 2e (clair)
const ECLAIR_TAILLE := 1.4                # agrandissement des carrés pendant le 1er palier (shader : eclair_taille)

## Réglages par matière : couleurs (palette du jeu, tirées au hasard par éclat), nombre d'éclats d'un coup léger, taille (m,
## avant arrondi en pixels : 3-8 px à 480x270 vers 2 m), vitesse (m/s), écart du cône (°), gravité (m/s²), amorti (freinage
## de l'air, m/s² : la gerbe jaillit puis se fige et retombe), durée (s), eclair (multiplicateurs de couleur des 2 paliers de
## l'éclat d'impact), refroidit (teinte de fin de vie, étincelles), rendu : "carre" (mélange, défaut), "trait" (mélange étiré
## dans le sens de la vitesse : étincelles nettes même sur la neige), "lueur" (additif, magie de givre).
const MATIERES := {
	# os de squelette : blanc d'os franc (Os #efe7d0) + beiges de Palette.OSSEMENT, quelques éclats sombres (moelle sèche)
	"os": {"couleurs": ["#fffbef", "#efe7d0", "#efe7d0", "#d2c9ad", "#b3aa8f", "#6b6452"], "n": 24, "taille": [0.03, 0.07],
		"vitesse": [1.6, 4.6], "ecart": 65.0, "gravite": 7.0, "amorti": 4.2, "duree": 0.9, "eclair": [2.2, 1.45]},
	# draugr : chair desséchée sur l'os — éclats d'os clairs et grumeaux de sang noirci, contraste fort
	"draugr": {"couleurs": ["#efe7d0", "#d2c9ad", "#b3aa8f", "#8a1a14", "#5a0e0b", "#2e0807"], "n": 22, "taille": [0.03, 0.068],
		"vitesse": [1.5, 4.2], "ecart": 60.0, "gravite": 8.0, "amorti": 4.0, "duree": 0.85, "eclair": [2.2, 1.45]},
	# chair vivante (bandits, mage) : sang « Laine rouge » vif à l'impact puis sombre (rouge de la palette, paliers)
	"sang": {"couleurs": ["#c42a22", "#9c1c18", "#7a1c1c", "#5e0e0c", "#3a0605"], "n": 16, "taille": [0.03, 0.065],
		"vitesse": [1.5, 4.0], "ecart": 50.0, "gravite": 11.0, "amorti": 3.2, "duree": 0.8, "eclair": [2.0, 1.4]},
	# jet d'un moignon (Demembrement, bandits) : cône serré, gros pixels de sang qui filent en arc et retombent en gouttes
	"sang_jet": {"couleurs": ["#c42a22", "#9c1c18", "#9c1c18", "#7a1c1c", "#5e0e0c", "#3a0605"], "n": 18, "taille": [0.035, 0.075],
		"vitesse": [2.0, 4.2], "ecart": 13.0, "gravite": 11.0, "amorti": 0.8, "duree": 0.8, "eclair": [1.5, 1.2]},
	# jet d'un moignon de draugr : fluide sombre presque noir et poussière brune de chair desséchée, plus lent, plus large
	"draugr_jet": {"couleurs": ["#5a0e0b", "#2e0807", "#1a0c08", "#3b2a1e", "#52453f", "#2e2a26"], "n": 18, "taille": [0.035, 0.075],
		"vitesse": [1.6, 3.4], "ecart": 20.0, "gravite": 9.0, "amorti": 1.4, "duree": 0.85, "eclair": [1.4, 1.15]},
	# chair épaisse (troll de givre) : sang vif et lambeaux de peau grise / fourrure claire
	"chair": {"couleurs": ["#d23a2c", "#a8201a", "#7a1c1c", "#4a0c0a", "#d8d4cc", "#8f8a86"], "n": 20, "taille": [0.04, 0.085],
		"vitesse": [1.6, 4.4], "ecart": 55.0, "gravite": 10.0, "amorti": 3.4, "duree": 0.85, "eclair": [2.0, 1.4]},
	# métal (cotte, casque, umbo, lame contre lame, bouclier) : étincelles blanc-jaune filantes qui refroidissent vers l'orange
	# (teintes chaudes : un jaune pâle se perd sur la neige et le ciel clair, l'orange reste lisible partout)
	"etincelles": {"couleurs": ["#ffffff", "#fff0a8", "#ffd23a", "#fcb53a", "#fcb53a", "#ec6a1f"], "n": 14, "taille": [0.02, 0.03],
		"vitesse": [3.0, 6.0], "ecart": 55.0, "gravite": 8.0, "amorti": 4.5, "duree": 0.45, "eclair": [1.6, 1.25],
		"refroidit": "#ec6a1f", "rendu": "trait"},
	# bois (bouclier, mannequin) : échardes de Palette.PLANCHES / FOIN, une écharde claire de cœur du bois
	"bois": {"couleurs": ["#c9a868", "#947e46", "#7a6636", "#4b3b2b", "#2a2018"], "n": 14, "taille": [0.03, 0.065],
		"vitesse": [1.5, 3.8], "ecart": 50.0, "gravite": 9.0, "amorti": 3.2, "duree": 0.75, "eclair": [1.9, 1.35]},
	# pierre (lame contre un mur, mécanismes brisés) : gravillons de Palette.ROCHE, arêtes claires
	"pierre": {"couleurs": ["#b8c0cc", "#8a96ad", "#6d7480", "#565c67", "#2e3238"], "n": 12, "taille": [0.03, 0.06],
		"vitesse": [1.4, 3.6], "ecart": 55.0, "gravite": 9.0, "amorti": 3.0, "duree": 0.7, "eclair": [1.9, 1.35]},
	# sang coupé (option gore à 0) : poussière de tissu et de chair sèche, neutre
	"poussiere": {"couleurs": ["#b3aa8f", "#8f8670", "#6b6452", "#52453f", "#2e2a26"], "n": 12, "taille": [0.03, 0.065],
		"vitesse": [1.2, 3.2], "ecart": 60.0, "gravite": 6.0, "amorti": 3.6, "duree": 0.75, "eclair": [1.8, 1.3]},
	# givre (glace brisée : troll, dragon, mage, trait de givre) : cristaux blancs et bleus de la palette Givre, opaques
	"givre": {"couleurs": ["#ffffff", "#e8f6ff", "#a8d8f8", "#a8d8f8", "#5f9fe8", "#2f5fb8"], "n": 16, "taille": [0.03, 0.07],
		"vitesse": [1.4, 4.0], "ecart": 70.0, "gravite": 6.0, "amorti": 3.6, "duree": 0.85, "eclair": [1.7, 1.3]},
	# lueur de givre (magie : téléport, invocation, souffle, onde) : pixels lumineux additifs, bleu glacier
	"givre_lueur": {"couleurs": ["#e8f6ff", "#a8d8f8", "#7ab8f0", "#5f9fe8"], "n": 14, "taille": [0.025, 0.05],
		"vitesse": [1.2, 3.6], "ecart": 75.0, "gravite": 2.0, "amorti": 3.0, "duree": 0.7, "eclair": [1.6, 1.25], "rendu": "lueur"},
	# écailles de dragon (givre) : éclats d'écaille bleu nuit à arêtes claires + sang sombre ; plus gros (corps vu à 4-6 m)
	"ecailles": {"couleurs": ["#d8e4f0", "#8a9cb8", "#4a5a78", "#2a3448", "#7a1c1c", "#3a0605"], "n": 22, "taille": [0.06, 0.12],
		"vitesse": [1.6, 4.4], "ecart": 60.0, "gravite": 8.0, "amorti": 3.6, "duree": 0.9, "eclair": [2.0, 1.4]},
	# braise (troll touché par le feu) : pixels de la palette du feu, lumineux, qui montent un peu
	"braise": {"couleurs": ["#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"], "n": 12, "taille": [0.025, 0.045],
		"vitesse": [1.0, 3.0], "ecart": 70.0, "gravite": -1.0, "amorti": 3.0, "duree": 0.7, "eclair": [1.5, 1.2], "rendu": "lueur"},
}
const FORCES := {"leger": 1.0, "moyen": 1.3, "lourd": 1.8, "critique": 2.3, "finisher": 2.8}

static var _pms := {}
static var _quad_mix: QuadMesh
static var _quad_add: QuadMesh
static var _quad_trait: QuadMesh
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
	var q := _quad_de(m)
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
	# carrés opaques : 3-8 px à 480x270 (le shader convertit pour 640x360), × ECLAIR_TAILLE pendant l'éclat d'impact
	_quad_mix = _quad(SH_MIX, {"taille_min": 3.0, "taille_max": 8.0, "eclair_fin": ECLAIR_FIN[0], "eclair_taille": ECLAIR_TAILLE})
	# étincelles : traits fins opaques, étirés dans le sens de la vitesse, un peu au-delà du blanc (le glow les prend)
	_quad_trait = _quad(SH_MIX, {"eclat": 1.5, "taille_min": 2.0, "taille_max": 3.0, "etire": 3.0, "long_max": 3.0})
	# lueur (magie de givre, braise) : additif
	_quad_add = _quad(SH_ADD, {"eclat": 1.6, "taille_min": 2.0, "taille_max": 5.0})
	for nom: String in MATIERES:
		_pm(nom, false)
		_pm(nom, true)

static func _quad(sh: Shader, params: Dictionary) -> QuadMesh:
	var q := QuadMesh.new()
	var m := ShaderMaterial.new()
	m.shader = sh
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	q.material = m
	return q

## Quad (donc shader) d'une matière selon son rendu.
static func _quad_de(m: Dictionary) -> QuadMesh:
	match String(m.get("rendu", "carre")):
		"trait":
			return _quad_trait
		"lueur":
			return _quad_add
	return _quad_mix

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
	if String(m.get("rendu", "")) == "trait":
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
	# couleur au fil de la vie (multiplie la couleur de l'éclat, HDR) : ÉCLAT D'IMPACT en deux paliers francs (os → blanc, sang →
	# rouge vif), puis la couleur de palette (ou la teinte de refroidissement des étincelles) ; opacité pleine puis éteinte sur le
	# dernier tiers (le shader la ramène à 3 paliers)
	var e: Array = m.get("eclair", [1.0, 1.0])
	var k1 := float(e[0]) * (1.15 if fort else 1.0)
	var k2 := float(e[1])
	var fin := Color(m["refroidit"]) if m.has("refroidit") else Color(1, 1, 1)
	var ga := Gradient.new()
	ga.offsets = PackedFloat32Array([0.0, ECLAIR_FIN[0] - 0.005, ECLAIR_FIN[0], ECLAIR_FIN[1] - 0.005, ECLAIR_FIN[1], 0.62, 1.0])
	ga.colors = PackedColorArray([Color(k1, k1, k1, 1), Color(k1, k1, k1, 1), Color(k2, k2, k2, 1), Color(k2, k2, k2, 1),
		Color(1, 1, 1, 1), Color(lerpf(1.0, fin.r, 0.6), lerpf(1.0, fin.g, 0.6), lerpf(1.0, fin.b, 0.6), 1), Color(fin.r, fin.g, fin.b, 0)])
	var gta := GradientTexture1D.new()
	gta.gradient = ga
	gta.width = 128
	gta.use_hdr = true
	pm.color_ramp = gta
	_pms[cle] = pm
	return pm

## Préchauffe (PrechauffeCombat.vitrine) : un émetteur par shader, rendus hors écran avec les VRAIES ressources partagées.
static func vitrine(parent: Node3D) -> void:
	_preparer_ressources()
	var x := 0.0
	for q: QuadMesh in [_quad_mix, _quad_trait, _quad_add]:
		var p := GPUParticles3D.new()
		p.amount = 8
		p.lifetime = 0.8
		p.preprocess = 0.3
		p.local_coords = false
		p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.process_material = _pm({_quad_mix: "os", _quad_trait: "etincelles", _quad_add: "givre_lueur"}[q], false)
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
