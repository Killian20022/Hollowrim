class_name CrypteTextures
## Textures de la crypte (lot 7a, 2e passe « réalisme 32 bits »). Chaque texture naît d'une CARTE DE HAUTEUR (blocs taillés,
## joints creux, biseaux arrondis, ondulation de la pierre, éclats, fissures) dont on tire : (1) l'albédo, par éclairage
## peint (lumière haut-gauche), occlusion ambiante dans les joints, ombres portées d'un bloc sur son voisin, dégradé
## interne de chaque pierre, teinte propre à chaque pierre (rampe froide <-> rampe chaude), coulures, salpêtre, mousse ;
## (2) une carte de pentes (`*_nm`) que le shader lit pour que la torche sculpte le relief en lumière rasante.
## Densité : 32 texels/m (K = 2) pour la pierre, le bois, le fer et les petits objets (tuiles de 1 à 8 m).
## Les rampes comptent 8 à 10 tons et sont INTERPOLÉES puis quantifiées à ~26 niveaux par quantification au bruit
## (grain « photo réduite et retouchée » au lieu d'aplats). Mipmaps « nearest » maison (vote de couleur 2x2,
## égalité départagée vers la valeur moyenne : plus d'assombrissement au loin).
## Aucune fonction partagée de palette.gd n'est touchée.

const CLEAR := Color(0, 0, 0, 0)
const DOSSIER := "res://assets/crypte"   # textures précalculées par outils/generer_crypte.gd
const VERSION := 3                       # à incrémenter à chaque changement de dessin : les .res périmés sont ignorés
const K := 2   # facteur de densité de la pierre : 1 = 16 texels/m, 2 = 32 texels/m

# rampes (indice 0 = creux/joint, dernier = lumière) : désaturées, froides dans l'ombre, un peu plus chaudes en lumière
const PIERRE_FROID := ["#0f1219", "#171b25", "#212733", "#2d3441", "#3b4352", "#4b5363", "#5e6575", "#747a89", "#8c909d", "#a6a9b3"]
const PIERRE_CHAUD := ["#15131a", "#1e1b20", "#2b2627", "#3a322f", "#4b413a", "#5e5247", "#75685a", "#8d806e", "#a59885", "#beb19d"]
const PIERRE_SOMBRE_F := ["#0b0d13", "#12151e", "#1b2029", "#262c37", "#323946", "#414857", "#535a69", "#676d7c", "#7d828f", "#979aa5"]
const MOUSSE := ["#0e1810", "#16261a", "#203820", "#2d4e2e", "#3f6a39", "#5b8a49"]
const SALPETRE := ["#4a5d5f", "#647e80", "#82a09f", "#a0bdb8", "#bdd5cd", "#d9e8e0"]
const BOIS := ["#130c07", "#1c120a", "#291a0f", "#372314", "#473019", "#593d22", "#6c4c2b", "#815c36", "#966e42", "#ab8250"]
const FER := ["#13161c", "#1c2029", "#292f3b", "#394150", "#4c5568", "#66718a", "#8591a8", "#a6b1c4"]
const ROUILLE := ["#2b160d", "#46230f", "#6a3517", "#8f4a21", "#b06530"]
const OSSE := ["#3f3b31", "#625c4c", "#867e68", "#a89f84", "#c8bfa2", "#e4dcc0"]
const ARGILE := ["#1d110b", "#2f1b11", "#432819", "#5a3a24", "#734c30", "#8c613f"]
const PARCHEMIN := ["#3b301d", "#5c4e30", "#80704a", "#a39266", "#c2b284", "#d8cb9e"]
const TOILE := ["#8d9db0", "#b5c4d3"]
const FLAMME := ["#4a1008", "#a8330c", "#f0801a", "#ffcb52", "#fff3c4"]
const NIVEAUX := 18.0

static func _c(rampe: Array, i: int) -> Color:
	return Color(rampe[clampi(i, 0, rampe.size() - 1)])

static func _cols(r: Array) -> Array:
	var o := []
	for h in r:
		o.append(Color(h))
	return o

