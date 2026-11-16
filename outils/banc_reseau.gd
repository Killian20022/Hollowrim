extends SceneTree
## Banc réseau, UNE instance (hôte ou invité) : lancé deux fois par outils/banc_reseau.sh.
##   godot --headless --path . --script res://outils/banc_reseau.gd -- --role=hote|invite --port=24577
## Hôte : héberge, attend l'invité, vérifie joueurs() = [1, id], envoie « ping », attend « pong », attend la déconnexion de l'invité.
## Invité : rejoint, vérifie joueurs() contient l'hôte, répond « pong » au « ping », se déconnecte.
## Imprime « BANC_RESEAU <role> OK » ou « BANC_RESEAU <role> ECHEC » ; code de sortie 0 / 1.

var _role := "hote"
var _port := 24577
var _res: Node
var _ok := true
var _etat := {}

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.substr(7)
		elif a.begins_with("--port="):
			_port = int(a.substr(7))
	_lancer.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + "[" + _role + "] " + msg)
	if not cond:
		_ok = false

func _attendre(cond: Callable, delai: float) -> bool:
	var t := 0.0
	while not cond.call() and t < delai:
		await create_timer(0.05).timeout
		t += 0.05
	return cond.call()

func _lancer() -> void:
	_res = root.get_node_or_null("Reseau")
	_verif(_res != null, "autoload Reseau présent")
	if _res == null:
		quit(1)
		return
	# solo : rien ne se lance
	_verif(_res.est_hote() and not _res.est_en_ligne() and _res.mon_id() == 1 and _res.joueurs() == [1], "solo : hôte, hors ligne, joueurs()=[1]")
	if _role == "hote":
		await _hote()
	else:
		await _invite()
	print("BANC_RESEAU %s %s" % [_role, "OK" if _ok else "ECHEC"])
	quit(0 if _ok else 1)

func _hote() -> void:
	_res.joueur_connecte.connect(func(id: int) -> void: _etat["connecte"] = id)
	_res.joueur_deconnecte.connect(func(id: int) -> void: _etat["deconnecte"] = id)
	_res.abonner("pong", func(exp: int, id: Variant, d: Dictionary) -> void: _etat["pong"] = [exp, id, d])
	_verif(_res.heberger(_port) == OK, "heberger() = OK")
	_verif(_res.est_hote() and _res.est_en_ligne() and _res.mon_id() == 1, "hôte en ligne, id 1")
	print("HOTE_PRET")
	_verif(await _attendre(func() -> bool: return _etat.has("connecte"), 30.0), "joueur_connecte reçu")
	var inv: int = _etat.get("connecte", 0)
	_verif(inv > 1 and _res.joueurs() == [1, inv], "joueurs() = [1, %d]" % inv)
	_verif(_res.registre.a(inv), "registre contient l'invité")
	await create_timer(0.5).timeout
	_res.envoyer_evenement("ping", 7, {"texte": "salut", "n": 42})
	_verif(await _attendre(func() -> bool: return _etat.has("pong"), 10.0), "évènement « pong » reçu")
	var p: Array = _etat.get("pong", [])
	_verif(p.size() == 3 and p[0] == inv and p[1] == 8 and p[2].get("texte") == "salut!", "pong : expéditeur, id, données corrects")
	_verif(await _attendre(func() -> bool: return _etat.has("deconnecte"), 15.0), "joueur_deconnecte reçu")
	_verif(_res.joueurs() == [1], "joueurs() = [1] après déconnexion")
	_res.deconnecter()
	_verif(not _res.est_en_ligne() and _res.est_hote(), "retour solo")

func _invite() -> void:
	_res.joueur_connecte.connect(func(id: int) -> void: _etat["pair"] = id)
	_res.abonner("ping", func(exp: int, id: Variant, d: Dictionary) -> void:
		_etat["ping"] = true
		_res.envoyer_evenement("pong", int(id) + 1, {"texte": str(d.get("texte")) + "!"}))
	_verif(_res.rejoindre("127.0.0.1", _port) == OK, "rejoindre() = OK")
	_verif(await _attendre(func() -> bool: return _etat.has("ok") or _res.joueurs().size() > 1 and _res.mon_id() > 1, 20.0), "connecté")
	_verif(_res.est_en_ligne() and not _res.est_hote() and _res.mon_id() > 1, "invité en ligne, id > 1")
	_verif(_res.joueurs().has(1) and _res.joueurs().has(_res.mon_id()), "joueurs() contient hôte et moi : %s" % str(_res.joueurs()))
	_verif(await _attendre(func() -> bool: return _etat.has("ping"), 10.0), "évènement « ping » reçu")
	await create_timer(0.5).timeout
	_res.deconnecter()
	_verif(not _res.est_en_ligne() and _res.joueurs() == [1], "retour solo après deconnecter()")
	await create_timer(0.3).timeout
