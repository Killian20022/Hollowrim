class_name Interieurs
extends RefCounted
## Constructeur des intérieurs de Skarnholt (lot « kit intérieur »). Un objet `Interieurs` par bâtiment : il range
## ses pièces dans le nœud `Interieur` (`ip.racine`) en réutilisant les lots fusionnés du village
## (`village._ajouter` : un maillage par (parent, matière)) ; matières = les textures du bâti sur le shader
## `ps1_interieur` (ambiante propre à la maison). Repère local = celui du bâtiment : X grand axe, Z largeur, porte
## côté +Z, dessus du plancher à `F` (0,42 m, soubassement à 0,40).
##
## Le dessin du mobilier vit dans `interieurs_halle.gd`, `interieurs_maisons.gd` et `interieurs_forge.gd` ; ce fichier
## donne les briques : matières, boîtes, cylindres, rondins, quads, flammes, halos, lumières, coque (plancher,
## plafond sous charpente, entraits, poteaux) et accessoires courants (table, banc, coffre, tonneau, lit…).

const SHADER := preload("res://shaders/ps1_interieur.gdshader")
const FLAMME_SHADER := preload("res://shaders/crypte_flamme.gdshader")
const F := 0.42
const AMBIANT := Color(0.25, 0.21, 0.23)
const DECAL_PLAFOND := 0.27       # le lambris du plafond pend sous le plan du toit
const FEU := Color(1.0, 0.56, 0.24)

var v: Node3D                     # village
var ip: Interieur
var M: Dictionary
var L := 8.0
var W := 5.5
var y0 := 2.7                     # dessus des murs
var faite := 2.4
var rng := RandomNumberGenerator.new()
var _flammes: Array = []          # [pos, échelle, phase]
var _halos: Array = []            # [centre, normale, w, h, couleur]
var _mats_statiques := {}

static var _atlas: ImageTexture
static var _halo: ImageTexture
static var _rai: ImageTexture

# ------------------------------------------------------------------------------------------------ matières

static func _m(nom: String, teinte := Color.WHITE, texels := 32.0, relief := 0.8, uv_m := false) -> ShaderMaterial:
	var m := TexturesBati.materiau(nom, teinte, texels, relief)
	m.shader = SHADER
	m.set_shader_parameter("ambiant", AMBIANT)
	if uv_m:
		m.set_shader_parameter("uv_metres", true)
	return m

## Toutes les matières d'intérieur (une fois par village).
static func materiaux() -> Dictionary:
	# os et parchemin : peints pour la crypte (images à mipmaps), réutilisés tels quels
	for nom in ["os", "parchemin"]:
		if not TexturesBati._cache.has(nom):
			var img: Image = ResourceLoader.load("res://assets/crypte/%s.res" % nom)
			TexturesBati._cache[nom] = [ImageTexture.create_from_image(img), TexturesBati.relief_neutre()]
	var d := {}
	d["bois"] = _m("planches_h", Color(0.95, 0.9, 0.86))
	d["bois_v"] = _m("planches_v", Color(0.95, 0.9, 0.86))
	d["bois_sombre"] = _m("planches_h", Color(0.62, 0.56, 0.54))
	d["bois_suie"] = _m("planches_v", Color(0.42, 0.38, 0.38))
	d["bois_clair"] = _m("planches_v", Color(1.15, 1.08, 0.98))
	d["ame"] = _m("planches_h", Color(0.3, 0.29, 0.32))
	d["rondin"] = _m("rondins", Color(1.12, 1.05, 1.0), 32.0, 0.9, true)
	d["rondin_sombre"] = _m("rondins", Color(0.8, 0.74, 0.72), 32.0, 0.9, true)
	d["bout"] = _m("bout_rondin", Color.WHITE, 64.0, 0.0, true)
	d["pierre"] = _m("pierre_fine", Color(0.95, 0.9, 0.88))
	d["pierre_sombre"] = _m("pierre_fine", Color(0.62, 0.6, 0.64))
	d["brute"] = _m("pierre_brute", Color(0.95, 0.9, 0.9))
	d["seche"] = _m("pierre_seche", Color(0.95, 0.8, 0.7))
	d["fer"] = _m("fer", Color(0.85, 0.87, 0.95))
	d["fer_noir"] = _m("fer", Color(0.45, 0.45, 0.5))
	d["etain"] = _m("fer", Color(1.35, 1.38, 1.45))
	d["cuir"] = _m("cuir", Color(1.2, 1.08, 0.95))
	d["foin"] = _m("foin", Color(0.9, 0.9, 0.82))
	d["herbe"] = _m("foin", Color(0.55, 0.78, 0.45))
	d["peau"] = _m("peau", Color(0.95, 0.85, 0.78))
	d["peau_claire"] = _m("peau", Color(1.25, 1.15, 1.05))
	d["peau_sombre"] = _m("peau", Color(0.55, 0.48, 0.46))
	d["terre"] = _m("terre", Color.WHITE)
	d["charbon"] = _m("charbon", Color.WHITE)
	d["os"] = _m("os", Color(1.15, 1.1, 1.0), 64.0, 0.0)
	d["parchemin"] = _m("parchemin", Color(1.1, 1.05, 0.95), 64.0, 0.0)
	d["cire"] = _m("os", Color(1.3, 1.15, 0.8), 64.0, 0.0)
	d["noir"] = _m("fer", Color(0.12, 0.12, 0.14), 32.0, 0.0)
	var eau := _m("fer", Color(0.1, 0.14, 0.22), 32.0, 0.0)
	eau.set_shader_parameter("emission", Color(0.03, 0.06, 0.12))
	d["eau"] = eau
	d["tenture_r"] = _m("tenture_rouge", Color.WHITE, 32.0, 0.6, true)
	d["tenture_b"] = _m("tenture_bleue", Color.WHITE, 32.0, 0.6, true)
	d["tenture_v"] = _m("tenture_verte", Color.WHITE, 32.0, 0.6, true)
	d["bouclier_r"] = _m("planches_v", Color(1.1, 0.34, 0.3))
	d["bouclier_b"] = _m("planches_v", Color(0.36, 0.5, 0.95))
	d["bouclier_n"] = _m("planches_v", Color(0.4, 0.38, 0.4))
	d["bouclier_j"] = _m("planches_v", Color(1.35, 1.1, 0.5))
	var br := _m("braises")
	br.set_shader_parameter("emission", Color(1.7, 0.65, 0.18))
	br.set_shader_parameter("emission_texture", true)
	d["braises"] = br
	var rune := _m("fer", Color(0.5, 0.55, 0.62), 32.0, 0.0)
	rune.set_shader_parameter("emission", Color(0.25, 0.85, 1.0))
	d["rune"] = rune
	var cendre := _m("charbon", Color(1.5, 1.4, 1.4))
	d["cendre"] = cendre
	# vitrage translucide (plan) + halo additif des flammes
	var vit := ShaderMaterial.new()
	vit.shader = preload("res://shaders/ps1_vitre.gdshader")
	vit.set_shader_parameter("tex_vitrage", TexturesBati.tex("vitrage"))
	d["vitre"] = vit
	Palette.materiaux.append(vit)
	return d

