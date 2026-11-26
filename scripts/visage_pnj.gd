class_name VisagePnj
## [pnj/realisme_v1] Traits du visage peints dans l'atlas de peau Quaternius (corps homme / femme, 256 px) des PNJ maison : le visage
## d'origine est lisse, rond, « poupée » (orbites plates, nez sans arêtes, joues pleines). Ici : orbites creusées, arcade éclairée et
## ombre dessous, arête du nez claire et flancs sombres, narines, sillons nasogéniens, commissures et ombre sous la lèvre, pommette
## éclairée et joue creusée, menton, rougeur du froid, barbe naissante (hommes), rides (âge), grain de peau.
## Repère : positions en fractions de l'atlas mesurées sur les textures source (T_Superhero_Male_Dark / Female_Dark_BaseColor) ;
## unité e = demi-écart des yeux. Appelé par RealismePnj.appliquer sur une COPIE de l'image.

## centre (x des yeux au milieu), y des yeux, demi-écart des yeux, y bout du nez, y bouche (fractions de l'atlas)
const REPERES := {
	"h": {"cx": 0.1855, "ey": 0.173, "e": 0.0495, "ny": 0.229, "my": 0.267},
	"f": {"cx": 0.1825, "ey": 0.176, "e": 0.0535, "ny": 0.224, "my": 0.261},
}

## Intensité globale des traits : la face fait ~20 px à 3 m, il faut des creux francs pour qu'elle se lise (1 = réglage de base).
const FORCE := 1.7
static var _img: Image
static var _W := 256
static var _r := {}

static func peindre(img: Image, p: Dictionary, graine: int) -> void:
	_img = img
	_W = img.get_width()
	var sexe := String(p.get("sexe", "h"))
	_r = REPERES[sexe]
	var age := int(p.get("age", 1))
	var rougeur := float(p.get("rougeur", 0.5))
	var barbe := float(p.get("barbe", 0.0)) if sexe == "h" else 0.0
	var f_age := 1.0 + 0.25 * age
	var f_orb := 0.45 if sexe == "f" else 0.9     # orbites peu creusées chez les femmes (passe 2 : plus de « fard » autour des yeux)
	# ---- teint (passe 2) : tout l'atlas ramené vers une peau nordique pâle, rosée ou hâlée selon l'individu (ni orange ni gris)
	_teint(String(p.get("teint", ["pale", "rose", "hale", "pale"][graine % 4])), age)
	# ---- grain de peau (tout le visage)
	_grain(graine)
	for s in [-1.0, 1.0]:
		# orbites : creux sous l'arcade, coin interne profond, paupière supérieure
		_tache(s * 1.0, -0.12, 0.85, 0.55, -0.16 * f_age * f_orb)
		_tache(s * 0.55, 0.02, 0.28, 0.30, -0.14 * f_orb)
		_tache(s * 1.05, -0.42, 0.70, 0.14, -0.08 * f_orb)
		# arcade sourcilière éclairée
		_tache(s * 0.95, -0.80, 0.85, 0.22, 0.11)
		# poches sous les yeux (âge)
		_tache(s * 1.0, 0.40, 0.55, 0.14, -0.06 * (0.5 + age))
		# flancs du nez
		_tache(s * 0.34, 0.75, 0.13, 0.55, -0.20)
		# ailes et narines
		_tache(s * 0.30, _y_nez() - 0.02, 0.16, 0.14, -0.10)
		_tache(s * 0.21, _y_nez() + 0.12, 0.09, 0.06, -0.35)
		# sillon nasogénien (ligne de l'aile du nez vers la commissure)
		_ligne(s * 0.42, _y_nez() + 0.05, s * 0.72, _y_bouche() + 0.32, 0.07, -0.13 * f_age)
		# commissures
		_tache(s * 0.46, _y_bouche() + 0.02, 0.09, 0.08, -0.20)
		# pommette éclairée, joue creusée dessous
		_tache(s * 1.30, _y_nez() - 0.25, 0.45, 0.24, 0.08)
		_tache(s * 1.15, _y_bouche() - 0.05, 0.34, 0.42, -0.10 * f_age)
		# mâchoire : ombre sous l'angle
		_tache(s * 1.35, _y_bouche() + 0.75, 0.40, 0.25, -0.10)
		# rougeur du froid (pommettes)
		_rougir(s * 1.15, _y_nez() - 0.05, 0.45, 0.32, 0.14 * rougeur)
	# glabelle (léger pli entre les sourcils), arête du nez claire, bout du nez
	_tache(0.0, -0.55, 0.22, 0.30, -0.06 * f_age)
	_tache(0.0, 0.55, 0.12, 0.55, 0.10)
	_tache(0.0, _y_nez() - 0.10, 0.17, 0.12, 0.08)
	_rougir(0.0, _y_nez() - 0.05, 0.22, 0.18, 0.20 * rougeur)
	# sous le nez, sous la lèvre, menton
	_tache(0.0, _y_nez() + 0.24, 0.26, 0.07, -0.16)
	_tache(0.0, _y_bouche() + 0.22, 0.30, 0.08, -0.18)
	_tache(0.0, _y_bouche() + 0.58, 0.32, 0.20, 0.07)
	_tache(0.0, _y_bouche() + 0.40, 0.10, 0.06, -0.10)
	# lèvres moins « peintes » (rose poupée d'origine ramené vers la peau)
	_ternir(0.0, _y_bouche() + 0.0, 0.48, 0.14, 0.45)
	if age >= 1:
		_rides(graine, age)
	if barbe > 0.0:
		_barbe_naissante(graine, barbe)
	if p.has("doigts"):
		doigts(img, p["doigts"])

