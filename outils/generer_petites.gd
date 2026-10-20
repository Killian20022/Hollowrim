extends SceneTree
## Précalcule les textures TexturesPetites (roche des menhirs/tertre/abords, os des offrandes) dans assets/petites/.
##   godot --headless --path . --script res://outils/generer_petites.gd
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	TexturesPetites.cuire()
	print("textures petites précalculées en %d ms" % (Time.get_ticks_msec() - t0))
	quit()
