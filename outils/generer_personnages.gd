extends SceneTree
## Précalcule les textures des personnages (PersonnagesTextures + PeauTextures) dans assets/personnages/<nom>.res.
## À relancer après toute modification de scripts/personnages_textures.gd (et d'incrémenter VERSION) :
##   godot --headless --path . --script res://outils/generer_personnages.gd [-- --planche=<dossier>]
## --planche : écrit un PNG par texture, agrandi (x6, fond sombre).
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PersonnagesTextures.DOSSIER))
	var planche := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--planche="):
			planche = a.substr(10)
	if planche != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(planche))
	var t0 := Time.get_ticks_msec()
	var noms: Array = PersonnagesTextures.noms()
	for nom: String in noms:
		var img := PersonnagesTextures.image(nom)
		if planche != "":
			var grand := img.duplicate() as Image
			var f := 6 if img.get_width() <= 128 else 3
			grand.resize(img.get_width() * f, img.get_height() * f, Image.INTERPOLATE_NEAREST)
			grand.save_png(ProjectSettings.globalize_path(planche + "/" + nom + ".png"))
		img.set_meta("version", PersonnagesTextures.VERSION)
		ResourceSaver.save(img, "%s/%s.res" % [PersonnagesTextures.DOSSIER, nom], ResourceSaver.FLAG_COMPRESS)
	print("%d textures de personnages en %d ms" % [noms.size(), Time.get_ticks_msec() - t0])
	quit()
