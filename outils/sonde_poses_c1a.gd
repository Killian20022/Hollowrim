extends SceneTree
## C1a : cherche des poses de capture dégagées (pas d'arbre devant) à l'ouest / au nord, avec roche + chemin + neige en vue.
##   godot --headless --path . --script res://outils/sonde_poses_c1a.gd -- --nouvelle
var monde: Node3D
func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	monde = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(monde)
	for k in 5:
		await process_frame
	var carte: Image = (load("res://assets/sol/carte_sol.res") as Texture2D).get_image() if load("res://assets/sol/carte_sol.res") is Texture2D else load("res://assets/sol/carte_sol.res")
	var arb: Array = []
	for a: Transform3D in monde.arbres:
		arb.append(Vector2(a.origin.x, a.origin.z))
	var res := []
	var x := -110.0
	while x < 60.0:
		var z := -110.0
		while z < 60.0:
			var ouest := x < -58.0 and z > -64.0
			var nord := z < -64.0
			if (ouest or nord) and Vector2(x, z).length() < 100.0:
				for lac in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
					var y := deg_to_rad(lac)
					var f := Vector2(-sin(y), -cos(y))
					var ok := true
					for t: Vector2 in arb:
						var d := t - Vector2(x, z)
						var l := d.length()
						if l < 2.5 or (l < 9.0 and d.dot(f) > 0.0 and absf(d.normalized().dot(Vector2(f.y, -f.x))) < 0.75):
							ok = false
							break
					if not ok:
						continue
					var cnt := {}
					for s in range(2, 14):
						for o in range(-4, 5):
							var p := Vector2(x, z) + f * s + Vector2(f.y, -f.x) * o * s * 0.12
							var i := int((p.x + 120.0) / 0.25)
							var j := int((p.y + 120.0) / 0.25)
							if i < 0 or j < 0 or i >= 960 or j >= 960:
								continue
							var m := int(carte.get_pixel(i, j).r8) >> 4
							cnt[m] = cnt.get(m, 0) + 1
					var sc: float = minf(cnt.get(5, 0), 40) * 1.0 + minf(cnt.get(2, 0) + cnt.get(1, 0), 30) * 1.0 + minf(cnt.get(0, 0) + cnt.get(7, 0), 30) * 0.5 + minf(cnt.get(4, 0), 15)
					res.append([sc, "N" if nord else "O", x, z, lac, cnt])
			z += 4.0
		x += 4.0
	res.sort_custom(func(a, b): return a[0] > b[0])
	var vus := {}
	for r in res:
		var k := "%s%d%d" % [r[1], int(r[2] / 16.0), int(r[3] / 16.0)]
		if vus.has(k):
			continue
		vus[k] = 1
		print("POSE %s %.0f,%.0f lacet=%.0f score=%.0f %s" % [r[1], r[2], r[3], r[4], r[0], str(r[5])])
	quit(0)
