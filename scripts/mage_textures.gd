class_name MageTextures
## Textures du Mage nordique (MageNordique), même recette que GuerrierTextures (128 texels/m, palettes froides de 4 à 6 tons,
## contours et rehauts peints, bruit seulement, mipmaps pixel art par vote) : les outils (_c, _h, _n, _ton, _p, mips_pixel,
## _touffe, _anneau, _bosse, _fer, _poignee) sont APPELÉS dans GuerrierTextures, rien n'y est modifié.
## Matières : robe de laine épaisse bleu ardoise (plis larges, bande brodée de runes sur le devant et à l'ourlet, ourlet
## UNI sombre + arête claire : plus aucun motif périodique fin, cause du « damier » des anciennes robes), capuche de laine
## gris-brun sombre, barbe grise, bâton de bois brun-gris gravé de runes, cristal de glace à facettes.

# palettes (sombre -> clair)
## passe 2 : robe quasi noire, ardoise très sombre à peine froide (la passe 1 virait au bleu marine au crépuscule)
const ROBE := ["#0a0a0d", "#111216", "#1a1c21", "#262a31", "#353b45", "#4c5663", "#6c7a8b"]
## broderies : fil bleu pâle glacé (les runes ressortent sur la robe noire, sans saturation « plastique »)
const BRODERIE := ["#1f2a36", "#3f5a74", "#6f93b5", "#9dbfdc", "#c9e0f2"]
const CAPUCHE := ["#08080a", "#0e0e11", "#151518", "#1d1d21", "#26262b", "#313136", "#3f3e44"]
## pèlerine de laine par-dessus la robe : gris anthracite un peu plus chaud que la robe (les deux couches se distinguent)
const PELERINE := ["#121111", "#1b1a19", "#252321", "#302d2b", "#3c3835", "#4b4642", "#5d5752"]
const BARBE := ["#2b2a2b", "#4a4849", "#6c6a6a", "#8f8d8b", "#b1aeaa", "#cfccc6"]
const CRISTAL := ["#132447", "#1f3d75", "#2f5fb0", "#5a8fe0", "#9cc4f5", "#d6ebff"]
## orbe de glace : du bleu profond au blanc glacé (cœur), lumineux (surface émissive)
const ORBE := ["#0a1d48", "#123a80", "#1d62bf", "#3a8ae4", "#62b0f4", "#9ad2ff"]
const RUNE_BOIS := ["#7d8fa6", "#a9bdd2", "#cfe0ee"]                          # entaille des runes : bois clair givré, un peu bleu

## Runes (futhark simplifié) en segments sur une grille 4 x 6 : [x0, y0, x1, y1] ; tracées en 1 texel.
const RUNES := [
	[[0, 0, 0, 6], [0, 1, 3, 0], [0, 3, 3, 2]],                 # fehu
	[[0, 0, 0, 6], [0, 0, 3, 3], [3, 3, 3, 6]],                 # uruz
	[[1, 0, 1, 6], [1, 1, 3, 3], [3, 3, 1, 5]],                 # thurisaz
	[[0, 0, 0, 6], [0, 0, 3, 2], [0, 2, 3, 4]],                 # ansuz
	[[0, 0, 0, 6], [0, 0, 3, 2], [3, 2, 0, 3], [0, 3, 3, 6]],   # raido
	[[3, 0, 0, 3], [0, 3, 3, 6]],                               # kenaz
	[[0, 0, 3, 6], [3, 0, 0, 6]],                               # gebo
	[[0, 0, 0, 6], [3, 0, 3, 6], [0, 2, 3, 4]],                 # hagalaz
	[[1, 0, 1, 6], [0, 2, 3, 4]],                               # naudiz
	[[1, 0, 1, 6], [0, 1, 1, 0], [1, 0, 2, 1]],                 # tiwaz (pointe)
	[[0, 0, 0, 6], [0, 0, 3, 1], [0, 3, 3, 4]],                 # laguz/berkana
	[[0, 6, 1.5, 0], [1.5, 0, 3, 6], [0, 3, 3, 3]],             # algiz inversé stylisé
]

