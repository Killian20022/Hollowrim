class_name GuerrierTextures
## Textures du Guerrier nordique pilote (GuerrierNordique), peintes par code à 128 texels/m (2 x la densité des vêtements
## du lot 4, mêmes UV métriques : u = 2 m par unité, v = 1 m, BAS de l'image = ourlet), dans des palettes FROIDES et désaturées
## de 4 à 6 tons par matière (référence persos_b : mailles gris-bleu, cuir brun à rivets, fourrure blanc cassé, bois veiné,
## fer), avec contours sombres et rehauts d'arête peints. Jamais de tramage Bayer : bruit seulement.
## Chaque texture reçoit des mipmaps « pixel art » (vote de couleur 2x2, comme les arbres) : texels nets de près,
## pas de moiré ni de grouillement à 4-8 m.

# palettes (sombre -> clair)
const MAILLE := ["#14171e", "#252a35", "#3b4250", "#56606f", "#7c8696", "#b0b8c4"]
const CUIR := ["#1a130e", "#2f2118", "#463325", "#614a34", "#7f6446", "#9e825e", "#b89d76"]   # 6 = arête usée, couture
## cuir clair et chaud (baudrier, ceinture) : se détache du plastron et de la maille sous la lumière froide
const CUIR_CLAIR := ["#24170e", "#4e3320", "#74502f", "#956b43", "#b38858", "#cca46f", "#dcbb88"]
## métal clair (boucle, fibule) : gris chaud poli, reste clair sous la lumière froide du crépuscule
const METAL_CLAIR := ["#2a2723", "#4a453f", "#6f685f", "#948c80", "#b7afa2", "#d4cdc0", "#ece7dc"]
const CUIR_SOMBRE := ["#100c0b", "#1d1613", "#2c221c", "#3f3228", "#544537"]
const FOUR := ["#1d1b19", "#38342f", "#575049", "#787066", "#9a9083", "#bab0a0"]   # gris-brun (référence), moins blanc
const LAINE_BLEUE := ["#0f1422", "#1a2439", "#283855", "#384d74", "#4c6490", "#687fa8"]
const LAINE_GRISE := ["#17171c", "#25252b", "#35343a", "#47454a", "#5b585b"]
const BANDE := ["#2c2a29", "#423e3a", "#57524b", "#6d675d"]   # bandes molletières (laine écrue)
const BOIS := ["#16110d", "#271e17", "#3a2d22", "#4f3f30", "#665341", "#7f6a54"]
## bois du bouclier : brun-gris usé, délavé par la neige (sombre -> clair)
const BOIS_GRIS := ["#1b1714", "#2f2822", "#443a31", "#5a4e42", "#716353", "#8a7b68", "#a39480"]
const PEINT_DELAVE := ["#77736a", "#959083", "#b2ac9c", "#cbc4b1"]
const PEINT_BLEU := ["#141b2b", "#1f2b44", "#2c3d5e", "#3e5276", "#566c90"]
const PEINT_CREME := ["#5c5546", "#807864", "#a39a84", "#c4bba3"]
const FER := ["#0d0e12", "#1b1d23", "#2e313a", "#474b56", "#6c717d", "#9da2ac", "#c9ccd2"]
const ROUILLE := ["#24150e", "#3d2416", "#5a3820"]
## barbe : teinte des cheveux, plus rousse et plus sombre
const BARBE := ["#1f150e", "#3a2618", "#573a24", "#764f30", "#946a40", "#b0855a"]
const CHEVEUX := ["#211b15", "#3a3024", "#574836", "#76644a", "#9a8666"]   # passe 2 : un demi-ton plus clair (la tête se détache à 8 m)

static var _cache := {}

# ------------------------------------------------------------------ outils
static func _c(pal: Array, i: int) -> Color:
	return Color(pal[clampi(i, 0, pal.size() - 1)])

static func _h(x: int, y: int, g: int) -> float:
	return ObjetsTextures._h(x, y, g)

## bruit de valeurs périodique (w x h pixels, cx x cy cellules)
static func _n(x: int, y: int, w: int, h: int, cx: int, cy: int, g: int) -> float:
	return ObjetsTextures._vn(float(x) / w * cx, float(y) / h * cy, cx, cy, g)

static func _p(img: Image, x: int, y: int, c: Color) -> void:
	img.set_pixel(posmod(x, img.get_width()), posmod(y, img.get_height()), c)

## ton entier depuis une luminance 0..1, avec un seuil bruité (jamais de damier)
static func _ton(l: float, n: int, x: int, y: int, g: int, jit := 0.3) -> int:
	var v := l * n + (_h(x, y, g) - 0.5) * jit
	return clampi(int(floorf(v)), 0, n - 1)

