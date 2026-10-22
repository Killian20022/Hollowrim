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
const FOUR_CHAUD := ["#25221d", "#47423a", "#6e675a", "#938b79", "#b8b09b", "#d4ccb7"]
const CREME := ["#4e4636", "#73694f", "#9a8f70", "#bdb291", "#d8cfae"]
## Col de fourrure (passe 3) : crème chaude plus claire que FOUR_CHAUD, pour rester crème sous la lumière froide du crépuscule.
const COL_FOUR := ["#33302a", "#5f594c", "#8a8473", "#aea792", "#cdc7b2", "#e2ddc9"]   # gris-beige (référence), moins jaune
const FRENE := ["#1c140e", "#33251a", "#4b3726", "#654b34", "#7f6146", "#9a7a5a"]

# ------------------------------------------------------------------ précalcul (même contrat que GuerrierTextures)
const DOSSIER := "res://assets/persos/gardien"
const VERSION := 12
## Masques de relief cuits (sources_blender/scripts/bake_persos.py) : bake_<texture>.png
const BAKE := "res://sources_blender/bake/gardien"
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
				"bottes": img = bottes()
				"pantalon": img = pantalon()
				"brassards": img = brassards()
				_: push_error("GardienTextures : texture inconnue " + nom)
			img = BakeRelief.appliquer(img, "%s/bake_%s.png" % [BAKE, nom])   # relief cuit par Blender, quantifié dans la palette
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
	_plastron_mailles(img)
	_sacoche(img)
	_baudrier(img)
	_gants(img)
	return img

## Baudrier de cuir brun usé (référence : sangle brune cousue qui barre la poitrine) : bords sombres, piqûres claires à 2 texels du
## bord, trous de réglage, rivets, plaques frottées.
static func _baudrier(img: Image) -> void:
	var r := GuerrierTextures.R_BAUD
	for y in r.size.y:
		for x in r.size.x:
			var t := GuerrierTextures._ton_cuir(x, y, r.size.x, r.size.y, 0.40, 3721)
			if x <= 1 or x >= r.size.x - 2:
				t = 0
			elif x == 2 or x == r.size.x - 3:
				t = 4 if _h(x, y, 3722) > 0.4 else 5            # arête usée
			elif (x == 4 or x == r.size.x - 5) and y % 4 < 2:
				t = 6                                          # piqûre
			img.set_pixel(r.position.x + x, r.position.y + y, _c(GuerrierTextures.CUIR, t))
		if y % 14 == 6:
			var cx := r.position.x + r.size.x / 2 - 1
			img.set_pixel(cx, r.position.y + y, _c(GuerrierTextures.CUIR, 0))         # trou de réglage
			img.set_pixel(cx + 1, r.position.y + y, _c(GuerrierTextures.CUIR, 0))
		if y % 28 == 20:
			_rivet(img, r.position.x + r.size.x / 2 - 1, r.position.y + y)

## Neige poudrée (fond de ciel bleuté) : tons du plus sombre au plus clair.
const NEIGE := ["#7f8ba3", "#a3aec4", "#c6cfdf", "#e3e9f2"]

## Bourse de cuir (fenêtre 28 x 10 de la région : x + 2..30, y + 4..14 de _boite) : rabat cousu, sangle verticale, rivet, bord sombre.
const R_SACOCHE := Rect2i(24, 208, 32, 16)

