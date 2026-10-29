class_name EclatsOs
extends Node3D
## OS QUI VOLENT (lot L6) : aux coups forts et aux finishers sur les squelettes et les draugrs, quelques morceaux d'os
## (esquilles, éclats de côte, fragments de crâne) partent du point d'impact, rebondissent sur le sol et y restent un moment.
##   EclatsOs.lancer(noeud, point, direction, nombre, force)
## Bon marché et sans allocation par coup : un seul nœud « EclatsOs » par scène tient un POOL de TAILLE_POOL corps rigides
## (boîtes, collision avec le décor seulement : calque 0, masque 1 ; rien ne les heurte, ni le joueur ni les ennemis) et
## leurs maillages / matériau partagés (shader ps1 du jeu, palette Palette.OSSEMENT). Un corps au repos est DÉSACTIVÉ
## (process_mode) : hors de l'espace physique, il ne coûte rien. Le plus ancien éclat est repris quand le pool est plein.

const NOM := "EclatsOs"
const TAILLE_POOL := 14
## Os de MORT d'un squelette : 8 à 12 vrais os des modules de la crypte (os_long_a/b/c, crane), posés sur un pool à part
## (NB_MORT corps, repris du plus ancien) ; ils restent DUREE_MORT s au sol, puis rétrécissent. Un corps au repos s'endort
## puis sort de l'espace physique : 20 s d'os au sol ne coûtent rien.
const NB_MORT := 30
const MODULES_MORT := ["os_long_a", "os_long_b", "os_long_c", "os_long_a", "os_long_b", "crane_a"]
const DUREE_MORT := 20.0
## Durée de vie d'un éclat (s) ; il rétrécit sur la dernière DUREE_FONTE s avant de disparaître.
const DUREE := 7.0
const DUREE_FONTE := 0.6
const TOTAL := TAILLE_POOL + NB_MORT
## Formes : esquille longue, éclat de côte, fragment plat (crâne).
const FORMES := [Vector3(0.16, 0.04, 0.04), Vector3(0.12, 0.05, 0.035), Vector3(0.08, 0.07, 0.025)]

static var _instance: EclatsOs
static var _mailles: Array[BoxMesh] = []
static var _formes: Array[BoxShape3D] = []
static var _mailles_mort: Array[Mesh] = []
static var _formes_mort: Array[BoxShape3D] = []
static var _mat: Material
static var _phys: PhysicsMaterial
## Compteur de lancers (tests).
static var lances := 0
## Faux = aucun os lancé (mesure de coût : outils/perf_retour_crypte.gd).
static var actif := true
## Temps CPU passé dans les lancers et le suivi des éclats (µs, mesures ; la physique elle-même est dans le serveur).
static var cout_us := 0

var _corps: Array[RigidBody3D] = []
var _reste := PackedFloat32Array()
var _suivant := 0
var _suivant_mort := 0
var _endormis := PackedByteArray()
var _vivants := 0

static func lancer(n: Node, point: Vector3, direction: Vector3, nombre: int, force := 1.0) -> void:
	if not actif or n == null or not n.is_inside_tree() or nombre <= 0:
		return
	var e := obtenir(n)
	if e != null:
		e._lancer(point, direction, mini(nombre, TAILLE_POOL), force)

static func obtenir(n: Node) -> EclatsOs:
	if is_instance_valid(_instance) and _instance.is_inside_tree():
		return _instance
	if n == null or not n.is_inside_tree():
		return null
	var arbre := n.get_tree()
	var hote: Node = arbre.current_scene if arbre.current_scene != null else arbre.root
	var e := EclatsOs.new()
	e.name = NOM
	hote.add_child(e)
	_instance = e
	return e

static func _ressources() -> void:
	if _mat != null:
		return
	_mat = Palette.materiau(Palette.tex("eclats_os", Palette.OSSEMENT, 2, 0.35), Vector2.ONE, Color(1.28, 1.27, 1.24))   # os MAT CLAIR neutre (2026-10-29, INSPIRATION_IGNITE §3.4) : plus de dominante jaune
	(_mat as ShaderMaterial).set_shader_parameter("emission", Color(0.07, 0.07, 0.075))   # lueur propre minimale : un aplat de lueur écrasait le modelé (os « plats »)
	_phys = PhysicsMaterial.new()
	_phys.bounce = 0.35
	_phys.friction = 0.9
	for t: Vector3 in FORMES:
		var b := BoxMesh.new()
		b.size = t
		b.material = _mat
		_mailles.append(b)
		var s := BoxShape3D.new()
		s.size = t
		_formes.append(s)
	_modules_os()

