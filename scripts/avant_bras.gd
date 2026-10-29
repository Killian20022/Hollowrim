class_name AvantBras
## Matières des avant-bras FPS « runes » (bras_fps.glb, sources_blender/scripts/avant_bras_runes.py ; références
## Jeux/references/avant_bras_magie/bras_*_1100.jpg). Modèle COMMUN à tous les équipements (épée, torche, bouclier, sorts,
## main vide) : mains.gd les pose par nom de matière Blender (ab_*). Textures peintes au pixel (64², plus proche voisin),
## pas de tramage : bruit de valeur seulement. Les creux et les pointes claires viennent des couleurs de sommet.

const T := 64
## Calque de rendu 18 : les maillages des avant-bras (mains.gd). Les auras des mains ne l'éclairent pas (lumière de 4 m
## posée dans la paume : bras brûlés à blanc) ; la lueur courte de RunesOrbite l'éclaire à la place.
const CALQUE := 1 << 17
static var _mats := {}

static func materiaux() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	_mats = {
		"ab_gant": Palette.materiau(_tex("gant"), Vector2(1, 1), Color(0.95, 0.88, 0.84), true),
		"ab_cuir": Palette.materiau(_tex("cuir"), Vector2(1, 1), Color(0.95, 0.9, 0.86), true),
		"ab_tresse": Palette.materiau(_tex("tresse"), Vector2(1, 1), Color(0.95, 0.9, 0.86), true),
		"ab_metal": Palette.materiau(_tex("metal"), Vector2(1, 1), Color(0.7, 0.7, 0.74), true),
		"ab_fer": Palette.materiau(_tex("fer"), Vector2(1, 1), Color(0.85, 0.85, 0.88), true),
		"ab_sangle": Palette.materiau(_tex("sangle"), Vector2(1, 1), Color(0.8, 0.76, 0.74), true),
		"ab_fourrure": Palette.materiau(_tex("fourrure"), Vector2(1, 1), Color(0.8, 0.79, 0.78), true),
	}
	return _mats

static var _textures := {}

static func _tex(nom: String) -> ImageTexture:
	if not _textures.has(nom):
		_textures[nom] = ImageTexture.create_from_image(peindre(nom))
	return _textures[nom]

# ------------------------------------------------------------------ bruit (valeur, périodique sur la tuile)
static func _h(x: int, y: int, g: int) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (g * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0

## Bruit de valeur lissé, périodique de période `p` (diviseur de T) : la texture se raccorde.
static func _bruit(x: float, y: float, p: int, g: int) -> float:
	var s := float(T) / p
	var fx := x / s
	var fy := y / s
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - x0
	var ty := fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _h(posmod(x0, p), posmod(y0, p), g)
	var b := _h(posmod(x0 + 1, p), posmod(y0, p), g)
	var c := _h(posmod(x0, p), posmod(y0 + 1, p), g)
	var d := _h(posmod(x0 + 1, p), posmod(y0 + 1, p), g)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)

static func _fbm(x: float, y: float, g: int) -> float:
	return _bruit(x, y, 4, g) * 0.5 + _bruit(x, y, 8, g + 1) * 0.3 + _bruit(x, y, 16, g + 2) * 0.2

## Rampe de couleurs (k 0..1) quantifiée en `pas` tons : pixel art, pas de dégradé continu.
static func _rampe(cols: Array, k: float, pas := 6) -> Color:
	k = clampf(round(clampf(k, 0.0, 1.0) * (pas - 1)) / (pas - 1), 0.0, 1.0)
	var f := k * (cols.size() - 1)
	var i := mini(int(f), cols.size() - 2)
	return (cols[i] as Color).lerp(cols[i + 1], f - i)

const GANT := [Color("#1e130c"), Color("#352217"), Color("#4c3221"), Color("#66452e"), Color("#86603f")]
const CUIR := [Color("#1a120d"), Color("#2c1f17"), Color("#3f2d22"), Color("#56412f"), Color("#705742")]   # passe 4 : plus clair, lisible dans le coin bas
const FER := [Color("#1d1c1c"), Color("#3a3836"), Color("#5a5652"), Color("#7e7872"), Color("#a7a098")]
const FOURRURE := [Color("#3e3a37"), Color("#6c6762"), Color("#98928b"), Color("#c4beb6"), Color("#e8e4dd")]
const FIL := Color("#7a6248")

static func peindre(nom: String) -> Image:
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	for y in T:
		for x in T:
			img.set_pixel(x, y, _pixel(nom, x, y))
	return img

