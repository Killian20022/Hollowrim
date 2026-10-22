extends SceneTree
## Compare les corps Humain homme / femme (os de la tête, du bassin, yeux, pièces) : godot --headless --script res://outils/mesure_corps.gd
func _init() -> void:
	for corps in ["homme", "femme"]:
		var h := Humain.creer({"corps": corps, "cheveux": "Hair_Long", "tenue": {"tunique": Color.WHITE, "pantalon": Color.WHITE, "bottes": Color.WHITE, "ceinture": Color.WHITE, "brassards": Color.WHITE, "mante": Color.WHITE, "pteruges": Color.WHITE}})
		var sq := h.find_child("Skeleton3D", true, false) as Skeleton3D
		for o in ["Head", "neck_01", "pelvis", "spine_03", "upperarm_l", "thigh_l", "foot_l"]:
			print(corps, " os ", o, " ", sq.get_bone_global_rest(sq.find_bone(o)).origin)
		for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
			var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var lo := Vector3(9, 9, 9)
			var hi := Vector3(-9, -9, -9)
			for p in v:
				lo = lo.min(p)
				hi = hi.max(p)
			print(corps, " ", mi.name, " ", v.size(), " ", lo, " ", hi, " visible=", mi.visible)
		h.free()
	quit()
