extends Node3D
## Look-dev « Guerrier nordique » (essai de faisabilité, PAS l'intégration ; aucun script de personnage touché).
## Trois échantillons statiques (buste + épaule de fourrure + bouclier + cape), même éclairage que le village :
##   A : textures peintes par code à la densité visée (64 texels/m, atlas 128²), palette limitée, contours sombres et ombrage cuits,
##       géométrie bas-poly ; fourrure = bord dentelé découpé dans la texture.
##   B : même géométrie, mêmes dessins à 128 texels/m (atlas 256²) + carte de relief (normales par texel) ;
##   C : textures de B sans relief, mais fourrure en MÈCHES géométriques et bouclier modelé (Blender, guerrier_c.glb).
## Tout passe par le shader « ps1 » (outils/lookdev_ps1.gdshader = partie personnage de ps1.gdshader : accroche des sommets,
## mapping affine, texels nets ; mipmaps pixel art en option). Sol et mur de fond : vrai shaders/ps1.gdshader.
## Lancement (fenêtre, 640×360) :
##   godot --path <wt> --disable-vsync --scene res://outils/lookdev_guerrier.tscn -- --sortie=<dossier> [--perf] [--sans-captures]

const CYCLE := preload("res://scripts/cycle.gd")
const CIEL := preload("res://shaders/ciel_nuit.gdshader")
const POST := preload("res://shaders/ps1_post.gdshader")
const PS1 := preload("res://shaders/ps1.gdshader")
const LOOK := preload("res://outils/lookdev_ps1.gdshader")
const GLB_C := "res://assets/modeles/lookdev/guerrier_c.glb"

const RES := Vector2i(640, 360)
const ATLAS_M := 2.0          # l'atlas couvre 2 m × 2 m (UV métriques)
const DENS_A := 64          # budget visé par l'audit : 64 texels/m (atlas 128²)
const DENS_B := 128

# rampes (sombre → clair) : ombres froides, lumières chaudes ; 4-6 tons par matière
const MAILLE := ["#121319", "#25272f", "#3e414b", "#60636c", "#8c8e95", "#b9b9bb"]
const ROUILLE := ["#24150f", "#472816", "#6e4322", "#94622f"]
const CUIR := ["#160f0c", "#2b1d16", "#45301f", "#634630", "#82603f"]
const FOUR := ["#1b1a1d", "#36322f", "#585048", "#7f766a", "#a89e8e", "#cfc6b4"]
const BOIS := ["#17120f", "#2c231c", "#463a2f", "#625243", "#81705c"]
const BLEU := ["#121829", "#1d2843", "#2c3d61", "#465a82", "#6a80a4"]
const CREME := ["#4a4234", "#7a6c55", "#a8977a", "#cbbb9c"]
const FER := ["#121216", "#26262c", "#41414a", "#64646d", "#93939a", "#c0c0c2"]
const CAPE := ["#0d1224", "#18213d", "#253465", "#364b88", "#5069a6"]
const PEAU := ["#3a2420", "#6a4434", "#966a52", "#c09274", "#e0b896"]
const POIL := ["#24170e", "#462b16", "#714823", "#9e6e38", "#c89a5c"]
const NEIGE := ["#7d8cab", "#8e9cba", "#a2afca", "#b7c2d9", "#cbd4e6"]
const PLANCHES := ["#15100c", "#221a13", "#30251b", "#3f3125"]

# régions de l'atlas (m) : x, y, largeur, hauteur
const R_TORSE := Rect2(0.0, 0.0, 1.25, 0.80)
const R_BRAS := Rect2(0.0, 0.82, 0.40, 0.34)
const R_FOUR := Rect2(0.42, 0.82, 1.50, 0.38)
const R_BOUC := Rect2(0.0, 1.22, 0.78, 0.78)
const R_CAPE := Rect2(0.85, 1.22, 0.60, 0.76)
const R_TETE := Rect2(1.40, 0.0, 0.60, 0.32)
const R_DOS := Rect2(1.50, 1.22, 0.50, 0.50)
const C_TORSE := 1.20         # circonférence de référence du torse (u du dépliage)
const C_FOUR := 1.50
const C_TETE := 0.60
const C_BRAS := 0.40
const RB := 0.38              # rayon du bouclier

var post: ShaderMaterial      # lu par cycle.gd (_etalonner)
var cycle: Node
var env: Environment
var soleil: DirectionalLight3D
var torche: OmniLight3D
var camera: Camera3D
var echantillons := {}        # nom -> Node3D
var stats := {}               # nom -> {triangles, textures}
var sortie := ""
var args := {}

# ------------------------------------------------------------------ outils
static func _h(x: int, y: int, g: int) -> float:
	var n := (x * 374761393 + y * 668265263 + g * 2147483647) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65536.0

static func _bruit(x: float, y: float, g: int) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(_h(ix, iy, g), _h(ix + 1, iy, g), fx), lerpf(_h(ix, iy + 1, g), _h(ix + 1, iy + 1, g), fx), fy)

static func _c(r: Array, i: int) -> Color:
	return Color(r[clampi(i, 0, r.size() - 1)])

# ------------------------------------------------------------------ peinture (une seule fonction, densité d)
## Peint l'atlas complet à `d` texels/m. Les motifs gardent une taille en texels (anneaux, rivets, mèches) :
## à 48 texels/m ils deviennent grossiers, à 128 texels/m ils ont la finesse de la référence.
func peindre_atlas(d: int) -> Image:
	var n := int(ATLAS_M * d)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_torse(img, d)
	_bras(img, d)
	_fourrure(img, d, R_FOUR, true)
	_bouclier(img, d, int(R_BOUC.position.x * d), int(R_BOUC.position.y * d), int(2 * RB * d), true)
	_dos_bouclier(img, d)
	_cape(img, d)
	_tete(img, d)
	return img

