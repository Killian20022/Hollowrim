extends SceneTree
## Planche du modèle de l'ARC DE CHASSEUR (fenêtre hors écran, via godot_slot.sh) :
##   godot --path . --resolution 1280x720 --disable-vsync --script res://outils/planche_arc.gd -- --sortie=<fichier.png>
## De gauche à droite : arc au repos (profil), arc à pleine allonge avec la flèche encochée (profil), arc au repos de 3/4,
## flèche seule (au-dessous). Rendu du jeu (shader ps1), fond gris neutre comme les références.

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _go() -> void:
	var sortie := _arg("sortie", "user://planche_arc.png")
	var monde := Node3D.new()
	root.add_child(monde)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.42, 0.43)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.73, 0.72)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	monde.add_child(we)
	var so := DirectionalLight3D.new()
	so.basis = Basis.looking_at(Vector3(-0.4, -0.5, -0.75), Vector3.UP)
	so.light_energy = 1.1
	monde.add_child(so)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.75
	cam.position = Vector3(0.0, -0.08, 3.0)
	monde.add_child(cam)
	cam.current = true
	# profil : l'arc tourné de 90° (la corde à droite, comme arc_trois_vues)
	var repos := ArcModele.new()
	monde.add_child(repos)
	repos.position = Vector3(-0.95, 0.0, 0.0)
	repos.rotation.y = -PI * 0.5
	repos.regler(0.0, false)
	var bande := ArcModele.new()
	monde.add_child(bande)
	bande.position = Vector3(-0.15, 0.0, 0.0)
	bande.rotation.y = -PI * 0.5
	bande.regler(1.0, true)
	var trois := ArcModele.new()
	monde.add_child(trois)
	trois.position = Vector3(0.9, 0.0, 0.0)
	trois.rotation.y = -PI * 0.5 + 0.6
	trois.regler(0.0, false)
	var f := ArcModele.creer_fleche()
	monde.add_child(f)
	f.rotation.y = -PI * 0.5
	f.rotation.x = 0.0
	f.position = Vector3(0.95, -0.78, 0.2)
	f.rotation = Vector3(0.0, PI * 0.5, 0.0)
	f.position = Vector3(0.45, -0.78, 0.2)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.save_png(sortie)
	print("PLANCHE ", sortie, " ", im.get_size())
	quit(0)
