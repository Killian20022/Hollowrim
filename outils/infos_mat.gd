extends SceneTree
func _init() -> void:
	for chemin in OS.get_cmdline_user_args():
		var s: Node = load(chemin).instantiate()
		for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
			var m := mi.get_active_material(0) as BaseMaterial3D
			print(chemin.get_file(), " ", mi.name, " mat=", m.resource_name if m else "", " transp=", m.transparency if m else -1, " tex=", (m.albedo_texture.resource_path.get_file() if m and m.albedo_texture else ""), " skin=", mi.skin != null, " bindnames=", (mi.skin.get_bind_name(0) if mi.skin and mi.skin.get_bind_count() > 0 else ""))
		s.free()
	quit()
