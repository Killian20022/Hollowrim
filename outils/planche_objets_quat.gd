extends SceneTree
## Planche studio AVANT | APRÈS des objets ramassables passés en props Quaternius (ObjetsQuat, champ modele_quat) : pour chaque objet,
## en haut l'ancien modèle (ObjetsQuat.actif = false : glb d'objets, primitives, prop .dat), en bas le prop pq_* ; même cadrage
## (RenduObjet, angles du genre d'objet), taille réelle.
##   godot --path . --script res://outils/planche_objets_quat.gd -- --sortie=<dossier> [--ids=a,b] [--nom=planche_studio.png]
## Avec fenêtre (godot_slot.sh : hors écran).

const TAILLE := 80
const AGRANDI := 2
const FOND := Color("#14110d")

func _init() -> void:
	_go.call_deferred()

func _att(n: int) -> void:
	for i in n:
		await process_frame

func _go() -> void:
	var sortie := "res://captures/objets_quat"
	var nom := "planche_studio.png"
	var ids: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
		elif a.begins_with("--ids="):
			ids = Array(a.substr(6).split(","))
		elif a.begins_with("--nom="):
			nom = a.substr(6)
	if ids.is_empty():
		for oid: String in Inventaire.ids_connus():
			if String(Inventaire.objet(oid).get("modele_quat", "")) != "":
				ids.append(oid)
		ids.sort()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var case_px := TAILLE * AGRANDI
	var colonnes := 10
	var rangs := ceili(float(ids.size()) / colonnes)
	DisplayServer.window_set_size(Vector2i(colonnes * (case_px + 6) + 20, 50 + rangs * (case_px * 2 + 40)))
	await _att(3)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ui)
	var bg := ColorRect.new()
	bg.color = FOND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var t := Label.new()
	t.text = "Objets ramassables — en haut : avant (glb / primitives / .dat) ; en bas : prop Quaternius texturé PS1 (modele_quat). Studio, taille réelle."
	t.position = Vector2(10, 8)
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", Color("#d8c9a8"))
	ui.add_child(t)
	var g := GridContainer.new()
	g.columns = colonnes
	g.position = Vector2(10, 34)
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	ui.add_child(g)
	for oid: String in ids:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		for actif in [false, true]:
			ObjetsQuat.actif = actif
			var r := RenduObjet.creer(Vector2i(TAILLE, TAILLE))
			var ang := RenduObjet.angles_pour(oid)
			r.lacet = ang.x
			r.tangage = ang.y
			v.add_child(r)
			r.montrer(oid)
			var tr := TextureRect.new()
			tr.texture = r.get_texture()
			tr.custom_minimum_size = Vector2(case_px, case_px)
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			v.add_child(tr)
		ObjetsQuat.actif = true
		var l := Label.new()
		l.text = "%s\n%s" % [String(Inventaire.objet(oid).get("nom", oid)), String(Inventaire.objet(oid).get("modele_quat", ""))]
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color("#bfb397"))
		l.custom_minimum_size = Vector2(case_px, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		v.add_child(l)
		g.add_child(v)
	await _att(10)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(sortie)
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(sortie.path_join(nom))
	print("CAPTURE ", sortie.path_join(nom))
	quit(0)
