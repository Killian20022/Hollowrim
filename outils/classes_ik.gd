extends SceneTree
func _init() -> void:
	var m := []
	for f in ClassDB.class_get_method_list("SkeletonModifier3D", true):
		m.append(f.name)
	print("SkeletonModifier3D : ", m)
	var p := []
	for f in ClassDB.class_get_method_list("IKModifier3D", true):
		p.append(f.name)
	print("IKModifier3D : ", p)
	quit()
