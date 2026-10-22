extends SceneTree
## Enregistre la texture des lambeaux (jupe + cape Blender) agrandie x3 : godot --headless --script res://outils/apercu_lambeaux.gd -- --sortie=<fichier.png>
func _init() -> void:
	var chemin := "C:/Users/lopezk19/Desktop/Skyrim captures/refonte/persos/draugr/blender/texture_lambeaux.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			chemin = a.substr(9)
	var img := DraugrTextures.lambeaux()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(chemin)
	quit()
