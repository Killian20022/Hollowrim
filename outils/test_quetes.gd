extends SceneTree
## Test sans fenêtre : joue les trois quêtes de bout en bout en appelant le jeu directement.
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node

func _init() -> void:
	_tester.call_deferred()

func _villageois(id: String) -> Node:
	for v in m.get_tree().get_nodes_in_group("villageois"):
		if v.donnees.get("id") == id:
			return v
	return null

func _parler(id: String) -> void:
	var lignes: Array = _villageois(id).parler()
	print("  ", id, " dit ", lignes.size(), " répliques : « ", lignes[-1], " »")
	_villageois(id).fin_conversation()

func _etat() -> String:
	return str(m.quetes.etat)

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 10:
		await process_frame
	var t = m.tertre
	print("1. parler à la cheffe")
	_parler("chef")
	print("   quêtes : ", _etat())
	print("2. Ylva et Brodd")
	_parler("chasseuse")
	_parler("forgeron")
	print("   quêtes : ", _etat())
	print("3. arriver au tertre")
	m.joueur.global_position = t.porte_dehors
	await process_frame
	await process_frame
	print("   quêtes : ", _etat())
	print("4. entrer, tirer le levier, fouiller Eirik")
	t._passer(true)
	await create_timer(1.5).timeout
	# refonte crypte : si le donjon n'est pas encore bâti, l'écran reste noir et l'entrée se fait dès qu'il est prêt
	var essais := 0
	while not t.dedans and essais < 200:
		await create_timer(0.1).timeout
		essais += 1
	print("   sous terre : ", t.dedans, " lune visible : ", m.cycle.lumiere.visible, " y=", snappedf(m.joueur.global_position.y, 0.1))
	t._tirer_levier()
	print("   ", t._fouiller_eirik().size(), " lignes de note ; quêtes : ", _etat())
	print("5. approcher du sarcophage : Svanhild se lève")
	m.joueur.global_position = t.crypte.to_global(t.SARCO + Vector3(0, 0.1, 5.0))
	for i in 5:
		await process_frame
	var s = t._svanhild
	print("   Svanhild : ", s != null, " vie=", s.vie if s else -1)
	s.recevoir_coup(999.0, m.joueur.global_position, true)
	await process_frame
	print("   quêtes : ", _etat(), " peut rendre : ", t._peut_rendre())
	t._rendre_anneau()
	print("   quêtes : ", _etat())
	print("6. ressortir, conclure")
	t._passer(false)
	await create_timer(1.5).timeout
	_parler("chef")
	_parler("chasseuse")
	m.joueur.inventaire.ajouter("lame_antique", 3)
	await process_frame
	_parler("forgeron")
	var inv = m.joueur.inventaire
	print("   quêtes : ", _etat(), " | pièces=", inv.pieces, " objets=", inv.objets)
	var ok: bool = m.quetes.etat.get("anneau_givre", 0) == 6 and m.quetes.etat.get("frere_ylva", 0) == 3 and m.quetes.etat.get("lames_brodd", 0) == 3
	ok = ok and inv.a("amulette_givre") and inv.a("epee_skarnholt") and inv.pieces == 210 and not inv.a("anneau_givre") and not inv.a("lame_antique") and not inv.a("amulette_eirik")
	print("TEST QUÊTES : ", "OK" if ok else "ÉCHEC")
	ok = await _tester_donjons() and ok
	print("TEST QUÊTES DONJONS : ", "OK" if ok else "ÉCHEC")
	quit()

func _verif(ok: bool, msg: String) -> bool:
	print(("OK    " if ok else "ECHEC ") + msg)
	return ok

