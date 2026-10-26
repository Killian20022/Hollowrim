extends SceneTree
## Sonde (piège du moulin) : formes de collision et lancers de sphère à travers la grille d'eau ouest.
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 8:
		await physics_frame
	var esp := m.get_world_3d().direct_space_state
	var c := Vector3(19.3, 0.5, 60.8)
	var p := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new(); s.radius = 1.2
	p.shape = s; p.transform = Transform3D(Basis(), c)
	for h in esp.intersect_shape(p, 64):
		var o: CollisionObject3D = h.collider
		var sh: Node = o.shape_owner_get_owner(o.shape_find_owner(h.shape))
		var g: Vector3 = (sh as Node3D).global_position if sh is Node3D else Vector3.ZERO
		var desc := ""
		if sh is CollisionShape3D:
			var f: Shape3D = sh.shape
			desc = f.get_class()
			if f is CylinderShape3D: desc += " r%.2f h%.2f" % [f.radius, f.height]
		print("FORME ", o.get_path(), " ", sh.name, " ", desc, " en ", g)
	var sq := PhysicsShapeQueryParameters3D.new()
	var sp := SphereShape3D.new(); sp.radius = 0.2
	sq.shape = sp
	for e in [[Vector2(19.5, 61), Vector2(19, 61)], [Vector2(19.5, 60.5), Vector2(19, 60.5)], [Vector2(19.5, 61), Vector2(19, 61.5)], [Vector2(19.5, 60), Vector2(19, 60.5)]]:
		for y in [0.0, 0.5, 1.3]:
			sq.transform = Transform3D(Basis(), Vector3(e[0].x, y, e[0].y))
			sq.motion = Vector3(e[1].x - e[0].x, 0, e[1].y - e[0].y)
			print("CAST ", e, " y ", y, " -> ", esp.cast_motion(sq))
	quit()
