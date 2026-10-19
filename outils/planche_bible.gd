extends SceneTree
## Planche de référence de la bible visuelle : rampes de la palette maîtresse + 6 échantillons de pixel art
## dessinés par code (amas délibérés, aucun bruit) + mise en situation de nuit.
##   godot --headless --path . --script outils/planche_bible.gd [-- dossier_sortie]
## Écrit <dossier>/planche_palette.png (défaut res://captures/bible) et des détails planche_<x>.png.

# --- palette maîtresse : nom -> tons du plus sombre (froid/violet) au plus clair (chaud) ---
const RAMPES := [
	["NEIGE", ["#4a557f", "#6877a3", "#8898bf", "#aab8d6", "#cdd7ec", "#f0eff4"]],
	["GLACE", ["#33577f", "#4f86ae", "#86bfd3", "#cfeef0"]],
	["EPICEA AIGUILLES", ["#08161a", "#10272a", "#1a3d32", "#2c5a41", "#5b866f", "#6e9172"]],
	["EPICEA ECORCE", ["#241a22", "#3a2a2a", "#54402f", "#735b43", "#947c5e"]],
	["PIN ECORCE", ["#3b1f24", "#6a3524", "#9c5129", "#cf7b3c", "#ecaa62"]],
	["BOULEAU", ["#17151d", "#3f3d4c", "#787f9e", "#a9aec4", "#d6d8e2", "#f4f0e8"]],
	["BOIS MORT", ["#3d3c4a", "#5b5a66", "#7f7d82", "#a7a19b"]],
	["PIERRE", ["#262a3b", "#3a4057", "#565b72", "#787d8e", "#a0a2ab"]],
	["BOIS TRAVAILLE", ["#2b1a1e", "#472a21", "#6a4229", "#92613a", "#bb8a53"]],
	["TOURBE CHAUME", ["#211e1c", "#3b3322", "#5c4e2d", "#82723f", "#b39d5d"]],
	["PEAU CLAIRE", ["#9a6266", "#cf9879", "#efc7a2", "#f8e0c4"]],
	["PEAU MOYENNE", ["#7a4747", "#ad7658", "#d6a27a", "#ecc79f"]],
	["PEAU FONCEE", ["#432a30", "#70473b", "#9d6b50", "#c18f6c"]],
	["CUIR", ["#1f1418", "#3a261b", "#5b3d27", "#86603a"]],
	["LAINE BLEUE", ["#1b2a52", "#2a4382", "#4468ac", "#7b9ad0"]],
	["LAINE ROUGE", ["#351520", "#5c1f2b", "#8a2f35", "#b9504a"]],
	["ECRU", ["#8e8688", "#b9ae9f", "#dbd0b6", "#efe7d0"]],
	["FOURRURE", ["#25262f", "#3d3e4a", "#5c5d68", "#85848c", "#b3b0b4"]],
	["FER", ["#20252f", "#3a4256", "#5b6680", "#8a96ae", "#bcc6d8"]],
	["OR TERNI", ["#4a3419", "#7b5a26", "#a98638", "#d3b25c"]],
	["BRAISE FLAMME", ["#5a1a1c", "#b3341f", "#ec6a1f", "#fcb53a", "#fff0a8"]],
	["RUNES CYAN", ["#0c4a5e", "#14899b", "#3fd0d0", "#b6fbf0"]],
]
const FOND := Color(0.07, 0.07, 0.09)
const TEXTE := Color(0.95, 0.85, 0.55)
const TEXTE2 := Color(0.7, 0.72, 0.8)
const CLEAR := Color(0, 0, 0, 0)
const GLYPHES := {
	"A": [14, 17, 17, 31, 17, 17, 17], "B": [30, 17, 17, 30, 17, 17, 30], "C": [14, 17, 16, 16, 16, 17, 14],
	"D": [30, 17, 17, 17, 17, 17, 30], "E": [31, 16, 16, 30, 16, 16, 31], "F": [31, 16, 16, 30, 16, 16, 16],
	"G": [14, 17, 16, 23, 17, 17, 15], "H": [17, 17, 17, 31, 17, 17, 17], "I": [14, 4, 4, 4, 4, 4, 14],
	"J": [7, 2, 2, 2, 2, 18, 12], "K": [17, 18, 20, 24, 20, 18, 17], "L": [16, 16, 16, 16, 16, 16, 31],
	"M": [17, 27, 21, 21, 17, 17, 17], "N": [17, 25, 21, 19, 17, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14],
	"P": [30, 17, 17, 30, 16, 16, 16], "Q": [14, 17, 17, 17, 21, 18, 13], "R": [30, 17, 17, 30, 20, 18, 17],
	"S": [15, 16, 16, 14, 1, 1, 30], "T": [31, 4, 4, 4, 4, 4, 4], "U": [17, 17, 17, 17, 17, 17, 14],
	"V": [17, 17, 17, 17, 17, 10, 4], "W": [17, 17, 17, 21, 21, 27, 17], "X": [17, 17, 10, 4, 10, 17, 17],
	"Y": [17, 17, 10, 4, 4, 4, 4], "Z": [31, 1, 2, 4, 8, 16, 31],
	"0": [14, 17, 19, 21, 25, 17, 14], "1": [4, 12, 4, 4, 4, 4, 14], "2": [14, 17, 1, 2, 4, 8, 31],
	"3": [30, 1, 1, 14, 1, 1, 30], "4": [2, 6, 10, 18, 31, 2, 2], "5": [31, 16, 30, 1, 1, 17, 14],
	"6": [6, 8, 16, 30, 17, 17, 14], "7": [31, 1, 2, 4, 8, 8, 8], "8": [14, 17, 17, 14, 17, 17, 14],
	"9": [14, 17, 17, 15, 1, 2, 12], "-": [0, 0, 0, 31, 0, 0, 0], " ": [0, 0, 0, 0, 0, 0, 0],
	"#": [10, 31, 10, 10, 31, 10, 0], "/": [1, 2, 2, 4, 8, 8, 16], ".": [0, 0, 0, 0, 0, 12, 12],
	":": [0, 12, 12, 0, 12, 12, 0], "+": [0, 4, 4, 31, 4, 4, 0], "(": [2, 4, 8, 8, 8, 4, 2], ")": [8, 4, 2, 2, 2, 4, 8],
}

