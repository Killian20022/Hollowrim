extends SceneTree
## Mesure du chargement du monde (nouvelle partie ou « continuer »), fenêtre hors écran ou --headless :
##   godot [--headless] --path . --script res://outils/mesure_chargement.gd -- --nouvelle (sinon : « continuer », lit la sauvegarde de test) [--chrono] [--attente=N]
## Reproduit l'entrée du monde de l'écran de chargement (Jeu.chargement_etale, arbre en pause), mesure le temps jusqu'à `pret`,
## puis attend N secondes (3 par défaut) la fin des créations différées et imprime : « MESURE <mode> : prêt en … ms ; différé fini
## en … ms ; mémoire statique … Mo ». `--ecrire-sauvegarde` écrit la sauvegarde de test en fin de mesure (pour mesurer ensuite « continuer »).
func _init() -> void:
	_lancer.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _lancer() -> void:
	var continuer := _arg("nouvelle") == ""
	Jeu.chargement_etale = _arg("bloc") == ""
	var t0 := Time.get_ticks_msec()
	var m: Node = (load(Jeu.SCENE_JEU) as PackedScene).instantiate()
	paused = Jeu.chargement_etale
	root.add_child(m)
	current_scene = m
	var images := 0
	while m.get("pret") != true:
		await process_frame
		images += 1
	var t_pret := Time.get_ticks_msec() - t0
	Jeu.chargement_etale = false
	paused = false
	var statique := OS.get_static_memory_usage() / 1048576.0
	var t1 := Time.get_ticks_msec()
	var attente := float(_arg("attente", "3"))
	await create_timer(attente).timeout
	print("MESURE %s : prêt en %d ms (%d images) ; mémoire statique %.0f Mo après %.0f s : %.0f Mo ; nœuds %d" % [
		"continuer" if continuer else "nouvelle", t_pret, images, statique, attente, OS.get_static_memory_usage() / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	if _arg("ecrire-sauvegarde") != "":
		m.sauvegarder()
		print("MESURE sauvegarde écrite : ", m.fichier_sauvegarde())
	quit()
