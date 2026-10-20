class_name GrotteTextures
## Textures de la grotte vitrine : roche, strates, sol, neige, glace, mousse, cristal, jour, rai, peau, paille.
## Principe « réalisme 32 bits » : chaque matière est calculée comme un CHAMP de hauteur tuilable (bruits fractals,
## crêtes, cellules), puis éclairée au repoussé (lumière haut-gauche), assombrie dans les fissures (AO peinte) et
## quantifiée sur une rampe de 10 tons désaturés (froids dans l'ombre, un peu chauds dans la lumière).
## Densité : 32 texels/m (tuile de 128 px = 4 m). Les textures « superposées » (neige, glace, mousse) portent dans le
## canal alpha un SEUIL : le shader les montre là où le masque de sommet dépasse ce seuil (bords déchiquetés au texel).
## Fonctions pures : utilisables dans des fils d'exécution. Les rampes ne changent pas la palette de la bible, elles l'étendent.

const S := 128

# bornes de rampe (sombre -> clair) ; 10 tons par interpolation, tirage de teinte froid -> chaud
const R_ROCHE := ["#0b0e14", "#1b212c", "#2d3646", "#47536a", "#6f7c90", "#a3adbb"]
const R_ROCHE_B := ["#0d0e12", "#1c1e24", "#2f3239", "#4a4d55", "#6f727a", "#a0a2a8"]
const R_GIVRE := ["#1e2738", "#2f3b54", "#4a5a78", "#70829f", "#9bacc4", "#c9d6e6"]
const R_BRUN := ["#0d0a08", "#1f1813", "#3a2e24", "#5c4b3a", "#85735b", "#b09c80"]
const R_ARDOISE := ["#0b0f12", "#171e22", "#293237", "#434f54", "#697679", "#9ba8aa"]
const R_SOL := ["#100f0f", "#211e1c", "#3b3530", "#5d5247", "#887866", "#b2a38e"]
const R_NEIGE := ["#6a7f9e", "#8397b3", "#a0b2c9", "#bdcbdc", "#dce5ef", "#f6f9fc"]
const R_GLACE := ["#0a1d30", "#12365a", "#215685", "#41799f", "#76a5c6", "#b4d2e4", "#e6f2f9"]
const R_MOUSSE := ["#0a110d", "#131f18", "#1f3226", "#2e4838", "#425d3e", "#5a774c"]
const R_CRISTAL := ["#0b2f73", "#1560bf", "#2f93e6", "#74c9f7", "#c4f0ff", "#ffffff"]
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
static func mips_image(img: Image) -> Image:
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
				var r := c[best]
				r.a = moy.a
				nxt.set_pixel(x, y, r)
		data.append_array(nxt.get_data())
		cur = nxt
	return Image.create_from_data(img.get_width(), img.get_height(), true, Image.FORMAT_RGBA8, data)

# ------------------------------------------------------------------ roche massive fracturée (pixel art net)
## Grandes facettes plates (cellules de ~1,5 m), chacune d'UN ton ; bancs horizontaux qui décalent le ton d'un cran ;
## fractures de 1 px (ligne sombre, lèvre claire d'un côté, creux d'un cran plus sombre de l'autre) ; quelques amas de
## 2x2 éclats. Pas de grain : uniquement des aplats et des arêtes. 10 tons, utilisés entre 2 et 8.
## variante 0 = ardoise bleue, 1 = gris neutre, 2 = roche givrée (claire, pour l'entrée).
static func roche_image(variante := 0) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_ROCHE if variante == 0 else (R_ROCHE_B if variante == 1 else R_GIVRE))
	var gr := 31 + variante * 17
	var cel := _champ(FastNoiseLite.TYPE_CELLULAR, 0.024, 101 + gr, S, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_CELL_VALUE)
	var arete := _champ(FastNoiseLite.TYPE_CELLULAR, 0.024, 101 + gr, S, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var onde := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 202 + gr, S, 2)
	var amas := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 404 + gr, S, 3)
	var eclat := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.09, 505 + gr, S, 1)
	var h := PackedFloat32Array()
	h.resize(S * S)
	for i in h.size():
		h[i] = float(int(cel[i] * 5.0)) / 5.0 + arete[i] * 0.25    # pente des facettes : seul le bord éclaire
	var base := 4.6 if variante != 2 else 5.4
	for y in S:
		for x in S:
			var i := y * S + x
			var t := base + float(int(cel[i] * 4.0)) * 0.8 - 1.2     # un ton par facette (4 niveaux)
			t += float(int((amas[i] - 0.5) * 4.0))                    # grands nuages, par paliers d'un ton
			var off := onde[i] * 22.0
			var yy := float(y) + off
			var banc := int(floorf(yy / 16.0))
			var fy := fposmod(yy, 16.0)
			var hb := _hash_i(posmod(banc, 8), 3 + variante)
			t += (-1.0 if hb < 0.3 else (1.0 if hb > 0.72 else 0.0))   # bancs : décalage d'un ton
			if fy < 1.0 and hb > 0.2:
				t -= 2.0                                               # joint de banc
			elif fy < 2.0 and hb > 0.2:
				t += 1.0                                               # lèvre claire sous le joint
			var a := arete[i]
			if a < 0.035:
				t = base - 2.6                                         # fracture
			elif a < 0.075:
				var rp := _repoussoir(h, x, y, 4.0)
				t += 1.0 if rp > 0.0 else -1.0                         # lèvre claire en haut-gauche, creux sombre en bas-droite
			if eclat[i] > 0.82:
				t += 1.0                                               # amas d'éclats clairs
			elif eclat[i] < 0.13:
				t -= 1.0
			img.set_pixel(x, y, R[clampi(roundi(t), 1, 8)])
	return img

