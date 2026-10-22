extends SceneTree
## Stabilité en mouvement : compare deux captures prises à 5 cm d'écart (mêmes réglages). Écrit la carte d'écart (x4) et affiche
## la part de pixels qui changent de plus de 8/255 et de plus de 32/255 (fort contraste = scintillement / « fourmillement » des textures).
##   godot --headless --path . --script res://outils/diff_images.gd -- a.png b.png sortie_diff.png
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var a := Image.load_from_file(args[0])
	var b := Image.load_from_file(args[1])
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var w := a.get_width()
	var h := a.get_height()
	var n8 := 0
	var n32 := 0
	var moy := 0.0
	var d := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(0, h):
		for x in range(0, w):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var e := maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b))
			moy += e
			if e > 8.0 / 255.0:
				n8 += 1
			if e > 32.0 / 255.0:
				n32 += 1
			var v := clampf(e * 4.0, 0.0, 1.0)
			d.set_pixel(x, y, Color(v, v, v))
	if args.size() > 2:
		d.save_png(args[2])
	var tot := float(w * h)
	print("DIFF %s | %s : moyenne %.2f/255, >8/255 : %.1f %%, >32/255 : %.1f %%" % [args[0].get_file(), args[1].get_file(), moy / tot * 255.0, n8 / tot * 100.0, n32 / tot * 100.0])
	quit()
