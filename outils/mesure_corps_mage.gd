extends SceneTree
## Hauteurs des os (repos) du corps homme et du corps femme d'Humain.creer : sert à régler la variante femme du mage.
##   godot --headless --path . --script res://outils/mesure_corps_mage.gd
func _init() -> void:
	for corps in ["homme", "femme"]:
		var r := Humain.creer({"corps": corps, "cheveux": "Hair_Long", "barbe": corps == "homme", "tenue": {"tunique": Color.WHITE, "pantalon": Color.WHITE, "bottes": Color.WHITE, "ceinture": Color.WHITE, "mante": Color.WHITE, "capuche": Color.WHITE}})
		root.add_child(r)
		var sq := r.find_child("Skeleton3D", true, false) as Skeleton3D
		var s: String = corps + " :"
		for os_ in ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "upperarm_l", "lowerarm_l", "hand_l", "thigh_l", "calf_l", "foot_l"]:
			var o := sq.get_bone_global_rest(sq.find_bone(os_)).origin
			s += " %s=(%.3f,%.3f,%.3f)" % [os_, o.x, o.y, o.z]
		print(s)
		for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
			var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var lo := Vector3(9, 9, 9)
			var hi := Vector3(-9, -9, -9)
			for p in v:
				lo = lo.min(p)
				hi = hi.max(p)
			print("  %-16s tris=%5d x[%.2f,%.2f] y[%.2f,%.2f] z[%.2f,%.2f] vis=%s" % [mi.name, v.size() / 3, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z, mi.visible])
		r.free()
	quit()