## Teintes de peau cibles : [teinte (h), saturation max, facteur de valeur]. Mesurées sur les références (joueur_base) : peau claire
## h 0,03-0,06, s 0,20-0,35.
const TEINTS := {"pale": [0.045, 0.26, 1.05], "rose": [0.025, 0.31, 1.02], "hale": [0.060, 0.34, 0.95]}

static func _teint(nom: String, age: int) -> void:
	var t: Array = TEINTS.get(nom, TEINTS["pale"])
	var ht := float(t[0])
	var smax := float(t[1]) * (0.9 if age >= 2 else 1.0)
	var vm := float(t[2])
	for y in _W:
		for x in _W:
			var c := _img.get_pixel(x, y)
			if c.a < 0.05:
				continue
			var h := c.h
			if h > 0.5:
				h -= 1.0
			var s2 := clampf(c.s * 0.80, 0.13, smax)
			var v2 := clampf(c.v * vm, 0.0, 1.0)
			_img.set_pixel(x, y, Color.from_hsv(fposmod(lerpf(h, ht, 0.7), 1.0), s2, v2, c.a))

## Doigts : triangles de la main assombris là où le poids se partage entre deux os (creux entre les doigts, plis des phalanges).
static func doigts(img: Image, tris: Array) -> void:
	var W := img.get_width()
	var H := img.get_height()
	var vu := {}
	for t: Array in tris:
		var a: Vector2 = (t[0] as Vector2) * Vector2(W, H)
		var b: Vector2 = (t[1] as Vector2) * Vector2(W, H)
		var c: Vector2 = (t[2] as Vector2) * Vector2(W, H)
		var x0 := maxi(0, int(floorf(minf(a.x, minf(b.x, c.x)))))
		var x1 := mini(W - 1, int(ceilf(maxf(a.x, maxf(b.x, c.x)))))
		var y0 := maxi(0, int(floorf(minf(a.y, minf(b.y, c.y)))))
		var y1 := mini(H - 1, int(ceilf(maxf(a.y, maxf(b.y, c.y)))))
		var aire := (b - a).cross(c - a)
		if absf(aire) < 0.0001 or (x1 - x0) * (y1 - y0) > 400:
			continue
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var q := Vector2(x + 0.5, y + 0.5)
				var w0 := (b - q).cross(c - q) / aire
				var w1 := (c - q).cross(a - q) / aire
				var w2 := 1.0 - w0 - w1
				if w0 < -0.15 or w1 < -0.15 or w2 < -0.15:
					continue
				var k := x + y * W
				if vu.has(k):
					continue
				vu[k] = true
				var d := clampf(w0 * float(t[3]) + w1 * float(t[4]) + w2 * float(t[5]), 0.0, 1.0)
				var f := 1.0 - 0.55 * smoothstep(0.12, 0.45, d)
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(p.r * f, p.g * f * 0.97, p.b * f * 0.94, p.a))

