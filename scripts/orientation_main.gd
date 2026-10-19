extends SkeletonModifier3D
## Après l'IK des bras : oriente la main comme sa cible (poignet tourné selon l'arme tenue).
## Les poses globales du squelette ne sont pas à jour pendant les modificateurs : on
## remonte la chaîne des poses locales (qui contiennent le résultat de l'IK).

var os := ""
var cible: Node3D
var decalage := Transform3D()  # repère de la main par rapport à la cible

func _process_modification_with_delta(_dt: float) -> void:
	var sq := get_skeleton()
	if sq == null or cible == null or not is_instance_valid(cible):
		return
	var i := sq.find_bone(os)
	if i < 0:
		return
	var parent := Transform3D()
	var p := sq.get_bone_parent(i)
	while p >= 0:
		parent = sq.get_bone_pose(p) * parent
		p = sq.get_bone_parent(p)
	var voulue := (sq.global_transform.affine_inverse() * cible.global_transform * decalage).basis.orthonormalized()
	sq.set_bone_pose_rotation(i, (parent.basis.orthonormalized().inverse() * voulue).get_rotation_quaternion())
