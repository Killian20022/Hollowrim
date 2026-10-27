extends CharacterBody3D
## Joueur factice de la scène de test des dégâts (scenes/test_degats.tscn) : juste ce que lisent les ennemis (tete, camera, mort,
## secousse, recevoir_coup, inventaire) ; il encaisse sans mourir. La caméra tremble avec `secousse` comme celle de joueur.gd.

class Sac:
	var objets := {}
	func ajouter(id: String, n: int) -> void:
		objets[id] = int(objets.get(id, 0)) + n
	func nom(id: String) -> String:
		return id
	func a(id: String) -> bool:
		return objets.has(id)

var tete: Node3D
var camera: Camera3D
var mort := false
var secousse := 0.0
var vie := 100.0
var vie_max := 100.0
var inventaire := Sac.new()
var coups_recus := 0
var _bruit := FastNoiseLite.new()
var _t := 0.0

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var c := CapsuleShape3D.new()
	c.radius = 0.3
	c.height = 1.75
	cs.shape = c
	cs.position.y = 0.9
	add_child(cs)
	tete = Node3D.new()
	tete.position.y = 1.62
	add_child(tete)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	tete.add_child(camera)
	_bruit.frequency = 2.0

func recevoir_coup(_degats: float, _origine: Vector3) -> String:
	coups_recus += 1
	return "touche"

func _process(dt: float) -> void:
	_t += dt
	secousse = maxf(0.0, secousse - dt * 1.8)
	var s := secousse * secousse
	camera.h_offset = _bruit.get_noise_2d(_t * 40.0, 0.0) * s * 0.08
	camera.v_offset = _bruit.get_noise_2d(0.0, _t * 40.0) * s * 0.08
	camera.rotation.z = _bruit.get_noise_2d(_t * 30.0, 50.0) * s * 0.06
