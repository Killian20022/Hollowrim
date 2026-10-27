class_name ReactionOs
extends SkeletonModifier3D
## Réaction procédurale aux coups, ajoutée PAR-DESSUS l'animation (Hit_Chest, Sword_Idle, attaque…) : un ressort amorti plie la
## colonne, la nuque et la tête dans le sens du coup (le haut du corps part avec la lame), puis revient. Plus le stagger est fort,
## plus le corps encaisse. En état étourdi, un balancement lent (le corps titube) s'y ajoute.
##   reaction.frapper(direction_monde, force)    force ~0,15 (léger) à ~0,7 rad (lourd)
## Désactivé à la mort (le ragdoll prend la main) : active = false.

## Part de la flexion prise par chaque os (somme ≈ 1,3 : la tête part un peu plus que le buste).
const POIDS := {"spine_01": 0.25, "spine_02": 0.25, "spine_03": 0.3, "neck_01": 0.2, "Head": 0.3}
const RAIDEUR := 140.0
const AMORTI := 13.0

var etourdi := false
var _d := Vector3.ZERO      # flexion (monde, horizontale) : direction × angle
var _v := Vector3.ZERO
var _t := 0.0
var _os: Array[int] = []
var _poids: Array[float] = []

func frapper(direction: Vector3, force: float) -> void:
	var h := Vector3(direction.x, 0.0, direction.z)
	if h.length() < 0.01:
		return
	_v += h.normalized() * force * 9.0

func _process_modification_with_delta(delta: float) -> void:
	var sq := get_skeleton()
	if sq == null:
		return
	if _os.is_empty():
		for nom: String in POIDS:
			var i := sq.find_bone(nom)
			if i >= 0:
				_os.append(i)
				_poids.append(float(POIDS[nom]))
	var dt := minf(delta, 0.05)
	_t += dt
	var cible := Vector3.ZERO
	if etourdi:
		cible = Vector3(sin(_t * 2.3), 0.0, cos(_t * 1.7) * 0.6) * 0.16
	_v += (-(_d - cible) * RAIDEUR - _v * AMORTI) * dt
	_d += _v * dt
	_d = _d.limit_length(0.9)
	var ang := _d.length()
	if ang < 0.002:
		return
	var axe_monde := Vector3.UP.cross(_d / ang).normalized()   # rotation qui amène le haut du corps vers _d
	var base_sq := sq.global_transform.basis.orthonormalized()
	for k in _os.size():
		var i := _os[k]
		var g := sq.get_bone_global_pose(i).basis.orthonormalized()
		var axe_os := (base_sq * g).inverse() * axe_monde
		var q := sq.get_bone_pose_rotation(i) * Quaternion(axe_os.normalized(), ang * _poids[k])
		sq.set_bone_pose_rotation(i, q)
