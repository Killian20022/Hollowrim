extends SceneTree
## Audit de performance des donjons : PARCOURS scriptés (pas des points fixes) dans la crypte ou la grotte (fenêtre, vsync coupé) :
##   godot --path . --disable-vsync --script res://outils/audit_perf.gd -- --nouvelle --cible=crypte|grotte [--vivant] [--vitesse=6.5] [--exp=a,b=3] [--csv=/tmp/x.csv] [--seul=nom]
## Par tronçon : temps réel par image (moyenne, p99, pire, nb > 16,7 ms et > 33 ms), CPU/GPU du viewport, appels de dessin, primitives, objets,
## lumières allumées, nœuds. `--vivant` : ennemis actifs (le joueur est invulnérable) ; sinon ils sont figés (--paisible implicite NON : on ne passe pas le drapeau).
## Interrupteurs d'expérience (--exp=) : voir _appliquer_exp.
const SCENE := preload("res://scenes/foret_test.tscn")

# (nom, [[x, z, y]...]) repère de la crypte (x est, z sud ; l'entrée est en z=+4 ; étage inférieur y=-6)
const CRYPTE := [
	["colonne", [[0, 0.5, 0], [0, -12, 0], [0, -25, 0], [0, -48, 0], [0, -58, 0], [0, -66, 0]]],
	["arene", [[0, -66, 0], [-7, -71, 0], [0, -77, 0], [7, -71, 0], [0, -66, 0], [-5, -72, 0], [5, -72, 0], [0, -62, 0]]],
	["tombeau", [[0, -71, 0], [9, -72, 0], [18, -72, 0], [20, -76, 0], [16, -69, 0]]],
	["aile_ouest", [[0, -25, 0], [-7, -19.8, 0], [-18, -19.8, 0], [-21, -16, 0], [-25, -26, 0], [-25, -36, 0], [-29, -43, 0], [-38, -44, 0]]],
	["aile_est", [[0, -25, 0], [0, -29.7, 0], [14, -29.7, 0], [26, -26, 0], [39, -30, 0], [51, -30, 0], [56, -30, 0]]],
	["etage_bas", [[-16, -32, 0], [-16, -43, -6], [-2, -43, -6], [3, -43, -6], [6, -46, -6], [6, -52, -6], [13, -52, -6], [22, -53, -6], [13, -52, -6], [6, -52, -6], [6, -46, -6], [3, -43, -6], [-2, -43, -6], [-14, -43, -6], [-25, -43, -6], [-35, -43, -6]]],
	["combat_arene", [[5, -71, 0], [0, -66, 0], [-5, -71, 0], [0, -76, 0], [5, -71, 0], [0, -66, 0], [-5, -71, 0], [0, -76, 0], [5, -71, 0], [0, -66, 0], [-5, -71, 0], [0, -76, 0], [5, -71, 0]]],
	["quartiers", [[0, -25, 0], [8, -29.7, 0], [24, -20, 0], [24, -13.5, 0], [21, -4, 0], [30, -4, 0]]],
]

var m: Node3D
var rid: RID
var cible := "crypte"
var vitesse := 6.5
var exps := {}
var vivant := false
var seul := ""
var tron: Array = []         # [nom, points Vector3 monde]
var ti := -1
var pts: Array = []
var pi := 0
var dist_tot := 0.0
var attente := 0
var prec_us := 0
var rec: Dictionary = {}
var tous: Array = []         # tous les tronçons : lignes de résumé
var pires: Array = []        # [ms, tronçon, position]
var csv_f: FileAccess
var phase := "init"
var t_attente := 0.0
var skip := 0
var _t_pf := 0
var _t_pre := 0
var _t_post := 0
var _a := 0.0   # process_frame -> pre_draw : _process des nœuds, animations, mises à jour de la scène
var _b := 0.0   # pre_draw -> post_draw : soumission du rendu (+ attente GPU éventuelle)
var _c := 0.0   # post_draw -> process_frame suivant : présentation, événements, physique

