extends SceneTree
## PrimGeo.boite / PrimGeo.cylindre = BoxMesh / CylinderMesh du moteur (sommets, normales, UV, indices).
##   godot --headless --path . --script res://outils/test_primitives.gd
var ok := true

func _init() -> void:
	for t in [Vector3(2, 4, 6), Vector3(0.07, 0.07, 0.07), Vector3(5.2, 0.22, 0.26), Vector3(1, 1, 1)]:
		var b := BoxMesh.new()
		b.size = t
		_comparer("boite %s" % t, b.get_mesh_arrays(), PrimGeo.boite(t))
	for c in [[0.5, 1.0, 2.0, 4], [0.3, 0.3, 0.9, 8], [0.1, 0.1, 1.6, 6], [0.0, 0.4, 1.0, 6], [0.4, 0.0, 1.0, 8], [0.05, 0.062, 0.34, 6], [0.38, 0.38, 0.06, 8]]:
		var m := CylinderMesh.new()
		m.top_radius = c[0]
		m.bottom_radius = c[1]
		m.height = c[2]
		m.radial_segments = c[3]
		m.rings = 1
		_comparer("cylindre %s" % [c], m.get_mesh_arrays(), PrimGeo.cylindre(c[0], c[1], c[2], c[3]))
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.center_offset = Vector3(0, 0.5, 0)
	_comparer("plan", q.get_mesh_arrays(), PrimGeo.plan(Vector2(1, 1), Vector3(0, 0.5, 0)))
	print("test_primitives : ", "TOUT OK" if ok else "ECHEC")
	quit(0 if ok else 1)

func _comparer(nom: String, ref: Array, moi: Array) -> void:
	var pire := 0.0
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV]:
		var a: Array = ref[k]
		var b: Array = moi[k]
		if a.size() != b.size():
			print("ECHEC %s : tableau %d taille %d != %d" % [nom, k, a.size(), b.size()])
			ok = false
			return
		for i in a.size():
			var d := 0.0
			if k == Mesh.ARRAY_TEX_UV:
				d = (a[i] as Vector2).distance_to(b[i])
			else:
				d = (a[i] as Vector3).distance_to(b[i])
			if d > 1e-4 and pire <= 1e-4:
				print("  1er ecart %s k=%d i=%d ref=%s moi=%s" % [nom, k, i, a[i], b[i]])
			pire = maxf(pire, d)
	if pire > 1e-4:
		print("ECHEC %s : ecart max %.6f" % [nom, pire])
		ok = false
	if ref[Mesh.ARRAY_INDEX] != moi[Mesh.ARRAY_INDEX]:
		print("ECHEC %s : indices differents" % nom)
		ok = false
	if ok:
		print("OK %s (ecart max %f)" % [nom, pire])
