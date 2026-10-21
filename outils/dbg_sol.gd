extends SceneTree
const SCENE := preload("res://scenes/foret_test.tscn")
func _init() -> void:
	_t.call_deferred()
func _t() -> void:
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await physics_frame
	m.tertre.attendre_donjon()
	for i in 5:
		await physics_frame
	var c: Node3D = m.tertre.crypte
	var ss: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.7
	for x in [-23.0, -23.5, -24.0, -24.5, -25.0, -25.5, -26.0, -27.0, -28.0, -29.0]:
		var a := c.to_global(Vector3(x, -5.0, -43.0))
		var r: Dictionary = ss.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + Vector3(0, -2.3, 0)))
		var ys := NAN if r.is_empty() else c.to_local(r["position"]).y
		var qp := PhysicsShapeQueryParameters3D.new()
		qp.shape = cap
		qp.transform = Transform3D(Basis(), c.to_global(Vector3(x, ys + 0.13 + 0.85, -43.0)))
		var hits := ss.intersect_shape(qp, 3)
		print("x=", x, " sol=", ys, " n=", hits.size(), " ", "" if hits.is_empty() else str((hits[0]["collider"] as Node).get_path()), " ", "" if hits.is_empty() else str(hits[0]["shape"]))
	quit()
