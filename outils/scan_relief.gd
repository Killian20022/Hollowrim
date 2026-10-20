extends SceneTree
## Outil : carte de hauteurs et de pentes du terrain (choix de l'entrée de la grotte).
##   godot --headless --path . --script outils/scan_relief.gd -- --nouvelle [x0 z0 x1 z1 pas]
const SCENE := preload("res://scenes/foret_test.tscn")

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 3:
		await process_frame
	var a: Array = []
	for t in OS.get_cmdline_user_args():
		if not t.begins_with("--"):
			a.append(int(t))
	if a.size() < 5:
		a = [-104, -104, 105, 105, 8]
	for z in range(a[1], a[3], a[4]):
		var l := "z=%4d " % z
		for x in range(a[0], a[2], a[4]):
			var h: float = m.hauteur(x, z)
			var gx: float = (m.hauteur(x + 2, z) - m.hauteur(x - 2, z)) / 4.0
			var gz: float = (m.hauteur(x, z + 2) - m.hauteur(x, z - 2)) / 4.0
			l += "%3d/%02d " % [roundi(h), roundi(Vector2(gx, gz).length() * 100.0)]
		print(l)
	quit()
