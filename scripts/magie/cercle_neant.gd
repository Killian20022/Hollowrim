class_name CercleNeant
extends Node3D
## GRAND CERCLE RUNIQUE VERTICAL du « rayon du néant » (data/sorts/rayon_neant.tres). Il apparaît à partir de la mi-charge devant
## la main, face à la visée : l'anneau se trace peu à peu, les runes de ténèbres s'allument une à une et tournent lentement.
## Fin et transparent au centre (shaders/rayon_neant_cercle.gdshader). Au relâchement, `tirer()` le fige dans le monde le temps du
## rayon (RayonNeant), puis il s'éteint. MainSort le pose chaque image (`placer`) tant que le sort se charge ; s'il n'est plus
## posé (changement d'arme, charge coupée), il s'éteint tout seul.
## Rendu : calque de la couche fine, comme le noyau d'école (NoyauEcole).

const SH := preload("res://shaders/rayon_neant_cercle.gdshader")
## Diamètre du carré (m) pour un cercle de rayon 1 : l'anneau extérieur est à 0,90 du demi-carré.
const NB_RUNES := 8
## Charge à partir de laquelle le cercle commence à se tracer, et charge où il est complet.
const DEBUT := 0.5
const COMPLET := 0.92
## Rayon du cercle (m) ; la double magie l'agrandit.
const RAYON := 0.34

enum Mode { CHARGE, TIR, FONDU }

## Un cercle par paume : pour que le tir retrouve celui de la charge (instance_id de la paume → cercle).
static var par_paume := {}

var mode := Mode.CHARGE
var charge := 0.0
var cote := 1.0
var rayon := RAYON
var _mi: MeshInstance3D
var _mat: ShaderMaterial
var _t := 0.0
var _rot := 0.0
var _vit := 0.35
var _trace := 0.0
var _allumees := 0.0
var _fondu := 0.0
var _flash := 0.0
var _depuis_pose := 0.0
var _duree_tir := 0.8
var _t_tir := 0.0
var _cle := 0
var _cible := Transform3D.IDENTITY
var _pose := false

func _ready() -> void:
	top_level = true
	_mat = ShaderMaterial.new()
	_mat.shader = SH
	var qd := QuadMesh.new()
	qd.size = Vector2.ONE
	_mi = MeshInstance3D.new()
	_mi.mesh = qd
	_mi.material_override = _mat
	_mi.layers = CoucheMagie.CALQUE
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = 2.0
	add_child(_mi)
	_mi.visible = false

## Cercle posé pour la paume `paume` (le crée s'il n'existe pas). `parent` : où l'accrocher (peu importe : top_level).
static func pour(paume: Node3D, parent: Node, cote_main: float) -> CercleNeant:
	var id := paume.get_instance_id()
	var c: CercleNeant = par_paume.get(id)
	if c != null and is_instance_valid(c) and not c.is_queued_for_deletion():
		return c
	c = CercleNeant.new()
	c.name = "CercleNeant"
	c.cote = cote_main
	c._cle = id
	par_paume[id] = c
	parent.add_child(c)
	return c

## Un cercle déjà né pour cette paume, ou null (le tir le reprend).
static func existant(paume: Node3D) -> CercleNeant:
	if paume == null:
		return null
	var c: CercleNeant = par_paume.get(paume.get_instance_id())
	if c != null and is_instance_valid(c) and not c.is_queued_for_deletion():
		return c
	return null

## Position du centre (monde) et axe de visée (le cercle est perpendiculaire à `avant`, debout).
func placer(centre: Vector3, avant: Vector3) -> void:
	_depuis_pose = 0.0
	if mode != Mode.CHARGE:
		return
	_cible = _repere(centre, avant)

static func _repere(centre: Vector3, avant: Vector3) -> Transform3D:
	var z := avant.normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.05:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x).normalized()
	return Transform3D(Basis(x, y, z), centre)

## Le rayon part : le cercle se fige là où il est, s'embrase, puis s'éteint (`duree` = durée du rayon).
func tirer(duree: float, centre := Vector3.INF, avant := Vector3.ZERO) -> void:
	if mode == Mode.TIR:
		return
	if centre != Vector3.INF:
		_cible = _repere(centre, avant)
	mode = Mode.TIR
	_duree_tir = duree
	_t_tir = 0.0
	_trace = 1.0
	_allumees = float(NB_RUNES)
	_flash = 1.0
	if _mi != null:
		_mi.visible = true

## Centre du cercle (monde).
func centre() -> Vector3:
	return _cible.origin

func fondre() -> void:
	if mode == Mode.CHARGE:
		mode = Mode.FONDU

func _exit_tree() -> void:
	if par_paume.get(_cle) == self:
		par_paume.erase(_cle)

func _process(dt: float) -> void:
	_t += dt
	_depuis_pose += dt
	if mode == Mode.CHARGE and _depuis_pose > 0.2:
		mode = Mode.FONDU
	var g := GestionMagie.obtenir()
	match mode:
		Mode.CHARGE:
			# le tracé suit la charge, lissé (jamais de saut)
			var voulu := smoothstep(DEBUT, COMPLET, charge)
			_trace = move_toward(_trace, voulu, dt * 1.6)
			_allumees = move_toward(_allumees, voulu * float(NB_RUNES) * 1.02, dt * 5.0)
			_fondu = move_toward(_fondu, 1.0 if _trace > 0.001 else 0.0, dt * 5.0)
			_vit = lerpf(_vit, 0.35 + 0.5 * charge, 1.0 - exp(-dt * 4.0))
			global_transform = global_transform.interpolate_with(_cible, 1.0 - exp(-dt * 22.0)) if _pose else _cible
			_pose = true
		Mode.TIR:
			_t_tir += dt
			_flash = maxf(_flash - dt * 1.8, 0.0)
			_vit = lerpf(_vit, 1.6, 1.0 - exp(-dt * 6.0))
			var fin := 1.0 - smoothstep(_duree_tir * 0.6, _duree_tir, _t_tir)
			_fondu = fin
			global_transform = _cible
			if _t_tir >= _duree_tir:
				queue_free()
				return
		Mode.FONDU:
			_fondu = move_toward(_fondu, 0.0, dt * 4.0)
			_trace = maxf(_trace - dt * 1.5, 0.0)
			_allumees = maxf(_allumees - dt * 10.0, 0.0)
			if _fondu <= 0.0:
				queue_free()
				return
	_rot += dt * _vit * cote
	_mi.visible = _fondu > 0.01
	var d := rayon * 2.0 / 0.9 * (1.0 + 0.03 * _flash)
	_mi.scale = Vector3(d, d, 1.0)
	_mat.set_shader_parameter("trace", _trace)
	_mat.set_shader_parameter("allumees", _allumees)
	_mat.set_shader_parameter("rot", _rot)
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("fondu", _fondu * (0.8 if mode != Mode.TIR else 1.0))
	_mat.set_shader_parameter("eclat", (0.85 + 0.15 * sin(_t * 3.1)) * (1.0 + 0.5 * charge) * (1.0 + 0.6 * _flash))
	if g != null and g.couche != null and _mi.visible:
		g.couche.demander()