static func _hash_i(a: int, b: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0

# ------------------------------------------------------------------ strates sédimentaires
## Bandes horizontales (0,15 à 0,6 m) de teintes différentes (gris, brun, ardoise), ondulées, lèvre claire en haut de chaque
## banc, ombre sous le bord, fissures verticales qui s'arrêtent aux joints de bancs, éboulis fin.
static func strate_image() -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var rampes := [_rampe(R_ROCHE), _rampe(R_BRUN), _rampe(R_ARDOISE), _rampe(R_ROCHE), _rampe(R_BRUN)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var onde := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 11, S, 3)
	var grain := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.3, 12, S, 3)
	var bloc := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 14, S, 4)
	var bancs: Array = []
	var y0 := 0
	while y0 < S:
		var e := mini(rng.randi_range(6, 22), S - y0)
		if S - y0 - e < 6:
			e = S - y0
		bancs.append([y0, e, rng.randi_range(0, 4), rng.randf_range(0.30, 0.52)])
		y0 += e
	# fissures verticales : par banc, 1 à 3 positions en x
	var fiss: Array = []
	for b in bancs:
		var l: Array = []
		for k in rng.randi_range(1, 3):
			l.append(rng.randi_range(0, S - 1))
		fiss.append(l)
	for y in S:
		for x in S:
			var i := y * S + x
			var yy := posmod(y + int((onde[i] - 0.5) * 12.0), S)      # bancs ondulés
			var ib := 0
			for k in bancs.size():
				if yy >= bancs[k][0] and yy < bancs[k][0] + bancs[k][1]:
					ib = k
			var banc: Array = bancs[ib]
			var R: Array = rampes[banc[2]]
			var dans: int = yy - banc[0]
			var v: float = banc[3] + 0.26 * (bloc[i] - 0.5) + 0.18 * (grain[i] - 0.5)
			v += 0.12 * (1.0 - float(dans) / banc[1]) - 0.05          # haut éclairé, bas sombre
			if dans == 0 and banc[0] > 0:
				v -= 0.14
			elif dans == 1:
				v += 0.2                                               # lèvre claire du banc
			elif dans == 2:
				v += 0.07
			if dans >= banc[1] - 2:
				v -= 0.13                                              # ombre portée sous le surplomb
			for fx: int in fiss[ib]:
				var dx := posmod(x - fx - int((bloc[i] - 0.5) * 6.0), S)
				if dx == 0 and dans > 1 and dans < banc[1] - 1:
					v -= 0.28
				elif dx == 1 and dans > 1:
					v += 0.08
			if grain[i] > 0.9:
				v += 0.1
			img.set_pixel(x, y, _ton(R, clampf(v, 0.0, 0.999)))
	return img

