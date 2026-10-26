class_name CrypteTextures
## Textures de la crypte (lot 7a, 2e passe « réalisme 32 bits »). Chaque texture naît d'une CARTE DE HAUTEUR (blocs taillés,
## joints creux, biseaux arrondis, ondulation de la pierre, éclats, fissures) dont on tire : (1) l'albédo, par éclairage
## peint (lumière haut-gauche), occlusion ambiante dans les joints, ombres portées d'un bloc sur son voisin, dégradé
## interne de chaque pierre, teinte propre à chaque pierre (rampe froide <-> rampe chaude), coulures, salpêtre, mousse ;
## (2) une carte de pentes (`*_nm`) que le shader lit pour que la torche sculpte le relief en lumière rasante.
## Densité : 64 texels/m (E = 2) pour murs, dalles, voûte et ossuaire (vus de près : plus de gros pixels) ; 32 texels/m (K = 2) pour la pierre, le bois, le fer et les petits objets (tuiles de 1 à 8 m).
## Les rampes comptent 8 à 10 tons et sont INTERPOLÉES puis quantifiées à ~26 niveaux par quantification au bruit
## (grain « photo réduite et retouchée » au lieu d'aplats). Mipmaps « nearest » maison (vote de couleur 2x2,
## égalité départagée vers la valeur moyenne : plus d'assombrissement au loin).
## Aucune fonction partagée de palette.gd n'est touchée.

const CLEAR := Color(0, 0, 0, 0)
const DOSSIER := "res://assets/crypte"   # textures précalculées par outils/generer_crypte.gd
const VERSION := 14                      # à incrémenter à chaque changement de dessin : les .res périmés sont ignorés
const E := 2   # facteur de finesse de la pierre proche (murs, dalles, voûte, ossuaire) : 2 = 64 texels/m (tuiles de 256 px pour 4 m)
## Murs et ossuaire : 128 texels/m (tuile de 512 px), car le joueur les frôle (< 1 m) ; dalles et voûte restent à 64.
const EM := 4   # refonte matière, 2e passe : 128 texels/m pour murs et dalles (vus à 1-2 m) avec micro-détail (moucheture, arêtes ébréchées)
const F := 2   # bois, fer, gravure : 64 texels/m (tuiles de 128 / 64 / 128 px) ; dessin pensé en « unités » de 2 cm (ancienne grille)
const K := 2   # facteur de densité de la pierre : 1 = 16 texels/m, 2 = 32 texels/m

