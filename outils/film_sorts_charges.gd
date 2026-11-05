extends "res://outils/captures_sorts_vfx.gd"
## Preuves de la CHARGE COMMUNE des sorts lancés (ChargeSort) : FENÊTRE (godot_slot.sh : hors écran), --fixed-fps 60 :
##   film   : godot --path . --resolution 1280x720 --fixed-fps 60 --disable-vsync --script res://outils/film_sorts_charges.gd -- \
##              --nouvelle --mode=film --sorts=boule_feu,trait_ombre --sortie=<dossier>
##            → <dossier>/f_00000.png … (une image sur 2 : 30 i/s) : pour chaque sort, un tap (tir non chargé) puis une charge
##              pleine relâchée, sur le mannequin (chiffres de dégâts du mannequin), légende en bas de l'image.
##   main   : … --mode=main --sorts=boule_feu,eclat_glace,trait_ombre --sortie=<dossier>
##            → <dossier>/main_<sort>_<debut|mi|max>.png : gros plan de la main pendant la charge.

var _legende: Label

func _go() -> void:
	sortie = _arg("sortie", "user://film_charges")
	DirAccess.make_dir_recursive_absolute(sortie)
	await _preparer()
	var cl := CanvasLayer.new()
	cl.layer = 50
	root.add_child(cl)
	_legende = Label.new()
	_legende.add_theme_font_override("font", Palette.police())
	_legende.add_theme_font_size_override("font_size", 28)
	_legende.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_legende.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03))
	_legende.add_theme_constant_override("outline_size", 8)
	_legende.position = Vector2(24, root.size.y - 64)
	cl.add_child(_legende)
	var sorts := _arg("sorts", "boule_feu,trait_ombre").split(",", false)
	if _arg("mode", "film") == "main":
		_legende.visible = false
		for id in sorts:
			await _main(id)
	else:
		var n := 0
		for id in sorts:
			n = await _film(id, n)
		print("FILM %d images" % n)
	quit(0)

func _viser(cible: Node3D) -> void:
	var c := Elements._centre(cible)
	for k in 3:
		var d := c - j.camera.global_position
		j.rotation.y = atan2(-d.x, -d.z)
		j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		await process_frame

## Film d'un sort : `n` = numéro de la prochaine image ; renvoie le suivant.
func _film(id: String, n: int) -> int:
	m.relacher("droite")
	m.equiper("gauche", "")
	m.equiper("droite", id)
	var mq: Node3D = s.mannequin
	s.placer_joueur(Vector3(0.6, 0, 4.2), 0.0)
	await _viser(mq)
	j.camera.current = true
	var nom: String = m.eq.sort_par_id(id).nom
	await _attendre(40)
	_legende.text = "%s : tir NON chargé (appui bref)" % nom
	n = await _filmer(30, n)
	m.appuyer("droite")
	n = await _filmer(1, n)
	m.relacher("droite")
	n = await _filmer(95, n)
	_legende.text = "%s : maintenir = charge…" % nom
	m.appuyer("droite")
	var plein := false
	for k in 110:
		var c := m.charge("droite")
		if not plein and ChargeSort.pleine(c):
			plein = true
		_legende.text = ("%s : CHARGE MAX (×2 dégâts)" % nom) if plein else ("%s : charge %d %%" % [nom, roundi(c * 100.0)])
		n = await _filmer(1, n)
	m.relacher("droite")
	_legende.text = "%s : tir chargé à fond" % nom
	n = await _filmer(110, n)
	return n

## `k` images de jeu, une sur 2 enregistrée (film à 30 i/s).
var _impaire := false
func _filmer(k: int, n: int) -> int:
	for i in k:
		await _attendre(1)
		_impaire = not _impaire
		if _impaire:
			continue
		var im := await _image()
		im.save_png(sortie.path_join("f_%05d.png" % n))
		n += 1
	return n

## Gros plan de la main droite à trois moments de la charge.
func _main(id: String) -> void:
	m.relacher("droite")
	m.equiper("gauche", "")
	m.equiper("droite", id)
	s.placer_joueur(Vector3(0, 0, 1.6), 180.0, 6.0)
	j.camera.current = true
	await _attendre(75)
	var sd: DonneesSort = m.eq.sort_par_id(id)
	var tp := ChargeSort.temps_plein(sd)
	m.appuyer("droite")
	# incantation puis : début (~5 %), mi (50 %), max (pulsation, 0,25 s après le maximum)
	var moments := [["debut", sd.incantation + tp * 0.05], ["mi", sd.incantation + tp * 0.5], ["max", sd.incantation + tp + 0.25]]
	var t := 0.0
	for mo in moments:
		while t < float(mo[1]):
			await _attendre(1)
			t += 1.0 / 60.0
		_cadrer("droite")
		cam_gp.current = true
		var im := await _image()
		im.save_png(sortie.path_join("main_%s_%s.png" % [id, mo[0]]))
		print("CAPTURE main_%s_%s charge=%.2f" % [id, mo[0], m.charge("droite")])
		j.camera.current = true
	m.relacher("droite")
	await _attendre(120)
