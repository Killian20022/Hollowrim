class_name CrypteTextures
## Textures de la crypte (lot 7a), dessinées en AMAS de pixels et non par bruit : blocs taillés avec joints,
## arête haute claire, arête basse ombrée, coins épaufrés, salpêtre, mousse, fissures, poussière.
## Densité : 16 texels/m pour la structure (tuile 64 px = 4 m), 32 texels/m pour le bois, le fer et les
## petits objets (tuile 32 ou 64 px = 1 à 2 m). Tout est dans des rampes de la bible, glissement de teinte
## compris (ombres bleu-violet, lumières un peu plus chaudes). Mipmaps « nearest » maison (vote de couleur 2x2).
## Aucune fonction partagée de palette.gd n'est touchée.

const CLEAR := Color(0, 0, 0, 0)
const K := 2   # facteur de densité de la pierre : 1 = 16 texels/m, 2 = 32 texels/m (voir journal : couloirs étroits)

# rampes : indice 0 = joint / creux, dernier = arête claire
const PIERRE := ["#1f2430", "#2f3643", "#424b5b", "#5a6579", "#7c889c"]
const PIERRE_SOMBRE := ["#161a23", "#212733", "#2f3745", "#414b5c", "#586377"]
const MOUSSE := ["#14231a", "#1e3524", "#2c4c2f", "#44703c"]
const SALPETRE := ["#6a8789", "#8cadab", "#b3cfc8"]
const BOIS := ["#1d130c", "#2d1e13", "#43301e", "#5d4329", "#7b5a37"]
const FER := ["#1e222b", "#323947", "#4c5568", "#7a869c"]
const ROUILLE := ["#3a1f14", "#5e3018", "#8a4a22"]
const OSSE := ["#4f4a3d", "#7b7360", "#a69d82", "#d0c7a8", "#ece4c8"]
const ARGILE := ["#281811", "#412819", "#5d3b26", "#7d5638"]
const PARCHEMIN := ["#4a3d27", "#76663f", "#a8956a", "#c9b88a"]
const TOILE := ["#8d9db0", "#b5c4d3"]
const FLAMME := ["#4a1008", "#a8330c", "#f0801a", "#ffcb52", "#fff3c4"]

static func _c(rampe: Array, i: int) -> Color:
	return Color(rampe[clampi(i, 0, rampe.size() - 1)])

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	img.set_pixel(posmod(x, img.get_width()), posmod(y, img.get_height()), c)

static func _rect(img: Image, x0: int, y0: int, w: int, h: int, c: Color) -> void:
	for y in h:
		for x in w:
			_px(img, x0 + x, y0 + y, c)

