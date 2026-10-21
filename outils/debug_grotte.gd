extends SceneTree
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var pere := Node3D.new()
	root.add_child(pere)
	var g := Grotte.creer(pere)
	for i in 4:
		await physics_frame
	var ss := g.get_world_3d().direct_space_state
	for z in [-89.0, -90.0, -90.5, -91.0, -91.5, -92.0, -92.5, -93.0, -94.0, -95.0]:
		var line := "z=%.1f :" % z
		for x in [-1.0, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0]:
			var p := g.to_global(Vector3(x, 0.0, z))
			var r0 := ss.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, -2.0, 0), p + Vector3(0, -9.0, 0)))
			line += " %6.2f" % ((r0["position"].y + 220.0) if not r0.is_empty() else 99.0)
		print(line)
	quit()
