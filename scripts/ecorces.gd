class_name Ecorces
## Lot 2, troncs : écorces « réalisme 32 bits » (épicéa, pin, bouleau, bois mort).
## Tuiles 64×64 = 2 m × 2 m = 32 texels/m (le fondu vers 16 texels/m au loin est fait par le shader
## `ps1_tronc` avec le niveau 1 des mipmaps). Chaque essence a deux tuiles : `haut` (fût) et `pied`
## (écorce crevassée du bas). Principe : un CHAMP DE HAUTEUR (plaques de Voronoï périodiques à crevasses,
## fibres, marques) dont on tire l'éclairage (arête haute claire, creux sombres) ; la luminance finale est
## quantifiée en 10 tons par essence (rampes étendues depuis la bible) + 3 tons de lichen, puis filtre
## « mode » (aucun texel isolé). Canal alpha = hauteur (le shader s'en sert pour la mousse, la neige et
## le relief). Aucun tirage du RNG monde : tout est déterministe (graines fixes).

const N := 64
const TONS := 10
## Cases au-delà de TONS = lichen (3 tons gris-vert).
const LICHEN := ["#4d5a4d", "#707c68", "#98a38a"]

static var _cache := {}

# ------------------------------------------------------------------ outils de base
static func rampe(stops: Array, n := TONS) -> Array:
	var out := []
	for i in n:
		var t := float(i) / (n - 1) * (stops.size() - 1)
		var a := int(floor(t))
		var b := mini(a + 1, stops.size() - 1)
		out.append(Color(stops[a]).lerp(Color(stops[b]), t - a))
	return out

static func _hs(x: int, y: int, s: int) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 1274126177) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1103515245) & 0x7fffffff
	return float((h ^ (h >> 15)) & 0xffff) / 65535.0

