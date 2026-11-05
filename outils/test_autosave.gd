extends SceneTree
## Test sans fenêtre des emplacements de sauvegarde et de l'autosauvegarde (scripts/sauvegardes.gd, Monde.autosauvegarder) :
##   godot --headless --path . --script res://outils/test_autosave.gd -- --nouvelle
## - écriture ATOMIQUE : aucun .tmp ne traîne, un contenu invalide n'écrase pas la bonne sauvegarde ;
## - 3 emplacements manuels + 1 automatique, fichiers distincts ; l'emplacement 1 est l'ancien fichier (migration : rien à convertir) ;
## - l'autosauvegarde écrit l'emplacement automatique (jamais ceux du joueur), attend la fin d'un combat, se déclenche à la fin
##   d'une quête, à la porte d'une maison et à l'entrée/sortie d'un donjon, et toutes les 10 minutes ;
## - « Continuer » prend la sauvegarde la plus récente ; une sauvegarde ancienne (sans clé inconnue) se relit toujours.
## Ne touche qu'aux fichiers de TEST de ce worktree, supprimés à la fin.
const SCENE := preload("res://scenes/foret_test.tscn")
var echecs := 0

func ok(c: bool, texte: String) -> void:
	print(("OK     " if c else "ÉCHEC  ") + texte)
	if not c:
		echecs += 1

func _init() -> void:
	_tester.call_deferred()

func _nettoyer() -> void:
	for e: int in Sauvegardes.tous():
		for suffixe in ["", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Sauvegardes.fichier(e) + suffixe))
	Sauvegardes.actif = 1

func _attendre(s: float) -> void:
	await create_timer(s).timeout

