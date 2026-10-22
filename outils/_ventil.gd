extends SceneTree
func _init() -> void:
	var g := GardienNordique.creer({})
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible: continue
		for s in mi.mesh.get_surface_count():
			var n: int = (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
			print(mi.name, " s", s, " ", n)
	quit()