## Quêtes de la grotte et de la crypte, choix moral, sauvegarde / rechargement.
func _tester_donjons() -> bool:
	var q = m.quetes
	var inv = m.joueur.inventaire
	var bon := true
	print("7. Le repaire de Hrafn (donneur : Haldor)")
	_parler("garde")
	bon = _verif(q.etat.get("repaire_hrafn", 0) == 1, "quête lancée par Haldor") and bon
	q.signaler("lieu:camp_hrafn")
	q.signaler("tue:hrafn")
	bon = _verif(q.etat.get("repaire_hrafn", 0) == 3, "camp trouvé, Hrafn tué") and bon
	inv.ajouter("registre_hrafn", 1)  # détecté par le sac : « ramasse:registre_hrafn »
	bon = _verif(q.etat.get("repaire_hrafn", 0) == 4 and q.vus.has("ramasse:registre_hrafn"), "registre ramassé (détecté dans le sac)") and bon
	var p0: int = inv.pieces
	_parler("garde")
	bon = _verif(q.etat.get("repaire_hrafn", 0) == 5 and inv.pieces == p0 + 120 and not inv.a("registre_hrafn"), "registre remis, +120 pièces") and bon
	print("8. L'expédition de Sigrun (donneur : Grima)")
	q.signaler("ramasse:journal_sigrun")  # événement avant la quête : retenu
	q.signaler("ramasse:broche_sigrun")
	_parler("ancienne")
	bon = _verif(q.etat.get("expedition_sigrun", 0) == 3, "quête lancée, journal et broche déjà vus") and bon
	_parler("ancienne")
	bon = _verif(q.etat.get("expedition_sigrun", 0) == 4, "rendue à Grima") and bon
	print("9. Les sceaux brisés et le Jarl gelé")
	bon = _verif(q.etat.get("sceaux_brises", 0) >= 1, "sceaux : lancée à l'approche du tertre") and bon
	q.signaler("ramasse:fragment_sceau_givre")
	q.signaler("ramasse:fragment_sceau_os")
	q.signaler("ramasse:fragment_sceau_eau")
	q.signaler("meca:socles_rituel:complet")
	bon = _verif(q.etat.get("sceaux_brises", 0) == 5, "3 fragments puis socles : quête terminée (dans le désordre)") and bon
	q.signaler("tue:jarl")
	bon = _verif(q.etat.get("jarl_gele", 0) == 2, "Jarl tué : quête lancée et avancée même sans passer par la salle du trône") and bon
	q.signaler("ramasse:hache_kolbeinn")
	bon = _verif(q.etat.get("jarl_gele", 0) == 3, "hache ramassée") and bon
	print("10. Choix moral : respecter les offrandes")
	bon = _verif(m.joueur.vie_max == 100.0 and q.choix_fait() == "", "avant : 100 de vie max, aucun choix") and bon
	bon = _verif(q.choisir("respecter_offrandes"), "choix accepté") and bon
	bon = _verif(m.joueur.vie_max == 110.0 and q.benediction() and q.vus.has("choix:respecter_offrandes"), "bénédiction : 110 de vie max") and bon
	bon = _verif(not q.choisir("piller_offrandes") and not q.vus.has("vague_gardiens"), "le choix est définitif") and bon
	var sauve: Dictionary = JSON.parse_string(JSON.stringify(q.exporter()))  # comme le fichier de sauvegarde
	m.joueur.vie_max = 100.0
	q.importer(sauve)
	bon = _verif(m.joueur.vie_max == 110.0 and q.choix_fait() == "respecter_offrandes" and q.etat.get("repaire_hrafn", 0) == 5, "rechargement : bénédiction et quêtes restaurées") and bon
	q.importer({"etat": {"anneau_givre": 2}, "vus": [], "journal": []})
	bon = _verif(m.joueur.vie_max == 100.0 and q.choix_fait() == "", "ancienne sauvegarde : valeurs par défaut (100, pas de choix)") and bon
	print("11. Choix moral : piller")
	q.importer({"etat": {}, "vus": [], "journal": []})
	var p1: int = inv.pieces
	var vague := {"vue": false}
	q.evenement.connect(func(e: String) -> void:
		if e == "vague_gardiens":
			vague["vue"] = true)
	bon = _verif(q.choisir("piller_offrandes"), "piller accepté") and bon
	bon = _verif(inv.pieces == p1 + q.PILLAGE_PIECES and vague["vue"] and q.vus.has("vague_gardiens") and m.joueur.vie_max == 100.0, "or reçu, événement vague_gardiens émis, pas de bénédiction") and bon
	for cle in ["fresque_sceaux", "note_compagnon_1", "note_compagnon_2", "note_compagnon_3", "journal_gardien", "fresque_svanhild", "journal_sigrun", "registre_hrafn", "inscription_offrandes"]:
		bon = _verif(q.texte(cle).size() >= 1, "texte « %s » présent" % cle) and bon
	return bon
