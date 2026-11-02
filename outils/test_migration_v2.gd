extends SceneTree
## Sauvegarde v2 et migration v1 -> v2 (scripts/rpg/migration.gd, docs/RPG.md §7), en deux processus :
##   godot --headless --path . --script res://outils/test_migration_v2.gd -- v1    puis    -- v2
## v1 : fonctions pures sur une COPIE d'une vraie sauvegarde v1 (outils/donnees_test/sauvegarde_v1_reelle.json) et sur une
##      v1 « avancée » écrite ici ; puis la copie réelle est posée dans le fichier de TEST, chargée par le jeu (foret_test),
##      vérifiée, et ressauvegardée (version 2).
## v2 : le fichier v2 relu par un nouveau processus donne le même état ; le fichier de test est effacé.
## Jamais user://sauvegarde.json (vérifié avant tout).

const SCENE := preload("res://scenes/foret_test.tscn")
const V1_REELLE := "res://outils/donnees_test/sauvegarde_v1_reelle.json"
var FICHIER: String = load("res://scripts/monde.gd").fichier_test()

var _ok := true
var _n := 0

func _init() -> void:
	_tester.call_deferred(OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "v1")

func _verif(cond: bool, msg: String) -> void:
	_n += 1
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _fin() -> void:
	print("ECHECS : %d  (%d vérifications)" % [0 if _ok else 1, _n])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)

