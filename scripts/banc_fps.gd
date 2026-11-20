extends Node
## Banc FPS DANS LE JEU (exe exporté comme éditeur) — 2026-11-20, passe d'optimisation, domaine physique_reseau_exe.
## Autoload « BancFps » : sans l'argument --banc-fps il se retire au premier _ready (coût nul en jeu normal).
##   Hollowrim.exe --disable-vsync -- --nouvelle [--paisible] [--pose=x,z,lacet,tangage] --banc-fps=<lieu>,<heure>,<durée> --banc-sortie=<fichier.json>
##   (éditeur : Godot_console.exe --path <projet> --disable-vsync -- mêmes arguments)
## Lieux : ceux d'outils/audit_mesure_lieu.gd — temoin, place (avec --pose), foret, halle, ferme, grotte, crypte, combat (sans --paisible :
## 6 ennemis réveillés dans l'arène de la crypte + sorts 1-2-3 en rotation). Le jeu suit son vrai chemin : écran titre → monde
## (Jeu.mode_outil : passage direct), puis le joueur est placé ; vsync coupée, pas de limite d'images, heure figée (sauf combat),
## 10 s de stabilisation puis <durée> s de mesure. Écrit le JSON puis quitte. Chaque image : dt réel (horloge), temps CPU des scripts
## (sonde encadrant tous les _process / _physics_process), temps de rendu CPU/GPU du viewport, appels de dessin, primitives, objets.
## FPS « 1 % bas » = 1000 / moyenne des 1 % d'images les plus longues (idem 0,1 %). Banc complet : outils/banc_fps_exe.sh ; comparaison :
## outils/compare_fps.sh.

const STAB := 10.0

var actif := false
var lieu := "temoin"
var heure := 12.0
var duree := 20.0
var sortie := ""

var m: Node3D
var j: CharacterBody3D
var rid: RID
var phase := "init"
var t := 0.0
var prec_us := 0
var t_charge_ms := 0
var dts := PackedFloat32Array()
var gpu := PackedFloat32Array()
var cpu := PackedFloat32Array()
var tp := PackedFloat32Array()
var tph := PackedFloat32Array()
var appels := 0.0
var prims := 0.0
var objets := 0.0
var ennemis: Array = []
var t_sort := 0.0
var rac := 0
var _pip0 := 0

## Sonde : deux nœuds de priorité extrême encadrent TOUS les _process / _physics_process de l'arbre (cf. audit_mesure_lieu.gd).
class Sonde extends Node:
	var debut := false
	var t0 := 0
	var sonde_debut: Sonde
	var cumul := PackedFloat32Array()
	var actif := false
	func _process(_dt: float) -> void:
		_tic()
	func _physics_process(_dt: float) -> void:
		_tic()
	func _tic() -> void:
		var maintenant := Time.get_ticks_usec()
		if debut:
			t0 = maintenant
		elif actif:
			cumul.append((maintenant - sonde_debut.t0) / 1000.0)

var sondes_p: Array = []
var sondes_ph: Array = []

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--banc-fps="):
			var p := a.substr(11).split(",")
			lieu = p[0] if p.size() > 0 and p[0] != "" else "temoin"
			heure = float(p[1]) if p.size() > 1 else 12.0
			duree = float(p[2]) if p.size() > 2 else 20.0
			actif = true
		elif a.begins_with("--banc-sortie="):
			sortie = a.substr(14)

func _ready() -> void:
	if not actif:
		set_process(false)
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_go.call_deferred()

func _arg(nom: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + nom)

func _go() -> void:
	var t0 := Time.get_ticks_msec()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("BANC_FPS %s heure=%.1f duree=%.0f sortie=%s" % [lieu, heure, duree, sortie])
	# l'écran titre passe seul au monde en mode outil : on attend le monde prêt (joueur présent)
	while true:
		var cs := get_tree().current_scene
		if cs != null and cs.scene_file_path == Jeu.SCENE_JEU and cs.get("joueur") != null:
			m = cs
			break
		if Time.get_ticks_msec() - t0 > 240000:
			_ecrire({"erreur": "monde introuvable après 240 s"})
			get_tree().quit(2)
			return
		await get_tree().process_frame
	j = m.joueur
	t_charge_ms = Time.get_ticks_msec() - t0
	rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for k in 60:
		await get_tree().process_frame
	await _placer()
	m.cycle.heure = heure
	m.cycle._process(0.0)
	if lieu != "combat":
		m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	_poser_sondes()
	_pip0 = _pipelines()
	print("BANC_FPS placé : %s pos=%s chargement=%d ms" % [lieu, j.global_position, t_charge_ms])
	prec_us = Time.get_ticks_usec()
	phase = "mesure"

