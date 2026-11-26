extends SceneTree
## Sonde : maillages et matières du corps du compagnon d'Eirik (crypte_donjon.gd COMPAGNON) ; textures absentes = « blanc ».
func _initialize() -> void:
	await process_frame
	var c: Node3D = GardeMaison.creer({"role": "epee", "ensemble": "fer", "tabard": "", "arme": "", "bouclier": "", "poil": 2, "peau": 1})
	root.add_child(c)
	await process_frame
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		var info := []
		var n := mi.mesh.get_surface_count() if mi.mesh else 0
		for s in n:
			var m: Material = mi.material_override if mi.material_override else (mi.get_surface_override_material(s) if mi.get_surface_override_material(s) else mi.mesh.surface_get_material(s))
			var tex: Variant = null
			if m is ShaderMaterial:
				for p in ["tex", "texture", "albedo", "tex_base", "albedo_texture"]:
					var v: Variant = (m as ShaderMaterial).get_shader_parameter(p)
					if v != null:
						tex = "%s=%s" % [p, v]
						break
			elif m is StandardMaterial3D:
				tex = (m as StandardMaterial3D).albedo_texture
			info.append("%s %s" % [m.get_class() if m else "null", tex])
		if not mi.visible or mi.mesh == null:
			continue
		var am := 0.0
		var nb := 0
		for s2 in mi.mesh.get_surface_count():
			var ar := mi.mesh.surface_get_arrays(s2)
			var cols: Variant = ar[Mesh.ARRAY_COLOR]
			if cols is PackedColorArray:
				for col in cols:
					am += col.a
					nb += 1
		var m0: Material = mi.material_override if mi.material_override else mi.get_active_material(0)
		var tn: Variant = (m0 as ShaderMaterial).get_shader_parameter("tex_neige") if m0 is ShaderMaterial else null
		var sh: String = (m0 as ShaderMaterial).shader.resource_path if m0 is ShaderMaterial and (m0 as ShaderMaterial).shader else ""
		info.append("alpha_moy=%s tex_neige=%s shader=%s teinte=%s" % [(am / nb) if nb > 0 else -1.0, tn, sh, (m0 as ShaderMaterial).get_shader_parameter("teinte") if m0 is ShaderMaterial else null])
		if mi.name == "tunique" and m0 is ShaderMaterial:
			var tx: Texture2D = (m0 as ShaderMaterial).get_shader_parameter("tex_base")
			if tx:
				tx.get_image().save_png("C:/Users/lopezk19/Jeux/rendus/soir_2026-11-25/compagnon_mort/tex_tunique.png")
			for u in (m0 as ShaderMaterial).shader.get_shader_uniform_list():
				print("   U ", u["name"], " = ", (m0 as ShaderMaterial).get_shader_parameter(u["name"]))
		print("MI %s vis=%s tris=%d | %s" % [mi.name, mi.visible, (mi.mesh.get_faces().size() / 3) if mi.mesh else 0, " ; ".join(info)])
	quit(0)
