class_name DraugrTextures
## Textures du Draugr nordique (DraugrNordique), peintes par code comme celles du guerrier (GuerrierTextures : 128 texels/m,
## mêmes UV métriques, mipmaps pixel art par vote de couleur, jamais de tramage Bayer), dans les palettes du mort-vivant de la
## référence (Image ChatGPT 14_01_59-5) : mailles BRUN-GRIS FERREUX rongées de rouille, os ivoire sale, chair desséchée gris-brun,
## fer corrodé, cuir noirci, tissu cendré en lambeaux, fourrure gris-brun sale à pointes claires, bois de bouclier délavé.
## AUCUN bleu, sauf l'œil luisant (R_OEIL, émissif par le shader ps1_draugr).
## Atlas des accessoires et des découpes : MÊME disposition que GuerrierTextures (les fonctions de géométrie du guerrier,
## appelées telles quelles, y lisent leurs régions), plus des régions propres (crâne, casque, épaulières) dans la place libre.


# palettes (sombre -> clair)
const MAILLE := ["#281f17", "#43372a", "#604f3d", "#7d6a52", "#9c8669", "#bea784"]   # brun-gris ferreux (chaud : la lumière de 17h30 le refroidit)
const ROUILLE := ["#261a12", "#3c2a1e", "#543b29", "#6c4e36"]   # rouille brun terne (orange vif = cuivre au soleil couchant)
const FER := ["#14120f", "#29251f", "#3f3931", "#585046", "#776d5f", "#9c9180", "#c0b5a0"]
const IVOIRE := ["#29241e", "#463e33", "#6a5f4f", "#8f826c", "#b2a58a", "#cec2a6"]
const CHAIR := ["#1b1612", "#2c251f", "#40372e", "#554a3d", "#6a5d4d"]
const TISSU := ["#1a1816", "#2a2723", "#3b3731", "#4e4840", "#625b50", "#776e61"]
const FOUR := ["#181512", "#2f2922", "#483f35", "#635747", "#7f705b", "#9a8a71"]   # gris-brun sale chaud, pointes claires
const CUIR := ["#1a140f", "#2e231a", "#433427", "#5a4635", "#715a45", "#8b7258", "#a48c6f"]
const BOIS := ["#151310", "#25211c", "#37312a", "#4a4238", "#5e5548", "#746a5a", "#8a806e"]
const PEINT_OS := ["#6a6356", "#878070", "#a49b88", "#bdb39d"]
const CHEVEUX := ["#26221c", "#3e372e", "#595043", "#776b5a", "#988a75"]
const BANDE := ["#2e2a24", "#464037", "#5f574b", "#7a705f"]

const DOSSIER := "res://assets/persos/draugr"
const VERSION := 4
static var enregistrer := false
static var _cache := {}

# régions propres (texels de l'atlas 256 x 256 des accessoires)
const R_CRANE := Rect2i(136, 128, 32, 32)     # masque-crâne : x = visage de -0,085 à +0,085 m, y = de 1,745 à 1,585 m
const R_CASQUE := Rect2i(200, 128, 56, 64)    # dôme du casque : u = tour (0 = devant), v = sommet (0) -> bord (63)
const R_EPAUL := Rect2i(136, 192, 64, 64)     # épaulières : lames de fer superposées, rivets
const R_TABARD := Rect2i(0, 0, 112, 128)      # (atlas des découpes) tabard et ptéruges en lambeaux

static func _c(pal: Array, i: int) -> Color:
	return Color(pal[clampi(i, 0, pal.size() - 1)])

static func _h(x: int, y: int, g: int) -> float:
	return ObjetsTextures._h(x, y, g)

static func _n(x: int, y: int, w: int, h: int, cx: int, cy: int, g: int) -> float:
	return GuerrierTextures._n(x, y, w, h, cx, cy, g)

static func _ton(l: float, n: int, x: int, y: int, g: int, jit := 0.3) -> int:
	return GuerrierTextures._ton(l, n, x, y, g, jit)

static func _p(img: Image, x: int, y: int, c: Color) -> void:
	img.set_pixel(posmod(x, img.get_width()), posmod(y, img.get_height()), c)

static func charger(cle: String) -> Image:
	var chemin := "%s/%s.res" % [DOSSIER, cle.validate_filename()]
	if not ResourceLoader.exists(chemin):
		return null
	var img := ResourceLoader.load(chemin) as Image
	if img == null or img.get_meta("version", -1) != VERSION:
		return null
	return img

static func sauver(cle: String, img: Image) -> void:
	if not enregistrer:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
	img.set_meta("version", VERSION)
	ResourceSaver.save(img, "%s/%s.res" % [DOSSIER, cle.validate_filename()], ResourceSaver.FLAG_COMPRESS)

