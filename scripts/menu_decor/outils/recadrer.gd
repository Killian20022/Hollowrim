extends SceneTree
## Outil : recadre et réduit une image (pour regarder la référence par morceaux).
##   godot --headless --script res://scripts/menu_decor/outils/recadrer.gd -- --entree=<png> --sortie=<png> --rect=x,y,w,h [--largeur=1000]

func _init() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var p: PackedStringArray = s.trim_prefix("--").split("=", true, 1)
		a[p[0]] = p[1] if p.size() > 1 else ""
	var img := Image.load_from_file(a["entree"])
	if a.has("rect"):
		var r: PackedStringArray = a["rect"].split(",")
		img = img.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	var l := int(a.get("largeur", "0"))
	if l > 0 and l != img.get_width():
		img.resize(l, maxi(1, int(round(img.get_height() * float(l) / img.get_width()))), Image.INTERPOLATE_LANCZOS)
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	var s: String = a["sortie"]
	if s.ends_with(".jpg"):
		img.save_jpg(s, 0.9)
	else:
		img.save_png(s)
	print("OK ", img.get_size())
	quit()