var P := {}  # nom -> Array[Color]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier: String = args[0] if args.size() > 0 else "res://captures/bible"
	for r in RAMPES:
		var l: Array = []
		for h in r[1]:
			l.append(Color(h))
		P[r[0]] = l
	var a := echantillon_a(64, 7)
	var b := tuile_neige()
	var c := tuile_pietinee()
	var d := tuile_ecorce()
	var e := tuile_planches()
	var f := tuile_pierre()
	var scene := mise_en_situation(b, d)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	var planche := assembler(a, b, c, d, e, f, scene)
	planche.save_png("%s/planche_palette.png" % dossier)
	print("planche %dx%d" % [planche.get_width(), planche.get_height()])
	var det := {"a": a, "b": b, "c": c, "d": d, "e": e, "f": f}
	for k in det:
		_agrandi(det[k], 8).save_png("%s/echantillon_%s.png" % [dossier, k])
	_agrandi(scene, 4).save_png("%s/mise_en_situation.png" % dossier)
	quit()

# ---------------------------------------------------------------- outils d'image
func col(nom: String, i: int) -> Color:
	var l: Array = P[nom]
	return l[clampi(i, 0, l.size() - 1)]

func nb(nom: String) -> int:
	return (P[nom] as Array).size()

func _agrandi(img: Image, k: int) -> Image:
	var o := Image.create(img.get_width() * k, img.get_height() * k, false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			o.fill_rect(Rect2i(x * k, y * k, k, k), img.get_pixel(x, y))
	return o

func nouvelle(w: int, h: int, fond: Color = CLEAR) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fond)
	return img

## pose un pixel ; `wrap` = tuile (bords qui bouclent), sinon rognage.
func px(img: Image, x: int, y: int, c: Color, wrap: bool = false) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if wrap:
		x = posmod(x, w)
		y = posmod(y, h)
	elif x < 0 or y < 0 or x >= w or y >= h:
		return
	img.set_pixel(x, y, c)

func ligne(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color, wrap: bool = false) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		px(img, x0, y0, c, wrap)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

## Filtre « mode » : un pixel isolé prend la couleur dominante de ses voisins (supprime le sel-et-poivre).
func lisser(img: Image, wrap: bool, seuil: int = 2) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var same := 0
			var cnt := {}
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if wrap:
					nx = posmod(nx, w)
					ny = posmod(ny, h)
				elif nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var n := src.get_pixel(nx, ny)
				if n.a == 0.0:
					continue
				if n == c:
					same += 1
				cnt[n] = int(cnt.get(n, 0)) + 1
			if same < 1:
				var best := c
				var bn := 0
				for k in cnt:
					if cnt[k] > bn:
						bn = cnt[k]
						best = k
				if bn >= seuil:
					img.set_pixel(x, y, best)