static func tex(nom: String) -> ImageTexture:
	if not _cache.has(nom):
		var mips := charger(nom)
		if mips == null:
			var img: Image
			match nom:
				"mailles": img = mailles()
				"pantalon": img = pantalon()
				"bottes": img = bottes()
				"brassards": img = brassards()
				"mante": img = mante()
				"cheveux": img = cheveux()
				"accessoires": img = accessoires()
				"decoupes": img = decoupes()
				_: push_error("DraugrTextures : texture inconnue " + nom)
			mips = GuerrierTextures.mips_pixel(img)
			sauver(nom, mips)
		_cache[nom] = ImageTexture.create_from_image(mips)
	return _cache[nom]

static func vider() -> void:
	_cache.clear()

static func _img(w: int, h: int, fond := Color.BLACK) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fond)
	return img

## Rivet corrodé : tête claire, ombre dessous, auréole de rouille.
static func _rivet(img: Image, x: int, y: int) -> void:
	_p(img, x, y, _c(FER, 5))
	_p(img, x + 1, y, _c(FER, 3))
	_p(img, x, y + 1, _c(ROUILLE, 1))
	_p(img, x + 1, y + 1, _c(FER, 0))

static func _ton_cuir(x: int, y: int, W: int, H: int, base: float, g: int) -> int:
	return GuerrierTextures._ton_cuir(x, y, W, H, base, g)

# ------------------------------------------------------------------ cotte de mailles rongée (UV de la tunique, 256 x 128)
## Anneaux en quinconce (comme le guerrier) dans le brun-gris ferreux, rouille en coulures, crasse ; ourlets (bas de la
## jupe et poignets : v = 1) DÉCHIRÉS en lanières pendantes (découpe alpha), quelques trous.
static func mailles() -> Image:
	var W := 256
	var H := 128
	var img := _img(W, H)
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var rang := y / 3
			var cx := (x + (rang & 1) * 2) & 3
			var cy := y % 3
			var t := 0
			if cy == 0:
				t = 4 if (cx == 1 or cx == 2) else 2
			elif cy == 1:
				t = 3 if (cx == 0 or cx == 3) else 0
			else:
				t = 2 if (cx == 1 or cx == 2) else 1
			t += int(roundf((_n(x, y, W, H, 12, 3, 1811) - 0.5) * 2.4))
			if _h(x, y, 1812) > 0.9:
				t -= 1
			if vy < 26 and _h(x, y, 1813) < (26 - vy) / 34.0:
				t -= 1
			var c := _c(MAILLE, t)
			# rouille : grandes plaques + coulures verticales
			var r := _n(x, y, W, H, 14, 7, 1814)
			var coulure := _n(x, 0, W, 1, 40, 1, 1816) > 0.72 and _n(x, y, W, H, 40, 5, 1817) > 0.45
			if t > 0 and (r > 0.66 or coulure) and _h(x, y, 1815) > 0.3:
				c = _c(ROUILLE, clampi(t / 2 + (1 if r > 0.8 else 0), 0, 3)).lerp(c, 0.4)
			# ourlet déchiré : lanières de 3 à 9 texels, longueurs 0 à 16 texels, bord effiloché
			var lan := int(x / 6.0 + _h(x / 6, 7, 1818) * 1.5)
			var coupe := 2 + int(_h(lan, 0, 1819) * 15.0)
			if vy < coupe and (posmod(x, 6) == 0 or _h(lan, 1, 1820) < 0.45):
				c = Color(0, 0, 0, 0)
			elif vy < coupe + 1 and c.a > 0.0:
				c = _c(MAILLE, 0)
			# trous rongés (rares, petits)
			if _n(x, y, W, H, 24, 12, 1821) > 0.86 and vy > 20 and _h(x, y, 1822) > 0.25:
				c = Color(0, 0, 0, 0)
			_p(img, x, y, c)
	return img

