class_name EffetElementLame
extends Node3D
## EFFET PASSIF DE L'ÉLÉMENT SUR LA LAME (2026-11-19) : toute arme dont DonneesArme.element_type est posé (feu, glace,
## electricite, tenebres) montre en permanence, le long de son segment tranchant (garde -> pointe du modèle), un petit effet
## pixel : braises qui montent + lueur orange du fil (feu), givre qui scintille + cristaux et vapeur froide qui tombent (glace),
## étincelles et arcs intermittents (électricité), fumée violette qui s'effiloche (ténèbres). Doc : docs/EFFETS_ELEMENTS.md.
##   EffetElementLame.poser(modele, donnees, garde, pointe) -> EffetElementLame    enfant du modèle de l'arme (repère du .glb)
##   EffetElementLame.poser_type(modele, type, garde, pointe)                      idem avec le type seul
##   EffetElementLame.type_de(id) -> String                                        élément d'une arme par son identifiant
##   EffetElementLame.prechauffer()                                                matériaux partagés créés au chargement
##   effet.mains = <mains.gd>                                                       renfort pendant la charge / le coup lourd
## Style PS1 : carrés de pixels entiers (shaders/lame_element_*.gdshader, même dessin que les particules de magie, sans
## occlusion de couche fine), palettes de 3-4 teintes en paliers, 38 à 58 particules allouées par arme (62 % émises au repos, toutes au renfort), AUCUNE lumière dynamique.
## Matériaux : créés une fois (fil principal) puis partagés par toutes les armes ; jamais créés dans un fil de construction.
## Interrupteur : --sans-effet-element (comparaison, mesures).

const SH_ADD := preload("res://shaders/lame_element_add.gdshader")
const SH_MIX := preload("res://shaders/lame_element_mix.gdshader")
const TYPES := ["feu", "glace", "electricite", "tenebres"]
## Portée d'affichage hors joueur (m) : au-delà, quelques pixels de 1 px ne se lisent plus.
const PORTEE := 28.0
## Renfort pendant la charge / le coup lourd : la part de particules émises passe de 1/RENFORT à 1 (amount_ratio).
const RENFORT := 1.6

