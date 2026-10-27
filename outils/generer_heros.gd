extends SceneTree
## Précalcule les textures du héros joueur (HerosSkarnholt) dans assets/persos/heros/<clé>.res.
## À relancer après toute modification des couleurs de scripts/heros_skarnholt.gd (et d'incrémenter HerosSkarnholt.VERSION), ou des
## textures du gardien dont elles dérivent :
##   godot --headless --path . --script res://outils/generer_heros.gd
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	HerosSkarnholt.enregistrer = true
	for n in ["mailles", "pantalon", "bottes", "brassards", "mante", "accessoires", "decoupes", "fps_mailles", "fps_fourrure", "fps_gant"]:
		HerosSkarnholt.tex(n)
	print("textures du héros en %d ms" % (Time.get_ticks_msec() - t0))
	quit()
