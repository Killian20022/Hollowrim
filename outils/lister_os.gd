extends SceneTree
## Outil : liste les os d'un modèle et la taille des maillages d'une arme.
func _init() -> void:
	for chemin in OS.get_cmdline_user_args():
		var scene: Node = load(chemin).instantiate()
		for sq in scene.find_children("*", "Skeleton3D", true, false):
			var noms := []
			for i in sq.get_bone_count():
				noms.append(sq.get_bone_name(i))
			print(chemin, " OS: ", ", ".join(noms))
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			print(chemin, " MAILLAGE ", mi.name, " ", mi.get_aabb())
		scene.free()
	quit()
