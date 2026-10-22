extends CharacterBody3D
## Joueur à la première personne : marche, course, saut, balancement de tête,
## vie, vigueur, coups reçus. Les touches sont physiques : ZQSD sur AZERTY = WASD sur QWERTY.

signal touche(degats: float)
signal deces

const MAINS := preload("res://scripts/mains.gd")
const CORPS := preload("res://scripts/corps_joueur.gd")
const CAMERA_TP := preload("res://scripts/camera_tp.gd")

const VITESSE := 3.2
const COURSE := 6.5
const SAUT := 4.4
const GRAVITE := 13.0
const SENSIBILITE := 0.0022
const LIMITE := 108.0  # bord du terrain jouable
const COUT_COURSE := 12.0  # vigueur par seconde
const CHUTE_DEHORS := 25.0   # filet anti-chute : sous le terrain de plus de 25 m (dehors)
const CHUTE_SOUS_TERRE := -260.0   # sous terre (la grotte descend à -228,4 m)

var vie := 100.0
var vie_max := 100.0
const VIE_BASE := 100.0
const BONUS_BENEDICTION := 10.0

## Bénédiction des ancêtres (choix « respecter les offrandes », quetes.gd) : +10 vie max permanents, jamais cumulés.
func regler_benediction(active: bool, soigner := false) -> void:
	vie_max = VIE_BASE + (BONUS_BENEDICTION if active else 0.0)
	if soigner and active:
		vie = minf(vie_max, vie + BONUS_BENEDICTION)
	vie = minf(vie, vie_max)
var vigueur := 100.0
var vigueur_max := 100.0
var mort := false
var en_dialogue := false  # posé par la boîte de dialogue : ni marche ni combat
var secousse := 0.0
var ennemi_vise: Node = null
## Dernier coup subi (pour la chute du corps à la mort) : origine de l'attaquant et dégâts.
var origine_dernier_coup := Vector3.ZERO
var degats_dernier_coup := 0.0
var competences := Competences.new()
var inventaire := Inventaire.new()

var tete: Node3D
var camera: Camera3D
var mains: Node3D
var corps: Node3D  # corps visible à la troisième personne
var camera_tp: Node3D
var troisieme := false  # V : bascule première / troisième personne
var _pas := 0.0
var _dernier_pas := 0
var _repos_vigueur := 0.0
var _recul := Vector3.ZERO
var _bruit_secousse := FastNoiseLite.new()
var _t := 0.0

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
	camera.far = 90.0  # lot 7 : au-delà de la fin du brouillard (75 m max) rien n'est visible
	tete.add_child(camera)
	camera.current = true
	mains = Node3D.new()
	mains.set_script(MAINS)
	mains.joueur = self
	camera.add_child(mains)
	corps = Node3D.new()
	corps.set_script(CORPS)
	corps.joueur = self
	corps.mains = mains
	add_child(corps)
	camera_tp = Node3D.new()
	camera_tp.set_script(CAMERA_TP)
	camera_tp.joueur = self
	add_child(camera_tp)
	for a in OS.get_cmdline_user_args():
		if a == "--vue=3":
			basculer_vue(true)
	_bruit_secousse.frequency = 2.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## V : passe de la première à la troisième personne. La caméra de la tête reste en place
## (hors champ) : les coups d'épée et les invites partent donc toujours des yeux du joueur.
func basculer_vue(troisieme_personne: bool) -> void:
	troisieme = troisieme_personne
	mains.visible = not troisieme
	corps.definir_vue(troisieme)
	if troisieme:
		camera_tp.recaler()
		camera_tp.camera.current = true
	else:
		camera.current = true

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
		for touche_clavier in touches[nom]:
			var e := InputEventKey.new()
			e.physical_keycode = touche_clavier
			InputMap.action_add_event(nom, e)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not mort and not en_dialogue:
		# screen_relative : non réduit par l'agrandissement du rendu 480x270
		rotate_y(-e.screen_relative.x * SENSIBILITE)
		tete.rotation.x = clampf(tete.rotation.x - e.screen_relative.y * SENSIBILITE, -1.45, 1.45)
	elif e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_V:
		basculer_vue(not troisieme)
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Retire de la vigueur ; la récupération reprend une seconde après.
func depenser(quantite: float) -> void:
	vigueur = maxf(0.0, vigueur - quantite)
	_repos_vigueur = 1.0

## Appelé par un ennemi qui frappe. Renvoie "parade", "bloque" ou "touche".
func recevoir_coup(degats: float, origine: Vector3) -> String:
	if mort:
		return ""
	var vers := origine - global_position
	vers.y = 0.0
	var face := -global_transform.basis.z
	if mains.bloque and vers.normalized().dot(Vector3(face.x, 0, face.z).normalized()) > 0.3 and vigueur > 0.0:
		var parade: bool = mains.temps_garde < 0.3
		var reduction := competences.reduction_parade()
		depenser(degats * (0.3 if parade else 1.1) * reduction)
		vie -= 0.0 if parade else degats * 0.15 * reduction
		competences.pratiquer("parade", 0.6 + degats * 0.08 + (0.6 if parade else 0.0))
		secousse = maxf(secousse, 0.2 if parade else 0.35)
		mains.encaisser()
		Sons.jouer(self, ["impactMetal_heavy_000", "impactMetal_heavy_001", "impactMetal_heavy_002"], -1.0)
		Effets.eclats(self, mains.pivot_epee.global_position, Color(3.0, 2.2, 0.8), 10, 2.5, true)
		return "parade" if parade else "bloque"
	vie -= degats
	origine_dernier_coup = origine
	degats_dernier_coup = degats
	secousse = maxf(secousse, 0.7)
	_recul = -vers.normalized() * 4.0
	touche.emit(degats)
	Sons.jouer(self, ["impactPunch_heavy_000", "impactPunch_heavy_001", "impactPunch_heavy_002"], 0.0)
	if vie <= 0.0:
		vie = 0.0
		mort = true
		deces.emit()
	return "touche"

