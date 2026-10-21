class_name GrotteTextures
## Textures de la grotte : roche, strates, sol, givre, neige, glace, glaçons, cristal, brume, jour, rai, peau, paille.
## Refonte « matières » (2026-10-21, d'après les images de référence grottes_cryptes_*) : pierre BRUN-GRIS sombre et granuleuse,
## mouchetée au texel sur plusieurs tons (taches brunes / grises, éclats clairs de givre), fractures quasi noires ; plus de bleu
## saturé ni de mousse verte. Chaque matière est un champ de hauteur tuilable (bruits fractals, cellules), éclairé au repoussé
## (lumière haut-gauche), assombri dans les fissures et quantifié sur une rampe de 12 tons.
## Densité : tuile de 256 px pour 2 m = 128 texels/m (rendu 640x360). Le shader grotte.gdshader projette ces tuiles en
## coordonnées MONDE (triplanaire) : elles ne dépendent pas des UV du maillage. Les textures « superposées » (neige, glace, givre)
## portent dans l'alpha un SEUIL : le shader les montre là où le masque (sommet ou pente) dépasse ce seuil (bords déchiquetés au texel).
## Fonctions pures : utilisables dans des fils d'exécution.

const S := 128
const E := 2          # roche, strates, sol, givre : tuile de 256 px (2 m dans la projection monde = 128 texels/m)
const SG := S * E

# bornes de rampe (sombre -> clair)
const R_ROCHE := ["#040303", "#0b0908", "#15120f", "#1f1b17", "#2a2520", "#37312b", "#463f37", "#5a5148", "#73695d", "#958a7c"]   # passe 2 kit : brun-gris granuleux (grottes_cryptes_6), plus de bleu dans la pierre
const R_ROCHE_GRIS := ["#040404", "#0c0c0c", "#161616", "#201f1e", "#2b2a28", "#383634", "#484542", "#5e5a56", "#7b7670", "#9b958e"]
const R_ROCHE_FROID := ["#050608", "#0b0d10", "#14161a", "#1d2024", "#272a2f", "#33373c", "#41454b", "#575b61", "#777c83"]
const R_BRUN := ["#070605", "#0f0e0c", "#191714", "#23201c", "#302d28", "#3d3933", "#4c463f", "#5f5850"]   # brun éteint, presque gris
const R_SOL := ["#040505", "#090a0b", "#111214", "#191b1e", "#24272b", "#31353a", "#40444a", "#545960", "#70767d"]
const R_GIVRE := ["#464e62", "#55607b", "#697492", "#8089a6", "#98a1be", "#b6c0d6", "#cdd7ec"]   # DA « neige crépuscule » (jamais #ffffff)
const R_NEIGE := ["#6a7f9e", "#8397b3", "#a0b2c9", "#bdcbdc", "#dce5ef", "#f6f9fc"]
const R_GLACE := ["#06080b", "#0c1015", "#141a21", "#1d252f", "#28323e", "#36424f", "#4a5867", "#687a8a", "#93a5b3", "#c4d1da"]   # glace du lac : gris-bleu sombre, peu saturé
const R_GLACON := ["#252c36", "#36475a", "#56708a", "#8aa6ba", "#c3d6e2"]   # glace des glaçons et de la cascade : gris-bleu, peu saturé
const R_CRISTAL := ["#0e1322", "#1f2a44", "#3a4f74", "#4275b8", "#70b9ed", "#b6e4f8"]   # DA « cristal bleu »
const R_PEAU := ["#0e0a07", "#211710", "#3a291b", "#58402a", "#7a5b3d"]
const R_PAILLE := ["#2e2410", "#52411d", "#7a6530", "#a08a48", "#c4ae6c"]

static func _rampe(stops: Array, n := 10) -> Array:
	var res: Array = []
	for i in n:
		var t := float(i) / (n - 1) * (stops.size() - 1)
		var k := mini(int(t), stops.size() - 2)
		res.append(Color(stops[k]).lerp(Color(stops[k + 1]), t - k))
	return res

static func _ton(rampe: Array, v: float) -> Color:
	return rampe[clampi(int(v * rampe.size()), 0, rampe.size() - 1)]

static func _champ(type: int, freq: float, graine: int, taille := S, octaves := 4, fractal := FastNoiseLite.FRACTAL_FBM, retour := -1) -> PackedFloat32Array:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.seed = graine
	n.frequency = freq
	n.fractal_type = fractal
	n.fractal_octaves = octaves
	if retour >= 0:
		n.cellular_return_type = retour
		n.cellular_jitter = 1.0
	var img := n.get_seamless_image(taille, taille, false, false, 0.15, true)
	img.convert(Image.FORMAT_L8)
	var d := img.get_data()
	var res := PackedFloat32Array()
	res.resize(taille * taille)
	for i in res.size():
		res[i] = d[i] / 255.0
	return res

static func _g(c: PackedFloat32Array, x: int, y: int, taille := S) -> float:
	return c[posmod(y, taille) * taille + posmod(x, taille)]