## Mipmaps pixel art : chaque niveau garde la couleur majoritaire de 4 texels (égalité : la plus sombre, les contours survivent) ;
## transparence si moins de 2 texels opaques (les découpes restent nettes).
static func mips_pixel(img: Image) -> Image:
	var niveaux: Array[Image] = [img]
	var cur := img
	while cur.get_width() > 1 or cur.get_height() > 1:
		var w := maxi(1, cur.get_width() / 2)
		var h := maxi(1, cur.get_height() / 2)
		var nxt := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var cnt := {}
				var opaques := 0
				for dd: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var c := cur.get_pixel(mini(x * 2 + dd.x, cur.get_width() - 1), mini(y * 2 + dd.y, cur.get_height() - 1))
					if c.a > 0.5:
						opaques += 1
						cnt[c] = int(cnt.get(c, 0)) + 1
				if opaques >= 2:
					var best := Color.BLACK
					var bn := 0
					for k: Color in cnt:
						if cnt[k] > bn or (cnt[k] == bn and k.get_luminance() < best.get_luminance()):
							bn = cnt[k]
							best = k
					best.a = 1.0
					nxt.set_pixel(x, y, best)
				else:
					nxt.set_pixel(x, y, Color(0, 0, 0, 0))
		niveaux.append(nxt)
		cur = nxt
	var data := PackedByteArray()
	for n in niveaux:
		data.append_array(n.get_data())
	return Image.create_from_data(img.get_width(), img.get_height(), true, Image.FORMAT_RGBA8, data)

## Précalcul (outils/generer_guerrier.gd) : images mipmappées dans DOSSIER/<clé>.res ; VERSION à incrémenter après toute
## modification d'un dessin (un .res d'une autre version est ignoré : recalcul au lancement, jamais d'image fausse).
const DOSSIER := "res://assets/personnages/guerrier"
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

static func tex(nom: String, args := []) -> ImageTexture:
	var cle := nom
	for a in args:
		cle += "_%s" % str(a)
	if not _cache.has(cle):
		var mips := charger(cle)
		if mips == null:
			var img: Image
			match nom:
				"mailles": img = mailles()
				"plastron": img = plastron(args[0], args[1])
				"pantalon": img = pantalon()
				"bottes": img = bottes()
				"ceinture": img = ceinture()
				"brassards": img = brassards()
				"mante": img = mante()
				"meches": img = meches()
				"cape": img = cape()
				"cheveux": img = cheveux()
				"accessoires": img = accessoires()
				"decoupes": img = decoupes()
				"barbe": img = barbe()
				_: push_error("GuerrierTextures : texture inconnue " + nom)
			mips = mips_pixel(img)
			sauver(cle, mips)
		_cache[cle] = ImageTexture.create_from_image(mips)
	return _cache[cle]

static func vider() -> void:
	_cache.clear()

static func _img(w: int, h: int, fond := Color.BLACK) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fond)
	return img

## Rivet : tête claire (1 texel, rehaut en haut à gauche) et ombre portée dessous.
static func _rivet(img: Image, x: int, y: int) -> void:
	_p(img, x, y, _c(FER, 5))
	_p(img, x + 1, y, _c(FER, 3))
	_p(img, x, y + 1, _c(FER, 2))
	_p(img, x + 1, y + 1, _c(CUIR, 0))


## Ton de cuir usé (index CUIR) : grain, plaques frottées plus claires, crasse dans les creux (jamais de damier).
static func _ton_cuir(x: int, y: int, W: int, H: int, base: float, g: int) -> int:
	var l := base + (_n(x, y, W, H, 10, 6, g) - 0.5) * 0.35 + (_n(x, y, W, H, 40, 20, g + 1) - 0.5) * 0.12
	var t := _ton(l, 5, x, y, g + 2, 0.35) + 1
	if _n(x, y, W, H, 7, 5, g + 3) > 0.66:
		t += 1                                  # frottement
	if _n(x, y, W, H, 18, 9, g + 4) < 0.22:
		t -= 1                                  # crasse
	return clampi(t, 1, 5)

## Éraflures : courts traits clairs en diagonale, liseré sombre dessous.
static func _eraflures(img: Image, r: Rect2i, nombre: int, g: int) -> void:
	for k in nombre:
		var x := r.position.x + int(_h(k, 0, g) * r.size.x)
		var y := r.position.y + int(_h(k, 1, g) * r.size.y)
		var lg := 3 + int(_h(k, 2, g) * 4.0)
		var sx := 1 if _h(k, 3, g) > 0.5 else -1
		for i in lg:
			var yy := y + i / 2
			if yy >= r.end.y:
				break
			_p(img, x + i * sx, yy, _c(CUIR, 5))
			_p(img, x + i * sx, yy + 1, _c(CUIR, 1))

## Image d'origine recopiée dans une région d'atlas (décalage en texels, u bouclé).
static func _copier(dst: Image, r: Rect2i, src: Image, ox: int, oy: int) -> void:
	for y in r.size.y:
		for x in r.size.x:
			dst.set_pixel(r.position.x + x, r.position.y + y, src.get_pixel(posmod(x + ox, src.get_width()), clampi(y + oy, 0, src.get_height() - 1)))

