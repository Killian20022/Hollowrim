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
const FLAMME_SHADER := preload("res://shaders/flamme_fixe.gdshader")
const RAI_SHADER := preload("res://shaders/ps1_rai.gdshader")
const F := 0.42
const AMBIANT := Color(0.52, 0.48, 0.55)   # nuit 2026-11-05 : relevée et moins brune (avant 0.29, 0.24, 0.25) ; le chaud vient du foyer, le froid des fenêtres
const FROID := Color(0.50, 0.66, 1.0)      # appoint de fenêtre : lueur de lune / d'aurore
const MAX_FROIDS := 2                      # lumières froides par bâtiment (coût GPU borné)
const DECAL_PLAFOND := 0.27       # le lambris du plafond pend sous le plan du toit
const FEU := Color(1.0, 0.66, 0.37)         # foyer moins saturé (avant 1.0, 0.56, 0.24)

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
var _froids := 0                  # lumières froides de fenêtre déjà posées
## Petits objets VIVANTS (ObjetsVivants : vaisselle, vivres…) rangés au lieu d'être fondus : specs créées par le village à la pose.
var vivants: Array = []

## Lot L6 : modules Blender du mobilier (sources_blender/scripts/mobilier_interieur.py → .dat, lu en bytes_to_var : aucun .glb,
## aucun matériau neuf dans le fil). {module: [[matière, arrays], …]} ; chargé une fois, au premier intérieur bâti.
const DAT_MOBILIER := "res://assets/modeles/mobilier_interieur.dat"
static var _mods: Dictionary = {}

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
	for nom in ["os", "parchemin", "argile", "lin", "or", "laine"]:
		if not TexturesBati._cache.has(nom):
			var img: Image = ResourceLoader.load("res://assets/crypte/%s.res" % nom)
			TexturesBati._cache[nom] = [ImageTexture.create_from_image(img), TexturesBati.relief_neutre()]
	var d := {}
	d["bois"] = _m("planches_h_int", Color(0.97, 0.93, 0.9), 64.0)
	d["bois_v"] = _m("planches_v_int", Color(0.95, 0.9, 0.86), 64.0)
	d["bois_sombre"] = _m("planches_h_int", Color(0.74, 0.69, 0.68), 64.0)
	d["bois_suie"] = _m("planches_v_int", Color(0.42, 0.38, 0.38), 64.0)
	d["bois_clair"] = _m("planches_v_int", Color(1.15, 1.08, 0.98), 64.0)
	d["bois_table"] = _m("planches_h_int", Color(2.0, 1.8, 1.6), 64.0)      # lot 4 : plateaux de la halle plus clairs (la nourriture ressort)
	d["ame"] = _m("planches_h_int", Color(0.3, 0.29, 0.32), 64.0)
	d["rondin"] = _m("rondins_int", Color(1.1, 1.05, 1.02), 64.0, 0.9, true)
	d["rondin_b"] = _m("rondins_int", Color(0.84, 0.95, 1.12), 64.0, 0.9, true)      # bois gris-bleu, vieilli par la fumée froide
	d["rondin_c"] = _m("rondins_int", Color(1.24, 1.0, 0.8), 64.0, 0.9, true)        # bois roux, plus frais
	d["rondin_sombre"] = _m("rondins_int", Color(0.95, 0.87, 0.82), 64.0, 0.9, true)
	d["bout"] = _m("bout_rondin", Color.WHITE, 64.0, 0.0, true)
	d["pierre"] = _m("pierre_int", Color(0.9, 0.97, 1.08), 64.0, 0.9)          # pierre grise, un peu froide
	d["pierre_sombre"] = _m("pierre_int", Color(0.62, 0.67, 0.76), 64.0, 0.9)
	d["brute"] = _m("pierre_int_s", Color(0.92, 0.98, 1.06), 64.0, 0.9)
	d["seche"] = _m("pierre_int", Color(1.0, 0.95, 0.9), 64.0, 1.0)
	d["pierre_mur"] = _m("pierre_int", Color(0.74, 0.7, 0.68), 64.0, 0.9)      # murs de pierre des bâtiments ouverts : moins clair que la pierre des foyers
	d["fer"] = _m("fer", Color(0.85, 0.87, 0.95))
	d["fer_noir"] = _m("fer", Color(0.45, 0.45, 0.5))
	d["etain"] = _m("fer", Color(1.35, 1.38, 1.45))
	d["cuir"] = _m("cuir", Color(1.2, 1.08, 0.95))
	d["foin"] = _m("foin", Color(0.9, 0.9, 0.82))
	d["herbe"] = _m("foin", Color(0.55, 0.78, 0.45))
	d["jute"] = _m("foin", Color(0.78, 0.66, 0.5), 64.0, 0.7)          # toile de sac (lot L6)
	d["argile"] = _m("argile", Color(1.05, 0.95, 0.9), 64.0, 0.4)      # cruches et bols tournés (lot L6)
	d["peau"] = _m("peau", Color(0.88, 0.84, 0.82), 64.0)
	d["peau_claire"] = _m("peau", Color(1.25, 1.15, 1.05), 64.0)
	d["peau_sombre"] = _m("peau", Color(0.55, 0.48, 0.46), 64.0)
	d["terre"] = _m("terre", Color.WHITE, 64.0)
	d["charbon"] = _m("charbon", Color.WHITE, 64.0)
	d["os"] = _m("os", Color(1.15, 1.1, 1.0), 64.0, 0.0)
	d["parchemin"] = _m("parchemin", Color(1.1, 1.05, 0.95), 64.0, 0.0)
	d["cire"] = _m("os", Color(1.3, 1.15, 0.8), 64.0, 0.0)
	d["noir"] = _m("fer", Color(0.12, 0.12, 0.14), 32.0, 0.0)
	# props Quaternius (props/placement) : fer MAT (CATALOGUE §6 : fer -> fer_mat), lin écru, or terni
	d["fer_mat"] = _m("fer", Color(0.72, 0.74, 0.8), 32.0, 0.6)
	d["lin"] = _m("lin", Color(1.0, 0.96, 0.9), 64.0, 0.4)
	d["or"] = _m("or", Color(1.0, 0.95, 0.85), 64.0, 0.3)
	# lot 4 (props/lot4) : nourriture Quaternius (viande, pommes, navets) : laine rouge sourde de la crypte, pas la tenture à motifs
	d["laine_q"] = _m("laine", Color(1.4, 1.1, 1.02), 64.0, 0.4)
	# lot 4 v3 : nourriture plus claire EN VALEUR (pas en saturation) pour se détacher du bois sombre sous les feux ; nappes et planches claires
	d["pain_q"] = _m("lin", Color(1.5, 1.12, 0.62), 64.0, 0.4)             # croûte dorée (lin : sans les cernes de la terre tournée)
	d["mie_q"] = _m("lin", Color(1.35, 1.24, 1.02), 64.0, 0.3)            # mie et tranche claires
	d["viande_q"] = _m("peau", Color(1.3, 0.92, 0.82), 64.0)               # viande crue, lard : rose-brun
	d["roti_q"] = _m("peau", Color(1.2, 0.9, 0.7), 64.0)                   # cuisse rôtie : brun doré
	d["fromage_q"] = _m("lin", Color(1.45, 1.32, 0.95), 64.0, 0.3)         # fromage crème
	d["nappe_q"] = _m("lin", Color(1.3, 1.25, 1.12), 64.0, 0.5)            # nappe de lin écru
	d["planche_q"] = _m("planches_h_int", Color(1.9, 1.72, 1.5), 64.0)     # planche à pain de bois clair
	var eau := _m("fer", Color(0.1, 0.14, 0.22), 32.0, 0.0)
	eau.set_shader_parameter("emission", Color(0.03, 0.06, 0.12))
	d["eau"] = eau
	d["tenture_r"] = _m("tenture_rouge", Color.WHITE, 64.0, 0.6, true)
	d["tenture_b"] = _m("tenture_bleue", Color.WHITE, 64.0, 0.6, true)
	d["tenture_v"] = _m("tenture_verte", Color.WHITE, 64.0, 0.6, true)
	d["bouclier_r"] = _m("planches_v_int", Color(1.1, 0.34, 0.3), 64.0)
	d["bouclier_b"] = _m("planches_v_int", Color(0.36, 0.5, 0.95), 64.0)
	d["bouclier_n"] = _m("planches_v_int", Color(0.4, 0.38, 0.4), 64.0)
	d["bouclier_j"] = _m("planches_v_int", Color(1.35, 1.1, 0.5), 64.0)
	var br := _m("braises")
	br.set_shader_parameter("emission", Color(1.7, 0.65, 0.18))
	br.set_shader_parameter("emission_texture", true)
	d["braises"] = br
	var rune := _m("fer", Color(0.5, 0.55, 0.62), 32.0, 0.0)
	rune.set_shader_parameter("emission", Color(0.25, 0.85, 1.0))
	d["rune"] = rune
	var cendre := _m("charbon", Color(1.5, 1.4, 1.4), 64.0)
	d["cendre"] = cendre
	# vitrage translucide (plan) + halo additif des flammes
	var vit := ShaderMaterial.new()
	vit.shader = preload("res://shaders/ps1_vitre.gdshader")
	vit.set_shader_parameter("tex_vitrage", TexturesBati.tex("vitrage"))
	d["vitre"] = vit
	Palette.suivre(vit)
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