# rampes (indice 0 = creux/joint, dernier = lumière) : désaturées, froides dans l'ombre, un peu plus chaudes en lumière
# Refonte « crypte matière » (2026-10-21, références grottes_cryptes_2/3) : pierre BRUN-GRIS (et non plus gris-lilas), ombres
# presque noires, lumière chaude ; la rampe froide ne bleuit que très peu (l'ambiant bleu de la crypte s'en charge).
# 3e passe : la pierre tirait sur la brique rose-rouge (rampe froide mauve + chaude orangée sous la torche) → brun-gris sombre et froid,
# la seule chaleur vient des torches.
const PIERRE_FROID := ["#08090a", "#101214", "#181a1d", "#212326", "#2b2d30", "#36383a", "#434446", "#525352", "#636360", "#77756f"]
# rampe « Pierre de donjon » de DIRECTION_ARTISTIQUE §2 (brun-gris granuleux, mesurée sur les références), interpolée à 10 tons
const PIERRE_CHAUD := ["#0d0b09", "#161412", "#1f1c19", "#292521", "#332e29", "#3d3731", "#48413a", "#564e44", "#686052", "#7c7263"]
const PIERRE_SOMBRE_F := ["#060708", "#0d0e10", "#141618", "#1c1e21", "#25272a", "#2f3134", "#3b3d3f", "#494a4b", "#59595a", "#6b6a68"]
const MOUSSE := ["#0e1810", "#16261a", "#203820", "#2d4e2e", "#3f6a39", "#5b8a49"]
const SALPETRE := ["#4a5d5f", "#647e80", "#82a09f", "#a0bdb8", "#bdd5cd", "#d9e8e0"]
const BOIS := ["#130c07", "#1c120a", "#291a0f", "#372314", "#473019", "#593d22", "#6c4c2b", "#815c36", "#966e42", "#ab8250"]
const FER := ["#13161c", "#1c2029", "#292f3b", "#394150", "#4c5568", "#66718a", "#8591a8", "#a6b1c4"]
const ROUILLE := ["#2b160d", "#46230f", "#6a3517", "#8f4a21", "#b06530"]
const OSSE := ["#3f3b31", "#625c4c", "#867e68", "#a89f84", "#c8bfa2", "#e4dcc0"]
const ARGILE := ["#1d110b", "#2f1b11", "#432819", "#5a3a24", "#734c30", "#8c613f"]
const PARCHEMIN := ["#3b301d", "#5c4e30", "#80704a", "#a39266", "#c2b284", "#d8cb9e"]
const GIVRE := ["#29354a", "#2f4866", "#33577f", "#41709a", "#4f86ae", "#6ba3c1", "#86bfd3", "#b6dde8"]   # rampe « Glace / givre » commune (jamais de blanc)      # donjon : pierre prise dans le gel
const GLACE := ["#122233", "#1a3550", "#254d6c", "#33688a", "#4585a8", "#5ea2c2", "#7fbed6", "#a4d6e6", "#c8e9f2", "#e8f7fb"]      # donjon : glace épaisse sur la pierre
const OR := ["#3d2a08", "#6e4d10", "#a8791c", "#d9a830", "#f6d56a", "#fff1b0"]
const TOILE := ["#8d9db0", "#b5c4d3"]
## Tissus (L0 objets) : laine écrue non teinte (bible, rampe « Ecru », assombrie pour la crypte), lin clair, toile de sac brune.
const LAINE := ["#221e1b", "#36312c", "#4d463e", "#665d52", "#81776a", "#9d9283", "#b9ae9f", "#d2c7b0"]
const LIN := ["#2f2b25", "#4a453c", "#686152", "#877e6c", "#a69c87", "#c1b79f", "#dbd0b6", "#ebe2c9"]
const JUTE := ["#1a140d", "#2c2216", "#413322", "#57462f", "#6e5a3d", "#86704d", "#9e8860", "#b49d72"]
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
static func _q(l: float, x: int, y: int, tram := 0.55) -> float:
	var h := float(((x * 73856093) ^ (y * 19349663)) & 1023) / 1023.0
	return floorf(l * NIVEAUX + 0.5 + (h - 0.5) * tram) / NIVEAUX

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
	var ech: int = o.get("ech", 1)               # finesse : tailles en texels (biseau, ombres, fissures) multipliées par ech
	var lisse: bool = o.get("lisse", false)     # dalles lisibles de loin : pas de grain texel par texel, usure en macro-taches
	var grain: float = o.get("grain", 0.0)      # moucheture fine multi-tons (références : pierre granuleuse brun-gris)
	var ebr: float = o.get("ebr", 0.0)          # arêtes ébréchées : éclats de 2-3 texels mordant le biseau
	var pous: float = o.get("poussiere", 0.0)   # sols : voile de poussière gris clair en macro-taches, surtout au creux des dalles
	var gj: float = o.get("givre_joints", 0.0)  # sols : grains de givre dans les joints et au bord des dalles
	var froid := _cols(PIERRE_SOMBRE_F if o.get("sombre", false) else PIERRE_FROID)
	var chaud := _cols(PIERRE_CHAUD)
	var mou := _cols(MOUSSE)
	var sal := _cols(SALPETRE)
	var giv := _cols(GIVRE)
	var gla := _cols(GLACE)
	var n_fin := _nmap(S, S / 3, S / 3, graine + 1, true)       # grain en amas de ~3 texels, sans lissage
	var n_mou2 := _nmap(S, S / 2, S / 2, graine + 11, true)    # moucheture : amas de 2 texels (rognés au hasard : 2-3 px irréguliers)
	var n_gr2 := _nmap(S, S / 6, S / 6, graine + 8, true)
	var n_gr := _nmap(S, S / 12, S / 12, graine + 2)
	var n_wob := _nmap(S, S / 8, S / 8, graine + 3)
	var n_big := _nmap(S, 4, 4, graine + 4)
	var n_stk := _nmap(S, S / 3, 3, graine + 5)
	var n_mac := _nmap(S, 5, 5, graine + 9)       # macro-taches d'usure (une dizaine de texels et plus)
	var n_mac2 := _nmap(S, 9, 9, graine + 10)
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
	# blocs [x, y, largeur, hauteur] : assises (murs) ou découpe irrégulière en grandes dalles (sols, option « bsp » = [min, max])
	var blocs: Array = []
	if o.has("bsp"):
		var lim: Array = o["bsp"]
		_bsp(rng, 0, 0, S, S, int(lim[0]), int(lim[1]), blocs)
	else:
		var yb := 0
		for rh: int in rangs:
			var xb := rng.randi_range(0, S - 1)
			for w: int in _largeurs(rng, S, larg):
				blocs.append([xb, yb, w, rh])
				xb += w
			yb += rh
	for bl: Array in blocs:
		var x: int = bl[0]
		var y0: int = bl[1]
		var w: int = bl[2]
		var rh: int = bl[3]
		var l0 := lerpf(l_lo, l_hi, rng.randf())
		if rng.randf() < 0.12:
			l0 -= 0.09
		var t := 0.45 * pow(rng.randf(), 2.0) + (0.3 if rng.randf() < 0.14 else 0.0)
		var elev := rng.randf() * elev_max
		var rugb := rug * (0.55 + rng.randf() * 0.9)
		var gxb := (rng.randf() - 0.5) * 0.09 / ech
		var gyb := (rng.randf() - 0.5) * 0.09 / ech
		var grad := 0.06 + rng.randf() * 0.1          # haut éclairé, bas sombre
		var coin := rng.randi_range(0, 3) if rng.randf() < 0.45 else -1
		var rc := rng.randf_range(3.0, 7.0) * ech
		for ly in rh:
			for lx in w:
				var i := (y0 + ly) * S + posmod(x + lx, S)
				var d := float(mini(mini(lx, w - 1 - lx), mini(ly, rh - 1 - ly)) + int(floorf((n_wob[i] - 0.5) * 1.6 * ech + 0.5)))
				if ebr > 0.0 and d >= J and d < J + 1.6 * ech and n_mou2[i] < ebr * (1.4 - (d - J) / (1.6 * ech)):
					d = J - 0.5
				var hh := -0.9
				var ll := jl
				if d >= J:
					var e := clampf((d - J + 1.0) / (B * ech), 0.0, 1.0)
					var prof := floorf(e * 3.0 + 0.5) / 3.0           # biseau en 3 marches : arête nette
					if lisse:
						var us := floorf(n_mac[i] * 3.0) / 3.0       # usure : 3 paliers de macro-taches
						hh = prof * 0.95 + elev * 0.6 - us * 0.5 + gxb * lx * 0.4 + gyb * ly * 0.4
						ll = l0 + grad * (0.5 - float(ly) / rh) * 0.8 + (us - 0.45) * 0.22 + (floorf(n_mac2[i] * 3.0) / 3.0 - 0.45) * 0.08
					else:
						hh = prof * 0.95 + elev + (floorf(n_fin[i] * 4.0) / 4.0 - 0.4) * rugb * 1.1 + (n_gr[i] - 0.5) * 0.55 * rugb + gxb * lx + gyb * ly
						ll = l0 + grad * (0.5 - float(ly) / rh) * 1.6 + (floorf(n_fin[i] * 4.0) / 4.0 - 0.4) * (0.5 - 0.3 * minf(grain, 1.0)) * rugb + (floorf(n_gr2[i] * 3.0) / 3.0 - 0.33) * (0.22 - 0.12 * minf(grain, 1.0)) + (n_gr[i] - 0.5) * 0.12 - 0.1 * _ss(0.8, 0.95, n_fin[(i + S * 3 + 7) % (S * S)]) * rugb
					if creux > 0.0:
						var cm := minf(float(w), float(rh)) * 0.5
						hh -= creux * (1.0 - clampf(d / cm, 0.0, 1.0)) * (0.6 + n_gr[i])
						ll += creux * 0.05 * (1.0 - clampf(d / cm, 0.0, 1.0))
					if coin >= 0:
						var cx := float(lx if (coin & 1) == 0 else w - 1 - lx)
						var cy := float(ly if (coin & 2) == 0 else rh - 1 - ly)
						if cx + cy < rc + ((n_fin[i] - 0.5) * 3.0 if not lisse else 0.0):
							hh -= 0.75
							ll -= 0.09
				L[i] = ll
				H[i] = hh
				T[i] = t
				D[i] = d
	# fissures : marche aléatoire qui creuse la pierre
	for k in o.get("fissures", S / 24):
		var fx := rng.randi_range(0, S - 1)
		var fy := rng.randi_range(0, S - 1)
		for s in rng.randi_range(8, 22) * ech:
			var i := posmod(fy, S) * S + posmod(fx, S)
			if D[i] >= J:
				H[i] = -0.8
				L[i] = 0.08
				D[i] = J
			fy += 1
			if rng.randf() < 0.55:
				fx += rng.randi_range(-1, 1)
	# glace : bulles piégées (2x2 claires avec un point sombre dessous), posées dans les blocs
	var bul := {}
	if v == 4:
		for k in S / 3:
			var bx := rng.randi_range(0, S - 4)
			var by := rng.randi_range(0, S - 4)
			if D[by * S + bx] < J + 2.0 or D[(by + 1) * S + bx + 1] < J + 2.0:
				continue
			bul[by * S + bx] = 1
			bul[by * S + bx + 1] = 1
			bul[(by + 1) * S + bx] = 1
			bul[(by + 1) * S + bx + 1] = 0
			bul[(by + 2) * S + bx + 1] = -1
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
			var ic := posmod(y - 2 * ech, S) * S + posmod(x - 2 * ech, S)
			var proj := clampf(H[ic] - H[i] - 0.25, 0.0, 1.0) * 0.2
			var d: float = D[i]
			var a := _ss(J, J + 2.0 * ech, d)
			var ao := 0.76 + 0.24 * a
			var lip := 0.0
			if d >= J and d < J + float(ech):                    # lèvre claire nette le long des joints (côtés éclairés)
				lip = (0.2 if v == 4 else 0.12) if (gx + gy) > 0.05 else 0.0
			var l: float = (L[i] + shade) * ao - proj + lip
			var ln := n_big[i]
			l -= 0.1 * _ss(0.55, 0.8, ln) * (1.0 + minf(v, 2.0) * 0.6)
			var stk := _ss(0.6, 0.8, n_stk[i]) * (0.45 + 0.55 * (1.0 - a))
			l -= coulure * stk * 0.6
			var t: float = T[i]
			if grain > 0.0 and d >= J:
				# moucheture : grains isolés plus sombres / plus clairs (tirage par texel, aucun motif ordonné) et teinte qui
				# hésite entre gris et brun d'un grain à l'autre : la pierre « granuleuse » des références
				var g1 := float(((x * 92837111) ^ (y * 689287499)) & 4095) / 4095.0
				var g2: float = n_mou2[i]
				var g := (g1 - 0.5) * 0.07
				if g1 < 0.75:          # un quart des texels d'un amas en sont exclus : contours irréguliers
					if g2 < 0.13:
						g -= 0.12 + 0.05 * g1
					elif g2 > 0.9:
						g += 0.1
				if n_fin[i] > 0.78:
					g += 0.035
				l += g * grain
				t = clampf(t + (g1 - 0.5) * 0.5 * grain, 0.0, 1.0)
			var lq := _q(clampf(l, 0.0, 1.0), x, y, 0.12 if lisse else 0.55)
			var c: Color = (_rp(froid, lq) as Color).lerp(_rp(chaud, lq), t)
			if v == 3:
				# pierre givrée (refonte matière) : le givre s'accroche à l'arête HAUTE de chaque bloc (biseau supérieur) et dans le joint
				# au-dessus, en grains (tirage par texel), plus quelques amas rares ; jamais de grandes plaques blanches en damier
				var hg := float(((x * 37139213) ^ (y * 51299581)) & 1023) / 1023.0
				var haut_bloc := gy > 0.015 and a < 0.95
				var gl := (haut_bloc and hg < 0.8) or (a < 0.3 and hg < 0.35) or hg < 0.05 or (n_mac2[i] > 0.86 and hg < 0.6)
				if gl:
					c = c.lerp(_rp(giv, clampf(0.25 + lq * 0.7 + (hg - 0.5) * 0.2, 0.0, 1.0)), 0.75)
			elif v == 4:
				# pierre sous une gangue de glace (refonte matière) : la pierre reste lisible sous un voile bleu-gris désaturé,
				# reflets en lèvre claire, givre en grains, bulles ; plus de « bleu plastique »
				var cg: Color = _rp(gla, clampf(lq * 0.9 + 0.05, 0.0, 1.0))
				var gris := cg.get_luminance()
				cg = cg.lerp(Color(gris, gris, gris), 0.45)
				c = c.lerp(cg, 0.55)
				var hg := float(((x * 37139213) ^ (y * 51299581)) & 1023) / 1023.0
				if (gy > 0.015 and a < 0.95 and hg < 0.6) or hg < 0.04:
					c = c.lerp(_rp(giv, clampf(0.35 + lq * 0.7, 0.0, 1.0)), 0.7)
				if bul.has(i):
					var bt: int = bul[i]
					c = _rp(gla, 0.85 if bt == 1 else (0.6 if bt == 0 else 0.12))
			elif v >= 1:
				var ms := _ss(0.72, 0.88, n_sal[i]) * (0.3 + 0.7 * (1.0 - a)) * (0.5 + 0.5 * (0.5 if v == 1 else 1.0))
				ms = maxf(ms, stk * 0.45 * (1.0 if v == 2 else 0.6) * _ss(0.78, 0.9, n_sal[(i + S * 5) % (S * S)]))
				c = c.lerp(_rp(sal, 0.25 + lq * 0.65), clampf(ms, 0.0, 1.0) * 0.85)
				if v == 1:
					var mm := _ss(0.68, 0.84, n_mou[i]) * (1.0 - a * 0.7)
					c = c.lerp(_rp(mou, 0.15 + lq * 0.9), clampf(mm, 0.0, 1.0) * 0.9)
			if pous > 0.0 and d >= J:
				var pz := _ss(0.5, 0.85, n_mac[i]) * (0.55 + 0.45 * _ss(0.4, 0.8, n_mac2[i]))
				var pc: Color = _rp(froid, clampf(0.5 + lq * 0.35, 0.0, 1.0))
				var pg := pc.get_luminance()
				c = c.lerp(Color(pg, pg, pg * 1.02).lerp(pc, 0.4), clampf(pz * pous, 0.0, 0.6))
			if gj > 0.0:
				var hj := float(((x * 73856093) ^ (y * 19349663)) & 1023) / 1023.0
				if (a < 0.5 and hj < gj) or (a < 0.9 and hj < gj * 0.25 and n_mac2[i] > 0.7):
					c = c.lerp(_rp(giv, clampf(0.45 + hj * 0.5, 0.0, 1.0)), 0.45)
			cols[i] = c
	return [_vers_image(S, cols), _pentes(H, S, 0.9)]

