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
const R_BRUN := ["#0d0a08", "#1f1813", "#3a2e24", "#5c4b3a", "#85735b", "#b09c80"]
const R_ARDOISE := ["#0b0f12", "#171e22", "#293237", "#434f54", "#697679", "#9ba8aa"]
const R_SOL := ["#100f0f", "#211e1c", "#3b3530", "#5d5247", "#887866", "#b2a38e"]
const R_NEIGE := ["#6a7f9e", "#8397b3", "#a0b2c9", "#bdcbdc", "#dce5ef", "#f6f9fc"]
const R_GLACE := ["#0a1d30", "#12365a", "#215685", "#41799f", "#76a5c6", "#b4d2e4", "#e6f2f9"]
const R_MOUSSE := ["#08120b", "#11231a", "#1d3a26", "#2f5530", "#46763a", "#688f4e"]
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

# ------------------------------------------------------------------ roche massive fracturée
## Facettes (cellules) éclairées chacune sous un angle différent, fissures sombres aux jonctions, grain fin,
## taches minérales, éclats clairs sur les arêtes du haut. 10 tons bleu-gris.
static func roche_image(variante := 0) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_ROCHE if variante == 0 else R_ROCHE_B)
	var gr := 31 + variante * 17
	var cel := _champ(FastNoiseLite.TYPE_CELLULAR, 0.045, 101 + gr, S, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_CELL_VALUE)
	var arete := _champ(FastNoiseLite.TYPE_CELLULAR, 0.045, 101 + gr, S, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var relief := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.028, 202 + gr, S, 5, FastNoiseLite.FRACTAL_RIDGED)
	var grain := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.32, 303 + gr, S, 2)
	var tache := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 404 + gr, S, 3)
	var h := _mix(relief, arete, 0.45)
	for y in S:
		for x in S:
			var i := y * S + x
			var facette := cel[i]                         # ton propre à chaque éclat
			var v := 0.30 + 0.34 * facette + 0.20 * (tache[i] - 0.5) + 0.07 * (grain[i] - 0.5)
			v += _repoussoir(h, x, y, 1.3)
			v += 0.16 * (relief[i] - 0.45)
			var a := arete[i]
			if a < 0.07:
				v -= (0.07 - a) * 5.5                    # fissure : AO peinte au pied des facettes
			elif a < 0.14 and _repoussoir(h, x, y, 1.0) > 0.03:
				v += 0.10                                # lèvre claire de l'arête haute
			if grain[i] > 0.93:
				v += 0.12                                # éclat minéral
			img.set_pixel(x, y, _ton(R, clampf(v, 0.0, 0.999)))
	return img

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
static func neige_image() -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_NEIGE)
	var onde := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 71, S, 3)
	var dune := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 72, S, 2)
	var grain := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.5, 73, S, 2)
	var seuil := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 74, S, 4)
	var h := PackedFloat32Array()
	h.resize(S * S)
	for y in S:
		for x in S:
			# rides de vent : sinus déformé, crête douce
			var r := sin((float(y) * 0.42 + onde[y * S + x] * 9.0 + dune[y * S + x] * 6.0)) * 0.5 + 0.5
			h[y * S + x] = r * 0.55 + dune[y * S + x] * 0.45
	for y in S:
		for x in S:
			var i := y * S + x
			var v := 0.62 + 0.40 * _repoussoir(h, x, y, 1.0) + 0.12 * (dune[i] - 0.5) + 0.05 * (grain[i] - 0.5)
			if grain[i] > 0.95:
				v = 1.0                                   # paillette
			var c := _ton(R, clampf(v, 0.0, 0.999))
			c.a = clampf(seuil[i] * 0.9 + 0.05, 0.02, 0.98)
			img.set_pixel(x, y, c)
	return img

# ------------------------------------------------------------------ glace (base du lac et superposée)
static func glace_image(superposee := false) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_GLACE)
	var profond := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.016, 81, S, 4)
	var nuage := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 86, S, 3)
	var fissure := _champ(FastNoiseLite.TYPE_CELLULAR, 0.026, 82, S, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var plaque := _champ(FastNoiseLite.TYPE_CELLULAR, 0.026, 82, S, 1, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.RETURN_CELL_VALUE)
	var presence := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.03, 87, S, 2)
	var bulle := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.3, 83, S, 1)
	var grain := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.5, 84, S, 2)
	var seuil := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 85, S, 4)
	var h := _mix(profond, fissure, 0.2)
	for y in S:
		for x in S:
			var i := y * S + x
			var v := 0.42 + 0.42 * (profond[i] - 0.45) + 0.16 * (nuage[i] - 0.5) + 0.06 * (plaque[i] - 0.5) + 0.05 * (grain[i] - 0.5)
			v += _repoussoir(h, x, y, 0.6)
			var f := fissure[i]
			if presence[i] > 0.56:                         # toutes les cassures ne se voient pas
				if f < 0.028:
					v = 0.74                               # givre dans la cassure
				elif f < 0.06:
					v -= 0.1                               # lèvre sombre
			if bulle[i] > 0.93:
				v = 0.86 if bulle[i] > 0.965 else v - 0.1   # bulle emprisonnée
			var c := _ton(R, clampf(v, 0.0, 0.999))
			c.a = clampf(seuil[i] * 0.9 + 0.05, 0.02, 0.98) if superposee else 1.0
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
			c.a = clampf(seuil[i] * 0.85 + 0.07, 0.02, 0.98)
			img.set_pixel(x, y, c)
	return img