static func _rng(graine: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	return r

## Largeurs de blocs qui totalisent exactement `total` (coupe en cas de reste trop petit).
static func _largeurs(rng: RandomNumberGenerator, total: int, choix: Array) -> Array:
	var res := []
	var reste := total
	while reste > 0:
		var w: int = choix[rng.randi_range(0, choix.size() - 1)]
		if reste - w < choix.min():
			w = reste
		res.append(w)
		reste -= w
	return res

## Chaîne de mipmaps « pixel art » : chaque niveau garde la couleur majoritaire d'un bloc 2x2 (à égalité, la plus
## sombre) ; reste opaque si au moins `seuil` pixels sur 4 le sont. Pure (utilisable dans un fil d'exécution).
static func mips_image(img: Image, seuil := 2) -> Image:
	var data := PackedByteArray()
	data.append_array(img.get_data())
	var cur := img
	while cur.get_width() > 1 and cur.get_height() > 1:
		var w := cur.get_width() / 2
		var h := cur.get_height() / 2
		var nxt := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var c: Array[Color] = [cur.get_pixel(x * 2, y * 2), cur.get_pixel(x * 2 + 1, y * 2), cur.get_pixel(x * 2, y * 2 + 1), cur.get_pixel(x * 2 + 1, y * 2 + 1)]
				var opaques := 0
				for k in 4:
					if c[k].a > 0.5:
						opaques += 1
				if opaques < seuil:
					nxt.set_pixel(x, y, CLEAR)
					continue
				var best := -1
				var bn := 0
				for k in 4:
					if c[k].a <= 0.5:
						continue
					var n := 0
					for j in 4:
						if c[j].a > 0.5 and c[j] == c[k]:
							n += 1
					if n > bn or (n == bn and c[k].get_luminance() < c[best].get_luminance()):
						bn = n
						best = k
				var r := c[best]
				r.a = 1.0
				nxt.set_pixel(x, y, r)
		data.append_array(nxt.get_data())
		cur = nxt
	return Image.create_from_data(img.get_width(), img.get_height(), true, Image.FORMAT_RGBA8, data)

static func _mips(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(mips_image(img))

# ------------------------------------------------------------------ pierre taillée en assises
## Mur : assises de 8 texels (0,5 m), blocs de 0,75 à 1,5 m, joints décalés d'une assise à l'autre.
## `v` : 0 = sain, 1 = mousse aux joints + coulures de salpêtre, 2 = humide (salpêtre, plaques sombres).
static func mur_image(v: int, graine := 0) -> Image:
	var rng := _rng(8100 + v * 17 + graine)
	var S := 64 * K
	var RH := 8 * K
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var R := PIERRE_SOMBRE if v == 2 else PIERRE
	img.fill(_c(R, 2))
	var coulures: Array = []
	for rang in 8:
		var y0 := rang * RH
		var x := rng.randi_range(0, S - 1)
		for w: int in _largeurs(rng, S, [12 * K, 16 * K, 16 * K, 20 * K, 24 * K]):
			var ton: int = [1, 2, 2, 2, 3, 3][rng.randi_range(0, 5)]
			if v == 2 and rng.randf() < 0.35:
				ton = 1
			_bloc(img, rng, x, y0, w, RH, R, ton)
			if v >= 1:
				_mousse_bloc(img, rng, x, y0, w, v)
				if rng.randf() < 0.14:
					coulures.append(Vector3i(x + rng.randi_range(2, w - 3), y0 + RH - 1, rng.randi_range(5, 14) * K))
			x += w
	for cl: Vector3i in coulures:
		var xs := cl.x
		for k in cl.z:
			var tone := 1 if k < cl.z - 2 else 2
			_px(img, xs, cl.y + k, _c(SALPETRE, tone if k % 5 != 4 else 0))
			if k % 4 == 1 and rng.randf() < 0.6:
				xs += rng.randi_range(-1, 1)
		_px(img, xs, cl.y + cl.z, _c(SALPETRE, 2))
		_px(img, xs + 1, cl.y + cl.z, _c(SALPETRE, 1))
	return img

## Un bloc : fond, arête haute et gauche claires, arête basse ombrée, joint sombre bas et droite,
## coins épaufrés, amas de relief, éventuelle fissure.
static func _bloc(img: Image, rng: RandomNumberGenerator, x0: int, y0: int, w: int, h: int, R: Array, ton: int) -> void:
	_rect(img, x0, y0, w, h, _c(R, ton))
	for x in w:
		_px(img, x0 + x, y0, _c(R, ton + 1))                # arête haute claire
		_px(img, x0 + x, y0 + h - 2, _c(R, ton - 1))        # ombre du bas
		_px(img, x0 + x, y0 + h - 1, _c(R, 0))              # joint bas
	for y in h - 1:
		_px(img, x0, y0 + y, _c(R, ton + 1))                # arête gauche claire
		_px(img, x0 + w - 1, y0 + y, _c(R, 0))              # joint droit
		_px(img, x0 + w - 2, y0 + y, _c(R, ton - 1))        # ombre de droite
	_px(img, x0, y0 + h - 1, _c(R, 0))
	_px(img, x0 + w - 1, y0, _c(R, 0))
	# coins épaufrés (un cran qui mord dans l'arête)
	if rng.randf() < 0.55:
		_px(img, x0, y0, _c(R, 0))
		_px(img, x0 + 1, y0, _c(R, ton))
		_px(img, x0, y0 + 1, _c(R, ton))
	if rng.randf() < 0.4:
		_px(img, x0 + w - 2, y0, _c(R, 0))
		_px(img, x0 + w - 3, y0, _c(R, ton - 1))
	if rng.randf() < 0.35:
		_px(img, x0, y0 + h - 2, _c(R, 0))
	# amas de relief : 2 à 4 petits plats, plus clairs ou plus sombres
	for k in rng.randi_range(2, 4) * K * K:
		var cx := x0 + rng.randi_range(2, w - 4)
		var cy := y0 + rng.randi_range(1, h - 4)
		var sx := rng.randi_range(1, 3)
		var sy := rng.randi_range(1, 2)
		var t: int = ton + (1 if rng.randf() < 0.5 else -1)
		_rect(img, cx, cy, sx, sy, _c(R, t))
		if t > ton:
			_px(img, cx, cy + sy, _c(R, ton - 1))           # petit ombrage sous un éclat clair
	# fissure en escalier
	if rng.randf() < 0.2:
		var fx := x0 + rng.randi_range(3, w - 4)
		var fy := y0 + 1
		for k in rng.randi_range(4, 6) * K:
			_px(img, fx, fy, _c(R, 0))
			fy += 1
			if rng.randf() < 0.55:
				fx += rng.randi_range(-1, 1)
				_px(img, fx, fy - 1, _c(R, 0))

static func _mousse_bloc(img: Image, rng: RandomNumberGenerator, x0: int, y0: int, w: int, v: int) -> void:
	var p := 0.45 if v == 1 else 0.2
	if rng.randf() < p:
		var mx := x0 + rng.randi_range(1, maxi(1, w - 7))
		var n := rng.randi_range(3, 6)
		for k in n:
			var h := 2 if (k > 0 and k < n - 1) else 1
			for j in h:
				_px(img, mx + k, y0 + j, _c(MOUSSE, 1 + (1 if j == 1 else 0) + (1 if k % 2 == 0 else 0)))
		_px(img, mx + 1, y0 + 2, _c(MOUSSE, 1))
		_px(img, mx + n - 2, y0 + 2, _c(MOUSSE, 0))
	if v == 1 and rng.randf() < 0.25:
		var sx := x0 + rng.randi_range(2, w - 4)
		_rect(img, sx, y0 + 5, 3, 1, _c(SALPETRE, 1))
		_px(img, sx + 1, y0 + 4, _c(SALPETRE, 2))

# ------------------------------------------------------------------ dalles du sol
## Dalles de 1 m (16 texels), joint sombre, biseau, usure au centre, poussière dans les joints.
static func dalle_image(v: int) -> Image:
	var rng := _rng(8200 + v)
	var L := 16 * K                       # une dalle = 1 m
	var N := 8                            # 8x8 dalles = 8 m
	var S := L * N
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var R := PIERRE
	for gy in N:
		for gx in N:
			var x0 := gx * L
			var y0 := gy * L
			var ton: int = [1, 2, 2, 2, 3][rng.randi_range(0, 4)]
			_rect(img, x0, y0, L, L, _c(R, ton))
			for i in L:
				_px(img, x0 + i, y0, _c(R, ton + 1))        # biseau haut
				_px(img, x0, y0 + i, _c(R, ton + 1))        # biseau gauche
				_px(img, x0 + i, y0 + L - 1, _c(R, 0))      # joint bas
				_px(img, x0 + L - 1, y0 + i, _c(R, 0))      # joint droit
				_px(img, x0 + i, y0 + L - 2, _c(R, ton - 1))
				_px(img, x0 + L - 2, y0 + i, _c(R, ton - 1))
			_px(img, x0, y0, _c(R, ton))
			_px(img, x0 + L - 1, y0, _c(R, 0))
			_px(img, x0, y0 + L - 1, _c(R, 0))
			# usure : creux plus clair au centre (passage), en amas
			if rng.randf() < 0.6:
				var wx := x0 + rng.randi_range(L / 4, L / 2)
				var wy := y0 + rng.randi_range(L / 4, L / 2)
				_rect(img, wx, wy, rng.randi_range(3, 5) * K, rng.randi_range(2, 4) * K, _c(R, ton + 1))
				_rect(img, wx + K, wy + K, 2 * K, K, _c(R, ton))
			# éclats sombres
			for k in rng.randi_range(1, 3) * K:
				_rect(img, x0 + rng.randi_range(2, L - 5), y0 + rng.randi_range(2, L - 5), rng.randi_range(1, 3) * K, 1, _c(R, ton - 1))
			# fissure
			if rng.randf() < 0.22:
				var fx := x0 + rng.randi_range(3, L - 4)
				var fy := y0 + 2
				for k in rng.randi_range(6, 11) * K:
					_px(img, fx, fy, _c(R, 0))
					fy += 1
					if rng.randf() < 0.5:
						fx += rng.randi_range(-1, 1)
						_px(img, fx, fy - 1, _c(R, 0))
	# poussière ou salpêtre dans les joints (petits amas clairs, teinte plus chaude)
	var poussiere := ["#6c6d78", "#858691"] if v == 0 else ["#6a8789", "#8cadab"]
	for k in 14 * N:
		var jx := rng.randi_range(0, N - 1) * L + L - 1
		var jy := rng.randi_range(0, S - 1)
		_rect(img, jx - 1, jy, 3, 1, Color(poussiere[0]))
		if rng.randf() < 0.6:
			_px(img, jx, jy - 1, Color(poussiere[1]))
		var jy2 := rng.randi_range(0, N - 1) * L + L - 1
		var jx2 := rng.randi_range(0, S - 1)
		_rect(img, jx2, jy2 - 1, 1, 3, Color(poussiere[0]))
		_px(img, jx2 - 1, jy2, Color(poussiere[1]))
	return img

# ------------------------------------------------------------------ voûte en petites briques
static func voute_image() -> Image:
	var rng := _rng(8300)
	var S := 64 * K
	var RH := 4 * K
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var R := PIERRE_SOMBRE
	img.fill(_c(R, 1))
	for rang in 16:
		var y0 := rang * RH
		var x := rng.randi_range(0, S - 1)
		for w: int in _largeurs(rng, S, [8 * K, 8 * K, 12 * K, 12 * K, 16 * K]):
			var ton: int = [1, 1, 2, 2, 3][rng.randi_range(0, 4)]
			_rect(img, x, y0, w, RH, _c(R, ton))
			for i in w:
				_px(img, x + i, y0, _c(R, ton + 1))
				_px(img, x + i, y0 + RH - 1, _c(R, 0))
			for j in RH - 1:
				_px(img, x + w - 1, y0 + j, _c(R, 0))
			if rng.randf() < 0.3:
				_rect(img, x + rng.randi_range(2, maxi(2, w - 4)), y0 + 1 + (K - 1), 2, 1, _c(R, ton - 1))
			x += w
	# suie : plaques sombres en amas
	for k in 9 * K:
		var sx := rng.randi_range(0, S - 1)
		var sy := rng.randi_range(0, S - 1)
		for j in rng.randi_range(2, 4):
			_rect(img, sx + rng.randi_range(-1, 1), sy + j, rng.randi_range(3, 7), 1, _c(R, 0 if j == 1 else 1))
	return img

# ------------------------------------------------------------------ planches de bois (32 texels/m)
static func bois_image() -> Image:
	var rng := _rng(8400)
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for rang in 8:
		var y0 := rang * 8
		var ton: int = [1, 2, 2, 3][rng.randi_range(0, 3)]
		_rect(img, 0, y0, S, 8, _c(BOIS, ton))
		for x in S:
			_px(img, x, y0, _c(BOIS, ton + 1))              # arête haute
			_px(img, x, y0 + 7, _c(BOIS, 0))                # joint bas
			_px(img, x, y0 + 6, _c(BOIS, ton - 1))
		# fil du bois : traits horizontaux groupés
		for k in rng.randi_range(5, 8):
			var gx := rng.randi_range(0, 63)
			var gy := y0 + rng.randi_range(1, 5)
			var gl := rng.randi_range(6, 20)
			var t: int = ton + (1 if rng.randf() < 0.45 else -1)
			for i in gl:
				_px(img, gx + i, gy, _c(BOIS, t))
		# nœud : petit anneau
		if rng.randf() < 0.45:
			var nx := rng.randi_range(4, 59)
			var ny := y0 + 3
			_rect(img, nx - 1, ny - 1, 4, 3, _c(BOIS, ton - 1))
			_rect(img, nx, ny, 2, 1, _c(BOIS, 0))
			_px(img, nx - 1, ny + 1, _c(BOIS, ton + 1))
		# aboutage vertical (planches mises bout à bout) et clou
		var jx := rng.randi_range(0, 63)
		for j in 7:
			_px(img, jx, y0 + j, _c(BOIS, 0))
		_px(img, jx + 2, y0 + 3, _c(FER, 3))
		_px(img, jx + 2, y0 + 4, _c(FER, 1))
	return img

# ------------------------------------------------------------------ fer riveté, rouille (32 texels/m)
static func fer_image() -> Image:
	var rng := _rng(8500)
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(_c(FER, 1))
	for bande in 2:
		var y0 := bande * 16
		_rect(img, 0, y0, S, 14, _c(FER, 1))
		for x in S:
			_px(img, x, y0, _c(FER, 3))                     # arête claire
			_px(img, x, y0 + 1, _c(FER, 2))
			_px(img, x, y0 + 13, _c(FER, 0))                # ombre
			_px(img, x, y0 + 14, _c(FER, 0))
		for rx in [4, 12, 20, 28]:                          # rivets : tête claire + ombre
			_rect(img, rx - 1, y0 + 5, 3, 3, _c(FER, 2))
			_px(img, rx - 1, y0 + 5, _c(FER, 3))
			_px(img, rx + 1, y0 + 7, _c(FER, 0))
		for k in 4:                                         # rayures
			var gx := rng.randi_range(0, 31)
			_rect(img, gx, y0 + rng.randi_range(2, 11), rng.randi_range(2, 5), 1, _c(FER, 2 if k % 2 == 0 else 0))
	for k in 5:                                             # rouille en amas
		var rx := rng.randi_range(0, 31)
		var ry := rng.randi_range(0, 31)
		for j in rng.randi_range(2, 3):
			_rect(img, rx + rng.randi_range(0, 1), ry + j, rng.randi_range(2, 5), 1, _c(ROUILLE, rng.randi_range(0, 2)))
	return img

## Lame rouillée (armes au sol) : métal éteint, taches de rouille, fil clair d'un seul côté.
static func lame_image() -> Image:
	var rng := _rng(8550)
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(_c(FER, 1))
	for x in S:
		_px(img, x, 0, _c(FER, 3))
		_px(img, x, 1, _c(FER, 2))
		_px(img, x, 15, _c(FER, 0))
		_px(img, x, 16, _c(FER, 0))
		_px(img, x, 17, _c(FER, 2))
		_px(img, x, 18, _c(FER, 1))
	for k in 12:
		var rx := rng.randi_range(0, 31)
		var ry := rng.randi_range(0, 31)
		_rect(img, rx, ry, rng.randi_range(2, 6), rng.randi_range(1, 3), _c(ROUILLE, rng.randi_range(0, 2)))
	return img

# ------------------------------------------------------------------ gravure runique (sarcophages)
static func gravure_image() -> Image:
	var rng := _rng(8600)
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var R := PIERRE
	img.fill(_c(R, 2))
	# fond en grandes dalles lisses
	for i in S:
		_px(img, i, 0, _c(R, 3))
		_px(img, 0, i, _c(R, 3))
		_px(img, i, 63, _c(R, 0))
		_px(img, 63, i, _c(R, 0))
	for k in 30:
		_rect(img, rng.randi_range(2, 60), rng.randi_range(2, 60), rng.randi_range(1, 3), 1, _c(R, 1 if k % 3 else 3))
	# cadre gravé : trait sombre + lèvre claire en dessous/à droite
	for i in range(6, 58):
		_px(img, i, 6, _c(R, 0))
		_px(img, i, 7, _c(R, 4))
		_px(img, i, 56, _c(R, 0))
		_px(img, i, 57, _c(R, 4))
		_px(img, 6, i, _c(R, 0))
		_px(img, 7, i, _c(R, 4))
		_px(img, 56, i, _c(R, 0))
		_px(img, 57, i, _c(R, 4))
	# frise de runes : traits verticaux avec branches (futhark simplifié)
	for rang in [12, 46]:
		var x := 11
		while x < 52:
			for j in 8:
				_px(img, x, rang + j, _c(R, 0))
				_px(img, x + 1, rang + j, _c(R, 4) if j % 3 == 0 else _c(R, 3))
			var forme := rng.randi_range(0, 3)
			for j in 3:
				if forme == 0 or forme == 2:
					_px(img, x + 1 + j, rang + 1 + j, _c(R, 0))
				if forme == 1 or forme == 2:
					_px(img, x + 1 + j, rang + 5 - j, _c(R, 0))
				if forme == 3:
					_px(img, x - 1 - j, rang + 2 + j, _c(R, 0))
			x += 6
	# serpent / entrelacs : sinusoïde de 2 px au centre, ombre sombre + reflet clair
	for x in range(10, 54):
		var y := 32 + int(round(sin(float(x) * 0.42) * 5.0))
		_px(img, x, y, _c(R, 0))
		_px(img, x, y + 1, _c(R, 0))
		_px(img, x, y - 1, _c(R, 4))
		_px(img, x, y + 2, _c(R, 1))
	_rect(img, 52, 29, 3, 3, _c(R, 0))                      # tête
	_px(img, 53, 30, _c(R, 4))
	return img

# ------------------------------------------------------------------ poterie, os, parchemin
static func argile_image() -> Image:
	var rng := _rng(8700)
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(_c(ARGILE, 2))
	for bande in 4:
		var y0 := bande * 8
		for x in S:
			_px(img, x, y0, _c(ARGILE, 3))
			_px(img, x, y0 + 7, _c(ARGILE, 0))
			_px(img, x, y0 + 6, _c(ARGILE, 1))
		if bande % 2 == 0:                                  # frise en zigzag
			for x in S:
				_px(img, x, y0 + 3 + (x % 4 if x % 8 < 4 else 3 - x % 4) / 2, _c(ARGILE, 0))
	for k in 8:
		_rect(img, rng.randi_range(0, 31), rng.randi_range(0, 31), rng.randi_range(1, 3), rng.randi_range(1, 2), _c(ARGILE, rng.randi_range(1, 3)))
	return img

static func os_image() -> Image:
	var rng := _rng(8800)
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(_c(OSSE, 2))
	for k in 26:
		var x := rng.randi_range(0, 31)
		var y := rng.randi_range(0, 31)
		var t: int = [0, 1, 1, 3, 3, 4][rng.randi_range(0, 5)]
		_rect(img, x, y, rng.randi_range(1, 3), rng.randi_range(1, 2), _c(OSSE, t))
	for k in 5:                                             # fêlures
		var x := rng.randi_range(0, 31)
		var y := rng.randi_range(0, 28)
		for j in 4:
			_px(img, x + (j / 2), y + j, _c(OSSE, 0))
	return img

static func parchemin_image() -> Image:
	var rng := _rng(8900)
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(_c(PARCHEMIN, 2))
	for y in range(3, 30, 4):                               # lignes d'écriture : groupes de traits
		var x := 2
		while x < 28:
			var l := rng.randi_range(2, 5)
			_rect(img, x, y, l, 1, _c(PARCHEMIN, 0))
			x += l + 1
	for i in S:
		_px(img, i, 0, _c(PARCHEMIN, 1))
		_px(img, i, 31, _c(PARCHEMIN, 1))
	for k in 4:
		_rect(img, rng.randi_range(0, 30), rng.randi_range(0, 30), 2, 2, _c(PARCHEMIN, 1))
	return img

# ------------------------------------------------------------------ toile d'araignée (alpha, un coin)
## 32x32 : rayons partant du coin (0,0), arcs en fils pendants ; fond transparent (découpe à 0,5).
static func toile_image() -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	for r in 6:                                             # rayons
		var a := deg_to_rad(8.0 + r * 15.0)
		for k in 60:
			var d := k * 0.5
			var x := int(round(cos(a) * d))
			var y := int(round(sin(a) * d))
			if x < S and y < S:
				_px(img, x, y, _c(TOILE, 1 if (x + y) % 3 else 0))
	for d in [9.0, 15.0, 21.0, 27.0]:                       # fils en arcs qui s'affaissent
		var prev := Vector2i(-1, -1)
		for k in 61:
			var a := deg_to_rad(6.0 + k * 1.3)
			var rr: float = d - sin(a * 2.0 * 2.0) * 1.2 - 1.5 * sin(PI * float(k) / 60.0)
			var x := int(round(cos(a) * rr))
			var y := int(round(sin(a) * rr))
			if x >= 0 and y >= 0 and x < S and y < S and Vector2i(x, y) != prev:
				_px(img, x, y, _c(TOILE, 0))
				prev = Vector2i(x, y)
	return img

# ------------------------------------------------------------------ flammes, halo, rai de lumière
## Atlas de 4 images de flamme 16x24 (côte à côte, 64x24) : bords rouges, corps orange, cœur jaune-blanc.
static func flamme_atlas_image() -> Image:
	var img := Image.create(64, 24, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	var decal := [0.0, 1.0, 0.0, -1.0]
	for f in 4:
		var ox := f * 16
		for y in 24:
			var t := float(y) / 23.0                        # 0 = haut, 1 = pied
			var demi := 5.4 * pow(sin(minf(t * 1.25, 1.0) * PI * 0.5 + 0.0), 1.2)
			if t > 0.86:
				demi *= 1.0 - (t - 0.86) * 4.0              # le pied se resserre sur le bois
			var sway: float = decal[f] * (1.0 - t) * 1.6 + sin(t * 5.0 + f * 1.7) * 0.9 * (1.0 - t)
			if y < (2 if f % 2 == 0 else 3):                # la pointe danse
				continue
			for x in 16:
				var dx := absf(float(x) - 7.5 - sway)
				if dx > demi:
					continue
				var r := dx / maxf(demi, 0.5)
				var ton := 1
				if r < 0.28 and t > 0.35:
					ton = 4 if t > 0.55 else 3
				elif r < 0.55 and t > 0.2:
					ton = 3 if t > 0.5 else 2
				elif r < 0.8:
					ton = 2
				_px(img, ox + x, y, _c(FLAMME, ton))
		# langue qui se détache (haut)
		if f % 2 == 1:
			_px(img, ox + 7 + int(decal[f]), 2, _c(FLAMME, 2))
			_px(img, ox + 7 + int(decal[f]), 3, _c(FLAMME, 3))
	return img

## Halo chaud NET : quatre anneaux d'alpha posterisés (pas de dégradé), à poser en additif sur le mur.
static func halo_image() -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var a := 0.0
			var c := Color("#ff7a1c")
			if d < 0.2:
				a = 0.55
				c = Color("#ffc46a")
			elif d < 0.42:
				a = 0.34
				c = Color("#ff9a2e")
			elif d < 0.7:
				a = 0.2
				c = Color("#e8601a")
			elif d < 0.98:
				a = 0.09
				c = Color("#b8420f")
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return img

static func rai_image() -> Image:
	var img := Image.create(16, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 16:
			var dx := absf(float(x) - 7.5) / 8.0
			var a := 0.0
			if dx < 0.35:
				a = 0.10
			elif dx < 0.7:
				a = 0.055
			elif dx < 0.95:
				a = 0.025
			a *= 0.35 + 0.65 * (1.0 - float(y) / 63.0)
			a = floorf(a * 60.0) / 60.0                    # paliers : pas de dégradé lisse
			img.set_pixel(x, y, Color(0.62, 0.78, 1.0, a))
	return img

static func poussiere_image() -> Image:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.88, 1.0, 1.0))
	return img

# ------------------------------------------------------------------ accès (le cache vit dans CrypteDecor)
static func tex(nom: String) -> ImageTexture:
	return _mips(image(nom))

static func image(nom: String) -> Image:
	match nom:
		"mur0": return mur_image(0)
		"mur1": return mur_image(1)
		"mur2": return mur_image(2)
		"dalle0": return dalle_image(0)
		"dalle1": return dalle_image(1)
		"voute": return voute_image()
		"bois": return bois_image()
		"fer": return fer_image()
		"lame": return lame_image()
		"gravure": return gravure_image()
		"argile": return argile_image()
		"os": return os_image()
		"parchemin": return parchemin_image()
		"toile": return toile_image()
		"flamme": return flamme_atlas_image()
		"halo": return halo_image()
		"rai": return rai_image()
	return mur_image(0)
