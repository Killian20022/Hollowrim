class_name Fourrure
## [pnj/realisme_v1, passe 2] Fourrures des PNJ maison en TOUFFES irrégulières et denses (relecture : « lamelles et pointes
## triangulaires » sur les épaules et les cols).
##   - cartes(img) : cartes découpées de l'atlas des découpes (D_MECHES, 4 variantes de 16 x 32) repeintes en touffes de brins
##     inégaux (longueurs, courbures, épaisseurs), base pleine, pointes effilées ; couleur moyenne de l'archétype, ternie ;
##   - mante(img) : la mante entière peinte en fourrure (mèches groupées en touffes le long de v, creux sombres entre elles), dans la
##     couleur de la tenue (brun, gris) ; l'alpha d'origine (ourlets) est gardé.

static func _h(a: int, b: int, g: int) -> float:
	return RealismePnj._h(a, b, g)

static func cartes(img: Image, p: Dictionary, g: int) -> void:
	_cartes(img, p, g, GuerrierTextures.D_MECHES)
	# deuxième bande (Chasseresse : « feuilles » pointues du col de fourrure ; Guerrier : mèches de cheveux, retirées par AllurePnj)
	_cartes(img, p, g + 101, Rect2i(GuerrierTextures.D_MECHES.position + Vector2i(0, 32), GuerrierTextures.D_MECHES.size))

static func _cartes(img: Image, p: Dictionary, g: int, R: Rect2i) -> void:
	if R.end.x > img.get_width() or R.end.y > img.get_height():
		return
	# couleur moyenne des mèches d'origine (crème, gris...), ternie
	var somme := Color(0, 0, 0, 0)
	var n := 0
	for y in R.size.y:
		for x in R.size.x:
			var c := img.get_pixel(R.position.x + x, R.position.y + y)
			if c.a > 0.5:
				somme += c
				n += 1
	var base := Color(0.62, 0.57, 0.50) if n == 0 else Color(somme.r / n, somme.g / n, somme.b / n)
	var l := base.get_luminance()
	base = Color(lerpf(base.r, l, 0.25), lerpf(base.g, l, 0.25), lerpf(base.b, l, 0.25)) * 0.86
	if p.has("fourrure"):
		base = p["fourrure"]
	for y in R.size.y:
		for x in R.size.x:
			img.set_pixel(R.position.x + x, R.position.y + y, Color(base.r, base.g, base.b, 0.0))
	for v in 4:
		var ox := R.position.x + v * 16
		# base pleine (accroche à l'étoffe), 3 à 5 texels selon la variante
		var b0 := 3 + v % 3
		for y in b0:
			for x in 16:
				var f := 0.62 + 0.3 * _h(ox + x, y, g + 3)
				img.set_pixel(ox + x, R.position.y + y, Color(base.r * f, base.g * f, base.b * f, 1.0))
		# touffes : groupes de 3 à 5 brins qui partent ensemble et s'écartent un peu
		var nt := 5 + (v + g) % 3
		for t in nt:
			var cx0 := 1.0 + 14.0 * (float(t) + _h(t, v, g + 5)) / nt
			var lg := 13.0 + 18.0 * _h(t, v, g + 6)
			var courbe := (_h(t, v, g + 7) - 0.5) * 5.0
			var nb := 3 + int(_h(t, v, g + 8) * 3.0)
			var ton := 0.78 + 0.38 * _h(t, v, g + 9)
			for s in nb:
				var dx := (float(s) - nb * 0.5) * 0.9
				var lgs := lg * (0.75 + 0.25 * _h(t * 7 + s, v, g + 10))
				for y in int(lgs):
					var f := float(y) / lgs
					var cx := cx0 + dx * (0.4 + f) + courbe * f * f
					var x := int(roundf(cx))
					if x < 0 or x > 15:
						continue
					var k := ton * (1.0 - 0.35 * f) + (_h(ox + x, y, g + 11) - 0.5) * 0.16
					if s == 0:
						k *= 1.12                      # brin éclairé
					img.set_pixel(ox + x, R.position.y + y, Color(clampf(base.r * k, 0, 1), clampf(base.g * k, 0, 1), clampf(base.b * k, 0, 1), 1.0))
					# brins de 2 texels dans la première moitié (touffe dense, pas de lamelle d'un texel)
					if f < 0.5 and x + 1 <= 15:
						var k2 := k * 0.82
						img.set_pixel(ox + x + 1, R.position.y + y, Color(clampf(base.r * k2, 0, 1), clampf(base.g * k2, 0, 1), clampf(base.b * k2, 0, 1), 1.0))

static func mante(img: Image, col: Color, g: int) -> void:
	var W := img.get_width()
	var H := img.get_height()
	var touffe := RealismePnj._champ(W, H, 24, 4, g + 21)
	var phase := RealismePnj._champ(W, H, 10, 3, g + 22)
	for y in H:
		for x in W:
			var a := img.get_pixel(x, y).a
			if a < 0.05:
				continue
			var tf := touffe.get_pixel(x, y).r
			# mèches : colonnes de 3 texels ondulées ; creux sombres entre les touffes
			var xx := float(x) + sin(float(y) * 0.18 + phase.get_pixel(x, y).r * 6.0) * 1.6
			var fil := fposmod(xx, 3.0)
			var f := 0.70 + 0.42 * tf + (_h(int(xx), y / 4, g + 23) - 0.5) * 0.22
			if fil < 0.8:
				f *= 0.78
			if tf < 0.28:
				f *= 0.80
			f += (_h(x, y, g + 24) - 0.5) * 0.08
			# ourlet (bas de l'image) : pointes de touffes irrégulières découpées (alpha 0 entre elles), au lieu des dents régulières
			var v := float(y) / H
			if v > 0.80:
				var lg := 0.80 + 0.20 * _h(int(xx) / 3, 0, g + 25)
				if v > lg:
					a = 0.0
			img.set_pixel(x, y, Color(clampf(col.r * f, 0, 1), clampf(col.g * f, 0, 1), clampf(col.b * f, 0, 1), a))
