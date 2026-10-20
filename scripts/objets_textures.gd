class_name ObjetsTextures
## Lot 6 : textures des objets tenus (torche, épée, gants, manches), en pixel art net. Aucune texture n'est un bruit brut :
## chaque matière est DESSINÉE (fibres et nœuds du bois, bandes de chiffon, gorge et fil de la lame, tresse de cuir,
## coutures et rivets des gants) puis quantifiée dans une rampe de 6 à 10 tons par un bruit à seuil (jamais Bayer).
## Précalculées par outils/generer_objets.gd dans assets/objets/<nom>.res (VERSION = invalidation) ; repli : calcul direct.
## Densités : lame 32 x 128 (≈ 170 texels/m le long, 550 en travers), cuir et fer 32 x 32 sur 5 à 10 cm, flamme 20 x 32 par image.

const DOSSIER := "res://assets/objets"
const VERSION := 2
const NOMS := ["flamme", "halo", "bois", "chiffon", "goudron", "braise", "lame", "tresse", "fer", "gant", "manche", "brassard", "fourrure", "cuir"]
const CLEAR := Color(0, 0, 0, 0)

const FLAMME := ["#4a0e08", "#a8260b", "#e5601a", "#ffa52c", "#ffd862", "#fff5c6"]
const BOIS := ["#120a06", "#1d120a", "#2b1b0f", "#3b2715", "#4e3720", "#63482b", "#7b5c39", "#947349"]
const CHIFFON := ["#0e0907", "#1a110b", "#281b11", "#392718", "#4c3423", "#614630", "#795940", "#947050"]
const GOUDRON := ["#040302", "#0a0705", "#120d09", "#1b140e", "#281e15", "#392d22"]
const BRAISE_CROUTE := ["#0e0806", "#1b100b", "#2b1a11", "#3b251a"]
const BRAISE_FEU := ["#661404", "#a82c07", "#e0580f", "#ff8d23", "#ffcc4e"]
const ACIER := ["#0e1219", "#19202b", "#273141", "#394559", "#506079", "#6d7e99", "#8fa0b9", "#b2c1d6", "#d3deec", "#f2f7fe"]
const CUIR := ["#150d08", "#21140c", "#321f12", "#472d19", "#5f4025", "#7a5833"]
const CUIR_CLAIR := ["#2b1c10", "#412a18", "#5b3d23", "#775330", "#93693d", "#b08350"]
const FER := ["#0f1218", "#181c25", "#242a36", "#343d4d", "#485468", "#64728a", "#8593a9", "#a9b6c8"]
const ROUILLE := ["#2b160d", "#46230f", "#6a3517", "#8f4a21"]
const LAINE := ["#12172a", "#1a2136", "#232c45", "#2d3956", "#3a4a6d", "#4a5e86", "#5f77a1"]
const FOURRURE := ["#2a2c34", "#3a3d47", "#4e525d", "#666a76", "#818692", "#a0a5b0", "#c0c4cc", "#dde0e5"]
const FIL := Color("#cdb88c")

# ------------------------------------------------------------------ outils
static func _c(r: Array, i: int) -> Color:
	return Color(r[clampi(i, 0, r.size() - 1)])