# ------------------------------------------------------------------ cotte de mailles (UV de la tunique, 256 x 128)
## Anneaux en quinconce de 4 x 3 texels (3 cm) : dessus éclairé, trou sombre, dessous ombré ; plis larges, crasse vers l'ourlet,
## quelques taches de rouille ternies ; ourlet de cuir cousu (poignets et bas de la jupe : v = 1).
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
			# plis (cellules allongées en hauteur) et usure
			var pli := _n(x, y, W, H, 12, 3, 811)
			t += int(roundf((pli - 0.5) * 2.4))
			if _h(x, y, 812) > 0.93:
				t -= 1
			# crasse vers l'ourlet
			if vy < 18 and _h(x, y, 813) < (18 - vy) / 30.0:
				t -= 1
			var c := _c(MAILLE, t)
			if t > 0 and _n(x, y, W, H, 16, 8, 814) > 0.74 and _h(x, y, 815) > 0.35:
				c = _c(ROUILLE, clampi(t / 2, 0, 2)).lerp(c, 0.55)
			_p(img, x, y, c)
	# ourlet de cuir : 5 rangées, bord sombre, piqûre claire
	for x in W:
		for k in 5:
			var t := 2 + (1 if k == 3 else 0) - (2 if k == 0 else 0)
			_p(img, x, H - 1 - k, _c(CUIR, t))
		if x % 4 < 2:
			_p(img, x, H - 3, _c(CUIR, 5))
		_p(img, x, H - 6, _c(MAILLE, 0))
	return img

# ------------------------------------------------------------------ plastron de cuir (mêmes UV que la tunique)
## v0, v1 : bornes en v de la pièce (bandes de bord rivées), u = 0 devant.
## Panneaux cousus (coutures verticales devant et sur les flancs), cuir épais usé (zones claires frottées), bandes de bord
## sombres à rivets, ombre portée sous la bande du haut.
static func plastron(v0: float, v1: float) -> Image:
	var W := 256
	var H := 128
	var img := _img(W, H)
	var y0 := int(v0 * H)
	var y1 := int(v1 * H)
	for y in H:
		for x in W:
			_p(img, x, y, _c(CUIR, _ton_cuir(x, y, W, H, 0.50, 821)))
	_eraflures(img, Rect2i(0, y0 + 5, W, maxi(1, y1 - y0 - 10)), 70, 826)
	# coutures verticales : devant (u = 0 -> x = 0), flancs (u = +-0.12 -> x = +-31), dos (x = 128)
	for xs: int in [0, 31, W - 31, 77, W - 77]:
		for y in range(y0, y1 + 1):
			_p(img, xs, y, _c(CUIR, 0))
			_p(img, xs + 1, y, _c(CUIR, 4))
			if y % 3 != 2:
				_p(img, xs - 2, y, _c(CUIR, 6))         # piqûre claire
	# bandes de bord (haut et bas) : 4 rangées sombres, rivets tous les 6 texels
	for x in W:
		for k in 4:
			_p(img, x, y0 + k, _c(CUIR_SOMBRE, 2 + (1 if k == 1 else 0)))
			_p(img, x, y1 - k, _c(CUIR_SOMBRE, 2 + (1 if k == 2 else 0)))
		# arête usée (le cuir épais blanchit sur les bords) et piqûre le long des bandes
		_p(img, x, y0, _c(CUIR, 5 if _h(x, 0, 827) > 0.35 else 4))
		_p(img, x, y1, _c(CUIR, 5 if _h(x, 1, 827) > 0.35 else 4))
		if x % 4 < 2:
			_p(img, x, y0 + 6, _c(CUIR, 6))
			_p(img, x, y1 - 6, _c(CUIR, 6))
		_p(img, x, y0 + 4, _c(CUIR, 0))             # ombre portée sous la bande
		_p(img, x, y1 - 4, _c(CUIR, 4))             # arête éclairée au-dessus de la bande du bas
		if x % 6 == 2:
			_rivet(img, x, y0 + 1)
			_rivet(img, x, y1 - 2)
	# bande médiane horizontale rivée (sangle)
	var ym := (y0 + y1) / 2 + 3
	for x in W:
		_p(img, x, ym, _c(CUIR, 0))
		_p(img, x, ym + 1, _c(CUIR, 4))
		if x % 8 == 4:
			_rivet(img, x, ym - 2)
	return img

# ------------------------------------------------------------------ pantalon (256 x 128) : laine sombre + bandes molletières
static func pantalon() -> Image:
	var W := 256
	var H := 128
	var img := _img(W, H)
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var sg := 0.05 if ((x + y) & 3) < 2 else -0.04
			var l := 0.48 + sg + (_n(x, y, W, H, 14, 3, 831) - 0.5) * 0.35
			var c := _c(LAINE_GRISE, _ton(l, 5, x, y, 832))
			# bandes molletières de laine écrue (de 4 à 66 cm au-dessus de l'ourlet) sous des lanières de cuir CROISÉES
			if vy >= 4 and vy < 84:
				var d := posmod(x + vy * 2, 12)
				if d < 9:
					var t := 1 + (1 if d > 1 and d < 6 else 0)
					if d == 0 or d == 8:
						t = 0
					t += int(roundf((_n(x, y, W, H, 8, 4, 833) - 0.5) * 1.2))
					c = _c(BANDE, t)
				else:
					c = _c(LAINE_GRISE, 1)
				# lanières : deux familles de diagonales (pas de 22 texels), 3 texels de large, bords sombres, arête claire
				for sens: int in [1, -1]:
					var e := posmod(x + sens * vy, 22)
					if e < 4:
						var tc: int = [0, 5, 3, 0][e]
						if e == 2 and _h(x, y, 834) > 0.7:
							tc = 4
						if _n(x, y, W, H, 12, 6, 835) > 0.7 and e == 1:
							tc = 6                      # usure claire
						c = _c(CUIR, tc)
			_p(img, x, y, c)
	return img

