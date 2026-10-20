extends SceneTree
## Précalcule les cartes de sol (carte 960² + empreintes) dans assets/sol/carte_sol.res et carte_traces.res.
## Le monde entier est construit une fois (le calcul dépend du relief, des arbres, des rochers et des chemins) ;
## Sol relit ensuite ces fichiers au lancement si la signature des entrées n'a pas changé (sinon il recalcule).
##   godot --headless --path . --script res://outils/generer_carte_sol.gd -- --nouvelle            (écrit)
##   godot --headless --path . --script res://outils/generer_carte_sol.gd -- --nouvelle --verifier  (compare au calcul direct)
const SCENE := preload("res://scenes/foret_test.tscn")

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var verifier := OS.get_cmdline_user_args().has("--verifier")
	Sol.cache_mode = Sol.CACHE_VERIFIER if verifier else Sol.CACHE_ECRIRE
	var m: Node = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 3:
		await process_frame
	print("carte de sol : %s (calcul %.0f ms)" % [Sol.cache_statut, Sol.temps_ms])
	m.queue_free()
	await process_frame
	quit(1 if Sol.cache_statut in ["DIFFERENT", "absent", "perime"] else 0)