static func _y_nez() -> float:
	return (float(_r["ny"]) - float(_r["ey"])) / float(_r["e"])

static func _y_bouche() -> float:
	return (float(_r["my"]) - float(_r["ey"])) / float(_r["e"])

## Point (dx, dy en unités e depuis le milieu des yeux) -> pixel.
static func _px(dx: float, dy: float) -> Vector2:
	return Vector2((float(_r["cx"]) + dx * float(_r["e"])) * _W, (float(_r["ey"]) + dy * float(_r["e"])) * _W)

static func _mul(x: int, y: int, f: float) -> void:
	if x < 0 or y < 0 or x >= _W or y >= _W:
		return
	var c := _img.get_pixel(x, y)
	if f < 1.0:
		_img.set_pixel(x, y, Color(clampf(c.r * f, 0, 1), clampf(c.g * pow(f, 1.08), 0, 1), clampf(c.b * pow(f, 1.22), 0, 1), c.a))
	else:
		_img.set_pixel(x, y, Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a))

## Tache elliptique douce : luminosité x (1 + force) au centre, décroissance (1 - d²)².
static func _tache(dx: float, dy: float, rx: float, ry: float, force: float) -> void:
	var c := _px(dx, dy)
	var e := float(_r["e"]) * _W
	var ax := rx * e
	var ay := ry * e
	for y in range(int(c.y - ay) - 1, int(c.y + ay) + 2):
		for x in range(int(c.x - ax) - 1, int(c.x + ax) + 2):
			var d := pow((x + 0.5 - c.x) / ax, 2) + pow((y + 0.5 - c.y) / ay, 2)
			if d < 1.0:
				var w := (1.0 - d) * (1.0 - d)
				_mul(x, y, 1.0 + force * FORCE * w)

static func _ligne(x0: float, y0: float, x1: float, y1: float, larg: float, force: float) -> void:
	var n := 12
	for k in n + 1:
		var t := float(k) / n
		_tache(lerpf(x0, x1, t), lerpf(y0, y1, t), larg, larg, force * (0.55 if k == 0 or k == n else 0.35))

static func _rougir(dx: float, dy: float, rx: float, ry: float, force: float) -> void:
	var c := _px(dx, dy)
	var e := float(_r["e"]) * _W
	var ax := rx * e
	var ay := ry * e
	for y in range(int(c.y - ay) - 1, int(c.y + ay) + 2):
		for x in range(int(c.x - ax) - 1, int(c.x + ax) + 2):
			if x < 0 or y < 0 or x >= _W or y >= _W:
				continue
			var d := pow((x + 0.5 - c.x) / ax, 2) + pow((y + 0.5 - c.y) / ay, 2)
			if d < 1.0:
				var w := (1.0 - d) * (1.0 - d) * force
				var p := _img.get_pixel(x, y)
				var l := p.get_luminance()
				var rouge := Color(l * 1.32, l * 0.78, l * 0.72, p.a)
				_img.set_pixel(x, y, p.lerp(rouge, w))

static func _ternir(dx: float, dy: float, rx: float, ry: float, force: float) -> void:
	var c := _px(dx, dy)
	var e := float(_r["e"]) * _W
	var ax := rx * e
	var ay := ry * e
	for y in range(int(c.y - ay) - 1, int(c.y + ay) + 2):
		for x in range(int(c.x - ax) - 1, int(c.x + ax) + 2):
			if x < 0 or y < 0 or x >= _W or y >= _W:
				continue
			var d := pow((x + 0.5 - c.x) / ax, 2) + pow((y + 0.5 - c.y) / ay, 2)
			if d < 1.0:
				var p := _img.get_pixel(x, y)
				var l := p.get_luminance()
				var terne := Color(l * 1.12, l * 0.92, l * 0.84, p.a) * 0.92
				_img.set_pixel(x, y, p.lerp(terne, force * (1.0 - d)))

