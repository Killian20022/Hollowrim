extends SceneTree
## LOT 5b : deux Godot headless (hôte + invité), deux PHASES (la phase 2 est un « relancement » : nouveaux processus), pilotés par
## outils/test_sauvegarde_multi.sh :
##   godot --headless --path . --script res://outils/test_sauvegarde_multi_reseau.gd -- --role=hote|invite --phase=1|2 --port=N
## HÔTE : un faux monde léger (heure, jour, quêtes, morts) + le vrai ApportPersonnage ; il écrit le fichier de partie (format v2 réel).
## INVITÉ : le VRAI monde (foret_test.tscn) en mode invité : charger() ne lit pas de fichier, ApportPersonnage envoie SON personnage.
## Phase 1 : version refusée, connexion, personnage neuf, modifications, sauvegarde invité, hôte sauvegarde le monde.
## Phase 2 : l'hôte relance et retrouve son monde ; l'invité se reconnecte et retrouve SON personnage ; triche refusée/plafonnée ;
##           l'hôte part -> l'invité sauvegarde son personnage chez lui.
## Imprime « TEST ok / ECHEC … » puis « TEST_SAUVEGARDE_MULTI <role> OK|ECHEC ».

const SCENE := preload("res://scenes/foret_test.tscn")
const RES := preload("res://scripts/reseau/reseau.gd")
const ATTENDU := "user://test5b_attendu.json"

class FauxMonde extends Node3D:
	var joueur := Node3D.new()
	var hud = null
	var village = null
	var heure := 12.0
	var jour := 1
	var quetes := {}
	var morts: Array = []
	var inv := Inventaire.new()
	func _init() -> void:
		joueur.name = "Joueur"
		add_child(joueur)
		inv.pieces = 500
	func exporter_monde() -> Dictionary:
		return {"version": 2, "heure": heure, "jour": jour, "quetes": quetes.duplicate(true), "draugrs_morts": morts.duplicate()}
	func exporter_personnage() -> Dictionary:
		return {"inventaire": inv.exporter(), "joueur": {"position": [joueur.position.x, joueur.position.y, joueur.position.z], "vie": 100.0, "vigueur": 100.0}}
	func importer_personnage(_p: Dictionary, _position := true) -> void:
		pass

var _role := "hote"
var _phase := 1
var _port := 25032
var _ok := true
var _R: Node
var _msgs := {}

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			_role = a.substr(7)
		elif a.begins_with("--phase="):
			_phase = int(a.substr(8))
		elif a.begins_with("--port="):
			_port = int(a.substr(7))
	_lancer.call_deferred()

func _v(cond: bool, msg: String) -> void:
	print(("TEST ok     " if cond else "TEST ECHEC  ") + "[%s p%d] " % [_role, _phase] + msg)
	if not cond:
		_ok = false

func _attendre(cond: Callable, delai := 60.0) -> bool:
	var t := 0.0
	while not cond.call() and t < delai:
		await create_timer(0.1).timeout
		t += 0.1
	return cond.call()

func _fin() -> void:
	print("TEST_SAUVEGARDE_MULTI %s %s" % [_role, "OK" if _ok else "ECHEC"])
	quit(0 if _ok else 1)

func _ecouter(type: String) -> void:
	_R.abonner(type, func(_e: int, id: Variant, d: Variant) -> void: _msgs[type] = {"id": id, "d": d})

func _lancer() -> void:
	_R = root.get_node("Reseau")
	for t in ["t_attendu", "t_pret_quitter", "t_fin"]:
		_ecouter(t)
	if _role == "hote":
		await _hote()
	else:
		await _invite()
	_fin()

# ---------- hôte ----------

