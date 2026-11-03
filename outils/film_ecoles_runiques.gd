extends "res://outils/captures_sorts_vfx.gd"
## Film d'un sort tenu en main droite (FPS, cadrage de captures_sorts_vfx « gros plan ») : repos → début d'incantation →
## charge → lancer → retour au repos. Une image sur deux (30 /s) en PNG, à assembler avec ffmpeg.
##   godot --path . --fixed-fps 60 --disable-vsync --script res://outils/film_ecoles_runiques.gd -- --nouvelle \
##       --sort=eclat_glace|arc_electrique|trait_ombre|boule_feu --sortie=<dossier> [--fov=40 --cible_y=0.035]
## (via godot_slot.sh : fenêtre hors écran.) Images : <dossier>/f_00000.png …
## Phases (images de jeu à 60 /s) : repos 120, début 24, charge 130, lancer 36, retour 110.
## « charge » : CHARGE imposée sans lancer (RunesOrbite.forcer_charge, montée de 0 à 1) ; « lance » : le vrai sort, tenu 36 images.
const PHASES := [["repos", 110], ["debut", 20], ["charge", 130], ["lance", 40], ["retour", 110]]

func _go() -> void:
	sortie = _arg("sortie", "user://film")
	DirAccess.make_dir_recursive_absolute(sortie)
	await _preparer()
	var sort := _arg("sort", "boule_feu")
	m.relacher("gauche")
	m.relacher("droite")
	m.equiper("gauche", "")
	m.equiper("droite", sort)
	s.placer_joueur(Vector3(0, 0, 1.6), 180.0, 6.0)
	j.camera.current = true
	await _attendre(75)
	var n := 0
	var tot := 0
	for ph in PHASES:
		match String(ph[0]):
			"lance":
				RunesOrbite.forcer_charge = -1.0
				m.appuyer("droite")
			"retour":
				m.relacher("droite")
		for k in int(ph[1]):
			if String(ph[0]) == "debut":
				RunesOrbite.forcer_charge = 0.0
			elif String(ph[0]) == "charge":
				RunesOrbite.forcer_charge = clampf(float(k) / 70.0, 0.0, 1.0)
			await _attendre(1)
			tot += 1
			if tot % 2 == 0:
				_cadrer("droite")
				cam_gp.current = true
				var im := await _image()
				im.save_png(sortie.path_join("f_%05d.png" % n))
				n += 1
	print("FILM %d images" % n)
	quit(0)