## Interpolation le long d'une rampe (liste de Color), l dans [0, 1].
static func _rp(cols: Array, l: float) -> Color:
	var f := clampf(l, 0.0, 1.0) * (cols.size() - 1)
	var i := mini(int(f), cols.size() - 2)
	return (cols[i] as Color).lerp(cols[i + 1], f - i)

## Quantification au bruit (jamais de motif ordonné) : le tirage ne bascule que les valeurs proches d'un seuil.
static func _q(l: float, x: int, y: int) -> float:
	var h := float(((x * 73856093) ^ (y * 19349663)) & 1023) / 1023.0
	return floorf(l * NIVEAUX + 0.5 + (h - 0.5) * 0.55) / NIVEAUX

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

static func _ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## Bruit de valeurs PÉRIODIQUE (tuile S x S) : treillis cx x cy de tirages, tuilé 3x3, agrandi en bicubique (natif, rapide),
## recadré sur la tuile centrale. Valeurs ~[0, 1] (le bicubique déborde un peu).
static func _nmap(S: int, cx: int, cy: int, graine: int, net := false) -> PackedFloat32Array:
	var rng := _rng(graine)
	var v := PackedFloat32Array()
	for i in cx * cy:
		v.append(rng.randf())
	var g := Image.create(cx * 3, cy * 3, false, Image.FORMAT_RF)
	for y in cy * 3:
		for x in cx * 3:
			g.set_pixel(x, y, Color(v[(y % cy) * cx + (x % cx)], 0, 0))
	g.resize(S * 3, S * 3, Image.INTERPOLATE_NEAREST if net else Image.INTERPOLATE_CUBIC)
	return g.get_region(Rect2i(S, S, S, S)).get_data().to_float32_array()

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

## Chaîne de mipmaps « pixel art » : chaque niveau garde la couleur majoritaire d'un bloc 2x2 ; sans majorité, celle dont la
## luminance est la plus proche de la moyenne ; reste opaque si au moins `seuil` pixels sur 4 le sont.
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
				var moy := 0.0
				for k in 4:
					if c[k].a > 0.5:
						opaques += 1
						moy += c[k].get_luminance()
				if opaques < seuil:
					nxt.set_pixel(x, y, CLEAR)
					continue
				moy /= opaques
				var best := -1
				var bn := 0
				for k in 4:
					if c[k].a <= 0.5:
						continue
					var n := 0
					for j in 4:
						if c[j].a > 0.5 and c[j] == c[k]:
							n += 1
					if best < 0 or n > bn or (n == bn and absf(c[k].get_luminance() - moy) < absf(c[best].get_luminance() - moy)):
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

## Carte de pentes (R = -dh/dx, G = -dh/dy, 0,5 = plat) tirée d'une carte de hauteur périodique ; mipmaps linéaires.
static func _pentes(H: PackedFloat32Array, S: int, gain: float) -> Image:
	var d := PackedByteArray()
	d.resize(S * S * 4)
	for y in S:
		var yu := posmod(y - 1, S) * S
		var yd := posmod(y + 1, S) * S
		var y0 := y * S
		for x in S:
			var xl := posmod(x - 1, S)
			var xr := posmod(x + 1, S)
			var gx := (H[y0 + xr] - H[y0 + xl]) * 0.5
			var gy := (H[yd + x] - H[yu + x]) * 0.5
			var o := (y0 + x) * 4
			d[o] = int(clampf(0.5 - gx * gain * 0.5, 0.0, 1.0) * 255.0)
			d[o + 1] = int(clampf(0.5 - gy * gain * 0.5, 0.0, 1.0) * 255.0)
			d[o + 2] = 255
			d[o + 3] = 255
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, d)
	img.generate_mipmaps()
	return img

static func _vers_image(S: int, cols: PackedColorArray) -> Image:
	var d := PackedByteArray()
	d.resize(S * S * 4)
	for i in S * S:
		var c := cols[i]
		d[i * 4] = int(c.r * 255.0 + 0.5)
		d[i * 4 + 1] = int(c.g * 255.0 + 0.5)
		d[i * 4 + 2] = int(c.b * 255.0 + 0.5)
		d[i * 4 + 3] = 255
	return Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, d)