func _hote() -> void:
	var fichier := Sauvegardes.fichier(2)
	var faux := FauxMonde.new()
	faux.joueur.position = Vector3(5, 0, 5)
	root.add_child(faux)
	_R.nom_joueur = "Hôte"
	var connexions: Array = []
	_R.joueur_connecte.connect(func(id: int) -> void: connexions.append(id))
	if _phase == 1:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fichier))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ATTENDU))
		faux.heure = 17.25
		faux.jour = 4
		faux.quetes = {"etat": {"bienvenue": 2}, "vus": {"prologue_vu": true}}
		faux.morts = ["sbire_9"]
	else:   # RELANCE : l'hôte retrouve son monde depuis le fichier de la phase 1
		_v(FileAccess.file_exists(fichier), "le fichier de partie de l'hôte existe après la relance")
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fichier))
		var sep: Dictionary = SauvegardeMulti.depuis_sauvegarde(d)
		var m: Dictionary = sep["monde"]
		_v(absf(float(m["heure"]) - 17.25) < 0.01 and int(m["jour"]) == 4 and (m["quetes"]["etat"] as Dictionary).get("bienvenue") == 2 and m["draugrs_morts"] == ["sbire_9"],
			"monde relu : heure 17h15, jour 4, quête « bienvenue » avancée, gardien mort")
		_v(int(sep["personnage"]["inventaire"]["pieces"]) == 500, "personnage de l'hôte relu depuis le même fichier (500 pièces)")
		faux.heure = float(m["heure"])
		faux.jour = int(m["jour"])
	ApportPersonnage.installer(faux)
	var err: int = _R.heberger(_port)
	_v(err == OK, "hôte : port %d ouvert" % _port)
	print("HOTE_PRET")
	_v(await _attendre(func() -> bool: return _R.joueurs().size() >= 2, 150.0), "l'invité est accepté par la poignée de main")
	var gid := 0
	for i: int in _R.joueurs():
		if i != 1:
			gid = i
	_v(connexions.size() == 1, "l'hôte n'a vu qu'UNE arrivée (la tentative d'une autre version n'est jamais entrée : %s)" % str(connexions))
	_v(String(_R.registre.infos(gid).get("nom", "")) == "Astrid", "nom de l'invité dans le registre : %s" % _R.registre.infos(gid).get("nom", ""))
	_v(await _attendre(func() -> bool: return bool(_R.registre.infos(gid).get("personnage_valide", false)), 200.0), "personnage de l'invité validé par l'hôte")
	var niveau := int(_R.registre.infos(gid).get("niveau", -1))
	if _phase == 1:
		_v(niveau == 1, "phase 1 : personnage neuf (niveau %d)" % niveau)
		_v(await _attendre(func() -> bool: return _msgs.has("t_attendu"), 120.0), "l'invité annonce son personnage modifié")
		faux.inv.pieces = 500
		var d := SauvegardeMulti.fusionner(faux.exporter_monde(), faux.exporter_personnage())
		_v(Sauvegardes.ecrire(fichier, JSON.stringify(d, "\t")) == OK, "l'hôte sauvegarde le monde (fichier v2 combiné)")
		var back: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fichier))
		var sep: Dictionary = SauvegardeMulti.separer(back)
		_v(not (sep["monde"] as Dictionary).has("inventaire") and (sep["personnage"] as Dictionary).has("inventaire"), "le fichier se découpe : monde sans sac, personnage avec sac")
	else:
		var att: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ATTENDU))
		_v(niveau == int(att["niveau"]) and niveau > 1, "phase 2 : l'hôte voit le personnage RESTAURÉ de l'invité (niveau %d, attendu %d)" % [niveau, int(att["niveau"])])
		_v(await _attendre(func() -> bool: return _msgs.has("t_pret_quitter"), 200.0), "l'invité est prêt pour la fin")
		_R.deconnecter()   # l'hôte part : l'invité doit sauvegarder son personnage chez lui
		await create_timer(2.0).timeout
	await _attendre(func() -> bool: return _msgs.has("t_fin"), 120.0 if _phase == 1 else 5.0)
	_R.deconnecter()

# ---------- invité (vrai monde) ----------

