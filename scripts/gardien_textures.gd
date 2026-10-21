class_name GardienTextures
## Textures du Gardien nordique (GardienNordique) : même méthode que GuerrierTextures (128 texels/m, palettes froides de 4 à 7
## tons, contours et rehauts peints, bruit seulement, jamais de Bayer, mipmaps « pixel art »). Les fonctions du guerrier sont
## APPELÉES (atlas de base, cape, mèches, mipmaps) ; seules les pièces propres au gardien sont peintes ici :
##   - cotte de mailles brun-gris FERREUX (le guerrier la portait trop bleue au crépuscule) ;
##   - bouclier peint en bleu du jarl, étoile à 8 branches crème (référence 14_01_58-4), planches visibles sous la peinture ;
##   - casque à plaques (spangenhelm) en fer brun, bandeau frontal et nasal clairs rivés ;
##   - hampe de lance en frêne, bagues de fer, fer de lance en feuille ;
##   - épaulières en lames de fer rivées sur cuir ;
##   - écharpe de laine bleue ; tabard bleu du jarl à bordure crème, motif SOBRE (une seule rune), franges ;
##   - yeux moins blancs (le guerrier avait les yeux « presque blancs »).

const MAILLE_FER := ["#151310", "#26231e", "#3a362f", "#524c43", "#736b5f", "#9b9284"]   # brun-gris ferreux (pas bleu)
const FER_BRUN := ["#0f0e0d", "#1d1b19", "#302d29", "#47433d", "#666058", "#8d867b", "#b7b0a3"]
const BLEU_JARL := ["#121620", "#1b2331", "#283244", "#36435a", "#475670", "#5d6c86"]   # bleu ardoise délavé (passe 2 : moins « plastique »)
## Fourrure crème chaude (passe 2) : remplace ton pour ton la palette gris-brun du guerrier, qui bleuissait au crépuscule.
const FOUR_CHAUD := ["#251f18", "#463b2d", "#6b5c47", "#8f7e63", "#b3a083", "#d3c2a2"]
const CREME := ["#4e4636", "#73694f", "#9a8f70", "#bdb291", "#d8cfae"]
## Col de fourrure (passe 3) : crème chaude plus claire que FOUR_CHAUD, pour rester crème sous la lumière froide du crépuscule.
const COL_FOUR := ["#3a2f22", "#6b5a42", "#9a8765", "#c2b18c", "#e2d4b0", "#f2e8c8"]
const FRENE := ["#1c140e", "#33251a", "#4b3726", "#654b34", "#7f6146", "#9a7a5a"]

# ------------------------------------------------------------------ précalcul (même contrat que GuerrierTextures)
const DOSSIER := "res://assets/persos/gardien"
const VERSION := 5
static var enregistrer := false
static var _cache := {}

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
				"accessoires": img = accessoires()
				"decoupes": img = decoupes()
				"mante": img = mante_creme()
				"bottes": img = _rechauffer(GuerrierTextures.bottes())
				_: push_error("GardienTextures : texture inconnue " + nom)
			mips = GuerrierTextures.mips_pixel(img)
			sauver(nom, mips)
		_cache[nom] = ImageTexture.create_from_image(mips)
	return _cache[nom]

static func vider() -> void:
	_cache.clear()

static func _c(pal: Array, i: int) -> Color:
	return Color(pal[clampi(i, 0, pal.size() - 1)])

static func _h(x: int, y: int, g: int) -> float:
	return ObjetsTextures._h(x, y, g)

static func _n(x: int, y: int, w: int, h: int, cx: int, cy: int, g: int) -> float:
	return ObjetsTextures._vn(float(x) / w * cx, float(y) / h * cy, cx, cy, g)

## Tons de fourrure du guerrier (GuerrierTextures.FOUR) remplacés par la fourrure crème chaude, dans `r` (toute l'image par défaut).
static func _rechauffer(img: Image, r := Rect2i()) -> Image:
	if r.size == Vector2i.ZERO:
		r = Rect2i(Vector2i.ZERO, img.get_size())
	var carte := {}
	for i in GuerrierTextures.FOUR.size():
		carte[Color(GuerrierTextures.FOUR[i])] = _c(FOUR_CHAUD, i)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			var k := Color(c.r, c.g, c.b, 1.0)
			if carte.has(k):
				var n: Color = carte[k]
				img.set_pixel(x, y, Color(n.r, n.g, n.b, c.a))
	return img