# ------------------------------------------------------------------ cristal de glace (tuile 2 m = 64 px)
static func cristal_image() -> Image:
	var T := 64
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var R := _rampe(R_CRISTAL)
	var onde := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.03, 61, T, 3)
	var grain := _champ(FastNoiseLite.TYPE_SIMPLEX, 0.4, 62, T, 2)
	for y in T:
		for x in T:
			var i := y * T + x
			# veines obliques claires, cœur plus sombre au centre des bandes
			var b := sin((float(x) * 0.55 + float(y) * 0.28) + onde[i] * 5.0) * 0.5 + 0.5
			var v := 0.35 + 0.45 * b + 0.12 * (onde[i] - 0.5) + 0.05 * (grain[i] - 0.5)
			if b > 0.93:
				v = 1.0
			img.set_pixel(x, y, _ton(R, clampf(v, 0.0, 0.999)))
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
## 256 x 128 : ciel couvert froid, crêtes lointaines enneigées, sapins sombres, neige au pied ; sans éclairage.
static func jour_image() -> Image:
	var W := 256
	var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var ciel := _rampe(["#9fb7d4", "#c7d8ea", "#eef4fa", "#ffffff"], 8)
	var cret := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 21, 256, 4)
	var neige := _rampe(["#9db0c8", "#c4d2e2", "#eaf1f8", "#ffffff"], 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var nuage := _champ(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 22, 256, 4)
	for y in H:
		for x in W:
			var t := float(y) / H                    # 0 = haut
			var v := 0.15 + 0.7 * t + 0.14 * (nuage[y * 256 + x] - 0.5)
			img.set_pixel(x, y, _ton(ciel, clampf(v, 0.0, 0.999)))
	# crêtes lointaines : deux plans, bleus pâles puis gris bleu
	for x in W:
		var y1 := int(H * 0.50 - 14.0 * cret[x] - 5.0 * sin(x * 0.07))
		var y2 := int(H * 0.60 - 11.0 * cret[(x * 2 + 40) % 256])
		for y in range(y1, H):
			var c := Color("#b9c9dc") if y > y1 + 1 else Color("#e6eef6")
			img.set_pixel(x, y, c)
		for y in range(y2, H):
			var c2 := Color("#8da3bd") if y > y2 + 1 else Color("#d3deea")
			img.set_pixel(x, y, c2)
	# sapins en silhouette sombre, sur la pente basse
	for k in 34:
		var cx := rng.randi_range(0, W - 1)
		var base := int(H * 0.66 + rng.randf() * H * 0.14)
		var ht := rng.randi_range(8, 20)
		for j in ht:
			var larg := int(float(ht - j) / ht * (2.0 + ht * 0.2))
			for dx in range(-larg, larg + 1):
				var tone := Color("#1a2a33") if (j + dx) % 5 != 0 else Color("#2c4048")
				if dx < -larg + 1 and j % 3 != 0:
					tone = Color("#e8f0f6")          # neige sur la branche
				img.set_pixel(posmod(cx + dx, W), base - j, tone)
	# neige au premier plan
	var ys := int(H * 0.82)
	for y in range(ys, H):
		for x in W:
			var v2 := 0.55 + 0.35 * (nuage[y * 256 + x] - 0.3) + (0.1 if y == ys else 0.0)
			img.set_pixel(x, y, _ton(neige, clampf(v2, 0.0, 0.999)))
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
		"strate": return strate_image()
		"sol": return sol_image(0)
		"neige": return neige_image()
		"glace": return glace_image(false)
		"glace_sup": return glace_image(true)
		"mousse": return mousse_image()
		"cristal": return cristal_image()
		"peau": return peau_image()
		"paille": return paille_image()
		"jour": return jour_image()
		"ciel": return ciel_faille_image()
		"rai": return rai_image()
		"flaque": return flaque_image()
	return roche_image(0)
