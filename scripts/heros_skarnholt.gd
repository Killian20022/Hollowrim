class_name HerosSkarnholt
## HÉROS JOUEUR : un garde de Skarnholt « amélioré » (demande de l'utilisateur, 2026-10-27 : « qu'il ressemble à un garde du village
## déjà mais en amélioré »). Même base que les gardes (GardienNordique : corps Quaternius, cotte, tabard, pèlerine, col de fourrure,
## casque à nasal, mêmes atlas peints), avec ce qui le distingue d'un simple garde au premier coup d'œil :
##   - PLASTRON DE LAMES d'acier rivées sur la cotte (5 rangées, la poitrine des gardes est en mailles seules) ;
##   - ÉPAULIÈRES DOUBLÉES (seconde rangée de lames, plus large) ; gants de cuir sombre ÉPAIS à REVERS DE FOURRURE claire aux
##     poignets (référence FPS de l'utilisateur : references/combat_epee/planche_combat_epee_1100.jpg) ;
##   - casque d'acier POLI (le fer des gardes est brun), bandeau, nasal et CRÊTE en laiton ; CAMAIL de mailles sur la nuque (la
##     caméra à la 3e personne regarde la nuque) à la place de l'écharpe ; col de fourrure plus fourni ;
##   - BLEU ROI profond (les gardes : bleu ardoise délavé) et bordures, emblème, franges en LAITON (les gardes : crème) ;
##     cotte d'acier propre (sans rouille), cuirs noircis ; barbe et cheveux blond-roux.
## Pas de lance : épée (corps_joueur.gd) et torche ; animations d'épée d'Humain (Sword_*, Idle_Torch…). Bouclier possible plus tard :
## creer({"bouclier": "bras" | "dos"}) (même bouclier que les gardes, peint en bleu roi). Tête nue : creer({"casque": false}).
##
##   HerosSkarnholt.creer({"casque": true, "bouclier": ""}) -> Node3D      (contrat d'Humain.creer : Skeleton3D, « Animations », ragdoll)
## Corps rangé dans le cache disque (CachePersos, archétype « heros ») ; textures précalculées dans assets/persos/heros/
## (outils/generer_heros.gd, à relancer après toute modification des couleurs ci-dessous, avec VERSION + 1).

const TEINTE_CHEVEUX := Color(0.98, 0.74, 0.50)
const TEINTE_BARBE := Color(0.92, 0.66, 0.44)

static func creer(options := {}) -> Node3D:
	var o := options.duplicate()
	o["heros"] = true
	o["lance"] = false
	o["casque"] = bool(o.get("casque", true))
	o["bouclier"] = String(o.get("bouclier", ""))
	var c := CachePersos.lire("heros", "res://scripts/heros_skarnholt.gd", o, [VERSION])
	if c != null:
		return c
	c = GardienNordique._creer(o)
	CachePersos.ecrire("heros", "res://scripts/heros_skarnholt.gd", o, c, [VERSION])
	return c

# ======================================================================================================== textures
## Couleurs du héros, appliquées aux atlas peints du gardien (même dessin, ton pour ton, par luminance).
const BLEU_ROI := ["#0b0f1f", "#121a36", "#1a2752", "#24376c", "#30498a", "#4360a8"]
const LAITON := ["#2e2310", "#53401c", "#7a6029", "#a2833e", "#c4a65e", "#ddc78e"]
const ACIER := ["#16171a", "#25282d", "#3a3e45", "#555a62", "#757b83", "#9da3aa", "#cdd2d6"]
const DOSSIER := "res://assets/persos/heros"
const VERSION := 1
static var enregistrer := false
static var _cache := {}

static func tex(nom: String) -> ImageTexture:
	if not _cache.has(nom):
		var mips := _charger(nom)
		if mips == null:
			mips = GuerrierTextures.mips_pixel(_peindre(nom))
			_sauver(nom, mips)
		_cache[nom] = ImageTexture.create_from_image(mips)
	return _cache[nom]

