class_name OrbeEsprit
extends Node3D
## ORBE DE L'ESPRIT tenu en main (télékinésie, répulsion, lévitation, attraction ; référence Jeux/references/orbe_esprit/
## reference_utilisateur.png) : une sphère de verre-énergie TRANSPARENTE aux reflets irisés, un cœur bleu-blanc qui tourbillonne,
## trois anneaux orbitaux fins inclinés comme autour d'une planète et de petits éclats de pierre en orbite. Les runes du
## Futhark qui gravitent sont celles de RunesOrbite (école "esprit" de son tableau ECOLES), dont ce nœud est l'enfant : il en
## relit l'état lissé (`_k_vit`, `_k_rayon`, `_k_eclat`, `charge`), donc l'effort (maintien, charge) accélère et resserre tout.
## ~0,28 m de bout en bout (rayon des anneaux 0,135 m). Shader : shaders/orbe_esprit.gdshader (calque de la couche fine).
## Variante par sort (`sort`) : teinte, sens de rotation, vitesse, petit comportement propre (voir VARIANTES).

const SH := preload("res://shaders/orbe_esprit.gdshader")
const RAYON_SPHERE := 0.056
const TAILLE_COEUR := 0.105
## teinte / iris : couleurs du verre ; sens : rotation (+1 / -1) ; vit : vitesse générale ; onde : les anneaux pulsent vers
## l'extérieur (répulsion) ; flotte : les éclats montent et descendent (lévitation) ; spirale : les éclats plongent vers le cœur (attraction).
const VARIANTES := {
	"telekinesie": {"teinte": Color("#73bfff"), "clair": Color("#ebfaff"), "iris": Color("#d99cff"), "sens": 1.0, "vit": 1.0, "graine": 0.0},
	"repulsion": {"teinte": Color("#9a8cff"), "clair": Color("#f2eeff"), "iris": Color("#ff8fd0"), "sens": -1.0, "vit": 1.35, "graine": 0.31, "onde": 1.0},
	"levitation": {"teinte": Color("#66ffe0"), "clair": Color("#eafff9"), "iris": Color("#8fd4ff"), "sens": 1.0, "vit": 0.7, "graine": 0.62, "flotte": 1.0},
	"attraction": {"teinte": Color("#8c70ff"), "clair": Color("#e8e4ff"), "iris": Color("#5fd8ff"), "sens": -1.0, "vit": 1.1, "graine": 0.83, "spirale": 1.0},
}
## Anneaux : rayon (m), inclinaison (euler, rad), vitesse de précession, largeur relative.
const ANNEAUX := [
	{"rayon": 0.135, "incl": Vector3(-1.05, 0.2, 0.18), "vit": 0.22, "w": 0.02},
	{"rayon": 0.108, "incl": Vector3(-0.6, -0.35, -0.7), "vit": -0.3, "w": 0.018},
	{"rayon": 0.16, "incl": Vector3(-1.3, 0.1, 0.5), "vit": 0.14, "w": 0.016},
]
const NB_ECLATS := 7

var runes: RunesOrbite
var sort := "telekinesie"
var cote := 1.0
var _v: Dictionary
var _t := 0.0
var _naiss := 0.0
var _sphere: MeshInstance3D
var _coeur: MeshInstance3D
var _mats: Array[ShaderMaterial] = []
var _anneaux: Array = []   # [{mi, base: Basis, defile}]
var _eclats: Array = []    # [{mi, base: Basis, r, phase, vit, spin: Vector3, taille, haut, bat}]

