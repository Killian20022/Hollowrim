extends Node
## LOT 3 : pause/menus, vote de sommeil, état « à terre » — UNE instance (hôte ou invité), lancée deux fois par outils/test_pause_vote.sh :
##   godot --headless --path . res://outils/test_pause_vote.tscn -- --role=hote|invite --port=24578
## Les deux instances déroulent le MÊME scénario en lockstep (barrières « sync »). Imprime « TEST ok / ECHEC … » puis
## « TEST_PAUSE_VOTE <role> OK|ECHEC » ; code de sortie 0 / 1.

class FauxCycle extends Node:
	var heure := 12.0
	func avancer_a(h: float) -> void:
		heure = h
	func _process(_dt: float) -> void:
		pass

class FauxMonde extends Node3D:
	var joueur: CharacterBody3D
	var village: Node3D
	var cycle: Node
	var hud: Node
	var dialogue: Control
	var vie: Node
	var faune: Node
	var marchand: Node

const JOUEUR := preload("res://scripts/joueur.gd")

var _role := "hote"
var _port := 24578
var _ok := true
var _res: Node
var _joueur: CharacterBody3D
var _monde: FauxMonde
var _somm: Sommeil
var _cycle: FauxCycle
var _vus := {}              # barrières reçues
var _clos: Array = []       # votes clos vus
var _dormi := 0
var _auto := ""             # réponse automatique aux votes : "" (aucune), "oui", "non"
var _avatar: ProtoAvatar

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.substr(7)
		elif a.begins_with("--port="):
			_port = int(a.substr(7))
	_lancer.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("TEST ok     " if cond else "TEST ECHEC  ") + "[" + _role + "] " + msg)
	if not cond:
		_ok = false

func _attendre(cond: Callable, delai: float) -> bool:
	var t := 0.0
	while not cond.call() and t < delai:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	return cond.call()

func _barriere(nom: String) -> void:
	_res.envoyer_evenement("sync", nom, null)
	if not await _attendre(func() -> bool: return _vus.has(nom), 40.0):
		_verif(false, "barrière « %s » jamais atteinte" % nom)
		get_tree().quit(1)

