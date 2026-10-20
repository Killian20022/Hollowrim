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
const VERSION := 4
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
	z.d = dens
	z.w = int(ceil(float(info["umax"]) * dens))
	z.h = int(ceil((float(info["vmax"]) - float(info["vmin"])) * dens))
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
			"cheveux", "barbe": _poil(z)
			"fourrure": _fourrure(z)
			"fer": _fer(z)
			_: _tunique(z, TUN, cle)
	return img

## Sergé : nervures diagonales, plis verticaux doux, salissure vers le DEBUT (ourlet) ; `fin` = maille plus fine.
static func _laine(z: Zone, reg: int, plis := 5, sale := 0.14, fin := false) -> void:
	for y in z.h + 2:
		var vy := y - z.debut
		for x in z.w:
			var sg := (0.05 if ((x + y) & 3) < 2 else -0.03) if not fin else (0.05 if ((x + y) & 1) == 0 else -0.03)
			var l := 0.52 + sg + (_h(x, 0, z.g) - 0.5) * 0.06 + (_h(0, y, z.g + 1) - 0.5) * 0.06
			l += (_n(x, y, z.w, z.h, plis, 3, z.g + 2) - 0.5) * 0.24
			l -= sale * smoothstep(float(z.d) * 0.9, 0.0, float(vy))
			z.ton(x, y, _t(l, x, y), reg)

## Bordure brodee de `n` rangees a partir de la ligne y0, vers le bas de l'image (+1) ou le haut (-1) : repli, fil d'or, losanges.
static func _bordure(z: Zone, y0: int, sens: int, n: int, reg: int, motif := true) -> void:
	for k in n:
		var y := y0 + sens * k
		for x in z.w:
			if k == 0:
				z.ton(x, y, 1, reg)
			elif k == 1 or k == n - 1:
				if ((x + k) & 3) < 3:
					z.fixe(x, y, F_OR)
				else:
					z.ton(x, y, 2, reg)
			elif k == n - 2 and n > 4:
				z.ton(x, y, 5, reg)               # lèvre claire de l'arête
			else:
				var m := motif and ((x + (k & 1) * 2) % 8) < 2
				if m:
					z.fixe(x, y, 12)
				else:
					z.ton(x, y, 2 + int(_h(x, k, z.g) > 0.6), reg)

static func _tunique(z: Zone, reg: int, cle: String) -> void:
	var info := z.info
	_laine(z, reg, 5, 0.14, false)
	var bw := maxi(3, int(round(z.d * 0.16)))
	match String(info["bord_debut"]):
		"ourlet": _bordure(z, z.debut, 1, bw + 3, reg)
	match String(info["bord_fin"]):
		"col":
			for k in maxi(2, bw - 2):
				for x in z.w:
					z.ton(x, z.fin - k, 1 if k == 0 else 2, reg)
					if k == 1 and (x & 3) != 3:
						z.fixe(x, z.fin - k, F_OR)
		"poignet": _bordure(z, z.fin, -1, maxi(4, bw), reg, false)
		"ourlet": _bordure(z, z.fin, -1, bw + 3, reg)
	# couture verticale du dos (colonne 0) : points clairs
	for y in range(z.debut + bw + 4, z.fin - 2):
		if (y & 3) < 2:
			z.ton(0, y, 5, reg)
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
	elif nom.begins_with("bracelet"):
		for x in range(2, z.w, 6):
			z.fixe(x, (z.debut + z.fin) / 2, 3)
	elif nom.begins_with("botte"):
		# revers de fourrure au haut du fût, semelle sombre vers l'orteil
		for y in range(z.debut, z.debut + maxi(3, int(z.d * 0.12))):
			for x in z.w:
				z.ton(x, y, 5 if ((x + y) & 3) < 2 else 4, CUIR)
		for y in range(z.fin - 2, z.fin + 4):
			for x in z.w:
				z.ton(x, y, 1, CUIR)
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

static func _poil(z: Zone) -> void:
	var tresse := bool(z.info.get("tresse", 0))
	for y in z.h + 2:
		for x in z.w:
			var l := 0.50 + (_n(x, y, z.w, z.h, 22, 3, z.g) - 0.5) * 0.62 + (_h(x, 0, z.g + 5) - 0.5) * 0.20
			l += 0.16 * smoothstep(0.4, 0.0, absf(float(y - z.debut) / maxf(float(z.fin - z.debut), 1.0) - 0.30))     # reflet
			if tresse:
				# nattes : chevrons obliques de 3 px
				var c := ((x + y) % 6) < 3
				l = 0.62 if c else 0.28
				l += (_h(x, y, z.g) - 0.5) * 0.12
			z.ton(x, y, _t(l, x, y, 0.45), CHEV)
	# bords du bas effilochés / cheveux plus sombres près de la racine
	for x in z.w:
		z.ton(x, z.debut, 1, CHEV)
	if z.info.has("z_bouche"):
		# barbe : la bouche reste visible (peau, lèvres) sous une moustache
		var yb := z.z_vers_y(float(z.info["z_bouche"]))
		var xc := z.w / 2
		var lw := int(round(0.05 * z.d * float(z.info.get("echelle", 1.0))))
		for j in range(-1, 2):
			for i in range(-lw / 2, lw / 2 + 1):
				z.ton(xc + i, yb + j, 3 if j != 0 else 1, PEAU)
		for i in range(-lw / 2 - 1, lw / 2 + 2):
			z.ton(xc + i, yb - 2, 1, CHEV)

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