func _ready() -> void:
	top_level = true
	_v = VARIANTES.get(sort, VARIANTES["telekinesie"])
	if runes != null:
		cote = runes.cote
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 20
	sm.rings = 10
	_sphere = _mi(sm, _mat(0), 1.0)
	var qd := QuadMesh.new()
	qd.size = Vector2.ONE
	_coeur = _mi(qd, _mat(1), 1.0)
	for k in ANNEAUX.size():
		var a: Dictionary = ANNEAUX[k]
		var mat := _mat(2)
		var mi := _mi(_ruban(float(a.w)), mat, 1.0)
		mi.set_instance_shader_parameter("graine", float(k) * 0.37 + float(_v.graine))
		var ie: Vector3 = a.incl
		_anneaux.append({"mi": mi, "base": Basis.from_euler(Vector3(ie.x, ie.y * cote, ie.z * cote)), "defile": float(k) * 0.3})
	var mats_eclat := _mat(3)
	for k in NB_ECLATS:
		var h := func(i: int) -> float: return _h(i * 7 + k * 31 + (0 if cote > 0.0 else 5))
		var mi := _mi(_eclat_mesh(k), mats_eclat, 1.0)
		mi.set_instance_shader_parameter("graine", float(h.call(4)))
		var incl := Vector3(lerpf(-1.2, 1.2, h.call(1)), lerpf(-0.9, 0.9, h.call(2)), lerpf(-1.5, 1.5, h.call(3)))
		_eclats.append({"mi": mi, "base": Basis.from_euler(incl), "r": lerpf(0.07, 0.165, h.call(5)), "phase": TAU * float(h.call(6)),
			"vit": lerpf(0.35, 0.8, h.call(7)) * (1.0 if k % 3 != 2 else -0.7), "taille": lerpf(0.012, 0.024, h.call(8)),
			"spin": Vector3(h.call(9) - 0.5, h.call(10) - 0.5, h.call(11) - 0.5).normalized() * lerpf(0.8, 2.2, h.call(12)),
			"haut": 0.02 * (float(h.call(13)) - 0.5), "bat": TAU * float(h.call(14))})
	for m in _mats:
		m.set_shader_parameter("teinte", _v.teinte)
		m.set_shader_parameter("clair", _v.clair)
		m.set_shader_parameter("iris", _v.iris)
		m.set_shader_parameter("sens", float(_v.sens) * cote)
	_sphere.set_instance_shader_parameter("graine", float(_v.graine))
	_coeur.set_instance_shader_parameter("graine", float(_v.graine))
	_suivre()

