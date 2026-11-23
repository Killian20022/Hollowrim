class_name GouttesSang
extends MultiMeshInstance3D
## GOUTTES DE SANG QUI TOMBENT (sang v2, 2026-10-30) : gouttes lâchées par les entailles qui coulent (Plaies) et par la lame
## sanglante du joueur (SangLame). Un seul nœud « GouttesSang » par scène : MultiMesh de MAX gouttes (petits pavés étirés,
## 1 × 2-3 px à 480x270), simulées en GDScript (chute libre) ; à l'arrivée au sol, une goutte sur TRACE_UNE laisse une
## petite tache (Sang.trace « giclure »). Aucune allocation par goutte.
##   GouttesSang.lacher(noeud, position, couleur, vitesse, tache)
## Sang v3 (2026-11-23) : GouttesSang.lacher_balistique(noeud, position, couleur, vitesse, taille) — goutte lancée par une giclée :
## elle vole (rayon le long de chaque pas), tache TOUJOURS là où elle touche (sol, mur, prop ; tache allongée dans le sens du vol,
## plus grosse si la goutte l'est) ; taille 0,5-2 (pavé plus ou moins gros). Plafond : MAX_V3 gouttes en vol (la plus ancienne cède).

const MAX := 48
const MAX_V3 := 80
const GRAVITE := 9.8
const TAILLE := Vector3(0.012, 0.026, 0.012)
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
## Sang v3 : goutte balistique (rayon à chaque pas) et sa taille.
var _bal := PackedByteArray()
var _taille := PackedFloat32Array()
var _ray := PackedVector3Array()   # dernier point vérifié par rayon (une image sur deux)
var _image := 0
var _exclus: Array[RID] = []
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

static func lacher_balistique(n: Node, pos: Vector3, couleur: Color, vitesse: Vector3, taille := 1.0) -> void:
	if not SangLame.actif or Sang.niveau() == 0:
		return
	var g := obtenir(n)
	if g != null:
		g._lacher(pos, couleur, vitesse, true, true, taille)

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
	m.emission = Color(0.06, 0.005, 0.005)
	b.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = b
	mm.instance_count = _max()
	mm.visible_instance_count = 0
	multimesh = mm
	custom_aabb = AABB(Vector3(-2000, -200, -2000), Vector3(4000, 400, 4000))
	var m_ := _max()
	_pos.resize(m_)
	_vit.resize(m_)
	_col.resize(m_)
	_sol.resize(m_)
	_vie.resize(m_)
	_tache.resize(m_)
	_bal.resize(m_)
	_taille.resize(m_)
	_ray.resize(m_)
	set_process(false)

static func _max() -> int:
	return MAX_V3 if SangV3.actif else MAX

func _lacher(pos: Vector3, couleur: Color, vitesse: Vector3, tache: bool, balistique := false, taille := 1.0) -> void:
	var i := _vivantes
	var m_ := _pos.size()
	if i >= m_:
		i = _n % m_   # plein : la plus ancienne place est reprise
	else:
		_vivantes += 1
	_n += 1
	lachees += 1
	_pos[i] = pos
	_vit[i] = vitesse
	_vie[i] = 2.0
	_col[i] = Color(minf(couleur.r * 1.3, 1.0), couleur.g * 1.1, couleur.b * 1.1)
	_tache[i] = 1 if (tache or _n % TRACE_UNE == 0) else 0
	_bal[i] = 1 if balistique else 0
	_taille[i] = taille
	_ray[i] = pos
	if balistique:
		_sol[i] = pos.y - 6.0   # le rayon de chaque pas trouve le point d'impact
		if _vivantes == 1 or _exclus.is_empty():
			_exclus = Sang._exclus(get_tree())
	else:
		var r := Sang.sol_sous(self, pos, 0.05, 3.0)
		_sol[i] = (r["position"] as Vector3).y if not r.is_empty() else pos.y - 3.0
	set_process(true)

func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	var i := 0
	var espace: PhysicsDirectSpaceState3D = null
	_image += 1
	while i < _vivantes:
		_vit[i] += Vector3(0, -GRAVITE * dt, 0)
		_pos[i] += _vit[i] * dt
		_vie[i] -= dt
		if _bal[i] == 1:
			# un rayon toutes les deux images (du dernier point vérifié à la position actuelle : aucun mur sauté)
			var r := {}
			if (i + _image) % 2 == 0 or _vie[i] <= 0.0:
				if espace == null:
					espace = get_world_3d().direct_space_state
				var q := PhysicsRayQueryParameters3D.create(_ray[i], _pos[i], 1, _exclus)
				r = espace.intersect_ray(q)
				_ray[i] = _pos[i]
			if not r.is_empty() or _vie[i] <= 0.0:
				if not r.is_empty() and Sang._surface(r, true) and (_taille[i] >= 1.15 or absf((r["normal"] as Vector3).y) < 0.5 or randf() < 0.5):
					var v := _vit[i]
					var nrm: Vector3 = r["normal"]
					var rasant := (v - nrm * v.dot(nrm)).length() > absf(v.dot(nrm)) * 1.1
					var sup: Node3D = r["collider"] if r["collider"] is RigidBody3D else null
					Sang.trace(self, r["position"], nrm, v, randf_range(0.07, 0.115) * _taille[i] * (1.3 if rasant else 1.0), _col[i] / 1.3, "giclure" if rasant else "goutte", 0.0, 0.0, sup)
				_retirer(i)
				continue
			i += 1
			continue
		if _pos[i].y <= _sol[i] or _vie[i] <= 0.0:
			if _pos[i].y <= _sol[i] + 0.02 and _tache[i] == 1:
				var p := Vector3(_pos[i].x, _sol[i], _pos[i].z)
				Sang.trace(self, p, Vector3.UP, Vector3.ZERO, randf_range(0.07, 0.12), _col[i] / 1.3, "giclure")
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
		if _taille[k] != 1.0:
			bas = bas * Basis.from_scale(Vector3.ONE * _taille[k])
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
	_bal[i] = _bal[d]
	_taille[i] = _taille[d]
	_ray[i] = _ray[d]
	_vivantes = d
