extends "res://outils/video_impacts_lances.gd"
## FILM 1re PERSONNE de l'ARC v3 (tenue dégagée, zoom du bandage, décoche dynamique, traînée). Fenêtre hors écran (godot_slot.sh, verrou rendu) :
##   godot --path . --fixed-fps 60 --resolution 1280x720 --disable-vsync --script res://outils/film_arc_v3.gd -- --decor=jour|nuit|crypte
##        --plan=normal|ralenti --sortie=<dossier>   (images f_00000.jpg… à 30 i/s : une image sur deux)
## normal  : arc au repos, bandage (zoom), tenue, lâcher, flèche suivie en caméra d'observation au ralenti jusqu'à l'impact, encoche suivante.
## ralenti : le même lâcher vu par le joueur, au ralenti (x0,2) : corde qui claque, recul, traînée.
## Aides de lecture du film seulement : aucune (pas de réticule ajouté, HUD masqué).

var n := 0
var _imp := false
var j: CharacterBody3D
var arc: ArcJoueur
var _suivi: Projectile
var _vol := false

func _go() -> void:
	sortie = _arg("sortie", "user://film_arc_v3")
	var decor := _arg("decor", "jour")
	var plan := _arg("plan", "normal")
	DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	if decor != "jour":
		s.options["nuit"] = ""
	root.add_child(s)
	current_scene = s
	for i in 20:
		await process_frame
	s.mur.position = Vector3(30, 1.3, 30)
	s.hud.visible = false
	j = s.joueur
	var ips := root.get_node_or_null("CompteurIps")   # le compteur d'IPS (option du joueur) n'a rien à faire dans le film : coupé pour de bon
	if ips != null:
		ips.set_process(false)
		ips.process_mode = Node.PROCESS_MODE_DISABLED
		ips.set("visible", false)
	var cible := Vector3(0.4, 1.25, -12.0)
	if decor == "crypte":
		s.placer_joueur(Vector3(0, 0, 3.5), 0.0)
		_salle()
		_tournage()
		j.visible = true   # _salle() cache le joueur : ici la 1re personne (bras, arc) doit se voir
		s.mannequin.position = Vector3(0.5, 0, -5.8)
		cible = Vector3(0.5, 1.3, -5.8)
	else:
		s.placer_joueur(Vector3(0, 0, 3.0), 0.0)
		s.mannequin.position = Vector3(0.4, 0, -12.0)
	j.inventaire.ajouter("arc_chasseur", 1)
	j.inventaire.ajouter("fleche", 14)
	arc = j.arc
	arc.souris_reelle = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cam = Camera3D.new()
	cam.fov = 60.0
	s.add_child(cam)
	for i in 40:
		await process_frame
	arc.equiper()
	await _viser(cible)
	arc.tir.connect(func(info: Dictionary) -> void: _suivi = info["projectile"])
	if plan == "normal":
		await _img(60)                 # repos, flèche encochée
		arc.appuyer()
		await _img(120)                # bandage + zoom
		await _img(20)                 # tenue
		arc.relacher()
		await _img(14)                 # lâcher en temps réel
		_temps(0.2)
		await _poursuite()
		_temps(1.0)
		Engine.time_scale = 1.0
		Engine.physics_ticks_per_second = 60
		j.camera.current = true
		await _img(90)                 # encoche suivante
	else:
		await _img(30)
		arc.appuyer()
		await _img(115)
		_temps(0.2)
		Engine.physics_ticks_per_second = 240
		arc.relacher()
		await _img(150)
		Engine.time_scale = 1.0
		Engine.physics_ticks_per_second = 60
		await _img(60)
	print("FILM %d images" % n)
	quit(0)

func _viser(c: Vector3) -> void:
	for it in 6:
		var cv: Camera3D = arc._camera_visee()
		var d: Vector3 = c - cv.global_position
		var fwd := -cv.global_transform.basis.z
		j.rotation.y += wrapf(atan2(-d.x, -d.z) - atan2(-fwd.x, -fwd.z), -PI, PI)
		j.tete.rotation.x = clampf(j.tete.rotation.x + (atan2(d.y, Vector2(d.x, d.z).length()) - asin(clampf(fwd.y, -1.0, 1.0))), -1.2, 1.2)
		await process_frame
		await process_frame

## Caméra d'observation derrière la flèche, jusqu'à l'impact (ou 1,6 s de jeu), puis 0,6 s sur l'impact.
func _poursuite() -> void:
	var p := _suivi
	if p == null:
		return
	var pos: Vector3 = j.camera.global_position
	cam.current = true
	var fin := 0
	var k := 0
	while k < 600 and fin < 40:
		if is_instance_valid(p) and not p.plantee:
			var d: Vector3 = p.vitesse.normalized() if p.vitesse.length() > 1.0 else -p.global_transform.basis.z
			var but := p.global_position - d * 2.2 + Vector3(0.45, 0.5, 0.0)
			pos = pos.lerp(but, 0.35)
			cam.look_at_from_position(pos, p.global_position + d * 4.0, Vector3.UP)
		elif is_instance_valid(p):
			fin += 1
			cam.look_at_from_position(pos.lerp(p.global_position + Vector3(1.4, 0.6, 2.2), minf(fin / 25.0, 1.0)), p.global_position, Vector3.UP)
		else:
			fin = 40
		await _img(1)
		k += 1

func _img(k: int) -> void:
	for i in k:
		await process_frame
		_imp = not _imp
		if _imp:
			continue
		await RenderingServer.frame_post_draw
		var im := root.get_viewport().get_texture().get_image()
		im.save_jpg(sortie.path_join("f_%05d.jpg" % n), 0.93)
		n += 1
		if n % 30 == 0:
			print("IPS_FILM %d (jeu, hors capture)" % Engine.get_frames_per_second())
