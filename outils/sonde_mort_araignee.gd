extends SceneTree
## Sonde visuelle : l'araignée Quaternius au fil du clip Death, vue de côté (planche de 6 images, lumière simple).
##   godot --path . --script res://outils/sonde_mort_araignee.gd -- --sortie=<dossier> [--clip=Death]
func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var sortie := _arg("sortie", "user://sonde_araignee")
	DirAccess.make_dir_recursive_absolute(sortie)
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	sol.mesh = pm
	root.add_child(sol)
	var l := DirectionalLight3D.new()
	l.rotation = Vector3(-0.8, 0.6, 0)
	root.add_child(l)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.4, 0.45, 0.55)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	root.add_child(we)
	var n := PersosQuat.creer("pq_araignee")
	root.add_child(n)
	n.scale = Vector3.ONE * float(_arg("echelle", "0.5"))
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(float(_arg("cx", "2.6")), float(_arg("cy", "0.5")), float(_arg("cz", "0.4")))
	cam.look_at(Vector3(0, 0.25, 0))
	cam.current = true
	var ap := n.get_node("Animations") as AnimationPlayer
	var clip := _arg("clip", "Death")
	if clip == "proc":         # mort calculée (MortAraignee) depuis la pose de repos (Idle)
		ap.play("Idle")
		for i in 3:
			await process_frame
		var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
		var lib := AnimationLibrary.new()
		lib.add_animation("a", MortAraignee.animation(sq, String(ap.get_animation("Death").track_get_path(0).get_concatenated_names()), float(_arg("cote", "1")), n))
		ap.add_animation_library("mort", lib)
		clip = "mort/a"
	ap.play(clip)
	var a := ap.get_animation(clip)
	for k in 6:
		ap.seek(a.length * k / 5.0, true)
		ap.pause()
		for i in 3:
			await process_frame
		var sk := n.find_child("Skeleton3D", true, false) as Skeleton3D
		var txt := "t=%.2f" % (a.length * k / 5.0)
		for nom in ["Body", "Head", "Abdomen", "FrontLeg3.L", "BackFoot.L"]:
			txt += " %s=%s" % [nom, sk.get_bone_global_pose(sk.find_bone(nom)).origin]
		print("POSE ", txt)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(sortie.path_join("%s_%d.png" % [clip.replace("/", "_"), k]))
	quit()
