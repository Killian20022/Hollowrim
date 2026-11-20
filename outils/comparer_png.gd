extends SceneTree
## Compare deux captures (opti cpu_scripts) et compose une planche AVANT | APRÈS :
##   godot --headless --script res://outils/comparer_png.gd -- --a=<avant.png> --b=<après.png> --sortie=<planche.png> [--zones=x,y,l,h;x,y,l,h]
## Imprime, pour l'image entière et pour chaque zone : pixels différents (> 8/255 sur une composante) et écart maximal.

func _init() -> void:
	var a := Image.load_from_file(_arg("a"))
	var b := Image.load_from_file(_arg("b"))
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	_rapport("image", a, b, Rect2i(0, 0, a.get_width(), a.get_height()))
	for z in _arg("zones").split(";", false):
		var v := z.split(",")
		_rapport("zone " + z, a, b, Rect2i(int(v[0]), int(v[1]), int(v[2]), int(v[3])))
	if _arg("sortie") != "":
		var p := Image.create(a.get_width() * 2 + 4, a.get_height(), false, Image.FORMAT_RGB8)
		p.fill(Color.WHITE)
		p.blit_rect(a, Rect2i(0, 0, a.get_width(), a.get_height()), Vector2i.ZERO)
		p.blit_rect(b, Rect2i(0, 0, b.get_width(), b.get_height()), Vector2i(a.get_width() + 4, 0))
		p.save_png(_arg("sortie"))
	quit(0)

func _rapport(nom: String, a: Image, b: Image, r: Rect2i) -> void:
	var n := 0
	var mx := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d := roundi(maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) * 255.0)
			mx = maxi(mx, d)
			if d > 8:
				n += 1
	print("COMPARER %s : %d px différents sur %d (%.3f %%), écart max %d/255" % [nom, n, r.size.x * r.size.y, 100.0 * n / maxf(1.0, r.size.x * r.size.y), mx])

func _arg(nom: String) -> String:
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--" + nom + "="):
			return x.substr(nom.length() + 3)
	return ""
