extends SceneTree
## Films des GESTES DE MAGIE (bras joués par les captures Mixamo, GestesMagie) dans scenes/test_magie.tscn.
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --write-movie <fichier.avi> --fixed-fps 60 --script res://outils/captures_gestes_magie.gd -- \
##       --geste=<nom> [--ralenti=0.5] [--avant]
##     gestes : lance (sort rapide à une main), charge (boule de feu : charge tenue puis départ), jet (jet tenu à une main),
##     double (double incantation : lancer à deux mains), double_jet (jet à deux mains), zone (sort de zone chargé),
##     droite (sort rapide de la main droite), epee (épée à droite + sort à gauche : enchaînement coup / sort).
##     --avant : gestes Mixamo coupés (anciennes poses fixes) pour la planche avant / après.
##   ... --script res://outils/captures_gestes_magie.gd -- --planche=<fichier.png> --geste=<nom> [--avant]
##     planche de 8 vignettes aux instants clés du geste.
##   godot --headless --path . --script res://outils/captures_gestes_magie.gd -- --bras
##     imprime la géométrie du bras FPS (épaules, longueurs, dans le repère de la caméra) utilisée par
##     sources_blender/scripts/gestes_magie.py.

const SCENE := preload("res://scenes/test_magie.tscn")

var s: Node3D
var m: MainSort
var l: Label

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _attendre(t: float) -> void:
	await create_timer(t, true, false, false).timeout

func _go() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await process_frame
	m = s.magie
	if _arg("bras") != "":
		_bras()
		quit(0)
		return
	GestesMagie.actif = _arg("avant") == ""
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(8, 8)
	calque.add_child(l)
	var geste := _arg("geste", "lance")
	if _arg("planche") != "":
		await _planche(geste, _arg("planche"))
	else:
		await _film(geste, float(_arg("ralenti", "1")))
	quit(0)

func _bras() -> void:
	var mains: Node3D = s.joueur.mains
	var sq: Skeleton3D = mains.get("_sq")
	var cam: Node3D = mains
	var p := func(os: String) -> Vector3:
		return cam.global_transform.affine_inverse() * (sq.global_transform * sq.get_bone_global_pose(sq.find_bone(os)).origin)
	for c in ["l", "r"]:
		var e: Vector3 = p.call("upperarm_" + c)
		var co: Vector3 = p.call("lowerarm_" + c)
		var h: Vector3 = p.call("hand_" + c)
		print("BRAS %s epaule %s coude %s main %s l1 %.4f l2 %.4f" % [c, e, co, h, e.distance_to(co), co.distance_to(h)])
	print("BRAS camera_vs_mains ", (s.joueur.camera as Node3D).global_transform.affine_inverse() * mains.global_transform)

## Équipe les mains, place le joueur face aux mannequins, pleine mana.
func _preparer(gauche: String, droite: String) -> void:
	m.equiper("droite", droite)
	m.equiper("gauche", gauche)
	s.placer_joueur(Vector3(0, 0, 1.6), 0.0)
	s.joueur.mana = s.joueur.mana_max
	m.recharges.clear()
	await _attendre(0.6)

func _recharger() -> void:
	s.joueur.mana = s.joueur.mana_max
	m.recharges.clear()

## Scénario d'un geste : liste de [délai avant (s), action, légende].
func _scenario(geste: String) -> Array:
	match geste:
		"lance":   # sort rapide (éclat de glace) : appui bref, deux fois
			return [["eclat_glace", "epee"], [0.5, "appui:gauche", "Sort rapide (main gauche)"], [0.08, "relache:gauche", ""],
				[1.1, "appui:gauche", ""], [0.08, "relache:gauche", ""], [1.2, "", ""]]
		"charge":   # boule de feu : charge tenue 1,2 s puis départ
			return [["boule_feu", "epee"], [0.5, "appui:gauche", "Charge (boule de feu)"], [1.3, "relache:gauche", "Depart"], [1.3, "", ""]]
		"jet":   # jet tenu
			return [["jet_flammes", "epee"], [0.5, "appui:gauche", "Jet tenu (main gauche)"], [2.2, "relache:gauche", "Fin du jet"], [1.0, "", ""]]
		"double":   # double incantation d'un sort rapide
			return [["eclat_glace", "eclat_glace"], [0.5, "appui:deux", "Double incantation (sort rapide)"], [0.08, "relache:deux", ""],
				[1.3, "appui:deux", ""], [0.08, "relache:deux", ""], [1.4, "", ""]]
		"double_charge":
			return [["boule_feu", "boule_feu"], [0.5, "appui:deux", "Double incantation (charge)"], [1.3, "relache:deux", "Depart"], [1.4, "", ""]]
		"double_jet":
			return [["jet_flammes", "jet_flammes"], [0.5, "appui:deux", "Double incantation (jet tenu)"], [2.2, "relache:deux", "Fin du jet"], [1.0, "", ""]]
		"zone":   # sort de zone chargé (explosion obscure)
			return [["explosion_obscure", "epee"], [0.5, "appui:gauche", "Sort de zone (charge)"], [1.3, "relache:gauche", "Depart"], [1.4, "", ""]]
		"droite":
			return [["vide", "eclat_glace"], [0.5, "appui:droite", "Sort rapide (main droite)"], [0.08, "relache:droite", ""],
				[1.1, "appui:droite", ""], [0.08, "relache:droite", ""], [1.2, "", ""]]
		"epee":   # coup d'épée puis sort, puis sort puis coup
			return [["eclat_glace", "epee"], [0.5, "coup", "Epee puis sort"], [0.45, "appui:gauche", ""], [0.08, "relache:gauche", ""],
				[1.0, "appui:gauche", "Sort puis epee"], [0.08, "relache:gauche", ""], [0.35, "coup", ""], [1.2, "", ""]]
	return []

