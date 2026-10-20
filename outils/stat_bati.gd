extends SceneTree
## Statistiques des textures du bâti cuites : taille, mémoire (RGBA8 + mips), part de texels isolés (aucun des 8 voisins identique).
##   godot --headless --path . --script outils/stat_bati.gd
func _init() -> void:
	var total := 0.0
	for nom: String in PeintureBati.fabriques():
		var tex: Texture2D = load(PeintureBati.DOSSIER + nom + ".res")
		var img := tex.get_image()
		img.clear_mipmaps()
		var ko := img.get_width() * img.get_height() * 4 * 4.0 / 3.0 / 1024.0
		total += ko
		print("%-16s %4d x %-4d %7.0f Ko  isolés %5.1f %%" % [nom, img.get_width(), img.get_height(), ko, PeintureBati.part_isolee(img)])
	print("total %.0f Ko" % total)
	quit()
