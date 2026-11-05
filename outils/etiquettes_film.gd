extends SceneTree
## Étiquettes PNG (texte blanc sur bandeau sombre) pour les montages ffmpeg des preuves (l'ffmpeg du poste n'a pas drawtext) :
##   godot --path . --resolution 640x40 --script res://outils/etiquettes_film.gd -- --sortie=<dossier> --textes="AVANT|APRÈS|…"
func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var sortie := _arg("sortie", "user://etiquettes")
	DirAccess.make_dir_recursive_absolute(sortie)
	var fond := ColorRect.new()
	fond.color = Color(0.05, 0.05, 0.06)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fond)
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(_arg("taille", "22")))
	l.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	root.add_child(l)
	var i := 0
	for t in _arg("textes", "").split("|"):
		l.text = t
		for k in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(sortie.path_join("e%d.png" % i))
		i += 1
	quit()
