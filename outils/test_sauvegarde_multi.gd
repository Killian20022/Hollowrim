extends SceneTree
## LOT 5b : partie SOLO / un seul processus du test de sauvegarde multijoueur (le réseau à deux instances est dans
## outils/test_sauvegarde_multi_reseau.gd ; le tout est lancé par outils/test_sauvegarde_multi.sh).
##   godot --headless --path . --script res://outils/test_sauvegarde_multi.gd
## 1. fonctions pures : partage monde/personnage, validation (triche), noms de fichier, adresses, décision de poignée de main ;
## 2. NON-RÉGRESSION : une ancienne sauvegarde (v1, sans version) se charge dans le vrai monde, se resauvegarde en v2, se recharge ;
## 3. hôte coop sans invité = solo ; personnage invité écrit/relu/importé sans toucher au fichier de la partie.
## Imprime « RESULTAT : OK » / « RESULTAT : ECHEC » (code de sortie peu fiable : le verdict se lit dans le journal).

const SCENE := preload("res://scenes/foret_test.tscn")
var _echecs := 0
var _port := 25031

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			_port = int(a.substr(7))
	_lancer.call_deferred()

func _v(cond: bool, msg: String) -> void:
	print(("ok      " if cond else "ECHEC   ") + msg)
	if not cond:
		_echecs += 1

func _lancer() -> void:
	_purs()
	await _ancienne_sauvegarde()
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : OK" if _echecs == 0 else "RESULTAT : ECHEC")
	quit(0 if _echecs == 0 else 1)

func _json(d: Variant) -> String:
	return JSON.stringify(d, "", true)

# ---------- 1. fonctions pures ----------

