class_name Lit
extends StaticBody3D
## Lit nordique (lot « sommeil », retours exe 5) : modèle procédural low-poly PS1 accordé aux intérieurs (matières
## `Interieurs.materiaux()`, shader ps1_interieur, couleur de sommet = occlusion au pied) et places de couchage pour les PNJ et le joueur.
##   - `Lit.creer(largeur, proprietaire)` : simple (largeur < 1,2 : une place) ou double (deux places côte à côte) ;
##     `proprietaire` = id de PNJ (« volva »), plusieurs séparés par des virgules (lit double), « joueur » (sa maison), « auberge »
##     (à louer), ou "" (lit libre) ;
##   - repère : origine = centre du lit AU SOL, -Z = pied du lit, +Z = tête (chevet), X = largeur ;
##   - cadre de bois (quatre montants, longs pans, chevet haut à pommeaux, pied bas), paillasse de toile, fourrure drapée qui retombe
##     sur les côtés, oreiller ; collision du cadre (on ne traverse pas le lit, les PNJ couchés n'ont plus de collision propre) ;
##   - `pose_couchee(i)` / `pose_assise(i, cote)` : où se pose le corps (pied du modèle) couché dans la place i, et assis au bord ;
##   - `occupants` : place -> nœud (PNJ ou joueur), tenu par Sommeil.
## Posé automatiquement par Sommeil sur chaque Marker3D du groupe « emplacement_lit » (meta « proprietaire », « largeur », « foyer »).

const GROUPE := "lits"
const LONG := 2.06               # longueur hors tout (m)
const LARG_SIMPLE := 1.0
const LARG_DOUBLE := 1.52
const H_CADRE := 0.36            # dessus des longs pans
const H_PAILLASSE := 0.50        # dessus de la paillasse
const H_CHEVET := 0.98
const H_PIED := 0.62
const ECART_PLACE := 0.37        # demi-écart des deux places d'un lit double
const RECUL_ASSIS := 0.30        # le pied du modèle assis est à ce recul du bord (le bassin du clip Sitting recule de ~0,3 m)

var proprietaire := ""
var proprietaires: PackedStringArray = []
var foyer := ""                  # id du bâtiment (halle, sigrun…) : lits libres du foyer
var largeur := LARG_SIMPLE
var longueur := LONG
var peau := "peau"
var occupants: Array = [null]    # place -> Node (PNJ / joueur) ou null
var cotes_libres: Array = [1.0, -1.0]   # côté par où l'on monte, par place (+1 = +X, -1 = -X) ; réglé par Sommeil (murs)
var loue := false                # lit d'auberge loué par le joueur
var interactif: Node3D

## `largeur_` : 1 = simple, 2 = double, ou une largeur en mètres (0,9 à 1,6 ; double dès 1,2 m) ; `longueur` en mètres (1,8 à 2,1) ;
## `peau` : matière de la fourrure (peau, peau_claire, peau_sombre).
static func creer(largeur_: float, proprietaire_ := "", mats: Dictionary = {}, peau := "peau", longueur_ := LONG) -> Lit:
	var l := Lit.new()
	l.name = "Lit"
	l.proprietaire = proprietaire_.strip_edges()
	l.proprietaires = PackedStringArray()
	for p in l.proprietaire.split(",", false):
		if p.strip_edges() != "":
			l.proprietaires.append(p.strip_edges())
	l.largeur = LARG_DOUBLE if largeur_ >= 1.95 else clampf(largeur_, 0.9, 1.6)
	l.longueur = clampf(longueur_, 1.8, 2.1)
	l.peau = peau
	l.occupants = [null, null] if l.largeur >= 1.2 else [null]
	l.cotes_libres = [-1.0, 1.0] if l.places() == 2 else [1.0]
	if mats.is_empty():
		mats = _mats_defaut()
	l._construire(mats)
	l.add_to_group(GROUPE)
	return l

static var _mats: Dictionary = {}
static func _mats_defaut() -> Dictionary:
	if _mats.is_empty():
		_mats = Interieurs.materiaux()
	return _mats

func places() -> int:
	return occupants.size()

func double() -> bool:
	return places() == 2

## Vrai si `id` (PNJ) est propriétaire de ce lit.
func a_pour_proprietaire(id: String) -> bool:
	return id != "" and id in proprietaires

## Lit libre : sans propriétaire (ou loué à l'auberge par le joueur).
func libre() -> bool:
	return proprietaires.is_empty()

func place_libre() -> int:
	for i in occupants.size():
		if occupants[i] == null or not is_instance_valid(occupants[i]):
			occupants[i] = null
			return i
	return -1

