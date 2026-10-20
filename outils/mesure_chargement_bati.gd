extends SceneTree
## Temps de chargement des textures du bâti (fichiers cuits) : `godot --headless --path . --script outils/mesure_chargement_bati.gd`
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	for nom: String in PeintureBati.fabriques():
		TexturesBati.charge(nom)
	print("chargement des textures du bâti : %d ms" % (Time.get_ticks_msec() - t0))
	quit()
