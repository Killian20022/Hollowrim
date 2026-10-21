extends SceneTree
## Audit graphique : statistiques de couleur d'images (références peintes vs captures du jeu).
##   godot --headless --script res://outils/analyse_palette.gd -- [--k=12] image1.png image2.png …
## Par image : luminance moyenne / écart-type / centiles 5-50-95 %, saturation moyenne, part de pixels
## « chauds » (teinte 10-50°, sat > 0,45, val > 0,45), « bleus saturés » (teinte 190-235°, sat > 0,45, val > 0,35),
## « quasi noirs » (lum < 0,06), puis une palette de k couleurs (k-moyennes sur 6 000 pixels, triées par luminance,
## avec leur part). Sortie texte uniquement (rien n'est écrit sur disque).
func _init() -> void:
	var k := 12
	var fichiers: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--k="):
			k = int(a.substr(4))
		else:
			fichiers.append(a)
	for f in fichiers:
		var im := Image.load_from_file(f)
		if im == null:
			print("introuvable : ", f)
			continue
		im.convert(Image.FORMAT_RGB8)
		_analyser(f, im, k)
	quit()

func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

func _analyser(nom: String, im: Image, k: int) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var pts: Array[Color] = []
	var lums := PackedFloat32Array()
	var s_sat := 0.0
	var chauds := 0
	var bleus := 0
	var noirs := 0
	var n := 6000
	for i in n:
		var c := im.get_pixel(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		pts.append(c)
		var l := _lum(c)
		lums.append(l)
		s_sat += c.s
		var hue := c.h * 360.0
		if hue >= 10.0 and hue <= 50.0 and c.s > 0.45 and c.v > 0.45:
			chauds += 1
		if hue >= 190.0 and hue <= 235.0 and c.s > 0.45 and c.v > 0.35:
			bleus += 1
		if l < 0.06:
			noirs += 1
	var tri := lums.duplicate()
	tri.sort()
	var moy := 0.0
	for l in lums:
		moy += l
	moy /= n
	var var_ := 0.0
	for l in lums:
		var_ += (l - moy) * (l - moy)
	print("== %s (%dx%d)" % [nom.get_file(), w, h])
	print("   lum moy=%.3f ecart=%.3f c5=%.3f c50=%.3f c95=%.3f | sat moy=%.3f | chauds=%.1f%% bleus_sat=%.1f%% quasi_noirs=%.1f%%" % [
		moy, sqrt(var_ / n), tri[int(n * 0.05)], tri[int(n * 0.5)], tri[int(n * 0.95)], s_sat / n,
		100.0 * chauds / n, 100.0 * bleus / n, 100.0 * noirs / n])
	# k-moyennes (initialisation par centiles de luminance, 12 itérations)
	var pts_tri := pts.duplicate()
	pts_tri.sort_custom(func(a: Color, b: Color) -> bool: return _lum(a) < _lum(b))
	var cent: Array[Color] = []
	for j in k:
		cent.append(pts_tri[int((j + 0.5) * n / k)])
	var compte := PackedInt32Array()
	for it in 12:
		var somme: Array[Vector3] = []
		compte = PackedInt32Array()
		compte.resize(k)
		for j in k:
			somme.append(Vector3.ZERO)
		for c in pts:
			var best := 0
			var bd := 1e9
			for j in k:
				var d := Vector3(c.r - cent[j].r, c.g - cent[j].g, c.b - cent[j].b).length_squared()
				if d < bd:
					bd = d
					best = j
			somme[best] += Vector3(c.r, c.g, c.b)
			compte[best] += 1
		for j in k:
			if compte[j] > 0:
				var m: Vector3 = somme[j] / compte[j]
				cent[j] = Color(m.x, m.y, m.z)
	var ordre := range(k)
	ordre.sort_custom(func(a: int, b: int) -> bool: return _lum(cent[a]) < _lum(cent[b]))
	var ligne := "   palette :"
	for j in ordre:
		ligne += " #%s(%d%%)" % [cent[j].to_html(false), roundi(100.0 * compte[j] / n)]
	print(ligne)
