extends SceneTree
## Mesure de performance : charge la scène principale, laisse 10 s de stabilisation puis moyenne
## sur 20 s : temps GPU/CPU du viewport, draw calls, primitives. Fenêtre nécessaire (pas --headless).
##   godot --path . --disable-vsync --script outils/mesure_perf.gd -- --nouvelle --paisible --pose=2.5,8.5,16,4
const STABILISATION := 10.0
const DUREE := 20.0

var t := 0.0
var n := 0
var gpu := 0.0
var cpu := 0.0
var appels := 0.0
var prims := 0.0
var rid: RID

func _init() -> void:
	_demarrer.call_deferred()

func _demarrer() -> void:
	root.add_child((load("res://scenes/foret_test.tscn") as PackedScene).instantiate())
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)

func _process(delta: float) -> bool:
	t += delta
	if t < STABILISATION:
		return false
	n += 1
	gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	appels += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	if t >= STABILISATION + DUREE:
		print("MESURE gpu_ms=%.2f cpu_ms=%.2f draw_calls=%d primitives=%d images=%d fps=%.0f" % [gpu / n, cpu / n, appels / n, prims / n, n, n / DUREE])
		quit(0)
	return false