## Pile de moellons d'intérieur : rangs de 22-30 cm, pierres de 28-52 cm, arêtes franches (chanfrein et gauchissement
## réduits) ; la texture `pierre_int` (64 texels/m, projetée en mètres : pas d'étirement) dessine les joints fins.
func pile(pos: Vector3, taille: Vector3, graine: int, mat := "brute", solide := false, neige := 0.0, lacet := 0.0) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var rangs := maxi(1, roundi(taille.y / 0.27))
	var hh := taille.y / rangs
	var basis := Basis(Vector3.UP, lacet)
	for k in rangs:
		var x := -taille.x * 0.5 - r.randf_range(0.0, 0.25)
		while x < taille.x * 0.5:
			var w := r.randf_range(0.28, 0.52)
			var x0 := maxf(x, -taille.x * 0.5)
			var x1 := minf(x + w, taille.x * 0.5)
			x += w * 0.98
			if x1 - x0 < 0.12:
				continue
			var c := Vector3((x0 + x1) * 0.5, -taille.y * 0.5 + hh * (k + 0.5), r.randf_range(-0.02, 0.02))
			v._ajouter(_p(), BatiGeo.bloc(Vector3(x1 - x0, hh * 1.03, taille.z), r.randi(), 0.1, 0.035, 0.0, 0.7).arrays(), Transform3D(basis, pos + basis * c), M[mat])
	if solide:
		v._collision(_p(), BoxShape3D.new(), Transform3D(basis, pos), taille)

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
	if longueur <= 1.3 and rayon <= 0.12 and rempl("q_buche"):      # bûche : pièce Quaternius/kitbash étirée à la longueur et au rayon voulus
		_q_xf("q_buche", Transform3D(Basis(Vector3.UP, lacet) * Basis(Vector3.BACK, pente) * Basis.from_scale(Vector3(longueur / 0.6, rayon / 0.1, rayon / 0.1)), pos), {"bois": mat})
		return
	var r := BatiGeo.rondin(longueur, rayon, graine, sag, graine % 4, float(graine % 9), 1.0, true)      # vu de près : joints en haut et en bas
	var xf := Transform3D(Basis(Vector3.UP, lacet) * Basis(Vector3.BACK, pente), pos)
	if mat == "rondin" and graine % 3 != 0:       # rondins moins répétitifs : trois bois (teinte par la graine)
		mat = "rondin_b" if graine % 3 == 1 else "rondin_c"
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

# ------------------------------------------------------------------------------------------------ modules Blender (lot L6)

static func _modules() -> Dictionary:
	if _mods.is_empty():
		var brut = bytes_to_var(FileAccess.get_file_as_bytes(DAT_MOBILIER))
		if not brut is Dictionary:
			push_error("Interieurs : %s illisible" % DAT_MOBILIER)
			return _mods
		var res := {}
		for cle: String in brut:
			if cle.begins_with("_"):
				continue
			var d: Array = brut[cle]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = d[0]
			arrays[Mesh.ARRAY_NORMAL] = d[1]
			arrays[Mesh.ARRAY_COLOR] = d[2]
			arrays[Mesh.ARRAY_INDEX] = d[3]
			var mc := cle.split("/")
			if not res.has(mc[0]):
				res[mc[0]] = []
			(res[mc[0]] as Array).append([mc[1], arrays])
		_mods = res
	return _mods

