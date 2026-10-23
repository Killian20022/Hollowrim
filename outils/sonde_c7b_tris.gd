extends SceneTree
## [C7b] Triangles du village par enfant direct (maillages + MultiMesh × instances) : où partent les primitives.
const SCENE := preload("res://scenes/foret_test.tscn")
func _init() -> void:
	_go.call_deferred()
func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t
func _compte(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and n.mesh != null:
		t += _tris(n.mesh)
	elif n is MultiMeshInstance3D and n.multimesh != null and n.multimesh.mesh != null:
		t += _tris(n.multimesh.mesh) * n.multimesh.instance_count
	for c in n.get_children():
		t += _compte(c)
	return t
func _go() -> void:
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 30:
		await process_frame
	var v: Node = m.village
	var groupes := {}
	var total := 0
	for c in v.get_children():
		var k := String(c.name).rstrip("0123456789").replace("@", "")
		var t := _compte(c)
		groupes[k] = groupes.get(k, 0) + t
		total += t
	var cles := groupes.keys()
	cles.sort_custom(func(a, b): return groupes[a] > groupes[b])
	for k in cles.slice(0, 25):
		print("TRIS %-30s %d" % [k, groupes[k]])
	print("TRIS TOTAL %d" % total)
	# détail par matière dans les groupes du bâti v2
	for gname in ["BatiV2_bas", "BatiV2_haut", "BatiV2_fermes"]:
		var g := v.get_node_or_null(gname)
		if g == null:
			continue
		for c in g.get_children():
			if c is MeshInstance3D:
				var mat = (c as MeshInstance3D).material_override
				var nom: String = mat.resource_name if mat != null and mat.resource_name != "" else str(mat.get_instance_id() if mat else 0)
				for k in v.get_property_list():
					if String(k.name).begins_with("m_") and v.get(k.name) == mat:
						nom = k.name
				print("MAT %s %-16s %d" % [gname, nom, _tris(c.mesh)])
	quit(0)
