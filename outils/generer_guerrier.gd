extends SceneTree
## Précalcule les textures du Guerrier nordique pilote (GuerrierTextures) dans assets/personnages/guerrier/<clé>.res.
## À relancer après toute modification de scripts/guerrier_textures.gd (et d'incrémenter GuerrierTextures.VERSION) :
##   godot --headless --path . --script res://outils/generer_guerrier.gd
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	GuerrierTextures.enregistrer = true
	for opts: Dictionary in [{}, {"casque": true}]:
		var g := GuerrierNordique.creer(opts)
		g.free()
	print("textures du guerrier en %d ms" % (Time.get_ticks_msec() - t0))
	quit()