## Pose un module Blender : `xf` dans le repère de la pièce ; `mats` remplace les matières génériques (PEAU, MAT, BOUCLIER).
func modele_xf(nom: String, xf: Transform3D, mats := {}) -> void:
	var mods := _modules()
	if not mods.has(nom):
		push_error("Interieurs : module %s absent de %s" % [nom, DAT_MOBILIER])
		return
	for e: Array in mods[nom]:
		var mat: String = mats.get(e[0], e[0])
		v._ajouter(_p(), e[1], xf, M[mat])

## Module posé en `pos`, tourné de `lacet`, mis à l'échelle `ech` (dans son repère : X largeur, Y hauteur, Z profondeur).
func modele(nom: String, pos: Vector3, lacet := 0.0, ech := Vector3.ONE, mats := {}) -> void:
	modele_xf(nom, Transform3D(Basis(Vector3.UP, lacet) * Basis.from_scale(ech), pos), mats)

## Props Quaternius (scripts/props_quaternius.gd) : matière du prop -> matière de l'intérieur. Fer MAT ; pierre chaude (les briques
## sortaient bleutées sur la rampe pierre de la bible) ; laine = tenture rouge, toile = tenture bleue.
## Lot 4 : nourriture et vaisselle Quaternius (Ultimate Food) : laine = rouge sourd de la crypte (viande, pommes), pas la tenture.
const MATS_NOURRITURE := {"laine": "laine_q"}
const MATS_Q := {"bois": "bois", "herbe": "herbe", "fer": "fer_mat", "lin": "lin", "jute": "jute", "os": "os", "pierre": "pierre", "or": "or",
	"argile": "argile", "laine": "tenture_r", "toile": "tenture_b", "noir": "noir", "lame": "etain"}

## Pose un prop Quaternius fondu dans les lots de la pièce : `pos` (y < 0,2 = posé sur le sol), lacet, échelle uniforme ; `mats` remplace
## une matière (ex. {"fer": "argile"} pour un vase) ; `solide_` : boîte de collision tirée de l'emprise du prop (gros objets).
func q(nom: String, pos: Vector3, lacet := 0.0, e := 1.0, mats := {}, solide_ := false) -> void:
	if not PropsQuaternius.actif:
		return
	pos = _sol(pos)
	if not PropsQuaternius.existe(nom):
		push_error("Interieurs : prop %s absent de %s" % [nom, PropsQuaternius.DAT])
		return
	var xf := Transform3D(Basis(Vector3.UP, lacet) * Basis.from_scale(Vector3.ONE * e), pos)
	if not solide_ and _vivant(nom, xf, mats):
		return
	for m: Array in PropsQuaternius.morceaux(nom):
		var cible: String = mats.get(m[0], MATS_Q.get(m[0], "bois"))
		v._ajouter(_p(), m[1], xf, M[cible])
	if solide_:
		var bb := PropsQuaternius.boite(nom)
		solide(pos + Basis(Vector3.UP, lacet) * (bb.get_center() * e), bb.size * e, lacet)

## Prop Quaternius AJUSTÉ à une boîte cible `taille` (X largeur, Y hauteur, Z profondeur du prop ; 0 = axe libre, échelle moyenne des autres) :
## échelle non uniforme, collision éventuelle = la boîte cible. Remplace les anciens modules maison (props/remplacement).
func qf(nom: String, pos: Vector3, lacet: float, taille: Vector3, mats := {}, solide_ := false) -> void:
	if not PropsQuaternius.existe(nom):
		return
	var bb := PropsQuaternius.boite(nom)
	var sc := Vector3.ONE
	var somme := 0.0
	var n := 0
	for a in 3:
		if taille[a] > 0.0:
			sc[a] = taille[a] / maxf(bb.size[a], 0.001)
			somme += sc[a]
			n += 1
	for a in 3:
		if taille[a] <= 0.0:
			sc[a] = somme / maxf(n, 1)
	pos = _sol(pos)
	PropsQuaternius.compter("interieurs")
	var xf := Transform3D(Basis(Vector3.UP, lacet) * Basis.from_scale(sc), pos)
	if not solide_ and _vivant(nom, xf, mats):
		return
	for m: Array in PropsQuaternius.morceaux(nom):
		var cible: String = mats.get(m[0], MATS_Q.get(m[0], "bois"))
		v._ajouter(_p(), m[1], xf, M[cible])
	if solide_:
		solide(pos + Basis(Vector3.UP, lacet) * (bb.get_center() * sc), bb.size * sc, lacet)

## Petit objet du décor rendu VIVANT (ObjetsVivants.capte) : rangé dans `vivants` (mêmes matières que le lot) au lieu d'être fondu.
func _vivant(nom: String, xf: Transform3D, mats: Dictionary) -> bool:
	if not ObjetsVivants.capte(nom):
		return false
	vivants.append(ObjetsVivants.spec(nom, xf, ObjetsVivants.morceaux_q(nom, func(m: String) -> Material: return M[mats.get(m, MATS_Q.get(m, "bois"))])))
	return true

## Prop posé par une transformation complète (repère de la pièce), sans recalage au sol.
func _q_xf(nom: String, xf: Transform3D, mats := {}, double_ := Vector3.ONE) -> void:
	PropsQuaternius.compter("interieurs")
	for m: Array in PropsQuaternius.morceaux(nom):
		v._ajouter(_p(), m[1], xf, M[mats.get(m[0], MATS_Q.get(m[0], "bois"))])
		if double_ != Vector3.ONE:      # pièce plane : seconde face (axe de la normale mis à -1)
			v._ajouter(_p(), m[1], xf * Transform3D(Basis.from_scale(double_), Vector3.ZERO), M[mats.get(m[0], MATS_Q.get(m[0], "bois"))])

## Hauteur (au-dessus du pied) du plateau n°i de l'étagère à 4 niveaux : plateaux de l'étagère à arche Quaternius, sinon ceux de l'ancien module.
func niv(i: int) -> float:
	if rempl("q_etagere_arche"):
		return [0.2, 0.74, 1.26][mini(i, 2)]
	return 0.52 + 0.46 * i