# ------------------------------------------------------------------ sol de pierre et de gravier
static func sol_image(variante := 0) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_SOL)
	var cel := _champ(FastNoiseLite.TYPE_CELLULAR, 0.05, 55 + variante, S, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_CELL_VALUE)
	var arete := _champ(FastNoiseLite.TYPE_CELLULAR, 0.05, 55 + variante, S, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var grain := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.45, 56 + variante, S, 2)
	var tache := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 57 + variante, S, 3)
	var bosse := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.07, 58 + variante, S, 3)
	var h := _mix(bosse, arete, 0.5)
	for y in S:
		for x in S:
			var i := y * S + x
			var v := 0.34 + 0.22 * (cel[i] - 0.5) + 0.2 * (tache[i] - 0.5) + 0.12 * (grain[i] - 0.5)
			v += _repoussoir(h, x, y, 1.1)
			var a := arete[i]
			if a < 0.09:
				v -= (0.09 - a) * 5.0                    # joint creux entre les cailloux
			if grain[i] > 0.88:
				v += 0.14                                 # gravillon clair
			elif grain[i] < 0.1:
				v -= 0.1
			img.set_pixel(x, y, _ton(R, clampf(v, 0.0, 0.999)))
	return img

# ------------------------------------------------------------------ neige soufflée (superposée, alpha = seuil)
## Couleurs et rides du sol du lot 3 (SolTuiles.tuile_neige : crêtes, ombres froides, plaques calmes). L'alpha est le SEUIL
## de recouvrement : la neige s'accroche par BANDES horizontales (en haut des bancs de roche), bords nets, sans taches rondes.
## Seuil « bancs » : la couche s'accroche en bandes horizontales irrégulières (épaisseur et densité propres à chaque banc).
static func _seuil_bancs(x: int, y: int, onde: PackedFloat32Array, nuage: PackedFloat32Array, graine: int) -> float:
	var i := y * S + x
	var yy := float(y) + onde[i] * 22.0
	var banc := int(floorf(yy / 16.0))
	var fy := fposmod(yy, 16.0) / 16.0                         # 0 = haut du banc (joint), 1 = bas
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
				c = c.lerp(Color("#d4deec"), 0.42)                                       # sol : tons resserrés, moins de camouflage
			else:
				c.a = _seuil_bancs(x, y, onde, nuage, 3)
			img.set_pixel(x, y, c)
	return img

# ------------------------------------------------------------------ glace (base du lac et superposée)
static func glace_image(superposee := false) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_GLACE)
	var profond := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 81, S, 3)
	var nuage := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.04, 86, S, 2)
	var fissure := _champ(FastNoiseLite.TYPE_CELLULAR, 0.02, 82, S, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var plaque := _champ(FastNoiseLite.TYPE_CELLULAR, 0.02, 82, S, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_CELL_VALUE)
	var presence := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.03, 87, S, 2)
	var bulle := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.25, 83, S, 1)
	var fin := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.11, 89, S, 3)
	var onde := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.015, 88, S, 2)
	var h := _mix(profond, fissure, 0.15)
	for y in S:
		for x in S:
			var i := y * S + x
			# glace lisible : grands plans de ton (une plaque = un palier), pas de grain fin
			var v := 0.46 + 0.5 * (profond[i] - 0.5) + 0.2 * (plaque[i] - 0.5) + 0.1 * (nuage[i] - 0.5) + 0.2 * (fin[i] - 0.5)
			v += _repoussoir(h, x, y, 0.7)
			# reflets nets : traînées obliques fines (2 px), claires, interrompues ; un liseré sombre juste dessous
			var u := (float(x) + float(y) * 0.6 + onde[i] * 30.0) / 42.0
			var f := u - floorf(u)
			var br := _hash_i(int(floorf(u)), 91)
			if br > 0.35:
				if f < 0.035:
					v = 0.93
				elif f < 0.05:
					v = maxf(v, 0.78)
				elif f > 0.052 and f < 0.07:
					v -= 0.12
			var fi := fissure[i]
			if presence[i] > 0.55:                         # fissures : filet de givre clair bordé d'un creux bleu nuit
				if fi < 0.012:
					v = 0.8
				elif fi < 0.03:
					v -= 0.22
			if bulle[i] > 0.94 and presence[i] < 0.5:
				v = 0.88                                    # bulle emprisonnée (rare, isolée)
			var c := _ton(R, clampf(v, 0.0, 0.999))
			c.a = clampf(0.04 + 0.4 * nuage[i] + 0.25 * (onde[i] - 0.3), 0.03, 0.6) if superposee else 1.0
			img.set_pixel(x, y, c)
	return img