## Découpe récursive d'un rectangle en dalles irrégulières (joints jamais alignés d'un bout à l'autre) : côtés entre mn et mx texels.
static func _bsp(rng: RandomNumberGenerator, x: int, y: int, w: int, h: int, mn: int, mx: int, out: Array) -> void:
	var peut_x := w >= mn * 2
	var peut_y := h >= mn * 2
	if (not peut_x and not peut_y) or (w <= mx and h <= mx and rng.randf() < 0.6):
		out.append([x, y, w, h])
		return
	var en_x := peut_x and (not peut_y or float(w) * rng.randf_range(0.7, 1.3) >= float(h))
	if en_x:
		var c := mn + int(float(w - 2 * mn) * rng.randf_range(0.0, 1.0))
		_bsp(rng, x, y, c, h, mn, mx, out)
		_bsp(rng, x + c, y, w - c, h, mn, mx, out)
	else:
		var c := mn + int(float(h - 2 * mn) * rng.randf_range(0.0, 1.0))
		_bsp(rng, x, y, w, c, mn, mx, out)
		_bsp(rng, x, y + c, w, h - c, mn, mx, out)

static func mur_paire(v: int) -> Array:
	# pierre de taille (références) : assises irrégulières de 0,3 à 0,75 m, blocs de 0,35 à 1,5 m (ponctuellement une grande
	# dalle), joints creux sombres, biseaux, arêtes ébréchées, éclats aux coins, fissures ; moucheture fine à 128 texels/m
	var rng := _rng(8150 + v)
	var S := 64 * K * EM
	var rangs: Array = _largeurs(rng, S, [10 * EM, 12 * EM, 14 * EM, 16 * EM, 18 * EM, 24 * EM])
	return _pierre(S, rangs, [12 * EM, 18 * EM, 22 * EM, 26 * EM, 30 * EM, 36 * EM, 48 * EM], {"ech": EM, "seed": 8100 + v * 17, "v": v, "sombre": v == 2, "joint": 2.6, "biseau": 2.2,
		"rug": 0.6, "l_lo": 0.5 if v == 2 else 0.56, "l_hi": 0.7 if v == 2 else 0.86, "elev": 0.6, "fissures": 12, "grain": 1.0, "ebr": 0.15})

static func dalle_paire(v: int) -> Array:
	var rng := _rng(8200 + v)
	var S := 64 * K * EM                  # tuile de 4 m (128 texels/m, 2e passe : sols vus de près)
	var rangs: Array = _largeurs(rng, S, [20 * EM, 24 * EM, 28 * EM, 32 * EM, 40 * EM, 56 * EM])
	var lisse := false                     # dalles granuleuses (refonte matière) ; avant : true, dalles de l'arène et du niveau gelé : grandes dalles nettes (retouche « sol granuleux »)
	return _pierre(S, rangs, [20 * EM, 28 * EM, 36 * EM, 44 * EM, 60 * EM] if not lisse else [32 * E, 40 * E, 48 * E, 64 * E], {"ech": EM, "seed": 8210 + v * 31, "v": v, "joint": 1.7 if not lisse else 1.6, "ebr": 0.2,
		"biseau": 2.6, "rug": 0.5, "l_lo": 0.58, "l_hi": 0.84, "elev": 1.0, "creux": 0.35 if lisse else 0.55, "joint_l": 0.06,
		"fissures": 6 if v < 3 else 7, "lisse": lisse, "grain": 0.8,
		"bsp": [26 * EM, 72 * EM], "poussiere": 0.55 if v < 3 else 0.2, "givre_joints": 0.07 if v < 3 else 0.04})

static func voute_paire() -> Array:
	var rng := _rng(8310)
	var S := 64 * K * E
	var rangs: Array = _largeurs(rng, S, [12 * E, 14 * E, 16 * E])
	return _pierre(S, rangs, [18 * E, 22 * E, 26 * E, 30 * E], {"ech": E, "seed": 8300, "sombre": true, "joint": 1.6, "biseau": 2.0, "rug": 0.55,
		"l_lo": 0.52, "l_hi": 0.68, "elev": 0.4, "fissures": 5, "grain": 0.45})

## Mur d'ossuaire (tuile de 4 m = 128 px) : 8 x 8 niches de 0,5 m, cadre de pierre, crâne ou fagot d'os ; relief par la carte de pentes.
const CRANE := ["..XXXXXX..", ".XXXXXXXX.", "XXXXXXXXXX", "XXXXXXXXXX", "XXooXXooXX", "XXooXXooXX", "XXXXnnXXXX", ".XXXXXXXX.", "..XXXXXX..", "..XtXtXt.."]

