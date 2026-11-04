extends SceneTree
## Test sans fenêtre : double magie des écoles à lancer propre (glace, électricité, ténèbres) branchée sur le point de fusion
## commun (TransitionSort), comme le feu : UN seul lancer combiné (meneuse + suiveuse), aucun second sort superposé.
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_lancer_double.gd -- --nouvelle

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0

var _ok := true
var _n := 0
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var magie: MainSort

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _sim(t: float) -> void:
	for i in roundi(t / DT):
		mains.avancer(DT)
		await physics_frame

func _lancers(ecole: String) -> Array:
	var r: Array = []
	var pile: Array = [root]
	while not pile.is_empty():
		var n: Node = pile.pop_back()
		if n is LancerEcole and (n as LancerEcole).ecole == ecole and not n.is_queued_for_deletion() \
				and not n.get_meta("reforme", false) and not (n as LancerEcole).get("_rep"):
			r.append(n)
		pile.append_array(n.get_children())
	return r

func _reset() -> void:
	for m in ["gauche", "droite"]:
		magie.relacher(m)
		magie._couper(m, false)
		magie.inc[m].changer(Incantation.REPOS)
		magie.inc[m].double = false
	j.mana = j.mana_max
	await _sim(1.2)
	for e in ["glace", "electricite", "tenebres"]:
		for n in _lancers(e):
			n.queue_free()
	await physics_frame

## Lance `sort` à deux mains (fenêtre de 0,05 s) ; tient `tenir` s ; renvoie les lancers d'école vus pendant `obs` s.
func _double(sort: String, ecole: String, tenir: float, obs: float) -> Dictionary:
	magie.equiper("gauche", sort)
	magie.equiper("droite", sort)
	await _reset()
	magie.appuyer("gauche")
	await _sim(0.03)
	magie.appuyer("droite")
	var vus := {}
	var t := 0.0
	var max_simul := 0
	while t < obs:
		if t >= tenir and magie.inc["gauche"].tenu:
			magie.relacher("gauche")
			magie.relacher("droite")
		await _sim(DT)
		t += DT
		var l := _lancers(ecole)
		max_simul = maxi(max_simul, l.size())
		for n in l:
			vus[n.get_instance_id()] = {"name": String(n.name), "double": n.double, "mains": n.mains.duplicate(), "tension": n.get("_tension") == true}
	magie.relacher("gauche")
	magie.relacher("droite")
	return {"vus": vus.values(), "max": max_simul}

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
	for i in 20:
		await physics_frame
	var pg: Node3D = magie._p("gauche")
	var pd: Node3D = magie._p("droite")
	for c in [["eclat_glace", "glace", 0.1, 0.5], ["trait_ombre", "tenebres", 0.1, 0.5], ["souffle_givre", "glace", 0.6, 0.6], ["drain_vie", "tenebres", 0.6, 0.6]]:
		var r := await _double(c[0], c[1], c[2], c[3])
		var vus: Array = r.vus
		_verif(magie.inc["gauche"].double or not vus.is_empty(), "%s double : double incantation" % c[0])
		# un lancer par projectile du sort double (éclats : éventail de `nombre`), aucun second jeu lancé par la suiveuse
		var sd := LanceurSorts.version_double(magie.eq.sort("droite"))
		var attendu := maxi(1, sd.nombre) if sd.portee_mode == DonneesSort.Portee.PROJECTILE else 1
		_verif(vus.size() == attendu, "%s double : un seul lancer combiné par tir (%d vus, %d attendus)" % [c[0], vus.size(), attendu])
		var deux := not vus.is_empty()
		var paumes := not vus.is_empty()
		for n: Dictionary in vus:
			deux = deux and n.double and n.mains.size() == 2
			paumes = paumes and n.mains.size() == 2 and n.mains.has(pg) and n.mains.has(pd)
		_verif(deux, "%s double : chaque lancer porte les deux sources" % c[0])
		_verif(paumes, "%s double : sources = les deux paumes (meneuse puis suiveuse)" % c[0])
	# électricité : la tension double part du point de fusion (un seul nœud, deux sources)
	var re := await _double("arc_electrique", "electricite", 0.6, 0.6)
	var ve: Array = re.vus
	for n: Dictionary in ve:
		print("  vu : ", n.name, " double=", n.double, " sources=", n.mains.size(), " tension=", n.tension)
	# tensions nées des mains (les rebonds de la chaîne entre cibles partent d'une cible : sans source de main, hors sujet)
	var tensions := ve.filter(func(n: Dictionary) -> bool: return n.tension and not n.mains.is_empty())
	_verif(tensions.size() == 1, "arc_electrique double : UNE seule tension combinée (%d)" % tensions.size())
	_verif(tensions.all(func(n: Dictionary) -> bool: return n.double and n.mains.size() == 2), "arc_electrique double : deux sources fusionnées")
	# simple : rien ne change (une main, pas de double)
	magie.equiper("gauche", "")
	magie.equiper("droite", "eclat_glace")
	await _reset()
	magie.appuyer("droite")
	await _sim(0.1)
	magie.relacher("droite")
	var vs := {}
	for k in 20:
		await _sim(DT)
		for n in _lancers("glace"):
			vs[n.get_instance_id()] = {"double": n.double, "mains": n.mains.size()}
	var simples := vs.values().filter(func(n: Dictionary) -> bool: return not n.double and n.mains == 1)
	_verif(vs.size() == 3 and simples.size() == 3, "eclat_glace simple : 3 éclats, une source chacun, pas de double (%d/%d)" % [simples.size(), vs.size()])
	print("ECHECS : %d" % (0 if _ok else 1), "  (", _n, " vérifications)")
	quit(0 if _ok else 1)