## Lot 4 (props/lot4) : nourriture et vaisselle Quaternius posées sur `pos` (y < 0,2 = au sol), matières MATS_NOURRITURE ; rien avec `--sans-lot4`.
## N'utilise JAMAIS `rng` (la mise en place du reste de la pièce reste celle de l'exe 3).
func nq(nom: String, pos: Vector3, lacet := 0.0, e := 1.0, mats := {}) -> void:
	if not PropsQuaternius.lot4 or not PropsQuaternius.existe(nom):
		return
	PropsQuaternius.compter("lot4_interieurs")
	var m := MATS_NOURRITURE.duplicate()
	if nom == "q_pain" or nom == "q_tranche_pain":      # croûte dorée claire, mie écrue (v3 : la terre cuite seule restait brune sur le bois)
		m.merge({"bois": "pain_q", "jute": "mie_q"})
		if nom == "q_pain":
			e *= 0.65      # v3 : miche de ~25 cm (à x1,25 elle faisait un billot de bois sur la table)
	elif nom == "q_viande" or nom == "q_lard":
		m.merge({"lin": "viande_q"})
	elif nom == "q_cuisse":
		m.merge({"argile": "roti_q"})
	elif nom == "q_ecuelle" or nom == "q_cuillere_bois":
		m.merge({"bois": "bois_clair"})
	q(nom, pos, lacet, e * 1.25, m.merged(mats))   # x1,25 : lisible en vue de jeu

## Lot 4 v3 : nappe de lin claire (ou planche de bois clair) posée sous la nourriture, qui la détache du plateau sombre ; `pos` = centre, au dessus.
func nappe(pos: Vector3, taille: Vector2, lacet := 0.0, planche := false) -> void:
	if not PropsQuaternius.lot4:
		return
	bx(pos + Vector3(0, 0.012 if planche else 0.004, 0), Vector3(taille.x, 0.024 if planche else 0.008, taille.y), "planche_q" if planche else "nappe_q", lacet)

## Lot 4 v3 : meule de fromage crème entamée (meule + quartier).
func fromage(pos: Vector3, lacet := 0.0) -> void:
	if not PropsQuaternius.lot4:
		return
	if ObjetsVivants.capte("fromage"):      # meule vivante (même géométrie : ObjetsVivants.morceaux_fromage)
		vivants.append(ObjetsVivants.spec("fromage", Transform3D(Basis(Vector3.UP, lacet), _sol(pos)), ObjetsVivants.morceaux_fromage(M["fromage_q"])))
		return
	cyl(pos + Vector3(0, 0.045, 0), 0.11, 0.09, "fromage_q", 8)
	bx(pos + Basis(Vector3.UP, lacet) * Vector3(0.17, 0.03, 0.02), Vector3(0.09, 0.06, 0.06), "fromage_q", lacet + 0.5)

## Lot 4 : couvert posé (écuelle de bois ou d'argile, cuillère de bois, couteau) ; `pos` = centre de l'écuelle.
func mets(pos: Vector3, lacet := 0.0, argile := false) -> void:
	if not PropsQuaternius.lot4:
		return
	var bz := Basis(Vector3.UP, lacet)
	nq("q_ecuelle_2" if argile else "q_ecuelle", pos, lacet + 0.7)
	nq("q_cuillere_bois", pos + bz * Vector3(0.2, 0, 0.05), lacet + 1.5)
	nq("q_couteau_f", pos + bz * Vector3(-0.2, 0, 0.0), lacet + 1.62)

## Prop de remplacement disponible (option `--sans-remplacement` : anciens modules maison).
static func rempl(nom: String) -> bool:
	return PropsQuaternius.remplace and PropsQuaternius.existe(nom)

## Variante tirée de la position (stable d'un lancement à l'autre) : "a", "b" ou "c".
static func variante(pos: Vector3, n: int, sel := 0) -> String:
	var h := absi(int(floorf(pos.x * 7.31 + pos.z * 13.17 + pos.y * 3.7)) + sel)
	return "abc"[h % n]

## Lacet de variété tiré de la position (petits objets ronds).
static func lacet_libre(pos: Vector3) -> float:
	return fposmod(pos.x * 4.1 + pos.z * 2.7, TAU)

# ------------------------------------------------------------------------------------------------ feu et lumière

func flamme(pos: Vector3, echelle := 1.0, cuit := 0.0) -> void:
	_flammes.append([pos, echelle, rng.randf() * 4.0, cuit])

## Lit de braises incandescent (cases de monde qui pulsent, shaders/feu_lit_braises.gdshader) posé sur les braises d'un foyer.
func lit_braises(pos: Vector3, taille: Vector2) -> void:
	FeuFixe.lit_de_braises(ip.racine, pos, taille, 0.04)

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
	if rempl("q_bougie_1"):      # Candle_1 (bougie sur sa soucoupe) ; flamme et lumière inchangées
		qf("q_bougie_1", pos, lacet_libre(pos), Vector3(0, h + 0.01, 0), {"os": "cire"})
		flamme(pos + Vector3(0, h, 0), 0.4)
		if avec_lumiere:
			lumiere(pos + Vector3(0, h + 0.35, 0), 0.9, 3.6, FEU, 1.8)
		return
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
	if _froids < MAX_FROIDS:       # appoint froid : la lueur du dehors tombe de la fenêtre dans la pièce (sans vaciller)
		_froids += 1
		lumiere(Vector3(x, y - 0.1, zi - face * 0.7), 1.0, 4.2, FROID, 1.6, false)

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

## Table sur tréteaux (long le long de X pour lacet 0) : plateau de planches, tréteaux, entretoise (modules L6).
var mats_table := {}      # matières imposées aux tables Quaternius (lot 4 : halle plus claire) ; vide = comme avant
func table(pos: Vector3, long: float, larg: float, lacet := 0.0, haut := 0.78, solide_ := true) -> void:
	pos = _sol(pos)
	if rempl("q_grande_table"):      # props/remplacement : Table_Large (ou établi Workbench si plan de travail haut)
		if solide_:
			solide(pos + Vector3(0, haut - 0.05, 0), Vector3(long, 0.1, larg), lacet)
		qf("q_etabli" if haut > 0.83 else "q_grande_table", pos, lacet, Vector3(long, haut, larg), mats_table)
		return
	var b := Basis(Vector3.UP, lacet)
	if solide_:
		solide(pos + Vector3(0, haut - 0.05, 0), Vector3(long, 0.1, larg), lacet)
	var va := variante(pos, 2)
	modele("table_plateau_" + va, pos + Vector3(0, haut, 0), lacet, Vector3(long / 2.0, 1.0, larg / 0.8))
	var n := maxi(2, int(long / 1.4) + 1)
	for i in n:
		var dx := -long * 0.5 + 0.25 + (long - 0.5) * float(i) / (n - 1)
		modele("table_treteau_" + va, pos + b * Vector3(dx, 0, 0), lacet, Vector3(1.0, (haut - 0.1) / 0.68, larg / 0.8))
	modele("table_entretoise", pos + Vector3(0, 0.2, 0), lacet, Vector3(long - 0.5, 1.0, 1.0))

