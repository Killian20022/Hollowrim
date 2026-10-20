extends Node3D
## Caméra à la troisième personne : derrière l'épaule droite, elle suit le lacet du joueur et
## le tangage de sa tête. Un SpringArm3D la rapproche quand un arbre ou un mur s'interpose.
## Elle est détachée du joueur (top_level) pour que son déplacement soit lissé.

const DISTANCE := 2.6   # recul derrière la tête
const EPAULE := 0.5     # décalage vers la droite
const HAUTEUR := 0.1    # au-dessus des yeux (soit ~1,7 m du sol)
const LISSAGE_XZ := 18.0
const LISSAGE_Y := 9.0

var joueur: CharacterBody3D
var bras: SpringArm3D
var camera: Camera3D
var _prete := false
var _refresh := 0.0
var _orbite := 0.0  # captures : --tp-orbite=degrés fait tourner la caméra autour du joueur

func _ready() -> void:
	top_level = true
	bras = SpringArm3D.new()
	bras.shape = SphereShape3D.new()
	(bras.shape as SphereShape3D).radius = 0.22
	bras.spring_length = DISTANCE
	bras.margin = 0.05
	bras.collision_mask = 1
	bras.position = Vector3(EPAULE, HAUTEUR, 0.0)
	add_child(bras)
	bras.add_excluded_object(joueur.get_rid())
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 90.0  # lot 7 : au-delà de la fin du brouillard (75 m max) rien n'est visible
	bras.add_child(camera)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tp-orbite="):
			_orbite = deg_to_rad(float(a.substr(12)))
			bras.position = Vector3.ZERO

## Recale la caméra sans lissage (à la bascule de vue ou après une téléportation).
func recaler() -> void:
	_prete = false
	_suivre(0.0)

func _process(dt: float) -> void:
	if joueur == null or not visible:
		return
	_suivre(dt)
	_refresh -= dt
	if _refresh <= 0.0:
		# les ennemis et villageois ne repoussent pas la caméra
		_refresh = 0.5
		bras.clear_excluded_objects()
		bras.add_excluded_object(joueur.get_rid())
		for g in ["ennemis", "villageois"]:
			for n in get_tree().get_nodes_in_group(g):
				if n is CollisionObject3D:
					bras.add_excluded_object((n as CollisionObject3D).get_rid())

func _suivre(dt: float) -> void:
	var cible: Vector3 = joueur.tete.global_position
	if not _prete or dt <= 0.0:
		global_position = cible
		_prete = true
	else:
		global_position.x = lerpf(global_position.x, cible.x, 1.0 - exp(-LISSAGE_XZ * dt))
		global_position.z = lerpf(global_position.z, cible.z, 1.0 - exp(-LISSAGE_XZ * dt))
		global_position.y = lerpf(global_position.y, cible.y, 1.0 - exp(-LISSAGE_Y * dt))
	# lacet du joueur + tangage de la tête (sans le roulis de la mort)
	global_basis = Basis.from_euler(Vector3(joueur.tete.rotation.x, joueur.global_rotation.y + _orbite, 0.0))
