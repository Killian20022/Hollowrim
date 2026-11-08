class_name ArcModele
extends Node3D
## Modèle de l'arc du joueur (maillage procédural, matériaux du shader ps1) : arc long d'if dont les branches se courbent avec la
## tension, corde qui part en V vers la main de tir, flèche encochée. Repère : l'arc est debout (axe y, poignée à l'origine), la
## flèche part vers -z, l'archer est du côté +z. Utilisé en première personne (calé sur la caméra) et en troisième (suit la main
## gauche du corps) par ArcJoueur.
##   regler(tension, encoche) : tension 0..1 (quantifiée par paliers : gros pixels, pas de lissage), encoche = flèche posée.
##   pointe() : position monde de la pointe de la flèche (départ du tir) ; encoche_monde() : position monde de la main de tir.

const DEMI := 0.66            # demi-hauteur de l'arc (m)
const COURBURE_MIN := 0.07
const COURBURE_MAX := 0.17
const TIRAGE_MAX := 0.46      # recul de la corde à pleine tension (m)
const PALIERS := 10
const LONGUEUR_FLECHE := 0.78

var mi_arc: MeshInstance3D
var mi_corde: MeshInstance3D
var fleche: Node3D
var main_g: MeshInstance3D
var main_d: MeshInstance3D
var _palier := -1
var _encoche := false
var tension := 0.0

static var _mats := {}

static func _materiaux() -> Dictionary:
	if _mats.is_empty():
		_mats["bois"] = Palette.materiau(Palette.tex("arc_bois", Palette.PLANCHES, 4, 0.5), Vector2(1, 4), Color(1.9, 1.55, 1.2), true)
		_mats["fut"] = Palette.materiau(Palette.tex("fleche_fut", Palette.PLANCHES, 4, 0.3), Vector2(1, 4), Color(1.7, 1.45, 1.1), true)
		_mats["fer"] = Palette.materiau(Palette.tex("fleche_fer", Palette.ACIER, 4, 0.3), Vector2.ONE, Color(1.1, 1.15, 1.25), true)
		_mats["plume"] = Palette.materiau(Palette.tex("fleche_plume", Palette.OSSEMENT, 4, 0.3), Vector2.ONE, Color(1.1, 1.05, 0.95), true)
		_mats["cuir"] = Palette.materiau(Palette.tex("cuir", Palette.CUIR, 4, 0.5), Vector2(1, 2), Color(1.3, 1.2, 1.1), true)
		var c := Palette.materiau(Palette.tex("corde_arc", Palette.OSSEMENT, 4, 0.2), Vector2.ONE, Color(1.25, 1.2, 1.05), true)
		_mats["corde"] = c
	return _mats

func _init() -> void:
	var m := _materiaux()
	mi_arc = MeshInstance3D.new()
	mi_arc.name = "arc"
	mi_arc.material_override = m["bois"]
	add_child(mi_arc)
	mi_corde = MeshInstance3D.new()
	mi_corde.name = "corde"
	mi_corde.material_override = m["corde"]
	add_child(mi_corde)
	fleche = Node3D.new()
	fleche.name = "fleche"
	add_child(fleche)
	_boite(fleche, Vector3(0, 0, -LONGUEUR_FLECHE * 0.5), Vector3(0.012, 0.012, LONGUEUR_FLECHE), m["fut"])
	_boite(fleche, Vector3(0, 0, -LONGUEUR_FLECHE - 0.03), Vector3(0.03, 0.03, 0.09), m["fer"])
	_boite(fleche, Vector3(0, 0, -0.07), Vector3(0.05, 0.004, 0.13), m["plume"])
	_boite(fleche, Vector3(0, 0, -0.07), Vector3(0.004, 0.05, 0.13), m["plume"])
	fleche.visible = false
	regler(0.0, false, true)

