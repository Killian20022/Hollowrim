extends SceneTree
## Test lot 2a, UNE instance (hote | inv1 | inv2) : lancé 3 fois par outils/test_rejoindre.sh.
## Monde factice : état {heure, pris} (contributeur « test »), entité « mob » (cercle près de l'hôte), « loin » (à 300 m).
## Scénario : inv1 rejoint (état A) -> l'hôte modifie l'état (B) -> inv2 rejoint APRÈS (doit voir B) ; inv1 se déconnecte puis se reconnecte (voit B).
## Imprime « TEST ok/ECHEC … » puis « REJOINDRE <role> OK|ECHEC ».

var R: Node
var Rep: Node
var Rej: Node
var role := "hote"
var port := 24578
var ok := true
var etat := {"heure": 8.0, "pris": ["clef"]}
var ev := {}
var mob: Node3D
var loin: Node3D
var recus := {"mob": 0, "loin": 0}
var derniere := {"mob": Vector3.ZERO}

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="): role = a.substr(7)
		elif a.begins_with("--port="): port = int(a.substr(7))
	_lancer.call_deferred()

func v(c: bool, m: String) -> void:
	print(("TEST ok    " if c else "TEST ECHEC ") + "[" + role + "] " + m)
	if not c: ok = false

func attendre(c: Callable, d: float) -> bool:
	var t := 0.0
	while not c.call() and t < d:
		await create_timer(0.05).timeout
		t += 0.05
	return c.call()

func _brancher() -> void:
	R = root.get_node("Reseau"); Rep = root.get_node("Replicateur"); Rej = root.get_node("Rejoindre")
	Rej.contributeur("test", func() -> Dictionary: return etat.duplicate(true),
		func(d: Dictionary) -> void: etat = d.duplicate(true))
	mob = Node3D.new(); loin = Node3D.new()
	root.add_child(mob); root.add_child(loin)
	loin.position = Vector3(300, 0, 0)
	Rep.enregistrer("mob", mob,
		func() -> Dictionary: return {"pos": mob.position, "a_lacet": 0.0, "vie": 10.0},
		func(s: Dictionary) -> void: recus["mob"] += 1; derniere["mob"] = s["pos"], 90.0)
	Rep.enregistrer("loin", loin,
		func() -> Dictionary: return {"pos": loin.position},
		func(_s: Dictionary) -> void: recus["loin"] += 1, 90.0)
	R.abonner("modif", func(_e: int, _i: Variant, d: Variant) -> void: etat = d.duplicate(true); ev["modif"] = true)
	R.abonner("go_reco", func(_e: int, _i: Variant, _d: Variant) -> void: ev["go_reco"] = true)
	R.abonner("fin", func(_e: int, _i: Variant, _d: Variant) -> void: ev["fin"] = true)
	R.abonner("pret", func(e: int, i: Variant, _d: Variant) -> void: ev["pret_" + str(i)] = e)

func _process(_dt: float) -> bool:
	if role == "hote" and mob != null:   # le mob tourne en rond (rayon 5) autour de (0,0,0)
		var t := Time.get_ticks_msec() / 1000.0
		mob.position = Vector3(cos(t) * 5.0, 0, sin(t) * 5.0)
	return false

func _lancer() -> void:
	_brancher()
	if role == "hote":
		await _hote()
	else:
		await _invite()
	print("REJOINDRE %s %s" % [role, "OK" if ok else "ECHEC"])
	quit(0 if ok else 1)

func _hote() -> void:
	R.joueur_connecte.connect(func(id: int) -> void:   # avatar de l'invité : inv1 au centre, inv2 à 300 m
		var n := Node3D.new(); root.add_child(n)
		n.position = Vector3.ZERO if not ev.has("inv1") else Vector3(300, 0, 0)
		if not ev.has("inv1"): ev["inv1"] = id
		else: ev["inv2"] = id
		R.registre.definir_noeud(id, n))
	v(R.heberger(port) == OK, "hôte héberge")
	print("HOTE_PRET")
	v(await attendre(func() -> bool: return ev.has("pret_inv1_a"), 40.0), "inv1 a vérifié l'état A")
	etat = {"heure": 20.5, "pris": ["clef", "hache"]}
	R.envoyer_evenement("modif", 0, etat)   # inv1 connecté : propagation en direct
	print("ETAT_MODIFIE")
	v(await attendre(func() -> bool: return ev.has("pret_inv2_b"), 60.0), "inv2 (rejoint après) a vu l'état B")
	v(R.joueurs().size() == 3, "3 joueurs présents avant la reconnexion : %s" % str(R.joueurs()))
	Rep.diffuser("go_reco", 0, null)   # inv1 peut se déconnecter / se reconnecter pendant que inv2 est là
	v(await attendre(func() -> bool: return ev.has("pret_inv1_reco"), 60.0), "inv1 reconnecté a vu l'état B")
	v(R.joueurs().size() == 3, "3 joueurs de nouveau présents : %s" % str(R.joueurs()))
	Rep.diffuser("fin", 0, null)
	await create_timer(1.0).timeout
	R.deconnecter()

func _invite() -> void:
	v(R.rejoindre("127.0.0.1", port) == OK, "rejoindre()")
	v(await attendre(func() -> bool: return R.est_en_ligne() and R.joueurs().size() > 1, 40.0), "connecté")
	if role == "inv1":
		v(await attendre(func() -> bool: return recus["mob"] > 5, 20.0), "marionnette « mob » mise à jour (%d)" % recus["mob"])
		v(etat["heure"] == 8.0 and etat["pris"] == ["clef"], "état A cohérent (init) : %s" % str(etat))
		R.envoyer_evenement("pret", "inv1_a", null)
		v(await attendre(func() -> bool: return ev.has("modif"), 20.0), "modification reçue en direct")
		# marionnette cohérente : rayon ~5 autour de l'origine (interpolation), pas de « loin »
		v(absf(Vector3(derniere["mob"]).length() - 5.0) < 0.5, "mob interpolé sur le cercle, |pos|=%.2f" % Vector3(derniere["mob"]).length())
		v(recus["loin"] == 0, "entité à 300 m jamais reçue (pertinence)")
		v(await attendre(func() -> bool: return ev.has("go_reco"), 90.0), "inv2 est là (3 joueurs) : go")
		R.deconnecter()
		etat = {"heure": 0.0, "pris": []}
		v(not R.est_en_ligne(), "déconnecté")
		await create_timer(1.0).timeout
		v(R.rejoindre("127.0.0.1", port) == OK, "reconnexion")
		v(await attendre(func() -> bool: return etat["heure"] == 20.5, 20.0), "reconnecté : état B retrouvé %s" % str(etat))
		v(etat["pris"] == ["clef", "hache"], "objets pris cohérents")
		R.envoyer_evenement("pret", "inv1_reco", null)
	else:
		v(await attendre(func() -> bool: return etat["heure"] == 20.5, 20.0), "état B reçu à la connexion")
		v(etat["pris"] == ["clef", "hache"], "objets pris cohérents après rejoindre tardif")
		await create_timer(1.5).timeout
		v(recus["loin"] > 5, "inv2 (à 300 m) reçoit « loin » (%d)" % recus["loin"])
		v(recus["mob"] == 0, "inv2 ne reçoit pas « mob » (hors pertinence)")
		R.envoyer_evenement("pret", "inv2_b", null)
	v(await attendre(func() -> bool: return ev.has("fin"), 60.0), "fin reçue de l'hôte")
	R.deconnecter()