func _purs() -> void:
	var d := {"version": 2, "heure": 5.5, "jour": 3, "quetes": {"etat": {"a": 1}}, "butin": {"graine": 7}, "inventaire": {"pieces": 4, "objets": {}},
		"progression": {"niveau": 2}, "crime": {"primes": {}}, "joueur": {"vie": 90}, "lieux_vus": ["x"], "vie": {}, "draugrs_morts": ["a"]}
	var sep: Dictionary = SauvegardeMulti.separer(d)
	var m: Dictionary = sep["monde"]
	var p: Dictionary = sep["personnage"]
	_v(m.has("heure") and m.has("quetes") and m.has("butin") and m.has("draugrs_morts") and m.has("vie") and m.has("version"), "monde : heure, quêtes, butin, morts, PNJ, version")
	_v(p.has("inventaire") and p.has("progression") and p.has("crime") and p.has("joueur") and p.has("lieux_vus"), "personnage : sac, progression, crime, joueur, lieux vus")
	var inter := false
	for k in m:
		inter = inter or p.has(k)
	_v(not inter and m.size() + p.size() == d.size(), "monde et personnage ne partagent aucune clé")
	_v(_json(SauvegardeMulti.fusionner(m, p)) == _json(d), "séparer puis fusionner redonne exactement la sauvegarde")
	p["inventaire"]["pieces"] = 99
	_v(int(d["inventaire"]["pieces"]) == 4, "séparer copie en profondeur (l'original n'est pas modifié)")
	var v1 := {"heure": 1.0, "competences": {"niveaux": {"epee": 30}, "experience": {}}, "inventaire": {"pieces": 5, "objets": {}}}
	var dep: Dictionary = SauvegardeMulti.depuis_sauvegarde(v1)
	_v((dep["personnage"] as Dictionary).has("progression") and int((dep["monde"] as Dictionary).get("version", 0)) == 2, "ancienne sauvegarde v1 migrée puis découpée")

	# validation : un tricheur
	var triche := {
		"inventaire": {"pieces": 9000000000, "objets": {"pain_seigle": 100000, "objet_qui_nexiste_pas": 5, "os_draugr": -4}},
		"progression": {"niveau": 500, "xp_niveau": 1.0e30, "points_perk": 99999, "points_attribut": -5,
			"attributs": {"vie": 100000}, "competences": {"niveaux": {"une_main": 999, "parade": -3}, "experience": {}}},
		"joueur": {"vie": 1.0e12, "vigueur": -50, "position": [1.0e9, 0, 0], "lacet": 1.0},
		"magie": {"mana": 1.0e9},
		"fantaisie": {"x": 1},
	}
	var r: Dictionary = SauvegardeMulti.valider(triche)
	var pv: Dictionary = r["personnage"]
	_v(bool(r["ok"]), "le tricheur est assaini, pas refusé")
	_v(int(pv["inventaire"]["pieces"]) == SauvegardeMulti.PIECES_MAX, "pièces plafonnées à %d" % SauvegardeMulti.PIECES_MAX)
	_v(int(pv["inventaire"]["objets"].get("pain_seigle", 0)) == SauvegardeMulti.QUANTITE_MAX and not pv["inventaire"]["objets"].has("objet_qui_nexiste_pas") and not pv["inventaire"]["objets"].has("os_draugr"), "quantité plafonnée, objet inconnu et quantité négative retirés")
	_v(int(pv["progression"]["niveau"]) == Progression.NIVEAU_MAX and int(pv["progression"]["points_perk"]) == SauvegardeMulti.POINTS_MAX and int(pv["progression"]["points_attribut"]) == 0, "niveau et points de progression plafonnés")
	_v(int(pv["progression"]["attributs"]["vie"]) == SauvegardeMulti.ATTRIBUT_MAX and int(pv["progression"]["competences"]["niveaux"]["une_main"]) == Competences.MAXIMUM and int(pv["progression"]["competences"]["niveaux"]["parade"]) == Competences.DEPART, "attributs et compétences dans leurs bornes")
	_v(float(pv["joueur"]["vie"]) == SauvegardeMulti.STAT_MAX and float(pv["joueur"]["vigueur"]) == 0.0 and not pv["joueur"].has("position"), "PV/endurance bornés, position folle retirée")
	_v(float(pv["magie"]["mana"]) == SauvegardeMulti.STAT_MAX and not pv.has("fantaisie"), "mana borné, clé inconnue écartée")
	_v((r["corrections"] as Array).size() >= 6, "corrections signalées à l'invité (%d)" % (r["corrections"] as Array).size())
	_v(not SauvegardeMulti.valider("pas un dictionnaire")["ok"] and not SauvegardeMulti.valider(null)["ok"], "un personnage qui n'est pas un dictionnaire est refusé")
	var objet := Node.new()
	var r2: Dictionary = SauvegardeMulti.valider({"inventaire": {"pieces": 3, "objets": {}, "piege": objet}, "lieux_vus": [objet, "ok"]})
	_v(not (r2["personnage"]["inventaire"] as Dictionary).has("piege") or r2["personnage"]["inventaire"]["piege"] == null, "un objet Godot glissé dans les données n'est pas conservé")
	objet.free()
	var gros := {"stockage": {"coffres": {}}, "lieux_vus": []}
	for i in 60000:
		gros["lieux_vus"].append("lieu_%d_%s" % [i, "x".repeat(40)])
	_v(not SauvegardeMulti.valider(gros)["ok"], "personnage trop volumineux refusé")

	# noms de fichier
	_v(SauvegardeMulti.nom_fichier("Éloïse Le Roux!") == "eloise_le_roux", "nom de fichier sans accent ni ponctuation : %s" % SauvegardeMulti.nom_fichier("Éloïse Le Roux!"))
	var piege := SauvegardeMulti.nom_fichier("../../etc/passwd")
	_v(not piege.contains("/") and not piege.contains("\\") and not piege.contains(".."), "nom de fichier : pas de remontée de dossier (%s)" % piege)
	_v(SauvegardeMulti.nom_fichier("   ") == "joueur" and SauvegardeMulti.nom_fichier("x".repeat(80)).length() == 24, "nom vide -> « joueur », long -> 24 caractères")

	# fichiers personnage
	var nom := "Testeur 5b"
	SauvegardeMulti.effacer_personnage(nom)
	_v(not SauvegardeMulti.personnage_existe(nom), "aucun fichier au départ")
	var perso := {"inventaire": {"pieces": 12, "objets": {"pain_seigle": 2}}, "progression": {"niveau": 4}, "monde_clandestin": 1}
	_v(SauvegardeMulti.ecrire_personnage(nom, perso) == OK, "écriture du fichier personnage")
	var relu: Dictionary = SauvegardeMulti.lire_personnage(nom)
	_v(int(relu["inventaire"]["pieces"]) == 12 and int(relu["progression"]["niveau"]) == 4 and not relu.has("monde_clandestin"), "relu : personnage seulement (les clés du monde sont écartées)")
	var f := FileAccess.open(SauvegardeMulti.chemin_personnage(nom), FileAccess.WRITE)
	f.store_string("{ abîmé")
	f.close()
	_v(SauvegardeMulti.lire_personnage(nom).is_empty(), "fichier illisible : personnage vide, pas de plantage")
	SauvegardeMulti.effacer_personnage(nom)

	# adresses (écran Multijoueur)
	var A = load("res://scripts/reseau/ecran_multi.gd")
	var cas := {"192.168.1.20": true, "192.168.1.20:24565": true, "127.0.0.1:25031": true, "localhost": true, "mon-pc.local:25000": true, "  10.0.0.1  ": true,
		"": false, "   ": false, "999.1.1.1": false, "1.2.3": false, "1.2.3.4.5": false, "192.168.1.20:80": false, "192.168.1.20:abc": false, "192.168.1.20:99999": false,
		"a b": false, ":24565": false, "bonjour!": false, "::1": false, "1.2.3.4:5:6": false, "-nom.local": false}
	for t: String in cas:
		var res: Dictionary = A.analyser_adresse(t)
		_v(bool(res["ok"]) == cas[t] and (cas[t] or String(res["erreur"]) != ""), "adresse « %s » -> %s%s" % [t, "valide" if res["ok"] else "refusée", "" if res["ok"] else " (" + String(res["erreur"]) + ")"])
	_v(int(A.analyser_adresse("1.2.3.4")["port"]) == 24565 and int(A.analyser_adresse("1.2.3.4:25000")["port"]) == 25000, "port par défaut 24565, port explicite lu")
	_v(not A.analyser_nom("")["ok"] and not A.analyser_nom("x".repeat(21))["ok"] and A.analyser_nom("  Astrid ")["nom"] == "Astrid", "noms de joueur")

	# décision de la poignée de main (hôte)
	var RS = load("res://scripts/reseau/reseau.gd")
	var R: Node = RS.new()
	var ok1: Dictionary = R.decision_poignee(RS.VERSION_PROTOCOLE, "Astrid")
	_v(bool(ok1["ok"]) and ok1["nom"] == "Astrid", "poignée de main : version identique acceptée")
	var mauvais: Dictionary = R.decision_poignee(RS.VERSION_PROTOCOLE + 1, "Astrid")
	_v(not mauvais["ok"] and String(mauvais["raison"]).contains("Version"), "version différente refusée : « %s »" % mauvais["raison"])
	R.registre.ajouter(1, {"nom": "Astrid"})
	_v(R.decision_poignee(RS.VERSION_PROTOCOLE, "Astrid")["nom"] == "Astrid (2)", "même nom : « Astrid (2) »")
	R.registre.ajouter(2, {"nom": "B"})
	R.registre.ajouter(3, {"nom": "C"})
	_v(bool(R.decision_poignee(RS.VERSION_PROTOCOLE, "D")["ok"]), "3 joueurs : un 4e est accepté")
	R.registre.ajouter(4, {"nom": "D"})
	var plein: Dictionary = R.decision_poignee(RS.VERSION_PROTOCOLE, "E")
	_v(not plein["ok"] and String(plein["raison"]).contains("pleine"), "4 joueurs : le 5e est refusé (« %s »)" % plein["raison"])
	R.free()