# ------------------------------------------------------------------ mousse (superposée)
static func mousse_image() -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_MOUSSE)
	var touffe := _champ(FastNoiseLite.TYPE_CELLULAR, 0.12, 91, S, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_DISTANCE)
	var grain := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.4, 92, S, 2)
	var seuil := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.04, 93, S, 4)
	var tache := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.03, 94, S, 3)
	for y in S:
		for x in S:
			var i := y * S + x
			var v := 0.30 + 0.5 * (1.0 - touffe[i]) * 0.7 + 0.22 * (tache[i] - 0.5) + 0.12 * (grain[i] - 0.5)
			v += _repoussoir(touffe, x, y, -1.2)
			var c := _ton(R, clampf(v, 0.0, 0.999))
			c.a = _seuil_bancs(x, y, tache, seuil, 9)
			img.set_pixel(x, y, c)
	return img

# ------------------------------------------------------------------ piste de la grotte (neige tassée, ornières, cailloux)
## Texture d'un ruban posé sur la neige : u = le long de la piste, v = en travers (centre à v = 0,5), 32 texels/m, tuile de 4 m.
## Neige tassée gris-bleu (plus sombre et plus brune que la neige vierge), deux ornières de 25 cm (creux sombre, lèvre claire
## côté lumière), pas de bottes espacés au centre, cailloux bruns et gravillons sur les bords, croûte de glace brillante par
## plaques. L'alpha est un SEUIL de bruit : le shader ne montre que les texels dont le seuil est sous le masque du sommet (bords
## tramés par bruit, jamais un trait droit).
const R_PISTE := ["#566074", "#6c778c", "#8590a6", "#9ea9bf", "#b6c1d4", "#cdd7e6", "#e4ebf4"]
const R_PISTE_TERRE := ["#2a211b", "#3d3027", "#53443a", "#6b5a4b", "#8a7863"]
static func piste_image() -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_PISTE, 10)
	var T := _rampe(R_PISTE_TERRE, 8)
	var gros := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.018, 301, S, 3)
	var fin := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.35, 302, S, 2)
	var plaque := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.04, 303, S, 3)
	var seuil := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.9, 304, S, 1)
	var ride := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 305, S, 2)
	var h := PackedFloat32Array()
	h.resize(S * S)
	for y in S:
		for x in S:
			var lat := float(y - 64) / 32.0                       # mètres en travers
			var d1 := absf(lat + 0.62 + (ride[y * S + x] - 0.5) * 0.5)
			var d2 := absf(lat - 0.62 + (ride[y * S + x] - 0.5) * 0.5)
			var orn := minf(d1, d2)
			h[y * S + x] = (0.0 if orn > 0.17 else -(0.17 - orn) * 3.0 * clampf((ride[y * S + x] - 0.3) * 4.0, 0.0, 1.0)) + 0.1 * gros[y * S + x] + 0.04 * fin[y * S + x]
	var pas_bottes: Array = []
	for k in 7:
		pas_bottes.append(Vector3(_hash_i(k, 11) * S, 52.0 + (k % 2) * 24.0 + (_hash_i(k, 12) - 0.5) * 8.0, _hash_i(k, 13)))
	for y in S:
		for x in S:
			var i := y * S + x
			var lat := float(y - 64) / 32.0
			var al := absf(lat)
			var v := 0.46 + 0.3 * (gros[i] - 0.5) + 0.16 * (fin[i] - 0.5) - 0.05 * al
			v += _repoussoir(h, x, y, 2.2)                         # ornières : lèvre claire en haut-gauche, creux en bas-droite
			var d1 := absf(lat + 0.62 + (ride[i] - 0.5) * 0.5)
			var d2 := absf(lat - 0.62 + (ride[i] - 0.5) * 0.5)
			var orn := minf(d1, d2)
			if orn < 0.07 and ride[i] > 0.4:
				v -= 0.12                                          # fond d'ornière : neige sale et tassée
			if plaque[i] > 0.7 and orn > 0.1:
				v += 0.2                                           # croûte de glace luisante, par plaques
			# empreintes de bottes : ovale creux, talon plus profond
			for b: Vector3 in pas_bottes:
				var dx := posmod(x - int(b.x) + S / 2, S) - S / 2
				var dy := y - int(b.y)
				var e := (dx * dx) / 56.0 + (dy * dy) / 14.0
				if e < 1.0 and b.z > 0.25:
					v -= 0.16 + (0.05 if dx < -3 else 0.0)
				elif e < 1.5 and b.z > 0.25 and dx - dy > 0:
					v += 0.08
			var c := _ton(R, clampf(v, 0.0, 0.999))
			# cailloux et terre dégelée vers les bords
			var terre := (fin[i] > 0.84 and al > 0.8) or (gros[i] < 0.16 and al > 0.5)
			if terre:
				c = _ton(T, clampf(0.35 + 0.5 * (fin[i] - 0.4) + 0.3 * (gros[i] - 0.3), 0.0, 0.999))
			var gr := _hash_i(x * 3, y * 7 + 5)
			if gr > 0.992:
				c = _ton(T, 0.95 if gr > 0.993 else 0.1)             # gravillon clair / ombré
			c.a = clampf(0.5 + 1.3 * (seuil[i] - 0.5) + 0.12 * (_hash_i(x, y) - 0.5), 0.04, 0.96)
			img.set_pixel(x, y, c)
	return img

