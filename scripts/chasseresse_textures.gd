class_name ChasseresseTextures
## Textures de la Chasseresse nordique (ChasseresseNordique), même méthode que GuerrierTextures (128 texels/m, palettes froides
## de 4 à 7 tons, contours et rehauts peints, bruit sans tramage Bayer, mipmaps pixel art) ; les outils et les matières
## communes (fourrure, bottes, fer, anneau, baudrier, ceinture) sont APPELÉS dans GuerrierTextures (même famille).
## Référence : Image ChatGPT 21 oct. 2026, 14_01_57-2.png (chasseresse blonde, cape vert-bleu sombre, jaque de cuir à écailles,
## col de fourrure, pantalon olive, bottes lacées, arc long, carquois).


# palettes (sombre -> clair)
## jaque de cuir à écailles : brun-gris (pas de bleu : la maille du guerrier virait trop bleu au crépuscule)
const CUIR_E := ["#1c150e", "#30251b", "#45372a", "#5c4936", "#755d45", "#8f7558", "#a98e6e"]
## cape (passe 2) : laine ardoise très sombre, bleu désaturé (la cape de la référence est bleu nuit, pas sarcelle ni verte)
const LAINE_VERTE := ["#0d1015", "#151a22", "#1e252f", "#28313d", "#343e4b", "#444f5d"]
## tabard : bleu-gris (mailles de la référence), liseré crème
const TABARD := ["#171b22", "#222833", "#2f3744", "#3f4857", "#535d6c"]
## pantalon (passe 2) : laine brun sombre (référence), plus d'olive
const LAINE_OLIVE := ["#14100c", "#1e1812", "#2a2119", "#372c21", "#45382b", "#554636"]
## fourrure (passe 2) : crème / beige chaud, pointes claires ; plus chaude que l'intuition (le crépuscule bleuit tout)
const FOUR_CHAUD := ["#2e2318", "#5a4632", "#7f6a4b", "#a68e69", "#c6ae89", "#ddcaa5"]
## cuir de la capuche rabattue : brun moyen usé
const CUIR_CAPUCHE := ["#1d140d", "#33241a", "#4b3626", "#644a34", "#7e6045", "#977758"]
const BLOND := ["#33230f", "#553c1c", "#7a5a2c", "#9e7a3e", "#c09a55", "#dbb872"]
const PLUME := ["#2a2824", "#59544b", "#8f887a", "#bdb5a3", "#ddd6c4"]
## arc : bois d'if brun-roux (âme claire, dos sombre)
const BOIS_ARC := ["#1c120b", "#2f1f13", "#45301d", "#5c4229", "#765637", "#8f6c48"]

static var _cache := {}

# ------------------------------------------------------------------ précalcul (comme GuerrierTextures)
const DOSSIER := "res://assets/persos/chasseresse"
const VERSION := 7
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
				"jaque": img = jaque()
				"pantalon": img = pantalon()
				"brassards": img = brassards()
				"accessoires": img = accessoires()
				"decoupes": img = decoupes()
				"mante": img = mante()
				"bottes": img = bottes()
				_: push_error("ChasseresseTextures : texture inconnue " + nom)
			mips = GuerrierTextures.mips_pixel(img)
			sauver(nom, mips)
		_cache[nom] = ImageTexture.create_from_image(mips)
	return _cache[nom]

static func vider() -> void:
	_cache.clear()

static func _c(pal: Array, i: int) -> Color:
	return Color(pal[clampi(i, 0, pal.size() - 1)])

# ------------------------------------------------------------------ jaque (UV de la tunique femme, 256 x 128)
## UV mesurés (outils/chasseresse_sonde.gd) : u = 0 devant ; torse v 0,12-0,70 ; ceinture v ~0,62-0,70 ; jupe v 0,66-1 (ourlet v = 1).
## Torse et manches : cuir à écailles arrondies (5 x 4 texels, rangs en quinconce, bord bas sombre, dessus frotté clair) ;
## jupe : panneaux de cuir lisse fendus, tabard sarcelle au milieu du devant (liseré tissé crème, pointe en V) ;
## ourlet : bande de fourrure dentelée (la jupe à franges de la référence ; les mèches géométriques s'y ajoutent).
const V_JUPE := 0.66

static func dx_t(x: int, W: int) -> int:
	return absi(x if x < W / 2 else x - W)