# ------------------------------------------------------------------ pierre générique (murs, dalles, voûte)
## Assises de hauteurs `rangs` (somme = S), blocs de largeurs tirées dans `larg`. Options `o` :
## seed, v (0 sain, 1 mousse + salpêtre, 2 humide), joint, biseau, rug (rugosité), l_lo/l_hi (luminance des blocs), sombre,
## elev (écart de profondeur entre blocs), creux (usure en cuvette au centre : dalles), fissures (nombre).
## Retourne [albédo, pentes].
static func _pierre(S: int, rangs: Array, larg: Array, o: Dictionary) -> Array:
	var graine: int = o.get("seed", 1)
	var rng := _rng(graine)
	var v: int = o.get("v", 0)
	var J: float = o.get("joint", 1.6)
	var B: float = o.get("biseau", 4.0)
	var rug: float = o.get("rug", 0.5)
	var l_lo: float = o.get("l_lo", 0.36)
	var l_hi: float = o.get("l_hi", 0.58)
	var elev_max: float = o.get("elev", 0.6)
	var creux: float = o.get("creux", 0.0)
	var jl: float = o.get("joint_l", 0.06)
	var froid := _cols(PIERRE_SOMBRE_F if o.get("sombre", false) else PIERRE_FROID)
	var chaud := _cols(PIERRE_CHAUD)
	var mou := _cols(MOUSSE)
	var sal := _cols(SALPETRE)
	var n_fin := _nmap(S, S / 3, S / 3, graine + 1, true)       # grain en amas de ~3 texels, sans lissage
	var n_gr2 := _nmap(S, S / 6, S / 6, graine + 8, true)
	var n_gr := _nmap(S, S / 12, S / 12, graine + 2)
	var n_wob := _nmap(S, S / 8, S / 8, graine + 3)
	var n_big := _nmap(S, 4, 4, graine + 4)
	var n_stk := _nmap(S, S / 3, 3, graine + 5)
	var n_sal := _nmap(S, S / 8, S / 8, graine + 6) if v >= 1 else n_big
	var n_mou := _nmap(S, 6, 6, graine + 7) if v == 1 else n_big
	var H := PackedFloat32Array()
	H.resize(S * S)
	var L := PackedFloat32Array()
	L.resize(S * S)
	var T := PackedFloat32Array()
	T.resize(S * S)
	var D := PackedFloat32Array()
	D.resize(S * S)
	var y0 := 0
	for rh: int in rangs:
		var x := rng.randi_range(0, S - 1)
		for w: int in _largeurs(rng, S, larg):
			var l0 := lerpf(l_lo, l_hi, rng.randf())
			if rng.randf() < 0.12:
				l0 -= 0.09
			var t := 0.45 * pow(rng.randf(), 2.0) + (0.3 if rng.randf() < 0.14 else 0.0)
			var elev := rng.randf() * elev_max
			var rugb := rug * (0.55 + rng.randf() * 0.9)
			var gxb := (rng.randf() - 0.5) * 0.09
			var gyb := (rng.randf() - 0.5) * 0.09
			var grad := 0.06 + rng.randf() * 0.1          # haut éclairé, bas sombre
			var coin := rng.randi_range(0, 3) if rng.randf() < 0.45 else -1
			var rc := rng.randf_range(3.0, 7.0)
			for ly in rh:
				for lx in w:
					var i := (y0 + ly) * S + posmod(x + lx, S)
					var d := float(mini(mini(lx, w - 1 - lx), mini(ly, rh - 1 - ly)) + int(floorf((n_wob[i] - 0.5) * 1.6 + 0.5)))
					var hh := -0.9
					var ll := jl
					if d >= J:
						var e := clampf((d - J + 1.0) / B, 0.0, 1.0)
						var prof := floorf(e * 3.0 + 0.5) / 3.0           # biseau en 3 marches : arête nette
						hh = prof * 0.95 + elev + (floorf(n_fin[i] * 4.0) / 4.0 - 0.4) * rugb * 1.1 + (n_gr[i] - 0.5) * 0.55 * rugb + gxb * lx + gyb * ly
						ll = l0 + grad * (0.5 - float(ly) / rh) * 1.6 + (floorf(n_fin[i] * 4.0) / 4.0 - 0.4) * 0.5 * rugb + (floorf(n_gr2[i] * 3.0) / 3.0 - 0.33) * 0.22 + (n_gr[i] - 0.5) * 0.12 - 0.1 * _ss(0.8, 0.95, n_fin[(i + S * 3 + 7) % (S * S)]) * rugb
						if creux > 0.0:
							var cm := minf(float(w), float(rh)) * 0.5
							hh -= creux * (1.0 - clampf(d / cm, 0.0, 1.0)) * (0.6 + n_gr[i])
							ll += creux * 0.05 * (1.0 - clampf(d / cm, 0.0, 1.0))
						if coin >= 0:
							var cx := float(lx if (coin & 1) == 0 else w - 1 - lx)
							var cy := float(ly if (coin & 2) == 0 else rh - 1 - ly)
							if cx + cy < rc + (n_fin[i] - 0.5) * 3.0:
								hh -= 0.75
								ll -= 0.09
					L[i] = ll
					H[i] = hh
					T[i] = t
					D[i] = d
			x += w
		y0 += rh
	# fissures : marche aléatoire qui creuse la pierre
	for k in o.get("fissures", S / 24):
		var fx := rng.randi_range(0, S - 1)
		var fy := rng.randi_range(0, S - 1)
		for s in rng.randi_range(8, 22):
			var i := posmod(fy, S) * S + posmod(fx, S)
			if D[i] >= J:
				H[i] = -0.8
				L[i] = 0.08
				D[i] = J
			fy += 1
			if rng.randf() < 0.55:
				fx += rng.randi_range(-1, 1)
	# passe 2 : éclairage peint, occlusion, ombres portées, salissures, teinte, tramage
	var cols := PackedColorArray()
	cols.resize(S * S)
	var coulure := 0.18 if v == 0 else 0.3
	for y in S:
		for x in S:
			var i := y * S + x
			var il := y * S + posmod(x - 1, S)
			var ir := y * S + posmod(x + 1, S)
			var iu := posmod(y - 1, S) * S + x
			var id := posmod(y + 1, S) * S + x
			var gx := (H[ir] - H[il]) * 0.5
			var gy := (H[id] - H[iu]) * 0.5
			var shade := clampf((gx + gy) * 0.55, -0.5, 0.5) * 0.5
			var ic := posmod(y - 2, S) * S + posmod(x - 2, S)
			var proj := clampf(H[ic] - H[i] - 0.25, 0.0, 1.0) * 0.2
			var d: float = D[i]
			var a := _ss(J, J + 2.0, d)
			var ao := 0.76 + 0.24 * a
			var lip := 0.0
			if d >= J and d < J + 1.0:                    # lèvre claire nette le long des joints (côtés éclairés)
				lip = 0.12 if (gx + gy) > 0.05 else 0.0
			var l: float = (L[i] + shade) * ao - proj + lip
			var ln := n_big[i]
			l -= 0.1 * _ss(0.55, 0.8, ln) * (1.0 + v * 0.6)
			var stk := _ss(0.6, 0.8, n_stk[i]) * (0.45 + 0.55 * (1.0 - a))
			l -= coulure * stk * 0.6
			var t: float = T[i]
			var lq := _q(clampf(l, 0.0, 1.0), x, y)
			var c: Color = (_rp(froid, lq) as Color).lerp(_rp(chaud, lq), t)
			if v >= 1:
				var ms := _ss(0.72, 0.88, n_sal[i]) * (0.3 + 0.7 * (1.0 - a)) * (0.5 + 0.5 * (0.5 if v == 1 else 1.0))
				ms = maxf(ms, stk * 0.45 * (1.0 if v == 2 else 0.6) * _ss(0.78, 0.9, n_sal[(i + S * 5) % (S * S)]))
				c = c.lerp(_rp(sal, 0.25 + lq * 0.65), clampf(ms, 0.0, 1.0) * 0.85)
				if v == 1:
					var mm := _ss(0.68, 0.84, n_mou[i]) * (1.0 - a * 0.7)
					c = c.lerp(_rp(mou, 0.15 + lq * 0.9), clampf(mm, 0.0, 1.0) * 0.9)
			cols[i] = c
	return [_vers_image(S, cols), _pentes(H, S, 0.9)]

