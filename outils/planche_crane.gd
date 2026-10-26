extends SceneTree
## Planche du CRÂNE des squelettes (E/crane_squelette) DANS LA CRYPTE, à la torche du joueur (shaders et éclairage du jeu).
## Gros plans (face, trois quarts, profil, regard du joueur) du sbire à crâne nu, cadrés sur l'os Head posé (caméra dédiée,
## le joueur se tient dessous : sa torche éclaire), puis le rang guerrier / archer / sbire à 3, 5 et 8 m (caméra du joueur).
##   godot --path . --script res://outils/planche_crane.gd -- --nouvelle --paisible --sortie=C:/.../dossier [--anim=Sword_Idle:0.3]
## Écrit <sortie>/<vue>.png (agrandi x2) et planche.png (2 colonnes). Mêmes poses à chaque lancement (avant / après).
const ORIGINE := Vector3(0.0, 0.0, -26.5)   # repère crypte : salle des piliers, devant le puits de lumière central
var m: Node3D

func _init() -> void:
	m = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _attendre(n: int) -> void:
	for i in n:
		await process_frame

func _lancer() -> void:
	await _attendre(30)
	var t = m.tertre
	t._basculer(true)
	await create_timer(1.0).timeout
	m.post.set_shader_parameter("fondu", 0.0)
	if m.hud:
		m.hud.visible = false
	if m.get("aide") is CanvasItem:
		m.aide.visible = false
	for g: GeometryInstance3D in m.joueur.mains.find_children("*", "GeometryInstance3D", true, false):
		g.visible = false
	var c: Node3D = t.crypte
	var types := ["squelette", "squelette_archer", "squelette:hache"]
	var an := _arg("anim", "Sword_Idle:0.3").split(":")
	var ennemis: Array = []
	var ecart := 1.15
	for i in types.size():
		var ty: PackedStringArray = types[i].split(":")
		var x := (i - (types.size() - 1) * 0.5) * ecart
		var opts := {"ident": "planche_crane_%d" % i, "debout": true}
		if ty.size() > 1:
			opts["variante"] = ty[1]
		var d: CharacterBody3D = m.creer_draugr(ty[0], c.to_global(ORIGINE + Vector3(x, 0.05, 0)), c.global_rotation.y, true, opts)
		ennemis.append(d)
	await _attendre(10)
	for d: CharacterBody3D in ennemis:
		d.anim.speed_scale = 1.0
		d.anim.play(an[0])
		d.anim.seek(d.anim.current_animation_length * float(an[1]), true)
		d.anim.pause()
		d.set_physics_process(false)
		d.set_process(false)
		d.collision_layer = 0
		d.collision_mask = 0
		d.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var j = m.joueur
	j.mains.process_mode = Node.PROCESS_MODE_DISABLED
	for f in j.mains.flammes:
		f.visible = false
	for n: Node3D in j.mains._visuels_torche:
		n.visible = false
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/planche_crane"))
	DirAccess.make_dir_recursive_absolute(sortie)
	var fov0: float = j.camera.fov
	# crâne : centre et repère du visage (os Head posé) de chaque ennemi, pour cadrer le visage quelle que soit l'inclinaison de la tête
	var reperes := []
	for e: Node3D in ennemis:
		var sq: Skeleton3D = e.modele.find_child("Skeleton3D", true, false)
		var ih := sq.find_bone("Head")
		var gp: Transform3D = sq.global_transform * sq.get_bone_global_pose(ih)
		var gr: Transform3D = sq.global_transform * sq.get_bone_global_rest(ih)
		var tourne: Basis = gp.basis.orthonormalized() * gr.basis.orthonormalized().inverse()
		var av: Vector3 = (tourne * (e.modele as Node3D).global_basis.z).normalized()
		var ht: Vector3 = (tourne * Vector3.UP).normalized()
		reperes.append([gp.origin + ht * 0.075 + av * 0.01, av, ht])
	var cam := Camera3D.new()
	cam.near = 0.02
	root.add_child(cam)
	# gros plans : [nom, distance, lacet autour du crâne (°), tangage (°, + = vu d'en haut), fov]
	# [nom, distance, lacet, tangage, fov, ennemi (0 guerrier casqué, 1 archer à capuche, 2 sbire à crâne nu)]
	var gros := [["gros_face", 0.75, 0.0, 0.0, 24.0, 2], ["gros_34", 0.75, 38.0, 4.0, 24.0, 2], ["gros_profil", 0.75, 88.0, 0.0, 24.0, 2], ["gros_joueur", 1.30, 12.0, 14.0, 26.0, 2],
		["casque_34", 0.85, 30.0, 4.0, 26.0, 0], ["capuche_face", 0.85, -15.0, 2.0, 26.0, 1]]
	# vues de jeu (caméra du joueur) : [nom, distance, hauteur visée, fov]
	var jeu := [["casques_3m", 3.0, 1.30, 34.0], ["rang_3m", 3.0, 1.0, fov0], ["jeu_5m", 5.0, 1.0, fov0], ["jeu_8m", 8.0, 0.9, fov0]]
	var images: Array[Image] = []
	for v in gros:
		for k in ennemis.size():
			(ennemis[k] as Node3D).visible = k == v[5]
		var centre: Vector3 = reperes[v[5]][0]
		var avant: Vector3 = reperes[v[5]][1]
		var haut_t: Vector3 = reperes[v[5]][2]
		var dir: Vector3 = avant.rotated(haut_t, deg_to_rad(v[2]))
		dir = dir.rotated(dir.cross(haut_t).normalized(), deg_to_rad(v[3]))
		var pc: Vector3 = centre + dir * float(v[1])
		cam.fov = v[4]
		cam.global_position = pc
		cam.look_at(centre, haut_t)
		cam.make_current()
		# torche : le joueur se tient sous la caméra, un peu en retrait
		var pj := Vector3(pc.x, j.global_position.y, pc.z) + Vector3(dir.x, 0, dir.z).normalized() * 0.35
		j.global_position = pj
		j.velocity = Vector3.ZERO
		j.rotation.y = atan2(-(centre.x - pj.x), -(centre.z - pj.z))
		await _attendre(120 if images.is_empty() else 25)
		images.append(await _capturer(sortie, v[0]))
		print("CAPTURE ", v[0], " cam=", c.to_local(pc), " crane=", c.to_local(centre))
	j.camera.make_current()
	cam.queue_free()
	for v in jeu:
		for k in ennemis.size():
			(ennemis[k] as Node3D).visible = true
		j.camera.fov = v[3]
		var cible: Vector3 = c.to_global(ORIGINE)
		var lat := 1.3 if String(v[0]) == "jeu_8m" else 0.0
		var pos: Vector3 = c.to_global(ORIGINE + Vector3(lat, 0.1, sqrt(v[1] * v[1] - lat * lat)))
		j.global_position = pos
		j.velocity = Vector3.ZERO
		var vers := cible - pos
		j.rotation.y = atan2(-vers.x, -vers.z)
		j.tete.rotation.x = atan2(cible.y + v[2] - (pos.y + 1.62), Vector2(vers.x, vers.z).length())
		await _attendre(25)
		images.append(await _capturer(sortie, v[0]))
		print("CAPTURE ", v[0], " cam=", c.to_local(j.camera.global_position))
	j.camera.fov = fov0
	var w := images[0].get_width()
	var h := images[0].get_height()
	var lignes := (images.size() + 1) / 2
	var pl := Image.create(w * 2 + 8, h * lignes + 8 * (lignes - 1), false, images[0].get_format())
	pl.fill(Color(0.1, 0.1, 0.1))
	for k in images.size():
		pl.blit_rect(images[k], Rect2i(0, 0, w, h), Vector2i((k % 2) * (w + 8), (k / 2) * (h + 8)))
	pl.save_png(sortie.path_join("planche.png"))
	print("PLANCHE ", sortie.path_join("planche.png"))
	quit(0)

func _capturer(sortie: String, nom: String) -> Image:
	await _attendre(3)
	var img := root.get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(sortie.path_join(nom + ".png"))
	return img
