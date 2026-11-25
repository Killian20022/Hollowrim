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
