extends SceneTree
## Aperçu des textures de la crypte v2 : écrit <dossier>/<nom>.png (2 x 2 tuiles) ; usage : godot --headless --script res://outils/previsu_textures_crypte_v2.gd -- <dossier absolu> [noms]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier: String = args[0] if args.size() > 0 else "C:/Users/lopezk19/Desktop/Skyrim captures/refonte/crypte_v2/salle_couloir"
	var noms: Array = Array(args.slice(1)) if args.size() > 1 else ["dalle_v2", "pierre_v2", "givre_sol"]
	DirAccess.make_dir_recursive_absolute(dossier)
	for nom: String in noms:
		var t0 := Time.get_ticks_msec()
		var img: Image = CrypteTextures.image(nom)
		var w := img.get_width()
		var big := Image.create(w * 2, w * 2, false, Image.FORMAT_RGBA8)
		for k in 4:
			big.blit_rect(img, Rect2i(0, 0, w, w), Vector2i((k % 2) * w, (k / 2) * w))
		big.save_png("%s/tex_%s.png" % [dossier, nom])
		print("%s : %d ms" % [nom, Time.get_ticks_msec() - t0])
	quit()
