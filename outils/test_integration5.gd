extends Node
## INTEGRATION 5 : poignée de main (5b) + sauvegardes monde/personnage (5b) + crime par joueur et quêtes partagées (5a) — UNE instance (hôte ou invité), lancée deux fois par
## outils/test_integration5.sh : godot --headless --path . res://outils/test_integration5.tscn -- --role=hote|invite --port=N
## Les deux instances déroulent le MÊME scénario en lockstep (barrières). Imprime « TEST ok / ECHEC … » puis « TEST_INTEGRATION5 <role> OK|ECHEC ».

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
	var pret := true
	## Mêmes frontières que le vrai monde (lot 5b) : monde = quêtes + heure ; personnage = sac + crime (prime). Le crime PASSE par exporter_personnage.
	func exporter_monde() -> Dictionary:
		return {"version": 2, "heure": cycle.heure, "jour": cycle.jour, "quetes": quetes.exporter()}
	func exporter_personnage() -> Dictionary:
		return {"inventaire": joueur.inventaire.exporter(), "crime": crime.exporter(),
			"joueur": {"position": [joueur.position.x, joueur.position.y, joueur.position.z], "vie": 100.0, "vigueur": 100.0}}
	func importer_monde(d: Dictionary) -> void:
		cycle.heure = float(d.get("heure", 12.0))
		cycle.jour = int(d.get("jour", 1))
		quetes.importer(d.get("quetes", {}))
	func importer_personnage(d: Dictionary, _position := true) -> void:
		joueur.inventaire.importer(d.get("inventaire", {}))
		crime.restaurer(d["crime"] if d.get("crime") is Dictionary else {})
	func sauvegarder_personnage() -> bool:
		return SauvegardeMulti.ecrire_personnage("Astrid", exporter_personnage()) == OK

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
const QID := "frere_ylva"
const FICHIER_HOTE := 3   # emplacement de sauvegarde de test de l'hôte

var _role := "hote"
var _port := 25101
var _ok := true
var _res: Node
var _monde: FauxMonde
var _joueur: CharacterBody3D
var _hud: FauxHud
var _crime: Crime
var _q: Node
var _vus := {}
var _autre := 1
var _etapes: Array = []

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
	if not await _attendre(func() -> bool: return _vus.has(nom), 60.0):
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

func _objet_vole() -> Node3D:
	var o := Node3D.new()
	o.set_meta("id_objet", "potion_soin")
	return o

func _construire() -> void:
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
	_pnj("temoin_a", Vector3(0, 0, 0))
	_pnj("temoin_b", Vector3(40, 0, 0))
	_crime = Crime.new()
	_crime.name = "Crime"
	_crime.monde = _monde
	_crime.joueur = _joueur
	_crime.hud = _hud
	_monde.add_child(_crime)
	_monde.crime = _crime

