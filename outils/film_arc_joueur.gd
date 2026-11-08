extends SceneTree
## Film de l'ARC DU JOUEUR (fenêtre, godot_slot.sh : hors écran) :
##   godot --path . --resolution 1280x720 --fixed-fps 60 --disable-vsync --script res://outils/film_arc_joueur.gd -- --vue=1|3 --sortie=<dossier>
## Images f_00000.png… (une sur 2 : 30 i/s) : l'arc équipé, un bandage progressif, un tir plein qui touche le mannequin, un tir
## court, légende (tension, flèches, dégâts). --vue=3 : caméra d'observation de côté (le corps de l'archer en pose de tir).

const SCENE := preload("res://scenes/test_combat.tscn")
var s: Node3D
var j: CharacterBody3D
var arc: ArcJoueur
var sortie := ""
var vue := "1"
var legende: Label
var cam: Camera3D
var n := 0
var _imp := false

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _go() -> void:
	sortie = _arg("sortie", "user://film_arc")
	vue = _arg("vue", "1")
	DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	arc = j.arc
	arc.souris_reelle = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.position = Vector3(0, 0, -8)
	var env: Environment = s.env
	env.background_color = Color(0.30, 0.27, 0.31)
	env.ambient_light_color = Color(0.52, 0.48, 0.56)
	env.ambient_light_energy = 0.42
	var so: DirectionalLight3D = s.soleil
	so.basis = Basis.looking_at(Vector3(-0.2, -0.25, 0.95), Vector3.UP)
	so.light_color = Color(1.0, 0.72, 0.52)
	so.light_energy = 0.6
	for c in root.find_children("*", "CanvasLayer", true, false):
		for k in c.get_children():
			var garder: bool = k is ColorRect and (k as ColorRect).material is ShaderMaterial
			if k is CanvasItem and not garder:
				(k as CanvasItem).visible = false
	var cl := CanvasLayer.new()
	cl.layer = 50
	root.add_child(cl)
	legende = Label.new()
	legende.add_theme_font_override("font", Palette.police())
	legende.add_theme_font_size_override("font_size", 28)
	legende.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	legende.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03))
	legende.add_theme_constant_override("outline_size", 8)
	legende.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	legende.offset_top = -70.0
	legende.offset_left = 20.0
	cl.add_child(legende)
	s.mannequin.touche.connect(func(_q: float, _p: bool) -> void: legende.text = "Touché : %d dégâts" % roundi(float(s.mannequin.dernier)))
	j.inventaire.ajouter("arc_chasseur", 1)
	j.inventaire.ajouter("fleche", 12)
	s.placer_joueur(Vector3(0.0, 0, 3.0), 0.0)
	j.mains.pas_manuel = false
	for i in 40:
		await process_frame
	if vue == "3":
		j.basculer_vue(true)
		cam = Camera3D.new()
		cam.fov = 55.0
		s.add_child(cam)
		cam.current = true
	arc.equiper()
	await _viser()
	await _filmer(40, "Arc équipé (B / Sac)")
	await _tir(1.2, "Bandage… clic gauche maintenu")
	await _filmer(110, "")
	await _tir(0.45, "Tir court : moins de dégâts")
	await _filmer(100, "")
	await _tir(1.2, "Tir plein")
	await _filmer(100, "")
	print("FILM %d images, flèches %d" % [n, arc.fleches()])
	quit(0)

func _viser() -> void:
	var c: Vector3 = s.mannequin.global_position + Vector3(0, 1.1, 0)
	var d: Vector3 = c - j.camera.global_position
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await process_frame

func _cadre() -> void:
	if cam != null:
		cam.global_position = j.global_position + Vector3(2.4, 1.55, -0.1)
		cam.look_at(j.global_position + Vector3(0, 1.3, -0.7))

func _tir(duree: float, texte: String) -> void:
	arc.appuyer()
	for i in roundi(duree * 60.0):
		legende.text = "%s  [tension %d %%  flèches %d]" % [texte, roundi(arc.tension * 100.0), arc.fleches()]
		await _filmer(1, "")
	arc.relacher()

func _filmer(k: int, texte: String) -> void:
	if texte != "":
		legende.text = texte
	for i in k:
		_cadre()
		await process_frame
		_imp = not _imp
		if _imp:
			continue
		await RenderingServer.frame_post_draw
		var im := root.get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.save_png(sortie.path_join("f_%05d.png" % n))
		n += 1