## Relief éclairé par le haut-gauche : > 0 face à la lumière, < 0 à l'ombre.
static func _repoussoir(h: PackedFloat32Array, x: int, y: int, gain: float, taille := S) -> float:
	return (_g(h, x - 1, y - 1, taille) - _g(h, x + 1, y + 1, taille) + 0.5 * (_g(h, x - 1, y, taille) - _g(h, x + 1, y, taille))) * gain

static func _mix(a: PackedFloat32Array, b: PackedFloat32Array, t: float) -> PackedFloat32Array:
	var r := PackedFloat32Array()
	r.resize(a.size())
	for i in a.size():
		r[i] = lerpf(a[i], b[i], t)
	return r

## Chaîne de mipmaps : par bloc 2x2 on garde la couleur existante la plus proche de la moyenne (pas de teinte
## nouvelle), l'alpha est moyenné (les textures « seuil » en ont besoin).
static func mips_image(img: Image, grain := false) -> Image:
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
				var moy := (c[0] + c[1] + c[2] + c[3]) * 0.25
				var best := 0
				var bd := 1e9
				for k in 4:
					var d := (c[k].r - moy.r) * (c[k].r - moy.r) + (c[k].g - moy.g) * (c[k].g - moy.g) + (c[k].b - moy.b) * (c[k].b - moy.b)
					if d < bd:
						bd = d
						best = k
				if grain:     # passe 2 kit (roches) : un des 4 texels tiré au hasard, le moucheté reste visible au loin (pas de fondu vers le ton moyen)
					best = int(_hash_i(x * 7 + w * 13, y * 11 + h * 3) * 3.999)
				var r := c[best]
				r.a = moy.a
				nxt.set_pixel(x, y, r)
		data.append_array(nxt.get_data())
		cur = nxt
	return Image.create_from_data(img.get_width(), img.get_height(), true, Image.FORMAT_RGBA8, data)

# ------------------------------------------------------------------ roche granuleuse (brun-gris, mouchetée)
## Blocs fracturés (cellules de ~0,6 m) d'un ton chacun, fractures quasi noires bordées d'une lèvre claire en haut-gauche,
## nuages de teinte (brun / gris) qui changent de rampe, grain au texel sur ±1 à 2 tons (moucheté fin), rares éclats clairs.
## variante 0 = brun-gris (roche courante), 1 = gris froid (zones de glace), 2 = brun givré (entrée : plus d'éclats clairs).
static func roche_image(variante := 0) -> Image:
	var img := Image.create(SG, SG, false, Image.FORMAT_RGBA8)
	var RA := _rampe(R_ROCHE if variante != 1 else R_ROCHE_FROID, 12)
	var RB := _rampe(R_ROCHE_GRIS, 12)
	var gr := 31 + variante * 17
	var arete := _champ(FastNoiseLite.TYPE_CELLULAR, 0.016, 101 + gr, SG, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var amas := _champ(FastNoiseLite.TYPE_CELLULAR, 0.28, 121 + gr, SG, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_CELL_VALUE)
	var amas2 := _champ(FastNoiseLite.TYPE_CELLULAR, 0.12, 131 + gr, SG, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_CELL_VALUE)
	var nuage := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.008, 202 + gr, SG, 3)
	var teinte := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 303 + gr, SG, 3)
	var bosse := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.03, 404 + gr, SG, 3)
	var coupe := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 606 + gr, SG, 2)
	var h := PackedFloat32Array()
	h.resize(SG * SG)
	for i in h.size():
		h[i] = bosse[i] * 0.8 + minf(arete[i], 0.1) * 1.5 + amas2[i] * 0.06
	var eclats := 0.985 if variante != 2 else 0.975
	for y in SG:
		for x in SG:
			var i := y * SG + x
			# granit : amas de 2 à 4 px d'un ton (deux échelles), nuages lents, relief doux ; jamais de grands à-plats
			# passe 2 kit : plus de tons (moucheté fin au texel ±1 ton, faces du relief plus claires, fractures presque noires)
			var v := 0.6 + 0.22 * (nuage[i] - 0.5) + 0.2 * (amas[i] - 0.5) + 0.12 * (amas2[i] - 0.5)
			v += _repoussoir(h, x, y, 1.35, SG)
			v += 0.15 * (_hash_i(x, y + 977 * variante) - 0.5)
			var a := arete[i]
			if coupe[i] > 0.48:                                  # fractures interrompues
				if a < 0.018:
					v = 0.02 + 0.04 * amas[i]
				elif a < 0.04:
					v -= 0.16
			var hs := _hash_i((x / 2) * 3 + 11, (y / 2) * 5 + variante)
			if hs > eclats:
				v += 0.26                                         # éclat clair 2x2 (givre, mica)
			var R: Array = RA if teinte[i] + 0.2 * (amas2[i] - 0.5) > 0.5 else RB
			var c := _ton(R, clampf(v, 0.0, 0.999))
			if variante == 2 and hs > eclats:
				c = c.lerp(Color("#98a1be"), 0.45)
			img.set_pixel(x, y, c)
	return img

