extends SceneTree
## Test sans fenêtre de la sauvegarde, en deux processus (comme F9, qui relance le jeu) :
##   -s res://outils/test_sauvegarde.gd -- ecrire   puis   -- verifier
const SCENE := preload("res://scenes/foret_test.tscn")
const FICHIER := "user://sauvegarde.json"

func _init() -> void:
	_tester.call_deferred(OS.get_cmdline_user_args()[0])

func _tester(etape: String) -> void:
	if etape == "ecrire":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	for i in 10:
		await process_frame
	if etape == "ecrire":
		m.joueur.inventaire.ajouter("pieces", 7)
		m.joueur.inventaire.ajouter("os_draugr", 2)
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
		print("épée=", j.competences.niveaux["epee"], " pièces=", j.inventaire.pieces, " draugrs=", m.draugrs.keys(), " heure=", m.cycle.texte_heure())
		print("TEST SAUVEGARDE : ", "OK" if ok else "ÉCHEC")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit()
