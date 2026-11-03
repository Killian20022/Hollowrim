extends "res://outils/captures_sorts_vfx.gd"
## Film de l'ORAGE RUNIQUE (sort à charge de l'électricité), vue FPS entière, mannequin à 3,5 m : main DROITE (repos, charge,
## décharge, retour) puis DOUBLE magie (charge des deux mains, décharge). Une image sur deux (30 /s) en PNG, à assembler avec ffmpeg.
##   godot --path . --fixed-fps 60 --disable-vsync --script res://outils/film_orage_runique.gd -- --nouvelle \
##       --sortie=<dossier> --taille=960x540 [--sort=orage_runique]
## (via godot_slot.sh : fenêtre hors écran.) Images : <dossier>/f_00000.png …
var _n := 0
var _tot := 0

func _images(frames: int) -> void:
	for k in frames:
		await _attendre(1)
		_tot += 1
		if _tot % 2 == 0:
			var im := await _image()
			im.save_png(sortie.path_join("f_%05d.png" % _n))
			_n += 1

func _go() -> void:
	sortie = _arg("sortie", "user://film")
	if _arg("taille") != "" and DisplayServer.get_name() != "headless":
		var wh := _arg("taille").split("x")
		root.size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(sortie)
	await _preparer()
	var sort := _arg("sort", "orage_runique")
	m.relacher("gauche")
	m.relacher("droite")
	m.equiper("gauche", "")
	m.equiper("droite", sort)
	s.placer_joueur(Vector3(0, 0, -1.75 + 3.5), 0.0, -2.0)
	j.camera.current = true
	await _attendre(75)
	# main droite : repos, charge (1,4 s : plafonnée), décharge, retour
	await _images(40)
	m.appuyer("droite")
	await _images(85)
	m.relacher("droite")
	await _images(75)
	# double magie : les deux mains
	m.equiper("gauche", sort)
	await _attendre(40)
	await _images(20)
	m.appuyer("gauche")
	m.appuyer("droite")
	await _images(85)
	m.relacher("gauche")
	m.relacher("droite")
	await _images(80)
	print("FILM %d images" % _n)
	quit(0)