static func mur_paire(v: int) -> Array:
	var rangs := []
	for r in 8:
		rangs.append(8 * K)
	return _pierre(64 * K, rangs, [20, 24, 28, 32, 40, 48], {"seed": 8100 + v * 17, "v": v, "sombre": v == 2, "joint": 1.0, "biseau": 2.4,
		"rug": 0.6, "l_lo": 0.5 if v < 2 else 0.42, "l_hi": 0.8 if v < 2 else 0.68, "elev": 0.7})

static func dalle_paire(v: int) -> Array:
	var rng := _rng(8200 + v)
	var S := 64 * K                       # tuile de 4 m (32 texels/m)
	var rangs: Array = _largeurs(rng, S, [24, 28, 32, 32, 40])
	return _pierre(S, rangs, [24, 32, 40, 48], {"seed": 8210 + v * 31, "v": v, "joint": 1.1, "biseau": 2.6, "rug": 0.5,
		"l_lo": 0.52, "l_hi": 0.8, "elev": 1.0, "creux": 0.55, "joint_l": 0.12, "fissures": 4})

static func voute_paire() -> Array:
	var rangs := []
	for r in 16:
		rangs.append(4 * K)
	return _pierre(64 * K, rangs, [10, 12, 16, 20, 24], {"seed": 8300, "sombre": true, "joint": 0.9, "biseau": 2.0, "rug": 0.5,
		"l_lo": 0.42, "l_hi": 0.68, "elev": 0.45, "fissures": 4})

