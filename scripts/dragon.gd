extends CharacterBody3D
## Dragon de givre : boss volant 100 % procédural (aucun modèle externe), rendu PS1.
## Il tournoie haut, pique en soufflant du givre, se pose près du joueur (vulnérable à l'épée),
## mord, balaie de la queue, souffle, puis redécolle. Mort : il s'effondre et laisse un squelette.
## Le nœud est à ras du sol, au centre du corps (global_position + (0,1,0) est dans le flanc :
## l'épée du joueur le touche déjà). Avant add_child : joueur, hauteur_sol, centre, hud.

signal vaincu

enum { TOURNOIE, PIQUE, ATTERRIT, AU_SOL, DECOLLE, MORT }
enum { RIEN, MORD, QUEUE, SOUFFLE }
const NOMS_ETATS := ["TOURNOIE", "PIQUE", "ATTERRIT", "AU_SOL", "DECOLLE", "MORT"]

const ECAILLES := ["#10161f", "#1b2736", "#2b3d52", "#4a6379"]
const MEMBRANE := ["#26201c", "#382f29", "#4e4338", "#685a4b"]
const BUTIN := preload("res://scripts/butin.gd")

const RAYON_VOL := 60.0
const DETECTION := 70.0
const COTES := 6
const N_COU := 7
const N_QUEUE := 9
const LONG_COU := 0.5
const LONG_QUEUE := 0.62
const PROFIL_SOL := [1.05, 0.95, 0.75, 0.5, 0.25, 0.0, -0.15]
const PROFIL_VOL := [0.3, 0.25, 0.2, 0.1, 0.05, 0.0, 0.0]
const PROFIL_MORT := [-0.05, -0.1, -0.12, -0.1, -0.08, -0.05, 0.0]
const EPAULE := Vector3(0.7, 2.9, 1.0)

# --- propriétés posées par le monde avant add_child ---
var joueur: CharacterBody3D
var hauteur_sol: Callable
var centre := Vector3.ZERO
var hud: Control

# --- interface attendue par le reste du jeu ---
var vie_max := 600.0
var vie := 600.0
var nom_affiche := "Dragon de givre"
var ident := ""

var etat := TOURNOIE
var _t := 0.0  # temps passé dans l'état courant
var _alt := 42.0  # altitude au-dessus du terrain
var _vitesse := 15.0
var _sens := 1.0
var _passes := 2
var _fait := 0
var _phase := 0  # 0 attaque, 1 sortie (pendant PIQUE)
var _en_passe := false  # la passe de souffle a commencé (il a le joueur en face)
var _t_phase := 0.0
var _atterrissage := Vector3.ZERO
var _vie_debut_sol := 600.0
var _act := RIEN
var _t_act := 0.0
var _recharge := 1.0
var _marche := false
var _coup_fait := false
var _cri_t := 6.0
var _souffle := false
var _t_tic := 0.0
var _portee_souffle := 30.0
var _demi_cone := 14.0
var _degats_souffle := 5.0
var _mort_t := 0.0
var _chute := 0.0
var _impact_fait := false
var _squelette_fait := false
var _poudre_t := 0.0
var _sursaut := 0.0

# --- animation ---
var _tw := 0.0
var _vol_k := 1.0
var _ouv := 1.0
var _amp := 0.35
var _freq := 0.8
var _phase_aile := 0.0
var _bouche := 0.0
var _bouche_t := 0.0
var _cible_yaw := 0.0
var _cible_el := 0.0
var _extra := 0.0
var _extra_cible := 0.0
var _balai := 0.0
var _balai_cible := 0.0
var _prof_tete := 0.0
var _pitch := 0.0
var _bank := 0.0
var _alt_avant := 42.0

var modele: Node3D
var tete: Node3D
var _machoire: Node3D
var _particules: GPUParticles3D
var _ombre: MeshInstance3D
var _mailles: Array[MeshInstance3D] = []
var _membranes: Array[MeshInstance3D] = []
var _cou: Array[MeshInstance3D] = []
var _queue: Array[MeshInstance3D] = []
var _cou_yaw := PackedFloat32Array()
var _cou_el := PackedFloat32Array()
var _queue_pts: Array[Vector3] = []
var _ailes: Array[Node3D] = []
var _os_aile: Array = []  # par aile : 5 MeshInstance3D
var _mb_aile: Array[MeshInstance3D] = []
var _pattes: Array = []  # par patte : {hanche, cuisse, tibia, pied, avant, cote}
var _mat_ec: ShaderMaterial
var _mat_os: ShaderMaterial
var _mat_mb: ShaderMaterial
var _mat_oeil: StandardMaterial3D
var _mesh_os: ArrayMesh

# ---------------------------------------------------------------- construction

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, indice: Vector3) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 0.000001:
		return
	if n.dot(indice) < 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	n = n.normalized()
	for p: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(p.x + p.z, p.y + p.z * 0.6) * 0.5)
		st.add_vertex(p)

## Tronc de pyramide hexagonal le long de +Z (de 0 à `long`), rayons (w, h) aux deux bouts.
static func _tronc(long: float, w0: float, h0: float, w1: float, h1: float, bouchons := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a0: Array[Vector3] = []
	var a1: Array[Vector3] = []
	for i in COTES:
		var ang := TAU * i / COTES
		a0.append(Vector3(cos(ang) * w0, sin(ang) * h0, 0.0))
		a1.append(Vector3(cos(ang) * w1, sin(ang) * h1, long))
	for i in COTES:
		var j := (i + 1) % COTES
		var c := (a0[i] + a0[j] + a1[i] + a1[j]) * 0.25
		var ind := Vector3(c.x, c.y, 0.0)
		_tri(st, a0[i], a0[j], a1[j], ind)
		_tri(st, a0[i], a1[j], a1[i], ind)
		if bouchons:
			_tri(st, Vector3(0, 0, long), a1[i], a1[j], Vector3.BACK)
			_tri(st, Vector3.ZERO, a0[i], a0[j], Vector3.FORWARD)
	return st.commit()

func _mi(parent: Node, mesh: Mesh, mat: Material, suivre := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	parent.add_child(m)
	if suivre:
		_mailles.append(m)
	return m

func _pointe(parent: Node, pos: Vector3, dir: Vector3, long: float, ep: float, mat: Material) -> void:
	var m := _mi(parent, _tronc(long, ep, ep, 0.02, 0.02), mat)
	m.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP, true), pos)

