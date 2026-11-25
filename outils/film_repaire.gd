extends SceneTree
## FILM 1re personne de la traversée du repaire (retours exe 4, chantier 5) : entrée -> mine (raccourci) -> camp -> levier -> porte qui
## s'ouvre -> salle aux cristaux (~45 s à 30 i/s). Le joueur est posé image par image sur le trajet (pas de physique) ; la porte est
## ouverte par le VRAI levier (interactif). Fenêtre hors écran (godot_slot.sh, verrou rendu) :
##   godot --path . --fixed-fps 30 --resolution 1280x720 --disable-vsync --script res://outils/film_repaire.gd -- --nouvelle --paisible --grotte=3,0,0,0 --sortie=<dossier>
## Écrit <dossier>/f_00000.jpg…  (puis : ffmpeg -framerate 30 -i f_%05d.jpg -c:v libx264 -pix_fmt yuv420p film.mp4)
const SCENE := preload("res://scenes/foret_test.tscn")

var s: Node3D
var j: CharacterBody3D
var g: Grotte
var jeu: GrotteJeu
var sortie := ""
var n := 0

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _image() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg("%s/f_%05d.jpg" % [sortie, n], 0.9)
	n += 1

## Pose le joueur au point (s global, lat), cap = celui de la galerie + dyaw (°), tangage (°).
func _pose(sg: float, lat: float, dyaw := 0.0, pitch := -3.0) -> void:
	j.velocity = Vector3.ZERO
	j.global_position = g.monde_sol(sg, lat) + Vector3(0, 0.05, 0)
	j.rotation.y = g.cap_monde(sg) + deg_to_rad(dyaw)
	j.tete.rotation.x = deg_to_rad(pitch)

## Marche de s0 à s1 en `t` secondes (lat constante, léger balayage du regard).
func _marche(s0: float, s1: float, lat: float, t: float, balayage := 10.0, pitch := -3.0) -> void:
	var nb := roundi(t * 30.0)
	for i in nb:
		var u := float(i) / float(nb)
		_pose(lerpf(s0, s1, u), lat, balayage * sin(u * TAU * 1.3), pitch)
		await _image()

func _vers(cible: Vector3) -> void:
	var d := cible - (j.global_position + Vector3(0, 1.6, 0))
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _go() -> void:
	sortie = _arg("sortie", "user://film_repaire")
	DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	root.add_child(s)
	current_scene = s
	for i in 90:
		await process_frame
	j = s.joueur
	g = s.grotte
	jeu = s.grotte_acces.jeu
	s.hud.visible = false
	var ips := root.get_node_or_null("CompteurIps")
	if ips != null:
		ips.set_process(false)
		ips.set("visible", false)
	j.set_physics_process(false)
	for i in 30:
		await process_frame
	var meta: Dictionary = g.get_meta("porte_goulot")
	var cm: float = (float(meta["lat_g"]) + float(meta["lat_d"])) * 0.5
	# 1. l'entrée
	await _marche(2.0, 30.0, 0.0, 8.0, 12.0)
	# 2. la mine (raccourci), puis le camp
	await _marche(158.0, 172.0, 0.0, 4.0, 14.0)
	await _marche(300.5, 316.0, 0.0, 9.0, 22.0, -4.0)
	# 3. le levier : on s'approche du goulet, côté camp, et on le regarde
	var lev: Vector3 = g.to_global(meta["levier"])
	for i in 120:
		var u := float(i) / 120.0
		_pose(lerpf(400.3, 402.2, u), lerpf(cm, cm + 0.3, u))
		_vers(lev + Vector3(0, -0.1, 0))
		await _image()
	for i in 36:
		await _image()
	(jeu.interactifs["levier_goulot"] as Node3D).parler()
	for i in 120:         # le manche bascule, la porte s'ouvre (2,45 s)
		_pose(402.2, cm + 0.3)
		_vers(lev if i < 20 else g.to_global(meta["bas"]) + Vector3(0, 1.3, 0))
		await _image()
	# 4. on passe la porte et on découvre la salle aux cristaux
	await _marche(402.2, 412.0, cm, 4.0, 4.0, -2.0)
	await _marche(412.0, 424.0, 0.0, 6.0, 25.0, -4.0)
	for i in 60:
		_pose(424.0, 0.0, 40.0 * sin(float(i) / 60.0 * PI), -3.0)
		await _image()
	print("FILM ", n, " images")
	quit(0)
