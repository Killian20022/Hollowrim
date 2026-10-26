extends SceneTree
## Pics du PREMIER passage (saccades ressenties par le joueur) : monde chargé à froid, puis parcours scripté par les VRAIS chemins du jeu
## (marche depuis le feu, entrée de la crypte par le fondu, entrée de la grotte par le fondu), puis 2e passage identique pour comparer.
## Fenêtre nécessaire (GPU réel), vsync coupé :
##   godot --path . --disable-vsync --script res://outils/mesure_pics.gd -- --nouvelle --paisible --cible=place|crypte|grotte
## Sortie : « PIC <ms> [tronçon] A/B/C + pipelines compilés pendant l'image » pour chaque image > 33 ms, puis
## « PICS <tronçon> moy=.. pire=.. >33=.. n=.. » par tronçon, et « PICS chargement ... » (temps jusqu'au monde prêt).
## A = process (scripts, animations), B = soumission du rendu (compilations de pipelines comprises), C = présentation + physique.
const SEUIL := 33.0

var m: Node3D
var rid: RID
var cible := "place"
var _t_pf := 0
var _t_pre := 0
var _t_post := 0
var _a := 0.0
var _b := 0.0
var _c := 0.0
var prec := 0
var nom := ""            # tronçon en cours (vide : pas d'enregistrement)
var dts: PackedFloat32Array = PackedFloat32Array()
var pip_prec := 0
var t0 := 0
var debug := false
var dt_s := 0.016       # durée de la dernière image (s)

func _init() -> void:
	_demarrer.call_deferred()

func _arg(n: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + n:
			return "1"
		if a.begins_with("--" + n + "="):
			return a.substr(n.length() + 3)
	return defaut

func _pipelines() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))

func _demarrer() -> void:
	cible = _arg("cible", "place")
	debug = _arg("detail") != ""
	process_frame.connect(func() -> void:
		var n := Time.get_ticks_usec()
		if _t_post > 0:
			_c = (n - _t_post) / 1000.0
		_t_pf = n)
	RenderingServer.frame_pre_draw.connect(func() -> void:
		_t_pre = Time.get_ticks_usec()
		_a = (_t_pre - _t_pf) / 1000.0)
	RenderingServer.frame_post_draw.connect(func() -> void:
		_t_post = Time.get_ticks_usec()
		_b = (_t_post - _t_pre) / 1000.0)
	t0 = Time.get_ticks_msec()
	m = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(m)
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	m.joueur.mains.visible = false
	prec = Time.get_ticks_usec()
	pip_prec = _pipelines()
	# chargement : jusqu'aux intérieurs prêts (le joueur attend au feu, comme en partie)
	nom = "chargement"
	while not m.village.prets and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	_clore()
	print("PICS monde pret (interieurs) a %d ms" % (Time.get_ticks_msec() - t0))
	await _attendre(1.0)
	if _arg("attendre-fils") != "":
		var tf := Time.get_ticks_msec()
		while _fils().replace("P", "") != "" and Time.get_ticks_msec() - tf < 120000:
			await process_frame
		print("PICS fils de fond termines apres %d ms" % (Time.get_ticks_msec() - tf))
	match cible:
		"place":
			await _place()
		"crypte":
			await _crypte()
		"grotte":
			await _grotte()
	print("PICS FIN")
	quit(0)

