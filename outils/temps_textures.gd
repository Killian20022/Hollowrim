extends SceneTree
## Temps de peinture de chaque texture de la crypte : godot --headless --path . --script outils/temps_textures.gd
func _init() -> void:
	for n in ["mur0", "mur1", "mur2", "dalle0", "voute", "bois", "fer", "lame", "gravure", "argile", "os", "parchemin", "toile", "flamme", "halo", "rai"]:
		var t := Time.get_ticks_msec()
		var p := CrypteTextures.paire(n)
		var t2 := Time.get_ticks_msec(); CrypteTextures.mips_image(p[0]);
		print("%-10s %4d ms" % [n, Time.get_ticks_msec() - t])
	quit()
