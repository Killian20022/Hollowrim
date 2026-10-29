extends SceneTree
## Test sans fenêtre : os de MORT d'un squelette (lot L6) —
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_os_mort.gd -- --nouvelle --test
## 8 à 12 os (modules os_long / crâne) à la mort d'un squelette, ragdoll conservé, os au sol ~20 s puis éteints, pool constant.

const SCENE := preload("res://scenes/test_degats.tscn")
var _ok := 0
var _ko := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ÉCHEC  ") + msg)
	if cond:
		_ok += 1
	else:
		_ko += 1

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _tester() -> void:
	RetourImpact.muet = true
	RetourImpact.arret_actif = false
	var sc: Node3D = SCENE.instantiate()
	root.add_child(sc)
	current_scene = sc
	await _frames(10)
	sc.joueur.global_position = Vector3(0, 0, 4.0)
	var sq: CharacterBody3D = sc.creer_draugr("squelette", Vector3(0, 0.05, 0.5), {"ident": "r_os"})
	await _frames(5)
	sq.set_physics_process(false)
	var eo := EclatsOs.obtenir(sc)
	_verif(eo.get_child_count() == EclatsOs.TOTAL, "pool : %d corps (%d + %d os de mort)" % [eo.get_child_count(), EclatsOs.TAILLE_POOL, EclatsOs.NB_MORT])
	for i in EclatsOs.NB_MORT:
		var rb := eo.get_child(EclatsOs.TAILLE_POOL + i) as RigidBody3D
		var mi := rb.get_child(1) as MeshInstance3D
		_verif(mi.mesh is ArrayMesh, "os de mort %d : maillage de module (%s)" % [i, mi.mesh.get_class()]) if i < 6 else null
	var l0 := EclatsOs.lances
	var r0 := _rigides()
	for k in 20:   # le squelette peut parer : on recommence jusqu'à la mort
		if sq.vie <= 0.0:
			break
		sq.vie = 1.0
		sq.combat.etourdi = 0.0
		sq.recevoir_coup(500.0, sq.global_position + Vector3(0, 0, 2.0), true, {"attaque": "lourde", "zone": "torse"})
	await _frames(3)
	var n := 0
	for i in EclatsOs.NB_MORT:
		if (eo.get_child(EclatsOs.TAILLE_POOL + i) as Node3D).visible:
			n += 1
	_verif(n >= 8 and n <= 12, "mort du squelette : %d os lancés (8-12 attendus)" % n)
	_verif(eo.vivants() >= 8, "os en vol : %d" % eo.vivants())
	await _frames(240)
	var au_sol := 0
	for i in EclatsOs.NB_MORT:
		var rb := eo.get_child(EclatsOs.TAILLE_POOL + i) as RigidBody3D
		if rb.visible and rb.global_position.y < 0.6 and rb.global_position.y > -1.0:
			au_sol += 1
	_verif(au_sol >= 8, "4 s après : %d os retombés au sol (y < 0,6 m)" % au_sol)
	await _frames(14 * 60)
	_verif(eo.vivants() >= 8, "18 s après : os toujours là (%d)" % eo.vivants())
	await _frames(3 * 60)
	_verif(eo.vivants() == 0, "21 s après : os éteints (%d restants)" % eo.vivants())
	_verif(eo.get_child_count() == EclatsOs.TOTAL, "pool inchangé")
	_verif(_rigides() == r0 + _ragdoll_ajoutes(sq), "aucun RigidBody3D créé par la mort (hors pool)")
	print("OS_MORT : %d OK, %d en échec" % [_ok, _ko])
	quit(1 if _ko > 0 else 0)

func _rigides() -> int:
	var n := 0
	for c in root.find_children("*", "RigidBody3D", true, false):
		if not c.get_parent() is EclatsOs:
			n += 1
	return n

func _ragdoll_ajoutes(_sq: Node) -> int:
	return 0
