class_name NoyauEcole
extends Node3D
## NOYAU 3D de l'énergie tenue en main pour les écoles glace, électricité et ténèbres : pendant, pour chaque élément, de la
## flamme runique (feu : shaders/magie_aura.gdshader forme 2). Ne dessine que la FORME CENTRALE ; les runes, leurs orbites,
## les états (repos / début d'incantation / charge / retour) et la lueur sur les avant-bras viennent de RunesOrbite, dont ce
## nœud est l'enfant : il en relit l'état lissé (`_k_vit`, `_k_eclat`, `_conv`), donc rien n'est dupliqué.
##   glace       : grappe de cristaux hexagonaux qui tourne, éclats qui flottent et basculent autour, halo givré
##   électricité : boule d'arcs crépitants (magie_noyau_ecole ecole 2)
##   ténèbres    : sphère de volutes sombres (magie_noyau_ecole ecole 3)
## Rendu sur le calque de la couche fine (CoucheMagie.CALQUE) comme la flamme : même netteté, preset rétro compris.
## Réglages : `taille_k`, `lumi_k`, `vitesse_k` (reprennent ceux de RunesOrbite si on les passe).

const SH_NOYAU := preload("res://shaders/magie_noyau_ecole.gdshader")
const SH_CRISTAL := preload("res://shaders/magie_cristal.gdshader")
const ECOLES := ["glace", "electricite", "tenebres"]
## Palettes (cœur → bord) des carrés procéduraux, même ordre que GestionMagie.AURA_PAL.
const PAL := {
	"glace": ["#ffffff", "#e8f6ff", "#a8d8f8", "#5f9fe8", "#2f5fb8", "#1b2c5a"],
	"electricite": ["#ffffff", "#f0f2ff", "#b4c0ff", "#7a7af0", "#4a3ad0", "#2a1a6a"],
	"tenebres": ["#ffe8ff", "#f0d0ff", "#d08aff", "#9a3ae0", "#5a1a8a", "#06030c"],
}
const ID_ECOLE := {"glace": 1, "electricite": 2, "tenebres": 3}
## Rayon (m) du carré selon l'école : la glace tient dans un halo, la boule et la sphère remplissent le creux de la main.
const RAYON := {"glace": 0.13, "electricite": 0.15, "tenebres": 0.15}
## Cristaux de la grappe : [inclinaison (rad), azimut (rad), longueur, rayon, décalage du pied]
const GRAPPE := [
	[0.0, 0.0, 0.074, 0.0125, 0.0],
	[0.5, 0.4, 0.05, 0.0085, 0.004],
	[0.62, 2.4, 0.044, 0.008, 0.004],
	[0.55, 4.3, 0.056, 0.0095, 0.004],
	[0.85, 1.4, 0.032, 0.0065, 0.006],
	[0.9, 3.5, 0.036, 0.007, 0.006],
]
const NB_ECLATS := 7
const BAS := -0.045   # le pied de la grappe, sous le centre de l'énergie (m)

var ecole := "glace"
var runes: RunesOrbite
var taille_k := 1.0
var lumi_k := 1.0
var vitesse_k := 1.0
var _t := 0.0
var _naiss := 0.0
var _quad: MeshInstance3D
var _halo: MeshInstance3D
var _mat_cristal: ShaderMaterial
var _grappe: Node3D
var _pieds: Array = []     # [{n, incl, az, haut}]
var _eclats: Array = []    # [{n, a, vit, rayon, y, basc, spin, taille}]
var _graine := 0.0

static func possede(nom: String) -> bool:
	return ECOLES.has(nom) and not EffetsMagie.muet

func _ready() -> void:
	top_level = true
	_graine = randf() * 10.0
	if ecole == "glace":
		_construire_glace()
	else:
		_quad = _carre(ecole, 0.0)

