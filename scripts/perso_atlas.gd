class_name PersoAtlas
## Atlas 256x256 des personnages « base unifiee » (un par morphologie), dessine par code a partir de la mise en page ecrite par Blender
## (sources_blender/scripts/base_persos.py -> assets/personnages/mise_en_page_<sexe>.json : rectangle de chaque partie, longueur, anneaux).
## DENSITE_PERSO texels/m, la meme pour le visage et la tunique (valeur lue dans le JSON : une seule source de verite).
## L'image ne contient pas de couleurs mais des INDICES : R = ton*32+16 (8 tons), G = region*16+8, A = 0 pour un texel decoupe.
## Regions : 0 peau, 1 tunique, 2 pantalon, 3 cuir, 4 surcouche, 5 cheveux, 6 fourrure, 7 iris, 8 fixe (R>>4 = couleur fixe du shader : fer, or, blancs).
## Les couleurs viennent du shader (perso.gdshader, rampe de 8 tons, 15 bits) : changer la couleur d'un PNJ ne recree aucune texture.
## Convention de dessin : colonne x = arc (m) * densite depuis la couture du dos ; ligne y = longueur de chemin depuis le DEBUT de la partie
## (ourlet du torse, poignet de la manche, cheville du pantalon, haut du crane...). Precalcul : outils/generer_personnages.gd -> atlas_<sexe>.res.

const DOSSIER := "res://assets/personnages"
const VERSION := 6
## Regions
const PEAU := 0
const TUN := 1
const PAN := 2
const CUIR := 3
const SUR := 4
const CHEV := 5
const FOUR := 6
const IRIS := 7
const FIXE := 8
## Couleurs fixes (index de FIXE[] du shader)
const F_FER := 1
const F_OR := 6
const F_BLANC := 9
const F_NOIR := 11

static var _tex := {}
static var _infos := {}

static func infos(sexe: String) -> Dictionary:
	if not _infos.has(sexe):
		var f := FileAccess.open("%s/mise_en_page_%s.json" % [DOSSIER, sexe], FileAccess.READ)
		_infos[sexe] = JSON.parse_string(f.get_as_text()) if f else {}
	return _infos[sexe]

static func densite(sexe := "homme") -> float:
	return float(infos(sexe).get("densite", 32.0))

static func _cle(sexe: String) -> String:
	var f := FileAccess.open("%s/mise_en_page_%s.json" % [DOSSIER, sexe], FileAccess.READ)
	return "%d:%d" % [VERSION, f.get_as_text().hash() if f else 0]

static func texture(sexe: String) -> Texture2D:
	if _tex.has(sexe):
		return _tex[sexe]
	var chemin := "%s/atlas_%s.res" % [DOSSIER, sexe]
	var t: Texture2D = null
	if ResourceLoader.exists(chemin):
		var r := load(chemin) as ImageTexture
		if r != null and r.has_meta("cle") and r.get_meta("cle") == _cle(sexe):
			t = r
	if t == null:
		var it := ImageTexture.create_from_image(peindre(sexe))
		it.set_meta("cle", _cle(sexe))
		t = it
	_tex[sexe] = t
	return t

static func vider() -> void:
	_tex.clear()
	_infos.clear()

# ------------------------------------------------------------------ outils
static func _h(x: int, y: int, g: int) -> float:
	return ObjetsTextures._h(x, y, g)

static func _n(x: int, y: int, w: int, h: int, cx: int, cy: int, g: int) -> float:
	return ObjetsTextures._vn(float(x) / maxf(w, 1) * cx, float(y) / maxf(h, 1) * cy, cx, cy, g)

class Zone:
	var img: Image
	var x0: int          # coin du rectangle + marge 1
	var y0: int
	var w: int           # largeur utile (px) : le tour
	var h: int           # hauteur utile
	var debut: int       # ligne du premier anneau
	var fin: int         # ligne du dernier anneau
	var d: float
	var g: int
	var info: Dictionary
	func ton(x: int, y: int, t: int, reg: int, a := 255) -> void:
		if y < 0 or y >= h + 2:
			return
		var xx := posmod(x, w) if w > 0 else 0
		img.set_pixel(x0 + xx, y0 + y, Color8(t * 32 + 16, reg * 16 + 8, 0, a))
	func fixe(x: int, y: int, idx: int, a := 255) -> void:
		if y < 0 or y >= h + 2:
			return
		var xx := posmod(x, w) if w > 0 else 0
		img.set_pixel(x0 + xx, y0 + y, Color8(idx * 16 + 8, FIXE * 16 + 8, 0, a))
	func v_vers_y(v: float) -> int:
		return int(round((v - float(info["vmin"])) * d))
	func y_vers_v(y: float) -> float:
		return float(info["vmin"]) + y / d
	## z (m) -> ligne, par interpolation entre les anneaux
	func z_vers_y(z: float) -> int:
		var an: Array = info["anneaux"]
		for i in an.size() - 1:
			var z0: float = an[i][1]
			var z1: float = an[i + 1][1]
			if (z - z0) * (z - z1) <= 0.0 and absf(z1 - z0) > 1e-6:
				var t := (z - z0) / (z1 - z0)
				return v_vers_y(lerpf(an[i][0], an[i + 1][0], t))
		return v_vers_y(an[0][0] if z < an[0][1] else an[-1][0])
	## largeur (px) du tour a la ligne y : le centre de l'avant est a la moitie
	func tour_a(y: int) -> float:
		var an: Array = info["anneaux"]
		var v := y_vers_v(float(y))
		for i in an.size() - 1:
			if v >= an[i][0] and v <= an[i + 1][0]:
				return lerpf(an[i][2], an[i + 1][2], inverse_lerp(an[i][0], an[i + 1][0], v)) * d
		return float(an[0][2] if v < an[0][0] else an[-1][2]) * d