func _invite() -> void:
	_R.nom_joueur = "Astrid"
	var chemin_hote_attendu := ATTENDU
	var avant := Sauvegardes.fichier(1)
	if _phase == 1:
		SauvegardeMulti.effacer_personnage("Astrid")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(avant))
	var echec := []
	_R.connexion_echouee.connect(func() -> void: echec.append(true))
	var ok_conn := []
	_R.connexion_reussie.connect(func() -> void: ok_conn.append(true))
	# attend l'hôte
	await create_timer(1.5).timeout
	if _phase == 1:
		_R.version_locale = RES.VERSION_PROTOCOLE + 41
		_v(_R.rejoindre("127.0.0.1", _port) == OK, "invité : tentative avec un protocole d'une autre version")
		_v(await _attendre(func() -> bool: return echec.size() > 0, 30.0), "version différente : connexion refusée")
		_v(String(_R.derniere_erreur).contains("Version") and not _R.est_en_ligne(), "message lisible : « %s »" % _R.derniere_erreur)
		_R.version_locale = RES.VERSION_PROTOCOLE
		echec.clear()
		await create_timer(0.5).timeout
	_v(_R.rejoindre("127.0.0.1", _port) == OK, "invité : connexion à l'hôte")
	_v(await _attendre(func() -> bool: return ok_conn.size() > 0 or echec.size() > 0, 30.0) and echec.is_empty(), "connexion réussie (poignée de main acceptée)")
	_v(_R.est_en_ligne() and not _R.est_hote() and _R.joueurs().size() == 2, "registre : 2 joueurs")
	_v(String(_R.registre.infos(1).get("nom", "")) != "", "l'invité connaît le nom de l'hôte")
	# VRAI monde en mode invité : pas de fichier de partie lu ; l'apport du personnage part au monde prêt
	Jeu.chargement_etale = true   # comme l'écran de chargement du vrai jeu : le monde se bâtit image par image, arbre EN PAUSE (le réseau reste lu)
	paused = true
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	var pret := await _attendre(func() -> bool: return m.pret, 200.0)
	paused = false
	Jeu.chargement_etale = false
	_v(pret, "le monde de l'invité est prêt")
	_v(m._invite_coop(), "monde : reconnu comme invité de la partie coop")
	var app: ApportPersonnage = m.get_node("ApportPersonnage")
	_v(await _attendre(func() -> bool: return app.etat == "ok" or app.etat == "refuse" or app.etat == "sans_reponse", 40.0) and app.etat == "ok", "apport : l'hôte a répondu (état %s)" % app.etat)
	var j = m.joueur
	var pos_h := Vector2(5, 5)
	_v(Vector2(j.global_position.x, j.global_position.z).distance_to(pos_h) < 4.5, "apparition près de l'hôte (%.1f m de lui)" % Vector2(j.global_position.x, j.global_position.z).distance_to(pos_h))
	if _phase == 1:
		_v(j.inventaire.pieces != 123, "personnage neuf au départ")
		j.inventaire.pieces = 123
		j.inventaire.ajouter("os_draugr", 4)
		j.progression.gagner_xp(900.0, false)
		var niv: int = j.progression.niveau
		_v(niv > 1, "l'invité monte de niveau (niveau %d)" % niv)
		_v(m.sauvegarder(), "invité : sauvegarde (écrit SON personnage)")
		_v(SauvegardeMulti.personnage_existe("Astrid") and not FileAccess.file_exists(avant), "fichier personnage créé ; aucun fichier de PARTIE écrit chez l'invité")
		var f := FileAccess.open(chemin_hote_attendu, FileAccess.WRITE)
		f.store_string(JSON.stringify({"pieces": 123, "os": 4, "niveau": niv}))
		f.close()
		_R.envoyer_evenement("t_attendu", 0, {})
		await create_timer(1.0).timeout
	else:
		var att: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(chemin_hote_attendu))
		_v(j.inventaire.pieces == int(att["pieces"]) and int(j.inventaire.objets.get("os_draugr", 0)) == int(att["os"]) and j.progression.niveau == int(att["niveau"]),
			"SON personnage est restauré après la relance : %d pièces, %d os, niveau %d" % [j.inventaire.pieces, int(j.inventaire.objets.get("os_draugr", 0)), j.progression.niveau])
		await create_timer(2.5).timeout   # laisse l'hôte relever le niveau restauré avant la triche (qui réécrit l'info du registre)
		# triche : l'hôte plafonne
		var recu := {}
		_R.abonner("apport_resultat", func(_e: int, _i: Variant, d: Variant) -> void: recu["d"] = d)
		var triche := {"nom": "Astrid", "existe": true, "perso": {"inventaire": {"pieces": 9000000000, "objets": {"pain_seigle": 50000, "objet_inventé": 3}}, "progression": {"niveau": 900}}}
		_R.envoyer_evenement("apport_perso", _R.mon_id(), ApportPersonnage._emballer(triche))
		_v(await _attendre(func() -> bool: return recu.has("d"), 20.0), "l'hôte répond à un personnage truqué")
		var r: Dictionary = ApportPersonnage._deballer(recu["d"])
		var p: Dictionary = r.get("perso", {})
		_v(bool(r.get("ok", false)) and int(p["inventaire"]["pieces"]) == SauvegardeMulti.PIECES_MAX and int(p["inventaire"]["objets"]["pain_seigle"]) == SauvegardeMulti.QUANTITE_MAX
			and not p["inventaire"]["objets"].has("objet_inventé") and int(p["progression"]["niveau"]) == Progression.NIVEAU_MAX,
			"triche plafonnée par l'hôte (%d correction(s))" % (r.get("corrections", []) as Array).size())
		recu.clear()
		_R.envoyer_evenement("apport_perso", _R.mon_id(), ApportPersonnage._emballer({"nom": "Astrid", "perso": "n'importe quoi"}))
		await _attendre(func() -> bool: return recu.has("d"), 20.0)
		_v(recu.has("d") and not bool(ApportPersonnage._deballer(recu["d"]).get("ok", true)), "un personnage illisible est refusé (message : %s)" % ApportPersonnage._deballer(recu.get("d", {})).get("raison", ""))
		# l'hôte part : le personnage est sauvegardé chez l'invité
		j.inventaire.pieces = 124
		_R.envoyer_evenement("t_pret_quitter", 0, {})
		_v(await _attendre(func() -> bool: return not _R.est_en_ligne(), 30.0), "l'hôte est parti : l'invité repasse hors ligne (« %s »)" % _R.derniere_erreur)
		await create_timer(1.0).timeout
		var pf: Dictionary = SauvegardeMulti.lire_personnage("Astrid")
		_v(not pf.is_empty() and int(pf["inventaire"]["pieces"]) == 124, "départ de l'hôte : le personnage est sauvegardé chez l'invité (124 pièces)")
	_R.envoyer_evenement("t_fin", 0, {})
	await create_timer(0.5).timeout
	_R.deconnecter()
	if _phase == 2:
		SauvegardeMulti.effacer_personnage("Astrid")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Sauvegardes.fichier(2)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ATTENDU))
