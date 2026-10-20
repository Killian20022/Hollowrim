extends SceneTree
## Planche des textures de la crypte (x8, tuile répétée 2x2) : godot --headless --script outils/planche_crypte.gd -- <dossier>
func _init() -> void:
	var dossier := "res://captures/crypte/textures"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			dossier = a.substr(9)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	var noms := ["mur0", "mur1", "mur2", "dalle0", "dalle1", "voute", "bois", "fer", "lame", "gravure", "argile", "os", "parchemin", "toile", "flamme", "halo", "rai"]
	for n in noms:
		var img: Image = CrypteTextures.image(n)
		var f := 8 if img.get_width() <= 32 else 6
		var grand := Image.create(img.get_width() * 2, img.get_height() * 2, false, Image.FORMAT_RGBA8)
		for oy in 2:
			for ox in 2:
				grand.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(ox * img.get_width(), oy * img.get_height()))
		grand.resize(grand.get_width() * f / 2 if false else grand.get_width() * f, grand.get_height() * f, Image.INTERPOLATE_NEAREST)
		if n in ["toile", "flamme", "halo", "rai"]:
			var fond := Image.create(grand.get_width(), grand.get_height(), false, Image.FORMAT_RGBA8)
			fond.fill(Color(0.08, 0.1, 0.16))
			fond.blend_rect(grand, Rect2i(0, 0, grand.get_width(), grand.get_height()), Vector2i.ZERO)
			grand = fond
		grand.save_png(ProjectSettings.globalize_path(dossier + "/" + n + ".png"))
	print("planches : ", dossier)
	quit()