func _ready() -> void:
	add_to_group("ennemis")
	vie = vie_max
	_vie_debut_sol = vie
	collision_layer = 0
	collision_mask = 0
	_mat_ec = Palette.materiau(Palette.tex("dragon_ecailles", ECAILLES, 4, 0.5), Vector2.ONE, Color(0.9, 1.0, 1.15))
	_mat_os = Palette.materiau(Palette.tex("dragon_corne", Palette.OSSEMENT, 4, 0.4), Vector2.ONE, Color(0.75, 0.85, 1.05))
	_mat_mb = Palette.materiau(Palette.tex("dragon_membrane", MEMBRANE, 4, 0.45), Vector2.ONE, Color(0.95, 1.0, 1.1))
	_mat_oeil = Palette.lueur(Color(0.5, 1.7, 2.8))
	_mesh_os = _tronc(1.0, 1.0, 1.0, 0.65, 0.65)

	modele = Node3D.new()
	add_child(modele)
	_construire_corps()
	_construire_cou_queue()
	_construire_tete()
	_construire_pattes()
	_construire_ailes()

	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(2.2, 3.2, 4.4)
	forme.shape = boite
	forme.position.y = 1.7
	add_child(forme)

	_ombre = MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = 1.0
	disque.bottom_radius = 1.0
	disque.height = 0.02
	disque.radial_segments = 10
	disque.rings = 1
	_ombre.mesh = disque
	var mo := StandardMaterial3D.new()
	mo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mo.albedo_color = Color(0, 0, 0, 0.4)
	mo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ombre.material_override = mo
	_ombre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ombre.top_level = true
	add_child(_ombre)

	_sens = 1.0 if randf() < 0.5 else -1.0
	if global_position.length() < 0.01:
		global_position = centre + Vector3(RAYON_VOL, 0, 0)
	_alt = 42.0
	_alt_avant = _alt
	global_position.y = _sol(global_position) + _alt
	var rel := Vector2(global_position.x - centre.x, global_position.z - centre.z)
	var tang := Vector2(-rel.y, rel.x).normalized() * _sens
	rotation.y = atan2(tang.x, tang.y)
	_cri_t = randf_range(6.0, 12.0)

func _construire_corps() -> void:
	var torse := _mi(modele, _tronc(4.2, 0.95, 1.0, 1.0, 1.05, true), _mat_ec)
	torse.position = Vector3(0, 2.3, -2.2)
	# crête dorsale
	for i in 5:
		_pointe(modele, Vector3(0, 3.25, -1.7 + i * 0.85), Vector3(0, 1, -0.5), 0.55, 0.16, _mat_os)

func _construire_cou_queue() -> void:
	for i in N_COU:
		var k := float(i) / N_COU
		var w0 := lerpf(0.55, 0.3, k)
		var w1 := lerpf(0.55, 0.3, k + 1.0 / N_COU)
		_cou.append(_mi(modele, _tronc(1.0, w0, w0 * 0.95, w1, w1 * 0.95), _mat_ec))
		_cou_yaw.append(0.0)
		_cou_el.append(PROFIL_SOL[i])
		if i % 2 == 0:
			_pointe(_cou[i], Vector3(0, w0 * 0.9, 0.2), Vector3(0, 1, -0.6), 0.3, 0.1, _mat_os)
	for i in N_QUEUE:
		var k := float(i) / N_QUEUE
		var w0 := lerpf(0.55, 0.04, k)
		var w1 := lerpf(0.55, 0.04, (float(i) + 1.0) / N_QUEUE)
		_queue.append(_mi(modele, _tronc(1.0, w0, w0 * 0.8, w1, w1 * 0.8), _mat_ec))
		if i % 2 == 1 and i < N_QUEUE - 1:
			_pointe(_queue[i], Vector3(0, w0 * 0.8, 0.2), Vector3(0, 1, -0.5), 0.3, 0.09, _mat_os)
	for i in N_QUEUE + 1:
		_queue_pts.append(Vector3.ZERO)