static var _cache := {}

const DOSSIER := "res://assets/personnages/mage"
const VERSION := 4
static var enregistrer := false

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
				"robe_haut": img = robe_haut()
				"capuche": img = capuche()
				"barbe": img = barbe()
				"fourrure": img = fourrure()
				"accessoires": img = accessoires()
				"decoupes": img = decoupes()
				"cristal": img = cristal()
				"orbe": img = orbe()
				"pelerine": img = pelerine()
				_: push_error("MageTextures : texture inconnue " + nom)
			mips = GuerrierTextures.mips_pixel(img)
			sauver(nom, mips)
		_cache[nom] = ImageTexture.create_from_image(mips)
	return _cache[nom]

static func vider() -> void:
	_cache.clear()

static func _c(pal: Array, i: int) -> Color:
	return Color(pal[clampi(i, 0, pal.size() - 1)])

## Trace une rune (indice k) dont le coin haut gauche est (x0, y0), échelle 1 (4 x 6 texels) ; couleur c, ombre sous le trait.
static func _rune(img: Image, k: int, x0: int, y0: int, c: Color, ombre: Color, echelle := 1.0) -> void:
	for seg: Array in RUNES[posmod(k, RUNES.size())]:
		var a := Vector2(seg[0], seg[1]) * echelle
		var b := Vector2(seg[2], seg[3]) * echelle
		var n := int(ceilf(maxf(absf(b.x - a.x), absf(b.y - a.y)))) + 1
		for i in n:
			var p := a.lerp(b, float(i) / maxf(1.0, n - 1))
			var x := x0 + int(roundf(p.x))
			var y := y0 + int(roundf(p.y))
			GuerrierTextures._p(img, x, y + 1, ombre)
		for i in n:
			var p := a.lerp(b, float(i) / maxf(1.0, n - 1))
			GuerrierTextures._p(img, x0 + int(roundf(p.x)), y0 + int(roundf(p.y)), c)

## Laine épaisse (robe, capuche) : plis verticaux larges (bruit 1D), grain lent, PAS de sergé ni de motif périodique.
static func _laine(x: int, y: int, W: int, H: int, base: float, g: int, plis := 18) -> float:
	var pli := GuerrierTextures._n(x, 0, W, 1, plis, 1, g)
	return base + (pli - 0.5) * 0.62 + maxf(0.0, pli - 0.72) * 0.55 + (GuerrierTextures._n(x, y, W, H, 24, 8, g + 1) - 0.5) * 0.16 + (GuerrierTextures._h(x, y, g + 2) - 0.5) * 0.06

# ------------------------------------------------------------------ robe (haut : UV de la tunique, 256 x 128 ; u = 0 devant)
## Laine bleu ardoise ; bande brodée de runes au milieu du devant (torse) ; poignets (v = 1) : bande sombre unie, runes
## espacées irrégulièrement, arête claire. Crasse légère vers le bas.
static func robe_haut() -> Image:
	var W := 256
	var H := 128
	var img := GuerrierTextures._img(W, H)
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var l := _laine(x, y, W, H, 0.46, 1101)
			var t := GuerrierTextures._ton(l, 6, x, y, 1104, 0.3)
			_p(img, x, y, _c(ROBE, t))
	_bande_devant(img, W, 26, 88)
	_poignet(img, W, H)
	return img

## Bande brodée verticale centrée sur x = 0 (repliée) : fond sombre, deux filets d'argent, runes empilées.
static func _bande_devant(img: Image, W: int, y0: int, y1: int) -> void:
	for y in range(y0, y1):
		for dx in range(-6, 7):
			var x := posmod(dx, W)
			var c := _c(ROBE, 1)
			if absf(dx) == 6:
				c = _c(BRODERIE, 2)
			elif absf(dx) == 5:
				c = _c(ROBE, 0)
			_p(img, x, y, c)
	var k := 0
	var y := y0 + 2
	while y + 7 < y1:
		_rune(img, k * 5 + 3, -2, y, _c(BRODERIE, 3), _c(ROBE, 0))
		y += 9 + (k % 2)
		k += 1

