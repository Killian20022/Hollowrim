extends SkeletonModifier3D
## Couche ADDITIVE des mouvements passifs (respiration, marche, inertie, saut…, MouvementsPassifs) par-dessus les
## animations du bras droit : le repère de l'os `os` (clavicule) — donc tout le bras et l'épée — est pré-multiplié par
## `decalage` (repère du squelette). L'animation repose les os à chaque image : aucun cumul.

var os := "clavicle_r"
var decalage := Transform3D()

func _process_modification_with_delta(_dt: float) -> void:
	var sq := get_skeleton()
	if sq == null or decalage.is_equal_approx(Transform3D()):
		return
	var i := sq.find_bone(os)
	if i < 0:
		return
	var parent := Transform3D()
	var j := sq.get_bone_parent(i)
	while j >= 0:
		parent = sq.get_bone_pose(j) * parent
		j = sq.get_bone_parent(j)
	var g := parent * sq.get_bone_pose(i)
	sq.set_bone_pose(i, parent.affine_inverse() * (decalage * g))
