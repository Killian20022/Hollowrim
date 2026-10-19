extends SceneTree
## Positions (repère caméra) des épaules, mains et cibles des vrais bras.
const SCENE := preload("res://scenes/foret_test.tscn")
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	for i in 30:
		await process_frame
	var mains = m.joueur.mains
	var cam: Camera3D = m.joueur.camera
	var sq: Skeleton3D = mains._sq
	var inv := cam.global_transform.affine_inverse()
	for os in ["Head", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r", "upperarm_l", "hand_l"]:
		var g: Vector3 = sq.global_transform * sq.get_bone_global_pose(sq.find_bone(os)).origin
		print(os, " pose=", (inv * g).snapped(Vector3.ONE * 0.01))
	print("cible épée (pivot) ", (inv * mains.pivot_epee.global_position).snapped(Vector3.ONE * 0.01))
	print("cible torche ", (inv * mains.pivot_torche.global_position).snapped(Vector3.ONE * 0.01))
	print("bras transform ", mains.bras.transform)
	for c in sq.get_children():
		if c is TwoBoneIK3D:
			print("IK actif=", c.active, " influence=", c.influence, " n=", c.get_setting_count(), " racine=", c.get_root_bone(0), " milieu=", c.get_middle_bone(0), " bout=", c.get_end_bone(0), " cible=", c.get_target_node(0), " -> ", c.get_node_or_null(c.get_target_node(0)), " pole=", c.get_node_or_null(c.get_pole_node(0)))
		if c is SkeletonModifier3D:
			print("modificateur ", c.get_class(), " ", c.name)
	print("mode de rappel ", sq.modifier_callback_mode_process)
	quit()
