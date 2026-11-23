extends SceneTree
## Bug « crypte noire » (2026-11-23) : à l'arrivée dans la crypte par la porte du tertre (chemin normal, entrée asynchrone), le couloir
## restait noir tant que le joueur ne bougeait pas. Ce script entre comme le joueur (tertre._passer(true), sans --captures/--crypte/
## --scenario : l'entrée n'est PAS synchrone), capture plusieurs images immobile à l'arrivée puis en avançant de ~1,5 m, et mesure les FPS.
##   godot --path . --disable-vsync --script res://outils/repro_crypte_noire.gd -- --nouvelle --paisible [--heure=12] --sortie=<dossier Windows> [--prefixe=avant]
## Lignes : « ARRIVEE i t=… lum=… occ=… visibles=… » (luminance moyenne du centre de l'image), « FPS crypte … ».
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var j: CharacterBody3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _attendre(k: int) -> void:
	for i in k:
		await process_frame

## Luminance moyenne d'une bande centrale (le couloir devant le joueur), 0..255.
func _lum(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var s := 0.0
	var n := 0
	for y in range(int(h * 0.25), int(h * 0.6), 2):
		for x in range(int(w * 0.3), int(w * 0.7), 2):
			var c := img.get_pixel(x, y)
			s += c.get_luminance()
			n += 1
	return s / maxf(n, 1) * 255.0

func _capture(sortie: String, nom: String) -> float:
	var img := get_root().get_viewport().get_texture().get_image()
	var l := _lum(img)
	if sortie != "":
		img.save_png(sortie.path_join(nom + ".png"))
	return l

func _go() -> void:
	var etale := "--etale" in OS.get_cmdline_user_args()
	m = SCENE.instantiate()
	if etale:
		# comme l'écran de chargement du titre (ecran_chargement.gd : _entrer_monde / _finir) : monde bâti en pause, sans rendu 3D, étalé
		Jeu.chargement_etale = true
		paused = true
		root.get_viewport().disable_3d = true
	root.add_child(m)
	current_scene = m
	j = m.joueur
	var t0 := Time.get_ticks_msec()
	if etale:
		while not m.pret and Time.get_ticks_msec() - t0 < 300000:
			await process_frame
		Jeu.chargement_etale = false
		root.get_viewport().disable_3d = false
		paused = false
	while (m.village.get("prets") != true or not m.tertre.bati) and Time.get_ticks_msec() - t0 < 300000:
		await process_frame
	print("REPRO etale=%s pret en %d ms ; donjon pret=%s" % [str(etale), Time.get_ticks_msec() - t0, str(m.tertre._donjon_pret())])
	if _arg("heure") != "":
		m.cycle.heure = float(_arg("heure"))
	await _attendre(int(_arg("attente", "30")))
	var sortie := _arg("sortie")
	var pre := _arg("prefixe", "repro")
	if sortie != "":
		DirAccess.make_dir_recursive_absolute(sortie)
	# devant la porte du tertre, face à elle (comme le joueur qui vient d'activer la dalle)
	var tr: Node3D = m.tertre
	j.global_position = tr.porte_dehors + Vector3(0, 0.3, 0.6)
	j.rotation.y = tr.orientation
	j.velocity = Vector3.ZERO
	await _attendre(int(_arg("attente-porte", "60")))
	tr._passer(true)
	# attendre la bascule (fin de l'écran noir) : dedans + fondu revenu à 0
	t0 = Time.get_ticks_msec()
	while not tr.dedans and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var t_bascule := Time.get_ticks_msec()
	var vp := get_root().get_viewport()
	var res: Array = []
	# 1) immobile : 12 images espacées sur ~3 s (la 1re juste à la fin du fondu de 0,6 s)
	for i in 12:
		var att := 0.65 if i == 0 else 0.2
		var tt := Time.get_ticks_msec()
		while Time.get_ticks_msec() - tt < att * 1000.0:
			await process_frame
		await RenderingServer.frame_post_draw
		var l := _capture(sortie, "%s_immobile_%02d" % [pre, i])
		var vis := _nb_visibles(tr.crypte)
		print("ARRIVEE immobile %d t=%.2fs lum=%.1f occ=%s visibles=%d pos=%s" % [i, (Time.get_ticks_msec() - t_bascule) / 1000.0, l,
			str(vp.use_occlusion_culling), vis, str(tr.crypte.to_local(j.global_position))])
		res.append(l)
		if i == 0:
			var ids: Array = []
			for ip in Occultation._dedans:
				ids.append(String((ip as Node).get("id")) + "@" + str((ip as Node3D).global_position))
			print("  intérieurs 'caméra dedans' : ", ids, " ; caméra ", j.global_position)
			var sa = tr.salles
			if sa != null:
				var caches := 0
				for k in sa._noeuds:
					if not (sa._noeuds[k]["n"] as GeometryInstance3D).visible:
						caches += 1
				print("  salles : courante='%s' actives=%s visibles=%s caches=%d/%d a_classer=%d" % [sa.courante, str(sa.actives.keys()), str(sa._visibles.keys()), caches, sa._noeuds.size(), sa._a_classer.size()])
			if "--diag" in OS.get_cmdline_user_args():
				var lums := []
				for g in tr.crypte.find_children("*", "GeometryInstance3D", true, false):
					if not (g as GeometryInstance3D).visible:
						lums.append(g)
				for g in lums:
					(g as GeometryInstance3D).visible = true
				await _attendre(3)
				await RenderingServer.frame_post_draw
				print("  DIAG tout visible (%d noeuds rallumes) lum=%.1f" % [lums.size(), _capture(sortie, pre + "_diag_tout_visible")])
				for g in lums:
					(g as GeometryInstance3D).visible = false
	# FPS immobile à l'arrivée (2 s)
	var fps_im := await _fps(2.0)
	# 2) en avançant ~1,5 m
	var p0 := j.global_position
	Input.action_press("avant")
	var k := 0
	while j.global_position.distance_to(p0) < 1.5 and k < 300:
		await process_frame
		k += 1
	Input.action_release("avant")
	await _attendre(5)
	await RenderingServer.frame_post_draw
	var l2 := _capture(sortie, "%s_avance" % pre)
	print("ARRIVEE avance d=%.2f lum=%.1f occ=%s visibles=%d" % [j.global_position.distance_to(p0), l2, str(vp.use_occlusion_culling), _nb_visibles(tr.crypte)])
	var fps_av := await _fps(2.0)
	print("FPS crypte immobile=%.1f apres_avance=%.1f" % [fps_im, fps_av])
	var noirs := 0
	for l in res:
		if l < l2 * 0.5:
			noirs += 1
	print("BILAN images noires a l'arrivee : %d / %d (lum avance %.1f)" % [noirs, res.size(), l2])
	quit()

func _fps(duree: float) -> float:
	var n := 0
	var t := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t < duree * 1e6:
		await process_frame
		n += 1
	return n / ((Time.get_ticks_usec() - t) / 1e6)

func _nb_visibles(c: Node3D) -> int:
	var n := 0
	for g in c.find_children("*", "GeometryInstance3D", true, false):
		if (g as GeometryInstance3D).is_visible_in_tree():
			n += 1
	return n
