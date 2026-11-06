extends SceneTree
## Liste les pièces (surfaces, triangles) d'un archétype : godot --headless --path . --script res://outils/dump_pieces_pnj.gd
func _init() -> void:
	for pair in [["guerrier", GuerrierNordique.creer({"casque": false, "bouclier": "", "epee": false, "avant_bras_nus": true})],
			["chasseresse_f", ChasseresseNordique.creer({"arc": false, "carquois": false, "couteau": false})],
			["chasseresse_h", ChasseresseNordique.creer({"corps": "homme", "arc": false, "carquois": false, "couteau": false})]]:
		print("== ", pair[0])
		var sq := (pair[1] as Node3D).find_child("Skeleton3D", true, false) as Skeleton3D
		for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", true, false):
			print("  ", mi.name, " vis=", mi.visible, " surf=", mi.mesh.get_surface_count() if mi.mesh else 0)
	quit()
