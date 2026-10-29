extends SceneTree
## Planches du lot M1 « sorts en gros pixels » (docs INSPIRATION_IGNITE §2.15) : impacts et explosions de sorts HORS
## corps (mur, sol : GestionMagie.impact / zone / chaine, pas ImpactCorps), image par image, et main au repos (aura de feu).
## FENÊTRE (via godot_slot.sh : hors écran), couche fine imposée (--detail-sorts=eleve par défaut) :
##   godot --path . --fixed-fps 60 --disable-vsync --script res://outils/captures_gros_pixels.gd -- \
##       --planche=<fichier.png> [--images=2,6,14,26] [--effets=boule_feu,lance_givre,...] [--main=<fichier.png>]
##       [--tenue=1]   main : aperçu avec avant-bras sur le calque 18 et flammes resserrées (comme fps/avant_bras_v2)
##   Vignettes : zone centrale 960x540 de la fenêtre 1280x720, sans ré-échantillonnage (pixels francs).

const SCENE := preload("res://scenes/test_magie.tscn")
const EFFETS := ["boule_feu", "explosion_incendiaire", "lance_givre", "nova_gelee", "trait_ombre", "explosion_obscure", "chaine_eclairs"]
const VW := 960
const VH := 540

var s: Node3D
var gm: GestionMagie
var l: Label

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _go() -> void:
	if _arg("detail-sorts") == "":
		CoucheMagie.niveau_force = CoucheMagie.ELEVE
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await process_frame
	gm = GestionMagie.obtenir()
	for mq in [s.mannequin, s.mannequin2, s.mannequin3]:
		(mq as Node3D).global_position += Vector3(0, -50, 0)
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.position = Vector2(170, 100)
	calque.add_child(l)
	s.placer_joueur(Vector3(0, 0, 2.0), 0.0, -8.0)
	var m: MainSort = s.magie
	m.equiper("droite", "epee")
	m.equiper("gauche", "boule_feu")
	for i in 60:
		await process_frame
	print("COUCHE FINE ", gm.couche != null and gm.couche.fine(), "  echelle ", gm.couche.facteur_couche() if gm.couche != null else 1)
	if _arg("main") != "":
		if _arg("tenue") != "":
			# APERÇU de la fusion avec fps/avant_bras_v2 : avant-bras sur le calque 18 (mains.gd de v2) et tenue « runes »
			# (main_sort.gd de v2 : flammes resserrées × 0,6 autour de la boule tenue)
			for mi: MeshInstance3D in (s.joueur.mains.bras as Node).find_children("*", "MeshInstance3D", true, false):
				mi.layers = GestionMagie.CALQUE_AVANT_BRAS
			for id in gm._auras:
				gm.echelles_aura[id] = 0.6
			for i in 30:
				await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(_arg("main"))
		print("MAIN ", _arg("main"), " ", img.get_size())
	if _arg("planche") != "":
		m.equiper("gauche", Equipement.MAIN_VIDE)
		await _planche(_arg("planche"))
	quit(0)

func _vignette() -> Image:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	if w != 1280 or h != 720:
		img.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	return img.get_region(Rect2i((1280 - VW) / 2, (720 - VH) / 2, VW, VH))

func _declencher(nom: String) -> void:
	# joueur à z = 2 face à -Z : mur virtuel à 3,4 m, sol à 4-5 m
	var mur := Vector3(0.0, 1.3, -1.4)
	var n := Vector3(0, 0, 1)
	match nom:
		"boule_feu":
			gm.impact("feu", mur, n, 1.0)
			gm.zone("feu", Vector3(0, 0, -1.4), 2.2, 1.2)
		"explosion_incendiaire":
			gm.zone("feu", Vector3(0, 0, -2.5), 3.0, 1.5)
		"lance_givre":
			gm.impact("glace", mur, n, 1.3)
		"nova_gelee":
			gm.zone("glace", Vector3(0, 0, -1.0), 4.5, 1.5)
		"trait_ombre":
			gm.impact("tenebres", mur, n, 1.0)
		"explosion_obscure":
			gm.zone("tenebres", Vector3(0, 0, -2.5), 3.5, 1.5)
		"chaine_eclairs":
			gm.chaine("electricite", [Vector3(-0.3, 1.3, 1.4), Vector3(-0.8, 1.2, -1.0), Vector3(0.9, 1.0, -2.2), Vector3(-0.2, 0.9, -3.5)])

func _planche(fichier: String) -> void:
	var images: Array = []
	for x in _arg("images", "2,6,14,26").split(","):
		images.append(int(x))
	var effets: Array = EFFETS
	if _arg("effets") != "":
		effets = Array(_arg("effets").split(","))
	var vignettes: Array[Image] = []
	for nom in effets:
		gm.tout_arreter()
		for i in 45:
			await process_frame
		_declencher(nom)
		var f := 0
		var dernier: int = images[images.size() - 1]
		while f <= dernier:
			if images.has(f):
				l.text = "%s  image %d" % [nom, f]
				await RenderingServer.frame_post_draw
				vignettes.append(_vignette())
			else:
				await process_frame
			f += 1
	var cols := images.size()
	var p := Image.create(VW * cols, VH * effets.size(), false, Image.FORMAT_RGBA8)
	for i in vignettes.size():
		p.blit_rect(vignettes[i], Rect2i(0, 0, VW, VH), Vector2i((i % cols) * VW, (i / cols) * VH))
	p.save_png(fichier)
	print("PLANCHE ", fichier, " ", p.get_size())
