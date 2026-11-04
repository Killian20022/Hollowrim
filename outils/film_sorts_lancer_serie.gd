extends "res://outils/captures_sorts_vfx.gd"
## Plusieurs films de TRANSITION de sorts dans UN SEUL lancement de Godot (branche vfx/sorts_lancer ; le lancement est long à obtenir
## quand beaucoup d'agents partagent les créneaux). Même rendu que film_sorts_lancer.gd.
##   godot --path . --fixed-fps 60 --disable-vsync --script res://outils/film_sorts_lancer_serie.gd -- --nouvelle --taille=1280x720 \
##       --sortie=<dossier> --series=nom:sort:main:vue:cadre:cible[;nom2:…] [--pas=2 --repos=30 --tenu=70 --retour=60]
##   sort = id de sort (jet_flammes, boule_feu…) ; main = gauche|droite|double ; vue = fps|tps ; cadre = jeu|gros|cote ; cible = vide|mannequin.
## Images : <dossier>/<nom>/f_00000.png …

func _go() -> void:
	sortie = _arg("sortie", "user://film")
	if _arg("taille") != "" and DisplayServer.get_name() != "headless":
		var wh := _arg("taille").split("x")
		root.size = Vector2i(int(wh[0]), int(wh[1]))
	await _preparer()
	for sc in _arg("series", "").split(";", false):
		var c := sc.split(":")
		await _film(c[0], c[1], c[2], c[3], c[4], c[5] if c.size() > 5 else "vide")
	print("SERIE finie")
	quit(0)

func _film(nom: String, sort: String, main: String, vue: String, cadre: String, cible: String) -> void:
	var dossier := sortie.path_join(nom)
	DirAccess.make_dir_recursive_absolute(dossier)
	var tps := vue == "tps"
	var pas := int(_arg("pas", "2"))
	var mains: Array = ["gauche", "droite"] if main == "double" else [main]
	var autre := "gauche" if main == "droite" else "droite"
	m.relacher("gauche")
	m.relacher("droite")
	await _attendre(2)
	if main == "double":
		m.equiper("gauche", sort)
		m.equiper("droite", sort)
	else:
		m.equiper(autre, "")
		m.equiper(main, sort)
	if cible == "vide":
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
	var phases: Array = [["repos", int(_arg("repos", "30"))], ["appui", 1], ["tenu", int(_arg("tenu", "70"))], ["relache", 1], ["retour", int(_arg("retour", "60"))]]
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
				_cam(cadre, tps, main)
				var im := await _image()
				im.save_png(dossier.path_join("f_%05d.png" % n))
				n += 1
	print("FILM %s %d images" % [nom, n])
	for h in mains: m.relacher(h)
	await _attendre(120)

func _cam(cadre: String, tps: bool, main: String) -> void:
	if tps:
		j.camera_tp.camera.current = true
	elif cadre == "gros":
		_cadrer(main)
		cam_gp.current = true
	elif cadre == "cote":
		# de côté (à droite de la main, un peu devant) : on lit l'hélice et les cercles le long du jet
		var pm: Vector3 = (m.paume["droite"] as Node3D).global_position
		if main == "double":
			pm = ((m.paume["gauche"] as Node3D).global_position + pm) * 0.5
		var bc: Basis = j.camera.global_transform.basis
		var pos := pm + bc.x * float(_arg("cx", "1.6")) - bc.z * float(_arg("cz", "1.3")) + bc.y * 0.1
		cam_gp.fov = float(_arg("fov", "50"))
		cam_gp.global_transform = Transform3D(Basis.looking_at(pm - bc.z * float(_arg("vz", "1.2")) - pos, Vector3.UP), pos)
		cam_gp.current = true
	else:
		j.camera.current = true