static func jaque() -> Image:
	var W := 256
	var H := 128
	var img := GuerrierTextures._img(W, H)
	var yj := int(V_JUPE * H)
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var c: Color
			if y < yj:
				# écailles fines (passe vetements) : rang de 3 texels, cellules de 4, quinconce ; contraste doux (cuir brun sombre,
				# la reference montre une cotte serree, pas de gros pavés)
				var rang := y / 3
				var cx := posmod(x + (rang & 1) * 2, 3)
				var cy := y % 3
				var t := 2
				if cy == 2:
					t = 1                                       # ombre sous l'écaille
				elif cy == 0 and cx == 1:
					t = 4                                       # dessus frotté
				elif cx == 0:
					t = 1
				t += int(roundf((GuerrierTextures._n(x, y, W, H, 10, 4, 1101) - 0.5) * 1.6))
				if GuerrierTextures._h(x, y, 1102) > 0.97:
					t -= 1
				c = _c(CUIR_E, clampi(t, 0, 6))
			else:
				# jupe : panneaux de 32 texels fendus, cuir lisse usé
				var px := posmod(x + 16, 32)
				var t2 := GuerrierTextures._ton_cuir(x, y, W, H, 0.42, 1111)
				if px == 0:
					t2 = 0
				elif px == 1:
					t2 = 4
				elif px == 3 and y % 3 != 0:
					t2 = 6
				# passe vetements : plis d'etoffe (ombre tous les 32 texels decales), salissure et boue vers l'ourlet, piqure de l'ourlet
				if posmod(x + 7, 32) < 3 and vy > 6:
					t2 -= 1
				if vy < 24 and GuerrierTextures._n(x, y, W, H, 14, 5, 1115) > 0.62 - float(24 - vy) * 0.012:
					t2 -= 1
				if vy < 8:
					t2 -= 1
				t2 = clampi(t2, 0, 6)
				c = GuerrierTextures._c(GuerrierTextures.CUIR, t2)
				# tabard sarcelle au milieu du devant (|u| < 0,055) : pointe en V à l'ourlet
				var dx := absi(x if x < W / 2 else x - W)
				var bout := 10 + dx            # le V descend jusqu'à 10 texels de l'ourlet
				if dx < 14 and vy >= bout - 4:
					var tt := 2 + int(roundf((GuerrierTextures._n(x, y, W, H, 6, 8, 1112) - 0.5) * 1.6))
					if posmod(y, 3) == 0 and dx < 11:
						tt += 1                                 # trame
					c = _c(TABARD, tt)
					# liseré tissé crème le long des bords (chevrons) et ligne sombre
					if dx >= 11 or vy < bout:
						c = _c(GuerrierTextures.PEINT_CREME, 1 + (1 if posmod(x + y, 4) < 2 else 0))
					if dx == 13 or vy == bout - 4:
						c = _c(TABARD, 0)
					if dx < 9 and absi(dx - 4) <= 1 and posmod(y, 6) < 3 and vy > bout + 4:
						c = _c(GuerrierTextures.PEINT_CREME, 0)                # motif central (losanges)
			# ourlet : fourrure dentelée (6 à 9 texels)
			var bande := 6 + int(GuerrierTextures._h(x / 2, 0, 1121) * 4.0)
			if y >= yj and vy < bande:
				var f := GuerrierTextures._n(x, y, W, H, 40, 3, 1122)
				var tf := 2 + int(f * 3.0) + (1 if vy > 2 else 0)
				if posmod(x * 5 + vy, 4) == 0:
					tf = 1
				c = _c(FOUR_CHAUD, tf)
			elif y >= yj and vy == bande:
				c = GuerrierTextures._c(GuerrierTextures.CUIR, 0)
			elif y >= yj and vy == bande + 3 and x % 3 != 0 and not (dx_t(x, W) < 14):
				c = GuerrierTextures._c(GuerrierTextures.CUIR, 5)                  # piqure de l'ourlet
			GuerrierTextures._p(img, x, y, c)
	# couture de la taille (sous la ceinture) et piqûres de bord
	for x in W:
		GuerrierTextures._p(img, x, yj, GuerrierTextures._c(GuerrierTextures.CUIR, 0))
		GuerrierTextures._p(img, x, yj + 1, GuerrierTextures._c(GuerrierTextures.CUIR, 5))
	return img

# ------------------------------------------------------------------ pantalon olive (256 x 128)
## Laine olive sombre, plis verticaux, genouillère de cuir usé (v ~0,55-0,65), crasse vers la cheville (cachée par la botte).
static func pantalon() -> Image:
	var W := 256
	var H := 128
	var img := GuerrierTextures._img(W, H)
	for y in H:
		for x in W:
			var sg := 0.05 if ((x + y) & 3) < 2 else -0.04
			var pli := GuerrierTextures._n(x, 0, W, 1, 18, 1, 1131)
			var l := 0.50 + sg + (pli - 0.5) * 0.45 + (GuerrierTextures._n(x, y, W, H, 14, 4, 1132) - 0.5) * 0.2
			var c := _c(LAINE_OLIVE, GuerrierTextures._ton(l, 6, x, y, 1133))
			# coutures latérales
			if posmod(x, 64) == 32:
				c = _c(LAINE_OLIVE, 0)
			_p(img, x, y, c)
	return img