func _construire_tete() -> void:
	tete = Node3D.new()
	modele.add_child(tete)
	var crane := _mi(tete, _tronc(1.1, 0.42, 0.36, 0.22, 0.17, true), _mat_ec)
	crane.position = Vector3(0, 0, 0.05)
	# cornes : deux grandes vers l'arrière, deux petites aux joues
	for s in [-1.0, 1.0]:
		_pointe(tete, Vector3(0.28 * s, 0.3, 0.1), Vector3(0.35 * s, 0.55, -1.0), 1.2, 0.1, _mat_os)
		_pointe(tete, Vector3(0.4 * s, 0.0, 0.2), Vector3(0.9 * s, 0.1, -0.6), 0.6, 0.08, _mat_os)
		var oeil := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.1, 0.09, 0.2)
		oeil.mesh = bm
		oeil.material_override = _mat_oeil
		oeil.position = Vector3(0.33 * s, 0.14, 0.6)
		tete.add_child(oeil)
		_pointe(tete, Vector3(0.15 * s, -0.12, 1.1), Vector3(0, -1, 0.1), 0.28, 0.05, _mat_os)
	_machoire = Node3D.new()
	_machoire.position = Vector3(0, -0.2, 0.1)
	tete.add_child(_machoire)
	var jaw := _mi(_machoire, _tronc(1.05, 0.34, 0.1, 0.17, 0.06, true), _mat_ec)
	jaw.position = Vector3(0, 0, 0.0)
	for s in [-1.0, 1.0]:
		_pointe(_machoire, Vector3(0.12 * s, 0.05, 0.98), Vector3(0, 1, 0.1), 0.25, 0.04, _mat_os)
	# souffle de givre
	_particules = GPUParticles3D.new()
	_particules.amount = 90
	_particules.lifetime = 1.3
	_particules.local_coords = false
	_particules.emitting = false
	_particules.position = Vector3(0, -0.1, 1.1)
	_particules.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 14.0
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(0, -1.0, 0)
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	pm.scale_min = 0.8
	pm.scale_max = 2.2
	var deg := Gradient.new()
	deg.set_color(0, Color(1.4, 1.8, 2.2, 1.0))
	deg.set_color(1, Color(0.05, 0.15, 0.3, 0.0))
	var rampe := GradientTexture1D.new()
	rampe.gradient = deg
	pm.color_ramp = rampe
	_particules.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.vertex_color_use_as_albedo = true
	mq.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mq.disable_receive_shadows = true
	quad.material = mq
	_particules.draw_pass_1 = quad
	_particules.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tete.add_child(_particules)

func _construire_pattes() -> void:
	var m_cuisse := _tronc(1.0, 0.42, 0.42, 0.28, 0.28)
	var m_tibia := _tronc(1.0, 0.28, 0.28, 0.2, 0.2)
	var m_pied := _tronc(1.0, 0.25, 0.12, 0.1, 0.06, true)
	for avant in [true, false]:
		for cote in [-1.0, 1.0]:
			var d := {
				"avant": avant,
				"cote": cote,
				"hanche": Vector3(0.8 * cote, 1.9, 1.3) if avant else Vector3(0.9 * cote, 1.9, -1.6),
				"cuisse": _mi(modele, m_cuisse, _mat_ec),
				"tibia": _mi(modele, m_tibia, _mat_ec),
				"pied": _mi(modele, m_pied, _mat_os),
			}
			_pattes.append(d)

func _construire_ailes() -> void:
	for cote in [-1.0, 1.0]:
		var aile := Node3D.new()
		aile.position = Vector3(EPAULE.x * cote, EPAULE.y, EPAULE.z)
		modele.add_child(aile)
		_ailes.append(aile)
		var os: Array[MeshInstance3D] = []
		for i in 5:
			os.append(_mi(aile, _mesh_os, _mat_os))
		_os_aile.append(os)
		var mb := MeshInstance3D.new()
		mb.material_override = _mat_mb
		aile.add_child(mb)
		_mailles.append(mb)
		_membranes.append(mb)
		_mb_aile.append(mb)

# ---------------------------------------------------------------- interface publique

func vivant() -> bool:
	return etat != MORT

## Vrai sauf quand il tournoie au loin.
func en_combat() -> bool:
	if etat == TOURNOIE:
		return false
	return etat != MORT

## Point du corps le plus proche du joueur (à utiliser pour tester les coups d'épée).
func point_impact() -> Vector3:
	var a := to_global(Vector3(0, 1.6, -1.8))
	var b := to_global(Vector3(0, 1.6, 1.8))
	if joueur == null:
		return global_position + Vector3.UP
	var p := joueur.global_position + Vector3(0, 1.4, 0)
	var ab := b - a
	var k := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return a + ab * k

func nom_etat() -> String:
	return NOMS_ETATS[etat]

func altitude() -> float:
	return _alt

## Appelé par l'épée du joueur. Renvoie "touche", "tue" (ou "bloque" s'il est hors de portée).
func recevoir_coup(quantite: float, origine_coup: Vector3, puissant := false, _info: Dictionary = {}) -> String:   # _info : contrat épée FPS (docs/DEGATS.md), non utilisé par le dragon
	if etat == MORT:
		return ""
	if _alt > 3.5:
		return "bloque"
	vie -= quantite
	_eclair()
	_sursaut = 1.0
	var impact := point_impact()
	Effets.eclats(self, impact, Color(0.7, 1.1, 1.8), 18 if puissant else 10, 3.5, true)
	Effets.eclats(self, impact, Color(0.85, 0.92, 1.0), 8, 2.5)
	_son(["knifeSlice", "knifeSlice2", "chop", "impactPlate_medium_000"], impact, 2.0 if puissant else 0.0, 0.8)
	if vie <= 0.0:
		_mourir()
		return "tue"
	return "touche"

# ---------------------------------------------------------------- outils

func _sol(p: Vector3) -> float:
	if hauteur_sol.is_valid():
		return float(hauteur_sol.call(p.x, p.z))
	return centre.y

func _plat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func _avant() -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y))

func _pos_bouche() -> Vector3:
	return tete.global_transform * Vector3(0, -0.08, 1.15)

func _son(noms: Array, pos: Vector3, volume := 0.0, hauteur := 1.0) -> void:
	var s := Sons.flux(noms.pick_random())
	if s == null or not is_inside_tree():
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = s
	a.volume_db = volume
	a.unit_size = 25.0
	a.max_distance = 250.0
	a.pitch_scale = hauteur * randf_range(0.93, 1.07)
	var scene := get_tree().current_scene
	(scene if scene else get_tree().root).add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)

func _cri() -> void:
	_bouche_t = 1.4
	_son(["ambiance_rugissement1", "ambiance_rugissement2"], _pos_bouche(), 8.0, randf_range(0.7, 0.85))

func _eclair() -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		for mi in _mailles:
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("eclair", v), 0.9, 0.0, 0.2)