static func ossuaire_paire() -> Array:
	var S := 64 * K * EM
	var rng := _rng(8900)
	var pierre := _cols(PIERRE_SOMBRE_F)
	var osse := _cols(OSSE)
	var n_fin := _nmap(S, S / 3, S / 3, 8901, true)
	var n_big := _nmap(S, 4, 4, 8902)
	var cols := PackedColorArray()
	cols.resize(S * S)
	var H := PackedFloat32Array()
	H.resize(S * S)
	var cell := 16 * EM
	var fr := 2 * EM       # épaisseur du cadre
	for cy in S / cell:
		for cx in S / cell:
			var genre := rng.randf()
			var jx := rng.randi_range(-1, 1) * EM
			var jy := rng.randi_range(-1, 1) * EM
			var rot := rng.randi_range(0, 1)
			for ly in cell:
				for lx in cell:
					var x := cx * cell + lx
					var y := cy * cell + ly
					var i := y * S + x
					var nf: float = n_fin[i]
					var l: float
					var h: float
					var c: Color
					if lx < fr or ly < fr or lx >= cell - fr or ly >= cell - fr:    # cadre : arête claire en haut/gauche, ombre en bas/droite
						l = 0.5 + (nf - 0.5) * 0.3 + n_big[i] * 0.12
						if lx < EM or ly < EM:
							l += 0.14
						if lx >= cell - EM or ly >= cell - EM:
							l -= 0.28
						h = 1.0
						c = _rp(pierre, _q(clampf(l, 0.0, 1.0), x, y))
					else:                                                          # fond de la niche : très sombre, plus clair vers le haut
						l = 0.08 + 0.06 * nf + 0.05 * (1.0 - float(ly) / cell)
						h = 0.0
						c = _rp(pierre, _q(clampf(l, 0.0, 1.0), x, y))
					cols[i] = c
					H[i] = h
			if genre < 0.62:                                                       # crâne
				var ox := cx * cell + 3 * EM + jx
				var oy := cy * cell + 3 * EM + jy
				var N := 10 * EM
				for sy in N:
					for sx in N:
						var m: String = CRANE[sy / EM][sx / EM]
						if m == ".":
							continue
						var i := posmod(oy + sy, S) * S + posmod(ox + sx, S)
						var nf: float = n_fin[i]
						var fx := float(sx) / float(N - 1)
						var fy := float(sy) / float(N - 1)
						var l := 0.58 - 0.12 * fy + (0.1 if fx < 0.3 else 0.0) - (0.12 if fx > 0.65 else 0.0) + (nf - 0.5) * 0.2
						var h := 0.5 + 0.2 * sin(fx * PI) * sin(fy * PI)
						if m == "o" or m == "n":
							l = 0.0
							h = -0.5
						elif m == "t":
							l = 0.1
							h = 0.1
						cols[i] = _rp(osse, _q(clampf(l, 0.0, 1.0), ox + sx, oy + sy))
						H[i] = h
			elif genre < 0.88:                                                     # fagot de trois os en diagonale
				for k in 3:
					var bx := cx * cell + (3 + rng.randi_range(0, 3)) * EM
					var by := cy * cell + (3 + k * 3 + rng.randi_range(0, 1)) * EM
					var pente := 0.35 if rot == 0 else -0.35
					for t in 11 * EM:
						var px := bx + t
						var py := by + int(float(t) * pente) + (4 * EM if rot == 1 else 0)
						for w in 2 * EM:
							var i := posmod(py + w, S) * S + posmod(px, S)
							var knob := t < 2 * EM or t > 8 * EM
							var l := 0.62 - 0.1 * float(w) / EM + (nf_safe(n_fin, i) - 0.5) * 0.2 + (0.08 if knob else 0.0)
							cols[i] = _rp(osse, _q(clampf(l, 0.0, 1.0), px, py + w))
							H[i] = 0.55 + (0.2 if knob else 0.0) - 0.2 * float(w) / EM
	return [_vers_image(S, cols), _pentes(H, S, 0.9)]

static func nf_safe(a: PackedFloat32Array, i: int) -> float:
	return a[i % a.size()]

## Neige soufflée (tuile de 2 m = 64 px) : amas nets blancs-bleutés, creux ombrés ; pour les congères des coins.
static func neige_image() -> Image:
	var S := 64
	var n_a := _nmap(S, 16, 16, 9001, true)
	var n_b := _nmap(S, 8, 8, 9002)
	var n_c := _nmap(S, 32, 32, 9003, true)
	var giv := _cols(GIVRE)
	var cols := PackedColorArray()
	cols.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var l := 0.62 + (n_b[i] - 0.5) * 0.5 + (floorf(n_a[i] * 3.0) / 3.0 - 0.4) * 0.22
			if n_c[i] > 0.85:
				l += 0.2
			cols[i] = _rp(giv, _q(clampf(l, 0.0, 1.0), x, y))
	return _vers_image(S, cols)

## Ton d'une rampe en `n` paliers (12 par défaut) : tramage par BRUIT stable de moins d'un palier, jamais d'ordre régulier.
static func _rq(cols: Array, l: float, x: int, y: int, n := 12) -> Color:
	var h := float(((x * 73856093) ^ (y * 19349663)) & 1023) / 1023.0
	var i := clampi(int(floorf(clampf(l, 0.0, 1.0) * (n - 1) + (h - 0.5) * 0.5 + 0.5)), 0, n - 1)
	return _rp(cols, float(i) / (n - 1))

## Nettoyage final des petites textures : aucun texel isolé (même passe que le bâti), 64 texels/m.
static func _fin(S: int, out: PackedColorArray) -> Image:
	return PeintureBati.nettoie(_vers_image(S, out), 3)

## Or (lingots, pièces, calices) : or martelé, facettes de coups de marteau (un ton par facette), arêtes claires,
## creux brunis, quelques éclats blancs. 32 x 32 pour 0,5 m = 64 texels/m.
static func or_image() -> Image:
	var S := 32
	var R := _cols(OR)
	var n_cel := _nmap(S, 4, 4, 5101, true)
	var n_big := _nmap(S, 2, 2, 5102)
	var n_fin := _nmap(S, 8, 8, 5103)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var l := 0.5 + (n_cel[i] - 0.5) * 0.34 + (n_big[i] - 0.5) * 0.3 + (n_fin[i] - 0.5) * 0.12
			var c := n_cel[i]
			if absf(c - n_cel[((y + 1) % S) * S + x]) > 0.12 or absf(c - n_cel[y * S + (x + 1) % S]) > 0.12:
				l += 0.16 if (x + y) % 3 else -0.1             # arête de coup de marteau : lèvre claire ou creux
			if n_fin[i] > 0.86:
				l += 0.3                                         # éclat
			elif n_fin[i] < 0.12:
				l -= 0.22                                        # creux bruni
			out[i] = _rq(R, l, x, y, 10)
	return _fin(S, out)


static func mur_image(v: int) -> Image:
	return mur_paire(v)[0]

# ------------------------------------------------------------------ planches de bois (32 texels/m)
static func bois_paire() -> Array:
	var rng := _rng(8400)
	var S := 64 * F
	var R := 8 * F          # hauteur d'une planche en texels
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
		var y0 := rang * R
		var l0 := lerpf(0.34, 0.58, rng.randf())
		var tt := rng.randf()
		var kx := rng.randi_range(4, 59)
		var avec_noeud := rng.randf() < 0.5
		var ax := rng.randi_range(0, 63) * F
		for ly in R:
			for lx in S:
				var i := (y0 + ly) * S + lx
				var fil := n_gr[i] * 0.6 + n_gr2[i] * 0.4
				var hh := 0.45 * fil + (n_fin[i] - 0.5) * 0.2
				var ll := l0 + (fil - 0.5) * 0.4 + (n_fin[i] - 0.5) * 0.1 + (n_big[i] - 0.5) * 0.15 + (0.5 - float(ly) / (R - 1)) * 0.12
				if ly < F:
					hh += 0.5
					ll += 0.08
				elif ly >= R - F:
					hh = -0.9
					ll = 0.05
				elif ly >= R - 2 * F:
					ll -= 0.07
				if avec_noeud:
					var r := Vector2(float(lx) / F - kx, (float(ly) / F - 3.5) * 1.6).length()
					if r < 3.6:
						ll = l0 - 0.2 + 0.11 * sin(r * 2.3) + 0.04 * (1.0 - r / 3.6)
						hh += 0.25 * sin(r * 2.3) - 0.2
				if ly < R - F and lx >= ax and lx < ax + F:
					hh = -0.8
					ll = 0.07
				elif ly < R - F and lx >= ax + F and lx < ax + 2 * F:
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
	# clous : tête ronde claire (F x F) et ombre dessous
	var fer := _cols(FER)
	for k in 14:
		var nx := rng.randi_range(0, 63) * F
		var ny := (rng.randi_range(0, 7) * 8 + rng.randi_range(2, 4)) * F
		for dy in F:
			for dx in F:
				out[posmod(ny + dy, S) * S + posmod(nx + dx, S)] = _rp(fer, 0.75 - 0.2 * float(dx + dy) / (2 * F))
				out[posmod(ny + F + dy, S) * S + posmod(nx + dx, S)] = _rp(fer, 0.15)
	return [_vers_image(S, out), _pentes(H, S, 0.9)]

static func bois_image() -> Image:
	return bois_paire()[0]

# ------------------------------------------------------------------ fer riveté, rouille (32 texels/m)
static func fer_paire() -> Array:
	var S := 32 * F
	var n_fin := _nmap(S, S / 2, S / 2, 8501)
	var n_big := _nmap(S, 3, 3, 8502)
	var n_rou := _nmap(S, 5, 5, 8503)
	var rng := _rng(8500)
	var H := PackedFloat32Array()
	H.resize(S * S)
	for y in S:
		for x in S:
			var v := float(y % (16 * F)) / F          # coordonnées en unités de l'ancienne grille
			var u := float(x) / F
			var h := 0.6 + (n_fin[y * S + x] - 0.5) * 0.25
			if v < 2.0:
				h = 0.9 * (floorf(v) + 1.0) * 0.5
			elif v > 12.0:
				h = 0.2 * (15.0 - v)
			for rx in [4, 12, 20, 28]:
				var r := Vector2(u - rx, v - 6.5).length()
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
			var l := 0.36 + (n_big[i] - 0.5) * 0.2 + (n_fin[i] - 0.5) * 0.1 + clampf((gx + gy) * 0.5 * F, -0.5, 0.5) * 0.4
			var c := _rp(fer, _q(clampf(l, 0.0, 1.0), x, y))
			var rm := _ss(0.58, 0.78, n_rou[i])
			if rm > 0.0:
				c = c.lerp(_rp(rou, 0.2 + l * 0.9), rm * 0.85)
			out[i] = c
	for k in 5 * F:                                         # rayures claires (fines)
		var gx := rng.randi_range(0, 28 * F)
		var gy := rng.randi_range(2 * F, 28 * F)
		for j in rng.randi_range(2 * F, 5 * F):
			var ip := posmod(gy, S) * S + posmod(gx + j, S)
			out[ip] = out[ip].lightened(0.25)
	return [_vers_image(S, out), _pentes(H, S, 0.8)]

