class_name DraugrTextures
## Textures du Draugr nordique (DraugrNordique), peintes par code comme celles du guerrier (GuerrierTextures : 128 texels/m,
## mêmes UV métriques, mipmaps pixel art par vote de couleur, jamais de tramage Bayer), dans les palettes du mort-vivant de la
## référence (Image ChatGPT 14_01_59-5) : mailles BRUN-GRIS FERREUX rongées de rouille, os ivoire sale, chair desséchée gris-brun,
## fer corrodé, cuir noirci, tissu cendré en lambeaux, fourrure gris-brun sale à pointes claires, bois de bouclier délavé.
## AUCUN bleu, sauf l'œil luisant (R_OEIL, émissif par le shader ps1_draugr).
## Atlas des accessoires et des découpes : MÊME disposition que GuerrierTextures (les fonctions de géométrie du guerrier,
## appelées telles quelles, y lisent leurs régions), plus des régions propres (crâne, casque, épaulières) dans la place libre.


# palettes (sombre -> clair)
const GIVRE := Color(0.72, 0.72, 0.70)   # givre neutre (jamais de blanc brûlé, pas de bleu)
const MAILLE := ["#1e1d1b", "#32302d", "#484644", "#605d59", "#79756e", "#9a9893"]   # brun-gris ferreux (chaud : la lumière de 17h30 le refroidit)
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
const BOIS_V := ["#0a0908", "#171513", "#24211e", "#33302b", "#433f39", "#544f47", "#6a645a"]   # passe 2 : vieux bois gris-noir
const TISSU_BLEU := ["#131314", "#1f2022", "#2e2f33", "#404247", "#55575d", "#6f7176"]   # laine gris-ardoise à peine bleutée (jupe de la référence ; le test interdit le bleu franc hors des yeux)
const BANDE := ["#2e2a24", "#464037", "#5f574b", "#7a705f"]

const DOSSIER := "res://assets/persos/draugr"
const VERSION := 13
static var enregistrer := false
static var _cache := {}