func _poudrerie(pos: Vector3, nombre := 40, force := 7.0) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = nombre
	p.lifetime = 1.8
	p.explosiveness = 0.9
	p.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 25, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 3.0
	pm.emission_ring_inner_radius = 1.0
	pm.emission_ring_height = 0.3
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.radial_velocity_min = force * 0.5
	pm.radial_velocity_max = force
	pm.gravity = Vector3(0, -1.2, 0)
	pm.damping_min = 2.0
	pm.damping_max = 3.5
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var deg := Gradient.new()
	deg.set_color(0, Color(0.78, 0.84, 0.95, 0.35))
	deg.set_color(1, Color(0.8, 0.88, 1.0, 0.0))
	var rampe := GradientTexture1D.new()
	rampe.gradient = deg
	pm.color_ramp = rampe
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.vertex_color_use_as_albedo = true
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mq
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var scene := get_tree().current_scene
	(scene if scene else get_tree().root).add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)

func _regler_souffle(portee: float, demi: float, degats: float) -> void:
	_portee_souffle = portee
	_demi_cone = demi
	_degats_souffle = degats
	var pm := _particules.process_material as ParticleProcessMaterial
	pm.spread = demi * 0.8
	pm.initial_velocity_min = portee / 1.3 * 0.6
	pm.initial_velocity_max = portee / 1.3 * 1.0

func _souffler(actif: bool) -> void:
	if _souffle == actif:
		return
	_souffle = actif
	_particules.emitting = actif
	_t_tic = 0.2

func _tic_souffle(dt: float) -> void:
	if not _souffle:
		return
	_t_tic -= dt
	if _t_tic > 0.0:
		return
	_t_tic = 0.25
	var b := _pos_bouche()
	var v := joueur.global_position + Vector3(0, 1.0, 0) - b
	var d := v.length()
	if d < 0.1 or d > _portee_souffle:
		return
	if rad_to_deg(tete.global_transform.basis.z.angle_to(v)) < _demi_cone:
		joueur.recevoir_coup(_degats_souffle, b)

func _viser(point: Vector3) -> void:
	var dl := modele.global_transform.basis.inverse() * (point - _pos_bouche())
	if dl.length() < 0.1:
		return
	dl = dl.normalized()
	_cible_yaw = clampf(atan2(dl.x, dl.z), -1.1, 1.1)
	_cible_el = clampf(asin(clampf(dl.y, -1.0, 1.0)) - _prof_tete, -1.0, 0.6)

func _virer(vers: Vector3, taux: float, dt: float) -> float:
	var d := vers - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return 0.0
	var diff := angle_difference(rotation.y, atan2(d.x, d.z))
	rotation.y += clampf(diff, -taux * dt, taux * dt)
	return diff

func _regler_alt(cible: float, taux: float, dt: float) -> void:
	_alt = move_toward(_alt, cible, taux * dt)

# ---------------------------------------------------------------- machine à états

func _changer(nouvel: int) -> void:
	etat = nouvel
	_t = 0.0

func _physics_process(dt: float) -> void:
	_t += dt
	_recharge -= dt
	_cible_yaw = 0.0
	_cible_el = 0.0
	_extra_cible = 0.0
	_balai_cible = 0.0
	_sursaut = maxf(0.0, _sursaut - dt * 2.5)
	_bouche_t = maxf(0.0, _bouche_t - dt)
	var bank_cible := 0.0
	var diff := 0.0
	if joueur == null:
		return
	var jp := joueur.global_position
	var vers := _plat(jp - global_position)
	var dist := vers.length()

	match etat:
		TOURNOIE:
			var rel := Vector2(global_position.x - centre.x, global_position.z - centre.z)
			var ang := atan2(rel.y, rel.x)
			var cible := centre + Vector3(cos(ang + 0.45 * _sens), 0, sin(ang + 0.45 * _sens)) * RAYON_VOL
			_vitesse = move_toward(_vitesse, 15.0, 6.0 * dt)
			diff = _virer(cible, 0.9, dt)
			_regler_alt(42.0 + sin(_tw * 0.2) * 7.0, 4.0, dt)
			_cri_t -= dt
			if _cri_t <= 0.0:
				_cri_t = randf_range(8.0, 14.0)
				_cri()
			if dist < DETECTION and not joueur.mort:
				_entrer_pique()
		PIQUE:
			_t_phase += dt
			_vitesse = move_toward(_vitesse, 18.0, 6.0 * dt)
			if joueur.mort:
				_souffler(false)
				_changer(TOURNOIE)
			elif _phase == 0:
				diff = _virer(jp, 1.1, dt)
				_regler_alt(clampf(12.0 + (dist - 35.0) * 0.7, 12.0, 30.0), 9.0, dt)
				var devant := _avant().dot(vers.normalized())
				if dist < 38.0 and devant > 0.8:
					_en_passe = true
					_regler_souffle(32.0, 14.0, 5.0)
					_souffler(true)
					_viser(jp + Vector3(0, 0.8, 0))
				var passe := (_en_passe and dist < 40.0 and devant < 0.0) or _t_phase > 25.0
				if passe:
					_souffler(false)
					_fait += 1
					_en_passe = false
					_t_phase = 0.0
					if _fait >= _passes:
						_entrer_atterrit()
					else:
						_phase = 1
			else:
				var fuite := global_position + _plat(global_position - jp).normalized() * 100.0
				diff = _virer(fuite, 0.9, dt)
				_regler_alt(22.0, 6.0, dt)
				if dist > 55.0 or _t_phase > 9.0:
					_phase = 0
					_t_phase = 0.0
		ATTERRIT:
			var vl := _plat(_atterrissage - global_position)
			var d := vl.length()
			if d > 16.0 and _t < 14.0:
				_vitesse = move_toward(_vitesse, 14.0, 6.0 * dt)
				diff = _virer(_atterrissage, 1.1, dt)
				_regler_alt(clampf(8.0 + (d - 16.0) * 0.6, 8.0, 30.0), 8.0, dt)
			else:
				# vol stationnaire : approche lente, face au joueur
				var v := clampf(d * 0.7, 1.5, 6.0) if _t < 14.0 else 12.0
				_vitesse = move_toward(_vitesse, v, 8.0 * dt)
				var dir := vl.normalized() if d > 0.1 else Vector3.ZERO
				global_position += dir * minf(v * dt, d)
				_vitesse = 0.0
				_virer(global_position + _plat(jp - global_position), 1.5, dt)
				_regler_alt(clampf(d * 0.5 - 2.0, 0.0, 8.0) if _t < 14.0 else 0.0, 5.0 if _t < 14.0 else 6.0, dt)
				if _alt < 0.25 and d < 4.0 or (_t > 14.0 and _alt <= 0.0 and d < 0.5):
					_atterrir()
			if _alt < 7.0:
				_poudre_t -= dt
				if _poudre_t <= 0.0:
					_poudre_t = 0.25
					_poudrerie(Vector3(global_position.x, _sol(global_position) + 0.3, global_position.z), 14, 5.0)
		AU_SOL:
			_logique_sol(dt, jp, vers, dist)
		DECOLLE:
			_vitesse = move_toward(_vitesse, 0.0 if _t < 1.0 else 12.0, 5.0 * dt)
			if _t > 0.8:
				_regler_alt(16.0, 4.5, dt)
			_poudre_t -= dt
			if _alt < 6.0 and _poudre_t <= 0.0:
				_poudre_t = 0.18
				_poudrerie(Vector3(global_position.x, _sol(global_position) + 0.3, global_position.z), 18, 6.0)
			if _alt >= 14.0:
				if not joueur.mort and dist < 110.0:
					_entrer_pique()
				else:
					_changer(TOURNOIE)
		MORT:
			_logique_mort(dt)

	if etat != AU_SOL and etat != MORT:
		_tic_souffle(dt)
	# déplacement
	if etat in [TOURNOIE, PIQUE, DECOLLE] or (etat == ATTERRIT and _vitesse > 0.01):
		global_position += _avant() * _vitesse * dt
	global_position.y = _sol(global_position) + _alt
	bank_cible = -clampf(diff * 1.5, -0.55, 0.55) if etat in [TOURNOIE, PIQUE, ATTERRIT] else 0.0
	_bank = lerpf(_bank, bank_cible, 1.0 - exp(-2.5 * dt))
	_animer(dt)
	_alt_avant = _alt

