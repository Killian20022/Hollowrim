class_name Sons
## Joue des bruitages de assets/sons (le nom sans extension, tiré au hasard dans la liste).

static var _cache := {}

static func flux(nom: String) -> AudioStream:
	if not _cache.has(nom):
		var trouve: AudioStream = null
		for ext in [".wav", ".ogg"]:   # .wav d'abord : lecture ~100x moins chère (une lecture Ogg Vorbis coûte ~2 ms de fil principal à son départ)
			var chemin: String = "res://assets/sons/" + nom + ext
			if ResourceLoader.exists(chemin):
				trouve = load(chemin)
				break
		if trouve == null:
			push_warning("Son introuvable : " + nom)
		_cache[nom] = trouve
	return _cache[nom]

## Son « dans la tête » du joueur (non spatialisé).
static func jouer(parent: Node, noms: Array, volume_db := 0.0, variation := 0.08) -> void:
	var s := flux(noms.pick_random())
	if s == null or not parent.is_inside_tree():
		return
	var a := AudioStreamPlayer.new()
	a.stream = s
	a.volume_db = volume_db
	a.pitch_scale = randf_range(1.0 - variation, 1.0 + variation)
	parent.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

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
