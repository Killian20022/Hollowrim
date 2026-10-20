extends SceneTree
## Outil : axes et étendue de l'épée tenue dans la main droite au repos (pour modeler l'arc dans le même repère).
func _init() -> void:
	var m: Node3D = load("res://assets/modeles/humains/homme_vetu.glb").instantiate()
	var sq: Skeleton3D = m.find_child("Skeleton3D", true, false)
	var d = load("res://scripts/draugr.gd").new()
	var prise: Transform3D = d.prise
	var epee: Node3D = load("res://assets/modeles/joueur/epee_nordique.glb").instantiate()
	var g := sq.get_bone_global_rest(sq.find_bone("hand_r"))
	var tris := 0
	for mi in epee.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = (mi as MeshInstance3D).get_aabb()
		print("epee ", mi.name, " aabb=", aabb, " surf=", mi.mesh.get_surface_count())
		for s in mi.mesh.get_surface_count():
			var arr = mi.mesh.surface_get_arrays(s)
			tris += (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
	print("epee tris=", tris)
	var w := g * prise
	print("hand_r rest origin(godot)=", g.origin, " prise origin in model=", w.origin)
	print("axes in model (godot): x=", w.basis.x, " y=", w.basis.y, " z=", w.basis.z)
	quit()
