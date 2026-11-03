class_name RayonNeant
extends Node3D
## RAYON DU NÉANT : l'ÉNORME rayon noir du sort à charge data/sorts/rayon_neant.tres (LanceurSorts._rayon_neant). Il traverse le
## cercle runique (CercleNeant) et file jusqu'au premier décor. Court (DUREE s), léger tremblement de caméra. Au point d'impact :
## tache d'ombre au sol, fumée noire qui monte, braises violettes, lueur violette brève.
## PERF (Iris Xe) : UN seul maillage (tube de ~2 000 triangles, shaders/rayon_neant_faisceau.gdshader : cœur noir, bord violet par
## l'angle de vue, brins de fumée en hélice), un carré pour la tache, deux MultiMesh de quelques bouffées (24 braises + 9 volutes), une lumière.
## Lisible sur fond sombre : cœur noir BORDÉ de violet très lumineux (le noir seul se perdrait). Pas de distorsion de l'image
## (la couche fine ne voit pas le décor) : des brins de fumée enroulés tiennent ce rôle.
## Le nœud est posé au point d'impact (top_level) ; le faisceau et la tache sont des enfants en coordonnées monde.

const SH_FAISCEAU := preload("res://shaders/rayon_neant_faisceau.gdshader")
const SH_TACHE := preload("res://shaders/rayon_neant_tache.gdshader")
const SH_BOUFFEE := preload("res://shaders/magie_bouffee.gdshader")
## Durée du rayon (s), de la tache (s) et des braises (s).
const DUREE := 0.85
const DUREE_TACHE := 5.0
const DUREE_BRAISES := 1.5
const NB_BRAISES := 24
const NB_VOLUTES := 9
const PAL_FUMEE := ["#07030c", "#2a0f45", "#6a2aa8", "#b070f0"]
const PAL_BRAISE := ["#07030c", "#9a3ae0", "#d08aff", "#f6e4ff"]

var debut := Vector3.ZERO
var fin := Vector3.ZERO
var normale := Vector3.UP
var touche := false
var largeur := 1.2
## Rayon (m) du faisceau à la sortie du cercle : un peu moins que le cercle (CercleNeant.RAYON x 0,9).
var rayon_depart := 0.27
var force := 1.0
var secoueur: Node        # le joueur (secousse de caméra), null pour un lanceur ennemi
var _t := 0.0
var _faisceau: MeshInstance3D
var _mat: ShaderMaterial
var _tache: MeshInstance3D
var _mat_tache: ShaderMaterial
var _braises: NoyauEcole.Bouffees
var _volutes: NoyauEcole.Bouffees
var _lueur: OmniLight3D
var _impact_fait := false
var _t_impact := 0.0
var _vel: Array = []

## Crée le rayon de `debut` (centre du cercle) à `fin` ; `touche` : `fin` est sur un décor (impact visible).
static func tirer(parent: Node, debut_: Vector3, fin_: Vector3, normale_: Vector3, touche_: bool, largeur_: float, force_: float, secoueur_: Node = null) -> RayonNeant:
	var r := RayonNeant.new()
	r.name = "RayonNeant"
	r.debut = debut_
	r.fin = fin_
	r.normale = normale_
	r.touche = touche_
	r.largeur = largeur_
	r.force = force_
	r.secoueur = secoueur_
	(parent if parent != null else (Engine.get_main_loop() as SceneTree).root).add_child(r)
	return r

## Pas de cercle de charge (tir direct, ou charge sous la mi-charge) : un cercle bref s'allume quand même.
func cercle_secours(avant: Vector3) -> void:
	var c := CercleNeant.new()
	c.name = "CercleNeant"
	c.rayon = CercleNeant.RAYON * (0.8 + 0.3 * force)
	add_child(c)
	c.tirer(DUREE, debut, avant)

func _ready() -> void:
	top_level = true
	global_position = fin
	_mat = ShaderMaterial.new()
	_mat.shader = SH_FAISCEAU
	_mat.set_shader_parameter("graine", randf() * 10.0)
	_faisceau = MeshInstance3D.new()
	_faisceau.mesh = _tube()
	_faisceau.material_override = _mat
	_faisceau.top_level = true
	_faisceau.layers = CoucheMagie.CALQUE
	_faisceau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_faisceau.extra_cull_margin = 50.0
	add_child(_faisceau)
	if touche:
		_construire_impact()
	_placer_faisceau()
	SonsMagie.rayon_neant(debut, force)

