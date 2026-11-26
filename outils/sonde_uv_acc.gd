extends SceneTree
## [pnj/realisme_v1] histogramme des UV de la surface 1 (découpes) des accessoires
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	CachePersos.actif = false
	for id in ["hab_paysan_b", "hab_paysanne_a"]:
		var n := PnjNordique._creer(id)
		var mi := n.find_child("accessoires", true, false) as MeshInstance3D
		var ar := mi.mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = ar[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = ar[Mesh.ARRAY_INDEX]
		var h := {}
		for t in idx.size() / 3:
			var u := (uv[idx[t*3]] + uv[idx[t*3+1]] + uv[idx[t*3+2]]) / 3.0
			var vx: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
			var pc: Vector3 = (ar[Mesh.ARRAY_VERTEX][idx[t*3]] + ar[Mesh.ARRAY_VERTEX][idx[t*3+1]] + ar[Mesh.ARRAY_VERTEX][idx[t*3+2]]) / 3.0
			if pc.y < 1.3 or absf(pc.x) < 0.08: continue
			var k := "%d,%d" % [int(u.x * 256 / 16), int(u.y * 256 / 16)]
			h[k] = h.get(k, 0) + 1
		print(id, " ", h)
		var m := mi.get_active_material(1) as ShaderMaterial
		var tx: Texture2D = m.get_shader_parameter("tex_base")
		tx.get_image().save_png("C:/Users/lopezk19/AppData/Local/Temp/dec_" + id + ".png")
		var m0 := mi.get_active_material(0) as ShaderMaterial
		(m0.get_shader_parameter("tex_base") as Texture2D).get_image().save_png("C:/Users/lopezk19/AppData/Local/Temp/acc0_" + id + ".png")
		n.free()
	quit()
