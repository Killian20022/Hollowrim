extends SceneTree
## Précalcule les textures du Gardien nordique (GardienTextures) dans assets/persos/gardien/<clé>.res.
## À relancer après toute modification de scripts/gardien_textures.gd (et d'incrémenter GardienTextures.VERSION) :
##   godot --headless --path . --script res://outils/generer_gardien.gd
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	GardienTextures.enregistrer = true
	GuerrierTextures.enregistrer = true
	var g := GardienNordique.creer({})
	g.free()
	print("textures du gardien en %d ms" % (Time.get_ticks_msec() - t0))
	quit()