func banc(pos: Vector3, long: float, lacet := 0.0, haut := 0.46, prof := 0.34, solide_ := true) -> void:
	pos = _sol(pos)
	if rempl("q_banc"):
		if solide_:
			solide(pos + Vector3(0, haut - 0.04, 0), Vector3(long, 0.08, prof), lacet)
		qf("q_banc", pos, lacet, Vector3(long, haut, prof))
		return
	var b := Basis(Vector3.UP, lacet)
	if solide_:
		solide(pos + Vector3(0, haut - 0.04, 0), Vector3(long, 0.08, prof), lacet)
	modele("banc_assise_" + variante(pos, 2), pos + Vector3(0, haut, 0), lacet, Vector3(long / 2.0, 1.0, prof / 0.34))
	for sx in [-1.0, 1.0]:
		modele("banc_pied", pos + b * Vector3(sx * (long * 0.5 - 0.25), 0, 0), lacet, Vector3(1.0, (haut - 0.08) / 0.38, (prof - 0.06) / 0.28))

func tabouret(pos: Vector3, haut := 0.45) -> void:
	pos = _sol(pos)
	if rempl("q_tabouret"):
		qf("q_tabouret", pos, lacet_libre(pos), Vector3(0, haut, 0))
		solide_cyl(pos + Vector3(0, haut * 0.5, 0), 0.2, haut)
		return
	modele("tabouret_" + variante(pos, 2), pos, lacet_libre(pos), Vector3(1.0, haut / 0.45, 1.0))
	solide_cyl(pos + Vector3(0, haut * 0.5, 0), 0.2, haut)

## Coffre ferré : caisse de planches, couvercle bombé / plat / en bâtière, ferrures, serrure (modules L6).
func coffre(pos: Vector3, lacet := 0.0, taille := Vector3(0.9, 0.46, 0.55), _ouvert := false) -> void:
	if rempl("q_coffre"):      # décor (les coffres de butin interactifs sont posés par le monde, pas ici)
		solide(pos + Vector3(0, taille.y * 0.5, 0), taille, lacet)
		qf("q_coffre", pos, lacet, Vector3(taille.x, taille.y, taille.z))
		return
	solide(pos + Vector3(0, taille.y * 0.5, 0), taille, lacet)
	modele("coffre_" + variante(pos, 3), pos, lacet, taille / Vector3(0.9, 0.46, 0.55))

## Tonneau de douelles cerclé ; la variante à cannelle tourne sa cannelle vers le centre de la pièce.
func tonneau(pos: Vector3, h := 0.9, r := 0.34, solide_ := true) -> void:
	pos = _sol(pos)
	if rempl("q_tonneau"):
		if solide_:
			solide_cyl(pos + Vector3(0, h * 0.5, 0), r, h)
		qf("q_tonneau", pos, lacet_libre(pos), Vector3(r * 2.0, h, r * 2.0))
		return
	if solide_:
		solide_cyl(pos + Vector3(0, h * 0.5, 0), r, h)
	var va := variante(pos, 3)
	var lac := atan2(-pos.x, -pos.z) if va == "b" else lacet_libre(pos)
	modele("tonneau_" + va, pos, lac, Vector3(r / 0.34, h / 0.9, r / 0.34))

func etagere(pos: Vector3, lacet: float, larg: float, haut: float, niveaux := 3, prof := 0.32) -> void:
	if rempl("q_etagere_arche"):      # étagère à arche : plateaux à NIV_ETAGERE (m au-dessus du pied), à respecter par les objets posés dessus
		pos = _sol(pos)
		qf("q_etagere_arche", pos, lacet, Vector3(larg, 0, prof))
		solide(pos + Vector3(0, haut * 0.5, 0), Vector3(larg, haut, prof), lacet)
		return
	if niveaux != 4:
		_etagere_boites(pos, lacet, larg, haut, niveaux, prof)
		return
	pos = _sol(pos)
	modele("etagere_" + variante(pos, 2), pos, lacet, Vector3(larg / 1.5, haut / 2.0, prof / 0.3))
	solide(pos + Vector3(0, haut * 0.5, 0), Vector3(larg, haut, prof), lacet)

## Lit (lot « sommeil ») : un Marker3D du groupe « emplacement_lit » où Sommeil pose un `Lit` (modèle procédural, places de couchage,
## collision, « Dormir »). Tête vers -X local (lacet 0), comme les lits d'avant ; le marqueur regarde la tête en +Z (son -Z = le pied).
## `larg` / `long` en mètres (Lit : double dès 1,2 m). `proprietaire` : id(s) de PNJ séparés par des virgules, « joueur », « auberge »,
## ou "" (lit libre du foyer `foyer`, ou de l'intérieur qui le contient) ; "?" (défaut) : celui que data/batiments.json donne au
## n-ième lit de cet intérieur (« lits_existants », bâtiments ouverts). Les lits des bâtiments ouverts passent par ici aussi.
## `marqueur` faux : l'ancien lit fusionné (modules Quaternius / L6), sans couchage (lit clos de la halle, bâti autour de lui).
var _n_lits := 0

func lit(pos: Vector3, lacet: float, long := 1.95, larg := 0.95, peau_mat := "peau", etat := 0, proprietaire := "?", foyer := "", marqueur := true) -> void:
	if not marqueur:
		_lit_fusionne(pos, lacet, long, larg, peau_mat, etat)
		return
	if proprietaire == "?":
		proprietaire = BatimentsOuverts.proprietaire_lit(String(ip.get_meta("id", "")), _n_lits)
	var m := Marker3D.new()
	m.name = "EmplacementLit%d" % _n_lits
	_n_lits += 1
	m.add_to_group("emplacement_lit", true)
	m.set_meta("proprietaire", proprietaire)
	m.set_meta("largeur", larg)
	m.set_meta("longueur", long)
	m.set_meta("peau", peau_mat)
	if foyer != "":
		m.set_meta("foyer", foyer)
	m.transform = Transform3D(Basis(Vector3.UP, lacet - PI * 0.5), pos)
	_p().add_child(m)

