extends SceneTree
## Précalcule la géométrie du village v2 de RuesVillage (pavés, marches, murs, sillons, lanternes, clôtures, collisions) dans
## assets/modeles/rues_village.cache. Le monde est construit une fois (la géométrie suit le relief) ; RuesVillage relit ensuite
## ce fichier au lancement si la signature (sources + relief échantillonné) n'a pas changé (sinon il recalcule, ≈ 1 s).
##   godot --headless --path . --script res://outils/generer_rues_village.gd -- --nouvelle            (écrit)
##   godot --headless --path . --script res://outils/generer_rues_village.gd -- --nouvelle --verifier  (compare au calcul direct)
const SCENE := preload("res://scenes/foret_test.tscn")

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var verifier := OS.get_cmdline_user_args().has("--verifier")
	RuesVillage.cache_mode = RuesVillage.CACHE_VERIFIER if verifier else RuesVillage.CACHE_ECRIRE
	var m: Node = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 3:
		await process_frame
	print("rues du village : %s (calcul %d ms)" % [RuesVillage.cache_statut, RuesVillage.temps_ms])
	m.queue_free()
	await process_frame
	quit(1 if RuesVillage.cache_statut in ["DIFFERENT", "absent", "perime", ""] else 0)
