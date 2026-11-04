extends SceneTree
## Mesure GPU du relief de la neige dans la zone témoin (-44,-26) : le joueur y est posé, une piste de pas et de course est
## écrite dans le masque, la caméra regarde la piste ; 3 s de stabilisation puis 12 s de moyenne (médiane et 10e centile aussi).
##   godot --path . --disable-vsync --script res://outils/mesure_perf_relief.gd -- --nouvelle --paisible --heure=12 [--sans-couche] [--sans-traces]
var monde: Node3D
var t := 0.0
var n := 0
var gpu := 0.0
var echant := PackedFloat32Array()
var rid: RID
var pret := false

func _arg(nom: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + nom)

func _init() -> void:
	EffetsSol.sans_couche = _arg("sans-couche")
	monde = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child.call_deferred(monde)
	_demarrer.call_deferred()

func _demarrer() -> void:
	var t0 := Time.get_ticks_msec()
	while monde.get("joueur") == null and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
	var j: CharacterBody3D = monde.joueur
	for i in 200:
		await process_frame
	var cam := Camera3D.new()
	cam.far = 90.0
	root.add_child(cam)
	cam.current = true
	var spot := Vector3(-44, monde.hauteur(-44, -26), -26)
	j.global_position = spot + Vector3(0, 0.15, 0)
	j.basculer_vue(true)
	cam.current = true
	for i in 90:
		await process_frame
	var e := EffetsSol.obtenir()
	if not _arg("sans-traces"):
		e._suivre_joueur(j)
		for k in 12:
			e._empreinte(Vector3(spot.x, 0, spot.z - 1.0 - k * 0.7), Vector2(0, -1), k % 2 == 0, false)
		for k in 8:
			e._empreinte(Vector3(spot.x - 2.5, 0, spot.z - 1.0 - k * 0.95), Vector2(0, -1), k % 2 == 0, true)
		e._envoyer()
	e._joueur = j
	cam.global_position = j.global_position + Vector3(2.6, 2.3, 5.2)
	cam.look_at(j.global_position + Vector3(-1.0, 0.0, -2.0), Vector3.UP)
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	pret = true

func _process(delta: float) -> bool:
	if not pret:
		return false
	t += delta
	EffetsSol.saut_de_temps(0.0)
	if t < 3.0:
		return false
	n += 1
	var g := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	gpu += g
	echant.append(g)
	if t >= 15.0:
		echant.sort()
		print("MESURE gpu_ms=%.2f gpu_med=%.2f gpu_p10=%.2f images=%d relief_visible=%s sans_couche=%s" % [gpu / n, echant[n / 2], echant[n / 10], n, str(EffetsSol.instance._couche != null and EffetsSol.instance._couche.visible), str(EffetsSol.sans_couche)])
		quit(0)
	return false