static func _rivet(img: Image, x: int, y: int) -> void:
	img.set_pixel(x, y, _c(GuerrierTextures.METAL_CLAIR, 6))
	img.set_pixel(x + 1, y, _c(GuerrierTextures.METAL_CLAIR, 3))
	img.set_pixel(x, y + 1, _c(GuerrierTextures.METAL_CLAIR, 2))
	img.set_pixel(x + 1, y + 1, _c(FER_BRUN, 0))

# ------------------------------------------------------------------ cotte de mailles ferreuse
## Le dessin des anneaux du guerrier, ses tons remplacés un à un par la palette brun-gris (rouille et ourlet de cuir gardés).
static func mailles() -> Image:
	var img := GuerrierTextures.mailles()
	var carte := {}
	for i in GuerrierTextures.MAILLE.size():
		carte[Color(GuerrierTextures.MAILLE[i])] = _c(MAILLE_FER, i)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if carte.has(c):
				img.set_pixel(x, y, carte[c])
			elif c.b > c.r + 0.02:
				# tons mêlés de rouille : on retire la dominante bleue
				var l := c.get_luminance()
				img.set_pixel(x, y, Color(l * 1.05, l, l * 0.9))
	return img

# ------------------------------------------------------------------ atlas des accessoires (256 x 256)
## Base : l'atlas du guerrier (cerclage, umbo, poignée, anneau ouvragé, plastron, ceinture…). Régions repeintes ou ajoutées :
##   (0,0,128,128)    face du bouclier : bleu du jarl, étoile crème à 8 branches, planches et clous
##   (224,32,16,8)    œil : blanc cassé terne, iris brun-gris
##   (136,128,64,48)  casque : u = tour (0 = droite, 0,25 = devant), v = du sommet (0) au bord (47)
##   (200,128,56,16)  bandeau frontal / nasal : fer clair rivé
##   (200,144,16,64)  hampe de frêne (u = tour, v = le long ; bagues de fer en haut et en bas de la région)
##   (216,144,16,48)  fer de lance : arête claire au milieu, fils clairs, douille sombre (v = 0 douille -> 47 pointe)
##   (232,144,24,32)  écharpe de laine bleue (tissage, plis)
##   (136,176,96,32)  épaulières : x = (u + 0,19) * 252, y = (v - 0,17) * 136 ; 3 lames de fer rivées, bord de cuir
const R_CASQUE := Rect2i(136, 128, 64, 48)
const R_BANDEAU := Rect2i(200, 128, 56, 16)
const R_HAMPE := Rect2i(200, 144, 16, 64)
const R_FER_LANCE := Rect2i(216, 144, 16, 48)
const R_LAINE := Rect2i(232, 144, 24, 32)
const R_EPAUL := Rect2i(136, 176, 96, 32)
## Surcot de cuir (passe 3) : tuile de 20 x 48 texels = 2 segments (0,156 m) x 0,42 m, jointure de panneau à gauche.
const R_SURCOT := Rect2i(0, 208, 20, 48)

static func accessoires() -> Image:
	var img := GuerrierTextures.accessoires()
	_face_bouclier(img)
	_oeil(img)
	_casque(img)
	_bandeau(img)
	_hampe(img)
	_fer_lance(img)
	_laine(img)
	_epaulieres(img)
	_surcot(img)
	return img