# ---------------------------------------------------------------- a) rameau d'épicéa enneigé
## Carte de feuillage S×S : tige centrale, rameaux alternés, aiguilles en traits groupés (3 passes : ombre,
## corps, lumière), neige en paquets sur le dessus, bord net, contour sélectif sous la masse.
func echantillon_a(S: int, graine: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var k := S / 64.0
	var img := nouvelle(S, S)
	var traits: Array = []   # [ton, x0, y0, x1, y1]
	var rameaux: Array = []  # chaque rameau : liste de points [x, y, s]
	var pas := maxf(5.2 * k, 4.0)
	var y := S - 4.0
	var i := 0
	while y > 6.0 * k:
		var t := (S - 4.0 - y) / (S - 4.0 - 6.0 * k)
		var sx: float = S * 0.5 + 2.2 * k * sin(t * 2.6 + 0.5)
		var longueur := (27.0 * pow(1.0 - t, 0.85) + 5.0) * k
		for cote in [-1, 1]:
			var l := longueur * rng.randf_range(0.68, 1.08)
			if rng.randf() < 0.12:
				l *= 0.5
			var ang := deg_to_rad(lerpf(52.0, 28.0, t) + rng.randf_range(-9, 9))  # écart avec l'axe de la tige
			var pts: Array = []
			var px_ := sx
			var py_ := y - (0.0 if cote < 0 else 2.0 * k)
			var n := int(l)
			for s in n:
				pts.append([px_, py_, float(s) / maxf(n - 1, 1)])
				var a2 := ang * (1.0 - 0.28 * float(s) / n)
				px_ += cote * sin(a2)
				py_ += -cos(a2) + 0.03 * s  # le bout retombe
			rameaux.append(pts)
		y -= pas * (1.0 + 0.1 * sin(i * 1.9))
		i += 1
	# pointe terminale : petit bouquet dressé
	var tip: Array = []
	for s in int(9 * k):
		tip.append([S * 0.5 + 2.2 * k * sin(1.0 * 2.6 + 0.5) + 0.2 * s, 7.0 * k + 9 * k - s, 0.3])
	# tige
	var tige: Array = []
	for yy in range(S - 2, int(5 * k), -1):
		var t2 := (S - 2.0 - yy) / (S - 7.0 * k)
		tige.append([S * 0.5 + 2.2 * k * sin(t2 * 2.6 + 0.5), float(yy)])
	# aiguilles : par rameau, amas (cluster) pilotés par une onde lente
	for pts in rameaux + [tip]:
		var ph := rng.randf() * 6.28
		var n: int = pts.size()
		for j in n:
			var p: Array = pts[j]
			var s: float = p[2]
			var nx0: float = pts[mini(j + 1, n - 1)][0] - pts[maxi(j - 1, 0)][0]
			var ny0: float = pts[mini(j + 1, n - 1)][1] - pts[maxi(j - 1, 0)][1]
			var h0 := atan2(ny0, nx0)
			var clump := 0.5 + 0.5 * sin(j * 0.55 + ph)
			for cote in [-1, 1]:
				var longueur2 := (3.0 + 2.6 * clump) * (0.75 + 0.5 * k) * (1.0 - 0.3 * s)
				var a3: float = h0 + cote * deg_to_rad(rng.randf_range(42, 66)) + 0.35
				var dx := cos(a3) * longueur2
				var dy := sin(a3) * longueur2
				# ton : face vers le haut = clair, vers le bas = sombre ; bouts givrés
				var haut := -sin(a3)
				var ton := 1.5 + haut * 1.9 + (clump - 0.5) * 1.8 + s * 0.8
				ton = float(clampi(roundi(ton), 0, 4))
				if s > 0.8 and haut > 0.2 and clump > 0.45:
					ton = 4.0
				traits.append([int(ton), p[0], p[1], p[0] + dx, p[1] + dy])
	traits.sort_custom(func(u, v): return u[0] < v[0])
	# couche d'ombre sous tout (rameaux épais)
	for pts in rameaux:
		for j in pts.size():
			var p: Array = pts[j]
			var w := 1.3 * k * (1.0 - 0.5 * float(p[2]))
			for dy in range(0, int(ceil(w)) + 1):
				px(img, roundi(p[0]), roundi(p[1]) + dy, col("EPICEA AIGUILLES", 1))
	for t in traits:
		ligne(img, roundi(t[1]), roundi(t[2]), roundi(t[3]), roundi(t[4]), col("EPICEA AIGUILLES", t[0]))
	# tige + rameaux (bois)
	for p in tige:
		px(img, roundi(p[0]), roundi(p[1]), col("EPICEA ECORCE", 1))
	for pts in rameaux:
		for p in pts:
			px(img, roundi(p[0]), roundi(p[1]), col("EPICEA ECORCE", 0))
	# neige : paquets sur le dessus des rameaux
	var neige_cases: Array = []
	for pts in rameaux:
		var n: int = pts.size()
		if n < 8:
			continue
		var lumps := 1 if n > 14 else 0
		if rng.randf() < 0.35:
			lumps += 1
		for q in lumps:
			var cx := rng.randf_range(0.12, 0.7) * n
			var hw := rng.randf_range(2.6, 4.2) * k
			var hh := rng.randf_range(1.6, 2.6) * (0.8 + 0.4 * k)
			for j in range(maxi(int(cx - hw), 0), mini(int(cx + hw) + 1, n)):
				var p: Array = pts[j]
				var u := (j - cx) / hw
				var top := hh * sqrt(maxf(1.0 - u * u, 0.0)) * (1.0 - 0.45 * float(p[2]))
				var ht := roundi(top)
				for d in range(-ht, 2):
					var cy := roundi(p[1]) + d
					var rel := float(d + ht) / float(maxi(ht + 2, 1))  # 0 haut … 1 bas
					var ton := 5 if rel < 0.25 else (4 if rel < 0.62 else (3 if rel < 0.85 else 2))
					if j - cx < -hw * 0.45 and ton == 4:
						ton = 5  # reflet côté lumière
					neige_cases.append([roundi(p[0]), cy, ton])
	for c in neige_cases:
		px(img, c[0], c[1], col("NEIGE", c[2]))
	# tige enneigée : fine crête
	for j in range(0, tige.size(), 1):
		if (j / 9) % 3 == 1 and j > 12:
			var p: Array = tige[j]
			px(img, roundi(p[0]) - 1, roundi(p[1]), col("NEIGE", 4))
	nettoyer_sprite(img, "EPICEA AIGUILLES")
	return img

## Orphelins supprimés, petits trous bouchés, contour sélectif sombre sous la masse.
func nettoyer_sprite(img: Image, nom_contour: String) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for passe in 2:
		var src := img.duplicate() as Image
		for y in h:
			for x in w:
				var c := src.get_pixel(x, y)
				var voisins := 0
				var d4 := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.0:
							voisins += 1
							if dx == 0 or dy == 0:
								d4 += 1
				if c.a > 0.0 and voisins <= 1:
					img.set_pixel(x, y, CLEAR)
				elif c.a == 0.0 and d4 >= 3:
					# trou : on prend la couleur la plus sombre des voisins
					var best := Color(1, 1, 1, 1)
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nx: int = x + d.x
						var ny: int = y + d.y
						if nx >= 0 and ny >= 0 and nx < w and ny < h:
							var n := src.get_pixel(nx, ny)
							if n.a > 0.0 and n.get_luminance() < best.get_luminance():
								best = n
					img.set_pixel(x, y, best)
	# contour : pixel d'aiguille sans voisin opaque dessous -> ton le plus sombre (sauf neige)
	var src2 := img.duplicate() as Image
	var sombre := col(nom_contour, 0)
	for y in h - 1:
		for x in w:
			var c := src2.get_pixel(x, y)
			if c.a > 0.0 and src2.get_pixel(x, y + 1).a == 0.0 and not _est_neige(c):
				img.set_pixel(x, y, sombre)

func _est_neige(c: Color) -> bool:
	return c.b > c.r + 0.05 and c.get_luminance() > 0.4

# ---------------------------------------------------------------- champs périodiques pour les tuiles
func _onde(x: float, y: float, n: int, fx: int, fy: int, ph: float) -> float:
	return sin(TAU * (float(fx * x + fy * y) / n) + ph)

# b) neige fraîche : grandes plaques tassées par le vent (2 tons proches) + petites dunes en croissant (sastrugi)
func tuile_neige() -> Image:
	var N := 32
	var img := nouvelle(N, N, Color.WHITE)
	for y in N:
		for x in N:
			var f := 0.55 * sin(TAU * (x * 1.0 / N) + 0.7 + 1.6 * sin(TAU * y / N)) + 0.45 * sin(TAU * (2.0 * y / N + x * 1.0 / N) + 2.1)
			var ton := 4
			if f < -0.5:
				ton = 3
			elif f > 0.7:
				ton = 5
			img.set_pixel(x, y, col("NEIGE", ton))
	lisser(img, true)
	# dunes : [centre x, centre y, longueur, hauteur]
	for dn in [[7, 6, 14, 3], [24, 3, 10, 2], [20, 15, 15, 3], [4, 22, 11, 2], [16, 27, 13, 3], [29, 21, 8, 2]]:
		_dune(img, dn[0], dn[1], dn[2], dn[3])
	return img

## Croissant de neige soufflée : crête claire, face au vent douce, ombre froide sous le vent qui s'effile.
func _dune(img: Image, cx: int, cy: int, L: int, H: int) -> void:
	var demi := L / 2
	for lx in range(-demi, demi + 1):
		var t := float(lx) / demi
		var hc := int(round(H * (1.0 - t * t)))
		var arc := int(round(1.6 * t * t))
		var ycr := cy + arc - hc
		for d in range(0, hc + 1):
			var ton := 4
			if d == 0:
				ton = 5
			elif d == 1 and hc >= 3:
				ton = 5 if lx < 0 else 4
			px(img, cx + lx, ycr + d, col("NEIGE", ton), true)
		# ombre sous la dune, plus épaisse au centre
		var ombre := 1 + (1 if hc >= 2 else 0)
		for d in ombre:
			px(img, cx + lx, ycr + hc + 1 + d, col("NEIGE", 2 if d == 0 else 3), true)
		if hc >= 3 and lx > 0:
			px(img, cx + lx, ycr + hc + 3, col("NEIGE", 3), true)

# c) neige piétinée : base tassée et grisée, empreintes de bottes alternées (ombre haut-gauche, lèvre claire bas-droite)
func tuile_pietinee() -> Image:
	var N := 32
	var img := nouvelle(N, N, Color.WHITE)
	for y in N:
		for x in N:
			var w1 := 0.05 * _onde(x, y, N, 1, 0, 0.3) + 0.03 * _onde(x, y, N, 2, 1, 1.0)
			var u := float(y) / N + w1
			var v := 0.5 + 0.3 * sin(TAU * 2.0 * u + 0.2) + 0.14 * _onde(x, y, N, 3, 2, 0.5)
			img.set_pixel(x, y, col("NEIGE", 3 + clampi(int(v * 1.9), 0, 1)))
	# ornière de traîneau le long du bord gauche : creux + bourrelets
	for y in N:
		var x := 3 + int(round(1.0 * sin(TAU * y / N)))
		px(img, x, y, col("NEIGE", 2), true)
		px(img, x + 1, y, col("NEIGE", 3), true)
		px(img, x + 2, y, col("NEIGE", 4), true)
	_botte(img, 12, 3, 1)
	_botte(img, 24, 19, -1)
	lisser(img, true)
	return img

## Empreinte de botte 5×11 : creux avant + creux talon séparés par la cambrure.
func _botte(img: Image, cx: int, cy: int, sens: int) -> void:
	var cases: Array = []
	for j in 13:
		var l := 3 if j in [1, 2, 3, 4, 5] else 2
		if j == 0:
			l = 2
		if j in [6, 7]:
			continue
		if j in [8, 12]:
			l = 2
		if j in [9, 10, 11]:
			l = 3
		var decal := int(round(0.25 * sens * (j - 5)))
		for i in range(-l + 1, l):
			cases.append(Vector2i(cx + i + decal, cy + j))
	var set_ := {}
	for c in cases:
		set_[c] = true
	for c in cases:
		var haut_gauche: bool = not set_.has(Vector2i(c.x, c.y - 1)) or not set_.has(Vector2i(c.x - 1, c.y))
		px(img, c.x, c.y, col("NEIGE", 1) if haut_gauche else col("NEIGE", 2), true)
	for c in cases:
		if not set_.has(Vector2i(c.x + 1, c.y)):
			px(img, c.x + 1, c.y, col("NEIGE", 4), true)
		if not set_.has(Vector2i(c.x, c.y + 1)):
			px(img, c.x, c.y + 1, col("NEIGE", 5), true)

# d) écorce d'épicéa : plaques verticales séparées par des sillons sinueux
func tuile_ecorce() -> Image:
	var N := 32
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var img := nouvelle(N, N, Color.WHITE)
	var plaques := 4
	var bases := [2, 3, 1, 3]
	for y in N:
		for x in N:
			var w := 1.3 * _onde(x, y, N, 0, 1, 0.9) + 0.6 * _onde(x, y, N, 0, 2, 2.4)
			var u := (x + w) / N * plaques
			var cell := posmod(int(floor(u)), plaques)
			var f: float = u - floor(u)
			var base: int = bases[cell]
			var ton := base
			if f < 0.12 or f > 0.93:
				ton = 0        # sillon
			elif f < 0.26:
				ton = maxi(base - 1, 0)
			elif f > 0.52 and f < 0.72:
				ton = mini(base + 1, 4)   # crête de la plaque
			# cassures horizontales décalées d'une plaque à l'autre : l'écorce se détache en écailles
			if ton != 0 and (y == (cell * 9 + 5) % N or y == (cell * 13 + 20) % N):
				ton = 0
			elif ton != 0 and (y == (cell * 9 + 6) % N or y == (cell * 13 + 21) % N):
				ton = mini(base + 1, 4)
			img.set_pixel(x, y, col("EPICEA ECORCE", ton))
	# fissures transversales : courts tirets sombres à l'intérieur des plaques
	for p in [Vector2i(5, 7), Vector2i(14, 21), Vector2i(23, 12), Vector2i(29, 27), Vector2i(10, 29)]:
		for j in 3:
			px(img, p.x + j, p.y, col("EPICEA ECORCE", 0), true)
		px(img, p.x + 1, p.y + 1, col("EPICEA ECORCE", 4), true)
	# plaque de givre / lichen clair en amas
	for p in [Vector2i(18, 4), Vector2i(7, 17), Vector2i(26, 20)]:
		for j in 2:
			px(img, p.x, p.y + j, col("EPICEA ECORCE", 4), true)
		px(img, p.x + 1, p.y, col("EPICEA ECORCE", 4), true)
	lisser(img, true)
	return img

# e) planches de maison : 4 planches horizontales, veines en courbes, nœuds, joints décalés, clous
func tuile_planches() -> Image:
	var N := 32
	var img := nouvelle(N, N, Color.WHITE)
	var bases := [2, 3, 2, 3]
	var joints := [11, 25, 4, 19]
	var noeuds := {1: Vector2i(20, 3), 3: Vector2i(7, 4)}
	for r in 4:
		var y0 := r * 8
		var base: int = bases[r]
		var ph := r * 1.7
		for ly in 8:
			for x in N:
				var g := float(ly) + 1.5 * sin(TAU * 2.0 * x / N + ph) + 0.9 * sin(TAU * 5.0 * x / N + ph * 2.0)
				if noeuds.has(r):
					var nk: Vector2i = noeuds[r]
					var dxn := float(posmod(x - nk.x + 16, N) - 16)
					var dyn := float(ly - nk.y)
					g += 3.2 * exp(-(dxn * dxn / 14.0 + dyn * dyn / 5.0)) * signf(dyn if dyn != 0.0 else 1.0)
				var ton := base
				var fr := g * 0.62 + r * 0.31
				fr -= floor(fr)
				if fr < 0.2:
					ton = base - 1
				elif fr > 0.84:
					ton = base + 1
				if ly == 0:
					ton = 0                    # joint entre planches
				elif ly == 1:
					ton = mini(base + 1, 4)    # arête haute éclairée
				elif ly == 7:
					ton = maxi(base - 1, 0)    # ombre de recouvrement
				img.set_pixel(x, y0 + ly, col("BOIS TRAVAILLE", ton))
		if noeuds.has(r):
			var nk2: Vector2i = noeuds[r]
			for j in range(-2, 3):
				for i in range(-3, 4):
					var dd := float(i * i) / 9.0 + float(j * j) / 4.0
					var yy := y0 + nk2.y + j
					if dd < 0.3:
						px(img, nk2.x + i, yy, col("BOIS TRAVAILLE", 0), true)
					elif dd < 0.85:
						px(img, nk2.x + i, yy, col("BOIS TRAVAILLE", base - 1), true)
					elif dd < 1.35 and (i < 1 and j < 1):
						px(img, nk2.x + i, yy, col("BOIS TRAVAILLE", base + 1), true)
		var xj: int = joints[r]
		for ly in range(1, 8):
			px(img, xj, y0 + ly, col("BOIS TRAVAILLE", 0), true)
		for sgn in [-3, 4]:
			px(img, xj + sgn, y0 + 4, col("FER", 0), true)
			px(img, xj + sgn, y0 + 3, col("FER", 2), true)
	lisser(img, true)
	return img

# f) pierre sèche : assises irrégulières, pierres arrondies, joints sombres, arête haute claire
func tuile_pierre() -> Image:
	var N := 32
	var rng := RandomNumberGenerator.new()
	rng.seed = 521
	var img := nouvelle(N, N, col("PIERRE", 0))
	var hauteurs := [9, 7, 8, 8]
	var y0 := 0
	for r in 4:
		var hh: int = hauteurs[r]
		var coupes: Array = []
		var x := 3 + r * 6
		var cuts: Array = []
		while x < 3 + r * 6 + N - 8:
			cuts.append(x)
			x += rng.randi_range(8, 12)
		cuts.append(3 + r * 6 + N)
		for ci in cuts.size() - 1:
			var xa: int = cuts[ci]
			var xb: int = cuts[ci + 1]
			var base := rng.randi_range(2, 3)
			if ci % 3 == 1:
				base = 1
			_pierre_pose(img, xa, y0, xb - xa, hh, base, rng)
		y0 += hh
	lisser(img, true)
	return img

func _pierre_pose(img: Image, xa: int, ya: int, w: int, h: int, base: int, rng: RandomNumberGenerator) -> void:
	# la pierre occupe [xa+1, xa+w) × [ya+1, ya+h) ; le joint (1 px) est à gauche et en haut
	var iw := w - 1
	var ih := h - 1
	for ly in ih:
		for lx in iw:
			var coin := (ly == 0 or ly == ih - 1) and (lx == 0 or lx == iw - 1)
			if coin:
				continue
			var ton := base
			if ly == 0 or lx == 0:
				ton = base + 1          # arête éclairée haut/gauche
			elif ly == ih - 1 or lx == iw - 1:
				ton = base - 1          # ombre bas/droite
			elif ly >= ih - 3 and lx > iw / 3:
				ton = base - 1          # creux d'ombre douce sous la pierre
			px(img, xa + 1 + lx, ya + 1 + ly, col("PIERRE", clampi(ton, 0, 4)), true)
	# reflet : amas de 2-3 px sur l'arête haute ; fissure en diagonale sur une pierre sur deux
	var rx := xa + 3 + rng.randi_range(0, maxi(iw - 6, 1))
	for d in 3:
		px(img, rx + d, ya + 2, col("PIERRE", clampi(base + 2, 0, 4)), true)
	if (xa + ya) % 2 == 0:
		var fx := xa + 2 + rng.randi_range(2, maxi(iw - 4, 3))
		for d in 3:
			px(img, fx + d, ya + 3 + d, col("PIERRE", clampi(base - 2, 0, 4)), true)

# ---------------------------------------------------------------- mise en situation (nuit simulée)
func mise_en_situation(neige: Image, ecorce: Image) -> Image:
	var W := 176
	var H := 116
	var img := nouvelle(W, H, Color.BLACK)
	var haut := Color(0.008, 0.012, 0.035)
	var hor := Color(0.07, 0.1, 0.17)
	for y in H:
		for x in W:
			var t := float(y) / 70.0
			var c := haut.lerp(hor, clampf(t, 0, 1))
			# aurore : ruban vert qui vire au violet en hauteur, bandes verticales
			var by := 28.0 + 8.0 * sin(x * 0.045) + 3.0 * sin(x * 0.17)
			var dy := float(y) - by
			if dy > -45.0 and dy < 35.0:
				var a := exp(-pow((dy + 4.0) / 10.0, 2.0)) * (0.55 + 0.45 * sin(x * 0.9 + sin(x * 0.2) * 2.0))
				var k := clampf((-dy + 6.0) / 28.0, 0, 1)
				c = c.lerp(Color(0.15, 1.0, 0.55).lerp(Color(0.55, 0.2, 0.95), k), clampf(a, 0, 1) * 0.55)
			img.set_pixel(x, y, Color(minf(c.r * 1.75, 1.0), minf(c.g * 1.6, 1.0), minf(c.b * 1.1, 1.0)))  # compense la teinte de nuit appliquée après
	# étoiles
	for p in [Vector2i(12, 8), Vector2i(40, 20), Vector2i(77, 6), Vector2i(120, 14), Vector2i(150, 5), Vector2i(165, 24), Vector2i(98, 30)]:
		img.set_pixel(p.x, p.y, Color(0.85, 0.9, 1.0))
	# sol : tuile neige répétée, pente de brume vers l'horizon
	var sol0 := 66
	for y in range(sol0, H):
		for x in W:
			img.set_pixel(x, y, neige.get_pixel(x % 32, (y - sol0 + 5) % 32))
	# brume bleue au pied de l'horizon
	for y in range(sol0, sol0 + 14):
		for x in W:
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.52, 0.58, 0.8), 0.55 * (1.0 - float(y - sol0) / 14.0)))
	# silhouettes de forêt lointaine (arbres pointus sombres, 1 ton)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var xx := 0
	while xx < W:
		var hh := rng.randi_range(14, 26)
		var ww := rng.randi_range(4, 7)
		for j in hh:
			var half := int(round(float(ww) * (float(j) / hh) * 0.9))
			for i in range(-half, half + 1):
				px(img, xx + i, sol0 - hh + j + 2, col("EPICEA AIGUILLES", 0))
		xx += rng.randi_range(5, 9)
	for y in range(sol0 + 2, H):
		for x in W:
			if img.get_pixel(x, y).get_luminance() < 0.03:
				pass
	# sapin « croisé » : 3 cartes a) droites (tailles 64/56/48, l'une retournée), tronc d'écorce derrière
	var cx := 88
	var base_y := 104
	for y in range(base_y - 30, base_y):
		for i in range(-2, 3):
			img.set_pixel(cx + i, y, ecorce.get_pixel(posmod(cx + i, 32), posmod(y, 32)))
	var cartes := [[56, 76, 103, true, 11], [48, 104, 104, false, 17], [64, 90, 105, false, 7]]
	for et in cartes:
		var taille: int = et[0]
		var carte := echantillon_a(taille, int(et[4]))
		if et[3]:
			carte.flip_x()
		var x0: int = int(et[1]) - taille / 2
		var y0: int = int(et[2]) - taille
		img.blend_rect(carte, Rect2i(0, 0, taille, taille), Vector2i(x0, y0))
	# lumière de nuit : teinte lune froide, ombres violettes, léger éclaircissement vers l'horizon
	for y in range(sol0 - 40, H):
		for x in W:
			var c := img.get_pixel(x, y)
			if y >= sol0 - 40 and c.get_luminance() > 0.0:
				pass
	var lune := Color(0.56, 0.62, 0.9)
	var amb := Color(0.2, 0.17, 0.4)
	for y in range(0, H):
		for x in W:
			var c := img.get_pixel(x, y)
			var lum := c.get_luminance()
			var o := Color(c.r * lune.r, c.g * lune.g, c.b * lune.b)
			o = o.lerp(amb, 0.2 * (1.0 - clampf(lum * 1.8, 0, 1)))
			# brume bleue vers le fond de la scène (haut du sol)
			var brume := clampf(1.0 - float(y - (sol0 - 44)) / 70.0, 0, 1) * 0.0
			img.set_pixel(x, y, o.lerp(Color(0.1, 0.14, 0.22), brume))
	# quelques flocons (amas de 1 px, pas de bruit)
	for p in [Vector2i(20, 50), Vector2i(60, 40), Vector2i(130, 56), Vector2i(150, 36), Vector2i(34, 82), Vector2i(158, 90)]:
		img.set_pixel(p.x, p.y, Color(0.8, 0.88, 1.0))
	return img