static func _zone(img: Image, cle: String, info: Dictionary, dens: float) -> Zone:
	var z := Zone.new()
	z.img = img
	z.info = info
	var r: Array = info["rect"]
	z.x0 = int(r[0]) + 1
	z.y0 = int(r[1]) + 1
	z.d = float(info.get("densite", dens))        # densite propre a la partie (visage v2 : 128 texels/m)
	z.w = int(ceil(float(info["umax"]) * z.d))
	z.h = int(ceil((float(info["vmax"]) - float(info["vmin"])) * z.d))
	z.debut = z.v_vers_y(float(info["anneaux"][0][0]))
	z.fin = z.v_vers_y(float(info["anneaux"][-1][0]))
	z.g = 100 + cle.hash() % 90
	return z

## Ton 0-7 d'une luminance l (0-1) avec bruit de seuil (jamais Bayer).
static func _t(l: float, x: int, y: int, jit := 0.4) -> int:
	return ObjetsTextures._ton(l, 8, x, y, jit)

# ------------------------------------------------------------------ peinture
static func peindre(sexe: String) -> Image:
	var inf := infos(sexe)
	var dens := float(inf["densite"])
	var n := int(inf["atlas"])
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color8(15 * 16 + 8, FIXE * 16 + 8, 0, 255))   # inutilise = magenta (visible si une partie manque)
	for cle: String in inf["rects"]:
		var z := _zone(img, cle, inf["rects"][cle], dens)
		match String(inf["rects"][cle]["kind"]):
			"tunique": _tunique(z, TUN, cle)
			"sur": _tunique(z, SUR, cle)
			"pantalon": _pantalon(z)
			"cuir": _cuir(z, cle)
			"peau": _peau(z)
			"visage": _visage(z, sexe == "femme")
			"nez": _nez(z)
			"oreille": _oreille(z)
			"cheveux", "barbe": _poil(z)
			"fourrure": _fourrure(z)
			"fer": _fer(z)
			_: _tunique(z, TUN, cle)
	return img

## Etoffe v2 : sergé fin, PLIS verticaux (phase deformee par un bruit lent : jamais regulier) avec ligne de creux sombre et arete claire, patine plus claire sur les
## aretes, saleté et ombre peinte (AO) vers l'ourlet, taches basses frequences faibles (plus de « camouflage »).
static func _laine(z: Zone, reg: int, plis := 5, sale := 0.14, fin := false) -> void:
	var nf := maxi(3, int(round(float(z.w) / 9.0)))
	for y in z.h + 2:
		var vy := y - z.debut
		for x in z.w:
			var sg := (0.04 if ((x + y) & 3) < 2 else -0.025) if not fin else (0.04 if ((x + y) & 1) == 0 else -0.025)
			var ph := float(x) / float(z.w) * float(nf) + (_n(x, y, z.w, z.h, 2, 3, z.g + 7) - 0.5) * 0.7 + float(y) * 0.006
			var f := sin(ph * TAU)
			var l := 0.52 + sg + 0.085 * f
			if f < -0.90:
				l -= 0.13                                             # creux du pli
			elif f > 0.93:
				l += 0.09                                             # arete eclairee
			l += (_h(x, y, z.g) - 0.5) * 0.05 + (_n(x, y, z.w, z.h, 3, 2, z.g + 2) - 0.5) * 0.11 + (_n(x, y, z.w, z.h, 8, 6, z.g + 5) - 0.5) * 0.07
			l -= sale * smoothstep(float(z.d) * 0.9, 0.0, float(vy))        # saleté vers l'ourlet / le poignet
			l -= 0.07 * smoothstep(float(z.d) * 0.5, 0.0, float(z.fin - y))    # ombre peinte au bout opposé
			z.ton(x, y, _t(l, x, y, 0.32), reg)

