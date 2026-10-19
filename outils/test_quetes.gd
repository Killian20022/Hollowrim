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
	print("   sous terre : ", t.dedans, " lune visible : ", m.cycle.lumiere.visible, " y=", snappedf(m.joueur.global_position.y, 0.1))
	t._tirer_levier()
	print("   ", t._fouiller_eirik().size(), " lignes de note ; quêtes : ", _etat())
	print("5. approcher du sarcophage : Svanhild se lève")
	m.joueur.global_position = t.crypte.to_global(Vector3(0, 0.1, -44.0))
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
	quit()
