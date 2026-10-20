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

## Tenture tissée de 1,5 × 2 m (96 × 128 texels = 64 texels/m, UV en mètres sur le quad) : galon d'ocre à chevrons,
## champ uni, trois losanges en chaîne, frange effilochée en bas. Trame et chaîne visibles (fils croisés d'un texel),
## plis verticaux, salissure en bas. `fond` / `motif` : rampes de couleur.
static func tenture(graine: int, fond: Array, motif: Array, liseré := true) -> Array:
	var w := 96
	var h := 128
	var cf := PeintureBati.rampe(fond, 12)
	var cm := PeintureBati.rampe(motif, 12)
	var fil := PeintureBati.bruit(w, h, 48, 64, graine + 1)
	var meso := PeintureBati.fbm(w, h, 4, 5, 3, graine + 2)
	var plis := PeintureBati.bruit(w, h, 9, 2, graine + 3)
	var hf := PackedFloat32Array()
	hf.resize(w * h)
	var zone := PackedByteArray()   # 0 champ, 1 galon, 2 motif, 3 contour de motif, 4 frange
	zone.resize(w * h)
	for y in h:
		for x in w:
			var z := 0
			var d_bord := mini(mini(x, w - 1 - x), y)
			if y >= 116:
				z = 4
			elif d_bord < 6 or (liseré and (d_bord == 9 or d_bord == 10)):
				z = 1
			elif liseré and d_bord < 9:
				z = 0
			else:
				for cy in [34, 62, 90]:
					var d := absi(x - 48) + absi(y - cy)
					if d <= 14:
						z = 3 if d >= 12 or d == 6 or d == 7 else 2
						if d <= 2:
							z = 3
			if z == 1 and d_bord < 6 and ((x + y) % 12) < 6:
				z = 3      # galon : chevrons
			zone[y * w + x] = z
			# armure : chaîne et trame alternées, un fil = 1 texel
			var tissage := 0.5 + (0.07 if ((x >> 0) + (y >> 0)) % 2 == 0 else -0.04) + (0.05 if (x % 4 < 2) == (y % 4 < 2) else 0.0)
			hf[y * w + x] = tissage + (fil[y * w + x] - 0.5) * 0.14 + (plis[y * w + x] - 0.5) * 0.25
	var lit := PeintureBati.eclairage(hf, w, h, 2.6)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var i := y * w + x
			var z := zone[i]
			var bas := clampf(float(y - 90) / 38.0, 0.0, 1.0)
			var L := 0.5 + (lit[i] - 0.5) * 0.8 + (meso[i] - 0.5) * 0.4 + (fil[i] - 0.5) * 0.14 + (plis[i] - 0.5) * 0.3 - bas * 0.12
			if y < 6:
				L -= 0.14     # ourlet de la tringle
			elif y < 8:
				L -= 0.07
			var col: Color
			if z == 4:
				# frange : fils verticaux qui s'effilochent
				var fx := x % 4
				if fx == 3 or (y > 126 - (x * 7) % 5 - (3 if fx == 1 else 0)):
					col = Color(0, 0, 0, 0)
				else:
					col = cm[ton_b(0.28 + (lit[i] - 0.5) * 0.5 + fil[i] * 0.2, x, y, 12, graine)]
			elif z == 1 or z == 3 or z == 2:
				var Lm := L + (0.12 if z == 3 else (-0.2 if z == 2 else 0.0))
				col = cm[ton_b(Lm * 0.78 + 0.1, x, y, 12, graine)] if z != 2 else cf[ton_b(L * 0.6 + 0.12, x, y, 12, graine)]
			else:
				col = cf[ton_b(L, x, y, 12, graine)]
			img.set_pixel(x, y, col)
	return [img, PeintureBati.relief_image(hf, w, h, 2.6)]