# ------------------------------------------------------------------ strates sédimentaires (brun-gris)
## Bancs horizontaux (0,1 à 0,35 m) aux rampes alternées (brun, gris, brun sombre), ondulés, lèvre claire en haut de chaque banc,
## ombre portée sous le bord, fissures verticales bornées aux joints, grain au texel.
static func strate_image() -> Image:
	var img := Image.create(SG, SG, false, Image.FORMAT_RGBA8)
	var rampes := [_rampe(R_ROCHE, 12), _rampe(R_BRUN, 12), _rampe(R_ROCHE_GRIS, 12), _rampe(R_ROCHE, 12), _rampe(R_BRUN, 12)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var onde := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.006, 11, SG, 3)
	var grain := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.4, 12, SG, 2)
	var bloc := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.025, 14, SG, 4)
	var amas := _champ(FastNoiseLite.TYPE_CELLULAR, 0.28, 15, SG, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_CELL_VALUE)
	var bancs: Array = []
	var y0 := 0
	while y0 < SG:
		var e := mini(rng.randi_range(13, 44), SG - y0)
		if SG - y0 - e < 12:
			e = SG - y0
		bancs.append([y0, e, rng.randi_range(0, 4), rng.randf_range(0.5, 0.68)])
		y0 += e
	var fiss: Array = []
	for b in bancs:
		var l: Array = []
		for k in rng.randi_range(1, 4):
			l.append(rng.randi_range(0, SG - 1))
		fiss.append(l)
	for y in SG:
		for x in SG:
			var i := y * SG + x
			var yy := posmod(y + int((onde[i] - 0.5) * 24.0), SG)
			var ib := 0
			for k in bancs.size():
				if yy >= bancs[k][0] and yy < bancs[k][0] + bancs[k][1]:
					ib = k
			var banc: Array = bancs[ib]
			var R: Array = rampes[banc[2]]
			var dans: int = yy - banc[0]
			var v: float = banc[3] + 0.22 * (bloc[i] - 0.5) + 0.14 * (amas[i] - 0.5) + 0.05 * (_hash_i(x, y + 31) - 0.5)
			v += 0.1 * (1.0 - float(dans) / banc[1]) - 0.05
			if dans == 0 and banc[0] > 0 and bloc[(i + 4099) % (SG * SG)] > 0.4:
				v = 0.1                                        # joint de banc : sombre, interrompu
			elif dans <= 2:
				v += 0.14                                      # lèvre claire du banc
			if dans >= banc[1] - 2:
				v -= 0.1                                       # ombre sous le surplomb
			for fx: int in fiss[ib]:
				var dx := posmod(x - fx - int((bloc[i] - 0.5) * 12.0), SG)
				if dx <= 1 and dans > 2 and dans < banc[1] - 1:
					v -= 0.3
				elif dx == 2 and dans > 2:
					v += 0.07
			if _hash_i(x * 7, y * 3 + 5) > 0.988:
				v += 0.26                                      # éclat clair
			img.set_pixel(x, y, _ton(R, clampf(v, 0.0, 0.999)))
	return img

# ------------------------------------------------------------------ sol de pierre et de gravier (sombre, humide)
static func sol_image(variante := 0) -> Image:
	var img := Image.create(SG, SG, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_SOL, 12)
	var RB := _rampe(R_BRUN, 12)
	var cel := _champ(FastNoiseLite.TYPE_CELLULAR, 0.05, 55 + variante, SG, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_CELL_VALUE)
	var arete := _champ(FastNoiseLite.TYPE_CELLULAR, 0.05, 55 + variante, SG, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var dalle := _champ(FastNoiseLite.TYPE_CELLULAR, 0.014, 59 + variante, SG, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var grain := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.5, 56 + variante, SG, 2)
	var tache := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.01, 57 + variante, SG, 3)
	var bosse := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.06, 58 + variante, SG, 3)
	var h := PackedFloat32Array()
	h.resize(SG * SG)
	for i in h.size():
		h[i] = bosse[i] * 0.4 + minf(arete[i], 0.1) * 3.0 + minf(dalle[i], 0.06) * 3.0
	for y in SG:
		for x in SG:
			var i := y * SG + x
			var v := 0.54 + 0.2 * (cel[i] - 0.5) + 0.2 * (tache[i] - 0.5) + 0.12 * (grain[i] - 0.5) + 0.06 * (_hash_i(x, y + 7) - 0.5)
			v += _repoussoir(h, x, y, 1.2, SG)
			var a := arete[i]
			if a < 0.05 and tache[(i + 9001) % (SG * SG)] > 0.6:
				v -= (0.05 - a) * 3.0                    # joint creux entre les cailloux (par endroits)
			if dalle[i] < 0.015 and tache[(i + 5003) % (SG * SG)] > 0.5:
				v = 0.08                                  # grande fissure de la dalle rocheuse (interrompue)
			var hs := _hash_i(x * 5 + 3, y * 7 + 1)
			if hs > 0.99:
				v += 0.25                                 # gravillon clair
			var c := _ton(RB if tache[i] > 0.62 else R, clampf(v, 0.0, 0.999))
			img.set_pixel(x, y, c)
	return img