func _maille(x: int, y: int, d: int) -> int:
	# anneaux 3×2 texels (2×2 à faible densité), rangs décalés : reflet en haut à gauche, creux en bas à droite
	var rw := 3 if d >= 96 else 2
	var rh := 2
	var row := y / rh
	var xo := x + (row % 2) * (rw / 2 + (1 if rw == 3 else 1))
	var lx := xo % rw
	var ly := y % rh
	if rw == 3:
		return [[3, 2, 1], [2, 1, 0]][ly][lx]
	return [[3, 1], [1, 0]][ly][lx]

func _torse(img: Image, d: int) -> void:
	var x0 := int(R_TORSE.position.x * d)
	var y0 := int(R_TORSE.position.y * d)
	var w := int(R_TORSE.size.x * d)
	var h := int(R_TORSE.size.y * d)
	var cx := int(C_TORSE * 0.5 * d)        # milieu du devant
	var pl := int(0.165 * d)                # demi-largeur du plastron
	var p_haut := int(0.16 * d)
	var p_bas := int(0.50 * d)
	var c_haut := int(0.50 * d)              # ceinture
	var c_bas := int(0.56 * d)
	var dos := int(0.0 * d)
	for y in h:
		for x in w:
			var vm := float(y) / d
			var ombre := 0
			if vm > 0.62: ombre = -1                       # sous la ceinture
			if vm < 0.12: ombre = -1                       # sous la fourrure
			var dx := absi(x - cx)
			var dxd := mini(absi(x - dos), absi(x - w))   # dos (u = 0 = w)
			var col: Color
			var plastron := (dx <= pl and y >= p_haut and y < p_bas) or (dxd <= pl and y >= p_haut and y < p_bas)
			var ceinture := y >= c_haut and y < c_bas
			# baudrier : de l'épaule gauche (devant, x > cx) à la hanche droite
			var t := float(y - p_haut) / float(c_haut - p_haut)
			var bx := int(lerpf(cx + pl * 0.9, cx - pl * 1.1, t))
			var baud := y >= int(0.10 * d) and y < c_haut and absi(x - bx) <= maxi(1, int(0.022 * d))
			if ceinture:
				var tc := 2
				if y == c_haut or y == c_bas - 1: tc = 0
				elif y == c_haut + 1: tc = 4
				if _h(x, y, 31) < 0.08: tc -= 1
				# boucle ronde (fer) au milieu du devant
				var bd := Vector2(x - cx, y - (c_haut + c_bas) * 0.5).length()
				if bd < 0.035 * d:
					var tf := 3 if (x - cx) + (y - (c_haut + c_bas) * 0.5) < 0 else 2
					if bd > 0.035 * d - 1.1: tf = 0
					if d >= 96 and bd < 0.02 * d and (x + y) % 2 == 0: tf = 1
					col = _c(FER, tf)
				else:
					col = _c(CUIR, tc)
				# rivets de laiton de la ceinture, tous les ~4 cm
				if y == (c_haut + c_bas) / 2 and x % maxi(3, int(0.04 * d)) == 0 and bd >= 0.035 * d:
					col = _c(CREME, 3)
			elif baud:
				var tb := 2 + (1 if x < bx else 0)
				if absi(x - bx) == maxi(1, int(0.022 * d)): tb = 0
				if d >= 96 and absi(x - bx) == 0 and y % 3 == 0: tb = 3
				col = _c(CUIR, tb + ombre)
			elif plastron:
				var ddx := mini(dx, dxd)
				var bord := (pl - ddx) <= 0 or y == p_haut or y == p_bas - 1
				var tp := 2
				var patch := _bruit(x * 0.18, y * 0.18, 5)
				if patch > 0.76: tp = 3
				elif patch < 0.22: tp = 1
				# plis horizontaux du cuir (cuits) et lumière en haut du plastron
				if y < p_haut + int(0.05 * d): tp += 1
				if y > p_bas - int(0.06 * d): tp -= 1
				if bord:
					tp = 0
				elif (pl - ddx) == 1 or y == p_haut + 1:
					tp = 4
				col = _c(CUIR, tp + ombre)
				# rivets le long des bords
				var ins := maxi(2, int(0.018 * d))
				var pas := maxi(4, int(0.045 * d))
				if not bord and ((pl - ddx) == ins and y % pas == 0) or (y == p_haut + ins and ddx % pas == 0 and ddx < pl - 1):
					col = _c(FER, 4)
				elif not bord and ((pl - ddx) == ins and y % pas == 1) or (y == p_haut + ins + 1 and ddx % pas == 0 and ddx < pl - 1):
					col = _c(CUIR, 0)
				# coutures (seulement si la densité le permet)
				if d >= 96 and (pl - ddx) == ins + 3 and y % 2 == 0 and y > p_haut + 3 and y < p_bas - 3:
					col = _c(CUIR, 3)
			else:
				var tm := _maille(x, y, d) + 1 + ombre
				if absi(x - cx) == pl + 1 or (dxd == pl + 1 and y >= p_haut and y < p_bas): tm = 0  # contour sous le plastron
				if y == c_bas: tm = 0
				col = _c(MAILLE, tm)
				if _bruit(x * 0.07, y * 0.07, 9) > 0.80 and _maille(x, y, d) >= 2:
					col = _c(ROUILLE, _maille(x, y, d))
			img.set_pixel(x0 + x, y0 + y, col)

func _bras(img: Image, d: int) -> void:
	var x0 := int(R_BRAS.position.x * d)
	var y0 := int(R_BRAS.position.y * d)
	for y in int(R_BRAS.size.y * d):
		for x in int(R_BRAS.size.x * d):
			var tm := _maille(x, y, d) + 1
			if y < int(0.04 * d): tm -= 1           # sous la fourrure
			if y > int(0.28 * d):                   # brassard de cuir au coude
				var tc := 2 if (y + x / 3) % 4 != 0 else 1
				if y == int(0.28 * d) + 1: tc = 0
				img.set_pixel(x0 + x, y0 + y, _c(CUIR, tc))
				continue
			var col := _c(MAILLE, tm)
			if _bruit(x * 0.08, y * 0.08, 19) > 0.82 and _maille(x, y, d) >= 2:
				col = _c(ROUILLE, _maille(x, y, d))
			img.set_pixel(x0 + x, y0 + y, col)