static func vider() -> void:
	_cache.clear()

static func _charger(nom: String) -> Image:
	var chemin := "%s/%s.res" % [DOSSIER, nom]
	if not ResourceLoader.exists(chemin):
		return null
	var img := ResourceLoader.load(chemin) as Image
	if img == null or img.get_meta("version", -1) != VERSION:
		return null
	return img

static func _sauver(nom: String, img: Image) -> void:
	if not enregistrer:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
	img.set_meta("version", VERSION)
	ResourceSaver.save(img, "%s/%s.res" % [DOSSIER, nom], ResourceSaver.FLAG_COMPRESS)

## Image de niveau 0 (sans mipmaps) d'une texture du gardien.
static func _base(nom: String) -> Image:
	var img := GardienTextures.tex(nom).get_image()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	return img

## Image de niveau 0 d'une texture du héros.
static func _niveau0(nom: String) -> Image:
	var img := tex(nom).get_image()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	return img

static func _peindre(nom: String) -> Image:
	match nom:
		"mailles":
			return _acier_propre(_base("mailles"), Rect2i(0, 0, 256, 122))
		"brassards":
			return _cuir_noirci(_base("brassards"), Rect2i(0, 0, 128, 64), 0.62)
		"bottes":
			return _cuir_noirci(_base("bottes"), Rect2i(0, 0, 128, 128), 0.78)
		"pantalon", "mante":
			return _base(nom)
		"accessoires":
			var img := _base("accessoires")
			_recolorer(img, GuerrierTextures.R_FACE, _bleu, BLEU_ROI)                # face du bouclier (bouclier possible plus tard)
			_recolorer(img, GuerrierTextures.R_FACE, _creme, LAITON)
			_acier_propre(img, GuerrierTextures.R_PLASTRON)                           # mailles de la poitrine
			_recolorer(img, GardienTextures.R_CASQUE, _tout, ACIER)                   # casque d'acier poli
			_recolorer(img, GardienTextures.R_BANDEAU, _tout, LAITON)                 # bandeau, nasal, crête
			_lames_polies(img, Rect2i(GardienTextures.R_EPAUL.position, Vector2i(96, 29)))   # lames (épaulières, plastron)
			_recolorer(img, GardienTextures.R_LAINE, _bleu, BLEU_ROI)
			_cuir_noirci(img, GuerrierTextures.R_CEINT, 0.70)
			_cuir_noirci(img, GardienTextures.R_GANT, 0.50)                           # gants de cuir sombre
			_cuir_noirci(img, GardienTextures.R_SURCOT, 0.72)
			_cuir_noirci(img, GardienTextures.R_SACOCHE, 0.72)
			return img
		"decoupes":
			var img := _base("decoupes")
			_recolorer(img, Rect2i(0, 0, img.get_width(), img.get_height()), _bleu, BLEU_ROI)
			_recolorer(img, GardienTextures.D_TABARD, _creme, LAITON)
			var pe := GardienTextures.D_PELERINE
			_recolorer(img, Rect2i(pe.position.x, pe.position.y + 26, pe.size.x, pe.size.y - 26), _creme, LAITON)   # emblème (le haut = fourrure)
			return img
		# --- textures des bras à la 1re personne (mains.gd, bras_fps.glb : UV propres, textures répétées)
		"fps_mailles":
			return _niveau0("mailles").get_region(Rect2i(0, 16, 64, 96))
		"fps_fourrure":
			return _niveau0("mante").get_region(Rect2i(96, 40, 32, 32))
		"fps_gant":
			var g := _niveau0("accessoires").get_region(GardienTextures.R_GANT)
			var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
			for y in 96:
				for x in 64:
					img.set_pixel(x, y, g.get_pixel(x % 16, y % 16))
			return img
	push_error("HerosSkarnholt : texture inconnue " + nom)
	return Image.create(8, 8, false, Image.FORMAT_RGBA8)

