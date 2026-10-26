extends SceneTree
## Rendu identique avec ou sans chargement étalé : construit le monde comme l'écran de chargement (Jeu.chargement_etale, arbre en
## pause, une image rendue entre les étapes de Monde._ready) ou d'un seul bloc, puis prend un lot de captures (--captures du monde).
## Fenêtre nécessaire (hors écran via godot_slot) ; comparer ensuite les deux dossiers avec outils/diff_images.gd.
##   godot --path . --script res://outils/comparer_chargement_etale.gd -- [--etale] --nouvelle --captures=<poses> --sortie=<dossier>
func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var etale := OS.get_cmdline_user_args().has("--etale")
	Jeu.chargement_etale = etale
	var m: Node = (load(Jeu.SCENE_JEU) as PackedScene).instantiate()
	paused = etale                 # comme l'écran de chargement : rien ne tourne pendant que le monde se bâtit
	root.add_child(m)
	current_scene = m
	var t0 := Time.get_ticks_msec()
	var images := 0
	while m.get("pret") != true:
		await process_frame
		images += 1
	print("COMPARER chargement %s : monde prêt en %d ms, %d images pendant l'entrée" % ["étalé" if etale else "d'un bloc", Time.get_ticks_msec() - t0, images])
	Jeu.chargement_etale = false
	paused = false                 # les captures (--captures) se chargent de la suite et quittent
