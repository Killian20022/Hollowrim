extends SceneTree
## Perf dans la grotte, plusieurs postes (fenêtre nécessaire, vsync coupé) :
##   godot --path . --disable-vsync --script res://outils/mesure_grotte.gd -- --nouvelle --paisible --res=640x360 [--postes=entree:3,0,0,-8;camp:304,0,15,-6]
## Par poste : 2,5 s de stabilisation puis 4 s mesurées : GPU moyen et PIRE (ms), CPU moyen, appels de dessin, primitives.
const POSTES := "entree:3,0,0,-8;boyau:20,0,0,-3;mine:114,0,0,-4;chambre:137,0,0,-6;lac:214,0,-30,-6;rivage:222,1,-50,-5;camp:304,0,15,-6;cristaux:412,0,0,-4;cache:510,0,0,-3"
const STAB := 2.5
const DUREE := 4.0

var m: Node
var rid: RID
var postes: Array = []
var i := -1
var t := 0.0
var acc := {}

func _init() -> void:
	_demarrer.call_deferred()

func _demarrer() -> void:
	var src := POSTES
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--postes="):
			src = a.substr(9)
	for p in src.split(";"):
		var kv := p.split(":")
		postes.append([kv[0], kv[1]])
	m = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(m)
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for k in 60:
		await process_frame
	m.joueur.mains.visible = false
	_suivant()

func _suivant() -> void:
	i += 1
	if i >= postes.size():
		quit(0)
		return
	m._aller_grotte(postes[i][1])
	t = 0.0
	acc = {"n": 0, "gpu": 0.0, "pire": 0.0, "cpu": 0.0, "appels": 0.0, "prims": 0.0}

func _process(dt: float) -> bool:
	if i < 0 or i >= postes.size():
		return false
	t += dt
	if t < STAB:
		return false
	var g := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	acc["n"] += 1
	acc["gpu"] += g
	acc["pire"] = maxf(acc["pire"], g)
	acc["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	acc["appels"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	acc["prims"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	if t >= STAB + DUREE:
		var n: float = acc["n"]
		print("PERF %-9s gpu_ms=%.2f pire=%.2f cpu_ms=%.2f appels=%d prims=%d" % [postes[i][0], acc["gpu"] / n, acc["pire"], acc["cpu"] / n, int(acc["appels"] / n), int(acc["prims"] / n)])
		_suivant()
	return false