# ------------------------------------------------------------------ brassards (128 x 64) : cuir lacé, sans fer
## Cuir sombre à écailles fines (comme la jaque), laçage croisé clair sur la face externe, bords cousus.
static func brassards() -> Image:
	var W := 128
	var H := 64
	var img := GuerrierTextures._img(W, H)
	for y in H:
		for x in W:
			var c := GuerrierTextures._c(GuerrierTextures.CUIR, GuerrierTextures._ton_cuir(x, y, W, H, 0.40, 1141) - 1)
			var e := posmod(x + (y / 3 & 1) * 2, 4)
			if y % 3 == 2 and e != 0:
				c = GuerrierTextures._c(GuerrierTextures.CUIR, 1)
			# laçage croisé (tous les 16 texels)
			var a := posmod(x + y, 16)
			var b := posmod(x - y, 16)
			if (a == 0 or b == 0) and posmod(x, 32) < 8:
				c = GuerrierTextures._c(GuerrierTextures.CUIR, 6)
			_p(img, x, y, c)
	for x in W:
		for k in 3:
			_p(img, x, k, GuerrierTextures._c(GuerrierTextures.CUIR_SOMBRE, 1 + k))
			_p(img, x, H - 1 - k, GuerrierTextures._c(GuerrierTextures.CUIR_SOMBRE, 1 + k))
		if x % 4 < 2:
			_p(img, x, 4, GuerrierTextures._c(GuerrierTextures.CUIR, 6))
			_p(img, x, H - 5, GuerrierTextures._c(GuerrierTextures.CUIR, 6))
	return img

static func _p(img: Image, x: int, y: int, c: Color) -> void:
	GuerrierTextures._p(img, x, y, c)

# ------------------------------------------------------------------ atlas des accessoires (256 x 256)
## MÊME disposition que GuerrierTextures.accessoires pour les régions que les accessoires partagés lisent (fer, anneau, bosse,
## œil, tresse, baudrier, ceinture, lame, poignée) ; les régions du bouclier, inutiles ici, portent l'arc, le carquois, les flèches :
##   (0,0,16,128)    arc : bois d'if veiné, poignée de cuir au milieu (v 56-72), bouts de corne
##   (16,0,4,128)    corde
##   (32,0,64,64)    carquois : cuir repoussé, coutures verticales, cerclage haut sombre, fond
##   (96,0,8,64)     fût de flèche
##   (104,0,16,64)   fourreau du couteau : cuir sombre, bouterolle de fer
const R_ARC := Rect2i(0, 0, 16, 128)
const R_CORDE := Rect2i(16, 0, 4, 128)
const R_CARQ := Rect2i(32, 0, 64, 64)
const R_FUT := Rect2i(96, 0, 8, 64)
const R_FOURREAU := Rect2i(104, 0, 16, 64)
## (32,64,96,64) capuche rabattue : cuir brun (u autour du cou, v du bord vers la pointe), doublure sombre en v 56-63
const R_CAPUCHE := Rect2i(32, 64, 96, 64)

static func accessoires() -> Image:
	var img := GuerrierTextures._img(GuerrierTextures.ATLAS.x, GuerrierTextures.ATLAS.y, GuerrierTextures._c(GuerrierTextures.FER, 2))
	GuerrierTextures._fer(img, GuerrierTextures.R_FER)
	GuerrierTextures._lame(img)
	GuerrierTextures._poignee(img)
	GuerrierTextures._baudrier(img)
	GuerrierTextures._anneau(img)
	GuerrierTextures._bosse(img)
	GuerrierTextures._ceinture_atlas(img)
	_rouille(img)
	_baudrier_sombre(img)
	_ceinture_sombre(img)
	_oeil(img)
	_tresse(img)
	_arc(img)
	_corde(img)
	_carquois(img)
	_fut(img)
	_fourreau(img)
	_capuche(img)
	return img


