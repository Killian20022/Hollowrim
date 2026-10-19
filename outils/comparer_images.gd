extends SceneTree
## Compare deux images : pourcentage de pixels dont un canal s'écarte de plus de 8/255.
##   godot --headless --path . --script outils/comparer_images.gd -- a.png b.png
const SEUIL := 8.0 / 255.0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage : -- a.png b.png")
		quit(2)
		return
	var a := Image.load_from_file(args[0])
	var b := Image.load_from_file(args[1])
	if a == null or b == null or a.get_size() != b.get_size():
		print("ECHEC : images illisibles ou de tailles différentes")
		quit(1)
		return
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var diff := 0
	var total := a.get_width() * a.get_height()
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) > SEUIL or absf(ca.g - cb.g) > SEUIL or absf(ca.b - cb.b) > SEUIL:
				diff += 1
	print("pixels différents (> 8/255) : %.4f %% (%d / %d)" % [100.0 * diff / total, diff, total])
	quit(0)
