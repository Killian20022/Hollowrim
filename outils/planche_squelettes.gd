extends SceneTree
## Planche squelettes vs draugr DANS LA CRYPTE, à la torche du joueur (monde réel, shaders et éclairage du jeu).
## Les ennemis sont posés en rang (dormeurs debout : figés, pose choisie), le joueur recule pour les vues de près / à 8 m.
##   godot --path . --script res://outils/planche_squelettes.gd -- --nouvelle --paisible --sortie=C:/.../dossier
##     [--types=guerrier,squelette,squelette_archer,squelette:hache] [--anim=Sword_Idle:0.3] [--mesure]
## Écrit <sortie>/<vue>.png (480x270 agrandi x2) et planche.png (grille des vues). --mesure : coût de rendu (gpu/cpu ms, appels) avec et sans les ennemis.
const ORIGINE := Vector3(0.0, 0.0, -26.5)   # devant le puits de lumière central   # repère crypte : salle des piliers, rang des ennemis
var m: Node3D
var vues := []

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
		g.visible = false      # mains et torche cachées, la LUMIÈRE de la torche reste
	var c: Node3D = t.crypte
	var types := _arg("types", "guerrier,squelette,squelette_archer").split(",")
	var an := _arg("anim", "Sword_Idle:0.3").split(":")
	var ennemis: Array = []
	var ecart := 1.15
	for i in types.size():
		var ty := types[i].split(":")
		var x := (i - (types.size() - 1) * 0.5) * ecart
		var opts := {"ident": "planche_%d" % i, "debout": true}
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
		# figé : ni IA (il se réveillerait quand la caméra s'approche) ni avance de l'animation (SalleActive peut remettre process_mode)
		d.set_physics_process(false)
		d.set_process(false)
		d.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var j = m.joueur
	# torche : visuels (flamme, halo) cachés et lumière figée ; la LUMIÈRE reste (mains figées après 30 images)
	j.mains.process_mode = Node.PROCESS_MODE_DISABLED
	for f in j.mains.flammes:
		f.visible = false
	for n: Node3D in j.mains._visuels_torche:
		n.visible = false
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/planche_squelettes"))
	DirAccess.make_dir_recursive_absolute(sortie)
	# vues : [nom, distance, décalage latéral, hauteur visée, lacet du rang (°)]
	var liste := [["pres", 2.6, 0.0, 1.0, 0.0], ["pres_34", 2.6, 0.0, 1.0, 35.0], ["haut", 1.5, 0.0, 1.45, 0.0], ["loin_8m", 8.0, 0.0, 0.9, 0.0]]
	if types.size() > 3:
		liste[0][1] = 3.2
		liste[1][1] = 3.2
	# gros plans (1 m) des types demandés en --gros=i,j (rang dans --types)
	for g in _arg("gros", "").split(",", false):
		var gi := int(g)
		liste.append(["gros_%d" % gi, 1.1, (gi - (types.size() - 1) * 0.5) * ecart, 1.4, 20.0, gi])
	var images: Array[Image] = []
	for v in liste:
		for k in ennemis.size():
			var d: CharacterBody3D = ennemis[k]
			d.modele.rotation.y = deg_to_rad(v[4])
			d.visible = v.size() < 6 or k == v[5]     # gros plan : les voisins sont cachés
		var cible: Vector3 = c.to_global(ORIGINE + Vector3(v[2], 0, 0))
		var lat := 1.3 if String(v[0]) == "loin_8m" else 0.0    # 8 m : de biais, le puits de lumière central ne masque pas le rang
		var pos: Vector3 = c.to_global(ORIGINE + Vector3(v[2] + lat, 0.1, sqrt(v[1] * v[1] - lat * lat)))
		j.global_position = pos
		j.velocity = Vector3.ZERO
		var vers := cible - pos
		j.rotation.y = atan2(-vers.x, -vers.z)
		var oeil := pos.y + 1.62
		j.tete.rotation.x = atan2(cible.y + v[3] - oeil, Vector2(vers.x, vers.z).length())
		await _attendre(120 if images.is_empty() else 25)
		var img := root.get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(sortie.path_join(String(v[0]) + ".png"))
		images.append(img)
		print("CAPTURE ", v[0], " cam=", c.to_local(j.camera.global_position), " ennemis=", ennemis.map(func(e): return c.to_local(e.modele.global_position)), " anim=", ennemis.map(func(e): return [e.anim.current_animation, snappedf(e.anim.current_animation_position, 0.01), e.etat]))
	if OS.get_cmdline_user_args().has("--mesure"):
		await _mesurer("avec", ennemis.size())
		for d: CharacterBody3D in ennemis:
			d.visible = false
		await _mesurer("sans", 0)
	# planche 2 colonnes
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

func _mesurer(nom: String, n: int) -> void:
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 30:
		await RenderingServer.frame_post_draw
	var g := 0.0
	var cpu := 0.0
	for i in 120:
		await RenderingServer.frame_post_draw
		g += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	var appels := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	print("RENDU %s (%d ennemis) gpu=%.3f ms cpu=%.3f ms appels=%d primitives=%d" % [nom, n, g / 120.0, cpu / 120.0, appels, prims])
