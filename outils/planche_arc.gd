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
	monde.add_child(cam)
	cam.current = true
	# comme arc_trois_vues : profil (corde à droite), face, trois quarts ; puis l'arc à pleine allonge avec la flèche encochée
	cam.size = 1.55
	cam.position = Vector3(0.0, 1.98, 3.0)   # tout est posé à 2 m de haut : sous le niveau du sol, le shader ps1 met de la neige
	var vues := [[-1.15, PI * 0.5, 0.0, false], [-0.45, 0.0, 0.0, false], [0.1, PI * 0.5 - 0.55, 0.0, false], [0.75, PI * 0.5, 1.0, true]]
	for v in vues:
		var a := ArcModele.new()
		monde.add_child(a)
		a.position = Vector3(v[0], 2.0, 0.0)
		a.rotation.y = v[1]
		a.regler(v[2], v[3])
	var fl := ArcModele.creer_fleche()   # la flèche seule, en bas, pointe à droite (comme arc_presentation)
	monde.add_child(fl)
	fl.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	fl.position = Vector3(-0.75, 1.27, 0.3)
	if _arg("gros") != "":
		cam.size = 0.45
		for a2 in monde.get_children():
			if a2 is ArcModele and _arg("gros") == "2":
				(a2 as ArcModele).mi_corde.visible = false
		cam.position = Vector3(-0.45, 1.6, 3.0)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.save_png(sortie)
	print("PLANCHE ", sortie, " ", im.get_size())
	quit(0)
