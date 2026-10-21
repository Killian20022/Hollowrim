extends SceneTree
## Précalcule les textures du Draugr nordique (DraugrTextures) dans assets/persos/draugr/<clé>.res.
## À relancer après toute modification de scripts/draugr_textures.gd (et incrémenter DraugrTextures.VERSION) :
##   godot --headless --path . --script res://outils/generer_draugr.gd -- --nouvelle
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	DraugrTextures.enregistrer = true
	var d := DraugrNordique.creer({})
	d.free()
	print("textures du draugr en %d ms" % (Time.get_ticks_msec() - t0))
	quit()
