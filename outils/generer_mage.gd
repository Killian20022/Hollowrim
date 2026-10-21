extends SceneTree
## Précalcule les textures du Mage nordique (MageTextures) dans assets/personnages/mage/<clé>.res (et celles du guerrier qu'il
## emprunte : pantalon, bottes, mante, mèches). À relancer après toute modification de scripts/mage_textures.gd (et d'incrémenter
## MageTextures.VERSION) :
##   godot --headless --path . --script res://outils/generer_mage.gd
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	MageTextures.enregistrer = true
	GuerrierTextures.enregistrer = true
	var g := MageNordique.creer({})
	g.free()
	print("textures du mage en %d ms" % (Time.get_ticks_msec() - t0))
	quit()