static func fer_image() -> Image:
	return fer_paire()[0]

## Lame rouillée (armes au sol) : acier forgé éteint, 64 texels/m. Coupe d'une lame de ~6 cm répétée sur 6 rangées (fil clair,
## biseau, plat, gorge sombre, plat, dos assombri), traînées de polissage dans le sens de la lame, piqûres, rouille en plaques
## qui se concentre sur les bords, auréole brune autour de chaque plaque.
static func lame_image() -> Image:
	var S := 64
	var n_str := _nmap(S, 3, 40, 8551)
	var n_fin := _nmap(S, S / 4, S / 4, 8553)
	var n_rou := _nmap(S, 5, 5, 8552)
	var n_pit := _nmap(S, S / 2, S / 2, 8554)
	var fer := _cols(FER)
	var rou := _cols(ROUILLE)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var by := y % 6
			var l := 0.42 + (n_str[i] - 0.5) * 0.16 + (n_fin[i] - 0.5) * 0.08
			match by:
				0: l += 0.3          # fil clair
				1: l += 0.14         # biseau éclairé
				2: l += 0.04
				3: l -= 0.2          # gorge
				4: l -= 0.02
				5: l -= 0.14         # dos dans l'ombre
			if n_pit[i] > 0.9:
				l -= 0.22            # piqûre
			var rm: float = n_rou[i] + (0.1 if by == 0 or by == 5 else 0.0)
			var c := _rq(fer, l, x, y)
			if rm > 0.62:
				c = _rq(rou, 0.12 + l * 0.9 + (n_fin[i] - 0.5) * 0.3, x, y, 10)
			elif rm > 0.55:
				c = _rq(fer, l - 0.17, x, y)        # auréole brune
			out[i] = c
	return _fin(S, out)


# ------------------------------------------------------------------ gravure runique (sarcophages) : creusée dans la pierre
static func gravure_paire() -> Array:
	var rng := _rng(8600)
	var S := 64 * F
	var carve := PackedFloat32Array()
	carve.resize(S * S)
	# trace de largeur w (unités de 2 cm) entre deux points (unités) : disques posés à pas fin, bords nets mais non crénelés en gros
	var trace := func(x0: float, y0: float, x1: float, y1: float, w: float) -> void:
		var hw := maxf(w * F * 0.5, 0.75)
		var n := maxi(int(Vector2(x1 - x0, y1 - y0).length() * F * 2.0), 1)
		for k in n + 1:
			var t := float(k) / n
			var cx := (x0 + (x1 - x0) * t) * F
			var cy := (y0 + (y1 - y0) * t) * F
			for py in range(int(cy - hw - 1.0), int(cy + hw + 2.0)):
				for px in range(int(cx - hw - 1.0), int(cx + hw + 2.0)):
					if Vector2(px + 0.5 - cx, py + 0.5 - cy).length() <= hw:
						carve[posmod(py, S) * S + posmod(px, S)] = 1.0
	trace.call(6.0, 6.5, 58.0, 6.5, 2.0)                     # cadre gravé
	trace.call(6.0, 56.5, 58.0, 56.5, 2.0)
	trace.call(6.5, 6.0, 6.5, 58.0, 2.0)
	trace.call(56.5, 6.0, 56.5, 58.0, 2.0)
	for rang in [12, 46]:                                   # frises de runes
		var x := 11
		while x < 52:
			trace.call(x + 0.5, rang, x + 0.5, rang + 8.0, 1.0)
			var forme := rng.randi_range(0, 3)
			if forme == 0 or forme == 2:
				trace.call(x + 1.5, rang + 1.5, x + 4.0, rang + 4.0, 1.0)
			if forme == 1 or forme == 2:
				trace.call(x + 1.5, rang + 5.5, x + 4.0, rang + 3.0, 1.0)
			if forme == 3:
				trace.call(x - 0.5, rang + 2.5, x - 3.0, rang + 5.0, 1.0)
			x += 6
	for k in range(0, 44 * 4):                              # serpent
		var xs := 10.0 + float(k) / 4.0
		var xe := xs + 0.25
		trace.call(xs, 32.5 + sin(xs * 0.42) * 5.0, xe, 32.5 + sin(xe * 0.42) * 5.0, 3.0)
	trace.call(52.0, 30.5, 56.0, 30.5, 3.0)                 # tête
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
			var e := mini(mini(x, S - 1 - x), mini(y, S - 1 - y))
			if e < 2 * F:
				h += 0.3 * float(2 * F - e) / F - 0.4 * (1.0 if e == 0 and (x == S - 1 or y == S - 1) else 0.0)
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
			var l := 0.5 + (n_fin[i] - 0.5) * 0.12 + (n_gr[i] - 0.5) * 0.14 + clampf((gx + gy) * 0.8 * F, -0.5, 0.5) * 0.3 - carve[i] * 0.16
			var lq := _q(clampf(l, 0.0, 1.0), x, y)
			out[i] = (_rp(fr, lq) as Color).lerp(_rp(ch, lq), 0.25)
	return [_vers_image(S, out), _pentes(H, S, 1.0)]

## Panneau d'ENTRELACS nordique (références : piliers, urnes, autel, façade) : 256 x 256 px pour UN panneau (UV 0..1 posés par la
## géométrie, souvent étiré en hauteur) : cadre en relief, losanges concentriques au centre, treillis tressé en diagonale
## (dessus / dessous alternés à chaque croisement : effet de vannerie), sillons profonds presque noirs, moucheture.
static func entrelacs_paire() -> Array:
	var S := 256
	var H := PackedFloat32Array()
	H.resize(S * S)
	var G := PackedFloat32Array()     # 1 = fond du sillon
	G.resize(S * S)
	var n_fin := _nmap(S, S / 3, S / 3, 8651, true)
	var n_gr := _nmap(S, 6, 6, 8652)
	for y in S:
		for x in S:
			var i := y * S + x
			var u := (x + 0.5) / S
			var v := (y + 0.5) / S
			var cx := u - 0.5
			var cy := v - 0.5
			var bord := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			var h := 0.0
			var g := 1.0
			if bord < 0.075:                                   # cadre : listel bombé, sillon intérieur
				var t := bord / 0.075
				if t < 0.78:
					h = 0.75 + 0.25 * sin(t / 0.78 * PI)
					g = 0.0
			else:
				var m := absf(cx) + absf(cy)                   # métrique « losange »
				if m < 0.36:
					# losanges concentriques : 4 bandes, losange plein au centre
					var k := m / 0.09
					var f := k - floorf(k)
					if m < 0.05 or (f > 0.2 and f < 0.8):
						h = 0.55 + 0.45 * sin(clampf((f - 0.2) / 0.6, 0.0, 1.0) * PI) if m >= 0.05 else 1.0
						g = 0.0
				elif m > 0.4:
					# treillis tressé : deux familles de bandes diagonales ; au croisement, l'une passe dessus, l'autre plonge
					var p1 := (cx + cy) * 7.0
					var p2 := (cx - cy) * 7.0
					var f1 := p1 - floorf(p1)
					var f2 := p2 - floorf(p2)
					var b1 := f1 > 0.18 and f1 < 0.82
					var b2 := f2 > 0.18 and f2 < 0.82
					var h1 := 0.6 + 0.4 * sin(clampf((f1 - 0.18) / 0.64, 0.0, 1.0) * PI)
					var h2 := 0.6 + 0.4 * sin(clampf((f2 - 0.18) / 0.64, 0.0, 1.0) * PI)
					if b1 and b2:
						var dessus := (int(floorf(p1)) + int(floorf(p2))) % 2 == 0
						h = h1 if dessus else h2
						var bas := h2 if dessus else h1
						h = maxf(h, bas * 0.55)
						# arête du brin du dessus : sillon fin qui sépare les deux brins
						var fe := f2 if dessus else f1
						if fe < 0.24 or fe > 0.76:
							h *= 0.8
						g = 0.0
					elif b1:
						h = h1 * 0.9
						g = 0.0
					elif b2:
						h = h2 * 0.9
						g = 0.0
			if g > 0.5:
				h = -0.6
			h += (floorf(n_fin[i] * 4.0) / 4.0 - 0.4) * 0.12 + (n_gr[i] - 0.5) * 0.18
			H[i] = h
			G[i] = g
	var fr := _cols(PIERRE_FROID)
	var ch := _cols(PIERRE_CHAUD)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var gx := (H[y * S + posmod(x + 1, S)] - H[y * S + posmod(x - 1, S)]) * 0.5
			var gy := (H[posmod(y + 1, S) * S + x] - H[posmod(y - 1, S) * S + x]) * 0.5
			var proj := clampf(H[posmod(y - 3, S) * S + posmod(x - 3, S)] - H[i] - 0.4, 0.0, 1.0) * 0.25     # ombre portée du relief
			var l := 0.46 + clampf(-(gx + gy) * 2.2, -0.5, 0.5) * 0.5 + (n_gr[i] - 0.5) * 0.12 - proj
			if G[i] > 0.5:
				l = 0.07 + n_fin[i] * 0.05
			else:
				l += H[i] * 0.06
			var g1 := float(((x * 92837111) ^ (y * 689287499)) & 4095) / 4095.0
			var g2 := float(((x * 19349663 + 7) ^ (y * 83492791 + 3)) & 4095) / 4095.0
			l += (g1 - 0.5) * 0.08 - (0.12 if g2 < 0.09 else 0.0) + (0.09 if g2 > 0.95 else 0.0)
			var lq := _q(clampf(l, 0.0, 1.0), x, y)
			out[i] = (_rp(fr, lq) as Color).lerp(_rp(ch, lq), clampf(0.35 + (g1 - 0.5) * 0.4, 0.0, 1.0))
	return [_vers_image(S, out), _pentes(H, S, 1.4)]