## Lit d'avant le lot sommeil : montants, chevets, paillasse, peau drapée, coussin (modules L6), tête vers -X local.
func _lit_fusionne(pos: Vector3, lacet: float, long: float, larg: float, peau_mat: String, etat: int) -> void:
	var b := Basis(Vector3.UP, lacet)
	solide(pos + Vector3(0, 0.3, 0), Vector3(long, 0.12, larg), lacet)
	if rempl("q_lit"):      # Bed_Twin : longueur le long de Z du prop → tourné d'un quart de tour (tête vers -X local comme avant)
		qf("q_lit" if variante(pos, 2) == "a" else "q_lit_2", pos, lacet + PI * 0.5, Vector3(larg, 0.75, long))
		return
	modele("lit_" + variante(pos, 2), pos, lacet, Vector3(long / 2.0, 1.0, larg / 1.0), {"PEAU": peau_mat})
	if etat == 1:   # défait
		modele("fourrure_froissee", pos + b * Vector3(0.25, 0.0, 0.1), lacet + 0.3, Vector3.ONE, {"PEAU": peau_mat})

func _etagere_boites(pos: Vector3, lacet: float, larg: float, haut: float, niveaux := 3, prof := 0.32) -> void:
	pos = _sol(pos)
	var b := Basis(Vector3.UP, lacet)
	for sx in [-1.0, 1.0]:
		bx(pos + b * Vector3(sx * (larg * 0.5 - 0.04), haut * 0.5, 0), Vector3(0.07, haut, prof), "bois_v", lacet)
	for i in niveaux:
		var y := haut * (float(i) + 0.8) / (niveaux + 0.5) - 0.0
		bx(pos + Vector3(0, y, 0), Vector3(larg, 0.045, prof), "bois", lacet)
	bx(pos + b * Vector3(0, haut * 0.5, -prof * 0.5 + 0.015), Vector3(larg - 0.08, haut - 0.1, 0.02), "bois_sombre", lacet)
	solide(pos + Vector3(0, haut * 0.5, 0), Vector3(larg, haut, prof), lacet)

func bouclier(pos: Vector3, lacet: float, rayon := 0.36, mat := "bouclier_r") -> void:
	if rempl("q_bouclier_bois"):      # Shield_Wooden : plaques de bois teintes par `mat`, ferrures en fer mat
		qf("q_bouclier_bois", pos, lacet, Vector3(rayon * 1.75, rayon * 1.75, 0), {"bois": mat})
		return
	modele("bouclier_" + variante(pos, 2), pos, lacet, Vector3.ONE * (rayon / 0.36), {"BOUCLIER": mat})

func crane(pos: Vector3, lacet := 0.0, e := 1.0) -> void:
	modele("crane", pos + Vector3(0, -0.05 * e, 0), lacet, Vector3.ONE * e)

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
	if rempl("q_hache_outil"):      # Axe_Bronze (manche de bois, fer mat), debout comme l'ancien module
		var b := Basis(Vector3.UP, lacet) * Basis(Vector3.BACK, inclin) * Basis.from_scale(Vector3.ONE * e)
		_q_xf("q_hache_outil", Transform3D(b, pos + b * Vector3(0, -0.4, 0)))
		return
	modele_xf("hache", Transform3D(Basis(Vector3.UP, lacet) * Basis(Vector3.BACK, inclin) * Basis.from_scale(Vector3.ONE * e), pos))

func epee(pos: Vector3, lacet: float, inclin := 0.0, e := 1.0) -> void:
	if rempl("q_epee_mur"):      # Sword_Bronze
		var b := Basis(Vector3.UP, lacet) * Basis(Vector3.BACK, inclin) * Basis.from_scale(Vector3.ONE * e)
		_q_xf("q_epee_mur", Transform3D(b, pos + b * Vector3(0, -0.55, 0)))
		return
	modele_xf("epee", Transform3D(Basis(Vector3.UP, lacet) * Basis(Vector3.BACK, inclin) * Basis.from_scale(Vector3.ONE * e), pos))