# ------------------------------------------------------------------ bottes fourrées (128 x 128 = 1 m x 1 m)
## Cuir brun à lanières croisées, semelle sombre, revers de fourrure en haut de tige (v ~ 0.56).
static func bottes() -> Image:
	var W := 128
	var H := 128
	var img := _img(W, H)
	for y in H:
		var vy := H - 1 - y           # hauteur depuis la semelle (texels)
		for x in W:
			var c := _c(CUIR, _ton_cuir(x, y, W, H, 0.45, 841))
			if vy < 3:
				c = _c(CUIR_SOMBRE, 1 + (1 if vy == 2 else 0))
			elif vy < 5:
				c = _c(CUIR, 0)
			# lanières croisées sur la tige (de 8 à 46 texels)
			elif vy > 8 and vy < 46:
				var a := posmod(x + vy, 10)
				var b := posmod(x - vy, 10)
				if a == 0 or b == 0:
					c = _c(CUIR_SOMBRE, 0)
				elif a == 1 or b == 1:
					c = _c(CUIR, 4 + (1 if _h(x, y, 843) > 0.7 else 0))
			# revers de fourrure en haut (v < 0.6 : vy > 51)
			if vy > 50:
				var f := _n(x, y, W, H, 32, 4, 844)
				c = _c(FOUR, 2 + int(f * 3.0) + (1 if vy > 53 else 0))
				if posmod(x * 7 + vy, 5) == 0:
					c = _c(FOUR, 1)
			_p(img, x, y, c)
	return img

# ------------------------------------------------------------------ ceinture (256 x 16)
static func ceinture() -> Image:
	var W := 256
	var H := 16
	var img := _img(W, H)
	for y in H:
		for x in W:
			var l := 0.5 + (_n(x, y, W, H, 16, 1, 851) - 0.5) * 0.4
			_p(img, x, y, _c(CUIR, _ton(l, 4, x, y, 852) + 1))
	for x in W:
		# la ceinture occupe les rangées 10 à 15 (v 0,7 -> 1)
		_p(img, x, 10, _c(CUIR, 0))
		_p(img, x, 11, _c(CUIR, 5))
		_p(img, x, 15, _c(CUIR, 0))
		if x % 3 == 0:
			_p(img, x, 14, _c(CUIR, 4))
		if x % 7 == 3:
			_rivet(img, x, 12)
	return img

# ------------------------------------------------------------------ brassards (128 x 64)
## Cuir épais lacé : laçage croisé clair, deux bandes de fer rivées aux extrémités.
static func brassards() -> Image:
	var W := 128
	var H := 64
	var img := _img(W, H)
	for y in H:
		for x in W:
			var c := _c(CUIR, _ton_cuir(x, y, W, H, 0.42, 861) - 1)
			# rainures verticales (lanières cousues)
			if x % 8 == 0:
				c = _c(CUIR, 0)
			elif x % 8 == 1:
				c = _c(CUIR, 5 if _h(x, y, 863) > 0.5 else 4)
			elif x % 8 == 4 and y % 3 != 0:
				c = _c(CUIR, 6)                          # piqûre
			_p(img, x, y, c)
	# bandes de fer : rangées 0-3 et 60-63 en v (bords du brassard selon les UV du lot 4 : poignet et coude)
	for x in W:
		for k in 4:
			var t := 3 + (1 if k == 1 else 0) - (2 if k == 3 else 0)
			_p(img, x, k, _c(FER, t))
			_p(img, x, H - 1 - k, _c(FER, t))
		if x % 6 == 0:
			_p(img, x, 1, _c(FER, 6))
			_p(img, x, H - 3, _c(FER, 6))
	return img

# ------------------------------------------------------------------ fourrure : touffes pointues en écailles
## Une touffe : pointe vers le bas, racine sombre, corps blanc cassé, arête gauche éclairée, liseré sombre sur le bord droit
## et la pointe, fente sombre au milieu (brins séparés). (x0, y0) = milieu de la racine ; w, h en texels.
static func _touffe(img: Image, x0: int, y0: int, w: int, h: int, pente: float, clair: int, alpha_fond := false) -> void:
	for k in h:
		var t := float(k) / maxf(1.0, h - 1)
		var demi := w * 0.5 * (1.0 - pow(t, 1.4) * 0.92)
		var cx := x0 + pente * k
		var xa := int(floorf(cx - demi))
		var xb := int(ceilf(cx + demi)) - 1
		for x in range(xa, xb + 1):
			var ton := clair - 1 + int(t * 2.2)
			if t < 0.18:
				ton = clair - 2                          # racine dans l'ombre des touffes du dessus
			if x == xa:
				ton = clair + 1 if t > 0.15 else clair   # arête éclairée (lumière en haut à gauche)
			if x == xb or (k == h - 1):
				ton = 1                                  # liseré sombre
			elif x == int(roundf(cx + demi * 0.25)) and t > 0.25 and t < 0.8:
				ton = clair - 2                          # fente entre deux brins
			if k == h - 1 and x == int(roundf(cx)):
				ton = clair + 1                          # pointe claire
			_p(img, x, y0 + k, _c(FOUR, ton))

