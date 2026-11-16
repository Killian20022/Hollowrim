extends Node
## Lot 2c : test headless (scène outils/test_lieux.tscn : les autoloads doivent exister) d'UNE instance (hôte ou invité), lancé deux fois par outils/test_lieux.sh.
## Vérifie : salle_active = union des salles (solo identique, 2 joueurs), coffre « premier arrivé » (un seul gagnant), porte synchronisée,
## contenant pillé par le plus rapide, instantané (export/import). Imprime « TEST ok/ECHEC … » puis « TEST_LIEUX <role> OK|ECHEC ».

class FauxQuetes extends RefCounted:
	var vus := {}
	func signaler(c: String) -> void:
		vus[c] = true

class FauxEnnemi extends Node3D:
	var gele := false
	func peut_geler() -> bool: return true
	func est_gele() -> bool: return gele
	func geler() -> void: gele = true
	func degeler() -> void: gele = false

var _role := "hote"
var _port := 24578
var _ok := true
var _quetes := FauxQuetes.new()
var _gagnes := {"cof": 0, "urne": 0}
var _perdus := {"cof": 0, "urne": 0}
var _portes_appliquees := 0
var _etat_rappels := 0
var _phase := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.substr(7)
		elif a.begins_with("--port="):
			_port = int(a.substr(7))
	_lancer.call_deferred()

func _v(nom: String, cond: bool, detail := "") -> void:
	print("TEST ", "ok    " if cond else "ECHEC ", "[", _role, "] ", nom, " ", detail)
	if not cond:
		_ok = false

func _attendre(cond: Callable, delai: float) -> bool:
	var t := 0.0
	while not cond.call() and t < delai:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	return cond.call()

func _R() -> Node:
	return get_tree().root.get_node("Reseau")

# ------------------------------------------------------------------ salle active (une seule instance, sans réseau)
func _salle() -> SalleActive:
	var repere := Node3D.new()
	get_tree().root.add_child(repere)
	var j := Node3D.new()
	get_tree().root.add_child(j)
	var sa := SalleActive.new()
	sa.arbre = get_tree()
	sa.repere = repere
	sa.joueur = j
	var defs := {"A": [Rect2(0, 0, 10, 10), ["B"]], "B": [Rect2(10, 0, 10, 10), ["A"]], "C": [Rect2(100, 0, 10, 10), []]}
	for id: String in defs:
		var r: Rect2 = defs[id][0]
		sa.salles[id] = {"rect": r, "y0": -1.0, "y1": 4.0, "pts": PackedVector3Array(), "voisins": defs[id][1], "long": false, "noeuds": []}
		sa._englober(Vector3(r.position.x, -1, r.position.y), Vector3(r.end.x, 4, r.end.y))
	sa._visibles = sa._calculer_actives("")
	return sa

func _ennemi(p: Vector3) -> FauxEnnemi:
	var e := FauxEnnemi.new()
	get_tree().root.add_child(e)
	e.position = p
	e.add_to_group("ennemis")
	return e

