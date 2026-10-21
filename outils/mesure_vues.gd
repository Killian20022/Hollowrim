extends SceneTree
## Mesure de perf PAR VUE pendant un lot de captures (audit graphique, refonte) — ne modifie pas le jeu.
## Lance la scène principale en mode --captures ; chaque vue reste posée `attente=N` images ; on échantillonne
## le temps GPU/CPU du viewport, les appels de dessin et les primitives, en ignorant les 60 premières images de
## chaque vue (compilation des shaders, stabilisation). Une vue = un changement de position du joueur > 0,3 m.
##   godot --path . --disable-vsync --script res://outils/mesure_vues.gd -- --captures=<poses> --sortie=<dossier> --nouvelle --paisible [--res=640x360]
## Sortie : lignes « VUE i pos=… gpu_ms=… cpu_ms=… appels=… primitives=… images=… » à la fin.
const IGNORER := 60

var monde: Node
var rid: RID
var pos_prec := Vector3.INF
var vues: Array = []   # [{pos, n, gpu, cpu, appels, prims, vues}]
var depuis := 0
var taille := ""

func _init() -> void:
	_demarrer.call_deferred()

func _demarrer() -> void:
	monde = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(monde)
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)

func _process(_dt: float) -> bool:
	if monde == null or not is_instance_valid(monde):
		return false
	var j = monde.get("joueur")
	if j == null or not is_instance_valid(j) or not monde.get("village") or not monde.village.prets:
		return false
	taille = str(root.get_window().content_scale_size)
	var p: Vector3 = j.global_position
	if p.distance_to(pos_prec) > 0.3:
		pos_prec = p
		depuis = 0
		vues.append({"pos": p, "n": 0, "gpu": 0.0, "cpu": 0.0, "appels": 0.0, "prims": 0.0, "pire": 0.0})
		return false
	depuis += 1
	if depuis < IGNORER or vues.is_empty():
		return false
	var v: Dictionary = vues[-1]
	var g := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	v["n"] += 1
	v["gpu"] += g
	v["pire"] = maxf(v["pire"], g)
	v["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	v["appels"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	v["prims"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	return false

func _finalize() -> void:
	var i := 0
	for v in vues:
		if v["n"] < 10:
			continue
		var n: float = v["n"]
		print("VUE %d pos=(%.1f,%.1f,%.1f) gpu_ms=%.2f gpu_pire=%.2f cpu_ms=%.2f appels=%d primitives=%d images=%d taille=%s" % [
			i, v["pos"].x, v["pos"].y, v["pos"].z, v["gpu"] / n, v["pire"], v["cpu"] / n, v["appels"] / n, v["prims"] / n, n,
			taille])
		i += 1
