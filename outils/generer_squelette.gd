extends SceneTree
## Précalcule l'atlas du squelette guerrier (peint par sources_blender/scripts/squelette_guerrier.py) en assets/personnages/squelette_guerrier.res.
## À relancer après chaque rejeu du script Blender (et incrémenter SqueletteGuerrier.VERSION) :
##   godot --headless --path . --script res://outils/generer_squelette.gd
func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SqueletteGuerrier.PNG))
	if img == null:
		push_error("atlas introuvable : " + SqueletteGuerrier.PNG)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	img.set_meta("version", SqueletteGuerrier.VERSION)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SqueletteGuerrier.DOSSIER))
	var e := ResourceSaver.save(img, SqueletteGuerrier.RES, ResourceSaver.FLAG_COMPRESS)
	print("atlas squelette %dx%d -> %s (%d)" % [img.get_width(), img.get_height(), SqueletteGuerrier.RES, e])
	quit()
