extends SceneTree
## C1b : densités des rochers v2 / touffes par bande (ouest, nord, est, sud, quart sud-est) et poses de capture dégagées
## à l'est (x > 50) et au sud (z > 50), hors village, avec rochers et touffes en vue (dérivé de sonde_poses_c1a.gd).
##   godot --headless --path . --script res://outils/sonde_poses_c1b.gd -- --nouvelle
var monde: Node3D

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	monde = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(monde)
	for k in 5:
		await process_frame
	var arb: Array = []
	for a: Transform3D in monde.arbres:
		arb.append(Vector2(a.origin.x, a.origin.z))
	var arbres_zone: Array = monde.get_meta("arbres_zone") if monde.has_meta("arbres_zone") else []
	for a in arbres_zone:
		arb.append(Vector2(a["pos"].x, a["pos"].z))
	var roches: Array = []
	var touffes: Array = []
	var decor := monde.get_node("SolV2Decor")
	for mmi in decor.get_children():
		if not mmi is MultiMeshInstance3D:
			continue
		var mm: MultiMesh = mmi.multimesh
		var herbe: bool = mm.mesh.surface_get_material(0) is ShaderMaterial and String((mm.mesh.surface_get_material(0) as ShaderMaterial).shader.resource_path).contains("herbe")
		for i in mm.instance_count:
			var p: Vector3 = mmi.global_transform * mm.get_instance_transform(i).origin
			(touffes if herbe else roches).append(Vector2(p.x, p.z))
	var bandes := {"ouest x<-50": func(v: Vector2) -> bool: return v.x < -50.0, "nord z<-50": func(v: Vector2) -> bool: return v.y < -50.0,
		"est x>50": func(v: Vector2) -> bool: return v.x > 50.0, "sud z>50": func(v: Vector2) -> bool: return v.y > 50.0,
		"quart SE": func(v: Vector2) -> bool: return v.x >= 0.0 and v.y >= 0.0}
	for b: String in bandes:
		var nr := 0
		var nt := 0
		for r: Vector2 in roches:
			if bandes[b].call(r): nr += 1
		for r: Vector2 in touffes:
			if bandes[b].call(r): nt += 1
		print("SONDE %s : %d rochers, %d touffes" % [b, nr, nt])
	var res := []
	var x := -100.0
	while x < 100.0:
		var z := -100.0
		while z < 100.0:
			var c := Vector2(x, z)
			if (x > 50.0 or z > 50.0) and c.length() < 96.0 and c.distance_to(Vector2(monde.VILLAGE.x, monde.VILLAGE.z)) > 47.0 and SolV2._pente(monde, x, z) < 0.6:
				for lac in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
					var y := deg_to_rad(lac)
					var f := Vector2(-sin(y), -cos(y))
					var ok := true
					for t: Vector2 in arb:
						var d := t - c
						var l := d.length()
						if l < 2.5 or (l < 10.0 and d.dot(f) > 0.0 and absf(d.normalized().dot(Vector2(f.y, -f.x))) < 0.6):
							ok = false
							break
					if not ok:
						continue
					var nr := 0
					var nt := 0
					for r: Vector2 in roches:
						var d := r - c
						if d.length() > 2.0 and d.length() < 14.0 and d.normalized().dot(f) > 0.8:
							nr += 1
					for r: Vector2 in touffes:
						var d := r - c
						if d.length() > 1.5 and d.length() < 10.0 and d.normalized().dot(f) > 0.8:
							nt += 1
					res.append([nr * 3.0 + minf(nt, 20), x, z, lac, nr, nt])
			z += 4.0
		x += 4.0
	res.sort_custom(func(a, b): return a[0] > b[0])
	var vus := {}
	for r in res:
		var k := "%d_%d" % [int(r[1] / 16.0), int(r[2] / 16.0)]
		if vus.has(k):
			continue
		vus[k] = 1
		print("POSE %s %.0f,%.0f lacet=%.0f score=%.0f rochers=%d touffes=%d" % ["E" if r[1] > 50.0 else "S", r[1], r[2], r[3], r[0], r[4], r[5]])
	quit(0)