## Peau de bête : poil court par touffes inclinées, taches claires.
static func peau(graine: int, n := 64) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var taches := PeintureBati.fbm(n, n, 3, 3, 3, graine + 1)
	var grain := PeintureBati.bruit(n, n, n / 2, n / 2, graine + 2)
	var hf := PackedFloat32Array()
	hf.resize(n * n)
	hf.fill(0.4)
	var nuance := PackedFloat32Array()
	nuance.resize(n * n)
	for k in n * 12:
		var x := rng.randi_range(0, n - 1)
		var y := rng.randi_range(0, n - 1)
		var t := rng.randf()
		for s in rng.randi_range(4, 9):
			var i := posmod(y + s, n) * n + posmod(x + (s * 2) / 3, n)
			hf[i] = 0.45 + 0.4 * (1.0 - s * 0.11) * t
			nuance[i] = t
	var lit := PeintureBati.eclairage(hf, n, n, 2.4)
	var coul := PeintureBati.rampe(K_FOURRURE, 12)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			var L := 0.34 + taches[i] * 0.5 + (lit[i] - 0.5) * 0.55 + (nuance[i] - 0.5) * 0.25 + (grain[i] - 0.5) * 0.1
			if taches[i] > 0.62:
				L += 0.16        # taches claires
			img.set_pixel(x, y, coul[ton_b(L, x, y, 12, graine)])
	return [img, PeintureBati.relief_image(hf, n, n, 2.4)]

## Terre battue : sol piétiné, cailloux, brins de paille et cendres.
static func terre(graine: int, n := 128) -> Array:
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
	for k in 60:
		var cx := rng.randi_range(0, n - 1)
		var cy := rng.randi_range(0, n - 1)
		var r := rng.randi_range(2, 4)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r + 1:
					hf[posmod(cy + dy, n) * n + posmod(cx + dx, n)] += 0.28 - (dx + dy) * 0.015
	for k in 90:
		var x := rng.randi_range(0, n - 1)
		var y := rng.randi_range(0, n - 1)
		var pente := rng.randf_range(-0.8, 0.8)
		for s in rng.randi_range(6, 14):
			var i := posmod(y + int(s * pente), n) * n + posmod(x + s, n)
			paille[i] = 1
			hf[i] += 0.06
	var lit := PeintureBati.eclairage(hf, n, n, 3.0)
	var coul := PeintureBati.rampe(PeintureBati.K_TERRE, 12)
	var chaume := PeintureBati.rampe(PeintureBati.K_CHAUME, 12)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			var L := 0.4 + (lit[i] - 0.5) * 0.8 + (meso[i] - 0.5) * 0.4 + (grain[i] - 0.5) * 0.14
			var col := coul[ton_b(L, x, y, 12, graine)]
			if paille[i] == 1:
				col = chaume[ton_b(0.3 + (lit[i] - 0.5) * 0.4 + grain[i] * 0.15, x, y, 12, graine)]
			img.set_pixel(x, y, col)
	return [img, PeintureBati.relief_image(hf, n, n, 3.0)]

## Charbon et cendre froide (réserve de la forge).
static func charbon(graine: int, n := 64) -> Array:
	var cell := PeintureBati.bruit(n, n, 12, 12, graine + 1)
	var fin := PeintureBati.bruit(n, n, 32, 32, graine + 2)
	var hf := PackedFloat32Array()
	hf.resize(n * n)
	for i in n * n:
		hf[i] = cell[i] * 0.7 + fin[i] * 0.3
	var lit := PeintureBati.eclairage(hf, n, n, 3.5)
	var coul := PeintureBati.rampe(K_SUIE, 12)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y * n + x
			var L := 0.3 + (lit[i] - 0.5) * 1.0 + (hf[i] - 0.5) * 0.4
			if fin[i] > 0.93:
				L += 0.5     # éclat de houille
			img.set_pixel(x, y, coul[ton_b(L, x, y, 12, graine)])
	return [img, PeintureBati.relief_image(hf, n, n, 3.5)]

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


# ------------------------------------------------------------------------------------------------ densité 64 texels/m
# Passe « finitions » : les matières qu'on regarde à moins d'un mètre (pierre, peaux, terre, tentures) sont repeintes à
# 64 texels/m (le shader intérieur les lit avec `texels_par_m` = 64, mip 1 = 32 texels/m au loin). Rampes de 12 tons,
# tramage par BRUIT (jamais de Bayer), teinte CHAude : sous le feu, la pierre doit rougeoyer et non bleuir.

