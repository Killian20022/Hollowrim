class_name PeintureInterieur
## Lot « intérieurs » : textures peintes propres aux maisons (tentures, peaux, terre battue, vitrage). Même
## méthode que `PeintureBati` (12 tons par matière, relief sur la normale, mipmaps « vote de couleur ») ; elles
## sont cuites dans `assets/bati/` par `outils/cuire_bati.gd` (via `PeintureBati.fabriques()`).

const K_ROUGE := ["#1b0b10", "#341018", "#521820", "#722228", "#923030", "#b04838"]
const K_OCRE := ["#2b1e10", "#4a3216", "#6e4b1e", "#946a2a", "#b98d3c", "#d8b25c"]
const K_BLEU := ["#0e1428", "#16213f", "#223259", "#33487a", "#4a629c", "#6b84bd"]
const K_VERT := ["#0e1a14", "#16291f", "#213d2c", "#2f5439", "#427049", "#5d8c5c"]
const K_CREME := ["#3a3028", "#5c4f40", "#7e6e58", "#a08e72", "#c0ae8e", "#dccfae"]
const K_FOURRURE := ["#150d0e", "#241618", "#38241d", "#4f3424", "#6b4a31", "#8a6542", "#a8845a", "#c8a77a"]
const K_SUIE := ["#0b0a0d", "#15131a", "#201c24", "#2e2830"]

## Tenture tissée de 1,5 × 2 m (48 × 64 texels, UV en mètres sur le quad) : galon d'ocre, champ uni, trois losanges
## en chaîne, frange effilochée en bas. `fond` / `motif` : rampes de couleur.
static func tenture(graine: int, fond: Array, motif: Array, liseré := true) -> Array:
	var w := 48
	var h := 64
	var cf := PeintureBati.rampe(fond, 8)
	var cm := PeintureBati.rampe(motif, 8)
	var fil := PeintureBati.bruit(w, h, 24, 32, graine + 1)
	var meso := PeintureBati.fbm(w, h, 4, 4, 3, graine + 2)
	var hf := PackedFloat32Array()
	hf.resize(w * h)
	var zone := PackedByteArray()   # 0 champ, 1 galon, 2 motif, 3 contour de motif, 4 frange
	zone.resize(w * h)
	for y in h:
		for x in w:
			var z := 0
			var d_bord := mini(mini(x, w - 1 - x), y)
			if y >= 58:
				z = 4
			elif d_bord < 3 or (liseré and d_bord == 4):
				z = 1
			elif d_bord == 3 and liseré:
				z = 0
			else:
				for cy in [17, 31, 45]:
					var d := absi(x - 24) + absi(y - cy)
					if d <= 7:
						z = 3 if d >= 6 or d == 3 else 2
						if d <= 1:
							z = 3
			# galon : petits chevrons
			if z == 1 and ((x + y) % 6) < 3 and d_bord < 3:
				z = 3
			zone[y * w + x] = z
			var tissage := 0.5 + (0.06 if (x + y) % 4 == 0 else 0.0) - (0.05 if (x + 2 * y) % 5 == 0 else 0.0)
			hf[y * w + x] = tissage + (fil[y * w + x] - 0.5) * 0.12
	var lit := PeintureBati.eclairage(hf, w, h, 5.0)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var i := y * w + x
			var z := zone[i]
			var L := 0.5 + (lit[i] - 0.5) * 0.9 + (meso[i] - 0.5) * 0.35 + (fil[i] - 0.5) * 0.12
			if y < 3:
				L -= 0.12     # ourlet de la tringle
			var col: Color
			if z == 4:
				# frange : fils verticaux, un sur deux, qui s'effilochent
				var fx := x % 3
				if fx == 2 or (y > 62 - (x * 7) % 4):
					col = Color(0, 0, 0, 0)
				else:
					col = cm[PeintureBati.ton(0.28 + (lit[i] - 0.5) * 0.5 + fil[i] * 0.2, x, y, 8)]
			elif z == 1 or z == 3 or z == 2:
				var Lm := L + (0.12 if z == 3 else (-0.2 if z == 2 else 0.0))
				col = cm[PeintureBati.ton(Lm * 0.78 + 0.1, x, y, 8)] if z != 2 else cf[PeintureBati.ton(L * 0.6 + 0.12, x, y, 8)]
			else:
				col = cf[PeintureBati.ton(L, x, y, 8)]
			img.set_pixel(x, y, col)
	return [img, PeintureBati.relief_image(hf, w, h, 5.0)]

## Peau de bête : poil court par touffes inclinées, taches claires.
static func peau(graine: int, n := 32) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var taches := PeintureBati.fbm(n, n, 3, 3, 3, graine + 1)
	var grain := PeintureBati.bruit(n, n, n / 2, n / 2, graine + 2)
	var hf := PackedFloat32Array()
	hf.resize(n * n)
	hf.fill(0.4)
	var nuance := PackedFloat32Array()
	nuance.resize(n * n)
	for k in n * 7:
		var x := rng.randi_range(0, n - 1)
		var y := rng.randi_range(0, n - 1)
		var t := rng.randf()
		for s in rng.randi_range(2, 5):
			var i := posmod(y + s, n) * n + posmod(x + (s * 2) / 3, n)
			hf[i] = 0.45 + 0.4 * (1.0 - s * 0.2) * t
			nuance[i] = t
	var lit := PeintureBati.eclairage(hf, n, n, 4.0)
	var coul := PeintureBati.rampe(K_FOURRURE, 12)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			var L := 0.34 + taches[i] * 0.5 + (lit[i] - 0.5) * 0.55 + (nuance[i] - 0.5) * 0.25 + (grain[i] - 0.5) * 0.1
			if taches[i] > 0.62:
				L += 0.16        # taches claires
			img.set_pixel(x, y, coul[PeintureBati.ton(L, x, y)])
	return [img, PeintureBati.relief_image(hf, n, n, 4.0)]