## Surcot de cuir brun usé : panneaux cousus (jointure sombre + points clairs de part et d'autre), clous de fer sur la jointure,
## plis de cuir frotté, ourlet replié cousu en bas. Jamais de damier : grain et plaques de frottement.
static func _surcot(img: Image) -> void:
	var r := R_SURCOT
	var W := r.size.x
	var H := r.size.y
	for y in H:
		for x in W:
			var t := GuerrierTextures._ton_cuir(x, y, W, H, 0.46 - 0.10 * float(y) / H, 3401)
			# jointure verticale (x 0) : fente sombre, point de couture clair à 2 texels de chaque côté, un point sur deux
			var c := _c(GuerrierTextures.CUIR, t)
			if x == 0:
				c = _c(GuerrierTextures.CUIR, 0)
			elif x == 1:
				c = _c(GuerrierTextures.CUIR, 3)
			elif (x == 2 or x == W - 2) and (y % 4) < 2:
				c = _c(GuerrierTextures.CUIR, 6)
			elif x == W - 1:
				c = _c(GuerrierTextures.CUIR, 1)
			# ourlet replié (y 41-47) : bord clair, couture, ombre
			if y == 40:
				c = _c(GuerrierTextures.CUIR, 0)
			elif y == 41:
				c = _c(GuerrierTextures.CUIR, 5)
			elif y == 43 and (x % 3) != 0:
				c = _c(GuerrierTextures.CUIR, 6)
			elif y >= 44:
				c = _c(GuerrierTextures.CUIR, clampi(t - 1, 1, 4))
				if y == H - 1:
					c = _c(GuerrierTextures.CUIR, 0)
			# bande de cuir plus sombre près de la taille (sous la ceinture)
			if y < 3:
				c = c.darkened(0.35)
			img.set_pixel(r.position.x + x, r.position.y + y, c)
	# clous de fer sur la jointure, tous les 12 texels
	for y in [10, 22, 34]:
		_rivet(img, r.position.x + 0, r.position.y + y)
	# deux plis de cuir (traits sombres + rehaut) par tuile
	for y in range(8, 38):
		var x := 7 + int(2.0 * sin(y * 0.45))
		img.set_pixel(r.position.x + x, r.position.y + y, _c(GuerrierTextures.CUIR, 1))
		img.set_pixel(r.position.x + x + 1, r.position.y + y, _c(GuerrierTextures.CUIR, 5))

## Bouclier : planches verticales (mêmes joints que le guerrier), peinture bleue couvrante usée sur les arêtes, étoile crème à
## 8 branches fines (croix + sautoir) partant de l'umbo, anneau crème au bord ; clous du cerclage.
static func _face_bouclier(img: Image) -> void:
	var r := GuerrierTextures.R_FACE
	var n := r.size.x
	var c0 := (n - 1) * 0.5
	var P: Array = GuerrierTextures.PLANCHES
	for y in n:
		for x in n:
			var dx := (x - c0) / c0
			var dy := (y - c0) / c0
			var rr := sqrt(dx * dx + dy * dy)
			var k := 0
			while k < P.size() - 2 and x >= P[k + 1]:
				k += 1
			var dj: int = x - int(P[k])
			var veine := _n(x, y, n, n, 10, 3, 2911 + k)
			var l := 0.50 + _h(k, 0, 2912) * 0.16 + (veine - 0.5) * 0.30 + (_h(x, k, 2918) - 0.5) * 0.14
			var t := clampi(int(floorf(l * 5.0 + (_h(x, y, 2913) - 0.5) * 0.3)), 0, 5)
			# éclairage de la face bombée : haut-gauche plus clair
			t = clampi(t + int(roundf((-dx - dy) * 0.6)), 0, 5)
			var c := _c(BLEU_JARL, t)
			# étoile : 8 branches de 3 texels (0 / 45 / 90 / 135°) entre l'umbo et l'anneau
			var ang := atan2(dy, dx)
			var branche := false
			for b in 8:
				var a := b * PI / 4.0
				var d := absf(sin(ang - a)) * rr * c0
				if d < 1.6 and cos(ang - a) > 0.0 and rr > 0.22 and rr < 0.80:
					branche = true
			# anneau crème au bord de la peinture
			if rr > 0.78 and rr < 0.82:
				branche = true
			if branche:
				c = _c(CREME, clampi(t - 1, 0, 4))
			# usure : bois brun-gris aux joints, quelques éclats (grandes plaques, pas de taches)
			var bois := _c(GuerrierTextures.BOIS_GRIS, clampi(t, 1, 5))
			if (dj <= 1 and k > 0 and _h(x, y, 2916) > 0.45) or _n(x, y, n, n, 5, 5, 2917) > 0.86:
				c = bois
			if k > 0 and dj == 0:
				c = _c(GuerrierTextures.BOIS_GRIS, 0)
			if rr > 0.84:
				c = c.darkened(0.2)
			if rr > 0.86 and rr < 0.92:
				if posmod(int(roundf(ang / TAU * 20.0 * 4.0)), 4) == 0:
					c = _c(FER_BRUN, 5) if dy < 0.0 else _c(FER_BRUN, 3)
			img.set_pixel(r.position.x + x, r.position.y + y, c)