# ------------------------------------------------------------------ givre (superposé : faces hautes, alpha = seuil)
## Croûte blanche granuleuse : tons blanc-bleuté sur 8 paliers, cristaux clairs au texel ; le seuil mélange un bruit moyen
## (plaques) et un grain fin (bord émietté, jamais un trait droit).
static func givre_image() -> Image:
	var img := Image.create(SG, SG, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_GIVRE, 10)
	var plaque := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 71, SG, 4)
	var fin := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.35, 72, SG, 2)
	var ton := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 73, SG, 3)
	for y in SG:
		for x in SG:
			var i := y * SG + x
			var v := 0.55 + 0.3 * (ton[i] - 0.5) + 0.2 * (fin[i] - 0.5) + 0.08 * (_hash_i(x, y + 3) - 0.5)
			if _hash_i(x * 3, y * 7 + 9) > 0.97:
				v = 0.97
			var c := _ton(R, clampf(v, 0.0, 0.999))
			c.a = clampf(0.25 + 0.55 * (1.0 - plaque[i]) + 0.4 * (fin[i] - 0.5) + 0.3 * (_hash_i(x + 5, y) - 0.5), 0.03, 0.97)
			img.set_pixel(x, y, c)
	return img

static func _net_rgb(img: Image) -> Image:
	var alpha := PackedFloat32Array()
	alpha.resize(img.get_width() * img.get_height())
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			alpha[y * img.get_width() + x] = c.a
			c.a = 1.0
			img.set_pixel(x, y, c)
	PeintureBati.nettoie(img, 2)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			c.a = alpha[y * img.get_width() + x]
			img.set_pixel(x, y, c)
	return img

static func _hash_i(a: int, b: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0

# ------------------------------------------------------------------ neige soufflée (superposée, alpha = seuil)
## Couleurs et rides du sol du lot 3 (SolTuiles.tuile_neige : crêtes, ombres froides, plaques calmes). L'alpha est le SEUIL
## de recouvrement : la neige s'accroche par BANDES horizontales (en haut des bancs de roche), bords nets, sans taches rondes.
## Seuil « bancs » : la couche s'accroche en bandes horizontales irrégulières (épaisseur et densité propres à chaque banc).
static func _seuil_bancs(x: int, y: int, onde: PackedFloat32Array, nuage: PackedFloat32Array, graine: int, taille := S) -> float:
	var k := float(taille) / S
	var i := y * taille + x
	var yy := float(y) + onde[i] * 22.0 * k
	var banc := int(floorf(yy / (16.0 * k)))
	var fy := fposmod(yy, 16.0 * k) / (16.0 * k)                         # 0 = haut du banc (joint), 1 = bas
	var hb := _hash_i(posmod(banc, 8), graine)
	return clampf(0.08 + 0.5 * fy * fy + 0.3 * hb + 0.28 * (nuage[i] - 0.4), 0.03, 0.97)

static func neige_image(sol_ := false) -> Image:
	var img := SolTuiles.image_couleur(SolTuiles.tuile_neige(0))
	var onde := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 74, S, 2)
	var nuage := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.03, 75, S, 3)
	var plaque := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.022, 76, S, 3)
	for y in S:
		for x in S:
			var c := img.get_pixel(x, y)
			if sol_:
				c.a = clampf(0.1 + 0.9 * plaque[y * S + x] * 1.1 - 0.05, 0.03, 0.97)   # plaques irrégulières au sol
				# couleurs EXACTES de la neige du sol extérieur (une seule neige de part et d'autre de la bouche)
			else:
				c.a = _seuil_bancs(x, y, onde, nuage, 3)
			img.set_pixel(x, y, c)
	return img


