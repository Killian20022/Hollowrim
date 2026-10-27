class_name PrechauffeRendu
extends Node
## Préchauffage du rendu d'un lieu caché (grotte, crypte). La 1re image après l'entrée compilait d'un coup une douzaine de pipelines (grotte :
## +12 de surface, +10 de spécialisation, ~60 ms de soumission, pire image ~80-130 ms) : sur le moteur Mobile un pipeline dépend aussi des lumières
## qui touchent l'objet, donc dessiner de petits maillages de remplacement ne suffit pas.
## Ici le lieu est dessiné POUR DE VRAI mais hors de l'écran : un SubViewport minuscule qui partage le monde, une caméra posée à tour de rôle
## aux points d'échantillonnage (le long des routes), une image de rendu chacun, étalées dans le temps (1 point toutes les 0,25 s environ).
## Le lieu est rendu visible le temps de l'opération (il est sous le sol : la vraie caméra ne le voit pas), puis recaché.
const TAILLE := Vector2i(128, 72)
const PAUSE := 0.25            # secondes entre deux points

var racine: Node3D             # le lieu (grotte / crypte) : visible pendant le préchauffage ; null = lieu déjà visible (dehors), rien à montrer
var pause := PAUSE             # secondes entre deux points (0 = un point par image)
var points: Array = []         # Transform3D monde : caméra à chaque étape
var soleil: Light3D            # le soleil : exclu de la caméra de préchauffage (sous terre il est éteint = autre variante de shader)
var env: Environment           # environnement du lieu (sous terre : brume, fond, ambiance) ; null = celui du monde
var fini := false
var _couches_soleil := 1
var rendus := 0
var _vp: SubViewport
var _cam: Camera3D
var _attente := 0.0
var _i := 0

## `hote` : nœud de l'arbre qui accueille le SubViewport ; `points` : Array de Transform3D (monde).
static func lancer(lieu: Node3D, hote: Node, pts: Array, sol: Light3D = null, env_: Environment = null, pause_ := PAUSE) -> PrechauffeRendu:
	var p := PrechauffeRendu.new()
	p.name = "PrechauffeRendu"
	p.racine = lieu
	p.pause = pause_
	p.points = pts
	p.soleil = sol
	p.env = env_
	hote.add_child(p)
	return p

func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = TAILLE
	_vp.own_world_3d = false                 # même monde (lumières, environnement, brume) que le jeu
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.audio_listener_enable_3d = false
	_cam = Camera3D.new()
	_cam.fov = 72.0
	_cam.near = 0.05
	_cam.far = 90.0
	if env != null:
		_cam.environment = env                    # variantes de shaders du lieu (brume exponentielle, fond uni) et non celles de dehors
	if soleil != null:
		# plusieurs préchauffages peuvent tourner en même temps (crypte + effets de combat) : les couches d'origine du soleil sont
		# gardées UNE fois et rendues quand le dernier s'arrête (sinon le second remettait les couches modifiées par le premier)
		var id := soleil.get_instance_id()
		if not _soleil_refs.has(id):
			_soleil_refs[id] = [soleil.layers, 0]
		_soleil_refs[id][1] += 1
		_couches_soleil = int(_soleil_refs[id][0])
		soleil.layers = 1 << 19                   # couche 20 : vue par la caméra du joueur (toutes couches), pas par la nôtre
		_cam.cull_mask = 0xFFFFF & ~(1 << 19)
	_vp.add_child(_cam)
	add_child(_vp)
	_cam.current = true

## Arrêt immédiat, sans toucher à la visibilité du lieu (le joueur l'ouvre).
func annuler() -> void:
	fini = true
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	queue_free()

static var _soleil_refs := {}     # id du soleil -> [couches d'origine, préchauffages en cours]

func _exit_tree() -> void:
	if soleil != null and is_instance_valid(soleil):
		var id := soleil.get_instance_id()
		var e: Array = _soleil_refs.get(id, [_couches_soleil, 1])
		e[1] -= 1
		if e[1] <= 0:
			soleil.layers = int(e[0])
			_soleil_refs.erase(id)
		soleil = null

func _process(dt: float) -> void:
	if fini:
		return
	var cache := racine != null
	if cache and (not is_instance_valid(racine) or not racine.is_inside_tree()):
		fini = true
		queue_free()
		return
	if cache and not _montre and racine.visible:
		fini = true                          # le joueur est entré (ou le lieu a été montré autrement) : on s'efface
		queue_free()
		return
	if _montre:
		if OS.get_cmdline_user_args().has("--debug-prechauffe"):
			print("PRECHAUFFE rendu : objets ", int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), " appels ", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), " prims ", int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		if OS.get_cmdline_user_args().has("--debug-prechauffe") and rendus in [1, 6]:
			_vp.get_texture().get_image().save_png("C:/Users/lopezk19/Jeux/captures_tmp/perf2_prech_%d.png" % rendus)
		if cache:
			racine.visible = false           # le rendu de l'image précédente est fait : on recache le lieu
		_montre = false
	_attente -= dt
	if _attente > 0.0:
		return
	if _i >= points.size():
		fini = true
		queue_free()
		return
	_cam.global_transform = points[_i]
	if OS.get_cmdline_user_args().has("--debug-prechauffe"):
		print("PRECHAUFFE point ", _i, "/", points.size(), " ", (points[_i] as Transform3D).origin, " pipelines surface ", int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)), " spec ", int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)))
	_i += 1
	if cache:
		racine.visible = true
	_montre = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	rendus += 1
	_attente = pause

var _montre := false