## Grain de peau : marbrures larges +-5 % et pores fins +-3 % sur la zone du visage (le reste du corps est sous les vêtements).
static func _grain(g: int) -> void:
	var c := _px(0.0, 0.6)
	var e := float(_r["e"]) * _W
	var rx := 3.4 * e
	var ry := 3.6 * e
	for y in range(maxi(0, int(c.y - ry)), mini(_W, int(c.y + ry))):
		for x in range(maxi(0, int(c.x - rx)), mini(_W, int(c.x + rx))):
			var m := RealismePnj.bruit(x, y, _W, _W, 40, 40, g + 41) - 0.5
			var po := RealismePnj._h(x, y, g + 43) - 0.5
			_mul(x, y, 1.0 + m * 0.10 + po * 0.06)

static func _rides(g: int, age: int) -> void:
	var f := -0.10 if age == 1 else -0.16
	# front : 2-3 lignes ondulées
	for k in (2 if age == 1 else 3):
		var y := -1.30 - 0.32 * k
		var n := 18
		for i in n + 1:
			var x := -1.25 + 2.5 * float(i) / n
			var yy := y + sin(x * 2.2 + k + g) * 0.05
			_tache(x, yy, 0.06, 0.035, f * 0.55)
	# pattes d'oie
	for s in [-1.0, 1.0]:
		for k in 3:
			var a := -0.35 + 0.35 * k
			_ligne(s * 1.62, 0.0, s * (1.62 + 0.38 * cos(a)), 0.38 * sin(a), 0.035, f * 0.8)
		if age >= 2:
			# bajoues et cou ridé
			_tache(s * 0.95, _y_bouche() + 0.55, 0.30, 0.30, -0.08)
			_ligne(s * 0.58, _y_bouche() + 0.1, s * 0.70, _y_bouche() + 0.70, 0.05, -0.12)

## Barbe naissante : points sombres froids sur la lèvre supérieure, le menton, les joues basses et la mâchoire.
static func _barbe_naissante(g: int, densite: float) -> void:
	var e := float(_r["e"]) * _W
	var haut := _px(0.0, _y_nez() + 0.18).y
	var c := _px(0.0, _y_bouche() + 0.2)
	var rx := 1.75 * e
	var ry := 1.6 * e
	var bouche := _px(0.0, _y_bouche())
	for y in range(int(haut), mini(_W, int(c.y + ry))):
		for x in range(maxi(0, int(c.x - rx)), mini(_W, int(c.x + rx))):
			var dxn := (x + 0.5 - c.x) / rx
			var dyn := (y + 0.5 - c.y) / ry
			# zone en « U » sous les pommettes, plus dense au menton
			var k := 1.0 - dxn * dxn * 0.85 - maxf(0.0, dyn) * maxf(0.0, dyn)
			if k <= 0.0:
				continue
			# pas sur les lèvres
			if absf(x + 0.5 - bouche.x) < 0.42 * e and absf(y + 0.5 - bouche.y) < 0.13 * e:
				continue
			# bord supérieur sur les joues : remonte vers les tempes
			if y < _px(0.0, _y_nez() + 0.35).y and absf(dxn) < 0.45 and absf(dxn) > 0.12:
				continue
			var tache := RealismePnj._h(x, y, g + 61)
			var nappe := RealismePnj.bruit(x, y, _W, _W, 64, 64, g + 63)
			var d := densite * clampf(k * 1.6, 0.0, 1.0)
			var p := _img.get_pixel(x, y)
			var l := p.get_luminance()
			var poil := Color(l * 0.60, l * 0.55, l * 0.52, p.a)
			var w := d * (0.16 + 0.16 * nappe)
			if tache > 1.0 - d * 0.45:
				w += 0.22 * d
			_img.set_pixel(x, y, p.lerp(poil, clampf(w, 0.0, 0.75)))
