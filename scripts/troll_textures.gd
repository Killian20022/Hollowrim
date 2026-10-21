class_name TrollTextures
## Textures du Troll de givre (TrollGivre), peintes par code dans la famille du Guerrier pilote : palettes FROIDES de 6 à 8 tons,
## contours sombres peints, bruit seulement (jamais de tramage Bayer), mipmaps pixel art (GuerrierTextures.mips_pixel).
##   peau        : atlas du corps Quaternius (T_Superhero_Male_Dark) redessiné en gris bleuté (512², le corps est agrandi x1,5 à x2,6),
##                 poil ras en courts traits, marbrures larges, creux plus sombres ; slip d'origine -> gris sombre (sous le pagne).
##   meches      : 8 variantes de mèches de fourrure (16 x 32, fond transparent) : 3 clartés (blanc givré, gris clair, gris),
##                 racine dans l'ombre, arête éclairée, pointe givrée bleutée.
##   accessoires : griffes et crocs (ivoire jauni -> corne sombre à la racine), gueule, arcade (peau sombre).
##   yeux        : lueur bleue (centre presque blanc), matériau à émission propre.

const PEAU := ["#1c1d23", "#282a32", "#363842", "#444752", "#535763", "#636775", "#747887", "#878a98", "#9b9eaa", "#b1b3bd"]   # gris bleuté (moins violet, plus clair : lisible à l'ombre)   # gris-bleu sombre légèrement violacé (référence)
const FOUR := ["#1c1b19", "#393632", "#5c5853", "#827d76", "#a7a29a", "#c7c3bb", "#e0ddd6", "#f2f0eb"]   # crème / gris chaud, pointes presque neutres (pas « pêche » au couchant)
const GIVRE := Color("#f6f6f3")
const IVOIRE_CROC := ["#3a3630", "#6b655a", "#9a9384", "#c4bdab", "#ddd7c6", "#ece7da", "#f7f4ec"]   # crocs : ivoire neutre (le jaune virait orange au couchant)
const IVOIRE := ["#3a2e22", "#5c4a36", "#806a4e", "#a68f6c", "#c8b38c", "#e0d1ad", "#f2e8cf"]
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
const VERSION := 12
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
## Atlas 1024² (~230 texels/m sur le corps agrandi ; 512² n'en donnait que ~115).
const COTE := 1024
## Géométrie du corps au nouveau repos, fournie par TrollGivre._construire avant la première texture (peinture EN 3D) :
## {"v", "n", "uv", "i" (indices), "four" (PackedByteArray par triangle : 0 nu, 1 fourrure), "rep" (repères : os -> position)}.
static var geo := {}