## Rouille brun-gris dans les creux du fer (anneau/boucle) : taches de bruit, plus denses vers le bas.
static func _rouille(img: Image) -> void:
	var r := GuerrierTextures.R_ANNEAU
	for y in r.size.y:
		for x in r.size.x:
			var n := GuerrierTextures._n(x, y, r.size.x, r.size.y, 6, 6, 1301)
			if n > 0.58 - float(y) * 0.004:
				var c := img.get_pixel(r.position.x + x, r.position.y + y)
				var rouille := Color("#6b4a36").lerp(Color("#4d4136"), GuerrierTextures._h(x, y, 1302))
				img.set_pixel(r.position.x + x, r.position.y + y, c.lerp(rouille, 0.6 * c.get_luminance() + 0.2))

## Baudrier (passe vetements) : cuir brun SOMBRE (la reference : sangle brun fonce, piquee, qui se detache du jaque sans etre beige),
## bords sombres, piqure en pointilles, rivets, passant de cuir et grande boucle rectangulaire de fer poli au milieu (v 24-39).
static func _baudrier_sombre(img: Image) -> void:
	var r := GuerrierTextures.R_BAUD
	for y in r.size.y:
		for x in r.size.x:
			var t := GuerrierTextures._ton_cuir(x, y, r.size.x, r.size.y, 0.40, 971) - 1
			t = clampi(t, 0, 4)
			if x == 0 or x == r.size.x - 1:
				t = 0
			elif x == 1 or x == r.size.x - 2:
				t = 4 if GuerrierTextures._h(x, y, 972) > 0.4 else 3
			elif (x == 3 or x == r.size.x - 4) and y % 4 < 2:
				t = 5                                   # piqure en pointilles
			img.set_pixel(r.position.x + x, r.position.y + y, GuerrierTextures._c(GuerrierTextures.CUIR, t))
		if y % 16 == 6 and y < 20 or y % 16 == 6 and y > 44:
			GuerrierTextures._rivet(img, r.position.x + 7, r.position.y + y)
	# passant de cuir (v 44-47)
	for y in range(44, 48):
		for x in range(r.size.x):
			var t2 := 1 if (y == 44 or y == 47) else 3
			img.set_pixel(r.position.x + x, r.position.y + y, GuerrierTextures._c(GuerrierTextures.CUIR, t2))
	# boucle rectangulaire : cadre 2 texels, ardillon, ombre portee
	for y in range(24, 40):
		for x in range(r.size.x):
			var bord := x <= 1 or x >= r.size.x - 2 or y <= 25 or y >= 38
			var c: Color
			if bord:
				var lum := 5 if (y <= 25 or x <= 1) else 3
				c = GuerrierTextures._c(GuerrierTextures.METAL_CLAIR, lum)
				if y == 24 or y == 39 or x == 0 or x == r.size.x - 1:
					c = GuerrierTextures._c(GuerrierTextures.CUIR, 0)
			else:
				c = GuerrierTextures._c(GuerrierTextures.CUIR, 1)
				if x >= 7 and x <= 8:
					c = GuerrierTextures._c(GuerrierTextures.METAL_CLAIR, 4)       # ardillon
			img.set_pixel(r.position.x + x, r.position.y + y, c)

## Ceinture large (passe vetements) : cuir brun sombre epais, bords cousus, rivets, pattes de cuir verticales (passants) ;
## la grande boucle est modelee (relief) sur le devant.
static func _ceinture_sombre(img: Image) -> void:
	var r := GuerrierTextures.R_CEINT
	for y in r.size.y:
		for x in r.size.x:
			var t := clampi(GuerrierTextures._ton_cuir(x, y, r.size.x, r.size.y, 0.40, 981) - 1, 0, 4)
			if y == 0 or y == r.size.y - 1:
				t = 0
			elif y == 1 or y == r.size.y - 2:
				t = 4 if GuerrierTextures._h(x, y, 982) > 0.35 else 3
			elif (y == 3 or y == r.size.y - 4) and x % 4 < 2:
				t = 5
			# passants : bande plus sombre de 4 texels toutes les 34 texels, bords clairs
			var pm := posmod(x, 34)
			if y > 1 and y < r.size.y - 2 and pm < 5:
				t = 0 if pm == 0 or pm == 4 else 1
			img.set_pixel(r.position.x + x, r.position.y + y, GuerrierTextures._c(GuerrierTextures.CUIR, t))
	for x in range(12, r.size.x, 17):
		if posmod(x, 34) > 6:
			GuerrierTextures._rivet(img, r.position.x + x, r.position.y + 7)

