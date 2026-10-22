extends SceneTree
## Précalcule les textures de la crypte (CrypteTextures) dans assets/crypte/<nom>.res (albédo, mipmaps comprises) et
## <nom>_nm.res (carte de pentes), comme outils/generer_sol.gd pour le sol. CrypteDecor les charge si la VERSION
## correspond, sinon il les recalcule (plusieurs centaines de ms). À relancer après toute modif de crypte_textures.gd :
##   godot --headless --path . --script res://outils/generer_crypte.gd
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CrypteTextures.DOSSIER))
	var t0 := Time.get_ticks_msec()
	# option : -- --seulement=dalle_v2,pierre_v2 ne régénère que ces textures (les autres .res restent octet pour octet)
	var seul: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seulement="):
			seul = a.substr(12).split(",")
	for nom: String in CrypteDecor.AVEC_MIPS + CrypteDecor.SANS_MIPS:
		if not seul.is_empty() and not nom in seul:
			continue
		var p := CrypteTextures.paire(nom)
		var a: Image = CrypteTextures.mips_image(p[0]) if nom in CrypteDecor.AVEC_MIPS else p[0]
		a.set_meta("version", CrypteTextures.VERSION)
		ResourceSaver.save(a, "%s/%s.res" % [CrypteTextures.DOSSIER, nom], ResourceSaver.FLAG_COMPRESS)
		if p[1] != null:
			ResourceSaver.save(p[1], "%s/%s_nm.res" % [CrypteTextures.DOSSIER, nom], ResourceSaver.FLAG_COMPRESS)
	print("textures de la crypte précalculées en %d ms" % (Time.get_ticks_msec() - t0))
	quit()
