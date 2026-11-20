class_name Sons
## Joue des bruitages de assets/sons (le nom sans extension, tiré au hasard dans la liste).

static var _cache := {}
static var _precharge := false

## Opti saccades (2026-11-20) : tous les bruitages de assets/sons (pas, portes, pièces, interface, bêtes) lus en tâche de fond au
## chargement du monde ; le 1er son de chaque sorte ne lit plus son fichier sur le fil principal au moment où il sonne.
## `--sans-opti-sons` : ancien comportement (load() au 1er son). Rien en --headless (voir Prechargement : fils de chargement + serveur factice).
static func precharger() -> void:
	if _precharge or OS.get_cmdline_user_args().has("--sans-opti-sons") or DisplayServer.get_name() == "headless":
		return
	_precharge = true
	var d := DirAccess.open("res://assets/sons")
	if d == null:
		return
	var vus := {}
	for f in d.get_files():
		var n := f.trim_suffix(".remap").trim_suffix(".import")
		var nom := n.get_basename()
		if vus.has(nom) or not n.get_extension() in ["wav", "ogg"]:
			continue
		var ch := _chemin(nom)
		if ch != "":
			vus[nom] = true
			ResourceLoader.load_threaded_request(ch, "AudioStream")

static func _chemin(nom: String) -> String:
	for ext in [".wav", ".ogg"]:   # .wav d'abord : lecture ~100x moins chère (une lecture Ogg Vorbis coûte ~2 ms de fil principal à son départ)
		var chemin: String = "res://assets/sons/" + nom + ext
		if ResourceLoader.exists(chemin):
			return chemin
	return ""

static func flux(nom: String) -> AudioStream:
	if not _cache.has(nom):
		var trouve: AudioStream = null
		var chemin := _chemin(nom)
		if chemin != "":
			if _precharge and ResourceLoader.load_threaded_get_status(chemin) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				trouve = ResourceLoader.load_threaded_get(chemin) as AudioStream   # prêt (ou attend la fin de SA lecture : jamais plus lent)
			else:
				trouve = load(chemin)
		if trouve == null:
			push_warning("Son introuvable : " + nom)
		_cache[nom] = trouve
	return _cache[nom]

## Son « dans la tête » du joueur (non spatialisé). `bus` vide = routage automatique (Lancement) ; `hauteur` = hauteur de base.
static func jouer(parent: Node, noms: Array, volume_db := 0.0, variation := 0.08, bus := &"", hauteur := 1.0) -> AudioStreamPlayer:
	var s := flux(noms.pick_random())
	if s == null or not parent.is_inside_tree():
		return null
	var a := AudioStreamPlayer.new()
	a.stream = s
	a.volume_db = volume_db
	a.pitch_scale = hauteur * randf_range(1.0 - variation, 1.0 + variation)
	if bus != &"" and AudioServer.get_bus_index(bus) != -1:
		a.bus = bus
	parent.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
	return a

## Son d'interface (montée de niveau, quête, objet, potion, menu) : bus « Interface », jamais de reverb, joué même en pause.
static func interface(parent: Node, noms: Array, volume_db := 0.0) -> void:
	var a := jouer(parent, noms, volume_db, 0.0, Mixage.INTERFACE)
	if a != null:
		a.process_mode = Node.PROCESS_MODE_ALWAYS

## Son placé dans le monde.
static func jouer_a(parent: Node, noms: Array, position: Vector3, volume_db := 0.0, variation := 0.08) -> void:
	var s := flux(noms.pick_random())
	if s == null or not parent.is_inside_tree():
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = s
	a.volume_db = volume_db
	a.unit_size = 5.0
	a.max_distance = 60.0
	a.pitch_scale = randf_range(1.0 - variation, 1.0 + variation)
	var scene := parent.get_tree().current_scene
	(scene if scene else parent.get_tree().root).add_child(a)
	a.global_position = position
	a.play()
	a.finished.connect(a.queue_free)

static func vider() -> void:
	_cache.clear()
	_precharge = false   # monde suivant : relancé par Monde (les demandes consommées ne servent plus)
