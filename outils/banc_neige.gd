extends SceneTree
## Micro-banc GPU de la neige (opti effets_lumieres 2026-11-20) : scène minimale (caméra à hauteur d'homme, sol, ciel uni, brume)
## et la neige du jeu (Neige.creer), variantes permutées toutes les --pas s (défaut 1) pendant --tours tours ; écart APPARIÉ au « base »
## voisin (le bruit lent de la machine partagée s'annule). Fenêtre nécessaire (hors écran via godot_slot.sh), vsync coupé :
##   godot --path . --disable-vsync --resolution 640x360 --script res://outils/banc_neige.gd -- --variantes=sans,turb0,fps15,petite [--tours=40]
## Variantes : sans (neige cachée), turb0 (sans turbulence), fps15, fps20, petite (flocons nuls : sommets seuls), moitie (amount_ratio 0,5),
## opti (Neige.creer avec les optimisations), et toute variante ajoutée à _variante().
var neige: GPUParticles3D
var neige_opti: GPUParticles3D
var rid: RID
var variantes: PackedStringArray = []
var tours := 40
var pas := 1.0
var ordre: Array = []      # suite des variantes jouées
var i_ordre := 0
var t := 0.0
var mesures := {}          # i_ordre -> PackedFloat32Array des gpu
var props: Array = []

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	variantes = _arg("variantes", "sans").split(",", false)
	tours = int(_arg("tours", "40"))
	pas = float(_arg("pas", "1.0"))
	var monde := Node3D.new()
	root.add_child(monde)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.40, 0.62)
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.14, 0.22)
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	monde.add_child(we)
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	sol.mesh = pm
	monde.add_child(sol)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.position = Vector3(0, 1.7, 0)
	cam.rotation_degrees = Vector3(-4, 30, 0)
	monde.add_child(cam)
	cam.make_current()
	neige = preload("res://scripts/neige.gd").creer(7)
	monde.add_child(neige)
	neige.global_position = cam.global_position + Vector3(0, 10, 0)
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for k in tours:
		for v in variantes:
			ordre.append("base")
			ordre.append(v)
	ordre.append("base")
	for k in 120:          # préchauffage (shaders, preprocess)
		await process_frame
	print("BANC_NEIGE diag : gpu=%.3f cpu=%.3f appels=%d prims=%d" % [RenderingServer.viewport_get_measured_render_time_gpu(rid), RenderingServer.viewport_get_measured_render_time_cpu(rid), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	_variante(ordre[0])
	set_meta("pret", true)

func _regler(o: Object, prop: String, v: Variant) -> void:
	props.append([o, prop, o.get(prop)])
	o.set(prop, v)

func _variante(v: String) -> void:
	for p: Array in props:
		(p[0] as Object).set(p[1], p[2])
	props.clear()
	match v:
		"sans": _regler(neige, "visible", false)
		"turb0": _regler(neige.process_material, "turbulence_enabled", false)
		"fps15": _regler(neige, "fixed_fps", 15)
		"fps20": _regler(neige, "fixed_fps", 20)
		"moitie": _regler(neige, "amount_ratio", 0.5)
		"petite": _regler(neige.draw_pass_1, "size", Vector2(0.0005, 0.0005))
		"interp0": _regler(neige, "interpolate", false)
		"nofade": _regler(neige.draw_pass_1.material, "distance_fade_mode", BaseMaterial3D.DISTANCE_FADE_DISABLED)
		"aabb": _regler(neige, "visibility_aabb", AABB(Vector3(-30, -20, -30), Vector3(60, 22, 60)))

func _process(dt: float) -> bool:
	if not has_meta("pret"):
		return false
	t += dt
	if t > 0.25:          # 0,25 s de reprise après chaque permutation (pipelines, remplissage)
		if not mesures.has(i_ordre):
			mesures[i_ordre] = PackedFloat32Array()
		(mesures[i_ordre] as PackedFloat32Array).append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	if t >= pas:
		t = 0.0
		i_ordre += 1
		if i_ordre >= ordre.size():
			_bilan()
			quit(0)
			return true
		_variante(ordre[i_ordre])
	return false

func _med(a: PackedFloat32Array) -> float:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2] if b.size() > 0 else 0.0

func _bilan() -> void:
	var base := PackedFloat32Array()
	for i in ordre.size():
		if ordre[i] == "base":
			base.append(_med(mesures.get(i, PackedFloat32Array())))
	print("BANC_NEIGE base gpu médiane=%.3f ms (%d passages, %s)" % [_med(base), base.size(), RenderingServer.get_video_adapter_name()])
	for v in variantes:
		var e := PackedFloat32Array()
		for i in range(1, ordre.size() - 1):
			if ordre[i] == v:
				var b := (_med(mesures.get(i - 1, PackedFloat32Array())) + _med(mesures.get(i + 1, PackedFloat32Array()))) * 0.5
				e.append(_med(mesures.get(i, PackedFloat32Array())) - b)
		var s := e.duplicate()
		s.sort()
		var q1: float = s[s.size() / 4]
		var q3: float = s[s.size() * 3 / 4]
		print("BANC_NEIGE %-8s écart apparié médiane=%+.3f ms (quartiles %+.3f / %+.3f, %d paires)" % [v, _med(e), q1, q3, e.size()])
