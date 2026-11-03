extends SceneTree
## Mode --test-butin (Jeu.test_butin, Monde._test_butin) : 5000 pièces, toutes les armures de armures.json, tous les tomes,
## tous les sorts appris, jamais surchargé, et PAS de doublon au rechargement d'une sauvegarde (drapeau test_butin_fait).
##   godot --headless --path . --script res://outils/test_mode_butin.gd -- --nouvelle --test-butin
const SCENE := preload("res://scenes/foret_test.tscn")

var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in int(ceil(s * 60.0)):
		await process_frame

func _tomes() -> Array:
	var r := []
	for id in Inventaire.OBJETS:
		var e = Inventaire.OBJETS[id].get("effets", {})
		if e is Dictionary and e.has("apprendre"):
			r.append(String(id))
	return r

func _tester() -> void:
	_verif(Jeu.test_butin(), "Jeu.test_butin() lu depuis la ligne de commande")
	var armures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/objets/armures.json"))["objets"]
	var tomes := _tomes()
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(0.5)
	var inv: Inventaire = m.joueur.inventaire
	_verif(inv.pieces >= 5000, "5000 pièces (%d)" % inv.pieces)
	var manque := []
	for id in armures:
		if inv.nombre(String(id)) != 1:
			manque.append(id)
	_verif(armures.size() > 0 and manque.is_empty(), "%d armures dans le sac, une de chaque (manque : %s)" % [armures.size(), str(manque)])
	manque = []
	for id in tomes:
		if inv.nombre(id) != 1:
			manque.append(id)
	_verif(tomes.size() > 0 and manque.is_empty(), "%d tomes dans le sac (manque : %s)" % [tomes.size(), str(manque)])
	var sorts := DirAccess.get_files_at("res://data/sorts/").size()
	var magie = m.joueur.mains.magie
	_verif(magie.eq.sorts_connus.size() >= sorts / 2 and magie.eq.sorts_connus.size() > 5, "sorts appris : %d" % magie.eq.sorts_connus.size())
	_verif(magie.eq.sorts_connus.has("orage_runique"), "orage runique appris")
	_verif(inv.nombre("tome_orage_runique") == 1, "tome de l'orage runique dans le sac")
	_verif(not inv.surcharge(), "pas de surcharge (%.0f kg / %.0f)" % [inv.poids(), inv.capacite()])
	# sauvegarde puis rechargement dans un monde neuf : aucun doublon
	m.sauvegarder()
	var avant := inv.objets.duplicate()
	var pieces := inv.pieces
	m.queue_free()
	await _attendre(0.3)
	var m2: Node3D = SCENE.instantiate()
	m2.set_meta("test", true)
	root.add_child(m2)
	await _attendre(0.5)
	m2.charger()
	m2._test_butin()
	var inv2: Inventaire = m2.joueur.inventaire
	_verif(inv2.objets == avant and inv2.pieces == pieces, "rechargement : sac identique, pas de doublon (%d pièces)" % inv2.pieces)
	m2.queue_free()
	print("ECHECS : %d" % _echecs if _echecs > 0 else "Tout est OK.")
	quit(_echecs)