## Œil (passe chasseresse) : blanc TERNE (le guerrier avait des yeux presque blancs), grand iris bleu-gris, pupille, paupière.
static func _oeil(img: Image) -> void:
	var r := GuerrierTextures.R_OEIL
	for y in r.size.y:
		for x in r.size.x:
			var dx := (x - 7.5) / 7.5
			var dy := (y - 3.5) / 3.5
			var c := Color("#9c958b")
			if dx * dx + dy * dy > 1.0:
				c = Color("#3a2a24")
			var di := Vector2(x - 7.5, (y - 4.0) * 1.1).length()
			if di < 3.3:
				c = Color("#4f7396") if di > 1.2 else Color("#101216")
				if di > 1.2 and di < 2.0 and x < 7 and y < 4:
					c = Color("#7c9dbd")                     # reflet de l'iris
			if y == 0 or (y == 1 and (x < 3 or x > 12)):
				c = Color("#241914")
			img.set_pixel(r.position.x + x, r.position.y + y, c)

## Tresse blonde : chevrons (brins croisés), 3 tons + bords sombres ; lien de cuir au bas (v 28-31).
static func _tresse(img: Image) -> void:
	var r := GuerrierTextures.R_TRESSE
	for y in r.size.y:
		for x in r.size.x:
			var d := posmod(y + absi(x - 8) / 2, 4)
			var t := 4 if d < 2 else 3
			if d == 0:
				t = 5
			if x == 0 or x == 15:
				t = 2
			var c := _c(BLOND, t)
			if y >= 27:
				c = GuerrierTextures._c(GuerrierTextures.CUIR, 2 if y % 2 == 0 else 4)   # lien de cuir
			img.set_pixel(r.position.x + x, r.position.y + y, c)

## Arc : u en travers (0 = ventre, 15 = dos), v le long (0 = bout haut, 127 = bout bas).
static func _arc(img: Image) -> void:
	var r := R_ARC
	for y in r.size.y:
		for x in r.size.x:
			var l := 0.55 - absf(x - 6.0) / 16.0 + (GuerrierTextures._n(x, y, 16, 128, 2, 24, 1151) - 0.5) * 0.35
			var t := GuerrierTextures._ton(l, 6, x, y, 1152, 0.25)
			if x == 0 or x == 15:
				t = 0
			elif x == 2:
				t = mini(t + 1, 5)                              # arête claire
			var c := _c(BOIS_ARC, t)
			if y >= 56 and y < 72:
				# poignée : lanière de cuir enroulée
				var e := posmod(y * 2 + x, 6)
				c = GuerrierTextures._c(GuerrierTextures.CUIR, 1 if e == 0 else (4 if e < 3 else 3))
			elif y < 5 or y > 122:
				c = GuerrierTextures._c(GuerrierTextures.FOUR, 4 - (1 if x > 8 else 0))      # bouts de corne
			elif y == 5 or y == 122 or y == 55 or y == 72:
				c = _c(BOIS_ARC, 0)
			img.set_pixel(r.position.x + x, r.position.y + y, c)

static func _corde(img: Image) -> void:
	var r := R_CORDE
	for y in r.size.y:
		for x in r.size.x:
			img.set_pixel(r.position.x + x, r.position.y + y, _c(PLUME, 2 + (1 if (y / 2) % 2 == 0 else 0)))

## Carquois : u autour (64 texels = 1 tour), v du haut (0) au fond (63). Cuir clair usé, deux coutures, cerclage sombre en haut,
## repoussé en losanges au milieu, fond cerclé.
static func _carquois(img: Image) -> void:
	var r := R_CARQ
	for y in r.size.y:
		for x in r.size.x:
			var t := GuerrierTextures._ton_cuir(x, y, r.size.x, r.size.y, 0.30, 1161) - 1
			var c := GuerrierTextures._c(GuerrierTextures.CUIR, t)
			if y < 6:
				c = GuerrierTextures._c(GuerrierTextures.CUIR_SOMBRE, 2 + (1 if y == 1 else 0))
				if y == 0:
					c = GuerrierTextures._c(GuerrierTextures.CUIR, 5)
			elif y > 58:
				c = GuerrierTextures._c(GuerrierTextures.CUIR_SOMBRE, 2)
			elif x % 32 == 0:
				c = GuerrierTextures._c(GuerrierTextures.CUIR, 0)
			elif x % 32 == 2 and y % 3 != 0:
				c = GuerrierTextures._c(GuerrierTextures.CUIR, 6)
			elif y > 18 and y < 44:
				var a := posmod(x + y, 10)
				var b := posmod(x - y, 10)
				if a == 0 or b == 0:
					c = GuerrierTextures._c(GuerrierTextures.CUIR, 1)
				elif a == 1 or b == 1:
					c = GuerrierTextures._c(GuerrierTextures.CUIR, 5)
			img.set_pixel(r.position.x + x, r.position.y + y, c)