static func _sacoche(img: Image) -> void:
	var r := R_SACOCHE
	for y in r.size.y:
		for x in r.size.x:
			img.set_pixel(r.position.x + x, r.position.y + y, _c(GuerrierTextures.CUIR, GuerrierTextures._ton_cuir(x, y, r.size.x, r.size.y, 0.42, 3701)))
	for x in range(2, 30):
		img.set_pixel(r.position.x + x, r.position.y + 4, _c(GuerrierTextures.CUIR, 0))           # haut
		img.set_pixel(r.position.x + x, r.position.y + 13, _c(GuerrierTextures.CUIR, 0))          # bas
		img.set_pixel(r.position.x + x, r.position.y + 5, _c(GuerrierTextures.CUIR, 5))           # arête usée du rabat
		if x % 3 != 2:
			img.set_pixel(r.position.x + x, r.position.y + 7, _c(GuerrierTextures.CUIR, 6))       # couture du rabat
		img.set_pixel(r.position.x + x, r.position.y + 8, _c(GuerrierTextures.CUIR, 1))           # ombre sous le rabat
	for y in range(4, 14):
		img.set_pixel(r.position.x + 2, r.position.y + y, _c(GuerrierTextures.CUIR, 0))
		img.set_pixel(r.position.x + 29, r.position.y + y, _c(GuerrierTextures.CUIR, 0))
		img.set_pixel(r.position.x + 15, r.position.y + y, _c(GuerrierTextures.CUIR, 0))          # sangle
		img.set_pixel(r.position.x + 16, r.position.y + y, _c(GuerrierTextures.CUIR, 5))
	_rivet(img, r.position.x + 15, r.position.y + 9)

## Plastron de cuir du guerrier -> COTTE DE MAILLES (référence : poitrine de mailles brun-gris sous le baudrier). Dans la région
## du plastron (mêmes UV que la tunique) : anneaux de la cotte, deux bandes de cuir cousu à rivets en haut (col) et en bas (ceinture).
static func _plastron_mailles(img: Image) -> void:
	var m := mailles()
	var R := GuerrierTextures.R_PLASTRON
	var y0 := int(0.22 * 128)
	var y1 := int(0.66 * 128)
	for y in R.size.y:
		for x in R.size.x:
			var sx := posmod(x - GuerrierTextures.PL_U0, 256)
			var sy := clampi(y + GuerrierTextures.PL_V0, 0, 127)
			if sy < y0 + 4 or sy > y1 - 4:
				continue                                   # bandes de cuir du plastron gardées
			var c := m.get_pixel(sx, sy)
			# ombre sous le col, lumière sur le haut du buste (les anneaux restent nets, un ton seulement)
			c = Color(minf(c.r * 1.22, 1.0), minf(c.g * 1.2, 1.0), minf(c.b * 1.15, 1.0), 1.0)    # mailles un cran plus claires (gris-brun lisible)
			if sy < y0 + 8:
				c = c.darkened(0.22)                        # ombre sous le col de fourrure
			img.set_pixel(R.position.x + x, R.position.y + y, c)

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
	GuerrierTextures._eraflures(img, Rect2i(r.position.x + 3, r.position.y + 6, W - 6, 32), 5, 3411)
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
			elif yl <= 2 and _n(x, y, r.size.x, r.size.y, 10, 3, 3153) > 0.58 and _h(x, y, 3154) > 0.3:
				c = _c(NEIGE, 1 + int(_h(x, y, 3155) * 2.0))     # neige accrochée au haut des lames
			elif yl == 8 and _h(x, y, 3156) > 0.8:
				c = _c(GuerrierTextures.ROUILLE, 1)                # rouille sous les rivets
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
	_tabard(img)
	return img