func _test_salles(en_ligne: bool) -> void:
	var marionnettes := en_ligne and _role != "hote"
	var sa := _salle()
	var eA := _ennemi(Vector3(5, 0, 5))
	var eC := _ennemi(Vector3(105, 0, 5))
	var autres: Array = []
	sa.positions_autres = func() -> Array: return autres
	var tag := "(en ligne) " if en_ligne else "(solo) "
	sa.joueur.position = Vector3(5, 0, 5)
	sa.rafraichir(true)
	_v(tag + "un seul joueur en A : actives = A+B", sa.actives.has("A") and sa.actives.has("B") and not sa.actives.has("C"), str(sa.actives.keys()))
	if marionnettes:
		_v(tag + "invité : marionnettes, rien n'est gelé", not eC.gele and not eA.gele)
	else:
		_v(tag + "ennemi de C gelé, celui de A actif", eC.gele and not eA.gele)
	autres.append(Vector3(105, 0, 5))
	sa.rafraichir(true)
	_v(tag + "2 joueurs (A et C) : union A+B+C", sa.actives.has("A") and sa.actives.has("B") and sa.actives.has("C"), str(sa.actives.keys()))
	_v(tag + "ennemi de C dégelé (simulé pour l'autre joueur)", not eC.gele and not eA.gele)
	_v(tag + "rendu local seulement : décor de C reste caché", not sa._visibles.has("C") and sa._visibles.has("A"), str(sa._visibles.keys()))
	sa.rafraichir(false)    # joueur local en surface, l'autre dans la crypte
	_v(tag + "local en surface, autre en C : seule C active", sa.actives.has("C") and not sa.actives.has("A"), str(sa.actives.keys()))
	_v(tag + "A gelé, C actif", (eA.gele and not eC.gele) != marionnettes)
	autres.clear()
	sa.rafraichir(false)
	_v(tag + "personne dedans : tout gelé", sa.actives.is_empty() and ((eA.gele and eC.gele) != marionnettes))
	eA.queue_free()
	eC.queue_free()
	for e in get_tree().get_nodes_in_group("ennemis"):
		e.queue_free()

# ------------------------------------------------------------------ scénario réseau
func _lancer() -> void:
	var R := _R()
	for chemin in ["res://scripts/tertre.gd", "res://scripts/grotte_jeu.gd", "res://scripts/cassable.gd", "res://scripts/objet_unique.gd", "res://scripts/salle_active.gd"]:
		var sc := load(chemin) as GDScript
		_v("compile " + chemin.get_file(), sc != null and sc.can_instantiate())
	await _test_salles(false)
	# branchements (comme tertre.gd / grotte_jeu.gd)
	ReseauLieux.poser_quetes(_quetes, ["crypte:"])
	ReseauLieux.sur_pris(func(cle: String, _t: String, _q: int) -> void:
		if cle == "crypte:cof_test":
			_quetes.signaler(cle))
	ReseauLieux.sur_etat(func() -> void: _etat_rappels += 1)
	ReseauLieux.enregistrer_porte("crypte:s1", func() -> void: _portes_appliquees += 1)
	R.abonner("t_go", _sur_go)
	R.abonner("t_fin", _sur_fin)
	R.abonner("t_res", _sur_res)
	if _role == "hote":
		_v("hôte : heberger OK", R.heberger(_port) == OK)
		print("HOTE_PRET")
		_v("invité connecté", await _attendre(func() -> bool: return R.joueurs().size() > 1, 150.0))
		await get_tree().create_timer(1.0).timeout
		await _test_salles(true)
		var inv: int = R.joueurs()[1]
		# registre : le nœud de l'invité alimente l'union sans callable de test
		var av := Node3D.new()
		get_tree().root.add_child(av)
		R.registre.definir_noeud(inv, av)
		var sa := _salle()
		sa.joueur.position = Vector3(5, 0, 5)
		av.position = Vector3(105, 0, 5)
		sa.rafraichir(true)
		_v("union via Reseau.registre (avatar de l'invité en C)", sa.actives.has("C") and sa.actives.has("A"), str(sa.actives.keys()))
		R.registre.definir_noeud(inv, null)
		await _hote_scenario()
	else:
		_v("invité : rejoindre OK", R.rejoindre("127.0.0.1", _port) == OK)
		_v("connecté", await _attendre(func() -> bool: return R.joueurs().size() > 1 and R.mon_id() > 1, 20.0))
		await get_tree().create_timer(1.0).timeout
		await _test_salles(true)
		await _attendre(func() -> bool: return _phase >= 9, 60.0)
		await get_tree().create_timer(0.5).timeout
	print("TEST_LIEUX %s %s" % [_role, "OK" if _ok else "ECHEC"])
	get_tree().quit(0 if _ok else 1)

func _go(n: int) -> void:
	_phase = n
	_R().envoyer_evenement("t_go", n, null)
	_sur_go(1, n, null)

