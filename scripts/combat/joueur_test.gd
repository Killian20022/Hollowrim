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

## Garde simulée par le pilote / les tests : "" (aucune), "bloque", "parade" (de face seulement ; un coup « imparable » ne se pare pas).
var garde := ""
var degats_recus := 0.0
var dernier_options := {}
var lenteur := 0.0
var lenteur_facteur := 1.0

func recevoir_coup(degats: float, origine: Vector3, options := {}) -> String:
	coups_recus += 1
	dernier_options = options
	var vers := origine - global_position
	vers.y = 0.0
	var face := -global_transform.basis.z
	var de_face := vers.length() < 0.01 or vers.normalized().dot(Vector3(face.x, 0, face.z).normalized()) > 0.3
	var imparable := float(options.get("imparable", 0.0))
	if garde != "" and de_face:
		if garde == "parade" and imparable <= 0.0:
			return "parade"
		degats_recus += degats * imparable
		if options.has("ralenti"):
			ralentir(Vector2(options["ralenti"]).x * 0.5, Vector2(options["ralenti"]).y)
		return "bloque"
	degats_recus += degats
	secousse = maxf(secousse, maxf(0.6, float(options.get("secousse", 0.0))))
	if options.has("ralenti"):
		ralentir(Vector2(options["ralenti"]).x, Vector2(options["ralenti"]).y)
	return "touche"

func ralentir(duree: float, facteur: float) -> void:
	lenteur = maxf(lenteur, duree)
	lenteur_facteur = minf(lenteur_facteur, facteur) if lenteur > 0.0 else facteur

func _process(dt: float) -> void:
	_t += dt
	lenteur = maxf(0.0, lenteur - dt)
	if lenteur <= 0.0:
		lenteur_facteur = 1.0
	secousse = maxf(0.0, secousse - dt * 1.8)
	var s := secousse * secousse
	camera.h_offset = _bruit.get_noise_2d(_t * 40.0, 0.0) * s * 0.08
	camera.v_offset = _bruit.get_noise_2d(0.0, _t * 40.0) * s * 0.08
	camera.rotation.z = _bruit.get_noise_2d(_t * 30.0, 50.0) * s * 0.06