func _construire_impact() -> void:
	_mat_tache = ShaderMaterial.new()
	_mat_tache.shader = SH_TACHE
	_mat_tache.set_shader_parameter("graine", randf() * 10.0)
	var qd := QuadMesh.new()
	qd.size = Vector2.ONE
	_tache = MeshInstance3D.new()
	_tache.mesh = qd
	_tache.material_override = _mat_tache
	_tache.top_level = true
	_tache.layers = CoucheMagie.CALQUE
	_tache.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tache.extra_cull_margin = 2.0
	_tache.visible = false
	add_child(_tache)
	_braises = NoyauEcole.Bouffees.new(NB_BRAISES + 2, _mat_bouffee(1, PAL_BRAISE, 0.7, 1.35))
	_volutes = NoyauEcole.Bouffees.new(NB_VOLUTES, _mat_bouffee(0, PAL_FUMEE, 0.85, 1.0))
	for b: NoyauEcole.Bouffees in [_braises, _volutes]:
		b.mi.custom_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 8, 12))
		add_child(b.mi)
	# braises : jaillissent de l'impact (cône autour de la normale), retombent
	var n := normale.normalized()
	var u := n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.UP).normalized()
	var w := n.cross(u)
	for i in NB_BRAISES:
		var a := randf() * TAU
		var lat := (u * cos(a) + w * sin(a)) * randf_range(0.8, 3.2)
		_vel.append({"v": n * randf_range(2.0, 5.5) + lat, "s": randf_range(0.014, 0.034), "h": randf(), "d": randf_range(0.6, 1.0)})
	_lueur = OmniLight3D.new()
	_lueur.light_color = Color(0.7, 0.3, 1.0)
	_lueur.omni_range = 7.0
	_lueur.shadow_enabled = false
	_lueur.light_energy = 0.0
	_lueur.top_level = true
	add_child(_lueur)
	_lueur.global_position = fin + n * 0.8