# ------------------------------------------------------------------ jambes : laine noircie + bandes molletières sales
static func pantalon() -> Image:
	var W := 256
	var H := 128
	var img := _img(W, H)
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var l := 0.45 + (_n(x, y, W, H, 14, 3, 1831) - 0.5) * 0.4
			var c := _c(TISSU, _ton(l, 5, x, y, 1832))
			if vy >= 2 and vy < 90:
				# bandes en spirale, irrégulières et relâchées (lambeaux qui se décollent)
				var d := posmod(x + vy * 2 + int(_n(x, y, W, H, 6, 3, 1833) * 4.0), 11)
				if d < 8:
					var t := 1 + (1 if d > 1 and d < 5 else 0)
					if d == 0 or d == 7:
						t = 0
					t += int(roundf((_n(x, y, W, H, 8, 4, 1834) - 0.5) * 1.4))
					c = _c(BANDE, t)
				else:
					c = _c(TISSU, 0)
				# lanières de cuir croisées, usées et cassées par endroits
				for sens: int in [1, -1]:
					var e := posmod(x + sens * vy, 26)
					if e < 3 and _n(x, y, W, H, 10, 6, 1835 + sens) > 0.25:
						c = _c(CUIR, [0, 4, 2][e])
			# boue / crasse en bas
			if vy < 24 and _h(x, y, 1836) < (24 - vy) / 40.0:
				c = c.darkened(0.25)
			_p(img, x, y, c)
	return img

# ------------------------------------------------------------------ bottes : cuir noirci enveloppé, revers de fourrure sale
static func bottes() -> Image:
	var W := 128
	var H := 128
	var img := _img(W, H)
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var c := _c(CUIR, _ton_cuir(x, y, W, H, 0.38, 1841) - 1)
			if vy < 3:
				c = _c(CUIR, 0)
			elif vy > 6 and vy < 46:
				var a := posmod(x + vy * 2, 9)
				if a == 0:
					c = _c(CUIR, 0)
				elif a == 1:
					c = _c(CUIR, 4)
			if vy > 50:
				var f := _n(x, y, W, H, 32, 4, 1844)
				c = _c(FOUR, 2 + int(f * 3.0) + (1 if vy > 53 else 0))
				if posmod(x * 7 + vy, 5) == 0:
					c = _c(FOUR, 1)
			_p(img, x, y, c)
	return img

# ------------------------------------------------------------------ brassards : fer corrodé sur cuir
static func brassards() -> Image:
	var W := 128
	var H := 64
	var img := _img(W, H)
	for y in H:
		for x in W:
			var c := _c(CUIR, _ton_cuir(x, y, W, H, 0.36, 1861) - 1)
			# plaques de fer verticales (attelles) rongées
			var pl := posmod(x, 16)
			if pl >= 2 and pl < 11:
				var t := 3 + (1 if pl == 3 else 0) - (1 if pl == 10 else 0)
				t += int(roundf((_n(x, y, W, H, 8, 6, 1862) - 0.5) * 1.6))
				c = _c(FER, t)
				if _n(x, y, W, H, 10, 8, 1863) > 0.6:
					c = _c(ROUILLE, clampi(t - 2, 0, 3))
			elif pl == 11:
				c = _c(FER, 0)
			_p(img, x, y, c)
	for x in W:
		for k in 4:
			var t := 3 + (1 if k == 1 else 0) - (2 if k == 3 else 0)
			_p(img, x, k, _c(FER, t))
			_p(img, x, H - 1 - k, _c(FER, t))
		if x % 8 == 0:
			_rivet(img, x, 1)
			_rivet(img, x, H - 3)
	return img

# ------------------------------------------------------------------ fourrure (touffes pointues, palette du draugr)
static func _touffe(img: Image, x0: int, y0: int, w: int, h: int, pente: float, clair: int) -> void:
	for k in h:
		var t := float(k) / maxf(1.0, h - 1)
		var demi := w * 0.5 * (1.0 - pow(t, 1.4) * 0.92)
		var cx := x0 + pente * k
		var xa := int(floorf(cx - demi))
		var xb := int(ceilf(cx + demi)) - 1
		for x in range(xa, xb + 1):
			var ton := clair - 1 + int(t * 2.2)
			if t < 0.18:
				ton = clair - 2
			if x == xa:
				ton = clair + 1 if t > 0.15 else clair
			if x == xb or (k == h - 1):
				ton = 1
			elif x == int(roundf(cx + demi * 0.25)) and t > 0.25 and t < 0.8:
				ton = clair - 2
			if k == h - 1 and x == int(roundf(cx)):
				ton = clair + 1
			_p(img, x, y0 + k, _c(FOUR, ton))

static func mante() -> Image:
	var W := 256
	var H := 128
	var img := _img(W, H, _c(FOUR, 1))
	var rangs := []
	var y := H - 12
	while y > 50:
		rangs.append(y)
		y -= 6
	for r in rangs.size():
		var yr: int = rangs[r]
		var x := int(_h(r, 0, 1871) * 6.0)
		var i := 0
		while x < W + 6:
			var w := 5 + int(_h(i, r, 1872) * 3.0)
			var h := 9 + int(_h(i, r, 1873) * 6.0)
			_touffe(img, x, yr + int(_h(i, r, 1875) * 3.0) - 1, w, h, (_h(i, r, 1876) - 0.5) * 0.45, 3 + (1 if _h(i, r, 1874) > 0.5 else 0))
			x += w - 1
			i += 1
	return img