static func mur_image(v: int) -> Image:
	return mur_paire(v)[0]

# ------------------------------------------------------------------ planches de bois (32 texels/m)
static func bois_paire() -> Array:
	var rng := _rng(8400)
	var S := 64
	var n_gr := _nmap(S, 2, S / 2, 8401)       # fil : traînées horizontales fines
	var n_gr2 := _nmap(S, 3, S / 4, 8402)
	var n_fin := _nmap(S, S / 4, S / 4, 8403)
	var n_big := _nmap(S, 3, 3, 8404)
	var H := PackedFloat32Array()
	H.resize(S * S)
	var L := PackedFloat32Array()
	L.resize(S * S)
	var T := PackedFloat32Array()
	T.resize(S * S)
	var cols := _cols(BOIS)
	for rang in 8:
		var y0 := rang * 8
		var l0 := lerpf(0.34, 0.58, rng.randf())
		var tt := rng.randf()
		var kx := rng.randi_range(4, 59)
		var avec_noeud := rng.randf() < 0.5
		var ax := rng.randi_range(0, 63)
		for ly in 8:
			for lx in S:
				var i := (y0 + ly) * S + lx
				var fil := n_gr[i] * 0.6 + n_gr2[i] * 0.4
				var hh := 0.45 * fil + (n_fin[i] - 0.5) * 0.2
				var ll := l0 + (fil - 0.5) * 0.4 + (n_fin[i] - 0.5) * 0.1 + (n_big[i] - 0.5) * 0.15 + (0.5 - ly / 7.0) * 0.12
				if ly == 0:
					hh += 0.5
					ll += 0.08
				elif ly == 7:
					hh = -0.9
					ll = 0.05
				elif ly == 6:
					ll -= 0.07
				if avec_noeud:
					var r := Vector2(lx - kx, (ly - 3.5) * 1.6).length()
					if r < 3.6:
						ll = l0 - 0.2 + 0.11 * sin(r * 2.3) + 0.04 * (1.0 - r / 3.6)
						hh += 0.25 * sin(r * 2.3) - 0.2
				if lx == ax and ly < 7:
					hh = -0.8
					ll = 0.07
				elif lx == ax + 1 and ly < 7:
					ll += 0.06
				L[i] = ll
				H[i] = hh
				T[i] = tt
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var gx := (H[y * S + posmod(x + 1, S)] - H[y * S + posmod(x - 1, S)]) * 0.5
			var gy := (H[posmod(y + 1, S) * S + x] - H[posmod(y - 1, S) * S + x]) * 0.5
			var l := L[i] + clampf((gx + gy) * 0.5, -0.4, 0.4) * 0.22
			var c := _rp(cols, _q(clampf(l, 0.0, 1.0), x, y))
			c = c.lerp(Color(c.g * 0.95, c.g * 1.0, c.b * 1.1), T[i] * 0.18)   # planche un peu plus grise
			out[i] = c
	# clous : tête claire et ombre
	for k in 14:
		var nx := rng.randi_range(0, S - 1)
		var ny := rng.randi_range(0, 7) * 8 + rng.randi_range(2, 4)
		out[ny * S + nx] = _rp(_cols(FER), 0.75)
		out[((ny + 1) % S) * S + nx] = _rp(_cols(FER), 0.15)
	return [_vers_image(S, out), _pentes(H, S, 0.9)]

