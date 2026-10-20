extends SceneTree
## Planche des textures de la grotte (tuile répétée 2x2, x4) : godot --headless --script outils/planche_grotte.gd -- --sortie=res://captures/grotte/textures
func _init() -> void:
	var dossier := "res://captures/grotte/textures"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			dossier = a.substr(9)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	var noms := ["roche", "roche_b", "strate", "sol", "neige", "glace", "glace_sup", "mousse", "cristal", "peau", "paille", "jour", "ciel", "rai", "flaque"]
	var t0 := Time.get_ticks_msec()
	for n in noms:
		var t1 := Time.get_ticks_msec()
		var img: Image = GrotteTextures.image(n)
		print(n, " ", img.get_width(), "x", img.get_height(), " ", Time.get_ticks_msec() - t1, " ms")
		var w := img.get_width()
		var h := img.get_height()
		var rep := 2 if n not in ["jour", "ciel", "rai", "flaque"] else 1
		var f := 4 if w <= 128 else 3
		var grand := Image.create(w * rep, h * rep, false, Image.FORMAT_RGBA8)
		for oy in rep:
			for ox in rep:
				grand.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(ox * w, oy * h))
		grand.resize(grand.get_width() * f, grand.get_height() * f, Image.INTERPOLATE_NEAREST)
		if n in ["neige", "glace_sup", "mousse"]:
			# l'alpha est un seuil : on l'affiche en bas à droite sous forme de niveaux de gris
			var s := Image.create(w, h, false, Image.FORMAT_RGBA8)
			for y in h:
				for x in w:
					var a := img.get_pixel(x, y).a
					s.set_pixel(x, y, Color(a, a, a, 1))
			s.resize(w * f, h * f, Image.INTERPOLATE_NEAREST)
			s.save_png(ProjectSettings.globalize_path(dossier + "/" + n + "_seuil.png"))
			var opaque := Image.create(grand.get_width(), grand.get_height(), false, Image.FORMAT_RGBA8)
			for y in grand.get_height():
				for x in grand.get_width():
					var c := grand.get_pixel(x, y)
					opaque.set_pixel(x, y, Color(c.r, c.g, c.b, 1))
			grand = opaque
		if n in ["rai", "flaque"]:
			var fond := Image.create(grand.get_width(), grand.get_height(), false, Image.FORMAT_RGBA8)
			fond.fill(Color(0.05, 0.07, 0.1))
			fond.blend_rect(grand, Rect2i(0, 0, grand.get_width(), grand.get_height()), Vector2i.ZERO)
			grand = fond
		grand.save_png(ProjectSettings.globalize_path(dossier + "/" + n + ".png"))
	print("total ", Time.get_ticks_msec() - t0, " ms -> ", dossier)
	quit()
