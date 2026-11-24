extends "res://outils/video_impacts_lances.gd"
## FILM 1re PERSONNE de la TRAÎNÉE des flèches (vue du joueur, arc réel ArcJoueur). Fenêtre hors écran (godot_slot.sh, verrou rendu) :
##   godot --path . --fixed-fps 30 --resolution 960x540 --script res://outils/video_fleche_trainee.gd -- --decor=jour|nuit|crypte --sortie=<dossier>
##        [--tirs=3] [--export]  (images f_00000.png… ; --export : sans aucune aide de test)
## Le joueur bande l'arc, vise un point lointain, lâche ; on filme jusqu'à l'impact.

var n := 0

func _go() -> void:
	sortie = _arg("sortie", "user://film_trainee")
	var decor := _arg("decor", "nuit")
	DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	if decor != "jour":
		s.options["nuit"] = ""
	root.add_child(s)
	current_scene = s
	for i in 20:
		await process_frame
	s.mannequin.position = Vector3(30, 0, 30)
	s.mur.position = Vector3(30, 1.3, 30)
	s.hud.visible = false
	var j: CharacterBody3D = s.joueur
	if decor == "crypte":
		s.placer_joueur(Vector3(0, 0, 3.5), 0.0)
		_salle()
		_tournage()
	else:
		s.placer_joueur(Vector3(0, 0, 3.0), 0.0)
	j.inventaire.ajouter("arc_chasseur", 1)
	j.inventaire.ajouter("fleche", 14)
	var arc: ArcJoueur = j.arc
	arc.souris_reelle = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame
	arc.equiper()
	var cible := Vector3(0.5, 1.4, -6.5) if decor == "crypte" else Vector3(0.8, 1.2, -30.0)
	for it in 6:
		var cv: Camera3D = arc._camera_visee()
		var d: Vector3 = cible - cv.global_position
		var fwd := -cv.global_transform.basis.z
		j.rotation.y += wrapf(atan2(-d.x, -d.z) - atan2(-fwd.x, -fwd.z), -PI, PI)
		j.tete.rotation.x = clampf(j.tete.rotation.x + (atan2(d.y, Vector2(d.x, d.z).length()) - asin(clampf(fwd.y, -1.0, 1.0))), -1.2, 1.2)
		await process_frame
		await process_frame
	for k in int(_arg("tirs", "3")):
		await _img(20)
		arc.appuyer()
		await _img(40)
		arc.relacher()
		if _arg("lateral") != "":   # contrôle : caméra d'observation sur le côté de la trajectoire
			var ob := Camera3D.new()
			s.add_child(ob)
			ob.global_position = j.global_position + Vector3(2.5, 1.6, -4.0)
			ob.look_at(j.global_position + Vector3(0.0, 1.4, -12.0))
			ob.current = true
		await _img(36)
		for i in 60:
			if arc.etat != arc.RECUP and arc._encochee:
				break
			await process_frame
	print("FILM %d images" % n)
	quit(0)

func _img(k: int) -> void:
	for i in k:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(sortie.path_join("f_%05d.png" % n))
		n += 1