## Carré procédural (magie_noyau_ecole) sur le calque de la couche fine.
func _carre(nom: String, avance: float) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = SH_NOYAU
	mat.set_shader_parameter("ecole", int(ID_ECOLE[nom]))
	var p: Array = PAL[nom]
	for k in 6:
		mat.set_shader_parameter("c%d" % k, Color(p[k]))
	mat.set_shader_parameter("eclat", {"glace": 1.1, "electricite": 1.6, "tenebres": 1.25}[nom])
	var qd := QuadMesh.new()
	qd.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = qd
	mi.material_override = mat
	mi.layers = CoucheMagie.CALQUE
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	mi.set_instance_shader_parameter("rayon", float(RAYON[nom]))
	mi.set_instance_shader_parameter("graine", _graine)
	mi.set_instance_shader_parameter("avance", avance)
	add_child(mi)
	return mi

# ---------------------------------------------------------------- glace

func _construire_glace() -> void:
	_mat_cristal = ShaderMaterial.new()
	_mat_cristal.shader = SH_CRISTAL
	_mat_cristal.set_shader_parameter("c_ombre", Color("#1a3a78"))
	_mat_cristal.set_shader_parameter("c_milieu", Color("#4a9ae8"))
	_mat_cristal.set_shader_parameter("c_clair", Color("#a8dcff"))
	_mat_cristal.set_shader_parameter("c_reflet", Color("#f4fbff"))
	_halo = _carre("glace", -0.06)
	_grappe = Node3D.new()
	add_child(_grappe)
	for k in GRAPPE.size():
		var g: Array = GRAPPE[k]
		var mi := _mesh_cristal(float(g[3]), float(g[2]))
		_grappe.add_child(mi)
		_pieds.append({"n": mi, "incl": float(g[0]), "az": float(g[1]), "haut": float(g[4]), "l": float(g[2])})
	for k in NB_ECLATS:
		var mi := _mesh_cristal(0.0045 + 0.003 * _h(k * 3 + 1), 0.016 + 0.014 * _h(k * 5 + 2))
		add_child(mi)
		_eclats.append({"n": mi, "a": TAU * _h(k * 7 + 3), "vit": (0.5 + 0.7 * _h(k * 11 + 4)) * (1.0 if k % 2 == 0 else -1.0),
			"rayon": 0.05 + 0.03 * _h(k * 13 + 5), "y": lerpf(-0.04, 0.075, _h(k * 17 + 6)), "basc": TAU * _h(k * 19 + 7),
			"spin": 1.0 + 1.6 * _h(k * 23 + 8), "incl": Vector3(_h(k * 29 + 1) * TAU, _h(k * 31 + 2) * TAU, 0.0)})

func _h(i: int) -> float:
	var x := (i * 73856093) ^ 19349663
	x = (x ^ (x >> 13)) * 1274126177
	return float((x ^ (x >> 16)) & 0xffff) / 65535.0

