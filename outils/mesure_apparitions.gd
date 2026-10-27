extends SceneTree
## Pics d'image à l'APPARITION des ennemis (draugrs, squelettes, mage de la crypte, troll de la grotte) et au 1er sort du mage
## (trait d'ombre). Vrais chemins du jeu : entrée de la crypte / de la grotte par le fondu, puis le joueur se pose devant chaque
## gardien à tour de rôle ; les zones le font apparaître comme en partie. Fenêtre nécessaire (GPU réel), vsync coupé :
##   godot --path . --disable-vsync --script res://outils/mesure_apparitions.gd -- --nouvelle [--lieu=crypte|grotte] [--ids=a,b]
##         [--sort] [--distance=6] [--log-file …]
## --sort (crypte) : à la fin, le mage cr_g4_mage est réveillé et ses 3 premiers traits sont mesurés (1er tir = trait d'ombre).
## Sortie : « PIC <ms> … » pour chaque image > 25 ms (process, rendu cpu, gpu, pipelines compilés, événements récents), une ligne
## « APPARITION <id> (<type>) » par ennemi (pire image des 40 suivantes, pipelines), « SORT … » par trait, puis « BILAN … ».
const SCENE := preload("res://scenes/foret_test.tscn")
const SEUIL := 25.0

var m: Node3D
var j: CharacterBody3D
var _prec := 0
var _evts: Array = []
var _pipe0 := 0
var _mesure := false
var _fen := {}              # fenêtre de mesure en cours : {nom, n, max, pipes, p0, proc, rcpu, rgpu}
var _res: Array = []
var _dts := PackedFloat32Array()
var _connus := {}
var _t_pf := 0
var _t_pre := 0
var _t_post := 0
var _a := 0.0
var _b := 0.0
var _c := 0.0

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _pipes() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))

func _evt(s: String) -> void:
	if "--journal" in OS.get_cmdline_user_args():
		print("EVT t=%.2f s %s" % [Time.get_ticks_msec() / 1000.0, s])
	_evts.append([Time.get_ticks_msec(), s])
	if _evts.size() > 12:
		_evts.pop_front()

func _sur_image() -> void:
	var n := Time.get_ticks_usec()
	var dt := (n - _prec) / 1000.0
	_prec = n
	if m == null:
		return
	# nouveaux ennemis (apparus par les zones du tertre / de la grotte)
	for id in m.draugrs:
		if not _connus.has(id):
			_connus[id] = true
			if _mesure:
				var e = m.draugrs[id]
				_evt("apparu %s(%s)" % [id, e.get("type") if e.get("type") != null else e.get_script().resource_path.get_file()])
	if not _mesure:
		return
	_dts.append(dt)
	var p := _pipes()
	var vp := root.get_viewport_rid()
	# A = scripts / animations (process), B = soumission du rendu (pipelines compris), C = présentation + physique (image précédente)
	var proc := _a
	var rcpu := _b
	var rgpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
	if dt > SEUIL:
		var recents := []
		for e in _evts:
			if Time.get_ticks_msec() - int(e[0]) < 400:
				recents.append(e[1])
		var ga = m.grotte_acces
		var etat_g := "" if ga == null else "grotte[enfants %d coque %d etapes %d]" % [(ga.get("_enfants_a_poser") as Array).size() if ga.get("_enfants_a_poser") != null else -1, (ga.get("_coque_a_poser") as Array).size(), (ga.get("_pose_restante") as Array).size()]
		print("PIC %.1f ms  t=%.2f s  A %.1f  B %.1f  C %.1f  gpu %.1f  pipelines +%d  %s evts=%s" % [dt, Time.get_ticks_msec() / 1000.0, _a, _b, _c, rgpu, p - _pipe0, etat_g, recents])
	if not _fen.is_empty():
		_fen["n"] += 1
		_fen["max"] = maxf(_fen["max"], dt)
		_fen["proc"] = maxf(_fen["proc"], proc)
		_fen["rcpu"] = maxf(_fen["rcpu"], rcpu)
		_fen["rgpu"] = maxf(_fen["rgpu"], rgpu)
		_fen["pipes"] = p - int(_fen["p0"])
	_pipe0 = p

func _ouvrir(nom: String) -> void:
	_fermer()
	_fen = {"nom": nom, "n": 0, "max": 0.0, "pipes": 0, "p0": _pipes(), "proc": 0.0, "rcpu": 0.0, "rgpu": 0.0}