static func _oeil(img: Image) -> void:
	var r := GuerrierTextures.R_OEIL
	for y in r.size.y:
		for x in r.size.x:
			var dx := (x - 7.5) / 7.5
			var dy := (y - 3.5) / 3.5
			var c := Color("#a49b8c")
			if dx * dx + dy * dy > 1.0:
				c = Color("#3a2a24")
			var di := Vector2(x - 7.5, (y - 4.0) * 1.2).length()
			if di < 2.8:
				c = Color("#5d5a52") if di > 1.0 else Color("#141418")
			if y <= 1:
				c = Color("#2a1e1a")
			img.set_pixel(r.position.x + x, r.position.y + y, c)

## Casque : 4 plaques de fer brun (u), séparées par 4 bandes claires rivées (devant, dos, côtés), lumière en haut à gauche.
static func _casque(img: Image) -> void:
	var r := R_CASQUE
	for y in r.size.y:
		for x in r.size.x:
			var u := (x + 0.5) / r.size.x
			var ang := u * TAU
			var lum := cos(ang - deg_to_rad(110.0)) * (1.0 - float(y) / r.size.y * 0.4)
			var t := 3 + int(roundf(lum * 1.4 + (_n(x, y, r.size.x, r.size.y, 8, 4, 3101) - 0.5) * 0.8))
			if y < 3:
				t = 5
			var bande := absf(wrapf(u * 4.0, -0.5, 0.5))
			var c := _c(FER_BRUN, clampi(t, 1, 5))
			if bande < 0.07:
				c = _c(GuerrierTextures.METAL_CLAIR, clampi(t + 1, 2, 6))
				if y % 8 == 4:
					c = _c(GuerrierTextures.METAL_CLAIR, 6)
			elif bande < 0.10:
				c = _c(FER_BRUN, 0)
			elif _n(x, y, r.size.x, r.size.y, 6, 4, 3102) > 0.80 and t < 5:
				c = _c(GuerrierTextures.ROUILLE, 1)
			img.set_pixel(r.position.x + x, r.position.y + y, c)

static func _bandeau(img: Image) -> void:
	var r := R_BANDEAU
	for y in r.size.y:
		for x in r.size.x:
			var t := 3
			if y == 0 or y == r.size.y - 1:
				t = 0
			elif y == 1:
				t = 5
			elif y >= r.size.y - 3:
				t = 2
			elif _h(x, y, 3111) > 0.88:
				t = 2
			img.set_pixel(r.position.x + x, r.position.y + y, _c(FER_BRUN, t + 1))
	for x in range(3, r.size.x - 2, 7):
		_rivet(img, r.position.x + x, r.position.y + 6)

static func _hampe(img: Image) -> void:
	var r := R_HAMPE
	for y in r.size.y:
		for x in r.size.x:
			var ang := TAU * (x + 0.5) / r.size.x
			var lum := cos(ang - deg_to_rad(120.0))
			var fil := _n(x, y, r.size.x, r.size.y, 3, 16, 3121)
			var t := clampi(2 + int(roundf(lum * 1.3 + (fil - 0.5) * 1.0)), 0, 5)
			var c := _c(FRENE, t)
			# bagues de fer (haut et bas de la région : sous le fer et au talon) et poignée de cuir au milieu
			if y < 3 or y > r.size.y - 3:
				c = _c(FER_BRUN, clampi(3 + int(roundf(lum * 1.5)), 1, 6))
			elif y >= 25 and y <= 36:
				c = _c(GuerrierTextures.CUIR, 1 + (2 if posmod(x + y, 3) == 0 else 1))
			img.set_pixel(r.position.x + x, r.position.y + y, c)

