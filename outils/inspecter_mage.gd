extends SceneTree
## Outil (mage) : débogage de la jupe dynamique (anneau 6 en Idle t=0,75 autour de la jambe droite).
func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var g := MageNordique.creer({})
	root.add_child(g)
	var sq := g.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := g.get_node("Animations") as AnimationPlayer
	ap.play("Idle")
	ap.seek(ap.get_animation("Idle").length * 0.75, true)
	var j := sq.get_node("jupe") as MageJupe
	var an := j.calculer()
	print("pelvis ", sq.get_bone_global_pose(sq.find_bone("pelvis")).origin, " calf_r ", sq.get_bone_global_pose(sq.find_bone("calf_r")).origin, " foot_r ", sq.get_bone_global_pose(sq.find_bone("foot_r")).origin)
	for k in [5, 6, 7]:
		var t := ""
		for i in range(8, 16):
			t += " %d:%s" % [i, (an[k][i] as Vector3).snapped(Vector3.ONE * 0.01)]
		print("anneau ", k, t)
	quit()