# ---------------------------------------------------------------- assemblage de la planche
func texte(img: Image, s: String, pos: Vector2i, k: int = 2, c: Color = TEXTE) -> void:
	var x := pos.x
	for ch in s:
		var g: Array = GLYPHES.get(ch, GLYPHES[" "])
		for ligne_ in 7:
			for cc in 5:
				if (int(g[ligne_]) >> (4 - cc)) & 1:
					img.fill_rect(Rect2i(x + cc * k, pos.y + ligne_ * k, k, k), c)
		x += 6 * k

func blit_agrandi(dst: Image, src: Image, pos: Vector2i, k: int) -> void:
	var g := _agrandi(src, k)
	dst.blend_rect(g, Rect2i(Vector2i.ZERO, g.get_size()), pos)

func mosaique(src: Image, n: int) -> Image:
	var w := src.get_width()
	var m := nouvelle(w * n, src.get_height() * n)
	for j in n:
		for i in n:
			m.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(i * w, j * src.get_height()))
	return m

func damier(w: int, h: int) -> Image:
	var d := nouvelle(w, h, Color(0.16, 0.16, 0.2))
	for y in range(0, h, 8):
		for x in range(0, w, 8):
			if ((x + y) / 8) % 2 == 0:
				d.fill_rect(Rect2i(x, y, 8, 8), Color(0.2, 0.2, 0.25))
	return d