## Maillages des os de mort, tirés des modules Blender de la crypte (CrypteDecor) ; boîtes si un module manque.
static func _modules_os() -> void:
	CrypteDecor._charger_modeles()
	for nom: String in MODULES_MORT:
		var v := PackedVector3Array()
		var nrm := PackedVector3Array()
		var col := PackedColorArray()
		for mat: String in CrypteDecor._modeles_de.get(nom, []):
			if mat == "pts":
				continue
			var dat: Dictionary = CrypteDecor._modeles["%s__%s" % [nom, mat]]
			var sv: PackedVector3Array = dat["v"]
			var sc: PackedColorArray = dat["c"]
			for q in range(0, sv.size() - 2, 3):
				var n := (sv[q + 1] - sv[q]).cross(sv[q + 2] - sv[q])
				if n.length_squared() < 1e-12:
					continue
				n = n.normalized()
				# ordre de sommets du module (a, c, b) : voir CrypteDecor._modele_cache
				v.append_array([sv[q], sv[q + 2], sv[q + 1]])
				nrm.append_array([n, n, n])
				col.append_array([_opaque(sc[q]), _opaque(sc[q + 2]), _opaque(sc[q + 1])])   # couleurs de sommet du module : arêtes claires, creux sombres (orbites)
		var m: Mesh
		var taille := Vector3(0.28, 0.05, 0.05)
		if v.size() >= 3:
			var tab := []
			tab.resize(Mesh.ARRAY_MAX)
			tab[Mesh.ARRAY_VERTEX] = v
			tab[Mesh.ARRAY_NORMAL] = nrm
			tab[Mesh.ARRAY_COLOR] = col
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tab)
			am.surface_set_material(0, _mat)
			m = am
			taille = am.get_aabb().size.max(Vector3(0.04, 0.04, 0.04))
		else:
			var b := BoxMesh.new()
			b.size = taille
			b.material = _mat
			m = b
		_mailles_mort.append(m)
		var s := BoxShape3D.new()
		s.size = taille
		_formes_mort.append(s)

static func _opaque(c: Color) -> Color:
	# contraste de sommet : arêtes (clair) un peu plus claires, creux (sombre) plus sombres ; teinte neutralisée à 60 % (pas de reflet jaune)
	var l := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	var f := 0.78 + 0.34 * smoothstep(0.3, 0.9, l)
	var n := Color(c.r, c.g, c.b).lerp(Color(l, l, l * 1.02), 0.6)
	return Color(minf(n.r * f, 1.0), minf(n.g * f, 1.0), minf(n.b * f, 1.0), 1.0)   # alpha 1 = texture de base (alpha 0 = variante neige du shader ps1)

func _ready() -> void:
	_ressources()
	for i in TAILLE_POOL:
		var rb := RigidBody3D.new()
		rb.collision_layer = 0
		rb.collision_mask = 1
		rb.mass = 0.06
		rb.physics_material_override = _phys
		rb.angular_damp = 1.5
		rb.linear_damp = 0.3
		rb.can_sleep = true
		var cs := CollisionShape3D.new()
		cs.shape = _formes[i % FORMES.size()]
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = _mailles[i % FORMES.size()]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Os"
		rb.add_child(mi)
		rb.visible = false
		rb.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(rb)
		_corps.append(rb)
	for i in NB_MORT:
		var k := i % _mailles_mort.size()
		var rb := RigidBody3D.new()
		rb.collision_layer = 0
		rb.collision_mask = 1
		rb.mass = 0.12
		rb.physics_material_override = _phys
		rb.angular_damp = 2.0
		rb.linear_damp = 0.2
		rb.can_sleep = true
		var cs := CollisionShape3D.new()
		cs.shape = _formes_mort[k]
		cs.position = _mailles_mort[k].get_aabb().get_center()
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = _mailles_mort[k]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Os"
		rb.add_child(mi)
		rb.visible = false
		rb.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(rb)
		_corps.append(rb)
	_reste.resize(TOTAL)
	_reste.fill(0.0)
	_endormis.resize(TOTAL)
	_endormis.fill(0)
	set_physics_process(false)