## Bordure v3 : repli d'ourlet, filet clair, bande tissée de 2 rangées (petite clé grecque, 1-2 texels) dans les TONS de l'étoffe (la couleur suit la palette du
## vêtement, rien de saturé), puis arête sombre. Pas de fil d'or vif ni de losanges rouges.
static func _bordure(z: Zone, y0: int, sens: int, n: int, reg: int, motif := true) -> void:
	for k in n:
		var y := y0 + sens * k
		for x in z.w:
			if k == 0:
				z.ton(x, y, 1, reg)
			elif k == 1:
				z.ton(x, y, 4 if (x & 7) != 5 else 3, reg)                     # filet clair du repli
			elif k == n - 1:
				z.ton(x, y, 2, reg)
			elif motif and n >= 5 and k == 2:
				z.ton(x, y, 5 if (x % 8) < 5 else 2, reg)
			elif motif and n >= 5 and k == 3:
				z.ton(x, y, 5 if (x & 3) == 0 else 2, reg)
			elif k == n - 2 and n > 4:
				z.ton(x, y, 4, reg)                                             # lèvre claire de l'arête
			else:
				z.ton(x, y, 2 + int(_h(x, k, z.g) > 0.6), reg)

## Usure : deux plaques élimées (ton +1, trame qui perce) aux endroits qui frottent, placées par le nom de la pièce.
static func _usure(z: Zone, reg: int, nom: String) -> void:
	if z.w < 14 or z.fin - z.debut < 14 or nom == "tablier":
		return
	var centres: Array = []
	if nom == "torse":
		centres = [[z.w / 4, z.debut + int((z.fin - z.debut) * 0.45)], [(z.w * 3) / 4, z.debut + int((z.fin - z.debut) * 0.80)]]
	elif nom.begins_with("manche"):
		centres = [[z.w / 2, z.v_vers_y(float(z.info["anneaux"][2][0]))]]
	else:
		centres = [[(z.g * 3) % z.w, z.debut + (z.g * 5) % maxi(z.fin - z.debut, 1)]]
	for c in centres:
		for j in range(-4, 5):
			for i in range(-6, 7):
				var d2 := float(i * i) / 36.0 + float(j * j) / 16.0
				if d2 > 1.0:
					continue
				var x: int = c[0] + i
				var y: int = c[1] + j
				if y < 0 or y >= z.h + 2:
					continue
				var px := z.img.get_pixel(z.x0 + posmod(x, z.w), z.y0 + y)
				var t := int(round(px.r * 255.0)) / 32
				if int(round(px.g * 255.0)) / 16 != reg:
					continue
				var h := _h(x, y, z.g + 21)
				z.ton(x, y, clampi(t + (1 if h > 0.35 else -1) * (1 if d2 < 0.6 else 0) + (1 if d2 >= 0.6 else 0), 0, 7), reg)

## Cuir épais roussi (tablier) : grain, plis horizontaux, brûlures sombres vers le bas, coutures du bord, 2 rivets.
static func _cuir_brule(z: Zone, reg: int) -> void:
	for y in z.h + 2:
		var t_rel := float(y - z.debut) / maxf(float(z.fin - z.debut), 1.0)
		for x in z.w:
			var l := 0.48 + (_n(x, y, z.w, z.h, 6, 4, z.g) - 0.5) * 0.30 + (_n(x, y, z.w, z.h, 22, 14, z.g + 1) - 0.5) * 0.14 + (_h(x, y, z.g + 2) - 0.5) * 0.06
			l += 0.05 * sin(float(y) * 0.55 + float(x) * 0.08)                 # plis d'assouplissement
			var brule := _n(x, y, z.w, z.h, 5, 5, z.g + 3)
			l -= 0.20 * smoothstep(0.55, 0.85, brule) * smoothstep(0.7, 0.0, t_rel)    # roussi, surtout au bas (debut = ourlet)
			z.ton(x, y, _t(l, x, y, 0.35), reg)
	for y in range(z.debut + 2, z.fin - 2):
		if (y % 3) != 2:
			z.ton(1, y, 5, reg)
			z.ton(z.w - 2, y, 5, reg)
	for yy in [z.debut + 8, z.fin - 8]:
		for dx in [3, z.w - 4]:
			z.fixe(dx, yy, 3)
			z.fixe(dx + 1, yy, 4)