## Peinture de la peau : chaque triangle du corps est rastérisé dans l'atlas (avec 1,5 texel de marge contre les coutures) ;
## pour chaque texel on connaît sa position 3D et sa normale au repos : le modelé (pectoraux, abdominaux, côtes, nombril, rides
## du front, sillons du museau), les cicatrices et le sous-poil des zones fourrées sont peints dans l'espace du MODÈLE, pas de
## l'atlas. Relief d'origine (T_Superhero) gardé en fond, adouci (le gain x2 de la passe 2 dessinait des traits noirs).
static func peau() -> Image:
	var src := Image.load_from_file(SOURCE_PEAU)
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	src.resize(COTE, COTE, Image.INTERPOLATE_LANCZOS)
	var n := COTE
	var out := Image.create(n, n, false, Image.FORMAT_RGBA8)
	out.fill(_c(PEAU, 4))
	if geo.is_empty():
		push_error("TrollTextures.peau : géométrie absente (TrollGivre._construire doit passer avant)")
		return out
	var lum := PackedFloat32Array()
	lum.resize(n * n)
	var somme := 0.0
	var nb := 0
	for y in n:
		for x in n:
			var l := src.get_pixel(x, y).get_luminance()
			lum[y * n + x] = l
			if l > 0.35 and (x + y) % 3 == 0:
				somme += l
				nb += 1
	var lm := somme / maxi(nb, 1)
	var bruit := FastNoiseLite.new()
	bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bruit.seed = 1331
	bruit.frequency = 9.0
	var bruit2 := FastNoiseLite.new()
	bruit2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bruit2.seed = 1332
	bruit2.frequency = 40.0
	var V: PackedVector3Array = geo["v"]
	var N: PackedVector3Array = geo["n"]
	var UV: PackedVector2Array = geo["uv"]
	var I: PackedInt32Array = geo["i"]
	var F: PackedByteArray = geo["four"]
	var rep: Dictionary = geo["rep"]
	var ctx := _Peintre.new(rep)
	var fait := PackedByteArray()
	fait.resize(n * n)
	for t in range(0, I.size(), 3):
		var a := UV[I[t]] * n
		var b := UV[I[t + 1]] * n
		var c := UV[I[t + 2]] * n
		var aire := (b - a).cross(c - a)
		if absf(aire) < 1e-6:
			continue
		var x0 := maxi(0, int(floorf(minf(a.x, minf(b.x, c.x)) - 2.0)))
		var x1 := mini(n - 1, int(ceilf(maxf(a.x, maxf(b.x, c.x)) + 2.0)))
		var y0 := maxi(0, int(floorf(minf(a.y, minf(b.y, c.y)) - 2.0)))
		var y1 := mini(n - 1, int(ceilf(maxf(a.y, maxf(b.y, c.y)) + 2.0)))
		var la := (c - b).length()
		var lb := (a - c).length()
		var lc := (b - a).length()
		var fourre := F[t / 3] == 1
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var q := Vector2(x + 0.5, y + 0.5)
				var w0 := (c - b).cross(q - b) / aire
				var w1 := (a - c).cross(q - c) / aire
				var w2 := 1.0 - w0 - w1
				# distance (texels) au bord, signée : marge de 1,5 texel hors du triangle
				var dmin := minf(w0 * absf(aire) / maxf(la, 1e-4), minf(w1 * absf(aire) / maxf(lb, 1e-4), w2 * absf(aire) / maxf(lc, 1e-4)))
				var dedans := dmin >= 0.0
				if dmin < -1.5:
					continue
				var k := y * n + x
				if fait[k] == 2 or (fait[k] == 1 and not dedans):
					continue
				w0 = clampf(w0, 0.0, 1.0)
				w1 = clampf(w1, 0.0, 1.0)
				w2 = clampf(w2, 0.0, 1.0)
				var ws := maxf(w0 + w1 + w2, 1e-5)
				var p := (V[I[t]] * w0 + V[I[t + 1]] * w1 + V[I[t + 2]] * w2) / ws
				var nr := (N[I[t]] * w0 + N[I[t + 1]] * w1 + N[I[t + 2]] * w2).normalized()
				# relief d'origine adouci + marbrures 3D
				var tn := 0.60 + clampf(lum[k] / lm - 1.0, -0.5, 0.5) * 0.8
				tn += bruit.get_noise_3dv(p) * 0.13 + bruit2.get_noise_3dv(p) * 0.07   # bosses musculaires + marbrures
				tn += ctx.modele(p, nr)
				var col: Color
				if fourre:
					col = _sous_poil(x, y, tn, p)
				else:
					var ton := clampi(int(floorf(tn * PEAU.size() + (_h(x, y, 1303) - 0.5) * 0.6)), 0, PEAU.size() - 1)
					if _h(x, y, 1305) < 0.06:
						ton = maxi(ton - 2, 0)                   # pores
					col = _c(PEAU, ton)
					var cic := ctx.cicatrice(p)
					if cic > 0.0:
						col = _c(PEAU, clampi(ton + (2 if cic > 0.5 else -1), 0, PEAU.size() - 1))
					var pl := ctx.poil_torse(p, nr)
					if pl > 0.0 and _h(x, y / 3, 1306) < pl:
						col = _c(FOUR, 3 + int(_h(x, y, 1307) * 2.5))   # poils clairsemés du torse (traits verticaux courts)
				out.set_pixel(x, y, col)
				fait[k] = 2 if dedans else 1
	# rides fines (traits courts courbes, plus sombres, liseré clair au-dessus) sur la peau nue seulement
	for kk in 7000:
		var x := int(_h(kk, 0, 1304) * n)
		var y := int(_h(kk, 1, 1304) * n)
		var c0 := out.get_pixel(x, y)
		var i0 := _indice(c0)
		if absf(Color(PEAU[i0]).r - c0.r) > 0.02:
			continue                                         # pas sur le sous-poil ni les poils
		var lg := 3 + int(_h(kk, 2, 1304) * 4.0)
		var courbe := (_h(kk, 3, 1304) - 0.5) * 0.8
		for i in lg:
			var yy := y + int(roundf(courbe * (i - lg * 0.5) * (i - lg * 0.5) / lg))
			_p(out, x + i, yy, _c(PEAU, maxi(i0 - 1, 0)))
			_p(out, x + i, yy - 1, _c(PEAU, mini(i0 + 1, PEAU.size() - 1)))
	return out

