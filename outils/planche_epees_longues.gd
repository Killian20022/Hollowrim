extends SceneTree
## Planches des épées longues (FENÊTRE nécessaire, hors écran via godot_slot.sh) :
##   1. epees_neutre.png : les cinq épées côte à côte sur fond neutre (de face, puis de trois quarts), rendu PS1 480 x 270 x3.
##   2. fps_<variante>_<jour|nuit>.png : chaque épée tenue à la place de l'épée du joueur (vue FPS du vrai jeu, pose --mains),
##      + fps_jour.png / fps_nuit.png : les cinq vues assemblées en bande (comme la rangée du haut de la planche de référence).
##   godot --path . --disable-vsync --script outils/planche_epees_longues.gd -- --nouvelle --paisible --mains=repos --sortie=<dossier>
func _init() -> void:
	_lancer.call_deferred()

var dossier := "res://captures/epees_longues"

func _lancer() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			dossier = a.substr(9)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	var m: Node = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for i in 60:
		await process_frame
	await _neutre()
	await _fps(m)
	print("planche_epees_longues : fini -> ", ProjectSettings.globalize_path(dossier))
	quit()

func _sauver(img: Image, nom: String) -> void:
	img.save_png(ProjectSettings.globalize_path(dossier.path_join(nom)))
	print("capture ", nom, " ", img.get_size())

# ------------------------------------------------------------------ fond neutre
func _neutre() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#3a3d44")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a90a0")
	env.ambient_light_energy = 0.55
	we.environment = env
	vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, -40, 0)
	sol.light_energy = 1.25
	vp.add_child(sol)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.3
	cam.position = Vector3(0, 0.42, 3)
	vp.add_child(cam)
	var epees: Array[Node3D] = []
	for k in EpeesLongues.VARIANTES.size():
		var e := EpeesLongues.instancier(EpeesLongues.VARIANTES[k])
		vp.add_child(e)
		e.position = Vector3((k - 2) * 0.42, 0, 0)
		epees.append(e)
	var planche := Image.create(480 * 3, 270 * 3 * 2, false, Image.FORMAT_RGBA8)
	for rangee in 2:
		for e in epees:
			e.rotation = Vector3(0, 0, 0) if rangee == 0 else Vector3(deg_to_rad(-12), deg_to_rad(38), deg_to_rad(-8))
		for i in 8:
			await process_frame
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(480 * 3, 270 * 3, Image.INTERPOLATE_NEAREST)
		planche.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(0, 270 * 3 * rangee))
	_sauver(planche, "epees_neutre.png")
	vp.queue_free()

# ------------------------------------------------------------------ vue FPS du jeu
func _fps(m: Node) -> void:
	var j = m.joueur
	var mains = j.mains
	var accroche: Node3D = mains._accroche_d
	var origine: Node3D = null
	for c in accroche.get_children():
		if c is Node3D:
			origine = c
	var prise: Transform3D = origine.transform
	origine.visible = false
	m.calque.visible = false
	# regard : vers le village, légèrement plongeant (rangée du haut de la planche de référence)
	j.tete.rotation.x = deg_to_rad(-4.0)
	j.rotation.y += deg_to_rad(-35.0)    # le sapin du point d'arrivée masque la gauche
	for i in 20:
		await process_frame
	# pose de la planche : main en bas à droite, lame en diagonale vers le haut à gauche. La pose « repos » de mains.gd
	# est figée puis inclinée (mains n'est pas modifié ; les cibles d'IK suivent pivot_epee).
	mains.set_process(false)
	var piv: Node3D = mains.pivot_epee
	piv.position += Vector3(0.03, -0.03, 0.10)   # un peu plus près de l'œil, comme la planche
	piv.rotate_object_local(Vector3.FORWARD, deg_to_rad(-28.0))
	piv.rotate_object_local(Vector3.RIGHT, deg_to_rad(-12.0))
	for phase in ["jour", "nuit"]:
		m.cycle.heure = 12.0 if phase == "jour" else 22.0
		var bande := Image.create(480 * 5, 270, false, Image.FORMAT_RGBA8)
		for k in EpeesLongues.VARIANTES.size():
			var v: String = EpeesLongues.VARIANTES[k]
			var e := EpeesLongues.instancier(v)
			accroche.add_child(e)
			e.transform = prise
			for i in 30:
				await process_frame
			var img := root.get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			_sauver(img, "fps_%s_%s.png" % [v, phase])
			var petit := img.duplicate() as Image
			petit.resize(480, 270, Image.INTERPOLATE_NEAREST)
			bande.blit_rect(petit, Rect2i(0, 0, 480, 270), Vector2i(480 * k, 0))
			e.queue_free()
		_sauver(bande, "fps_%s.png" % phase)