## Poignet (bas de l'image) : 9 rangées sombres unies, runes espacées irrégulièrement, arête claire en haut, liseré au bord.
static func _poignet(img: Image, W: int, H: int) -> void:
	for x in W:
		for k in 10:
			var yy := H - 1 - k
			var c := _c(ROBE, 1)
			if k == 0:
				c = _c(ROBE, 0)
			elif k == 9:
				c = _c(BRODERIE, 1)
			elif k == 8:
				c = _c(ROBE, 5)
			_p(img, x, yy, c)
	var x := 2
	var i := 0
	while x < W - 4:
		_rune(img, i * 7 + 1, x, H - 8, _c(BRODERIE, 2), _c(ROBE, 0))
		x += 7 + int(GuerrierTextures._h(i, 0, 1111) * 4.0)
		i += 1

static func _p(img: Image, x: int, y: int, c: Color) -> void:
	GuerrierTextures._p(img, x, y, c)

# ------------------------------------------------------------------ capuche (UV empruntés à la tunique : 256 x 128)
## Laine gris-brun sombre, plis longs, bord (v proche de 1) sombre ; le haut de la tête prend la lumière.
static func capuche() -> Image:
	var W := 256
	var H := 128
	var img := GuerrierTextures._img(W, H)
	for y in H:
		for x in W:
			var l := _laine(x, y, W, H, 0.48, 1201, 14)
			_p(img, x, y, _c(CAPUCHE, GuerrierTextures._ton(l, 6, x, y, 1205, 0.3)))
	return img

# ------------------------------------------------------------------ barbe grise (64 x 64) : mèches peignées vers le bas
static func barbe() -> Image:
	var W := 64
	var H := 64
	var img := GuerrierTextures._img(W, H)
	for y in H:
		for x in W:
			var brin := posmod(x + int(GuerrierTextures._h(x / 3, 0, 1301) * 3.0), 3)
			var l := 0.52 + (GuerrierTextures._n(x, y, W, H, 14, 2, 1302) - 0.5) * 0.45 + (0.16 if brin == 1 else (-0.16 if brin == 0 else 0.0)) - y / float(H) * 0.12
			_p(img, x, y, _c(BARBE, GuerrierTextures._ton(l, 6, x, y, 1303, 0.4)))
	return img

# ------------------------------------------------------------------ fourrure pleine (manchettes) : touffes en écailles sur toute l'image
static func fourrure() -> Image:
	var W := 128
	var H := 64
	var img := GuerrierTextures._img(W, H, GuerrierTextures._c(GuerrierTextures.FOUR, 1))
	var y := H - 8
	var r := 0
	while y > -10:
		var x := int(GuerrierTextures._h(r, 0, 1401) * 6.0)
		var i := 0
		while x < W + 6:
			var w := 5 + int(GuerrierTextures._h(i, r, 1402) * 3.0)
			var h := 9 + int(GuerrierTextures._h(i, r, 1403) * 4.0)
			GuerrierTextures._touffe(img, x, y + int(GuerrierTextures._h(i, r, 1404) * 3.0) - 1, w, h, (GuerrierTextures._h(i, r, 1405) - 0.5) * 0.35, 3 + (1 if GuerrierTextures._h(i, r, 1406) > 0.5 else 0))
			x += w - 1
			i += 1
		y -= 6
		r += 1
	return img

# ------------------------------------------------------------------ cristal (32 x 32) : facettes, cœur clair, arêtes nettes
static func cristal() -> Image:
	var W := 32
	var H := 32
	var img := GuerrierTextures._img(W, H)
	for y in H:
		for x in W:
			# 4 facettes par bande de 8 texels en u : arête claire à gauche, face qui s'assombrit, éclat près du sommet
			var f := x % 8
			var l := 0.62 - f * 0.05 + (1.0 - absf(y - 16) / 16.0) * 0.25 + (GuerrierTextures._n(x, y, W, H, 4, 4, 1501) - 0.5) * 0.15
			var t := GuerrierTextures._ton(l, 6, x, y, 1502, 0.25)
			if f == 0:
				t = mini(t + 2, 5)
			elif f == 7:
				t = maxi(t - 1, 1)
			_p(img, x, y, _c(CRISTAL, t))
	return img