func _entrer_pique() -> void:
	_changer(PIQUE)
	_passes = randi_range(2, 3)
	_fait = 0
	_en_passe = false
	# trop près (redécollage) : d'abord s'éloigner pour prendre de l'élan
	_phase = 1 if _plat(joueur.global_position - global_position).length() < 60.0 else 0
	_t_phase = 0.0
	_cri()

func _entrer_atterrit() -> void:
	_souffler(false)
	_changer(ATTERRIT)
	var jp := joueur.global_position
	var away := _plat(global_position - jp)
	if away.length() < 1.0:
		away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	_atterrissage = jp + away.normalized() * 10.5
	_atterrissage.y = _sol(_atterrissage)
	_poudre_t = 0.0

func _atterrir() -> void:
	_alt = 0.0
	_vitesse = 0.0
	_changer(AU_SOL)
	_act = RIEN
	_recharge = 1.0
	_marche = false
	_vie_debut_sol = vie
	collision_layer = 1
	joueur.secousse = maxf(joueur.secousse, 0.8)
	var p := Vector3(global_position.x, _sol(global_position) + 0.3, global_position.z)
	_poudrerie(p, 60, 9.0)
	_son(["impactWood_heavy_000", "impactPunch_heavy_000", "impactPunch_heavy_001"], p, 8.0, 0.5)
	_cri()

func _decoller() -> void:
	_souffler(false)
	_act = RIEN
	_changer(DECOLLE)
	collision_layer = 0
	_vitesse = 0.0
	_balai_cible = 0.0
	_poudrerie(Vector3(global_position.x, _sol(global_position) + 0.3, global_position.z), 50, 9.0)
	_son(["ambiance_rugissement1", "ambiance_rugissement2"], _pos_bouche(), 6.0, 0.7)
	joueur.secousse = maxf(joueur.secousse, 0.4)

