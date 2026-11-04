extends SceneTree
## Sonde (gen/animaux) : carte ASCII de la pente du terrain autour du village. '.' < 0,25 m sur 2 m, ':' < 0,6, '#' plus raide.
func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var m: Node = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(m)
	while m.get("pret") != true:
		await process_frame
	for z in range(0, 62, 2):
		var l := "z%3d " % z
		for x in range(50, 104, 2):
			var h: float = m.hauteur(x, z)
			var d := maxf(absf(m.hauteur(x + 2, z) - h), absf(m.hauteur(x, z + 2) - h))
			l += "." if d < 0.25 else (":" if d < 0.6 else "#")
		print(l)
	print("x de 50 a 102 pas 2")
	quit()
