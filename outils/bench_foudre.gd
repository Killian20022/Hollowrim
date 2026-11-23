extends SceneTree
## Micro-banc (CPU) de FoudreV2.arbre / fbm / construire : godot --headless --script res://outils/bench_foudre.gd
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	var a := Vector3.ZERO
	var b := Vector3(0, 0, -3.8)
	var c := a.lerp(b, 0.42) + Vector3(0.2, 0.1, 0)
	var N := 300
	var t := Time.get_ticks_usec()
	var x := 0.0
	for i in N * 100:
		x += FoudreV2.fbm(i * 0.1, 5, 1.0)
	print("fbm : %.2f us" % [float(Time.get_ticks_usec() - t) / (N * 100)])
	t = Time.get_ticks_usec()
	for i in N:
		FoudreV2.nervure(a, c, b, 0.2, 34, rng.randi(), 1.0)
	print("nervure 34 : %.1f us" % [float(Time.get_ticks_usec() - t) / N])
	var gr := [[b, b + Vector3(0.3, 0.2, 0), Vector3.UP], [b, b + Vector3(-0.2, 0.3, 0), Vector3.UP]]
	for opts in [{"branches": 3, "filaments": 0.6, "pas": 0.13}, {"branches": 1, "filaments": 0.25, "pas": 0.18, "largeur": 0.8}, {"branches": 3, "filaments": 0.6, "pas": 0.13, "griffes": gr}]:
		t = Time.get_ticks_usec()
		var nt := 0
		var tr: Array
		for i in N:
			tr = FoudreV2.arbre(a, c, b, rng, 1.0, opts)
			nt += tr.size()
		var ta := float(Time.get_ticks_usec() - t) / N
		var m := ArrayMesh.new()
		t = Time.get_ticks_usec()
		for i in N:
			FoudreV2.construire(m, tr, a)
		print("arbre %s : %.1f us (%.1f traits), construire %.1f us" % [opts.keys(), ta, float(nt) / N, float(Time.get_ticks_usec() - t) / N])
	quit(0)