static func _pixel(nom: String, x: int, y: int) -> Color:
	match nom:
		"gant":
			# cuir de gant noir-brun : grain fin, plis clairs usés, quelques éraflures
			var k := _fbm(x, y, 3) * 0.75 + _h(x, y, 5) * 0.18
			var pli := absf(_bruit(x * 1.0, y * 2.0, 8, 11) - 0.5)
			if pli < 0.035:
				k += 0.22
			if _h(x, y, 7) > 0.985:
				k += 0.35
			return _rampe(GANT, k - 0.05)
		"cuir":
			# coque du brassard : cuir épais sombre, couture claire le long des deux bords (v = 0 et v = 1 de la tuile)
			var k := _fbm(x, y, 21) * 0.8 + _h(x, y, 22) * 0.15
			if y < 2 or y > T - 3:
				return _rampe(CUIR, 0.05)
			if (y == 4 or y == T - 5) and x % 4 < 2:
				return FIL
			if y == 5 or y == T - 4:
				k -= 0.2
			return _rampe(CUIR, k)
		"tresse":
			# lanière tressée : chevrons de brins (u le long du tour, v autour de la section), rangs de perles de fer aux bords
			var v := float(y) / T
			var bord := absf(v - 0.25) < 0.035 or absf(v - 0.75) < 0.035
			if bord and x % 5 < 2:
				return _rampe(FER, 0.55 + 0.35 * _h(x, y, 31))
			var brin := fposmod((x + absf(y - T * 0.5) * 0.9) / 7.0, 1.0)
			var k := 0.30 + 0.45 * sin(brin * PI) + (_fbm(x, y, 33) - 0.5) * 0.35
			if brin < 0.12:
				k = 0.05
			if absf(v - 0.5) > 0.38:
				k *= 0.6
			return _rampe(CUIR, k)
		"metal":
			# plaque nordique : cadre en relief, entrelacs (deux bandes qui se croisent) et losange runique gravés,
			# fond piqué plus sombre, usure claire sur les arêtes
			var u := (x + 0.5) / T
			var v := (y + 0.5) / T
			var usure := _fbm(x, y, 41)
			var cadre := u < 0.08 or u > 0.92 or v < 0.08 or v > 0.92
			if cadre:
				var arete := u < 0.03 or u > 0.97 or v < 0.03 or v > 0.97
				return _rampe(FER, (0.85 if arete else 0.62) + (usure - 0.5) * 0.3)
			if u < 0.11 or u > 0.89 or v < 0.11 or v > 0.89:
				return _rampe(FER, 0.12)
			var fond := 0.30 + (usure - 0.5) * 0.25 + (0.12 if _h(x, y, 43) > 0.9 else 0.0)
			var meilleur := 9.0
			var dessus := -1
			for s: float in [-1.0, 1.0]:
				var c: float = 0.5 + s * 0.22 * sin((v - 0.11) / 0.78 * TAU * 1.5)
				var d := absf(u - c)
				if d < meilleur:
					meilleur = d
					# entrelacs : au croisement, la bande du dessus alterne
					dessus = 0 if s < 0.0 else 1
			var croise := int(floor((v - 0.11) / 0.78 * 3.0 + 0.5))
			var largeur := 0.065
			# losange runique au centre de chaque boucle
			var lv := fposmod((v - 0.11) / 0.78 * 3.0, 1.0)
			var los := absf(u - 0.5) / 0.13 + absf(lv - 0.5) / 0.32
			if meilleur < largeur:
				if meilleur > largeur - 0.022:
					return _rampe(FER, 0.08)          # trait de gravure qui borde la bande
				var masque := (croise + dessus) % 2 == 0 and absf(lv - 0.0) < 0.06
				return _rampe(FER, (0.25 if masque else 0.7) + (usure - 0.5) * 0.3)
			if los > 0.8 and los < 1.0:
				return _rampe(FER, 0.72)
			if los < 0.45 and (absf(u - 0.5) < 0.012 or absf(lv - 0.5) < 0.02):
				return _rampe(FER, 0.08)              # rune (croix) gravée dans le losange
			return _rampe(FER, fond)
		"fer":
			var k := 0.45 + (_fbm(x, y, 51) - 0.5) * 0.5 + (0.2 if _h(x, y, 52) > 0.93 else 0.0)
			return _rampe(FER, k)
		"sangle":
			# sangle de cuir plus sombre, double piqûre claire (v = 0,2 et 0,8), bords rognés
			var v := float(y) / T
			if v < 0.06 or v > 0.94:
				return _rampe(CUIR, 0.0)
			if (absf(v - 0.2) < 0.02 or absf(v - 0.8) < 0.02) and x % 4 < 2:
				return FIL.darkened(0.15)
			return _rampe(CUIR, 0.15 + (_fbm(x, y, 61) - 0.5) * 0.4 + _h(x, y, 62) * 0.1)
		"fourrure":
			# mèches grises et blanches : stries le long de v (pied sombre -> pointe claire), mèches de teintes différentes
			var v := float(y) / T
			var meche := int(x / 3)
			var clair := _h(meche, 0, 71)
			var strie := _h(x, int(y / 6), 72)
			var k := 0.15 + 0.55 * v + 0.35 * (clair - 0.4) + (strie - 0.5) * 0.25
			if x % 3 == 0:
				k -= 0.15
			return _rampe(FOURRURE, k, 7)
	return Color.MAGENTA
