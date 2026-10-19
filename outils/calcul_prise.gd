extends SceneTree
## Calcule la prise d'une épée dans la main droite : lame selon l'axe auriculaire → index,
## poignée au creux des doigts (repère local de l'os hand_r).
func _init() -> void:
	var h: Node3D = load("res://assets/modeles/humains/homme_vetu.glb").instantiate()
	root.add_child(h)
	var sq: Skeleton3D = h.find_child("Skeleton3D", true, false)
	var p := func(n: String) -> Vector3: return sq.get_bone_global_rest(sq.find_bone(n)).origin
	var main: Transform3D = sq.get_bone_global_rest(sq.find_bone("hand_r"))
	var index: Vector3 = p.call("index_01_r")
	var auri: Vector3 = p.call("pinky_01_r")
	var milieu: Vector3 = p.call("middle_01_r")
	var bout: Vector3 = p.call("middle_03_r")
	var lame := (index - auri).normalized()
	var doigts := (bout - milieu).normalized()
	var z := doigts - lame * doigts.dot(lame)
	z = z.normalized()
	var x := lame.cross(z)
	var poignee := (index + auri) * 0.5 + doigts * 0.035
	var monde := Transform3D(Basis(x, lame, z), poignee)
	var local := main.affine_inverse() * monde
	print("PRISE = Transform3D(Basis(Vector3", local.basis.x, ", Vector3", local.basis.y, ", Vector3", local.basis.z, "), Vector3", local.origin, ")")
	quit()