func liberer(n: Node) -> void:
	for i in occupants.size():
		if occupants[i] == n:
			occupants[i] = null

## Décalage latéral de la place i (repère du lit).
func x_place(i: int) -> float:
	var e := minf(ECART_PLACE, largeur * 0.25)
	return 0.0 if not double() else (-e if i == 0 else e)

## Pied du modèle couché sur le dos dans la place i (repère du monde) : le haut du modèle (+Y) vers le chevet, la face (+Z) vers le
## plafond. Le pied du modèle est à 0,2 m du bout du lit ; il est à 0,165 m au-dessus de la paillasse (épaisseur du dos : elle s'enfonce de 2-3 cm).
func pose_couchee(i: int) -> Transform3D:
	var b := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))   # colonnes : X modèle, Y modèle (tête), Z modèle (face)
	var o := Vector3(x_place(i), H_PAILLASSE + 0.165, -longueur * 0.5 + 0.2)
	return global_transform * Transform3D(b, o)

## Corps assis sur le bord de la place i, côté `cote` (+1 / -1), tourné vers l'extérieur, pied du modèle au sol.
func pose_assise(i: int, cote := 0.0) -> Transform3D:
	if cote == 0.0:
		cote = float(cotes_libres[clampi(i, 0, cotes_libres.size() - 1)])
	var x := cote * (largeur * 0.5 + RECUL_ASSIS)      # bord du lit de ce côté (place 1 d'un double prise par l'autre bord : il glisse en s'allongeant)
	var face := Vector3(cote, 0, 0)                      # le modèle regarde +Z : on l'oriente vers l'extérieur du lit
	var b := Basis(Vector3.UP.cross(face), Vector3.UP, face)
	return global_transform * Transform3D(b, Vector3(x, 0.0, -0.12))

## Point (monde) où l'on se tient debout avant de s'asseoir : un peu plus loin du bord que la pose assise.
func point_abord(i: int, cote := 0.0) -> Vector3:
	var xf := pose_assise(i, cote)
	return xf.origin + xf.basis.z * 0.12

## Nom affiché : « Lit de Sigrún », « Votre lit », « Lit libre »…
func nom_affiche(noms: Dictionary = {}) -> String:
	if "joueur" in proprietaires:
		return "Votre lit" if Stockage.maison_achetee else "Lit"
	if proprietaire == "auberge":
		return "Lit loué" if loue else "Lit de l'auberge"
	if proprietaires.is_empty():
		return "Lit libre"
	var n: Array = []
	for p in proprietaires:
		n.append(String(noms.get(p, p)))
	return "Lit de " + " et ".join(n)

# ------------------------------------------------------------------------------------------------ modèle

var _lots := {}                  # matière -> [v, n, uv, c, i]
var _M: Dictionary

