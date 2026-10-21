extends SceneTree
## Répartition des triangles et surfaces du Mage nordique par pièce (diagnostic).
##   godot --headless --path . --script res://outils/tris_mage.gd
func _init() -> void:
	var g := MageNordique.creer({})
	root.add_child(g)
	var tot := 0
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			var n: int = (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
			tot += n
			print("%-20s s%d %5d" % [mi.name, s, n])
	print("TOTAL ", tot)
	quit()
