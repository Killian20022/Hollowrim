extends SceneTree
## [C7b] Carte des hauteurs (2 m) et des arbres de l'est du village : choix des emplacements des fermes et du moulin à vent.
const SCENE := preload("res://scenes/foret_test.tscn")
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 3:
		await process_frame
	var arbres := {}
	for t: Transform3D in m.arbres:
		arbres[Vector2i(roundi(t.origin.x / 2.0), roundi(t.origin.z / 2.0))] = true
	var l := "z\\x  "
	for x in range(50, 101, 2):
		l += "%4d" % x
	print(l)
	for z in range(-14, 52, 2):
		l = "%4d " % z
		for x in range(50, 101, 2):
			var h := DetailsSol.hauteur_maillage(m, x, z)
			var c := "*" if arbres.has(Vector2i(x / 2, z / 2)) else ("#" if ReliefVillage.distance_palissade(x, z) < 0.0 else " ")
			l += "%3d%s" % [roundi(h), c]
		print(l)
	quit(0)
