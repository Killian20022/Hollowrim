extends SceneTree
## Essai Tripo : gros plans de l'épée du garde Tripo (face, profil, 3/4) à l'idle, à mi-marche et à l'attaque (clips Humain).
##   godot --path . --resolution 960x540 --script res://outils/capture_epee_garde.gd -- --gardes-tripo --gardes-tripo-en-plus --nouvelle --sortie=<dossier>
var m: Node3D
var j: CharacterBody3D
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
	GardeTripo.EPEE_INCL = float(_arg("incl", "0"))
	GardeTripo.EPEE_ECH = float(_arg("ech", "1"))
	DirAccess.make_dir_recursive_absolute(_arg("sortie", "user://tripo"))
	var sc := (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
		if m == null:
			m = sc if sc.get("pret") != null else null
	j = m.joueur
	j.mort = false
	if m.get("hud") != null: m.hud.visible = false
	j.mains.visible = false
	for c in j.camera.get_children():
		if c is Node3D: c.visible = false
	var g: Node3D = null
	while g == null:
		for n in get_nodes_in_group("villageois"):
			if n.get("donnees") is Dictionary and n.donnees.get("id") == "hab_garde_epee_tripo":
				g = n
		await process_frame
	for n in get_nodes_in_group("villageois"):
		if n.get("_delai_interpelle") != null: n._delai_interpelle = 99999.0
		if n != g and n is Node3D: (n as Node3D).visible = false
	if m.get("vie") != null: m.vie.set_process(false)
	if m.get("dialogue") != null: m.dialogue.set_process(false)
	m.cycle.heure = 11.0
	m.cycle._process(0.0)
	j.camera.fov = 35.0
	await _att(60)
	var p0: Vector3 = j.global_position + Vector3(4, 0, 0)
	g.installer(Vector3(p0.x, m.hauteur(p0.x, p0.z), p0.z), false, false, "Idle", NAN)
	await _att(30)
	var cam3 := Camera3D.new()
	cam3.fov = 32.0
	cam3.near = 0.05
	m.add_child(cam3)
	cam3.make_current()
	if _arg("sans_epee") != "":
		(g.modele.find_child("EpeeMain", true, false) as Node3D).visible = false
	var sq: Skeleton3D = g.modele.find_child("Skeleton3D", true, false)
	var anim: AnimationPlayer = g.modele.get_node("Animations")
	g.set_process(false); g.set_physics_process(false)
	for nom in _arg("clips", "Idle,Walk,Sword_Attack").split(","):
		if not anim.has_animation(nom):
			print("pas de clip ", nom); continue
		anim.play(nom)
		anim.seek(0.4 if nom != "Sword_Attack" else 0.3, true)
		anim.pause()
		await _att(8)
		if _arg("marq") != "" and not has_meta("marq"):
			set_meta("marq", true)
			for k in [["hand_r", Vector3.ZERO, Color.RED], ["hand_r", GardeTripo.PRISE.origin, Color.GREEN], ["middle_03_r", Vector3.ZERO, Color.BLUE], ["index_01_r", Vector3.ZERO, Color.YELLOW], ["pinky_01_r", Vector3.ZERO, Color.MAGENTA]]:
				var acc := BoneAttachment3D.new()
				acc.bone_name = k[0]
				sq.add_child(acc)
				var mi := MeshInstance3D.new()
				mi.mesh = SphereMesh.new()
				(mi.mesh as SphereMesh).radius = 0.012
				(mi.mesh as SphereMesh).height = 0.024
				var mt := StandardMaterial3D.new()
				mt.albedo_color = k[2]
				mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mt.no_depth_test = true
				mi.material_override = mt
				mi.position = k[1]
				acc.add_child(mi)
		var main := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_r")).origin
		for vue in [["face", Vector3(0, 0, 1), 1.3], ["profil", Vector3(-1, 0, 0), 1.3], ["trois_quart", Vector3(-0.7, 0.2, 0.7), 1.3], ["large", Vector3(-1, 0, 0.6), 3.2], ["dessus", Vector3(0, 1, 0.0), 1.1], ["arriere", Vector3(0, 0, -1), 1.1], ["profil_proche", Vector3(-1, 0, 0), 0.7]]:
			var dirw: Vector3 = g.global_transform.basis * vue[1]
			var cam := main + dirw.normalized() * float(vue[2]) + Vector3(0, 0.25, 0)
			print("MAIN ", main, " garde ", g.global_position, " cam ", j.camera.global_position)
			cam3.global_position = cam
			cam3.look_at(main, Vector3.UP if absf(dirw.normalized().y) < 0.9 else Vector3.FORWARD)
			await _att(3)
			await _fixe("%s_%s" % [nom, vue[0]])
	quit()