## Fourrure de la mante (256 x 128 ; la mante n'occupe que le bas, v 0,58-1) : rangées de touffes en quinconce, les rangées
## du HAUT peintes en dernier (elles recouvrent la racine des suivantes, comme une fourrure qui pend).
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
		var x := int(_h(r, 0, 871) * 6.0)
		var i := 0
		while x < W + 6:
			var w := 5 + int(_h(i, r, 872) * 3.0)
			var h := 9 + int(_h(i, r, 873) * 5.0)
			var clair := 3 + (1 if _h(i, r, 874) > 0.45 else 0)
			_touffe(img, x, yr + int(_h(i, r, 875) * 3.0) - 1, w, h, (_h(i, r, 876) - 0.5) * 0.35, clair)
			x += w - 1
			i += 1
	return img

# ------------------------------------------------------------------ mèches (cartes découpées) : 4 variantes de 16 x 32
## Chaque carte porte 2 ou 3 touffes pointues côte à côte (une devant l'autre), fond transparent.
static func meches() -> Image:
	var W := 64
	var H := 32
	var img := _img(W, H, Color(0, 0, 0, 0))
	for v in 4:
		var ox := v * 16
		var n := 2 + (v & 1)
		var larg := 16.0 / n
		for i in n:
			var w := int(larg) + 2
			var cx := ox + int(larg * (i + 0.5))
			var h := 22 + int(_h(i, v, 881) * 9.0)
			var clair := 3 + (1 if (i + v) % 2 == 0 else 0)
			_touffe(img, cx, 0, mini(w, 16 - 1), mini(h, H), (_h(i, v, 882) - 0.5) * 0.25, clair)
		# pas de débord sur la variante voisine
		for y in H:
			for x in [ox, ox + 15]:
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, _c(FOUR, 1))
	return img

# ------------------------------------------------------------------ cape bleue (UV de la cape : u 0,22-0,62, v 0,1-1)
## Laine bleue froide, plis verticaux, bordure tissée sombre, ourlet effiloché découpé (alpha) en dents irrégulières.
static func cape() -> Image:
	var W := 256
	var H := 128
	var img := _img(W, H)
	for y in H:
		var vy := H - 1 - y
		for x in W:
			var sg := 0.04 if ((x + y) & 3) < 2 else -0.03
			var pli := _n(x, 0, W, 1, 22, 1, 891)
			var l := 0.42 + sg + (pli - 0.5) * 0.55 + (_n(x, y, W, H, 30, 10, 892) - 0.5) * 0.12
			l += 0.10 * smoothstep(90.0, 120.0, float(vy))          # le haut (épaules) prend la lumière
			var t := _ton(l, 6, x, y, 893, 0.3)
			var c := _c(LAINE_BLEUE, t)
			# bordure tissée sombre près de l'ourlet (8 à 13 texels)
			if vy >= 8 and vy <= 13:
				c = _c(LAINE_BLEUE, 1 + (1 if (vy == 10 or vy == 11) and (x % 4) < 2 else 0))
				if vy == 13:
					c = _c(LAINE_BLEUE, 4)
			# ourlet effiloché : coupe irrégulière (0 à 7 texels)
			var coupe := int(_h(x / 2, 0, 894) * 5.0) + int(_h(x, 1, 895) * 3.0)
			if vy < coupe:
				c = Color(0, 0, 0, 0)
			elif vy < coupe + 1:
				c = _c(LAINE_BLEUE, 0)
			_p(img, x, y, c)
	return img

# ------------------------------------------------------------------ cheveux / barbe (teinte des mèches Quaternius remplacée)
## Brins en bandes de 2-3 texels (racine sombre -> pointe claire), 64 x 64.
static func cheveux() -> Image:
	var W := 64
	var H := 64
	var img := _img(W, H)
	for y in H:
		for x in W:
			var brin := posmod(x + int(_h(x / 3, 0, 901) * 3.0), 3)
			var l := 0.45 + (_n(x, y, W, H, 16, 2, 902) - 0.5) * 0.5 + (0.18 if brin == 1 else (-0.18 if brin == 0 else 0.0))
			_p(img, x, y, _c(CHEVEUX, _ton(l, 5, x, y, 903, 0.4)))
	return img