## Fourrure en mèches peintes : fond sombre, mèches tracées de haut en bas (racine sombre → pointe claire), chaque mèche
## bordée à gauche d'un texel sombre ; en bas, le bord dentelé suit les pointes (transparent au-delà) si `dentele`.
func _fourrure(img: Image, d: int, r: Rect2, dentele: bool, g := 1) -> void:
	var x0 := int(r.position.x * d)
	var y0 := int(r.position.y * d)
	var w := int(r.size.x * d)
	var h := int(r.size.y * d)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + g
	var fond := _c(FOUR, 1)
	var bas := PackedInt32Array()
	bas.resize(w)
	for x in w:
		bas[x] = 0
	for y in h:
		for x in w:
			img.set_pixel(x0 + x, y0 + y, fond)
	var L := maxi(4, int(0.085 * d))         # longueur d'une mèche
	var pas_x := 2 if d >= 96 else 1
	var rangs := int(float(h) / (L * 0.55)) + 1
	for rg in rangs:
		var yb := int(rg * L * 0.55) - L / 3
		var x := rng.randi_range(0, pas_x)
		while x < w:
			var lg := int(L * rng.randf_range(0.7, 1.25))
			var pente := rng.randf_range(-0.25, 0.25)
			var ys := yb + rng.randi_range(-2, 2)
			var lum := rng.randi_range(-1, 0)
			var large := 2 if (d >= 96 and rng.randf() < 0.6) else 1
			for k in lg:
				var t := float(k) / lg
				var yy := ys + k
				var xx := x + int(pente * k)
				if yy < 0 or yy >= h:
					continue
				var ton := 1 + int(t * 3.6) + lum
				if dentele and rg == rangs - 1 and t > 0.85: ton += 1
				for dw in large:
					var xw := posmod(xx + dw, w)
					img.set_pixel(x0 + xw, y0 + yy, _c(FOUR, ton))
					bas[xw] = maxi(bas[xw], yy)
				img.set_pixel(x0 + posmod(xx - 1, w), y0 + yy, _c(FOUR, maxi(0, ton - 3)))  # creux sombre à gauche
			x += pas_x + rng.randi_range(0, 1) + large - 1
	if dentele:
		# au-delà de la pointe la plus basse de chaque colonne (dans la frange) : transparent
		var frange := int(h * 0.68)
		for x in w:
			var lim := maxi(bas[x], frange)
			for y in range(lim + 1, h):
				img.set_pixel(x0 + x, y0 + y, Color(0, 0, 0, 0))

## Face du bouclier, disque de `taille` texels (2·RB) dont le coin haut-gauche est (ox, oy).
## `cerclage` : cerclage et umbo peints (A, B) ; C les a en géométrie (peints quand même dessous : invisibles).
func _bouclier(img: Image, d: int, ox: int, oy: int, taille: int, cerclage: bool) -> void:
	var bords := [-0.23, -0.075, 0.075, 0.23]
	var fissure := [Vector2(0.15, -0.32), Vector2(0.12, -0.25), Vector2(0.135, -0.19), Vector2(0.10, -0.12), Vector2(0.11, -0.07)]
	var e := 1.0 / d
	for py in taille:
		for px in taille:
			var x := (px + 0.5) / taille * 2.0 * RB - RB
			var z := RB - (py + 0.5) / taille * 2.0 * RB
			var r := sqrt(x * x + z * z)
			if r > RB:
				continue
			var lum := (-x + z) / RB      # lumière cuite : haut-gauche
			var col: Color
			if cerclage and r > RB - 0.026:
				var a := atan2(z, x)
				var tf := 3 if lum > 0.5 else (1 if lum < -0.5 else 2)
				if r > RB - 1.2 * e or r < RB - 0.026 + 1.2 * e: tf = 0
				elif r > RB - 0.026 + 2.0 * e and r < RB - 0.026 + 3.2 * e and lum > -0.2: tf += 1
				var ar := fmod(a + TAU, TAU / 14.0)
				var rr := absf(r - (RB - 0.013))
				if rr < 0.8 * e and ar < 1.2 * e / RB: tf = 4
				elif rr < 0.8 * e and ar < 2.4 * e / RB: tf = 0
				col = _c(FER, tf)
				if _bruit(x * 30.0, z * 30.0, 41) > 0.7 and tf > 0:
					col = _c(ROUILLE, tf - 1)
			elif cerclage and r < 0.095:
				var nn := Vector2(x, z) / 0.095
				var tf := 2 + int(round(1.6 * nn.dot(Vector2(-0.65, 0.65))))
				if r > 0.095 - 1.2 * e: tf = 0
				if absf(Vector2(x + 0.03, z - 0.03).length() - 0.035) < 0.9 * e and nn.dot(Vector2(-1, 1)) > 0: tf = 5
				col = _c(FER, tf)
			else:
				var planche := 0
				for b: float in bords:
					if x > b: planche += 1
				var joint := false
				for b: float in bords:
					if absf(x - b) < 0.7 * e: joint = true
				var grain := fposmod(x * 38.0 + 0.6 * sin(z * 7.0 + planche * 2.1) + 0.4 * _bruit(z * 12.0, planche, 3), 1.0)
				var tb := 2
				if grain < 0.16: tb = 1
				elif grain > 0.85: tb = 3
				if lum > 0.55: tb += 1
				elif lum < -0.55: tb -= 1
				# ombre portée de l'umbo, en bas à droite
				if cerclage and r < 0.115 and Vector2(x, z).dot(Vector2(1, -1)) > 0.0: tb -= 1
				col = _c(BOIS, tb)
				# peinture bleue usée (bruit à seuil), croix crème
				var croix := absf(x) < 0.03 or absf(z) < 0.03
				# usure : écaillage surtout près du cerclage et des joints, le long du fil du bois
				var pres_bord := smoothstep(RB - 0.09, RB - 0.03, r)
				var pres_joint := 0.0
				for b: float in bords:
					pres_joint = maxf(pres_joint, 1.0 - smoothstep(0.0, 0.025, absf(x - b)))
				var usure := 0.75 * _bruit(x * 22.0, z * 7.0, 17) + 0.25 * _bruit(x * 60.0, z * 20.0, 23) - 0.45 * maxf(pres_bord, pres_joint * 0.7) + 0.1
				if usure > 0.40 and r < RB - 0.03:
					var tp := 2 + (1 if grain > 0.85 else (-1 if grain < 0.16 else 0))
					if lum > 0.55: tp += 1
					elif lum < -0.55: tp -= 1
					col = _c(CREME, tp) if croix else _c(BLEU, tp)
					if usure < 0.43: col = _c(BOIS, 1)       # bord écaillé : liseré sombre
				if joint: col = _c(BOIS, 0)
			img.set_pixel(ox + px, oy + py, col)
	# fissure : trait sombre + reflet en haut à gauche
	for i in fissure.size() - 1:
		var a: Vector2 = fissure[i]
		var b: Vector2 = fissure[i + 1]
		var nstep := int(a.distance_to(b) * d * 2.0) + 1
		for k in nstep + 1:
			var p := a.lerp(b, float(k) / nstep)
			var px := int((p.x + RB) / (2.0 * RB) * taille)
			var py := int((RB - p.y) / (2.0 * RB) * taille)
			if px >= 0 and py >= 0 and px < taille and py < taille:
				img.set_pixel(ox + px, oy + py, _c(BOIS, 0))
				if px - 1 >= 0 and py - 1 >= 0:
					img.set_pixel(ox + px - 1, oy + py - 1, _c(BOIS, 3))