# ------------------------------------------------------------------ glace (lac gelé, et couche superposée sur la roche)
## Lac : glace noire-bleutée profonde (tons très sombres, désaturés), plaques d'un palier, rares fissures droites blanches
## bordées d'un creux, bulles et poussière de givre ; reflets en traînées fines. Superposée : vernis gris-bleu clair par plaques.
static func glace_image(superposee := false) -> Image:
	var T := 256        # 128 texels/m (tuile de 2 m)
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_GLACE, 12)
	var RG := _rampe(["#1e2023", "#2a2d31", "#363a3f", "#44484e", "#555a60", "#6c7177", "#8d9298"], 10)   # vernis de givre gris sombre (2e passe : la roche des cristaux reste anthracite, la lumière froide fait le bleu)
	var profond := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.008, 81, T, 3)
	var nuage := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.025, 86, T, 3)
	var fissure := _champ(FastNoiseLite.TYPE_CELLULAR, 0.009, 82, T, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var plaque := _champ(FastNoiseLite.TYPE_CELLULAR, 0.009, 82, T, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_CELL_VALUE)
	var presence := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 87, T, 2)
	var fin := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.3, 89, T, 2)
	var onde := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.008, 88, T, 2)
	for y in T:
		for x in T:
			var i := y * T + x
			var v: float
			if superposee:
				v = 0.4 + 0.2 * (nuage[i] - 0.5) + 0.14 * (fin[i] - 0.5) + 0.1 * (_hash_i(x, y) - 0.5)
			else:
				v = 0.30 + 0.3 * (profond[i] - 0.5) + 0.12 * (plaque[i] - 0.5) + 0.05 * (fin[i] - 0.5)
				var u := (float(x) + float(y) * 0.55 + onde[i] * 50.0) / 70.0
				var f := u - floorf(u)
				if _hash_i(int(floorf(u)), 91) > 0.55 and f < 0.02:
					v += 0.28                               # reflet : traînée oblique fine
				var fi := fissure[i]
				if presence[i] > 0.5:
					if fi < 0.006:
						v = 0.78                            # fissure blanche
					elif fi < 0.016:
						v -= 0.1
				if _hash_i(x * 3 + 1, y * 5 + 2) > 0.993:
					v += 0.35                               # bulle / poussière de givre
				if nuage[i] > 0.7:
					v += 0.12                               # voile de givre à la surface
			var c := _ton(RG if superposee else R, clampf(v, 0.0, 0.999))
			c.a = clampf(0.45 + 0.6 * nuage[i] + 0.3 * (fin[i] - 0.5) + 0.2 * (_hash_i(x + 3, y) - 0.5), 0.03, 0.97) if superposee else 1.0
			img.set_pixel(x, y, c)
	return img

# ------------------------------------------------------------------ glaçons et cascades gelées (tuile 1 m = 128 px)
## Coulures verticales : bandes étroites (2 à 6 px) de tons blanc-bleuté, cœur plus sombre, filets clairs, bulles.
static func glacon_image() -> Image:
	var T := 128
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_GLACON, 10)
	var onde := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 121, T, 2)
	var fin := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.25, 122, T, 2)
	for y in T:
		for x in T:
			var i := y * T + x
			var u := float(x) + (onde[i] - 0.5) * 10.0
			var bande := int(floorf(u / 5.0))
			var f := fposmod(u, 5.0) / 5.0
			var v := 0.35 + 0.4 * _hash_i(posmod(bande, 64), 7) + 0.12 * (fin[i] - 0.5)
			if f < 0.2:
				v += 0.25                                   # filet clair
			elif f > 0.8:
				v -= 0.15
			if _hash_i(x * 5, y * 3) > 0.99:
				v = 0.98
			img.set_pixel(x, y, _ton(R, clampf(v, 0.0, 0.999)))
	return img

# ------------------------------------------------------------------ brume au sol (carte alpha, tuile 4 m = 128 px)
## Nappes de brume : paliers d'alpha nets (6 niveaux), bords rongés par un bruit fin ; le bord de la carte s'efface.
static func brume_image() -> Image:
	var T := 128
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var nappe := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 131, T, 4)
	var fin := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.2, 132, T, 2)
	for y in T:
		for x in T:
			var i := y * T + x
			var d := Vector2(float(x) - 63.5, float(y) - 63.5).length() / 64.0
			var a := clampf((nappe[i] - 0.35) * 1.6 + 0.15 * (fin[i] - 0.5), 0.0, 1.0) * clampf((1.0 - d) * 2.2, 0.0, 1.0)
			a = floorf(a * 6.0) / 6.0 * 0.38
			img.set_pixel(x, y, Color(0.72, 0.78, 0.86, a))
	return img