func _action(a: String) -> void:
	var mains: Node3D = s.joueur.mains
	match a:
		"appui:gauche": m.appuyer("gauche")
		"appui:droite": m.appuyer("droite")
		"appui:deux":
			m.appuyer("gauche")
			m.appuyer("droite")
		"relache:gauche": m.relacher("gauche")
		"relache:droite": m.relacher("droite")
		"relache:deux":
			m.relacher("gauche")
			m.relacher("droite")
		"coup":
			mains.entrees.appuyer()
			await _attendre(0.05)
			mains.entrees.relacher()

func _film(geste: String, ralenti: float) -> void:
	var sc := _scenario(geste)
	await _preparer(sc[0][0], sc[0][1])
	var titre := ("AVANT (poses fixes) - " if not GestesMagie.actif else "") + ("ralenti x%.2f" % ralenti if ralenti < 1.0 else "vitesse reelle")
	l.text = titre
	Engine.time_scale = ralenti
	for e in sc.slice(1):
		await _attendre(float(e[0]))
		if String(e[2]) != "":
			l.text = titre + "\n" + String(e[2])
		_recharger()
		await _action(String(e[1]))
	Engine.time_scale = 1.0

## Planche : 12 vignettes légendées (instant, état de la main).
func _planche(geste: String, fichier: String) -> void:
	var sc := _scenario(geste)
	await _preparer(sc[0][0], sc[0][1])
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_constant_override("outline_size", 12)
	var duree := 0.0
	for e in sc.slice(1):
		duree += float(e[0])
	# --de=<s> --pas=<s> : 12 vignettes à pas fixe à partir de --de (sinon 12 instants répartis sur le geste)
	var instants := []
	var de := float(_arg("de", "0.45"))
	var pas_v := float(_arg("pas", str((duree - 0.75) / 11.0)))
	for i in 12:
		instants.append(de + pas_v * i)
	var vignettes: Array[Image] = []
	var t := 0.0
	var k := 0
	var evts := sc.slice(1)
	var prochain := float(evts[0][0])
	var ie := 0
	var pas := 1.0 / 60.0
	while k < instants.size():
		await process_frame
		t += root.get_process_delta_time() if root.get_process_delta_time() > 0.0 else pas
		while ie < evts.size() and t >= prochain:
			_recharger()
			await _action(String(evts[ie][1]))
			ie += 1
			if ie < evts.size():
				prochain += float(evts[ie][0])
		var mg: Incantation = m.inc["gauche"]
		var md: Incantation = m.inc["droite"]
		l.text = "%s%.2f s  G %s  D %s" % ["AVANT  " if not GestesMagie.actif else "", t, mg.nom(), md.nom()]
		if t >= float(instants[k]):
			await RenderingServer.frame_post_draw
			var img := root.get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
			vignettes.append(img)
			print("VIGNETTE %d t=%.2f %s" % [k, t, l.text])
			k += 1
	var p := Image.create(480 * 4, 270 * 3, false, Image.FORMAT_RGBA8)
	for i in vignettes.size():
		p.blit_rect(vignettes[i], Rect2i(0, 0, 480, 270), Vector2i((i % 4) * 480, (i / 4) * 270))
	p.save_png(fichier)
	print("PLANCHE ", fichier)