func lance(pos: Vector3, lacet: float, inclin := 0.0, long := 1.9) -> void:
	if rempl("q_poutre_ronde"):      # lance = hampe (poutre ronde Quaternius/kitbash étirée) + pointe (épée mur réduite en fer de lance)
		var b := Basis(Vector3.UP, lacet) * Basis(Vector3.BACK, inclin)
		_q_xf("q_poutre_ronde", Transform3D(b * Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(long, 0.5, 0.5)), pos + b * Vector3(0, long * 0.5, 0)))
		_q_xf("q_epee_mur", Transform3D(b * Basis.from_scale(Vector3(0.7, 0.28, 0.7)), pos + b * Vector3(0, long, 0)), {"bois": "fer_mat"})
		return
	var b := Basis(Vector3.UP, lacet) * Basis(Vector3.BACK, inclin)
	modele_xf("lance_hampe", Transform3D(b * Basis.from_scale(Vector3(1.0, long, 1.0)), pos))
	modele_xf("lance_fer", Transform3D(b, pos + b * Vector3(0, long * 0.5, 0)))

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
	if rempl("q_bourse") and rempl("q_carotte"):      # kitbash : jambons = bourse Quaternius, saucissons = carotte retournée, ficelle = poutre ronde fine
		var bz := Basis(Vector3.UP, lacet)
		for i in k:
			var off := bz * Vector3(float(i - (k - 1) * 0.5) * 0.2, 0, 0)
			var hh := 0.26 + rng.randf() * 0.16
			_q_xf("q_poutre_ronde", Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(0.2, 0.07, 0.07)), pos + off + Vector3(0, -0.1, 0)), {"bois": "cuir"})
			if PropsQuaternius.lot4 and rempl("q_cuisse"):      # lot 4 : vraies pièces, cuisse fumée (os en haut, noué) / saucisses pendues
				if i % 2 == 0:
					_q_xf("q_cuisse", Transform3D(bz * Basis(Vector3.BACK, -PI * 0.5) * Basis.from_scale(Vector3.ONE * (0.8 + hh * 0.6)), pos + off + Vector3(0, -0.2 - hh * 0.35, 0)), MATS_NOURRITURE.merged({"argile": "peau_sombre"}))
				else:
					_q_xf("q_saucisse" if i % 4 == 1 else "q_saucisse_crue", Transform3D(bz * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3.ONE * (hh * 0.8 / 0.18)), pos + off + Vector3(0, -0.2 - hh * 0.4, 0)), MATS_NOURRITURE.merged({"argile": "peau_sombre"}))
			elif i % 2 == 0:
				_q_xf("q_bourse", Transform3D(bz * Basis.from_scale(Vector3.ONE * (hh / 0.30)), pos + off + Vector3(0, -0.2 - hh, 0)), {"fer": "peau_sombre", "os": "os"})
			else:
				_q_xf("q_carotte", Transform3D(bz * Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3(1.0, hh * 0.9 / 0.30, 1.0) * Vector3(0.9, 1.0, 0.9)), pos + off + Vector3(0, -0.2, 0)), {"fer": "cuir"})
		return
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
	if rempl("q_carotte"):      # kitbash : bouquet = cinq feuilles-carottes retournées (teinte herbe / foin) liées à une barre fine
		_q_xf("q_poutre_ronde", Transform3D(Basis(Vector3.UP, lacet) * Basis.from_scale(Vector3(0.2, 0.07, 0.07)), pos + Vector3(0, -0.01, 0)), {"bois": "cuir"})
		for i in 5:
			var dx := (i - 2) * 0.04
			var hq := (0.3 + 0.05 * (i % 2)) * e
			_q_xf("q_carotte", Transform3D(Basis(Vector3.UP, lacet + i * 0.9) * Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3(1.0, hq / 0.30, 1.0) * Vector3(0.7, 1.0, 0.7)) , pos + Basis(Vector3.UP, lacet) * Vector3(dx, -0.02, 0)), {"fer": "herbe" if i % 2 == 0 else "foin"})
		return
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
	if rempl("q_assiette"):      # kitbash : fût et fléau = poutre ronde fine (fer mat), plateaux = assiettes Quaternius
		_q_xf("q_poutre_ronde", Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(0.24, 0.1, 0.1)), pos + Vector3(0, 0.12, 0)), {"bois": "fer_mat"})
		_q_xf("q_poutre_ronde", Transform3D(Basis.from_scale(Vector3(0.3, 0.1, 0.1)), pos + Vector3(0, 0.24, 0)), {"bois": "fer_mat"})
		for sx in [-1.0, 1.0]:
			cyl(pos + Vector3(sx * 0.14, 0.15, 0), 0.004, 0.18, "fer", 4)
			qf("q_assiette", pos + Vector3(sx * 0.14, 0.055, 0), 0.0, Vector3(0.12, 0, 0.12), {"fer": "etain"})
		qf("q_assiette", pos + Vector3(0, 0.0, 0), 0.0, Vector3(0.1, 0, 0.1))
		return
	cyl(pos + Vector3(0, 0.12, 0), 0.012, 0.24, "fer", 4)
	bx(pos + Vector3(0, 0.24, 0), Vector3(0.3, 0.012, 0.012), "fer")
	for sx in [-1.0, 1.0]:
		cyl(pos + Vector3(sx * 0.14, 0.15, 0), 0.004, 0.18, "fer", 4)
		cyl(pos + Vector3(sx * 0.14, 0.055, 0), 0.05, 0.01, "etain", 8)
	cyl(pos + Vector3(0, 0.005, 0), 0.04, 0.01, "fer", 6)

func assiette(pos: Vector3, mat := "etain") -> void:
	if rempl("q_assiette"):
		qf("q_assiette", pos, 0.0, Vector3(0.24, 0, 0.24), {"fer": mat})
		return
	modele("assiette", pos, 0.0, Vector3.ONE, {"MAT": mat})

func chope(pos: Vector3, mat := "bois") -> void:
	if rempl("q_chope"):
		qf("q_chope", pos, lacet_libre(pos), Vector3(0.12, 0, 0), {"bois": mat, "fer": "etain" if mat == "etain" else "fer_mat"})
		return
	modele("chope_" + variante(pos, 2), pos, lacet_libre(pos), Vector3.ONE, {"MAT": mat})

func chaudron(pos: Vector3, r := 0.3) -> void:
	if PropsQuaternius.lot4 and rempl("q_marmite_soupe"):      # lot 4 : marmite de soupe (pot de fer, bouillon) à la place du chaudron vide
		PropsQuaternius.compter("lot4_interieurs")
		qf("q_marmite_soupe", pos, lacet_libre(pos), Vector3(r * 1.9, 0, 0), {"fer": "fer_noir"})
		return
	if rempl("q_chaudron"):
		qf("q_chaudron", pos, lacet_libre(pos), Vector3(r * 2.0, 0, 0))
		return
	modele("chaudron", pos, lacet_libre(pos), Vector3.ONE * (r / 0.3))

func bol(pos: Vector3) -> void:
	if rempl("q_marmite"):      # bol = petite marmite d'argile (Pot_1)
		qf("q_marmite", pos, lacet_libre(pos), Vector3(0.2, 0, 0), {"fer": "argile"})
		return
	modele("bol", pos, lacet_libre(pos))

func cruche(pos: Vector3, h := 0.3) -> void:
	if rempl("q_vase_4"):
		if variante(pos, 2) == "a":
			qf("q_vase_4", pos, lacet_libre(pos), Vector3(0, h, 0), {"fer": "argile"})
		else:
			qf("q_vase_2", pos, lacet_libre(pos), Vector3(h * 0.9, h, h * 0.9), {"fer": "argile"})
		return
	modele("cruche_" + variante(pos, 2), pos, lacet_libre(pos), Vector3.ONE * (h / 0.3))

func livre(pos: Vector3, lacet := 0.0) -> void:
	if rempl("q_livre_7"):
		qf("q_livre_7", pos, lacet, Vector3(0.2, 0, 0), {"fer": "cuir"})
		return
	modele("livre", pos, lacet)

func parchemin(pos: Vector3, lacet := 0.0) -> void:
	if rempl("q_parchemin"):
		qf("q_parchemin", pos, lacet, Vector3(0.2, 0, 0), {"fer": "bois"})
		return
	modele("parchemin", pos, lacet)