## Gants de cuir (première personne : le corps n'est pas là) : poing sur la poignée, main de tir à l'encoche.
func avec_mains() -> void:
	var m := _materiaux()
	main_g = _boite(self, Vector3(0.0, 0.0, 0.03), Vector3(0.085, 0.12, 0.085), m["cuir"])
	main_d = _boite(self, Vector3(0.0, 0.0, 0.2), Vector3(0.07, 0.07, 0.1), m["cuir"])

static func _boite(parent: Node3D, pos: Vector3, taille: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

## Tension 0..1 : courbure des branches, recul de la corde, flèche encochée visible.
func regler(t: float, encoche: bool, forcer := false) -> void:
	tension = clampf(t, 0.0, 1.0)
	var p := roundi(tension * PALIERS)
	if p == _palier and encoche == _encoche and not forcer:
		return
	_palier = p
	_encoche = encoche
	var u := float(p) / PALIERS
	var c := lerpf(COURBURE_MIN, COURBURE_MAX, u)
	var tirage := u * TIRAGE_MAX
	mi_arc.mesh = _maille_arc(c)
	mi_corde.mesh = _maille_corde(c, tirage)
	fleche.visible = encoche
	fleche.position = Vector3(0.0, 0.0, c + tirage)
	if main_d != null:
		main_d.position = Vector3(0.0, 0.0, c + tirage + 0.045)
		main_d.visible = encoche or u > 0.0

func _pt(t: float, c: float) -> Vector3:
	var at := absf(t)
	return Vector3(0.0, t * DEMI, c * at * at - 0.04 * smoothstep(0.8, 1.0, at))

func _maille_arc(c: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	for i in n:
		var t0 := -1.0 + 2.0 * i / n
		var t1 := -1.0 + 2.0 * (i + 1) / n
		var l0 := lerpf(0.018, 0.008, smoothstep(0.1, 1.0, absf(t0)))
		var l1 := lerpf(0.018, 0.008, smoothstep(0.1, 1.0, absf(t1)))
		_prisme(st, _pt(t0, c), _pt(t1, c), l0, l1, 0.012, 0.012)
	st.generate_normals()
	return st.commit()

func _maille_corde(c: float, tirage: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var haut := _pt(1.0, c)
	var bas := _pt(-1.0, c)
	var noeud := Vector3(0.0, 0.0, c + tirage)
	_prisme(st, bas, noeud, 0.0035, 0.0035, 0.0035, 0.0035)
	_prisme(st, noeud, haut, 0.0035, 0.0035, 0.0035, 0.0035)
	st.generate_normals()
	return st.commit()

## Prisme à 4 pans entre a et b (demi-largeurs lx, demi-épaisseurs lz à chaque bout) ; matériau double face.
static func _prisme(st: SurfaceTool, a: Vector3, b: Vector3, lxa: float, lxb: float, lza: float, lzb: float) -> void:
	var ax := (b - a).normalized()
	var x := ax.cross(Vector3.FORWARD if absf(ax.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(ax).normalized()
	var ca: Array[Vector3] = [a + x * lxa + z * lza, a - x * lxa + z * lza, a - x * lxa - z * lza, a + x * lxa - z * lza]
	var cb: Array[Vector3] = [b + x * lxb + z * lzb, b - x * lxb + z * lzb, b - x * lxb - z * lzb, b + x * lxb - z * lzb]
	for k in 4:
		var k1 := (k + 1) % 4
		var uv := [Vector2(k * 0.25, 0), Vector2((k + 1) * 0.25, 0), Vector2((k + 1) * 0.25, 1), Vector2(k * 0.25, 1)]
		var q := [ca[k], ca[k1], cb[k1], cb[k]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[idx])
			st.add_vertex(q[idx])

func pointe() -> Vector3:
	return fleche.global_transform * Vector3(0.0, 0.0, -LONGUEUR_FLECHE - 0.08)

func encoche_monde() -> Vector3:
	return fleche.global_position
