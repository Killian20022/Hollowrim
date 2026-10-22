extends SceneTree
## Filet anti-chute (joueur.gd) : un joueur tombé de plus de 25 m sous le terrain revient au dernier point sûr (ou au départ) ;
## sous terre, le seuil est -260 m ; une position normale n'est jamais déplacée.
##   godot --headless --fixed-fps 60 --path . --script outils/test_filet.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 90:
		await physics_frame
	var j: CharacterBody3D = m.joueur
	var sur := j.global_position
	_verif(j._point_sur_valide, "un point sûr est mémorisé au sol")
	# dehors : on se téléporte à 40 m sous le relief
	j.global_position = Vector3(sur.x, m.hauteur(sur.x, sur.z) - 40.0, sur.z)
	await physics_frame
	await physics_frame
	_verif(j.global_position.y > m.hauteur(sur.x, sur.z) - 1.0, "chute dehors : remonté (y=%.2f)" % j.global_position.y)
	_verif(Vector2(j.global_position.x - sur.x, j.global_position.z - sur.z).length() < 1.0, "revenu au point sûr")
	# juste au-dessus du seuil : pas touché
	var q := j.global_position
	j.global_position = Vector3(q.x, m.hauteur(q.x, q.z) - 10.0, q.z)
	await physics_frame
	_verif(j.global_position.y < m.hauteur(q.x, q.z) - 5.0 or j.is_on_floor() == false, "à -10 m : pas de téléportation intempestive")
	# sous terre : y=-140 (crypte) n'est pas une chute ; -300 oui
	j.global_position = Vector3(q.x, -140.0, q.z)
	await physics_frame
	_verif(absf(j.global_position.y + 140.0) < 5.0, "y=-140 (crypte) laissé en place")
	j.global_position = Vector3(q.x, -300.0, q.z)
	await physics_frame
	await physics_frame
	_verif(j.global_position.y > -50.0, "y=-300 : remonté (y=%.1f)" % j.global_position.y)
	print("ECHECS : %d" % _echecs if _echecs > 0 else "TOUT OK")
	quit(1 if _echecs > 0 else 0)
