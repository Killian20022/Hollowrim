extends SceneTree
## Précalcule l'atlas du squelette nordique (peint par sources_blender/scripts/squelette_nordique.py) avec ses mipmaps pixel art
## (GuerrierTextures.mips_pixel : vote de couleur, découpes nettes) en assets/personnages/squelette_nordique.res.
## À relancer après chaque rejeu du script Blender (et incrémenter SqueletteGuerrier.VERSION) :
##   godot --headless --path . --script res://outils/generer_squelette.gd
func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SqueletteGuerrier.PNG))
	if img == null:
		push_error("atlas introuvable : " + SqueletteGuerrier.PNG)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var mips := GuerrierTextures.mips_pixel(img)
	mips.set_meta("version", SqueletteGuerrier.VERSION)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SqueletteGuerrier.DOSSIER))
	var e := ResourceSaver.save(mips, SqueletteGuerrier.RES, ResourceSaver.FLAG_COMPRESS)
	print("atlas squelette %dx%d (mipmaps) -> %s (%d)" % [mips.get_width(), mips.get_height(), SqueletteGuerrier.RES, e])
	quit()