static func _textures_feu() -> void:
	if _atlas == null:
		_atlas = ObjetsTextures.tex("flamme")
		_halo = ImageTexture.create_from_image(CrypteTextures.halo_image())
		_rai = ImageTexture.create_from_image(CrypteTextures.rai_image())

# ------------------------------------------------------------------------------------------------ construction

func _init(village: Node3D, interieur: Interieur, materiaux_: Dictionary, longueur: float, largeur: float, hauteur_murs: float, faite_: float) -> void:
	v = village
	ip = interieur
	M = materiaux_
	L = longueur
	W = largeur
	y0 = 0.4 + hauteur_murs
	faite = faite_
	rng.seed = int(longueur * 131.0 + largeur * 17.0) + 5

func _p() -> Node3D:
	return ip.racine

## Boîte centrée en `pos`, tournée de `lacet` (autour de Y), `inclin` = (tangage, _, roulis) ; collision facultative.
func bx(pos: Vector3, taille: Vector3, mat: String, lacet := 0.0, solide := false, inclin := Vector3.ZERO) -> void:
	var b := Basis.from_euler(Vector3(inclin.x, lacet, inclin.z))
	v._boite(_p(), taille, Transform3D(b, pos), M[mat], solide)

## Cylindre (8 pans par défaut) centré en `pos` ; `r_bas` < 0 → même rayon.
func cyl(pos: Vector3, r: float, h: float, mat: String, cotes := 8, solide := false, r_bas := -1.0, b := Basis()) -> void:
	v._cylindre(_p(), r, r if r_bas < 0.0 else r_bas, h, Transform3D(b, pos), M[mat], cotes, solide)

## Cylindre couché le long de X (lacet 0) ou de Z (lacet PI/2).
func cyl_h(pos: Vector3, r: float, longueur: float, mat: String, lacet := 0.0, cotes := 8, solide := false) -> void:
	var b := Basis(Vector3.UP, lacet) * Basis(Vector3.BACK, PI * 0.5)
	v._cylindre(_p(), r, r, longueur, Transform3D(b, pos), M[mat], cotes, solide)

func pile(pos: Vector3, taille: Vector3, graine: int, mat := "brute", solide := false, neige := 0.0, lacet := 0.0) -> void:
	v._pile(_p(), pos, taille, graine, M[mat], solide, neige, lacet)

func bloc(taille: Vector3, graine: int, pos: Vector3, mat := "brute", lacet := 0.0, chanfrein := 0.2, jitter := 0.06, solide := false) -> void:
	v._bloc(_p(), taille, graine, pos, M[mat], lacet, 0.0, chanfrein, jitter, solide)

## Collision sans maillage.
func solide(pos: Vector3, taille: Vector3, lacet := 0.0) -> void:
	v._collision(_p(), BoxShape3D.new(), Transform3D(Basis(Vector3.UP, lacet), pos), taille)

func solide_cyl(pos: Vector3, rayon: float, h: float) -> void:
	var f := CylinderShape3D.new()
	f.radius = rayon
	f.height = h
	v._collision(_p(), f, Transform3D(Basis(), pos), Vector3.ZERO)

## Rondin à 8 pans (fût + bouts). `lacet` 0 = le long de X, PI/2 = le long de Z ; `pente` = inclinaison autour de Z (rad).
func rondin(pos: Vector3, lacet: float, longueur: float, rayon: float, graine: int, mat := "rondin", pente := 0.0, sag := 0.015) -> void:
	var r := BatiGeo.rondin(longueur, rayon, graine, sag, graine % 4, float(graine % 9), 1.0)
	var xf := Transform3D(Basis(Vector3.UP, lacet) * Basis(Vector3.BACK, pente), pos)
	v._ajouter(_p(), (r[0] as BatiGeo.Maillage).arrays(), xf, M[mat])
	v._ajouter(_p(), (r[1] as BatiGeo.Maillage).arrays(), xf, M["bout"])

## Poteau octogonal sur socle, à chapiteau (éléments porteurs : jamais de cube nu).
func poteau(pos: Vector3, rayon: float, h_haut: float, mat := "rondin_sombre", collision := true, y_bas := F) -> void:
	var h := h_haut - y_bas
	cyl(Vector3(pos.x, y_bas + h * 0.5, pos.z), rayon, h, mat, 8, false)
	bx(Vector3(pos.x, y_bas + 0.07, pos.z), Vector3(rayon * 2.9, 0.14, rayon * 2.9), "brute", 0.39)
	bx(Vector3(pos.x, h_haut - 0.09, pos.z), Vector3(rayon * 2.7, 0.18, rayon * 2.7), "bois_sombre", 0.39)
	if collision:
		solide_cyl(Vector3(pos.x, y_bas + h * 0.5, pos.z), rayon * 1.15, h)

## Quad (a, b, c, d dans l'ordre du contour), normale `n`, couleurs de sommet facultatives.
func quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uvs: Array = [], cols: Array = []) -> void:
	var pts := [a, b, c, d]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uv := PackedVector2Array()
	var co := PackedColorArray()
	var geo := (b - a).cross(c - a)
	var ordre := [0, 2, 1, 0, 3, 2] if geo.dot(n) > 0.0 else [0, 1, 2, 0, 2, 3]
	for k in ordre:
		verts.append(pts[k])
		norms.append(n)
		uv.append(uvs[k] if not uvs.is_empty() else Vector2.ZERO)
		co.append(cols[k] if not cols.is_empty() else Color.WHITE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = co
	v._ajouter(_p(), arrays, Transform3D(), M[mat], false)

## Polygone convexe dans un plan (points dans l'ordre du contour), normale `n`.
func poly(mat: String, pts: Array, n: Vector3, parent: Node3D = null, materiel: Material = null) -> void:
	for k in range(1, pts.size() - 1):
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var tri := [pts[0], pts[k], pts[k + 1]]
		var geo: Vector3 = ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3))
		var ordre := [0, 2, 1] if geo.dot(n) > 0.0 else [0, 1, 2]
		for i in ordre:
			verts.append(tri[i])
			norms.append(n)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		v._ajouter(parent if parent != null else _p(), arrays, Transform3D(), materiel if materiel != null else M[mat], false)