var _point_sur := Vector3.ZERO
var _point_sur_sous_terre := false
var _point_sur_valide := false
var _t_point_sur := 0.0

## Filet anti-chute : mémorise ~1 fois par seconde un point sûr (au sol) ; sous le seuil, retour à ce point sans pénalité.
func _filet(dt: float) -> void:
	var monde := get_parent()
	if monde == null or not monde.has_method("hauteur"):
		return
	var sous_terre: bool = monde.get("_sous_terre_actif") == true
	var p := global_position
	var seuil: float = CHUTE_SOUS_TERRE if sous_terre else float(monde.hauteur(p.x, p.z)) - CHUTE_DEHORS
	if p.y < seuil:
		var cible: Vector3 = _point_sur if (_point_sur_valide and _point_sur_sous_terre == sous_terre) else Vector3.ZERO
		if cible == Vector3.ZERO:
			cible = monde.get("depart_joueur") if not sous_terre else _point_sur
		if cible == Vector3.ZERO:
			return
		global_position = cible + Vector3(0, 0.2, 0)
		velocity = Vector3.ZERO
		push_warning("Filet anti-chute : joueur ramené à %s" % cible)
		return
	_t_point_sur -= dt
	if _t_point_sur <= 0.0 and is_on_floor() and not mort:
		_t_point_sur = 1.0
		_point_sur = p
		_point_sur_sous_terre = sous_terre
		_point_sur_valide = true

func ressusciter(lieu: Vector3, lacet: float) -> void:
	position = lieu
	rotation.y = lacet
	tete.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	vie = vie_max
	vigueur = vigueur_max
	mort = false

func _physics_process(dt: float) -> void:
	_t += dt
	if not is_on_floor():
		velocity.y -= GRAVITE * dt
	elif Input.is_action_just_pressed("saut") and not mort and not en_dialogue and vigueur > 5.0:
		velocity.y = SAUT
		depenser(6.0)
	var entree := Vector2.ZERO if (mort or en_dialogue) else Input.get_vector("gauche", "droite", "avant", "arriere")
	var dir := (transform.basis * Vector3(entree.x, 0.0, entree.y)).normalized()
	var court: bool = Input.is_action_pressed("course") and vigueur > 0.0 and entree.y < 0.0 and not mains.bloque
	var vitesse := COURSE if court else VITESSE
	if mains.bloque:
		vitesse *= 0.5
	if court and dir != Vector3.ZERO:
		vigueur = maxf(0.0, vigueur - COUT_COURSE * competences.cout_course() * dt)
		competences.pratiquer("athletisme", dt * 0.12)
		_repos_vigueur = 0.6
	var cible := dir * vitesse + _recul
	_recul = _recul.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * dt))
	var reactivite := 1.0 - exp(-(10.0 if is_on_floor() else 2.0) * dt)
	velocity.x = lerpf(velocity.x, cible.x, reactivite)
	velocity.z = lerpf(velocity.z, cible.z, reactivite)
	move_and_slide()
	position.x = clampf(position.x, -LIMITE, LIMITE)
	position.z = clampf(position.z, -LIMITE, LIMITE)
	_filet(dt)

	# récupération
	_repos_vigueur -= dt
	if _repos_vigueur <= 0.0:
		vigueur = minf(vigueur_max, vigueur + 22.0 * dt)
	if not mort:
		vie = minf(vie_max, vie + 0.8 * dt)

	# pas dans la neige
	var vitesse_sol := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and vitesse_sol > 0.3:
		_pas += dt * vitesse_sol * 2.4
		var n := floori(_pas / PI)
		if n != _dernier_pas:
			_dernier_pas = n
			Sons.jouer(self, ["footstep_snow_000", "footstep_snow_001", "footstep_snow_002", "footstep_snow_003", "footstep_snow_004"], -12.0 if not court else -8.0, 0.1)
	var amplitude := clampf(vitesse_sol / COURSE, 0.0, 1.0)
	var bob := Vector3(cos(_pas) * 0.035, absf(sin(_pas)) * 0.06, 0.0) * amplitude
	if mort:
		# on s'effondre
		bob = Vector3(0, -1.2, 0)
		tete.rotation.z = lerpf(tete.rotation.z, 1.2, 1.0 - exp(-3.0 * dt))
	camera.position = camera.position.lerp(bob, 1.0 - exp(-12.0 * dt))

	# secousse de caméra
	secousse = maxf(0.0, secousse - dt * 1.8)
	var s := secousse * secousse
	camera.h_offset = _bruit_secousse.get_noise_2d(_t * 40.0, 0.0) * s * 0.08
	camera.v_offset = _bruit_secousse.get_noise_2d(0.0, _t * 40.0) * s * 0.08
	camera.rotation.z = _bruit_secousse.get_noise_2d(_t * 30.0, 50.0) * s * 0.06
	var cam_tp: Camera3D = camera_tp.camera
	cam_tp.h_offset = camera.h_offset
	cam_tp.v_offset = camera.v_offset
	cam_tp.rotation.z = camera.rotation.z