static func _fut(img: Image) -> void:
	var r := R_FUT
	for y in r.size.y:
		for x in r.size.x:
			var t := 3 if x < 4 else 2
			if x == 0 or x == 7:
				t = 1
			img.set_pixel(r.position.x + x, r.position.y + y, _c(BOIS_ARC, t + (1 if GuerrierTextures._h(x, y, 1171) > 0.85 else 0)))

static func _fourreau(img: Image) -> void:
	var r := R_FOURREAU
	for y in r.size.y:
		for x in r.size.x:
			var c := GuerrierTextures._c(GuerrierTextures.CUIR_SOMBRE, 2 + int(GuerrierTextures._n(x, y, 16, 64, 3, 6, 1181) * 2.5))
			if x == 0 or x == 15:
				c = GuerrierTextures._c(GuerrierTextures.CUIR_SOMBRE, 0)
			elif x == 3 and y % 3 != 0:
				c = GuerrierTextures._c(GuerrierTextures.CUIR, 5)
			if y > 54:
				c = GuerrierTextures._c(GuerrierTextures.FER, 4 if x < 7 else 3)              # bouterolle
			img.set_pixel(r.position.x + x, r.position.y + y, c)

# ------------------------------------------------------------------ atlas des découpes (192 x 128) : cape + mèches + plumes
## Même taille et même place des mèches que GuerrierTextures.decoupes (les cartes de fourrure partagées les lisent là) ;
## cape femme : x = u * 256 - CAPE_U0 (UV u 0,186-0,621) ; plumes d'empennage en (128,32,32,32) : 2 variantes de 16 x 32.
const CAPE_U0 := 47
const D_PLUME := Rect2i(128, 32, 32, 32)

static func decoupes() -> Image:
	var img := GuerrierTextures._img(GuerrierTextures.DECOUPES.x, GuerrierTextures.DECOUPES.y, Color(0, 0, 0, 0))
	var cp := cape()
	for y in 128:
		for x in 112:
			img.set_pixel(x, y, cp.get_pixel(posmod(x + CAPE_U0, 256), y))
	var m := meches()
	img.blit_rect(m, Rect2i(Vector2i.ZERO, m.get_size()), GuerrierTextures.D_MECHES.position)
	_plumes(img)
	return img

## Cape vert-bleu sombre : plis verticaux, frise tissée brun-ocre près de l'ourlet (référence), ourlet effiloché découpé.
static func cape() -> Image:
	var W := 256
	var H := 128
	var img := GuerrierTextures._img(W, H)
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var sg := 0.04 if ((x + y) & 3) < 2 else -0.03
			var pli := GuerrierTextures._n(x, 0, W, 1, 22, 1, 1191)
			var l := 0.42 + sg + (pli - 0.5) * 0.55 + (GuerrierTextures._n(x, y, W, H, 30, 10, 1192) - 0.5) * 0.12
			l += 0.10 * smoothstep(90.0, 120.0, float(vy))
			var c := _c(LAINE_VERTE, GuerrierTextures._ton(l, 6, x, y, 1193, 0.3))
			# frise (passe vetements) : ENTRELACS nordique (deux brins qui se croisent, dessus/dessous alternes) entre deux filets
			if vy >= 7 and vy <= 16:
				c = _c(LAINE_VERTE, 1)
				if vy == 7 or vy == 16:
					c = GuerrierTextures._c(GuerrierTextures.CUIR, 3).lerp(_c(LAINE_VERTE, 2), 0.4)
				else:
					var ph := TAU * float(x) / 20.0
					var ya := 11.5 + 2.6 * sin(ph)
					var yb := 11.5 - 2.6 * sin(ph)
					var da := absf(float(vy) - ya)
					var db := absf(float(vy) - yb)
					var dessus_a := cos(ph) > 0.0
					var ocre := GuerrierTextures._c(GuerrierTextures.CUIR, 5).lerp(_c(LAINE_VERTE, 3), 0.25)
					var ombre := GuerrierTextures._c(GuerrierTextures.CUIR, 2).lerp(_c(LAINE_VERTE, 1), 0.3)
					if da < 1.0 and (dessus_a or db >= 1.0):
						c = ocre if da < 0.6 else ombre
					elif db < 1.0:
						c = ocre if db < 0.6 else ombre
			# ourlet effiloche : coupe irreguliere + fils plus longs
			var coupe := int(GuerrierTextures._h(x / 2, 0, 1194) * 6.0) + int(GuerrierTextures._h(x, 1, 1195) * 4.0)
			if posmod(x * 7 + 3, 11) == 0:
				coupe = maxi(0, coupe - 5)                       # fil qui pend
			if vy < coupe:
				c = Color(0, 0, 0, 0)
			elif vy < coupe + 1:
				c = _c(LAINE_VERTE, 0)
			# neige posee sur le haut (epaules) et prise dans les plis
			elif vy > 108 and GuerrierTextures._n(x, y, W, H, 7, 4, 1196) > 0.74 + float(116 - mini(vy, 116)) * 0.03:
				c = _c(LAINE_VERTE, 5).lerp(Color("#c9d3de"), 0.5)
			_p(img, x, y, c)
	return img

