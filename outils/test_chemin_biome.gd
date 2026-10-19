extends SceneTree
## Accessibilité des sentiers de la zone témoin : une capsule (r 0,35 ; h 1,8) avec gravité suit
## `chemins.points` du feu (-6, -6.5) à la porte du tertre à 4 m/s, par move_and_slide.
## Échec si progression < 0,5 m en 2 s ou durée > 60 s.
##   godot --headless --path . --script outils/test_chemin_biome.gd -- --paisible [--sans-arbres]
## --sans-arbres : ignore les collisions des troncs (diagnostic, la végétation est refaite au lot E).
const SCENE := preload("res://scenes/foret_test.tscn")
const VITESSE := 4.0
const INTERIEUR := Vector2(-33.5, -34.0)  # traversée du cercle entre les deux sentiers (entre deux brèches)

var m: Node
var capsule: CharacterBody3D
var _echecs := 0

func _init() -> void:
	_lancer.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await process_frame
	var ch: Chemins = m.chemins
	_verif(ch.points.size() > 40, "chemins : %d points, init %d ms" % [ch.points.size(), ch.temps_ms])
	# pente du terrain le long de l'axe et arbres/rochers gênants (diagnostic)
	var pmax := 0.0
	for i in range(1, ch.points.size()):
		if ch.debuts.has(i):
			continue
		var a := ch.points[i - 1]
		var b := ch.points[i]
		pmax = maxf(pmax, rad_to_deg(atan(absf(m.hauteur(b.x, b.y) - m.hauteur(a.x, a.y)) / a.distance_to(b))))
	print("   pente max de l'axe : %.1f°" % pmax)
	var gen := 0
	for t: Transform3D in m.arbres:
		var d := ch.distance(t.origin.x, t.origin.z)
		if d < 1.0:
			gen += 1
			print("   tronc à %.2f m de l'axe : (%.1f, %.1f)" % [d, t.origin.x, t.origin.z])
	print("   troncs à moins de 1 m de l'axe : ", gen)
	if args.has("--sans-arbres"):
		for nd in m.find_children("*", "CollisionShape3D", true, false):
			var cs := nd as CollisionShape3D
			if cs.shape is CylinderShape3D and (cs.shape as CylinderShape3D).height == 4.0:
				cs.disabled = true
	# route : sentier du cercle, traversée du cercle, sentier du tumulus, devant la porte
	var route: Array[Vector2] = []
	for i in ch.points.size():
		if i == ch.debuts[1]:
			route.append(INTERIEUR)
		route.append(ch.points[i])
	capsule = CharacterBody3D.new()
	var cs2 := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs2.shape = cap
	cs2.position.y = 0.9
	capsule.add_child(cs2)
	m.add_child(capsule)
	capsule.global_position = Vector3(route[0].x, m.hauteur(route[0].x, route[0].y) + 0.1, route[0].y)
	for i in 10:
		await physics_frame
	var t := 0.0
	var cible := 1
	var depuis := 0.0
	var pos_ref := Vector2(capsule.global_position.x, capsule.global_position.z)
	var ok := true
	var pente_max := 0.0
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	while cible < route.size() and t < 60.0:
		var p := Vector2(capsule.global_position.x, capsule.global_position.z)
		if p.distance_to(route[cible]) < 0.6:
			cible += 1
			continue
		var dir := (route[cible] - p).normalized()
		capsule.velocity.x = dir.x * VITESSE
		capsule.velocity.z = dir.y * VITESSE
		capsule.velocity.y -= 20.0 * dt
		capsule.move_and_slide()
		if capsule.is_on_floor():
			pente_max = maxf(pente_max, rad_to_deg(capsule.get_floor_angle()))
		await physics_frame
		t += dt
		depuis += dt
		if depuis >= 2.0:
			var p2 := Vector2(capsule.global_position.x, capsule.global_position.z)
			if p2.distance_to(pos_ref) < 0.5:
				print("   bloqué près de ", p2, " (point ", cible, " ", route[cible], ")")
				ok = false
				break
			pos_ref = p2
			depuis = 0.0
	_verif(ok and cible >= route.size(), "capsule : arrivée devant la porte en %.1f s (point %d/%d, pente max %.1f°)" % [t, cible, route.size(), pente_max])
	_verif(t <= 60.0, "durée ≤ 60 s")
	print("ECHECS : ", _echecs)
	quit(1 if _echecs > 0 else 0)