static func bois_image() -> Image:
	return bois_paire()[0]

# ------------------------------------------------------------------ fer riveté, rouille (32 texels/m)
static func fer_paire() -> Array:
	var S := 32
	var n_fin := _nmap(S, S / 2, S / 2, 8501)
	var n_big := _nmap(S, 3, 3, 8502)
	var n_rou := _nmap(S, 5, 5, 8503)
	var rng := _rng(8500)
	var H := PackedFloat32Array()
	H.resize(S * S)
	for y in S:
		for x in S:
			var by := y % 16
			var h := 0.6 + (n_fin[y * S + x] - 0.5) * 0.25
			if by < 2:
				h = 0.9 * (by + 1) * 0.5
			elif by > 12:
				h = 0.2 * (15 - by)
			for rx in [4, 12, 20, 28]:
				var r := Vector2(x - rx, by - 6.5).length()
				if r < 2.4:
					h = 1.5 - r * 0.28 + 0.6
			H[y * S + x] = h
	var fer := _cols(FER)
	var rou := _cols(ROUILLE)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var gx := (H[y * S + posmod(x + 1, S)] - H[y * S + posmod(x - 1, S)]) * 0.5
			var gy := (H[posmod(y + 1, S) * S + x] - H[posmod(y - 1, S) * S + x]) * 0.5
			var l := 0.36 + (n_big[i] - 0.5) * 0.2 + (n_fin[i] - 0.5) * 0.1 + clampf((gx + gy) * 0.5, -0.5, 0.5) * 0.4
			var c := _rp(fer, _q(clampf(l, 0.0, 1.0), x, y))
			var rm := _ss(0.58, 0.78, n_rou[i])
			if rm > 0.0:
				c = c.lerp(_rp(rou, 0.2 + l * 0.9), rm * 0.85)
			out[i] = c
	for k in 5:                                             # rayures claires
		var gx := rng.randi_range(0, 28)
		var gy := rng.randi_range(2, 28)
		for j in rng.randi_range(2, 5):
			out[gy * S + gx + j] = out[gy * S + gx + j].lightened(0.25)
	return [_vers_image(S, out), _pentes(H, S, 0.8)]

static func fer_image() -> Image:
	return fer_paire()[0]

## Lame rouillée (armes au sol) : métal éteint, taches de rouille, fil clair d'un seul côté.
static func lame_image() -> Image:
	var S := 32
	var n_fin := _nmap(S, S / 2, S / 2, 8551)
	var n_rou := _nmap(S, 4, 4, 8552)
	var fer := _cols(FER)
	var rou := _cols(ROUILLE)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var by := y % 16
			var l := 0.42 + (n_fin[i] - 0.5) * 0.14
			if by < 2:
				l += 0.32 - by * 0.12                        # fil clair
			elif by > 12:
				l -= 0.22
			elif by > 8:
				l -= 0.05 * (by - 8)
			var c := _rp(fer, _q(clampf(l, 0.0, 1.0), x, y))
			var rm := _ss(0.5, 0.72, n_rou[i])
			c = c.lerp(_rp(rou, 0.15 + l), rm * 0.9)
			out[i] = c
	return _vers_image(S, out)

