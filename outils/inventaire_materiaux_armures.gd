extends SceneTree
## Inventaire des matériaux des glb d'armures (porte/, sol/, chausses/) : glb, nom du matériau, texture d'albédo, md5 de la source.
##   Godot --headless --path <projet> --script res://outils/inventaire_materiaux_armures.gd -- <sortie.tsv>
## Sert au dédoublonnage des textures identiques (outils/dedoublonner_textures_armures.py).
func _initialize() -> void:
	var sortie := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://materiaux_armures.tsv"
	var f := FileAccess.open(sortie, FileAccess.WRITE)
	for dossier: String in ["res://assets/modeles/armures/porte", "res://assets/modeles/armures/sol", "res://assets/modeles/armures/chausses"]:
		for nom in DirAccess.get_files_at(dossier):
			if nom.get_extension() != "glb":
				continue
			var chemin := dossier.path_join(nom)
			var ps := load(chemin) as PackedScene
			if ps == null:
				printerr("illisible : ", chemin)
				continue
			var inst := ps.instantiate()
			var vus := {}
			for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
				for s in mi.mesh.get_surface_count():
					var m := mi.mesh.surface_get_material(s)
					if m == null or vus.has(m.resource_name):
						continue
					vus[m.resource_name] = true
					var tex: Texture2D = (m as BaseMaterial3D).albedo_texture if m is BaseMaterial3D else null
					var tp := tex.resource_path if tex else ""
					var autres := ""
					if m is BaseMaterial3D:
						var b := m as BaseMaterial3D
						for t in [b.normal_texture, b.roughness_texture, b.metallic_texture, b.emission_texture, b.ao_texture]:
							if t != null:
								autres += t.resource_path + ";"
					f.store_line("\t".join([chemin, m.resource_name, tp, FileAccess.get_md5(tp) if tp != "" else "", autres, m.get_class()]))
			inst.free()
	f.close()
	print("INVENTAIRE OK ", sortie)
	quit(0)