# ---------- 2. ancienne sauvegarde dans le vrai monde ----------

func _attendre_pret(m: Node, secondes := 150.0) -> bool:
	var t := 0.0
	while not m.pret and t < secondes:
		await process_frame
		t += 1.0 / 60.0
	return m.pret

func _ancienne_sauvegarde() -> void:
	var fichier: String = load("res://scripts/monde.gd").fichier_sauvegarde()
	if fichier == "user://sauvegarde.json" or not fichier.contains("test"):
		_v(false, "le jeu viserait la vraie sauvegarde (%s) : test annulé" % fichier)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fichier))
	# une vraie sauvegarde d'AVANT les compétences/équipement (v1) : pas de « version », compétences à l'ancienne
	var ancienne := {
		"joueur": {"position": [10.0, 30.0, 10.0], "lacet": 0.5, "vie": 55.0, "vigueur": 40.0},
		"heure": 5.5, "jour": 3,
		"competences": {"niveaux": {"epee": 30, "parade": 20, "athletisme": 18}, "experience": {"epee": 12.0}},
		"inventaire": {"pieces": 77, "objets": {"os_draugr": 3, "potion_soin": 2}},
		"quetes": {"etat": {}, "vus": {}},
		"draugrs_morts": ["sbire_4"], "villageois_parles": [],
	}
	var fa := FileAccess.open(fichier, FileAccess.WRITE)
	fa.store_string(JSON.stringify(ancienne, "\t"))
	fa.close()
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	_v(await _attendre_pret(m), "le monde se charge")
	var j = m.joueur
	var prog: Dictionary = j.progression.exporter()
	_v(j.inventaire.pieces == 77 and int(j.inventaire.objets.get("os_draugr", 0)) == 3 and int(j.inventaire.objets.get("potion_soin", 0)) == 2, "ancienne sauvegarde : sac relu (77 pièces, 3 os, 2 potions)")
	_v(absf(m.cycle.heure - 5.5) < 0.05 and m.cycle.jour == 3, "ancienne sauvegarde : heure 5h30 et jour 3 relus (%s, jour %d)" % [m.cycle.texte_heure(), m.cycle.jour])
	_v(int(prog["competences"]["niveaux"]["une_main"]) == 30 and int(prog["niveau"]) > 1, "ancienne sauvegarde : compétences migrées (épée -> une_main 30), niveau recalculé %d" % int(prog["niveau"]))
	_v(Vector2(j.global_position.x, j.global_position.z).distance_to(Vector2(10, 10)) < 2.5, "ancienne sauvegarde : position de retour (%s)" % j.global_position)
	_v(not m.draugrs.has("sbire_4"), "ancienne sauvegarde : gardien mort le reste")
	_v(absf(j.vie - 55.0) < 0.5 or j.vie <= j.vie_max, "ancienne sauvegarde : PV relus (%.1f)" % j.vie)

	# repasse en v2, découpe, relecture
	_v(m.sauvegarder(1), "sauvegarde au format courant")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fichier))
	_v(Migration.version_de(d) == Migration.VERSION and d.has("progression") and not d.has("competences"), "le fichier réécrit est en version %d" % Migration.VERSION)
	var sep: Dictionary = SauvegardeMulti.separer(d)
	_v((sep["monde"] as Dictionary).has("heure") and (sep["monde"] as Dictionary).has("quetes") and (sep["personnage"] as Dictionary).has("inventaire") and (sep["personnage"] as Dictionary).has("progression"), "le fichier se découpe en monde + personnage")
	_v(_json(SauvegardeMulti.fusionner(sep["monde"], sep["personnage"])) == _json(d), "monde + personnage = le fichier d'origine")
	var ex: Dictionary = SauvegardeMulti.valider(JSON.parse_string(JSON.stringify(m.exporter_personnage())))
	_v(bool(ex["ok"]) and (ex["corrections"] as Array).is_empty(), "un vrai personnage passe la validation sans correction (%s)" % str(ex["corrections"]))
	j.inventaire.pieces = 1
	j.inventaire.objets.erase("os_draugr")
	m.cycle.heure = 20.0
	m.charger()
	_v(j.inventaire.pieces == 77 and int(j.inventaire.objets.get("os_draugr", 0)) == 3 and absf(m.cycle.heure - 5.5) < 0.05, "recharger la sauvegarde v2 rend le même état")

	# hôte coop sans invité : comme en solo ; fichier personnage d'invité
	var R: Node = root.get_node("Reseau")
	R.nom_joueur = "Testeur 5b"
	_v(R.heberger(_port) == OK, "l'hôte ouvre le port %d" % _port)
	_v(m.sauvegarder(2) and Jeu.sauvegarde_valide(Sauvegardes.fichier(2)), "hôte : la sauvegarde du monde (emplacement 2) s'écrit comme en solo")
	var dh: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sauvegardes.fichier(2)))
	_v(dh.has("quetes") and dh.has("inventaire"), "hôte : le fichier contient le monde ET le personnage de l'hôte")
	R.deconnecter()
	SauvegardeMulti.effacer_personnage("Testeur 5b")
	_v(m.sauvegarder_personnage() and SauvegardeMulti.personnage_existe("Testeur 5b"), "invité : son personnage s'écrit dans user://personnages/")
	var pf: Dictionary = SauvegardeMulti.lire_personnage("Testeur 5b")
	_v(not pf.has("heure") and not pf.has("quetes") and int(pf["inventaire"]["pieces"]) == 77, "fichier personnage : pas de données du monde, 77 pièces")
	var avant: Vector3 = j.global_position
	j.inventaire.pieces = 5
	m.importer_personnage(pf, false)
	_v(j.inventaire.pieces == 77 and j.global_position.distance_to(avant) < 0.01, "importer_personnage(invité) : sac rétabli, position inchangée (apparition près de l'hôte)")
	SauvegardeMulti.effacer_personnage("Testeur 5b")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sauvegardes.fichier(2)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fichier))
	m.queue_free()