# ------------------------------------------------------------------ piste de la grotte (neige tassée, ornières, cailloux)
## Texture d'un ruban posé sur la neige : u = le long de la piste, v = en travers (centre à v = 0,5), 32 texels/m, tuile de 4 m.
## Neige tassée gris-bleu (plus sombre et plus brune que la neige vierge), deux ornières de 25 cm (creux sombre, lèvre claire
## côté lumière), pas de bottes espacés au centre, cailloux bruns et gravillons sur les bords, croûte de glace brillante par
## plaques. L'alpha est un SEUIL de bruit : le shader ne montre que les texels dont le seuil est sous le masque du sommet (bords
## tramés par bruit, jamais un trait droit).
const R_PISTE := ["#393b47", "#464e62", "#55607b", "#697492", "#8089a6", "#98a1be", "#cdd7ec"]   # neige tassée : rampe « neige crépuscule » de la DA
const R_PISTE_TERRE := ["#2a211b", "#3d3027", "#53443a", "#6b5a4b", "#8a7863"]
static func piste_image() -> Image:
	var img := Image.create(SG, SG, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_PISTE, 10)
	var T := _rampe(R_PISTE_TERRE, 8)
	var gros := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.018 / E, 301, SG, 3)
	var fin := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.2, 302, SG, 2)
	var plaque := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.04 / E, 303, SG, 3)
	var seuil := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.9, 304, SG, 1)
	var ride := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02 / E, 305, SG, 2)
	var h := PackedFloat32Array()
	h.resize(SG * SG)
	for y in SG:
		for x in SG:
			var lat := float(y - SG / 2) / (32.0 * E)                       # mètres en travers
			var d1 := absf(lat + 0.62 + (ride[y * SG + x] - 0.5) * 0.5)
			var d2 := absf(lat - 0.62 + (ride[y * SG + x] - 0.5) * 0.5)
			var orn := minf(d1, d2)
			h[y * SG + x] = (0.0 if orn > 0.17 else -(0.17 - orn) * 3.0 * clampf((ride[y * SG + x] - 0.3) * 4.0, 0.0, 1.0)) + 0.1 * gros[y * SG + x] + 0.04 * fin[y * SG + x]
	var pas_bottes: Array = []
	for k in 7:
		pas_bottes.append(Vector3(_hash_i(k, 11) * SG, (52.0 + (k % 2) * 24.0 + (_hash_i(k, 12) - 0.5) * 8.0) * E, _hash_i(k, 13)))
	for y in SG:
		for x in SG:
			var i := y * SG + x
			var lat := float(y - SG / 2) / (32.0 * E)
			var al := absf(lat)
			var v := 0.46 + 0.3 * (gros[i] - 0.5) + 0.16 * (fin[i] - 0.5) - 0.05 * al
			v += _repoussoir(h, x, y, 2.2 * E, SG)                         # ornières : lèvre claire en haut-gauche, creux en bas-droite
			var d1 := absf(lat + 0.62 + (ride[i] - 0.5) * 0.5)
			var d2 := absf(lat - 0.62 + (ride[i] - 0.5) * 0.5)
			var orn := minf(d1, d2)
			if orn < 0.07 and ride[i] > 0.4:
				v -= 0.12                                          # fond d'ornière : neige sale et tassée
			if plaque[i] > 0.7 and orn > 0.1:
				v += 0.2                                           # croûte de glace luisante, par plaques
			# empreintes de bottes : ovale creux, talon plus profond
			for b: Vector3 in pas_bottes:
				var dx := posmod(x - int(b.x) + SG / 2, SG) - SG / 2
				var dy := y - int(b.y)
				var e := (dx * dx) / (56.0 * E * E) + (dy * dy) / (14.0 * E * E)
				if e < 1.0 and b.z > 0.25:
					v -= 0.16 + (0.05 if dx < -3 * E else 0.0)
				elif e < 1.5 and b.z > 0.25 and dx - dy > 0:
					v += 0.08
			var c := _ton(R, clampf(v, 0.0, 0.999))
			# cailloux et terre dégelée vers les bords
			var terre := (fin[i] > 0.9 and al > 0.85) or (gros[i] < 0.09 and al > 0.6)
			if terre:
				c = _ton(T, clampf(0.35 + 0.5 * (fin[i] - 0.4) + 0.3 * (gros[i] - 0.3), 0.0, 0.999))
			var gr := _hash_i((x / 2) * 3, (y / 2) * 7 + 5)
			if gr > 0.996:
				c = _ton(T, 0.95 if gr > 0.993 else 0.1)             # gravillon clair / ombré
			c.a = clampf(0.5 + 1.3 * (seuil[i] - 0.5) + 0.12 * (_hash_i(x, y) - 0.5), 0.04, 0.96)
			img.set_pixel(x, y, c)
	return _net_rgb(img)

# ------------------------------------------------------------------ cristal lumineux (tuile 2 m = 128 px)
## Bandes obliques nettes de bleus (du bleu nuit au blanc bleuté), arêtes claires de 1 px, joints sombres, reflets isolés.
## Une seule famille de teinte (bleu froid lumineux des références) : plus de violet ni de cyan saturé.
static func cristal_image() -> Image:
	var T := 128
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_CRISTAL, 12)
	var onde := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.015, 61, T, 2)
	var grain := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.07, 62, T, 2)
	for y in T:
		for x in T:
			var i := y * T + x
			var u := (float(x) * 0.5 + float(y) * 0.5 + (onde[i] - 0.5) * 14.0) / 16.0
			var bande := int(floorf(u))
			var f := u - floorf(u)
			var hb := _hash_i(posmod(bande, 8), 17)
			var t := 1.5 + hb * 4.0 + 3.0 * (1.0 - f) + (grain[i] - 0.5) * 2.0
			if f < 0.06:
				t = 10.5
			elif f < 0.12:
				t += 1.4
			elif f > 0.94:
				t = 1.0
			if _hash_i(x / 2, y / 2 + 91) > 0.996:
				t = 11.0
			img.set_pixel(x, y, R[clampi(roundi(t), 0, 11)])
	return img