static func _tunique(z: Zone, reg: int, cle: String) -> void:
	var info := z.info
	var nom0 := cle.get_slice(".", 1)
	if nom0 == "tablier":
		_cuir_brule(z, reg)                                  # tablier de forge : cuir épais roussi
	elif nom0.begins_with("cote") or nom0 == "avant" or nom0 == "arriere":
		_laine(z, reg, 5, 0.12, true)                        # robe : toile fine
		for y in z.h + 2:                                    # fils plus gros (nopes) : traits horizontaux courts
			for x in z.w:
				if _h(x / 5, y, z.g + 11) > 0.93:
					for i in 4:
						z.ton(x + i, y, 5, reg)
	elif nom0 == "panneau" or nom0 == "capuche":
		_laine(z, reg, 7, 0.20, false)                       # cape / capuche : gros drap pelucheux
		for y in z.h + 2:
			for x in z.w:
				if _h(x, y, z.g + 12) > 0.90:
					z.ton(x, y, 6, reg)
	else:
		_laine(z, reg, 5, 0.16, false)
	_usure(z, reg, nom0)
	var bw := maxi(3, int(round(z.d * 0.16)))
	match String(info["bord_debut"]):
		"ourlet": _bordure(z, z.debut, 1, bw + 3, reg)
	match String(info["bord_fin"]):
		"col":
			# v3 : encolure sobre, bande tissée fine dans les tons du vêtement (plus de zigzag jaune)
			for k in maxi(3, bw - 1):
				for x in z.w:
					var t := 2 if k == 0 else (4 if (k == 1 and (x & 1) == 0) else 3)
					z.ton(x, z.fin - k, t, reg)
		"poignet": _bordure(z, z.fin, -1, maxi(4, bw), reg, false)
		"ourlet": _bordure(z, z.fin, -1, bw + 3, reg)
	# coutures : dos (colonne 0) et, sur un torse, les deux côtés (points clairs 2 sur 1, fil plus clair que l'étoffe)
	var nom := cle.get_slice(".", 1)
	var coutures: Array = [0]
	if nom == "torse":
		coutures = [0, z.w / 4, (z.w * 3) / 4]
	for cx: int in coutures:
		for y in range(z.debut + bw + 4, z.fin - 2):
			if (y % 3) != 2:
				z.ton(cx, y, 5, reg)
				z.ton(cx + 1, y, 2, reg)                                # ombre du surjet
	if nom.begins_with("manche"):
		# plis du coude : trois fronces cassées + patine claire sur le pli
		var ye := z.v_vers_y(float(info["anneaux"][2][0]))
		for k in [-3, 0, 3]:
			for x in z.w:
				if ((x + k * 2) % 7) < 4:
					z.ton(x, ye + k, 2 if k != 0 else 1, reg)
					z.ton(x, ye + k + 1, 5, reg)
	if nom == "torse":
		# fronces au-dessus de la ceinture : petits plis obliques sur 2 rangées
		var yf := z.debut + int(float(z.fin - z.debut) * 0.30)
		for x in z.w:
			var h := _h(x / 3, 5, z.g)
			if h > 0.45:
				z.ton(x, yf + (x & 1), 2, reg)
				z.ton(x, yf + 1 + (x & 1), 5, reg)
		# col : laçage en V (deux cordons) au milieu du devant
		var xc := z.w / 2
		for k in 7:
			z.ton(xc - 1 - k / 2, z.fin - 3 - k, 5, reg)
			z.ton(xc + 1 + k / 2, z.fin - 3 - k, 5, reg)
		for k in 7:
			z.ton(xc, z.fin - 3 - k, 1, reg)
	# une pièce rapportée cousue, une reprise (placées par le nom : chaque pièce a la sienne)
	var g := z.g
	if z.fin - z.debut > 14 and z.w > 12:
		var px := 4 + g % maxi(z.w - 12, 1)
		var py := z.debut + bw + 6 + g % maxi(z.fin - z.debut - bw - 12, 1)
		for j in 4:
			for i in 5:
				z.ton(px + i, py + j, 4 + int(((i + j) & 3) < 2), reg)
		for i in 5:
			z.ton(px + i, py, 6, reg)
			z.ton(px + i, py + 3, 2, reg)
		for j in 4:
			z.ton(px - 1, py + j, 5 if (j & 1) == 0 else 3, reg)           # fil de reprise
			z.ton(px + 5, py + j, 5 if (j & 1) == 0 else 3, reg)

static func _pantalon(z: Zone) -> void:
	_laine(z, PAN, 6, 0.18, true)
	# revers de cheville (fin) : deux rangs
	for x in z.w:
		z.ton(x, z.fin, 1, PAN)
		z.ton(x, z.fin - 1, 5, PAN)
	# genou : pièce plus sombre cousue
	var yg := z.debut + int((z.fin - z.debut) * 0.5)
	for j in range(-2, 3):
		for i in z.w:
			if absi(i - z.w / 2) < 4 + 1:
				z.ton(i, yg + j, 2 + int(_h(i, j, z.g) > 0.7), PAN)
	# couture exterieure
	for y in range(z.debut + 3, z.fin - 3):
		if (y & 3) < 2:
			z.ton(0, y, 5, PAN)

