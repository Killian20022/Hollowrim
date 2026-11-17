extends Node
## INTEGRATION 6 : sous 100 ms / 5 % de perte (--sim-*), l'invité frappe un ennemi et prend un coffre, puis l'hôte part (tué net) :
## le personnage de l'invité est sauvegardé à l'annonce « hôte perdu » (AVANT le retour en solo) et le message s'affiche à l'écran titre.
##   godot --headless --path . res://outils/test_integration6.tscn -- --role=hote|invite --port=N --sim-latence=100 --sim-gigue=20 --sim-perte=5
## Imprime « TEST_INTEGRATION6 <role> OK|ECHEC ».

class FauxMonde extends Node3D:
	var joueur: CharacterBody3D
	var village: Node3D
	var cycle: Node
	var hud: Node
	var dialogue: Control
	var vie: Node
	var faune: Node
	var marchand: Node
	var pret := true
	func exporter_personnage() -> Dictionary:
		return {"inventaire": joueur.inventaire.exporter(), "joueur": {"position": [joueur.position.x, joueur.position.y, joueur.position.z], "vie": 100.0, "vigueur": 100.0}}
	func importer_personnage(d: Dictionary, _position := true) -> void:
		joueur.inventaire.importer(d.get("inventaire", {}))
	func sauvegarder_personnage() -> bool:
		return SauvegardeMulti.ecrire_personnage("Astrid", exporter_personnage()) == OK

const JOUEUR := preload("res://scripts/joueur.gd")
const DRAUGR := preload("res://scripts/draugr.gd")
const CYCLE := preload("res://scripts/cycle.gd")

var _role := "hote"
var _port := 25301
var _ok := true
var _res: Node
var _rs: Resilience
var _j: CharacterBody3D
var _monde: FauxMonde
var _vus := {}
var _gagne := false
var _perdu := false

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
	var t := 0.0
	while not _vus.has(nom) and t < 60.0:   # renvoi toutes les 0,5 s (le pair peut ne pas encore écouter)
		_res.envoyer_evenement("sync", nom, null)
		var u := 0.0
		while not _vus.has(nom) and u < 0.5:
			await get_tree().create_timer(0.05).timeout
			u += 0.05
		t += u
	if not _vus.has(nom):
		_verif(false, "barrière « %s » jamais atteinte" % nom)
		get_tree().quit(1)
	_res.envoyer_evenement("sync", nom, null)   # dernier envoi : le pair peut ne pas avoir vu le nôtre (on a pu le voir avant d'avoir émis)

func _info_coup(pt: Vector3) -> Dictionary:
	return {"attaque": "legere", "type": "tranchant", "point": pt + Vector3(0, 1.1, 0), "direction": Vector3(1, -0.4, 0).normalized(), "normale": Vector3(0, 0, 1), "zone": "torse"}

func _journal(type: String, ident: String) -> int:
	var n := 0
	for e: Dictionary in CombatCoop.journal:
		if String(e.get("type", "")) == type and e.get("id") == "e:" + ident:
			n += 1
	return n

func _construire() -> void:
	_monde = FauxMonde.new()
	_monde.name = "Monde"
	get_tree().root.add_child(_monde)
	var sol := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	col.shape = box
	sol.add_child(col)
	sol.position = Vector3(0, -0.5, 0)
	_monde.add_child(sol)
	_j = CharacterBody3D.new()
	_j.set_script(JOUEUR)
	_j.name = "Joueur"
	_j.position = Vector3(0, 0.1, 20) if _role == "hote" else Vector3(2, 0.1, 0)
	_monde.add_child(_j)
	_monde.joueur = _j
	var cyc := Node.new()
	cyc.set_script(CYCLE)
	cyc.env = Environment.new()
	cyc.lumiere = DirectionalLight3D.new()
	cyc.ciel = ShaderMaterial.new()
	_monde.add_child(cyc)
	_monde.cycle = cyc

