extends SceneTree
## Captures de la scène de démonstration de l'eau (fenêtre nécessaire) : plusieurs vues × plusieurs heures en UN lancement.
##   godot --path . --disable-vsync --script res://outils/captures_eau.gd -- --capture --sortie=<dossier absolu>
##        [--vues=a,b] [--heures=jour,crep,nuit] [--paires] [--perf] [--sans-eau] [--x2]
## --paires : pour chaque vue, une seconde image décalée de 5 cm et un masque de l'eau (rose) ; écrit le taux de pixels d'eau qui
##            changent (scintillement) dans <sortie>/paires.txt.
## --perf   : temps GPU moyen (ms) de chaque vue sur 40 images, écrit dans <sortie>/perf.txt (relancer avec --sans-eau pour le coût de l'eau).
const HEURES := {"jour": 12.5, "crep": 17.4, "nuit": 23.0}

var demo: Node3D

func _init() -> void:
	_lancer.call_deferred()

## nom -> [position (x, z) ou fonction, cible ou lacet/tangage]. Calculé à partir de la scène (zc, hauteur…).
func _vues() -> Dictionary:
	var c: Node3D = demo
	var X_C: float = c.X_C
	var G: float = c.X_GUE
	return {
		"cascade": [Vector2(X_C + 9.5, c.zc(X_C + 9.5) + 5.0), Vector3(X_C, 0.9, c.zc(X_C))],
		"bassin": [Vector2(X_C + 4.0, c.zc(X_C + 4.0) + 8.5), Vector3(X_C + 3.0, 0.0, c.zc(X_C + 3.0) - 2.5)],
		"gue": [Vector2(6.0, c.zc(6.0) + 6.0), Vector3(G, 0.2, c.zc(G))],
		"gue_face": [Vector2(G - 0.5, c.zc(G) + 6.5), Vector3(G, 0.1, c.zc(G) - 1.0)],
		"aval": [Vector2(G + 2.5, c.zc(G + 2.5) + 4.0), Vector3(36.0, 0.0, c.zc(36.0))],
		"panorama": [Vector2(-21.0, c.zc(-21.0) + 7.0), Vector3(6.0, 0.3, c.zc(6.0))],
		"lac": [Vector2(X_C + 8.5, c.zc(X_C + 8.5) + 6.0), Vector3(X_C - 1.0, 0.8, c.zc(X_C) - 1.0)],
		"approche_a": [Vector2(G - 9.0, c.zc(G - 9.0) + 8.0), Vector3(G - 1.0, 0.0, c.zc(G - 1.0) + 0.5)],
		"approche_b": [Vector2(G - 5.5, c.zc(G - 5.5) + 4.6), Vector3(G - 1.0, 0.0, c.zc(G - 1.0) + 0.5)],
		"approche_c": [Vector2(G - 2.2, c.zc(G - 2.2) + 3.0), Vector3(G - 1.0, 0.0, c.zc(G - 1.0) + 0.5)],
		"regard_bas": [Vector2(G - 1.0, c.zc(G - 1.0) + 2.3), Vector3(G - 1.0, -0.8, c.zc(G - 1.0) + 0.9)],
		"plan": [Vector2(2.0, 5.0), Vector3(2.0, 0.0, 4.9), 34.0],
		"plan_cascade": [Vector2(X_C + 3.0, c.zc(X_C + 3.0) + 0.6), Vector3(X_C + 3.0, 0.0, c.zc(X_C + 3.0)), 9.0],
		"cascade_pres": [Vector2(X_C + 6.5, c.zc(X_C + 6.5) + 1.0), Vector3(X_C, 0.5, c.zc(X_C)), 0.4],
		"regard_bas_pool": [Vector2(X_C + 6.0, c.zc(X_C + 6.0) + 4.5), Vector3(X_C + 6.0, -0.6, c.zc(X_C + 6.0) + 3.6)],
	}

var dossier_ab := ""

