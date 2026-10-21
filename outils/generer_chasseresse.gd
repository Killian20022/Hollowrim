extends SceneTree
## Précalcule les textures de la Chasseresse nordique (ChasseresseTextures) dans assets/persos/chasseresse/<clé>.res.
## À relancer après toute modification de scripts/chasseresse_textures.gd (et d'incrémenter ChasseresseTextures.VERSION) :
##   godot --headless --path . --script res://outils/generer_chasseresse.gd
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	ChasseresseTextures.enregistrer = true
	var c := ChasseresseNordique.creer({})
	c.free()
	print("textures de la chasseresse en %d ms" % (Time.get_ticks_msec() - t0))
	quit()
