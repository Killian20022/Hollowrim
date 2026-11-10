extends SceneTree
## Garde-fous du chargement (chargement de la nuit du 2026-11-05) :
##   - caches signés À JOUR : « RuesVillage (lu) » et carte de sol « lue » (un cache périmé coûte ~1 s à chaque lancement ;
##     le régénérer : `godot --headless --path . --script res://outils/precalculer_tout.gd -- --seulement=rues,carte_sol`) ;
##   - grille des arbres (brume locale) identique à la boucle brute sur tous les arbres ;
##   - étals du village : pièces exposées APRÈS la fin du chargement (exposition différée), jamais avant.
##   - avec --etale (chargement de l'écran titre) : les villageois à naissance différée sont nés AVANT la fin du chargement (plus de gel en jeu).
##   godot --headless --path . --script res://outils/test_chargement.gd -- --nouvelle [--etale]
const SCENE := preload("res://scenes/foret_test.tscn")
var _ok := true
var _n := 0

func _verif(c: bool, msg: String) -> void:
	_n += 1
	print(("OK    " if c else "ECHEC ") + msg)
	if not c:
		_ok = false

func _init() -> void:
	_go.call_deferred()

func _pieces(m: Node) -> int:
	var n := 0
	for e in m.find_children("Etal_*", "Node3D", true, false):
		n += e.get_node("Pieces").get_child_count() if e.has_node("Pieces") else 0
	return n

func _go() -> void:
	var etale := OS.get_cmdline_user_args().has("--etale")
	Jeu.chargement_etale = etale
	var m: Node3D = SCENE.instantiate()
	paused = etale   # comme l'écran de chargement : rien ne tourne pendant que le monde se bâtit
	root.add_child(m)
	current_scene = m
	while m.get("pret") != true:
		await process_frame
	Jeu.chargement_etale = false
	paused = false
	if etale:
		# 2026-11-10 (saccades) : les naissances différées (~200 ms chacune sur le fil principal = gels dans les premières secondes de jeu)
		# se font désormais DANS le chargement (Monde._terminer_fonds) : à `pret`, plus aucun villageois en attente
		var nes := get_nodes_in_group("villageois").size()   # 14 gardes + les habitants nés pendant le chargement
		_verif(m._pnj_differes.is_empty() and nes >= 24, "chargement étalé : aucun villageois en attente à la fin du chargement, %d dans le groupe" % nes)
		var ids: Array = []
		for v in get_nodes_in_group("villageois"):
			ids.append(v.donnees.get("id", "?"))
		_verif(ids.has("forgeron") and ids.has("chef"), "Brodd et Gunnar sont là")
	_verif(RuesVillage.cache_statut == "lu", "rues du village : cache valide (statut « %s »)" % RuesVillage.cache_statut)
	_verif(Sol.cache_statut == "lu", "carte de sol : cache valide (statut « %s »)" % Sol.cache_statut)
	_verif(m.arbres.size() > 500, "%d arbres" % m.arbres.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var diff := 0
	for i in 200:
		var p := Vector3(rng.randf_range(-120.0, 120.0), 0.0, rng.randf_range(-120.0, 120.0))
		if i < 60 and m.arbres.size() > 0:   # points collés aux arbres (cas limites des cases)
			var t: Transform3D = m.arbres[rng.randi() % m.arbres.size()]
			p = Vector3(t.origin.x + rng.randf_range(-14.0, 14.0), 0.0, t.origin.z + rng.randf_range(-14.0, 14.0))
		var brut := 0
		for t: Transform3D in m.arbres:
			var dx := t.origin.x - p.x
			var dz := t.origin.z - p.z
			if dx * dx + dz * dz < 196.0:
				brut += 1
		if brut != m.arbres_autour(p, 14.0):
			diff += 1
	_verif(diff == 0, "grille des arbres : identique à la boucle brute sur 200 points (%d écarts)" % diff)
	var etals := m.find_children("Etal_*", "Node3D", true, false)
	_verif(etals.size() == 2, "deux étals posés (Brodd, Grima)")
	for essai in 600:
		if _pieces(m) >= 4:
			break
		await process_frame
	_verif(_pieces(m) >= 4, "étals : %d pièces exposées après le chargement" % _pieces(m))
	print("ECHECS : %d" % (0 if _ok else 1))
	print("RESULTAT ", "OK" if _ok else "ECHEC", " (%d vérifications)" % _n)
	quit(0 if _ok else 1)