func _attendre(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await process_frame

func _poser(p: Vector3, lacet: float, tang := 0.0) -> void:
	m.joueur.global_position = p
	m.joueur.velocity = Vector3.ZERO
	m.joueur.rotation.y = lacet
	m.joueur.tete.rotation.x = deg_to_rad(tang)

## Marche (téléportation lissée) le long de points monde x,z au sol, regard dans le sens de la marche.
func _marcher(pts: Array, vitesse: float, sol: Callable) -> void:
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var d := a.distance_to(b)
		var f := 0.0
		var lacet := atan2(-(b - a).x, -(b - a).y)
		while f < d:
			var p := a.lerp(b, f / d)
			_poser(sol.call(p), lacet)
			await process_frame
			f += vitesse * clampf(dt_s, 0.004, 0.05)   # pas plafonné : une saccade ne fait pas sauter le tronçon
	return

func _tourner(centre: Vector3, duree: float) -> void:
	var t := 0.0
	while t < duree:
		_poser(centre, TAU * t / duree, -4.0)
		await process_frame
		t += clampf(dt_s, 0.004, 0.05)

func _sol_monde(p: Vector2) -> Vector3:
	return Vector3(p.x, m.hauteur(p.x, p.y) + 0.1, p.y)

const CHEMIN_PLACE := [Vector2(3, 9), Vector2(19, 17.5), Vector2(35, 30), Vector2(39.5, 42)]

func _place() -> void:
	for passage in [1, 2]:
		_poser(_sol_monde(CHEMIN_PLACE[0]), 0.0)
		await _attendre(1.5)
		nom = "approche_%d" % passage
		await _marcher(CHEMIN_PLACE.slice(0, 3), 5.0, _sol_monde)
		_clore()
		nom = "place_%d" % passage
		await _marcher(CHEMIN_PLACE.slice(2), 5.0, _sol_monde)
		await _tourner(_sol_monde(CHEMIN_PLACE[3]), 4.0)
		_clore()

func _crypte() -> void:
	# même chemin que le joueur : marche jusqu'à la façade, fondu, attente « dedans »
	m.tertre._passer(true)
	var t := Time.get_ticks_msec()
	nom = "entree_crypte"
	while not m.tertre.dedans and Time.get_ticks_msec() - t < 30000:
		await process_frame
	await _attendre(0.8)
	_clore()
	var cr: Node3D = m.tertre.crypte
	var loc := func(p: Vector2) -> Vector3: return cr.to_global(Vector3(p.x, 0.1, p.y))
	for passage in [1, 2]:
		_poser(loc.call(Vector2(0, 0.5)), cr.global_rotation.y)
		await _attendre(0.5)
		nom = "colonne_haut_%d" % passage
		await _marcher([Vector2(0, 0.5), Vector2(0, -22)], 6.5, loc)
		_clore()
		nom = "colonne_22_48_%d" % passage
		await _marcher([Vector2(0, -22), Vector2(0, -48)], 6.5, loc)
		_clore()
		nom = "colonne_bas_%d" % passage
		await _marcher([Vector2(0, -48), Vector2(0, -66)], 6.5, loc)
		_clore()
		nom = "arene_%d" % passage
		await _tourner(loc.call(Vector2(0, -71)), 3.0)
		_clore()

func _grotte() -> void:
	var ga: Node3D = m.grotte_acces
	nom = "marche_grotte"
	await _marcher([Vector2(3, 9), Vector2(60, -20), Vector2(84, -27)], 6.0, _sol_monde)
	_clore()
	var t := Time.get_ticks_msec()
	while ga.grotte == null and Time.get_ticks_msec() - t < 30000:
		await process_frame
	print("PICS grotte prete ; prechauffe en cours=%s (attente %d ms)" % [ga.prechauffe != null and is_instance_valid(ga.prechauffe) and not ga.prechauffe.fini, Time.get_ticks_msec() - t])
	await _attendre(float(_arg("delai", "6")))
	print("PICS prechauffe finie=%s" % [ga.prechauffe == null or not is_instance_valid(ga.prechauffe) or ga.prechauffe.fini])
	nom = "entree_grotte"
	ga._passer(true)
	t = Time.get_ticks_msec()
	while not ga.dedans and Time.get_ticks_msec() - t < 10000:
		await process_frame
	await _attendre(2.0)
	_clore()
	var g: Node = ga.grotte
	var routes: Dictionary = g.routes_test()
	var l: Array = routes.values()[0]
	nom = "grotte_route"
	var k := 0
	while k < mini(l.size(), 400):
		var p: Vector3 = l[k]
		var q: Vector3 = l[mini(k + 4, l.size() - 1)]
		var dir := q - p
		_poser(p + Vector3(0, 0.1, 0), atan2(-dir.x, -dir.z))
		await process_frame
		k += 1
	_clore()

## Travaux de fond en cours (lettres) : V intérieurs du village, C fil de la crypte, E modèles d'ennemis, D pose du donjon par tranches,
## X extérieur de la grotte, G fil de la grotte, P préchauffage de la grotte.
func _fils() -> String:
	var s := ""
	if m == null:
		return s
	if m.village != null and not m.village.prets: s += "V"
	var tr: Node = m.tertre
	if tr != null:
		if int(tr.get("_tache")) >= 0: s += "C"
		if int(tr.get("_tache_en")) >= 0: s += "E"
		if not (tr.get("_reste_donjon") as Array).is_empty() or not (tr.get("_etapes_fin") as Array).is_empty(): s += "D"
	var ga: Node = m.grotte_acces
	if ga != null:
		if int(ga.get("_tache_ext")) >= 0: s += "X"
		if int(ga.get("_tache")) >= 0: s += "G"
		var pr = ga.get("prechauffe")
		if pr != null and is_instance_valid(pr) and not pr.fini: s += "P"
	return s

func _process(_dt: float) -> bool:
	var n := Time.get_ticks_usec()
	var ms := (n - prec) / 1000.0
	prec = n
	dt_s = ms / 1000.0
	var pip := _pipelines()
	var dp := pip - pip_prec
	pip_prec = pip
	if nom == "":
		return false
	dts.append(ms)
	if ms > SEUIL or (debug and dp > 0):
		var jp: Vector3 = m.joueur.global_position if m != null and m.joueur != null else Vector3.ZERO
		if cible == "crypte" and m.tertre.dedans:
			jp = m.tertre.crypte.to_local(jp)
		print("PIC %6.1f ms [%s] t=%.1f s A=%.1f B=%.1f C=%.1f pipelines+%d fils=%s | joueur (%.1f, %.1f, %.1f) gpu=%.1f" % [ms, nom, (Time.get_ticks_msec() - t0) / 1000.0, _a, _b, _c, dp, _fils(), jp.x, jp.y, jp.z,
			RenderingServer.viewport_get_measured_render_time_gpu(rid)])
	return false

func _clore() -> void:
	if dts.is_empty():
		nom = ""
		return
	var s := 0.0
	var mx := 0.0
	var n33 := 0
	for v in dts:
		s += v
		mx = maxf(mx, v)
		if v > SEUIL:
			n33 += 1
	print("PICS %-18s moy=%6.2f pire=%7.1f >33=%3d n=%d (t=%.1f s, fils=%s)" % [nom, s / dts.size(), mx, n33, dts.size(), (Time.get_ticks_msec() - t0) / 1000.0, _fils()])
	dts = PackedFloat32Array()
	nom = ""