func _tester() -> void:
	_nettoyer()
	ok(Sauvegardes.fichier(1) == Sauvegardes.fichier_base() and Sauvegardes.fichier_base().contains("sauvegarde_test_"), "emplacement 1 = fichier de TEST d'avant les emplacements")
	var noms := {}
	for e: int in Sauvegardes.tous():
		noms[Sauvegardes.fichier(e)] = true
	ok(noms.size() == 4 and Sauvegardes.fichier(0).ends_with("_auto.json") and Sauvegardes.fichier(2).ends_with("_2.json") and Sauvegardes.fichier(3).ends_with("_3.json"), "4 fichiers distincts (auto, 1, 2, 3)")
	# --- écriture atomique ---
	var f1 := Sauvegardes.fichier(1)
	ok(Sauvegardes.ecrire(f1, '{"version": 2, "inventaire": {"pieces": 5}}') == OK and Jeu.sauvegarde_valide(f1), "écriture d'une sauvegarde valide")
	ok(not FileAccess.file_exists(f1 + ".tmp"), "aucun fichier .tmp après l'écriture")
	ok(Sauvegardes.ecrire(f1, "{ pas du json") != OK, "un contenu illisible est refusé…")
	ok(Jeu.sauvegarde_valide(f1) and int(Jeu.resume_sauvegarde(f1)["pieces"]) == 5 and not FileAccess.file_exists(f1 + ".tmp"), "…et la bonne sauvegarde est intacte, sans .tmp")
	ok(Sauvegardes.ecrire(f1, '{"version": 2, "inventaire": {"pieces": 9}}') == OK and int(Jeu.resume_sauvegarde(f1)["pieces"]) == 9, "réécriture sur un fichier existant")
	# --- migration : un ancien fichier = emplacement 1 ---
	var r1 := Sauvegardes.resume(1)
	ok(not r1["vide"] and int(r1["pieces"]) == 9 and Sauvegardes.resume(2)["vide"] and Sauvegardes.resume(0)["vide"], "l'ancien fichier est listé comme emplacement 1, les autres sont vides")
	ok(Sauvegardes.ligne(Sauvegardes.resume(3)) == "Emplacement 3 — vide", "ligne d'un emplacement vide : « %s »" % Sauvegardes.ligne(Sauvegardes.resume(3)))
	ok(Sauvegardes.plus_recent() == 1 and Sauvegardes.premier_libre() == 2, "plus récent = 1, premier libre = 2")
	# --- monde ---
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	for i in 10:
		await process_frame
	m.joueur.inventaire.ajouter("pieces", 3)
	# autosauvegarde : emplacement automatique seulement
	var mtime1 := FileAccess.get_modified_time(f1)
	ok(m.autosauvegarder(), "autosauvegarder() réussit")
	ok(Sauvegardes.valide(0) and Sauvegardes.actif == 1 and FileAccess.get_modified_time(f1) == mtime1 and int(Jeu.resume_sauvegarde(f1)["pieces"]) == 9, "écrit l'automatique, laisse l'emplacement 1 et l'emplacement en cours intacts")
	ok(m.derniere_autosauvegarde != "", "raison retenue (%s)" % m.derniere_autosauvegarde)
	# sauvegarde manuelle dans l'emplacement 2
	ok(m.sauvegarder(2) and Sauvegardes.valide(2) and Sauvegardes.actif == 2, "sauvegarde manuelle dans l'emplacement 2 → emplacement en cours")
	ok(m.fichier_sauvegarde() == Sauvegardes.fichier(2), "Monde.fichier_sauvegarde() suit l'emplacement en cours")
	Sauvegardes.actif = 0
	ok(Sauvegardes.emplacement_rapide() == 3, "F5 depuis l'automatique : premier emplacement libre (3), pas d'écrasement")
	Sauvegardes.actif = 1
	# déclencheurs
	var avant := FileAccess.get_modified_time(Sauvegardes.fichier(0))
	await _attendre(1.2)   # les horodatages sont à la seconde
	# fin de quête
	m.quetes.quete_terminee.emit("test")
	await _attendre(3.5)
	ok(FileAccess.get_modified_time(Sauvegardes.fichier(0)) > avant and m.derniere_autosauvegarde == "quête", "fin de quête → autosauvegarde (%s)" % m.derniere_autosauvegarde)
	# combat : attend
	avant = FileAccess.get_modified_time(Sauvegardes.fichier(0))
	await _attendre(1.2)
	var ennemi := Node3D.new()
	var sc := GDScript.new()   # faux ennemi : en combat tant que `au_combat` est vrai
	sc.source_code = "extends Node3D\nvar au_combat := true\nfunc en_combat() -> bool:\n\treturn au_combat\n"
	sc.reload()
	ennemi.set_script(sc)
	ennemi.add_to_group("ennemis")
	m.add_child(ennemi)
	m.demander_autosauvegarde("donjon")
	await _attendre(3.0)
	ok(m.en_combat() and FileAccess.get_modified_time(Sauvegardes.fichier(0)) == avant, "en combat : l'autosauvegarde attend")
	ennemi.set("au_combat", false)
	await _attendre(3.5)
	ok(not m.en_combat() and FileAccess.get_modified_time(Sauvegardes.fichier(0)) > avant and m.derniere_autosauvegarde == "donjon", "combat fini : l'autosauvegarde est faite (%s)" % m.derniere_autosauvegarde)
	# porte de maison
	avant = FileAccess.get_modified_time(Sauvegardes.fichier(0))
	await _attendre(1.2)
	var maisons: Array = m.village.interieurs
	if not maisons.is_empty():
		maisons[0].porte_actionnee.emit(true)
		await _attendre(3.5)
		ok(FileAccess.get_modified_time(Sauvegardes.fichier(0)) > avant and m.derniere_autosauvegarde == "maison", "porte de maison → autosauvegarde (%s)" % m.derniere_autosauvegarde)
	else:
		ok(false, "aucune maison dans le village de test")
	# minuterie de 10 minutes
	avant = FileAccess.get_modified_time(Sauvegardes.fichier(0))
	await _attendre(1.2)
	m._minuterie_sauvegarde = m.INTERVALLE_AUTOSAUVEGARDE - 0.2
	await _attendre(3.5)
	ok(m.INTERVALLE_AUTOSAUVEGARDE == 600.0 and FileAccess.get_modified_time(Sauvegardes.fichier(0)) > avant and m.derniere_autosauvegarde == "temps", "toutes les 10 minutes → autosauvegarde (%s)" % m.derniere_autosauvegarde)
	# donjon : entrée de la crypte
	avant = FileAccess.get_modified_time(Sauvegardes.fichier(0))
	await _attendre(1.2)
	m.tertre.entree.emit(true)
	await _attendre(6.0)
	ok(FileAccess.get_modified_time(Sauvegardes.fichier(0)) > avant and m.derniere_autosauvegarde == "donjon", "entrée/sortie de donjon → autosauvegarde (%s)" % m.derniere_autosauvegarde)
	# mort : pas d'autosauvegarde
	m.joueur.mort = true
	ok(not m.autosauvegarder(), "joueur mort : pas d'autosauvegarde (on garderait une partie perdue)")
	m.joueur.mort = false
	# le plus récent
	await _attendre(1.2)
	m.sauvegarder(3)
	ok(Sauvegardes.plus_recent() == 3, "le plus récent est l'emplacement 3 (« Continuer » le reprend)")
	ok(Sauvegardes.premier_libre() == -1 and Sauvegardes.emplacement_rapide() == 3, "trois emplacements pris : plus de libre, F5 écrit dans l'emplacement en cours")
	_nettoyer()
	print("TEST AUTOSAVE : ", "OK" if echecs == 0 else "ÉCHEC (%d)" % echecs)
	quit(1 if echecs > 0 else 0)