# ------------------------------------------------------------------ gravure runique (sarcophages) : creusée dans la pierre
static func gravure_paire() -> Array:
	var rng := _rng(8600)
	var S := 64
	var carve := PackedFloat32Array()
	carve.resize(S * S)
	var tr := func(x: int, y: int, f: float) -> void:
		var i := posmod(y, S) * S + posmod(x, S)
		carve[i] = maxf(carve[i], f)
	for i in range(6, 58):                                  # cadre gravé
		for k in 2:
			tr.call(i, 6 + k, 1.0)
			tr.call(i, 56 + k, 1.0)
			tr.call(6 + k, i, 1.0)
			tr.call(56 + k, i, 1.0)
	for rang in [12, 46]:                                   # frises de runes
		var x := 11
		while x < 52:
			for j in 8:
				tr.call(x, rang + j, 1.0)
			var forme := rng.randi_range(0, 3)
			for j in 3:
				if forme == 0 or forme == 2:
					tr.call(x + 1 + j, rang + 1 + j, 1.0)
				if forme == 1 or forme == 2:
					tr.call(x + 1 + j, rang + 5 - j, 1.0)
				if forme == 3:
					tr.call(x - 1 - j, rang + 2 + j, 1.0)
			x += 6
	for x in range(10, 54):                                 # serpent
		var y := 32 + int(round(sin(float(x) * 0.42) * 5.0))
		for k in 3:
			tr.call(x, y + k - 1, 1.0)
	for dy in 3:
		for dx in 4:
			tr.call(52 + dx, 29 + dy, 1.0)
	var n_fin := _nmap(S, S / 4, S / 4, 8601)
	var n_gr := _nmap(S, 4, 4, 8602)
	var H := PackedFloat32Array()
	H.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var cm := 0.0                                   # creux adouci : moyenne 3x3
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					cm += carve[posmod(y + dy, S) * S + posmod(x + dx, S)]
			cm = cm / 9.0 * 0.5 + carve[i] * 0.5
			var h := (n_fin[i] - 0.5) * 0.25 + (n_gr[i] - 0.5) * 0.4 - cm * 1.6
			var e := mini(mini(x, 63 - x), mini(y, 63 - y))
			if e < 2:
				h += 0.3 * (2 - e) - 0.4 * (1.0 if e == 0 and (x == 63 or y == 63) else 0.0)
			H[i] = h
	var fr := _cols(PIERRE_FROID)
	var ch := _cols(PIERRE_CHAUD)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var gx := (H[y * S + posmod(x + 1, S)] - H[y * S + posmod(x - 1, S)]) * 0.5
			var gy := (H[posmod(y + 1, S) * S + x] - H[posmod(y - 1, S) * S + x]) * 0.5
			var l := 0.5 + (n_fin[i] - 0.5) * 0.12 + (n_gr[i] - 0.5) * 0.14 + clampf((gx + gy) * 0.8, -0.5, 0.5) * 0.3 - carve[i] * 0.16
			var lq := _q(clampf(l, 0.0, 1.0), x, y)
			out[i] = (_rp(fr, lq) as Color).lerp(_rp(ch, lq), 0.25)
	return [_vers_image(S, out), _pentes(H, S, 1.0)]

static func gravure_image() -> Image:
	return gravure_paire()[0]