func _lancer() -> void:
	create_timer(850.0).timeout.connect(func() -> void: push_error("captures_eau : délai dépassé"); quit(1))   # garde-fou : jamais de processus orphelin
	dossier_ab = "res://captures/eau/x"
	var dossier := dossier_ab
	var noms: Array = []
	var heures: Array = ["jour", "crep", "nuit"]
	var paires := false
	var perf := false
	var x2 := false
	var ablation := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			dossier = a.substr(9)
			dossier_ab = dossier
		elif a.begins_with("--vues="):
			noms = a.substr(7).split(",")
		elif a.begins_with("--heures="):
			heures = a.substr(9).split(",")
		elif a == "--paires":
			paires = true
		elif a == "--perf":
			perf = true
		elif a == "--ablation":
			ablation = true
		elif a == "--x2":
			x2 = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	demo = (load("res://scenes/demo_eau.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	for i in 40:
		await process_frame
	var vues := _vues()
	if noms.is_empty():
		noms = ["cascade", "bassin", "gue", "gue_face", "aval", "panorama", "lac", "approche_a", "approche_b", "approche_c", "regard_bas", "regard_bas_pool"]
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var lignes_perf := PackedStringArray()
	var lignes_paires := PackedStringArray()
	var t_eau := 3.7
	for e in [demo.eau_haute, demo.eau_basse, demo.flaque]:
		if e != null:
			e.temps_force = t_eau
	if demo.cascade != null:
		demo.cascade.temps_force = t_eau
	var t0 := Time.get_ticks_msec()
	if ablation:
		await _ablation(vues, noms, heures[0])
		quit()
		return
	for h in heures:
		demo.cycle.heure = HEURES.get(h, float(h))
		demo.cycle._process(0.0)
		for i in 6:
			await process_frame
		for n in noms:
			var v: Array = vues[n]
			var img := await _poser_et_prendre(v, 0.0, 14)
			_enregistrer(img, dossier, "%s_%s" % [n, h], x2)
			if perf:
				var g := 0.0
				var cpu := 0.0
				for i in 40:
					await process_frame
					g += RenderingServer.viewport_get_measured_render_time_gpu(rid)
					cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
				lignes_perf.append("%s_%s gpu_ms=%.2f cpu_ms=%.2f appels=%d primitives=%d" % [n, h, g / 40.0, cpu / 40.0,
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
			if paires:
				var img2 := await _poser_et_prendre(v, 0.05, 14)
				_enregistrer(img2, dossier, "%s_%s_p5" % [n, h], x2)
				_masque(true)
				var m1 := await _poser_et_prendre(v, 0.0, 6)
				var m2 := await _poser_et_prendre(v, 0.05, 6)
				_masque(false)
				_enregistrer(m1, dossier, "%s_%s_masque" % [n, h], false)
				lignes_paires.append("%s_%s %s" % [n, h, _scintillement(img, img2, m1, m2)])
	if perf:
		FileAccess.open(ProjectSettings.globalize_path(dossier) + "/perf.txt", FileAccess.WRITE).store_string("\n".join(lignes_perf) + "\n")
		print("\n".join(lignes_perf))
	if paires:
		FileAccess.open(ProjectSettings.globalize_path(dossier) + "/paires.txt", FileAccess.WRITE).store_string("\n".join(lignes_paires) + "\n")
		print("\n".join(lignes_paires))
	print("LOT : %d vues x %d heures en %.1f s" % [noms.size(), heures.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	quit()

func _poser_et_prendre(v: Array, decalage: float, attente: int) -> Image:
	var p: Vector2 = v[0]
	var cible: Vector3 = v[1]
	var y: float = demo.hauteur(p.x, p.y)
	var oeil: float = float(v[2]) if v.size() > 2 else 0.1
	var cap: Vector2 = demo.viser(Vector3(p.x, y + oeil + 1.62, p.y), cible)
	# décalage latéral (vers la droite de la caméra) de `decalage` mètres
	var droite := Vector2(cos(cap.x), -sin(cap.x))
	var q := p + droite * decalage
	demo.joueur.set_physics_process(false)
	demo.joueur.global_position = Vector3(q.x, demo.hauteur(q.x, q.y) + oeil, q.y)
	demo.joueur.rotation.y = cap.x
	demo.joueur.tete.rotation.x = cap.y
	demo.joueur.velocity = Vector3.ZERO
	for i in attente:
		await process_frame
	return root.get_viewport().get_texture().get_image()

func _enregistrer(img: Image, dossier: String, nom: String, x2: bool) -> void:
	if x2:
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(dossier + "/" + nom + ".png"))

## Les surfaces d'eau en rose uni (pour isoler l'eau dans les mesures de scintillement).
func _masque(actif: bool) -> void:
	for e in [demo.eau_haute, demo.eau_basse, demo.flaque]:
		if e != null:
			e.materiau.set_shader_parameter("debug_masque", actif)

func _scintillement(a: Image, b: Image, ma: Image, mb: Image) -> String:
	var n := 0
	var diff := 0
	var somme := 0.0
	var w := a.get_width()
	var h := a.get_height()
	for y in h:
		for x in w:
			var ca := ma.get_pixel(x, y)
			var cb := mb.get_pixel(x, y)
			if not (ca.r - ca.g > 0.35 and ca.b - ca.g > 0.35 and cb.r - cb.g > 0.35 and cb.b - cb.g > 0.35):
				continue
			n += 1
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			var d := absf(pa.get_luminance() - pb.get_luminance())
			somme += d
			if d > 0.08:
				diff += 1
	if n < 50:
		return "pixels_eau=%d (trop peu)" % n
	return "pixels_eau=%d (%.0f%% de l'image) ecart_moyen=%.3f changent>8%%=%.1f%%" % [n, 100.0 * n / float(w * h), somme / n, 100.0 * diff / n]

## Isole la cause du scintillement : pour chaque réglage coupé, taux de pixels d'eau qui changent (décalage de 5 cm).
const ABLATIONS := [
	["base", {}],
	["sans_ondes", {"ond_amp": 0.0}],
	["sans_eclats", {"eclats": 0.0}],
	["sans_refraction", {"refraction": 0.0}],
	["sans_reflet", {"reflet_force": 0.0}],
	["sans_ecume", {"ecume_force": 0.0, "vaguelettes": 0.0}],
	["tout_coupe", {"ond_amp": 0.0, "eclats": 0.0, "refraction": 0.0, "reflet_force": 0.0, "ecume_force": 0.0, "vaguelettes": 0.0}],
]

func _ablation(vues: Dictionary, noms: Array, heure: String) -> void:
	demo.cycle.heure = HEURES.get(heure, float(heure))
	demo.cycle._process(0.0)
	for i in 6:
		await process_frame
	var base := {}
	for e in [demo.eau_haute, demo.eau_basse, demo.flaque]:
		if e != null:
			for k in ["ond_amp", "eclats", "refraction", "reflet_force", "ecume_force", "vaguelettes"]:
				base[[e, k]] = e.materiau.get_shader_parameter(k)
	var lignes := PackedStringArray()
	for ab in ABLATIONS:
		for key in base:
			(key[0] as Eau).regler(key[1], base[key])
		for e in [demo.eau_haute, demo.eau_basse, demo.flaque]:
			if e != null:
				for k in (ab[1] as Dictionary):
					e.regler(k, ab[1][k])
		for n in noms:
			var v: Array = vues[n]
			var img := await _poser_et_prendre(v, 0.0, 8)
			var img2 := await _poser_et_prendre(v, 0.05, 8)
			_masque(true)
			var m1 := await _poser_et_prendre(v, 0.0, 4)
			var m2 := await _poser_et_prendre(v, 0.05, 4)
			_masque(false)
			lignes.append("%s %s_%s %s" % [ab[0], n, heure, _scintillement(img, img2, m1, m2)])
	for key in base:
		(key[0] as Eau).regler(key[1], base[key])
	print("\n".join(lignes))
	FileAccess.open(ProjectSettings.globalize_path(dossier_ab) + "/ablation.txt", FileAccess.WRITE).store_string("\n".join(lignes) + "\n")
