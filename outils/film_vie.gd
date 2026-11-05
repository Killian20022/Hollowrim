extends SceneTree
## Film (≤ 15 s) du lot vie_pnj : un loup entre dans la place du village, les civils fuient vers les maisons, les gardes se mettent en alerte.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_vie.gd -- --nouvelle --sans-mains [--sans-vie]
## (fenêtre hors écran via godot_slot.sh). Le loup est mené à la main (course sur une droite, clip Run) : le plan est reproductible.
## `--sans-vie` : le village d'avant (les civils ne réagissent pas).
const SCENE := "res://scenes/foret_test.tscn"
const CAM := Vector2(44.0, 50.0)
const VISE := Vector2(39.5, 38.0)
const DEPART := Vector2(41.0, 22.0)        # le loup arrive par la porte nord de la place
const ARRIVEE := Vector2(40.0, 42.0)
var m: Node3D
var j: CharacterBody3D

func _init() -> void:
	_go.call_deferred()

func _cam(pos: Vector3, cible: Vector3) -> void:
	j.global_position = pos
	j.velocity = Vector3.ZERO
	var d := cible - (pos + Vector3(0, j.tete.position.y, 0))
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _go() -> void:
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
	j = m.joueur
	j.mort = false
	j.vie = 100000.0
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	for i in 90:
		await process_frame
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	m.cycle.heure = 12.0
	m.cycle._process(0.0)
	j.tete.position.y = 3.4
	j.camera.fov = 62.0
	var cam := Vector3(CAM.x, m.hauteur(CAM.x, CAM.y) + 0.1, CAM.y)
	var vise := Vector3(VISE.x, m.hauteur(VISE.x, VISE.y) + 1.0, VISE.y)
	_cam(cam, vise)
	for i in 120:                       # le village vit : tick de Vie, civils au poste
		await process_frame
	var loup: CharacterBody3D = m.creer_ennemi(load("res://scripts/bete_quat.gd"), Vector3(DEPART.x, m.hauteur(DEPART.x, DEPART.y), DEPART.y), 0.0, {"espece": "loup", "ident": "loup_film"})
	loup.set_physics_process(false)
	loup.set_process(false)
	loup.visible = true
	loup._jouer("Run" if loup.anim.has_animation("Run") else "Walk", 0.0)
	var d0 := Engine.get_frames_drawn()
	var total := int(13.5 * 30.0)
	var depart := Vector3(DEPART.x, 0, DEPART.y)
	var arrivee := Vector3(ARRIVEE.x, 0, ARRIVEE.y)
	var dist := depart.distance_to(arrivee)
	var vitesse := 5.5
	var t_arrivee := dist / vitesse
	print("FILM début image ", d0)
	for i in total:
		var t := float(i) / 30.0
		if t > 1.0 and t < 1.0 + t_arrivee:
			var k := (t - 1.0) / t_arrivee
			var p := depart.lerp(arrivee, k)
			loup.global_position = Vector3(p.x, m.hauteur(p.x, p.z) + 0.02, p.z)
			var dir := (arrivee - depart).normalized()
			loup.rotation.y = atan2(dir.x, dir.z)
			loup.anim.speed_scale = 1.4
		elif t >= 1.0 + t_arrivee and loup.visible and t < 1.0 + t_arrivee + 1.0:
			loup._jouer("Attack" if loup.anim.has_animation("Attack") else "Idle", 0.2)
		elif t >= 1.0 + t_arrivee + 1.0:
			var k2 := minf((t - 2.0 - t_arrivee) / 2.0, 1.0)      # il repart
			var p2 := arrivee.lerp(depart, k2)
			loup.global_position = Vector3(p2.x, m.hauteur(p2.x, p2.z) + 0.02, p2.z)
			var dir2 := (depart - arrivee).normalized()
			loup.rotation.y = atan2(dir2.x, dir2.z)
			loup._jouer("Run" if loup.anim.has_animation("Run") else "Walk", 0.2)
		_cam(cam, vise)
		await process_frame
	print("FILM fini images=%d" % Engine.get_frames_drawn())
	quit(0)