## Mèches découpées : 4 variantes de 16 x 32, touffes emmêlées de longueurs inégales (plus hirsutes que le guerrier).
static func meches() -> Image:
	var W := 64
	var H := 32
	var img := _img(W, H, Color(0, 0, 0, 0))
	for v in 4:
		var ox := v * 16
		var n := 3 + (v & 1)
		var larg := 16.0 / n
		for i in n:
			var w := int(larg) + 2
			var cx := ox + int(larg * (i + 0.5))
			var h := 16 + int(_h(i, v, 1881) * 15.0)
			_touffe(img, cx, 0, mini(w, 15), mini(h, H), (_h(i, v, 1882) - 0.5) * 0.4, 3 + (1 if (i + v) % 2 == 0 else 0))
		for y in H:
			for x in [ox, ox + 15]:
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, _c(FOUR, 1))
	return img

## Cheveux filasse (texture de secours) : brins gris-brun ternes.
static func cheveux() -> Image:
	var W := 64
	var H := 64
	var img := _img(W, H)
	for y in H:
		for x in W:
			var brin := posmod(x + int(_h(x / 3, 0, 1901) * 3.0), 3)
			var l := 0.42 + (_n(x, y, W, H, 16, 2, 1902) - 0.5) * 0.5 + (0.2 if brin == 1 else (-0.2 if brin == 0 else 0.0))
			_p(img, x, y, _c(CHEVEUX, _ton(l, 5, x, y, 1903, 0.4)))
	return img

# ------------------------------------------------------------------ atlas des accessoires (256 x 256, disposition du guerrier)
static func accessoires() -> Image:
	var img := _img(GuerrierTextures.ATLAS.x, GuerrierTextures.ATLAS.y, _c(FER, 2))
	_face_bouclier(img)
	_fer(img, GuerrierTextures.R_FER)
	_umbo(img)
	_lame(img)
	_poignee(img)
	_oeil(img)
	_baudrier(img)
	_dos_bouclier(img)
	_anneau(img)
	_bosse(img)
	GuerrierTextures._copier(img, GuerrierTextures.R_PLASTRON, _plastron(0.22, 0.66), -GuerrierTextures.PL_U0, GuerrierTextures.PL_V0)
	_ceinture_atlas(img)
	_crane(img)
	_casque(img)
	_epaul(img)
	return img

## « Plastron » du draugr (même pièce que le guerrier, gonflée au-dessus de la tunique) : seconde couche de mailles, plus
## claire et plus rouillée, bordée de cuir noirci rivé (la poitrine se lit en relief, comme la référence).
static func _plastron(v0: float, v1: float) -> Image:
	var W := 256
	var H := 128
	var img := _img(W, H)
	var y0 := int(v0 * H)
	var y1 := int(v1 * H)
	for y in H:
		for x in W:
			var rang := y / 3
			var cx := (x + (rang & 1) * 2) & 3
			var cy := y % 3
			var t := 0
			if cy == 0:
				t = 5 if (cx == 1 or cx == 2) else 3
			elif cy == 1:
				t = 3 if (cx == 0 or cx == 3) else 0
			else:
				t = 2 if (cx == 1 or cx == 2) else 1
			t += int(roundf((_n(x, y, W, H, 10, 4, 1921) - 0.5) * 2.0))
			var c := _c(MAILLE, t)
			if t > 0 and _n(x, y, W, H, 12, 6, 1922) > 0.62 and _h(x, y, 1923) > 0.3:
				c = _c(ROUILLE, clampi(t / 2, 0, 3)).lerp(c, 0.45)
			_p(img, x, y, c)
	for x in W:
		for k in 4:
			_p(img, x, y0 + k, _c(CUIR, 2 + (1 if k == 1 else 0)))
			_p(img, x, y1 - k, _c(CUIR, 2 + (1 if k == 2 else 0)))
		_p(img, x, y0, _c(CUIR, 5 if _h(x, 0, 1927) > 0.4 else 4))
		_p(img, x, y0 + 4, _c(MAILLE, 0))
		if x % 7 == 3:
			_rivet(img, x, y0 + 1)
			_rivet(img, x, y1 - 2)
	return img

