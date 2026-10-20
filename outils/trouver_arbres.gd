extends SceneTree
## Outil (lot 2) : liste les arbres de la zone témoin proches du chemin, par forme, pour choisir
## des poses de gros plan.   godot --headless --path . --script outils/trouver_arbres.gd
const SCENE := preload("res://scenes/foret_test.tscn")

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await process_frame
	var infos: Array = m.get_meta("arbres_zone")
	for a: Dictionary in infos:
		var p: Vector3 = a["pos"]
		var dc: float = m.chemins.distance(p.x, p.z)
		if dc < 7.0 or a["forme"] >= 3 or (a["forme"] <= 1 and dc < 14.0):
			print("forme=%d s=%.2f x=%.1f z=%.1f y=%.1f chemin=%.1f" % [a["forme"], a["s"], p.x, p.z, p.y, dc])
	quit()