# ------------------------------------------------------------------ atlas des accessoires (256 x 512)
## Mêmes régions que l'atlas du guerrier pour les pièces partagées (fer, anneau ouvragé, bosse, poignée, œil, ceinture), puis :
##   (0,0,16,128)    hampe du bâton : bois brun-gris, veine longue, runes entaillées claires (v le long de la hampe)
##   (16,0,16,32)    tête sculptée (nœud, griffes) : bois plus sombre, arêtes claires
##   (32,0,16,16)    cordon (amulette) ; (48,0,16,16) pierre runique (amulette de ceinture) ; (64,0,16,16) dent d'os
##   (32,16,32,32)   disque runique de l'amulette (gravure claire sur pierre bleu-gris)
##   (0,256,256,128) jupe de la robe : x = angle (0 = devant, repliée), y = de la taille (0) à l'ourlet (127)
##   (192,128,64,32) doublure de la robe (laine sombre, face intérieure)
##   (0,384,256,128) pantalon du guerrier (UV du pantalon tels quels)
const R_HAMPE := Rect2i(0, 0, 16, 128)
const R_TETE := Rect2i(16, 0, 16, 32)
const R_CORDON := Rect2i(32, 0, 16, 16)
const R_PIERRE := Rect2i(48, 0, 16, 16)
const R_DENT := Rect2i(64, 0, 16, 16)
const R_DISQUE := Rect2i(32, 16, 32, 32)
const R_JUPE := Rect2i(0, 256, 256, 128)
const R_DOUBLURE := Rect2i(192, 128, 64, 32)
const R_PANTALON := Rect2i(0, 384, 256, 128)
const ATLAS := Vector2i(256, 512)
## ombre du visage sous la capuche (quasi noire, très léger grain)
const R_MASQUE := Rect2i(80, 0, 16, 16)

static func accessoires() -> Image:
	var img := GuerrierTextures._img(ATLAS.x, ATLAS.y, _c(ROBE, 1))
	GuerrierTextures._fer(img, GuerrierTextures.R_FER)
	GuerrierTextures._poignee(img)
	GuerrierTextures._anneau(img)
	GuerrierTextures._bosse(img)
	_oeil(img)
	_hampe(img)
	_tete_baton(img)
	_amulettes(img)
	_jupe(img)
	_doublure(img)
	_ceinture(img)
	for y in R_MASQUE.size.y:
		for x in R_MASQUE.size.x:
			img.set_pixel(R_MASQUE.position.x + x, R_MASQUE.position.y + y, Color("#060608") if GuerrierTextures._h(x, y, 2401) > 0.3 else Color("#0b0b0e"))
	var pa := GuerrierTextures.pantalon()
	img.blit_rect(pa, Rect2i(Vector2i.ZERO, pa.get_size()), R_PANTALON.position)
	return img

## Œil (16 x 8) : blanc GRIS (pas blanc pur : à l'ombre de la capuche il ne doit pas briller), iris bleu glacier, pupille,
## paupière sombre épaisse en haut, coins sombres.
static func _oeil(img: Image) -> void:
	var r := GuerrierTextures.R_OEIL
	for y in r.size.y:
		for x in r.size.x:
			var c := Color("#8a8c90")
			var dx := x - 7.5
			if absf(dx) <= 2.6 and y >= 2 and y <= 6:
				c = Color("#6f9ad0") if absf(dx) > 1.0 or y < 3 else Color("#1a2232")
			if y <= 1 or y >= 7 or x <= 1 or x >= 14:
				c = Color("#2a201c")
			if y == 2 and (x < 4 or x > 11):
				c = Color("#3c302a")
			img.set_pixel(r.position.x + x, r.position.y + y, c)