## Couches par élément. Clés : add (additif, sinon mélange), local (particules attachées à la lame), n (particules, au renfort
## maximal ; la moitié au repos), vie (s), larg (demi-largeur de la boîte d'émission vers le tranchant, m), ep (demi-épaisseur, m),
## grav (m/s², repère du monde), vit (min, max m/s), ecart (°), taille (min, max m), courbe, rampe (paliers sRVB), eclat, cap (px),
## alea, expl, turb, etire (traînée en tailles), bout (0..1 : part du segment côté garde exclue : la lame commence après la garde).
const COUCHES := {
	"feu": [
		# braises : points jaune -> orange -> rouge sombre qui montent du fil et traînent derrière un coup
		{"add": true, "n": 30, "vie": 1.0, "larg": 0.016, "ep": 0.014, "grav": Vector3(0, 0.6, 0), "vit": Vector2(0.02, 0.1),
			"ecart": 180.0, "taille": Vector2(0.012, 0.02), "courbe": "descend", "rampe": ["#fff0a8", "#ffb040", "#ec6a1f", "#8a2a10"],
			"eclat": 1.4, "cap": 3.0, "alea": 0.4},
		# lueur du fil : pixels orange collés à la lame qui s'allument et s'éteignent (fer chauffé)
		{"add": true, "local": true, "n": 28, "vie": 0.5, "larg": 0.016, "ep": 0.014, "vit": Vector2(0.0, 0.0),
			"taille": Vector2(0.011, 0.017), "rampe": ["#ffd070", "#ff8a30", "#c84a18"], "eclat": 1.25, "cap": 3.0, "alea": 0.5},
	],
	"glace": [
		# givre : éclats blancs / bleu pâle fixés au fil qui scintillent longuement
		{"add": true, "local": true, "n": 30, "vie": 1.6, "larg": 0.018, "ep": 0.014, "vit": Vector2(0.0, 0.0),
			"taille": Vector2(0.011, 0.017), "courbe": "bosse", "rampe": ["#a8d8f8", "#e8f6ff", "#5f9fe8"], "eclat": 1.2, "cap": 3.0, "alea": 0.5},
		# cristaux qui se détachent et tombent
		{"add": true, "n": 10, "vie": 1.3, "larg": 0.016, "ep": 0.014, "grav": Vector3(0, -0.5, 0), "vit": Vector2(0.0, 0.02),
			"ecart": 30.0, "taille": Vector2(0.012, 0.017), "rampe": ["#e8f6ff", "#a8d8f8", "#5f9fe8"], "eclat": 1.25, "cap": 3.0, "alea": 0.5},
		# vapeur froide : petits paquets pâles qui coulent sous la lame
		{"n": 12, "vie": 1.5, "larg": 0.016, "ep": 0.016, "grav": Vector3(0, -0.14, 0), "vit": Vector2(0.0, 0.015), "ecart": 40.0,
			"taille": Vector2(0.03, 0.05), "courbe": "bosse", "rampe": ["#d8ecf880", "#b0d0ec60", "#8cb4dc40"], "eclat": 1.0, "cap": 6.0,
			"alea": 0.4},
	],
	"electricite": [
		# étincelles : rafales courtes (relancées à intervalles irréguliers par _process), traînée d'un pixel
		{"add": true, "n": 16, "vie": 0.22, "larg": 0.014, "ep": 0.014, "vit": Vector2(0.3, 0.8), "ecart": 180.0, "grav": Vector3(0, -1.2, 0),
			"taille": Vector2(0.009, 0.013), "rampe": ["#ffffff", "#c8d0ff", "#7a7af0"], "eclat": 1.6, "cap": 2.0, "expl": 0.85, "rafale": true,
			"etire": 3.0},
		# grésillement du fil : pixels bleu-violet
		{"add": true, "local": true, "n": 22, "vie": 0.3, "larg": 0.014, "ep": 0.014, "vit": Vector2(0.0, 0.0),
			"taille": Vector2(0.011, 0.016), "rampe": ["#e0e6ff", "#9a9af8"], "eclat": 1.25, "cap": 3.0, "alea": 0.6},
	],
	"tenebres": [
		# fumée violette sombre qui monte en ondulant et s'effiloche
		{"n": 30, "vie": 1.6, "larg": 0.016, "ep": 0.016, "grav": Vector3(0, 0.16, 0), "vit": Vector2(0.005, 0.03), "ecart": 180.0,
			"taille": Vector2(0.03, 0.048), "courbe": "bosse", "rampe": ["#8a48c8c0", "#5e2c90a0", "#3a1c5c70"], "eclat": 1.0, "cap": 6.0,
			"alea": 0.4, "turb": true},
		# braises violettes au cœur de la fumée
		{"add": true, "local": true, "n": 22, "vie": 0.7, "larg": 0.014, "ep": 0.014, "vit": Vector2(0.0, 0.0),
			"taille": Vector2(0.011, 0.016), "rampe": ["#e0b0ff", "#a050e8"], "eclat": 1.25, "cap": 3.0, "alea": 0.5},
	],
}
## Arcs électriques (électricité) : traits d'un pixel (lignes) en zigzag le long du fil, montrés ARC_DUREE s à intervalles irréguliers.
const ARC_VARIANTES := 8
const ARC_DUREE := Vector2(0.05, 0.09)
const ARC_PAUSE := Vector2(0.25, 0.9)

## Faux = effet coupé (--sans-effet-element).
static var actif := not OS.get_cmdline_user_args().has("--sans-effet-element")
static var _pms := {}
static var _mats := {}
static var _quad: QuadMesh
static var _arcs: Array[ArrayMesh] = []
static var _mat_arc: ShaderMaterial
## Nombre d'effets vivants et de particules allouées (mesures, tests).
static var vivants := 0
static var particules := 0

var type := ""
var garde := Vector3(0, 0.1, 0)
var pointe := Vector3(0, 0.9, 0)
## mains.gd (joueur, avatar) : renfort pendant la charge et le coup lourd ; null ailleurs (PNJ, sol, râtelier).
var mains: Node = null
## Portée d'affichage (0 = illimitée : armes du joueur).
var portee := PORTEE
var renfort := 0.0
var _emetteurs: Array[GPUParticles3D] = []
var _rafales: Array[GPUParticles3D] = []
var _arc: MeshInstance3D
var _t_arc := 0.0
var _t_rafale := 0.0
var _n_alloue := 0
var _rng := RandomNumberGenerator.new()

