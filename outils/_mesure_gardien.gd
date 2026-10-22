extends SceneTree
## Mesure jetable : triangles par piece du gardien et bornes en y de quelques pieces de Humain.
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var app := {"corps": "homme", "barbe": true, "cheveux": "Hair_Long", "tenue": {"tunique": Color.WHITE, "pantalon": Color.WHITE, "bottes": Color.WHITE, "ceinture": Color.WHITE, "brassards": Color.WHITE, "cape": Color.WHITE, "mante": Color.WHITE, "tablier": Color.WHITE, "epaulieres": Color.WHITE}}
	var h := Humain.creer(app)
	var sq := h.find_child("Skeleton3D", true, false) as Skeleton3D
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var y0 := 9.0
		var y1 := -9.0
		var xm := 0.0
		for p in v:
			y0 = minf(y0, p.y); y1 = maxf(y1, p.y); xm = maxf(xm, absf(p.x))
		print("%s : %d tris, y %.3f..%.3f, |x|max %.3f" % [mi.name, (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, y0, y1, xm])
	var g := GardienNordique.creer({})
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible:
			continue
		for s in mi.mesh.get_surface_count():
			print("G %s s%d : %d tris" % [mi.name, s, mi.mesh.surface_get_array_index_len(s) / 3])
	quit()