# régions propres (texels de l'atlas 256 x 256 des accessoires)
const R_CRANE := Rect2i(136, 128, 32, 32)     # masque-crâne : x = visage de -0,085 à +0,085 m, y = de 1,745 à 1,585 m
const R_CASQUE := Rect2i(200, 128, 56, 64)    # dôme du casque : u = tour (0 = devant), v = sommet (0) -> bord (63)
const R_EPAUL := Rect2i(136, 192, 64, 64)     # épaulières : lames de fer superposées, rivets
const R_TABARD := Rect2i(0, 0, 112, 128)      # (atlas des découpes) tabard et ptéruges en lambeaux
const R_LAMB := Rect2i(128, 40, 32, 64)       # (atlas des découpes) lanières de la cape : tissu cendré, trous, v = 0 en haut
const R_OSS := Rect2i(0, 212, 64, 32)         # côtes / clavicules : moitié gauche os ivoire, moitié droite chair desséchée creuse

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
				"lambeaux": img = lambeaux()
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
			var lan := x / 10
			var tri := absf(posmod(x, 10) - 4.5) / 4.5     # 0 au centre de la dent, 1 entre deux dents
			var coupe := 3 + int(_h(lan, 0, 1819) * 10.0) + int(tri * (6.0 + _h(lan, 2, 1824) * 14.0))
			if vy < coupe and _h(lan, 1, 1820) < 0.8:
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
			# trame de laine : fils verticaux irréguliers, plis horizontaux sombres
			var l := 0.42 + (_n(x, y, W, H, 14, 5, 1831) - 0.5) * 0.36 + (0.06 if (x & 1) == 0 else -0.04)
			var c := _c(TISSU, _ton(l, 5, x, y, 1832))
			if vy >= 2 and vy < 96:
				# bandelettes enroulées : bandes horizontales de 9 texels, pente douce, lisière haute claire, ombre dessous
				var dec := int(vy + _n(x, y, W, H, 4, 3, 1833) * 3.0)
				var d := posmod(dec, 14)
				if d < 10:
					var t := 1 + (1 if d == 1 or d == 2 else 0) - (1 if d >= 8 else 0)
					t += int(roundf((_n(x, y, W, H, 10, 5, 1834) - 0.5) * 1.6))
					c = _c(BANDE, clampi(t, 0, 3))
					# fils de la bandelette (courts traits obliques)
					if posmod(x + d, 4) == 0 and d > 1 and d < 8:
						c = c.darkened(0.15)
				else:
					c = _c(TISSU, 1)
				# bouts qui se décollent : trous rongés
				if _n(x, y, W, H, 16, 8, 1837) > 0.84 and _h(x, y, 1838) > 0.3:
					c = _c(TISSU, 0)
			# lanière de cuir verticale avec rivets (couture extérieure de la jambe)
			if vy >= 10 and vy < 96:
				var e := posmod(x, 64)
				if e >= 30 and e < 34:
					c = _c(CUIR, [0, 4, 3, 1][e - 30])
					if e == 31 and vy % 11 == 5:
						c = _c(FER, 5)
			# boue / crasse en bas
			if vy < 26 and _h(x, y, 1836) < (26 - vy) / 38.0:
				c = c.darkened(0.3)
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
			var c := _c(CUIR, _ton_cuir(x, y, W, H, 0.36, 1841) - 1)
			if vy < 3:
				c = _c(CUIR, 0)
			elif vy < 8:
				c = _c(CUIR, 1 + (1 if _h(x, y, 1845) > 0.7 else 0))     # semelle crottée
			elif vy < 50:
				# bandes de cuir/tissu enroulées en spirale serrée, lisière claire usée, couture en pointillé
				var a := posmod(x + int(vy * 1.5) + int(_n(x, y, W, H, 8, 4, 1846) * 2.0), 12)
				if a < 8:
					var t := 2 + (1 if a == 1 else 0) - (1 if a >= 6 else 0)
					c = _c(CUIR, clampi(t + int(roundf((_n(x, y, W, H, 12, 6, 1847) - 0.5) * 1.6)), 0, 5))
				else:
					c = _c(CUIR, 0)
				if a == 1 and (vy & 3) == 0:
					c = _c(CUIR, 6)
				# sangle large avec boucle
				if vy >= 22 and vy < 29:
					c = _c(CUIR, 3 + (1 if vy == 23 else 0) - (1 if vy >= 27 else 0))
					if vy == 25 and x % 8 == 3:
						c = _c(CUIR, 6)
					if x >= 60 and x < 70:
						c = _c(FER, 4 if vy > 22 and vy < 28 else 1)
						if x >= 63 and x < 67 and vy > 23 and vy < 27:
							c = _c(FER, 1)
			if vy > 50:
				var f := _n(x, y, W, H, 32, 4, 1844)
				c = _c(FOUR, 3 + int(f * 3.0) + (1 if vy > 53 else 0))     # revers plus crème
				if posmod(x * 7 + vy, 5) == 0:
					c = _c(FOUR, 1)
			if vy < 18 and _h(x, y, 1848) < (18 - vy) / 40.0:
				c = c.darkened(0.25)
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
			var cf := _c(FOUR, ton)
			if t > 0.55 and ton > 1 and _h(x, y0 + k, 1899) > 0.62:
				cf = cf.lerp(GIVRE, 0.4)     # givre sur les pointes
			_p(img, x, y0 + k, cf)

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
	_oss(img)
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
	for x in range(0, r.size.x, 3):
		_p(img, r.position.x + x, r.position.y + 3, _c(CUIR, 6))
		_p(img, r.position.x + x, r.position.y + r.size.y - 4, _c(CUIR, 6))
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
			var base := 0.30 + _h(k, 0, 1912) * 0.20
			var lb := base + (_n(x, y, n, n, 10, 3, 1911 + k) - 0.5) * 0.30 + (_h(x, k, 1918) - 0.5) * 0.2
			var t := clampi(_ton(lb, 5, x, y, 1913, 0.2) + 1, 1, 5)
			if dj == 1 and k > 0:
				t = 4
			var c := _c(BOIS_V, t)
			# rune en étoile (croix + diagonales), peinte en os pâle, écaillée
			var a := atan2(dy, dx)
			var bras := absf(sin(a * 4.0)) < 0.16 + 0.05 / maxf(r, 0.05)
			if bras and r > 0.16 and r < 0.78 and dj > 1:
				if _n(x, y, n, n, 7, 7, 1917) < 0.7 and _h(x, y, 1916) > 0.15:
					c = c.lerp(_c(PEINT_OS, clampi(t - 1, 0, 3)), 0.62)
			if r > 0.82:
				c = c.darkened(0.22)
			if k > 0 and dj == 0:
				c = _c(BOIS_V, 0)
			# fentes : fissures qui serpentent le long des planches (arête claire à droite)
			for fi in 5:
				var fx := 8 + int(_h(fi, 0, 1951) * (n - 16))
				var y0 := int(_h(fi, 1, 1952) * n * 0.6)
				var yl := 18 + int(_h(fi, 2, 1953) * 44)
				var cx := fx + int(roundf(sin(y * 0.21 + fi * 2.0) * 2.0))
				if y >= y0 and y < y0 + yl and r < 0.92:
					if x == cx:
						c = _c(BOIS_V, 0)
					elif x == cx + 1:
						c = _c(BOIS_V, 5)
			# trous et éclats
			for e: Vector3 in [Vector3(0.42, -0.38, 0.07), Vector3(-0.5, 0.36, 0.06), Vector3(-0.25, -0.55, 0.045), Vector3(0.2, 0.52, 0.05)]:
				var dd := Vector2(dx - e.x, (dy - e.y) * 1.6).length()
				if dd < e.z:
					c = _c(BOIS_V, 0) if dd < e.z * 0.7 else _c(BOIS_V, 6)
			# morceau arraché (bas à droite) : bord déchiqueté clair, bois noir derrière
			var cassure := dx * 0.7 + dy * 0.7 - 0.86 - (_h(int(dx * 20.0), 3, 1919) - 0.5) * 0.12
			if cassure > 0.0 and r < 1.0:
				c = _c(BOIS_V, 0) if cassure > 0.04 else _c(BOIS_V, 6)
			if r > 0.86 and r < 0.92:
				var ang := atan2(dy, dx)
				if posmod(int(roundf(ang / TAU * 18.0 * 4.0)), 4) == 0:
					c = _c(ROUILLE, 3) if dy < 0.0 else _c(ROUILLE, 2)
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
			elif _n(x, y, r.size.x, r.size.y, 4, 4, 1922) > 0.48 and t > 1:
				c = _c(ROUILLE, clampi(t - 1, 1, 3))
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
			var t := 3
			if x <= 1 or x >= 14:
				t = 5
				if _h(y / 3, x / 8, 1932) > 0.85:
					t = 2                                 # ébréchure
			elif x == 2 or x == 13:
				t = 5
			elif x >= 6 and x <= 9 and y < 48:
				t = 2 if x == 6 else 3
			var c := _c(FER, t)
			if t >= 2 and t <= 5 and _n(x, y, r.size.x, r.size.y, 4, 12, 1931) > 0.38:
				c = _c(ROUILLE, clampi(t - 2, 0, 3))
			if t >= 2 and t <= 5 and _n(x, y, r.size.x, r.size.y, 3, 5, 1933) > 0.62:
				c = _c(ROUILLE, 0).lerp(_c(FER, 2), 0.3)
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
			var c := _c(BOIS_V, t)
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

