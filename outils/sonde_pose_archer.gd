extends SceneTree
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var c := Humain.creer({"corps": "femme", "tenue": {"tunique": Color.WHITE}})
	root.add_child(c)
	var sq := c.find_child("Skeleton3D", true, false) as Skeleton3D
	for n in ["pelvis","spine_01","spine_02","spine_03","neck_01","Head","clavicle_l","upperarm_l","lowerarm_l","hand_l","clavicle_r","upperarm_r","lowerarm_r","hand_r","index_01_l","middle_01_r"]:
		var i := sq.find_bone(n)
		if i < 0: print(n, " ABSENT"); continue
		var g := sq.get_bone_global_rest(i)
		print("%-12s parent=%-12s pos=%s  x=%s y=%s z=%s" % [n, sq.get_bone_name(sq.get_bone_parent(i)), g.origin, g.basis.x.snapped(Vector3.ONE*0.01), g.basis.y.snapped(Vector3.ONE*0.01), g.basis.z.snapped(Vector3.ONE*0.01)])
	var ap := c.get_node("Animations") as AnimationPlayer
	for clip in ["Idle", "Pistol_Aim_Neutral", "Pistol_Shoot"]:
		ap.play(clip)
		ap.seek(ap.get_animation(clip).length * 0.5, true)
		print("== ", clip, " len ", ap.get_animation(clip).length)
		print("   PELVIS_FULL ", sq.get_bone_global_pose(sq.find_bone("pelvis")))
		for n in ["pelvis","spine_03","Head","hand_l","hand_r","upperarm_l","upperarm_r"]:
			var g := sq.get_bone_global_pose(sq.find_bone(n))
			print("   %-12s pos=%s y=%s z=%s" % [n, g.origin.snapped(Vector3.ONE*0.01), g.basis.y.snapped(Vector3.ONE*0.01), g.basis.z.snapped(Vector3.ONE*0.01)])
	quit()