## Peau posée au sol (y = 0 : sur le plancher).
func peau_sol(pos: Vector3, taille: Vector2, lacet := 0.0, mat := "peau") -> void:
	if rempl("q_banniere_toile"):      # kitbash : tissu de bannière Quaternius couché sur le plancher (deux faces), teinte de la peau voulue
		var yy := (F if pos.y < 0.01 else pos.y) + 0.025
		var bb := PropsQuaternius.boite("q_banniere_toile")
		var xf := Transform3D(Basis(Vector3.UP, lacet) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(taille.x / bb.size.x, taille.y / bb.size.y, 3.0)), Vector3(pos.x, yy, pos.z) + Basis(Vector3.UP, lacet) * Vector3(0, 0, -taille.y * 0.5))
		_q_xf("q_banniere_toile", xf, {"toile": mat, "laine": mat}, Vector3(1, 1, -1))
		return
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
	if rempl("q_sac"):
		v._collision(_p(), BoxShape3D.new(), Transform3D(Basis.from_euler(Vector3(0, lac, 0.05)), pos + Vector3(0, h * 0.5, 0)), Vector3(0.42, h, 0.3))
		qf("q_sac", pos, lac, Vector3(0, h, 0))
		return
	v._collision(_p(), BoxShape3D.new(), Transform3D(Basis.from_euler(Vector3(0, lac, 0.05)), pos + Vector3(0, h * 0.5, 0)), Vector3(0.42, h, 0.3))
	modele("sac_" + "abc"[int(absf(graine) * 3.0) % 3], pos, lac, Vector3(1.0, h / 0.5, 1.0))

func os_sol(pos: Vector3, lacet := 0.0) -> void:
	bx(pos + Vector3(0, 0.02, 0), Vector3(0.2, 0.035, 0.045), "os", lacet)
	bx(pos + Vector3(0.09, 0.025, 0.0), Vector3(0.05, 0.045, 0.06), "os", lacet + 0.4)

## Tas de bûches (fendues) empilées contre un mur.
func buches(pos: Vector3, lacet := 0.0) -> void:
	if rempl("q_buche"):      # kitbash : bûches (pièce Quaternius/kitbash) empilées 4-3-2, même emprise et même collision
		var bs := Basis(Vector3.UP, lacet)
		for rang in 3:
			for k in 4 - rang:
				var d := bs * Vector3((k + rang * 0.5) * 0.24 - 0.4, 0.1 + rang * 0.2, 0)
				_q_xf("q_buche", Transform3D(bs * Basis(Vector3.UP, PI * 0.5 + 0.05 * (k + rang)) * Basis.from_scale(Vector3(1.0, 1.0, 1.0)), pos + d))
		solide(pos + bs * Vector3(0, 0.3, 0), Vector3(1.05, 0.6, 0.62), lacet)
		return
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
		mm.mesh = PrimGeo.maillage(PrimGeo.plan(Vector2(1, 1), Vector3(0, 0.5, 0)))   # = QuadMesh, sans ressource primitive en fil
		mm.instance_count = _flammes.size()
		for i in _flammes.size():
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, _flammes[i][0]))
			mm.set_instance_custom_data(i, Color(_flammes[i][2], _flammes[i][1], _flammes[i][3], 0.0))
		var sm := ShaderMaterial.new()
		sm.shader = FLAMME_SHADER
		sm.set_shader_parameter("vent_k", 0.0)      # à l'abri du toit
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = sm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.name = "Flammes"
		ip.racine.add_child(mmi)
	_flammes.clear()
	# lumière volumétrique (shader ps1_rai) : halos au sol, halos muraux, rais ; chaque groupe = un maillage fusionné
	for nom in ["sol", "mur", "rai"]:
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		for h in _halos:
			var n: Vector3 = h[1]
			var est_rai: bool = h[5] == "rai"
			var groupe := "rai" if est_rai else ("sol" if absf(n.y) > 0.9 else "mur")
			if groupe != nom:
				continue
			var c: Vector3 = h[0]
			if nom == "sol":
				c.y += 0.05      # un peu au-dessus du sol : le fondu de profondeur ne l'éteint pas
			var w: float = h[2]
			var hh: float = h[3]
			var plans: Array = []      # [droite, haut, normale, largeur haut, largeur bas]
			if est_rai:
				for k in 4:
					var ang := PI * 0.25 * k
					var d := Vector3(cos(ang), 0, sin(ang))
					plans.append([d, Vector3.UP, Vector3(-d.z, 0, d.x), w * 0.5, w])
			else:
				var droite := Vector3.UP.cross(n)
				var haut := Vector3.UP
				if absf(n.y) > 0.9:
					droite = Vector3.RIGHT
					haut = Vector3.FORWARD
				else:
					droite = droite.normalized()
				plans.append([droite, haut, n, w, w])
			for pl in plans:
				var dr: Vector3 = pl[0]
				var hu: Vector3 = pl[1]
				var nn: Vector3 = pl[2]
				var wt: float = pl[3]
				var wb: float = pl[4]
				# rai : le haut (y max) est en UV.y = 0, la base en UV.y = 1 ; halo : (0,1) = bas gauche
				var a: Vector3 = c - dr * wb * 0.5 - hu * hh * 0.5
				var b: Vector3 = c + dr * wb * 0.5 - hu * hh * 0.5
				var cc: Vector3 = c + dr * wt * 0.5 + hu * hh * 0.5
				var d2: Vector3 = c - dr * wt * 0.5 + hu * hh * 0.5
				for q in [[a, Vector2(0, 1)], [b, Vector2(1, 1)], [cc, Vector2(1, 0)], [a, Vector2(0, 1)], [cc, Vector2(1, 0)], [d2, Vector2(0, 0)]]:
					verts.append(q[0])
					norms.append(nn)
					uvs.append(q[1])
					cols.append(h[4])
		if verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = cols
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var s := ShaderMaterial.new()
		s.shader = RAI_SHADER
		s.set_shader_parameter("mode", 0 if nom == "rai" else 1)
		s.set_shader_parameter("angle_fondu", 0.75 if nom == "sol" else 1.0)
		s.set_shader_parameter("fondu_profondeur", 0.12 if nom == "sol" else (0.5 if nom == "rai" else 0.3))
		s.set_shader_parameter("intensite", 1.0)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = s
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Rais" if nom == "rai" else "Halos"
		ip.racine.add_child(mi)
	_halos.clear()
