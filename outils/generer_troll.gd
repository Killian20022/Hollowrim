extends SceneTree
## Précalcule les textures du Troll de givre (TrollTextures) dans assets/personnages/troll/<clé>.res.
## À relancer après toute modification de scripts/troll_textures.gd (et incrémenter TrollTextures.VERSION) :
##   godot --headless --path . --script res://outils/generer_troll.gd
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	TrollTextures.enregistrer = true
	TrollGivre.creer({}).free()
	print("textures du troll en %d ms" % (Time.get_ticks_msec() - t0))
	quit()