## Hampe : bois brun-gris (palette du bouclier), veine longue, nœuds, runes entaillées tous les ~11 texels sur la moitié haute,
## bague de cuir sombre (prise) peinte au tiers.
static func _hampe(img: Image) -> void:
	var r := R_HAMPE
	for y in r.size.y:
		for x in r.size.x:
			var l := 0.45 + (GuerrierTextures._n(x, y, 16, 128, 3, 24, 1601) - 0.5) * 0.45 + (0.12 if x % 4 == 1 else 0.0) - (0.15 if x % 8 == 6 else 0.0)
			var t := GuerrierTextures._ton(l, 7, x, y, 1602, 0.25)
			img.set_pixel(r.position.x + x, r.position.y + y, GuerrierTextures._c(GuerrierTextures.BOIS_GRIS, t))
	# runes entaillées (moitié haute : y 4 à 60), deux colonnes décalées (faces opposées)
	var k := 0
	var y := 4
	while y < 62:
		var cx := 2 if k % 2 == 0 else 10
		_rune(img, k + 2, r.position.x + cx, r.position.y + y, _c(RUNE_BOIS, 1 + (k % 2)), GuerrierTextures._c(GuerrierTextures.BOIS_GRIS, 0))
		y += 9
		k += 1

## Tête sculptée : bois sombre, arêtes claires, filets gravés.
static func _tete_baton(img: Image) -> void:
	var r := R_TETE
	for y in r.size.y:
		for x in r.size.x:
			var l := 0.35 + (GuerrierTextures._n(x, y, 16, 32, 4, 6, 1611) - 0.5) * 0.35
			var t := GuerrierTextures._ton(l, 7, x, y, 1612, 0.25)
			if x == 0 or x == 8:
				t = 5
			elif x == 7 or x == 15:
				t = 1
			if y % 8 == 0:
				t = 1
			elif y % 8 == 1:
				t = 5
			img.set_pixel(r.position.x + x, r.position.y + y, GuerrierTextures._c(GuerrierTextures.BOIS_GRIS, t))

static func _amulettes(img: Image) -> void:
	# cordon de cuir tressé
	var r := R_CORDON
	for y in r.size.y:
		for x in r.size.x:
			var t := 2 + (1 if posmod(x + y, 4) < 2 else 0) - (1 if x % 8 == 7 else 0)
			img.set_pixel(r.position.x + x, r.position.y + y, GuerrierTextures._c(GuerrierTextures.CUIR, t))
	# pierre runique : pierre bleu-gris, rune claire au centre, arêtes
	r = R_PIERRE
	for y in r.size.y:
		for x in r.size.x:
			var t := 2 + int(GuerrierTextures._n(x, y, 16, 16, 3, 3, 1621) * 2.0)
			if x == 0 or y == 0:
				t = 4
			if x == 15 or y == 15:
				t = 0
			img.set_pixel(r.position.x + x, r.position.y + y, GuerrierTextures._c(GuerrierTextures.MAILLE, t))
	_rune(img, 7, r.position.x + 6, r.position.y + 5, _c(RUNE_BOIS, 2), GuerrierTextures._c(GuerrierTextures.MAILLE, 0))
	# dent d'os : ivoire sale, base sombre
	r = R_DENT
	for y in r.size.y:
		for x in r.size.x:
			var l := 0.75 - y / 16.0 * 0.3 + (GuerrierTextures._h(x, y, 1631) - 0.5) * 0.1
			var c := GuerrierTextures._c(GuerrierTextures.PEINT_CREME, GuerrierTextures._ton(l, 4, x, y, 1632, 0.2))
			if x == 0:
				c = GuerrierTextures._c(GuerrierTextures.PEINT_CREME, 3)
			img.set_pixel(r.position.x + x, r.position.y + y, c)
	# disque runique : pierre bleu-gris, anneau gravé, rune au centre
	r = R_DISQUE
	for y in r.size.y:
		for x in r.size.x:
			var d := Vector2(x - 15.5, y - 15.5).length()
			var t := 2 + int(GuerrierTextures._n(x, y, 32, 32, 4, 4, 1641) * 2.0)
			if d > 13.0:
				t = 1
			elif d > 11.0 and d < 12.2:
				t = 5
			if x + y < 22 and d < 13.0:
				t = mini(t + 1, 5)
			img.set_pixel(r.position.x + x, r.position.y + y, GuerrierTextures._c(GuerrierTextures.MAILLE, t))
	_rune(img, 9, r.position.x + 12, r.position.y + 10, _c(RUNE_BOIS, 2), GuerrierTextures._c(GuerrierTextures.MAILLE, 0), 2.0)

