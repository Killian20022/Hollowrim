extends SceneTree
## Prise de l'épée du garde en armure de verre, MESURÉE sur le poing posé par les clips :
##   godot --headless --path . --script res://outils/prise_verre.gd
## Les clips des humains referment les doigts en poing (même pose dans tous les clips). Pour chaque doigt, le cercle passant par ses trois
## jointures (01, 02, 03), dans le plan perpendiculaire à l'axe des jointures, donne le creux du poing ; la poignée y passe, dans l'axe
## index -> auriculaire. Imprime le centre et l'axe dans le repère de hand_r (à reporter dans GardeTripo), et la poignée de l'épée.
func _init() -> void:
	_go.call_deferred()

func _cercle(a: Vector2, b: Vector2, c: Vector2) -> Array:
	var d := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(d) < 1e-9:
		return [a, 0.0]
	var ux := ((a.length_squared()) * (b.y - c.y) + (b.length_squared()) * (c.y - a.y) + (c.length_squared()) * (a.y - b.y)) / d
	var uy := ((a.length_squared()) * (c.x - b.x) + (b.length_squared()) * (a.x - c.x) + (c.length_squared()) * (b.x - a.x)) / d
	var o := Vector2(ux, uy)
	return [o, (a - o).length()]

func _go() -> void:
	var g: Node3D = GardeTripo.creer("tripo_garde_verre", false)
	root.add_child(g)
	var sq: Skeleton3D = g.find_child("Skeleton3D", true, false)
	var ap: AnimationPlayer = g.get_node("Animations")
	var ih := sq.find_bone("hand_r")
	for nom in ["Idle", "Walk", "Sword_Idle", "Sword_Attack"]:
		ap.play(nom)
		ap.seek(0.4, true)
		await process_frame
		await process_frame
		var mh := sq.get_bone_global_pose(ih).affine_inverse()
		var P := func(n: String) -> Vector3: return mh * sq.get_bone_global_pose(sq.find_bone(n)).origin
		var axe: Vector3 = (P.call("index_01_r") - P.call("pinky_01_r")).normalized()
		var e1 := axe.cross(Vector3(1, 0, 0)).normalized()
		var e2 := axe.cross(e1).normalized()
		var somme := Vector3.ZERO
		var lig := ""
		for f in ["index", "middle", "ring", "pinky"]:
			var p1: Vector3 = P.call(f + "_01_r")
			var p2: Vector3 = P.call(f + "_02_r")
			var p3: Vector3 = P.call(f + "_03_r")
			var p4: Vector3 = P.call(f + "_04_leaf_r")
			var q := func(p: Vector3) -> Vector2: return Vector2(p.dot(e1), p.dot(e2))
			var cr: Array = _cercle(q.call(p1), q.call(p2), q.call(p3))
			var o: Vector2 = cr[0]
			var c3 := e1 * o.x + e2 * o.y + axe * ((p1 + p2 + p3) / 3.0).dot(axe)
			somme += c3
			lig += " %s r=%.3f bout->centre %.3f ;" % [f, cr[1], (q.call(p4) - o).length()]
		print("PRISE %s centre %s axe %s |%s" % [nom, somme / 4.0, axe, lig])
	var ep: Node3D = (GardeTripo.EPEE as PackedScene).instantiate()
	for mi: MeshInstance3D in ep.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			var ar := mi.mesh.surface_get_arrays(s)
			var bb := AABB()
			var V: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
			for i in V.size():
				bb = AABB(V[i], Vector3.ZERO) if i == 0 else bb.expand(V[i])
			print("EPEE surface %s : %s" % [mat.resource_name if mat else "?", mi.transform * bb])
	quit(0)
