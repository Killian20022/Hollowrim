extends SceneTree
## Outil : liste les endroits où jeunes arbres, souches et semis sont proches (lisière), le long du chemin.
##   godot --headless --path . --script outils/trouver_lisiere.gd
const SCENE := preload("res://scenes/foret_test.tscn")

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await process_frame
	var pts: Array = []
	var vus := {}
	for n in m.find_children("*", "MultiMeshInstance3D", true, false):
		if n.has_meta("sous_bois"):
			var g: String = n.get_meta("sous_bois")
			if (g == "souche" or g == "semis") and not vus.has(g):
				vus[g] = true
				for t: Transform3D in n.get_meta("transforms"):
					pts.append([g, t.origin])
	var best := []
	for x in range(-56, 2, 2):
		for z in range(-62, 2, 2):
			var ns := 0
			var nm := 0
			for q in pts:
				var d := Vector2(q[1].x - x, q[1].z - z).length()
				if d < 7.0:
					if q[0] == "souche": ns += 1
					else: nm += 1
			var dc: float = m.chemins.distance(x, z)
			if ns >= 2 and nm >= 2 and dc < 9.0 and dc > 1.5:
				best.append([ns + nm, x, z, dc])
	best.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(12, best.size()):
		print("lisiere souches+semis=%d x=%d z=%d dist_chemin=%.1f" % best[i])
	quit()
