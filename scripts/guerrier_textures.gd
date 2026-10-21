class_name GuerrierTextures
## Textures du Guerrier nordique pilote (GuerrierNordique), peintes par code à 128 texels/m (2 x la densité des vêtements
## du lot 4, mêmes UV métriques : u = 2 m par unité, v = 1 m, BAS de l'image = ourlet), dans des palettes FROIDES et désaturées
## de 4 à 6 tons par matière (référence persos_b : mailles gris-bleu, cuir brun à rivets, fourrure blanc cassé, bois veiné,
## fer), avec contours sombres et rehauts d'arête peints. Jamais de tramage Bayer : bruit seulement.
## Chaque texture reçoit des mipmaps « pixel art » (vote de couleur 2x2, comme les arbres) : texels nets de près,
## pas de moiré ni de grouillement à 4-8 m.

# palettes (sombre -> clair)
const MAILLE := ["#14171e", "#252a35", "#3b4250", "#56606f", "#7c8696", "#b0b8c4"]
const CUIR := ["#1a130e", "#2f2118", "#463325", "#614a34", "#7f6446", "#9e825e"]
const CUIR_SOMBRE := ["#100c0b", "#1d1613", "#2c221c", "#3f3228", "#544537"]
const FOUR := ["#1c1d22", "#383a40", "#5b5c60", "#838482", "#aeaca4", "#d3d0c4"]
const LAINE_BLEUE := ["#0f1422", "#1a2439", "#283855", "#384d74", "#4c6490", "#687fa8"]
const LAINE_GRISE := ["#17171c", "#25252b", "#35343a", "#47454a", "#5b585b"]
const BANDE := ["#2c2a29", "#423e3a", "#57524b", "#6d675d"]   # bandes molletières (laine écrue)
const BOIS := ["#16110d", "#271e17", "#3a2d22", "#4f3f30", "#665341", "#7f6a54"]
const PEINT_BLEU := ["#141b2b", "#1f2b44", "#2c3d5e", "#3e5276", "#566c90"]
const PEINT_CREME := ["#5c5546", "#807864", "#a39a84", "#c4bba3"]
const FER := ["#0d0e12", "#1b1d23", "#2e313a", "#474b56", "#6c717d", "#9da2ac", "#c9ccd2"]
const ROUILLE := ["#24150e", "#3d2416", "#5a3820"]
const CHEVEUX := ["#1b1712", "#33291f", "#4f412f", "#6e5c42", "#927e5c"]

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
			var l := 0.50 + (_n(x, y, W, H, 10, 6, 821) - 0.5) * 0.35 + (_n(x, y, W, H, 40, 20, 822) - 0.5) * 0.12
			# frottement : clair au milieu des panneaux
			var t := _ton(l, 5, x, y, 823, 0.35) + 1
			_p(img, x, y, _c(CUIR, t))
	# coutures verticales : devant (u = 0 -> x = 0), flancs (u = +-0.12 -> x = +-31), dos (x = 128)
	for xs: int in [0, 31, W - 31, 77, W - 77]:
		for y in range(y0, y1 + 1):
			_p(img, xs, y, _c(CUIR, 0))
			_p(img, xs + 1, y, _c(CUIR, 4))
			if y % 3 == 0:
				_p(img, xs - 1, y, _c(CUIR, 5))
	# bandes de bord (haut et bas) : 4 rangées sombres, rivets tous les 6 texels
	for x in W:
		for k in 4:
			_p(img, x, y0 + k, _c(CUIR_SOMBRE, 2 + (1 if k == 1 else 0)))
			_p(img, x, y1 - k, _c(CUIR_SOMBRE, 2 + (1 if k == 2 else 0)))
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
			# bandes molletières : de 4 à 40 cm au-dessus de l'ourlet, bandes de 5 texels en diagonale, bord sombre
			if vy >= 4 and vy < 52:
				var d := posmod(x + vy * 2, 12)
				if d < 9:
					var t := 1 + (1 if d > 1 and d < 6 else 0)
					if d == 0 or d == 8:
						t = 0
					t += int(roundf((_n(x, y, W, H, 8, 4, 833) - 0.5) * 1.2))
					c = _c(BANDE, t)
				else:
					c = _c(LAINE_GRISE, 1)
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
			var l := 0.45 + (_n(x, y, W, H, 8, 8, 841) - 0.5) * 0.4
			var c := _c(CUIR, _ton(l, 5, x, y, 842) + 1)
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
			var l := 0.5 + (_n(x, y, W, H, 8, 4, 861) - 0.5) * 0.45
			var c := _c(CUIR, _ton(l, 5, x, y, 862))
			# rainures verticales (lanières cousues)
			if x % 8 == 0:
				c = _c(CUIR, 0)
			elif x % 8 == 1:
				c = _c(CUIR, 4)
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