# ------------------------------------------------------------------ poterie, os, parchemin
static func argile_image() -> Image:
	var S := 32
	var n_fin := _nmap(S, S / 2, S / 2, 8701)
	var n_big := _nmap(S, 3, 3, 8702)
	var cols := _cols(ARGILE)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var by := y % 8
			var l := 0.5 + (n_big[i] - 0.5) * 0.3 + (n_fin[i] - 0.5) * 0.16
			l += 0.12 * (1.0 - by / 7.0) - 0.1 * (1.0 if by == 7 else 0.0)
			if (y / 8) % 2 == 0:                            # frise en zigzag peinte
				var zz := 3 + (x % 4 if x % 8 < 4 else 3 - x % 4) / 2
				if by == zz or by == zz + 1:
					l -= 0.28
			out[i] = _rp(cols, _q(clampf(l, 0.0, 1.0), x, y))
	return _vers_image(S, out)

static func os_image() -> Image:
	var S := 32
	var n_fin := _nmap(S, S / 2, S / 2, 8801)
	var n_big := _nmap(S, 4, 4, 8802)
	var rng := _rng(8800)
	var cols := _cols(OSSE)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var l := 0.58 + (n_big[i] - 0.5) * 0.4 + (n_fin[i] - 0.5) * 0.18
			out[i] = _rp(cols, _q(clampf(l, 0.0, 1.0), x, y)).lerp(Color(0.55, 0.42, 0.25), _ss(0.7, 0.95, n_big[(i * 7) % (S * S)]) * 0.4)
	for k in 5:                                             # fêlures
		var x := rng.randi_range(0, 31)
		var y := rng.randi_range(0, 28)
		for j in 4:
			out[(y + j) * S + posmod(x + (j / 2), S)] = _c(OSSE, 0)
	return _vers_image(S, out)

static func parchemin_image() -> Image:
	var S := 32
	var rng := _rng(8900)
	var n_fin := _nmap(S, S / 2, S / 2, 8901)
	var n_big := _nmap(S, 3, 3, 8902)
	var cols := _cols(PARCHEMIN)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var l := 0.55 + (n_big[i] - 0.5) * 0.4 + (n_fin[i] - 0.5) * 0.12
			if y < 2 or y > 29:
				l -= 0.14                                   # bords brunis
			out[i] = _rp(cols, _q(clampf(l, 0.0, 1.0), x, y))
	for y in range(3, 30, 4):                               # lignes d'écriture
		var x := 2
		while x < 28:
			var l := rng.randi_range(2, 5)
			for j in l:
				out[y * S + x + j] = _c(PARCHEMIN, 0).lerp(_c(PARCHEMIN, 1), 0.3)
			x += l + 1
	return _vers_image(S, out)

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

## Halo chaud en dégradé posterisé à 14 paliers (cœur clair, bord orangé) : lisible de loin, additif sur le mur.
static func halo_image() -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var chaud := [Color("#ffe2a8"), Color("#ffb458"), Color("#f0801f"), Color("#b8420f")]
	for y in S:
		for x in S:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var f := clampf(1.0 - d, 0.0, 1.0)
			var a := floorf(pow(f, 2.2) * 0.34 * 24.0 + 0.5) / 24.0
			var k := clampf(d * 1.15, 0.0, 1.0) * 3.0
			var i := mini(int(k), 2)
			var c: Color = (chaud[i] as Color).lerp(chaud[i + 1], k - i)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a if d < 1.0 else 0.0))
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

## Albédo + carte de pentes ([albédo, pentes] ; pentes = null si la matière n'a pas de relief).
static func paire(nom: String) -> Array:
	match nom:
		"mur0": return mur_paire(0)
		"mur1": return mur_paire(1)
		"mur2": return mur_paire(2)
		"dalle0": return dalle_paire(0)
		"dalle1": return dalle_paire(1)
		"voute": return voute_paire()
		"bois": return bois_paire()
		"fer": return fer_paire()
		"gravure": return gravure_paire()
	return [image(nom), null]

static func image(nom: String) -> Image:
	match nom:
		"mur0", "mur1", "mur2", "dalle0", "dalle1", "voute", "bois", "fer", "gravure":
			return paire(nom)[0]
		"lame": return lame_image()
		"argile": return argile_image()
		"os": return os_image()
		"parchemin": return parchemin_image()
		"toile": return toile_image()
		"flamme": return flamme_atlas_image()
		"halo": return halo_image()
		"rai": return rai_image()
	return mur_image(0)