## Pièce de tissu plane (tenture, peau tendue) face à la direction `lacet` ; UV en mètres (motif entier 1,5 × 2 m).
func tenture(centre: Vector3, lacet: float, w: float, h: float, mat := "tenture_r") -> void:
	var n := Basis(Vector3.UP, lacet) * Vector3.BACK
	var droite := Basis(Vector3.UP, lacet) * Vector3.RIGHT
	var a := centre - droite * w * 0.5 - Vector3.UP * h * 0.5
	var b := centre + droite * w * 0.5 - Vector3.UP * h * 0.5
	var c := centre + droite * w * 0.5 + Vector3.UP * h * 0.5
	var d := centre - droite * w * 0.5 + Vector3.UP * h * 0.5
	quad(mat, a, b, c, d, n, [Vector2(0, 2.0), Vector2(1.5, 2.0), Vector2(1.5, 0), Vector2(0, 0)])
	# tringle de bois en haut, petits poids de fer en bas
	cyl_h(centre + Vector3(0, h * 0.5 + 0.02, 0) + n * 0.02, 0.025, w + 0.24, "bois_sombre", lacet, 6)
	for sx in [-1.0, 1.0]:
		bx(centre + droite * sx * (w * 0.5 + 0.12) + Vector3(0, h * 0.5 + 0.02, 0) + n * 0.02, Vector3(0.07, 0.07, 0.07), "fer", lacet)

## Plan de peau tendue (cadre de bois + peau) face à `lacet`.
func peau_murale(centre: Vector3, lacet: float, w: float, h: float, mat := "peau") -> void:
	var n := Basis(Vector3.UP, lacet) * Vector3.BACK
	var droite := Basis(Vector3.UP, lacet) * Vector3.RIGHT
	bx(centre + n * 0.02, Vector3(w, h, 0.03), mat, lacet)
	bx(centre + Vector3(0, h * 0.5 + 0.02, 0) + n * 0.04, Vector3(w + 0.1, 0.04, 0.04), "bois_sombre", lacet)
	bx(centre - Vector3(0, h * 0.5 + 0.02, 0) + n * 0.04, Vector3(w + 0.1, 0.04, 0.04), "bois_sombre", lacet)
	for sx in [-1.0, 1.0]:
		bx(centre + droite * sx * (w * 0.5 + 0.02) + n * 0.04, Vector3(0.04, h + 0.08, 0.04), "bois_sombre", lacet)

# ------------------------------------------------------------------------------------------------ feu et lumière

func flamme(pos: Vector3, echelle := 1.0) -> void:
	_flammes.append([pos, echelle, rng.randf() * 4.0])

## Carte additive posée (halo au sol ou sur un mur, rai de lumière) ; `normale` horizontale ou verticale.
func halo(centre: Vector3, normale: Vector3, w: float, h: float, couleur := Color(1, 1, 1, 1), nom := "halo") -> void:
	_halos.append([centre, normale.normalized(), w, h, couleur, nom])

func lumiere(pos: Vector3, energie: float, portee: float, couleur := FEU, att := 1.7, vacille := true) -> void:
	ip.lumiere(pos, energie, portee, couleur, att, vacille)

## Foyer ouvert : flamme(s) + halo au sol + une lumière.
func feu(pos: Vector3, echelle := 1.6, energie := 2.4, portee := 7.5) -> void:
	flamme(pos, echelle)
	halo(pos + Vector3(0, 0.01 - pos.y + F + 0.03, 0), Vector3.UP, 3.0 * echelle, 3.0 * echelle)
	lumiere(pos + Vector3(0, 0.7, 0), energie, portee)

## Applique murale : console de fer, manche goudronné, flamme, halo net sur le mur, lumière courte facultative.
func applique(pos: Vector3, vers_lacet: float, energie := 1.6, portee := 5.0, avec_lumiere := true) -> void:
	var b := Basis(Vector3.UP, vers_lacet)
	var d := b * Vector3.BACK
	bx(pos + d * 0.03, Vector3(0.16, 0.34, 0.06), "fer", vers_lacet)
	bx(pos + d * 0.18 - Vector3(0, 0.07, 0), Vector3(0.05, 0.05, 0.34), "fer", vers_lacet)
	cyl(pos + d * 0.34 - Vector3(0, 0.07, 0), 0.075, 0.1, "fer", 6, false, 0.05)
	cyl(pos + d * 0.34 + Vector3(0, 0.06, 0), 0.032, 0.34, "bois_sombre", 6)
	cyl(pos + d * 0.34 + Vector3(0, 0.25, 0), 0.062, 0.09, "bois_suie", 6, false, 0.045)
	flamme(pos + d * 0.34 + Vector3(0, 0.3, 0), 1.5)
	halo(pos + d * 0.12 + Vector3(0, 0.3, 0), d, 1.3, 1.3)
	if avec_lumiere:
		lumiere(pos + d * 0.55 + Vector3(0, 0.45, 0), energie, portee, FEU, 1.8)

func bougie(pos: Vector3, h := 0.14, avec_lumiere := false) -> void:
	cyl(pos + Vector3(0, h * 0.5, 0), 0.026, h, "cire", 6)
	cyl(pos + Vector3(0, 0.008, 0), 0.06, 0.016, "etain", 6)
	flamme(pos + Vector3(0, h, 0), 0.4)
	if avec_lumiere:
		lumiere(pos + Vector3(0, h + 0.35, 0), 0.9, 3.6, FEU, 1.8)

# ------------------------------------------------------------------------------------------------ coque

## Plancher de planches (dessus à F) sur toute l'emprise ; la collision est posée par le village.
func plancher(zone := Rect2(), mat := "bois") -> void:
	var r := zone if zone.size != Vector2.ZERO else Rect2(-L * 0.5 + 0.14, -W * 0.5 + 0.14, L - 0.28, W - 0.28)
	var c := r.get_center()
	bx(Vector3(c.x, F - 0.02, c.y), Vector3(r.size.x, 0.04, r.size.y), mat)

## Dalles de pierre posées sur le plancher (zone de foyer).
func dallage(zone: Rect2, mat := "pierre_sombre", haut := F + 0.025, y := F - 0.02) -> void:
	var c := zone.get_center()
	bx(Vector3(c.x, y + (haut - y) * 0.5, c.y), Vector3(zone.size.x, haut - y, zone.size.y), mat)

## Géométrie d'un pan de toit (repère du village : faîte au centre) : point du faîte, direction, normale, longueur.
func _pan_geo(cote: float) -> Dictionary:
	var rp := Vector3(0, y0 + faite, 0)
	var d := Vector3(0, (y0 - 0.5) - rp.y, cote * (W * 0.5 + 0.78))
	var sl := d.length()
	var t := d / sl
	var nrm := Vector3(0, t.z, -t.y)
	if nrm.y < 0.0:
		nrm = -nrm
	return {"Rp": rp, "t": t, "nrm": nrm, "Sl": sl, "cote": cote}

