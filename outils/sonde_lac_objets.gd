extends SceneTree
## C7c : objets (arbres, MultiMesh de rochers/touffes/cailloux, corps physiques) posés DANS le lac (sous -0,6 m dans LAC_RECT).
##   godot --headless --path . --script res://outils/sonde_lac_objets.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

func _init() -> void:
	_lancer.call_deferred()

func _dans(p: Vector3, m: Node) -> bool:
	return EauVillage.LAC_RECT.has_point(Vector2(p.x, p.z)) and m.hauteur(p.x, p.z) < EauVillage.LAC_NIVEAU + 0.05

func _lancer() -> void:
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 3:
		await process_frame
	var n := 0
	for t: Transform3D in m.arbres:
		if _dans(t.origin, m):
			n += 1
	print("arbres dans le lac : %d" % n)
	var par := {}
	for mmi: MultiMeshInstance3D in m.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := mmi.multimesh
		if mm == null:
			continue
		for i in mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count:
			var p := mmi.global_transform * mm.get_instance_transform(i).origin
			if _dans(p, m):
				var cle := String(mmi.get_parent().name) + "/" + String(mmi.name).left(24)
				par[cle] = int(par.get(cle, 0)) + 1
	print("instances MultiMesh dans le lac : ", par)
	var corps := {}
	for c: CollisionObject3D in m.find_children("*", "CollisionObject3D", true, false):
		if c is StaticBody3D and _dans(c.global_position, m):
			corps[String(c.get_parent().name)] = int(corps.get(String(c.get_parent().name), 0)) + 1
	print("corps statiques dans le lac : ", corps)
	quit(0)
