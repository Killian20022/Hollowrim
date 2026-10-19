extends SkeletonModifier3D
## Après l'IK des bras : oriente la main comme sa cible (poignet tourné selon l'arme tenue).

var os := ""
var cible: Node3D
var decalage := Transform3D()  # repère de la main par rapport à la cible

func _process_modification() -> void:
	var sq := get_skeleton()
	if sq == null or cible == null or not is_instance_valid(cible):
		return
	var i := sq.find_bone(os)
	if i < 0:
		return
	var actuelle := sq.get_bone_global_pose(i)
	var voulue := (sq.global_transform.affine_inverse() * cible.global_transform * decalage).basis.orthonormalized()
	sq.set_bone_global_pose(i, Transform3D(voulue, actuelle.origin))