# ------------------------------------------------------------------ atlas des accessoires (256 x 256)
## Régions (texels) :
##   (0,0,128,128)   face du bouclier : 5 planches verticales lisibles, joints sombres, bois brun-gris usé, croix délavée, clous
##   (128,0,32,32)   fer (cerclage, garde) : bandes de tons, rivets, rouille
##   (160,0,32,32)   umbo : dôme de fer éclairé en haut à gauche
##   (192,0,16,64)   lame : arête claire, gouttière sombre
##   (208,0,16,32)   poignée de cuir tressé
##   (224,0,16,32)   tresses de cheveux
##   (224,32,16,8)   œil (blanc, iris clair, pupille, paupière)
##   (240,0,16,64)   baudrier : cuir, arêtes usées, piqûre, rivets
##   (128,32,64,64)  dos du bouclier : bois brut, sangles de cuir
##   (192,64,32,32)  anneau ouvragé (boucle de ceinture, fibule)
##   (0,128,136,64)  plastron (UV de la tunique : x = u*256 + 68, y = (v - 0,203125)*128)
##   (0,192,136,16)  large ceinture (x = u*256 + 68, y = (v - 0,698) / 0,302 * 16)
const R_FACE := Rect2i(0, 0, 128, 128)
const R_FER := Rect2i(128, 0, 32, 32)
const R_UMBO := Rect2i(160, 0, 32, 32)
const R_LAME := Rect2i(192, 0, 16, 64)
const R_POIGNEE := Rect2i(208, 0, 16, 32)
const R_TRESSE := Rect2i(224, 0, 16, 32)
const R_OEIL := Rect2i(224, 32, 16, 8)
const R_BAUD := Rect2i(240, 0, 16, 64)
const R_DOS := Rect2i(128, 32, 64, 64)
const R_ANNEAU := Rect2i(192, 64, 32, 32)
const R_BOSSE := Rect2i(192, 96, 32, 32)
const R_PLASTRON := Rect2i(0, 128, 136, 64)
const R_CEINT := Rect2i(0, 192, 136, 16)
const ATLAS := Vector2i(256, 256)
## bornes des UV du plastron et de la ceinture dans l'atlas
const PL_U0 := 68
const PL_V0 := 26           # texels (0,203125 x 128)

static func accessoires() -> Image:
	var img := _img(ATLAS.x, ATLAS.y, _c(FER, 2))
	_face_bouclier(img)
	_fer(img, R_FER)
	_umbo(img)
	_lame(img)
	_poignee(img)
	_tresse(img)
	_oeil(img)
	_baudrier(img)
	_dos_bouclier(img)
	_anneau(img)
	_bosse(img)
	var pl := _plastron_atlas()
	_copier(img, R_PLASTRON, pl, -PL_U0, PL_V0)
	_ceinture_atlas(img)
	return img

## Plastron peint dans les UV de la tunique (bornes en v mesurées sur le maillage : 0,217 - 0,668).
static func _plastron_atlas() -> Image:
	return plastron(0.22, 0.66)

# ------------------------------------------------------------------ atlas des découpes (192 x 128) : cape + mèches
## (0,0,112,128) cape (x = (u - 0,21875) * 256, y = v * 128) ; (128,0,64,32) mèches de fourrure (4 variantes de 16 x 32).
const D_CAPE := Rect2i(0, 0, 112, 128)
const D_MECHES := Rect2i(128, 0, 64, 32)
const DECOUPES := Vector2i(192, 128)
const CAPE_U0 := 56

static func decoupes() -> Image:
	var img := _img(DECOUPES.x, DECOUPES.y, Color(0, 0, 0, 0))
	_copier(img, D_CAPE, cape(), CAPE_U0, 0)
	var m := meches()
	img.blit_rect(m, Rect2i(Vector2i.ZERO, m.get_size()), D_MECHES.position)
	return img

## Bouclier : planches VERTICALES (5, largeurs inégales) lisibles à 4 m : joints sombres de 2 texels + arête claire,
## veinure longue, nœuds ; bois brun-gris usé ; croix peinte délavée (mêlée au bois, écaillée par grandes plaques
## et le long des joints) ; crasse vers le bord ; clous du cerclage.
const PLANCHES := [0, 24, 51, 77, 104, 128]

