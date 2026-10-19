extends CharacterBody3D
## Joueur à la première personne : marche, course, saut, balancement de tête.
## Les touches sont physiques : ZQSD sur AZERTY = WASD sur QWERTY.

const VITESSE := 3.2
const COURSE := 6.5
const SAUT := 4.4
const GRAVITE := 13.0
const SENSIBILITE := 0.0022
const LIMITE := 108.0  # bord du terrain jouable

var tete: Node3D
var camera: Camera3D
var _pas := 0.0

func _ready() -> void:
	_actions()
	floor_snap_length = 0.4
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	forme.shape = capsule
	forme.position.y = 0.9
	add_child(forme)
	tete = Node3D.new()
	tete.position.y = 1.62
	add_child(tete)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 180.0
	tete.add_child(camera)
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _actions() -> void:
	var touches := {
		"avant": [KEY_W, KEY_UP], "arriere": [KEY_S, KEY_DOWN],
		"gauche": [KEY_A, KEY_LEFT], "droite": [KEY_D, KEY_RIGHT],
		"saut": [KEY_SPACE], "course": [KEY_SHIFT],
	}
	for nom in touches:
		if InputMap.has_action(nom):
			continue
		InputMap.add_action(nom)
		for touche in touches[nom]:
			var e := InputEventKey.new()
			e.physical_keycode = touche
			InputMap.action_add_event(nom, e)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen_relative : non réduit par l'agrandissement du rendu 480x270
		rotate_y(-e.screen_relative.x * SENSIBILITE)
		tete.rotation.x = clampf(tete.rotation.x - e.screen_relative.y * SENSIBILITE, -1.45, 1.45)
	elif e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(dt: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITE * dt
	elif Input.is_action_just_pressed("saut"):
		velocity.y = SAUT
	var entree := Input.get_vector("gauche", "droite", "avant", "arriere")
	var dir := (transform.basis * Vector3(entree.x, 0.0, entree.y)).normalized()
	var cible := dir * (COURSE if Input.is_action_pressed("course") else VITESSE)
	var reactivite := 1.0 - exp(-(10.0 if is_on_floor() else 2.0) * dt)
	velocity.x = lerpf(velocity.x, cible.x, reactivite)
	velocity.z = lerpf(velocity.z, cible.z, reactivite)
	move_and_slide()
	position.x = clampf(position.x, -LIMITE, LIMITE)
	position.z = clampf(position.z, -LIMITE, LIMITE)

	var vitesse_sol := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and vitesse_sol > 0.3:
		_pas += dt * vitesse_sol * 2.4
	var amplitude := clampf(vitesse_sol / COURSE, 0.0, 1.0)
	var bob := Vector3(cos(_pas) * 0.035, absf(sin(_pas)) * 0.06, 0.0) * amplitude
	camera.position = camera.position.lerp(bob, 1.0 - exp(-12.0 * dt))