## Tabard (passe vêtements) : de la ceinture (texel 42) aux franges, laine bleue sergée, galon crème de 4 texels sur les côtés
## (fil sombre, points de broderie), PANNEAU central brodé d'une chaîne de losanges entrelacés crème (référence : bande ornée
## des tabards de la garde), bande de chevrons, franges découpées ; crasse brune et poussière de neige vers l'ourlet.
static func _tabard(img: Image) -> void:
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
			# galon crème sur les côtés (4 texels) : filet sombre dehors, deux rangs crème, filet sombre dedans, points de couture
			if x == 0 or x == W - 1:
				c = _c(BLEU_JARL, 0)
			elif x <= 2 or x >= W - 3:
				c = _c(CREME, 3 if (y % 4) < 2 else 2)
			elif x == 3 or x == W - 4:
				c = _c(BLEU_JARL, 0)
			# panneau brodé central (x 11..28, y 44..76) : fond bleu plus sombre, filets crème, losanges entrelacés
			if x >= 11 and x <= 28 and y >= 44 and y <= 76:
				c = _c(BLEU_JARL, clampi(t - 1, 0, 3))
				if x == 11 or x == 28 or y == 44 or y == 76:
					c = _c(CREME, 2)
				elif x == 12 or x == 27 or y == 45 or y == 75:
					c = _c(BLEU_JARL, 0)
				else:
					var cy := posmod(y - 47, 8) - 4                 # cellule de 8 texels de haut
					var dx := absi(x - 19) if x >= 19 else absi(x - 20)
					var d := dx + absi(cy)
					if d == 4 or (d == 3 and (x + y) % 2 == 0 and dx > 0):
						c = _c(CREME, 3 if (x < 20) == (cy < 0) else 2)   # losange : deux demi-brins qui s'entrecroisent
					elif d == 0 or (dx == 1 and cy == 0):
						c = _c(CREME, 4)                               # nœud central
					elif dx >= 7 and (cy == 0 or cy == -4):
						c = _c(CREME, 1)                               # point aux bords
			# bande de chevrons au-dessus des franges (y 79-86)
			if y >= 79 and y <= 86 and x > 3 and x < W - 4:
				var d2 := posmod(x + absi(y - 82), 6)
				c = _c(CREME, 2 + (1 if d2 == 0 else 0)) if (d2 < 2) else _c(BLEU_JARL, 1)
				if y == 79 or y == 86:
					c = _c(CREME, 3)
			# crasse et usure en bas : brun-gris sale, plus dense près de l'ourlet ; neige poudrée dans les plis
			if y >= 58 and c.a > 0.0:
				var sale := (float(y) - 58.0) / 38.0
				if _n(x, y, W, H, 6, 8, 3207) < sale * 0.75 and _h(x, y, 3208) > 0.25:
					c = c.lerp(_c(GuerrierTextures.CUIR, 1), 0.55)
			if y >= 42 and y < 60 and _n(x, y, W, H, 4, 3, 3209) > 0.78 and _h(x, y, 3210) > 0.55 and x > 3 and x < W - 4:
				c = _c(NEIGE, 1)
			# franges : dents irrégulières découpées (y 88-95), pointes de fil crème
			if y >= 88:
				var coupe := 88 + int(_h(x, 0, 3204) * 4.0) + (2 if x % 2 == 0 else 0)
				if y > coupe:
					c = Color(0, 0, 0, 0)
				elif x % 2 == 0:
					c = _c(CREME, 1)
			img.set_pixel(r.position.x + x, r.position.y + y, c)

# ------------------------------------------------------------------ pèlerine de la garde (passe 2)
## La cape longue du guerrier devient une PÈLERINE aux couleurs de la garde qui s'arrête aux hanches (le tabard se voit dessous,
## de dos) : UV planaires vus de dos à 128 texels/m, x = (0,28 - x) * 128 (gauche de l'image = côté gauche vu de dos),
## y = (1,58 - y) * 128. Laine bleu ardoise, plis, EMBLÈME de la cité (étoile crème à 8 branches du bouclier, dans un anneau)
## centré à 1,10 m, galon crème doublé de filets sombres au-dessus de l'ourlet, ourlet effiloché découpé vers 0,87 m.
const D_PELERINE := Rect2i(0, 0, 72, 128)
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
			# neige accrochée aux épaules et aux plis du haut, crasse brune vers l'ourlet
			if y < 14 and _n(x, y, W, H, 9, 5, 3306) > 0.52 + float(y) * 0.02 and _h(x, y, 3307) > 0.25:
				c = _c(NEIGE, 1 + int(_h(x, y, 3308) * 2.5))
			elif y > 60 and _n(x, y, W, H, 7, 6, 3309) < (float(y) - 60.0) / 40.0 * 0.7 and _h(x, y, 3310) > 0.3:
				c = c.lerp(_c(GuerrierTextures.CUIR, 1), 0.5)
			# ourlet effiloché : coupe irrégulière à partir de y 88 (le maillage s'arrête à 0,85 m, y 93)
			var coupe := 121 + int(_h(x / 2, 0, 3304) * 3.0) + int(_h(x, 1, 3305) * 2.0)
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
				var t := 2 + int(f * 3.0) + int(roundf((_h(x, y + k * 24, 3501) - 0.5) * 0.9))
				if (x + k) % 4 == 0:
					t -= 1                                   # brin sombre
				elif absf(x - cx) < 1.0:
					t += 1                                   # arête de la mèche, plus claire
				if d > demi - 0.7:
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