## Épaulières en DÔME (64 x 64, u = tour en 9 pans, v = sommet -> collerette) : fer bombé terni, reflet clair au sommet,
## 9 pans séparés par des nervures, couronne de rivets en bas de la coupole, collerette sombre, rouille en coulures.
## C10 (armure usée) : fond plus sombre, nervure en creux noir + arête claire, bosses (enfoncements sombres à lèvre claire),
## rayures claires en biais, bord de la collerette usé jusqu'au métal (liseré clair ébréché) : la coque ne se lit plus en aplat.
static func _epaul(img: Image) -> void:
	var r := R_EPAUL
	var bosses := [Vector2(14, 20), Vector2(41, 12), Vector2(52, 33), Vector2(25, 38)]
	for y in r.size.y:
		for x in r.size.x:
			var fx := int(fposmod(x * 9.0 / 64.0, 1.0) * 8.0)
			var t := 3 - y / 24
			t += int(roundf((_n(x, y, 64, 64, 8, 8, 2002) - 0.5) * 2.0))
			if y < 9:
				t += 1                                        # reflet au sommet
			var c := _c(FER, clampi(t, 0, 6))
			if _n(x, y, 64, 64, 6, 6, 2003) > 0.62 or (y > 40 and _h(x, y, 2004) < (y - 40) / 50.0):
				c = _c(ROUILLE, clampi(t - 1, 0, 3))
			for b: Vector2 in bosses:                          # bosses : creux sombre, lèvre claire en haut
				var d := Vector2(x, y).distance_to(b)
				if d < 3.2:
					c = _c(FER, 0 if d < 2.0 else 1)
				elif d < 4.4 and y < b.y:
					c = _c(FER, 5)
			if y < 46 and posmod(x * 2 - y * 3 + 7, 37) == 0 and _h(x, y, 2005) > 0.35:
				c = _c(FER, 5)                                # rayure claire
			if fx == 0:
				c = _c(FER, 0)                                # nervure en creux noir
			elif fx == 1:
				c = _c(FER, 5) if y < 44 else c               # arête claire
			if y >= 50:
				c = _c(FER, 1 if y > 58 else 2)               # collerette
				if y == 63 or (y == 62 and _h(x, y, 2006) > 0.55):
					c = _c(FER, 6 if _h(x, y, 2007) > 0.3 else 4)   # bord usé jusqu'au métal
			elif y == 49:
				c = _c(FER, 6)
			img.set_pixel(r.position.x + x, r.position.y + y, c)
	for k in range(0, 9):
		var cx := r.position.x + int((k + 0.5) * 64.0 / 9.0)
		_rivet(img, cx - 1, r.position.y + 45)
		_rivet(img, cx - 1, r.position.y + 54)

