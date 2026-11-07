extends SceneTree
## Banc d'essai du jarl animé (scène minimale, sans village) : il marche en ligne droite, photos face / profil / dos en marche et au repos.
##   bash /tmp/godot_slot.sh godot --path . --script res://outils/essai_tripo_jarl_anime.gd -- --sortie=<dossier> [--sans-ressorts=1] [--clip=Walk]
var jarl: Node3D
var cam: Camera3D
var vit := 1.03

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _fixe(nom: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_arg("sortie", "user://tripo").path_join(nom + ".png"))

func _att(sec: float, marche := true) -> void:
	for i in roundi(sec * 30.0):
		await process_frame
		if marche:
			jarl.position += Vector3(0, 0, 1) * vit * 0.033

func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_arg("sortie", "user://tripo"))
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	sol.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.38, 0.28)
	sol.material_override = mat
	root.add_child(sol)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-50, 35, 0)
	soleil.light_energy = 1.1
	root.add_child(soleil)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.65, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.68)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	JarlTripo.RAIDEUR = float(_arg("raideur", str(JarlTripo.RAIDEUR)))
	JarlTripo.AMORTI = float(_arg("amorti", str(JarlTripo.AMORTI)))
	JarlTripo.GRAVITE = float(_arg("gravite", str(JarlTripo.GRAVITE)))
	jarl = JarlTripo.creer(_arg("sans-ressorts") != "1", _arg("collisions", "1") == "1")
	root.add_child(jarl)
	jarl.position = Vector3(0, 0, -20)
	cam = Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	var anim: AnimationPlayer = jarl.get_node("Animations")
	var clip := _arg("clip", "Walk")
	anim.play(clip)
	anim.speed_scale = vit / 1.03 if clip == "Walk" else 1.0
	var marche := clip == "Walk"
	var vues := {"face": Vector3(0, 0, 1), "profil": Vector3(1, 0, 0), "dos": Vector3(0, 0, -1), "troisq": Vector3(0.7, 0, -0.7)}
	await _att(2.0, marche)
	var sk: Skeleton3D = jarl.find_child("Skeleton3D", true, false)
	var sim: SpringBoneSimulator3D = sk.get_node_or_null("Cape")
	if sim != null:
		print("DBG sim actif ", sim.active, " infl ", sim.influence, " n ", sim.get_setting_count(), " joints ", sim.get_joint_count(1), " root ", sim.get_root_bone_name(1), " end ", sim.get_end_bone_name(1), " mode ", sim.callback_mode_process, " coll ", sim.get_collision_count(1), " grav ", sim.get_gravity(1), " stiff ", sim.get_stiffness(1))
	for n in ["cape_c_1", "cape_c_2", "cape_c_3", "cape_c_4", "spine_03"]:
		var b := sk.find_bone(n)
		print("DBG ", n, " ecart repos ", rad_to_deg(sk.get_bone_pose_rotation(b).angle_to(sk.get_bone_rest(b).basis.get_rotation_quaternion())))
	for k in 3:
		for n: String in vues:
			var d: Vector3 = vues[n]
			cam.global_position = jarl.global_position + d * 3.0 + Vector3(0, 1.1, 0)
			cam.look_at(jarl.global_position + Vector3(0, 0.95, 0))
			await _att(0.12, marche)
			await _fixe("%s_%d" % [n, k])
			await _att(0.25, marche)
	quit(0)
