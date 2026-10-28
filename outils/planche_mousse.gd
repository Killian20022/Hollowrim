extends SceneTree
## Planche de contrôle de la mousse des murs (mur0, mur1, mur2) : tuile 1:1, puis niveaux de mipmaps 2 et 3 agrandis au plus
## proche (ce que montre un mur vu à 3-8 m en 480x270). godot --headless --script res://outils/planche_mousse.gd -- --sortie=<dossier>
func _init() -> void:
	var dossier := "res://captures/crypte/mousse"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			dossier = a.substr(9)
	var abs_d: String = ProjectSettings.globalize_path(dossier) if dossier.begins_with("res://") else dossier
	DirAccess.make_dir_recursive_absolute(abs_d)
	for n: String in ["mur0", "mur1", "mur2"]:
		var img: Image = CrypteTextures.mips_image(CrypteTextures.paire(n)[0])
		var S := img.get_width()
		var verts := 0
		for yy in S:
			for xx in S:
				var cc := img.get_pixel(xx, yy)
				if cc.g > cc.r + 0.025 and cc.g >= cc.b:
					verts += 1
		print("%s : %.1f %% de texels verdâtres (g > r + 0,025)" % [n, 100.0 * verts / float(S * S)])
		var planche := Image.create(S * 3, S, false, Image.FORMAT_RGBA8)
		var base := Image.create(S, S, false, Image.FORMAT_RGBA8)
		base.blit_rect(img, Rect2i(0, 0, S, S), Vector2i.ZERO)
		planche.blit_rect(base, Rect2i(0, 0, S, S), Vector2i.ZERO)
		for k: int in [2, 3]:
			var off := img.get_mipmap_offset(k)
			var w := S >> k
			var data := img.get_data().slice(off, off + w * w * 4)
			var m := Image.create_from_data(w, w, false, Image.FORMAT_RGBA8, data)
			m.resize(S, S, Image.INTERPOLATE_NEAREST)
			planche.blit_rect(m, Rect2i(0, 0, S, S), Vector2i(S * (k - 1), 0))
		planche.save_png(abs_d + "/" + n + ".png")
	print("planches mousse : ", dossier)
	quit()