func _placer() -> void:
	var tree := get_tree()
	match lieu:
		"foret":
			_vers_foret()
		"halle", "ferme":
			var th := Time.get_ticks_msec()
			while m.village.get("prets") != true and Time.get_ticks_msec() - th < 90000:
				await tree.process_frame
			var ip: Interieur = m.village.interieur("halle" if lieu == "halle" else "ferme_a")
			if lieu == "halle":
				j.global_position = ip.to_global(Vector3(3.4, ip.sol_y + 0.05, 0.9))
				j.rotation.y = ip.global_rotation.y + deg_to_rad(25.0)
				j.tete.rotation.x = deg_to_rad(-14.0)
			else:
				j.global_position = ip.to_global(Vector3(0.0, ip.sol_y + 0.05, 0.6))
				j.rotation.y = ip.global_rotation.y
				j.tete.rotation.x = deg_to_rad(-12.0)
			j.velocity = Vector3.ZERO
			for k in 30:
				await tree.process_frame
		"crypte", "combat":
			var tt := Time.get_ticks_msec()
			while not m.tertre._donjon_pret() and Time.get_ticks_msec() - tt < 90000:
				await tree.process_frame
			m.tertre._basculer(true)
			m._sous_terre(true)
			j.mains.visible = true
			j.global_position = m.tertre.crypte.to_global(Vector3(0, 0.1, -66.0 if lieu == "combat" else -25.0))
			j.velocity = Vector3.ZERO
			for k in 30:
				await tree.process_frame
			if lieu == "combat":
				await _reveiller()
		"grotte":
			var tt2 := Time.get_ticks_msec()
			while m.grotte_acces.grotte == null and Time.get_ticks_msec() - tt2 < 90000:
				await tree.process_frame
			m.grotte = m.grotte_acces.obtenir()
			m.grotte_acces.montrer(true)
			m._sous_terre(true)
			m.grotte.ambiance(m._env)
			var routes: Dictionary = m.grotte.routes_test()
			var best: Array = []
			for id in routes:
				if (routes[id] as Array).size() > best.size():
					best = routes[id]
			var p: Vector3 = best[best.size() / 2]
			j.global_position = p + Vector3(0, 0.1, 0)
			j.velocity = Vector3.ZERO
			j.rotation.y = atan2(-(best[best.size() / 2 + 1] - p).x, -(best[best.size() / 2 + 1] - p).z)

func _vers_foret() -> void:
	var best := Vector3.ZERO
	var bn := -1
	var pts: Array = []
	for tr: Transform3D in m.arbres:
		pts.append(Vector2(tr.origin.x, tr.origin.z))
	var x := -100.0
	while x <= 100.0:
		var z := -100.0
		while z <= 100.0:
			var c := Vector2(x, z)
			if c.distance_to(Vector2(44, 40)) > 40.0 and c.distance_to(Vector2.ZERO) > 20.0 and c.distance_to(Vector2(-38, -34)) > 20.0:
				var k := 0
				for p: Vector2 in pts:
					if p.distance_squared_to(c) < 196.0:
						k += 1
				if k > bn:
					bn = k
					best = Vector3(x, 0, z)
			z += 6.0
		x += 6.0
	j.global_position = Vector3(best.x, m.hauteur(best.x, best.z) + 0.1, best.z)
	j.velocity = Vector3.ZERO
	j.rotation.y = 0.5

func _reveiller() -> void:
	var tree := get_tree()
	var tr = m.tertre
	tr.attendre_donjon()
	tr.dedans = true
	var cr: Node3D = tr.crypte
	cr.visible = true
	for g: Dictionary in tr.donjon.gardiens:
		var ex: Dictionary = g["extra"]
		if String(g["type"]) == "squelette_archer" or ex.has("boss") or ex.has("si") or ex.has("reveil_evt"):
			continue
		j.global_position = cr.to_global(g["pos"]) + Vector3(0, 0.1, 3.0)
		for k in 8:
			tr._gerer_zones()
			await tree.process_frame
		if _vivants().size() >= 6:
			break
	ennemis = _vivants().slice(0, 6)
	var centre := cr.to_global(Vector3(0, 0.1, -66.0))
	j.global_position = centre
	j.velocity = Vector3.ZERO
	for i in ennemis.size():
		var a := TAU * i / maxf(1.0, ennemis.size())
		var e: Node3D = ennemis[i]
		e.process_mode = Node.PROCESS_MODE_INHERIT
		e.visible = true
		e.global_position = centre + Vector3(cos(a) * 5.0, 0.2, sin(a) * 5.0)
	for k in 30:
		await tree.process_frame

func _vivants() -> Array:
	var r: Array = []
	for id in m.draugrs:
		var e = m.draugrs[id]
		if is_instance_valid(e) and e is Node3D and e.has_method("vivant") and e.vivant():
			r.append(e)
	return r

func _sorts(dt: float) -> void:
	var cible: Node3D = null
	var dmin := 1e9
	for e in ennemis:
		if is_instance_valid(e) and e is Node3D:
			var d := (e as Node3D).global_position.distance_to(j.global_position)
			if d < dmin:
				dmin = d
				cible = e
	if cible != null:
		var v: Vector3 = cible.global_position + Vector3(0, 1.1, 0) - j.camera.global_position
		j.rotation.y = atan2(-v.x, -v.z)
		j.tete.rotation.x = clampf(atan2(v.y, Vector2(v.x, v.z).length()), -1.0, 0.6)
	var magie: Node = j.mains.magie
	t_sort -= dt
	if t_sort <= 0.0:
		t_sort = 5.0
		magie.relacher("gauche")
		magie.relacher("droite")
		rac = (rac + 1) % 3
		magie.raccourci(rac)
		magie.appuyer("gauche")
		magie.appuyer("droite")

