extends SceneTree
## Gros plans RAPIDES (scène vide) de la main et de l'épée du garde Tripo, sans charger le village :
##   godot --path . --resolution 960x540 --script res://outils/capture_epee_rapide.gd -- --incl=-35 --ech=1.2 --origine=x,y,z --clip=Idle --sortie=<dossier>
func _init() -> void:
	_go.call_deferred()
func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut
func _att(n: int) -> void:
	for i in n:
		await process_frame
func _fixe(nom: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_arg("sortie", "user://tripo").path_join(nom + ".png"))
func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_arg("sortie", "user://tripo"))
	GardeTripo.EPEE_INCL = float(_arg("incl", str(GardeTripo.EPEE_INCL)))
	if _arg("dir") != "":
		var dd := _arg("dir").split_floats(",")
		GardeTripo.EPEE_DIR = Vector3(dd[0], dd[1], dd[2])
	GardeTripo.EPEE_ECH = float(_arg("ech", str(GardeTripo.EPEE_ECH)))
	var o := _arg("centre")
	if o != "":
		var q := o.split(",")
		GardeTripo.CENTRE_POING = Vector3(float(q[0]), float(q[1]), float(q[2]))
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.72)
	w.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 35, 0)
	w.add_child(sol)
	var g := GardeTripo.creer(_arg("id", "tripo_garde_epee"))
	w.add_child(g)
	var sq: Skeleton3D = g.find_child("Skeleton3D", true, false)
	var anim: AnimationPlayer = g.get_node("Animations")
	var mq := _arg("marq")
	if mq != "":
		var qq := mq.split(",")
		var acc := BoneAttachment3D.new()
		acc.bone_name = "hand_r"
		sq.add_child(acc)
		var mi := MeshInstance3D.new()
		mi.mesh = SphereMesh.new()
		(mi.mesh as SphereMesh).radius = 0.012
		(mi.mesh as SphereMesh).height = 0.024
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color.CYAN
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.no_depth_test = true
		mi.material_override = mt
		mi.position = Vector3(float(qq[0]), float(qq[1]), float(qq[2]))
		acc.add_child(mi)
	var cam := Camera3D.new()
	cam.fov = 30.0
	w.add_child(cam)
	cam.make_current()
	for nom in _arg("clip", "Idle").split(","):
		anim.play(nom)
		anim.seek(0.4, true)
		anim.pause()
		await _att(6)
		var bm := sq.global_transform.basis.inverse() * sq.global_transform.basis * sq.get_bone_global_pose(sq.find_bone("hand_r")).basis
		var arme := sq.find_child("EpeeJeu", true, false) as Node3D
		var gb := g.global_basis.inverse()
		var m_ := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_r")).origin
		var e_ := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("lowerarm_r")).origin
		print("DIR ", nom, " lame(local garde) ", gb * arme.global_basis.y, " avant-bras ", gb * (m_ - e_).normalized(), " devant ", gb * Vector3.BACK)
		print("AXE_AVANT_BRAS_DANS_MAIN ", nom, " ", (sq.global_transform.basis * sq.get_bone_global_pose(sq.find_bone("hand_r")).basis).inverse() * (m_ - e_).normalized())
		var dm := _arg("delta_monde")
		if dm != "":
			var qd := dm.split(",")
			var c0 := Vector3(-0.108, -0.028, 0.012) + bm.inverse() * Vector3(float(qd[0]), float(qd[1]), float(qd[2]))
			print("ORIGINE_LOCALE ", c0)
		var main := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_r")).origin
		var bras := (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("upperarm_r")).origin + main) * 0.5
		for vue in [["bras_face", Vector3(0, 0.1, 1), 1.6, "bras"], ["bras_profil", Vector3(-1, 0.1, 0), 1.6, "bras"], ["bras_dos", Vector3(-0.3, 0.1, -1), 1.6, "bras"], ["bras_dessus", Vector3(-0.2, 1, 0.2), 1.6, "bras"]] if _arg("bras") != "" else [["face", Vector3(0, 0.15, 1), 1.0], ["profil", Vector3(-1, 0.15, 0), 1.0], ["dessus", Vector3(-0.3, 1, 0.3), 1.0], ["large", Vector3(-1, 0.1, 0.8), 3.5], ["avant_trois_quart", Vector3(-0.8, 0.2, 0.8), 1.0]]:
			var cible := bras if vue.size() > 3 else main
			cam.global_position = cible + (vue[1] as Vector3).normalized() * float(vue[2])
			cam.look_at(cible, Vector3.UP if absf((vue[1] as Vector3).normalized().y) < 0.9 else Vector3.FORWARD)
			await _att(2)
			await _fixe("%s_%s" % [nom, vue[0]])
	quit()