static func _h(x: int, y: int, g: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (g * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0

## Bruit de valeurs périodique (période px x py cellules), lissé, 0..1.
static func _vn(x: float, y: float, px: int, py: int, g: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - xi
	var fy := y - yi
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _h(posmod(xi, px), posmod(yi, py), g)
	var b := _h(posmod(xi + 1, px), posmod(yi, py), g)
	var c := _h(posmod(xi, px), posmod(yi + 1, py), g)
	var d := _h(posmod(xi + 1, px), posmod(yi + 1, py), g)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

## Bruit fractal de la texture (w x h) : `cx` x `cy` cellules en octave 1.
static func _fbm(x: int, y: int, w: int, h: int, cx: int, cy: int, g: int, oct := 3) -> float:
	var v := 0.0
	var a := 0.5
	var tot := 0.0
	var px := cx
	var py := cy
	for o in oct:
		v += _vn(float(x) / w * px, float(y) / h * py, px, py, g * 10 + o) * a
		tot += a
		a *= 0.5
		px *= 2
		py *= 2
	return v / tot

## Quantification au bruit : le grain ne fait basculer que les valeurs proches d'un seuil.
static func _ton(l: float, n: int, x: int, y: int, jitter := 0.5) -> int:
	var j := (_h(x, y, 991) - 0.5) * jitter
	return clampi(int(floorf(l * n + j)), 0, n - 1)

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	img.set_pixel(posmod(x, img.get_width()), posmod(y, img.get_height()), c)

static func _img(w: int, h: int) -> Image:
	var i := Image.create(w, h, false, Image.FORMAT_RGBA8)
	i.fill(CLEAR)
	return i

# ------------------------------------------------------------------ flamme : 6 images de 20 x 32, bords rouges, corps orange, cœur jaune-blanc
const FW := 20
const FH := 32
const FIMAGES := 6

static func flamme_atlas() -> Image:
	var img := _img(FW * FIMAGES, FH)
	var sways := [-1.6, 1.8, -0.4, 2.2, -2.0, 0.8]
	var hautes := [1.0, 0.9, 1.05, 0.82, 0.96, 0.88]
	for f in FIMAGES:
		var ox := f * FW
		var sway: float = sways[f]
		var hf: float = hautes[f]
		for y in FH:
			var s := 1.0 - float(y) / (FH - 1)                     # 0 = pied, 1 = pointe
			var s_eff := s / hf
			if s_eff >= 1.0:
				continue
			# axe qui s'incline vers le haut, largeur : pied serré sur la tête, ventre à 25 %, pointe effilée
			var axe := 9.5 + sway * pow(s_eff, 1.6) + sin(s * 7.0 + f * 1.9) * 0.55 * s_eff
			var ventre := sin(clampf(s_eff * 1.15, 0.0, 1.0) * PI * 0.5) * (1.0 - pow(s_eff, 2.2))
			var demi := 3.9 + 4.0 * ventre * (1.0 - 0.35 * s_eff)
			demi *= 1.0 - pow(s_eff, 3.0) * 0.55
			# deuxième langue (fourche) sur certaines images
			var langue2 := 0.0
			var axe2 := 0.0
			if f % 3 != 0 and s_eff > 0.42 and s_eff < 0.95:
				var ts := (s_eff - 0.42) / 0.53
				axe2 = 9.5 + (-sway * 0.9 - (3.0 if sway > 0.0 else -3.0) * 0.4) * pow(s_eff, 1.3) + (3.0 if sway > 0.0 else -3.0) * -0.6 * ts
				langue2 = 2.3 * sin(ts * PI) * (1.0 - ts * 0.5)
			for x in FW:
				var bruit := (_fbm(x + f * 7, y, 32, 32, 4, 4, 17 + f, 2) - 0.5) * 2.2
				var dx := absf(float(x) - axe)
				var dedans := dx <= demi + bruit * (0.35 + 0.5 * s_eff)
				var d := dx / maxf(demi, 0.6)
				if not dedans and langue2 > 0.0:
					var dx2 := absf(float(x) - axe2)
					if dx2 <= langue2 + bruit * 0.3:
						dedans = true
						d = dx2 / maxf(langue2, 0.6) * 0.95 + 0.25
				if not dedans:
					continue
				# chaleur : cœur au centre et près du pied ; rouge sur les bords et en pointe
				var chaud := (1.0 - clampf(d, 0.0, 1.0)) * (0.50 + 0.50 * (1.0 - pow(s_eff, 0.9)))
				chaud += (_fbm(x, y + f * 5, 32, 32, 5, 5, 31, 2) - 0.5) * 0.30
				var t := _ton(chaud, 6, x, y, 0.35)
				if d > 0.86:
					t = 0                                           # liseré rouge sombre : la flamme se lit sur fond clair
				elif d > 0.62:
					t = mini(t, 1 if s_eff > 0.5 else 2)
				_px(img, ox + x, y, _c(FLAMME, t))
		# étincelle détachée au-dessus de la pointe (images impaires)
		if f % 2 == 1:
			var ey := 0
			var ex := int(9.5 + sway * 0.9 * hf)
			_px(img, ox + ex, ey, _c(FLAMME, 4))
			_px(img, ox + ex, ey + 1, _c(FLAMME, 3))
	return img

## Halo : anneaux posterisés (14 paliers), additif. Repris de la crypte (même dessin que les halos des appliques murales).
static func halo() -> Image:
	return CrypteTextures.halo_image()

# ------------------------------------------------------------------ torche : bois, chiffon, goudron, braise
## Manche : fibres verticales, cernes, nœuds sombres cerclés de clair, fentes de séchage ; 32 x 64.
static func bois() -> Image:
	var W := 32
	var H := 64
	var img := _img(W, H)
	var noeuds := [[8, 14, 3.2], [22, 40, 2.6], [12, 57, 2.2], [26, 6, 1.8]]
	for y in H:
		for x in W:
			var fibre := _fbm(x, y, W, H, 8, 2, 3, 3)                # étiré : cellules hautes de 32 px
			var cerne := 0.5 + 0.5 * sin((float(x) / W * 6.0 + fibre * 2.4) * TAU)
			var l := 0.18 + fibre * 0.46 + cerne * 0.20
			for n in noeuds:
				var d: float = Vector2((x - n[0]) / 1.0, (y - n[1]) / 1.6).length() / n[2]
				if d < 1.0:
					l = lerpf(0.07, 0.30, d)                          # cœur du nœud sombre
				elif d < 1.35:
					l += 0.17 * (1.0 - (d - 1.0) / 0.35)              # bourrelet clair autour
			if _h(x / 2, y / 11, 55) > 0.965 and fibre > 0.4:
				l *= 0.40                                              # fente de séchage
			if _h(x, y, 56) > 0.997:
				l = 0.98                                               # éclat de bois
			_px(img, x, y, _c(BOIS, _ton(l, BOIS.size(), x, y, 0.6)))
	return img

## Chiffon goudronné : bandes enroulées en diagonale (liseré clair d'un côté, couture sombre de l'autre), trame, bouts effilochés.
static func chiffon() -> Image:
	var S := 32
	var img := _img(S, S)
	for y in S:
		for x in S:
			var diag := posmod(x * 2 + y * 3, 16)                    # période 16 : se raccorde (32 = 2 x 16)
			var l := 0.34
			if diag < 2:
				l = 0.04                                              # couture de la bande
			elif diag < 4:
				l = 0.60                                              # biseau éclairé
			else:
				l += (_fbm(x, y, S, S, 4, 4, 7, 2) - 0.5) * 0.50
				l += 0.08 if (x + y) % 2 == 0 else -0.05              # trame du tissu
			if _h(x, y, 61) > 0.93:
				l += 0.22                                              # fibres sorties
			_px(img, x, y, _c(CHIFFON, _ton(l, CHIFFON.size(), x, y, 0.5)))
	return img

static func goudron() -> Image:
	var S := 32
	var img := _img(S, S)
	for y in S:
		for x in S:
			var n := _fbm(x, y, S, S, 3, 3, 9, 3)
			var l := 0.25 + n * 0.55
			var c := _c(GOUDRON, _ton(l, GOUDRON.size(), x, y, 0.5))
			# reflets du goudron mouillé : traits clairs courts, rares
			if n > 0.64 and _h(x, y, 62) > 0.55 and (x + y * 2) % 5 == 0:
				c = Color("#6e7280")
			_px(img, x, y, c)
	return img

## Cœur de braises : croûte noire fendillée, fentes incandescentes (le shader la rend sans éclairage) ; 32 x 16.
static func braise() -> Image:
	var W := 32
	var H := 16
	var img := _img(W, H)
	for y in H:
		for x in W:
			var n := _fbm(x, y, W, H, 4, 2, 21, 3)
			var fente := absf(n - 0.5)
			var grain := _h(x, y, 63)
			var c: Color
			if fente < 0.045 or (fente < 0.09 and grain > 0.55):
				var chaud := 1.0 - fente / 0.09
				c = _c(BRAISE_FEU, _ton(0.15 + chaud * 0.85, BRAISE_FEU.size(), x, y, 0.6))
			else:
				c = _c(BRAISE_CROUTE, _ton(n, BRAISE_CROUTE.size(), x, y, 0.8))
				if grain > 0.985:
					c = _c(BRAISE_FEU, 1)
			_px(img, x, y, c)
	return img

# ------------------------------------------------------------------ lame : gorge, biseaux du fil, reflets, rune ; 32 x 128 (v = 0 : pointe)
static func lame() -> Image:
	var W := 32
	var H := 128
	var img := _img(W, H)
	for y in H:
		var v := 1.0 - float(y) / (H - 1)                           # 0 = base (garde), 1 = pointe
		for x in W:
			var u := (x + 0.5) / W
			var au := absf(u - 0.5) * 2.0                            # 0 centre, 1 fil
			var brosse := _fbm(x, y, W, H, 6, 2, 5, 3)               # polissage en long
			var l := 0.45 + (brosse - 0.5) * 0.30
			var fuller := 0.0
			# gorge : entre u = 0.34 et 0.66 de v = 0.09 à 0.72
			if v > 0.085 and v < 0.76 and au < 0.34:
				var bord_bas := smoothstep(0.085, 0.13, v) * (1.0 - smoothstep(0.66, 0.76, v))
				if bord_bas > 0.5:
					fuller = 1.0
			if fuller > 0.5:
				l = 0.20 + (brosse - 0.5) * 0.18
				if au > 0.28:
					l = 0.62 if u < 0.5 else 0.10                      # lèvres : éclairée à gauche, ombre à droite
				elif au > 0.22:
					l = 0.34 if u < 0.5 else 0.14
				elif au < 0.06:
					l += 0.10                                           # fond de gorge : brillance du creux
			else:
				if au > 0.87:
					l = 0.88 + (brosse - 0.5) * 0.18                   # fil du tranchant : acier clair
				elif au > 0.72:
					l = 0.64 + (brosse - 0.5) * 0.20                   # biseau
					if au > 0.80 and au < 0.84:
						l = 0.38                                        # arête entre le biseau et le plat
				elif au > 0.34 and au < 0.40:
					l = 0.30                                            # pli côté gorge
				# plats
				if au > 0.40 and au < 0.72:
					l = 0.50 + (brosse - 0.5) * 0.30
			# reflet net : deux bandes en biais, bords francs (plats et biseaux), plus claires côté gauche
			var diag := v * 7.0 + u * 2.4
			var bande := fmod(diag, 1.0)
			if bande > 0.80 and bande < 0.93 and fuller < 0.5 and v > 0.10:
				l += 0.26 if u < 0.5 else 0.12
			# ricasso : plus sombre, noirci par le feu ; pointe : poli plus clair
			if v < 0.09:
				l = l * 0.72
			elif v > 0.93:
				l += 0.10
			# marque du forgeron (v 0.02 - 0.075) : petit glyphe en creux, sur le plat gauche
			if v > 0.015 and v < 0.078 and u > 0.17 and u < 0.30:
				var gx := int((u - 0.17) / 0.13 * 5.0)
				var gy := int((v - 0.015) / 0.063 * 9.0)
				if gx == 2 or (gy == 4 and (gx == 1 or gx == 3)) or (gy in [2, 3] and (gx == 0 or gx == 4)):
					l = 0.12
			# éclats du fil (ébréchures) et rayures fines
			if au > 0.92 and _h(x, y / 3, 77) > 0.90:
				l = 0.16
			if _h(x / 2, y, 78) > 0.985 and fuller < 0.5:
				l += 0.16
			if (x + y * 3) % 61 == 0 and fuller < 0.5:
				l -= 0.18
			_px(img, x, y, _c(ACIER, _ton(l, ACIER.size(), x, y, 0.45)))
	return img

## Poignée de cuir tressée : lanières en chevrons, interstices sombres, bord éclairé en haut à gauche ; 32 x 32 (2 raccords en largeur).
static func tresse() -> Image:
	var S := 32
	var img := _img(S, S)
	for y in S:
		for x in S:
			var demi := x % 16
			var k: int
			if demi < 8:
				k = posmod(demi + y, 8)
			else:
				k = posmod((15 - demi) + y, 8)                         # miroir : chevron en V
			var l := 0.50
			var lanière := float(k) / 8.0
			if k == 0:
				l = 0.02                                               # interstice entre deux lanières
			elif k == 1:
				l = 0.78                                               # bord éclairé
			elif k < 5:
				l = 0.46 + (_fbm(x, y, S, S, 4, 4, 13, 2) - 0.5) * 0.35
			else:
				l = 0.30 + lanière * 0.1
			if demi == 7 or demi == 8:
				l = minf(l, 0.22) if demi == 7 else maxf(l, 0.20)      # axe du chevron
			if _h(x, y, 65) > 0.95:
				l += 0.20                                               # cuir usé
			_px(img, x, y, _c(CUIR, _ton(l, CUIR.size(), x, y, 0.4)))
	return img

## Fer forgé : coups de marteau (cuvettes à lèvre claire en haut à gauche), rayures, un peu de rouille ; 32 x 32.
static func fer() -> Image:
	var S := 32
	var img := _img(S, S)
	var hauteur := PackedFloat32Array()
	hauteur.resize(S * S)
	var cuv := []
	for i in 22:
		cuv.append([_h(i, 1, 81) * S, _h(i, 2, 81) * S, 1.6 + _h(i, 3, 81) * 2.2])
	for y in S:
		for x in S:
			var hv := 0.5 + (_fbm(x, y, S, S, 4, 4, 11, 3) - 0.5) * 0.5
			for c in cuv:
				var dx := absf(x - c[0])
				dx = minf(dx, S - dx)
				var dy := absf(y - c[1])
				dy = minf(dy, S - dy)
				var d: float = Vector2(dx, dy).length() / c[2]
				if d < 1.0:
					hv -= 0.20 * (1.0 - d * d)
			hauteur[y * S + x] = hv
	for y in S:
		for x in S:
			var hv := hauteur[y * S + x]
			var gauche := hauteur[y * S + posmod(x - 1, S)]
			var haut := hauteur[posmod(y - 1, S) * S + x]
			var l := 0.38 + (hv - 0.5) * 0.7 + ((hv - gauche) + (hv - haut)) * -2.0   # lèvre éclairée / ombre
			if _h(x, y, 82) > 0.975:
				l += 0.30
			if (x * 2 + y) % 37 == 0:
				l -= 0.15
			var c := _c(FER, _ton(l, FER.size(), x, y, 0.4))
			if _fbm(x, y, S, S, 3, 3, 12, 2) > 0.74 and _h(x, y, 83) > 0.5:
				c = _c(ROUILLE, _ton(l, ROUILLE.size(), x, y, 0.5))
			_px(img, x, y, c)
	return img

# ------------------------------------------------------------------ gants, manches, brassards, fourrure
## Cuir de gant 64 x 64 : grain fin en cellules, pli aux articulations, coutures en pointillé (fil clair) et lisérés.
static func gant() -> Image:
	var S := 64
	var img := _img(S, S)
	for y in S:
		for x in S:
			var n := _fbm(x, y, S, S, 6, 6, 41, 3)
			var cell := _h(x / 3, y / 3, 42)
			var l := 0.34 + n * 0.40 + (cell - 0.5) * 0.16
			# plis horizontaux (articulations) : fines bandes sombres à v = 0.25, 0.5, 0.75
			var pli := absf(fmod(float(y) / S * 4.0, 1.0) - 0.5)
			if pli > 0.46:
				l -= 0.20
			_px(img, x, y, _c(CUIR_CLAIR, _ton(l, CUIR_CLAIR.size(), x, y, 0.5)))
	# coutures : deux lignes verticales (x = 15 et 47) et une horizontale (y = 31), pointillé 3 px fil / 2 px trou, double rangée de trous
	for t in S:
		if t % 5 < 3:
			_px(img, 15, t, FIL)
			_px(img, 47, t, FIL)
			_px(img, t, 31, FIL)
		_px(img, 16, t, _c(CUIR_CLAIR, 0))
		_px(img, 14, t, _c(CUIR_CLAIR, 1))
		_px(img, 48, t, _c(CUIR_CLAIR, 0))
		_px(img, 46, t, _c(CUIR_CLAIR, 1))
		_px(img, t, 32, _c(CUIR_CLAIR, 0))
		_px(img, t, 30, _c(CUIR_CLAIR, 1))
	# liseré de bord (haut de la texture = poignet) : bande plus sombre cousue
	for x in S:
		_px(img, x, 0, _c(CUIR_CLAIR, 0))
		_px(img, x, 1, _c(CUIR_CLAIR, 1))
		_px(img, x, 63, _c(CUIR_CLAIR, 0))
	return img

## Cuir sombre 64 x 64 (gants de la sous-couche, brassards) : même grain, coutures et lacet croisé.
static func brassard() -> Image:
	var S := 64
	var img := _img(S, S)
	for y in S:
		for x in S:
			var n := _fbm(x, y, S, S, 6, 6, 47, 3)
			var cell := _h(x / 3, y / 3, 48)
			var l := 0.28 + n * 0.38 + (cell - 0.5) * 0.14
			_px(img, x, y, _c(CUIR, _ton(l, CUIR.size(), x, y, 0.5)))
	# lanière de bord (haut et bas) : bande cousue
	for x in S:
		for k in 4:
			_px(img, x, k, _c(CUIR, 2 + (1 if k == 0 else 0)))
			_px(img, x, S - 1 - k, _c(CUIR, 2 + (1 if k == 3 else 0)))
		if x % 4 < 2:
			_px(img, x, 2, FIL)
			_px(img, x, S - 3, FIL)
	# lacet croisé au milieu (u 0.4 - 0.6) : X de lanières
	for y in range(8, S - 8):
		var phase := (y - 8) % 12
		var a := 22 + phase if phase < 6 else 22 + 12 - phase
		for dx in 2:
			_px(img, a + dx, y, _c(CUIR, 4))
			_px(img, 41 - (a - 22) + dx, y, _c(CUIR, 4))
	for k in 6:
		_px(img, 31, 8 + k * 8, _c(CUIR, 5))
		_px(img, 32, 8 + k * 8, _c(CUIR, 5))
	return img

## Laine de la manche 64 x 64 : mailles en V (rangées de 4 px), fils plus clairs au bord de chaque maille, côtes en bas.
static func manche() -> Image:
	var S := 64
	var img := _img(S, S)
	for y in S:
		for x in S:
			var rang := y / 4
			var lx := (x + (0 if rang % 2 == 0 else 2)) % 4
			var ly := y % 4
			# maille = V : deux brins diagonaux
			var brin := (ly == lx) or (ly == 3 - lx)
			var l := 0.30 + (_fbm(x, y, S, S, 5, 5, 51, 2) - 0.5) * 0.35
			if brin:
				l += 0.22
			if ly == 3:
				l -= 0.12
			_px(img, x, y, _c(LAINE, _ton(l, LAINE.size(), x, y, 0.4)))
	# côtes du bord (bas, 8 px) : traits verticaux serrés
	for y in range(S - 8, S):
		for x in S:
			var c := 0.18 if x % 4 == 0 else (0.62 if x % 4 == 1 else 0.38)
			_px(img, x, y, _c(LAINE, _ton(c + (_h(x, y, 52) - 0.5) * 0.2, LAINE.size(), x, y, 0.3)))
	for x in S:
		if x % 6 < 3:
			_px(img, x, S - 9, FIL.darkened(0.25))                       # surpiqûre
	return img

## Fourrure 32 x 32 : mèches plongeantes (traits de 3 à 6 px clairs et sombres), pointes claires.
static func fourrure() -> Image:
	var S := 32
	var img := _img(S, S)
	for y in S:
		for x in S:
			var l := 0.42 + (_fbm(x, y, S, S, 6, 3, 71, 2) - 0.5) * 0.45
			_px(img, x, y, _c(FOURRURE, _ton(l, FOURRURE.size(), x, y, 0.4)))
	for i in 70:
		var x := int(_h(i, 1, 72) * S)
		var y := int(_h(i, 2, 72) * S)
		var longueur := 3 + int(_h(i, 3, 72) * 4.0)
		var clair := _h(i, 4, 72) > 0.45
		for k in longueur:
			var t := float(k) / longueur
			var ton := (5 if clair else 1) + (1 if (clair and t > 0.6) else 0)
			_px(img, x + (1 if k > longueur / 2 and _h(i, 5, 72) > 0.5 else 0), y + k, _c(FOURRURE, ton))
	return img

## Cuir de base 32 x 32 (rivets des brassards et des gants dessinés ailleurs) : grain fin.
static func cuir() -> Image:
	var S := 32
	var img := _img(S, S)
	for y in S:
		for x in S:
			var l := 0.30 + _fbm(x, y, S, S, 5, 5, 91, 3) * 0.46 + (_h(x / 2, y / 2, 92) - 0.5) * 0.14
			_px(img, x, y, _c(CUIR, _ton(l, CUIR.size(), x, y, 0.5)))
	return img

# ------------------------------------------------------------------ accès
static func image(nom: String) -> Image:
	match nom:
		"flamme": return flamme_atlas()
		"halo": return halo()
		"bois": return bois()
		"chiffon": return chiffon()
		"goudron": return goudron()
		"braise": return braise()
		"lame": return lame()
		"tresse": return tresse()
		"fer": return fer()
		"gant": return gant()
		"manche": return manche()
		"brassard": return brassard()
		"fourrure": return fourrure()
		"cuir": return cuir()
	return cuir()

static var _cache := {}

## Texture prête à l'emploi : lue dans assets/objets si la VERSION correspond, sinon calculée.
static func tex(nom: String) -> ImageTexture:
	if _cache.has(nom):
		return _cache[nom]
	var a: Image = null
	var chemin := "%s/%s.res" % [DOSSIER, nom]
	if ResourceLoader.exists(chemin):
		a = ResourceLoader.load(chemin) as Image
		if a != null and a.get_meta("version", -1) != VERSION:
			a = null
	if a == null:
		a = image(nom)
	var t := ImageTexture.create_from_image(a)
	_cache[nom] = t
	return t

static func vider() -> void:
	_cache.clear()
