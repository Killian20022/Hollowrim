extends SceneTree
## Butin des corps sauvegardé (scripts/butin.gd cle_sauvegarde, ButinTables.corps / restes, Butin.restaurer) :
##   - un corps d'ennemi garde ses objets dans ButinTables.restes[« ennemi:<id> »] et sa position dans ButinTables.corps ;
##   - objet pris à la fenêtre → l'état suit ; exporter / JSON / importer / restaurer repose le corps avec les objets restants, à sa place ;
##   - tout pris : plus rien exporté ; ancienne sauvegarde sans « corps » : importée sans erreur ; sans clé : rien n'est sauvegardé.
##   godot --headless --path . --script res://outils/test_butin_corps.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")
const BUTIN := preload("res://scripts/butin.gd")

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

func _corps(m: Node3D, cle: String, contenu: Dictionary, pos: Vector3) -> Node3D:
	var b := Node3D.new()
	b.set_script(BUTIN)
	b.joueur = m.joueur
	b.hud = m.hud
	b.contenu = contenu
	b.nom_corps = "Draugr d'essai"
	b.cle_sauvegarde = cle
	m.add_child(b)
	b.global_position = pos
	return b

func _tester() -> void:
	ButinTables.reinitialiser()
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(0.3)
	var fb: FenetreButin = m.fenetre_butin
	var inv: Inventaire = m.joueur.inventaire
	var pos: Vector3 = m.joueur.global_position + Vector3(6.0, 0.0, 0.0)
	var b := _corps(m, "ennemi:essai_1", {"collier_or": 1, "os_draugr": 2}, pos)
	await _attendre(0.2)
	_verif(b.a_fouille() and ButinTables.a_reste("ennemi:essai_1") and ButinTables.corps.has("ennemi:essai_1"), "corps avec objets : état + position notés")
	var sans := _corps(m, "", {"os_draugr": 1}, pos + Vector3(0, 0, 4))
	await _attendre(0.2)
	_verif(ButinTables.restes.size() == 1 and ButinTables.corps.size() == 1, "corps sans clé : non sauvegardé")
	# prise partielle à la fenêtre
	_verif(b.fouiller() and fb.ouvert, "fouille : fenêtre ouverte")
	var ligne := -1
	for i in fb.lignes.size():
		if String(fb.lignes[i]["id"]) == "collier_or":
			ligne = i
	fb.prendre(ligne)
	fb.fermer()
	_verif(inv.a("collier_or") and ButinTables.reste("ennemi:essai_1") == {"os_draugr": 2}, "collier pris : il reste %s" % str(ButinTables.reste("ennemi:essai_1")))
	# sauvegarde JSON, nouvelle partie en mémoire, rechargement
	var json := JSON.stringify(ButinTables.exporter())
	var d: Dictionary = JSON.parse_string(json)
	_verif(d["corps"].has("ennemi:essai_1") and not d["corps"].has("ennemi:"), "exporté : %s" % json.substr(0, 200))
	ButinTables.importer(d)
	_verif(ButinTables.reste("ennemi:essai_1") == {"os_draugr": 2} and typeof(ButinTables.reste("ennemi:essai_1")["os_draugr"]) == TYPE_INT, "importé : restes en entiers")
	var ancien: Node3D = b
	BUTIN.restaurer(m, m.joueur, m.hud)
	await _attendre(0.3)
	_verif(not is_instance_valid(ancien) or ancien.is_queued_for_deletion(), "restauration : l'ancien corps de la partie en cours est retiré")
	var nouveaux := get_nodes_in_group("corps_butin")
	_verif(nouveaux.size() == 1, "un seul corps reposé (%d)" % nouveaux.size())
	if nouveaux.size() == 1:
		var n: Node3D = nouveaux[0]
		_verif(n.global_position.distance_to(pos) < 0.05 and n.objets == {"os_draugr": 2} and n.a_fouille() and n.nom_corps == "Draugr d'essai",
			"corps reposé à sa place (%s), objets %s, invite « Fouiller »" % [str(n.global_position), str(n.objets)])
		n.fouiller()
		fb.tout_prendre()
		await _attendre(0.2)
		_verif(inv.a("os_draugr") and not ButinTables.a_reste("ennemi:essai_1") and ButinTables.exporter()["corps"].is_empty(), "tout pris : plus rien à sauvegarder")
	# ancienne sauvegarde : pas de clé « corps »
	ButinTables.importer({"graine": 5, "pilles": ["a"], "restes": {}})
	_verif(ButinTables.corps.is_empty() and ButinTables.est_pille("a"), "ancienne sauvegarde (sans « corps ») : importée sans erreur")
	if is_instance_valid(sans):
		sans.queue_free()
	await _attendre(0.1)
	print("ECHECS : %d" % _echecs)
	quit(_echecs)