func _lancer(point: Vector3, direction: Vector3, nombre: int, force: float) -> void:
	var t_us := Time.get_ticks_usec()
	var d := direction.normalized() if direction.length() > 0.01 else Vector3.UP
	for k in nombre:
		var i := _suivant
		_suivant = (_suivant + 1) % TAILLE_POOL
		var rb := _corps[i]
		if _reste[i] <= 0.0:
			_vivants += 1
		_reste[i] = DUREE * randf_range(0.8, 1.0)
		rb.process_mode = Node.PROCESS_MODE_INHERIT
		rb.visible = true
		(rb.get_child(1) as Node3D).scale = Vector3.ONE
		var b := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
		rb.global_transform = Transform3D(b, point + Vector3(randf_range(-0.05, 0.05), randf_range(-0.03, 0.05), randf_range(-0.05, 0.05)))
		var lat := Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * 1.3
		rb.linear_velocity = (d * randf_range(0.8, 1.8) + Vector3.UP * randf_range(1.2, 2.4) + lat * 0.7) * sqrt(force)
		rb.angular_velocity = Vector3(randf_range(-14, 14), randf_range(-14, 14), randf_range(-14, 14))
		rb.sleeping = false
	lances += nombre
	set_physics_process(true)
	cout_us += Time.get_ticks_usec() - t_us

## Mort d'un squelette : 8 à 12 os jaillissent du corps (du bassin à la tête), retombent et restent DUREE_MORT s.
## `centre` = pied du squelette ; le ragdoll reste en place (les os sont en plus de lui, pas à sa place).
static func mort_squelette(n: Node, centre: Vector3, direction: Vector3, force := 1.0) -> void:
	if not actif or n == null or not n.is_inside_tree():
		return
	var e := obtenir(n)
	if e != null:
		e._mort(centre, direction, force)

func _mort(centre: Vector3, direction: Vector3, force: float) -> void:
	var t_us := Time.get_ticks_usec()
	var d := direction
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.ZERO
	var nombre := randi_range(8, 12)
	for k in nombre:
		var i := TAILLE_POOL + _suivant_mort
		_suivant_mort = (_suivant_mort + 1) % NB_MORT
		var rb := _corps[i]
		if _reste[i] <= 0.0:
			_vivants += 1
		_reste[i] = DUREE_MORT * randf_range(0.9, 1.0)
		_endormis[i] = 0
		rb.process_mode = Node.PROCESS_MODE_INHERIT
		rb.visible = true
		(rb.get_child(1) as Node3D).scale = Vector3.ONE
		var b := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
		var haut := randf_range(0.25, 1.55)   # le crâne (dernier os) part de la tête
		if k == nombre - 1:
			haut = 1.6
		rb.global_transform = Transform3D(b, centre + Vector3(randf_range(-0.12, 0.12), haut, randf_range(-0.12, 0.12)))
		var lat := Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized() * randf_range(0.8, 2.2)
		rb.linear_velocity = (lat + d * randf_range(0.4, 1.4) + Vector3.UP * randf_range(1.6, 3.4)) * sqrt(force)
		rb.angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
		rb.sleeping = false
	lances += nombre
	set_physics_process(true)
	cout_us += Time.get_ticks_usec() - t_us

func _physics_process(dt: float) -> void:
	if _vivants <= 0:
		set_physics_process(false)
		return
	var t_us := Time.get_ticks_usec()
	for i in TOTAL:
		if _reste[i] <= 0.0:
			continue
		_reste[i] -= dt
		var rb := _corps[i]
		if _reste[i] <= 0.0:
			rb.visible = false
			rb.process_mode = Node.PROCESS_MODE_DISABLED
			_vivants -= 1
		elif _reste[i] < DUREE_FONTE:
			(rb.get_child(1) as Node3D).scale = Vector3.ONE * maxf(_reste[i] / DUREE_FONTE, 0.05)
		elif rb.global_position.y < -200.0:
			_reste[i] = DUREE_FONTE   # tombé hors du monde
		elif i >= TAILLE_POOL and _endormis[i] == 0 and rb.sleeping and _reste[i] > DUREE_FONTE:
			_endormis[i] = 1   # os au repos : il sort de l'espace physique (reste visible, ne coûte plus rien)
			rb.process_mode = Node.PROCESS_MODE_DISABLED
	cout_us += Time.get_ticks_usec() - t_us

## Éclats en vol ou au sol (tests).
func vivants() -> int:
	return _vivants