# ------------------------------------------------------------------ face de cristal (prismes hexagonaux, UV par face)
## u = travers de la face (0 -> 1), v = long du prisme (0 = pied, 1 = pointe ; l'image est retournée : y = 0 en haut = pointe).
## Dégradé interne bleu nuit (pied, enfoncé dans la roche) -> cyan pâle (pointe), arête claire d'1 texel à gauche,
## joint sombre à droite, inclusions et fêlures obliques, quelques reflets. 64 x 64 texels (carré : chaîne de mipmaps complète).
const R_CRISTAL_F := ["#05080f", "#09101c", "#0e182a", "#14223a", "#1a2b44", "#223853", "#2b4664", "#456c8f", "#80b0cf", "#c8e8f5"]   # corps bleu nuit, cyan pâle seulement en tête

## Grosses grappes éclairantes (4e passe, grottes_cryptes_6) : faces bleu vif, tête et arête blanc-cyan (jamais #ffffff).
const R_CRISTAL_V := ["#0b1830", "#122c56", "#1a4482", "#2460ad", "#327fd0", "#4c9ce6", "#6fb9f2", "#96d2f7", "#bde6fa", "#dcf4fc"]

static func cristal_face_image(vif := false) -> Image:
	var W := 64
	var H := 64
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_CRISTAL_V if vif else R_CRISTAL_F, 12)
	var onde := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.08, 64, 64, 2)
	for y in H:
		for x in W:
			var v := 1.0 - float(y) / float(H - 1)            # 0 au pied, 1 à la pointe
			var t := (pow(v, 2.2) * 9.0 + 0.5) if not vif else (3.2 + v * 6.0)
			t += (onde[(y % 64) * 64 + x] - 0.5) * 2.2
			var fel := fposmod(float(x) * 0.7 + float(y) * 0.45, 13.0)
			if fel < 0.8 and _hash_i(int((float(x) * 0.7 + float(y) * 0.45) / 13.0), 5) > 0.45:
				t += 1.6                                          # fêlure interne claire (oblique, interrompue)
			if x > W * 3 / 10 and x < W * 4 / 10:
				t += 1.8                                          # facette interne plus claire (reflet d'une face arrière)
			if x >= W - 2:
				t = minf(t, 1.0)                                  # joint sombre
			elif x <= 1:
				t = maxf(t + 3.0, 8.0)                            # arête claire d'un texel
			elif x <= 2:
				t += 1.0
			if _hash_i(x / 2, y / 2 + 37) > 0.992:
				t = 11.0
			img.set_pixel(x, y, R[clampi(roundi(t), 0, 11)])
	return img

# ------------------------------------------------------------------ planches de bois usées (caisses, chariots, étais)
## Tuile 64 x 64 = 1 m (64 texels/m) : planches horizontales de 16 px (25 cm), joint sombre d'un texel, veinage, nœuds,
## bords usés plus clairs, clous de fer aux deux bouts de chaque planche (tous les 50 cm), plaques de crasse.
const R_PLANCHE := ["#0a0807", "#15110d", "#211a14", "#2d241b", "#3a2f24", "#483b2d", "#574837", "#685843", "#7c6a52"]

static func planches_image() -> Image:
	var T := 64
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_PLANCHE, 12)
	var veine := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.06, 81, T, 3)
	var crasse := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 82, T, 2)
	for y in T:
		var pl := y / 16
		var yy := y % 16
		var base := 4.5 + _hash_i(pl, 3) * 2.5
		for x in T:
			var i := y * T + x
			var t := base
			t += sin((float(x) * 0.09 + veine[i] * 6.0 + float(yy) * 0.6) * 3.0) * 0.9      # veinage
			t += (_hash_i(x, y + 11) - 0.5) * 0.9
			if crasse[i] > 0.62:
				t -= 1.6
			if yy == 15:
				t = 0.0                                                                      # joint
			elif yy == 0 or yy == 14:
				t += 1.4 if _hash_i(x / 3, pl + 40) > 0.35 else -0.5                         # arête usée
			var xn := (x + pl * 9) % 32
			if (xn == 3 or xn == 4) and (yy == 5 or yy == 6 or yy == 9 or yy == 10):
				var c := Color("#5d6166") if (xn == 3 and (yy == 5 or yy == 9)) else Color("#22252a")
				img.set_pixel(x, y, c)                                                       # clou de fer (tête 2x2, reflet en haut-gauche)
				continue
			var nx := x - int(_hash_i(pl, 9) * 60.0)
			var ny := yy - 7
			if nx * nx + ny * ny * 4 < 9 and _hash_i(pl, 13) > 0.4:
				t = 1.5                                                                      # nœud
			img.set_pixel(x, y, R[clampi(roundi(t), 0, 11)])
	return img

# ------------------------------------------------------------------ peau, paille, or
static func peau_image() -> Image:
	var T := 64   # 64 texels/m (tuile de 1 m)
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_PEAU, 12)
	var poil := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.14, 41, T, 3)
	var tache := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.025, 42, T, 2)
	for y in T:
		for x in T:
			var i := y * T + x
			var strie := sin(float(x) * 0.85 + poil[i] * 6.0) * 0.5 + 0.5
			var v := 0.25 + 0.34 * poil[i] + 0.18 * (tache[i] - 0.5) + 0.2 * strie * 0.5
			img.set_pixel(x, y, _ton(R, clampf(v, 0.0, 0.999)))
	return PeintureBati.nettoie(img, 3)

