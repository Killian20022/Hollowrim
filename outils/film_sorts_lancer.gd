extends "res://outils/captures_sorts_vfx.gd"
## Film de la TRANSITION repos → lancer → jet → fin d'un sort (branche vfx/sorts_lancer, docs/MAGIE_TRANSITIONS.md), vue FPS ou 3e personne.
##   godot --path . --fixed-fps 60 --disable-vsync --script res://outils/film_sorts_lancer.gd -- --nouvelle \
##       --sort=jet_flammes|boule_feu|... --main=droite|gauche|double --vue=fps|tps [--cadre=jeu|gros] [--cible=vide|mannequin] \
##       [--orbite=-125] [--pas=3] --sortie=<dossier>
## (via godot_slot.sh : fenêtre hors écran.) Images : <dossier>/f_00000.png … ; jet = tenu 1,5 s ; boule = relâchée après 0,7 s de charge.
## Phases (images de jeu à 60 /s) : repos, appui, tenu, relâché, retour.

func _go() -> void:
	sortie = _arg("sortie", "user://film")
	DirAccess.make_dir_recursive_absolute(sortie)
	if _arg("taille") != "" and DisplayServer.get_name() != "headless":
		var wh := _arg("taille").split("x")
		root.size = Vector2i(int(wh[0]), int(wh[1]))
	await _preparer()
	var sort := _arg("sort", "jet_flammes")
	var main := _arg("main", "droite")
	var tps := _arg("vue", "fps") == "tps"
	var cadre := _arg("cadre", "jeu")
	var pas := int(_arg("pas", "3"))
	var mains: Array = ["gauche", "droite"] if main == "double" else [main]
	var autre := "gauche" if main == "droite" else "droite"
	m.relacher("gauche")
	m.relacher("droite")
	if main == "double":
		m.equiper("gauche", sort)
		m.equiper("droite", sort)
	else:
		m.equiper(autre, "")
		m.equiper(main, sort)
	if _arg("cible", "vide") == "vide":
		s.placer_joueur(Vector3(0, 0, 1.6), 180.0, 6.0)
	else:
		s.placer_joueur(Vector3(0, 0, -1.75 + 3.5), 0.0, -2.0)
	if j.has_method("basculer_vue"):
		j.basculer_vue(tps)
	if not tps:
		j.camera.current = true
	else:
		j.camera_tp.set("_orbite", deg_to_rad(float(_arg("orbite", "-125"))))
		j.camera_tp.recaler()
	await _attendre(75)
	var phases: Array = [["repos", int(_arg("repos", "45"))], ["appui", 1], ["tenu", int(_arg("tenu", "90"))], ["relache", 1], ["retour", int(_arg("retour", "75"))]]
	var n := 0
	var tot := 0
	for ph in phases:
		match String(ph[0]):
			"appui":
				for h in mains: m.appuyer(h)
			"relache":
				for h in mains: m.relacher(h)
		for k in int(ph[1]):
			await _attendre(1)
			tot += 1
			if tot % pas == 0:
				if cadre == "cote" and not tps:
					# de côté (à droite de la main, un peu devant) : on lit l'hélice et les cercles le long du jet
					var pm: Vector3 = (m.paume["droite"] as Node3D).global_position
					if main == "double":
						pm = ((m.paume["gauche"] as Node3D).global_position + pm) * 0.5
					var bc: Basis = j.camera.global_transform.basis
					var pos := pm + bc.x * float(_arg("cx", "1.6")) - bc.z * float(_arg("cz", "1.3")) + bc.y * 0.1
					cam_gp.fov = float(_arg("fov", "50"))
					cam_gp.global_transform = Transform3D(Basis.looking_at(pm - bc.z * float(_arg("vz", "1.2")) - pos, Vector3.UP), pos)
					cam_gp.current = true
				elif cadre == "gros" and not tps:
					_cadrer(main)
					cam_gp.current = true
				elif tps:
					j.camera_tp.camera.current = true
				else:
					j.camera.current = true
				var im := await _image()
				im.save_png(sortie.path_join("f_%05d.png" % n))
				n += 1
	print("FILM %d images" % n)
	quit(0)
