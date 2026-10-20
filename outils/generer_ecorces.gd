extends SceneTree
## Précalcule les tuiles d'écorce (avec mipmaps) : godot --headless --path . --script res://outils/generer_ecorces.gd
## À relancer après toute modification de scripts/ecorces.gd (sinon la génération au lancement coûte ~1 s).
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ecorces"))
	for nom in Ecorces.NOMS:
		var img := Ecorces.mips_image(Ecorces.image(nom))
		var err := ResourceSaver.save(img, "res://assets/ecorces/%s.res" % nom)
		print(nom, " ", err)
	quit()