func _lire(chemin: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	return d if d is Dictionary else {}

func _tester(etape: String) -> void:
	if FICHIER == "user://sauvegarde.json" or load("res://scripts/monde.gd").fichier_sauvegarde() != FICHIER or not FICHIER.contains("test"):
		print("ÉCHEC : le jeu viserait la vraie sauvegarde, test annulé")
		quit(1)
		return
	if etape == "v1":
		_pures()
		await _charger_v1()
	else:
		await _relire_v2()
	_fin()

# ------------------------------------------------------------------ fonctions pures

func _pures() -> void:
	var reelle := _lire(V1_REELLE)
	_verif(Migration.version_de(reelle) == 1 and reelle.has("competences"), "copie de la vraie sauvegarde v1 lue (version 1)")
	var avant := reelle.duplicate(true)
	var m := Migration.migrer(reelle)
	_verif(reelle == avant, "migrer() ne modifie pas le dictionnaire d'origine")
	_verif(int(m["version"]) == 2 and m.has("progression") and not m.has("competences"), "v1 -> v2 : version 2, clé progression, ancienne clé competences retirée")
	var pc: Dictionary = m["progression"]["competences"]["niveaux"]
	var niv_v1: Dictionary = reelle["competences"]["niveaux"]
	_verif(int(pc["une_main"]) == int(niv_v1["epee"]) and int(pc["parade"]) == int(niv_v1["parade"]) and int(pc["athletisme"]) == int(niv_v1["athletisme"]),
		"compétences reprises (epee -> une_main %d, parade %d, athlétisme %d)" % [pc["une_main"], pc["parade"], pc["athletisme"]])
	var huit := true
	for c in Progression.COMPETENCES:
		huit = huit and pc.has(c)
	_verif(huit and int(pc["destruction"]) == 15 and int(pc["furtivite"]) == 15, "les 8 compétences présentes, nouvelles à 15")
	_verif(absf(float(m["progression"]["competences"]["experience"]["une_main"]) - float(reelle["competences"]["experience"]["epee"])) < 0.0001, "expérience de compétence reprise")
	_verif(m["inventaire"] == reelle["inventaire"], "sac identique (aucun objet perdu) %s" % str(m["inventaire"]))
	var autres := true
	for k in reelle:
		if k in ["version", "competences"]:
			continue
		if k != "inventaire" and m.get(k) != reelle[k]:
			autres = false
			print("   clé changée : ", k)
	_verif(autres, "toutes les autres clés gardées telles quelles (%d clés)" % reelle.size())
	# niveau : épée 15 -> 16 = 16 XP, quête sceaux_brises en cours (1/5) : niveau 1, aucun point
	var xp_attendu := 0.0
	for c in Progression.COMPETENCES:
		xp_attendu += Progression.xp_competence_jusqua(int(pc[c]))
	_verif(int(m["progression"]["niveau"]) == 1 and absf(float(m["progression"]["xp_niveau"]) - xp_attendu) < 0.001 and int(m["progression"]["points_perk"]) == 0,
		"vraie sauvegarde : niveau 1, %.0f XP de niveau, 0 point" % xp_attendu)
	_verif(m["equipement_corps"] == {} and m["stockage"]["coffres"] == {}, "équipement de corps et coffres vides")
	_verif(Migration.migrer(m) == m, "une v2 n'est pas re-migrée")
	# v1 avancée : épée 35, parade 28, athlétisme 40, quêtes anneau_givre (6/6) et frere_ylva (3/3) finies, lames_brodd 2/4
	var av := {"version": 1, "competences": {"niveaux": {"epee": 35, "parade": 28, "athletisme": 40}, "experience": {"epee": 3.5, "parade": 1.0, "athletisme": 0.0}},
		"quetes": {"etat": {"anneau_givre": 6, "frere_ylva": 3, "lames_brodd": 2}, "vus": [], "journal": []},
		"inventaire": {"pieces": 512, "objets": {"epee_skarnholt": 1, "hache_kolbeinn": 1, "amulette_givre": 3, "potion_soin": 4, "fragment_sceau_os": 1}}}
	var ma := Migration.migrer(av)
	var xp := (16 + 35) * 20 / 2.0 + (16 + 28) * 13 / 2.0 + (16 + 40) * 25 / 2.0 + 2 * Progression.XP_QUETE_DEFAUT   # 1496 + 300 = 1796
	var p := Progression.new()
	p.gagner_xp(xp, false)
	var pg: Dictionary = ma["progression"]
	_verif(int(pg["niveau"]) == p.niveau and p.niveau == 7 and int(pg["points_perk"]) == 6 and int(pg["points_attribut"]) == 6,
		"v1 avancée : %.0f XP -> niveau %d, 6 points d'arbre et 6 choix d'attribut À DÉPENSER" % [xp, int(pg["niveau"])])
	_verif(pg["attributs"] == {"vie": 0, "magie": 0, "vigueur": 0} and pg["perks"] == {}, "rien d'attribué d'office (le joueur choisit)")
	_verif(ma["inventaire"]["objets"].size() == 5 and int(ma["inventaire"]["pieces"]) == 512, "v1 avancée : sac intact")
	_verif(Migration.migrer({}).get("version") == 2 and int(Migration.migrer({})["progression"]["niveau"]) == 1, "sauvegarde sans version ni compétences : niveau 1")
	_verif(Migration.migrer({"version": 9, "x": 1}).get("version") == 9, "version future : rendue telle quelle")

# ------------------------------------------------------------------ chargement par le jeu

func _charger_v1() -> void:
	var f := FileAccess.open(FICHIER, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(V1_REELLE))
	f.close()
	var reelle := _lire(V1_REELLE)
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	for i in 10:
		await process_frame
	var j = m.joueur
	_verif(j.competences.niveaux["epee"] == int(reelle["competences"]["niveaux"]["epee"]) and j.progression.competence("une_main") == j.competences.niveaux["epee"],
		"jeu : compétence épée relue (%d), Progression.competence(\"une_main\") identique" % j.competences.niveaux["epee"])
	_verif(j.progression.niveau == 1 and j.progression.competence("destruction") == 15, "jeu : niveau 1, destruction 15")
	var sac_ok: bool = j.inventaire.pieces == int(reelle["inventaire"]["pieces"])
	for id in reelle["inventaire"]["objets"]:
		sac_ok = sac_ok and j.inventaire.nombre(id) == int(reelle["inventaire"]["objets"][id])
	_verif(sac_ok, "jeu : sac relu sans perte %s" % str(j.inventaire.exporter()))
	_verif(j.vie_max == 100.0 + (10.0 if j.benediction else 0.0) and j.mana_max == 100.0 and j.vigueur_max == 100.0 and j.inventaire.capacite() == Inventaire.CAPACITE,   # 150 depuis le lot A
		"jeu : maxima inchangés (vie %d, mana %d, vigueur %d, charge %d)" % [j.vie_max, j.mana_max, j.vigueur_max, j.inventaire.capacite()])
	_verif(ReglagesCombat.competence("une_main") == 1.0 and ReglagesCombat.competence("armure") == 1.0, "jeu : multiplicateurs de combat à 1,0")
	# un peu d'état v2 pour l'aller-retour : un choix d'attribut et une pièce dans le coffre de Grima
	j.progression.gagner_xp(Progression.seuil_niveau(1) + 5.0)
	_verif(j.progression.niveau == 2 and j.progression.choisir_attribut("vigueur") == "" and j.vigueur_max == 110.0 and j.inventaire.capacite() == Inventaire.CAPACITE + 5.0,
		"niveau 2, +10 vigueur -> vigueur max 110, charge +5")
	Stockage.conteneur("coffre_grima").ajouter("os_draugr", 2)
	m.sauvegarder()
	var v2 := _lire(FICHIER)
	_verif(int(v2.get("version", 0)) == 2 and v2.has("progression") and v2.has("equipement_corps") and v2.has("stockage") and not v2.has("competences"),
		"fichier réécrit en version 2 (progression, equipement_corps, stockage)")
	_verif(int(v2["progression"]["competences"]["niveaux"]["une_main"]) == int(reelle["competences"]["niveaux"]["epee"]), "v2 : compétences sous leurs noms canoniques")
	print("ÉCRIT v2 : ", JSON.stringify(v2["progression"]))

func _relire_v2() -> void:
	var v2 := _lire(FICHIER)
	_verif(int(v2.get("version", 0)) == 2, "fichier v2 présent")
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	for i in 10:
		await process_frame
	var j = m.joueur
	var pv: Dictionary = v2["progression"]
	var e: Dictionary = j.progression.exporter()
	var meme: bool = int(e["niveau"]) == int(pv["niveau"]) and absf(float(e["xp_niveau"]) - float(pv["xp_niveau"])) < 0.001 and int(e["points_perk"]) == int(pv["points_perk"]) \
		and int(e["points_attribut"]) == int(pv["points_attribut"])
	for c in pv["competences"]["niveaux"]:
		meme = meme and int(e["competences"]["niveaux"].get(c, -1)) == int(pv["competences"]["niveaux"][c])
	_verif(meme and e["competences"]["niveaux"].size() == 8,
		"progression relue à l'identique (niveau %d, points %d)" % [j.progression.niveau, j.progression.points_perk])
	_verif(j.progression.attributs["vigueur"] == 10 and j.vigueur_max == 110.0 and j.inventaire.capacite() == Inventaire.CAPACITE + 5.0, "attribut vigueur relu : maxima recalculés")
	_verif(Stockage.conteneur("coffre_grima").nombre("os_draugr") == 2, "coffre de Grima relu")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
