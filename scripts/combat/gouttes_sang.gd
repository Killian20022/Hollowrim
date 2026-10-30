class_name GouttesSang
extends MultiMeshInstance3D
## GOUTTES DE SANG QUI TOMBENT (sang v2, 2026-10-30) : gouttes lâchées par les entailles qui coulent (Plaies) et par la lame
## sanglante du joueur (SangLame). Un seul nœud « GouttesSang » par scène : MultiMesh de MAX gouttes (petits pavés étirés,
## 1 × 2-3 px à 480x270), simulées en GDScript (chute libre) ; à l'arrivée au sol, une goutte sur TRACE_UNE laisse une
## petite tache (Sang.trace « giclure »). Aucune allocation par goutte.
##   GouttesSang.lacher(noeud, position, couleur, vitesse, tache)

const MAX := 48
const GRAVITE := 9.8
const TAILLE := Vector3(0.016, 0.034, 0.016)
const TRACE_UNE := 3

static var _instance: GouttesSang
## Gouttes lâchées depuis le lancement (tests).
static var lachees := 0
static var cout_us := 0

var _pos := PackedVector3Array()
var _vit := PackedVector3Array()
var _sol := PackedFloat32Array()
var _vie := PackedFloat32Array()
var _col := PackedColorArray()
var _tache := PackedByteArray()
var _vivantes := 0
var _n := 0

static func obtenir(n: Node) -> GouttesSang:
	if is_instance_valid(_instance) and _instance.is_inside_tree():
		return _instance
	if n == null or not n.is_inside_tree():
		return null
	var arbre := n.get_tree()
	var g := GouttesSang.new()
	g.name = "GouttesSang"
	(arbre.current_scene if arbre.current_scene != null else arbre.root).add_child(g)
	_instance = g
	return g

static func lacher(n: Node, pos: Vector3, couleur: Color, vitesse := Vector3.ZERO, tache := false) -> void:
	if not SangLame.actif or Sang.niveau() == 0:
		return
	var g := obtenir(n)
	if g != null:
		g._lacher(pos, couleur, vitesse, tache)

## Gouttes en vol (tests).
static func en_vol() -> int:
	return _instance._vivantes if is_instance_valid(_instance) else 0

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var b := BoxMesh.new()
	b.size = TAILLE
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = Color(0.12, 0.01, 0.01)
	b.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = b
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	multimesh = mm
	custom_aabb = AABB(Vector3(-2000, -200, -2000), Vector3(4000, 400, 4000))
	for a in [_pos, _vit, _col]:
		a.resize(MAX)
	_sol.resize(MAX)
	_vie.resize(MAX)
	_tache.resize(MAX)
	set_process(false)

func _lacher(pos: Vector3, couleur: Color, vitesse: Vector3, tache: bool) -> void:
	var i := _vivantes
	if i >= MAX:
		i = _n % MAX   # plein : la plus ancienne place est reprise
	else:
		_vivantes += 1
	_n += 1
	lachees += 1
	_pos[i] = pos
	_vit[i] = vitesse
	_vie[i] = 2.0
	_col[i] = Color(minf(couleur.r * 1.5, 1.0), couleur.g * 1.2, couleur.b * 1.2)
	_tache[i] = 1 if (tache or _n % TRACE_UNE == 0) else 0
	var r := Sang.sol_sous(self, pos, 0.05, 3.0)
	_sol[i] = (r["position"] as Vector3).y if not r.is_empty() else pos.y - 3.0
	set_process(true)

func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	var i := 0
	while i < _vivantes:
		_vit[i] += Vector3(0, -GRAVITE * dt, 0)
		_pos[i] += _vit[i] * dt
		_vie[i] -= dt
		if _pos[i].y <= _sol[i] or _vie[i] <= 0.0:
			if _pos[i].y <= _sol[i] + 0.02 and _tache[i] == 1:
				var p := Vector3(_pos[i].x, _sol[i], _pos[i].z)
				Sang.trace(self, p, Vector3.UP, Vector3.ZERO, randf_range(0.07, 0.12), _col[i] / 1.5, "giclure")
			_retirer(i)
			continue
		i += 1
	var mm := multimesh
	for k in _vivantes:
		var v := _vit[k]
		var bas := Basis.IDENTITY
		if v.length_squared() > 0.25:
			var d := -v.normalized() if v.y < 0.0 else v.normalized()
			bas = Basis(Quaternion(Vector3.UP, d)) * Basis.from_scale(Vector3(1.0, clampf(v.length() * 0.35, 1.0, 2.2), 1.0))
		mm.set_instance_transform(k, Transform3D(bas, _pos[k]))
		mm.set_instance_color(k, _col[k])
	mm.visible_instance_count = _vivantes
	if _vivantes == 0:
		set_process(false)
	cout_us += Time.get_ticks_usec() - t0

func _retirer(i: int) -> void:
	var d := _vivantes - 1
	_pos[i] = _pos[d]
	_vit[i] = _vit[d]
	_vie[i] = _vie[d]
	_col[i] = _col[d]
	_sol[i] = _sol[d]
	_tache[i] = _tache[d]
	_vivantes = d
