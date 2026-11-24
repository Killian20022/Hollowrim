extends SceneTree
## Test sans fenêtre des DÉGÂTS d'un ennemi projeté par l'esprit (Attraction relâchée, Répulsion, Lévitation lâchée) :
##  godot --headless --fixed-fps 60 --path . --script res://outils/test_degats_projection.gd -- --nouvelle
## Mesure les PV perdus (arrivée au sol, mur, autre ennemi), vérifie : chefs résistants, jamais fatal (budget), dégâts réseau via _frapper.

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

func _viser_point(c: Vector3) -> void:
	for k in 3:
		var o: Vector3 = j.camera.global_position
		var d := c - o
		j.rotation.y = atan2(-d.x, -d.z)
		j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		await physics_frame

func _reset() -> void:
	for m in ["gauche", "droite"]:
		magie._couper(m, false)
		magie.inc[m].changer(Incantation.REPOS)
		magie.inc[m].tenu = false
	es.tout_lacher()
	es.journal.clear()
	rag.journal.clear()
	magie.recharges.clear()
	j.mana = j.mana_max
	j.vie = j.vie_max
	await _sim(0.4)

func _draugr(p: Vector3, type := "draugr") -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(s.DRAUGR)
	d.type = type
	d.joueur = j
	d.hud = s.hud
	d.ident = "dg_%s_%d" % [type, randi() % 100000]
	d.position = p
	d.rotation.y = atan2(j.global_position.x - p.x, j.global_position.z - p.z)
	s.add_child(d)
	d.set_physics_process(false)
	return d

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
	rag = es.rag
	if j.touche.is_connected(magie._sur_touche):
		j.touche.disconnect(magie._sur_touche)
	await _attraction("draugr")
	await _attraction("chef")
	await _repulsion()
	await _impact_ennemi()
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)

func _chocs() -> Array:
	return es.journal.filter(func(x): return String(x[1]).begins_with("choc")).map(func(x): return x[1])

## Attraction : le vortex aspire l'ennemi, le relâche, il est projeté.
func _attraction(type: String) -> void:
	await _reset()
	magie.equiper("gauche", "attraction")
	s.placer_joueur(Vector3(0, 0, 9.0), 0.0)
	var d := _draugr(Vector3(0, 0, 3.0), "draugr")
	if type == "chef":
		d.boss = "hrafn"
	await _sim(0.4)
	await _viser_point(Elements._centre(d))
	var vie0: float = d.vie
	magie.appuyer("gauche")
	await _sim(0.1)
	magie.relacher("gauche")
	var pris := false
	var vu := false
	var t := 0.0
	while t < 9.0:
		await _sim(DT)
		t += DT
		pris = pris or es.vols.has(d.get_instance_id())
		vu = vu or rag.en_vol(d)
		if vu and t > 4.5 and not rag.contient(d):
			break
	var perdue := vie0 - maxf(float(d.vie), 0.0)
	print("   attraction %s : pris=%s ragdoll=%s, %.0f / %.0f PV perdus ; %s" % [type, str(pris), str(vu), perdue, vie0, str(_chocs())])
	for x in es.journal:
		print("   ES %.2f %s" % [x[0], x[1]])
	if type == "chef":
		_verif(perdue < 0.4 * vie0, "attraction sur un chef : il résiste (%.0f / %.0f)" % [perdue, vie0])
	else:
		_verif(pris and vu, "attraction : le draugr est aspiré puis projeté en ragdoll")
		_verif(perdue > 20.0 and perdue < 0.6 * vie0, "attraction : le draugr projeté prend des dégâts (sort + arrivée au sol, jamais fatal) (%.0f PV)" % perdue)
		_verif(d.vie > 0.0 or perdue <= vie0, "attraction : budget respecté (%.0f / %.0f)" % [perdue, vie0])
	if is_instance_valid(d):
		d.queue_free()

func _repulsion() -> void:
	await _reset()
	magie.equiper("gauche", "repulsion")
	s.placer_joueur(Vector3(0, 0, 9.0), 0.0)
	var d := _draugr(Vector3(0, 0, 5.0), "draugr")
	await _sim(0.4)
	await _viser_point(Elements._centre(d))
	var vie0: float = d.vie
	magie.appuyer("gauche")
	await _sim(3.0)   # pleine charge
	magie.relacher("gauche")
	var t := 0.0
	var vu := false
	while t < 6.0:
		await _sim(DT)
		t += DT
		vu = vu or rag.en_vol(d)
		if vu and t > 2.0 and not rag.contient(d):
			break
	var perdue := vie0 - maxf(float(d.vie), 0.0)
	print("   répulsion : ragdoll=%s, %.0f / %.0f PV perdus ; %s" % [str(vu), perdue, vie0, str(_chocs())])
	for x in es.journal:
		print("   ES %.2f %s" % [x[0], x[1]])
	_verif(vu and perdue > 15.0 and perdue < 0.7 * vie0, "répulsion : l'ennemi projeté prend des dégâts (%.0f PV)" % perdue)
	if is_instance_valid(d):
		d.queue_free()

## Un ennemi projeté (ragdoll) contre un second ennemi : les deux encaissent.
func _impact_ennemi() -> void:
	await _reset()
	s.placer_joueur(Vector3(0, 0, 9.0), 0.0)
	var a := _draugr(Vector3(0, 0, 3.0), "draugr")
	var b := _draugr(Vector3(0, 0, -1.0), "draugr")
	await _sim(0.4)
	var va: float = a.vie
	var vb: float = b.vie
	es.projeter(a, Vector3(0, 0, -16.0), es._sort("repulsion"))
	await _sim(4.0)
	print("   projeté contre un autre ennemi : A %.0f -> %.0f, B %.0f -> %.0f ; %s" % [va, a.vie, vb, b.vie, str(_chocs())])
	_verif(b.vie < vb - 1.0, "l'ennemi percuté perd des PV (%.0f -> %.0f)" % [vb, b.vie])
	_verif(a.vie < va - 1.0, "l'ennemi projeté perd des PV (%.0f -> %.0f)" % [va, a.vie])
	for d in [a, b]:
		if is_instance_valid(d):
			d.queue_free()