## Côtes / clavicules (R_OSS : 64 x 32) : moitié gauche = os ivoire sale (arête claire en haut, ombre dessous), moitié droite =
## chair desséchée creuse, très sombre (fond entre les côtes).
static func _oss(img: Image) -> void:
	var r := R_OSS
	for y in 32:
		for x in 32:
			var l := 0.60 - float(y) / 32.0 * 0.35 + (_n(x, y, 32, 32, 6, 6, 2021) - 0.5) * 0.3
			var t := _ton(l, 6, x, y, 2022, 0.3)
			if y < 3:
				t = 5
			elif y > 28:
				t = 0
			img.set_pixel(r.position.x + x, r.position.y + y, _c(IVOIRE, clampi(t, 0, 5)))
			var q := 0.30 + (_n(x, y, 32, 32, 5, 7, 2023) - 0.5) * 0.7
			var ch := _c(CHAIR, _ton(q, 5, x, y, 2024, 0.3) - 1)
			if posmod(x + y * 2, 11) == 0 and _h(x, y, 2025) > 0.5:
				ch = _c(CHAIR, 0)
			img.set_pixel(r.position.x + 32 + x, r.position.y + y, ch)

# ------------------------------------------------------------------ atlas des découpes (192 x 128) : tabard + mèches
## Tabard / ptéruges (112 x 128, u = autour du corps, v = 0 en haut -> 1 en bas) : tissu cendré grossier, plis, taches,
## lambeaux pendants en dents irrégulières (comme des glaçons sur la référence), trous rongés.
static func _tabard() -> Image:
	var W := 112
	var H := 128
	var img := _img(W, H, Color(0, 0, 0, 0))
	# dents triangulaires : largeurs 7 à 14 texels, une sur quatre COURTE (échancrure), pointes décalées
	var bornes := [0]
	var i := 0
	while bornes[-1] < W:
		bornes.append(bornes[-1] + 5 + int(_h(i, 5, 2031) * 6.0))
		i += 1
	for y in H:
		for x in W:
			var pli := _n(x, 0, W, 1, 14, 1, 2011)
			var l := 0.42 + (pli - 0.5) * 0.5 + (_n(x, y, W, H, 20, 12, 2012) - 0.5) * 0.18 + (0.05 if ((x + y) & 3) < 2 else -0.04)
			var c := _c(TISSU_BLEU, _ton(l, 6, x, y, 2013, 0.3))
			if y >= 4 and y <= 5:
				c = _c(TISSU_BLEU, 5 if _h(x, y, 2014) > 0.3 else 4)     # galon clair en haut
			elif y >= 6 and y <= 15:
				# bande brodée nordique : chaîne de losangues entrelacés
				var px := posmod(x, 12)
				var r := y - 6
				var dd := absi(px - 6) + absi(r - 4)
				c = _c(TISSU_BLEU, 1)
				if dd == 4 or dd == 3 and (r == 4 or px == 6):
					c = _c(TISSU_BLEU, 5 if _h(x, y, 2015) > 0.25 else 4)
				elif dd == 1:
					c = _c(TISSU_BLEU, 3)
			elif y == 16:
				c = _c(TISSU_BLEU, 4)
			var d := 0
			while d < bornes.size() - 2 and x >= bornes[d + 1]:
				d += 1
			var x0: int = bornes[d]
			var x1: int = bornes[d + 1]
			var cxd := x0 + (x1 - x0) * (0.25 + 0.5 * _h(d, 1, 2032))
			var court := _h(d, 0, 2033) < 0.38
			var fin := int(H * ((0.52 + _h(d, 2, 2034) * 0.12) if court else (0.74 + _h(d, 2, 2034) * 0.25)))
			var prof := 40.0 if not court else 18.0
			var t0 := clampf(float(y - (fin - prof)) / prof, 0.0, 1.0)     # 0 en haut de la dent, 1 à la pointe
			var demi := (x1 - x0) * 0.5 * (1.0 - t0) + 0.4
			var bas := y > fin - prof
			var ecart := absf(x + 0.5 - cxd)
			if y > fin or (bas and ecart > demi):
				c = Color(0, 0, 0, 0)
			elif bas and ecart > demi - 1.6:
				c = _c(TISSU_BLEU, 5 if _h(x, y, 2016) > 0.45 else 3)     # lisière effilochée claire
			# trous : losanges et triangles (cellules de 26 x 22 texels, 45 % occupées)
			var gx := x / 26
			var gy := y / 22
			if gy >= 1 and _h(gx, gy, 2035) < 0.55:
				var hx := gx * 26 + 6 + int(_h(gx, gy, 2036) * 14.0)
				var hy := gy * 22 + 5 + int(_h(gx, gy, 2037) * 10.0)
				var rr := 3 + int(_h(gx, gy, 2038) * 4.0)
				var dd := absi(x - hx) + absi(y - hy)
				if (_h(gx, gy, 2039) < 0.5 and dd < rr) or (_h(gx, gy, 2039) >= 0.5 and absi(x - hx) * 2 + maxi(0, y - hy) * 2 < rr * 2 and y >= hy - rr and y < hy + rr):
					c = Color(0, 0, 0, 0)
				elif dd == rr and c.a > 0.0:
					c = _c(TISSU_BLEU, 0)
			if c.a > 0.0 and _n(x, y, W, H, 8, 8, 2017) > 0.72:
				c = c.darkened(0.2)
			if c.a > 0.0 and y > 17 and (_n(x, y, W, H, 10, 5, 2018) > 0.86 or (bas and ecart > demi - 2.4 and _h(x, y, 2019) > 0.6)):
				c = c.lerp(GIVRE, 0.4)     # givre gris-blanc accroché aux plis et aux pointes
			img.set_pixel(x, y, c)
	return img

