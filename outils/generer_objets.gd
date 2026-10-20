extends SceneTree
## Précalcule les textures des objets tenus (ObjetsTextures) dans assets/objets/<nom>.res (version dans les métadonnées),
## comme outils/generer_crypte.gd. À relancer après toute modification de objets_textures.gd (et d'incrémenter VERSION) :
##   godot --headless --path . --script res://outils/generer_objets.gd
## Option : -- --planche=<dossier> écrit aussi un PNG de chaque texture (x8, fond sombre pour les alphas).
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ObjetsTextures.DOSSIER))
	var planche := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--planche="):
			planche = a.substr(10)
	if planche != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(planche))
	var t0 := Time.get_ticks_msec()
	for nom: String in ObjetsTextures.NOMS:
		var img := ObjetsTextures.image(nom)
		if planche != "":
			var f := 8 if img.get_width() <= 64 else 6
			var grand := img.duplicate() as Image
			grand.resize(img.get_width() * f, img.get_height() * f, Image.INTERPOLATE_NEAREST)
			var fond := Image.create(grand.get_width(), grand.get_height(), false, Image.FORMAT_RGBA8)
			fond.fill(Color(0.10, 0.12, 0.18))
			fond.blend_rect(grand, Rect2i(0, 0, grand.get_width(), grand.get_height()), Vector2i.ZERO)
			fond.save_png(ProjectSettings.globalize_path(planche + "/" + nom + ".png"))
		img.set_meta("version", ObjetsTextures.VERSION)
		ResourceSaver.save(img, "%s/%s.res" % [ObjetsTextures.DOSSIER, nom], ResourceSaver.FLAG_COMPRESS)
	print("textures des objets tenus précalculées en %d ms" % (Time.get_ticks_msec() - t0))
	quit()
