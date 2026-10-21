extends SkeletonModifier3D
## Démarche raide du draugr nordique (passe 2) : s'applique APRÈS l'animation (comme SuiviTete des villageois), sans toucher
## aux animations partagées ni au gameplay. Marche / course : rotations des hanches, genoux et colonne ramenées vers le repos
## (pas courts, jambes tendues, buste qui ne ballotte pas) ; en tout temps (sauf mort) : dos voûté, nuque tendue vers l'avant.
## Les clips d'attaque, de coup reçu et de mort restent intacts (seule la voûte, atténuée, s'y ajoute ; rien pendant la mort).

const AMORTIS := {"thigh_l": 0.80, "thigh_r": 0.80, "calf_l": 0.72, "calf_r": 0.72, "spine_01": 0.55, "spine_02": 0.55, "spine_03": 0.6,
	"upperarm_l": 0.85, "upperarm_r": 0.85}
## voûte (radians autour de l'axe X du squelette, + = vers l'avant)
const VOUTE := {"spine_01": 0.02, "spine_02": 0.04, "spine_03": 0.04, "neck_01": 0.07, "Head": -0.07}

var _marche := 0.0     # 0 = immobile, 1 = marche / course (lissé)
var _voute := 1.0      # 0 pendant la mort

func _process_modification() -> void:
	var sq := get_skeleton()
	if sq == null:
		return
	var ap := sq.get_parent().get_node_or_null("Animations") as AnimationPlayer
	var clip := String(ap.current_animation) if ap else ""
	var cible_m := 1.0 if (clip.begins_with("Walk") or clip.begins_with("Jog") or clip.begins_with("Sprint") or clip.begins_with("Run")) else 0.0
	var cible_v := 0.0 if clip.begins_with("Death") else (0.5 if (clip.contains("Attack") or clip.begins_with("Hit")) else 1.0)
	var k := 1.0 - exp(-8.0 * get_process_delta_time())
	_marche = lerpf(_marche, cible_m, k)
	_voute = lerpf(_voute, cible_v, k)
	if _marche > 0.01:
		for nom: String in AMORTIS:
			var i := sq.find_bone(nom)
			if i < 0:
				continue
			var repos := sq.get_bone_rest(i).basis.get_rotation_quaternion()
			var pose := sq.get_bone_pose_rotation(i)
			sq.set_bone_pose_rotation(i, repos.slerp(pose, lerpf(1.0, float(AMORTIS[nom]), _marche)))
	if _voute > 0.01:
		for nom: String in VOUTE:
			var i := sq.find_bone(nom)
			if i < 0:
				continue
			var parent := sq.get_bone_parent(i)
			var pb := sq.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
			var voulue := Basis(Vector3.RIGHT, float(VOUTE[nom]) * _voute) * sq.get_bone_global_pose(i).basis
			sq.set_bone_pose_rotation(i, (pb.inverse() * voulue).orthonormalized().get_rotation_quaternion())
