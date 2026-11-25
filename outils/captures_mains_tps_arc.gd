extends SceneTree
## Planche 3e personne de chaque combinaison de mains (ce que le corps tient / affiche), fenêtre hors écran (godot_slot.sh) :
##   godot --path . --fixed-fps 60 --resolution 1280x720 --script res://outils/captures_mains_tps_arc.gd -- --planche=<fichier.png>
## Chaque case : on équipe d'abord épée + bouclier (état d'avant), puis la combinaison ; capture après 0,5 s, vue de trois quarts.

const SCENE := preload("res://scenes/test_combat.tscn")
var s: Node3D
var j: CharacterBody3D
var mg: MainSort
var l: Label

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _attendre(t: float) -> void:
	await create_timer(t, true, false, false).timeout

func _go() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mg = j.mains.magie
	mg.eq.apprendre_tout()
	s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	j.inventaire.ajouter("arc_chasseur", 1)
	j.inventaire.ajouter("fleche", 30)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -6.0)
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.position = Vector2(12, 8)
	calque.add_child(l)
	for i in 30:
		await process_frame
	j.basculer_vue(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	j.camera_tp.bras.spring_length = 2.2
	var imgs: Array[Image] = []
	var orb := float(_arg("orbite", "145"))
	var inv: InventaireMains = s.inventaire_ui
	# séquence joueur réelle : épée + bouclier par le menu, puis raccourcis 1-0 au clavier, puis lancer les sorts
	inv.equiper("droite", "epee")
	inv.equiper("gauche", "bouclier")
	await _cadre("menu : epee + bouclier", orb, imgs)
	var touches := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
	var voulues := _arg("touches", "")
	for i in touches.size():
		if voulues != "" and not (",%d," % ((i + 1) % 10)) in "," + voulues + ",":
			continue
		inv.equiper("droite", "epee")
		inv.equiper("gauche", "bouclier")
		await _attendre(0.3)
		for p in [true, false]:
			var e := InputEventKey.new()
			e.physical_keycode = touches[i]
			e.keycode = touches[i]
			e.pressed = p
			Input.parse_input_event(e)
			await process_frame
		var r: Dictionary = mg.eq.raccourcis[i] if i < mg.eq.raccourcis.size() else {}
		await _cadre("touche %d : %s | %s" % [(i + 1) % 10, mg.eq.mains["gauche"].get("id"), mg.eq.mains["droite"].get("id")], orb, imgs)
		if imgs.size() >= 9:
			_enregistrer(imgs, _arg("planche") .replace(".png", "_%d.png" % (i + 1)))
			imgs.clear()
	if imgs.size() > 0:
		_enregistrer(imgs, _arg("planche").replace(".png", "_fin.png"))
	quit(0)

func _cadre(titre: String, orb: float, imgs: Array[Image]) -> void:
	j.camera_tp.set("_orbite", deg_to_rad(orb))
	j.camera_tp.recaler()
	l.text = titre
	await _attendre(0.8)
	_liste(titre)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
	imgs.append(img)

func _enregistrer(imgs: Array[Image], fichier: String) -> void:
	var p := Image.create(640 * 3, 360 * 3, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		p.blit_rect(imgs[i], Rect2i(0, 0, 640, 360), Vector2i((i % 3) * 640, (i / 3) * 360))
	p.save_png(fichier)
	print("PLANCHE ", fichier)

func _ancien() -> void:
	var cas := [
		["epee + bouclier", "epee", "bouclier"], ["sort / sort", "boule_feu", "jet_flammes"], ["epee / sort", "epee", "jet_flammes"],
		["sort / bouclier", "boule_feu", "bouclier"], ["sort / main nue", "boule_feu", "vide"], ["epee / main nue", "epee", "vide"],
		["mains nues", "vide", "vide"], ["ARC", "arc", ""],
	]
	var imgs: Array[Image] = []
	for c in cas:
		if j.arc.actif:
			j.arc.ranger()
		mg.equiper("droite", "epee")
		mg.equiper("gauche", "bouclier")
		await _attendre(0.4)
		if c[1] == "arc":
			j.arc.equiper()
		else:
			mg.equiper("droite", c[1])
			mg.equiper("gauche", c[2])
		j.camera_tp.set("_orbite", deg_to_rad(-35.0))
		j.camera_tp.recaler()
		l.text = String(c[0])
		await _attendre(0.7)
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		imgs.append(img)
	var p := Image.create(640 * 3, 360 * 3, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		p.blit_rect(imgs[i], Rect2i(0, 0, 640, 360), Vector2i((i % 3) * 640, (i / 3) * 360))
	p.save_png(_arg("planche", "res://planche_mains_tps.png"))
	print("PLANCHE ", _arg("planche"))
	quit(0)

func _liste(t: String) -> void:
	print("== ", t)
	for n in j.corps.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.is_visible_in_tree():
			var chemin := str(j.corps.get_path_to(mi))
			if chemin.contains("Tps") or chemin.contains("Copie") or chemin.contains("Attach") or chemin.contains("Epee") or chemin.contains("Arme"):
				print("   VIS ", chemin)
	var tp: CorpsMainsTps = j.corps.mains_tps
	print("   tps: cat D=", tp.categorie("droite"), " G=", tp.categorie("gauche"), " _arme_d=", tp.get("_arme_d"), " src_d=", tp.get("_source_d"), " objet_g=", tp.get("_objet_g"), " proc=", tp.is_processing(), " corps_proc=", j.corps.is_processing(), " mode=", j.corps.process_mode, " mains_tps_mode=", tp.process_mode)
	for n in tp.get_children():
		print("   enfant MainsTps ", n.name)
	var ac = j.corps.get("arme_corps")
	print("   arme_corps visible=", ac.visible if ac is Node3D else "-", " arc=", j.arc.actif, " pivot_torche=", j.corps.pivot_torche.visible)
