extends SceneTree
## Planche de choix des armes CC0 (essai jetable) : par arme, vues neutres (face + trois quarts, avec l'épée actuelle du jeu à côté)
## et vue FPS en main (jour). Sortie : <dossier>/neutre_<id>.png, fps_<id>.png.
##   godot --path . --disable-vsync --script outils/planche_armes_cc0.gd -- --nouvelle --paisible --mains=repos --sortie=<dossier>
const DOSSIER_GLB := "res://assets/modeles/armes/cc0_essai/"
var dossier := "res://captures/armes_cc0"
var ids: Array[String] = []

func _init() -> void:
	_lancer.call_deferred()

func _charger(id: String) -> Node3D:
	var e: Node3D = (load(DOSSIER_GLB + id + ".glb") as PackedScene).instantiate()
	EpeesLongues.habiller(e)
	return e

func _lancer() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			dossier = a.substr(9)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	for f in DirAccess.get_files_at(DOSSIER_GLB):
		if f.ends_with(".glb"):
			ids.append(f.get_basename())
	ids.sort()
	var m: Node = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for i in 60:
		await process_frame
	await _neutre()
	await _fps(m)
	print("planche_armes_cc0 : fini -> ", ProjectSettings.globalize_path(dossier), " ", ids.size(), " armes")
	quit()

func _sauver(img: Image, nom: String) -> void:
	img.save_png(ProjectSettings.globalize_path(dossier.path_join(nom)))
	print("capture ", nom, " ", img.get_size())

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
	cam.size = 1.6
	cam.position = Vector3(0, 0.45, 3)
	vp.add_child(cam)
	var ref := EpeesLongues.instancier("metal")
	vp.add_child(ref)
	ref.position = Vector3(0.38, 0, 0)
	for id in ids:
		var e := _charger(id)
		vp.add_child(e)
		e.position = Vector3(-0.05, 0, 0)
		var planche := Image.create(480 * 2 * 2, 270 * 2, false, Image.FORMAT_RGBA8)
		for k in 2:
			for n: Node3D in [e, ref]:
				n.rotation = Vector3.ZERO if k == 0 else Vector3(deg_to_rad(-12), deg_to_rad(38), deg_to_rad(-8))
			for i in 8:
				await process_frame
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(480 * 2, 270 * 2, Image.INTERPOLATE_NEAREST)
			planche.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(480 * 2 * k, 0))
		_sauver(planche, "neutre_%s.png" % id)
		e.queue_free()
	vp.queue_free()

func _fps(m: Node) -> void:
	var j = m.joueur
	var mains = j.mains
	var accroche: Node3D = mains._accroche_d
	var origine: Node3D = mains._modele_arme_d
	var prise: Transform3D = origine.transform
	origine.visible = false
	m.calque.visible = false
	j.tete.rotation.x = deg_to_rad(-4.0)
	j.rotation.y += deg_to_rad(-35.0)
	for i in 20:
		await process_frame
	mains.set_process(false)
	var piv: Node3D = mains.pivot_epee
	piv.position += Vector3(0.03, -0.03, 0.10)
	piv.rotate_object_local(Vector3.FORWARD, deg_to_rad(-28.0))
	piv.rotate_object_local(Vector3.RIGHT, deg_to_rad(-12.0))
	m.cycle.heure = 12.0
	var liste: Array[String] = ["metal"]
	liste.append_array(ids)
	for id in liste:
		var e: Node3D = EpeesLongues.instancier("metal") if id == "metal" else _charger(id)
		accroche.add_child(e)
		e.transform = prise
		for i in 30:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		_sauver(img, "fps_%s.png" % ("00_jeu_actuel" if id == "metal" else id))
		e.queue_free()
