extends SceneTree
## Outil : liste les matériaux et textures de chaque maillage d'un modèle.
func _init() -> void:
	for chemin in OS.get_cmdline_user_args():
		var scene: Node = load(chemin).instantiate()
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var m := mi.get_active_material(s)
				var t = m.albedo_texture if m is BaseMaterial3D else null
				print(chemin.get_file(), " ", mi.name, " surf", s, " ", m.get_class() if m else "aucun", " tex=", t.resource_path if t else "AUCUNE")
		scene.free()
	quit()