static func _ceinture_atlas(img: Image) -> void:
	var r := GuerrierTextures.R_CEINT
	for y in r.size.y:
		for x in r.size.x:
			var t := _ton_cuir(x, y, r.size.x, r.size.y, 0.40, 1961)
			if y == 0 or y == r.size.y - 1:
				t = 0
			elif y == 1 or y == r.size.y - 2:
				t = 5 if _h(x, y, 1962) > 0.3 else 4
			# cuir craquelé
			if _n(x, y, r.size.x, r.size.y, 20, 2, 1963) > 0.75:
				t -= 2
			_p(img, r.position.x + x, r.position.y + y, _c(CUIR, clampi(t, 0, 6)))
	for x in range(5, r.size.x, 11):
		_rivet(img, r.position.x + x, r.position.y + 7)

## Bouclier du draugr : planches verticales disjointes, bois gris-brun délavé, rune pâle en étoile (os blanchi) à demi
## effacée, trous et éclats noirs, un morceau arraché en bas à droite, crasse au bord, clous rouillés.
static func _face_bouclier(img: Image) -> void:
	var o := GuerrierTextures.R_FACE.position
	var n := GuerrierTextures.R_FACE.size.x
	var c0 := (n - 1) * 0.5
	for y in n:
		for x in n:
			var dx := (x - c0) / c0
			var dy := (y - c0) / c0
			var r := sqrt(dx * dx + dy * dy)
			var k := 0
			while k < GuerrierTextures.PLANCHES.size() - 2 and x >= GuerrierTextures.PLANCHES[k + 1]:
				k += 1
			var dj: int = x - int(GuerrierTextures.PLANCHES[k])
			var base := 0.36 + _h(k, 0, 1912) * 0.22
			var lb := base + (_n(x, y, n, n, 10, 3, 1911 + k) - 0.5) * 0.30 + (_h(x, k, 1918) - 0.5) * 0.2
			var t := clampi(_ton(lb, 5, x, y, 1913, 0.2) + 1, 1, 5)
			if dj == 1 and k > 0:
				t = 4
			var c := _c(BOIS, t)
			# rune en étoile (croix + diagonales), peinte en os pâle, écaillée
			var a := atan2(dy, dx)
			var bras := absf(sin(a * 4.0)) < 0.16 + 0.05 / maxf(r, 0.05)
			if bras and r > 0.16 and r < 0.78 and dj > 1:
				if _n(x, y, n, n, 7, 7, 1917) < 0.7 and _h(x, y, 1916) > 0.15:
					c = c.lerp(_c(PEINT_OS, clampi(t - 1, 0, 3)), 0.62)
			if r > 0.82:
				c = c.darkened(0.22)
			if k > 0 and dj == 0:
				c = _c(BOIS, 0)
			# trous et éclats
			for e: Vector3 in [Vector3(0.42, -0.38, 0.07), Vector3(-0.5, 0.36, 0.06), Vector3(-0.25, -0.55, 0.045), Vector3(0.2, 0.52, 0.05)]:
				var dd := Vector2(dx - e.x, (dy - e.y) * 1.6).length()
				if dd < e.z:
					c = _c(BOIS, 0) if dd < e.z * 0.7 else _c(BOIS, 6)
			# morceau arraché (bas à droite) : bord déchiqueté clair, bois noir derrière
			var cassure := dx * 0.7 + dy * 0.7 - 0.86 - (_h(int(dx * 20.0), 3, 1919) - 0.5) * 0.12
			if cassure > 0.0 and r < 1.0:
				c = _c(BOIS, 0) if cassure > 0.04 else _c(BOIS, 6)
			if r > 0.86 and r < 0.92:
				var ang := atan2(dy, dx)
				if posmod(int(roundf(ang / TAU * 18.0 * 4.0)), 4) == 0:
					c = _c(ROUILLE, 2) if dy < 0.0 else _c(ROUILLE, 1)
			img.set_pixel(o.x + x, o.y + y, c)

## Œil du draugr : orbite noire, braise bleu glacé au centre (le shader la fait luire : c'est le SEUL bleu du personnage).
static func _oeil(img: Image) -> void:
	var r := GuerrierTextures.R_OEIL
	for y in r.size.y:
		for x in r.size.x:
			var dx := (x - 7.5) / 7.5
			var dy := (y - 3.5) / 3.5
			var d := sqrt(dx * dx + dy * dy)
			var c := Color("#0a0908")
			if d < 0.62:
				c = Color("#2f5f8a")
			if d < 0.42:
				c = Color("#7fc2ee")
			if d < 0.2:
				c = Color("#d8f2ff")
			img.set_pixel(r.position.x + x, r.position.y + y, c)

