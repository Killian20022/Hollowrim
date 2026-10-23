extends SceneTree
## [C7b] Sonde des trous de la palissade signalés par test_palissade (pieux sans cylindre, rayons non arrêtés).
const SCENE := preload("res://scenes/foret_test.tscn")
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 10:
		await physics_frame
	var v = m.village
	var formes := []
	for cs in (v.corps as StaticBody3D).get_children():
		if cs is CollisionShape3D and cs.shape is CylinderShape3D:
			formes.append([(v.corps as Node3D).global_transform * (cs as CollisionShape3D).position, cs.shape.radius])
	for p: Vector3 in v.pieux_v2:
		var best := INF
		for f in formes:
			best = minf(best, Vector2(f[0].x - p.x, f[0].z - p.z).length())
		var k := Vector2i(roundi(p.x * 20.0), roundi(p.z * 20.0))
		var nk := 0
		for f in formes:
			if Vector2i(roundi(f[0].x * 20.0), roundi(f[0].z * 20.0)) == k:
				nk += 1
		if best > 0.005 or nk != 1:
			print("pieu %s : forme la plus proche %.3f m, nk %d" % [p, best, nk])
	for c in [Vector2(18.9, 60.1), Vector2(61.4, 80.3)]:
		print("== autour de ", c, " sol ", DetailsSol.hauteur_maillage(m, c.x, c.y), " riviere ", ReliefVillage.riviere(c.x, c.y))
		for f in formes:
			if Vector2(f[0].x - c.x, f[0].z - c.y).length() < 1.6:
				print("   forme r%.2f centre %s (de %.2f à %.2f)" % [f[1], f[0], f[0].y - 1.8, f[0].y + 1.8])
	quit(0)
