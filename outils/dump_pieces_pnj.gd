extends SceneTree
## [pnj/realisme_v1] Liste des pièces d'un PNJ (nom, surfaces, triangles, visible, boîte, texture) : -- --ids=a,b
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	CachePersos.actif = false
	var ids := "hab_paysan_c,hab_paysanne_b,forgeron,volva".split(",")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ids="):
			ids = a.substr(6).split(",")
	for id in ids:
		var n := PnjNordique._creer(id)
		print("== ", id)
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null: continue
			var s: String = ""
			for k in mi.mesh.get_surface_count():
				var t: int = mi.mesh.surface_get_array_index_len(k) / 3
				var m := mi.get_active_material(k) as ShaderMaterial
				var tx: Texture2D = m.get_shader_parameter("tex_base") if m else null
				s += " s%d:%dtri tex=%s%s" % [k, t, (str(tx.get_width()) + "x" + str(tx.get_height())) if tx else "-", " dec" if m and m.get_shader_parameter("decoupe") else ""]
			var bb: AABB = mi.get_aabb()
			print("  %-28s vis=%s par=%s aabb=%s/%s%s" % [mi.name, mi.is_visible_in_tree(), mi.get_parent().name, bb.position.snapped(Vector3.ONE*0.01), bb.size.snapped(Vector3.ONE*0.01), s])
		n.free()
	quit()