## Point du lambris (plan du toit descendu de `decal`) à l'abscisse x et la distance s du faîte.
func _lambris(g: Dictionary, x: float, s: float, decal := DECAL_PLAFOND) -> Vector3:
	var p: Vector3 = g["Rp"] + (g["t"] as Vector3) * s - (g["nrm"] as Vector3) * decal
	p.x = x
	return p

## Plafond sous charpente : lambris de planches sous chaque pan, nervures, fermes (arbalétriers + entrait + poinçon),
## faîtage, pignons lambrissés. `fermes` = abscisses des entraits ; `trou` = (x0, x1, demi-largeur z) du trou à fumée.
func plafond(fermes: Array, trou := Vector3.ZERO) -> void:
	var xa := -L * 0.5 + 0.17
	var xb := L * 0.5 - 0.17
	var sorties := []
	for cote in [-1.0, 1.0]:
		var g := _pan_geo(cote)
		var t: Vector3 = g["t"]
		var nrm: Vector3 = g["nrm"]
		var s0: float = nrm.z * DECAL_PLAFOND / t.z                   # le lambris naît à z = 0
		var s1: float = (cote * (W * 0.5 - 0.02) + nrm.z * DECAL_PLAFOND) / t.z
		var n_in := -nrm
		var bandes: Array = [[xa, xb, s0]]
		if trou != Vector3.ZERO:
			# sous le trou à fumée, le lambris ne commence qu'au-delà de la gaine (|z| > demi-largeur)
			var sh: float = (cote * trou.z + nrm.z * DECAL_PLAFOND) / t.z
			bandes = [[xa, trou.x, s0], [trou.x, trou.y, sh], [trou.y, xb, s0]]
		for bd in bandes:
			var a := _lambris(g, bd[0], bd[2])
			var b := _lambris(g, bd[1], bd[2])
			var c := _lambris(g, bd[1], s1)
			var d := _lambris(g, bd[0], s1)
			quad("bois_sombre", a, b, c, d, n_in)
		# nervures sous le lambris (une tous les 0,9 m)
		var xr := xa + 0.3
		while xr < xb:
			if trou == Vector3.ZERO or xr < trou.x - 0.1 or xr > trou.y + 0.1:
				var sa: float = s0 + 0.05
				var sb := s1
				var centre: Vector3 = (_lambris(g, xr, sa, DECAL_PLAFOND + 0.04) + _lambris(g, xr, sb, DECAL_PLAFOND + 0.04)) * 0.5
				var lg := (sb - sa)
				var base := Basis(Vector3.RIGHT * (1.0 if cote > 0.0 else -1.0), nrm, t)
				v._boite(_p(), Vector3(0.07, 0.06, lg), Transform3D(base, centre), M["bois_sombre"])
			xr += 0.9
		# arbalétriers des fermes (sous les nervures)
		for xf in fermes:
			var sa2: float = s0 + 0.1
			var centre2: Vector3 = (_lambris(g, xf, sa2, DECAL_PLAFOND + 0.12) + _lambris(g, xf, s1, DECAL_PLAFOND + 0.12)) * 0.5
			var base2 := Basis(Vector3.RIGHT * (1.0 if cote > 0.0 else -1.0), nrm, t)
			v._boite(_p(), Vector3(0.17, 0.17, s1 - sa2), Transform3D(base2, centre2), M["bois_sombre"])
		sorties.append([g, s0])
	# poinçon + faîtage : lissé au sommet du lambris
	var gp: Dictionary = sorties[0][0]
	var yr_l: float = _lambris(gp, 0.0, sorties[0][1]).y
	rondin(Vector3(0, yr_l - 0.1, 0), 0.0, L - 0.4, 0.13, 301, "rondin_sombre")
	for xf in fermes:
		# entrait : rondin en travers, posé sur les murs ; poinçon jusqu'au faîtage
		rondin(Vector3(xf, y0 - 0.06, 0), PI * 0.5, W - 0.1, 0.12, 310 + int(absf(xf) * 7.0), "rondin_sombre")
		cyl(Vector3(xf, (y0 - 0.06 + yr_l - 0.1) * 0.5, 0), 0.07, yr_l - 0.1 - (y0 - 0.06), "rondin_sombre", 6)
		# jambes de force (liens obliques entre le poinçon et l'entrait)
		for sz in [-1.0, 1.0]:
			bx(Vector3(xf, y0 + 0.36, sz * 0.62), Vector3(0.1, 0.1, 1.15), "bois_sombre", 0.0, false, Vector3(sz * 0.9, 0, 0))
	# pignons lambrissés (intérieurs) : triangle sous le lambris
	for cx in [-1.0, 1.0]:
		var x: float = cx * (L * 0.5 - 0.162)
		var m_pente := absf((gp["t"] as Vector3).y / (gp["t"] as Vector3).z)
		var zb := (yr_l - y0) / m_pente
		poly("bois_sombre", [Vector3(x, y0, -zb), Vector3(x, y0, zb), Vector3(x, yr_l, 0)], Vector3(-cx, 0, 0))
		# poteau de pignon
		bx(Vector3(x, (y0 + yr_l) * 0.5, 0), Vector3(0.1, yr_l - y0, 0.2), "bois_sombre")
	# sablière haute : poutre de bois qui court sous les rives, au-dessus de la porte et des fenêtres
	for cz in [-1.0, 1.0]:
		bx(Vector3(0, y0 - 0.02, cz * (W * 0.5 - 0.2)), Vector3(L - 0.3, 0.1, 0.12), "bois_sombre")

## Cadre intérieur d'une fenêtre : jambages, linteau, appui profond (l'embrasure d'un mur de 30 cm).
func fenetre_cadre(x: float, y: float, z: float, face: float, demi_l := 0.35, demi_h := 0.275) -> void:
	var zi := z - face * 0.12      # côté pièce
	for sx in [-1.0, 1.0]:
		bx(Vector3(x + sx * (demi_l + 0.03), y, zi), Vector3(0.08, demi_h * 2.0 + 0.16, 0.34), "bois_sombre")
	bx(Vector3(x, y + demi_h + 0.04, zi), Vector3(demi_l * 2.0 + 0.14, 0.09, 0.34), "bois_sombre")
	bx(Vector3(x, y - demi_h - 0.03, zi), Vector3(demi_l * 2.0 + 0.2, 0.07, 0.4), "bois")

## Murs : bandeau de poteaux d'angle et chaînages.
func poteaux_angle() -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * (L * 0.5 - 0.24), 0, sz * (W * 0.5 - 0.24))
			cyl(Vector3(p.x, (F + y0) * 0.5, p.z), 0.11, y0 - F, "rondin_sombre", 8)

# ------------------------------------------------------------------------------------------------ mobilier courant

## Recale `pos` au niveau du sol de la pièce si son y est ~0 (convention : y < 0,2 = « sur le sol », sinon absolu).
func _sol(pos: Vector3) -> Vector3:
	return Vector3(pos.x, ip.sol_y, pos.z) if pos.y < 0.2 else pos