func _lancer() -> void:
	_res = get_node("/root/Reseau")
	_res.abonner("sync", func(_e: int, id: Variant, _d: Variant) -> void: _vus[String(id)] = true)
	_construire()
	await get_tree().create_timer(0.5).timeout
	_joueur.set("est_local", true)
	for qq: Dictionary in _q.donnees["quetes"]:
		if qq["id"] == QID:
			for e: Dictionary in qq["etapes"]:
				_etapes.append(String(e["declencheur"]).split("|")[0])
	_verif(_etapes.size() == 3, "quête de test « %s » : 3 étapes" % QID)
	var fichier := Sauvegardes.fichier(FICHIER_HOTE)
	var connexions: Array = []
	var reussies: Array = []
	var echecs: Array = []
	_res.joueur_connecte.connect(func(id: int) -> void: connexions.append(id))
	_res.connexion_reussie.connect(func() -> void: reussies.append(connexions.duplicate()))
	_res.connexion_echouee.connect(func() -> void: echecs.append(true))

	# ===== 0. PRÉPARATION : un monde sauvegardé (hôte) et un personnage sauvegardé (invité), chacun dans son fichier =====
	if _role == "hote":
		_res.nom_joueur = "Hôte"
		_q.signaler(_etapes[0])                  # la quête est acceptée AVANT la partie
		_monde.cycle.heure = 17.25
		_monde.cycle.jour = 4
		_joueur.inventaire.ajouter("pieces", 500)
		var d := SauvegardeMulti.fusionner(_monde.exporter_monde(), _monde.exporter_personnage())
		_verif(Sauvegardes.ecrire(fichier, JSON.stringify(d, "\t")) == OK, "hôte : monde sauvegardé (fichier v2)")
		# « relance » : l'état en mémoire est effacé puis relu depuis le fichier
		_q.importer({})
		_monde.cycle.heure = 8.0
		_monde.cycle.jour = 1
		var sep := SauvegardeMulti.depuis_sauvegarde(JSON.parse_string(FileAccess.get_file_as_string(fichier)))
		_monde.importer_monde(sep["monde"])
		_monde.importer_personnage(sep["personnage"])
		_verif(_q.index(QID) == 1 and absf(_monde.cycle.heure - 17.25) < 0.01 and _monde.cycle.jour == 4, "hôte : monde relu (quête à l'étape 1, 17h15, jour 4)")
		_verif(float(sep["monde"].get("quetes", {}).get("etat", {}).get(QID, 0)) == 1 and not (sep["monde"] as Dictionary).has("crime"), "le monde ne contient PAS le crime")
	else:
		_res.nom_joueur = "Astrid"
		SauvegardeMulti.effacer_personnage("Astrid")
		_joueur.inventaire.ajouter("pieces", 321)
		_crime.ajouter_prime(40.0)
		var perso := _monde.exporter_personnage()
		_verif(float((perso["crime"]["primes"] as Dictionary).get("skarnholt", 0.0)) == 40.0, "invité : la prime est dans le personnage exporté (exporter_personnage -> crime)")
		_verif(SauvegardeMulti.ecrire_personnage("Astrid", perso) == OK, "invité : personnage sauvegardé (321 pièces, prime 40)")
		# « relance » : un personnage neuf en mémoire
		_crime.restaurer({})
		_joueur.inventaire.importer({})
		_verif(_crime.prime() == 0.0 and _joueur.inventaire.pieces == 0, "invité : état en mémoire remis à zéro avant la connexion")
	if _role == "hote":
		ApportPersonnage.installer(_monde)   # l'hôte écoute avant d'ouvrir ; l'invité l'installe après la connexion (comme le monde, bâti après)

	# ===== 1. CONNEXION par la poignée de main =====
	if _role == "hote":
		_verif(_res.heberger(_port) == OK, "heberger() OK")
		print("HOTE_PRET")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1, 60.0)
		_verif(connexions.size() == 1 and echecs.is_empty(), "hôte : une seule arrivée (poignée acceptée)")
	else:
		_verif(_res.rejoindre("127.0.0.1", _port) == OK, "rejoindre() OK")
		await _attendre(func() -> bool: return reussies.size() > 0 or echecs.size() > 0, 40.0)
		_verif(reussies.size() == 1 and echecs.is_empty(), "invité : connexion_reussie après la poignée de main")
		_verif(reussies.size() == 1 and (reussies[0] as Array).has(1), "invité : l'hôte est déjà présenté (joueur_connecte(1)) quand connexion_reussie part")
		_verif(String(_res.registre.infos(1).get("nom", "")) == "Hôte", "invité : nom de l'hôte connu (« %s »)" % _res.registre.infos(1).get("nom", ""))
	_verif(_res.joueurs().size() == 2 and _res.mon_id() >= 1, "2 joueurs en ligne")
	if _role != "hote":
		ApportPersonnage.installer(_monde)
	_autre = 1 if _role != "hote" else int(_res.joueurs()[1])
	ProtoAvatar.creer(_monde, _autre, Vector3(0, 0.1, 4) if _role != "hote" else Vector3(40, 0.1, 4))
	await _barriere("connectes")

	# ===== 2. LE PERSONNAGE DE L'INVITÉ RENTRE PAR LA POIGNÉE + L'APPORT =====
	var app: ApportPersonnage = _monde.get_node("ApportPersonnage")
	if _role != "hote":
		_verif(await _attendre(func() -> bool: return app.etat == "ok" or app.etat == "refuse" or app.etat == "sans_reponse", 30.0) and app.etat == "ok", "invité : apport accepté par l'hôte (état %s)" % app.etat)
		_verif(_joueur.inventaire.pieces == 321, "invité : SON sac est restauré (%d pièces)" % _joueur.inventaire.pieces)
		_verif(is_equal_approx(_crime.prime(), 40.0), "invité : SA prime est restaurée (%.0f)" % _crime.prime())
	else:
		_verif(await _attendre(func() -> bool: return bool(_res.registre.infos(_autre).get("personnage_valide", false)), 30.0), "hôte : personnage de l'invité validé")
		# la prime de l'invité est connue de l'hôte (contexte de l'invité) : arrive par crime_perso APRÈS l'apport
		_verif(await _attendre(func() -> bool: return is_equal_approx(_prime_de(_autre), 40.0), 15.0), "hôte : arbitre l'invité avec SA prime sauvegardée (%.0f)" % _prime_de(_autre))
		_verif(_crime.prime() == 0.0, "hôte : sa propre prime n'est pas celle de l'invité (%.0f)" % _crime.prime())
	await _barriere("apport")

	# ===== 3. QUÊTE SAUVEGARDÉE CHEZ L'HÔTE, PARTAGÉE AVEC L'INVITÉ =====
	_verif(await _attendre(func() -> bool: return _q.index(QID) == 1, 10.0), "la quête acceptée avant la partie est visible chez les deux (index 1)")
	await _barriere("q0")
	if _role != "hote":
		_q.signaler(_etapes[1])       # l'invité fait progresser
	_verif(await _attendre(func() -> bool: return _q.index(QID) == 2, 10.0), "progression de l'invité partagée (index 2)")
	await _barriere("q1")

	# ===== 4. CRIME PAR JOUEUR =====
	var p_hote0 := _crime.prime() if _role == "hote" else 0.0
	if _role != "hote":
		var avant := _crime.prime()
		_crime.signaler_vol(_objet_vole(), "personne", _joueur.global_position)
		_verif(await _attendre(func() -> bool: return _crime.prime() > avant + 4.0, 10.0), "invité : son vol s'ajoute à SA prime (%.0f -> %.0f)" % [avant, _crime.prime()])
	else:
		_verif(await _attendre(func() -> bool: return _prime_de(_autre) > 44.0, 10.0), "hôte : vol de l'invité arbitré dans le contexte de l'invité (%.0f)" % _prime_de(_autre))
		_verif(is_equal_approx(_crime.prime(), p_hote0), "hôte : sa prime n'a pas bougé (%.0f)" % _crime.prime())
	await _barriere("c1")
	var prime_finale := _crime.prime() if _role != "hote" else _prime_de(_autre)

	# ===== 5. SAUVEGARDES À LA FIN =====
	if _role == "hote":
		var d2 := SauvegardeMulti.fusionner(_monde.exporter_monde(), _monde.exporter_personnage())
		_verif(Sauvegardes.ecrire(fichier, JSON.stringify(d2, "\t")) == OK, "hôte : monde sauvegardé en partie (quête index 2)")
		var sep2 := SauvegardeMulti.depuis_sauvegarde(JSON.parse_string(FileAccess.get_file_as_string(fichier)))
		_verif(int(sep2["monde"]["quetes"]["etat"].get(QID, 0)) == 2, "fichier hôte : la progression de l'invité est dans le MONDE")
		_verif(float(sep2["personnage"]["crime"]["primes"].get("skarnholt", 0.0)) == 0.0, "fichier hôte : la prime de l'hôte seulement (0), pas celle de l'invité")
		_res.envoyer_evenement("prime", 0, prime_finale)
		await _barriere("fin_hote")
		await get_tree().create_timer(1.5).timeout   # laisse l'invité recevoir la barrière avant de couper
		_res.deconnecter()          # l'hôte part : l'invité sauvegarde SON personnage
		await get_tree().create_timer(2.0).timeout
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fichier))
	else:
		_joueur.inventaire.ajouter("pieces", 10)
		await _barriere("fin_hote")
		_verif(await _attendre(func() -> bool: return not _res.est_en_ligne(), 30.0), "invité : l'hôte est parti, hors ligne")
		await get_tree().create_timer(1.0).timeout
		var pf := SauvegardeMulti.lire_personnage("Astrid")
		_verif(not pf.is_empty() and int(pf["inventaire"]["pieces"]) == 331, "invité : SON personnage est sauvegardé à la déconnexion (331 pièces)")
		_verif(float(pf["crime"]["primes"].get("skarnholt", 0.0)) > 44.0 and is_equal_approx(float(pf["crime"]["primes"].get("skarnholt", 0.0)), prime_finale), "invité : sa prime (%.0f) est dans son fichier personnage" % float(pf["crime"]["primes"].get("skarnholt", 0.0)))
		_verif(not pf.has("quetes"), "invité : les quêtes (monde) ne sont pas dans son fichier")
		SauvegardeMulti.effacer_personnage("Astrid")
	print("TEST_INTEGRATION5 %s %s" % [_role, "OK" if _ok else "ECHEC"])
	get_tree().quit(0 if _ok else 1)