# ------------------------------------------------------------------ pantalon de laine (passe vêtements)
## Large pantalon de laine gris sombre (référence : « braies » amples, plis aux genoux), SANS les bandes molletières du guerrier
## (les bottes portent leurs lanières) : sergé fin, couture de côté piquée, plis (clairs sur la crête, sombres au creux),
## genou usé, boue brun-gris sur le bas et neige poudrée sur le haut des bottes. v : 0 = ceinture, 127 = ourlet (comme le guerrier).
const LAINE_CHAUDE := ["#161513", "#262522", "#383632", "#4a4743", "#5e5a54"]   # gris de laine naturelle, un peu chaud (référence : braies gris sombre)

static func pantalon() -> Image:
	var W := 256
	var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var sg := 0.06 if ((x + y) & 3) < 2 else -0.05
			var pli := _n(x, y, W, H, 14, 3, 831)
			var l := 0.46 + sg + (pli - 0.5) * 0.42 + (_n(x, y, W, H, 40, 10, 836) - 0.5) * 0.10
			var t := clampi(int(floorf(l * 5.0 + (_h(x, y, 832) - 0.5) * 0.35)), 0, 4)
			var c := _c(LAINE_CHAUDE, t)
			# couture de côté (x ~ 64 et 192) : fente sombre + piqûre claire
			for xs: int in [64, 192]:
				if x == xs:
					c = _c(LAINE_CHAUDE, 0)
				elif x == xs + 1 and vy % 3 != 0:
					c = _c(GuerrierTextures.BANDE, 3)
			# genou : zone usée, plus claire, et plis de tissu en chevrons
			if vy >= 52 and vy <= 62 and _n(x, y, W, H, 12, 2, 837) > 0.5:
				c = _c(LAINE_CHAUDE, clampi(t + 1, 0, 4))
			# boue brun-gris sur le bas (35 cm), plus dense vers l'ourlet ; neige poudrée à l'ourlet
			if vy < 36:
				var sale := 1.0 - float(vy) / 36.0
				if _n(x, y, W, H, 16, 6, 838) < sale * 0.9 and _h(x, y, 839) > 0.2:
					c = c.lerp(_c(GuerrierTextures.CUIR_SOMBRE, 3), 0.6)
			if vy < 6 and _h(x, y, 840) > 0.7:
				c = _c(NEIGE, 0 + int(_h(x, y, 841) * 2.0))
			img.set_pixel(x, y, c)
	return img

