class_name ChasseresseTextures
## Textures de la Chasseresse nordique (ChasseresseNordique), même méthode que GuerrierTextures (128 texels/m, palettes froides
## de 4 à 7 tons, contours et rehauts peints, bruit sans tramage Bayer, mipmaps pixel art) ; les outils et les matières
## communes (fourrure, bottes, fer, anneau, baudrier, ceinture) sont APPELÉS dans GuerrierTextures (même famille).
## Référence : Image ChatGPT 21 oct. 2026, 14_01_57-2.png (chasseresse blonde, cape vert-bleu sombre, jaque de cuir à écailles,
## col de fourrure, pantalon olive, bottes lacées, arc long, carquois).


# palettes (sombre -> clair)
## jaque de cuir à écailles : brun-gris (pas de bleu : la maille du guerrier virait trop bleu au crépuscule)
const CUIR_E := ["#141009", "#261e17", "#3a2f25", "#504234", "#685745", "#82705a", "#9c8a70"]
## cape : laine vert-bleu sombre (référence : sarcelle sombre)
const LAINE_VERTE := ["#0b1315", "#122125", "#1a3035", "#234046", "#2e5259", "#3f666c"]
## tabard : sarcelle plus clair, liseré crème
const TABARD := ["#13252a", "#1e353b", "#2a474e", "#385a61", "#4b6e73"]
const LAINE_OLIVE := ["#121410", "#1c1f17", "#282c20", "#353a2a", "#444a36", "#555b43"]
const BLOND := ["#2c2213", "#4a3a21", "#6b5631", "#8d7544", "#ae955b", "#cbb377"]
const PLUME := ["#2a2824", "#59544b", "#8f887a", "#bdb5a3", "#ddd6c4"]
## arc : bois d'if brun-roux (âme claire, dos sombre)
const BOIS_ARC := ["#1c120b", "#2f1f13", "#45301d", "#5c4229", "#765637", "#8f6c48"]

static var _cache := {}

# ------------------------------------------------------------------ précalcul (comme GuerrierTextures)
const DOSSIER := "res://assets/persos/chasseresse"
const VERSION := 1
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
				# écailles : rang de 4 texels, décalé de 2-3 texels un rang sur deux
				var rang := y / 4
				var cx := posmod(x + (rang & 1) * 3, 5)
				var cy := y % 4
				var t := 3
				if cy == 3:
					t = 1                                       # ombre sous l'écaille
				elif cy == 0 and (cx == 1 or cx == 2):
					t = 5                                       # dessus frotté
				elif cx == 0 or cx == 4:
					t = 2 if cy > 0 else 1                      # bords arrondis
				elif cy == 2 and cx == 3:
					t = 2
				t += int(roundf((GuerrierTextures._n(x, y, W, H, 10, 4, 1101) - 0.5) * 2.0))
				if GuerrierTextures._h(x, y, 1102) > 0.95:
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
				c = GuerrierTextures._c(GuerrierTextures.FOUR, tf)
			elif y >= yj and vy == bande:
				c = GuerrierTextures._c(GuerrierTextures.CUIR, 0)
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

static func accessoires() -> Image:
	var img := GuerrierTextures._img(GuerrierTextures.ATLAS.x, GuerrierTextures.ATLAS.y, GuerrierTextures._c(GuerrierTextures.FER, 2))
	GuerrierTextures._fer(img, GuerrierTextures.R_FER)
	GuerrierTextures._lame(img)
	GuerrierTextures._poignee(img)
	GuerrierTextures._baudrier(img)
	GuerrierTextures._anneau(img)
	GuerrierTextures._bosse(img)
	GuerrierTextures._ceinture_atlas(img)
	_oeil(img)
	_tresse(img)
	_arc(img)
	_corde(img)
	_carquois(img)
	_fut(img)
	_fourreau(img)
	return img

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
			var t := 4 if d < 2 else 2
			if d == 0:
				t = 5
			if x == 0 or x == 15:
				t = 1
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
			var t := GuerrierTextures._ton_cuir(x, y, r.size.x, r.size.y, 0.52, 1161)
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
	var m := GuerrierTextures.meches()
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
			# frise tissée (8 à 15 texels) : bande sombre, motif en grecque ocre délavé
			if vy >= 8 and vy <= 15:
				c = _c(LAINE_VERTE, 1)
				var m := posmod(x, 8)
				if (vy == 9 or vy == 14) or ((vy >= 10 and vy <= 13) and (m == 0 or (m < 4 and vy == 11))):
					c = GuerrierTextures._c(GuerrierTextures.CUIR, 4).lerp(_c(LAINE_VERTE, 2), 0.35)
			var coupe := int(GuerrierTextures._h(x / 2, 0, 1194) * 5.0) + int(GuerrierTextures._h(x, 1, 1195) * 3.0)
			if vy < coupe:
				c = Color(0, 0, 0, 0)
			elif vy < coupe + 1:
				c = _c(LAINE_VERTE, 0)
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