func _mat(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH
	m.set_shader_parameter("mode", mode)
	m.render_priority = mode
	_mats.append(m)
	return m

func _mi(mesh: Mesh, mat: ShaderMaterial, marge: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = CoucheMagie.CALQUE
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = marge
	add_child(mi)
	return mi

func _h(i: int) -> float:
	var x := (i * 73856093) ^ 19349663
	x = (x ^ (x >> 13)) * 1274126177
	return float((x ^ (x >> 16)) & 0xffff) / 65535.0

## Ruban circulaire de rayon 1 dans le plan XY (UV.x = fraction du tour, UV.y = travers).
func _ruban(largeur: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 72
	var w := largeur * 0.5
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var d0 := Vector3(cos(a0), sin(a0), 0.0)
		var d1 := Vector3(cos(a1), sin(a1), 0.0)
		var p := [d0 * (1.0 - w), d1 * (1.0 - w), d1 * (1.0 + w), d0 * (1.0 + w)]
		var uv := [Vector2(float(i) / n, 0.0), Vector2(float(i + 1) / n, 0.0), Vector2(float(i + 1) / n, 1.0), Vector2(float(i) / n, 1.0)]
		for t in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[t])
			st.add_vertex(p[t])
	return st.commit()

## Éclat de pierre : octaèdre irrégulier (8 faces, normales franches), un peu étiré et déformé selon `k`.
func _eclat_mesh(k: int) -> ArrayMesh:
	var s := Vector3(lerpf(0.7, 1.3, _h(k * 3 + 1)), lerpf(0.45, 0.9, _h(k * 3 + 2)), lerpf(0.6, 1.1, _h(k * 3 + 3)))
	var dirs := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var pts: Array[Vector3] = []
	for i in 6:
		var d: Vector3 = dirs[i]
		var j := Vector3(_h(k * 17 + i * 5 + 1), _h(k * 17 + i * 5 + 2), _h(k * 17 + i * 5 + 3)) - Vector3(0.5, 0.5, 0.5)
		pts.append((d * lerpf(0.7, 1.15, _h(k * 11 + i)) + j * 0.35) * s * 0.5)
	var faces := [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		for i in 3:
			st.add_vertex(pts[f[i]])
	st.generate_normals()
	return st.commit()

func _suivre() -> void:
	if runes != null and is_instance_valid(runes):
		global_transform = Transform3D(Basis.IDENTITY, runes.global_position)

func _process(dt: float) -> void:
	if runes == null or not is_instance_valid(runes):
		return
	_t += dt
	_naiss = minf(_naiss + dt * 2.5, 1.0)
	_suivre()
	var nais := sin(_naiss * PI * 0.5)
	var ch: float = runes.charge if runes.etat == 2 else 0.0
	var conv := sin(minf(runes._conv, 1.0) * PI * 0.5)
	var vit_etat: float = runes._k_vit * runes.vitesse_k * float(_v.vit)   # effort : jusqu'à ×2,4 en maintien, davantage en charge
	var serre: float = runes._k_rayon * (1.0 - 0.45 * conv) * runes.echelle   # effort : les orbites se resserrent
	var vif: float = clampf(runes._k_eclat * runes.lumi_k, 0.0, 1.8) * clampf(0.7 + 0.5 * runes.intensite, 0.0, 1.4)
	var gr := (1.0 + 0.25 * ch) * runes.taille_k * nais
	var sens := float(_v.sens) * cote
	for m in _mats:
		m.set_shader_parameter("eclat", vif)
		m.set_shader_parameter("vitesse", vit_etat)
	# sphère et cœur : le cœur bat doucement et gonfle un peu à l'effort
	var pouls := 1.0 + 0.05 * sin(_t * 3.1 * vit_etat) + 0.1 * (vit_etat - 1.0) * 0.3
	_sphere.transform = Transform3D(Basis.from_euler(Vector3(0.2, _t * 0.3 * sens, 0.1)).scaled(Vector3.ONE * (RAYON_SPHERE * 2.0 * gr * pouls)), Vector3.ZERO)
	_coeur.global_basis = _basis_camera().scaled(Vector3.ONE * (TAILLE_COEUR * gr * (0.95 + 0.1 * pouls)))
	# anneaux
	for i in _anneaux.size():
		var an: Dictionary = _anneaux[i]
		var def: float = float(an.defile) + dt * 0.16 * sens * vit_etat * (1.0 + 0.3 * i)
		an.defile = def
		var ar: Dictionary = ANNEAUX[i]
		var r: float = float(ar.rayon) * serre * gr
		if float(_v.get("onde", 0.0)) > 0.0:
			r *= 1.0 + 0.12 * maxf(sin(_t * 2.6 * vit_etat - float(i) * 1.1), 0.0)   # répulsion : l'onde part vers l'extérieur
		var mi: MeshInstance3D = an.mi
		var bs: Basis = (an.base as Basis) * Basis(Vector3.BACK, _t * float(ar.vit) * vit_etat * sens)
		mi.transform = Transform3D(bs.scaled(Vector3.ONE * r), Vector3.ZERO)
		mi.set_instance_shader_parameter("defile", def)
	# éclats de pierre
	for e in _eclats:
		var a: float = float(e.phase) + _t * float(e.vit) * vit_etat * sens
		var rr: float = float(e.r) * serre * gr
		var haut: float = float(e.haut)
		if float(_v.get("spirale", 0.0)) > 0.0:
			rr *= 0.72 + 0.28 * (0.5 + 0.5 * sin(_t * 0.9 * vit_etat + float(e.bat)))   # attraction : ils plongent vers le cœur puis repartent
		if float(_v.get("flotte", 0.0)) > 0.0:
			haut += 0.022 * sin(_t * 1.4 + float(e.bat))   # lévitation : ils flottent
		var p: Vector3 = (e.base as Basis) * Vector3(cos(a) * rr, 0.0, sin(a) * rr) + Vector3(0.0, haut, 0.0)
		var rot := Basis(Vector3(e.spin).normalized(), _t * Vector3(e.spin).length() * vit_etat)
		var mi: MeshInstance3D = e.mi
		mi.transform = Transform3D(rot.scaled(Vector3.ONE * float(e.taille) * gr * (0.85 + 0.15 * nais) * 1.7), p)

func _basis_camera() -> Basis:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_basis if cam != null else Basis.IDENTITY
