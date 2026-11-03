extends "res://outils/captures_sorts_vfx.gd"
## Captures et film du RAYON DU NÉANT (data/sorts/rayon_neant.tres, scripts/magie/cercle_neant.gd + rayon_neant.gd), en jeu : le
## vrai sort, maintenu puis relâché (aucune charge imposée). Fenêtre via godot_slot.sh (hors écran), avec --fixed-fps 60 :
##   godot --path . --fixed-fps 60 --disable-vsync --resolution 960x540 --script res://outils/captures_rayon_neant.gd -- --nouvelle \
##       --sortie=<dossier> [--main=droite|gauche|double] [--tps] [--film] [--pitch=-2] [--cible=mannequin|vide]
## Captures (PNG) : debut, mi, plein, rayon, rayon2, impact, apres ; avec --film : <dossier>/f_00000.png … (30 images /s).
## Chronologie (images de jeu à 60 /s, depuis l'appui) : incantation 12 ; charge 84 (1,4 s) ; départ ; rayon 51 (0,85 s) ; tache ensuite.

## Image du jeu portée à 960x540 (la fenêtre rend en 640x360 quoi qu'on demande).
func _image960() -> Image:
	var im: Image = await _image()
	if im.get_width() != 960:
		im.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	return im

func _go() -> void:
	sortie = _arg("sortie", "user://rayon_neant")
	DirAccess.make_dir_recursive_absolute(sortie)
	await _preparer()
	var main := _arg("main", "droite")
	var tps := _arg("tps") != ""
	var film := _arg("film") != ""
	m.relacher("gauche")
	m.relacher("droite")
	if main == "double":
		m.equiper("gauche", "rayon_neant")
		m.equiper("droite", "rayon_neant")
	else:
		m.equiper("gauche" if main == "droite" else "droite", "")
		m.equiper(main, "rayon_neant")
	if _arg("cible", "mannequin") == "vide":
		s.placer_joueur(Vector3(0, 0, 1.6), 180.0, float(_arg("pitch", "-5")))
	else:
		s.placer_joueur(Vector3(0, 0, -1.75 + 3.5), 0.0, float(_arg("pitch", "-2")))
	if j.has_method("basculer_vue"):
		j.basculer_vue(tps)
	if tps:
		j.camera_tp.set("_orbite", deg_to_rad(float(_arg("orbite", "-35"))))
		j.camera_tp.recaler()
	else:
		j.camera.current = true
	await _attendre(75)
	var n := 0
	var tot := 0
	var points := {}   # nom → image de jeu (depuis l'appui) où capturer
	if not film:
		points = {"debut": 14, "mi": 72, "plein": 100, "rayon": 100 + 14, "rayon2": 100 + 30, "impact": 100 + 62, "apres": 100 + 140}
	var appui := 0
	var fin_film := 100 + 200 + (60 if film else 0)
	var boutons: Array = ["gauche", "droite"] if main == "double" else [main]
	for b in boutons:
		m.appuyer(b)
	for k in fin_film:
		if k == 98:
			for b in boutons:
				m.relacher(b)
		await _attendre(1)
		tot += 1
		if film:
			if tot % 2 == 0:
				var im := await _image960()
				im.save_png(sortie.path_join("f_%05d.png" % n))
				n += 1
		else:
			for nom in points:
				if points[nom] == k:
					var im := await _image960()
					im.save_png(sortie.path_join("%s.png" % nom))
					print("CAPTURE ", nom)
	print("FIN %d images" % n)
	quit(0)