static func _face_bouclier(img: Image) -> void:
	var o := R_FACE.position
	var n := R_FACE.size.x
	var c0 := (n - 1) * 0.5
	for y in n:
		for x in n:
			var dx := (x - c0) / c0
			var dy := (y - c0) / c0
			var r := sqrt(dx * dx + dy * dy)
			var k := 0
			while k < PLANCHES.size() - 2 and x >= PLANCHES[k + 1]:
				k += 1
			var dj: int = x - int(PLANCHES[k])                    # distance au joint gauche de la planche
			var base := 0.42 + _h(k, 0, 912) * 0.22
			var veine := _n(x, y, n, n, 10, 3, 911 + k)
			var fil := (_h(x, k, 918) - 0.5) * 0.18          # fil du bois : colonnes plus ou moins claires
			var lb := base + (veine - 0.5) * 0.30 + fil
			var t := clampi(_ton(lb, 5, x, y, 913, 0.2) + 1, 1, 5)
			if dj == 1 and k > 0:
				t = 5                                    # arête éclairée à droite du joint
			# nœud (un par planche)
			var nx: float = PLANCHES[k] + 6 + _h(k, 1, 919) * (PLANCHES[k + 1] - PLANCHES[k] - 12)
			var ny: float = 20 + _h(k, 2, 919) * (n - 40)
			var dn := Vector2((x - nx) * 1.6, (y - ny) * 0.6).length()
			if dn < 2.5:
				t = 1 if dn < 1.2 else 2
			var c := _c(BOIS_GRIS, t)
			# croix peinte délavée (bras de 13 texels) : couche mince, presque entière (lisible à 4 m, pas de taches), qui
			# laisse voir le fil du bois ; manque seulement le long des joints et en quelques griffures
			var croix := absf(x - c0) < 6.5 or absf(y - c0) < 6.5
			if croix and r < 0.9:
				var manque := dj <= 1 or (_n(x, y, n, n, 6, 6, 917) > 0.82 and _h(x, y, 916) > 0.4)
				if not manque:
					c = c.lerp(_c(PEINT_DELAVE, clampi(t - 1, 0, 3)), 0.58)
			# crasse vers le bord, sous le cerclage
			if r > 0.84:
				c = c.darkened(0.18)
			# joints (2 texels, le plus sombre)
			if k > 0 and dj == 0:
				c = _c(BOIS_GRIS, 0)
			# éclats dans le bois (2 entailles)
			for e: Vector3 in [Vector3(0.45, -0.35, 0.07), Vector3(-0.55, 0.42, 0.05)]:
				if Vector2(dx - e.x, (dy - e.y) * 2.5).length() < e.z:
					c = _c(BOIS_GRIS, 0)
			# clous du cerclage
			if r > 0.86 and r < 0.92:
				var ang := atan2(dy, dx)
				if posmod(int(roundf(ang / TAU * 20.0 * 4.0)), 4) == 0:
					c = _c(FER, 5) if dy < 0.0 else _c(FER, 3)
			img.set_pixel(o.x + x, o.y + y, c)

## Œil : blanc cassé lumineux, iris clair gris-bleu, pupille, ligne de paupière sombre en haut et coins sombres.
static func _oeil(img: Image) -> void:
	var r := R_OEIL
	for y in r.size.y:
		for x in r.size.x:
			var dx := (x - 7.5) / 7.5
			var dy := (y - 3.5) / 3.5
			var c := Color("#d9d4c8")
			if dx * dx + dy * dy > 1.0:
				c = Color("#3a2a24")
			var di := Vector2(x - 7.5, (y - 4.0) * 1.2).length()
			if di < 2.6:
				c = Color("#8aa2bc") if di > 1.0 else Color("#141418")
			if y == 0:
				c = Color("#2a1e1a")
			img.set_pixel(r.position.x + x, r.position.y + y, c)

## Baudrier : u en travers (0-15), v le long (se répète). Bords sombres, arêtes usées claires, piqûre, rivets.
static func _baudrier(img: Image) -> void:
	var r := R_BAUD
	for y in r.size.y:
		for x in r.size.x:
			var t := _ton_cuir(x, y, r.size.x, r.size.y, 0.66, 951)      # cuir clair à bords sombres : tranche sur le plastron
			if x == 0 or x == r.size.x - 1:
				t = 0
			elif x == 1 or x == r.size.x - 2:
				t = 5 if _h(x, y, 952) > 0.3 else 6
			elif (x == 3 or x == r.size.x - 4) and y % 3 != 0:
				t = 6
			_p(img, r.position.x + x, r.position.y + y, _c(CUIR_CLAIR, t))
		if y % 16 == 8:
			_rivet(img, r.position.x + 7, r.position.y + y)

## Large ceinture : cuir épais, bords sombres, arêtes usées, deux piqûres, rivets, plaques frottées.
static func _ceinture_atlas(img: Image) -> void:
	var r := R_CEINT
	for y in r.size.y:
		for x in r.size.x:
			var t := _ton_cuir(x, y, r.size.x, r.size.y, 0.44, 961)
			if y == 0 or y == r.size.y - 1:
				t = 0
			elif y == 1 or y == r.size.y - 2:
				t = 5 if _h(x, y, 962) > 0.3 else 6
			elif (y == 3 or y == r.size.y - 4) and x % 4 < 2:
				t = 6
			_p(img, r.position.x + x, r.position.y + y, _c(CUIR_CLAIR, t))
	for x in range(5, r.size.x, 9):
		_rivet(img, r.position.x + x, r.position.y + 7)

## Anneau ouvragé (boucle, fibule) : u = angle (32 texels), v = du bord intérieur (0) au bord extérieur (31) ;
## entrelacs en chevrons (2 brins), bords sombres, éclairé en haut à gauche.
static func _anneau(img: Image) -> void:
	var r := R_ANNEAU
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
			img.set_pixel(r.position.x + x, r.position.y + y, _c(METAL_CLAIR, clampi(t + 1, 0, 6)))