static func _lum(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114

static func _bleu(c: Color) -> bool:
	return c.b > c.r + 0.035 and c.b >= c.g - 0.01

## Crème des bordures et emblèmes (plus saturé que la fourrure gris-beige, voir GardienTextures.CREME / COL_FOUR).
static func _creme(c: Color) -> bool:
	return c.r - c.b > 0.12 and c.r - c.b < 0.24 and _lum(c) > 0.22

static func _gris(c: Color) -> bool:
	return absf(c.r - c.b) < 0.09

static func _tout(_c: Color) -> bool:
	return true

## Pixels de `r` retenus par `filtre` : remplacés par le ton de `pal` de même rang de luminance (0,03 -> 0,65).
static func _recolorer(img: Image, r: Rect2i, filtre: Callable, pal: Array) -> Image:
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var tons: Array[Color] = []
	for h: String in pal:
		tons.append(Color(h))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			if c.a < 0.5 or not filtre.call(c):
				continue
			var t := clampf((_lum(c) - 0.03) / 0.62, 0.0, 1.0)
			var n := tons[clampi(roundi(t * (tons.size() - 1)), 0, tons.size() - 1)]
			img.set_pixel(x, y, Color(n.r, n.g, n.b, c.a))
	return img

## Mailles d'acier propres : rouille retirée, tons gris acier un peu plus clairs que le fer brun des gardes.
static func _acier_propre(img: Image, r: Rect2i) -> Image:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var l := minf(_lum(c) * 1.12 + 0.01, 1.0)
			img.set_pixel(x, y, Color(l * 0.97, l * 0.99, l * 1.04, c.a))
	return img

## Cuir noirci (assombri, un peu désaturé) ; les tons gris (rivets, métal) gardés.
static func _cuir_noirci(img: Image, r: Rect2i, k: float) -> Image:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			if c.a < 0.5 or c.r - c.b < 0.05:
				continue
			var l := _lum(c)
			img.set_pixel(x, y, Color(lerpf(c.r, l, 0.3) * k, lerpf(c.g, l, 0.3) * k, lerpf(c.b, l, 0.3) * k, c.a))
	return img

## Lames d'acier poli : les tons gris (fer brun des gardes) éclaircis et refroidis, le cuir du bord noirci.
static func _lames_polies(img: Image, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if _gris(c):
				var l := minf(_lum(c) * 1.30 + 0.03, 1.0)
				img.set_pixel(x, y, Color(l * 0.96, l * 0.99, l * 1.05, c.a))
			else:
				img.set_pixel(x, y, Color(c.r * 0.6, c.g * 0.58, c.b * 0.58, c.a))

# ======================================================================================================== 1re personne
## Matières des bras à la 1re personne (bras_fps.glb, par nom de matériau Blender) assorties au corps : manches = cotte d'acier,
## brassards = ceux du corps, gants = cuir sombre des gants, revers des poignets = fourrure claire du col. Voir mains.gd.
static func materiaux_fps() -> Dictionary:
	return {
		"tunique": Palette.materiau(tex("fps_mailles"), Vector2(2, 1), Color.WHITE, true),
		"brassards": Palette.materiau(tex("brassards"), Vector2(1, 1), Color.WHITE, true),
		"gants": Palette.materiau(tex("fps_gant"), Vector2(2, 1), Color(0.74, 0.70, 0.68), true),
		"fourrure": Palette.materiau(tex("fps_fourrure"), Vector2(2, 1), Color(1.08, 1.05, 1.0), true),
		# brassard d'avant-bras (sources_blender/scripts/brassards_skarnholt.py) : coque de cuir sombre, sangles plus
		# sombres, lames et rivets en « fer » (mains.gd), revers de fourrure gris-brun au coude et au poignet
		"brassard_cuir": Palette.materiau(Palette.tex("cuir", Palette.CUIR, 4, 0.5), Vector2(2, 3), Color(0.52, 0.43, 0.38), true),
		"sangle": Palette.materiau(Palette.tex("cuir", Palette.CUIR, 4, 0.5), Vector2(4, 1), Color(0.34, 0.27, 0.23), true),
		"fourrure_sombre": Palette.materiau(tex("fps_fourrure"), Vector2(3, 1), Color(0.6, 0.53, 0.47), true),
	}

# ======================================================================================================== pièces du héros
class AccHeros extends GardienNordique.AccGardien:
	func _init(s: Skeleton3D) -> void:
		super(s)
		col_ample = 1.12
		col_devant = 0.45     # devant du col plus dégagé : le plastron de lames se lit de face

	func _tex_atlas(nom: String) -> ImageTexture:
		return HerosSkarnholt.tex(nom)

	## Appelé par GardienNordique._creer à la place du baudrier des gardes.
	func equiper(pieces: Dictionary, plastron: MeshInstance3D, casque: bool) -> void:
		plaques(plastron)
		epaulieres_doublees(pieces["epaulieres"])
		if pieces.has("gants"):
			poignets(pieces["gants"])
		if casque:
			camail()
			crete()

	# ------------------------------------------------------------ plastron de lames (devant)
	## 5 rangées de lames d'acier rivées (texture des lames d'épaulières), du haut de la poitrine à la ceinture, posées sur le plastron
	## de mailles et qui se recouvrent (bas de chaque lame un peu plus en saillie) ; poids d'os du plastron.
	func plaques(plastron: MeshInstance3D) -> void:
		var a := plastron.mesh.surface_get_arrays(0)
		var EP := GardienTextures.R_EPAUL
		var hauts := [1.41, 1.34, 1.27, 1.20, 1.13]
		var haut_lame := 0.078
		var nseg := 8
		for k in hauts.size():
			var yh: float = hauts[k]
			var yb := yh - haut_lame
			var demi := lerpf(0.130, 0.118, float(k) / (hauts.size() - 1))
			var v0 := EP.position.y + 0.5 + (k % 3) * 9.6
			var v1 := v0 + 9.0
			var prec: Array = []
			for i in nseg + 1:
				var x := lerpf(-demi, demi, float(i) / nseg)
				var ph := _projeter(plastron, x, yh, true)
				var pb := _projeter(plastron, x, yb, true)
				if ph.is_empty() or pb.is_empty() or ph[0].z < 0.04 or pb[0].z < 0.04:
					prec = []
					continue
				var h: Vector3 = ph[0] + ph[1] * 0.012
				var b: Vector3 = pb[0] + pb[1] * 0.020
				var u := EP.position.x + 0.5 + (EP.size.x - 1.0) * float(i) / nseg
				if not prec.is_empty():
					var pw := [_poids_proche(plastron, a, prec[0]), _poids_proche(plastron, a, h), _poids_proche(plastron, a, b), _poids_proche(plastron, a, prec[1])]
					_quad(op, prec[0], h, b, prec[1], _uva(prec[2], v0), _uva(u, v0), _uva(u, v1), _uva(prec[2], v1), pw, Vector3(x, yh, -0.3))
				prec = [h, b, u]
			# chants latéraux de la lame (épaisseur visible de profil)
			for sg: float in [-1.0, 1.0]:
				var ph2 := _projeter(plastron, demi * sg, yh, true)
				var pb2 := _projeter(plastron, demi * sg, yb, true)
				if ph2.is_empty() or pb2.is_empty() or ph2[0].z < 0.04 or pb2[0].z < 0.04:
					continue
				var w := _poids_proche(plastron, a, ph2[0])
				_quad(op, ph2[0], ph2[0] + ph2[1] * 0.012, pb2[0] + pb2[1] * 0.020, pb2[0], _uva(EP.position.x + 1, v0), _uva(EP.position.x + 2, v0), _uva(EP.position.x + 2, v1), _uva(EP.position.x + 1, v1), [w, w, w, w], Vector3(0, yh, 0))

	# ------------------------------------------------------------ épaulières doublées
	## Seconde rangée de lames sous l'épaulière des gardes, plus large et plus en saillie (triangles des épaules seulement).
	func epaulieres_doublees(ep: MeshInstance3D) -> void:
		var EP := GardienTextures.R_EPAUL
		var D := Vector2(GuerrierTextures.ATLAS)
		copier(ep, op, func(uv: Vector2, _p: Vector3) -> Vector2:
				return Vector2(EP.position.x + clampf((uv.x + 0.198) / 0.396, 0.0, 1.0) * (EP.size.x - 0.5), EP.position.y + clampf((uv.y - 0.17) / 0.23, 0.0, 1.0) * (EP.size.y - 0.5)) / D,
			func(p: Vector3, n: Vector3) -> Vector3:
				var f := clampf((absf(p.x) - 0.16) / 0.2, 0.0, 1.0)
				return p + n * 0.044 + Vector3(signf(p.x) * 0.030, -0.050, 0.0) * f,
			func(p0: Vector3, p1: Vector3, p2: Vector3) -> bool: return minf(absf(p0.x), minf(absf(p1.x), absf(p2.x))) > 0.19)

	# ------------------------------------------------------------ revers de fourrure aux poignets
	## Couronne de mèches claires (atlas du col) autour de chaque poignet, sur le haut des gants, dirigée vers la main et vers
	## l'extérieur (référence FPS : gants épais à revers de fourrure). Poids d'os des gants.
	func poignets(gants: MeshInstance3D) -> void:
		var a := gants.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		for cote: String in ["l", "r"]:
			var main := sq.get_bone_global_rest(sq.find_bone("hand_" + cote)).origin
			var coude := sq.get_bone_global_rest(sq.find_bone("lowerarm_" + cote)).origin
			var axe := (main - coude).normalized()
			# centre et rayon du gant à 2 cm avant le poignet (côté coude)
			var centre := main - axe * 0.02
			var rayon := 0.0
			var somme := Vector3.ZERO
			var nb := 0
			for p in v:
				if absf((p - centre).dot(axe)) < 0.012:
					somme += p
					nb += 1
			if nb > 0:
				centre = somme / nb
			for p in v:
				var d := p - centre
				if absf(d.dot(axe)) < 0.012:
					rayon = maxf(rayon, (d - axe * d.dot(axe)).length())
			if rayon <= 0.0:
				rayon = 0.045
			var ref := Vector3.UP - axe * axe.dot(Vector3.UP)
			ref = ref.normalized()
			var ref2 := axe.cross(ref)
			var n := 10
			for i in n:
				var th := TAU * (i + 0.5 * (i % 2)) / n
				var rad := (ref * cos(th) + ref2 * sin(th)).normalized()
				var racine := centre + rad * (rayon + 0.004) - axe * 0.006
				var dir := (axe * 0.70 + rad * 0.72).normalized()
				var c := axe.cross(rad).normalized()
				_carte_col(gants, a, racine, c, dir, 0.050 + _h(i) * 0.012, 0.050 + _h(i + 5) * 0.016, i % 4, false)

	# ------------------------------------------------------------ camail (nuque et joues)
	## Rideau de mailles accroché sous le bord du casque, de joue à joue par la nuque, évasé jusqu'au col de fourrure (qui en cache
	## le bas). Tête -> cou -> haut du dos. Mailles de la poitrine (R_PLASTRON, acier propre).
	func camail() -> void:
		var i_tete := sq.find_bone("Head")
		var i_cou := sq.find_bone("neck_01")
		var i_dos := sq.find_bone("spine_03")
		var R := GuerrierTextures.R_PLASTRON
		# [y, rx, rz, centre z, poids]
		var rangs := [
			[1.712, 0.106, 0.120, -0.008, [PackedInt32Array([i_tete, 0, 0, 0]), PackedFloat32Array([1.0, 0.0, 0.0, 0.0])]],
			[1.630, 0.118, 0.132, -0.014, [PackedInt32Array([i_tete, i_cou, 0, 0]), PackedFloat32Array([0.55, 0.45, 0.0, 0.0])]],
			[1.545, 0.135, 0.148, -0.020, [PackedInt32Array([i_cou, i_dos, 0, 0]), PackedFloat32Array([0.5, 0.5, 0.0, 0.0])]],
		]
		var a0 := PI * 0.5 + 0.95
		var a1 := PI * 2.5 - 0.95
		var n := 12
		for k in rangs.size() - 1:
			var A: Array = rangs[k]
			var B: Array = rangs[k + 1]
			var va := R.position.y + 4.0 + k * 11.0
			var vb := va + 11.0
			for i in n:
				var t0 := lerpf(a0, a1, float(i) / n)
				var t1 := lerpf(a0, a1, float(i + 1) / n)
				var p := func(rg: Array, t: float) -> Vector3: return Vector3(cos(t) * rg[1], rg[0], rg[3] + sin(t) * rg[2])
				var u0 := R.position.x + 4.0 + (R.size.x - 8.0) * float(i) / n
				var u1 := R.position.x + 4.0 + (R.size.x - 8.0) * float(i + 1) / n
				_quad(op, p.call(A, t0), p.call(A, t1), p.call(B, t1), p.call(B, t0), _uva(u0, va), _uva(u1, va), _uva(u1, vb), _uva(u0, vb),
					[A[4], A[4], B[4], B[4]], Vector3(0.0, (float(A[0]) + float(B[0])) * 0.5, -0.01))

	# ------------------------------------------------------------ crête de laiton du casque
	## Arête de laiton sur le sommet du casque, de l'avant à l'arrière (profil de la calotte de GardienNordique.AccGardien.casque).
	func crete() -> void:
		var os_ := sq.find_bone("Head")
		var c := Vector3(0.0, 1.722, -0.008)
		var rz := 0.117
		var profil := [[0.035, 0.99], [0.07, 0.90], [0.10, 0.70], [0.12, 0.42], [0.134, 0.0]]
		var pts: Array[Vector3] = []
		for k in profil.size():
			pts.append(c + Vector3(0, profil[k][0], profil[k][1] * rz))
		for k in range(profil.size() - 2, -1, -1):
			pts.append(c + Vector3(0, profil[k][0], -profil[k][1] * rz))
		var B := GardienTextures.R_BANDEAU
		var e := 0.007
		for k in pts.size() - 1:
			var pa := pts[k]
			var pb := pts[k + 1]
			var na := (pa - c).normalized()
			var nb := (pb - c).normalized()
			var ha := pa + na * 0.018
			var hb := pb + nb * 0.018
			var ua := B.position.x + 2.0 + k * 5.0
			var ub := ua + 5.0
			var vb_ := B.position.y + 1.0
			var vh := B.position.y + B.size.y - 1.0
			for sg: float in [-1.0, 1.0]:
				var dx := Vector3(e * sg, 0, 0)
				_quad(op, pa + dx, pb + dx, hb + dx, ha + dx, _uva(ua, vb_), _uva(ub, vb_), _uva(ub, vh), _uva(ua, vh), os_, c + Vector3(-sg, 0, 0) * 0.5 + Vector3(0, 0.05, 0))
			_quad(op, ha + Vector3(-e, 0, 0), hb + Vector3(-e, 0, 0), hb + Vector3(e, 0, 0), ha + Vector3(e, 0, 0), _uva(ua, vh), _uva(ub, vh), _uva(ub, vh - 2), _uva(ua, vh - 2), os_, c)