## Sous-poil des zones fourrées (visible entre les mèches) : gris chaud sombre en courts brins verticaux, pas de peau bleue.
static func _sous_poil(x: int, y: int, tn: float, p: Vector3) -> Color:
	var brin := _h(x, 0, 1308)                          # colonne = un brin
	var ton := 2 + int(brin * 2.2 + (tn - 0.6) * 3.0 + _h(x, y / 4, 1309) * 0.9)
	return _c(FOUR, clampi(ton, 1, 4))

## Modelé peint du troll dans l'espace du modèle (repères = positions d'os au nouveau repos).
class _Peintre:
	var rep: Dictionary
	var cicatrices := []
	func _init(r: Dictionary) -> void:
		rep = r
		var s3: Vector3 = rep["spine_03"]
		var lp: float = rep["larg_torse"]
		# trois griffures parallèles en travers du pectoral gauche, une longue sur le ventre, une sur chaque bras
		for i in 3:
			var o := Vector3(0.0, 0.03 * i, 0.0)
			cicatrices.append([s3 + Vector3(lp * 0.15, 0.08, 0.2) + o, s3 + Vector3(lp * 0.75, -0.02, 0.2) + o, 0.0045])
		cicatrices.append([s3 + Vector3(-lp * 0.55, -0.12, 0.2), s3 + Vector3(-lp * 0.05, -0.30, 0.2), 0.004])
		var e: Vector3 = rep["upperarm_l"]
		cicatrices.append([e + Vector3(0.10, 0.03, 0.2), e + Vector3(0.26, -0.03, 0.2), 0.004])
		var d: Vector3 = rep["upperarm_r"]
		cicatrices.append([d + Vector3(-0.08, -0.02, 0.2), d + Vector3(-0.22, 0.04, 0.2), 0.004])

	## Ajout de clarté (-0,3..+0,2) : modelé éclairé par le haut (bosses claires dessus, ombres douces dessous).
	func modele(p: Vector3, nr: Vector3) -> float:
		var d := 0.0
		var s1: Vector3 = rep["spine_01"]
		var s2: Vector3 = rep["spine_02"]
		var s3: Vector3 = rep["spine_03"]
		var pv: Vector3 = rep["pelvis"]
		var lp: float = rep["larg_torse"]
		var tete: Vector3 = rep["Head"]
		var ax := absf(p.x)
		# ---- torse, face avant
		if nr.z > 0.15 and p.y > pv.y - 0.02 and p.y < s3.y + 0.19 and ax < lp * 1.05:
			var avant := smoothstep(0.15, 0.45, nr.z)
			# pectoraux : deux masses ; dessus clair, sillon inférieur sombre et DOUX (pas de trait)
			var yp := s3.y + 0.045
			var e := Vector2((ax - lp * 0.45) / (lp * 0.44), (p.y - yp) / 0.095)
			var r := e.length()
			if r < 1.25:
				var bosse := clampf(1.0 - r, 0.0, 1.0)
				d += bosse * 0.18 * clampf(e.y + 0.6, 0.0, 1.0)            # haut des pectoraux éclairé
				d -= smoothstep(0.6, 1.0, r) * smoothstep(1.3, 1.0, r) * 0.26 * clampf(-e.y * 1.4, 0.0, 1.0)   # sillon sous le pectoral (large, doux)
			# sillon du sternum entre les pectoraux
			if p.y > yp - 0.08:
				d -= smoothstep(lp * 0.08, 0.0, ax) * 0.16
			# abdominaux : ligne blanche + 3 rangées de blocs, chaque bloc clair en haut, sombre en bas
			var y_haut := yp - 0.105
			var y_bas := pv.y + 0.06
			if p.y < y_haut and p.y > y_bas and ax < lp * 0.42:
				var u := (y_haut - p.y) / (y_haut - y_bas) * 3.4
				var f := u - floorf(u)
				var bord_x := smoothstep(lp * 0.42, lp * 0.30, ax)
				d += (0.11 - f * 0.22) * bord_x
				d -= smoothstep(0.016, 0.0, ax) * 0.2                # ligne blanche
				d -= smoothstep(0.12, 0.0, f) * 0.08 * bord_x
			# obliques en V vers le pubis
			var v_l := absf((ax - lp * 0.42) - (p.y - y_bas) * 0.9)
			if p.y < y_haut and p.y > pv.y - 0.03 and ax > lp * 0.25:
				d -= smoothstep(0.035, 0.0, v_l) * 0.16
			# côtes et dentelés sur les flancs : sillons obliques
			if ax > lp * 0.55 and p.y > s1.y and p.y < s3.y + 0.02:
				var ph := (p.y + ax * 0.55) / 0.052
				d -= smoothstep(0.55, 1.0, sin(ph * TAU) * 0.5 + 0.5) * 0.15 * smoothstep(lp * 0.55, lp * 0.75, ax)
			# nombril
			var nb := Vector2(p.x / 0.016, (p.y - (pv.y + 0.13)) / 0.012).length()
			d -= smoothstep(1.0, 0.4, nb) * 0.22
			d *= avant
		# ---- tête : rides du front, rides du nez, sillons du museau
		var q := p - tete
		var oy: float = rep["yeux_y"] - tete.y
		var k: float = rep["tete_k"]
		if nr.z > 0.2 and absf(q.x) < 0.10 * k:
			var fy := (q.y - oy) / k
			if fy > 0.045 and fy < 0.10:
				var onde := sin((fy - 0.045) / 0.017 * TAU + q.x * 40.0) * 0.5 + 0.5
				d -= smoothstep(0.55, 1.0, onde) * 0.28
				d += smoothstep(0.55, 1.0, 1.0 - onde) * 0.08
			if fy > 0.012 and fy < 0.06 and absf(q.x) < 0.012 * k:
				d -= 0.22                                            # plis verticaux entre les sourcils
			# sillons naso-labiaux (du nez aux coins de la gueule)
			var sl := absf(absf(q.x) / k - 0.03 - (oy - q.y) / k * 0.35)
			if fy < -0.02 and fy > -0.08:
				d -= smoothstep(0.008, 0.0, sl) * 0.24
		return d

	func cicatrice(p: Vector3) -> float:
		for c: Array in cicatrices:
			var a: Vector3 = c[0]
			var b: Vector3 = c[1]
			# distance dans le plan de face (x, y) : les cicatrices sont projetées sur le torse
			var ab := Vector2(b.x - a.x, b.y - a.y)
			var ap := Vector2(p.x - a.x, p.y - a.y)
			var t := clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
			if p.z < a.z - 0.35:
				continue
			var dd := (ap - ab * t).length()
			var r: float = c[2] * (1.0 - absf(t - 0.5) * 0.9)
			if dd < r:
				return 1.0
			if dd < r + 0.004:
				return 0.3
		return 0.0

	## Densité de poils peints sur le torse nu (sternum surtout).
	func poil_torse(p: Vector3, nr: Vector3) -> float:
		var s3: Vector3 = rep["spine_03"]
		if nr.z < 0.2 or p.y < s3.y - 0.25 or p.y > s3.y + 0.2:
			return 0.0
		return smoothstep(0.06, 0.0, absf(p.x)) * 0.12

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
## Une carte = une TOUFFE (32 x 64 texels) : 6 à 9 brins partent de toute la largeur de la racine et CONVERGENT vers une ou
## deux pointes, en se recourbant tous du même côté ; brin effilé (largeur 3 -> 1), racine sombre (sous-poil), milieu crème,
## pointe claire givrée. Pas de liseré noir (damier de plaques à 1 m).
const MW := 32
const MH := 64
static func _brin(img: Image, cel: int, xr: float, xt: float, h: int, courbe: float, w0: float, clair: int, givre: float, g: int) -> void:
	for k in h:
		var t := float(k) / maxf(1.0, h - 1)
		var cx := lerpf(xr, xt, smoothstep(0.35, 1.0, t)) + courbe * t * t
		var demi := w0 * 0.5 * (1.0 - pow(t, 2.0) * 0.55)
		var xa := maxi(int(floorf(cx - demi)), cel)
		var xb := mini(int(ceilf(cx + demi)) - 1, cel + MW - 1)
		for x in range(xa, xb + 1):
			var ton := clair - 2 + int(t * 2.4 + _h(x, k, g) * 0.8)
			if x == xa and xb > xa:
				ton += 1                                 # arête éclairée
			elif x == xb and xb > xa + 1:
				ton -= 1
			var col := _c(FOUR, mini(ton, clair + 1))
			if t > 0.75 and ton >= clair:
				col = col.lerp(_c(FOUR, clair), 0.5)    # pointe mate : pas plus claire que le corps de la touffe
			if t > 0.8 and _h(x, k, g + 1) < givre:
				col = GIVRE
			_p(img, x, k, col)

