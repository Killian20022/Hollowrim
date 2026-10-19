extends SceneTree
## Profil de l'épée le long de Y (largeur en X par tranche) : où sont pommeau, poignée, garde.
func _init() -> void:
	var e: Node3D = load("res://assets/modeles/joueur/epee_nordique.glb").instantiate()
	root.add_child(e)
	var tranches := {}
	for mi: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
		var xf := e.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var nom := mi.mesh.surface_get_material(s).resource_name if mi.mesh.surface_get_material(s) else "?"
			for v: Vector3 in arr[Mesh.ARRAY_VERTEX]:
				var p := xf * v
				var k := int(floor(p.y / 0.02))
				var t: Array = tranches.get(k, [99.0, -99.0, 99.0, -99.0, {}])
				t[0] = minf(t[0], p.x); t[1] = maxf(t[1], p.x); t[2] = minf(t[2], p.z); t[3] = maxf(t[3], p.z)
				t[4][nom] = true
				tranches[k] = t
	var ks := tranches.keys()
	ks.sort()
	for k in ks:
		var t: Array = tranches[k]
		if k > 12: continue
		print("y=%.2f  x[%.3f %.3f] z[%.3f %.3f] %s" % [k * 0.02, t[0], t[1], t[2], t[3], t[4].keys()])
	quit()
