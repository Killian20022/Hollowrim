class_name PersonnagesTextures
## Lot 4 : textures des personnages à 64 texels/m (tissages sergés, coutures, bordures nordiques brodées, fourrure en mèches, cuir cousu et usé,
## mailles rouillées), dessinées par code puis quantifiées dans des rampes de 8 tons (froides à l'ombre, chaudes à la lumière), tramage par bruit
## à seuil (jamais Bayer). Les UV des vêtements sont métriques (sources_blender/scripts/personnages_uv.py) : v = hauteur depuis l'ourlet (ou
## distance au poignet), u = angle x rayon ; BAS de l'image = ourlet. Précalculées par outils/generer_personnages.gd dans
## assets/personnages/<nom>.res (VERSION = invalidation) ; repli : calcul direct. Tailles : voir TAILLE (identiques à personnages_uv.py).

const DOSSIER := "res://assets/personnages"
const VERSION := 1

## [base, fond de bordure, motif a, motif b, motif] ; motifs : losanges, dents, cordon
const LAINES := {
	"bleu": ["#34487c", "#1d2748", "#b8923c", "#9a3d2c", "losanges"],
	"brun": ["#6a4e34", "#3a2a1c", "#a8844a", "#7f3626", "dents"],
	"vert": ["#4f6540", "#2b3a26", "#b09a5c", "#8f4a2c", "dents"],
	"violet": ["#5a4474", "#2d2240", "#b8a4c0", "#b08c3c", "losanges"],
	"rouge": ["#8a3228", "#4a1812", "#b49a5c", "#c0b498", "dents"],
	"lin": ["#9b8a6c", "#5b4c36", "#7a3a2a", "#3d4a6a", "dents"],
	"gris": ["#6a6c70", "#34363a", "#b8b0a0", "#8a4a3a", "cordon"],
	"neutre": ["#9a9a9a", "#555555", "#d8d8d8", "#bdbdbd", "cordon"],
}
const CUIRS := {"cuir_a": "#6a4426", "cuir_b": "#443020", "cuir_c": "#7d5a38"}
const FOURRURES := {"blanc": "#aeb4c0", "gris": "#7d818c", "brun": "#6b4c34"}
const PANTALONS := {"brun": "#5d4a38", "gris": "#55585c", "lin": "#8d7f68", "bleu": "#3c4660", "neutre": "#9a9a9a", "noir": "#34302c"}
const TAILLE := {"tunique": Vector2i(128, 64), "pantalon": Vector2i(128, 64), "bottes": Vector2i(64, 64), "ceinture": Vector2i(128, 8),
	"mante": Vector2i(128, 64), "brassards": Vector2i(64, 32), "gants": Vector2i(64, 32)}

static func noms() -> Array:
	var l: Array = []
	for k in LAINES: l.append("tunique_" + k)
	for k in CUIRS: l.append("tunique_" + k)
	l += ["tunique_draugr", "tunique_mailles", "tunique_mailles_rouille"]
	for k in PANTALONS: l.append("pantalon_" + k)
	l.append("pantalon_draugr")
	for k in CUIRS: l.append("bottes_" + k)
	l.append("bottes_draugr")
	for k in CUIRS: l.append("ceinture_" + k)
	l.append("ceinture_draugr")
	for k in FOURRURES: l.append("mante_" + k)
	l += ["mante_draugr", "mante_cuir"]
	for k in CUIRS: l.append("brassards_" + k)
	l += ["brassards_fer", "brassards_draugr"]
	for k in CUIRS: l.append("gants_" + k)
	l += ["peau_homme", "peau_femme", "peau_homme_draugr", "peau_femme_draugr", "yeux", "yeux_draugr", "sourcils"]
	return l

# ------------------------------------------------------------------ outils
## Rampe de n tons : ombres froides et désaturées, lumières chaudes.
static func rampe(base: Color, n := 8, clair := 1.35, sombre := 0.30) -> Array[Color]:
	var r: Array[Color] = []
	for i in n:
		var t := float(i) / (n - 1)
		var c := base * lerpf(sombre, clair, t)
		c.a = 1.0
		var g := c.get_luminance()
		c = c.lerp(Color(g, g, g), (1.0 - t) * 0.22)
		c = c.lerp(Color(0.55, 0.62, 0.85) * g * 1.2, (1.0 - t) * 0.22)
		c = c.lerp(Color(1.0, 0.9, 0.7) * maxf(g, 0.3) * 1.5, pow(t, 2.0) * 0.18)
		r.append(Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1)))
	return r

