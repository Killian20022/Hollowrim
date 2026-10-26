extends SceneTree
## Outil : statistiques de couleur de rectangles (--rects=x,y,w,h;x,y,w,h) ou profil d'une colonne (--colonne=x,y0,y1).
func _init() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var p: PackedStringArray = s.trim_prefix("--").split("=", true, 1)
		a[p[0]] = p[1] if p.size() > 1 else ""
	var img := Image.load_from_file(a["entree"])
	if a.has("rects"):
		for rs in a["rects"].split(";"):
			var r: PackedStringArray = rs.split(",")
			var lum: Array = []
			var somme := Color(0, 0, 0)
			for y in range(int(r[1]), int(r[1]) + int(r[3])):
				for x in range(int(r[0]), int(r[0]) + int(r[2])):
					var c := img.get_pixel(x, y)
					lum.append(c.get_luminance())
					somme += c
			var n := lum.size()
			lum.sort()
			print(rs, " moy=", somme / n, " p10=%.3f p50=%.3f p90=%.3f" % [lum[n / 10], lum[n / 2], lum[n * 9 / 10]])
	if a.has("colonne"):
		var c: PackedStringArray = a["colonne"].split(",")
		for y in range(int(c[1]), int(c[2])):
			var col := img.get_pixel(int(c[0]), y)
			print(y, " %.3f %.3f %.3f" % [col.r, col.g, col.b])
	quit()