## Terre battue : sol piétiné, cailloux, brins de paille et cendres.
static func terre(graine: int, n := 64) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var meso := PeintureBati.fbm(n, n, 5, 5, 4, graine + 1)
	var grain := PeintureBati.bruit(n, n, n / 2, n / 2, graine + 2)
	var hf := PackedFloat32Array()
	hf.resize(n * n)
	var paille := PackedByteArray()
	paille.resize(n * n)
	for i in n * n:
		hf[i] = 0.45 + (meso[i] - 0.5) * 0.4 + (grain[i] - 0.5) * 0.1
	for k in 18:
		var cx := rng.randi_range(0, n - 1)
		var cy := rng.randi_range(0, n - 1)
		var r := rng.randi_range(1, 2)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r + 1:
					hf[posmod(cy + dy, n) * n + posmod(cx + dx, n)] += 0.28 - (dx + dy) * 0.03
	for k in 26:
		var x := rng.randi_range(0, n - 1)
		var y := rng.randi_range(0, n - 1)
		var pente := rng.randf_range(-0.8, 0.8)
		for s in rng.randi_range(3, 7):
			var i := posmod(y + int(s * pente), n) * n + posmod(x + s, n)
			paille[i] = 1
			hf[i] += 0.06
	var lit := PeintureBati.eclairage(hf, n, n, 5.0)
	var coul := PeintureBati.rampe(PeintureBati.K_TERRE, 12)
	var chaume := PeintureBati.rampe(PeintureBati.K_CHAUME, 12)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			var L := 0.4 + (lit[i] - 0.5) * 0.8 + (meso[i] - 0.5) * 0.4 + (grain[i] - 0.5) * 0.14
			var col := coul[PeintureBati.ton(L, x, y)]
			if paille[i] == 1:
				col = chaume[PeintureBati.ton(0.3 + (lit[i] - 0.5) * 0.4 + grain[i] * 0.15, x, y)]
			img.set_pixel(x, y, col)
	return [img, PeintureBati.relief_image(hf, n, n, 5.0)]

## Charbon et cendre froide (réserve de la forge).
static func charbon(graine: int, n := 32) -> Array:
	var cell := PeintureBati.bruit(n, n, 8, 8, graine + 1)
	var fin := PeintureBati.bruit(n, n, 16, 16, graine + 2)
	var hf := PackedFloat32Array()
	hf.resize(n * n)
	for i in n * n:
		hf[i] = cell[i] * 0.7 + fin[i] * 0.3
	var lit := PeintureBati.eclairage(hf, n, n, 6.0)
	var coul := PeintureBati.rampe(K_SUIE, 12)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			var L := 0.3 + (lit[i] - 0.5) * 1.0 + (hf[i] - 0.5) * 0.4
			if fin[i] > 0.93:
				L += 0.5     # éclat de houille
			img.set_pixel(x, y, coul[PeintureBati.ton(L, x, y)])
	return [img, PeintureBati.relief_image(hf, n, n, 6.0)]

## Vitrage 0,7 × 0,55 m (22 × 18 texels, UV du quad) : cadre et plombs opaques (alpha 255), carreaux
## translucides (alpha 0 : le shader `ps1_vitre` règle la transparence), reflet en haut à gauche.
static func vitrage() -> Array:
	var w := 22
	var h := 18
	var bois := PeintureBati.rampe(PeintureBati.K_BOIS, 12)
	var verre := PeintureBati.rampe(PeintureBati.K_BRAISE, 12)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var col: Color
			var mx := 10 <= x and x <= 11
			var my := 8 <= y and y <= 9
			if x < 2 or x >= w - 2 or y < 2 or y >= h - 2 or mx or my:
				var L := 0.34 + (0.14 if (x == 2 or y == 2) else 0.0) - (0.1 if (x == w - 3 or y == h - 3) else 0.0)
				col = bois[PeintureBati.ton(L, x, y)]
				col.a = 1.0
			else:
				var px := x - 2 if x < 10 else x - 12
				var py := y - 2 if y < 8 else y - 10
				var L := 0.85 - float(px) / 18.0 - float(py) / 16.0 + (0.18 if px < 3 and py < 2 else 0.0)
				col = verre[PeintureBati.ton(L, x, y, 12)]
				col.a = 0.0
			img.set_pixel(x, y, col)
	return [img, null]

static func fabriques() -> Dictionary:
	return {
		"tenture_rouge": func() -> Array: return tenture(6101, K_ROUGE, K_OCRE),
		"tenture_bleue": func() -> Array: return tenture(6102, K_BLEU, K_CREME),
		"tenture_verte": func() -> Array: return tenture(6103, K_VERT, K_OCRE),
		"peau": func() -> Array: return peau(6111),
		"terre": func() -> Array: return terre(6121),
		"charbon": func() -> Array: return charbon(6131),
		"vitrage": func() -> Array: return vitrage(),
	}