## Table sur tréteaux (long le long de X pour lacet 0).
func table(pos: Vector3, long: float, larg: float, lacet := 0.0, haut := 0.78, solide_ := true) -> void:
	pos = _sol(pos)
	var b := Basis(Vector3.UP, lacet)
	bx(pos + Vector3(0, haut - 0.05, 0), Vector3(long, 0.1, larg), "bois", lacet, solide_)
	var n := maxi(2, int(long / 1.4) + 1)
	for i in n:
		var dx := -long * 0.5 + 0.25 + (long - 0.5) * float(i) / (n - 1)
		for sz in [-1.0, 1.0]:
			bx(pos + b * Vector3(dx, (haut - 0.1) * 0.5, sz * (larg * 0.5 - 0.1)), Vector3(0.1, haut - 0.1, 0.09), "bois_v", lacet)
		bx(pos + b * Vector3(dx, 0.2, 0), Vector3(0.07, 0.07, larg - 0.18), "bois_sombre", lacet)
	bx(pos + Vector3(0, 0.2, 0), Vector3(long - 0.5, 0.06, 0.08), "bois_sombre", lacet)

func banc(pos: Vector3, long: float, lacet := 0.0, haut := 0.46, prof := 0.34, solide_ := true) -> void:
	pos = _sol(pos)
	var b := Basis(Vector3.UP, lacet)
	bx(pos + Vector3(0, haut - 0.04, 0), Vector3(long, 0.08, prof), "bois", lacet, solide_)
	for sx in [-1.0, 1.0]:
		bx(pos + b * Vector3(sx * (long * 0.5 - 0.25), (haut - 0.08) * 0.5, 0), Vector3(0.09, haut - 0.08, prof - 0.06), "bois_v", lacet)

func tabouret(pos: Vector3, haut := 0.45) -> void:
	pos = _sol(pos)
	cyl(pos + Vector3(0, haut - 0.03, 0), 0.19, 0.06, "bois", 8)
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		bx(pos + Vector3(sin(a) * 0.1, (haut - 0.06) * 0.5, cos(a) * 0.1), Vector3(0.05, haut - 0.06, 0.05), "bois_v", a)
	solide_cyl(pos + Vector3(0, haut * 0.5, 0), 0.2, haut)

## Coffre ferré : caisse, couvercle bombé, sangles, serrure.
func coffre(pos: Vector3, lacet := 0.0, taille := Vector3(0.9, 0.46, 0.55), ouvert := false) -> void:
	var b := Basis(Vector3.UP, lacet)
	var w := taille.x
	var h := taille.y
	var d := taille.z
	bx(pos + Vector3(0, h * 0.5, 0), Vector3(w, h, d), "bois_v", lacet, true)
	bx(pos + Vector3(0, h + 0.06, 0), Vector3(w + 0.02, 0.12, d - 0.04), "bois", lacet)
	bx(pos + Vector3(0, h + 0.14, 0), Vector3(w - 0.04, 0.06, d - 0.16), "bois", lacet)
	for sx in [-1.0, 1.0]:
		bx(pos + b * Vector3(sx * w * 0.34, h * 0.5 + 0.07, 0), Vector3(0.09, h + 0.18, d + 0.03), "fer", lacet)
	bx(pos + b * Vector3(0, h * 0.8, d * 0.5 + 0.015), Vector3(0.1, 0.13, 0.03), "fer_noir", lacet)
	bx(pos + Vector3(0, 0.03, 0), Vector3(w + 0.04, 0.06, d + 0.04), "fer_noir", lacet)

func tonneau(pos: Vector3, h := 0.9, r := 0.34, solide_ := true) -> void:
	pos = _sol(pos)
	cyl(pos + Vector3(0, h * 0.5, 0), r, h, "bois_v", 8, solide_, r * 0.84)
	cyl(pos + Vector3(0, h * 0.5, 0), r * 1.02, h * 0.55, "bois_v", 8, false, r * 1.02)
	for y in [0.14, 0.34, 0.66, 0.86]:
		var f := 1.0 - 0.16 * pow(absf(y - 0.5) * 2.0, 1.4) * (r / r)
		cyl(pos + Vector3(0, h * y, 0), r * (0.84 + 0.18 * (1.0 - pow(absf(y - 0.5) * 2.0, 2.0))) * 1.02, 0.045, "fer", 8)
	cyl(pos + Vector3(0, h - 0.005, 0), r * 0.82, 0.02, "bois", 8)

func etagere(pos: Vector3, lacet: float, larg: float, haut: float, niveaux := 3, prof := 0.32) -> void:
	pos = _sol(pos)
	var b := Basis(Vector3.UP, lacet)
	for sx in [-1.0, 1.0]:
		bx(pos + b * Vector3(sx * (larg * 0.5 - 0.04), haut * 0.5, 0), Vector3(0.07, haut, prof), "bois_v", lacet)
	for i in niveaux:
		var y := haut * (float(i) + 0.8) / (niveaux + 0.5) - 0.0
		bx(pos + Vector3(0, y, 0), Vector3(larg, 0.045, prof), "bois", lacet)
	bx(pos + b * Vector3(0, haut * 0.5, -prof * 0.5 + 0.015), Vector3(larg - 0.08, haut - 0.1, 0.02), "bois_sombre", lacet)

## Lit : cadre, paillasse de foin, couverture de peau, oreiller. `tete` : sens de la tête (lacet).
func lit(pos: Vector3, lacet: float, long := 1.95, larg := 0.95, peau_mat := "peau", etat := 0) -> void:
	var b := Basis(Vector3.UP, lacet)
	bx(pos + Vector3(0, 0.3, 0), Vector3(long, 0.12, larg), "bois", lacet, true)
	for sx in [-1.0, 1.0]:
		bx(pos + b * Vector3(sx * (long * 0.5 - 0.06), 0.46, 0), Vector3(0.1, 0.6, larg + 0.08), "bois_v", lacet)
		for sz in [-1.0, 1.0]:
			bx(pos + b * Vector3(sx * (long * 0.5 - 0.06), 0.15, sz * (larg * 0.5 - 0.02)), Vector3(0.1, 0.3, 0.1), "bois_v", lacet)
	for sz in [-1.0, 1.0]:
		bx(pos + b * Vector3(0, 0.42, sz * (larg * 0.5 + 0.02)), Vector3(long, 0.18, 0.06), "bois", lacet)
	bx(pos + Vector3(0, 0.45, 0), Vector3(long - 0.2, 0.14, larg - 0.1), "foin", lacet)
	bx(pos + b * Vector3(0.1, 0.55, 0), Vector3(long - 0.55, 0.07, larg - 0.08), peau_mat, lacet)
	bx(pos + b * Vector3(-long * 0.5 + 0.35, 0.58, 0), Vector3(0.42, 0.12, larg - 0.3), "cuir", lacet, false, Vector3(0, 0, 0.08))
	if etat == 1:   # défait
		bx(pos + b * Vector3(0.25, 0.6, 0.1), Vector3(0.7, 0.1, 0.5), peau_mat, lacet + 0.3, false, Vector3(0.12, 0, 0.05))

