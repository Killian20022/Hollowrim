extends SceneTree
func _init() -> void:
	for id in ["cuirasse_verre"]:
		var mi := ArmureVisible.charger_porte(id)
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			var tex: Texture2D = m.get_shader_parameter("tex_base")
			var img := tex.get_image()
			if img.is_compressed(): img.decompress()
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var col = a[Mesh.ARRAY_COLOR]
			var somme := Color(0,0,0,0)
			for k in range(0, uv.size(), max(1, uv.size() / 50)):
				somme += img.get_pixelv(Vector2i(clampi(int(uv[k].x * img.get_width()), 0, img.get_width()-1), clampi(int(uv[k].y * img.get_height()), 0, img.get_height()-1)))
			print(s, " ", mi.mesh.surface_get_material(s).resource_name if mi.mesh.surface_get_material(s) else "?", " -> ", m.resource_name, " tex ", tex.get_size(), " couleur moy ", somme / 51.0, " col ", col != null and (col as PackedColorArray).size() > 0)
	quit()