static func _h(x: int, y: int, g: int) -> float:
	return ObjetsTextures._h(x, y, g)

## bruit de valeurs périodique en u (w) et v (h) : cx, cy cellules
static func _n(x: int, y: int, w: int, h: int, cx: int, cy: int, g: int) -> float:
	return ObjetsTextures._vn(float(x) / w * cx, float(y) / h * cy, cx, cy, g)

static func _p(img: Image, x: int, y: int, c: Color) -> void:
	img.set_pixel(posmod(x, img.get_width()), posmod(y, img.get_height()), c)

static func _t(r: Array, l: float, x: int, y: int, jit := 0.35) -> Color:
	return r[ObjetsTextures._ton(l, r.size(), x, y, jit)]

static func _nouvelle(nom: String) -> Image:
	var s: Vector2i = TAILLE[nom.get_slice("_", 0)]
	var img := Image.create(s.x, s.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	return img

const MOTIFS := {
	"losanges": ["...aa...", "..a..a..", ".a.bb.a.", ".a.bb.a.", "..a..a..", "...aa..."],
	"dents": ["a......a", "aa....aa", "aaa..aaa", ".abaaba.", "..abba..", "...aa..."],
	"cordon": ["aabb....", ".aabb...", "..aabb..", "...aabb.", "b...aab.", "bb...aa."],
}

## Bordure brodée de 9 rangées de l'ourlet (ligne 0 = bas de l'image) : bord replié, cordon, motif, cordon.
static func bordure(img: Image, fond: Array, a: Color, b: Color, motif: String, vy0 := 1) -> void:
	var W := img.get_width()
	var H := img.get_height()
	var m: Array = MOTIFS[motif]
	for x in W:
		for k in 9:
			var vy := vy0 + k
			var c: Color
			if k == 0:
				c = fond[1]
			elif k == 1 or k == 8:
				c = a if ((x + k) & 3) < 3 else fond[3]   # fil jaune, quelques sauts
			elif k == 2 or k == 7:
				c = fond[2]
			else:
				var ch: String = m[k - 3][x % m[0].length()]
				c = a if ch == "a" else (b if ch == "b" else fond[3 if _h(x, k, 51) > 0.3 else 2])
			_p(img, x, H - 1 - vy, c)

## Point de couture : ligne pointillée claire.
static func couture(img: Image, vy: int, c: Color, x0 := 0, x1 := -1, pas := 4) -> void:
	var W := img.get_width()
	if x1 < 0: x1 = W
	for x in range(x0, x1):
		if x % pas < pas - 1:
			_p(img, x, img.get_height() - 1 - vy, c)

## Pièce rapportée : rectangle de tissu plus clair cousu au point.
static func rapiece(img: Image, x: int, vy: int, w: int, h: int, r: Array, ton: int, g: int, fil: Color) -> void:
	var H := img.get_height()
	for j in h:
		for i in w:
			var l := 0.5 + (_h(i, j, g) - 0.5) * 0.3 + (0.07 if ((i + j) & 3) < 2 else -0.04)
			_p(img, x + i, H - 1 - (vy + j), r[clampi(ton + ObjetsTextures._ton(l, 3, i, j, 0.4) - 1, 0, r.size() - 1)])
	for i in w:
		if i % 3 != 2:
			_p(img, x + i, H - 1 - vy, fil)
			_p(img, x + i, H - 1 - (vy + h - 1), fil)
	for j in h:
		if j % 3 != 2:
			_p(img, x, H - 1 - (vy + j), fil)
			_p(img, x + w - 1, H - 1 - (vy + j), fil)

## Sergé : nervures diagonales, irrégularités de fil, plis verticaux doux, salissure vers l'ourlet.
static func _laine(img: Image, r: Array, g: int, plis := 5, sale := 0.16, fin := false) -> void:
	var W := img.get_width()
	var H := img.get_height()
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var sg := (0.045 if ((x + y) & 3) < 2 else -0.03) if not fin else (0.05 if ((x + y) & 1) == 0 else -0.03)
			var l := 0.52 + sg + (_h(x, 0, g) - 0.5) * 0.06 + (_h(0, y, g + 1) - 0.5) * 0.06
			l += (_n(x, y, W, H, plis, 2, g + 2) - 0.5) * 0.22
			l += (_n(x, y, W, H, 16, 8, g + 3) - 0.5) * 0.07
			l -= sale * smoothstep(30.0, 0.0, float(vy))
			_p(img, x, y, _t(r, l, x, y, 0.4))

# ------------------------------------------------------------------ tunique
static func tunique(v: String) -> Image:
	var img := _nouvelle("tunique")
	var W := img.get_width()
	var H := img.get_height()
	if v == "draugr":
		return tunique_draugr(img)
	if v == "mailles" or v == "mailles_rouille":
		return tunique_mailles(img, v == "mailles_rouille")
	if CUIRS.has(v):
		return tunique_cuir(img, v)
	var d: Array = LAINES[v]
	var r := rampe(Color(d[0]))
	var fond := rampe(Color(d[1]))
	var g := 100 + v.hash() % 50
	_laine(img, r, g)
	# encolure et épaules : rangées du haut plus sombres (le col est dessiné par la bordure du haut)
	for x in W:
		for k in 5:
			var c: Color = fond[2 + (1 if k == 2 else 0)] if k < 4 else Color(d[2])
			if k == 4 and x % 4 == 3: c = fond[3]
			_p(img, x, k, c)
	bordure(img, fond, Color(d[2]), Color(d[3]), d[4])
	couture(img, 11, r[6])
	# deux pièces cousues, une reprise
	rapiece(img, 20 + (g % 17), 22, 10, 8, r, 3, g + 7, r[6])
	rapiece(img, 84 + (g % 9), 31, 8, 10, r, 5, g + 9, r[2])
	return img

static func tunique_cuir(img: Image, v: String) -> Image:
	var W := img.get_width()
	var H := img.get_height()
	var r := rampe(Color(CUIRS[v]), 8, 1.4, 0.25)
	var g := 120 + v.hash() % 40
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var l := 0.48 + (_n(x, y, W, H, 8, 4, g) - 0.5) * 0.40 + (_n(x, y, W, H, 32, 16, g + 1) - 0.5) * 0.2 + (_h(x, y, g + 2) - 0.5) * 0.08
			# lanières cousues en bandes horizontales de 12 rangées, joints sombres
			if vy % 12 == 0:
				l -= 0.30
			elif vy % 12 == 1:
				l += 0.10
			l -= 0.14 * smoothstep(26.0, 0.0, float(vy))
			_p(img, x, y, _t(r, l, x, y, 0.4))
	for vy in range(2, H, 12):
		couture(img, vy + 3, Color(ObjetsTextures.FIL) * 0.85, 0, -1, 3)
	for x in range(3, W, 16):                       # clous de fer
		for vy in range(7, H, 12):
			_p(img, x, H - 1 - vy, ObjetsTextures._c(ObjetsTextures.FER, 6))
			_p(img, x + 1, H - 1 - vy, ObjetsTextures._c(ObjetsTextures.FER, 3))
	var fond := rampe(Color("#2a1c12"))
	bordure(img, fond, Color("#8a8f98"), Color("#5d646e"), "cordon", 0)
	return img

static func tunique_draugr(img: Image) -> Image:
	var W := img.get_width()
	var H := img.get_height()
	var r := rampe(Color("#4a4640"), 8, 1.25, 0.22)
	var chair := rampe(Color("#6c7a86"), 8, 1.2, 0.3)
	_laine(img, r, 160, 7, 0.1)
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var n := _n(x, y, W, H, 10, 5, 171)
			var deschire := n > 0.64 or (vy < 8 and _n(x, y, W, H, 24, 3, 172) + float(vy) * 0.02 < 0.5)
			if deschire:
				var l := 0.35 + (_h(x, y, 173) - 0.5) * 0.25 + (0.10 if n > 0.70 else 0.0)
				_p(img, x, y, _t(chair, l, x, y))
			elif n > 0.60:
				_p(img, x, y, r[1])                     # bord effiloché sombre
			if _n(x, y, W, H, 6, 4, 174) > 0.72 and not deschire:
				_p(img, x, y, _t(r, 0.18, x, y))          # moisissure / sang séché
	return img

static func tunique_mailles(img: Image, rouille: bool) -> Image:
	var W := img.get_width()
	var H := img.get_height()
	var fer := ObjetsTextures.FER
	for y in H:
		for x in W:
			var cx := x & 3
			var cy := y & 3
			if (y >> 2) & 1 == 1:
				cx = (x + 2) & 3
			var anneau := ((cx == 0 or cx == 3) and (cy == 1 or cy == 2)) or ((cy == 0 or cy == 3) and (cx == 1 or cx == 2))
			var ton := 4 if anneau else 2
			if anneau and cx <= 1 and cy <= 1: ton = 5      # arête éclairée en haut à gauche
			var base := 0.45 + (_n(x, y, W, H, 7, 4, 181) - 0.5) * 0.5
			ton = clampi(ton + int(floorf((base - 0.45) * 3.0)), 0, 7)
			var c: Color = ObjetsTextures._c(fer, ton) * 0.9
			if rouille:
				var rr := _n(x, y, W, H, 9, 5, 182) + (_h(x, y, 183) - 0.5) * 0.25
				if rr > 0.50:
					c = ObjetsTextures._c(ObjetsTextures.ROUILLE, clampi(ton / 2, 0, 3)).lerp(c, 0.45)
			_p(img, x, y, c)
	# ourlet cuir rivé
	var cu := rampe(Color("#4a3320"))
	for x in W:
		for k in 5:
			_p(img, x, H - 1 - k, cu[2 + (1 if k == 2 else 0) - (1 if k == 0 else 0)])
	couture(img, 3, ObjetsTextures.FIL * 0.7, 0, -1, 3)
	return img

# ------------------------------------------------------------------ pantalon
static func pantalon(v: String) -> Image:
	var img := _nouvelle("pantalon")
	var W := img.get_width()
	var H := img.get_height()
	if v == "draugr":
		var rd := rampe(Color("#403c36"), 8, 1.2, 0.22)
		var chair := rampe(Color("#657480"), 8, 1.2, 0.3)
		_laine(img, rd, 190, 6, 0.1, true)
		for y in H:
			for x in W:
				var n := _n(x, y, W, H, 12, 6, 191)
				if n > 0.66:
					_p(img, x, y, _t(chair, 0.3 + (_h(x, y, 192) - 0.5) * 0.3, x, y))
		return img
	var r := rampe(Color(PANTALONS[v]))
	_laine(img, r, 200 + v.hash() % 30, 6, 0.2, true)
	# jambières croisées (bandelettes enroulées en diagonale) entre la botte (vy 24) et le genou : même étoffe en plus clair
	var lin := rampe(Color(PANTALONS[v]) * 1.18 if v != "lin" else Color("#a09474"), 8, 1.3, 0.35)
	for vy in range(15, 34):
		var y := H - 1 - vy
		for x in W:
			var d := posmod(x - vy * 2, 12)
			if d < 9:
				var l := 0.52 + (_h(x, vy, 201) - 0.5) * 0.12 + (0.05 if ((x + y) & 3) < 2 else -0.03) - (0.14 if d == 0 else 0.0) + (0.08 if d == 8 else 0.0)
				_p(img, x, y, _t(lin, l, x, y, 0.3))
			else:
				_p(img, x, y, r[2])
	for x in W:                                     # haut et bas des jambières : lien de cuir
		_p(img, x, H - 1 - 34, r[0])
		_p(img, x, H - 1 - 15, r[0])
	return img

# ------------------------------------------------------------------ bottes
static func bottes(v: String) -> Image:
	var img := _nouvelle("bottes")
	var W := img.get_width()
	var H := img.get_height()
	var draugr := v == "draugr"
	var r := rampe(Color("#3a3024") if draugr else Color(CUIRS[v]), 8, 1.35, 0.25)
	var g := 220 + v.hash() % 30
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var l := 0.50 + (_n(x, y, W, H, 8, 8, g) - 0.5) * 0.36 + (_h(x, y, g + 1) - 0.5) * 0.10
			# plis de cheville (horizontaux) et peau tendue du cou-de-pied
			var pli := sin(float(vy) * 0.9 + _n(x, y, W, H, 4, 4, g + 2) * 6.0)
			if vy >= 8 and vy <= 17 and pli > 0.82:
				l -= 0.22
			elif vy >= 8 and vy <= 17 and pli > 0.62:
				l += 0.08
			if vy < 4:
				l = 0.12 + (_h(x, y, g + 3) - 0.5) * 0.1      # semelle
			elif vy == 4:
				l = 0.78 if x % 4 < 3 else 0.2              # trépointe cousue
			elif vy >= 22 and vy <= 24:
				l = 0.66 + (_h(x, y, g + 4) - 0.5) * 0.18   # bord du col retourné
			elif vy > 24:
				l = 0.35
			# usure des orteils / talons : zone éclaircie et craquelée
			l += 0.12 * smoothstep(0.6, 0.9, _n(x, y, W, H, 6, 6, g + 5))
			_p(img, x, y, _t(r, l, x, y, 0.4))
	if draugr:
		for y in H:
			for x in W:
				if _n(x, y, W, H, 7, 7, g + 6) > 0.62:
					_p(img, x, y, ObjetsTextures._c(ObjetsTextures.ROUILLE, 0).lerp(r[2], 0.5))
	# lacet du dessus du pied
	for vy in range(10, 28, 3):
		_p(img, 31, H - 1 - vy, Color(ObjetsTextures.FIL) * 0.8)
		_p(img, 33, H - 1 - vy, Color(ObjetsTextures.FIL) * 0.8)
		_p(img, 32, H - 1 - vy - 1, Color(ObjetsTextures.FIL) * 0.9)
	return img

# ------------------------------------------------------------------ ceinture : 5 rangées utiles en bas (vy 0-4) d'une image de 8
static func ceinture(v: String) -> Image:
	var img := _nouvelle("ceinture")
	var W := img.get_width()
	var H := img.get_height()
	var draugr := v == "draugr"
	var r := rampe(Color("#3a2e22") if draugr else Color(CUIRS[v]), 8, 1.4, 0.2)
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var l := 0.5 + (_n(x, y, W, H, 16, 2, 231) - 0.5) * 0.3 + (_h(x, y, 232) - 0.5) * 0.12
			if vy == 0 or vy == 5:
				l = 0.18
			elif vy == 1 or vy == 4:
				l = 0.62
			elif vy == 2:
				l = 0.82 if x % 4 < 3 else 0.35               # piqûre
			_p(img, x, y, _t(r, l, x, y, 0.3))
	# boucle de fer carrée au milieu de l'avant (u = 0 -> colonnes 124..4)
	for dx in range(-6, 7):
		for vy in range(0, 6):
			var bord := absi(dx) == 6 or vy == 0 or vy == 5
			var c: Color = ObjetsTextures._c(ObjetsTextures.FER, 2 if bord else 5)
			if not bord and (dx in [-3, -2, -1]):
				c = ObjetsTextures._c(ObjetsTextures.FER, 1)                          # ouverture de la boucle
			if not bord and dx == 1:
				c = ObjetsTextures._c(ObjetsTextures.FER, 7)                          # ardillon
			_p(img, dx, H - 1 - vy, c)
	return img

# ------------------------------------------------------------------ mante : fourrure en mèches
static func mante(v: String) -> Image:
	var img := _nouvelle("mante")
	var W := img.get_width()
	var H := img.get_height()
	if v == "cuir":
		return mante_cuir(img)
	var base := Color("#6e6a62") if v == "draugr" else Color(FOURRURES[v])
	var r := rampe(base, 8, 1.3 if v != "draugr" else 1.2, 0.46)
	var g := 300 + v.hash() % 40
	# sous-poil : stries verticales (cellules très allongées), un peu plus clair vers la pointe (bas de l'image)
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var l := 0.40 + (_n(x, y, W, H, 42, 3, g) - 0.5) * 0.36 + (_n(x, y, W, H, 8, 4, g + 1) - 0.5) * 0.16 + 0.12 * smoothstep(40.0, 0.0, float(vy))
			_p(img, x, y, _t(r, l, x, y, 0.3))
	# mèches en touffes de 4 à 6 pixels (liseré sombre à gauche, flanc éclairé, flanc ombré), 9 à 22 rangées, pointe effilée plus claire ;
	# elles se recouvrent dans un ordre aléatoire : les touffes de devant ombrent celles de derrière
	for i in 150:
		var x := int(_h(i, 1, g + 2) * W)
		var haut := int(_h(i, 2, g + 3) * 54.0) + 10
		var lg := 9 + int(_h(i, 4, g + 5) * 14.0)
		var cl := _h(i, 6, g + 7)
		var pente := (_h(i, 8, g + 9) - 0.5) * 0.35
		var larg0 := 4 + int(_h(i, 10, g + 11) * 3.0)
		var teinte := 3 + int(cl * 2.0)
		for k in lg:
			var t := float(k) / lg
			var vy := haut - k
			if vy < 0:
				break
			var xx := x + int(roundf(pente * k))
			var larg := maxi(1, int(roundf(larg0 * (1.0 - pow(t, 1.6) * 0.85))))
			var ton := teinte + int(t * 2.4)
			for c in larg:
				var tc := ton + (1 if c == 1 else 0) - (2 if c == 0 else 0) - (1 if c == larg - 1 and larg > 2 else 0) + (1 if _h(c + i * 3, k, g + 13) > 0.8 else 0)
				_p(img, xx + c, H - 1 - vy, r[clampi(tc, 0, 7)])
	# bord du bas : touffes claires en dents de scie
	for x in W:
		var h := 2 + int(_h(x / 2, 3, g + 12) * 4.0)
		for k in h:
			_p(img, x, H - 1 - k, r[clampi(6 - k / 2 + (1 if _h(x, k, g + 14) > 0.6 else 0), 3, 7)])
	if v == "draugr":
		for y in H:
			for x in W:
				if _n(x, y, W, H, 9, 5, g + 13) > 0.7:
					_p(img, x, y, r[2])
	return img

static func mante_cuir(img: Image) -> Image:
	var W := img.get_width()
	var H := img.get_height()
	var r := rampe(Color("#4a3523"), 8, 1.35, 0.25)
	for y in H:
		for x in W:
			var l := 0.46 + (_n(x, y, W, H, 8, 4, 331) - 0.5) * 0.4 + (_h(x, y, 332) - 0.5) * 0.1
			_p(img, x, y, _t(r, l, x, y, 0.4))
	for x in W:
		_p(img, x, H - 1, r[1]); _p(img, x, H - 2, r[5]); 
		if x % 3 < 2: _p(img, x, H - 4, Color(ObjetsTextures.FIL) * 0.8)
	return img

# ------------------------------------------------------------------ brassards et gants
static func brassards(v: String) -> Image:
	var img := _nouvelle("brassards")
	var W := img.get_width()
	var H := img.get_height()
	if v == "fer" or v == "draugr":
		var fer := ObjetsTextures.FER
		for y in H:
			var vy := H - 1 - y
			for x in W:
				var l := 0.5 + (_n(x, y, W, H, 4, 3, 341) - 0.5) * 0.4 + (_h(x, y, 342) - 0.5) * 0.12
				var ton := clampi(int(l * 6.0), 1, 6)
				if vy % 8 == 0: ton = 1
				elif vy % 8 == 1: ton = 7
				var c: Color = ObjetsTextures._c(fer, ton)
				if _n(x, y, W, H, 8, 4, 343) > 0.55 or v == "draugr":
					if _n(x, y, W, H, 8, 4, 343) + (_h(x, y, 344) - 0.5) * 0.3 > 0.5:
						c = ObjetsTextures._c(ObjetsTextures.ROUILLE, clampi(ton / 2, 0, 3))
				_p(img, x, y, c)
		for vy in [3, 11]:
			for x in range(0, W, 8):
				_p(img, x, H - 1 - vy, ObjetsTextures._c(fer, 7)); _p(img, x + 1, H - 1 - vy, ObjetsTextures._c(fer, 2))
		return img
	var r := rampe(Color(CUIRS[v]), 8, 1.4, 0.22)
	var g := 350 + v.hash() % 30
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var l := 0.5 + (_n(x, y, W, H, 8, 4, g) - 0.5) * 0.34 + (_h(x, y, g + 1) - 0.5) * 0.12
			if vy == 0 or vy == 17: l = 0.18
			elif vy == 1 or vy == 16: l = 0.7
			_p(img, x, y, _t(r, l, x, y, 0.35))
	couture(img, 3, Color(ObjetsTextures.FIL), 0, -1, 4)
	couture(img, 14, Color(ObjetsTextures.FIL), 0, -1, 4)
	for x in range(6, W, 16):                                # rivets de fer
		for vy in [8, 9]:
			_p(img, x, H - 1 - vy, ObjetsTextures._c(ObjetsTextures.FER, 6 if vy == 9 else 2))
			_p(img, x + 1, H - 1 - vy, ObjetsTextures._c(ObjetsTextures.FER, 4))
	# lacet croisé sur le dessus du bras (u = 0 : colonnes 58..6)
	for vy in range(3, 15):
		var dx := ((vy % 4) - 2) * 2
		_p(img, dx, H - 1 - vy, Color(ObjetsTextures.FIL) * 0.9)
		_p(img, -dx, H - 1 - vy, Color(ObjetsTextures.FIL) * 0.9)
	return img

static func gants(v: String) -> Image:
	var img := _nouvelle("gants")
	var W := img.get_width()
	var H := img.get_height()
	var r := rampe(Color(CUIRS[v]), 8, 1.4, 0.22)
	var g := 380 + v.hash() % 30
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var l := 0.5 + (_n(x, y, W, H, 6, 4, g) - 0.5) * 0.36 + (_h(x, y, g + 1) - 0.5) * 0.14
			if vy >= 15 and vy <= 17:
				l = 0.3 + (_h(x, y, g + 2) - 0.5) * 0.2        # poignet resserré
			if vy < 3:
				l += 0.10                                    # bout des doigts usé
			_p(img, x, y, _t(r, l, x, y, 0.35))
	for x in W:
		if x % 4 < 3: _p(img, x, H - 1 - 14, Color(ObjetsTextures.FIL) * 0.85)
	for x in range(2, W, 12):                               # coutures entre les doigts
		for vy in range(2, 13):
			_p(img, x, H - 1 - vy, r[1])
	return img

# ------------------------------------------------------------------ accès
static func image(nom: String) -> Image:
	var piece := nom.get_slice("_", 0)
	var v := nom.substr(piece.length() + 1)
	match piece:
		"tunique": return tunique(v)
		"pantalon": return pantalon(v)
		"bottes": return bottes(v)
		"ceinture": return ceinture(v)
		"mante": return mante(v)
		"brassards": return brassards(v)
		"gants": return gants(v)
	if nom.begins_with("peau_"):
		return peau(nom)
	if nom.begins_with("yeux"):
		return yeux(nom.ends_with("draugr"))
	if nom == "sourcils":
		return sourcils()
	return bottes("cuir_a")

# ------------------------------------------------------------------ peau, yeux, sourcils (atlas d'origine réduit et redessiné)
const SOURCES := {"homme": "res://assets/modeles/humains/T_Superhero_Male_Dark.png", "femme": "res://assets/modeles/humains/T_Superhero_Female_Dark_BaseColor.png"}
const COTE_PEAU := 256

static func _source(chemin: String) -> Image:
	var img := Image.load_from_file(chemin)
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img

## Atlas de peau 256 x 256 (le visage fait ~90 px de large : ~550 texels/m, lisible à 1 m) : réduction en moyenne (Lanczos) puis
## quantification dans une rampe de 10 tons à contraste renforcé ; le chroma d'origine (lèvres, joues) est gardé par paliers.
## Draugr : rampe gris-bleu, contraste x2, cuir tanné desséché (taches et fissures).
static func peau(nom: String) -> Image:
	var draugr := nom.ends_with("draugr")
	var corps := nom.get_slice("_", 1)
	var img := _source(SOURCES[corps])
	img.resize(COTE_PEAU, COTE_PEAU, Image.INTERPOLATE_LANCZOS)
	var n := COTE_PEAU
	# couleur moyenne de la peau (hors pixels très sombres : sous-vêtements)
	var somme := Color(0, 0, 0)
	var nb := 0
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			if c.get_luminance() > 0.35:
				somme += c
				nb += 1
	var moy := Color(somme.r / nb, somme.g / nb, somme.b / nb)
	var lm := moy.get_luminance()
	var r := rampe(Color("#7f8c97") if draugr else moy, 10, 1.45, 0.34)
	var contraste := 2.3 if draugr else 1.9
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			if l < 0.2:
				_p(img, x, y, Color("#2a2a2e"))       # sous-vêtements : cachés
				continue
			var t := 0.52 + (l / lm - 1.0) * contraste * 0.5
			if draugr:
				t -= 0.18 * smoothstep(0.55, 0.8, _n(x, y, n, n, 9, 9, 701))
				t += (_n(x, y, n, n, 40, 40, 702) - 0.5) * 0.18
				if _n(x, y, n, n, 28, 28, 703) > 0.8:
					t -= 0.3                          # fissures
			var idx := ObjetsTextures._ton(t, 10, x, y, 0.45)
			var col: Color = r[idx]
			if not draugr:
				var ch := Color(c.r - l, c.g - l, c.b - l)
				var chm := Color(moy.r - lm, moy.g - lm, moy.b - lm)
				var q := Color(roundf((ch.r - chm.r) * 14.0) / 14.0, roundf((ch.g - chm.g) * 14.0) / 14.0, roundf((ch.b - chm.b) * 14.0) / 14.0)
				q = Color(clampf(q.r, -0.1, 0.1), clampf(q.g, -0.1, 0.1), clampf(q.b, -0.1, 0.1))
				col = Color(clampf(col.r + q.r * 1.2, 0, 1), clampf(col.g + q.g * 1.2, 0, 1), clampf(col.b + q.b * 1.2, 0, 1))
			_p(img, x, y, col)
	return img

static func yeux(draugr: bool) -> Image:
	var img := _source("res://assets/modeles/humains/T_Eye_Brown.png")
	img.resize(48, 48, Image.INTERPOLATE_LANCZOS)
	var peau_c := Color("#5a666f") if draugr else Color("#c8967a")
	for y in 48:
		for x in 48:
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			var rouge := c.r - (c.g + c.b) * 0.5            # fond de paupière rosé : peau
			if rouge > 0.12 and l > 0.35:
				c = peau_c * (0.72 + l * 0.35)
			elif l > 0.62:
				c = Color("#d8d4cc") if not draugr else Color("#9ad8e0")     # blanc de l'œil
			elif l < 0.22:
				c = Color("#14100e") if not draugr else Color("#0c1418")      # pupille, cils
			else:
				c = Color(roundf(c.r * 7.0) / 7.0, roundf(c.g * 7.0) / 7.0, roundf(c.b * 7.0) / 7.0) * 0.95
				if draugr:
					c = Color("#4aa8c0")
			img.set_pixel(x, y, c)
	return img

static func sourcils() -> Image:
	var img := _source("res://assets/modeles/humains/T_Hair_1_BaseColor.png")
	img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	for y in 128:
		for x in 128:
			var c := img.get_pixel(x, y)
			c = Color(roundf(c.r * 6.0) / 6.0, roundf(c.g * 6.0) / 6.0, roundf(c.b * 6.0) / 6.0)
			img.set_pixel(x, y, c)
	return img

static var _cache := {}

static func tex(nom: String) -> ImageTexture:
	if _cache.has(nom):
		return _cache[nom]
	var a: Image = null
	var chemin := "%s/%s.res" % [DOSSIER, nom]
	if ResourceLoader.exists(chemin):
		a = ResourceLoader.load(chemin) as Image
		if a != null and a.get_meta("version", -1) != VERSION:
			a = null
	if a == null:
		a = image(nom)
	a = a.duplicate() as Image
	a.generate_mipmaps()
	var t := ImageTexture.create_from_image(a)
	_cache[nom] = t
	return t

static func vider() -> void:
	_cache.clear()