func _dos_bouclier(img: Image, d: int) -> void:
	var x0 := int(R_DOS.position.x * d)
	var y0 := int(R_DOS.position.y * d)
	for y in int(R_DOS.size.y * d):
		for x in int(R_DOS.size.x * d):
			var tb := 1 + (1 if fposmod(x * 0.4 + sin(y * 0.2) * 0.5, 1.0) > 0.8 else 0)
			if y > int(0.42 * d):    # bande de fer (tranche du cerclage)
				var tf := 2 if y != int(0.42 * d) + 1 else 0
				if (x % maxi(4, int(0.06 * d))) == 0: tf = 4
				img.set_pixel(x0 + x, y0 + y, _c(FER, tf))
			else:
				img.set_pixel(x0 + x, y0 + y, _c(BOIS, tb))

func _cape(img: Image, d: int) -> void:
	var x0 := int(R_CAPE.position.x * d)
	var y0 := int(R_CAPE.position.y * d)
	var w := int(R_CAPE.size.x * d)
	var h := int(R_CAPE.size.y * d)
	for y in h:
		for x in w:
			var ph := float(x) / d * 26.0 + 1.3 * _bruit(y * 0.05, 0.0, 11) + float(y) / d * 2.0
			var pli := sin(ph)
			var tc := 2
			if pli > 0.6: tc = 3
			elif pli < -0.55: tc = 1
			if pli < -0.92: tc = 0
			if y > h - int(0.05 * d): tc -= 1            # ourlet sale
			if y == h - int(0.05 * d): tc = 0
			if x == 0 or x == w - 1: tc = 0                  # bords
			if _h(x, y, 61) < 0.05: tc += 1                  # peluche de la laine
			img.set_pixel(x0 + x, y0 + y, _c(CAPE, tc))

func _tete(img: Image, d: int) -> void:
	var x0 := int(R_TETE.position.x * d)
	var y0 := int(R_TETE.position.y * d)
	var w := int(R_TETE.size.x * d)
	var h := int(R_TETE.size.y * d)
	var cx := int(C_TETE * 0.5 * d)
	var fl := int(0.065 * d)
	var f_haut := int(0.09 * d)
	var yeux := int(0.135 * d)
	var barbe := int(0.17 * d)
	for y in h:
		for x in w:
			var dx := absi(x - cx)
			var col: Color
			if dx <= fl and y >= f_haut and y < barbe:
				var tp := 3
				if dx == fl: tp = 1
				if y == f_haut: tp = 1
				if y >= yeux - int(0.012 * d) and y < yeux - int(0.006 * d) and dx > 1 and dx < int(0.045 * d): tp = 0  # sourcils
				if y >= yeux and y < yeux + maxi(1, int(0.008 * d)) and dx >= int(0.015 * d) and dx < int(0.04 * d):
					tp = 0 if dx > int(0.025 * d) else 4      # yeux (iris sombre, blanc vers le nez)
				if dx <= maxi(1, int(0.008 * d)) and y > yeux and y < barbe - 2: tp = 4 if x <= cx else 2  # arête du nez
				col = _c(PEAU, tp)
			else:
				# cheveux / barbe : mèches verticales tressées
				var tc := 2 + (1 if (x + (y / 3)) % 3 == 0 else 0) - (1 if x % 4 == 0 else 0)
				if y < int(0.03 * d): tc += 1
				if y >= barbe and dx <= int(0.02 * d) and (y / 2) % 2 == 0: tc = 1   # tresse
				if y >= barbe + int(0.02 * d) and dx <= int(0.006 * d * 4) and y < barbe + int(0.026 * d): tc = 0  # bouche
				col = _c(POIL, tc)
			img.set_pixel(x0 + x, y0 + y, col)

## Carte de normales « par texel » tirée de la luminance (relief léger : creux = sombre).
static func relief_de(img: Image, force: float) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var lum := PackedFloat32Array()
	lum.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			lum[y * w + x] = c.get_luminance() if c.a > 0.5 else 0.0
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var hx := lum[y * w + posmod(x + 1, w)] - lum[y * w + posmod(x - 1, w)]
			var hy := lum[posmod(y - 1, h) * w + x] - lum[posmod(y + 1, h) * w + x]
			var n := Vector3(-hx * force, -hy * force, 1.0).normalized()
			out.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	out.generate_mipmaps()
	return out