func _logique_sol(dt: float, jp: Vector3, vers: Vector3, dist: float) -> void:
	_t_act += dt
	_vitesse = 0.0
	var dir := vers.normalized() if dist > 0.01 else _avant()
	var basis_z := _avant()
	var devant := basis_z.dot(dir)
	var lx := basis_z.cross(Vector3.UP).dot(dir)  # > 0 : joueur du côté +X local
	lx = global_transform.basis.x.dot(dir)

	if _t > 20.0 or vie <= _vie_debut_sol - 0.3 * vie_max:
		_decoller()
		return

	# on se tourne vers le joueur (moins vite pendant le souffle) ; le dos reste exposé
	var rate := 1.3
	if _act == SOUFFLE:
		rate = 0.8
	elif _act == QUEUE:
		rate = 0.0
	elif _act == MORD and _t_act > 0.4:
		rate = 0.0
	var diff := angle_difference(rotation.y, atan2(dir.x, dir.z))
	rotation.y += clampf(diff, -rate * dt, rate * dt)
	if _act == MORD or _act == SOUFFLE:
		_viser(jp + Vector3(0, 1.0, 0))

	match _act:
		RIEN:
			if _marche:
				if dist < 6.5:
					_marche = false
				else:
					global_position += basis_z * 3.0 * dt
			elif dist > 8.5:
				_marche = true
			if _recharge <= 0.0:
				if devant < -0.25 and dist < 9.5:
					_demarrer(QUEUE)
					_balai_cible = signf(lx) * 1.4
				elif dist < 6.0 and devant > 0.3:
					_demarrer(MORD)
				elif dist < 12.0 and devant > 0.8 and dist > 4.0:
					_demarrer(SOUFFLE)
					_regler_souffle(10.0, 25.0, 6.0)
				elif dist < 12.0 and devant > 0.8:
					_demarrer(MORD)
		MORD:
			if _t_act < 0.45:
				_extra_cible = 0.5
				_bouche_t = 0.3
			elif _t_act < 0.8:
				_extra_cible = -0.8
				_bouche_t = 0.0
				if not _coup_fait and _t_act >= 0.55:
					_coup_fait = true
					var b := _pos_bouche()
					var v := jp + Vector3(0, 1.0, 0) - b
					if dist < 6.4 and devant > 0.25 and v.length() < 6.5:
						joueur.recevoir_coup(30.0, b)
					_son(["swing", "swing2", "swing3"], b, 4.0, 0.5)
			if _t_act >= 1.1:
				_fin_action(1.0)
		QUEUE:
			if _t_act < 0.5:
				_balai_cible = signf(lx) * 1.4 if _balai_cible == 0.0 else _balai_cible
				_bouche_t = 0.0
			else:
				_balai_cible = -signf(_balai) * 1.4
				if not _coup_fait and _t_act >= 0.62:
					_coup_fait = true
					var bout := modele.to_global(_queue_pts[N_QUEUE - 2])
					if dist < 9.5 and devant < 0.1:
						joueur.recevoir_coup(25.0, bout)
					_son(["swing", "swing2", "swing3"], bout, 4.0, 0.5)
			if _t_act >= 1.2:
				_fin_action(0.9)
		SOUFFLE:
			if _t_act < 0.4:
				_extra_cible = 0.4
				_bouche_t = 0.5
			elif _t_act < 1.9:
				_bouche_t = 0.3
				_souffler(true)
				_tic_souffle(dt)
			else:
				_souffler(false)
			if _t_act >= 2.0:
				_fin_action(1.2)
	# suit le relief
	global_position.y = lerpf(global_position.y, _sol(global_position), 1.0 - exp(-8.0 * dt))

func _demarrer(a: int) -> void:
	_act = a
	_t_act = 0.0
	_coup_fait = false
	_marche = false
	if a == SOUFFLE:
		_son(["mnstr1", "mnstr2", "mnstr3"], _pos_bouche(), 5.0, 0.6)

func _fin_action(pause: float) -> void:
	_souffler(false)
	_act = RIEN
	_recharge = pause + randf_range(0.0, 0.8)

# ---------------------------------------------------------------- mort

func _mourir() -> void:
	_souffler(false)
	_act = RIEN
	_changer(MORT)
	_mort_t = 0.0
	_chute = 0.0
	_impact_fait = _alt <= 0.05
	_mat_oeil.albedo_color = Color(0.08, 0.1, 0.14)
	_son(["mnstr5", "mnstr6", "giant5"], _pos_bouche(), 10.0, 0.5)
	Effets.eclats(self, point_impact(), Color(0.7, 1.1, 1.8), 40, 4.5, true)
	_laisser_butin()
	vaincu.emit()

func _logique_mort(dt: float) -> void:
	_mort_t += dt
	_vitesse = move_toward(_vitesse, 0.0, 8.0 * dt)
	if _alt > 0.0:
		_chute += 20.0 * dt
		_alt = maxf(0.0, _alt - _chute * dt)
	if _alt <= 0.0 and not _impact_fait:
		_impact_fait = true
		joueur.secousse = maxf(joueur.secousse, 0.6)
		var p := Vector3(global_position.x, _sol(global_position) + 0.3, global_position.z)
		_poudrerie(p, 60, 9.0)
		_son(["impactWood_heavy_000", "impactPunch_heavy_002"], p, 8.0, 0.45)
	collision_layer = 1 if _alt < 0.5 else 0
	if _vitesse > 0.01:
		global_position += _avant() * _vitesse * dt
	if _mort_t > 30.0 and not _squelette_fait:
		_en_squelette()

func _laisser_butin() -> void:
	var b := Node3D.new()
	b.set_script(BUTIN)
	b.joueur = joueur
	b.hud = hud
	var contenu := {"pieces": randi_range(150, 300), "amulette_givre": 1}
	if Inventaire.OBJETS.has("ecaille_dragon"):
		contenu["ecaille_dragon"] = randi_range(2, 4)
	b.contenu = contenu
	get_parent().add_child(b)
	var p := global_position + _avant() * 5.5
	b.global_position = Vector3(p.x, _sol(p), p.z)

func _en_squelette() -> void:
	_squelette_fait = true
	for m in _mailles:
		if is_instance_valid(m) and not (m in _membranes):
			m.material_override = _mat_os
	for m in _membranes:
		m.visible = false
	Effets.eclats(self, global_position + Vector3(0, 1.5, 0), Color(0.85, 0.92, 1.0), 30, 4.0)

# ---------------------------------------------------------------- animation procédurale

func _mort_k() -> float:
	return clampf(_mort_t / 3.0, 0.0, 1.0) if etat == MORT else 0.0

static func _rotz(v: Vector3, a: float) -> Vector3:
	return Vector3(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a), v.z)

