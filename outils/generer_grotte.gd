extends SceneTree
## Précalcule les textures de la grotte vitrine dans assets/grotte/*.res (Image, mipmaps comprises).
## GrotteDecor les charge si elles existent et repeint sinon : relancer après toute modif de grotte_textures.gd.
##   godot --headless --path . --script res://outils/generer_grotte.gd

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GrotteDecor.DOSSIER))
	var total := 0
	for nom: String in GrotteDecor.PROPRES_MIPS + GrotteDecor.PROPRES_PLATES:
		var img := GrotteDecor.image_finale(nom)
		var chemin := "%s/%s.res" % [GrotteDecor.DOSSIER, nom]
		var err := ResourceSaver.save(img, chemin, ResourceSaver.FLAG_COMPRESS)
		var taille := FileAccess.get_file_as_bytes(chemin).size()
		total += taille
		print("%-12s %dx%d  %6d octets  %s" % [nom, img.get_width(), img.get_height(), taille, "OK" if err == OK else "ERREUR %d" % err])
	print("grotte : %d textures, %d Ko, calculées en %d ms" % [GrotteDecor.PROPRES_MIPS.size() + GrotteDecor.PROPRES_PLATES.size(), total / 1024, Time.get_ticks_msec() - t0])
	quit()
