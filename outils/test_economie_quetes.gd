extends Node
## LOT 5a : crime par joueur, quêtes partagées, commerce arbitré, verrou de conversation — UNE instance (hôte ou invité), lancée deux fois par
## outils/test_economie_quetes.sh : godot --headless --path . res://outils/test_economie_quetes.tscn -- --role=hote|invite --port=25011
## Les deux instances déroulent le MÊME scénario en lockstep (barrières). Imprime « TEST ok / ECHEC … » puis « TEST_ECONOMIE_QUETES <role> OK|ECHEC ».

class FauxCycle extends Node:
	var heure := 12.0
	var jour := 1
	func avancer_a(h: float) -> void:
		heure = fposmod(h, 24.0)

class FauxHud extends Control:
	var avis_recus: Array = []
	func avis(t: String) -> void:
		avis_recus.append(t)
	func annonce(_a: String, _b: String) -> void:
		pass
	func objectif_change() -> void:
		pass

class FauxMonde extends Node3D:
	var joueur: CharacterBody3D
	var village: Node3D
	var cycle: Node
	var hud: Node
	var dialogue: Control
	var vie: Node
	var quetes: Node
	var crime: Node

## PNJ du village minimal : témoin (groupe villageois, donnees.id) ou interlocuteur.
class FauxPnj extends Node3D:
	var donnees := {}
	var remplace: Node = null
	var _en_conversation := false
	var _conv_distante := false
	var _debut_conversation := 0.0
	func nom_affiche() -> String:
		return String(donnees.get("nom", "?"))
	func fin_conversation() -> void:
		_en_conversation = false

const JOUEUR := preload("res://scripts/joueur.gd")
const QUETES := preload("res://scripts/quetes.gd")

var _role := "hote"
var _port := 25011
var _ok := true
var _res: Node
var _monde: FauxMonde
var _joueur: CharacterBody3D
var _hud: FauxHud
var _crime: Crime
var _q: Node
var _vus := {}
var _autre := 1
var _refus_recu := false
var _bilan_autre := -1
var _bilan2 := -1

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

func _pnj(id: String, pos: Vector3) -> FauxPnj:
	var p := FauxPnj.new()
	p.donnees = {"id": id, "nom": id, "type": "paysan"}
	p.name = id
	p.position = pos
	p.add_to_group("villageois")
	_monde.add_child(p)
	return p

func _prime_de(peer: int) -> float:
	var v: Variant = _crime.en_tant_que(peer, func() -> Variant: return _crime.prime())
	return -1.0 if v == null else float(v)

func _hostile_de(peer: int) -> bool:
	return bool(_crime.en_tant_que(peer, func() -> Variant: return _crime.est_hostile()))

func _objet_vole() -> Node3D:
	var o := Node3D.new()
	o.set_meta("id_objet", "potion_soin")
	return o