## Cristal hexagonal : prisme de 6 pans fermé par deux pointes, pied à l'origine, pointe vers +Y (facettes plates).
func _mesh_cristal(r: float, l: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pointe := l * 0.32
	var corps := l - pointe
	var bas: Array[Vector3] = []
	var haut: Array[Vector3] = []
	for s in 6:
		var a := TAU * s / 6.0
		bas.append(Vector3(cos(a) * r, corps * 0.18, sin(a) * r))
		haut.append(Vector3(cos(a) * r * 0.92, corps, sin(a) * r * 0.92))
	var pied := Vector3(0.0, -r * 0.35, 0.0)
	var tete := Vector3(0.0, l, 0.0)
	for s in 6:
		var s2 := (s + 1) % 6
		for v in [bas[s], haut[s], haut[s2], bas[s], haut[s2], bas[s2], haut[s], tete, haut[s2], bas[s2], pied, bas[s]]:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat_cristal
	mi.layers = CoucheMagie.CALQUE
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.0
	return mi

# ---------------------------------------------------------------- vie

func _process(dt: float) -> void:
	if runes == null or not is_instance_valid(runes):
		return
	_t += dt
	_naiss = minf(_naiss + dt * 3.0, 1.0)
	global_transform = Transform3D(Basis.IDENTITY, runes.global_position)
	var ch: float = runes.charge if runes.etat == 2 else 0.0
	var conv := sin(minf(runes._conv, 1.0) * PI * 0.5)
	var vit: float = runes._k_vit * vitesse_k
	var vif: float = runes._k_eclat * lumi_k
	var nais := sin(_naiss * PI * 0.5)
	# charge : x1,3 en hauteur et x1,15 en largeur au plus (comme la flamme) ; les départs resserrent le noyau
	var ech := 1.3 if ecole == "glace" else 1.0   # cristaux un cran plus grands que le halo
	var haut_k := (1.0 + 0.3 * ch) * (1.0 - 0.35 * conv) * taille_k * nais * ech
	var larg_k := (1.0 + 0.15 * ch) * (1.0 - 0.3 * conv) * taille_k * nais
	var larg_c := larg_k * ech
	var forc := clampf(0.78 + 0.35 * runes.intensite, 0.0, 1.3) * (0.97 + 0.04 * sin(_t * 9.0)) * minf(vif, 1.45)
	if ecole == "glace":
		_maj_glace(ch, vit, vif, haut_k, larg_c, larg_k, forc)
	elif _quad != null:
		_quad.set_instance_shader_parameter("rayon", float(RAYON[ecole]) * larg_k)
		_quad.set_instance_shader_parameter("force", forc)
		_quad.set_instance_shader_parameter("charge", ch)

func _maj_glace(ch: float, vit: float, vif: float, haut_k: float, larg_c: float, larg_k: float, forc: float) -> void:
	_mat_cristal.set_shader_parameter("eclat", clampf(0.9 + 0.35 * (vif - 1.0) + 0.1 * ch, 0.7, 1.5))
	_halo.set_instance_shader_parameter("rayon", float(RAYON["glace"]) * larg_k)
	_halo.set_instance_shader_parameter("force", forc)
	_halo.set_instance_shader_parameter("charge", ch)
	# la grappe tourne lentement sur son axe, balance un peu ; chaque cristal respire à son rythme
	_grappe.basis = Basis(Vector3.UP, _t * 0.45 * vit) * Basis(Vector3.RIGHT, 0.05 * sin(_t * 0.9)) * Basis.IDENTITY.scaled(Vector3(larg_c, haut_k, larg_c))
	_grappe.position = Vector3(0.0, BAS * haut_k + 0.004 * sin(_t * 1.3), 0.0)
	for k in _pieds.size():
		var p: Dictionary = _pieds[k]
		var b := Basis(Vector3.UP, float(p.az)) * Basis(Vector3.BACK, -float(p.incl) * (1.0 - 0.12 * ch) + 0.03 * sin(_t * 1.1 + k))
		var n: MeshInstance3D = p.n
		n.transform = Transform3D(b * Basis(Vector3.UP, _t * 0.3 * vit * (1.0 if k % 2 == 0 else -1.0)), Vector3(sin(float(p.az)) * 0.004, float(p.haut), cos(float(p.az)) * 0.004))
	# éclats flottants : orbites inclinées, remontent et redescendent, basculent ; se resserrent en charge
	for e: Dictionary in _eclats:
		var a: float = float(e.a) + _t * float(e.vit) * vit * 0.9
		var rr := float(e.rayon) * (1.0 - 0.22 * ch) * (1.0 - 0.5 * minf(runes._conv, 1.0)) * larg_c
		var y := float(e.y) * haut_k + 0.007 * sin(_t * 1.6 + float(e.basc))
		var n: MeshInstance3D = e.n
		var inc: Vector3 = e.incl
		var b := Basis.from_euler(Vector3(inc.x + _t * 0.7 * float(e.spin) * vit * 0.5, inc.y + _t * 0.5 * float(e.spin), 0.0))
		n.transform = Transform3D(b * Basis.IDENTITY.scaled(Vector3.ONE * (1.0 + 0.1 * ch)), Vector3(cos(a) * rr, y, sin(a) * rr))
