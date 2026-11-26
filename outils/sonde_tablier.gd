extends SceneTree
## [pnj/realisme_v1] matériau du tablier et de la robe (noirs en jeu ?)
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	CachePersos.actif = false
	for id in ["hab_paysanne_c", "hab_paysanne_a"]:
		var n := PnjNordique._creer(id)
		for nom in ["tablier", "robe", "tunique", "mante"]:
			var mi := n.find_child(nom, true, false) as MeshInstance3D
			if mi == null or not mi.visible: continue
			var m := mi.get_active_material(0) as ShaderMaterial
			var tx: Texture2D = m.get_shader_parameter("tex_base")
			var img := tx.get_image()
			var moy := Color(0,0,0)
			for k in 200:
				moy += img.get_pixel(k * 37 % img.get_width(), k * 53 % img.get_height()) / 200.0
			var ar := mi.mesh.surface_get_arrays(0)
			var nn := Vector3.ZERO
			for q: Vector3 in ar[Mesh.ARRAY_NORMAL]: nn += q
			var w: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = ar[Mesh.ARRAY_INDEX]
			var fz := 0.0
			for t in ix.size() / 3: fz += (w[ix[t*3+1]] - w[ix[t*3]]).cross(w[ix[t*3+2]] - w[ix[t*3]]).z
			print("   normale moy ", nn / w.size(), " enroulement z ", fz, " cull ", m.get_shader_parameter("decoupe"), " ", m.shader.resource_path)
			print(id, " ", nom, " ov=", mi.material_override != null, " teinte=", m.get_shader_parameter("teinte"), " moy=", moy, " col=", ar[Mesh.ARRAY_COLOR] != null, " gonfle=", m.get_shader_parameter("gonfle"))
			img.save_png("C:/Users/lopezk19/AppData/Local/Temp/t_%s_%s.png" % [id, nom])
		n.free()
	quit()
