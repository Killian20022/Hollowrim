extends SceneTree
## Sonde : direction de la lame (repère du squelette) selon l'inclinaison INCL, par clip. godot --headless --script res://outils/sonde_arme_tripo.gd -- --ennemis-tripo
const CLIPS := ["Sword_Idle", "Walk", "Jog_Fwd", "Sword_Attack", "Zombie_Attente", "Zombie_Marche", "Idle"]
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	for id: String in ["draugr", "squelette", "gobelin"]:
		var n := EnnemiTripo.creer(id, "")
		root.add_child(n)
		var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
		var ap := n.get_node("Animations") as AnimationPlayer
		var m := sq.find_bone("hand_r")
		for clip: String in CLIPS:
			if not ap.has_animation(clip):
				continue
			var ln := ap.get_animation(clip).length
			var lignes := ""
			for incl in [-90, -60, -35, -15, 0, 20, 45]:
				var bs := Basis(Vector3.RIGHT, deg_to_rad(float(incl))) * EnnemiTripo.PRISE.basis
				var ys: Array = []
				var zs: Array = []
				var t := 0.0
				while t < ln:
					ap.play(clip)
					ap.seek(t, true)
					sq.advance(0.0)
					var d: Vector3 = (sq.get_bone_global_pose(m).basis * bs.y).normalized()
					ys.append(d.y)
					zs.append(d.z)
					t += ln / 8.0
				var sy := 0.0
				var sz := 0.0
				for v: float in ys: sy += v
				for v: float in zs: sz += v
				lignes += "  [%d: y=%.2f(%.2f..%.2f) z=%.2f(%.2f..%.2f)]" % [incl, sy / ys.size(), ys.min(), ys.max(), sz / zs.size(), zs.min(), zs.max()]
			print(id, " ", clip, lignes)
		n.queue_free()
	quit()