## Effet de l'élément de `d` sous `modele` (null si l'arme n'a pas d'élément ou si l'effet est coupé). Peut être appelé hors de
## l'arbre (et hors du fil principal) : les émetteurs sont construits à l'entrée dans l'arbre.
static func poser(modele: Node3D, d: DonneesArme, g := Vector3.INF, p := Vector3.INF) -> EffetElementLame:
	if d == null:
		return null
	if g == Vector3.INF or p == Vector3.INF:
		var seg := segment(modele, d)
		g = seg[0]
		p = seg[1]
	return poser_type(modele, d.element_type, g, p)

static func poser_type(modele: Node3D, t: String, g: Vector3, p: Vector3) -> EffetElementLame:
	if not actif or modele == null or not (t in TYPES) or g.distance_to(p) < 0.05:
		return null
	retirer(modele)
	var e := EffetElementLame.new()
	e.name = "EffetElement"
	e.type = t
	e.garde = g
	e.pointe = p
	modele.add_child(e)
	return e

## Retire l'effet posé sous `modele` (changement d'arme, comparaison).
static func retirer(modele: Node) -> void:
	if modele == null:
		return
	var v := modele.get_node_or_null("EffetElement")
	if v != null:
		modele.remove_child(v)
		v.queue_free()

## Élément d'une arme par son identifiant (catalogue, data/armes/<id>.tres) ; "" sans élément.
static func type_de(id: String) -> String:
	var d: DonneesArme = CatalogueArmes.donnees(id) if CatalogueArmes.connu(id) else null
	if d == null and id.is_valid_filename() and ResourceLoader.exists("res://data/armes/%s.tres" % id):
		d = load("res://data/armes/%s.tres" % id) as DonneesArme
	return d.element_type if d != null else ""

## Segment tranchant de `d` dans le repère de `modele` : nœuds vides garde / pointe du modèle s'il en a (reperes_du_modele),
## sinon DonneesArme.garde / pointe.
static func segment(modele: Node3D, d: DonneesArme) -> Array:
	var g := d.garde
	var p := d.pointe
	if d.reperes_du_modele and modele != null:
		var mg := _repere(modele, "garde")
		var mp := _repere(modele, "pointe")
		if mg != Vector3.INF and mp != Vector3.INF and mg.distance_to(mp) > 0.1:
			g = mg
			p = mp
	return [g, p]

static func _repere(racine: Node3D, nom: String) -> Vector3:
	var n := racine.find_child(nom, true, false) as Node3D
	if n == null:
		return Vector3.INF
	var t := Transform3D()
	while n != null and n != racine:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t.origin

## Matériaux partagés (process + dessin) de tous les éléments pour les longueurs de lame courantes : à appeler au chargement
## (fil principal) ; les shaders de particules sont compilés une fois pour toutes.
static func prechauffer() -> void:
	for t: String in TYPES:
		for l in [0.35, 0.6, 0.75, 0.8, 0.85, 0.9, 0.95, 1.0, 1.05]:
			for c: Dictionary in COUCHES[t]:
				_pm(c, l)
				_mat(c)
	_mesh_arcs()

# ------------------------------------------------------------------------------------------------ construction

func _ready() -> void:
	if not actif or not (type in TYPES):
		queue_free()
		return
	_rng.randomize()
	var axe := pointe - garde
	var l := axe.length()
	var y := axe / l
	var x := Vector3.RIGHT - y * Vector3.RIGHT.dot(y)
	if x.length() < 0.2:
		x = Vector3.FORWARD - y * Vector3.FORWARD.dot(y)
	x = x.normalized()
	var z := x.cross(y).normalized()
	# la lame commence un peu après la garde (talon) et s'arrête un peu avant la pointe
	var a := garde + axe * 0.08
	var b := garde + axe * 0.97
	l = a.distance_to(b)
	transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	var lq := snappedf(l, 0.05)
	for c: Dictionary in COUCHES[type]:
		var gp := GPUParticles3D.new()
		var n := int(c.n)
		gp.amount = n
		gp.amount_ratio = 1.0 / RENFORT
		gp.lifetime = float(c.vie)
		gp.randomness = float(c.get("alea", 0.25))
		gp.explosiveness = float(c.get("expl", 0.0))
		gp.local_coords = bool(c.get("local", false))
		gp.one_shot = bool(c.get("rafale", false))
		gp.fixed_fps = 0
		gp.interpolate = false
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gp.process_material = _pm(c, lq)
		gp.draw_pass_1 = _quad_partage()
		gp.material_override = _mat(c)
		gp.sorting_offset = 0.5 if bool(c.get("add", false)) else 0.0
		var ext := maxf(l, 0.3) + 1.0
		gp.visibility_aabb = AABB(Vector3.ONE * -ext, Vector3.ONE * ext * 2.0)
		if portee > 0.0:
			gp.visibility_range_end = portee
		add_child(gp)
		_n_alloue += n
		if gp.one_shot:
			gp.emitting = false
			_rafales.append(gp)
		else:
			gp.emitting = true
			_emetteurs.append(gp)
	if type == "electricite":
		_mesh_arcs()
		_arc = MeshInstance3D.new()
		_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arc.material_override = _mat_arc
		_arc.visible = false
		if portee > 0.0:
			_arc.visibility_range_end = portee
		# repère de l'arc : bas de la lame, axe Y étiré sur la longueur (les zigzags gardent leur largeur en mètres)
		_arc.transform = Transform3D(Basis(Vector3.RIGHT, Vector3.UP * l, Vector3.BACK), Vector3(0, -l * 0.5, 0))
		add_child(_arc)
		_t_arc = _rng.randf_range(0.1, 0.6)
	_t_rafale = _rng.randf_range(0.05, 0.4)
	vivants += 1
	particules += _n_alloue