## Mipmaps pixel art (vote de couleur 2×2, comme les arbres) : à distance, pas de moiré ni de fondu de teinte.
## (Copie de TexturesArbres.mips_image, étendue aux textures non carrées.)
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
				var vus := 0
				for dd: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var sx := mini(x * 2 + dd.x, cur.get_width() - 1)
					var sy := mini(y * 2 + dd.y, cur.get_height() - 1)
					var c := cur.get_pixel(sx, sy)
					vus += 1
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

# ------------------------------------------------------------------ géométrie
## Tube d'anneaux elliptiques [y, rx, rz, cx, cz] (angle 0 = dos -Z, π = devant +Z), UV métriques dans la région.
func _tube(st: SurfaceTool, anneaux: Array, n: int, region: Rect2, circ: float, m: Transform3D = Transform3D.IDENTITY, flip := false) -> void:
	var vcum := [0.0]
	for i in range(1, anneaux.size()):
		var a: Array = anneaux[i - 1]
		var b: Array = anneaux[i]
		var ra := (float(a[1]) + float(a[2])) * 0.5
		var rb := (float(b[1]) + float(b[2])) * 0.5
		vcum.append(float(vcum[i - 1]) + Vector2(float(b[0]) - float(a[0]), rb - ra).length())
	for i in anneaux.size() - 1:
		for j in n:
			var quad: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var an: Array = anneaux[i + k.y]
				var th := TAU * float(j + k.x) / n
				var p := Vector3(float(an[3]) + sin(th) * float(an[1]), float(an[0]), float(an[4]) - cos(th) * float(an[2]))
				quad.append(m * p)
				uvs.append(Vector2(region.position.x + float(j + k.x) / n * circ, region.position.y + float(vcum[i + k.y])) / ATLAS_M)
			var ordre := [0, 2, 1, 0, 3, 2] if not flip else [0, 1, 2, 0, 2, 3]
			for o: int in ordre:
				st.set_uv(uvs[o])
				st.add_vertex(quad[o])

func _maillage_base(st: SurfaceTool) -> void:
	st.set_smooth_group(0)
	# torse (10 côtés), descend du cou à la taille : v croissant vers le bas → anneaux du haut vers le bas
	var torse := [
		[1.66, 0.065, 0.065, 0.0, 0.0], [1.60, 0.09, 0.08, 0.0, 0.0], [1.55, 0.19, 0.115, 0.0, 0.0],
		[1.47, 0.23, 0.135, 0.0, 0.0], [1.36, 0.225, 0.14, 0.0, 0.01], [1.22, 0.205, 0.135, 0.0, 0.01],
		[1.08, 0.18, 0.125, 0.0, 0.0], [0.95, 0.17, 0.12, 0.0, 0.0]]
	_tube(st, torse, 10, R_TORSE, C_TORSE)
	# bras (8 côtés), de l'épaule au coude, légèrement écartés
	for s: float in [-1.0, 1.0]:
		var m := Transform3D(Basis(Vector3(0, 0, 1), s * 0.18), Vector3(s * 0.25, 0, 0))
		var bras := [[1.49, 0.068, 0.068, 0.0, 0.0], [1.33, 0.062, 0.062, 0.0, 0.0], [1.15, 0.055, 0.055, 0.0, 0.01]]
		var mm := Transform3D(Basis.IDENTITY, Vector3(0, 1.49, 0)) * m * Transform3D(Basis.IDENTITY, Vector3(0, -1.49, 0))
		_tube(st, bras, 8, R_BRAS, C_BRAS, mm)
	# tête (8 côtés)
	var tete := [[1.90, 0.03, 0.03, 0.0, 0.0], [1.87, 0.075, 0.085, 0.0, 0.0], [1.80, 0.092, 0.102, 0.0, 0.0],
		[1.72, 0.09, 0.10, 0.0, 0.01], [1.66, 0.07, 0.085, 0.0, 0.02], [1.62, 0.05, 0.055, 0.0, 0.0]]
	_tube(st, tete, 8, R_TETE, C_TETE)

func _maillage_cape(st: SurfaceTool) -> void:
	st.set_smooth_group(0)
	# panneau courbe dans le dos (5 × 4), double face
	var nx := 5
	var ny := 4
	for j in ny:
		for i in nx:
			var quad: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var u := float(i + k.x) / nx
				var v := float(j + k.y) / ny
				var larg := lerpf(0.27, 0.33, v)
				var a := (u - 0.5) * 2.2
				var p := Vector3(sin(a) * larg, lerpf(1.56, 0.86, v), -cos(a) * lerpf(0.15, 0.2, v) - 0.03)
				quad.append(p)
				uvs.append(Vector2(R_CAPE.position.x + u * R_CAPE.size.x, R_CAPE.position.y + v * R_CAPE.size.y) / ATLAS_M)
			for o: int in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uvs[o])
				st.add_vertex(quad[o])

## Épaule de fourrure (A, B) : 4 anneaux de 16 côtés, frange dentelée par la texture (double face).
func _maillage_fourrure(st: SurfaceTool) -> void:
	st.set_smooth_group(0)
	var a := []
	for r: Array in [[0.42, 0.03], [0.92, -0.05], [1.03, -0.13], [1.09, -0.23]]:
		a.append([1.60 + float(r[1]), 0.27 * float(r[0]), 0.175 * float(r[0]), 0.0, 0.0])
	_tube(st, a, 16, R_FOUR, C_FOUR)

