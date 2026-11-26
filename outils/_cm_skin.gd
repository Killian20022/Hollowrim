extends SceneTree
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	var c: Node3D = GardeMaison.creer(CrypteDonjon.COMPAGNON)
	root.add_child(c)
	await process_frame
	await process_frame
	var sq := c.find_child("Skeleton3D", true, false) as Skeleton3D
	sq.force_update_all_bone_transforms()
	print("scale ", c.scale, " sq ", sq.global_transform)
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible or mi.mesh == null:
			continue
		var sk := mi.skin
		var mn := INF
		var mn2 := INF
		for s in mi.mesh.get_surface_count():
			var ar := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
			var bo: Variant = ar[Mesh.ARRAY_BONES]
			var we: Variant = ar[Mesh.ARRAY_WEIGHTS]
			mn2 = minf(mn2, (mi.global_transform * vs[0]).y)
			if sk == null or not (bo is PackedInt32Array):
				for v in vs:
					mn2 = minf(mn2, (mi.global_transform * v).y)
				continue
			var k := (bo as PackedInt32Array).size() / vs.size()
			for i in vs.size():
				var acc := Vector3.ZERO
				for j in k:
					var w: float = (we as PackedFloat32Array)[i * k + j]
					if w <= 0.0: continue
					var bi: int = (bo as PackedInt32Array)[i * k + j]
					var bone := sk.get_bind_bone(bi)
					if bone < 0: bone = sq.find_bone(sk.get_bind_name(bi))
					acc += (sq.global_transform * sq.get_bone_global_pose(bone) * sk.get_bind_pose(bi) * vs[i]) * w
				mn = minf(mn, acc.y)
		print("MI %-16s skin=%s k? min_skin=%.3f min_rigide=%.3f parent=%s xf=%s" % [mi.name, sk != null, mn, mn2, mi.get_parent().name, mi.transform.origin])
	quit(0)