func bouclier(pos: Vector3, lacet: float, rayon := 0.36, mat := "bouclier_r") -> void:
	var b := Basis(Vector3.UP, lacet) * Basis(Vector3.RIGHT, PI * 0.5)
	var n := Basis(Vector3.UP, lacet) * Vector3.BACK
	v._cylindre(_p(), rayon, rayon, 0.06, Transform3D(b, pos + n * 0.03), M[mat], 8)
	v._cylindre(_p(), rayon + 0.02, rayon + 0.02, 0.04, Transform3D(b, pos + n * 0.045), M["fer"], 8)
	v._cylindre(_p(), rayon * 0.8, rayon * 0.8, 0.05, Transform3D(b, pos + n * 0.065), M[mat], 8)
	v._cylindre(_p(), 0.085, 0.1, 0.1, Transform3D(b, pos + n * 0.1), M["fer"], 8)
	# croisillon de fer
	bx(pos + n * 0.08, Vector3(rayon * 1.6, 0.045, 0.02), "fer", lacet)
	bx(pos + n * 0.08, Vector3(0.045, rayon * 1.6, 0.02), "fer", lacet)

func crane(pos: Vector3, lacet := 0.0, e := 1.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	bx(pos + Vector3(0, 0.06 * e, 0), Vector3(0.13, 0.11, 0.15) * e, "os", lacet)
	bx(pos + b * Vector3(0, 0.0, 0.07 * e), Vector3(0.09, 0.07, 0.07) * e, "os", lacet)
	bx(pos + b * Vector3(0, -0.035 * e, 0.05 * e), Vector3(0.08, 0.035, 0.09) * e, "os", lacet)
	for sx in [-1.0, 1.0]:
		bx(pos + b * Vector3(sx * 0.035 * e, 0.065 * e, 0.075 * e), Vector3(0.035, 0.035, 0.02) * e, "noir", lacet)

## Ramure de cerf accrochée au mur (`lacet` = direction vers la pièce).
func ramure(pos: Vector3, lacet: float, e := 1.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	var n := b * Vector3.BACK
	bx(pos + n * 0.06, Vector3(0.34, 0.3, 0.05) * e, "bois_sombre", lacet)       # écusson
	bx(pos + n * 0.14 + Vector3(0, 0.02, 0), Vector3(0.16, 0.2, 0.22) * e, "peau", lacet)      # crâne
	for sx in [-1.0, 1.0]:
		var base := pos + n * 0.14 + b * Vector3(sx * 0.07 * e, 0.12 * e, 0)
		bx(base + b * Vector3(sx * 0.12 * e, 0.16 * e, 0.0), Vector3(0.035, 0.38, 0.035) * e, "os", lacet, false, Vector3(0, 0, -sx * 0.5))
		for k in 3:
			bx(base + b * Vector3(sx * (0.2 + k * 0.045) * e, (0.32 + k * 0.07) * e, 0.05 * e), Vector3(0.028, 0.22, 0.028) * e, "os", lacet, false, Vector3(0.5, 0, -sx * 0.15))

func hache(pos: Vector3, lacet: float, inclin := 0.0, e := 1.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	bx(pos, Vector3(0.045, 0.82, 0.045) * e, "bois", lacet, false, Vector3(0, 0, inclin))
	var tete := pos + b * Basis(Vector3.BACK, inclin) * Vector3(0.0, 0.3 * e, 0.0)
	bx(tete + b * Vector3(0.0, 0.0, 0.06 * e), Vector3(0.06, 0.2, 0.16) * e, "fer", lacet, false, Vector3(0, 0, inclin))

func epee(pos: Vector3, lacet: float, inclin := 0.0, e := 1.0) -> void:
	var b := Basis(Vector3.UP, lacet) * Basis(Vector3.BACK, inclin)
	bx(pos, Vector3(0.05, 0.85, 0.014) * e, "etain", lacet, false, Vector3(0, 0, inclin))
	bx(pos + b * Vector3(0, -0.42 * e, 0), Vector3(0.22, 0.035, 0.035) * e, "fer_noir", lacet, false, Vector3(0, 0, inclin))
	bx(pos + b * Vector3(0, -0.52 * e, 0), Vector3(0.04, 0.14, 0.04) * e, "cuir", lacet, false, Vector3(0, 0, inclin))

func lance(pos: Vector3, lacet: float, inclin := 0.0, long := 1.9) -> void:
	var b := Basis(Vector3.UP, lacet) * Basis(Vector3.BACK, inclin)
	bx(pos, Vector3(0.035, long, 0.035), "bois", lacet, false, Vector3(0, 0, inclin))
	bx(pos + b * Vector3(0, long * 0.5 + 0.12, 0), Vector3(0.07, 0.26, 0.015), "etain", lacet, false, Vector3(0, 0, inclin))

func arc(pos: Vector3, lacet: float, e := 1.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	bx(pos, Vector3(0.035, 0.5, 0.045) * e, "bois_clair", lacet)
	for sy in [-1.0, 1.0]:
		bx(pos + b * Vector3(0.0, sy * 0.4 * e, -0.03 * e * 0.0), Vector3(0.03, 0.42, 0.04) * e, "bois_clair", lacet, false, Vector3(0, 0, sy * 0.0))
		bx(pos + b * Vector3(-0.05 * e, sy * 0.68 * e, 0), Vector3(0.03, 0.26, 0.035) * e, "bois_clair", lacet, false, Vector3(0, 0, -sy * 0.28))
	bx(pos + b * Vector3(-0.17 * e, 0, 0), Vector3(0.008, 1.4, 0.008) * e, "cuir", lacet)

func carquois(pos: Vector3, lacet: float) -> void:
	var b := Basis(Vector3.UP, lacet)
	cyl(pos + Vector3(0, 0.0, 0), 0.07, 0.55, "cuir", 6, false, 0.09, Basis(Vector3.BACK, 0.1))
	for k in 4:
		bx(pos + b * Vector3(-0.02 + k * 0.016, 0.34, 0.01 * k), Vector3(0.012, 0.18, 0.012), "bois_clair", lacet, false, Vector3(0.0, 0, 0.1))

## Viande ou poisson séchés qui pendent d'une corde (à accrocher sous un entrait).
func viande_seche(pos: Vector3, k := 3, lacet := 0.0) -> void:
	var b := Basis(Vector3.UP, lacet)
	for i in k:
		var off := b * Vector3(float(i - (k - 1) * 0.5) * 0.2, 0, 0)
		var h := 0.26 + rng.randf() * 0.16
		cyl(pos + off + Vector3(0, -0.1, 0), 0.008, 0.2, "cuir", 4)
		if i % 2 == 0:
			# jambon : fuseau renflé en haut, os qui dépasse en bas
			cyl(pos + off + Vector3(0, -0.2 - h * 0.5, 0), 0.07, h, "peau_sombre", 6, false, 0.03)
			bx(pos + off + Vector3(0, -0.22 - h, 0.0), Vector3(0.025, 0.07, 0.025), "os", lacet)
		else:
			# saucisson : boudin ficelé
			cyl(pos + off + Vector3(0, -0.2 - h * 0.45, 0), 0.035, h * 0.9, "cuir", 6, false, 0.03)
			cyl(pos + off + Vector3(0, -0.22, 0), 0.04, 0.025, "foin", 6)

func herbes(pos: Vector3, lacet := 0.0, e := 1.0) -> void:
	bx(pos + Vector3(0, -0.01, 0), Vector3(0.2, 0.02, 0.02), "cuir", lacet)
	for i in 5:
		var dx := (i - 2) * 0.04
		var h := (0.34 + 0.06 * (i % 2)) * e
		cyl(pos + Vector3(dx, -h * 0.5, 0), 0.006, h, "bois_sombre", 4)
		var teinte := "herbe" if i % 2 == 0 else "foin"
		bx(pos + Vector3(dx * 1.6, -h - 0.04, 0.0), Vector3(0.05, 0.12 * e, 0.045), teinte, lacet + i * 0.9, false, Vector3(0, 0, (i - 2) * 0.05))
		bx(pos + Vector3(dx * 1.9, -h - 0.015, 0.0), Vector3(0.07, 0.05 * e, 0.03), teinte, lacet + i * 0.4)

## Petite balance de marchand (herboriste) : fût, fléau, deux plateaux de cuivre.
func balance(pos: Vector3) -> void:
	cyl(pos + Vector3(0, 0.12, 0), 0.012, 0.24, "fer", 4)
	bx(pos + Vector3(0, 0.24, 0), Vector3(0.3, 0.012, 0.012), "fer")
	for sx in [-1.0, 1.0]:
		cyl(pos + Vector3(sx * 0.14, 0.15, 0), 0.004, 0.18, "fer", 4)
		cyl(pos + Vector3(sx * 0.14, 0.055, 0), 0.05, 0.01, "etain", 8)
	cyl(pos + Vector3(0, 0.005, 0), 0.04, 0.01, "fer", 6)

func assiette(pos: Vector3, mat := "etain") -> void:
	cyl(pos + Vector3(0, 0.012, 0), 0.11, 0.024, mat, 8, false, 0.08)

func chope(pos: Vector3, mat := "bois") -> void:
	cyl(pos + Vector3(0, 0.07, 0), 0.05, 0.14, mat, 8, false, 0.042)
	cyl(pos + Vector3(0, 0.02, 0), 0.045, 0.012, "fer", 8)

func chaudron(pos: Vector3, r := 0.3) -> void:
	cyl(pos + Vector3(0, r * 0.6, 0), r, r * 1.1, "fer_noir", 8, false, r * 0.72)
	cyl(pos + Vector3(0, r * 1.15, 0), r * 1.05, 0.045, "fer", 8)
	cyl(pos + Vector3(0, r * 1.12, 0), r * 0.85, 0.03, "noir", 8)
	cyl_h(pos + Vector3(0, r * 1.45, 0), 0.012, r * 2.0, "fer", 0.0, 4)

func bol(pos: Vector3) -> void:
	cyl(pos + Vector3(0, 0.04, 0), 0.09, 0.08, "terre", 8, false, 0.06)

func cruche(pos: Vector3, h := 0.3) -> void:
	cyl(pos + Vector3(0, h * 0.4, 0), h * 0.45, h * 0.8, "bois_sombre", 8, false, h * 0.3)
	cyl(pos + Vector3(0, h * 0.88, 0), h * 0.16, h * 0.28, "bois_sombre", 6, false, h * 0.2)

func livre(pos: Vector3, lacet := 0.0) -> void:
	bx(pos + Vector3(0, 0.03, 0), Vector3(0.2, 0.05, 0.28), "cuir", lacet)
	bx(pos + Vector3(0.0, 0.03, 0.0), Vector3(0.18, 0.04, 0.26), "parchemin", lacet)

func parchemin(pos: Vector3, lacet := 0.0) -> void:
	cyl_h(pos + Vector3(0, 0.03, 0), 0.025, 0.26, "parchemin", lacet, 6)

## Peau posée au sol (y = 0 : sur le plancher).
func peau_sol(pos: Vector3, taille: Vector2, lacet := 0.0, mat := "peau") -> void:
	var y := (F if pos.y < 0.01 else pos.y) + 0.02
	bx(Vector3(pos.x, y, pos.z), Vector3(taille.x, 0.035, taille.y), mat, lacet)
	bx(Vector3(pos.x, y + 0.012, pos.z), Vector3(taille.x * 0.8, 0.03, taille.y * 0.8), mat, lacet + 0.2)

## Litière de paille sur le plancher.
func paille(pos: Vector3, taille: Vector2) -> void:
	bx(Vector3(pos.x, F + 0.03, pos.z), Vector3(taille.x, 0.05, taille.y), "foin", rng.randf() * 3.0)
	for k in 6:
		bx(Vector3(pos.x + rng.randf_range(-0.4, 0.4) * taille.x, F + 0.07, pos.z + rng.randf_range(-0.4, 0.4) * taille.y), Vector3(0.3, 0.03, 0.05), "foin", rng.randf() * 3.0)

func sac(pos: Vector3, graine := 0.0, h := 0.5) -> void:
	var lac := graine * 1.7
	bx(pos + Vector3(0, h * 0.5, 0), Vector3(0.42, h, 0.3), "foin", lac, true, Vector3(0, 0, 0.05))
	bx(pos + Vector3(0, h * 0.5 + h * 0.02, 0), Vector3(0.38, h * 0.9, 0.34), "cuir", lac + 0.2)
	cyl(pos + Vector3(0, h + 0.03, 0), 0.07, 0.08, "foin", 6, false, 0.045)

func os_sol(pos: Vector3, lacet := 0.0) -> void:
	bx(pos + Vector3(0, 0.02, 0), Vector3(0.2, 0.035, 0.045), "os", lacet)
	bx(pos + Vector3(0.09, 0.025, 0.0), Vector3(0.05, 0.045, 0.06), "os", lacet + 0.4)

## Tas de bûches (fendues) empilées contre un mur.
func buches(pos: Vector3, lacet := 0.0) -> void:
	var bs := Basis(Vector3.UP, lacet)
	for rang in 3:
		for k in 4 - rang:
			var d := bs * Vector3((k + rang * 0.5) * 0.24 - 0.4, 0.1 + rang * 0.2, 0)
			rondin(pos + d, lacet + PI * 0.5, 0.6, 0.095, 340 + rang * 7 + k, "rondin_sombre", 0.0, 0.0)
	solide(pos + bs * Vector3(0, 0.3, 0), Vector3(1.05, 0.6, 0.62), lacet)

## Gaine du trou à fumée (halle) : parois sombres entre le lambris et le toit, rebord au-dessus de la neige,
## quatre poteaux et petit toit de lucarne laissant sortir la fumée. Tout est dans le groupe extérieur (toujours visible).
var trou3 := Vector3.ZERO     # (x0, x1, demi-largeur en z du trou)

func gaine_fumee(trou: Vector2) -> void:
	var p: Node3D = ip.get_parent()
	var g := _pan_geo(1.0)
	var t: Vector3 = g["t"]
	var nrm: Vector3 = g["nrm"]
	var rp: Vector3 = g["Rp"]
	var zh: float = (g["Sl"] as float) / 5.0 * t.z
	trou3 = Vector3(trou.x, trou.y, zh)
	var s0: float = nrm.z * DECAL_PLAFOND / t.z
	var yr_l: float = _lambris(g, 0.0, s0).y
	var m := absf(t.y / t.z)
	var y_bas := yr_l - m * zh
	var y_c := rp.y + 0.42
	var xc := (trou.x + trou.y) * 0.5
	var lg := trou.y - trou.x
	# parois longues (le long de X) à z = ±zh
	for cz in [-1.0, 1.0]:
		v._boite(p, Vector3(lg + 0.12, y_c - y_bas, 0.12), Transform3D(Basis(), Vector3(xc, (y_c + y_bas) * 0.5, cz * zh)), v.m_ame)
		v._boite(p, Vector3(lg + 0.34, 0.14, 0.2), Transform3D(Basis(), Vector3(xc, y_c, cz * zh)), v.m_poutres_h)
	# parois courtes (à x0 et x1) : pentagone suivant la pente du lambris
	for xe in [trou.x, trou.y]:
		var pts := [Vector3(xe, y_bas, -zh), Vector3(xe, yr_l, 0), Vector3(xe, y_bas, zh), Vector3(xe, y_c, zh), Vector3(xe, y_c, -zh)]
		poly("", pts, Vector3.RIGHT, p, v.m_poutres_h)
		poly("", pts, Vector3.LEFT, p, v.m_poutres_h)
	for ex in [trou.x, trou.y]:
		v._boite(p, Vector3(0.2, 0.14, zh * 2.0 + 0.2), Transform3D(Basis(), Vector3(ex, y_c, 0)), v.m_poutres_h)
	# lucarne : poteaux et petit toit à deux pans
	for ex in [trou.x + 0.06, trou.y - 0.06]:
		for cz in [-1.0, 1.0]:
			v._cylindre(p, 0.06, 0.06, 0.6, Transform3D(Basis(), Vector3(ex, y_c + 0.3, cz * (zh - 0.02))), v.m_poutres, 8)
	for cz in [-1.0, 1.0]:
		var pente := 0.52
		var demi_p := zh + 0.3
		var long_p := demi_p / cos(pente)
		var xf := Transform3D(Basis(Vector3.RIGHT, -cz * pente), Vector3(xc, y_c + 0.6 + demi_p * 0.5 * tan(pente), cz * demi_p * 0.5))
		v._boite(p, Vector3(lg + 0.5, 0.07, long_p), xf, v.m_poutres_h)
		v._boite(p, Vector3(lg + 0.46, 0.08, long_p - 0.1), xf * Transform3D(Basis(), Vector3(0, 0.07, 0.0)), v.m_neige)

## Coque de l'intérieur : plancher, poteaux d'angle, plafond sous charpente (entraits aux abscisses de `FERMES`).
const FERMES := {
	"halle": [-5.2, -2.6, 1.4, 3.0, 5.2],
	"sigrun": [-2.6, 0.0, 2.6],
	"chasseurs": [-2.6, 0.0, 2.6],
	"grima": [-2.2, 0.0, 2.2],
}

func coque(id: String) -> void:
	plancher()
	poteaux_angle()
	plafond(FERMES[id], trou3)

## Dessin du mobilier, des objets et des lumières de chaque intérieur.
func contenu(id: String) -> void:
	match id:
		"halle":
			InterieurHalle.construire(self)
		"sigrun", "chasseurs", "grima":
			InterieursMaisons.construire(self, id)
		"forge":
			InterieurForge.construire(self)

# ------------------------------------------------------------------------------------------------ fin

## Crée les flammes (MultiMesh de sprites), les halos additifs et la gaine de lumière.
func finir() -> void:
	_textures_feu()
	if not _flammes.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		q.center_offset = Vector3(0, 0.5, 0)
		mm.mesh = q
		mm.instance_count = _flammes.size()
		for i in _flammes.size():
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, _flammes[i][0]))
			mm.set_instance_custom_data(i, Color(_flammes[i][2], _flammes[i][1], 0.0, 0.0))
		var sm := ShaderMaterial.new()
		sm.shader = FLAMME_SHADER
		sm.set_shader_parameter("atlas", _atlas)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = sm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.name = "Flammes"
		ip.racine.add_child(mmi)
	_flammes.clear()
	for nom in ["halo", "rai"]:
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		for h in _halos:
			if h[5] != nom:
				continue
			var n: Vector3 = h[1]
			var droite := Vector3.UP.cross(n)
			var haut := Vector3.UP
			if absf(n.y) > 0.9:
				droite = Vector3.RIGHT
				haut = Vector3.FORWARD
			else:
				droite = droite.normalized()
			var c: Vector3 = h[0]
			var w: float = h[2]
			var hh: float = h[3]
			var a: Vector3 = c - droite * w * 0.5 - haut * hh * 0.5
			var b: Vector3 = c + droite * w * 0.5 - haut * hh * 0.5
			var cc: Vector3 = c + droite * w * 0.5 + haut * hh * 0.5
			var d: Vector3 = c - droite * w * 0.5 + haut * hh * 0.5
			for k in [[a, Vector2(0, 1)], [b, Vector2(1, 1)], [cc, Vector2(1, 0)], [a, Vector2(0, 1)], [cc, Vector2(1, 0)], [d, Vector2(0, 0)]]:
				verts.append(k[0])
				uvs.append(k[1])
				cols.append(h[4])
		if verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = cols
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var s := StandardMaterial3D.new()
		s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		s.albedo_texture = _halo if nom == "halo" else _rai
		s.vertex_color_use_as_albedo = true
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.cull_mode = BaseMaterial3D.CULL_DISABLED
		s.disable_receive_shadows = true
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = s
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Halos" if nom == "halo" else "Rais"
		ip.racine.add_child(mi)
	_halos.clear()