func _construire(mats: Dictionary) -> void:
	_M = mats
	var w := largeur
	var L := longueur
	var hw := w * 0.5
	var hl := L * 0.5
	var bois := "bois_sombre"
	var bois2 := "rondin_sombre" if mats.has("rondin_sombre") else bois
	var p_mont := 0.10
	# --- montants : chevet haut (pommeaux taillés), pied bas
	for sx: float in [-1.0, 1.0]:
		var x := sx * (hw - p_mont * 0.5)
		_boite(bois2, Vector3(x, H_CHEVET * 0.5, hl - p_mont * 0.5), Vector3(p_mont, H_CHEVET, p_mont))
		_pommeau(bois2, Vector3(x, H_CHEVET, hl - p_mont * 0.5), 0.07)
		_boite(bois2, Vector3(x, H_PIED * 0.5, -hl + p_mont * 0.5), Vector3(p_mont, H_PIED, p_mont))
		_pommeau(bois2, Vector3(x, H_PIED, -hl + p_mont * 0.5), 0.065)
		# long pan (planche épaisse) et sa moulure basse
		_boite(bois, Vector3(sx * (hw - 0.035), H_CADRE - 0.09, 0), Vector3(0.07, 0.18, L - p_mont * 2.0))
		_boite(bois2, Vector3(sx * (hw - 0.03), H_CADRE + 0.012, 0), Vector3(0.09, 0.025, L - p_mont * 2.0))
	# --- chevet : deux traverses et planches verticales, la traverse haute déborde un peu (fronton)
	var zc := hl - 0.05
	_boite(bois2, Vector3(0, H_CADRE - 0.05, zc), Vector3(w - p_mont * 2.0, 0.1, 0.06))
	_boite(bois2, Vector3(0, H_CHEVET - 0.12, zc), Vector3(w - p_mont * 2.0 + 0.04, 0.12, 0.08))
	var nb := 3 if not double() else 5
	var lp := (w - p_mont * 2.0) / nb
	for k in nb:
		var x := -hw + p_mont + lp * (k + 0.5)
		_boite(bois if k % 2 == 0 else "bois_v", Vector3(x, (H_CADRE + H_CHEVET - 0.18) * 0.5, zc), Vector3(lp - 0.012, H_CHEVET - 0.18 - H_CADRE + 0.04, 0.04))
	# rune gravée au fronton (losange en relief, discret)
	_losange(bois, Vector3(0, H_CHEVET - 0.12, zc + 0.045), 0.06)
	# --- pied : une traverse et une planche basse
	var zp := -hl + 0.05
	_boite(bois2, Vector3(0, H_CADRE - 0.05, zp), Vector3(w - p_mont * 2.0, 0.1, 0.06))
	_boite(bois, Vector3(0, (H_CADRE + H_PIED - 0.06) * 0.5, zp), Vector3(w - p_mont * 2.0, H_PIED - 0.06 - H_CADRE + 0.04, 0.04))
	_boite(bois2, Vector3(0, H_PIED - 0.04, zp), Vector3(w - p_mont * 2.0 + 0.03, 0.06, 0.07))
	# --- sangles / planches de fond visibles entre la paillasse et le cadre
	_boite(bois, Vector3(0, H_CADRE - 0.13, 0), Vector3(w - 0.12, 0.03, L - 0.2))
	# --- paillasse de toile bourrée de paille (chanfreinée, un peu bombée)
	var hp := 0.15
	_paillasse("jute" if mats.has("jute") else "foin", Vector3(0, H_PAILLASSE - hp * 0.5, -0.02), Vector3(w - 0.13, hp, L - 0.2))
	# brins de paille qui dépassent de la couture (deux touffes)
	if mats.has("foin"):
		_boite("foin", Vector3(-hw + 0.1, H_PAILLASSE - 0.11, -hl + 0.22), Vector3(0.05, 0.03, 0.12))
		_boite("foin", Vector3(hw - 0.1, H_PAILLASSE - 0.12, 0.3), Vector3(0.04, 0.03, 0.1))
	# --- oreiller(s) de lin
	for i in places():
		_paillasse("lin" if mats.has("lin") else "jute", Vector3(x_place(i), H_PAILLASSE + 0.05, hl - 0.33), Vector3(0.5 if not double() else 0.56, 0.1, 0.3), 0.035)
	# --- fourrure drapée : couvre les deux tiers bas de la paillasse, retombe sur les côtés et au pied
	var pm := peau if mats.has(peau) else ("peau" if mats.has("peau") else "jute")
	_fourrure(pm, w - 0.13, L - 0.2, -0.02)
	# seconde peau, d'un autre ton, pliée en travers au pied
	var p2 := "peau_claire" if pm != "peau_claire" else "peau"
	_boite(p2 if mats.has(p2) else pm, Vector3(0, H_PAILLASSE + 0.045, -hl + 0.42), Vector3(w - 0.16, 0.035, 0.32))
	_finir()
	# collision : le cadre entier + le chevet
	_forme(Vector3(0, H_PAILLASSE * 0.5, 0), Vector3(w, H_PAILLASSE, L))
	_forme(Vector3(0, H_CHEVET * 0.5, hl - 0.05), Vector3(w, H_CHEVET, 0.1))

func _forme(c: Vector3, t: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = t
	cs.shape = b
	cs.position = c
	add_child(cs)

## Occlusion au pied (comme le bâti) : plus sombre près du sol.
static func _ao(y: float) -> float:
	return lerpf(0.55, 1.0, clampf(y / 0.55, 0.0, 1.0))

func _lot(mat: String) -> Array:
	if not _M.has(mat):
		mat = "bois"
	if not _lots.has(mat):
		_lots[mat] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedColorArray()]
	return _lots[mat]