## Jupe : même laine que le haut, plis plus marqués vers le bas (le tissu tombe), bande brodée verticale au milieu du devant,
## bande de runes au-dessus de l'ourlet, ourlet UNI sombre (5 rangées) avec arête claire : aucune alternance fine de texels.
static func _jupe(img: Image) -> void:
	var r := R_JUPE
	var W := r.size.x
	var H := r.size.y
	for y in H:
		for x in W:
			var bas := float(y) / H
			var l := 0.46 + (GuerrierTextures._n(x, 0, W, 1, 20, 1, 1701) - 0.5) * (0.35 + bas * 0.35) + (GuerrierTextures._n(x, y, W, H, 24, 8, 1702) - 0.5) * 0.14
			l += (GuerrierTextures._h(x, y, 1703) - 0.5) * 0.06 - bas * 0.06
			var t := GuerrierTextures._ton(l, 6, x, y, 1704, 0.3)
			# crasse et neige fondue vers l'ourlet (taches allongées, pas de grain)
			if y > H - 24 and GuerrierTextures._n(x, y, W, H, 32, 6, 1705) < 0.3 + (y - (H - 24)) / 60.0:
				t -= 1
			img.set_pixel(r.position.x + x, r.position.y + y, _c(ROBE, t))
	# bande brodée du devant (repliée autour de x = 0) jusqu'à la bande de l'ourlet
	var sous := Image.create(W, H, false, Image.FORMAT_RGBA8)
	sous.blit_rect(img, r, Vector2i.ZERO)
	_bande_devant(sous, W, 0, H - 16)
	# bande de runes au-dessus de l'ourlet (y H-15 .. H-7), ourlet uni (H-6 .. H-1)
	for x in W:
		for k in 15:
			var yy := H - 1 - k
			var c := _c(ROBE, 1)
			if k <= 1:
				c = _c(ROBE, 0)
			elif k == 5:
				c = _c(ROBE, 5)             # arête claire de l'ourlet replié
			elif k == 6:
				c = _c(ROBE, 0)
			elif k == 14:
				c = _c(BRODERIE, 2)         # filet d'argent haut
			elif k == 4:
				c = _c(BRODERIE, 1)         # liseré froid sous la bande de runes
			elif k == 13:
				c = _c(ROBE, 0)
			sous.set_pixel(x, yy, c)
	var x := 3
	var i := 0
	while x < W - 5:
		_rune(sous, i * 5 + 2, x, H - 13, _c(BRODERIE, 3 if i % 3 != 1 else 2), _c(ROBE, 0))
		x += 8 + int(GuerrierTextures._h(i, 0, 1711) * 5.0)
		i += 1
	img.blit_rect(sous, Rect2i(Vector2i.ZERO, sous.get_size()), r.position)

static func _doublure(img: Image) -> void:
	var r := R_DOUBLURE
	for y in r.size.y:
		for x in r.size.x:
			img.set_pixel(r.position.x + x, r.position.y + y, _c(ROBE, 1 if GuerrierTextures._n(x, y, 64, 32, 6, 3, 1801) > 0.5 else 0))

