extends SceneTree
## Mesure (m) des os de bras_fps.glb à l'échelle de l'arc (ECHELLE_BRAS) : avant-bras, main (poignet -> bout du majeur), largeur
## de paume, comparées à la poignée de l'arc. Règle de la skill : main ≈ 75-80 % de l'avant-bras.
func _init() -> void:
	var b: Node3D = load("res://assets/modeles/joueur/bras_fps.glb").instantiate()
	root.add_child(b)
	var sq: Skeleton3D = b.find_child("Skeleton3D", true, false)
	var e := ArcJoueur.ECHELLE_BRAS
	for c in ["l", "r"]:
		var g := func(n: String) -> Vector3: return sq.get_bone_global_rest(sq.find_bone("%s_%s" % [n, c])).origin
		var coude: Vector3 = g.call("lowerarm")
		var poignet: Vector3 = g.call("hand")
		var bout: Vector3 = g.call("middle_04_leaf")
		var largeur: float = (g.call("index_01") as Vector3).distance_to(g.call("pinky_01"))
		print("BRAS %s avant-bras %.1f cm main %.1f cm (%.0f %%) largeur paume %.1f cm" % [c, coude.distance_to(poignet) * e * 100, poignet.distance_to(bout) * e * 100, 100.0 * poignet.distance_to(bout) / coude.distance_to(poignet), largeur * e * 100])
	var mi: MeshInstance3D = b.find_children("*", "MeshInstance3D", true, false)[0]
	quit()