## Triangle (sens horaire vu de devant = face avant en Godot). `centre` fini : orienté vers l'extérieur de ce point.
func _tri(mat: String, a: Vector3, b: Vector3, c: Vector3, teinte := 1.0, centre := Vector3(INF, 0, 0)) -> void:
	var nn := (c - a).cross(b - a)
	if nn.length_squared() < 1e-12:
		return
	nn = nn.normalized()
	if centre.x != INF and nn.dot((a + b + c) / 3.0 - centre) < 0.0:
		var t := b
		b = c
		c = t
		nn = -nn
	var lot := _lot(mat)
	var v: PackedVector3Array = lot[0]
	var n: PackedVector3Array = lot[1]
	var u: PackedVector2Array = lot[2]
	var col: PackedColorArray = lot[3]
	for p in [a, b, c]:
		v.append(p)
		n.append(nn)
		u.append(Vector2(p.x + p.z, p.y))
		var g := _ao(p.y) * teinte
		col.append(Color(g, g, g, 1.0))
	lot[0] = v
	lot[1] = n
	lot[2] = u
	lot[3] = col

## Quadrilatère a, b, c, d (ordre du contour, vu de l'extérieur : sens horaire en Godot = face avant).
func _quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, teinte := 1.0, centre := Vector3(INF, 0, 0)) -> void:
	_tri(mat, a, b, c, teinte, centre)
	_tri(mat, a, c, d, teinte, centre)

## Boîte alignée (6 faces).
func _boite(mat: String, c: Vector3, t: Vector3, teinte := 1.0) -> void:
	var h := t * 0.5
	var p := func(sx: float, sy: float, sz: float) -> Vector3: return c + Vector3(sx * h.x, sy * h.y, sz * h.z)
	_quad(mat, p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(-1, 1, 1), teinte, c)       # dessus
	_quad(mat, p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, -1, -1), p.call(-1, -1, -1), teinte, c)   # dessous
	_quad(mat, p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, -1, 1), p.call(-1, -1, 1), teinte, c)       # +Z
	_quad(mat, p.call(1, 1, -1), p.call(-1, 1, -1), p.call(-1, -1, -1), p.call(1, -1, -1), teinte, c)   # -Z
	_quad(mat, p.call(1, 1, 1), p.call(1, 1, -1), p.call(1, -1, -1), p.call(1, -1, 1), teinte, c)       # +X
	_quad(mat, p.call(-1, 1, -1), p.call(-1, 1, 1), p.call(-1, -1, 1), p.call(-1, -1, -1), teinte, c)   # -X

## Pommeau taillé : pyramide à 4 pans sur un collet.
func _pommeau(mat: String, base: Vector3, r: float) -> void:
	_boite(mat, base + Vector3(0, 0.02, 0), Vector3(r * 1.9, 0.04, r * 1.9))
	var s := base + Vector3(0, 0.04 + r * 1.6, 0)
	var b := base + Vector3(0, 0.04, 0)
	var q := [b + Vector3(-r, 0, -r), b + Vector3(r, 0, -r), b + Vector3(r, 0, r), b + Vector3(-r, 0, r)]
	for k in 4:
		_tri(mat, q[k], s, q[(k + 1) % 4], 1.0, b + Vector3(0, r * 0.4, 0))

## Losange en relief (rune du fronton), face vers +Z.
func _losange(mat: String, c: Vector3, r: float) -> void:
	var d := 0.012
	var a := [c + Vector3(0, r, 0), c + Vector3(r * 0.7, 0, 0), c + Vector3(0, -r, 0), c + Vector3(-r * 0.7, 0, 0)]
	var av := c + Vector3(0, 0, d)
	for k in 4:
		_tri(mat, a[k], a[(k + 1) % 4], av, 0.8, c - Vector3(0, 0, 0.05))

