extends SceneTree
## Écrit les textures du guerrier en PNG agrandis x4 (revue des vêtements) :
##   godot --headless --path . --script res://outils/dump_textures_guerrier.gd -- --sortie=<dossier absolu>
func _init() -> void:
	var sortie := "res://captures/tex_guerrier"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	DirAccess.make_dir_recursive_absolute(sortie)
	var T := GuerrierTextures
	var liste := {"mailles": T.mailles(), "pantalon": T.pantalon(), "bottes": T.bottes(), "brassards": T.brassards(), "mante": T.mante(), "cape": T.cape(), "decoupes": T.decoupes(), "accessoires": T.accessoires()}
	for k: String in liste:
		var img: Image = liste[k]
		img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
		img.save_png("%s/%s.png" % [sortie, k])
	quit()