static func _cuir(z: Zone, cle: String) -> void:
	for y in z.h + 2:
		for x in z.w:
			var l := 0.50 + (_n(x, y, z.w, z.h, 7, 4, z.g) - 0.5) * 0.40 + (_n(x, y, z.w, z.h, 24, 12, z.g + 1) - 0.5) * 0.18 + (_h(x, y, z.g + 2) - 0.5) * 0.06
			z.ton(x, y, _t(l, x, y, 0.4), CUIR)
	var nom := cle.get_slice(".", 1)
	var bords := [String(z.info["bord_debut"]), String(z.info["bord_fin"])]
	# arêtes : lèvre claire en haut, ombre en bas de la bande
	for x in z.w:
		z.ton(x, z.debut, 6, CUIR)
		z.ton(x, z.debut + 1, 5, CUIR)
		z.ton(x, z.fin, 1, CUIR)
		z.ton(x, z.fin - 1, 2, CUIR)
	# points de couture
	for x in z.w:
		if (x & 3) < 2:
			z.ton(x, z.debut + 3, 6, CUIR)
			z.ton(x, z.fin - 3, 6, CUIR)
	if nom.begins_with("ceinture"):
		# boucle de fer au milieu de l'avant
		var xc := z.w / 2
		var ym := (z.debut + z.fin) / 2
		for j in range(-2, 3):
			for i in range(-3, 4):
				var bord := absi(i) == 3 or absi(j) == 2
				z.fixe(xc + i, ym + j, 4 if bord else F_FER)
		for i in range(-1, 2):
			z.fixe(xc + i, ym, 0)
		# v2 : clous de laiton tous les 6 texels, une rangée de trous d'ardillon d'un côté de la boucle, languette qui pend
		for x in range(3, z.w, 6):
			if absi(x - xc) > 6:
				z.fixe(x, ym, F_OR)
				z.ton(x, ym - 1, 1, CUIR)
		for k in 3:
			z.fixe(xc + 6 + k * 3, ym, 0)
		for j in range(-1, 2):
			z.ton(xc + 4, ym + j, 7, CUIR)
	elif nom.begins_with("bracelet"):
		for x in range(2, z.w, 6):
			z.fixe(x, (z.debut + z.fin) / 2, 3)
	elif nom.begins_with("botte"):
		# v2 : fut de cuir avec deux sangles bouclees, couture sous le revers, SEMELLE sur la couture du dos de l'anneau (colonne 0 = dessous du pied),
		# bout arrondi use et eclairci, boue vers la semelle
		var an: Array = z.info["anneaux"]
		var ya := z.v_vers_y(float(an[1][0]))                       # ligne de la cheville
		for y in range(z.debut, z.debut + maxi(3, int(z.d * 0.12))):
			for x in z.w:
				z.ton(x, y, 5 if ((x + y) & 3) < 2 else 4, CUIR)
		for k in [0.35, 0.72]:
			var ys := z.debut + int(float(ya - z.debut) * k)
			for x in z.w:
				z.ton(x, ys, 1, CUIR)
				z.ton(x, ys + 1, 5 if (x & 3) != 3 else 2, CUIR)
				z.ton(x, ys - 1, 2, CUIR)
			z.fixe(z.w / 2, ys, 3)
			z.fixe(z.w / 2 + 1, ys, 4)                                # boucle de fer au milieu du cou-de-pied
		for y in range(ya - 2, z.h + 2):
			var t := clampf(float(y - ya) / maxf(float(z.fin - ya), 1.0), 0.0, 1.0)
			var ep := 1 + int(round(t * 2.0))                         # la semelle s'epaissit vers l'orteil
			for x in range(-ep, ep + 1):
				z.ton(x, y, 0 if absi(x) < ep else 1, CUIR)
			z.ton(ep + 1, y, 5 if (y & 1) == 0 else 2, CUIR)          # couture de la semelle
			z.ton(-ep - 2, y, 5 if (y & 1) == 0 else 2, CUIR)
			if y > ya + 2:
				for x in z.w:
					var xs := minf(float(x), float(z.w - x))
					if xs > float(ep) + 2.0:
						var usure := 0.20 * smoothstep(float(z.fin - 8), float(z.fin + 2), float(y)) * (_n(x, y, z.w, z.h, 6, 4, z.g + 4))
						z.ton(x, y, clampi(4 + int(round(usure * 10.0)), 3, 7), CUIR)
		for x in z.w:
			var bas := _h(x, 0, z.g + 6) > 0.55
			z.ton(x, z.fin - 3, 1 if bas else 2, CUIR)
	elif nom.begins_with("carquois") or nom.begins_with("sacoche"):
		for y in range(z.debut + 2, z.fin - 1, 7):
			for x in z.w:
				if (x & 3) != 3:
					z.ton(x, y, 1, CUIR)

