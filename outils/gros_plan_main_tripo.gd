extends SceneTree
## Gros plans des mains d'un ennemi Tripo en jeu (même cadrage que le rendu Blender de la source) : <sortie>/<ennemi>_<clip>_<main>.png
##   godot --path . --script res://outils/gros_plan_main_tripo.gd -- --ennemis-tripo --ennemi=squelette --arme= --clips=Sword_Idle:0.5,Punch_Cross:0.3 --sortie=<dossier>
## --vue=face|cote ; --dist ; --fov
func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(900, 900)
	var sortie := _arg("sortie", "user://mains")
	DirAccess.make_dir_recursive_absolute(sortie)
	var id := _arg("ennemi", "squelette")
	var arme := _arg("arme", "")
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-30, 25, 0)
	soleil.light_energy = 1.2
	root.add_child(soleil)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.3, 0.35)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.8
	root.add_child(env)
	var cam := Camera3D.new()
	cam.fov = float(_arg("fov", "22"))
	root.add_child(cam)
	cam.current = true
	var n := EnnemiTripo.creer(id, arme)
	n.scale = Vector3.ONE * float(n.get_meta("echelle_tripo", 1.0))
	root.add_child(n)
	var ap := n.get_node("Animations") as AnimationPlayer
	var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
	for i in 4:
		await process_frame
	var dist := float(_arg("dist", "0.9"))
	for spec in _arg("clips", "Sword_Idle:0.5").split(","):
		var p := spec.split(":")
		ap.play(p[0])
		ap.seek(float(p[1]), true)
		for i in 3:
			await process_frame
		for main in ["r", "l"]:
			var h := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_" + main)).origin
			var dir := Vector3(0.0, 0.15, 1.0) if _arg("vue", "face") == "face" else Vector3(1.0 if main == "r" else -1.0, 0.1, 0.3)
			cam.global_position = h + dir.normalized() * dist
			cam.look_at(h)
			for i in 2:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(sortie.path_join("%s_%s_%s.png" % [id, p[0], main]))
	quit(0)
