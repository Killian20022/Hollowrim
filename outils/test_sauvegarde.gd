extends SceneTree
## Test sans fenêtre de la sauvegarde, en deux processus (comme F9, qui relance le jeu) :
##   -s res://outils/test_sauvegarde.gd -- ecrire   puis   -- verifier
const SCENE := preload("res://scenes/foret_test.tscn")
## Fichier de TEST (le jeu l'utilise dès qu'il y a des arguments) : jamais la vraie partie.
var FICHIER: String = load("res://scripts/monde.gd").fichier_test()

func _init() -> void:
	_tester.call_deferred(OS.get_cmdline_user_args()[0])

func _tester(etape: String) -> void:
	if FICHIER == "user://sauvegarde.json" or load("res://scripts/monde.gd").fichier_sauvegarde() != FICHIER:
		print("TEST SAUVEGARDE : ÉCHEC (le jeu viserait la vraie sauvegarde, test annulé)")
		quit(1)
		return
	if etape == "ecrire":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	for i in 10:
		await process_frame
	if etape == "ecrire":
		m.joueur.inventaire.ajouter("pieces", 11)
		Marchand.avancer(30.0)                          # lot L8 : 30 h de jeu, puis un pain acheté à Grima (4 pièces → reste 7)
		print("marchand : ", Marchand.acheter("ancienne", m.joueur.inventaire, "pain_seigle", 1), " stock=", Marchand.stock("ancienne"))
		m.joueur.inventaire.ajouter("os_draugr", 2)
		m.joueur.inventaire.ajouter("potion_soin", 3)   # consommable (data/butin/objets.json)
		ButinTables.piller("test:urne_sauvegarde")      # contenant vidé (docs/BUTIN.md)
		m.joueur.competences.pratiquer("epee", 30.0)
		m.sbire.recevoir_coup(999.0, m.joueur.global_position, true)
		m.joueur.position = Vector3(10, m.hauteur(10, 10) + 0.1, 10)
		m.cycle.heure = 3.5
		m.sauvegarder()
		print("ÉCRIT : épée=", m.joueur.competences.niveaux["epee"])
	else:
		var j = m.joueur
		var ok: bool = j.inventaire.pieces == 7 and j.inventaire.objets.get("os_draugr", 0) == 2
		ok = ok and j.competences.niveaux["epee"] > 15 and not m.draugrs.has("sbire_4")
		ok = ok and j.position.distance_to(Vector3(10, m.hauteur(10, 10), 10)) < 1.0
		ok = ok and absf(m.cycle.heure - 3.5) < 0.1
		var ok_butin: bool = j.inventaire.objets.get("potion_soin", 0) == 3 and ButinTables.est_pille("test:urne_sauvegarde") and not ButinTables.est_pille("test:autre")
		print("butin : potions=", j.inventaire.objets.get("potion_soin", 0), " pillés=", ButinTables.pilles.keys(), " -> ", "OK" if ok_butin else "ÉCHEC")
		ok = ok and ok_butin
		var pain0 := int(Marchand.stock_tire("ancienne", 0).get("pain_seigle", 0))
		var ok_marchand: bool = Marchand.heures >= 30.0 and Marchand.heures < 31.0 and int(Marchand.stock("ancienne").get("pain_seigle", 0)) == pain0 - 1 \
			and Marchand.or_de("ancienne") == int(Marchand.fiche("ancienne")["or"]) + 4 and j.inventaire.objets.get("pain_seigle", 0) == 1
		print("marchands : heures=", Marchand.heures, " stock Grima=", Marchand.stock("ancienne"), " bourse=", Marchand.or_de("ancienne"), " -> ", "OK" if ok_marchand else "ÉCHEC")
		ok = ok and ok_marchand
		print("épée=", j.competences.niveaux["epee"], " pièces=", j.inventaire.pieces, " draugrs=", m.draugrs.keys(), " heure=", m.cycle.texte_heure())
		print("TEST SAUVEGARDE : ", "OK" if ok else "ÉCHEC")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit()
