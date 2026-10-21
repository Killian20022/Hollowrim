class_name TrollTextures
## Textures du Troll de givre (TrollGivre), peintes par code dans la famille du Guerrier pilote : palettes FROIDES de 6 à 8 tons,
## contours sombres peints, bruit seulement (jamais de tramage Bayer), mipmaps pixel art (GuerrierTextures.mips_pixel).
##   peau        : atlas du corps Quaternius (T_Superhero_Male_Dark) redessiné en gris bleuté (512², le corps est agrandi x1,5 à x2,6),
##                 poil ras en courts traits, marbrures larges, creux plus sombres ; slip d'origine -> gris sombre (sous le pagne).
##   meches      : 8 variantes de mèches de fourrure (16 x 32, fond transparent) : 3 clartés (blanc givré, gris clair, gris),
##                 racine dans l'ombre, arête éclairée, pointe givrée bleutée.
##   accessoires : griffes et crocs (ivoire jauni -> corne sombre à la racine), gueule, arcade (peau sombre).
##   yeux        : lueur bleue (centre presque blanc), matériau à émission propre.

const PEAU := ["#161a22", "#222731", "#2f3541", "#3d4451", "#4c5462", "#5c6573", "#6d7684", "#7f8895", "#939ba7"]
const FOUR := ["#14171d", "#2a2f39", "#464c58", "#666d79", "#8a919c", "#adb3bd", "#cbd0d7", "#e3e7ec"]
const GIVRE := Color("#e8f0fa")
const IVOIRE := ["#2a241c", "#4a3f2f", "#6f6046", "#988561", "#bba77f", "#d6c7a2", "#ebe1c6"]
const GUEULE := ["#0e0708", "#1e0c0e", "#341418", "#4c1e22"]
const SOURCE_PEAU := "res://assets/modeles/humains/T_Superhero_Male_Dark.png"

static var _cache := {}

static func _c(pal: Array, i: int) -> Color:
	return Color(pal[clampi(i, 0, pal.size() - 1)])

static func _h(x: int, y: int, g: int) -> float:
	return ObjetsTextures._h(x, y, g)

static func _n(x: int, y: int, w: int, h: int, cx: int, cy: int, g: int) -> float:
	return ObjetsTextures._vn(float(x) / w * cx, float(y) / h * cy, cx, cy, g)

static func _p(img: Image, x: int, y: int, c: Color) -> void:
	img.set_pixel(posmod(x, img.get_width()), posmod(y, img.get_height()), c)

# ------------------------------------------------------------------ précalcul (outils/generer_troll.gd)
const DOSSIER := "res://assets/personnages/troll"
const VERSION := 2
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
				"peau": img = peau()
				"meches": img = meches()
				"accessoires": img = accessoires()
				"yeux": img = yeux()
				_: push_error("TrollTextures : texture inconnue " + nom)
			mips = GuerrierTextures.mips_pixel(img)
			sauver(nom, mips)
		_cache[nom] = ImageTexture.create_from_image(mips)
	return _cache[nom]

static func vider() -> void:
	_cache.clear()

# ------------------------------------------------------------------ peau (atlas du corps)
const COTE := 512

static func peau() -> Image:
	var img := Image.load_from_file(SOURCE_PEAU)
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(COTE, COTE, Image.INTERPOLATE_LANCZOS)
	var n := COTE
	var somme := 0.0
	var nb := 0
	for y in range(0, n, 2):
		for x in range(0, n, 2):
			var l := img.get_pixel(x, y).get_luminance()
			if l > 0.35:
				somme += l
				nb += 1
	var lm := somme / maxi(nb, 1)
	var out := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			if l < 0.2 or (l < 0.34 and c.b > c.r):      # slip d'origine et sa ceinture (bleu sombre)
				out.set_pixel(x, y, _c(PEAU, 3 + int(_h(x, y, 1300) * 1.6)))   # slip d'origine : peau moyenne (sous le pagne)
				continue
			# relief d'origine (muscles, creux) renforcé, marbrures larges, grain
			var t := 0.50 + (l / lm - 1.0) * 1.15
			t += (_n(x, y, n, n, 12, 12, 1301) - 0.5) * 0.16
			t += (_n(x, y, n, n, 48, 48, 1302) - 0.5) * 0.08
			# lèvres et joues (chroma rouge d'origine) : plus sombres, bleu-violet
			var rouge := c.r - (c.g + c.b) * 0.5
			if rouge > 0.16:
				t -= 0.14
			var ton := clampi(int(floorf(t * PEAU.size() + (_h(x, y, 1303) - 0.5) * 0.5)), 0, PEAU.size() - 1)
			out.set_pixel(x, y, _c(PEAU, ton))
	# poil ras : courts traits verticaux, un ton plus clair, liseré d'un ton plus sombre dessous (jamais de damier)
	for k in 9000:
		var x := int(_h(k, 0, 1304) * n)
		var y := int(_h(k, 1, 1304) * n)
		var c0 := out.get_pixel(x, y)
		var i0 := _indice(c0)
		var lg := 2 + int(_h(k, 2, 1304) * 3.0)
		var sx := 1 if _h(k, 3, 1304) > 0.5 else 0
		for i in lg:
			_p(out, x + (i / 2) * sx, y + i, _c(PEAU, mini(i0 + 1, PEAU.size() - 1)))
		_p(out, x + (lg / 2) * sx, y + lg, _c(PEAU, maxi(i0 - 1, 0)))
	return out

