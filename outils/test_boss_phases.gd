extends SceneTree
## Test headless : chefs. Svanhild (phase 2 à mi-vie : 2 squelettes aux identifiants fixes, puis souffle de givre annoncé et
## évitable), Hrafn (cri qui alerte les archers, enchaînement de 2 coups), Jarl (réglages renforcés).
## godot --headless --path . --script outils/test_boss_phases.gd -- --nouvelle
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

func _frames(n: int, j: Node = null, pos := Vector3.ZERO) -> void:
	for i in n:
		if j != null:
			j.global_position = pos
			j.velocity = Vector3.ZERO
		await physics_frame

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
	# ---------- Svanhild
	var base := _sol(o.x + 60.0, o.z)
	var s: CharacterBody3D = m.creer_draugr("guerrier", base, 0.0, false, {"boss": "svanhild"})
	_verif(s.ident == "svanhild", "l'ident d'un boss vaut son nom (%s)" % s.ident)
	_verif(s.vie_max == 260.0, "Svanhild : 260 de vie")
	var p_j := _sol(base.x, base.z - 7.0)  # devant elle (regarde vers +z → on la place à -z, elle pivote)
	j.global_position = p_j
	await _frames(40, j, p_j)
	_verif(s.etat in [s.TRAQUE, s.ATTAQUE], "phase 1 : elle attaque (état %d)" % s.etat)
	_verif(s._phase == 1 and not m.draugrs.has("svanhild_garde_1"), "phase 1 : pas de squelettes")
	s.vie = s.vie_max * 0.5 - 1.0
	var vu_appel := false
	for i in 40:
		j.vie = 100.0
		await _frames(1, j, p_j)
		if s.etat == s.APPEL:
			vu_appel = true
			break
	_verif(vu_appel and s._phase == 2, "à 50 % de vie : phase 2, elle appelle (état APPEL)")
	await _frames(70, j, p_j)
	var g1 = m.draugrs.get("svanhild_garde_1")
	var g2 = m.draugrs.get("svanhild_garde_2")
	_verif(g1 != null and g2 != null and is_instance_valid(g1) and is_instance_valid(g2), "deux squelettes aux identifiants fixes (svanhild_garde_1/2)")
	if g1 != null and g2 != null:
		_verif(g1.vivant() and g2.vivant() and g1.type == "squelette", "ce sont des squelettes vivants")
		g1.set_physics_process(false)
		g2.set_physics_process(false)
	# souffle : annoncé, cône figé, évitable
	s._cd_souffle = 0.0
	s._recharge = 5.0  # pas de coup de mêlée pendant l'essai
	var annonce := false
	for i in 200:
		j.vie = 100.0
		await _frames(1, j, p_j)
		if s.etat == s.ANNONCE:
			annonce = true
			break
	_verif(annonce, "phase 2 : souffle de givre ANNONCÉ (état ANNONCE)")
	_verif(is_instance_valid(s._cone), "le cône est dessiné au sol pendant l'annonce")
	var t0 := 0.0
	# on sort du cône pendant l'annonce (0,8 s) : à 7 m de côté
	var cote := _sol(s.global_position.x + 7.0, s.global_position.z - 3.0)
	j.vie = 100.0
	for i in 70:
		await _frames(1, j, cote)
		if s.etat == s.SOUFFLE:
			break
	await _frames(15, j, cote)
	_verif(j.vie >= 99.9, "évitable : hors du cône, aucun dégât (vie %.1f)" % j.vie)
	# deuxième souffle : le joueur reste dans le cône
	await _frames(30, j, cote)
	s._cd_souffle = 0.0
	s._recharge = 5.0
	var p_cone := _sol(s.global_position.x, s.global_position.z - 6.0)
	for i in 200:
		j.vie = 100.0 if s.etat != s.ANNONCE else j.vie
		await _frames(1, j, p_cone)
		if s.etat == s.ANNONCE:
			break
	var v_avant: float = j.vie
	for i in 120:
		await _frames(1, j, p_cone)
		if s.etat == s.SOUFFLE:
			break
	await _frames(5, j, p_cone)
	_verif(j.vie < v_avant - 10.0, "dans le cône : le souffle touche (vie %.1f -> %.1f)" % [v_avant, j.vie])
	s.recevoir_coup(9999.0, p_cone, true)
	await _frames(3)
	_verif(not s.vivant(), "Svanhild meurt (contrat mort/vivant)")
	# ---------- Hrafn et son archer
	var bh := _sol(o.x + 60.0, o.z + 60.0)
	var arch: CharacterBody3D = m.creer_draugr("sbire", _sol(bh.x + 10.0, bh.z + 3.0), PI, false, {"ident": "t_hrafn_archer", "archer": true, "poste": true})
	var h: CharacterBody3D = m.creer_draugr("sbire", bh, 0.0, false, {"boss": "hrafn", "ident": "hrafn"})
	_verif(h.vie_max > 150.0 and h.ident == "hrafn", "Hrafn : plus de vie (%d)" % int(h.vie_max))
	_verif(arch.archer and arch.etat == arch.GARDE, "l'archer attend (GARDE) tant que Hrafn ne crie pas")
	arch.joueur = j
	var ph := _sol(bh.x, bh.z - 1.6)
	var vu_appel_h := false
	var combo := false
	var coups := 0
	var dernier_etat := -1
	for i in 700:
		j.vie = 100.0
		await _frames(1, j, ph)
		if h.etat == h.APPEL:
			vu_appel_h = true
		if h.etat == h.ATTAQUE and dernier_etat != h.ATTAQUE:
			coups += 1
		if h.etat == h.ATTAQUE and h._combo == 1:
			combo = true
		dernier_etat = h.etat
		if combo and coups >= 2:
			break
	_verif(vu_appel_h, "Hrafn appelle au début (état APPEL)")
	_verif(arch.etat != arch.GARDE, "l'archer est alerté par le cri (état %d)" % arch.etat)
	_verif(combo and coups >= 2, "enchaînement de 2 coups (coups=%d)" % coups)
	# ---------- Jarl
	var jl: CharacterBody3D = m.creer_draugr("guerrier", _sol(o.x - 60.0, o.z), 0.0, true, {"boss": "jarl", "ident": "jarl"})
	_verif(jl.vie_max >= 300.0 and jl.degats >= 35.0 and jl._rythme < 0.8 and jl._bouclier > 0.5, "Jarl : vie %d, dégâts %d, coups lents, bouclier" % [int(jl.vie_max), int(jl.degats)])
	print("TEST BOSS : ", "OK" if _echecs == 0 else "ÉCHEC (%d)" % _echecs)
	quit()