func _exit_tree() -> void:
	if _n_alloue > 0:
		vivants -= 1
		particules -= _n_alloue
		_n_alloue = 0

func _enter_tree() -> void:
	# ré-entrée (arme rangée puis ressortie, nœud déplacé) : recompté
	if _n_alloue == 0 and not _emetteurs.is_empty():
		for gp in _emetteurs + _rafales:
			_n_alloue += gp.amount
		vivants += 1
		particules += _n_alloue

func _process(dt: float) -> void:
	if not is_visible_in_tree():
		for gp in _emetteurs:
			gp.emitting = false
		return
	var cible := _renfort_mains()
	renfort = move_toward(renfort, cible, dt * (4.0 if cible > renfort else 1.5))
	var ratio := lerpf(1.0 / RENFORT, 1.0, renfort)
	for gp in _emetteurs:
		if not gp.emitting:
			gp.emitting = true
		if absf(gp.amount_ratio - ratio) > 0.04:
			gp.amount_ratio = ratio
	# rafales d'étincelles (électricité) à intervalles irréguliers, plus serrées au renfort
	if not _rafales.is_empty():
		_t_rafale -= dt
		if _t_rafale <= 0.0:
			_t_rafale = _rng.randf_range(0.3, 1.1) * lerpf(1.0, 0.45, renfort)
			for gp in _rafales:
				gp.amount_ratio = ratio
				gp.restart()
				gp.emitting = true
	if _arc != null:
		_t_arc -= dt
		if _t_arc <= 0.0:
			if _arc.visible:
				_arc.visible = false
				# parfois un second arc juste après le premier (crépitement)
				_t_arc = _rng.randf_range(0.04, 0.08) if _rng.randf() < 0.3 else _rng.randf_range(ARC_PAUSE.x, ARC_PAUSE.y) * lerpf(1.0, 0.4, renfort)
			else:
				_arc.mesh = _arcs[_rng.randi() % _arcs.size()]
				var miroir := 1.0 if _rng.randf() < 0.5 else -1.0
				_arc.basis = Basis(Vector3.RIGHT * miroir, _arc.basis.y, Vector3.BACK)
				_arc.visible = true
				_t_arc = _rng.randf_range(ARC_DUREE.x, ARC_DUREE.y)

## Renfort voulu (0..1) d'après les mains qui tiennent l'arme : charge de l'attaque puissante, coup lourd en cours.
func _renfort_mains() -> float:
	if mains == null or not is_instance_valid(mains):
		return 0.0
	var c = mains.get("combat")
	if c == null:
		return 0.0
	var e := int(c.get("etat"))
	if e == EtatCombat.CHARGE_LOURDE:
		return clampf(0.35 + 0.65 * float(mains.get("_charge")), 0.0, 1.0)
	if e == EtatCombat.ATTAQUE_LOURDE or (e == EtatCombat.RECUPERATION and bool(mains.get("_lourd"))):
		return 1.0
	return 0.0

# ------------------------------------------------------------------------------------------------ ressources partagées

static func _quad_partage() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
	return _quad