static func _fer(img: Image, r: Rect2i) -> void:
	for y in r.size.y:
		for x in r.size.x:
			var t := 4 if y < 8 else (3 if y < 16 else (2 if y < 24 else 3))
			if y == 0 or y == r.size.y - 1:
				t = 1
			if y == 2:
				t = 5
			if (y == 12 or y == 20) and x % 8 == 3:
				t = 6
			var c := _c(FER, t + (1 if _h(x, y, 921) > 0.92 else 0))
			if _n(x, y, r.size.x, r.size.y, 4, 4, 922) > 0.72 and t > 1:
				c = _c(ROUILLE, clampi(t - 2, 0, 2))
			img.set_pixel(r.position.x + x, r.position.y + y, c)

static func _umbo(img: Image) -> void:
	var r := R_UMBO
	for y in r.size.y:
		for x in r.size.x:
			# u = angle autour du dôme (0 = droite, sens trigo), v = du sommet (0) au bord (31) ; lumière en haut à gauche
			var ang := TAU * (x + 0.5) / r.size.x
			var lum := cos(ang - deg_to_rad(135.0))
			var t := 3 + int(roundf(lum * 1.6))
			if y < 5:
				t = 4
			if absf(wrapf(ang - deg_to_rad(135.0), -PI, PI)) < 0.35 and y > 6 and y < 16:
				t = 6                                 # reflet
			if y > 27:
				t = 1 if y > 29 else 2                # pied du dôme, dans l'ombre
			var c := _c(FER, clampi(t, 0, 6))
			if _n(x, y, r.size.x, r.size.y, 6, 4, 925) > 0.78 and t < 5:
				c = _c(ROUILLE, 1)
			img.set_pixel(r.position.x + x, r.position.y + y, c)

static func _lame(img: Image) -> void:
	var r := R_LAME
	for y in r.size.y:
		for x in r.size.x:
			# u en travers (0 = tranchant gauche, 15 = tranchant droit), v de la garde (0) à la pointe (63)
			var t := 4
			if x <= 1 or x >= 14:
				t = 6                                 # fil clair
			elif x == 2 or x == 13:
				t = 5
			elif x >= 6 and x <= 9 and y < 48:
				t = 2 if x == 6 else 3                # gouttière
			if _h(x, y, 931) > 0.94:
				t -= 1
			img.set_pixel(r.position.x + x, r.position.y + y, _c(FER, t))

static func _poignee(img: Image) -> void:
	var r := R_POIGNEE
	for y in r.size.y:
		for x in r.size.x:
			var t := 3 if posmod(x + y, 4) < 2 else 1
			if posmod(x + y, 4) == 0:
				t = 0
			img.set_pixel(r.position.x + x, r.position.y + y, _c(CUIR, t))

static func _tresse(img: Image) -> void:
	var r := R_TRESSE
	for y in r.size.y:
		for x in r.size.x:
			# tresse : chevrons en V (brins croisés), 3 tons
			var d := posmod(y + absi(x - 8) / 2, 4)
			var t := 3 if d < 2 else 1
			if d == 0:
				t = 4
			if x == 0 or x == 15:
				t = 0
			img.set_pixel(r.position.x + x, r.position.y + y, _c(BARBE, t + 1 if t > 0 else 0))

## Dôme clair des disques ouvragés (boucle, fibule) : fer poli, reflet net en haut à gauche.
static func _bosse(img: Image) -> void:
	var r := R_BOSSE
	for y in r.size.y:
		for x in r.size.x:
			var ang := TAU * (x + 0.5) / r.size.x
			var lum := cos(ang - deg_to_rad(135.0))
			var t := 4 + int(roundf(lum * 1.4))
			if y < 6:
				t = 5
			if absf(wrapf(ang - deg_to_rad(135.0), -PI, PI)) < 0.5 and y > 4 and y < 18:
				t = 6
			if y > 26:
				t = 2
			img.set_pixel(r.position.x + x, r.position.y + y, _c(METAL_CLAIR, clampi(t, 0, 6)))

## Barbe (32 x 64) : mèches peignées vers le bas (v = hauteur), racine plus sombre sous les joues, pointes plus claires,
## sillons sombres entre les mèches ; pas de damier.
static func barbe() -> Image:
	var W := 32
	var H := 64
	var img := _img(W, H)
	for y in H:
		for x in W:
			var meche := posmod(x + int(_h(x / 3, 0, 971) * 2.0), 3)
			var l := 0.42 + 0.22 * float(y) / H + (_n(x, y, W, H, 8, 2, 972) - 0.5) * 0.35
			l += 0.14 if meche == 1 else (-0.16 if meche == 0 else 0.0)
			_p(img, x, y, _c(BARBE, _ton(l, 6, x, y, 973, 0.3)))
	return img

static func _dos_bouclier(img: Image) -> void:
	var r := R_DOS
	for y in r.size.y:
		for x in r.size.x:
			var pl := posmod(x, 8)
			var lb := 0.4 + (_n(x, y, r.size.x, r.size.y, 4, 16, 941) - 0.5) * 0.5
			var t := _ton(lb, 4, x, y, 942)
			if pl == 0:
				t = 0
			var c := _c(BOIS_GRIS, t)
			# sangles de cuir horizontales
			if (y > 22 and y < 28) or (y > 38 and y < 44):
				c = _c(CUIR, 2 if (y == 23 or y == 39) else 3)
			img.set_pixel(r.position.x + x, r.position.y + y, c)