static func _fer_lance(img: Image) -> void:
	var r := R_FER_LANCE
	for y in r.size.y:
		for x in r.size.x:
			var t := 4
			if x <= 1 or x >= 14:
				t = 6
			elif x == 7 or x == 8:
				t = 5                               # arête médiane
			elif x == 6:
				t = 2
			elif x < 7:
				t = 4
			else:
				t = 3
			if y < 10:
				t = 2 + (1 if x % 5 == 0 else 0)    # douille
			if _h(x, y, 3131) > 0.93:
				t -= 1
			img.set_pixel(r.position.x + x, r.position.y + y, _c(FER_BRUN, t))

static func _laine(img: Image) -> void:
	var r := R_LAINE
	for y in r.size.y:
		for x in r.size.x:
			var sg := 0.06 if ((x + y) & 3) < 2 else -0.05
			var pli := _n(x, y, r.size.x, r.size.y, 4, 2, 3141)
			var t := clampi(int(floorf((0.45 + sg + (pli - 0.5) * 0.5) * 6.0 + (_h(x, y, 3142) - 0.5) * 0.3)), 0, 5)
			img.set_pixel(r.position.x + x, r.position.y + y, _c(BLEU_JARL, t))

## Épaulières : 3 lames de fer brun qui se chevauchent (rehaut en haut de chaque lame, ombre portée dessous), rivets, bord de cuir.
static func _epaulieres(img: Image) -> void:
	var r := R_EPAUL
	for y in r.size.y:
		for x in r.size.x:
			var lame := y / 10
			var yl := y % 10
			var t := 4 - yl / 3
			if yl == 0:
				t = 6
			elif yl == 9:
				t = 0
			t += int(roundf((_n(x, y, r.size.x, r.size.y, 8, 3, 3151) - 0.5) * 1.2))
			var c := _c(FER_BRUN, clampi(t, 0, 6))
			if lame >= 3:
				c = _c(GuerrierTextures.CUIR, 2 + (1 if x % 4 < 2 else 0))
			img.set_pixel(r.position.x + x, r.position.y + y, c)
		if y % 10 == 3:
			for x in range(4, r.size.x - 2, 12):
				_rivet(img, r.position.x + x, r.position.y + y)

# ------------------------------------------------------------------ atlas des découpes (192 x 128)
## Base : cape bleue et mèches de fourrure du guerrier ; ajout du TABARD (tablier) en (128,32,40,96) :
## x = 128 + (u + 0,0796) / 0,1592 * 40, y = 32 + (v - 0,078) / 0,922 * 96.
## Laine bleue du jarl, bordure crème de 2 texels doublée d'un filet sombre, UNE rune crème sobre sur la poitrine
## (pal à deux chevrons, celle des bannières du village), bande de chevrons crème au-dessus des franges découpées.
const D_TABARD := Rect2i(128, 32, 40, 96)
## Mèches du col (passe 3) : 4 variantes de 12 x 24 texels (128 texels/m) en (72, 0) : mèche effilée en pointe (une fourchue),
## brun-crème à la racine, crème clair à la pointe, brins sombres tous les 3 texels.
const D_COL := Rect2i(72, 0, 48, 24)