## Plumes d'empennage : u en travers, v de l'avant (0) à l'arrière (31) ; barbes en biais, rachis sombre, bord découpé.
static func _plumes(img: Image) -> void:
	var r := D_PLUME
	for k in 2:
		for y in r.size.y:
			var demi := 6.5 * sin(PI * clampf(float(y) / 30.0, 0.0, 1.0)) + 1.0
			for x in 16:
				var dx := absf(x - 7.5)
				if dx > demi or y > 30:
					continue
				var t := 3 if k == 0 else 2
				if posmod(y + int(dx), 3) == 0:
					t -= 1
				if dx < 1.0:
					t = 1
				if dx > demi - 1.0:
					t = maxi(t - 1, 0)
				img.set_pixel(r.position.x + k * 16 + x, r.position.y + y, _c(PLUME, t))

# ------------------------------------------------------------------ cheveux blonds (mèches Quaternius requantifiées)
static var _tex_q := {}

static func cheveux(src: Texture2D) -> Texture2D:
	var cle_res := "cheveux_blonds"
	if _tex_q.has(cle_res):
		return _tex_q[cle_res]
	var deja := charger(cle_res)
	if deja:
		_tex_q[cle_res] = ImageTexture.create_from_image(deja)
		return _tex_q[cle_res]
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(64, 64, Image.INTERPOLATE_LANCZOS)
	var lmin := 1.0
	var lmax := 0.0
	for y in 64:
		for x in 64:
			var l := img.get_pixel(x, y).get_luminance()
			lmin = minf(lmin, l)
			lmax = maxf(lmax, l)
	for y in 64:
		for x in 64:
			var l := (img.get_pixel(x, y).get_luminance() - lmin) / maxf(0.01, lmax - lmin)
			img.set_pixel(x, y, _c(BLOND, GuerrierTextures._ton(l * 0.85 + 0.15, 6, x, y, 1201, 0.3)))
	var mips := GuerrierTextures.mips_pixel(img)
	sauver(cle_res, mips)
	_tex_q[cle_res] = ImageTexture.create_from_image(mips)
	return _tex_q[cle_res]

static func vider_tout() -> void:
	_cache.clear()
	_tex_q.clear()

# ------------------------------------------------------------------ passe 2 : fourrure chaude, capuche
## Capuche rabattue : cuir usé (u : autour du cou, v : du bord (0) vers la pointe (47)), couture centrale du dos (u milieu),
## piqûres le long du bord ; v 48-63 : doublure de laine sombre (vue par l'ouverture).
static func _capuche(img: Image) -> void:
	var r := R_CAPUCHE
	for y in r.size.y:
		for x in r.size.x:
			var c: Color
			if y >= 48:
				c = _c(LAINE_VERTE, 1 + int(GuerrierTextures._n(x, y, 96, 16, 8, 2, 1211) * 2.0))
			else:
				var l := 0.55 + (GuerrierTextures._n(x, y, 96, 48, 6, 4, 1212) - 0.5) * 0.45 - float(y) / 48.0 * 0.18
				var t := GuerrierTextures._ton(l, 6, x, y, 1213, 0.35)
				if absi(x - 48) == 0:
					t = 0                                       # couture du dos
				elif absi(x - 48) == 1 and y % 3 != 0:
					t = 5
				elif y == 3 and x % 3 != 0:
					t = 5                                       # piqûres du bord
				elif y < 2:
					t = 1
				if GuerrierTextures._h(x, y, 1214) > 0.965:
					t = mini(t + 2, 5)                          # éraflures claires
				c = _c(CUIR_CAPUCHE, t)
			img.set_pixel(r.position.x + x, r.position.y + y, c)

