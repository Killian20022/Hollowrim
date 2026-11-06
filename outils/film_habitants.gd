extends SceneTree
## Court film des habitants du village qui MARCHENT sur la place (retours6/pnj, 2026-11-06), pour Movie Maker :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_habitants.gd -- --nouvelle --paisible --sans-mains
## (fenêtre hors écran via godot_slot.sh). Cinq habitants quittent leur poste pour traverser la place ; deux plans de caméra,
## chacun annoncé par `SEGMENT <nom> <première image> <dernière image>` pour la découpe (ffmpeg).

const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var j: CharacterBody3D

func _init() -> void:
	_go.call_deferred()

func _attendre(s: float) -> void:
	for i in int(s * 30.0):     # --fixed-fps 30 : le temps du jeu avance d'1/30 s par image
		await process_frame
		if paused:
			paused = false

func _poser(x: float, z: float, lacet: float, tangage: float) -> void:
	j.global_position = Vector3(x, m.hauteur(x, z) + 0.1, z)
	j.rotation.y = deg_to_rad(lacet)
	j.tete.rotation.x = deg_to_rad(tangage)
	j.velocity = Vector3.ZERO

func _heure(h: float) -> void:
	m.cycle.heure = h
	m.cycle._process(0.0)

func _plan(nom: String, x: float, z: float, lacet: float, tangage: float, duree: float) -> void:
	_poser(x, z, lacet, tangage)
	await _attendre(0.5)
	var d := Engine.get_frames_drawn()
	await _attendre(duree)
	print("SEGMENT %s %d %d" % [nom, d, Engine.get_frames_drawn()])

## Fait marcher l'habitant `id` vers (x, z) : la mécanique de sa promenade (état ALLER, puis pause et retour au poste).
func _marcher(id: String, x: float, z: float) -> void:
	for v in get_nodes_in_group("villageois"):
		if v.get("donnees") is Dictionary and v.donnees.get("id") == id:
			v.points = [v.global_position, Vector3(x, 0.0, z)]
			v._cible = 1
			v.etat = v.ALLER
			v._t = 0.0
			v._duree_pause = 6.0

## Plus aucune interpellation (bandeau de réplique) pendant le film.
func _taire() -> void:
	for v in get_nodes_in_group("villageois"):
		if v.get("_delai_interpelle") != null:
			v._delai_interpelle = 99999.0

func _go() -> void:
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
		if m == null:
			m = sc if sc.get("pret") != null else null
	j = m.joueur
	j.mort = false
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	await _attendre(2.0)
	_heure(11.0)
	_poser(32.5, 44.5, -54.0, -4.0)
	_taire()
	await _attendre(0.5)
	_marcher("hab_paysanne_2", 37.0, 43.0)
	_marcher("hab_chasseresse_2", 35.5, 41.0)
	_marcher("hab_paysan_3", 38.5, 47.0)
	_marcher("hab_paysan_1", 36.0, 38.5)
	await _plan("marche_a", 32.5, 44.5, -54.0, -4.0, 7.0)
	await _plan("marche_b", 41.0, 47.5, 28.0, -4.0, 7.0)
	print("FILM fini")
	quit(0)