func _hote_scenario() -> void:
	_go(1)           # coffre : hôte et invité demandent en même temps
	await get_tree().create_timer(2.0).timeout
	_go(2)           # porte demandée par l'invité
	await get_tree().create_timer(2.0).timeout
	_go(3)           # contenant : l'invité d'abord, l'hôte ensuite
	await get_tree().create_timer(2.5).timeout
	_go(4)           # instantané
	await get_tree().create_timer(2.0).timeout
	_go(5)           # bilan
	await _attendre(func() -> bool: return _phase >= 9, 15.0)
	await get_tree().create_timer(0.5).timeout

func _sur_go(expediteur: int, n: Variant, _d: Variant) -> void:
	if expediteur != 1:
		return
	_phase = int(n)
	match _phase:
		1:
			ReseauLieux.reclamer("crypte:cof_test", func() -> void:
				_gagnes["cof"] += 1
				_quetes.signaler("crypte:cof_test"), func() -> void: _perdus["cof"] += 1, "coffre")
		2:
			if _role != "hote":
				var stop := ReseauLieux.router_porte("crypte:s1")
				_v("invité : router_porte = « attendre la diffusion »", stop)
		3:
			if _role != "hote":
				_demander_urne()
			else:
				await get_tree().create_timer(1.0).timeout
				_demander_urne()
		4:
			if _role != "hote":
				pass
		5:
			_bilan_local()

func _demander_urne() -> void:
	ReseauLieux.reclamer("village:urne_test", func() -> void:
		ButinTables.piller("village:urne_test")
		_gagnes["urne"] += 1, func() -> void: _perdus["urne"] += 1, "contenant")

func _bilan_local() -> void:
	_v("porte appliquée exactement 1 fois localement", _portes_appliquees == 1, "n=%d" % _portes_appliquees)
	_v("porte marquée ouverte", ReseauLieux.porte_ouverte("crypte:s1"))
	_v("coffre marqué vidé localement (gagnant ou perdant)", _quetes.vus.has("crypte:cof_test"))
	_v("urne pillée localement", ButinTables.est_pille("village:urne_test"))
	if _role == "hote":
		# 2e demande de la même porte : plus rien à faire
		_v("hôte : porte déjà ouverte -> router_porte = true", ReseauLieux.router_porte("crypte:s1"))
		_R().envoyer_evenement("t_res", 0, {"cof": _gagnes["cof"], "urne": _gagnes["urne"], "export": ReseauLieux.exporter()})
	else:
		pass

func _sur_res(expediteur: int, _id: Variant, d: Variant) -> void:
	if expediteur != 1 or _role == "hote":
		return
	_v("coffre vidé UNE seule fois (somme des gagnants = 1)", int(d["cof"]) + _gagnes["cof"] == 1, "hôte=%d invité=%d" % [d["cof"], _gagnes["cof"]])
	_v("urne : un seul gagnant, et c'est l'invité (premier arrivé)", int(d["urne"]) == 0 and _gagnes["urne"] == 1, "hôte=%d invité=%d" % [d["urne"], _gagnes["urne"]])
	# instantané : l'invité repart de zéro puis importe celui de l'hôte (rejoindre en cours)
	ReseauLieux.reinitialiser()
	_quetes.vus.clear()
	ButinTables.pilles.erase("village:urne_test")
	var avant := _etat_rappels
	ReseauLieux.importer(d["export"])
	_v("instantané : porte ouverte restituée", ReseauLieux.porte_ouverte("crypte:s1"))
	_v("instantané : coffre vidé restitué (vus)", _quetes.vus.has("crypte:cof_test"))
	_v("instantané : urne pillée restituée", ButinTables.est_pille("village:urne_test"))
	_v("instantané : état ré-appliqué (rappel sur_etat)", _etat_rappels == avant + 1)
	_R().envoyer_evenement("t_fin", 0, {"ok": _ok})

func _sur_fin(expediteur: int, _id: Variant, d: Variant) -> void:
	if expediteur == 1:
		_phase = 9
	elif _role == "hote":
		_v("l'invité n'a aucun échec", bool(d["ok"]))
		_phase = 9