## Bouclier bas-poly (A, B) : disque bombé de 16 côtés + dos + tranche ; centre à l'origine, face vers +Z.
func _maillage_bouclier(st: SurfaceTool) -> void:
	st.set_smooth_group(-1)
	var n := 16
	var anneaux := [[0.0, 0.040], [0.095, 0.034], [0.25, 0.022], [RB, 0.010]]
	var uvf := func(x: float, y: float) -> Vector2:
		return Vector2(R_BOUC.position.x + (x + RB), R_BOUC.position.y + (RB - y)) / ATLAS_M
	for k in anneaux.size() - 1:
		for i in n:
			var pts: Array[Vector3] = []
			for q: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var an: Array = anneaux[k + q.y]
				var th := TAU * float(i + q.x) / n
				pts.append(Vector3(cos(th) * float(an[0]), sin(th) * float(an[0]), float(an[1])))
			for o: int in [0, 2, 1, 0, 3, 2]:
				st.set_uv(uvf.call(pts[o].x, pts[o].y))
				st.add_vertex(pts[o])
	# dos plat + tranche (bande de fer)
	for i in n:
		var t0 := TAU * float(i) / n
		var t1 := TAU * float(i + 1) / n
		var c := Vector3.ZERO
		var p0 := Vector3(cos(t0) * RB, sin(t0) * RB, 0.0)
		var p1 := Vector3(cos(t1) * RB, sin(t1) * RB, 0.0)
		var uvd := func(p: Vector3) -> Vector2:
			return Vector2(R_DOS.position.x + 0.2 + p.x * 0.5, R_DOS.position.y + 0.2 + p.y * 0.5) / ATLAS_M
		for p: Vector3 in [c, p0, p1]:
			st.set_uv(uvd.call(p))
			st.add_vertex(p)
		var q0 := p0 + Vector3(0, 0, 0.010)
		var q1 := p1 + Vector3(0, 0, 0.010)
		var u0 := Vector2(R_DOS.position.x + float(i) / n * 0.5, R_DOS.position.y + 0.44) / ATLAS_M
		var u1 := Vector2(R_DOS.position.x + float(i + 1) / n * 0.5, R_DOS.position.y + 0.44) / ATLAS_M
		var u2 := Vector2(R_DOS.position.x + float(i + 1) / n * 0.5, R_DOS.position.y + 0.48) / ATLAS_M
		var u3 := Vector2(R_DOS.position.x + float(i) / n * 0.5, R_DOS.position.y + 0.48) / ATLAS_M
		var pts := [p0, p1, q1, q0]
		var uv := [u0, u1, u2, u3]
		for o: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[o])
			st.add_vertex(pts[o])

