extends SceneTree
## Planche de contrôle d'un ennemi Tripo : [ancien modèle | nouveau | garde Tripo (échelle)] vus de face / profil / dos / trois-quarts, + gros plan de l'arme en main.
##   godot --path . --script res://outils/planche_ennemis_tripo.gd -- --ennemis-tripo --ennemi=draugr --arme=epee --sortie=<dossier>
## Écrit face.png, profil.png, dos.png, trois_quarts.png, arme_1.png, arme_2.png dans <dossier>.
var cam: Camera3D
var rangee: Array = []

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _ancien(id: String, arme: String) -> Node3D:
	match id:
		"draugr":
			return DraugrNordique.creer({"bouclier": "", "epee": arme == "epee"})
		"archer":
			var n := DraugrNordique.creer({"bouclier": "", "epee": false})
			EnnemisNordiques._arc(n.find_child("Skeleton3D", true, false))
			return n
		"squelette":
			return SqueletteGuerrier.modele("epee" if arme == "epee" else arme)
	return null

func _go() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1200, 800)
	var sortie := _arg("sortie", "user://planche")
	DirAccess.make_dir_recursive_absolute(sortie)
	var id := _arg("ennemi", "draugr")
	var arme := _arg("arme", "epee")
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
	env.environment.background_color = Color(0.45, 0.47, 0.52)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.environment.ambient_light_energy = 0.6
	root.add_child(env)
	cam = Camera3D.new()
	cam.fov = 28.0
	root.add_child(cam)
	cam.current = true
	var modeles: Array = []
	var ancien := _ancien(id, arme)
	if ancien != null:
		modeles.append(ancien)
	var nouveau := EnnemiTripo.creer(id, "arc" if id == "archer" else arme)
	nouveau.scale = Vector3.ONE * float(nouveau.get_meta("echelle_tripo", 1.0))
	modeles.append(nouveau)
	modeles.append(GardeTripo.creer("tripo_garde_epee"))
	for i in modeles.size():
		var n: Node3D = modeles[i]
		n.position = Vector3((i - (modeles.size() - 1) / 2.0) * 1.3, 0, 0)
		root.add_child(n)
		var ap := n.get_node("Animations") as AnimationPlayer
		ap.play("Sword_Idle" if ap.has_animation("Sword_Idle") else "Idle")
		ap.seek(0.5, true)
		rangee.append(n)
	for i in 4:
		await process_frame
	var vues := {"face": 0.0, "profil": 90.0, "dos": 180.0, "trois_quarts": 40.0}
	for nom: String in vues:
		for n: Node3D in rangee:
			n.rotation.y = deg_to_rad(float(vues[nom]))
		cam.global_position = Vector3(0, 1.1, 8.0)
		cam.look_at(Vector3(0, 0.95, 0))
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(sortie.path_join(nom + ".png"))
	# gros plans de l'arme (main droite) : deux angles
	for n: Node3D in rangee:
		n.rotation.y = 0.0
	var cible := nouveau
	for n: Node3D in rangee:
		n.visible = (n == nouveau)
	var sq := cible.find_child("Skeleton3D", true, false) as Skeleton3D
	var arme_n := sq.get_node_or_null("Arme") as Node3D
	var main := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_r")).origin
	var centre := main
	if arme_n != null:
		var a_n := arme_n.get_child(0) as Node3D
		centre = a_n.global_position + a_n.global_transform.basis.y.normalized() * 0.18
	var dist := float(_arg("dist", "1.8"))
	var dirs := [Vector3(-0.9, 0.2, 1.0), Vector3(1.0, 0.25, 0.5), Vector3(0.0, 0.3, 1.0), Vector3(-1.0, 0.5, -0.3)]
	for k in dirs.size():
		cam.fov = 22.0
		cam.global_position = centre + (dirs[k] as Vector3).normalized() * dist
		cam.look_at(centre)
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(sortie.path_join("arme_%d.png" % (k + 1)))
	quit(0)