func _poser(mi: MeshInstance3D, a: Vector3, b: Vector3, ep: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	d /= l
	var haut := Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT
	var bs := Basis.looking_at(d, haut, true).scaled_local(Vector3(ep, ep, l))
	mi.transform = Transform3D(bs, a)

func _animer(dt: float) -> void:
	_tw += dt
	var mk := _mort_k()
	var mk_s := mk * mk * (3.0 - 2.0 * mk)
	var vol_cible := clampf(_alt / 2.5, 0.0, 1.0) if etat != MORT else 0.0
	_vol_k = lerpf(_vol_k, vol_cible, 1.0 - exp(-6.0 * dt))

	# attitude globale (tangage, roulis, enfoncement à la mort)
	var vy := (_alt - _alt_avant) / maxf(dt, 0.0001)
	var montee := atan2(vy, maxf(_vitesse, 3.0)) if _alt > 0.5 else 0.0
	_pitch = lerpf(_pitch, -clampf(montee, -0.6, 0.6), 1.0 - exp(-3.0 * dt))
	modele.rotation.x = lerpf(_pitch, 0.0, mk_s)
	modele.rotation.z = lerpf(_bank, 0.0, mk_s)
	var bob := sin(_tw * 1.4) * 0.04 * (1.0 - _vol_k)
	modele.position.y = -1.0 * mk_s + bob
	var min_y := 0.2 - modele.position.y

	# ailes
	var ouv_cible := 1.0
	var amp_cible := 0.35
	var freq_cible := 0.8
	match etat:
		TOURNOIE:
			amp_cible = 0.3 + 0.25 * maxf(0.0, sin(_tw * 0.35))
			freq_cible = 0.8
		PIQUE:
			amp_cible = 0.3
			freq_cible = 1.2
		ATTERRIT:
			amp_cible = 0.85 if _alt < 10.0 else 0.4
			freq_cible = 2.0 if _alt < 10.0 else 1.0
		DECOLLE:
			amp_cible = 0.9
			freq_cible = 1.9
		AU_SOL:
			ouv_cible = 0.0
			amp_cible = 0.0
			freq_cible = 0.0
		MORT:
			ouv_cible = 0.85 * mk_s if mk_s > 0.0 else 0.0
			amp_cible = 0.0
			freq_cible = 0.0
	var ouv_vitesse := 1.6 if etat == AU_SOL else 2.5
	if etat == MORT:
		ouv_cible = lerpf(1.0, 0.8, mk_s)
		ouv_vitesse = 3.0
	_ouv = lerpf(_ouv, ouv_cible, 1.0 - exp(-ouv_vitesse * dt))
	_amp = lerpf(_amp, amp_cible, 1.0 - exp(-3.0 * dt))
	_freq = lerpf(_freq, freq_cible, 1.0 - exp(-3.0 * dt))
	_phase_aile += TAU * _freq * dt
	var phi := sin(_phase_aile) * _amp + 0.12 * _ouv
	phi = lerpf(phi, -0.55, mk_s)
	for i in 2:
		var cote := -1.0 if i == 0 else 1.0
		_poser_aile(i, cote, phi, min_y - EPAULE.y)

	# cou : profil de repos + regard, chaque segment suit celui qui le précède avec retard
	_extra = lerpf(_extra, _extra_cible, 1.0 - exp(-9.0 * dt))
	var p := Vector3(0, 2.7, 1.8)
	var cible_cou := _cible_yaw
	for i in N_COU:
		var w := pow(float(i + 1) / N_COU, 1.2)
		var base_sol: float = PROFIL_SOL[i]
		var base_vol: float = PROFIL_VOL[i]
		var base_mort: float = PROFIL_MORT[i]
		var prof := lerpf(lerpf(base_sol, base_vol, _vol_k), base_mort, mk_s)
		if i == N_COU - 1:
			_prof_tete = prof
		var taux := 3.0 + i * 1.5
		var ty := cible_cou * w * (1.0 - mk_s) + sin(_tw * 1.1 - i * 0.5) * 0.03
		var te := prof + (_cible_el * w + _extra * w + _sursaut * 0.35 * w) * (1.0 - mk_s) + sin(_tw * 1.7 - i * 0.6) * 0.04 * (1.0 - mk_s)
		_cou_yaw[i] = lerpf(_cou_yaw[i], ty, 1.0 - exp(-taux * dt))
		_cou_el[i] = lerpf(_cou_el[i], te, 1.0 - exp(-taux * dt))
		var d := Vector3(sin(_cou_yaw[i]) * cos(_cou_el[i]), sin(_cou_el[i]), cos(_cou_yaw[i]) * cos(_cou_el[i]))
		var q := p + d * LONG_COU
		if mk_s > 0.0:
			q.y = maxf(q.y, min_y + 0.2)
		_poser(_cou[i], p, q, 1.0)
		p = q
		if i == N_COU - 1:
			tete.transform = Transform3D(Basis.looking_at(d, Vector3.UP, true), p)
	var ouverture := 0.7 if _bouche_t > 0.0 else 0.0
	ouverture = maxf(ouverture, 0.6 * mk_s)
	_bouche = lerpf(_bouche, ouverture, 1.0 - exp(-10.0 * dt))
	_machoire.rotation.x = _bouche

	# queue : ondulation + balayage
	_balai = lerpf(_balai, _balai_cible, 1.0 - exp(-(9.0 if _act == QUEUE else 3.0) * dt))
	var q0 := Vector3(0, 2.4, -2.1)
	var yaw := PI
	var el := -0.12
	_queue_pts[0] = q0
	for i in N_QUEUE:
		var onde := sin(_tw * 1.8 - i * 0.65) * (0.07 + 0.012 * i) * (1.0 - mk_s)
		yaw += onde + _balai / N_QUEUE
		el = lerpf(-0.12 + i * 0.015, -0.03, mk_s)
		var d := Vector3(sin(yaw) * cos(el), sin(el), cos(yaw) * cos(el))
		var q := q0 + d * LONG_QUEUE
		if mk_s > 0.0:
			q.y = maxf(q.y, min_y + 0.1)
		_poser(_queue[i], q0, q, 1.0)
		q0 = q
		_queue_pts[i + 1] = q0

	_animer_pattes(mk_s, min_y)

	# ombre-disque sous le dragon quand il vole bas
	var proche := etat != MORT and _alt > 0.5 and _alt < 28.0
	_ombre.visible = proche
	if proche:
		var gp := Vector3(global_position.x, _sol(global_position) + 0.12, global_position.z)
		var k := 1.0 - _alt / 28.0
		_ombre.global_transform = Transform3D(Basis(Vector3.UP, rotation.y).scaled_local(Vector3(4.5, 1.0, 6.5)), gp)
		(_ombre.material_override as StandardMaterial3D).albedo_color.a = 0.45 * k

func _animer_pattes(mk_s: float, min_y: float) -> void:
	for d: Dictionary in _pattes:
		var avant: bool = d["avant"]
		var cote: float = d["cote"]
		var h: Vector3 = d["hanche"]
		var sol_p := Vector3(1.1 * cote, 0.0, 1.6) if avant else Vector3(1.2 * cote, 0.0, -1.4)
		var vol_p := h + (Vector3(0.3 * cote, -0.8, 0.8) if avant else Vector3(0.2 * cote, -0.9, -1.3))
		var mort_p := Vector3(2.2 * cote, 0.0, 1.8) if avant else Vector3(2.0 * cote, 0.0, -1.4)
		var pied := sol_p.lerp(vol_p, _vol_k).lerp(mort_p, mk_s)
		pied.y = maxf(pied.y, min_y) if mk_s > 0.0 else pied.y
		var plie := Vector3(0.6 * cote, 0.1, -1.0) if avant else Vector3(0.5 * cote, 0.3, 1.0)
		var genou := _genou(h, pied, 1.25, 1.25, plie)
		(d["cuisse"] as MeshInstance3D).visible = true
		_poser(d["cuisse"], h, genou, 1.0)
		_poser(d["tibia"], genou, pied, 1.0)
		_poser(d["pied"], pied, pied + Vector3(0.1 * cote, -0.05, 0.75), 1.0)

func _genou(h: Vector3, p: Vector3, a: float, b: float, plie: Vector3) -> Vector3:
	var v := p - h
	var dist := clampf(v.length(), 0.05, a + b - 0.05)
	var dir := v.normalized()
	var x := (a * a - b * b + dist * dist) / (2.0 * dist)
	var y := sqrt(maxf(a * a - x * x, 0.0))
	var perp := plie - dir * plie.dot(dir)
	perp = perp.normalized() if perp.length() > 0.001 else Vector3.UP
	return h + dir * x + perp * y

func _points_aile(ouv: float, phi: float, min_y: float) -> Array[Vector3]:
	# repère de l'aile droite (+X vers l'extérieur), origine à l'épaule
	var s := Vector3.ZERO
	var e_o := s + _rotz(Vector3(1.4, 0.3, -0.4), phi)
	var w_o := e_o + _rotz(Vector3(1.8, 0.2, 0.4), phi * 1.3)
	var f1_o := w_o + _rotz(Vector3(3.3, 0.0, 0.9), phi * 1.8)
	var f2_o := w_o + _rotz(Vector3(3.0, 0.0, -1.3), phi * 1.9)
	var f3_o := w_o + _rotz(Vector3(2.2, 0.0, -2.6), phi * 2.0)
	var e_f := Vector3(0.5, 0.7, -1.2)
	var w_f := Vector3(0.6, 0.9, 0.5)
	var f1_f := w_f + Vector3(0.1, 0.0, -3.0)
	var f2_f := w_f + Vector3(0.15, -0.2, -3.3)
	var f3_f := w_f + Vector3(0.2, -0.5, -2.9)
	var b := Vector3(0.2, -0.6, -3.2)
	var e := e_f.lerp(e_o, ouv)
	var w := w_f.lerp(w_o, ouv)
	var f1 := f1_f.lerp(f1_o, ouv)
	var f2 := f2_f.lerp(f2_o, ouv)
	var f3 := f3_f.lerp(f3_o, ouv)
	var m12 := (f1 + f2) * 0.5
	m12 += (w - m12) * 0.22
	var m23 := (f2 + f3) * 0.5
	m23 += (w - m23) * 0.22
	var m3b := (f3 + b) * 0.5
	m3b += (w - m3b) * 0.2
	var pts: Array[Vector3] = [s, e, w, f1, f2, f3, m12, m23, m3b, b]
	for i in pts.size():
		pts[i].y = maxf(pts[i].y, min_y)
	return pts

func _poser_aile(i: int, cote: float, phi: float, min_y: float) -> void:
	var pts := _points_aile(_ouv, phi, min_y)
	for k in pts.size():
		pts[k].x *= cote
	var os: Array = _os_aile[i]
	_poser(os[0], pts[0], pts[1], 0.17)
	_poser(os[1], pts[1], pts[2], 0.14)
	_poser(os[2], pts[2], pts[3], 0.1)
	_poser(os[3], pts[2], pts[4], 0.1)
	_poser(os[4], pts[2], pts[5], 0.1)
	# membrane : éventail depuis le poignet, double face (le shader n'a pas de cull désactivé)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := [
		[2, 3, 6], [2, 6, 4], [2, 4, 7], [2, 7, 5], [2, 5, 8], [2, 8, 9],
		[0, 2, 9], [0, 1, 2],
	]
	for t: Array in tris:
		var a: Vector3 = pts[t[0]]
		var b: Vector3 = pts[t[1]]
		var c: Vector3 = pts[t[2]]
		var n := (c - a).cross(b - a)
		_tri(st, a, b, c, n)
		_tri(st, a, b, c, -n)
	_mb_aile[i].mesh = st.commit()
