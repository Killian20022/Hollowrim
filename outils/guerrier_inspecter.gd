extends SceneTree
## Outil (guerrier pilote) : inventaire des maillages d'un modèle : triangles, AABB, surfaces.
func _init() -> void:
	for chemin in OS.get_cmdline_user_args():
		var scene: Node = load(chemin).instantiate()
		for sq in scene.find_children("*", "Skeleton3D", true, false):
			print("OS ", sq.get_bone_count())
			for i in sq.get_bone_count():
				var r: Transform3D = sq.get_bone_global_rest(i)
				print("  ", i, " ", sq.get_bone_name(i), " parent=", sq.get_bone_parent(i), " pos=", r.origin)
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			var t := 0
			for s in mi.mesh.get_surface_count():
				var a := mi.mesh.surface_get_arrays(s)
				t += (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] else a[Mesh.ARRAY_VERTEX].size()) / 3
			print("MAILLAGE ", mi.name, " tris=", t, " surf=", mi.mesh.get_surface_count(), " aabb=", mi.get_aabb(), " mat0=", mi.get_active_material(0).resource_name if mi.get_active_material(0) else "")
		scene.free()
	quit()