# ------------------------------------------------------------------ cristal de glace (tuile 2 m = 64 px)
## Bandes obliques NETTES de 4 couleurs froides (cyan, bleu, violet froid, blanc bleuté), arêtes claires de 1 px,
## quelques reflets blancs isolés ; chaque bande est un aplat de 2 à 3 tons.
const R_CYAN := ["#06394f", "#0c6c86", "#1fa6bf", "#5fdbe6", "#b5f6f8", "#ffffff"]
const R_VIOLET := ["#1a1c5e", "#31318f", "#5a54c4", "#8d86e6", "#c5c0fa", "#ffffff"]
static func cristal_image() -> Image:
	var T := 64
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var rampes := [_rampe(R_CRISTAL, 8), _rampe(R_CYAN, 8), _rampe(R_VIOLET, 8), _rampe(R_CRISTAL, 8)]
	var onde := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.03, 61, T, 2)
	for y in T:
		for x in T:
			var i := y * T + x
			var u := (float(x) * 0.5 + float(y) * 0.5 + (onde[i] - 0.5) * 7.0) / 8.0   # une bande tous les 8 px en diagonale
			var bande := int(floorf(u))
			var f := u - floorf(u)
			var R: Array = rampes[posmod(bande, 4)]
			var hb := _hash_i(posmod(bande, 8), 17)
			var t := 2.5 + hb * 3.0 + 1.6 * (1.0 - f)                     # dégradé par paliers dans la bande
			if f < 0.1:
				t = 7.0                                                    # arête claire
			elif f > 0.9:
				t = 1.0                                                    # joint sombre
			if _hash_i(x, y + 91) > 0.992:
				t = 7.0                                                    # reflet isolé
			img.set_pixel(x, y, R[clampi(roundi(t), 0, 7)])
	return img

# ------------------------------------------------------------------ peau, paille, or
static func peau_image() -> Image:
	var T := 32
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_PEAU, 8)
	var poil := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.28, 41, T, 3)
	var tache := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 42, T, 2)
	for y in T:
		for x in T:
			var i := y * T + x
			var strie := sin(float(x) * 1.7 + poil[i] * 6.0) * 0.5 + 0.5
			var v := 0.25 + 0.34 * poil[i] + 0.18 * (tache[i] - 0.5) + 0.2 * strie * 0.5
			img.set_pixel(x, y, _ton(R, clampf(v, 0.0, 0.999)))
	return img

static func paille_image() -> Image:
	var T := 32
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_PAILLE, 8)
	var bruit := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.2, 43, T, 2)
	for y in T:
		for x in T:
			var i := y * T + x
			var brin := sin(float(x) * 0.9 + float(y) * 0.35 + bruit[i] * 4.0) * 0.5 + 0.5
			var v := 0.2 + 0.55 * brin + 0.2 * (bruit[i] - 0.5)
			if posmod(x + y * 3, 11) == 0:
				v -= 0.25
			img.set_pixel(x, y, _ton(R, clampf(v, 0.0, 0.999)))
	return img

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
			a *= 0.8 + 0.5 * bruit[y * 64 + x % 64]
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
		"neige": return neige_image()
		"neige_sol": return neige_image(true)
		"glace": return glace_image(false)
		"glace_sup": return glace_image(true)
		"mousse": return mousse_image()
		"piste": return piste_image()
		"cristal": return cristal_image()
		"peau": return peau_image()
		"paille": return paille_image()
		"jour": return jour_image()
		"ciel": return ciel_faille_image()
		"rai": return rai_image()
		"flaque": return flaque_image()
	return roche_image(0)