# ------------------------------------------------------------------ atlas des accessoires (256 x 128)
## Régions (texels) :
##   (0,0,128,128)   face du bouclier : planches verticales, joints, veinure, peinture bleue usée + croix crème, clous du cerclage
##   (128,0,32,32)   fer (cerclage, boucle, garde) : bandes de tons, rivets, rouille
##   (160,0,32,32)   umbo : dôme de fer, reflet
##   (192,0,16,64)   lame : arête claire, gouttière sombre
##   (208,0,16,32)   poignée de cuir tressé
##   (224,0,16,32)   tresses de cheveux
##   (128,32,64,64)  dos du bouclier : bois brut sombre, sangles de cuir
const R_FACE := Rect2i(0, 0, 128, 128)
const R_FER := Rect2i(128, 0, 32, 32)
const R_UMBO := Rect2i(160, 0, 32, 32)
const R_LAME := Rect2i(192, 0, 16, 64)
const R_POIGNEE := Rect2i(208, 0, 16, 32)
const R_TRESSE := Rect2i(224, 0, 16, 32)
const R_DOS := Rect2i(128, 32, 64, 64)
const ATLAS := Vector2i(256, 128)

static func accessoires() -> Image:
	var img := _img(ATLAS.x, ATLAS.y, _c(FER, 2))
	_face_bouclier(img)
	_fer(img, R_FER)
	_umbo(img)
	_lame(img)
	_poignee(img)
	_tresse(img)
	_dos_bouclier(img)
	return img

static func _face_bouclier(img: Image) -> void:
	var o := R_FACE.position
	var n := R_FACE.size.x
	var c0 := (n - 1) * 0.5
	for y in n:
		for x in n:
			var dx := (x - c0) / c0
			var dy := (y - c0) / c0
			var r := sqrt(dx * dx + dy * dy)
			# planches verticales de 15 texels (12 cm), joint sombre + arête claire
			var pl := posmod(x + 3, 15)
			var veine := _n(x, y, n, n, 6, 28, 911 + (x + 3) / 15)
			var lb := 0.5 + (veine - 0.5) * 0.7 + (_h((x + 3) / 15, 0, 912) - 0.5) * 0.25
			var bois := _c(BOIS, _ton(lb, 5, x, y, 913, 0.25) + 1)
			if pl == 0:
				bois = _c(BOIS, 0)
			elif pl == 1:
				bois = _c(BOIS, 4)
			# peinture : champ bleu, croix crème (bras de 12 texels), anneau bleu sombre au bord
			var croix := absf(x - c0) < 7.0 or absf(y - c0) < 7.0
			var peint: Color
			var lp := 0.55 + (veine - 0.5) * 0.4
			if r > 0.80:
				peint = _c(PEINT_BLEU, _ton(lp * 0.7, 5, x, y, 914))
			elif croix:
				peint = _c(PEINT_CREME, [0, 2, 2, 3][_ton(lp, 4, x, y, 915)])
			else:
				peint = _c(PEINT_BLEU, _ton(lp, 5, x, y, 916) + 1)
			# usure : la peinture part par plaques (bruit) et le long des joints
			var usure := _n(x, y, n, n, 9, 9, 917) + (0.25 if pl <= 1 else 0.0) + r * 0.15
			var c := peint if usure < 0.76 else bois
			if usure >= 0.72 and usure < 0.76:
				c = _c(BOIS, 0)                       # bord écaillé sombre
			# éclats dans le bois (2 entailles)
			for e: Vector3 in [Vector3(0.45, -0.35, 0.08), Vector3(-0.55, 0.42, 0.06)]:
				if Vector2(dx - e.x, (dy - e.y) * 2.5).length() < e.z:
					c = _c(BOIS, 0)
			# clous du cerclage
			if r > 0.86 and r < 0.92:
				var ang := atan2(dy, dx)
				if posmod(int(roundf(ang / TAU * 20.0 * 4.0)), 4) == 0:
					c = _c(FER, 5) if dy < 0.0 else _c(FER, 3)
			img.set_pixel(o.x + x, o.y + y, c)

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
			# u = angle autour du dôme, v = du sommet (0) au bord (1)
			var t := 3 + (1 if x < 12 else 0) - (1 if x > 22 else 0)
			if y < 6:
				t += 1
			if x == 9 and y < 20:
				t = 6                                 # reflet
			if y > 28:
				t = 1
			img.set_pixel(r.position.x + x, r.position.y + y, _c(FER, t))

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
			img.set_pixel(r.position.x + x, r.position.y + y, _c(CHEVEUX, t))

static func _dos_bouclier(img: Image) -> void:
	var r := R_DOS
	for y in r.size.y:
		for x in r.size.x:
			var pl := posmod(x, 8)
			var lb := 0.4 + (_n(x, y, r.size.x, r.size.y, 4, 16, 941) - 0.5) * 0.5
			var t := _ton(lb, 4, x, y, 942)
			if pl == 0:
				t = 0
			var c := _c(BOIS, t)
			# sangles de cuir horizontales
			if (y > 22 and y < 28) or (y > 38 and y < 44):
				c = _c(CUIR, 2 if (y == 23 or y == 39) else 3)
			img.set_pixel(r.position.x + x, r.position.y + y, c)