## 8 touffes : 0-2 dessus clair givré (crinière, barbe, bras), 3-5 crème grise, 6-7 sous-poil gris chaud plus sombre.
static func meches() -> Image:
	var img := Image.create(MW * 8, MH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for v in 8:
		var cel := v * MW
		var clair := 4 if v < 6 else 3       # crème / gris chaud ; plus de « glaçons » blancs
		var givre := 0.06 if v < 3 else (0.02 if v < 6 else 0.0)
		var courbe := (4.0 + _h(v, 1, 1317) * 5.0) * (1.0 if v % 2 == 0 else -1.0)
		# deux pointes (touffe fendue) pour la moitié des variantes
		var pointes := [cel + 16.0 + courbe * -0.3] if v % 3 != 1 else [cel + 11.0, cel + 21.0]
		# masse sombre courte à la racine : bouche les trous entre les brins
		var nbm := 7
		for i in nbm:
			var xr := cel + 3.0 + 26.0 * (i + 0.5) / nbm
			_brin(img, cel, xr, lerpf(xr, cel + 16.0, 0.45), 32 + int(_h(i, v, 1318) * 14.0), courbe * 0.4, 5.5, clair - 1, 0.0, 1319 + v * 13 + i)
		var nb := 6 + v % 4
		for i in nb:
			var xr := cel + 2.5 + 27.0 * (i + 0.5) / nb + (_h(i, v, 1316) - 0.5) * 2.0
			var xt: float = pointes[0] if pointes.size() == 1 or xr < cel + 16.0 else pointes[1]
			xt += (_h(i, v, 1320) - 0.5) * 3.0
			var centre := 1.0 - absf(xr - (cel + 16.0)) / 16.0
			var h := int(MH * (0.55 + 0.45 * centre) * (0.85 + _h(i, v, 1313) * 0.15))
			var ton := clair if (i + v) % 3 != 0 else clair - 1
			_brin(img, cel, xr, xt, mini(h, MH), courbe * (0.7 + _h(i, v, 1314) * 0.6), 4.0 + _h(i, v, 1321) * 1.6, ton, givre, 1315 + v * 7 + i)
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
				var base := 1.0 + t * 4.2 if not croc else 4.2 + t * 2.0
				var ton := int(base + (_h(x, y, 1321) - 0.5) * 0.8)
				if x == 0 or x == 1:
					ton += 1
				if x >= r.size.x - 2:
					ton -= 2
				if not croc and y < 3:
					ton = 0
				img.set_pixel(r.position.x + x, r.position.y + y, _c(IVOIRE_CROC if croc else IVOIRE, ton))
	for y in R_GUEULE.size.y:
		for x in R_GUEULE.size.x:
			var dy := absf(y - 7.5) / 7.5
			var ton := 3 - int(dy * 3.2 + _h(x, y, 1322) * 0.6)
			img.set_pixel(R_GUEULE.position.x + x, R_GUEULE.position.y + y, _c(GUEULE, ton))
	for y in R_ARCADE.size.y:
		for x in R_ARCADE.size.x:
			var t := 0.46 + float(R_ARCADE.size.y - y) / R_ARCADE.size.y * 0.14 + (_h(x, y, 1323) - 0.5) * 0.12   # même peau que le front (pas de « visière »)
			var ton := clampi(int(t * PEAU.size()), 0, PEAU.size() - 1)
			if y >= R_ARCADE.size.y - 2:
				ton = 3                                  # dessous de l'arcade : ombre (pas un trait noir de « visière »)
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