static func paille_image() -> Image:
	var T := 64   # 64 texels/m
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_PAILLE, 12)
	var bruit := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.1, 43, T, 2)
	for y in T:
		for x in T:
			var i := y * T + x
			var brin := sin(float(x) * 0.45 + float(y) * 0.17 + bruit[i] * 4.0) * 0.5 + 0.5
			var v := 0.2 + 0.55 * brin + 0.2 * (bruit[i] - 0.5)
			if posmod(x + y * 3, 17) == 0 and posmod(x, 2) == 0:
				v -= 0.25
			img.set_pixel(x, y, _ton(R, clampf(v, 0.0, 0.999)))
	return PeintureBati.nettoie(img, 3)

# ------------------------------------------------------------------ jour (vue vers l'extérieur) et ciel de la faille
## 256 x 128 : épaisse brume blanche de tempête (rubans de vent par paliers de 8 tons, plus denses en bas) ; de très vagues
## masses gris-bleu (arbres, relief) y affleurent à peine. Sans éclairage : la bouche de la grotte s'ouvre sur la tempête.
static func jour_image() -> Image:
	var W := 256
	var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var R := _rampe(["#8499b8", "#9aaecb", "#b3c3d9", "#c9d6e6", "#dce6f1", "#eef3f9"], 8)
	var ruban := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.008, 21, 256, 4)
	var fin := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 22, 256, 3)
	var masse := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 23, 256, 3)
	for y in H:
		for x in W:
			var i := y * 256 + x
			var t := float(y) / H
			var band := sin((float(y) * 0.5 + ruban[i] * 16.0) * 0.55 + fin[i] * 3.0) * 0.5 + 0.5   # rubans de vent
			var v := 0.40 + 0.22 * t + 0.20 * (band - 0.5) + 0.18 * (fin[i] - 0.5)
			if t > 0.45 and masse[i] > 0.58 + (0.55 - t) * 0.4:
				v -= 0.17                                                 # masse lointaine, noyée dans la brume
			img.set_pixel(x, y, R[clampi(int(v * 8.0), 0, 7)])
	return img

static func ciel_faille_image() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var ciel := _rampe(["#cfe0f2", "#f0f7fd", "#ffffff"], 6)
	var b := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.2, 23, 16, 2)
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, _ton(ciel, 0.4 + 0.6 * b[y * 16 + x]))
	return img

## Rai de lumière froid, additif : coupe en travers, quelques paliers, poussière de givre.
static func rai_image() -> Image:
	var W := 32
	var H := 64
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var bruit := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.18, 24, 64, 2)
	for y in H:
		for x in W:
			var dx := absf(float(x) - 15.5) / 16.0
			var a := 0.0
			if dx < 0.3:
				a = 0.17
			elif dx < 0.55:
				a = 0.11
			elif dx < 0.78:
				a = 0.06
			elif dx < 0.95:
				a = 0.025
			a *= 0.55 + 0.45 * float(y) / (H - 1)                # plus intense vers le sol (y grandit vers le bas)
			a *= (0.8 + 0.5 * bruit[y * 64 + x % 64]) * 0.6
			a = floorf(a * 80.0) / 80.0
			img.set_pixel(x, y, Color(0.68, 0.82, 1.0, a))
	return img

## Flaque de lumière froide sur la glace : cercle à anneaux nets, bords rongés par un bruit.
static func flaque_image() -> Image:
	var T := 64
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var b := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.15, 25, T, 2)
	for y in T:
		for x in T:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0 + (b[y * T + x] - 0.5) * 0.2
			var a := 0.0
			var c := Color("#e6f6ff")
			if d < 0.25:
				a = 0.5
			elif d < 0.45:
				a = 0.32
				c = Color("#cde9ff")
			elif d < 0.68:
				a = 0.17
				c = Color("#9fcfff")
			elif d < 0.92:
				a = 0.07
				c = Color("#7fb6f0")
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return img

static func image(nom: String) -> Image:
	match nom:
		"roche": return roche_image(0)
		"roche_b": return roche_image(1)
		"roche_givre": return roche_image(2)
		"strate": return strate_image()
		"sol": return sol_image(0)
		"givre": return givre_image()
		"neige": return neige_image()
		"neige_sol": return neige_image(true)
		"glace": return glace_image(false)
		"glace_sup": return glace_image(true)
		"glacon": return glacon_image()
		"brume": return brume_image()
		"piste": return piste_image()
		"cristal": return cristal_image()
		"cristal_f": return cristal_face_image()
		"cristal_v": return cristal_face_image(true)
		"planches": return planches_image()
		"peau": return peau_image()
		"paille": return paille_image()
		"jour": return jour_image()
		"ciel": return ciel_faille_image()
		"rai": return rai_image()
		"flaque": return flaque_image()
	return roche_image(0)
