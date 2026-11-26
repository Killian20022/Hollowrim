extends SceneTree
## [pnj/realisme_v1] quelles pièces ont des triangles à hauteur d'épaule hors du corps (pointes du col)
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	CachePersos.actif = false
	for id in ["hab_paysan_b", "hab_paysanne_a"]:
		var n := PnjNordique._creer(id)
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or not mi.is_visible_in_tree(): continue
			for s in mi.mesh.get_surface_count():
				var ar := mi.mesh.surface_get_arrays(s)
				var v: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
				var c := 0
				for p in v:
					if p.y > 1.3 and p.y < 1.6 and absf(p.x) > 0.12 and absf(p.x) < 0.45:
						c += 1
				if c > 0:
					print(id, " ", mi.name, " s", s, " ", c, "/", v.size())
		n.free()
	quit()
