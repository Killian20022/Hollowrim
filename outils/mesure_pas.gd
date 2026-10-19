extends SceneTree
## Vitesse du corps que suppose chaque animation de marche : à chaque image on prend le pied le plus bas
## (celui qui est au sol) et on mesure sa vitesse vers l'arrière dans le repère du corps (= vitesse du corps).
## godot --headless -s res://outils/mesure_pas.gd
func _initialize() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var h: Node3D = Humain.creer({"corps": "homme", "tenue": {}})
	root.add_child(h)
	var sq: Skeleton3D = h.find_child("Skeleton3D", true, false)
	var ap: AnimationPlayer = h.get_node("Animations")
	var n := 120
	for nom in ["Walk", "Walk_Formal", "Jog_Fwd", "Sprint", "Crouch_Fwd"]:
		var a := ap.get_animation(nom)
		ap.play(nom)
		ap.pause()
		var pts: Array = []
		for i in n + 1:
			ap.seek(a.length * i / n, true)
			ap.advance(0.0)
			await process_frame
			var l := sq.get_bone_global_pose(sq.find_bone("ball_l")).origin
			var r := sq.get_bone_global_pose(sq.find_bone("ball_r")).origin
			pts.append([l, r])
		var dt := a.length / n
		var vit: Array = []
		for i in n:
			for c in 2:
				var y0: float = pts[i][c].y
				var y1: float = pts[i + 1][c].y
				var autre: float = pts[i][1 - c].y
				if y0 < autre and y0 < 0.06 and y1 < 0.06:
					vit.append(-(pts[i + 1][c].z - pts[i][c].z) / dt)
		vit.sort()
		print("%s : durée %.3f s, %d images d'appui, vitesse du corps médiane %.2f m/s (min %.2f max %.2f)" % [nom, a.length, vit.size(), vit[vit.size() / 2] if vit.size() > 0 else 0.0, vit[0] if vit.size() > 0 else 0.0, vit[-1] if vit.size() > 0 else 0.0])
	quit()