func _init() -> void:
	_demarrer.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _demarrer() -> void:
	cible = _arg("cible", "crypte")
	vitesse = float(_arg("vitesse", "6.5"))
	vivant = _arg("vivant") != ""
	seul = _arg("seul")
	for e in _arg("exp").split(",", false):
		var kv := e.split("=")
		exps[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var csv := _arg("csv")
	if csv != "":
		csv_f = FileAccess.open(csv, FileAccess.WRITE)
		if csv_f == null:
			print("CSV impossible : ", csv)
			quit(2)
			return
		csv_f.store_line("troncon,t,dt_ms,cpu_ms,gpu_ms,appels,prims,objets,phys_ms,sol,x,y,z")
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
	print("AUDIT moteur physique : %s | args: %s" % [ProjectSettings.get_setting("physics/3d/physics_engine"), OS.get_cmdline_args()])
	var t0 := Time.get_ticks_msec()
	m = SCENE.instantiate()
	root.add_child(m)
	print("AUDIT chargement monde (instanciation) %d ms" % (Time.get_ticks_msec() - t0))
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for k in 60:
		await process_frame
	m.joueur.mains.visible = false
	# on laisse le fil de construction finir (mesure à part du coût d'entrée)
	if cible == "crypte":
		var tt := Time.get_ticks_msec()
		while not m.tertre._donjon_pret() and Time.get_ticks_msec() - tt < 60000:
			await process_frame
		print("AUDIT donjon prêt (fil + pose en tranches) après %d ms de jeu" % (Time.get_ticks_msec() - tt))
		var t1 := Time.get_ticks_usec()
		m.tertre._basculer(true)
		print("AUDIT entrée crypte (_basculer) : %.1f ms" % ((Time.get_ticks_usec() - t1) / 1000.0))
		m._sous_terre(true)
	else:
		var tt2 := Time.get_ticks_msec()
		while m.grotte_acces.grotte == null and Time.get_ticks_msec() - tt2 < 60000:
			await process_frame
		print("AUDIT grotte prête (fil de fond + pose) après %d ms de jeu" % (Time.get_ticks_msec() - tt2))
		var t1 := Time.get_ticks_usec()
		m.grotte = m.grotte_acces.obtenir()
		print("AUDIT grotte obtenir (construction si pas prête) : %.1f ms" % ((Time.get_ticks_usec() - t1) / 1000.0))
		m.grotte_acces.montrer(true)
		m._sous_terre(true)
		m.grotte.ambiance(m._env)
	_appliquer_exp()
	_preparer_parcours()
	# 1 s d'arrêt à l'entrée : mesure des premières images (compilation, pose différée)
	phase = "entree"
	rec = _neuf("entree")
	var p0: Vector3 = tron[0][1][0]
	m.joueur.global_position = p0
	t_attente = 0.0
	prec_us = Time.get_ticks_usec()

func _preparer_parcours() -> void:
	tron.clear()
	if cible == "crypte":
		for t in CRYPTE:
			var l: Array = []
			for p in t[1]:
				l.append(m.tertre.crypte.to_global(Vector3(p[0], p[2] + 0.1, p[1])))
			tron.append([t[0], l])
	else:
		var g: Node = m.grotte
		var routes: Dictionary = g.routes_test()
		for id in routes:
			var l: Array = []
			var pp: Array = routes[id]
			for p in pp:
				l.append(p)
			if l.size() > 1:
				tron.append(["branche_" + id, l])
	if seul != "":
		tron = tron.filter(func(t): return t[0] == seul or t[0].begins_with(seul))

func _neuf(nom: String) -> Dictionary:
	return {"nom": nom, "dt": PackedFloat32Array(), "cpu": 0.0, "gpu": 0.0, "appels": 0.0, "prims": 0.0, "objets": 0.0, "lum": 0.0, "proc": 0.0, "phys": 0.0, "obj_phys": 0.0, "paires": 0.0, "iles": 0.0, "A": 0.0, "B": 0.0, "C": 0.0, "n": 0, "gpu_max": 0.0, "appels_max": 0, "t": 0.0}

func _lumieres() -> int:
	var n := 0
	for l in (m.tertre.crypte if cible == "crypte" else m.grotte).find_children("*", "Light3D", true, false):
		if l is Light3D and l.is_visible_in_tree() and (l as Light3D).light_energy > 0.0:
			n += 1
	return n

func _process(dt: float) -> bool:
	if phase == "init":
		return false
	var now := Time.get_ticks_usec()
	var d_ms := (now - prec_us) / 1000.0
	prec_us = now
	var j: CharacterBody3D = m.joueur
	j.vie = j.vie_max
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(rid)
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	if gpu > 200.0 or gpu < 0.0:
		gpu = 0.0
	var appels := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objets := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	if skip > 0 and phase == "marche":
		skip -= 1
		pires.append([0.0, "", Vector3.ZERO, 0.0, 0.0, 0])
	elif phase == "entree" or phase == "marche":
		rec["dt"].append(d_ms)
		rec["cpu"] += cpu
		rec["gpu"] += gpu
		rec["appels"] += appels
		rec["prims"] += prims
		rec["objets"] += objets
		rec["proc"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		rec["phys"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		rec["obj_phys"] += Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
		rec["paires"] += Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
		rec["iles"] += Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)
		rec["A"] += _a
		rec["B"] += _b
		rec["C"] += _c
		rec["n"] += 1
		rec["t"] += d_ms
		rec["gpu_max"] = maxf(rec["gpu_max"], gpu)
		rec["appels_max"] = maxi(rec["appels_max"], appels)
		pires.append([d_ms, rec["nom"], j.global_position, cpu, gpu, appels])
		if csv_f != null:
			csv_f.store_line("%s,%.3f,%.2f,%.2f,%.2f,%d,%d,%d,%.2f,%d,%.1f,%.1f,%.1f" % [rec["nom"], rec["t"], d_ms, cpu, gpu, appels, prims, objets, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 1 if j.is_on_floor() else 0, j.global_position.x, j.global_position.y, j.global_position.z])
	if phase == "entree":
		t_attente += dt
		if t_attente > 1.5:
			rec["lum"] = _lumieres()
			_clore()
			_tronc_suivant()
		return false
	if phase == "marche":
		var ordre_lum: bool = rec["n"] % 30 == 0
		if ordre_lum:
			_exp_ennemis()
			rec["lum"] = maxf(rec["lum"], _lumieres())
		var reste := vitesse * dt
		while reste > 0.0 and pi < pts.size() - 1:
			var a: Vector3 = pts[pi]
			var b: Vector3 = pts[pi + 1]
			var seg := a.distance_to(b)
			var avance := dist_tot
			if avance + reste >= seg:
				reste -= seg - avance
				dist_tot = 0.0
				pi += 1
			else:
				dist_tot += reste
				reste = 0.0
		if pi >= pts.size() - 1:
			_clore()
			_tronc_suivant()
			return false
		var a2: Vector3 = pts[pi]
		var b2: Vector3 = pts[pi + 1]
		var u := dist_tot / maxf(a2.distance_to(b2), 0.001)
		var pos := a2.lerp(b2, u)
		j.global_position = pos
		j.velocity = Vector3.ZERO
		var dir := b2 - a2
		dir.y = 0.0
		if dir.length() > 0.05:
			j.rotation.y = lerp_angle(j.rotation.y, atan2(-dir.x, -dir.z), 0.15)
		j.tete.rotation.x = 0.0
	return false

func _clore() -> void:
	var n: int = rec["n"]
	if n == 0:
		return
	var dt: PackedFloat32Array = rec["dt"]
	var tri := dt.duplicate()
	tri.sort()
	var moy := 0.0
	var s16 := 0
	var s33 := 0
	for v in dt:
		moy += v
		if v > 16.7:
			s16 += 1
		if v > 33.0:
			s33 += 1
	moy /= n
	var l := "TRONCON %-14s n=%4d dt moy=%5.2f p50=%5.2f p99=%5.2f max=%6.1f ms | >16,7: %3d (%4.1f%%)  >33: %2d | cpu=%5.2f gpu=%5.2f (max %5.2f) | appels=%4d (max %d) prims=%6d obj=%4d lum=%d | phys=%.2f (obj %.0f paires %.0f) A=%.2f B=%.2f C=%.2f" % [
		rec["nom"], n, moy, tri[n / 2], tri[mini(n - 1, int(n * 0.99))], tri[n - 1], s16, 100.0 * s16 / n, s33,
		rec["cpu"] / n, rec["gpu"] / n, rec["gpu_max"], int(rec["appels"] / n), rec["appels_max"], int(rec["prims"] / n), int(rec["objets"] / n), int(rec["lum"]), rec["phys"] / n, rec["obj_phys"] / n, rec["paires"] / n, rec["A"] / n, rec["B"] / n, rec["C"] / n]
	print(l)
	tous.append(rec.duplicate())

func _tronc_suivant() -> void:
	ti += 1
	if ti >= tron.size():
		_fin()
		return
	pts = tron[ti][1]
	pi = 0
	dist_tot = 0.0
	rec = _neuf(tron[ti][0])
	if tron[ti][0] == "combat_arene":
		# combat de l'arène : Svanhild levée et éveillée à 40 % de vie (phase 2 : squelettes + souffle), tous les ennemis alertés
		m.tertre._lever_svanhild()
		var boss: Node = m.draugrs.get("svanhild")
		if boss != null:
			boss.vie = boss.vie_max * 0.4
		skip = 6
		for e in get_nodes_in_group("ennemis"):
			if e.has_method("alerter") and e.global_position.distance_to(pts[0]) < 40.0:
				e.alerter()
	phase = "marche"
	m.joueur.global_position = pts[0]
	m.joueur.velocity = Vector3.ZERO

func _fin() -> void:
	phase = "fin"
	if exps.has("liste"):
		_recensement()
	pires.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(12, pires.size()):
		var p = pires[i]
		print("PIRE #%d %6.1f ms  %-14s pos=(%.1f,%.1f,%.1f) cpu=%.2f gpu=%.2f appels=%d" % [i + 1, p[0], p[1], p[2].x, p[2].y, p[2].z, p[3], p[4], p[5]])
	var tot := 0
	var s16 := 0
	var s33 := 0
	var tsum := 0.0
	for r in tous:
		for v in r["dt"]:
			tot += 1
			tsum += v
			if v > 16.7: s16 += 1
			if v > 33.0: s33 += 1
	print("TOTAL %s images=%d moyenne=%.2f ms (%.0f i/s) >16,7: %.1f%%  >33: %d  | mémoire statique %.0f Mo, vidéo %.0f Mo, objets %d, nœuds %d, orphelins %d" % [
		cible, tot, tsum / maxf(tot, 1), 1000.0 * tot / maxf(tsum, 1.0), 100.0 * s16 / maxf(tot, 1), s33,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	if csv_f != null:
		csv_f.close()
	quit(0)

# ------------------------------------------------------------------ expériences
func _appliquer_exp() -> void:
	var racine: Node = m.tertre.crypte if cible == "crypte" else m.grotte
	if exps.has("cacher"):
		racine.visible = false
	if exps.has("liste"):
		_recensement()
	for cat in ["villageois", "draugr", "dragon", "village", "cycle", "hud"]:
		if exps.has("w_" + cat):
			for c in m.find_children("*", "", true, false):
				var sc: Script = c.get_script()
				if sc != null and sc.resource_path.get_file().begins_with(cat) and not (c in [m.tertre, m.grotte_acces]):
					if cat == "draugr" and m.joueur.global_position.distance_to(c.global_position) < 80.0:
						continue
					c.process_mode = Node.PROCESS_MODE_DISABLED
	if exps.has("monde_off"):
		var garde := [m.joueur, m.tertre, m.grotte_acces, m.hud, m.post, m.dialogue, m.quetes]
		for c in m.get_children():
			if c in garde or c is Camera3D or c is WorldEnvironment:
				continue
			if c is Node3D or c is Node:
				if c.name in ["Village", "Villageois"] or c.get_script() != null or c is CharacterBody3D:
					c.process_mode = Node.PROCESS_MODE_DISABLED
	if exps.has("mat_simple"):     # coût des shaders : tout en matériau non éclairé simple (même géométrie, mêmes appels)
		var simple := StandardMaterial3D.new()
		simple.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		simple.albedo_color = Color(0.3, 0.3, 0.35)
		for n in racine.find_children("*", "MeshInstance3D", true, false):
			(n as MeshInstance3D).material_override = simple
	if exps.has("sans_transp"):
		for n in racine.find_children("*", "MeshInstance3D", true, false):
			var mt: Material = (n as MeshInstance3D).material_override
			if mt is BaseMaterial3D and (mt as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				n.visible = false
	if exps.has("lum_max"):        # garde les N lumières les plus proches de l'entrée allumées en permanence : sinon N par zone via tertre
		pass
	if exps.has("coque_off"):
		for cs in racine.find_children("*", "CollisionShape3D", true, false):
			(cs as CollisionShape3D).disabled = true
	if exps.has("stats"):
		_stats(racine)
	if exps.has("ombres_off"):
		for l in m.find_children("*", "Light3D", true, false):
			(l as Light3D).shadow_enabled = false
	if exps.has("lune_off"):
		for l in m.find_children("*", "DirectionalLight3D", true, false):
			(l as Light3D).visible = false
	if exps.has("lum_off"):
		for l in racine.find_children("*", "OmniLight3D", true, false):
			(l as OmniLight3D).omni_range = 0.05
		for l in racine.find_children("*", "SpotLight3D", true, false):
			(l as SpotLight3D).spot_range = 0.05
	if exps.has("vr"):
		var r := float(exps["vr"])
		for n in racine.find_children("*", "GeometryInstance3D", true, false):
			(n as GeometryInstance3D).visibility_range_end = r
			(n as GeometryInstance3D).visibility_range_end_margin = 0.0
	if exps.has("particules_off"):
		for p in racine.find_children("*", "GPUParticles3D", true, false):
			p.visible = false
	if exps.has("ennemis_off"):
		for n in m.get_tree().get_nodes_in_group("ennemis"):
			n.process_mode = Node.PROCESS_MODE_DISABLED
	if exps.has("post_off") and m.get("post") != null:
		m.post.get_parent().visible = false
	if exps.has("sans_physique_ennemis"):
		pass
	if exps.has("res"):   # échelle de rendu (fraction) pour juger si le coût est lié aux pixels
		root.scaling_3d_scale = float(exps["res"])

func _recensement() -> void:
	var par := {}
	for c in m.find_children("*", "", true, false):
		var sc: Script = c.get_script()
		var k: String = sc.resource_path.get_file() if sc != null else "(" + c.get_class() + ")"
		var e: Array = par.get(k, [0, 0, 0])
		e[0] += 1
		if c.is_processing(): e[1] += 1
		if c.is_physics_processing(): e[2] += 1
		par[k] = e
	var ks := par.keys()
	ks.sort_custom(func(a, b): return par[a][0] > par[b][0])
	for k in ks:
		print("SCRIPT %-34s n=%5d process=%4d physics=%4d" % [k, par[k][0], par[k][1], par[k][2]])


func _exp_ennemis() -> void:
	for e in get_nodes_in_group("ennemis"):
		if exps.has("en_gel"):
			e.process_mode = Node.PROCESS_MODE_DISABLED
		if exps.has("en_phys_off"):
			e.set_physics_process(false)
		for n in e.find_children("*", "", true, false):
			if n is SkeletonModifier3D:
				var sc: Script = n.get_script()
				var nom: String = sc.resource_path.get_file() if sc != null else ""
				if exps.has("en_mod_off") or (exps.has("en_pieds_off") and nom == "pieds_au_sol.gd") or (exps.has("en_raideur_off") and nom == "draugr_raideur.gd"):
					n.active = false
			elif n is AnimationPlayer and exps.has("en_anim_off"):
				n.active = false
			elif n is MeshInstance3D and exps.has("en_mesh_off"):
				n.visible = false

func _stats(racine: Node) -> void:
	var cl := {}
	var tris := 0
	for n in racine.find_children("*", "Node", true, false):
		cl[n.get_class()] = cl.get(n.get_class(), 0) + 1
	var mats := {}
	var nmi := 0
	var lum_omni := 0
	var lum_spot := 0
	var ombres := 0
	var transp := 0
	var ncoll := 0
	for n in racine.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		nmi += 1
		var mt: Material = mi.material_override if mi.material_override != null else (mi.get_active_material(0) if mi.mesh != null else null)
		if mt != null:
			mats[mt] = 1
			if mt is BaseMaterial3D and (mt as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				transp += 1
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				tris += ix.size() / 3 if ix.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	for l in racine.find_children("*", "Light3D", true, false):
		if l is OmniLight3D: lum_omni += 1
		if l is SpotLight3D: lum_spot += 1
		if (l as Light3D).shadow_enabled: ombres += 1
	for n in racine.find_children("*", "CollisionShape3D", true, false):
		ncoll += 1
	print("STATS %s : %d nœuds ; classes %s" % [cible, racine.find_children("*", "Node", true, false).size(), cl])
	for cs in racine.find_children("*", "CollisionShape3D", true, false):
		var sh = (cs as CollisionShape3D).shape
		if sh is ConcavePolygonShape3D:
			print("STATS trimesh %s : %d triangles, AABB taille %s" % [cs.name, (sh as ConcavePolygonShape3D).get_faces().size() / 3, str((sh as ConcavePolygonShape3D).get_debug_mesh().get_aabb().size)])
	print("STATS MeshInstance3D=%d matériaux distincts=%d triangles(total)=%d transparents=%d | omni=%d spot=%d avec ombre=%d | CollisionShape3D=%d" % [nmi, mats.size(), tris, transp, lum_omni, lum_spot, ombres, ncoll])