func _lancer() -> void:
	_res = get_node("/root/Reseau")
	_res.abonner("heure", func(_e: int, _i: Variant, d: Variant) -> void: _vus["h%.2f" % float(d["h"])] = true)
	_res.abonner("sync", func(_e: int, id: Variant, _d: Variant) -> void: _vus[String(id)] = true)
	# --- monde minimal : sol, joueur local, faux monde + vrai Sommeil ---
	_monde = FauxMonde.new()
	_monde.name = "Monde"
	get_tree().root.add_child(_monde)
	var sol := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	col.shape = box
	sol.add_child(col)
	sol.position = Vector3(0, -0.5, 0)
	_monde.add_child(sol)
	_cycle = FauxCycle.new()
	_monde.add_child(_cycle)
	_monde.cycle = _cycle
	_joueur = CharacterBody3D.new()
	_joueur.set_script(JOUEUR)
	_joueur.name = "Joueur"
	_joueur.position = Vector3(0, 0.1, 0) if _role == "hote" else Vector3(1.0, 0.1, 0)
	_monde.add_child(_joueur)
	_monde.joueur = _joueur
	_somm = Sommeil.installer(_monde)
	_somm.dormi.connect(func(_h: int, _m: String) -> void: _dormi += 1)
	_somm._vote.clos.connect(func(id: int, t: String, ok: bool, raison: String, _d: Dictionary) -> void: _clos.append([id, t, ok, raison]))
	_somm._vote.ouvert.connect(func(_id: int, _t: String, auteur: int, _d: Dictionary, _to: float) -> void:
		if auteur != _res.mon_id() and _auto != "":
			_somm._vote.repondre(_auto == "oui", "" if _auto == "oui" else "refusé par test"))
	await get_tree().create_timer(0.5).timeout          # le joueur retombe au sol
	_joueur.set("est_local", true)

	# ===== 1. solo : le monde SE MET en pause (comportement d'avant), puis reprend =====
	_verif(not _res.est_en_ligne(), "solo : hors ligne")
	_somm.fenetre.ouvrir("attendre", "test", 12.0, 1)
	_verif(get_tree().paused, "solo : menu ouvert -> monde EN PAUSE")
	_verif(not _joueur.en_dialogue, "solo : en_dialogue non touché par la pause")
	_somm.fenetre.fermer()
	_verif(not get_tree().paused, "solo : menu fermé -> monde repris")
	_verif(Effets.coop == false and Engine.time_scale == 1.0, "solo : Effets.coop faux, time_scale 1")

	# ===== connexion =====
	if _role == "hote":
		_verif(_res.heberger(_port) == OK, "heberger() OK")
		print("HOTE_PRET")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1, 40.0)
	else:
		_verif(_res.rejoindre("127.0.0.1", _port) == OK, "rejoindre() OK")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1 and _res.mon_id() > 1, 30.0)
	_verif(_res.joueurs().size() == 2, "2 joueurs en ligne")
	var autre: int = 1 if _role != "hote" else int(_res.joueurs()[1])
	_avatar = ProtoAvatar.creer(_monde, autre, Vector3(1.0, 0.0, 0.0) if _role == "hote" else Vector3(0, 0.0, 0))
	await _barriere("connectes")

	# ===== 2. coop : un menu NE met PAS le monde en pause =====
	_somm.fenetre.ouvrir("attendre", "test", 12.0, 1)
	_verif(not get_tree().paused, "coop : menu ouvert -> monde PAS en pause")
	_verif(_joueur.en_dialogue and PauseCoop.occupe() and PauseCoop.en_pause(get_tree()), "coop : joueur « occupé » (contrôles gelés), menu détecté")
	var t0 := _cycle.heure
	await get_tree().create_timer(0.3).timeout
	_verif(Engine.get_physics_frames() > 0 and not get_tree().paused, "coop : le monde continue de tourner pendant le menu")
	_somm.fenetre.fermer()
	_verif(not get_tree().paused and not _joueur.en_dialogue and not PauseCoop.occupe(), "coop : menu fermé -> joueur libre")
	_verif(_cycle.heure == t0, "coop : heure inchangée par un simple menu")
	Effets.coop = false
	await Effets._echelle_temps(get_tree(), 0.2, 0.2)
	_verif(Engine.time_scale == 1.0, "coop : Engine.time_scale reste à 1 (ralenti ignoré)")
	_auto = "oui"          # avant la barrière : la réponse doit être prête quand le vote arrive
	await _barriere("menus")

	# ===== 3. vote unanime : l'hôte propose, l'invité accepte =====
	_auto = "oui"
	_joueur.vie = 50.0
	_dormi = 0
	if _role == "hote":
		_somm._sur_choix(2, "attendre", null)
	var h_avant := _cycle.heure
	_verif(await _attendre(func() -> bool: return _dormi == 1, 20.0), "vote unanime : tout le monde a attendu (dormi émis)")
	_verif(_clos.size() >= 1 and _clos[-1][2] == true, "vote unanime : clos accepté %s" % str(_clos))
	await get_tree().create_timer(0.5).timeout
	_verif(is_equal_approx(_cycle.heure, fposmod(h_avant + 2.0, 24.0)), "vote unanime : heure avancée de 2 h (%.1f -> %.1f)" % [h_avant, _cycle.heure])
	_verif(_joueur.vie > 50.0, "vote unanime : jauges régénérées (%.1f)" % _joueur.vie)
	await _barriere("vote_oui")
	var h_commune := _cycle.heure
	_res.envoyer_evenement("heure", 0, {"h": h_commune})
	await get_tree().create_timer(0.5).timeout
	_verif(_vus.has("h%.2f" % h_commune), "vote unanime : même heure chez les deux (%.2f)" % h_commune)

	# ===== 4. vote refusé : l'invité propose, l'hôte refuse =====
	_clos.clear()
	_dormi = 0
	_auto = "non" if _role == "hote" else ""
	await _barriere("avant_refus")
	if _role != "hote":
		_somm._sur_choix(1, "attendre", null)
	_verif(await _attendre(func() -> bool: return _clos.size() == 1, 10.0), "vote refusé : clos reçu")
	_verif(_clos.size() == 1 and _clos[0][2] == false, "vote refusé : non accepté (%s)" % str(_clos))
	await get_tree().create_timer(1.0).timeout
	_verif(_dormi == 0 and is_equal_approx(_cycle.heure, h_commune), "vote refusé : personne n'a dormi, heure inchangée")
	await _barriere("refus")

	# ===== 5. timeout : personne ne répond =====
	_clos.clear()
	_auto = ""
	if _role == "hote":
		_somm._vote.proposer("sommeil", {"heures": 1, "mode": "attendre", "libelle": "test"}, 2.0)
	_verif(await _attendre(func() -> bool: return _clos.size() == 1, 10.0), "timeout : clos reçu")
	_verif(_clos.size() == 1 and _clos[0][2] == false and String(_clos[0][3]).contains("délai"), "timeout : refus « délai dépassé » (%s)" % str(_clos))
	await _barriere("timeout")

	# ===== 6. vote annulé si un joueur est touché =====
	_clos.clear()
	if _role == "hote":
		_somm._vote.proposer("sommeil", {"heures": 1, "mode": "attendre", "libelle": "test"}, 10.0)
	await _attendre(func() -> bool: return _somm._vote.en_cours(), 5.0)
	if _role != "hote":
		_joueur.touche.emit(5.0)          # touché pendant le vote
	_verif(await _attendre(func() -> bool: return _clos.size() == 1, 5.0), "annulation : clos reçu")
	_verif(_clos.size() == 1 and _clos[0][2] == false and String(_clos[0][3]).contains("touché"), "annulation : refus « touché » (%s)" % str(_clos))
	await _barriere("annule")

	# ===== 7. à terre puis relevé (l'invité tombe, l'hôte le relève) =====
	var at := ATerre.de(_joueur)
	_verif(at != null, "ATerre installé sur le joueur local")
	if _role != "hote":
		_joueur.vie = 10.0
		var r: String = _joueur.recevoir_coup(50.0, Vector3(5, 0, 0), {})
		_verif(_joueur.a_terre and not _joueur.mort and _joueur.vie == 0.0 and _joueur.en_dialogue, "à terre : tombé (pas mort), 0 PV, contrôles gelés (%s)" % r)
		_verif(_joueur.recevoir_coup(50.0, Vector3(5, 0, 0), {}) == "", "à terre : invulnérable")
	else:
		_verif(await _attendre(func() -> bool: return at.est_a_terre(autre), 5.0), "à terre : l'hôte voit l'invité à terre")
		await get_tree().create_timer(0.5).timeout
		ATerre.touche_forcee = true       # maintient « interagir » à côté de l'invité (1 m)
	if _role != "hote":
		_verif(await _attendre(func() -> bool: return not _joueur.a_terre, 10.0), "relevé : l'invité n'est plus à terre après ~3 s")
		_verif(not _joueur.mort and _joueur.vie > 20.0 and _joueur.vie < 40.0 and not _joueur.en_dialogue, "relevé : PV partiels (%.0f), contrôles rendus" % _joueur.vie)
	else:
		await _attendre(func() -> bool: return not at.est_a_terre(autre), 10.0)
		_verif(not at.est_a_terre(autre), "relevé : l'hôte voit l'invité debout")
		ATerre.touche_forcee = false
	await _barriere("releve")

	# ===== 8. à terre, le délai expire (secours absent) -> mort habituelle =====
	if _role != "hote":
		_joueur.vie = 10.0
		_joueur.recevoir_coup(50.0, Vector3(5, 0, 0), {})
		_verif(_joueur.a_terre, "délai : de nouveau à terre")
		at.reste = 0.3
		_verif(await _attendre(func() -> bool: return _joueur.mort, 3.0), "délai : mort/rechargement habituels à l'expiration")
		_joueur.ressusciter(Vector3(1, 0.1, 0), 0.0)
		_verif(not _joueur.mort and not _joueur.a_terre, "délai : ressuscité")
	await _barriere("delai")

	# ===== 9. à terre sans allié debout : l'hôte tombe, l'invité tombe ensuite = mort immédiate pour lui =====
	if _role == "hote":
		await _attendre(func() -> bool: return not at.est_a_terre(autre), 5.0)    # l'invité est réapparu
		_joueur.vie = 10.0
		_joueur.recevoir_coup(50.0, Vector3(5, 0, 0), {})
		_verif(_joueur.a_terre, "tous à terre : l'hôte tombe (l'invité est debout)")
	else:
		await _attendre(func() -> bool: return at.est_a_terre(1), 5.0)
		_verif(at.est_a_terre(1), "tous à terre : l'invité voit l'hôte à terre")
		_joueur.vie = 10.0
		_joueur.recevoir_coup(50.0, Vector3(5, 0, 0), {})
		_verif(_joueur.mort and not _joueur.a_terre, "tous à terre / sans allié debout : mort immédiate (pas d'état à terre)")
	if _role == "hote":
		_verif(await _attendre(func() -> bool: return _joueur.mort, 5.0), "tous à terre : l'hôte, sans allié debout, meurt aussi")
	await _barriere("fin")
	await get_tree().create_timer(1.0).timeout      # laisse partir le dernier paquet avant de couper
	# ===== 10. solo : sans réseau, 0 PV = mort directe =====
	_res.deconnecter()
	_joueur.ressusciter(Vector3(0, 0.1, 0), 0.0)
	_joueur.vie = 10.0
	_joueur.recevoir_coup(50.0, Vector3(5, 0, 0), {})
	_verif(_joueur.mort and not _joueur.a_terre, "solo : 0 PV = mort directe (jamais « à terre »)")
	print("TEST_PAUSE_VOTE %s %s" % [_role, "OK" if _ok else "ECHEC"])
	get_tree().quit(0 if _ok else 1)