static func _mat_bouffee(mode: int, pal: Array, dechire: float, eclat: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_BOUFFEE
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("dechire", dechire)
	m.set_shader_parameter("eclat", eclat)
	for k in 4:
		m.set_shader_parameter(["c_a", "c_b", "c_c", "c_d"][k], Color(pal[k]))
	m.render_priority = mode
	return m

## Volume englobant du rayon (tube unité de rayon 1, axe +Z de 0 à 1, fermé au départ) : anneaux resserrés près de la source ; UV.x le
## long, UV.y autour. Seul le shader dessine la forme du rayon.
static var _tube_mesh: ArrayMesh

static func _tube() -> ArrayMesh:
	if _tube_mesh != null:
		return _tube_mesh
	var pts := PackedVector3Array()
	var nor := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var nz := 28
	var nc := 36
	for i in nz + 1:
		var z := pow(float(i) / nz, 1.5)
		for j in nc + 1:
			var th := TAU * float(j) / nc
			pts.append(Vector3(cos(th), sin(th), z))
			nor.append(Vector3(cos(th), sin(th), 0.0))
			uvs.append(Vector2(z, float(j) / nc))
	for i in nz:
		for j in nc:
			var a := i * (nc + 1) + j
			var b := a + nc + 1
			idx.append_array([a, b, a + 1, a + 1, b, b + 1])   # sens horaire vu de l'extérieur (face avant de Godot)
	# couvercle de DÉPART (au cercle), face avant tournée vers l'arrière : un regard dans l'axe, depuis la main, entre par lui
	var c0 := pts.size()
	pts.append(Vector3(0, 0, 0))
	nor.append(Vector3(0, 0, -1))
	uvs.append(Vector2(0.0, 0.0))
	for j in nc:
		idx.append_array([c0, j, j + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	arr[Mesh.ARRAY_NORMAL] = nor
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	_tube_mesh = ArrayMesh.new()
	_tube_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_tube_mesh.custom_aabb = AABB(Vector3(-4, -4, 0), Vector3(8, 8, 1))
	return _tube_mesh

## Le tube : axe de `debut` à `fin`, longueur portée par la base (z), rayon (m) calculé dans le shader.
func _placer_faisceau() -> void:
	var axe := fin - debut
	var l := maxf(axe.length(), 0.1)
	var d := axe / l
	var x := Vector3.UP.cross(d)
	if x.length() < 0.05:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := d.cross(x).normalized()
	_faisceau.global_transform = Transform3D(Basis(x, y, d * l), debut)
	var rmax := largeur * (0.9 + 0.4 * clampf(force, 0.0, 1.0))
	_mat.set_shader_parameter("longueur", l)
	_mat.set_shader_parameter("rayon_max", rmax)
	_mat.set_shader_parameter("rayon_min", minf(rayon_depart, rmax))
	_mat.set_shader_parameter("ouverture", 7.0)

func _process(dt: float) -> void:
	_t += dt
	var g := GestionMagie.obtenir()
	var vie := clampf(_t / DUREE, 0.0, 1.0)
	_faisceau.visible = _t < DUREE
	if _faisceau.visible:
		_placer_faisceau()
		_mat.set_shader_parameter("vie", vie)
		if g != null and g.couche != null:
			g.couche.demander()
		# léger tremblement de caméra pendant le tir (secousse du joueur : amortie par l'option « secousses »)
		if secoueur != null and "secousse" in secoueur:
			secoueur.secousse = maxf(float(secoueur.secousse), 0.32 * (1.0 - smoothstep(0.2, 0.7, _t)) * clampf(0.6 + 0.5 * force, 0.0, 1.0))
	if touche:
		_maj_impact(dt, g)
	if _t >= maxf(DUREE, DUREE_TACHE if touche else 0.0):
		queue_free()

func _maj_impact(dt: float, g: GestionMagie) -> void:
	var tete := 0.1 * DUREE
	if not _impact_fait and _t >= tete:
		_impact_fait = true
		_t_impact = 0.0
		var n := normale.normalized()
		var d := largeur * 2.4 * (0.7 + 0.3 * force)
		var u := n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.UP).normalized()
		var w := n.cross(u)
		_tache.global_transform = Transform3D(Basis(u * d, w * d, n), fin + n * 0.03)
		_tache.visible = true
		EffetsMagie.impact("tenebres", fin, n, 0.8 + 0.6 * force)
	if not _impact_fait:
		return
	_t_impact += dt
	var ti := _t_impact
	if ti < DUREE_TACHE:
		_mat_tache.set_shader_parameter("vie", ti / DUREE_TACHE)
		if g != null and g.couche != null:
			g.couche.demander()
	else:
		_tache.visible = false
	var cam := get_viewport().get_camera_3d()
	var cb := cam.global_basis if cam != null else Basis.IDENTITY
	var n2 := normale.normalized()
	# braises (additives) : trajectoire balistique, scintillent
	if ti < DUREE_BRAISES:
		var lot: Array = []
		for i in NB_BRAISES:
			var e: Dictionary = _vel[i]
			var p := ti / (DUREE_BRAISES * float(e.d))
			if p >= 1.0:
				continue
			var pos: Vector3 = fin + n2 * 0.05 + (e.v as Vector3) * ti + Vector3(0, -5.5, 0) * 0.5 * ti * ti - global_position
			var s := float(e.s) * (1.0 - 0.5 * p) * (0.8 + 0.4 * force)
			var al := smoothstep(0.0, 0.05, p) * (1.0 - smoothstep(0.55, 1.0, p))
			lot.append([pos, cb.scaled(Vector3(s, s, 1.0)), Color(1, 1, 1, al), Color(float(e.h), float(i % 2), 3.0, 0.0)])
		# éclair de l'impact : cœur violet qui s'éteint vite
		var f := 1.0 - smoothstep(0.0, 0.4, ti)
		if f > 0.01:
			var rc := 0.5 * (1.0 + 0.4 * force) * (1.0 - 0.5 * f)
			lot.append([n2 * 0.1 + fin - global_position, cb.scaled(Vector3(rc, rc, 1.0)), Color(1, 1, 1, 0.55 * f), Color(0.0, 1.0, 2.0, 0.0)])
		_braises.ecrire(lot, cb, false)
	else:
		_braises.mm.visible_instance_count = 0
	# volutes de fumée noire qui montent et s'élargissent
	if ti < 2.2:
		var lot2: Array = []
		for i in NB_VOLUTES:
			var h := float(_vel[i % NB_BRAISES].h)
			var dec := float(i) / NB_VOLUTES * 0.35
			var p := clampf((ti - dec) / 1.8, 0.0, 1.0)
			if ti < dec:
				continue
			var a := h * TAU
			var pos := n2 * (0.2 + 1.9 * p) + (Vector3.UP * 0.4 * p) + Vector3(cos(a), 0.0, sin(a)) * (0.3 + 0.9 * p) * largeur
			pos += fin - global_position
			var s := lerpf(0.5, 1.5, p) * largeur * (0.8 + 0.4 * h)
			var al := smoothstep(0.0, 0.12, p) * (1.0 - smoothstep(0.5, 1.0, p)) * 0.75
			lot2.append([pos, cb.scaled(Vector3(s, s, 1.0)), Color(1, 1, 1, al), Color(h, 0.3 + 0.6 * p, 0.0, 0.0)])
		_volutes.ecrire(lot2, cb)
	else:
		_volutes.mm.visible_instance_count = 0
	# lueur violette brève
	_lueur.light_energy = 5.0 * (1.0 - smoothstep(0.0, 0.7, ti)) * force