# ------------------------------------------------------------------ bottes : jambières de cuir bandées (passe vêtements)
## Cuir brun à BANDES de lanière enroulées (7 texels de haut, bord haut sombre, bord bas éclairé, léger biais, couture piquée),
## semelle sombre, boue sur le pied, revers de fourrure crème en haut de tige ; neige dans le revers.
static func bottes() -> Image:
	var W := 128
	var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var c := _c(GuerrierTextures.CUIR, GuerrierTextures._ton_cuir(x, y, W, H, 0.37, 841))
			if vy < 3:
				c = _c(GuerrierTextures.CUIR_SOMBRE, 1 + (1 if vy == 2 else 0))
			elif vy < 5:
				c = _c(GuerrierTextures.CUIR, 0)
			elif vy > 8 and vy < 48:
				# bandes enroulées : période 7, biais d'un texel tous les 16 en x
				var q := posmod(vy + (x >> 4), 7)
				if q == 6:
					c = _c(GuerrierTextures.CUIR_SOMBRE, 0)              # joint sombre entre deux tours
				elif q == 5:
					c = _c(GuerrierTextures.CUIR, 1)
				elif q == 0:
					c = _c(GuerrierTextures.CUIR, 5 + (1 if _h(x, y, 845) > 0.6 else 0))   # arête éclairée du tour
				elif q == 3 and x % 4 < 2:
					c = _c(GuerrierTextures.CUIR, 4)                    # piqûre
				# boucle de sangle verticale à l'avant (x ~ 0 et 127)
				if x < 3 or x > 124:
					c = _c(GuerrierTextures.CUIR_CLAIR, 1 if (x == 0 or x == 127) else 3)
			# boue sur le pied et la cheville
			if vy >= 5 and vy < 18 and _n(x, y, W, H, 14, 5, 846) < (18.0 - vy) / 18.0 * 0.8:
				c = c.lerp(_c(GuerrierTextures.CUIR_SOMBRE, 2), 0.6)
			if vy < 7 and _h(x, y, 847) > 0.82:
				c = _c(NEIGE, 1)
			if vy > 50:
				var f := _n(x, y, W, H, 32, 4, 844)
				c = _c(FOUR_CHAUD, 2 + int(f * 3.0) + (1 if vy > 53 else 0))
				if posmod(x * 7 + vy, 5) == 0:
					c = _c(FOUR_CHAUD, 1)
				if vy > 58 and _h(x, y, 848) > 0.86:
					c = _c(NEIGE, 2)
			img.set_pixel(x, y, c)
	return img

# ------------------------------------------------------------------ brassards : manchon de cuir et revers de fourrure
## Cuir lacé (rainures et piqûres comme le guerrier) ; bande de fourrure crème aux deux bouts (revers de manche),
## fil de fer rivé sous la fourrure.
static func brassards() -> Image:
	var img := GuerrierTextures.brassards()
	var W := img.get_width()
	var H := img.get_height()
	for y in H:
		var d := mini(y, H - 1 - y)
		if d < 11:
			for x in W:
				if d < 3:
					continue
				if d == 10:
					img.set_pixel(x, y, _c(GuerrierTextures.CUIR, 0))
					continue
				var f := _n(x, y, W, H, 24, 6, 3801)
				var t := 2 + int(f * 3.0) + (1 if d > 7 else 0)
				if posmod(x * 5 + d * 3, 5) == 0:
					t -= 1
				img.set_pixel(x, y, _c(FOUR_CHAUD, clampi(t, 1, 5)))
	return img


## Gants de cuir brun, 16 x 16 texels dans l'atlas des accessoires en (60,208) (UV du gant étirées sur la région : cuir usé uni,
## coutures verticales piquées, arêtes claires).
const R_GANT := Rect2i(60, 208, 16, 16)

static func _gants(img: Image) -> void:
	var r := R_GANT
	for y in r.size.y:
		for x in r.size.x:
			var t := GuerrierTextures._ton_cuir(x, y, r.size.x, r.size.y, 0.40, 3901)
			if x % 5 == 0:
				t = 1
			elif x % 5 == 1 and _h(x, y, 3902) > 0.4:
				t = 5
			elif x % 5 == 3 and y % 3 != 0:
				t = 6
			img.set_pixel(r.position.x + x, r.position.y + y, _c(GuerrierTextures.CUIR, t))
