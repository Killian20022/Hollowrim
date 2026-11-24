extends SceneTree
## Test sans fenêtre : le RELEVÉ d'un ennemi projeté part toujours de là où le CORPS est posé (jamais en l'air).
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_releve_sol.gd -- --nouvelle
## Plusieurs lancers (haut et longs : plus de 2,4 s de vol), chute sur une table, sur une pente, sur un escalier : au début du relevé,
## écart vertical capsule (pieds) <-> sol sous elle < 10 cm, bassin du ragdoll à moins de 55 cm du sol, corps immobile.

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: MainSort
var es: SortsEsprit
var rag: RagdollEsprit

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _sim(t: float) -> void:
	for i in maxi(1, roundi(t / DT)):
		mains.avancer(DT)
		await physics_frame

func _sol_sous(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.3, p + Vector3.DOWN * 40.0, 1)
	var ex: Array[RID] = []
	for essai in 4:
		q.exclude = ex
		var r := j.get_world_3d().direct_space_state.intersect_ray(q)
		if r.is_empty():
			return -INF
		if r["collider"] is CharacterBody3D:
			ex.append((r["collider"] as CharacterBody3D).get_rid())
			continue
		return (r["position"] as Vector3).y
	return -INF

func _draugr(p: Vector3) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(s.DRAUGR)
	d.type = "squelette"
	d.joueur = j
	d.hud = s.hud
	d.ident = "rs_%d" % (randi() % 100000)
	d.position = p
	s.add_child(d)
	d.set_physics_process(false)
	return d

func _boite(centre: Vector3, taille: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var b := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var f := BoxShape3D.new()
	f.size = taille
	c.shape = f
	b.add_child(c)
	b.collision_layer = 1
	s.add_child(b)
	b.global_position = centre
	b.rotation = rot
	return b

## Projette `d` avec `v` depuis `y0` ; mesure au premier instant de relevé. Rend un dictionnaire de mesures.
func _lancer(d: CharacterBody3D, v: Vector3, y0 := 0.0) -> Dictionary:
	d.global_position.y = y0
	await _sim(DT * 2)
	if not rag.prendre(d, v, es._sort("repulsion")):
		return {}
	var t := 0.0
	var res := {}
	while t < 20.0:
		await _sim(DT)
		t += DT
		if rag.phase(d) == "releve":
			var rl := rag.journal.filter(func(x): return x.get("e") == d and x.has("clip"))
			var bassin: Vector3 = rl[0]["bassin_rd"]
			res = {"t": t, "pos": d.global_position, "gap": d.global_position.y - _sol_sous(d.global_position),
				"bassin_h": bassin.y - _sol_sous(bassin), "clip": rl[0]["clip"]}
			break
	return res

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	magie = mains.magie
	magie.eq.apprendre_tout()
	mains.pas_manuel = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 20:
		await physics_frame
	es = magie.esprit
	rag = es.rag if es != null else null
	if rag == null:
		_verif(false, "ragdoll de projection installé")
		quit(1)
		return
	s.placer_joueur(Vector3(6, 0, 12), 0.0)
	# décor d'essai : table (plateau à 0,8 m), pente 25°, escalier
	var table := _boite(Vector3(12, 0.4, 3), Vector3(2.4, 0.8, 1.6))
	var pente := _boite(Vector3(18, 0.5, 3), Vector3(4.0, 0.4, 3.0), Vector3(0, 0, deg_to_rad(25.0)))
	for k in 6:
		_boite(Vector3(24 + 0.4 * k, 0.1 * (k + 1), 3), Vector3(0.4, 0.2 * (k + 1), 3.0))
	await _sim(0.3)
	var cas := [
		["lancer vertical 20 m/s (vol > 4 s)", Vector3(8, 0, 6), Vector3(0, 20, 0), 0.0],
		["lancer en cloche 7+13 m/s", Vector3(6, 0, 7), Vector3(3, 11, 1), 0.0],
		["lancer en cloche opposé", Vector3(14, 0, 8), Vector3(-5, 15, 0), 0.0],
		["lancer rasant long", Vector3(8, 0, 9), Vector3(8, 6, 0), 0.0],
		["lâché de 6 m (lévitation lâchée)", Vector3(10, 0, 10), Vector3(0, 0, 0), 6.0],
		["chute sur la table", Vector3(12, 0, 3), Vector3(0, 0.2, 0), 3.0],
		["chute sur la pente 25°", Vector3(18, 0, 3), Vector3(0, 0.2, 0), 3.0],
		["chute sur l'escalier", Vector3(25, 0, 3), Vector3(0, 0.2, 0), 3.0],
	]
	for c in cas:
		var d := _draugr(c[1])
		var r: Dictionary = await _lancer(d, c[2], c[3])
		if r.is_empty():
			_verif(false, "%s : pas de relevé" % c[0])
		else:
			_verif(absf(float(r["gap"])) < 0.10 and float(r["bassin_h"]) < 0.55,
				"%s : début du relevé à %.1f s, pieds à %.1f cm du sol, bassin à %.0f cm (%s)" % [c[0], r["t"], float(r["gap"]) * 100.0, float(r["bassin_h"]) * 100.0, r["clip"]])
		await _sim(2.5)
		d.queue_free()
		await _sim(0.2)
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)