## Bruit de valeur périodique : réseau fx × fy sur la tuile, interpolation cubique.
static func _champ(fx: int, fy: int, s: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(N * N)
	var g := PackedFloat32Array()
	g.resize(fx * fy)
	for j in fy:
		for i in fx:
			g[j * fx + i] = _hs(i, j, s)
	for y in N:
		var gy := (y + 0.5) / N * fy
		var iy := int(floor(gy))
		var ty := gy - iy
		ty = ty * ty * (3.0 - 2.0 * ty)
		var y0 := posmod(iy, fy) * fx
		var y1 := posmod(iy + 1, fy) * fx
		for x in N:
			var gx := (x + 0.5) / N * fx
			var ix := int(floor(gx))
			var tx := gx - ix
			tx = tx * tx * (3.0 - 2.0 * tx)
			var x0 := posmod(ix, fx)
			var x1 := posmod(ix + 1, fx)
			out[y * N + x] = lerpf(lerpf(g[y0 + x0], g[y0 + x1], tx), lerpf(g[y1 + x0], g[y1 + x1], tx), ty)
	return out

## Voronoï périodique : cx × cy cellules (rangées impaires décalées de `stagger` cellule), `jit` = écart des
## points, (sx, sy) = métrique (sy > 1 : cellules plus étroites en hauteur), `warp` px de gauchissement.
## Renvoie {gap: F2-F1 en px, f1: distance au centre, id: identifiant de cellule (0..1)}.
static func _voronoi(cx: int, cy: int, jit: float, sx: float, sy: float, stagger: float, warp: float, s: int) -> Dictionary:
	var cw := float(N) / cx
	var ch := float(N) / cy
	var px_ := PackedFloat32Array()
	var py_ := PackedFloat32Array()
	var idc := PackedFloat32Array()
	for j in cy:
		var ox := stagger * (0.5 if j % 2 == 1 else 0.0)
		for i in cx:
			px_.append((i + 0.5 + ox + (_hs(i, j, s) - 0.5) * jit) * cw)
			py_.append((j + 0.5 + (_hs(i, j, s + 7) - 0.5) * jit) * ch)
			idc.append(_hs(i, j, s + 13))
	var wx := _champ(5, 5, s + 31)
	var wy := _champ(5, 5, s + 47)
	var gap := PackedFloat32Array()
	var f1a := PackedFloat32Array()
	var ida := PackedFloat32Array()
	gap.resize(N * N)
	f1a.resize(N * N)
	ida.resize(N * N)
	for y in N:
		for x in N:
			var k0 := y * N + x
			var px := x + 0.5 + (wx[k0] - 0.5) * warp
			var py := y + 0.5 + (wy[k0] - 0.5) * warp
			var ci := int(floor(px / cw))
			var cj := int(floor(py / ch))
			var d1 := 1e9
			var d2 := 1e9
			var id := 0.0
			for dj in range(-1, 2):
				var jj := cj + dj
				var wj := posmod(jj, cy)
				for di in range(-1, 2):
					var ii := ci + di
					var wi := posmod(ii, cx)
					var k := wj * cx + wi
					var dx := (px_[k] + (ii - wi) * cw - px) * sx
					var dy := (py_[k] + (jj - wj) * ch - py) * sy
					var d := dx * dx + dy * dy
					if d < d1:
						d2 = d1
						d1 = d
						id = idc[k]
					elif d < d2:
						d2 = d
			f1a[k0] = sqrt(d1)
			gap[k0] = sqrt(d2) - sqrt(d1)
			ida[k0] = id
	return {"gap": gap, "f1": f1a, "id": ida}

static func _st(e: float, x: float) -> float:
	return 1.0 if x >= e else 0.0

static func _at(a: PackedFloat32Array, x: int, y: int) -> float:
	return a[posmod(y, N) * N + posmod(x, N)]

## Éclairage rasant depuis le haut-gauche : arête haute claire (+), pied d'une plaque dans l'ombre (−).
static func _lumiere(H: PackedFloat32Array) -> PackedFloat32Array:
	var L := PackedFloat32Array()
	L.resize(N * N)
	for y in N:
		for x in N:
			L[y * N + x] = (_at(H, x - 1, y - 1) * 0.6 + _at(H, x, y - 1) * 0.4 + _at(H, x - 1, y) * 0.4
				- _at(H, x + 1, y + 1) * 0.6 - _at(H, x, y + 1) * 0.4 - _at(H, x + 1, y) * 0.4)
	return L

## Fissures verticales longues (crevasses) : retire de la hauteur et de la luminance.
static func _fissures(H: PackedFloat32Array, lum: PackedFloat32Array, n: int, s: int, largeur: float, long_min: int, long_max: int, prof: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000 + s
	for f in n:
		var x0 := rng.randf() * N
		var y0 := rng.randi_range(0, N - 1)
		var L := rng.randi_range(long_min, long_max)
		var ph := rng.randf() * TAU
		var dev := rng.randf_range(0.8, 2.2)
		for d in L:
			var t := float(d) / L
			var ef := sin(PI * t)   # s'effile aux deux bouts
			var xc := x0 + dev * sin(ph + t * 4.0) + t * rng.randf_range(-0.3, 0.3)
			var w := largeur * ef
			for dx in range(-3, 4):
				var xx := int(floor(xc)) + dx
				var dist := absf(xx + 0.5 - xc)
				if dist < w + 0.7:
					var k := posmod(y0 + d, N) * N + posmod(xx, N)
					var q := clampf(1.0 - dist / (w + 0.7), 0.0, 1.0)
					H[k] = lerpf(H[k], 0.0, q * prof)
					lum[k] -= 0.38 * q * prof
					# lèvre claire côté gauche (la lumière vient du haut-gauche)
				elif dist < w + 1.7 and xx + 0.5 < xc:
					var k2 := posmod(y0 + d, N) * N + posmod(xx, N)
					lum[k2] += 0.07 * ef

# ------------------------------------------------------------------ finition
static func _finir(lum: PackedFloat32Array, H: PackedFloat32Array, ramp: Array, graine: int, lichen := PackedFloat32Array(), passes := 2) -> Image:
	var idx := PackedInt32Array()
	idx.resize(N * N)
	var grain := _champ(32, 32, graine + 3)   # grain fin (aucun bruit blanc : lisse sur 2 texels)
	for i in N * N:
		var v := clampf(lum[i] + (grain[i] - 0.5) * 0.07, 0.0, 1.0)
		idx[i] = clampi(int(round(v * (ramp.size() - 1))), 0, ramp.size() - 1)
		if lichen.size() > 0 and lichen[i] > 0.0:
			idx[i] = TONS + clampi(int(lichen[i] * 3.0), 0, 2)
	_mode(idx, passes)
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var i := y * N + x
			var c: Color = Color(LICHEN[idx[i] - TONS]) if idx[i] >= TONS else ramp[idx[i]]
			c.a = clampf(H[i], 0.0, 1.0)
			img.set_pixel(x, y, c)
	return img

## Filtre « mode » : un texel qui n'a aucun voisin (8) de même ton prend le ton majoritaire du voisinage.
static func _mode(idx: PackedInt32Array, passes: int) -> void:
	for p in passes:
		var nouveau := idx.duplicate()
		for y in N:
			for x in N:
				var me := idx[y * N + x]
				var cnt := {}
				var egaux := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var v := idx[posmod(y + dy, N) * N + posmod(x + dx, N)]
						cnt[v] = int(cnt.get(v, 0)) + 1
						if v == me:
							egaux += 1
				if egaux < (1 if p == 0 else 2):
					var best := me
					var bn := 0
					for k: int in cnt:
						if cnt[k] > bn or (cnt[k] == bn and absi(k - me) < absi(best - me)):
							bn = cnt[k]
							best = k
					nouveau[y * N + x] = best
		for i in idx.size():
			idx[i] = nouveau[i]

## Mipmaps : couleur = ton majoritaire du bloc 2×2 (à égalité le plus sombre), alpha (hauteur) = moyenne.
static func mips(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(mips_image(img))

static func mips_image(img: Image) -> Image:
	var niveaux: Array[Image] = [img]
	var cur := img
	while cur.get_width() > 1:
		var w := cur.get_width() / 2
		var nxt := Image.create(w, w, false, Image.FORMAT_RGBA8)
		for y in w:
			for x in w:
				var cnt := {}
				var h := 0.0
				for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var c := cur.get_pixel(x * 2 + d.x, y * 2 + d.y)
					h += c.a * 0.25
					var cc := Color(c.r, c.g, c.b, 1.0)
					cnt[cc] = int(cnt.get(cc, 0)) + 1
				var best := Color.BLACK
				var bn := 0
				for k: Color in cnt:
					if cnt[k] > bn or (cnt[k] == bn and k.get_luminance() < best.get_luminance()):
						bn = cnt[k]
						best = k
				best.a = h
				nxt.set_pixel(x, y, best)
		niveaux.append(nxt)
		cur = nxt
	var data := PackedByteArray()
	for n in niveaux:
		data.append_array(n.get_data())
	return Image.create_from_data(N, N, true, Image.FORMAT_RGBA8, data)


## Écorce générique : plaques de Voronoï (cx × cy cellules), contraste faible entre plaques, fissures sombres fines.
static func _plaques(cx: int, cy: int, jit: float, stag: float, warp: float, graine: int, base: float, ecart: float, relief: float, crev: float, crev_w: float, ramp: Array, fiss: int, fl: Vector2i, passes := 1, lichen := PackedFloat32Array()) -> Image:
	var v := _voronoi(cx, cy, jit, 1.0, 1.0, stag, warp, graine)
	var gap: PackedFloat32Array = v["gap"]
	var id: PackedFloat32Array = v["id"]
	var lent := _champ(3, 4, graine + 1)
	var fin := _champ(12, 16, graine + 2)
	var H := PackedFloat32Array()
	H.resize(N * N)
	var lum := PackedFloat32Array()
	lum.resize(N * N)
	for i in N * N:
		H[i] = clampf(smoothstep(0.0, crev_w * 2.5, gap[i]) * 0.8 + (fin[i] - 0.5) * 0.14 + 0.12, 0.0, 1.0)
	var L := _lumiere(H)
	for i in N * N:
		var c := 1.0 - smoothstep(0.0, crev_w, gap[i])
		lum[i] = base + ecart * (id[i] - 0.5) + 0.07 * (lent[i] - 0.5) + relief * L[i] + 0.06 * (fin[i] - 0.5) - crev * c
	if fiss > 0:
		_fissures(H, lum, fiss, graine % 97, 0.6, fl.x, fl.y, 0.9)
	return _finir(lum, H, ramp, graine, lichen, passes)

# ------------------------------------------------------------------ épicéa : écailles fines gris-brun
const R_EPICEA := ["#231d1d", "#322a28", "#41372f", "#4d433a", "#5a4f45", "#665b50", "#72675b"]
static func epicea_haut() -> Image:
	# écailles fines (1-3 texels), valeurs voisines, fissures courtes
	var lic := _champ(4, 5, 131)
	var v0 := _plaques(20, 15, 0.8, 1.0, 1.5, 101, 0.5, 0.24, 0.38, 0.34, 0.55, rampe(R_EPICEA), 4, Vector2i(5, 10))
	return v0
static func epicea_pied() -> Image:
	# plaques un peu plus larges et hautes, fissures verticales courtes
	return _plaques(14, 12, 0.8, 0.5, 2.0, 151, 0.45, 0.22, 0.3, 0.38, 0.7, rampe(R_EPICEA), 6, Vector2i(8, 16))
# ------------------------------------------------------------------ pin : plaques orangées / crevasses grises
const R_PIN_HAUT := ["#2c161b", "#4b2321", "#703224", "#92472a", "#b4602f", "#d4803c", "#eea560"]
const R_PIN_PIED := ["#1c1620", "#2b2527", "#3a3231", "#483f3a", "#574d45", "#675b50"]
static func pin_haut() -> Image:
	# fines plaquettes orangées qui pèlent, valeurs proches
	return _plaques(12, 14, 0.8, 0.5, 2.0, 201, 0.55, 0.2, 0.4, 0.34, 0.6, rampe(R_PIN_HAUT), 3, Vector2i(6, 12))
static func pin_pied() -> Image:
	# plaques allongées verticalement (≈ 1:4), longues crevasses grises
	return _plaques(16, 3, 0.5, 0.5, 2.0, 251, 0.46, 0.3, 0.4, 0.55, 1.1, rampe(R_PIN_PIED), 8, Vector2i(16, 34))
# ------------------------------------------------------------------ bouleau : papier blanc, lenticelles, losanges noirs
const R_BOULEAU := ["#14121a", "#2b2935", "#47465a", "#686d8a", "#8e93ad", "#b4b8ca", "#d3d5e0", "#ebe9ea", "#f6f1e7"]
const R_BOULEAU_PIED := ["#0f0e14", "#1a1820", "#2a2831", "#3d3b47", "#57566a", "#787f9e"]

static func _plot(lum: PackedFloat32Array, H: PackedFloat32Array, x: int, y: int, l: float, h := -1.0, mode := 0) -> void:
	var k := posmod(y, N) * N + posmod(x, N)
	if mode == 0:
		lum[k] = l
	elif mode == 1:
		lum[k] = minf(lum[k], l)
	else:
		lum[k] = maxf(lum[k], l)
	if h >= 0.0:
		H[k] = h

static func bouleau_haut() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6011
	var a := _champ(2, 3, 301)
	var b := _champ(5, 7, 311)
	var fin := _champ(8, 16, 321)
	var H := PackedFloat32Array()
	H.resize(N * N)
	var lum := PackedFloat32Array()
	lum.resize(N * N)
	for i in N * N:
		lum[i] = 0.74 + 0.16 * (a[i] - 0.5) + 0.2 * (b[i] - 0.5) + 0.07 * (fin[i] - 0.5)
		H[i] = 0.5 + 0.1 * (b[i] - 0.5)
	# papier qui se détache : fines lèvres horizontales, ombre dessous, lumière dessus
	for n in 11:
		var x0 := rng.randi_range(0, N - 1)
		var y0 := rng.randi_range(0, N - 1)
		var L := rng.randi_range(12, 30)
		var dy := 0.0
		for d in L:
			dy += rng.randf_range(-0.25, 0.25)
			var yy := y0 + int(round(dy))
			var e := sin(PI * float(d) / L)
			_plot(lum, H, x0 + d, yy - 1, 0.98, 0.78, 2)
			_plot(lum, H, x0 + d, yy, 0.62 + 0.1 * e, 0.4)
			_plot(lum, H, x0 + d, yy + 1, 0.7, 0.45, 1)
	# lenticelles : tirets horizontaux sombres à bout clair
	for n in 34:
		var x0 := rng.randi_range(0, N - 1)
		var y0 := rng.randi_range(0, N - 1)
		var L := rng.randi_range(3, 9)
		var ep := 2 if rng.randf() < 0.3 else 1
		for d in L:
			var e := sin(PI * (d + 0.5) / L)
			for q in ep:
				_plot(lum, H, x0 + d, y0 + q, 0.36 - 0.16 * e, 0.3)
			_plot(lum, H, x0 + d, y0 - 1, 0.9, 0.62, 2)
			_plot(lum, H, x0 + d, y0 + ep, 0.62, 0.5, 1)
	# losanges noirs : cicatrices de branches, ourlet gris, lèvre claire en bas
	for n in 5:
		var cx := rng.randi_range(0, N - 1)
		var cy := rng.randi_range(0, N - 1)
		var wd := rng.randf_range(2.5, 4.5)
		var ht := rng.randf_range(5.0, 8.5)
		for dy in range(-int(ht) - 2, int(ht) + 3):
			for dx in range(-int(wd) - 2, int(wd) + 3):
				var d := absf(dx) / wd + absf(dy) / ht
				if d < 1.0:
					var prof := 0.05 + 0.2 * d * d   # centre noir, bords un peu moins
					if dy < -ht * 0.55 and d > 0.5:
						prof += 0.1   # arc clair au sommet (le bourrelet de la cicatrice)
					_plot(lum, H, cx + dx, cy + dy, prof, 0.15 + 0.2 * d)
				elif d < 1.35:
					_plot(lum, H, cx + dx, cy + dy, 0.5 + 0.12 * (1.35 - d), 0.55, 1)
				if dy > 0 and d >= 0.95 and d < 1.2 and dx > -wd * 0.5:
					_plot(lum, H, cx + dx, cy + dy, 0.94, 0.9, 2)
	return _finir(lum, H, rampe(R_BOULEAU), 301)

static func bouleau_pied() -> Image:
	var v := _voronoi(8, 3, 0.8, 1.0, 0.45, 0.5, 6.0, 351)
	var gap: PackedFloat32Array = v["gap"]
	var id: PackedFloat32Array = v["id"]
	var fin := _champ(10, 14, 361)
	var H := PackedFloat32Array()
	H.resize(N * N)
	var lum := PackedFloat32Array()
	lum.resize(N * N)
	for i in N * N:
		H[i] = clampf(smoothstep(0.0, 2.8, gap[i]) * 0.85 + (fin[i] - 0.5) * 0.18 + 0.1, 0.0, 1.0)
	var L := _lumiere(H)
	for i in N * N:
		var crevasse := 1.0 - smoothstep(0.0, 1.2, gap[i])
		lum[i] = 0.38 + 0.2 * id[i] + 0.2 * (H[i] - 0.5) + 0.55 * L[i] - 0.4 * crevasse + 0.1 * (fin[i] - 0.5)
	_fissures(H, lum, 4, 51, 1.1, 14, 30, 1.0)
	# restes de papier blanc, hauts de crête
	var pap := _champ(4, 5, 371)
	for i in N * N:
		if pap[i] > 0.82 and H[i] > 0.65:
			lum[i] = maxf(lum[i], 0.72 + (pap[i] - 0.74) * 0.8)
	return _finir(lum, H, rampe(R_BOULEAU_PIED), 351)

# ------------------------------------------------------------------ bois mort : argenté, fendu, fibreux
const R_MORT := ["#241f25", "#3a343c", "#4f4b57", "#68656f", "#817e86", "#9c9791", "#b6b0a6", "#cac4b8"]
static func mort_haut() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7011
	var f1 := _champ(14, 2, 401)    # fibres longues (étroites en x, longues en y)
	var f2 := _champ(30, 5, 411)
	var f3 := _champ(4, 3, 421)
	var wx := _champ(3, 4, 431)
	var H := PackedFloat32Array()
	H.resize(N * N)
	var lum := PackedFloat32Array()
	lum.resize(N * N)
	for y in N:
		for x in N:
			var i := y * N + x
			# cernes : ondes verticales gauchies
			var onde := sin(TAU * (x + (wx[i] - 0.5) * 9.0) / N * 6.0)
			var fib := 0.55 * f1[i] + 0.45 * f2[i]
			H[i] = clampf(0.25 + 0.55 * fib + 0.12 * onde, 0.0, 1.0)
			lum[i] = 0.42 + 0.5 * (fib - 0.5) + 0.07 * onde + 0.14 * (f3[i] - 0.5)
	var L := _lumiere(H)
	for i in N * N:
		lum[i] += 0.5 * L[i]
	_fissures(H, lum, 6, 61, 1.3, 14, 34, 1.0)
	# nœud : ellipse à cernes concentriques
	for dy in range(-6, 7):
		for dx in range(-4, 5):
			var d := sqrt(float(dx * dx) / 12.0 + float(dy * dy) / 40.0)
			if d < 1.0:
				var ring := 0.5 + 0.28 * sin(d * 11.0)
				_plot(lum, H, 22 + dx, 40 + dy, ring * (0.5 + 0.5 * d) * 0.9, 0.3 + 0.4 * d)
			elif d < 1.3:
				_plot(lum, H, 22 + dx, 40 + dy, 0.62, 0.85, 2)
	var lic := _champ(4, 5, 441)
	var lichen := PackedFloat32Array()
	lichen.resize(N * N)
	for i in N * N:
		if lic[i] > 0.86 and H[i] > 0.65:
			lichen[i] = clampf((H[i] - 0.5) * 2.0, 0.0, 0.99)
	return _finir(lum, H, rampe(R_MORT), 401, lichen)

static func mort_pied() -> Image:
	# bois mouillé, plus sombre et plus grossier, fentes plus larges
	var f1 := _champ(9, 2, 451)
	var f2 := _champ(20, 4, 461)
	var wx := _champ(3, 4, 471)
	var H := PackedFloat32Array()
	H.resize(N * N)
	var lum := PackedFloat32Array()
	lum.resize(N * N)
	for y in N:
		for x in N:
			var i := y * N + x
			var onde := sin(TAU * (x + (wx[i] - 0.5) * 10.0) / N * 4.0)
			var fib := 0.6 * f1[i] + 0.4 * f2[i]
			H[i] = clampf(0.25 + 0.55 * fib + 0.14 * onde, 0.0, 1.0)
			lum[i] = 0.26 + 0.48 * (fib - 0.5) + 0.07 * onde
	var L := _lumiere(H)
	for i in N * N:
		lum[i] += 0.5 * L[i]
	_fissures(H, lum, 7, 71, 1.6, 16, 38, 1.0)
	return _finir(lum, H, rampe(R_MORT), 451)

# ------------------------------------------------------------------ textures prêtes à l'emploi
static func tuile(nom: String) -> ImageTexture:
	if not _cache.has(nom):
		var chemin := "res://assets/ecorces/%s.res" % nom
		if ResourceLoader.exists(chemin):
			_cache[nom] = ImageTexture.create_from_image(load(chemin))
		else:
			_cache[nom] = mips(image(nom))
	return _cache[nom]

static func image(nom: String) -> Image:
	match nom:
		"epicea_haut": return epicea_haut()
		"epicea_pied": return epicea_pied()
		"pin_haut": return pin_haut()
		"pin_pied": return pin_pied()
		"bouleau_haut": return bouleau_haut()
		"bouleau_pied": return bouleau_pied()
		"mort_haut": return mort_haut()
		"mort_pied": return mort_pied()
	return null

const NOMS := ["epicea_haut", "epicea_pied", "pin_haut", "pin_pied", "bouleau_haut", "bouleau_pied", "mort_haut", "mort_pied"]

static func vider() -> void:
	_cache.clear()