func _fermer() -> void:
	if _fen.is_empty():
		return
	print("%s  images %d  pire %.1f ms  pipelines +%d | max process %.1f  rendu cpu %.1f  gpu %.1f" % [_fen["nom"], _fen["n"], _fen["max"], _fen["pipes"], _fen["proc"], _fen["rcpu"], _fen["rgpu"]])
	_res.append(_fen)
	_fen = {}

func _attendre(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await process_frame

func _images(n: int) -> void:
	for k in n:
		await process_frame

func _go() -> void:
	m = SCENE.instantiate()
	root.add_child(m)
	current_scene = m
	j = m.joueur
	process_frame.connect(_sur_image)
	if _arg("noeuds") != "":
		node_added.connect(func(n: Node) -> void:
			if _mesure and (n is GeometryInstance3D or n is Light3D or n is Decal or n is SubViewport):
				_evt("+%s %s (%s)" % [n.get_class(), n.name, n.get_parent().name if n.get_parent() else "?"]))
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
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	print("MESURE monde prêt à %d ms" % (Time.get_ticks_msec() - t0))
	if _arg("attendre-grotte") != "":
		var ga = m.grotte_acces
		var tg := Time.get_ticks_msec()
		while (ga.grotte == null or not (ga.get("_pose_restante") as Array).is_empty() or not (ga.get("_coque_a_poser") as Array).is_empty()) and Time.get_ticks_msec() - tg < 90000:
			await process_frame
		print("MESURE grotte posée après %d ms d'attente" % (Time.get_ticks_msec() - tg))
	# préchauffage du monde (PrechauffeRendu / PrechauffeCombat) : ~2 premières secondes de jeu, comme en partie
	await _attendre(3.0)
	for id in m.draugrs:
		_connus[id] = true
	if _arg("lieu", "crypte") == "fond":
		await _pose_grotte()
	elif _arg("lieu", "crypte") == "grotte":
		await _grotte()
	else:
		await _crypte()
	_fermer()
	_bilan()
	quit(0)
	# filet : un fil de fond pendu à la sortie (vu une fois après la grotte) ne doit pas bloquer un créneau Godot
	await create_timer(8.0).timeout
	OS.kill(OS.get_process_id())

func _vivant_invulnerable() -> void:
	j.vie = j.vie_max
	j.vigueur = j.vigueur_max

func _poser_devant(cible: Vector3, face: Vector3, dist: float) -> void:
	j.global_position = cible + face * dist + Vector3(0, 0.1, 0)
	j.velocity = Vector3.ZERO
	var v := cible + Vector3(0, 1.0, 0) - (j.global_position + Vector3(0, 1.6, 0))
	j.rotation.y = atan2(-v.x, -v.z)
	j.tete.rotation.x = clampf(atan2(v.y, Vector2(v.x, v.z).length()), -1.0, 0.6)

# ------------------------------------------------------------------ crypte

func _crypte() -> void:
	var tr = m.tertre
	var tt := Time.get_ticks_msec()
	while not tr._donjon_pret() and Time.get_ticks_msec() - tt < 60000:
		await process_frame
	# comme le joueur : il arrive devant la porte (copies des gardiens de l'entrée faites d'avance, une par image), puis entre
	j.global_position = tr.porte_dehors + Vector3(0, 0.3, 0)
	await _attendre(float(_arg("devant-porte", "1.5")))
	_pipe0 = _pipes()
	_prec = Time.get_ticks_usec()
	_mesure = true
	_evt("entree crypte")
	_ouvrir("ENTREE crypte (fondu + 1,5 s)")
	tr._passer(true)
	tt = Time.get_ticks_msec()
	while not tr.dedans and Time.get_ticks_msec() - tt < 30000:
		await process_frame
	await _attendre(1.5)
	_fermer()
	var cr: Node3D = tr.crypte
	var ids := _arg("ids").split(",", false)
	var choisis: Array = []
	var types_vus := {}
	for g: Dictionary in tr.donjon.gardiens:
		var ex: Dictionary = g["extra"]
		if ex.has("si"):
			continue
		var cle := String(ex.get("ia", g["type"])) + ("_boss" if ex.has("boss") else "")
		if ids.is_empty():
			if types_vus.has(cle):
				continue
			types_vus[cle] = true
		elif not String(g["ident"]) in ids:
			continue
		choisis.append(g)
	print("MESURE crypte : gardiens choisis ", choisis.map(func(g): return "%s(%s)" % [g["ident"], g["type"]]))
	var dist := float(_arg("distance", "6"))
	var mage = null
	for g: Dictionary in choisis:
		var id := String(g["ident"])
		if m.draugrs.has(id):
			print("APPARITION %s déjà là (apparu avec un voisin)" % id)
			continue
		var pos: Vector3 = cr.to_global(g["pos"])
		var face := Basis(Vector3.UP, cr.global_rotation.y + float(g["lacet"])).z
		_poser_devant(pos, face, dist)
		await _images(2)
		_evt("approche " + id)
		_ouvrir("APPARITION %s (%s)" % [id, g["type"]])
		var t0 := Time.get_ticks_msec()
		while not m.draugrs.has(id) and Time.get_ticks_msec() - t0 < 4000:
			_vivant_invulnerable()
			await process_frame
		if not m.draugrs.has(id):
			print("APPARITION %s : n'apparaît pas" % id)
			_fen = {}
			continue
		for k in 40:
			_vivant_invulnerable()
			_poser_devant(pos, face, dist)
			await process_frame
		_fermer()
		# gelés après la mesure (sauf le mage, pour --sort) : la mesure suivante n'est pas faussée par un combat
		for id2 in m.draugrs:
			var e = m.draugrs[id2]
			if String(id2) == "cr_g4_mage":
				mage = e
				continue
			if is_instance_valid(e) and String(id2).begins_with("cr_"):
				e.process_mode = Node.PROCESS_MODE_DISABLED
	if _arg("sort-direct") != "" and mage != null:
		await _sorts_directs(mage)
	elif _arg("sort") != "" and mage != null:
		await _sorts(mage)

func _sorts(mage) -> void:
	for id2 in m.draugrs:
		var e = m.draugrs[id2]
		if is_instance_valid(e) and e != mage:
			e.process_mode = Node.PROCESS_MODE_DISABLED
	mage.process_mode = Node.PROCESS_MODE_INHERIT
	mage.tirs = 2               # 1er tir = trait d'ombre (un tir sur trois)
	var pm: Vector3 = mage.global_position
	var face: Vector3 = mage.global_transform.basis.z
	_poser_devant(pm, face, 9.0)
	await _images(2)
	mage.alerter()
	var tirs0: int = mage.tirs
	var t0 := Time.get_ticks_msec()
	var etat0: int = mage.etat
	while mage.tirs - tirs0 < 3 and Time.get_ticks_msec() - t0 < 25000:
		_vivant_invulnerable()
		j.global_position = pm + face * 9.0 + Vector3(0, 0.1, 0)
		for id2 in m.draugrs:
			var e = m.draugrs[id2]
			if is_instance_valid(e) and e != mage and e.process_mode != Node.PROCESS_MODE_DISABLED:
				e.process_mode = Node.PROCESS_MODE_DISABLED
		if mage.etat != etat0:
			etat0 = mage.etat
			if etat0 == 2:   # INCANTE
				_ouvrir("SORT n°%d (%s)" % [mage.tirs - tirs0 + 1, "ombre" if mage.tirs % 3 == 2 else "givre"])
				_evt("incante")
		var t_avant: int = mage.tirs
		await process_frame
		if mage.tirs != t_avant:
			_evt("tir " + ("ombre" if mage.ombres > 0 and (mage.tirs - 1) % 3 == 2 else "givre"))
			# suit le vol du trait 1 s
			for k in 60:
				_vivant_invulnerable()
				await process_frame
			_fermer()
	print("SORTS mage : tirs %d dont ombre %d" % [mage.tirs - tirs0, mage.ombres])

## Traits lancés directement par le LanceurSorts du mage (gelé) vers le joueur immobile : ombre, ombre, givre ; 2 s mesurées chacun
## (vol, impact sur le joueur : statut corruption = voile + lumière, vol de mana).
func _sorts_directs(mage) -> void:
	for id2 in m.draugrs:
		var e = m.draugrs[id2]
		if is_instance_valid(e):
			e.process_mode = Node.PROCESS_MODE_DISABLED
	var pm: Vector3 = mage.global_position
	var face: Vector3 = mage.global_transform.basis.z
	_poser_devant(pm, face, float(_arg("distance-sort", "4")))
	await _attendre(1.0)
	var n := 1
	for sort in [mage.sort_ombre, mage.sort_ombre, mage.sort_givre]:
		_vivant_invulnerable()
		var vie0: float = j.vie
		var depart: Vector3 = pm + Vector3(0, 1.4, 0) + face * 0.5
		var cible: Vector3 = j.global_position + Vector3(0, 1.15, 0)
		mage.lanceur_sorts.cible_joueur = j
		_ouvrir("SORT direct n°%d (%s)" % [n, sort.ecole])
		_evt("tir " + String(sort.ecole))
		var tir: Dictionary = {} if _arg("sans-tir") != "" else mage.lanceur_sorts.lancer(sort, null, depart, (cible - depart).normalized())
		var projs: Array = tir.get("projectiles", [])
		var t0 := Time.get_ticks_msec()
		var touche := false
		while Time.get_ticks_msec() - t0 < 2000:
			await process_frame
			if not touche and j.vie < vie0:
				touche = true
				_evt("impact joueur")
			j.vie = maxf(j.vie, j.vie_max * 0.5)
			vie0 = minf(vie0, j.vie)
		_fermer()
		for pr in projs:
			if is_instance_valid(pr):
				print("   projectile encore en vol à ", pr.global_position)
		var jr: Array = mage.lanceur_sorts.journal
		print("SORT direct n°%d : joueur touché = %s  journal %s  joueur %s mage %s" % [n, touche, jr.map(func(x): return x["resultat"]), j.global_position, pm])
		n += 1
		_vivant_invulnerable()
		await _attendre(1.5)

# ------------------------------------------------------------------ grotte

## Le joueur reste au feu : pose de la grotte construite en fond (intégration dans l'arbre, coque, préchauffage, gameplay).
func _pose_grotte() -> void:
	var ga = m.grotte_acces
	_pipe0 = _pipes()
	_prec = Time.get_ticks_usec()
	_mesure = true
	_ouvrir("POSE grotte en fond (jusqu'à la fin + 2 s)")
	var tg := Time.get_ticks_msec()
	while (ga.grotte == null or not (ga.get("_pose_restante") as Array).is_empty() or not (ga.get("_coque_a_poser") as Array).is_empty()) and Time.get_ticks_msec() - tg < 90000:
		await process_frame
	print("MESURE grotte posée à t=%.1f s" % (Time.get_ticks_msec() / 1000.0))
	await _attendre(2.0)
	_fermer()

func _grotte() -> void:
	var ga: Node3D = m.grotte_acces
	j.global_position = Vector3(84, m.hauteur(84, -27) + 0.1, -27)
	var t := Time.get_ticks_msec()
	while ga.grotte == null and Time.get_ticks_msec() - t < 60000:
		await process_frame
	await _attendre(6.0)
	ga._passer(true)
	t = Time.get_ticks_msec()
	while not ga.dedans and Time.get_ticks_msec() - t < 10000:
		await process_frame
	await _attendre(2.0)
	var g: Node = ga.grotte
	var gj = ga.jeu
	var ids := _arg("ids", "troll_lac").split(",", false)
	_pipe0 = _pipes()
	_prec = Time.get_ticks_usec()
	_mesure = true
	for id: String in ids:
		var a: Dictionary = {}
		if gj != null:
			for x: Dictionary in gj.get("_file"):
				if String(x["id"]) == id:
					a = x
		if a.is_empty():
			print("APPARITION %s : absent de la file de la grotte" % id)
			continue
		var pos: Vector3 = g.to_global(a["pos"])
		# on s'approche le long du couloir jusqu'à la distance d'apparition (46 m, comme en marchant)
		var face: Vector3 = Basis(Vector3.UP, float(a["lacet"]) + g.global_rotation.y).z
		_poser_devant(pos, face, 8.0)
		await _images(2)
		_evt("approche " + id)
		_ouvrir("APPARITION %s (grotte)" % id)
		var t0 := Time.get_ticks_msec()
		while not m.draugrs.has(id) and Time.get_ticks_msec() - t0 < 4000:
			_vivant_invulnerable()
			await process_frame
		for k in 40:
			_vivant_invulnerable()
			_poser_devant(pos, face, 8.0)
			await process_frame
		_fermer()

func _bilan() -> void:
	var tri := _dts.duplicate()
	tri.sort()
	var n33 := 0
	for d in _dts:
		if d > 33.0:
			n33 += 1
	print("BILAN images %d  p99 %.1f  pire %.1f  >33ms %d" % [_dts.size(), tri[int(tri.size() * 0.99)] if tri.size() > 0 else 0.0, tri[-1] if tri.size() > 0 else 0.0, n33])
	for f in _res:
		print("BILAN %-40s pire %.1f ms  pipelines +%d" % [f["nom"], f["max"], f["pipes"]])
