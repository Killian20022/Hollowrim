extends SceneTree
## Film du husky qui suit le joueur dans le village (Faune, lot F2), ~12 s, vue à la troisième personne, 12 h :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_husky.gd -- --nouvelle --sans-mains
## Le joueur est mené sur un trajet fixe (est, pause, retour à l'ouest) ; le husky, laissé à son IA, vient à lui dès qu'il passe à moins de 3,5 m.
const SCENE := "res://scenes/foret_test.tscn"
const TRAJET := [Vector3(46.0, 0, 34.5), Vector3(65.0, 0, 34.5), Vector3(65.0, 0, 34.5), Vector3(49.0, 0, 36.0)]
const TEMPS := [0.0, 6.0, 7.5, 12.5]      # instants (s) de chaque point
var m: Node3D
var j: CharacterBody3D

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc
	while m.get("pret") != true:
		await process_frame
	j = m.joueur
	j.mort = false
	j.vie = 100000.0
	m.hud.visible = false
	m.dialogue.visible = false
	m.cycle.heure = 12.0
	m.cycle._process(0.0)
	m.faune.actualiser()
	for n in get_nodes_in_group("villageois"):
		if n is Node3D:
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED
	for g in get_nodes_in_group("garde_village"):
		if g is Node3D:
			g.visible = false
			g.process_mode = Node.PROCESS_MODE_DISABLED
	j.basculer_vue(true)
	j.set_physics_process(false)
	for i in 45:
		await process_frame
	var husky: Node3D = null
	for e: Dictionary in m.faune.domestiques:
		if e["def"]["espece"] == "husky":
			husky = e["bete"]
	print("HUSKY départ ", husky.global_position, " suit=", husky.suit_joueur)
	var n := int(TEMPS[-1] * 30.0)
	for i in n:
		var t := float(i) / 30.0
		var k := 0
		while k < TEMPS.size() - 2 and t > TEMPS[k + 1]:
			k += 1
		var u := clampf((t - TEMPS[k]) / maxf(TEMPS[k + 1] - TEMPS[k], 0.001), 0.0, 1.0)
		var a: Vector3 = TRAJET[k]
		var b: Vector3 = TRAJET[k + 1]
		var p := a.lerp(b, u)
		p.y = m.hauteur(p.x, p.z) + 0.05
		var d := b - a
		if d.length() > 0.01 and u < 1.0:
			j.rotation.y = atan2(-d.x, -d.z)
		j.global_position = p
		j.velocity = Vector3.ZERO
		await process_frame
		if i % 30 == 0:
			print("t=%.0f s husky=%s suit=%s écart=%.1f m" % [t, husky.global_position, husky.suit_joueur, husky.global_position.distance_to(j.global_position)])
	print("FILM fini")
	quit(0)
