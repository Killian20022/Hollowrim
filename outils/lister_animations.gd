extends SceneTree
## Outil : liste les animations et la hiérarchie d'un modèle importé.
## godot --headless -s res://outils/lister_animations.gd -- res://chemin/modele.glb
func _init() -> void:
	var chemin: String = OS.get_cmdline_user_args()[0]
	var scene: Node = load(chemin).instantiate()
	_parcourir(scene, 0)
	for ap in scene.find_children("*", "AnimationPlayer", true, false):
		print("ANIMATIONS: ", " ".join(ap.get_animation_list()))
	quit()

func _parcourir(n: Node, niveau: int) -> void:
	if niveau < 4:
		var info := ""
		if n is MeshInstance3D:
			info = " aabb=" + str(n.get_aabb())
		print("  ".repeat(niveau), n.name, " (", n.get_class(), ")", info)
	for c in n.get_children():
		_parcourir(c, niveau + 1)
