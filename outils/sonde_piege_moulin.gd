extends SceneTree
## Sonde (piège du moulin) : le VRAI joueur, posé sur des cases suspectes du graphe d'accessibilité, tente d'en sortir
## (8 caps, course + sauts, 5 s chacun) ; sorti = à plus de 2,5 m du départ.
##   godot --headless --fixed-fps 60 --path . --script res://outils/sonde_piege_moulin.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
const POINTS := [Vector2(75.75, 53.5), Vector2(16.5, 76.0), Vector2(19.3, 60.2), Vector2(18.6, 58.9)]
var m: Node3D

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 8:
		await physics_frame
	var esp := m.get_world_3d().direct_space_state
	var j: CharacterBody3D = m.joueur
	j.set_physics_process(true)
	Input.action_press("course")
	Input.action_press("avant")
	for p: Vector2 in POINTS:
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 40, p.y), Vector3(p.x, -10, p.y))
		q.exclude = [j.get_rid()]
		var r := esp.intersect_ray(q)
		var dep := Vector3(p.x, (r.position as Vector3).y + 0.1, p.y)
		var ok := 0
		for c in 8:
			j.global_position = dep
			j.velocity = Vector3.ZERO
			j.rotation.y = c * TAU / 8.0
			for f in 300:
				if f % 40 == 20: Input.action_press("saut")
				elif f % 40 == 21: Input.action_release("saut")
				j.vigueur = j.vigueur_max
				await physics_frame
			var g := j.global_position
			if Vector2(g.x - dep.x, g.z - dep.z).length() > 2.5:
				ok += 1
		print("SONDE départ %s : %d/8 caps sortent" % [dep, ok])
	quit()
