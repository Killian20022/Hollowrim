extends SceneTree
## Gel du chargement « après Donjon : intégré » (correctifs/gel_cache_persos, 2026-10-28). Le fil de préparation des ennemis
## (EnnemisNordiques.prechauffer_fil) bâtit les corps SOUS le verrou des constructeurs (EnnemisNordiques._bm, SqueletteGuerrier._mx)
## et fait pendant ce temps des appels au serveur de rendu qui attendent une réponse (surface_get_arrays…) : avec une fenêtre, seul le
## fil principal vide leur file. Si le fil principal demande alors un corps sans gabarit (draugr du cercle, gardiens d'une autre zone,
## outil de vidéo), il attendait le verrou SANS vider la file : interblocage, jeu figé (avant le correctif : figé à chaque fois, cache
## chaud ou --sans-cache-persos). Le test entre dans la crypte et, PENDANT le fil des ennemis, fait bâtir sur le fil principal des
## corps qui n'ont pas de gabarit ; tout doit finir (« Ennemis : … modèles préparés »), l'entrée se faire, la grotte (2e fil) se bâtir.
##   godot --path . --script res://outils/test_gel_cache_persos.gd -- --nouvelle [--remplir] [--sans-cache-persos]
## FENÊTRE obligatoire (le fil ne tourne pas en --headless, où le serveur de rendu factice répond tout de suite) : via
## /tmp/godot_slot.sh (fenêtre hors écran), voir outils/tous_les_tests.sh (AVEC_FENETRE=1).
## `--remplir` : à la fin, les corps des ennemis de la crypte et de la grotte sont rebâtis sur le fil principal et écrits dans le cache
## des corps (au lancement suivant, le fil de préparation les RELIT du disque : cas du tournage de la vidéo, cache chaud).
## Sortie : OK / ECHEC + durées, « ECHECS : n » ; code 0 si tout passe. Figé = tué par le délai de godot_slot (rc 124).
const SCENE := "res://scenes/foret_test.tscn"
const DELAI_S := 120.0
const CORPS_CONCURRENTS := 6

var m: Node
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre_vrai(f: Callable, max_s: float) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < max_s * 1000.0:
		if f.call():
			return true
		await process_frame
	return f.call()

func _abandon(msg: String) -> void:
	_verif(false, msg)
	print("ECHECS : %d" % _echecs)
	OS.kill(OS.get_process_id())

func _tester() -> void:
	if DisplayServer.get_name() == "headless":
		print("ECHEC test à fenêtre : lancer sans --headless (via /tmp/godot_slot.sh, fenêtre hors écran)")
		quit(1)
		return
	var t0 := Time.get_ticks_msec()
	print("cache des corps : %s" % ("actif" if CachePersos.actif else "désactivé"))
	m = (load(SCENE) as PackedScene).instantiate()
	root.add_child(m)
	current_scene = m
	_verif(await _attendre_vrai(func() -> bool: return m.pret and m.village != null and m.village.prets, DELAI_S), "monde prêt en %d ms" % (Time.get_ticks_msec() - t0))
	var t: Node3D = m.tertre
	var t1 := Time.get_ticks_msec()
	t._passer(true)
	# fil des ennemis de la crypte lancé (à l'intégration du donjon) : corps sans gabarit demandés sur le fil principal pendant qu'il tourne
	await _attendre_vrai(func() -> bool: return t._tache_en >= 0 or t._donjon_pret(), DELAI_S)
	var pendant := 0
	for k in CORPS_CONCURRENTS:
		var en_cours: bool = t._tache_en >= 0 and not WorkerThreadPool.is_task_completed(t._tache_en)
		var tk := Time.get_ticks_msec()
		var n: Node3D
		if k == CORPS_CONCURRENTS - 1:
			n = EnnemisNordiques.squelette({"ident": "test_gel_sq", "variante": "hache"})       # verrou de SqueletteGuerrier
		else:
			n = EnnemisNordiques.creer(EnnemisNordiques.spec_depuis_options(["guerrier", "sbire"][k % 2], {"ident": "test_gel_%d" % k}))
		print("corps %d bâti sur le fil principal en %d ms (fil des ennemis en cours : %s)" % [k, Time.get_ticks_msec() - tk, en_cours])
		if en_cours:
			pendant += 1
		if n != null:
			n.free()
		await process_frame
	_verif(pendant > 0, "%d corps demandés pendant le fil des ennemis (sinon le test ne prouve rien)" % pendant)
	var ok: bool = await _attendre_vrai(func() -> bool: return t.dedans and not t._entree_en_attente, DELAI_S)
	if not ok:
		_abandon("entrée dans la crypte (fil des ennemis figé ?)")
		return
	_verif(true, "entrée dans la crypte en %d ms (fil des ennemis fini : %s)" % [Time.get_ticks_msec() - t1, t._tache_en < 0])
	_verif(EnnemisNordiques.nb_gabarits() > 0 or EnnemisNordiques.anciens(), "%d gabarits d'ennemis prêts" % EnnemisNordiques.nb_gabarits())
	# la grotte (et son propre fil d'ennemis : bandits, archères) se bâtit ensuite, en tâche de fond
	var ga: Node = m.grotte_acces
	var ok_g: bool = await _attendre_vrai(func() -> bool: return ga != null and ga.jeu != null and ga.jeu._ennemis_prets(), DELAI_S)
	if not ok_g:
		_abandon("grotte bâtie et fil de ses ennemis fini (figé ?)")
		return
	_verif(true, "grotte bâtie et fil de ses ennemis fini en %d ms" % (Time.get_ticks_msec() - t1))
	print("cache des corps : %d lus, total %d ms" % [CachePersos.lus, Time.get_ticks_msec() - t0])
	if OS.get_cmdline_user_args().has("--remplir"):
		# corps des ennemis rebâtis sur le FIL PRINCIPAL (seul fil qui écrit le cache) : au lancement suivant, le fil les relit du disque
		EnnemisNordiques.vider()
		var specs: Array = t.specs_ennemis()
		specs.append_array(ga.jeu.specs_ennemis())
		EnnemisNordiques.prechauffer(specs)
		CachePersos.ecrire_en_attente()
		print("remplissage du cache : %d corps écrits" % CachePersos.ecrits)
	m.queue_free()
	await process_frame
	await process_frame
	print("ECHECS : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)
