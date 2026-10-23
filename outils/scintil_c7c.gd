extends SceneTree
## C7c : scintillement de l'eau du village (même mesure que docs/EAU.md : part des pixels d'EAU qui changent de plus de 8 %
## entre deux vues décalées de 5 cm). Masque de l'eau = pixels où APRÈS diffère d'AVANT (--sans-eau-village) de plus de 10 %.
##   godot --headless --path . --script res://outils/scintil_c7c.gd -- avant.png apres.png apres_decale_5cm.png
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var im: Array[Image] = []
	for k in 3:
		var i := Image.load_from_file(a[k])
		i.convert(Image.FORMAT_RGBA8)
		im.append(i)
	var masque := 0
	var change := 0
	for y in im[0].get_height():
		for x in im[0].get_width():
			var av := im[0].get_pixel(x, y)
			var ap := im[1].get_pixel(x, y)
			if maxf(absf(av.r - ap.r), maxf(absf(av.g - ap.g), absf(av.b - ap.b))) <= 0.1:
				continue
			masque += 1
			var d := im[2].get_pixel(x, y)
			if maxf(absf(d.r - ap.r), maxf(absf(d.g - ap.g), absf(d.b - ap.b))) > 0.08:
				change += 1
	print("SCINTIL %s : masque %d px, %.1f %% des pixels d'eau changent de plus de 8 %%" % [a[1].get_file(), masque, 100.0 * change / maxi(1, masque)])
	quit(0)
