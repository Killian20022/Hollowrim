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
## Durée de vie d'un éclat (s) ; il rétrécit sur la dernière DUREE_FONTE s avant de disparaître.
const DUREE := 7.0
const DUREE_FONTE := 0.6
## Formes : esquille longue, éclat de côte, fragment plat (crâne).
const FORMES := [Vector3(0.16, 0.04, 0.04), Vector3(0.12, 0.05, 0.035), Vector3(0.08, 0.07, 0.025)]

static var _instance: EclatsOs
static var _mailles: Array[BoxMesh] = []
static var _formes: Array[BoxShape3D] = []
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
	_mat = Palette.materiau(Palette.tex("eclats_os", Palette.OSSEMENT, 2, 0.35), Vector2.ONE, Color(1.3, 1.25, 1.15))   # éclairci : lisible dans la pénombre
	(_mat as ShaderMaterial).set_shader_parameter("emission", Color(0.16, 0.15, 0.12))   # un peu de lueur propre (crypte)
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
	_reste.resize(TAILLE_POOL)
	_reste.fill(0.0)
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

func _physics_process(dt: float) -> void:
	if _vivants <= 0:
		set_physics_process(false)
		return
	var t_us := Time.get_ticks_usec()
	for i in TAILLE_POOL:
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
	cout_us += Time.get_ticks_usec() - t_us

## Éclats en vol ou au sol (tests).
func vivants() -> int:
	return _vivants