static func _peau(z: Zone) -> void:
	for y in z.h + 2:
		for x in z.w:
			var l := 0.56 + (_n(x, y, z.w, z.h, 4, 3, z.g) - 0.5) * 0.26 + (_h(x, y, z.g + 3) - 0.5) * 0.05
			# ombre sous la face inferieure (colonnes du milieu de la moitie) : relief des mains / du cou
			l -= 0.10 * smoothstep(0.55, 1.0, float(y - z.debut) / maxf(float(z.fin - z.debut), 1.0))
			z.ton(x, y, _t(l, x, y, 0.35), PEAU)
	for x in z.w:
		z.ton(x, z.debut, 2, PEAU)

## Cheveux et barbes v2 : meches de 2-3 texels qui ondulent, reflet doux, pointes plus claires, racines sombres. Barbe : le bord haut s'effiloche (alpha decoupe) et
## une fenetre a la bouche laisse voir la bouche peinte du visage (piece double face).
static func _poil(z: Zone) -> void:
	var tresse := bool(z.info.get("tresse", 0))
	var barbe := z.info.has("z_bouche")
	for y in z.h + 2:
		var t_rel := float(y - z.debut) / maxf(float(z.fin - z.debut), 1.0)
		for x in z.w:
			var xs := x + int(round(sin(float(y) * 0.30 + float(x / 5) * 1.7) * 1.3))
			var meche := _h(xs / 2, 3, z.g)                       # luminosite de la meche (2 texels de large)
			var l := 0.46 + (meche - 0.5) * 0.38 + (_n(x, y, z.w, z.h, 9, 4, z.g + 1) - 0.5) * 0.12 + (_h(x, y, z.g + 2) - 0.5) * 0.08
			l += 0.15 * smoothstep(0.30, 0.0, absf(t_rel - 0.34))                # reflet
			if tresse:
				var c := ((x + y) % 6) < 3                                      # nattes : chevrons obliques
				l = 0.60 if c else 0.30
				l += (meche - 0.5) * 0.20 + (_h(x, y, z.g) - 0.5) * 0.10
			var a := 255
			if barbe:
				l -= 0.10 * smoothstep(0.55, 1.0, t_rel)                        # le bas de la barbe est dans l'ombre du menton
				if y - z.debut < 3 and _h(x, 1, z.g + 9) * 3.0 > float(y - z.debut) + 0.4 and not tresse:
					a = 0                                                       # bord haut effiloche (favoris)
			z.ton(x, y, _t(l, x, y, 0.40), CHEV, a)
	if barbe and not tresse:
		# barbe : fenetre sur la bouche du visage (transparente), moustache juste au-dessus (la rangee suivante vers le bas du chemin = vers le menton)
		var yb := z.z_vers_y(float(z.info["z_bouche"]))
		var xc := z.w / 2
		var lw := int(round(0.043 * z.d * float(z.info.get("echelle", 1.0))))
		for j in range(-2, 3):
			for i in range(-lw, lw + 1):
				if absi(j) == 2 and absi(i) > lw - 2:
					continue
				z.ton(xc + i, yb + j, 1, CHEV, 0)                               # fenetre
		for i in range(-lw - 2, lw + 3):
			z.ton(xc + i, yb - 3, 5 if absi(i) < lw else 2, CHEV)               # moustache : levre haute couverte
			z.ton(xc + i, yb - 4, 3, CHEV)

static func _fourrure(z: Zone) -> void:
	for y in z.h + 2:
		var vy := z.fin - y
		for x in z.w:
			var l := 0.52 + (_n(x, y, z.w, z.h, 18, 5, z.g) - 0.5) * 0.7 + (_h(x, y, z.g + 2) - 0.5) * 0.25
			# mèches : pointes plus claires vers la fin
			l += 0.20 * smoothstep(5.0, 0.0, float(vy))
			var a := 255
			if vy < 4 and _h(x, 0, z.g + 9) * 4.0 > float(vy) + 0.5:
				a = 0                      # bord de mèches découpé net (alpha scissor)
			z.ton(x, y, _t(l, x, y, 0.45), FOUR, a)

static func _fer(z: Zone) -> void:
	for y in z.h + 2:
		for x in z.w:
			var l := 0.5 + (_n(x, y, z.w, z.h, 5, 4, z.g) - 0.5) * 0.5
			z.fixe(x, y, clampi(int(l * 4.0 + (_h(x, y, z.g) - 0.5) * 0.7), 0, 4))
	for x in z.w:
		z.fixe(x, z.debut, 4)
		z.fixe(x, z.debut + 1, 3)

