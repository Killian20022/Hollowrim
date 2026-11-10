class_name FilVerrou
extends RefCounted
## Verrou commun des constructions en fil d'exécution qui fabriquent des maillages (grotte, entrée de la grotte, donjon de la crypte,
## intérieurs du village). Avec un vrai rendu, RenderingServer accepte ces créations en parallèle ; le serveur « dummy » du mode
## --headless (tests) ne le supporte pas : deux fils qui créent des ArrayMesh en même temps corrompent le stockage des maillages
## (« Attempting to initialize the wrong RID », « Parameter "m" is null », plantage rc=5). On sérialise donc ces fils UNIQUEMENT en
## headless : aucun changement du temps de chargement en jeu.

##
## Ce verrou ne suffisait pas : il exclut les fils ENTRE EUX, pas le fil principal, qui crée lui aussi des maillages pendant qu'un fil
## tourne (lit posé par Sommeil.scanner toutes les secondes, torche de nuit d'un garde, cadavres…). En Godot 4.7, le stockage factice
## (servers/rendering/dummy/storage/mesh_storage.h) déclare `RID_Owner<DummyMesh> mesh_owner` SANS sûreté de fil (les vrais rendus
## RD et GLES3 déclarent `RID_Owner<Mesh, true>`) ; et l'allocation d'un RID (`mesh_allocate`, faite sur le fil appelant) court contre
## le fil principal qui en alloue, initialise ou libère d'autres → même case allouée deux fois : « Attempting to initialize the wrong
## RID » puis « Parameter "m" is null » et arrêt net du test (correctifs/rid_lit, 1 lancement sur 3 de test_crime_sommeil). Le
## fil principal ne peut pas « attendre sans vider » (les appels à réponse d'un fil passent par la file qu'il vide) : en --headless,
## les constructions qui fabriquent des maillages passent donc par `lancer`, qui les exécute sur le fil appelant. En jeu (vrai rendu,
## stockage sûr), rien ne change : vraie tâche de fond.

static var _m := Mutex.new()
static var _actif := DisplayServer.get_name() == "headless"
static var _en_ligne := 0       # > 0 : une construction « de fil » s'exécute en ce moment sur le fil principal (--headless, voir lancer)

static func prendre() -> void:
	if _actif:
		_m.lock()

static func rendre() -> void:
	if _actif:
		_m.unlock()

## Vrai si on est sur le fil principal (celui qui vide la file de commandes du serveur de rendu et dessine les images).
static func fil_principal() -> bool:
	return OS.get_thread_caller_id() == OS.get_main_thread_id()

## Lance une construction qui fabrique des maillages (ArrayMesh, PrimitiveMesh, matériaux…) : tâche du WorkerThreadPool en jeu ;
## en --headless (serveur de rendu factice, stockage des maillages non sûr entre fils : voir en tête), exécutée TOUT DE SUITE sur le
## fil appelant. Renvoie toujours un vrai identifiant de tâche (en --headless, une tâche vide déjà lancée après coup), si bien que
## is_task_completed / attendre / wait_for_task_completion des appelants marchent sans changement.
static func lancer(travail: Callable, nom := "") -> int:
	if not _actif:
		return WorkerThreadPool.add_task(travail, false, nom)
	_en_ligne += 1
	travail.call()
	_en_ligne -= 1
	return WorkerThreadPool.add_task(func() -> void: pass, false, nom)

## Vrai pendant une construction lancée par `lancer` : dans un fil de travail, ou exécutée en ligne sur le fil principal (--headless).
## Pour les données propres à la construction (lots et caches du village) : c'est le travail qui compte, pas le fil qui l'exécute.
static func en_construction() -> bool:
	return _en_ligne > 0 or not fil_principal()

## Attente d'une tâche du WorkerThreadPool SANS interblocage (reprend l'ancien Tertre._attendre_fil, commit c5cc4e3). Un fil de
## construction fait des appels au serveur de rendu qui attendent une réponse (surface_get_arrays, get_image, get_aabb…) ; avec une
## fenêtre, ces appels passent par la file de commandes que SEUL le fil principal vide. Un wait_for_task_completion nu sur le fil
## principal l'empêchait de la vider : interblocage. Sur le fil principal avec fenêtre, on vide donc la file en attendant (force_sync) ;
## dans un fil de travail, attente nue. Même en --headless : un fil de construction (donjon de la crypte, extérieur de la grotte) peut
## attendre la file de commandes du serveur de rendu (sorties de partie et de test pendant le chargement, ex. test_filet : « TOUT OK »
## puis quit() figé pour toujours dans GrotteAcces._exit_tree) ; une attente nue du fil principal l'empêchait de la vider.
static func attendre(tache: int) -> void:
	if tache < 0:
		return
	if fil_principal():
		while not WorkerThreadPool.is_task_completed(tache):
			RenderingServer.force_sync()
			OS.delay_usec(500)
	WorkerThreadPool.wait_for_task_completion(tache)

## Prise d'un verrou partagé avec des fils de construction SANS interblocage (correctifs/gel_cache_persos, 2026-10-28). Un fil qui bâtit
## un corps garde son verrou (EnnemisNordiques._bm, SqueletteGuerrier._mx) pendant des appels au serveur de rendu qui attendent une
## réponse (surface_get_arrays…) ; avec une fenêtre, SEUL le fil principal vide la file de ces appels. Un lock() nu du fil principal
## sur ce verrou (corps demandé pendant que le fil de préparation des ennemis tourne : draugr du cercle, gardiens, outils) le figeait
## donc pour toujours : le fil attendait le fil principal, qui attendait le verrou (chargement figé après « Donjon : intégré »).
## Sur le fil principal avec fenêtre, on vide la file en attendant (comme attendre) ; ailleurs (fils, --headless), lock() nu.
static func verrouiller(m: Mutex) -> void:
	if fil_principal() and DisplayServer.get_name() != "headless":
		while not m.try_lock():
			RenderingServer.force_sync()
			OS.delay_usec(200)
		return
	m.lock()

## Appel réservé au fil principal : tout de suite si on y est, sinon différé (call_deferred, ignoré si l'objet a été libéré entre-temps).
## Sert aux affectations qui compilent un shader de matériau intégré (StandardMaterial3D / ParticleProcessMaterial neufs : get_rid →
## _update_shader → compilation par tâches de groupe du WorkerThreadPool). Faite depuis un fil de construction pendant le chargement
## (réserve de fils pleine : donjon, peintures de textures, préparation des ennemis), cette compilation interbloquait le moteur : fil de
## la grotte figé dans `draw_pass_1 = …` (neige soufflée), fil principal figé avant le dessin de l'image, jeu gelé (bug du 2026-10-23,
## sauvegarde près de l'entrée de la grotte). Sur le fil principal, le matériau se compile dans BaseMaterial3D.flush_changes, sans risque.
static func sur_fil_principal(o: Object, methode: StringName, args: Array = []) -> void:
	if fil_principal():
		o.callv(methode, args)
	else:
		o.callv("call_deferred", [methode] + args)