static func _baudrier(img: Image) -> void:
	var r := GuerrierTextures.R_BAUD
	for y in r.size.y:
		for x in r.size.x:
			var t := _ton_cuir(x, y, r.size.x, r.size.y, 0.46, 1951)
			if x == 0 or x == r.size.x - 1:
				t = 0
			elif x == 1 or x == r.size.x - 2:
				t = 5 if _h(x, y, 1952) > 0.4 else 4
			if _n(x, y, r.size.x, r.size.y, 2, 10, 1953) > 0.78:
				t -= 2                                   # cuir craquelé
			_p(img, r.position.x + x, r.position.y + y, _c(CUIR, clampi(t, 0, 6)))
		if y % 16 == 8:
			_rivet(img, r.position.x + 7, r.position.y + y)

## Anneau ouvragé (médaillon, boucle) : entrelacs de fer terni, rouille dans les creux.
static func _anneau(img: Image) -> void:
	var r := GuerrierTextures.R_ANNEAU
	for y in r.size.y:
		for x in r.size.x:
			var ang := TAU * (x + 0.5) / r.size.x
			var lum := cos(ang - deg_to_rad(135.0))
			var d := posmod(x * 2 + absi(y - 16) / 3, 8)
			var t := 4 if d < 4 else 3
			if d == 0 or d == 4:
				t = 1
			t += int(roundf(lum * 1.2))
			if y < 3 or y > 28:
				t = 1
			elif y == 3 or y == 28:
				t = 5 if lum > 0.0 else 3
			var c := _c(FER, clampi(t + 1, 0, 6))
			if (d == 1 or d == 5) and _h(x, y, 1971) > 0.4:
				c = _c(ROUILLE, 1)
			img.set_pixel(r.position.x + x, r.position.y + y, c)

static func _bosse(img: Image) -> void:
	var r := GuerrierTextures.R_BOSSE
	for y in r.size.y:
		for x in r.size.x:
			var ang := TAU * (x + 0.5) / r.size.x
			var lum := cos(ang - deg_to_rad(135.0))
			var t := 3 + int(roundf(lum * 1.4))
			# croisillons gravés (médaillon de la référence)
			if posmod(x, 8) == 0 or posmod(y, 6) == 0:
				t -= 1
			if absf(wrapf(ang - deg_to_rad(135.0), -PI, PI)) < 0.5 and y > 4 and y < 16:
				t = 5
			if y > 26:
				t = 1
			img.set_pixel(r.position.x + x, r.position.y + y, _c(FER, clampi(t + 1, 0, 6)))

static func _fer(img: Image, r: Rect2i) -> void:
	for y in r.size.y:
		for x in r.size.x:
			var t := 4 if y < 8 else (3 if y < 16 else (2 if y < 24 else 3))
			if y == 0 or y == r.size.y - 1:
				t = 1
			if y == 2:
				t = 5
			var c := _c(FER, t + (1 if _h(x, y, 1921) > 0.92 else 0))
			if (y == 12 or y == 20) and x % 8 == 3:
				c = _c(FER, 6)
			elif _n(x, y, r.size.x, r.size.y, 4, 4, 1922) > 0.6 and t > 1:
				c = _c(ROUILLE, clampi(t - 1, 0, 3))
			img.set_pixel(r.position.x + x, r.position.y + y, c)

static func _umbo(img: Image) -> void:
	var r := GuerrierTextures.R_UMBO
	for y in r.size.y:
		for x in r.size.x:
			var ang := TAU * (x + 0.5) / r.size.x
			var lum := cos(ang - deg_to_rad(135.0))
			var t := 3 + int(roundf(lum * 1.6))
			if y < 5:
				t = 4
			if absf(wrapf(ang - deg_to_rad(135.0), -PI, PI)) < 0.3 and y > 6 and y < 14:
				t = 6
			if y > 27:
				t = 1 if y > 29 else 2
			var c := _c(FER, clampi(t, 0, 6))
			if _n(x, y, r.size.x, r.size.y, 6, 4, 1925) > 0.55 and t < 6:
				c = _c(ROUILLE, clampi(t - 1, 0, 3))
			img.set_pixel(r.position.x + x, r.position.y + y, c)

## Lame rouillée : fer brun-gris, plaques de rouille, fil clair ébréché (encoches sombres).
static func _lame(img: Image) -> void:
	var r := GuerrierTextures.R_LAME
	for y in r.size.y:
		for x in r.size.x:
			var t := 4
			if x <= 1 or x >= 14:
				t = 6
				if _h(y / 2, x / 8, 1932) > 0.72:
					t = 1                                 # ébréchure
			elif x == 2 or x == 13:
				t = 5
			elif x >= 6 and x <= 9 and y < 48:
				t = 2 if x == 6 else 3
			var c := _c(FER, t)
			if t >= 2 and t <= 5 and _n(x, y, r.size.x, r.size.y, 4, 12, 1931) > 0.5:
				c = _c(ROUILLE, clampi(t - 2, 0, 3))
			img.set_pixel(r.position.x + x, r.position.y + y, c)