## Visage v2 : cylindre (l'avant est a la moitie du tour), 128 texels/m. Les rangees croissent VERS LE HAUT du visage (menton -> crane). Lumiere peinte (orbites,
## pommettes, dessous du menton), yeux de 5 x 3 texels (paupiere, blanc, iris, pupille, reflet), sourcils par variante, ailes du nez, bouche (levres, commissures),
## menton. Aucun tramage regulier : le bruit est un bruit de valeur a seuil.
static func _visage(z: Zone, femme: bool) -> void:
	var inf := z.info
	var d := z.d
	var v := int(inf.get("var", 1))
	var yE := z.z_vers_y(float(inf["z_yeux"]))
	var yN := z.z_vers_y(float(inf["z_nez"]))
	var yM := z.z_vers_y(float(inf["z_bouche"]))
	var yC := z.z_vers_y(float(inf["z_menton"]))
	var ec := float(inf["ecart_yeux"]) * d
	var yB := yE + 3 + (1 if v == 3 else 0)                 # sourcils : 3 rangees au-dessus de l'oeil (4 pour le visage rond)
	# --- 1. volumes : lumiere douce + bruit de valeur
	for y in z.h + 2:
		var xc := z.tour_a(y) * 0.5
		for x in z.w:
			var dx := float(x) - xc
			var s := absf(dx) / d / 0.085                       # 0 = milieu du visage, 1 = le cote
			var l := 0.60 - 0.27 * smoothstep(0.62, 1.25, s)
			l += 0.05 * smoothstep(float(yB), float(yB + 7), float(y))                      # front plus clair
			l -= 0.13 * smoothstep(float(yM - 1), float(yC - 1), float(y))                  # dessous du menton dans l'ombre
			var oeil := absf(absf(dx) - ec) / 4.2                                           # orbite : ombre autour de chaque oeil
			l -= 0.11 * exp(-(oeil * oeil + pow((float(y) - float(yE) - 0.5) / 3.2, 2.0)))
			l += 0.05 * exp(-(pow((absf(dx) - 0.058 * d) / 3.0, 2.0) + pow((float(y) - float(yN) - 1.0) / 3.2, 2.0)))   # pommette
			l -= 0.05 * exp(-(pow((absf(dx) - 0.050 * d) / 2.5, 2.0) + pow((float(y) - float(yN) + 3.0) / 3.0, 2.0)))   # creux de la joue
			l -= 0.06 * exp(-(pow(dx / 5.0, 2.0) + pow((float(y) - float(yN) + 1.0) / 1.6, 2.0)))                       # dessous du nez
			l += (_n(x, y, z.w, z.h, 7, 5, z.g) - 0.5) * 0.08 + (_h(x, y, z.g + 4) - 0.5) * 0.05
			z.ton(x, y, _t(l, x, y, 0.3), PEAU)
	var xc_e := z.tour_a(yE) * 0.5
	# --- 2. yeux (5 x 3 texels) : paupiere, blanc, iris, pupille, reflet, poche
	for s: int in [-1, 1]:
		var cx := int(round(xc_e + s * ec))
		for i in range(-3, 4):
			z.ton(cx + i, yE + 2, 2 if absi(i) < 3 else 3, PEAU)                           # pli de la paupiere
		for i in range(-2, 3):                                                         # ligne des cils (fonce chez les femmes)
			if femme:
				z.fixe(cx + i, yE + 2, 14)
			else:
				z.ton(cx + i, yE + 2, 1, PEAU)
		for r in 2:                                                                    # rangee haute (r = 1) et basse (r = 0)
			for i in range(-2, 3):
				if absi(i) == 2:
					z.fixe(cx + i, yE + r, F_BLANC if (i * s) > 0 or r == 1 else 8)            # blanc ; coin interieur un peu gris
				elif i == 0 and r == 1:
					z.fixe(cx + i, yE + r, F_NOIR)                                          # pupille
				else:
					z.ton(cx + i, yE + r, 2 if r == 1 else 4, IRIS)
		z.ton(cx - s, yE, 6, IRIS)                                                     # reflet clair dans l'iris
		for i in range(-1, 2):
			z.ton(cx + i, yE - 1, 3, PEAU)                                              # poche sous l'oeil
		if femme:
			z.ton(cx - 2 * s, yE + 1, 2, PEAU)
	# --- 3. sourcils (par variante : 1 carre, droit et epais ; 2 long, arque fin ; 3 rond, haut et doux)
	for s: int in [-1, 1]:
		var bw := (7 if v == 1 else 6) - (1 if femme else 0)
		var cxb := xc_e + s * (ec + 0.3)
		for i in range(-bw / 2, bw / 2 + 1):
			var ext := absi(i)                      # distance au centre ; l'extremite EXTERIEURE descend
			var ext_ext := float(i * s) > 0.0
			var yy := yB + (0 if not ext_ext else (-1 if ext >= bw / 2 else 0))
			var ton_b := 1 if ext < bw / 2 else 3
			z.ton(int(round(cxb)) + i, yy, ton_b, CHEV)
			if not femme and v != 3:
				z.ton(int(round(cxb)) + i, yy + 1, 2 if ext < bw / 2 else 4, CHEV)     # sourcil epais : 2e rangee
			elif v == 2 and ext_ext:
				z.ton(int(round(cxb)) + i, yy + 1, 4, CHEV)
	# --- 4. nez : arete claire, plans lateraux, narines, ombre portee (la geometrie du nez est une piece separee : on peint son pied)
	var xcn := int(round(z.tour_a(yN) * 0.5))
	for k in range(-1, 5):
		z.ton(xcn, yN + k, 6 if k > 1 else 5, PEAU)
	for k in range(-1, 4):
		z.ton(xcn - 2, yN + k, 3, PEAU)
		z.ton(xcn + 2, yN + k, 3, PEAU)
	z.ton(xcn - 2, yN - 1, 1, PEAU)
	z.ton(xcn + 2, yN - 1, 1, PEAU)
	for i in range(-2, 3):
		z.ton(xcn + i, yN - 2, 2, PEAU)
	# --- 5. bouche : levre haute, fente, levre basse (+ rouge pour les femmes), commissures (variante 2 : leger sourire, 3 : levres pleines)
	var xcb := int(round(z.tour_a(yM) * 0.5))
	var bw2 := (4 if v == 1 else 3) + (0 if femme else 1)
	for i in range(-bw2, bw2 + 1):
		var bord := absi(i) == bw2
		var yl := yM + (1 if (v == 2 and bord) else 0)
		if femme:
			z.fixe(xcb + i, yl + 1, 12 if not bord else 14)                              # levre haute
			z.fixe(xcb + i, yl, 14 if absi(i) < bw2 else 12)                              # fente
			if not bord:
				z.fixe(xcb + i, yl - 1, 13 if absi(i) < bw2 - 1 else 12)                  # levre basse
				if v == 3:
					z.fixe(xcb + i, yl - 2, 12)
		else:
			z.ton(xcb + i, yl + 1, 3 if not bord else 4, PEAU)
			z.ton(xcb + i, yl, 0 if not bord else 2, PEAU)
			if not bord:
				z.ton(xcb + i, yl - 1, 5 if absi(i) < bw2 - 1 else 4, PEAU)
	z.ton(xcb, yM - 1, 6, PEAU)                                                          # reflet de la levre basse
	for i in range(-2, 3):
		z.ton(xcb + i, yM - 2 - (1 if v == 3 else 0), 3, PEAU)                           # creux sous la levre
	# --- 6. menton et machoire
	var xcm := int(round(z.tour_a(yC + 3) * 0.5))
	z.ton(xcm, yC + 3, 6, PEAU)
	z.ton(xcm - 1, yC + 3, 5, PEAU)
	z.ton(xcm + 1, yC + 3, 5, PEAU)
	if v == 1 and not femme:
		z.ton(xcm, yC + 4, 3, PEAU)                                                      # fossette du menton carre

