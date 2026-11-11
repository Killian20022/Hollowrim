extends SceneTree
## Planche de contrôle du boss Jarl Kolbeinn le Gelé sur le draugr Tripo (docs/ARMURES_TRIPO.md) :
## rangée [ancien boss (DraugrNordique) | boss Tripo | draugr Tripo ordinaire], mêmes fabriques que le jeu (EnnemisNordiques.creer),
## échelle de boss ×1,12 comme draugr.gd.
##   godot --path . --script res://outils/planche_boss_tripo.gd -- --sortie=<dossier> [--magenta] [--clip=Sword_Idle] [--t=0.5]
## Écrit face, profil, dos, trois_quarts, tete_face, tete_profil, main_d_1/2, main_g_1/2 (.png) dans <dossier>.
## --magenta : fond magenta uni, sans sol (contrôle des trous du maillage).
var cam: Camera3D
var rangee: Array = []

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _init() -> void:
	_go.call_deferred()

func _boss(ancien: bool) -> Node3D:
	var spec := {"type": "guerrier", "boss": "jarl", "ident": "planche_jarl_%s" % ancien, "apparence": EnnemisNordiques.apparence_defaut("guerrier")}
	if ancien:
		spec["modele_ancien"] = true
	var n := EnnemisNordiques.creer(spec)
	n.scale = Vector3.ONE * 1.12
	return n

func _photo(chemin: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(chemin)

func _go() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1200, 800)
	var sortie := _arg("sortie", "user://planche_boss")
	DirAccess.make_dir_recursive_absolute(sortie)
	var magenta := _arg("magenta") != ""
	if not magenta:
		var sol := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(20, 20)
		sol.mesh = pm
		var ms := StandardMaterial3D.new()
		ms.albedo_color = Color(0.28, 0.3, 0.33)
		sol.material_override = ms
		root.add_child(sol)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-40, 35, 0)
	soleil.light_energy = 1.1
	root.add_child(soleil)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(1, 0, 1) if magenta else Color(0.45, 0.47, 0.52)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.environment.ambient_light_energy = 0.6
	root.add_child(env)
	cam = Camera3D.new()
	cam.fov = 28.0
	root.add_child(cam)
	cam.current = true
	var tripo := _boss(false)
	var modeles: Array = [_boss(true), tripo, EnnemiTripo.creer("draugr", "epee")]
	print("BOSS TRIPO variante=", tripo.get_meta("variante", ""), " tripo_ennemi=", tripo.get_meta("tripo_ennemi", ""))
	var clip := _arg("clip", "Sword_Idle")
	var t := float(_arg("t", "0.5"))
	for i in modeles.size():
		var n: Node3D = modeles[i]
		n.position = Vector3((i - 1) * 1.45, 0, 0)
		root.add_child(n)
		var ap := n.get_node("Animations") as AnimationPlayer
		ap.play(clip if ap.has_animation(clip) else "Idle")
		ap.seek(t, true)
		ap.pause()
		rangee.append(n)
	for i in 4:
		await process_frame
	var vues := {"face": 0.0, "profil": 90.0, "dos": 180.0, "trois_quarts": 40.0}
	for nom: String in vues:
		for n: Node3D in rangee:
			n.rotation.y = deg_to_rad(float(vues[nom]))
		cam.fov = 28.0
		cam.global_position = Vector3(0, 1.15, 8.6)
		cam.look_at(Vector3(0, 1.0, 0))
		await _photo(sortie.path_join(nom + ".png"))
	# gros plans sur le boss Tripo seul
	for n: Node3D in rangee:
		n.visible = (n == tripo)
		n.rotation.y = 0.0
	tripo.position = Vector3.ZERO
	var sq := tripo.find_child("Skeleton3D", true, false) as Skeleton3D
	# positions d'os APRÈS les modificateurs du squelette (raideur, pieds au sol) : lues sur des BoneAttachment3D
	var reperes := {}
	for nom: String in ["Head", "hand_r", "hand_l"]:
		var ba := BoneAttachment3D.new()
		ba.bone_name = nom
		sq.add_child(ba)
		reperes[nom] = ba
	for i in 3:
		await process_frame
	var os_g := func(nom: String) -> Vector3: return (reperes[nom] as Node3D).global_position
	var tete: Vector3 = os_g.call("Head") + Vector3(0, 0.16, 0)
	cam.fov = 22.0
	for p: Array in [["tete_face", Vector3(0, 0.1, 1)], ["tete_profil", Vector3(1, 0.15, 0)], ["tete_dos", Vector3(-0.3, 0.3, -1)]]:
		cam.global_position = tete + (p[1] as Vector3).normalized() * 1.5
		cam.look_at(tete)
		await _photo(sortie.path_join(p[0] + ".png"))
	for cote: String in ["d", "g"]:
		var main: Vector3 = os_g.call("hand_r" if cote == "d" else "hand_l")
		var sx := -1.0 if cote == "d" else 1.0
		var dirs := [Vector3(sx * 0.6, 0.2, 1.0), Vector3(sx * 1.0, 0.3, -0.2)]
		for k in dirs.size():
			cam.global_position = main + (dirs[k] as Vector3).normalized() * 1.6
			cam.look_at(main)
			await _photo(sortie.path_join("main_%s_%d.png" % [cote, k + 1]))
	cam.fov = 28.0
	quit(0)