## Ceinture de cuir sombre (même place et mêmes UV que la large ceinture du guerrier) : bords sombres, piqûre, arêtes usées.
static func _ceinture(img: Image) -> void:
	var r := GuerrierTextures.R_CEINT
	for y in r.size.y:
		for x in r.size.x:
			var t := GuerrierTextures._ton_cuir(x, y, r.size.x, r.size.y, 0.58, 1901)
			if y <= 1 or y >= r.size.y - 2:
				t = 1
			elif y == 2 or y == r.size.y - 3:
				t = 4
			elif (y == 4 or y == r.size.y - 5) and x % 4 < 2:
				t = 6
			img.set_pixel(r.position.x + x, r.position.y + y, GuerrierTextures._c(GuerrierTextures.CUIR, t))

# ------------------------------------------------------------------ atlas des découpes (même mise en page que le guerrier, 192 x 128)
## Mèches de fourrure du guerrier (même famille) ; région de la cape : fourrure pleine des manchettes (0,32,112,64).
static func decoupes() -> Image:
	var img := GuerrierTextures._img(GuerrierTextures.DECOUPES.x, GuerrierTextures.DECOUPES.y, Color(0, 0, 0, 0))
	var m := GuerrierTextures.meches()
	# col de fourrure : teinte crème / gris chaud cuite ici (le tissu effiloché partage la surface, il ne doit pas être teinté)
	for y in m.get_height():
		for x in m.get_width():
			var c := m.get_pixel(x, y)
			if c.a > 0.0:
				m.set_pixel(x, y, Color(c.r * MageNordique.TEINTE_COL.r, c.g * MageNordique.TEINTE_COL.g, c.b * MageNordique.TEINTE_COL.b, c.a))
	img.blit_rect(m, Rect2i(Vector2i.ZERO, m.get_size()), GuerrierTextures.D_MECHES.position)
	_effiloche(img, D_EFFILOCHE)
	return img

## Région du tissu effiloché dans l'atlas des découpes (manches larges, franges de la pèlerine) : u autour / le long du bord,
## v du haut (0) au bord libre (1).
const D_EFFILOCHE := Rect2i(0, 32, 112, 64)

## Laine noire de la robe, plis verticaux ; bande brodée de runes bleu pâle (filets en haut et en bas) au-dessus du bord ;
## bord libre EFFILOCHÉ : lanières de 2 à 5 texels de longueurs inégales (alpha 0 dessous, découpe nette), fils pendants.
static func _effiloche(img: Image, r: Rect2i) -> void:
	var W := r.size.x
	var H := r.size.y
	# longueur de chaque lanière (rangée où le tissu s'arrête)
	var coupe := PackedInt32Array()
	coupe.resize(W)
	var x := 0
	var k := 0
	while x < W:
		var larg := 2 + int(GuerrierTextures._h(k, 0, 2101) * 4.0)
		var fin := 50 + int(GuerrierTextures._h(k, 1, 2102) * 13.0)
		for i in larg:
			if x + i < W:
				# pointe effilée : les bords de la lanière s'arrêtent un peu plus haut
				coupe[x + i] = fin - (2 if (i == 0 or i == larg - 1) and larg > 2 else 0)
		x += larg
		k += 1
	for y in H:
		for x2 in W:
			var c := Color(0, 0, 0, 0)
			if y < coupe[x2]:
				var l := _laine(x2, y, W, H, 0.42, 2111, 14) - float(y) / H * 0.08
				var t := GuerrierTextures._ton(l, 6, x2, y, 2112, 0.3)
				c = _c(ROBE, t)
				if y == coupe[x2] - 1:
					c = _c(ROBE, 0)                          # fil sombre au bout de la lanière
				elif y >= 38 and y <= 48:
					c = _c(ROBE, 1)
					if y == 38 or y == 48:
						c = _c(BRODERIE, 2)
			elif y < coupe[x2] + 4 and GuerrierTextures._h(x2, 7, 2113) < 0.18:
				c = _c(ROBE, 1)                              # fil pendant isolé
			img.set_pixel(r.position.x + x2, r.position.y + y, c)
	var xr := 2
	var i2 := 0
	while xr < W - 5:
		_rune(img, i2 * 3 + 1, r.position.x + xr, r.position.y + 40, _c(BRODERIE, 4 if i2 % 3 != 2 else 3), _c(ROBE, 0))
		xr += 8 + int(GuerrierTextures._h(i2, 0, 2121) * 4.0)
		i2 += 1

