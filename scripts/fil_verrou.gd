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