## Lanière de cape (32 x 64) : tissu cendré rongé, couture, bord sombre, quelques trous.
static func _lamb() -> Image:
	var img := _img(32, 64, Color(0, 0, 0, 0))
	for y in 64:
		for x in 32:
			var pli := _n(x, 0, 32, 1, 4, 1, 2044)     # plis verticaux
			var l := 0.45 - float(y) / 64.0 * 0.14 + (pli - 0.5) * 0.45 + (_n(x, y, 32, 64, 5, 8, 2041) - 0.5) * 0.4 + (0.05 if ((x + y) & 3) < 2 else -0.04)
			var c := _c(TISSU, _ton(l, 6, x, y, 2042, 0.3))
			if posmod(x, 16) < 2 or posmod(x, 16) > 13:
				c = _c(TISSU, 0)
			elif posmod(x, 16) == 2 or posmod(x, 16) == 13:
				c = _c(TISSU, 1)     # couture
			var rong := _n(x, y, 32, 64, 6, 10, 2043)
			if rong > 0.72 and y > 6:
				c = Color(0, 0, 0, 0)
			elif rong > 0.67 and y > 6 and c.a > 0.0:
				c = _c(TISSU, 5 if _h(x, y, 2045) > 0.5 else 0)     # bord de déchirure : fil clair ou noirci
			elif c.a > 0.0 and y > 4 and _n(x, y, 32, 64, 7, 6, 2046) > 0.84:
				c = c.lerp(GIVRE, 0.5)     # givre
			img.set_pixel(x, y, c)
	return img

static func decoupes() -> Image:
	var img := _img(GuerrierTextures.DECOUPES.x, GuerrierTextures.DECOUPES.y, Color(0, 0, 0, 0))
	var t := _tabard()
	img.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), R_TABARD.position)
	var m := meches()
	img.blit_rect(m, Rect2i(Vector2i.ZERO, m.get_size()), GuerrierTextures.D_MECHES.position)
	var lb := _lamb()
	img.blit_rect(lb, Rect2i(Vector2i.ZERO, lb.get_size()), R_LAMB.position)
	return img