static func _indice(c: Color) -> int:
	var best := 0
	var bd := 9.0
	for i in PEAU.size():
		var p := Color(PEAU[i])
		var d := absf(p.r - c.r) + absf(p.g - c.g) + absf(p.b - c.b)
		if d < bd:
			bd = d
			best = i
	return best

# ------------------------------------------------------------------ mèches (cartes découpées)
## Touffe pointue de w texels, de h texels de long, pente en texels par rangée, clarté de base `clair` (index FOUR).
static func _touffe(img: Image, x0: float, y0: int, w: int, h: int, pente: float, clair: int, givre: float, g: int) -> void:
	for k in h:
		var t := float(k) / maxf(1.0, h - 1)
		var demi := w * 0.5 * (1.0 - pow(t, 1.3) * 0.94)
		var cx := x0 + pente * k
		var xa := int(floorf(cx - demi))
		var xb := int(ceilf(cx + demi)) - 1
		for x in range(xa, xb + 1):
			var ton := clair - 1 + int(t * 2.0)
			if t < 0.2:
				ton = clair - 2                          # racine dans l'ombre des touffes du dessus
			if x == xa:
				ton = clair + 1 if t > 0.15 else clair   # arête éclairée
			var col := _c(FOUR, ton)
			if x == xb or k == h - 1:
				col = _c(FOUR, 1)                        # liseré sombre
			elif x == int(roundf(cx + demi * 0.2)) and t > 0.25 and t < 0.85:
				col = _c(FOUR, clair - 2)                # fente entre deux brins
			elif t > 0.72 and _h(x, k, g) < givre:
				col = GIVRE                              # pointe givrée
			_p(img, x, y0 + k, col)

## 8 variantes de 16 x 32 : 0-2 blanc givré (mane, barbe), 3-5 gris clair, 6-7 gris (racines, membres).
static func meches() -> Image:
	var W := 128
	var H := 32
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for v in 8:
		var ox := v * 16
		var clair := 6 if v < 3 else (5 if v < 6 else 4)
		var givre := 0.45 if v < 3 else (0.25 if v < 6 else 0.1)
		var n := 2 + (v % 2)
		var larg := 16.0 / n
		# touffe arrière (plus sombre) puis touffes de devant
		_touffe(img, ox + 8.0 + (_h(v, 9, 1311) - 0.5) * 3.0, 0, 9, 24 + int(_h(v, 8, 1311) * 6.0), (_h(v, 7, 1311) - 0.5) * 0.2, clair - 1, givre * 0.5, 1312 + v)
		for i in n:
			var cx := ox + larg * (i + 0.5)
			var h := 20 + int(_h(i, v, 1313) * 12.0)
			_touffe(img, cx, 0, int(larg) + 2, mini(h, H), (_h(i, v, 1314) - 0.5) * 0.3, clair if (i + v) % 2 == 0 else clair - 1, givre, 1315 + v * 7 + i)
		for y in H:
			for x in [ox, ox + 15]:
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, _c(FOUR, 1))
	return img

# ------------------------------------------------------------------ accessoires (32 x 32)
const R_GRIFFE := Rect2i(0, 0, 8, 32)
const R_CROC := Rect2i(8, 0, 8, 32)
const R_GUEULE := Rect2i(16, 0, 16, 16)
const R_ARCADE := Rect2i(16, 16, 16, 16)
const ATLAS := Vector2i(32, 32)

static func accessoires() -> Image:
	var img := Image.create(ATLAS.x, ATLAS.y, false, Image.FORMAT_RGBA8)
	# griffe : v = 0 racine (corne sombre) -> v = 1 pointe (ivoire clair) ; arête claire à gauche, sombre à droite
	for r: Rect2i in [R_GRIFFE, R_CROC]:
		var croc := r == R_CROC
		for y in r.size.y:
			var t := float(y) / (r.size.y - 1)
			for x in r.size.x:
				var base := 1.0 + t * 4.2 if not croc else 3.0 + t * 2.8
				var ton := int(base + (_h(x, y, 1321) - 0.5) * 0.8)
				if x == 0 or x == 1:
					ton += 1
				if x >= r.size.x - 2:
					ton -= 2
				if not croc and y < 3:
					ton = 0
				img.set_pixel(r.position.x + x, r.position.y + y, _c(IVOIRE, ton))
	for y in R_GUEULE.size.y:
		for x in R_GUEULE.size.x:
			var dy := absf(y - 7.5) / 7.5
			var ton := 3 - int(dy * 3.2 + _h(x, y, 1322) * 0.6)
			img.set_pixel(R_GUEULE.position.x + x, R_GUEULE.position.y + y, _c(GUEULE, ton))
	for y in R_ARCADE.size.y:
		for x in R_ARCADE.size.x:
			var t := 0.35 + float(R_ARCADE.size.y - y) / R_ARCADE.size.y * 0.3 + (_h(x, y, 1323) - 0.5) * 0.12
			var ton := clampi(int(t * PEAU.size()), 0, PEAU.size() - 1)
			if y >= R_ARCADE.size.y - 2:
				ton = 1                                  # dessous de l'arcade : ombre
			img.set_pixel(R_ARCADE.position.x + x, R_ARCADE.position.y + y, _c(PEAU, ton))
	return img

## Lueur des yeux (8 x 8) : centre presque blanc, iris bleu glacier, bord sombre.
static func yeux() -> Image:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var d := Vector2((x - 3.5) / 3.5, (y - 3.5) / 2.6).length()
			var c := Color("#123058")
			if d < 0.45:
				c = Color("#e4f6ff")
			elif d < 0.8:
				c = Color("#62c0f4")
			elif d < 1.05:
				c = Color("#2a6cb0")
			img.set_pixel(x, y, c)
	return img