static func gravure_image() -> Image:
	return gravure_paire()[0]

# ------------------------------------------------------------------ poterie, os, parchemin
static func argile_image() -> Image:
	var S := 64
	var n_fin := _nmap(S, S / 4, S / 4, 8701)
	var n_big := _nmap(S, 3, 3, 8702)
	var n_cou := _nmap(S, 2, 12, 8703)
	var cols := _cols(ARGILE)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var by := y % 16
			var l := 0.5 + (n_big[i] - 0.5) * 0.3 + (n_fin[i] - 0.5) * 0.12 + (n_cou[i] - 0.5) * 0.12
			l += 0.14 * (1.0 - by / 15.0) - 0.12 * (1.0 if by >= 14 else 0.0)      # épaulement éclairé, pied sombre
			if y % 5 == 0:
				l -= 0.05                                                            # stries du tour
			if (y / 16) % 2 == 0:                                                    # frise en zigzag, engobe sombre
				var xm := x % 16
				var zz := 5 + (xm if xm < 8 else 15 - xm) / 2
				if by >= zz and by <= zz + 2:
					l -= 0.3
			if n_big[i] > 0.78 and by < 3:
				l -= 0.14                                                            # coulure de glaçure
			out[i] = _rq(cols, l, x, y)
	return _fin(S, out)

## Os (64 texels/m, tuile de 1 m) : fibres claires dans le sens de la hauteur, taches brunes de terre, fêlures à lèvre claire,
## pores sombres, extrémités plus jaunes.
static func os_image() -> Image:
	var S := 64
	var n_fin := _nmap(S, 20, 4, 8801)
	var n_big := _nmap(S, 4, 4, 8802)
	var n_pore := _nmap(S, S / 2, S / 2, 8803)
	var rng := _rng(8800)
	var cols := _cols(OSSE)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var l := 0.6 + (n_big[i] - 0.5) * 0.36 + (n_fin[i] - 0.5) * 0.18
			if n_pore[i] > 0.88:
				l -= 0.25
			var c := _rq(cols, l, x, y)
			if n_big[(i * 7) % (S * S)] > 0.74:
				c = c.lerp(Color(0.55, 0.42, 0.25), 0.4)                             # tache de terre
			out[i] = c
	for k in 8:                                                                       # fêlures : creux sombre + lèvre claire à gauche
		var x := rng.randi_range(0, S - 1)
		var y := rng.randi_range(0, S - 14)
		for j in rng.randi_range(6, 12):
			out[(y + j) * S + posmod(x + (j * 2) / 5, S)] = _c(OSSE, 0)
			if j % 2 == 0:
				out[(y + j) * S + posmod(x - 1 + (j * 2) / 5, S)] = _c(OSSE, 5)
	return _fin(S, out)

## Parchemin (64 texels/m, tuile de 1 m) : fibres de papier, taches d'eau, bords brunis et roussis, pli central, lignes
## d'écriture à l'encre brune (mots de 3 à 9 texels, interlignes de 6), initiale enluminée en tête.
static func parchemin_image() -> Image:
	return _parchemin_image()

# ------------------------------------------------------------------ tissus (L0 objets : paillasses, couvertures, tapis, nappes, sacs, bannières)
## Laine tissée en sergé (64 texels/m, tuile de 1 m) : fils de 2 texels (chaîne et trame d'épaisseurs inégales), côtes diagonales
## du sergé, flammes de trame plus épaisses, feutrage et bouloches en grandes taches, quelques fibres claires. Écru moyen : la teinte
## de l'objet (couleurs de sommet du tapis, des bannières) s'y multiplie comme sur l'ancien parchemin (même luminosité moyenne).
static func laine_image() -> Image:
	var S := 64
	var rng := _rng(9100)
	var n_big := _nmap(S, 4, 4, 9101)
	var n_fin := _nmap(S, S / 4, S / 4, 9102)
	var n_flamme := _nmap(S, 3, S / 2, 9103)
	var chaine := PackedFloat32Array()
	var trame := PackedFloat32Array()
	for k in S / 2:
		chaine.append(rng.randf_range(-0.06, 0.06))
		trame.append(rng.randf_range(-0.06, 0.06))
	var cols := _cols(LAINE)
	var cote := [0.06, 0.025, -0.025, -0.07]
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var l := 0.6 + (n_big[i] - 0.5) * 0.3 + (n_fin[i] - 0.5) * 0.1
			l += cote[posmod(x / 2 + y / 2, 4)] + chaine[x / 2] * 0.6 + trame[y / 2] * 0.6
			if n_flamme[i] > 0.78:
				l += 0.07                                                            # flamme de trame (fil plus épais)
			out[i] = _rq(cols, l, x, y)
	for k in 10:                                                                      # fibres claires qui dépassent (2 à 4 texels)
		var x := rng.randi_range(0, S - 1)
		var y := rng.randi_range(0, S - 1)
		for j in rng.randi_range(2, 4):
			out[posmod(y + j / 2, S) * S + posmod(x + j, S)] = _c(LAINE, 6)
	return _fin(S, out)

## Lin (64 texels/m, tuile de 1 m) : toile fine et claire, fils de chaîne et de trame en traînées irrégulières (pas de damier),
## boutons de fil (nœuds plus épais), plis doux en grandes ondes, légère salissure. Nappes d'autel, bandelettes, linceul.
static func lin_image() -> Image:
	var S := 64
	var rng := _rng(9200)
	var n_big := _nmap(S, 3, 5, 9201)
	var n_fin := _nmap(S, S / 3, S / 3, 9202)
	var n_noeud := _nmap(S, S / 2, S / 4, 9203)
	var chaine := PackedFloat32Array()
	var trame := PackedFloat32Array()
	for k in S:
		chaine.append(rng.randf_range(-0.05, 0.05))
		trame.append(rng.randf_range(-0.04, 0.04))
	var cols := _cols(LIN)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var l := 0.52 + (n_big[i] - 0.5) * 0.26 + (n_fin[i] - 0.5) * 0.08 + chaine[x] + trame[y]
			l += sin((y + n_big[i] * 10.0) * TAU / 21.0) * 0.04                       # plis doux
			if n_noeud[i] > 0.83:
				l += 0.08                                                            # bouton de fil
			out[i] = _rq(cols, l, x, y)
	return _fin(S, out)

