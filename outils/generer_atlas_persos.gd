extends SceneTree
## Precalcule les atlas des personnages vivants -> assets/personnages/atlas_<sexe>.res (repli : PersoAtlas.peindre au premier usage).
## A relancer apres toute modification de scripts/perso_atlas.gd (VERSION) ou de la mise en page Blender (base_persos.py).
##   godot --headless --path . --script res://outils/generer_atlas_persos.gd [-- --planche=res://captures/persos/atlas]
func _init() -> void:
	var planche := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--planche="):
			planche = a.substr(10)
	for sexe in ["homme", "femme"]:
		var t0 := Time.get_ticks_msec()
		var img := PersoAtlas.peindre(sexe)
		var tex := ImageTexture.create_from_image(img)
		tex.set_meta("cle", PersoAtlas._cle(sexe))
		var err := ResourceSaver.save(tex, "%s/atlas_%s.res" % [PersoAtlas.DOSSIER, sexe])
		print("atlas %s : peint en %d ms, enregistre (%s)" % [sexe, Time.get_ticks_msec() - t0, "ok" if err == OK else "ERREUR %d" % err])
		if planche != "":
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(planche))
			img.save_png(ProjectSettings.globalize_path("%s/index_%s.png" % [planche, sexe]))
	quit()
