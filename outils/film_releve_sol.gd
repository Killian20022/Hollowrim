extends SceneTree
## FILM du relevé au sol (scripts/magie/ragdoll_esprit.gd) : vue de derrière l'épaule, un ennemi saisi par la télékinésie (Lévitation),
## lancé en l'air, retombe en ragdoll puis se relève là où son corps est posé (clips capturés). Deux lancers, arène de test_magie.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_releve_sol.gd -- --nouvelle
## (via godot_slot.sh : hors écran). « DEBUT_SEQUENCE <s> » : instant à garder au montage.

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: MainSort
var es: SortsEsprit
var rag: RagdollEsprit
var cam: Camera3D
var cible: Node3D
var _vise := Vector3.ZERO
var l: Label

func _init() -> void:
	_go.call_deferred()

func _sim(t: float) -> void:
	for i in maxi(1, roundi(t / DT)):
		mains.avancer(DT)
		j.vie = j.vie_max
		await physics_frame
		_camera()

func _camera() -> void:
	var dir := -j.global_basis.z
	dir.y = 0.0
	dir = dir.normalized()
	var droite := dir.cross(Vector3.UP)
	var but := _vise
	var long := -3.2
	if cible != null and is_instance_valid(cible):
		but = Elements._centre(cible)
		long = maxf(-3.2, (but - j.global_position).dot(dir) - 11.0)   # d'abord derrière l'épaule, puis il suit l'ennemi
	but.y = clampf(but.y, 0.8, 9.0)
	var pos := j.global_position + dir * long + droite * 0.9 + Vector3.UP * 3.2
	cam.global_position = cam.global_position.lerp(pos, 0.07) if cam.global_position.distance_to(pos) < 30.0 else pos
	_vise = _vise.lerp(but, 0.12)
	cam.look_at(_vise, Vector3.UP)

func _regarder(c: Vector3) -> void:
	for k in 3:
		var d := c - (j.camera.global_position as Vector3)
		j.rotation.y = atan2(-d.x, -d.z)
		j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		await physics_frame

func _draugr(p: Vector3) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(s.DRAUGR)
	d.type = "squelette"
	d.joueur = j
	d.hud = s.hud
	d.ident = "film_rs_%d" % (randi() % 100000)
	d.position = p
	d.rotation.y = atan2(j.global_position.x - p.x, j.global_position.z - p.z)
	s.add_child(d)
	d.set_physics_process(false)
	return d

func _lancer(d: CharacterBody3D, but: Vector3, texte: String) -> void:
	cible = d
	_vise = Elements._centre(d)
	await _regarder(Elements._centre(d))
	l.text = texte
	magie.appuyer("gauche")
	for k in 70:
		await _sim(DT)
	l.text = "lancé en l'air…"
	await _regarder(but)
	magie.relacher("gauche")
	var vu_vol := false
	var t := 0.0
	while t < 14.0:
		await _sim(DT)
		t += DT
		if rag.phase(d) == "vol" and not vu_vol:
			vu_vol = true
		if rag.phase(d) == "releve":
			l.text = "il se relève là où il est tombé"
		if vu_vol and not rag.contient(d):
			break
	await _sim(1.2)
	print("FILM lancer : vol=%s t=%.1f journal=%s" % [vu_vol, t, str(rag.journal.filter(func(x): return x.get("e") == d and x.has("clip")).map(func(x): return [x["clip"], x["pos"], x["bassin_rd"]]))])
	l.text = ""
	d.set_physics_process(false)

func _go() -> void:
	RetourImpact.muet = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	magie = mains.magie
	magie.eq.apprendre_tout()
	mains.pas_manuel = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 20:
		await physics_frame
	es = magie.esprit
	rag = es.rag
	if j.touche.is_connected(magie._sur_touche):
		j.touche.disconnect(magie._sur_touche)
	magie.equiper("gauche", "levitation")
	# lumière de tournage (film seulement)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-55, 30, 0)
	soleil.light_energy = 1.1
	s.add_child(soleil)
	for we in s.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (we as WorldEnvironment).environment
		if env != null:
			env.ambient_light_energy = maxf(env.ambient_light_energy, 1.0) * 1.8
	cam = Camera3D.new()
	cam.fov = 72
	s.add_child(cam)
	cam.make_current()
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(12, 480)
	calque.add_child(l)
	for n in s.get_children():
		if n is Control and n != calque:
			(n as Control).visible = false
	var hud = s.get("hud")
	if hud != null and hud.get_parent() is CanvasLayer:
		(hud.get_parent() as CanvasLayer).visible = false
	s.placer_joueur(Vector3(6, 0, 12), 0.0)
	_vise = Vector3(6, 1, 6)
	await _sim(0.8)
	print("DEBUT_SEQUENCE %.3f" % (Engine.get_process_frames() / 30.0))
	var d1 := _draugr(Vector3(6.0, 0.0, 7.0))
	await _sim(0.5)
	await _lancer(d1, Vector3(6.0, 22.0, 3.0), "Télékinésie : l'ennemi est saisi…")
	var d2 := _draugr(Vector3(4.0, 0.0, 7.5))
	await _sim(0.4)
	await _lancer(d2, Vector3(8.0, 20.0, 3.0), "Second lancer")
	await _sim(1.0)
	print("FIN_SEQUENCE")
	quit(0)