## Toile de sac / paillasse (64 texels/m, tuile de 1 m) : grosse toile de jute brune, fils de 4 texels bombés (clair au milieu,
## sombre aux bords) qui passent dessus/dessous en alternance (armure toile à grande échelle), jours sombres aux croisements,
## brins de paille clairs et taches de crasse.
static func jute_image() -> Image:
	var S := 64
	var rng := _rng(9300)
	var n_big := _nmap(S, 4, 4, 9301)
	var n_fin := _nmap(S, S / 2, S / 2, 9302)
	var fil := PackedFloat32Array()
	for k in S / 4 * 2:
		fil.append(rng.randf_range(-0.07, 0.07))
	var cols := _cols(JUTE)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var cx := x / 4
			var cy := y / 4
			var dessus_h := (cx + cy) % 2 == 0              # fil de trame (horizontal) dessus, sinon fil de chaîne
			var t := float(y % 4 if dessus_h else x % 4)      # position dans l'épaisseur du fil (0..3)
			var bombe := 1.0 - absf(t - 1.5) / 1.5           # 0 au bord, 1 au milieu
			var l := 0.5 + bombe * 0.13 + (n_big[i] - 0.5) * 0.3 + (n_fin[i] - 0.5) * 0.12
			l += fil[cy] if dessus_h else fil[S / 4 + cx]
			var u := x % 4
			var v := y % 4
			if (u == 0 or u == 3) and (v == 0 or v == 3):
				l -= 0.1                                                             # jour entre les fils
			out[i] = _rq(cols, l, x, y)
	for k in 5:                                                                       # brins de paille (paillasse) : traits clairs obliques
		var x := rng.randi_range(0, S - 1)
		var y := rng.randi_range(0, S - 1)
		var dx := rng.randi_range(-1, 1)
		for j in rng.randi_range(4, 8):
			out[posmod(y + j, S) * S + posmod(x + (j * dx) / 2, S)] = Color("#a8925f")
	return _fin(S, out)

static func _parchemin_image() -> Image:
	var S := 64
	var rng := _rng(8900)
	var n_fin := _nmap(S, S / 3, S / 3, 8901)
	var n_big := _nmap(S, 3, 3, 8902)
	var n_fib := _nmap(S, 14, 3, 8903)
	var cols := _cols(PARCHEMIN)
	var out := PackedColorArray()
	out.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var l := 0.56 + (n_big[i] - 0.5) * 0.42 + (n_fin[i] - 0.5) * 0.1 + (n_fib[i] - 0.5) * 0.1
			var bord := mini(mini(x, S - 1 - x), mini(y, S - 1 - y))
			if bord < 6:
				l -= 0.04 * (6 - bord)                                               # bords brunis puis roussis
			if x == 32:
				l -= 0.16                                                            # pli
			elif x == 33:
				l += 0.1
			out[i] = _rq(cols, l, x, y)
	var encre := _c(PARCHEMIN, 0).lerp(_c(PARCHEMIN, 1), 0.25)
	for y in range(9, 56, 6):
		var x := 7
		while x < 57:
			var l := rng.randi_range(3, 9)
			for j in l:
				if x + j < 57:
					out[y * S + x + j] = encre
					if rng.randf() < 0.45:
						out[(y + 1) * S + x + j] = encre                              # jambage
			x += l + 2
	for y in 4:                                                                       # initiale enluminée : carré rouille et or
		for x in 5:
			out[(y + 3) * S + x + 7] = _c(ROUILLE, 2) if (x + y) % 2 == 0 else _c(OR, 3)
	return _fin(S, out)

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


# ------------------------------------------------------------------ crypte v2 (2026-10-22, réf. references/crypte_v2_planche.png)
## Dalles de sol IRRÉGULIÈRES (planche : « pierre usée / fissurée / terre-gravier ») : cellules de Voronoï aux bords gauchis (joints
## étroits et sinueux, plus de rectangles alignés), chaque dalle a son ton, son inclinaison et son usure ; fissures qui la traversent,
## éclats aux arêtes, graviers et givre dans les joints, voiles de poussière et plaques humides en macro-taches. 128 texels/m, tuile de 4 m.
static func dalle_v2_paire() -> Array:
	var S := 64 * K * EM
	var graine := 8800
	var rng := _rng(graine)
	var GR := 5                                    # 5 x 5 sites par tuile : dalles de 0,6 à 1,1 m
	var cel := float(S) / GR
	var sites: Array = []
	var tons: Array = []
	var teintes: Array = []
	var pentes: Array = []
	var haut: Array = []
	var fiss: Array = []
	for j in GR:
		for i in GR:
			sites.append(Vector2((i + 0.5 + rng.randf_range(-0.36, 0.36)) * cel, (j + 0.5 + rng.randf_range(-0.36, 0.36)) * cel))
			tons.append(rng.randf_range(0.5, 0.8) - (0.1 if rng.randf() < 0.15 else 0.0))
			teintes.append(clampf(0.45 * pow(rng.randf(), 2.0) + (0.25 if rng.randf() < 0.12 else 0.0), 0.0, 1.0))
			pentes.append(Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * 0.0045)
			haut.append(rng.randf_range(-0.2, 0.6))
			fiss.append([rng.randf() < 0.42, rng.randf() * PI, rng.randf_range(-0.28, 0.28) * cel, rng.randf() < 0.4])
	var n_fin := _nmap(S, S / 3, S / 3, graine + 1, true)
	var n_gr := _nmap(S, S / 12, S / 12, graine + 2)
	var n_wx := _nmap(S, S / 24, S / 24, graine + 3)
	var n_wy := _nmap(S, S / 24, S / 24, graine + 4)
	var n_mac := _nmap(S, 5, 5, graine + 9)
	var n_mac2 := _nmap(S, 9, 9, graine + 10)
	var n_mou := _nmap(S, S / 2, S / 2, graine + 11, true)
	var n_big := _nmap(S, 4, 4, graine + 5)
	var froid := _cols(PIERRE_FROID)
	var chaud := _cols(PIERRE_CHAUD)
	var giv := _cols(GIVRE)
	var H := PackedFloat32Array()
	H.resize(S * S)
	var cols := PackedColorArray()
	cols.resize(S * S)
	var J := 1.9
	var BIS := 5.0
	for y in S:
		for x in S:
			var i := y * S + x
			var gx := x + (n_wx[i] - 0.5) * 9.0                   # gauchissement des joints
			var gy := y + (n_wy[i] - 0.5) * 9.0
			var ci := int(floorf(gx / cel))
			var cj := int(floorf(gy / cel))
			var d1 := 1.0e9
			var d2 := 1.0e9
			var k1 := 0
			var k2 := 0
			var p1 := Vector2.ZERO
			var p2 := Vector2.ZERO
			for dj in range(-1, 2):
				for di in range(-1, 2):
					var ii := posmod(ci + di, GR)
					var jj := posmod(cj + dj, GR)
					var q: Vector2 = sites[jj * GR + ii]
					q += Vector2(floorf(float(ci + di) / GR) * S, floorf(float(cj + dj) / GR) * S) if (ci + di < 0 or ci + di >= GR or cj + dj < 0 or cj + dj >= GR) else Vector2.ZERO
					var dd := (Vector2(gx, gy) - q).length_squared()
					if dd < d1:
						d2 = d1
						k2 = k1
						p2 = p1
						d1 = dd
						k1 = jj * GR + ii
						p1 = q
					elif dd < d2:
						d2 = dd
						k2 = jj * GR + ii
						p2 = q
			var sep := maxf((p2 - p1).length(), 1.0)
			var de := (d2 - d1) / (2.0 * sep)                      # distance au joint (médiatrice)
			if n_mou[i] > 0.86 and de < J + 4.0:
				de -= 2.2                                            # éclat à l'arête
			var rel := Vector2(gx, gy) - p1
			var fl: Array = fiss[k1]
			var crack := 9.9
			if fl[0]:
				var nrm := Vector2(cos(fl[1]), sin(fl[1]))
				var tg := Vector2(-nrm.y, nrm.x)
				var t_ := rel.dot(tg)
				if absf(t_) < cel * 0.46:
					crack = absf(rel.dot(nrm) - fl[2] + sin(t_ * 0.09 + k1) * 2.2 + (n_gr[i] - 0.5) * 4.0)
			var ton: float = tons[k1]
			var tt: float = teintes[k1]
			var hh := -1.0
			var l := 0.05
			if de >= J:
				var e := clampf((de - J) / BIS, 0.0, 1.0)
				var usure := _ss(0.45, 0.75, n_mac[i])
				var prof := floorf((e - 0.0) * 3.0 + 0.5) / 3.0
				hh = prof * 0.6 + haut[k1] + (pentes[k1] as Vector2).dot(rel) + (n_gr[i] - 0.5) * 0.6 - usure * 0.35 * (1.0 - e * 0.5)
				l = ton + (n_gr[i] - 0.5) * 0.2 + (n_fin[i] - 0.5) * 0.16 + (1.0 - e) * -0.09 * (1.0 if de < J + 2.0 else 0.6) + (usure - 0.4) * 0.08
				var dirv := (p1 - p2).normalized()                  # biseau peint : lumière haut-gauche
				l += dirv.dot(Vector2(-0.7, -0.7)) * 0.2 * (1.0 - e)
				var gk := float(((x * 92837111) ^ (y * 689287499)) & 4095) / 4095.0
				l += (gk - 0.5) * 0.09 + (floorf(n_fin[i] * 3.0) / 3.0 - 0.33) * 0.12
				if n_fin[(i + 7919) % (S * S)] > 0.9:
					l -= 0.12                                       # piqûres
				if n_fin[(i + 100003) % (S * S)] > 0.94:
					l += 0.08
			if crack < 1.15 + n_fin[i] * 1.2:
				hh = -0.8
				l = 0.07
			H[i] = hh
			var lq := _q(clampf(l, 0.0, 1.0), x, y, 0.5)
			var c: Color = (_rp(froid, lq) as Color).lerp(_rp(chaud, lq), clampf(tt * 1.5 + 0.1, 0.0, 1.0))
			if de >= J:
				# poussière claire en macro-taches ; plaques humides plus sombres et bleutées
				var pz := _ss(0.55, 0.85, n_mac2[i]) * 0.45
				var pg := c.get_luminance()
				c = c.lerp(Color(pg * 1.05, pg * 1.08, pg * 1.12), pz)
				var hum := _ss(0.74, 0.86, n_big[i])
				if hum > 0.0:
					c = c.lerp(Color(c.r * 0.6, c.g * 0.72, c.b * 0.92), hum * 0.4)
			else:
				# joint : terre sombre, graviers clairs, grains de givre
				var hj := float(((x * 73856093) ^ (y * 19349663)) & 1023) / 1023.0
				if hj < 0.07:
					c = c.lerp(Color(0.34, 0.29, 0.23), 0.8)
				elif hj > 0.97:
					c = c.lerp(_rp(giv, 0.5 + hj * 0.4), 0.5)
			if de < J + 2.5 and de >= J:
				var hg := float(((x * 37139213) ^ (y * 51299581)) & 1023) / 1023.0
				if hg < 0.04:
					c = c.lerp(_rp(giv, 0.55 + hg * 5.0), 0.5)
			cols[i] = c
	return [_vers_image(S, cols), _pentes(H, S, 0.9)]