const K_PIERRE_A := ["#14110f", "#221c19", "#332a25", "#473b34", "#5d4e44", "#75645a", "#8e7b6d", "#a69384", "#bfab99", "#d3c1ad"]
const K_PIERRE_B := ["#17120d", "#2a2017", "#3f3122", "#56432e", "#6f593b", "#8a7149", "#a18857", "#b9a06c"]
const K_PIERRE_C := ["#12130f", "#1f201b", "#302f29", "#444239", "#5a574b", "#726e60", "#8d887a", "#a6a090"]
const K_SALPETRE := ["#2a2a27", "#44443d", "#5f5f55", "#7d7d70", "#9c9c8c"]

## Index de ton avec tramage par bruit blanc stable (amplitude < 1 ton).
static func ton_b(L: float, x: int, y: int, n: int, graine := 0) -> int:
	var hsh := fposmod(sin(float(x) * 12.9898 + float(y) * 78.233 + float(graine) * 3.7) * 43758.5453, 1.0)
	return clampi(int(floor(L * (n - 1) + (hsh - 0.5) * 0.7 + 0.5)), 0, n - 1)

## Pierre sèche d'intérieur : assises de 22 à 34 cm, moellons de 40 à 110 cm, joints creux sombres de 1 à 2 texels avec
## lèvre claire au-dessus de chaque pierre, bombé de chaque moellon (haut éclairé, bas sombre), éclats, salpêtre aux
## joints bas, teinte propre à chaque pierre. Tuile 256 × 256 = 4 × 4 m (64 texels/m), raccordée sur les quatre bords.
static func pierre_int(graine: int, w := 256, h := 256, hmin := 14, hmax := 22, wmin := 26, wmax := 70, rayon := 3.4, grain_fort := 1.0) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var assises := PeintureBati._decouper(rng, h, hmin, hmax)
	var nc := assises.size()
	var y0 := PackedInt32Array()
	y0.resize(nc)
	var row_c := PackedInt32Array()
	row_c.resize(h)
	var yy := 0
	for c in nc:
		y0[c] = yy
		for r in assises[c]:
			row_c[yy + r] = c
		yy += assises[c]
	var starts: Array = []
	var tilt := PackedFloat32Array()
	var base_id := PackedInt32Array()
	var total := 0
	var prec := PackedFloat32Array()
	for c in nc:
		var larg: Array[int] = []
		var st := PackedFloat32Array()
		for essai in 14:
			larg = PeintureBati._decouper(rng, w, wmin, wmax)
			var dep := rng.randf_range(0, wmax)
			st = PackedFloat32Array()
			var x := dep
			var ok := true
			for lw in larg:
				st.append(x)
				for p in prec:
					if absf(fposmod(x - p + w * 0.5, w) - w * 0.5) < 8.0:
						ok = false
				x += lw
			if ok:
				break
		prec = st
		starts.append(st)
		tilt.append(rng.randf_range(-0.2, 0.2))
		base_id.append(total)
		total += larg.size()
	var l0 := PackedFloat32Array()
	var tint := PackedFloat32Array()
	var proud := PackedFloat32Array()
	var salp := PackedFloat32Array()
	for i in total:
		l0.append(rng.randf_range(0.4, 0.72))
		tint.append(rng.randf())
		proud.append(rng.randf_range(0.55, 0.85) if rng.randf() > 0.2 else rng.randf_range(0.9, 1.0))
		salp.append(rng.randf())
	var ond := PackedInt32Array()
	ond.resize(w)
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	for x in w:
		ond[x] = int(round(2.4 * sin(TAU * 2 * x / w + p1) + 1.6 * sin(TAU * 5 * x / w + p2)))
	var nj := PeintureBati.bruit(w, h, 48, 24, graine + 1)
	var chip := PeintureBati.fbm(w, h, 20, 12, 3, graine + 2)
	var meso := PeintureBati.fbm(w, h, 16, 16, 4, graine + 3)
	var grain := PeintureBati.bruit(w, h, w / 2, h / 2, graine + 4)
	var grain2 := PeintureBati.bruit(w, h, w / 3, h / 3, graine + 9)
	var sid := PackedInt32Array()
	sid.resize(w * h)
	var vfr := PackedFloat32Array()
	vfr.resize(w * h)
	var hf := PackedFloat32Array()
	hf.resize(w * h)
	var lev := PackedFloat32Array()      # 1 = lèvre claire (juste au-dessus d'un joint), -1 = ombre sous la pierre
	lev.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			var yv := posmod(y + ond[x], h)
			var c := row_c[yv]
			var hh: float = assises[c]
			var v := float(yv - y0[c]) + 0.5
			var xx := fposmod(x - tilt[c] * (v - hh * 0.5), w)
			var st: PackedFloat32Array = starts[c]
			if xx < st[0]:
				xx += w
			var k := st.size() - 1
			for j in st.size() - 1:
				if xx < st[j + 1]:
					k = j
					break
			var sw: float = (st[k + 1] if k + 1 < st.size() else st[0] + w) - st[k]
			var u := xx - st[k]
			var jit := (nj[i] - 0.5) * 3.6
			var du := minf(u, sw - u) + jit
			var dv := minf(v, hh - v) + (nj[(i + w * 5) % (w * h)] - 0.5) * 2.4
			var ex := minf(du, dv)
			if du < rayon and dv < rayon:
				ex = rayon - sqrt((rayon - du) * (rayon - du) + (rayon - dv) * (rayon - dv))
			var id := base_id[c] + k
			sid[i] = id
			vfr[i] = v / hh
			var jw := 0.7 + nj[(i + 11) % (w * h)] * 1.1
			var t := clampf((ex - jw) / (rayon + 2.0 * (1.0 - proud[id])), 0.0, 1.0)
			var prof := PeintureBati._sstep(0.0, 1.0, t)
			var dome := 1.0 - 0.5 * (pow(u / sw * 2.0 - 1.0, 2.0) + pow(v / hh * 2.0 - 1.0, 2.0))
			var ht := proud[id] * (0.5 + 0.5 * pow(prof, 0.8)) + 0.2 * dome + (meso[i] - 0.5) * 0.4 + (grain[i] - 0.5) * 0.06 * grain_fort
			if chip[i] > 0.68 and ex > jw + 0.8:
				ht -= 0.16 + (chip[i] - 0.68) * 0.9
			hf[i] = 0.0 if ex < jw else maxf(ht, 0.04)
			# lèvre : bord haut de la pierre (v petit), ombre : bord bas
			if ex >= jw and ex < jw + 1.6:
				lev[i] = 1.0 if v < hh * 0.5 else -1.0
	var lit := PeintureBati.eclairage(hf, w, h, 3.2)
	var omb := PeintureBati.ombres(hf, w, h, 0.1)
	var hb := PeintureBati.flou(hf, w, h, 4)
	var ra := PeintureBati.rampe(K_PIERRE_A, 12)
	var rb := PeintureBati.rampe(K_PIERRE_B, 12)
	var rc := PeintureBati.rampe(K_PIERRE_C, 12)
	var rs := PeintureBati.rampe(K_SALPETRE, 12)
	var lk := PeintureBati.fbm(w, h, 10, 10, 3, graine + 6)
	var strie := PeintureBati.bruit(w, h, 70, 5, graine + 8)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var i := y * w + x
			var id := sid[i]
			var joint := hf[i] <= 0.0
			var ao := clampf(hb[i] - hf[i], 0.0, 0.3)
			var L := l0[id] + (lit[i] - 0.5) * 0.8 - ao * 0.7 + clampf(hf[i] - hb[i], 0.0, 0.3) * 0.6
			L += (0.5 - vfr[i]) * 0.3 + (meso[i] - 0.5) * 0.2 + (grain[i] - 0.5) * 0.12 + (grain2[i] - 0.5) * 0.08
			L -= omb[i] * 0.09
			if lev[i] > 0.5:
				L += 0.11     # arête éclairée : 1 ton au-dessus, pas blanche
			elif lev[i] < -0.5:
				L -= 0.08
			var s := strie[i]
			if s > 0.62:
				L -= (s - 0.62) * 0.55 * (1.0 - vfr[i] * 0.6)    # coulures
			if joint:
				L = 0.03 + grain[i] * 0.07
			var tt := tint[id]
			var ix := ton_b(L, x, y, 12, graine)
			var col: Color
			if tt < 0.5:
				col = ra[ix].lerp(rb[ix], tt / 0.5 * 0.55)
			elif tt < 0.82:
				col = ra[ix].lerp(rc[ix], (tt - 0.5) / 0.32 * 0.4)
			else:
				col = rb[ix].lerp(rc[ix], 0.3)
			# salpêtre pâle en bas des pierres, près des joints
			if not joint and salp[id] > 0.6 and lk[i] > 0.6 and vfr[i] > 0.55:
				col = rs[ton_b(L * 0.9 + 0.08, x, y, 12, graine + 5)]
			img.set_pixel(x, y, col)
	return [img, PeintureBati.relief_image(hf, w, h, 3.2)]

