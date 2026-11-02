extends SceneTree
## Planches studio des objets du monde (outils/rendu_objet.gd = RenduObjet) : une case par objet, nom dessous, fond sombre.
##   godot --path . --script res://outils/planche_objets_monde.gd -- --sortie=<dossier> [--ids=a,b,c] [--nom=planche.png]
##     sans --ids : planche_bijoux.png (les 10 bijoux, 2 vues) puis planche_armures_sol.png (armures qui ont un modèle au sol).
##   --icones=<dossier> : en plus, un PNG transparent 64 px par objet (essai des futures icônes).
## Avec fenêtre (godot_slot.sh : hors écran) : un Godot --headless ne dessine rien.

const TAILLE_RENDU := 96
const AGRANDI := 2
const FOND := Color("#14110d")
var _sortie := ""
var _icones := ""

func _init() -> void:
	_go.call_deferred()

func _att(n: int) -> void:
	for i in n:
		await process_frame

func _go() -> void:
	var ids: Array = []
	var nom := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			_sortie = a.substr(9)
		elif a.begins_with("--ids="):
			ids = Array(a.substr(6).split(","))
		elif a.begins_with("--nom="):
			nom = a.substr(6)
		elif a.begins_with("--icones="):
			_icones = a.substr(9)
	if _sortie == "":
		_sortie = "res://captures/objets_monde"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED      # planche nette en 1280 x 720 (le jeu rend en 640 x 360)
	DisplayServer.window_set_size(Vector2i(1100, 900))
	if not ids.is_empty():
		await _planche(ids, [[0.65, -0.62]], nom if nom != "" else "planche_objets.png", "Objets")
	else:
		var bijoux: Array = []
		var armures: Array = []
		for oid: String in Inventaire.ids_connus():
			if Inventaire.categorie_de(oid) == "bijou":
				bijoux.append(oid)
			elif Inventaire.categorie_de(oid) == "armure" and ObjetMonde.chemin_modele(oid) != "":
				armures.append(oid)
		await _planche(bijoux, [[0.65, -0.62], [0.0, -1.35]], "planche_bijoux.png", "Bijoux — rendu studio (taille réelle, deux vues : 3/4 et dessus)")
		if not armures.is_empty():
			await _planche(armures, [[0.65, -0.55]], "planche_armures_sol.png", "Armures au sol — rendu studio")
		else:
			print("INFO aucune armure n'a encore de modèle au sol")
	quit(0)

func _planche(ids: Array, vues: Array, fichier: String, titre: String) -> void:
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ui)
	var bg := ColorRect.new()
	bg.color = FOND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var t := Label.new()
	t.text = titre
	t.position = Vector2(16, 8)
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color("#d8c9a8"))
	ui.add_child(t)
	var grille := GridContainer.new()
	var case_px := TAILLE_RENDU * AGRANDI
	var largeur := DisplayServer.window_get_size().x - 20
	grille.columns = clampi(int(largeur / (case_px + 8)), 1, 10)      # une colonne par objet, ses vues empilées
	var rangs := ceili(float(ids.size()) / grille.columns)             # fenêtre assez haute pour toutes les rangées
	DisplayServer.window_set_size(Vector2i(1100, maxi(300, 48 + rangs * (case_px * vues.size() + 26))))
	await _att(2)
	grille.position = Vector2(10, 38)
	grille.add_theme_constant_override("h_separation", 8)
	grille.add_theme_constant_override("v_separation", 4)
	ui.add_child(grille)
	for oid: String in ids:
		var boite := VBoxContainer.new()
		boite.add_theme_constant_override("separation", 0)
		for v: Array in vues:
			var r := RenduObjet.creer(Vector2i(TAILLE_RENDU, TAILLE_RENDU))
			r.lacet = v[0]
			r.tangage = v[1]
			boite.add_child(r)       # le SubViewport vit dans l'arbre (dessiné), affiché par la TextureRect
			r.montrer(oid)
			var tr := TextureRect.new()
			tr.texture = r.get_texture()
			tr.custom_minimum_size = Vector2(case_px, case_px)
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			boite.add_child(tr)
		var l := Label.new()
		l.text = String(Inventaire.objet(oid).get("nom", oid))
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color("#bfb397"))
		l.custom_minimum_size = Vector2(case_px, 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boite.add_child(l)
		grille.add_child(boite)
	await _att(8)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_sortie)
	var img := root.get_texture().get_image()
	var h := mini(img.get_height(), int(grille.position.y + grille.size.y + 6))
	img = img.get_region(Rect2i(0, 0, img.get_width(), h))
	img.save_png(_sortie.path_join(fichier))
	print("CAPTURE ", _sortie.path_join(fichier))
	if _icones != "":
		for oid: String in ids:
			await RenduObjet.png(self, oid, _icones.path_join(oid + ".png"), Vector2i(64, 64))
		print("ICONES ", _icones)
	ui.queue_free()
	await _att(2)
