extends SceneTree
## Test sans fenêtre des briques de la sortie Hollowrim (scripts/jeu.gd), sur des dossiers TEMPORAIRES
## (captures/test_sortie/<horodatage>) : jamais l'ancien dossier des sauvegardes ni un dossier du joueur.
##   godot --headless --path . --script res://outils/test_sortie.gd
## - migration : copie depuis l'« ancien » dossier si le neuf n'a pas de partie ; ne touche pas l'ancien ; ne remplace jamais
##   une partie déjà présente dans le neuf.
## - copie de secours : horodatée, 10 gardées, dossier impossible = false sans plantage, restauration de la plus récente
##   lisible (sauvegarde locale illisible gardée en .corrompue).
## - options : valeurs par défaut, mode outil.

var echecs := 0

func ok(c: bool, texte: String) -> void:
	print(("OK     " if c else "ÉCHEC  ") + texte)
	if not c:
		echecs += 1

func _init() -> void:
	var racine := ProjectSettings.globalize_path("res://captures/test_sortie").path_join(Time.get_datetime_string_from_system().replace(":", "-"))
	var ancien := racine.path_join("ancien")
	var neuf := racine.path_join("neuf")
	DirAccess.make_dir_recursive_absolute(ancien)
	_ecrire(ancien.path_join("sauvegarde.json"), '{"version": 1, "joueur": {"vie": 33}}')
	_ecrire(ancien.path_join("fenetre.cfg"), "[fenetre]\nplein_ecran=true\n")
	var t_ancien := FileAccess.get_modified_time(ancien.path_join("sauvegarde.json"))
	# 1) migration
	var copies := Jeu.migrer(ancien, neuf)
	ok(copies.has("sauvegarde.json") and copies.has("fenetre.cfg"), "migration : fichiers copiés %s" % [copies])
	ok(FileAccess.get_file_as_string(neuf.path_join("sauvegarde.json")).contains('"vie": 33'), "migration : contenu identique")
	ok(FileAccess.file_exists(ancien.path_join("sauvegarde.json")) and FileAccess.get_modified_time(ancien.path_join("sauvegarde.json")) == t_ancien, "migration : ancien dossier intact")
	_ecrire(neuf.path_join("sauvegarde.json"), '{"version": 1, "joueur": {"vie": 99}}')
	ok(Jeu.migrer(ancien, neuf).is_empty() and FileAccess.get_file_as_string(neuf.path_join("sauvegarde.json")).contains("99"), "migration : une partie déjà présente n'est jamais remplacée")
	ok(Jeu.migrer(racine.path_join("absent"), racine.path_join("neuf2")).is_empty(), "migration : rien à copier sans ancienne partie")
	# 2) copie de secours
	var secours := racine.path_join("secours")
	var partie := neuf.path_join("sauvegarde.json")
	for i in 12:
		_ecrire(partie, '{"version": 1, "n": %d}' % i)
		var reussi := Jeu.copie_secours(partie, secours)
		if i == 0:
			ok(reussi and Jeu.copies_secours(secours).size() == 1, "copie de secours : première copie horodatée")
		# horodatage à la seconde : on renomme pour simuler 12 sauvegardes à des moments différents
		var liste := Jeu.copies_secours(secours)
		var derniere := liste[liste.size() - 1]
		DirAccess.rename_absolute(derniere, secours.path_join("%s_sauvegarde_2026-01-01_00-00-%02d.json" % [Jeu.nom(), i]))
	# l'élagage se fait à la copie suivante : une 13e copie ramène à 10
	Jeu.copie_secours(partie, secours)
	var liste := Jeu.copies_secours(secours)
	ok(liste.size() == Jeu.SECOURS_GARDEES, "copie de secours : %d gardées (attendu %d)" % [liste.size(), Jeu.SECOURS_GARDEES])
	ok(not liste[0].ends_with("00-00-00.json") and not liste[0].ends_with("00-00-01.json") and not liste[0].ends_with("00-00-02.json"), "copie de secours : les plus anciennes sont supprimées")
	var tmp_restants := Array(DirAccess.get_files_at(secours)).filter(func(f: String) -> bool: return f.ends_with(".tmp"))
	ok(tmp_restants.is_empty(), "copie de secours : aucun .tmp laissé (écriture atomique)")
	_ecrire(secours.path_join("autre_fichier.json"), "{}")
	Jeu.copie_secours(partie, secours)
	ok(FileAccess.file_exists(secours.path_join("autre_fichier.json")), "copie de secours : les fichiers étrangers ne sont jamais supprimés")
	# dossier impossible (un FICHIER porte ce nom) : false, avertissement, pas de plantage
	var bloque := racine.path_join("pas_un_dossier")
	_ecrire(bloque, "x")
	ok(not Jeu.copie_secours(partie, bloque.path_join("sous")) and Jeu.avertissement_secours != "", "copie de secours : échec discret (%s)" % Jeu.avertissement_secours)
	# 3) validité et restauration (fonctions en chemin absolu)
	ok(Jeu.sauvegarde_valide(partie), "sauvegarde valide reconnue")
	_ecrire(partie, "{ corrompue")
	ok(not Jeu.sauvegarde_valide(partie), "sauvegarde illisible reconnue")
	var locale: String = load("res://scripts/monde.gd").fichier_test()
	_ecrire(ProjectSettings.globalize_path(locale), "{ corrompue")
	ok(Jeu.restaurer_secours(secours) and Jeu.sauvegarde_valide(locale), "restauration de la copie la plus récente")
	ok(FileAccess.file_exists(ProjectSettings.globalize_path(locale) + ".corrompue"), "sauvegarde illisible gardée en .corrompue")
	# 4) options
	Jeu.charger_options()
	ok(Jeu.option("sauvegarde", "dossier_secours") is String and Jeu.option("commandes", "sensibilite") is float, "options : types attendus")
	ok(Jeu.mode_outil(), "mode outil reconnu en --script (titre sauté, options non appliquées)")
	ok(Jeu.dossier_secours() == "", "pas de copie de secours en mode outil")
	print("TEST SORTIE : ", "OK" if echecs == 0 else "ÉCHECS : %d" % echecs)
	quit(0 if echecs == 0 else 1)

func _ecrire(chemin: String, texte: String) -> void:
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(texte)
	f.close()
