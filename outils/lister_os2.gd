extends SceneTree
## Outil : arborescence complète (5 niveaux), os et pistes d'animation d'un modèle.
func _init() -> void:
	for chemin in OS.get_cmdline_user_args():
		var scene: Node = load(chemin).instantiate()
		_parcourir(scene, 0)
		for sq in scene.find_children("*", "Skeleton3D", true, false):
			var noms := []
			for i in sq.get_bone_count():
				noms.append(sq.get_bone_name(i))
			print("OS (", noms.size(), "): ", ", ".join(noms))
		for ap: AnimationPlayer in scene.find_children("*", "AnimationPlayer", true, false):
			var a := ap.get_animation(ap.get_animation_list()[1])
			print("PISTES ex : ", a.track_get_path(0), " | ", a.track_get_path(1), " racine=", ap.root_node)
		scene.free()
	quit()

func _parcourir(n: Node, niveau: int) -> void:
	if niveau < 6:
		var info := ""
		if n is MeshInstance3D:
			info = " aabb=" + str(n.get_aabb()) + " surf=" + str(n.mesh.get_surface_count())
		print("  ".repeat(niveau), n.name, " (", n.get_class(), ")", info)
	for c in n.get_children():
		_parcourir(c, niveau + 1)