## Pierre de taille NUE (tuile de 2 m = 256 px) pour les blocs des modules Blender : grain fin, strates, piqûres, lichen rare ;
## aucun joint (la géométrie les fournit). Le ton de chaque bloc et l'occlusion viennent des couleurs de sommet.
static func pierre_v2_paire() -> Array:
	var S := 256
	var graine := 8830
	var n_fin := _nmap(S, S / 3, S / 3, graine + 1, true)
	var n_gr := _nmap(S, S / 12, S / 12, graine + 2)
	var n_mac := _nmap(S, 4, 4, graine + 3)
	var n_str := _nmap(S, 3, S / 5, graine + 4)
	var n_mou := _nmap(S, S / 2, S / 2, graine + 5, true)
	var n_li := _nmap(S, 6, 6, graine + 6)
	var froid := _cols(PIERRE_FROID)
	var chaud := _cols(PIERRE_CHAUD)
	var mou := _cols(MOUSSE)
	var H := PackedFloat32Array()
	H.resize(S * S)
	var cols := PackedColorArray()
	cols.resize(S * S)
	for y in S:
		for x in S:
			var i := y * S + x
			var l := 0.62 + (n_gr[i] - 0.5) * 0.22 + (n_mac[i] - 0.5) * 0.2 + (floorf(n_fin[i] * 4.0) / 4.0 - 0.4) * 0.16 + (n_str[i] - 0.5) * 0.12
			var g1 := float(((x * 92837111) ^ (y * 689287499)) & 4095) / 4095.0
			var h := (n_gr[i] - 0.5) * 0.5 + (floorf(n_fin[i] * 4.0) / 4.0 - 0.4) * 0.7
			if n_mou[i] < 0.1 and g1 < 0.8:
				l -= 0.18
				h -= 0.5
			elif n_mou[i] > 0.92:
				l += 0.09
			H[i] = h
			var lq := _q(clampf(l, 0.0, 1.0), x, y, 0.45)
			var c: Color = (_rp(froid, lq) as Color).lerp(_rp(chaud, lq), clampf(0.35 + (n_mac[i] - 0.5) * 0.9 + (g1 - 0.5) * 0.3, 0.0, 1.0))
			var lich := _ss(0.86, 0.93, n_li[i]) * (0.5 if g1 < 0.8 else 0.15)
			if lich > 0.0:
				c = c.lerp(_rp(mou, 0.2 + lq * 0.6), lich * 0.7)
			cols[i] = c
	return [_vers_image(S, cols), _pentes(H, S, 0.7)]

## Croûte de givre au sol en DÉCALQUE (tuile de 1 m = 128 px) : bords déchiquetés au pixel, grains isolés autour ; remplace les dalles de neige
## (rectangles blancs posés sur le sol) par des taches irrégulières qui épousent les joints. Alpha tout ou rien (découpe).
static func givre_sol_image() -> Image:
	var S := 128
	var graine := 8860
	var n_a := _nmap(S, 6, 6, graine)
	var n_b := _nmap(S, 14, 14, graine + 1)
	var n_c := _nmap(S, S / 3, S / 3, graine + 2, true)
	var n_d := _nmap(S, 3, 3, graine + 3)
	var giv := _cols(GIVRE)
	var d := PackedByteArray()
	d.resize(S * S * 4)
	for y in S:
		for x in S:
			var i := y * S + x
			var f := n_a[i] * 0.55 + n_b[i] * 0.3 + n_c[i] * 0.15
			var seuil := 0.62 + (n_d[i] - 0.5) * 0.12
			var h := float(((x * 73856093) ^ (y * 19349663)) & 1023) / 1023.0
			var dedans := f > seuil
			var grain := f > seuil - 0.07 and h < 0.22
			var o := i * 4
			if dedans or grain:
				var l := 0.62 + (f - seuil) * 2.6 + (h - 0.5) * 0.3
				var c: Color = _rp(giv, _q(clampf(l, 0.0, 1.0), x, y, 0.5))
				c = c.lerp(Color(0.8, 0.9, 0.96), 0.35)
				d[o] = int(c.r * 255.0)
				d[o + 1] = int(c.g * 255.0)
				d[o + 2] = int(c.b * 255.0)
				d[o + 3] = 255
	return Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, d)

# ------------------------------------------------------------------ accès (le cache vit dans CrypteDecor)
static func tex(nom: String) -> ImageTexture:
	return _mips(image(nom))

## Albédo + carte de pentes ([albédo, pentes] ; pentes = null si la matière n'a pas de relief).
static func paire(nom: String) -> Array:
	match nom:
		"mur0": return mur_paire(0)
		"mur1": return mur_paire(1)
		"mur2": return mur_paire(2)
		"mur3": return mur_paire(3)
		"mur4": return mur_paire(4)
		"dalle3": return dalle_paire(3)
		"dalle4": return dalle_paire(4)
		"ossuaire": return ossuaire_paire()
		"dalle_v2": return dalle_v2_paire()
		"pierre_v2": return pierre_v2_paire()
		"dalle0": return dalle_paire(0)
		"dalle1": return dalle_paire(1)
		"voute": return voute_paire()
		"bois": return bois_paire()
		"fer": return fer_paire()
		"gravure": return gravure_paire()
		"entrelacs": return entrelacs_paire()
	return [image(nom), null]

static func image(nom: String) -> Image:
	match nom:
		"mur0", "mur1", "mur2", "mur3", "mur4", "dalle0", "dalle1", "dalle3", "dalle4", "dalle_v2", "pierre_v2", "voute", "bois", "fer", "gravure", "ossuaire", "entrelacs":
			return paire(nom)[0]
		"givre_sol": return givre_sol_image()
		"or": return or_image()
		"neige": return neige_image()
		"lame": return lame_image()
		"argile": return argile_image()
		"os": return os_image()
		"parchemin": return parchemin_image()
		"laine": return laine_image()
		"lin": return lin_image()
		"jute": return jute_image()
		"toile": return toile_image()
		"flamme": return flamme_atlas_image()
		"halo": return halo_image()
		"rai": return rai_image()
	return mur_image(0)