static func _poignee(img: Image) -> void:
	var r := GuerrierTextures.R_POIGNEE
	for y in r.size.y:
		for x in r.size.x:
			var t := 3 if posmod(x + y, 4) < 2 else 1
			if posmod(x + y, 4) == 0:
				t = 0
			img.set_pixel(r.position.x + x, r.position.y + y, _c(CUIR, t))

static func _dos_bouclier(img: Image) -> void:
	var r := GuerrierTextures.R_DOS
	for y in r.size.y:
		for x in r.size.x:
			var lb := 0.36 + (_n(x, y, r.size.x, r.size.y, 4, 16, 1941) - 0.5) * 0.5
			var t := _ton(lb, 4, x, y, 1942)
			if posmod(x, 8) == 0:
				t = 0
			var c := _c(BOIS, t)
			if (y > 22 and y < 28) or (y > 38 and y < 44):
				c = _c(CUIR, 1 if (y == 23 or y == 39) else 2)
			img.set_pixel(r.position.x + x, r.position.y + y, c)

## Masque-crâne (32 x 32 texels, 5 mm/texel) : os ivoire sale, orbites profondes, cavité nasale, dents serrées, pommettes
## saillantes, joues creusées de chair desséchée ; bords fondus dans la chair (raccord avec le reste de la tête).
static func _crane(img: Image) -> void:
	var r := R_CRANE
	var oeils := [Vector2(10.4, 9.6), Vector2(21.6, 9.6)]
	for y in r.size.y:
		for x in r.size.x:
			var l := 0.62 + (_n(x, y, 32, 32, 5, 5, 1981) - 0.5) * 0.35 - absf(x - 15.5) / 15.5 * 0.25
			var c := _c(IVOIRE, _ton(l, 6, x, y, 1982, 0.35))
			# arcades sourcilières éclairées
			for e: Vector2 in oeils:
				var d := Vector2((x - e.x) / 4.2, (y - e.y) / 3.4)
				if d.length() < 1.0:
					c = _c(IVOIRE, 0) if d.length() < 0.75 else _c(IVOIRE, 1)
				elif d.y < -0.9 and d.y > -1.5 and absf(d.x) < 1.0:
					c = _c(IVOIRE, 5)
			# cavité nasale (cœur renversé)
			var nx := absf(x - 15.5)
			if y >= 13 and y <= 18 and nx < 0.5 + (y - 13) * 0.45 and not (y == 18 and nx < 0.6):
				c = _c(IVOIRE, 0) if nx < (y - 13) * 0.45 else _c(IVOIRE, 1)
			# pommettes
			for sg: float in [-1.0, 1.0]:
				var px := 15.5 + sg * 9.5
				if Vector2((x - px) / 3.0, (y - 15.0) / 1.6).length() < 1.0:
					c = _c(IVOIRE, 5 if y < 15 else 4)
			# joues creuses : chair desséchée sous les pommettes
			if nx > 6.0 and nx < 12.5 and y > 16 and y < 24:
				c = _c(CHAIR, clampi(_ton(0.5 + (_n(x, y, 32, 32, 4, 4, 1983) - 0.5) * 0.6, 5, x, y, 1984), 0, 4))
			# dents : deux rangées, interstices sombres, lèvre retroussée
			if nx < 6.0 and y >= 20 and y <= 26:
				if y == 23:
					c = _c(IVOIRE, 0)
				elif posmod(x, 2) == 0 and y != 20 and y != 26:
					c = _c(IVOIRE, 1)
				else:
					c = _c(IVOIRE, 5 if y < 23 else 4)
				if y == 20 or y == 26:
					c = _c(CHAIR, 1)
			# mâchoire / menton
			if y > 26:
				c = _c(IVOIRE, 3 if nx < 4.0 else 2)
				if nx > 7.0:
					c = _c(CHAIR, 2)
			# fissures
			if (x == 13 and y >= 1 and y < 5) or (x == 14 and y >= 4 and y < 6) or (x == 20 and y >= 2 and y < 4):
				c = _c(IVOIRE, 1)
			# bords fondus dans la chair desséchée (raccord)
			var bord := mini(mini(x, 31 - x), 31 - y + 4)
			if bord < 3 and not (nx < 6.0 and y >= 20):
				c = _c(CHAIR, 1 + bord)
			img.set_pixel(r.position.x + x, r.position.y + y, c)

