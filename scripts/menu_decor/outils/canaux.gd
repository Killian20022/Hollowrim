extends SceneTree
## Outil hors jeu : planche de contrôle des masques (chaque canal de masques_a/b/c en surimpression rouge sur le fond).
##   godot --headless --path . --script res://scripts/menu_decor/outils/canaux.gd -- --sortie=C:\chemin\planche.png [--fichier=masques_a]

func _init() -> void:
	var sortie := ""
	var seul := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.get_slice("=", 1)
		elif a.begins_with("--fichier="):
			seul = a.get_slice("=", 1)
	var fond := Image.load_from_file(ProjectSettings.globalize_path("res://textures/menu_decor/fond_sans_logo.png"))
	var cw := 480; var ch := 270
	if seul != "":
		cw = 960; ch = 540
	fond.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
	fond.convert(Image.FORMAT_RGB8)
	var fichiers := ["masques_a", "masques_b", "masques_c"] if seul == "" else [seul]
	var planche := Image.create(cw * 4, ch * fichiers.size(), false, Image.FORMAT_RGB8)
	for fi in fichiers.size():
		var m := Image.load_from_file(ProjectSettings.globalize_path("res://textures/menu_decor/%s.png" % fichiers[fi]))
		m.convert(Image.FORMAT_RGBA8)
		m.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
		for c in 4:
			for y in ch:
				for x in cw:
					var v: float = [m.get_pixel(x, y).r, m.get_pixel(x, y).g, m.get_pixel(x, y).b, m.get_pixel(x, y).a][c]
					var f := fond.get_pixel(x, y) * 0.3
					planche.set_pixel(c * cw + x, fi * ch + y, Color(lerpf(f.r, 1.0, v), f.g * (1.0 - v * 0.5), f.b * (1.0 - v * 0.5)))
	planche.save_png(sortie)
	print("OK ", planche.get_size())
	quit()