func _lancer() -> void:
	_res = get_node("/root/Reseau")
	_res.abonner("sync", func(_e: int, id: Variant, _d: Variant) -> void: _vus[String(id)] = true)
	_res.abonner("bilan", func(_e: int, _id: Variant, d: Variant) -> void: _bilan_autre = int(d))
	_res.abonner("bilan2", func(_e: int, _id: Variant, d: Variant) -> void: _bilan2 = int(d))
	# --- monde minimal : sol, joueur local, témoins, quêtes, crime ---
	_monde = FauxMonde.new()
	_monde.name = "Monde"
	get_tree().root.add_child(_monde)
	var sol := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	col.shape = box
	sol.add_child(col)
	sol.position = Vector3(0, -0.5, 0)
	_monde.add_child(sol)
	var cyc := FauxCycle.new()
	_monde.add_child(cyc)
	_monde.cycle = cyc
	_hud = FauxHud.new()
	_monde.add_child(_hud)
	_monde.hud = _hud
	_joueur = CharacterBody3D.new()
	_joueur.set_script(JOUEUR)
	_joueur.name = "Joueur"
	_joueur.position = Vector3(0, 0.1, 4) if _role == "hote" else Vector3(40, 0.1, 4)
	_monde.add_child(_joueur)
	_monde.joueur = _joueur
	_q = Node.new()
	_q.set_script(QUETES)
	_q.set("joueur", _joueur)
	_q.set("hud", _hud)
	_q.name = "Quetes"
	_monde.add_child(_q)
	_monde.quetes = _q
	ConversationsCoop.brancher()        # normalement faits par Dialogue._ready et Marchand._ready
	MarchandCoop.brancher()
	_pnj("temoin_a", Vector3(0, 0, 0))        # voit le joueur de l'hôte (z = 4, devant lui)
	_pnj("temoin_b", Vector3(40, 0, 0))       # voit le joueur de l'invité
	var pc1 := _pnj("causeur_1", Vector3(20, 0, -40))
	var pc2 := _pnj("causeur_2", Vector3(20, 0, -50))
	_crime = Crime.new()
	_crime.name = "Crime"
	_crime.monde = _monde
	_crime.joueur = _joueur
	_crime.hud = _hud
	_monde.add_child(_crime)
	_monde.crime = _crime
	await get_tree().create_timer(0.5).timeout          # le joueur retombe au sol
	_joueur.set("est_local", true)
	_joueur.inventaire.ajouter("pieces", 1000)

	# ===== 0. solo : tout est inchangé =====
	_verif(not _res.est_en_ligne(), "solo : hors ligne")
	_verif(ConversationsCoop.prendre(pc1) and not MarchandCoop.invite(), "solo : verrou de conversation toujours libre, commerce local")
	ConversationsCoop.liberer(pc1)
	_verif(_crime.prime() == 0.0 and not _crime.est_distant(), "solo : prime 0, contexte local")
	var a0 := _crime.signaler_vol(_objet_vole(), "personne", _joueur.global_position)
	_verif(a0 and _crime.prime() >= 5.0 and _crime.est_hostile() == false, "solo : un vol vu par un témoin = prime (%.0f)" % _crime.prime())
	_crime.ajouter_prime(-_crime.prime())
	_crime.voles.clear()
	_crime.reputation.clear()
	_crime.perdue.clear()

	# ===== connexion =====
	if _role == "hote":
		_verif(_res.heberger(_port) == OK, "heberger() OK")
		print("HOTE_PRET")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1, 40.0)
	else:
		_verif(_res.rejoindre("127.0.0.1", _port) == OK, "rejoindre() OK")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1 and _res.mon_id() > 1, 30.0)
	_verif(_res.joueurs().size() == 2, "2 joueurs en ligne")
	_autre = 1 if _role != "hote" else int(_res.joueurs()[1])
	ProtoAvatar.creer(_monde, _autre, Vector3(0, 0.1, 4) if _role != "hote" else Vector3(40, 0.1, 4))
	await _barriere("connectes")
	await get_tree().create_timer(0.5).timeout

	# ===== 1. CRIME PAR JOUEUR : le vol de l'hôte ne touche pas l'invité =====
	var p_hote := 0.0
	if _role == "hote":
		_crime.signaler_vol(_objet_vole(), "personne", _joueur.global_position)
		p_hote = _crime.prime()
		_verif(p_hote >= 5.0, "hôte : son vol vu par le témoin A lui vaut une prime (%.0f)" % p_hote)
	await _barriere("c1")
	await get_tree().create_timer(0.4).timeout
	if _role == "hote":
		_verif(_prime_de(_autre) == 0.0 and not _hostile_de(_autre), "hôte : l'invité n'a ni prime ni hostilité du fait de l'hôte")
	else:
		_verif(_crime.prime() == 0.0 and not _crime.est_hostile(), "invité : aucune prime pour un crime de l'hôte")
	# le vol de l'invité : arbitré par l'hôte (témoin B voit SON avatar), prime renvoyée à l'invité
	if _role != "hote":
		_crime.signaler_vol(_objet_vole(), "personne", _joueur.global_position)
		_verif(await _attendre(func() -> bool: return _crime.prime() >= 5.0, 8.0), "invité : sa prime arrive par le miroir de l'hôte (%.0f)" % _crime.prime())
		_verif(_crime.voles.get("potion_soin", 0) == 1, "invité : l'objet volé est marqué dans SON sac")
	else:
		_verif(await _attendre(func() -> bool: return _prime_de(_autre) >= 5.0, 8.0), "hôte : le vol de l'invité est arbitré pour l'invité (%.0f)" % _prime_de(_autre))
		_verif(is_equal_approx(_crime.prime(), p_hote), "hôte : sa propre prime n'a pas bougé (%.0f)" % _crime.prime())
		_verif(not _hostile_de(_autre) and not _crime.est_hostile(), "hôte : personne n'est encore hostile")
	await _barriere("c2")
	# la garde devient hostile envers l'invité SEUL
	if _role == "hote":
		_crime.en_tant_que(_autre, func() -> void: _crime.guerre(_crime.joueur.global_position, []))
	await get_tree().create_timer(0.6).timeout
	if _role == "hote":
		_verif(_hostile_de(_autre) and not _crime.est_hostile(), "hôte : garde hostile envers l'invité, pas envers l'hôte")
	else:
		_verif(await _attendre(func() -> bool: return _crime.est_hostile(), 5.0), "invité : sait que la garde le recherche")
	await _barriere("c3")
	# l'invité paie l'amende : prime levée pour LUI seul ; l'or sort de SA bourse
	if _role != "hote":
		var avant: int = _joueur.inventaire.pieces
		var due := ceili(_crime.prime())
		_crime.coop.choisir("amende")
		_verif(_joueur.inventaire.pieces == avant - due, "invité : amende payée de sa bourse (-%d)" % due)
		_verif(await _attendre(func() -> bool: return _crime.prime() == 0.0 and not _crime.est_hostile(), 8.0), "invité : prime et hostilité levées")
	else:
		_verif(await _attendre(func() -> bool: return _prime_de(_autre) == 0.0 and not _hostile_de(_autre), 8.0), "hôte : prime de l'invité purgée")
		_verif(is_equal_approx(_crime.prime(), p_hote), "hôte : SA prime reste (%.0f) : elle se purge individuellement" % _crime.prime())
	await _barriere("c4")
	# plaidoyer d'un invité (jet gagnant)
	if _role != "hote":
		_crime.signaler_vol(_objet_vole(), "personne", _joueur.global_position)
		await _attendre(func() -> bool: return _crime.prime() >= 5.0, 8.0)
		_crime.coop.choisir("plaider", 0.0)
		_verif(await _attendre(func() -> bool: return _crime.prime() == 0.0, 8.0), "invité : plaidoyer réussi, prime levée")
	else:
		await _attendre(func() -> bool: return _prime_de(_autre) >= 5.0, 8.0)
		_verif(await _attendre(func() -> bool: return _prime_de(_autre) == 0.0, 8.0), "hôte : plaidoyer de l'invité arbitré")
	await _barriere("c5")
	# export par personnage : l'hôte garde la sienne, l'invité sauvegarde la sienne
	if _role != "hote":
		var perso: Dictionary = _crime.coop.exporter_perso()
		_verif(perso["primes"] is Dictionary and float(perso["primes"].get("skarnholt", 0.0)) == 0.0, "invité : exporter_perso() = son état (prime 0 après plaidoyer)")
	else:
		_verif(float(_crime.exporter()["primes"].get("skarnholt", 0.0)) == p_hote, "hôte : exporter() = SA prime seulement (%.0f)" % p_hote)

	# ===== 2. QUÊTES PARTAGÉES =====
	var qid := "frere_ylva"
	var etapes: Array = []
	for qq: Dictionary in _q.donnees["quetes"]:
		if qq["id"] == qid:
			for e: Dictionary in qq["etapes"]:
				etapes.append(String(e["declencheur"]).split("|")[0])
	_verif(etapes.size() == 3, "quête de test « %s » : 3 étapes" % qid)
	var prime_q := int(_q.recompense_de(qid).get("pieces", 0))
	var pieces0: int = _joueur.inventaire.pieces
	await _barriere("q0")
	if _role != "hote":
		_q.signaler(etapes[0])       # l'invité accepte la quête
	_verif(await _attendre(func() -> bool: return _q.index(qid) == 1, 8.0), "quête acceptée par l'invité : visible chez les deux (index 1)")
	await _barriere("q1")
	if _role == "hote":
		_q.signaler(etapes[1])       # l'hôte fait progresser
	_verif(await _attendre(func() -> bool: return _q.index(qid) == 2, 8.0), "progression de l'hôte partagée (index 2)")
	_verif(_q.entrees(qid).size() == 2, "journal : 2 entrées chez les deux")
	await _barriere("q2")
	if _role != "hote":
		_q.signaler(etapes[2])       # l'invité termine
	_verif(await _attendre(func() -> bool: return _q.fini(qid), 8.0), "quête terminée visible chez les deux")
	await get_tree().create_timer(0.6).timeout
	_verif(_joueur.inventaire.pieces == pieces0 + prime_q, "récompense (%d pièces) reçue par CHACUN, une seule fois (%d -> %d)" % [prime_q, pieces0, _joueur.inventaire.pieces])
	await _barriere("q3")

	# ===== 3. COMMERCE : objet unique, un seul acheteur =====
	var mid := "forgeron"
	Marchand.etats[mid] = {"periode": Marchand.periode_de(mid), "or": 600, "stock": {"arc_chasseur": 1, "minerai_fer": 0}}
	(Marchand.etats[mid]["stock"] as Dictionary).erase("minerai_fer")
	var arcs0: int = _joueur.inventaire.nombre("arc_chasseur")
	var raison := ["?"]
	await _barriere("m0")
	Marchand.acheter_coop(mid, _joueur.inventaire, "arc_chasseur", 1, func(r: String) -> void: raison[0] = r)
	_verif(await _attendre(func() -> bool: return raison[0] != "?", 8.0), "achat : réponse reçue (« %s »)" % raison[0])
	var a_lui: int = _joueur.inventaire.nombre("arc_chasseur") - arcs0
	_res.envoyer_evenement("bilan", 0, a_lui)
	await _attendre(func() -> bool: return _bilan_autre >= 0, 8.0)
	_verif(a_lui + _bilan_autre == 1, "objet unique : un seul des deux l'obtient (moi %d, l'autre %d)" % [a_lui, _bilan_autre])
	_verif(a_lui == 1 or raison[0] == "Plus en stock.", "le perdant reçoit « Plus en stock. » (%s)" % raison[0])
	await get_tree().create_timer(0.4).timeout
	_verif(not (Marchand.etat(mid)["stock"] as Dictionary).has("arc_chasseur"), "stock vide chez les deux")
	await _barriere("m1")
	# vente de l'invité : bourse et stock du marchand à l'hôte
	var or0 := int(Marchand.etat(mid)["or"])
	if _role != "hote":
		_joueur.inventaire.ajouter("minerai_fer", 3)
		var pc0: int = _joueur.inventaire.pieces
		var r2 := ["?"]
		Marchand.vendre_coop(mid, _joueur.inventaire, "minerai_fer", 2, null, func(r: String) -> void: r2[0] = r)
		_verif(await _attendre(func() -> bool: return r2[0] != "?", 8.0) and r2[0] == "", "invité : vente acceptée (« %s »)" % r2[0])
		_verif(_joueur.inventaire.nombre("minerai_fer") == 1 and _joueur.inventaire.pieces > pc0, "invité : 2 minerais vendus, pièces reçues (+%d)" % (_joueur.inventaire.pieces - pc0))
	await _barriere("m2")
	await get_tree().create_timer(0.4).timeout
	_verif(int((Marchand.etat(mid)["stock"] as Dictionary).get("minerai_fer", 0)) == 2 and int(Marchand.etat(mid)["or"]) < or0, "stock et bourse du marchand à jour chez les deux (minerai x2, or %d)" % int(Marchand.etat(mid)["or"]))

	# ===== 4. CONVERSATIONS : un PNJ, un joueur =====
	if _role != "hote":
		_verif(ConversationsCoop.prendre(pc1), "invité : prend causeur_1")
	_verif(await _attendre(func() -> bool: return ConversationsCoop.detenteur(pc1) != 0, 5.0), "verrou connu des deux")
	if _role == "hote":
		_verif(pc1._en_conversation and pc1._conv_distante, "hôte : le PNJ est figé pendant que l'invité lui parle")
		_verif(not ConversationsCoop.prendre(pc1), "hôte : PNJ occupé par l'invité -> refus")
	await _barriere("v1")
	if _role != "hote":
		ConversationsCoop.liberer(pc1)
	_verif(await _attendre(func() -> bool: return ConversationsCoop.detenteur(pc1) == 0, 5.0), "verrou libéré chez les deux")
	if _role == "hote":
		_verif(not pc1._en_conversation and not pc1._conv_distante, "hôte : le PNJ reprend sa vie")
		_verif(ConversationsCoop.prendre(pc1), "hôte : le PNJ est libre, il peut lui parler")
		ConversationsCoop.liberer(pc1)
	await _barriere("v2")
	# course : les deux veulent causeur_2 en même temps -> exactement un gagnant
	_refus_recu = false
	var moi_ok := ConversationsCoop.prendre(pc2, func() -> void: _refus_recu = true)
	await get_tree().create_timer(1.2).timeout
	var gagne := 1 if (moi_ok and not _refus_recu) else 0
	_res.envoyer_evenement("bilan2", 0, gagne)
	await _attendre(func() -> bool: return _bilan2 >= 0, 8.0)
	_verif(gagne + _bilan2 == 1, "course : exactement un joueur obtient le PNJ (moi %d, l'autre %d)" % [gagne, _bilan2])
	await _barriere("fin")
	print("TEST_ECONOMIE_QUETES %s %s" % [_role, "OK" if _ok else "ECHEC"])
	get_tree().quit(0 if _ok else 1)