static func _mat(c: Dictionary) -> ShaderMaterial:
	var add := bool(c.get("add", false))
	var cle := "%s|%s|%s|%s" % [add, c.get("cap", 2.0), c.get("eclat", 1.0), c.get("etire", 0.0)]
	if not _mats.has(cle):
		var m := ShaderMaterial.new()
		m.shader = SH_ADD if add else SH_MIX
		m.set_shader_parameter("taille_max", float(c.get("cap", 2.0)))
		m.set_shader_parameter("eclat", float(c.get("eclat", 1.0)))
		m.set_shader_parameter("etire", float(c.get("etire", 0.0)))
		_mats[cle] = m
	return _mats[cle]

## Matériau de process d'une couche pour une lame de longueur `l` (m, arrondie à 5 cm) : boîte d'émission le long du fil.
static func _pm(c: Dictionary, l: float) -> ParticleProcessMaterial:
	var cle := "%s|%s" % [str(c.get("rampe")), snappedf(l, 0.05)] + ("|%s" % str(c.get("grav", Vector3.ZERO)))
	if _pms.has(cle):
		return _pms[cle]
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(float(c.get("larg", 0.012)), maxf(l, 0.05) * 0.5, float(c.get("ep", 0.005)))
	pm.direction = Vector3.UP
	pm.spread = float(c.get("ecart", 0.0))
	var v: Vector2 = c.get("vit", Vector2.ZERO)
	pm.initial_velocity_min = v.x
	pm.initial_velocity_max = v.y
	pm.gravity = c.get("grav", Vector3.ZERO)
	var t: Vector2 = c.get("taille", Vector2(0.005, 0.008))
	pm.scale_min = t.x
	pm.scale_max = t.y
	var courbe := String(c.get("courbe", "plat"))
	if courbe != "plat":
		var cv := Curve.new()
		match courbe:
			"descend":
				cv.add_point(Vector2(0, 1.0))
				cv.add_point(Vector2(1, 0.3))
			"bosse":
				cv.add_point(Vector2(0, 0.4))
				cv.add_point(Vector2(0.35, 1.0))
				cv.add_point(Vector2(1, 0.5))
		var ct := CurveTexture.new()
		ct.curve = cv
		pm.scale_curve = ct
	if bool(c.get("turb", false)):
		pm.turbulence_enabled = true
		pm.turbulence_influence_min = 0.05
		pm.turbulence_influence_max = 0.12
		pm.turbulence_noise_scale = 1.5
		pm.turbulence_noise_strength = 0.6
		pm.turbulence_noise_speed = Vector3(0, 0.4, 0)
	pm.particle_flag_align_y = float(c.get("etire", 0.0)) > 0.0
	pm.color_ramp = GestionMagie._rampe(c.get("rampe", ["#ffffff"]), false)
	_pms[cle] = pm
	return pm

## Arcs en zigzag pré-calculés (lignes d'un pixel), repère unitaire : y de 0 (talon) à 1 (bout), x en mètres.
static func _mesh_arcs() -> void:
	if not _arcs.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7731
	for v in ARC_VARIANTES:
		var y0 := rng.randf_range(0.0, 0.55)
		var y1 := minf(1.0, y0 + rng.randf_range(0.25, 0.5))
		var n := rng.randi_range(5, 8)
		var pts := PackedVector3Array()
		for i in n + 1:
			var k := float(i) / float(n)
			var xo := 0.0 if i == 0 or i == n else rng.randf_range(-0.022, 0.022)
			pts.append(Vector3(0.008 + xo, lerpf(y0, y1, k), rng.randf_range(-0.004, 0.004)))
		var sommets := PackedVector3Array()
		var couleurs := PackedColorArray()
		for i in n:
			sommets.append(pts[i])
			sommets.append(pts[i + 1])
			var c := Color("#f0f2ff") if i % 2 == 0 else Color("#b4c0ff")
			couleurs.append(c)
			couleurs.append(c)
		# petite branche au milieu
		var mi := n / 2
		sommets.append(pts[mi])
		sommets.append(pts[mi] + Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(0.01, 0.04), 0))
		couleurs.append(Color("#7a7af0"))
		couleurs.append(Color("#7a7af0"))
		var tab := []
		tab.resize(Mesh.ARRAY_MAX)
		tab[Mesh.ARRAY_VERTEX] = sommets
		tab[Mesh.ARRAY_COLOR] = couleurs
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, tab)
		am.custom_aabb = AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 1.2, 0.2))
		_arcs.append(am)
	_mat_arc = ShaderMaterial.new()
	_mat_arc.shader = preload("res://shaders/lame_element_arc.gdshader")