func _lancer() -> void:
	_res = get_node("/root/Reseau")
	_res.abonner("sync", func(_e: int, id: Variant, _d: Variant) -> void: _vus[String(id)] = true)
	_construire()
	var ennemi := CharacterBody3D.new()
	ennemi.set_script(DRAUGR)
	ennemi.set("type", "sbire")
	ennemi.set("dort", true)
	ennemi.set("joueur", _j)
	ennemi.set("ident", "i6_sbire")
	ennemi.name = "i6_sbire"
	ennemi.set("vie_imposee", 4000.0)
	ennemi.position = Vector3(3, 0, -2)
	_monde.add_child(ennemi)
	ennemi.set_physics_process(false)
	await get_tree().create_timer(0.5).timeout
	_j.set("est_local", true)
	_j.vie = 1.0e6
	_j.vie_max = 1.0e6
	var sim := SimulateurReseau.parametres()
	_verif(float(sim["latence"]) >= 100.0 and float(sim["perte"]) >= 5.0, "conditions simulées actives (%.0f ms, %.0f %%)" % [float(sim["latence"]), float(sim["perte"])])
	if _role == "invite":
		_res.nom_joueur = "Astrid"
		SauvegardeMulti.effacer_personnage("Astrid")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Resilience.FICHIER_MESSAGE))
	else:
		_res.nom_joueur = "Hôte"

	# ===== connexion =====
	if _role == "hote":
		_verif(_res.heberger(_port) == OK, "heberger() OK")
		print("HOTE_PRET")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1, 90.0)
	else:
		_verif(_res.rejoindre("127.0.0.1", _port) == OK, "rejoindre() OK")
		await _attendre(func() -> bool: return _res.joueurs().size() > 1 and _res.mon_id() > 1, 90.0)
	_verif(_res.joueurs().size() == 2, "2 joueurs en ligne")
	AvatarsCoop.installer(_monde, _j, "J-" + _role)
	ReseauProjectiles.installer()
	var app := ApportPersonnage.installer(_monde)
	_rs = Resilience.instance()
	_verif(_rs != null, "nœud Resilience présent")
	_rs.retour_titre_auto = false
	_rs.pause_essais = 1.0
	_rs.delai_confirmation = 3.0
	_rs.silence_max = 5.0
	_rs.periode_ping = 0.25
	await _barriere("connectes")
	await get_tree().create_timer(3.0).timeout   # avatars installés des deux côtés (position de l'invité connue de l'hôte)
	if _role == "invite":
		await _attendre(func() -> bool: return app.etat != "attente" and app.etat != "", 30.0)
		_j.global_position = Vector3(2, 0.1, 0)   # l'apport place l'invité près de l'hôte : on le ramène près de l'ennemi
		await get_tree().create_timer(2.0).timeout   # position répliquée vers l'hôte (sous 100 ms / 5 %)

	# ===== coup + coffre sous latence/perte =====
	if _role == "invite":
		_j.inventaire.ajouter("pieces", 100)
		for i in 3:
			ennemi.recevoir_coup(40.0, _j.global_position, false, _info_coup(Vector3(3, 0, -2)))
			await get_tree().create_timer(0.4).timeout
		ReseauLieux.reclamer("i6:coffre", func() -> void: _gagne = true, func() -> void: _perdu = true)
		await _attendre(func() -> bool: return _gagne or _perdu, 30.0)
		_verif(_gagne, "invité : coffre pris")
		if _gagne:
			_j.inventaire.ajouter("os_draugr", 2)
	else:
		ReseauLieux.enregistrer_porte("i6:porte", func() -> void: pass)
		await _attendre(func() -> bool: return _journal("applique", "i6_sbire") + _journal("refus", "i6_sbire") >= 3, 40.0)
		_verif(_journal("applique", "i6_sbire") == 3, "hôte : 3 coups de l'invité appliqués (refus %d)" % _journal("refus", "i6_sbire"))
	await _barriere("fait")

	# ===== l'hôte part =====
	if _role == "hote":
		print("TEST_INTEGRATION6 hote %s" % ("OK" if _ok else "ECHEC"))
		await get_tree().create_timer(1.5).timeout
		print("HOTE_TUE_NET")
		OS.kill(OS.get_process_id())
		return
	var etat := {"recu": false, "fichier_deja": false, "en_ligne": false, "abandon": "", "titre": ""}
	_res.hote_perdu.connect(func(_r: String) -> void:   # connecté APRÈS ApportPersonnage : s'exécute après sa sauvegarde
		etat["recu"] = true
		etat["en_ligne"] = _res.est_en_ligne()
		etat["fichier_deja"] = SauvegardeMulti.personnage_existe("Astrid"))
	_rs.reconnexion_abandonnee.connect(func(t: String) -> void: etat["abandon"] = t)
	_rs.retour_titre_demande.connect(func(t: String) -> void: etat["titre"] = t)
	_verif(await _attendre(func() -> bool: return etat["recu"], 60.0), "invité : hote_perdu reçu")
	_verif(etat["en_ligne"], "invité : hote_perdu émis AVANT le retour en solo")
	_verif(etat["fichier_deja"], "invité : le fichier personnage existe dès l'annonce (sauvegarde AVANT le retour au titre)")
	_verif(app.hote_perdu_sauvegarde, "invité : ApportPersonnage a sauvegardé sur hote_perdu")
	var pf := SauvegardeMulti.lire_personnage("Astrid")
	_verif(not pf.is_empty() and int(pf["inventaire"]["pieces"]) == 100, "invité : personnage sauvegardé (100 pièces)")
	_verif(not pf.is_empty() and int(pf["inventaire"].get("objets", {}).get("os_draugr", pf["inventaire"].get("os_draugr", 0))) == 2 or str(pf).contains("os_draugr"), "invité : butin du coffre dans le fichier")
	_verif(await _attendre(func() -> bool: return String(etat["abandon"]) != "", 120.0), "invité : reconnexion abandonnée, retour au titre demandé")
	_verif(String(etat["titre"]) != "", "invité : message de retour (« %s »)" % String(etat["titre"]))
	# le retour réel passe par Jeu.relancer (fichier de message) : on pose le fichier comme le ferait _abandonner puis on ouvre l'écran titre
	var f := FileAccess.open(Resilience.FICHIER_MESSAGE, FileAccess.WRITE)
	f.store_string(String(etat["titre"]))
	f.close()
	var titre: Control = (load("res://scenes/ecran_titre.tscn") as PackedScene).instantiate()
	titre.set("mode_test", true)
	get_tree().root.add_child(titre)
	await get_tree().create_timer(1.0).timeout
	_verif(String(titre.get("message_reseau")) == String(etat["titre"]) and titre.has_node("MessageReseau"), "écran titre : le message réseau est affiché")
	_verif(Resilience.message_titre() == "", "écran titre : message consommé (effacé)")
	SauvegardeMulti.effacer_personnage("Astrid")
	print("TEST_INTEGRATION6 invite %s" % ("OK" if _ok else "ECHEC"))
	get_tree().quit(0 if _ok else 1)