## Paillasse : boîte aux arêtes chanfreinées (bombée), 8 côtés par section.
func _paillasse(mat: String, c: Vector3, t: Vector3, ch := 0.05) -> void:
	var h := t * 0.5
	var e := minf(ch, minf(h.x, minf(h.y, h.z)) * 0.9)
	# section dans le plan XY (8 points), extrudée le long de Z, bouts fermés et chanfreinés
	var sec := [Vector2(-h.x + e, h.y), Vector2(h.x - e, h.y), Vector2(h.x, h.y - e), Vector2(h.x, -h.y + e * 0.5),
		Vector2(h.x - e * 0.5, -h.y), Vector2(-h.x + e * 0.5, -h.y), Vector2(-h.x, -h.y + e * 0.5), Vector2(-h.x, h.y - e)]
	var z0 := -h.z
	var z1 := h.z
	for k in 8:
		var s0: Vector2 = sec[k]
		var s1: Vector2 = sec[(k + 1) % 8]
		_quad(mat, c + Vector3(s0.x, s0.y, z1 - e), c + Vector3(s1.x, s1.y, z1 - e), c + Vector3(s1.x, s1.y, z0 + e), c + Vector3(s0.x, s0.y, z0 + e), 1.0, c)
	# bouts : un anneau rétréci (chanfrein) puis la face
	for zz in [[z1 - e, z1], [z0 + e, z0]]:
		var za: float = zz[0]
		var zb: float = zz[1]
		var k_in := 0.8
		var dehors := zb > za
		for k in 8:
			var s0: Vector2 = sec[k]
			var s1: Vector2 = sec[(k + 1) % 8]
			var a := c + Vector3(s0.x, s0.y, za)
			var b := c + Vector3(s1.x, s1.y, za)
			var b2 := c + Vector3(s1.x * k_in, s1.y * k_in, zb)
			var a2 := c + Vector3(s0.x * k_in, s0.y * k_in, zb)
			if dehors:
				_quad(mat, b, a, a2, b2, 0.95, c)
			else:
				_quad(mat, a, b, b2, a2, 0.95, c)
		var centre := c + Vector3(0, 0, zb)
		for k in 8:
			var s0: Vector2 = sec[k] * k_in
			var s1: Vector2 = sec[(k + 1) % 8] * k_in
			if dehors:
				_tri(mat, c + Vector3(s1.x, s1.y, zb), c + Vector3(s0.x, s0.y, zb), centre, 0.9, c)
			else:
				_tri(mat, c + Vector3(s0.x, s0.y, zb), c + Vector3(s1.x, s1.y, zb), centre, 0.9, c)

## Fourrure : nappe de 7 x 6 sommets posée sur la paillasse (du pied aux deux tiers), qui retombe sur les côtés et au pied, ondulée.
func _fourrure(mat: String, w: float, l: float, zc: float) -> void:
	var nx := 8
	var nz := 6
	var z_bas := zc - l * 0.5 - 0.02
	var z_haut := zc + l * 0.5 - 0.62
	var ep := 0.025
	var tombe := 0.2
	var pts := []
	for iz in nz + 1:
		var row := []
		var fz := float(iz) / nz
		for ix in nx + 1:
			var fx := float(ix) / nx
			# u : -1..1 ; les deux bords latéraux retombent (deux rangs par côté)
			var u := fx * 2.0 - 1.0
			var x: float
			var y: float
			var ondule := sin(fx * 9.1 + fz * 4.3) * 0.012 + sin(fz * 13.0 + fx * 2.0) * 0.008
			if absf(u) <= 0.72:
				x = u / 0.72 * (w * 0.5 + 0.01)
				y = H_PAILLASSE + ep + ondule + (1.0 - absf(u) / 0.72) * 0.015
			else:
				var k := (absf(u) - 0.72) / 0.28           # 0..1 le long de la retombée
				x = signf(u) * (w * 0.5 + 0.025 + k * 0.035)
				y = H_PAILLASSE + ep - k * tombe + ondule
			var z := lerpf(z_bas, z_haut, fz)
			if iz == 0:                                    # bord du pied : retombe aussi
				y -= 0.1
				z -= 0.02
			row.append(Vector3(x, y, z))
		pts.append(row)
	for iz in nz:
		for ix in nx:
			var a: Vector3 = pts[iz][ix]
			var b: Vector3 = pts[iz][ix + 1]
			var c: Vector3 = pts[iz + 1][ix + 1]
			var d: Vector3 = pts[iz + 1][ix]
			var t := 0.92 + 0.08 * float((ix * 7 + iz * 3) % 3) / 2.0
			_quad(mat, a, b, c, d, t)          # face du dessus (vue d'en haut : a b c d en sens horaire)
			_quad(mat, d, c, b, a, 0.7)        # envers (vu du dessous, retombées)
	# ourlet du haut : bourrelet replié
	for ix in nx:
		var a: Vector3 = pts[nz][ix]
		var b: Vector3 = pts[nz][ix + 1]
		var a2 := a + Vector3(0, 0.035, 0.05)
		var b2 := b + Vector3(0, 0.035, 0.05)
		_quad(mat, a, b, b2, a2, 1.05)
		_quad(mat, b, a, a2, b2, 0.8)

func _finir() -> void:
	for mat: String in _lots:
		var lot: Array = _lots[mat]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = lot[0]
		arrays[Mesh.ARRAY_NORMAL] = lot[1]
		arrays[Mesh.ARRAY_TEX_UV] = lot[2]
		arrays[Mesh.ARRAY_COLOR] = lot[3]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.name = "Lit_" + mat
		mi.mesh = m
		mi.material_override = _M[mat]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # comme le reste de l'intérieur
		add_child(mi)
	_lots.clear()