## Dôme du casque (56 x 64 : u = tour, v = sommet -> bord) : 4 plaques de fer rouillé entre des bandes rivées (spangenhelm),
## éclairage peint en haut, coulures de rouille vers le bord, bosses et éraflures.
static func _casque(img: Image) -> void:
	var r := R_CASQUE
	for y in r.size.y:
		for x in r.size.x:
			var bande := posmod(x, 14)
			var l := 0.55 - float(y) / r.size.y * 0.25 + (_n(x, y, r.size.x, r.size.y, 6, 8, 1991) - 0.5) * 0.35
			var t := _ton(l, 6, x, y, 1992, 0.3)
			var c := _c(FER, t)
			if _n(x, y, r.size.x, r.size.y, 8, 10, 1993) > 0.58 or (y > 40 and _h(x, y, 1994) < (y - 40) / 40.0):
				c = _c(ROUILLE, clampi(t - 1, 0, 3))
			if bande <= 2:
				c = _c(FER, [1, 5, 3][bande])
				if bande == 1 and y % 8 == 4:
					c = _c(FER, 6)
			img.set_pixel(r.position.x + x, r.position.y + y, c)

## Épaulières (64 x 64, u = avant -> arrière, v = haut -> bas) : lames de fer superposées (bord clair en haut, ombre sous la
## lame), rivets en rang, rouille ; écailles de la référence lues comme des lames de 8 texels.
static func _epaul(img: Image) -> void:
	var r := R_EPAUL
	for y in r.size.y:
		for x in r.size.x:
			var off := int(_h(y / 8, 0, 2001) * 4.0)
			var ly := posmod(y + off, 8)
			var t := 4 - ly / 3
			if ly == 0:
				t = 5
			elif ly == 7:
				t = 0
			t += int(roundf((_n(x, y, 64, 64, 8, 8, 2002) - 0.5) * 1.6))
			var c := _c(FER, clampi(t, 0, 6))
			if _n(x, y, 64, 64, 6, 6, 2003) > 0.74 and ly != 0 and ly != 7:
				c = _c(ROUILLE, clampi(t - 1, 0, 3))
			if ly == 2 and posmod(x + (y / 8) * 3, 7) == 0:
				_rivet(img, r.position.x + x, r.position.y + y)
				continue
			img.set_pixel(r.position.x + x, r.position.y + y, c)

# ------------------------------------------------------------------ atlas des découpes (192 x 128) : tabard + mèches
## Tabard / ptéruges (112 x 128, u = autour du corps, v = 0 en haut -> 1 en bas) : tissu cendré grossier, plis, taches,
## lambeaux pendants en dents irrégulières (comme des glaçons sur la référence), trous rongés.
static func _tabard() -> Image:
	var W := 112
	var H := 128
	var img := _img(W, H, Color(0, 0, 0, 0))
	for y in H:
		for x in W:
			var pli := _n(x, 0, W, 1, 14, 1, 2011)
			var l := 0.42 + (pli - 0.5) * 0.5 + (_n(x, y, W, H, 20, 12, 2012) - 0.5) * 0.18 + (0.05 if ((x + y) & 3) < 2 else -0.04)
			var c := _c(TISSU, _ton(l, 6, x, y, 2013, 0.3))
			# bord tissé (ancienne broderie, à peine lisible)
			if y >= 6 and y <= 9:
				c = _c(TISSU, 4 if (x + y) % 4 < 2 else 2)
			# lambeaux : dents de 3-6 texels, longueur variable (bas : v > 0,55)
			var dent := int(x / 4.0 + _h(x / 4, 3, 2014))
			var fin := int(H * (0.62 + _h(dent, 0, 2015) * 0.36))
			var larg := 1.0 - float(y - (fin - 22)) / 22.0     # la dent s'amincit vers le bas
			if y > fin or (y > fin - 22 and absf(posmod(x, 4) - 1.5) > 2.0 * larg + 0.2):
				c = Color(0, 0, 0, 0)
			elif y > fin - 2:
				c = _c(TISSU, 0)
			# trous rongés
			if _n(x, y, W, H, 12, 14, 2016) > 0.84 and y > 14:
				c = Color(0, 0, 0, 0)
			if c.a > 0.0 and _n(x, y, W, H, 8, 8, 2017) > 0.72:
				c = c.darkened(0.2)          # taches
			img.set_pixel(x, y, c)
	return img

static func decoupes() -> Image:
	var img := _img(GuerrierTextures.DECOUPES.x, GuerrierTextures.DECOUPES.y, Color(0, 0, 0, 0))
	var t := _tabard()
	img.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), R_TABARD.position)
	var m := meches()
	img.blit_rect(m, Rect2i(Vector2i.ZERO, m.get_size()), GuerrierTextures.D_MECHES.position)
	return img