# ------------------------------------------------------------------ pèlerine (UV de la mante du jeu, 128 x 128, répétée)
static func pelerine() -> Image:
	var W := 128
	var H := 128
	var img := GuerrierTextures._img(W, H)
	for y in H:
		for x in W:
			var l := _laine(x, y, W, H, 0.45, 2201, 10)
			_p(img, x, y, _c(PELERINE, GuerrierTextures._ton(l, 6, x, y, 2205, 0.3)))
	return img

# ------------------------------------------------------------------ orbe et lueurs (64 x 64, surface émissive, découpe)
##   (0,0,64,32)  surface de l'orbe : u autour, v d'un pôle à l'autre ; cœur blanc glacé, bord bleu, rune deux fois (devant / dos)
##   (0,32,16,16) étincelle (losange à croix) ; (16,32,16,8) œil luisant (fente) ; (32,32,32,32) 4 runes flottantes 16 x 16
const O_SPHERE := Rect2i(0, 0, 64, 32)
const O_ETINCELLE := Rect2i(0, 32, 16, 16)
const O_OEIL := Rect2i(16, 32, 16, 8)
const O_RUNES := Rect2i(32, 32, 32, 32)

static func orbe() -> Image:
	var img := GuerrierTextures._img(64, 64, Color(0, 0, 0, 0))
	for y in 32:
		for x in 64:
			var lat := absf(y - 15.5) / 16.0
			var l := 0.64 - lat * lat * 0.62 + (GuerrierTextures._n(x, y, 64, 32, 8, 4, 2301) - 0.5) * 0.25
			# volutes de givre qui tournent dans l'orbe
			if posmod(x + int(y * 0.6), 11) == 0:
				l -= 0.2
			img.set_pixel(x, y, _c(ORBE, GuerrierTextures._ton(l, 6, x, y, 2302, 0.25)))
	for cx in [10, 42]:
		_rune(img, 7, cx, 9, _c(ORBE, 5), _c(ORBE, 2), 2.0)
		# cercle gravé autour de la rune
		for a in 24:
			var p := Vector2(cx + 3, 15) + Vector2(cos(TAU * a / 24.0) * 8.0, sin(TAU * a / 24.0) * 7.0)
			img.set_pixel(clampi(int(p.x), 0, 63), clampi(int(p.y), 0, 31), _c(ORBE, 5))
	# étincelle
	var r := O_ETINCELLE
	for y in 16:
		for x in 16:
			var d := absf(x - 7.5) + absf(y - 7.5)
			var croix := (absf(x - 7.5) < 1.0 or absf(y - 7.5) < 1.0) and d < 8.0
			if d < 3.5:
				img.set_pixel(r.position.x + x, r.position.y + y, _c(ORBE, 5))
			elif d < 5.0 or croix:
				img.set_pixel(r.position.x + x, r.position.y + y, _c(ORBE, 4 if d < 6.0 else 3))
	# œil : fente horizontale, cœur blanc glacé
	r = O_OEIL
	for y in 8:
		for x in 16:
			var e := pow(absf(x - 7.5) / 8.0, 2.0) + pow(absf(y - 3.5) / 3.6, 2.0)
			if e < 0.35:
				img.set_pixel(r.position.x + x, r.position.y + y, _c(ORBE, 5))
			elif e < 1.0:
				img.set_pixel(r.position.x + x, r.position.y + y, _c(ORBE, 3))
	# runes flottantes : tracé épais (échelle 2, doublé), cœur clair
	r = O_RUNES
	for k in 4:
		var ox := r.position.x + (k % 2) * 16 + 4
		var oy := r.position.y + (k / 2) * 16 + 2
		_rune(img, [0, 4, 7, 10][k], ox + 1, oy, _c(ORBE, 3), _c(ORBE, 3), 2.0)
		_rune(img, [0, 4, 7, 10][k], ox, oy, _c(ORBE, 5), _c(ORBE, 4), 2.0)
	return img
