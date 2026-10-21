extends SceneTree
## Test headless : patrouille par points (marche entre les points, détection, retour après abandon) et réveil sur événement
## de quête (reveil_evt). godot --headless --path . --script outils/test_patrouille.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _sol(x: float, z: float) -> Vector3:
	return Vector3(x, m.hauteur(x, z) + 0.05, z)

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 8:
		await physics_frame
	for e in get_nodes_in_group("ennemis"):
		e.set_physics_process(false)
	var j = m.joueur
	var o: Vector3 = j.global_position
	var loin := _sol(o.x + 90.0, o.z)
	j.global_position = loin
	j.velocity = Vector3.ZERO
	# --- patrouille
	var pts: Array[Vector3] = [_sol(o.x, o.z), _sol(o.x + 4.0, o.z), _sol(o.x + 4.0, o.z + 4.0)]
	var g: CharacterBody3D = m.creer_draugr("sbire", pts[0], 0.0, false, {"ident": "t_patrouille", "patrouille": pts})
	for i in 3:
		await physics_frame
	_verif(g.etat == g.PATROUILLE, "un patrouilleur démarre en PATROUILLE")
	var visite := [false, false, false]
	for i in 2600:
		j.global_position = loin
		await physics_frame
		for k in 3:
			if g.global_position.distance_to(pts[k]) < 1.3 and (k > 0 or i > 200):
				visite[k] = true
		if visite[0] and visite[1] and visite[2]:
			break
	_verif(visite[1] and visite[2], "il marche entre les points (visités : %s)" % str(visite))
	_verif(g.etat == g.PATROUILLE, "toujours en patrouille sans joueur")
	# --- détection
	j.global_position = _sol(g.global_position.x + 7.0, g.global_position.z)
	for i in 30:
		await physics_frame
	_verif(g.etat in [g.TRAQUE, g.ATTAQUE], "il repère le joueur à 7 m (état %d)" % g.etat)
	# --- abandon : retour à la patrouille
	j.global_position = loin
	for i in 10:
		await physics_frame
	_verif(g.etat == g.PATROUILLE, "joueur parti : retour à la patrouille (état %d)" % g.etat)
	g.queue_free()
	# --- réveil sur événement
	var d: CharacterBody3D = m.creer_draugr("squelette", _sol(o.x, o.z + 12.0), 0.0, true, {"ident": "t_reveil", "reveil_evt": "vague_gardiens_test", "debout": true})
	j.global_position = _sol(o.x, o.z + 15.0)  # à 3 m : un dormeur ordinaire se lèverait
	for i in 90:
		await physics_frame
	_verif(d.etat == d.DORT, "avec reveil_evt, il reste endormi même joueur tout près")
	m.quetes.signaler("vague_gardiens_test")
	for i in 5:
		await physics_frame
	_verif(d.etat in [d.REVEIL, d.TRAQUE], "à l'événement il se réveille (état %d)" % d.etat)
	# événement déjà survenu : pas d'attente (comportement normal)
	var d2: CharacterBody3D = m.creer_draugr("squelette", _sol(o.x + 20.0, o.z + 12.0), 0.0, true, {"ident": "t_reveil2", "reveil_evt": "vague_gardiens_test"})
	_verif(not d2._attend, "événement déjà vu : plus d'attente")
	print("TEST PATROUILLE : ", "OK" if _echecs == 0 else "ÉCHEC (%d)" % _echecs)
	quit()