static func decoupes() -> Image:
	var img := GuerrierTextures.decoupes()
	_rechauffer(img, GuerrierTextures.D_MECHES)
	_pelerine(img)
	_mechesCol(img)
	var r := D_TABARD
	var W := r.size.x
	var H := r.size.y
	for y in H:
		for x in W:
			var sg := 0.05 if ((x + y) & 3) < 2 else -0.04
			var pli := _n(x, y, W, H, 3, 1, 3201)
			var l := 0.50 + sg + (pli - 0.5) * 0.45 + (_n(x, y, W, H, 8, 12, 3202) - 0.5) * 0.1
			l += 0.08 * (1.0 - float(y) / H)
			var t := clampi(int(floorf(l * 6.0 + (_h(x, y, 3203) - 0.5) * 0.3)), 0, 5)
			var c := _c(BLEU_JARL, t)
			# bordure crème (côtés) + filet sombre à l'intérieur
			if x <= 1 or x >= W - 2:
				c = _c(CREME, 3 if x == 0 or x == W - 1 else 2)
			elif x == 2 or x == W - 3:
				c = _c(BLEU_JARL, 0)
			# bande de chevrons au-dessus des franges (y 78-85)
			if y >= 78 and y <= 85 and x > 2 and x < W - 3:
				var d := posmod(x + absi(y - 81) * 1, 6)
				c = _c(CREME, 2 + (1 if d == 0 else 0)) if (d < 2) else _c(BLEU_JARL, 1)
				if y == 78 or y == 85:
					c = _c(CREME, 3)
			# franges : dents irrégulières découpées (y 88-95)
			if y >= 87:
				var coupe := 87 + int(_h(x, 0, 3204) * 4.0) + (2 if x % 2 == 0 else 0)
				if y > coupe:
					c = Color(0, 0, 0, 0)
				elif x % 2 == 0:
					c = _c(CREME, 1)
			img.set_pixel(r.position.x + x, r.position.y + y, c)
	# rune de la poitrine (centrée en x, y 8-30) : pal vertical + deux chevrons ouverts vers le bas
	var cx := r.position.x + W / 2
	for k in 23:
		var yy := r.position.y + 8 + k
		img.set_pixel(cx - 1, yy, _c(CREME, 3))
		img.set_pixel(cx, yy, _c(CREME, 4))
		img.set_pixel(cx + 1, yy, _c(BLEU_JARL, 0))
	for cv in [0, 9]:
		for k in 8:
			var yy: int = r.position.y + 10 + cv + k
			for sgn: int in [-1, 1]:
				var xx: int = cx + sgn * (k + 1)
				img.set_pixel(xx, yy, _c(CREME, 3))
				img.set_pixel(xx, yy + 1, _c(BLEU_JARL, 0))
	return img

# ------------------------------------------------------------------ pèlerine de la garde (passe 2)
## La cape longue du guerrier devient une PÈLERINE aux couleurs de la garde qui s'arrête aux hanches (le tabard se voit dessous,
## de dos) : UV planaires vus de dos à 128 texels/m, x = (0,28 - x) * 128 (gauche de l'image = côté gauche vu de dos),
## y = (1,58 - y) * 128. Laine bleu ardoise, plis, EMBLÈME de la cité (étoile crème à 8 branches du bouclier, dans un anneau)
## centré à 1,10 m, galon crème doublé de filets sombres au-dessus de l'ourlet, ourlet effiloché découpé vers 0,87 m.
const D_PELERINE := Rect2i(0, 0, 72, 96)
const PEL_X := 0.28
const PEL_Y := 1.58

