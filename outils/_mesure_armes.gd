extends SceneTree
## Mesure (outil jetable) : AABB, nœuds, étendue Y par matériau des glb d'armes.
func _local(e: Node, n: Node) -> Transform3D:
	var t := Transform3D()
	while n != null and n != e:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
func _init() -> void:
	var fichiers: Array[String] = ["res://assets/modeles/armes/epees/metal.glb", "res://assets/modeles/armes/bouclier_nordique.glb"]
	for d in ["res://assets/modeles/armes/hybrides/", "res://assets/modeles/armes/cc0_essai/"]:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".glb"):
				fichiers.append(d + f)
	for f in fichiers:
		var e: Node3D = (load(f) as PackedScene).instantiate()
		var lignes := []
		for mi: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
			var t := _local(e, mi)
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				var v: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				var lo := Vector3.INF; var hi := -Vector3.INF
				for p in v:
					var q := t * p
					lo = lo.min(q); hi = hi.max(q)
				lignes.append("   %s x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f]" % [m.resource_name if m else "?", lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
		var noeuds := []
		for n in e.find_children("*", "Node3D", true, false):
			if not n is MeshInstance3D:
				noeuds.append("%s@%s" % [n.name, _local(e, n).origin.snapped(Vector3.ONE * 0.001)])
		print(f.get_file(), " noeuds=", noeuds)
		for l in lignes: print(l)
		e.free()
	quit()
