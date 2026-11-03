extends SceneTree
## FLAMME RUNIQUE dans la main droite, VUE DE JEU FPS (caméra du joueur, pas de zoom), en un lancement :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_flamme_main.gd -- --nouvelle
## repos → marche → incantation/charge → lancement → retour au repos, puis la même chose vue de près (cadrage de la référence).
const DT := 1.0 / 30.0
var s: Node3D
var j: CharacterBody3D
var m: MainSort
var cam_gp: Camera3D
var proche := false

func _init() -> void:
	_go.call_deferred()

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		j.mana = j.mana_max
		m.recharges.clear()
		if proche:
			var p: Node3D = m.paume["droite"]
			var cible := p.global_position + Vector3(0.0, 0.05, 0.0)
			cam_gp.global_transform = Transform3D(Basis.looking_at(cible - j.camera.global_position, Vector3.UP), j.camera.global_position)
		await process_frame

var mains: Array = ["droite"]

func _appuyer() -> void:
	for h in mains: m.appuyer(h)

func _relacher() -> void:
	for h in mains: m.relacher(h)

func _equiper() -> void:
	m.relacher("gauche")
	m.relacher("droite")
	m.equiper("gauche", "boule_feu" if mains.has("gauche") else "")
	m.equiper("droite", "boule_feu" if mains.has("droite") else "")

func _sequence() -> void:
	print("ETAPE repos")
	await _attendre(3.0)
	print("ETAPE marche")
	Input.action_press("avant")
	await _attendre(2.0)
	Input.action_release("avant")
	await _attendre(0.6)
	print("ETAPE charge")
	_appuyer()
	await _attendre(1.6)
	print("ETAPE lance")
	_relacher()
	await _attendre(0.6)
	print("ETAPE retour")
	await _attendre(2.5)

func _go() -> void:
	s = load("res://scenes/test_magie.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	m = s.magie
	if m.eq.has_method("apprendre_tout"):
		m.eq.apprendre_tout()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _attendre(0.5)
	var env: Environment = s.env
	env.background_color = Color(0.30, 0.27, 0.31)
	env.ambient_light_color = Color(0.52, 0.48, 0.56)
	env.ambient_light_energy = 0.42
	var so: DirectionalLight3D = s.soleil
	so.basis = Basis.looking_at(Vector3(-0.2, -0.25, 0.95), Vector3.UP)
	so.light_color = Color(1.0, 0.72, 0.52)
	so.light_energy = 0.55
	for n in root.find_children("*", "CanvasLayer", true, false):
		for c in n.get_children():
			var garder: bool = c is ColorRect and (c as ColorRect).material is ShaderMaterial
			if c is CanvasItem and not garder:
				(c as CanvasItem).visible = false
	for n in root.find_children("*", "Label3D", true, false):
		(n as Label3D).visible = false
	m.equiper("gauche", "")
	m.equiper("droite", "boule_feu")
	s.placer_joueur(Vector3(0, 0, 1.6), 180.0, 6.0)
	if j.has_method("basculer_vue"):
		j.basculer_vue(false)
	j.camera.current = true
	await _attendre(1.0)
	await _sequence()
	# v5 : main gauche, puis double magie (même séquence, vue de jeu)
	mains = ["gauche"]
	_equiper()
	await _attendre(0.6)
	await _sequence()
	mains = ["gauche", "droite"]
	_equiper()
	await _attendre(0.6)
	await _sequence()
	mains = ["droite"]
	_equiper()
	await _attendre(0.6)
	# même séquence, vue de près (cadrage de la référence)
	cam_gp = Camera3D.new()
	cam_gp.fov = 45.0
	cam_gp.near = 0.01
	s.add_child(cam_gp)
	s.placer_joueur(Vector3(0, 0, 1.6), 180.0, 6.0)
	proche = true
	cam_gp.current = true
	await _sequence()
	quit(0)
