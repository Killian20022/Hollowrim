extends SceneTree
## Outil : recadre une image et y trace une grille (lignes fines tous les 50 px, rouges tous les 100 px, en coordonnées de l'image source),
## avec des repères chiffrés aux lignes de 100 (petits chiffres en pixels).
##   --entree= --sortie= --rect=x,y,w,h [--largeur=1000]
const CHIFFRES := ["111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001",
	"111100111001111", "111100111101111", "111001001001001", "111101111101111", "111101111001111"]

func _init() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var p: PackedStringArray = s.trim_prefix("--").split("=", true, 1)
		a[p[0]] = p[1] if p.size() > 1 else ""
	var src := Image.load_from_file(a["entree"])
	src.convert(Image.FORMAT_RGB8)
	var r: PackedStringArray = a["rect"].split(",")
	var x0 := int(r[0]); var y0 := int(r[1]); var w := int(r[2]); var h := int(r[3])
	var img := src.get_region(Rect2i(x0, y0, w, h))
	var l := int(a.get("largeur", "1000"))
	var k := float(l) / w
	img.resize(l, int(h * k), Image.INTERPOLATE_LANCZOS)
	for gx in range(int(ceil(x0 / 50.0)) * 50, x0 + w, 50):
		var px := int((gx - x0) * k)
		var col := Color(1, 0.1, 0.1) if gx % 100 == 0 else Color(1, 1, 0.3, 1)
		for py in img.get_height():
			if gx % 100 == 0 or py % 4 < 2:
				img.set_pixel(px, py, col.lerp(img.get_pixel(px, py), 0.35))
		if gx % 100 == 0:
			_texte(img, str(gx), px + 2, 2)
	for gy in range(int(ceil(y0 / 50.0)) * 50, y0 + h, 50):
		var py := int((gy - y0) * k)
		var col := Color(1, 0.1, 0.1) if gy % 100 == 0 else Color(1, 1, 0.3, 1)
		for px in img.get_width():
			if gy % 100 == 0 or px % 4 < 2:
				img.set_pixel(px, py, col.lerp(img.get_pixel(px, py), 0.35))
		if gy % 100 == 0:
			_texte(img, str(gy), 2, py + 2)
	img.save_png(a["sortie"])
	print("OK")
	quit()

func _texte(img: Image, t: String, x: int, y: int) -> void:
	var e := 2
	for i in t.length():
		var m: String = CHIFFRES[int(t[i])]
		for cy in 5:
			for cx in 3:
				var on := m[cy * 3 + cx] == "1"
				for dy in e:
					for dx in e:
						var px := x + i * 4 * e + cx * e + dx
						var py := y + cy * e + dy
						if px < img.get_width() and py < img.get_height():
							img.set_pixel(px, py, Color.WHITE if on else Color.BLACK)