## Visage : cylindre (l'avant est a la moitie du tour). Volumes de la geometrie + yeux, sourcils, bouche et reflets peints a la meme densite que le reste.
static func _visage(z: Zone, femme: bool) -> void:
	var inf := z.info
	var d := z.d
	var v := int(inf.get("var", 1))
	for y in z.h + 2:
		var xc := z.tour_a(y) * 0.5
		for x in z.w:
			var s := absf(float(x) - xc) / d / 0.085          # 0 = milieu du visage, 1 = le côté
			var l := 0.60 - 0.26 * smoothstep(0.65, 1.25, s)
			l += (_n(x, y, z.w, z.h, 6, 4, z.g) - 0.5) * 0.10 + (_h(x, y, z.g + 4) - 0.5) * 0.04
			z.ton(x, y, _t(l, x, y, 0.3), PEAU)
	var yy := z.z_vers_y(float(inf["z_yeux"]))
	var ec := float(inf["ecart_yeux"]) * d
	var pw := maxi(1, int(round(0.026 * d * float(inf.get("echelle", 1.0)))))
	for s: int in [-1, 1]:
		var xc2 := z.tour_a(yy) * 0.5 + s * ec
		# orbite : ombre au-dessus (arcade), blanc, iris, reflet
		for i in range(-pw, pw + 1):
			z.ton(int(xc2) + i, yy - 1 - (1 if d >= 48 else 0), 2, PEAU)
		for i in pw:
			var xi := int(round(xc2)) - pw / 2 + i
			var iris := i == pw / 2 or (pw >= 3 and i == pw / 2 + 1 and s > 0) or (pw >= 3 and i == pw / 2 - 1 and s < 0)
			if iris:
				z.ton(xi, yy, 1, IRIS)
			else:
				z.fixe(xi, yy, F_BLANC)
		if femme:
			for i in pw:
				z.ton(int(round(xc2)) - pw / 2 + i, yy - 1, 0, CHEV)
	# sourcils
	var ys := z.z_vers_y(float(inf["z_sourcils"]))
	for s: int in [-1, 1]:
		var xc3 := z.tour_a(ys) * 0.5 + s * ec
		var bw := int(round((0.040 if not femme else 0.034) * d))
		for i in range(-bw / 2, bw / 2 + 1):
			z.ton(int(round(xc3)) + i, ys - (1 if v == 2 and absi(i) < 1 else 0), 1, CHEV)
			if not femme and d >= 48 and v != 3:
				z.ton(int(round(xc3)) + i, ys - 1, 2, CHEV)
	# nez : arete claire, narines
	var yn := z.z_vers_y(float(inf["z_nez"]))
	var xcn := z.tour_a(yn) * 0.5
	for k in 2 + int(d >= 48):
		z.ton(int(round(xcn)), yn - k, 6, PEAU)
	z.ton(int(round(xcn)) - 1, yn + 1, 2, PEAU)
	z.ton(int(round(xcn)) + 1, yn + 1, 2, PEAU)
	# pommettes
	for s: int in [-1, 1]:
		z.ton(int(round(xcn + s * 0.050 * d)), yn - 1, 6, PEAU)
	# bouche : trait sombre, lèvre inférieure plus claire
	var yb := z.z_vers_y(float(inf["z_bouche"]))
	var bw2 := int(round((0.046 if not femme else 0.040) * d))
	var xcb := z.tour_a(yb) * 0.5
	for i in range(-bw2 / 2, bw2 / 2 + 1):
		z.ton(int(round(xcb)) + i, yb, 1 if absi(i) < bw2 / 2 else 2, PEAU)
		z.ton(int(round(xcb)) + i, yb + 1, 5 if absi(i) < bw2 / 3 else 4, PEAU)
		if femme:
			z.fixe(int(round(xcb)) + i, yb, 12 if absi(i) < bw2 / 2 else 14)
	# menton : reflet
	var ym := z.z_vers_y(float(inf["z_menton"]) + 0.012)
	var xcm := z.tour_a(ym) * 0.5
	z.ton(int(round(xcm)), ym, 6, PEAU)
