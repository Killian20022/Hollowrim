extends SceneTree
## Outil hors jeu : captures, film et mesures du décor animé du menu (fenêtre nécessaire : lancer via godot_slot.sh, hors écran).
##   godot --path . --script res://scripts/menu_decor/outils/captures.gd -- --sortie=<dossier absolu> [--film] [--perf]
## Le décor est rendu dans un SubViewport à la taille voulue (indépendant de la fenêtre et du stretch 640×360 du projet).
## Écrit : t00.png, t05.png, t10.png (1920×1080), format_16x10.png, format_4x3.png, format_21x9.png, sans_logo.png,
##         comparaison.png (référence | décor), film/fNNN.jpg (--film, 12 i/s pendant 10 s, 960×540), mesures.txt.

const SCENE := "res://scenes/menu_decor/menu_decor.tscn"
var sortie := ""
var vp: SubViewport
var decor: Control
var lignes: PackedStringArray = []

func _init() -> void:
	_lancer.call_deferred()

func _attendre(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()

func _lancer() -> void:
	create_timer(600.0).timeout.connect(func() -> void: push_error("captures menu_decor : délai dépassé"); quit(1))
	var film := false
	var perf := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
		elif a == "--film":
			film = true
		elif a == "--perf":
			perf = true
	DirAccess.make_dir_recursive_absolute(sortie)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	vp = SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	await process_frame
	var mem0 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	# --- chargement : lecture des ressources + instanciation + première image (compilation des shaders comprise)
	var t0 := Time.get_ticks_usec()
	var ps := load(SCENE) as PackedScene
	var t_load := Time.get_ticks_usec()
	decor = ps.instantiate() as Control
	vp.add_child(decor)
	var t_inst := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var t_img := Time.get_ticks_usec()
	lignes.append("chargement : load %.1f ms, instanciation %.1f ms, 1re image %.1f ms, total %.1f ms" % [
		(t_load - t0) / 1000.0, (t_inst - t_load) / 1000.0, (t_img - t_inst) / 1000.0, (t_img - t0) / 1000.0])
	await process_frame
	var mem1 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	lignes.append("mémoire textures (VRAM) ajoutée : %.1f Mo" % ((mem1 - mem0) / 1048576.0))
	# --- captures à t = 0, 5, 10 s
	var img0 := await _image()
	img0.save_png(sortie.path_join("t00.png"))
	await _attendre(5.0)
	var img5 := await _image()
	img5.save_png(sortie.path_join("t05.png"))
	if film:
		DirAccess.make_dir_recursive_absolute(sortie.path_join("film"))
		var t_debut := Time.get_ticks_msec()
		var n := 0
		while Time.get_ticks_msec() - t_debut < 10000:
			var f := await _image()
			f.resize(960, 540, Image.INTERPOLATE_BILINEAR)
			f.save_jpg(sortie.path_join("film/f%03d.jpg" % n), 0.88)
			n += 1
			var cible := t_debut + n * 1000 / 12
			var reste := cible - Time.get_ticks_msec()
			if reste > 0:
				await _attendre(reste / 1000.0)
		lignes.append("film : %d images en 10 s" % n)
	else:
		await _attendre(5.0)
	var img10 := await _image()
	img10.save_png(sortie.path_join("t10.png"))
	# --- planche de comparaison avec la référence
	var ref := Image.load_from_file(ProjectSettings.globalize_path("res://textures/menu_decor/_source/reference.png"))
	ref.convert(Image.FORMAT_RGBA8)
	ref.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	var cmp := Image.create(1930, 540, false, Image.FORMAT_RGBA8)
	cmp.fill(Color.BLACK)
	var r5 := img5.duplicate() as Image
	r5.convert(Image.FORMAT_RGBA8)
	r5.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	cmp.blit_rect(ref, Rect2i(0, 0, 960, 540), Vector2i(0, 0))
	cmp.blit_rect(r5, Rect2i(0, 0, 960, 540), Vector2i(970, 0))
	cmp.save_png(sortie.path_join("comparaison.png"))
	# --- logo peint masqué
	decor.set_logo_peint(false)
	await process_frame
	(await _image()).save_png(sortie.path_join("sans_logo.png"))
	decor.set_logo_peint(true)
	decor.pulse_cristal()
	await _attendre(0.2)
	(await _image()).save_png(sortie.path_join("pulse_cristal.png"))
	# --- performances à 1920×1080
	if perf:
		var rid := vp.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(rid, true)
		await _attendre(0.5)
		var g := 0.0; var c := 0.0; var n := 0
		var t_deb := Time.get_ticks_usec()
		for i in 120:
			await RenderingServer.frame_post_draw
			g += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			c += RenderingServer.viewport_get_measured_render_time_cpu(rid)
			n += 1
		var duree := (Time.get_ticks_usec() - t_deb) / 1e6
		lignes.append("1920×1080 : GPU %.3f ms/image, CPU rendu %.3f ms/image (moyenne sur %d images), %.1f i/s mesurés (vsync %s)" % [
			g / n, c / n, n, n / duree, str(DisplayServer.window_get_vsync_mode())])
		lignes.append("appels de dessin : %d, mémoire vidéo totale : %.1f Mo" % [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
		lignes.append("GPU : %s / %s" % [RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name()])
		RenderingServer.viewport_set_measure_render_time(rid, false)
	# --- autres formats d'écran (cadrage « cover »)
	for fmt in [["16x10", Vector2i(1920, 1200)], ["4x3", Vector2i(1440, 1080)], ["21x9", Vector2i(2560, 1080)], ["720p", Vector2i(1280, 720)]]:
		vp.size = fmt[1]
		decor.size = Vector2(fmt[1])
		await process_frame
		await process_frame
		(await _image()).save_png(sortie.path_join("format_%s.png" % fmt[0]))
	# --- fondu de sortie
	vp.size = Vector2i(1920, 1080)
	decor.size = Vector2(1920, 1080)
	var termine := [false]
	decor.fondu_termine.connect(func() -> void: termine[0] = true)
	var t_f := Time.get_ticks_msec()
	decor.fondu_sortie(0.6)
	await _attendre(0.3)
	(await _image()).save_png(sortie.path_join("fondu_milieu.png"))
	while not termine[0] and Time.get_ticks_msec() - t_f < 3000:
		await process_frame
	lignes.append("fondu_sortie(0.6) : signal fondu_termine reçu = %s après %d ms" % [str(termine[0]), Time.get_ticks_msec() - t_f])
	var f := FileAccess.open(sortie.path_join("mesures.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lignes) + "\n")
	f.close()
	print("\n".join(lignes))
	print("CAPTURES OK")
	quit()