## Nez v3 : le tube a 4 pans, le dessus (th = 90 deg) est au milieu du tour : arete claire au centre, plans latéraux moyens, dessous (couture) et narines dans l'ombre.
static func _nez(z: Zone) -> void:
	for y in z.h + 2:
		var t_rel := float(y - z.debut) / maxf(float(z.fin - z.debut), 1.0)
		for x in z.w:
			var a := absf(float(x) / float(z.w) - 0.5) * 2.0            # 0 = arete du dessus, 1 = dessous
			var l := 0.66 - 0.40 * smoothstep(0.15, 0.95, a) - 0.12 * smoothstep(0.55, 1.0, t_rel)
			if a < 0.18:
				l += 0.10                                              # arete claire
			z.ton(x, y, _t(l, x, y, 0.2), PEAU)

## Oreille v3 : bord clair, creux de la conque plus sombre au centre (la pointe du tube), lobe un peu plus clair.
static func _oreille(z: Zone) -> void:
	for y in z.h + 2:
		var t_rel := float(y - z.debut) / maxf(float(z.fin - z.debut), 1.0)
		for x in z.w:
			var l := 0.56 - 0.24 * smoothstep(0.45, 1.0, t_rel) + (_h(x, y, z.g) - 0.5) * 0.06
			if t_rel < 0.2:
				l += 0.08
			z.ton(x, y, _t(l, x, y, 0.25), PEAU)