## Touffe pointue (copie de GuerrierTextures._touffe) dans la palette chaude de la chasseresse.
static func _touffe(img: Image, x0: int, y0: int, w: int, h: int, pente: float, clair: int) -> void:
	for k in h:
		var t := float(k) / maxf(1.0, h - 1)
		var demi := w * 0.5 * (1.0 - pow(t, 1.4) * 0.92)
		var cx := x0 + pente * k
		var xa := int(floorf(cx - demi))
		var xb := int(ceilf(cx + demi)) - 1
		for x in range(xa, xb + 1):
			# touffe lisible (passe vetements) : ton plat, UN reflet cote lumiere, bord sombre, pointe claire
			var ton := clair - 1
			if x == xa or (x == xa + 1 and w >= 8 and t < 0.7):
				ton = clair + 1                                     # reflet
			if x == xb or (k == h - 1):
				ton = 2
			elif t < 0.2:
				ton = clair - 2                                     # racine ombree
			if t > 0.88 and GuerrierTextures._h(x, k, 889) > 0.55:
				ton = 5                                             # givre sur la pointe
			_p(img, x, y0 + k, _c(FOUR_CHAUD, ton))

## Fourrure de la mante (même construction que GuerrierTextures.mante, palette chaude).
static func mante() -> Image:
	var W := 256
	var H := 128
	var img := GuerrierTextures._img(W, H, _c(FOUR_CHAUD, 1))
	var rangs := []
	var y := H - 12
	while y > 50:
		rangs.append(y)
		y -= 8
	for r in rangs.size():
		var yr: int = rangs[r]
		var x := int(GuerrierTextures._h(r, 0, 871) * 6.0)
		var i := 0
		while x < W + 6:
			var w := 8 + int(GuerrierTextures._h(i, r, 872) * 4.0)
			var h := 12 + int(GuerrierTextures._h(i, r, 873) * 5.0)
			var clair := 3 + (1 if GuerrierTextures._h(i, r, 874) > 0.45 else 0)
			_touffe(img, x, yr + int(GuerrierTextures._h(i, r, 875) * 3.0) - 1, w, h, (GuerrierTextures._h(i, r, 876) - 0.5) * 0.35, clair)
			x += w - 1
			i += 1
	return img

## Mèches (4 variantes de 16 x 32, palette chaude, pointes claires).
static func meches() -> Image:
	var W := 64
	var H := 32
	var img := GuerrierTextures._img(W, H, Color(0, 0, 0, 0))
	for v in 4:
		var ox := v * 16
		var n := 1 + (v & 1)
		var larg := 16.0 / n
		for i in n:
			var w := int(larg) + 2
			var cx := ox + int(larg * (i + 0.5))
			var h := 22 + int(GuerrierTextures._h(i, v, 881) * 9.0)
			var clair := 3 + (1 if (i + v) % 2 == 0 else 0)
			_touffe(img, cx, 0, mini(w, 16 - 1), mini(h, H), (GuerrierTextures._h(i, v, 882) - 0.5) * 0.25, clair)
		for y in H:
			for x in [ox, ox + 15]:
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, _c(FOUR_CHAUD, 1))
	return img

## Bottes : celles du guerrier (cuir lacé), revers de fourrure chaude.
static func bottes() -> Image:
	var img := GuerrierTextures.bottes()
	var W := img.get_width()
	var H := img.get_height()
	# passe vetements : deux sangles de cuir sombre qui ceinturent la tige (vy 18-21 et 34-37), boucle de fer sur le cote,
	# bande de cuir cousue sous le revers, bout de botte use
	for sv in [18, 34]:
		for k in 4:
			var y0: int = H - 1 - (sv + k)
			for x in W:
				var t := 2 if (k == 0) else (1 if k == 3 else 3)
				if k == 1 and x % 4 < 2:
					t = 4
				_p(img, x, y0, GuerrierTextures._c(GuerrierTextures.CUIR, t))
				if k == 0 or k == 3:
					_p(img, x, y0, GuerrierTextures._c(GuerrierTextures.CUIR, 0 if k == 3 else 2))
		for bx in [10, 74]:
			for yy in 6:
				for xx in 6:
					var edge := yy == 0 or yy == 5 or xx == 0 or xx == 5
					_p(img, bx + xx, H - 1 - (sv - 1 + yy), GuerrierTextures._c(GuerrierTextures.METAL_CLAIR, 4 if edge else 1))
	for y in H:
		var vy := H - 1 - y
		if vy <= 50:
			continue
		for x in W:
			var f := GuerrierTextures._n(x, y, W, H, 32, 4, 844)
			var c := _c(FOUR_CHAUD, 2 + int(f * 3.0) + (1 if vy > 53 else 0))
			if posmod(x * 7 + vy, 5) == 0:
				c = _c(FOUR_CHAUD, 1)
			_p(img, x, y, c)
	return img
