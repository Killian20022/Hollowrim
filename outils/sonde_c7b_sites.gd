extends SceneTree
## [C7b] Cherche des emplacements peu pentus pour les fermes et le moulin à vent (hors enceinte) : écart de hauteur sur
## l'emprise (+0,8 m) et nombre d'arbres, sur une grille de 1 m autour du point du plan.
const SCENE := preload("res://scenes/foret_test.tscn")
const CAS := [["GA", 87, 27, 7, 5, 90], ["GA", 86, 20, 7, 5, 90], ["MV", 90, 38, 5.5, 5.5, 0], ["MV", 90, 14, 5.5, 5.5, 0], ["FB", 61, 3.5, 8, 5, 0], ["GB", 67.5, 6, 6, 5, 90]]

func _init() -> void:
	_go.call_deferred()

func _ecart(m: Node3D, x: float, z: float, l: float, w: float, a: float) -> Vector2:
	var bas := Basis(Vector3.UP, a)
	var mn := INF
	var mx := -INF
	for i in 5:
		for j in 5:
			var c := Vector3(x, 0, z) + bas * Vector3((i / 4.0 - 0.5) * (l + 1.6), 0, (j / 4.0 - 0.5) * (w + 1.6))
			var h := DetailsSol.hauteur_maillage(m, c.x, c.z)
			mn = minf(mn, h)
			mx = maxf(mx, h)
	return Vector2(mn, mx)

func _go() -> void:
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 3:
		await process_frame
	for b in CAS:
		var res: Array = []
		for dx in range(-6, 7):
			for dz in range(-6, 7):
				var x := float(b[1]) + dx
				var z := float(b[2]) + dz
				if absf(x) > 96.0 or absf(z) > 96.0 or ReliefVillage.distance_palissade(x, z) < 6.0:
					continue
				var e := _ecart(m, x, z, b[3], b[4], deg_to_rad(float(b[5])))
				var arbres := 0
				for t: Transform3D in m.arbres:
					if Vector2(t.origin.x - x, t.origin.z - z).length() < maxf(b[3], b[4]) * 0.5 + 1.5:
						arbres += 1
				res.append([e.y - e.x, Vector2(dx, dz).length(), x, z, e.x, e.y, arbres])
		res.sort_custom(func(p: Array, q: Array) -> bool: return p[0] + p[1] * 0.08 + p[6] * 0.3 < q[0] + q[1] * 0.08 + q[6] * 0.3)
		for k in 6:
			var r: Array = res[k]
			print("%s cand (%.0f;%.0f) ecart %.2f (h %.2f..%.2f) dist %.1f arbres %d" % [b[0], r[2], r[3], r[0], r[4], r[5], r[1], r[6]])
	quit(0)
