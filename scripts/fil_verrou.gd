class_name FilVerrou
extends RefCounted
## Verrou commun des constructions en fil d'exécution qui fabriquent des maillages (grotte, entrée de la grotte, donjon de la crypte,
## intérieurs du village). Avec un vrai rendu, RenderingServer accepte ces créations en parallèle ; le serveur « dummy » du mode
## --headless (tests) ne le supporte pas : deux fils qui créent des ArrayMesh en même temps corrompent le stockage des maillages
## (« Attempting to initialize the wrong RID », « Parameter "m" is null », plantage rc=5). On sérialise donc ces fils UNIQUEMENT en
## headless : aucun changement du temps de chargement en jeu.

static var _m := Mutex.new()
static var _actif := DisplayServer.get_name() == "headless"

static func prendre() -> void:
	if _actif:
		_m.lock()

static func rendre() -> void:
	if _actif:
		_m.unlock()

## Vrai si on est sur le fil principal (celui qui vide la file de commandes du serveur de rendu et dessine les images).
static func fil_principal() -> bool:
	return OS.get_thread_caller_id() == OS.get_main_thread_id()

## Attente d'une tâche du WorkerThreadPool SANS interblocage (reprend l'ancien Tertre._attendre_fil, commit c5cc4e3). Un fil de
## construction fait des appels au serveur de rendu qui attendent une réponse (surface_get_arrays, get_image, get_aabb…) ; avec une
## fenêtre, ces appels passent par la file de commandes que SEUL le fil principal vide. Un wait_for_task_completion nu sur le fil
## principal l'empêchait de la vider : interblocage. Sur le fil principal avec fenêtre, on vide donc la file en attendant (force_sync) ;
## dans un fil de travail (ou en --headless, serveur factice synchrone), attente nue.
static func attendre(tache: int) -> void:
	if tache < 0:
		return
	if fil_principal() and DisplayServer.get_name() != "headless":
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

