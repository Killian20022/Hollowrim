extends SceneTree
## Géométrie du poing fermé (pose des doigts des vrais bras) dans le repère de l'os hand_r.
const SCENE := preload("res://scenes/foret_test.tscn")
func _init() -> void:
	_go.call_deferred()
func _globale(sq: Skeleton3D, i: int) -> Transform3D:
	var t := Transform3D()
	while i >= 0:
		t = sq.get_bone_pose(i) * t
		i = sq.get_bone_parent(i)
	return t
func _go() -> void:
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	for i in 10:
		await process_frame
	var sq: Skeleton3D = m.joueur.mains._sq
	var main := _globale(sq, sq.find_bone("hand_l"))
	var inv := main.affine_inverse()
	for d in ["thumb", "index", "middle", "ring", "pinky"]:
		var l := ""
		for k in ["01", "02", "03"]:
			var i := sq.find_bone("%s_%s_l" % [d, k])
			if i >= 0:
				l += "  %s=%s" % [k, (inv * _globale(sq, i).origin).snapped(Vector3.ONE * 0.001)]
		print(d, l)
	print("PRISE_D ", m.joueur.mains.PRISE_D, "\nPRISE_G ", m.joueur.mains.PRISE_G)
	quit()