static func _pelerine(img: Image) -> void:
	var r := D_PELERINE
	var W := r.size.x
	var H := r.size.y
	var cx := W * 0.5 - 0.5
	var cy := (PEL_Y - 1.10) * 128.0
	var R := 13.0
	for y in H:
		for x in W:
			var sg := 0.05 if ((x + y) & 3) < 2 else -0.04
			var pli := _n(x, 0, W, 1, 7, 1, 3301)
			var l := 0.46 + sg + (pli - 0.5) * 0.5 + (_n(x, y, W, H, 10, 12, 3302) - 0.5) * 0.12
			l += 0.10 * (1.0 - float(y) / H)                      # le haut (épaules) prend la lumière
			var t := clampi(int(floorf(l * 6.0 + (_h(x, y, 3303) - 0.5) * 0.3)), 0, 5)
			var c := _c(BLEU_JARL, t)
			# emblème : anneau crème + étoile à 8 branches (croix + sautoir), ombre portée d'un texel en bas à droite
			var dx := x - cx
			var dy := y - cy
			var rr := sqrt(dx * dx + dy * dy)
			var ang := atan2(dy, dx)
			var motif := false
			if rr > R - 1.6 and rr < R + 0.6:
				motif = true
			if rr < R - 2.5:
				for b in 8:
					var a := b * PI / 4.0
					var lb := 1.7 if b % 2 == 0 else 1.3
					if absf(sin(ang - a)) * rr < lb * (1.0 - rr / R * 0.45) and cos(ang - a) > 0.0:
						motif = true
				if rr < 2.2:
					motif = true
			if motif:
				c = _c(CREME, 3 if (dx + dy) < 2.0 else 2)
			else:
				var dx2 := dx - 1.0
				var dy2 := dy - 1.0
				var rr2 := sqrt(dx2 * dx2 + dy2 * dy2)
				if (rr2 > R - 1.6 and rr2 < R + 0.6) or rr2 < 2.2:
					c = _c(BLEU_JARL, 0)
			# galon crème (y 80-84) : filets sombres, chevrons crème sur fond bleu sombre
			if y >= 79 and y <= 85:
				if y == 79 or y == 85:
					c = _c(BLEU_JARL, 0)
				elif y == 80 or y == 84:
					c = _c(CREME, 3)
				else:
					var d := posmod(x + absi(y - 82), 5)
					c = _c(CREME, 2) if d < 2 else _c(BLEU_JARL, 1)
			# ourlet effiloché : coupe irrégulière à partir de y 88 (le maillage s'arrête à 0,85 m, y 93)
			var coupe := 88 + int(_h(x / 2, 0, 3304) * 3.0) + int(_h(x, 1, 3305) * 2.0)
			if y > coupe:
				c = Color(0, 0, 0, 0)
			elif y == coupe:
				c = _c(BLEU_JARL, 0)
			img.set_pixel(r.position.x + x, r.position.y + y, c)

## Mèches du col : alpha découpé, pointe vers le bas (v croissant). Variantes : 0 droite, 1 courbée à gauche, 2 courbée à droite, 3 fourchue.
static func _mechesCol(img: Image) -> void:
	var r := D_COL
	for k in 4:
		var x0 := r.position.x + k * 12
		for y in 24:
			var f := float(y) / 23.0
			var demi := 5.8 * (1.0 - pow(f, 2.6)) + 0.4
			var cx := 5.5
			if k == 1:
				cx -= 2.2 * f * f
			elif k == 2:
				cx += 2.2 * f * f
			for x in 12:
				var d := absf(x - cx)
				var visible := d <= demi
				if k == 3 and f > 0.55:
					visible = absf(d - 2.0 * (f - 0.45) * 4.0) < demi * 0.6 + 0.4 and d <= demi
				if not visible:
					img.set_pixel(x0 + x, r.position.y + y, Color(0, 0, 0, 0))
					continue
				var t := 1 + int(f * 3.6) + int(roundf((_h(x, y + k * 24, 3501) - 0.5) * 0.9))
				if (x + k) % 3 == 0:
					t -= 1                                   # brin sombre
				elif absf(x - cx) < 1.0:
					t += 1                                   # arête de la mèche, plus claire
				if d > demi - 1.0:
					t -= 1                                   # bord dans l'ombre
				img.set_pixel(x0 + x, r.position.y + y, _c(COL_FOUR, clampi(t, 0, 5)))

## Peau de la mante sous le col (passe 3) : pelage crème chaud uni, brins verticaux courts un ton plus clairs ou plus sombres,
## racines sombres vers le bas de l'image (jamais de plaques « camouflage »).
static func mante_creme() -> Image:
	var W := 256
	var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var t := 3
			var brin := _h(x, y / 6, 3601)
			if brin > 0.72:
				t = 4
			elif brin < 0.22:
				t = 2
			t += int(roundf((_n(x, y, W, H, 6, 3, 3602) - 0.5) * 1.2))
			img.set_pixel(x, y, _c(COL_FOUR, clampi(t, 1, 5)))
	return img
