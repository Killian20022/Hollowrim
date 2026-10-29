extends SceneTree
## Lot L9 : coût des objets uniques à l'écran (FENÊTRE hors écran via godot_slot.sh, vsync coupé) : à trois postes (trône, armurerie,
## forge), appels de dessin, primitives et temps GPU du viewport, objet unique VISIBLE puis CACHÉ (moyenne sur 120 images chacun).
##   godot --path . --disable-vsync --audio-driver Dummy --script res://outils/mesure_l9.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D

func _init() -> void:
	_go.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _regarder(cible: Vector3, dist: float, lacet: float, sol_y: float) -> void:
	var j: CharacterBody3D = m.joueur
	var d := Vector3(sin(lacet), 0, cos(lacet))
	j.global_position = Vector3(cible.x, sol_y + 0.05, cible.z) + d * dist
	j.velocity = Vector3.ZERO
	j.rotation.y = atan2(d.x, d.z)
	await _images(20)
	var v := cible - j.camera.global_position
	j.tete.rotation.x = atan2(v.y, Vector2(v.x, v.z).length())
	await _images(30)

func _mesure() -> Array:
	var vp := root.get_viewport().get_viewport_rid()
	var dc := 0.0
	var pr := 0.0
	var gpu := 0.0
	for i in 120:
		await process_frame
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		pr += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return [dc / 120.0, pr / 120.0, gpu / 120.0]

func _poste(nom: String, u: ObjetUnique) -> void:
	u.visible = true
	await _images(10)
	var a := await _mesure()
	u.visible = false
	await _images(10)
	var b := await _mesure()
	u.visible = true
	print("L9 %-10s visible : %4.0f appels, %6.0f prim., GPU %.3f ms | caché : %4.0f appels, %6.0f prim., GPU %.3f ms | écart %+.0f appels, %+.0f prim., %+.3f ms" %
		[nom, a[0], a[1], a[2], b[0], b[1], b[2], a[0] - b[0], a[1] - b[1], a[2] - b[2]])

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(30)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport().get_viewport_rid(), true)
	m.hud.aide_t = 0.0
	var t: Node3D = m.tertre
	t.attendre_donjon()
	t._basculer(true)
	await _images(90)
	if m.draugrs.has("jarl") and is_instance_valid(m.draugrs["jarl"]):
		m.draugrs["jarl"].global_position += Vector3(0, -50, 0)
	var hache: ObjetUnique = t._uniques["unique_hache_kolbeinn"]
	var assise: Transform3D = (t.crypte as Node3D).global_transform * (t.d2.get_meta("trone_assise") as Transform3D)
	var av := assise.basis.z
	await _regarder(hache.global_position, 1.6, atan2(av.x, av.z) + 0.4, assise.origin.y - 0.56)
	await _poste("trone", hache)
	var obs: ObjetUnique = t._uniques["unique_epee_obsidienne"]
	var fo := -(obs.global_basis.z)
	var op := obs.global_position + obs.global_basis.y * 0.42
	await _regarder(op, 1.6, atan2(fo.x, fo.z), op.y - 1.45)
	await _poste("armurerie", obs)
	t._basculer(false)
	await _images(20)
	m.quetes.etat["lames_brodd"] = 3
	m.quetes.change.emit()
	var uf: ObjetUnique = m.unique_forge
	var sp := uf.global_position + uf.global_basis.y * 0.42
	var ff := -(uf.global_basis.z)
	await _regarder(sp, 1.6, atan2(ff.x, ff.z), sp.y - 1.45)
	await _poste("forge", uf)
	quit()