func assembler(a: Image, b: Image, c: Image, d: Image, e: Image, f: Image, scene: Image) -> Image:
	var W := 1900
	var out := nouvelle(W, 1990, FOND)
	texte(out, "BIBLE VISUELLE - PALETTE MAITRESSE (OMBRES FROIDES/VIOLETTES A LUMIERES CHAUDES)", Vector2i(20, 14), 3)
	var y0 := 56
	for i in RAMPES.size():
		var colonne := i / 8
		var ligne_ := i % 8
		var x := 20 + colonne * 625
		var y := y0 + ligne_ * 50
		texte(out, RAMPES[i][0], Vector2i(x, y + 2), 2, TEXTE)
		var l: Array = P[RAMPES[i][0]]
		for j in l.size():
			out.fill_rect(Rect2i(x + j * 48, y + 18, 46, 18), l[j])
			texte(out, String(RAMPES[i][1][j]).to_upper(), Vector2i(x + j * 48, y + 38), 1, TEXTE2)
		# la liste est affichée : gauche = ombre
	# ---- échantillon a + mise en situation
	var ya := y0 + 8 * 50 + 24
	texte(out, "A) RAMEAU D EPICEA ENNEIGE 64X64 (X8)  -  CARTE ALPHA, 5 TONS + NEIGE", Vector2i(20, ya), 2)
	var fond_a := damier(512, 512)
	out.blit_rect(fond_a, Rect2i(0, 0, 512, 512), Vector2i(20, ya + 26))
	blit_agrandi(out, a, Vector2i(20, ya + 26), 8)
	texte(out, "MOSAIQUE 3X3 (X2)", Vector2i(560, ya + 26), 2, TEXTE2)
	var mo := mosaique(a, 3)
	out.blit_rect(damier(384, 384), Rect2i(0, 0, 384, 384), Vector2i(560, ya + 50))
	blit_agrandi(out, mo, Vector2i(560, ya + 50), 2)
	texte(out, "MISE EN SITUATION NUIT (X4) - 3 ETAGES DE CARTES", Vector2i(970, ya + 26), 2, TEXTE2)
	blit_agrandi(out, scene, Vector2i(970, ya + 50), 4)
	# ---- tuiles
	var tuiles := [
		["B) NEIGE FRAICHE 32X32", b], ["C) NEIGE PIETINEE + TRACES", c], ["D) ECORCE D EPICEA",d],
		["E) PLANCHES DE MAISON", e], ["F) PIERRE SECHE", f],
	]
	var yt := ya + 26 + 512 + 30
	for i in tuiles.size():
		var col_ := i % 3
		var row := i / 3
		var x := 20 + col_ * 625
		var y := yt + row * 330
		texte(out, tuiles[i][0], Vector2i(x, y), 2)
		blit_agrandi(out, tuiles[i][1], Vector2i(x, y + 24), 8)
		texte(out, "3X3 (X3)", Vector2i(x + 270, y + 24), 1, TEXTE2)
		blit_agrandi(out, mosaique(tuiles[i][1], 3), Vector2i(x + 270, y + 36), 3)
		texte(out, "3X3 (X1)", Vector2i(x + 270, y + 36 + 296), 1, TEXTE2) if false else null
	# légende a-f (mosaïques x1) en bas à droite
	var xl := 20 + 2 * 625 + 270 - 270
	var yl := yt + 330 + 24
	texte(out, "MOSAIQUES X1 (TAILLE REELLE)", Vector2i(xl, yl - 22), 1, TEXTE2)
	var mx := xl
	for t in [b, c, d, e, f]:
		out.blend_rect(mosaique(t, 3), Rect2i(0, 0, 96, 96), Vector2i(mx, yl))
		mx += 104
	return out.get_region(Rect2i(0, 0, W, yt + 2 * 330 + 10))
