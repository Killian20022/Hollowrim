extends SceneTree
## Cuit les textures du bâti (lot 5, 2e passe) : `assets/bati/*.res` + aperçus PNG (albédo ×3 en mosaïque 2×2,
## relief) dans captures/batiments/textures_v2/.
##   godot --headless --path . --script outils/cuire_bati.gd [-- nom1 nom2 …]
func _init() -> void:
	var noms: Array = Array(OS.get_cmdline_user_args())
	PeintureBati.cuire(noms)
	var dossier := "res://captures/batiments/textures_v2/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	var f := PeintureBati.fabriques()
	for nom: String in f:
		if not noms.is_empty() and not noms.has(nom):
			continue
		var tex: ImageTexture = load(PeintureBati.DOSSIER + nom + ".res")
		var img := tex.get_image()
		img.clear_mipmaps()
		var k := 3 if img.get_width() <= 64 else 2
		var m := Image.create(img.get_width() * 2, img.get_height() * 2, false, Image.FORMAT_RGBA8)
		for j in 2:
			for i in 2:
				m.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * img.get_width(), j * img.get_height()))
		m.resize(m.get_width() * k, m.get_height() * k, Image.INTERPOLATE_NEAREST)
		m.save_png(ProjectSettings.globalize_path(dossier + nom + ".png"))
		# zoom ×6 sur le coin haut gauche (128 × 64 max)
		var zw := mini(img.get_width(), 128)
		var zh := mini(img.get_height(), 64)
		var z := img.get_region(Rect2i(0, 0, zw, zh))
		z.resize(zw * 6, zh * 6, Image.INTERPOLATE_NEAREST)
		z.save_png(ProjectSettings.globalize_path(dossier + nom + "_zoom.png"))
	quit()