## Jupe et cape en lambeaux MODELÉS dans Blender (sources_blender/scripts/draugr_lambeaux.py) : relief CUIT (AO + courbure,
## détail -> léger) lu dans lambeaux_bake.png (R = AO, G = courbure 0,5 neutre, B = distance au sommet / 1,2 m, A = 1 jupe /
## 0,5 cape / 0 trou), QUANTIFIÉ ici dans les palettes du draugr (aplats 5-6 tons, creux sombres, arêtes claires, lisière
## effilochée). 256 x 512 texels à 128 texels/m. Jamais de normal map.
const BAKE_LAMBEAUX := "res://assets/persos/draugr/blender/lambeaux_bake.png"

static func _flou(plan: PackedFloat32Array, w: int, h: int, alpha: PackedByteArray) -> PackedFloat32Array:
	var r := PackedFloat32Array()
	r.resize(w * h)
	for y in h:
		for x in w:
			var somme := 0.0
			var cnt := 0.0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx
					var yy := y + dy
					if xx < 0 or yy < 0 or xx >= w or yy >= h or alpha[yy * w + xx] == 0:
						continue
					somme += plan[yy * w + xx]
					cnt += 1.0
			r[y * w + x] = somme / cnt if cnt > 0.0 else 0.5
	return r

static func lambeaux() -> Image:
	var src := Image.load_from_file(ProjectSettings.globalize_path(BAKE_LAMBEAUX))
	if src == null:
		push_error("DraugrTextures : bake des lambeaux introuvable (" + BAKE_LAMBEAUX + ")")
		return _img(8, 8, Color(0, 0, 0, 0))
	src.convert(Image.FORMAT_RGBA8)
	var W := src.get_width()
	var H := src.get_height()
	var al := PackedByteArray()
	var ao := PackedFloat32Array()
	var cu := PackedFloat32Array()
	al.resize(W * H)
	ao.resize(W * H)
	cu.resize(W * H)
	for y in H:
		for x in W:
			var c := src.get_pixel(x, y)
			al[y * W + x] = 0 if c.a < 0.25 else (1 if c.a < 0.75 else 2)     # 0 trou, 1 cape, 2 jupe
			ao[y * W + x] = c.r
			cu[y * W + x] = c.g
	var cu_f := _flou(cu, W, H, al)
	var img := _img(W, H, Color(0, 0, 0, 0))
	for y in H:
		for x in W:
			var k := al[y * W + x]
			if k == 0:
				continue
			var c := src.get_pixel(x, y)
			var t := c.b * 1.2                                # mètres depuis le sommet de la lanière
			var jupe := k == 2
			var pal: Array = TISSU_BLEU if jupe else TISSU
			# tissu : plis verticaux + trame, puis relief cuit (creux de l'AO sombres, arêtes de la courbure claires)
			var pli := _n(x, 0, W, 1, 40, 1, 2051)
			var l := 0.62 + (pli - 0.5) * 0.30 + (_n(x, y, W, H, 14, 28, 2052) - 0.5) * 0.22 + (0.04 if ((x + y) & 3) < 2 else -0.03)
			l += (ao[y * W + x] - 0.72) * 0.42
			l += (cu_f[y * W + x] - 0.55) * 0.55
			l -= minf(t, 0.5) * 0.12                          # le bas des lanières est plus sale
			var ton := _ton(l, 6, x, y, 2053, 0.28)
			var cc := _c(pal, ton)
			if jupe and t < 0.026:
				cc = _c(pal, 5 if t > 0.020 or _h(x, y, 2054) > 0.4 else 3)          # galon clair en haut
			elif jupe and t < 0.048:
				cc = _c(pal, 1)
			# lisière effilochée : fil clair ou noirci sur le bord de découpe
			var bord := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx := x + d.x
				var yy := y + d.y
				if xx < 0 or yy < 0 or xx >= W or yy >= H or al[yy * W + xx] == 0:
					bord = true
			if bord and t > 0.05:
				cc = _c(pal, 5 if _h(x, y, 2055) > 0.45 else 0)
			elif t > 0.05 and ton >= 4 and _n(x, y, W, H, 9, 17, 2056) > 0.84:
				cc = cc.lerp(GIVRE, 0.4)                      # givre dans les plis
			img.set_pixel(x, y, Color(cc.r, cc.g, cc.b, 1.0))
	return img