func _mesh(f: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	f.call(st)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

func _mat(tex: Image, avec_mips: bool, relief: Image, double: bool, decoupe := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if double:
		var s := Shader.new()
		s.code = LOOK.code.replace("render_mode diffuse_lambert, specular_disabled;", "render_mode diffuse_lambert, specular_disabled, cull_disabled;")
		m.shader = s
	else:
		m.shader = LOOK
	m.set_shader_parameter("tex_base", ImageTexture.create_from_image(tex))
	if avec_mips:
		m.set_shader_parameter("tex_base_mips", ImageTexture.create_from_image(mips_pixel(tex)))
		m.set_shader_parameter("mips", true)
	if relief != null:
		m.set_shader_parameter("tex_relief", ImageTexture.create_from_image(relief))
		m.set_shader_parameter("relief", true)
	m.set_shader_parameter("decoupe", decoupe)
	return m

## Échantillon A ou B : même géométrie, densité et relief différents.
func _echantillon_ab(nom: String, d: int, avec_relief: bool, avec_mips: bool, contour := false) -> Node3D:
	var racine := Node3D.new()
	racine.name = nom
	var t0 := Time.get_ticks_msec()
	var atlas := peindre_atlas(d)
	var rel: Image = relief_de(atlas, 2.2) if avec_relief else null
	print("ATLAS %s %dx%d en %d ms" % [nom, atlas.get_width(), atlas.get_height(), Time.get_ticks_msec() - t0])
	atlas.save_png("%s/atlas_%s.png" % [sortie, nom])
	var opaque := _mat(atlas, avec_mips, rel, false)
	var double := _mat(atlas, avec_mips, rel, true, true)
	var tris := 0
	for p: Array in [[_mesh(_maillage_base), opaque, Transform3D.IDENTITY],
			[_mesh(_maillage_cape), double, Transform3D.IDENTITY],
			[_mesh(_maillage_fourrure), double, Transform3D.IDENTITY],
			[_mesh(_maillage_bouclier), double, _pose_bouclier()]]:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.material_override = p[1]
		mi.transform = p[2]
		mi.set_meta("contour", p[1] == opaque or p[2] != Transform3D.IDENTITY)
		racine.add_child(mi)
		tris += (p[0] as ArrayMesh).surface_get_array_len(0) / 3
	stats[nom] = {"triangles": tris, "texture": "%d² RGBA8%s%s" % [atlas.get_width(), " + mips" if avec_mips else "", " + normales" if avec_relief else ""],
		"memoire_ko": int(atlas.get_width() * atlas.get_height() * 4 * (1.33 if avec_mips else 1.0) * (2.0 if avec_relief else 1.0) / 1024.0), "materiaux": 2}
	if contour:
		_contours(racine, nom)
	return racine

## Contour sombre (coque inversée à épaisseur constante à l'écran) sur le corps et le bouclier.
## Pas sur les cartes découpées (fourrure, cape) : la coque suivrait le quadrilatère, pas la découpe.
func _contours(racine: Node3D, nom: String) -> void:
	var m := ShaderMaterial.new()
	m.shader = preload("res://outils/lookdev_contour.gdshader")
	m.set_shader_parameter("epaisseur", 1.5)
	var n := 0
	for mi: MeshInstance3D in racine.get_children():
		if mi.get_meta("contour", false):
			var c := MeshInstance3D.new()
			c.mesh = mi.mesh
			c.material_override = m
			c.transform = mi.transform
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			racine.add_child(c)
			n += 1
	stats[nom]["contours"] = n

func _pose_bouclier() -> Transform3D:
	# au bras gauche (côté +X), tourné de 35° vers la droite de la caméra, légèrement incliné
	var b := Basis(Vector3.UP, deg_to_rad(68.0)) * Basis(Vector3.RIGHT, deg_to_rad(-6.0))
	return Transform3D(b, Vector3(0.40, 1.12, 0.06))

## Échantillon C : base de B (sans relief) + fourrure en mèches et bouclier modelés (glb Blender).
func _echantillon_c(nom := "C", contour := false) -> Node3D:
	var racine := Node3D.new()
	racine.name = nom
	var atlas := peindre_atlas(DENS_B)
	var opaque := _mat(atlas, true, null, false)
	var double := _mat(atlas, true, null, true, true)
	var tris := 0
	for p: Array in [[_mesh(_maillage_base), opaque], [_mesh(_maillage_cape), double]]:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.material_override = p[1]
		mi.set_meta("contour", p[1] == opaque)
		racine.add_child(mi)
		tris += (p[0] as ArrayMesh).surface_get_array_len(0) / 3
	# textures propres à C (même dessin, même densité)
	var meche := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	_meche(meche)
	var base_f := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	_fourrure(base_f, 64, Rect2(0, 0, 2.0, 0.5), false, 5)
	var face := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	face.fill(_c(BOIS, 1))
	_bouclier(face, 168, 0, 0, 128, true)
	var fer := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var tf := 3 if y < 8 else (2 if y < 16 else (1 if y < 24 else 2))
			if y == 0 or y == 31: tf = 0
			if y == 4 and x % 8 == 0: tf = 5
			if y == 5 and x % 8 == 0: tf = 0
			var col := _c(FER, tf)
			if _bruit(x * 0.3, y * 0.3, 41) > 0.7 and tf > 0: col = _c(ROUILLE, tf - 1)
			fer.set_pixel(x, y, col)
	var umbo := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var tf := 2 + (1 if x < 14 else 0) + (1 if y > 20 else 0) - (1 if x > 24 else 0)
			if x == 13 and y > 18: tf = 5
			umbo.set_pixel(x, y, _c(FER, tf))
	var mats := {
		"fourrure_meche": _mat(meche, true, null, true, true),
		"fourrure_base": _mat(base_f, true, null, true),
		"bois": _mat(face, true, null, true),
		"fer": _mat(fer, true, null, true),
		"fer_umbo": _mat(umbo, true, null, false),
	}
	var scene := (load(GLB_C) as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			var nm := mat.resource_name if mat != null else ""
			if mats.has(nm):
				mi.set_surface_override_material(s, mats[nm])
			else:
				push_warning("matériau inconnu " + nm)
			tris += mesh.surface_get_array_len(s) / 3 if mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX == 0 else mesh.surface_get_array_index_len(s) / 3
		var copie := MeshInstance3D.new()
		copie.mesh = mesh
		for s in mesh.get_surface_count():
			copie.set_surface_override_material(s, mi.get_surface_override_material(s))
		if mi.name.begins_with("fourrure"):
			copie.position = Vector3(0, 1.60, 0)
		else:
			copie.transform = _pose_bouclier()
			copie.set_meta("contour", true)
		racine.add_child(copie)
	scene.free()
	stats[nom] = {"triangles": tris, "texture": "atlas 256² + mèche %dx%d + face 128² + fer 32² + umbo 32² (mips)" % [meche.get_width(), meche.get_height()],
		"memoire_ko": int((256 * 256 + meche.get_width() * meche.get_height() + face.get_width() * face.get_height() + 128 * 29 + 2048) * 4 * 1.33 / 1024.0), "materiaux": 7}
	if contour:
		_contours(racine, nom)
	return racine

## Texture d'une mèche (u en travers, v de la racine à la pointe) : brins clairs vers la pointe, bords découpés.
func _meche(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	img.fill(Color(0, 0, 0, 0))
	for x in w:
		var bord := absf((x + 0.5) / w - 0.5) * 2.0
		var fin := int(h * (1.0 - 0.18 * bord - 0.12 * _h(x, 0, 3)))
		for y in fin:
			var t := float(y) / h
			var ton := 1 + int(t * 3.5)
			if x % 3 == 0: ton -= 1            # creux entre brins
			if x == w / 2 or x == w / 2 - 1: ton += 1 if t > 0.3 else 0
			if bord > 0.85: ton -= 1
			img.set_pixel(x, y, _c(FOUR, ton))

# ------------------------------------------------------------------ décor + lumière
func _decor() -> void:
	var sky := Sky.new()
	var ciel := ShaderMaterial.new()
	ciel.shader = CIEL
	sky.sky_material = ciel
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.0
	for i in 7:
		env.set_glow_level(i, 1.0 if (i == 1 or i == 2) else 0.0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	soleil = DirectionalLight3D.new()
	soleil.shadow_enabled = true
	soleil.shadow_bias = 0.08
	soleil.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	soleil.directional_shadow_max_distance = 62.0
	add_child(soleil)
	cycle = Node.new()
	cycle.set_script(CYCLE)
	cycle.env = env
	cycle.lumiere = soleil
	cycle.ciel = ciel
	cycle.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(cycle)
	# sol de neige et mur de planches (vrai ps1.gdshader)
	var neige := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var v := _bruit(x * 0.25, y * 0.25, 2) + 0.3 * _h(x, y, 4)
			neige.set_pixel(x, y, _c(NEIGE, int(v * 4.0)))
	var mn := ShaderMaterial.new()
	mn.shader = PS1
	var tn := ImageTexture.create_from_image(neige)
	mn.set_shader_parameter("tex_base", tn)
	mn.set_shader_parameter("tex_neige", tn)
	mn.set_shader_parameter("uv_echelle", Vector2(30, 30))
	mn.set_shader_parameter("grille", 180.0)
	mn.set_shader_parameter("affine", 0.55)
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	pm.subdivide_width = 59
	pm.subdivide_depth = 59
	sol.mesh = pm
	sol.material_override = mn
	add_child(sol)
	var bois := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var t := 1 + (1 if fposmod(y * 0.33 + sin(x * 0.2), 1.0) > 0.7 else 0)
			if x % 8 == 0: t = 0
			bois.set_pixel(x, y, _c(PLANCHES, t))
	var mb := ShaderMaterial.new()
	mb.shader = PS1
	var tb := ImageTexture.create_from_image(bois)
	mb.set_shader_parameter("tex_base", tb)
	mb.set_shader_parameter("tex_neige", tb)
	mb.set_shader_parameter("uv_echelle", Vector2(50, 3))
	mb.set_shader_parameter("grille", 180.0)
	mb.set_shader_parameter("affine", 0.55)
	var mur := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(60, 3.2, 0.3)
	mur.mesh = bm
	mur.material_override = mb
	mur.position = Vector3(6, 1.6, -4.0)
	mur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mur)
	# post-traitement du jeu (15 bits, tramage par bruit, étalonnage)
	var calque := CanvasLayer.new()
	add_child(calque)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = POST
	rect.material = post
	calque.add_child(rect)
	torche = OmniLight3D.new()
	torche.light_color = Color(1.0, 0.58, 0.28)
	torche.light_energy = 1.5
	torche.omni_range = 10.0
	torche.omni_attenuation = 1.3
	torche.shadow_enabled = false
	add_child(torche)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	add_child(camera)
	camera.current = true

func _eclairage(nom: String) -> void:
	cycle.heure = 17.5 if nom == "crep" else 21.5
	cycle._process(0.0)
	torche.visible = nom == "torche"

const X_ECH := {"A": -6.0, "B": 0.0, "C": 6.0, "B0": 0.0, "Bc": 12.0, "Cc": 18.0}
const ROT := -50.0   # lacet des échantillons (°)

func _montrer(nom: String) -> void:
	for k: String in echantillons:
		(echantillons[k] as Node3D).visible = k == nom

func _placer_camera(nom: String, dist: float, decal: float) -> void:
	var o := Vector3(float(X_ECH[nom]), 0, 0)
	var rb := Basis(Vector3.UP, deg_to_rad(ROT))
	var cible := o + rb * Vector3(0.12, 1.32, 0.05)
	var dir := rb * Vector3(sin(deg_to_rad(28.0)), 0.10, cos(deg_to_rad(28.0))).normalized()
	var pos := cible + dir * dist
	var droite := dir.cross(Vector3.UP).normalized() * -1.0
	camera.global_position = pos + droite * decal
	camera.look_at(cible + droite * decal, Vector3.UP)
	# torche tenue par le joueur : à droite et sous la caméra
	torche.global_position = camera.global_position + camera.global_basis * Vector3(0.3, -0.25, -0.4)
	cycle.orienter_brume(-camera.global_basis.z)

func _cadre(nom: String) -> Rect2i:
	# rectangle écran du buste + bouclier (projection des coins de la boîte)
	var o := Vector3(float(X_ECH[nom]), 0, 0)
	var mini_ := Vector2(1e9, 1e9)
	var maxi_ := Vector2(-1e9, -1e9)
	for x: float in [-0.35, 0.62]:
		for y: float in [0.8, 1.95]:
			for z: float in [-0.25, 0.45]:
				var p := camera.unproject_position(o + Basis(Vector3.UP, deg_to_rad(ROT)) * Vector3(x, y, z))
				mini_ = mini_.min(p)
				maxi_ = maxi_.max(p)
	var r := Rect2i(Vector2i(mini_), Vector2i(maxi_ - mini_))
	return r.intersection(Rect2i(Vector2i.ZERO, RES))

func _attendre(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	sortie = args.get("sortie", OS.get_user_data_dir() + "/lookdev")
	DirAccess.make_dir_recursive_absolute(sortie)
	var w := get_window()
	w.content_scale_size = RES
	w.size = RES * 2
	_decor()
	var a := _echantillon_ab("A", DENS_A, false, true)
	var b := _echantillon_ab("B", DENS_B, true, true)
	var b0 := _echantillon_ab("B0", DENS_B, true, false)   # B sans mipmaps : témoin du scintillement
	var c := _echantillon_c()
	var bc := _echantillon_ab("Bc", DENS_B, true, true, true)   # B + contour
	var cc := _echantillon_c("Cc", true)                          # C + contour
	for n: Node3D in [a, b, b0, c, bc, cc]:
		n.position.x = float(X_ECH[n.name])
		n.rotation.y = deg_to_rad(ROT)
		add_child(n)
		echantillons[n.name] = n
	print("STATS ", JSON.stringify(stats))
	await _attendre(40)
	var cadres := {}
	if not args.has("sans-captures"):
		var t0 := Time.get_ticks_msec()
		for ecl: String in ["crep", "torche"]:
			_eclairage(ecl)
			for nom: String in ["A", "B", "C", "B0", "Bc", "Cc"]:
				_montrer(nom)
				for dist: float in [2.0, 5.0]:
					if nom == "B0" and dist < 3.0 and ecl == "torche":
						continue
					for k in 3:
						_placer_camera(nom, dist, 0.02 * k)
						await _attendre(4 if k > 0 else 12)
						var img := get_viewport().get_texture().get_image()
						var f := "%s_%s_%dm_%d" % [ecl, nom, int(dist), k]
						img.save_png("%s/%s.png" % [sortie, f])
						cadres[f] = [_cadre(nom).position.x, _cadre(nom).position.y, _cadre(nom).size.x, _cadre(nom).size.y]
		var fj := FileAccess.open(sortie + "/cadres.json", FileAccess.WRITE)
		fj.store_string(JSON.stringify({"cadres": cadres, "stats": stats}))
		fj.close()
		print("CAPTURES %d en %d ms" % [cadres.size(), Time.get_ticks_msec() - t0])
	if args.has("perf"):
		await _perf()
	get_tree().quit(0)

func _perf() -> void:
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	_eclairage("crep")
	var res := {}
	for tour in 2:
		for nom: String in ["aucun", "A", "B", "C", "Cc"]:
			_montrer(nom)
			_placer_camera("B" if nom == "aucun" else nom, 2.0, 0.0)
			await _attendre(60)
			var g := 0.0
			var dc := 0.0
			var pr := 0.0
			var n := 240
			for i in n:
				await get_tree().process_frame
				g += RenderingServer.viewport_get_measured_render_time_gpu(rid)
				dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				pr += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			print("PERF tour=%d %s gpu_ms=%.3f draw_calls=%.1f primitives=%d" % [tour, nom, g / n, dc / n, int(pr / n)])
			res["%s_%d" % [nom, tour]] = [g / n, dc / n, pr / n]
	var fj := FileAccess.open(sortie + "/perf.json", FileAccess.WRITE)
	fj.store_string(JSON.stringify(res))
	fj.close()