func _poser_sondes() -> void:
	for ph in [false, true]:
		var a := Sonde.new()
		var b := Sonde.new()
		a.debut = true
		b.sonde_debut = a
		for s in [a, b]:
			s.process_priority = -100000 if s == a else 100000
			s.process_physics_priority = s.process_priority
			s.process_mode = Node.PROCESS_MODE_ALWAYS
			get_tree().root.add_child(s)
			s.set_process(not ph)
			s.set_physics_process(ph)
		(sondes_ph if ph else sondes_p).assign([a, b])

func _process(dt: float) -> void:
	if phase != "mesure":
		return
	t += dt
	var now := Time.get_ticks_usec()
	var d_ms := (now - prec_us) / 1000.0
	prec_us = now
	j.vie = j.vie_max
	j.mana = 100.0
	if lieu == "combat":
		_sorts(dt)
	if t < STAB:
		return
	if dts.is_empty():
		sondes_p[1].actif = true
		sondes_ph[1].actif = true
		_pip0 = _pipelines()
	dts.append(d_ms)
	gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	tp.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	tph.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	appels += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	objets += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	if t >= STAB + duree:
		phase = "fin"
		_finir.call_deferred()

func _pipelines() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))

static func _pct(a: PackedFloat32Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[mini(b.size() - 1, int(b.size() * p))]

## moyenne de la fraction la plus lente (0.01 = 1 %) des temps d'image, en ms
static func _pire(a: PackedFloat32Array, frac: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	var k := maxi(1, int(round(b.size() * frac)))
	var s := 0.0
	for i in k:
		s += b[b.size() - 1 - i]
	return s / k

static func _moy(a: PackedFloat32Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(1.0, a.size())

func _finir() -> void:
	var n := dts.size()
	var s16 := 0
	var s33 := 0
	for d in dts:
		if d > 16.7:
			s16 += 1
		if d > 33.0:
			s33 += 1
	var total_ms := 0.0
	for d in dts:
		total_ms += d
	var r := {
		"lieu": lieu, "heure": heure, "duree": duree, "n": n,
		"fps_moy": 1000.0 * n / maxf(total_ms, 0.001),
		"fps_1pc_bas": 1000.0 / maxf(_pire(dts, 0.01), 0.001),
		"fps_01pc_bas": 1000.0 / maxf(_pire(dts, 0.001), 0.001),
		"dt_med": _pct(dts, 0.5), "dt_p95": _pct(dts, 0.95), "dt_p99": _pct(dts, 0.99), "dt_max": _pct(dts, 1.0),
		"sup_16_7": s16, "sup_33": s33,
		"cpu_scripts_process_med": _pct(sondes_p[1].cumul, 0.5), "cpu_scripts_process_p95": _pct(sondes_p[1].cumul, 0.95),
		"cpu_scripts_physics_med": _pct(sondes_ph[1].cumul, 0.5), "cpu_scripts_physics_p95": _pct(sondes_ph[1].cumul, 0.95),
		"cpu_scripts_physics_pas": sondes_ph[1].cumul.size(),
		"temps_process_med": _pct(tp, 0.5), "temps_physics_med": _pct(tph, 0.5),
		"rendu_cpu_med": _pct(cpu, 0.5), "rendu_cpu_p95": _pct(cpu, 0.95),
		"gpu_med": _pct(gpu, 0.5), "gpu_p95": _pct(gpu, 0.95), "gpu_max": _pct(gpu, 1.0),
		"appels": appels / maxf(1, n), "prims": prims / maxf(1, n), "objets": objets / maxf(1, n),
		"pipelines_compiles_pendant_mesure": _pipelines() - _pip0,
		"physique_objets_actifs": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"physique_paires": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		"physique_ilots": Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT),
		"noeuds": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"memoire_statique_mo": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"memoire_video_mo": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"chargement_ms": t_charge_ms,
		"exe_exporte": not OS.has_feature("editor"), "debug": OS.is_debug_build(),
		"godot": Engine.get_version_info().get("string", ""),
		"rendu": RenderingServer.get_current_rendering_method(), "pilote": RenderingServer.get_current_rendering_driver_name(),
		"carte": RenderingServer.get_video_adapter_name(),
		"fenetre": str(DisplayServer.window_get_size()), "rendu_interne": str(get_viewport().get_visible_rect().size),
		"fils": OS.get_processor_count(), "ticks_physique": Engine.physics_ticks_per_second,
		"args": " ".join(OS.get_cmdline_user_args()),
		"date": Time.get_datetime_string_from_system(),
	}
	print("BANC_FPS " + JSON.stringify(r))
	_ecrire(r)
	get_tree().quit(0)

func _ecrire(r: Dictionary) -> void:
	if sortie == "":
		return
	var f := FileAccess.open(sortie, FileAccess.WRITE)
	if f == null:
		push_error("BANC_FPS : écriture impossible de %s (%d)" % [sortie, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(r, "\t"))
	f.close()