## Bois à 64 texels/m : on repart de la matière du bâti (structure : joints, nœuds, fentes), doublée en résolution, puis on
## ajoute le veinage fin (fibres de 1 texel le long du fil, cernes), des pores sombres et des arêtes de joint nettes.
## `axe` : 0 = fil le long de X, 1 = fil le long de Y. Pas de tramage ordonné : bruit fin seulement.
static func raffine_bois(r: Array, graine: int, axe: int) -> Array:
	var img: Image = r[0]
	var rel: Image = r[1]
	var w := img.get_width() * 2
	var h := img.get_height() * 2
	img.resize(w, h, Image.INTERPOLATE_NEAREST)
	rel.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var cx := w / 2 if axe == 1 else 14
	var cy := 14 if axe == 1 else h / 2
	var fib := PeintureBati.bruit(w, h, cx, cy, graine + 21)
	var fib2 := PeintureBati.bruit(w, h, cx * 2 if axe == 1 else 28, 28 if axe == 1 else cy * 2, graine + 22)
	var cerne := PeintureBati.bruit(w, h, 4 if axe == 1 else 3, 3 if axe == 1 else 4, graine + 23)
	var pores := PeintureBati.bruit(w, h, w / 2 if axe == 1 else 40, 40 if axe == 1 else h / 2, graine + 24)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var f := (fib[y * w + x] - 0.5) * 0.5 + (fib2[y * w + x] - 0.5) * 0.35
			var k := 1.0 + f * 0.55 + (cerne[y * w + x] - 0.5) * 0.12
			var hsh := fposmod(sin(float(x) * 12.9898 + float(y) * 78.233 + float(graine)) * 43758.5453, 1.0)
			k += (hsh - 0.5) * 0.05
			if pores[y * w + x] > 0.84:
				k *= 0.8       # pores / fibres creuses
			img.set_pixel(x, y, Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1), c.a))
	return [img, rel]

static func fabriques() -> Dictionary:
	return {
		"planches_v_int": func() -> Array: return raffine_bois(PeintureBati.planches(5311), 5311, 1),
		"planches_h_int": func() -> Array: return raffine_bois(PeintureBati.planches(5312, 128, 128, true), 5312, 0),
		"rondins_int": func() -> Array: return raffine_bois(PeintureBati.rondins(5321), 5321, 0),
		"pierre_int": func() -> Array: return pierre_int(6201),
		"pierre_int_s": func() -> Array: return pierre_int(6203, 256, 256, 18, 28, 36, 90, 4.4),
		"tenture_rouge": func() -> Array: return tenture(6101, K_ROUGE, K_OCRE),
		"tenture_bleue": func() -> Array: return tenture(6102, K_BLEU, K_CREME),
		"tenture_verte": func() -> Array: return tenture(6103, K_VERT, K_OCRE),
		"peau": func() -> Array: return peau(6111),
		"terre": func() -> Array: return terre(6121),
		"charbon": func() -> Array: return charbon(6131),
		"vitrage": func() -> Array: return vitrage(),
	}
