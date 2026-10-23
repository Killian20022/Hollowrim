extends SceneTree
## Coût de rendu et de création : N draugrs vs N squelettes vs aucun, même caméra dans la crypte, en alternance (3 tours).
##   godot --path . --script res://outils/mesure_squelettes.gd -- --nouvelle --paisible [--n=6]
const ORIGINE := Vector3(0.0, 0.0, -26.5)
var m: Node3D

func _init() -> void:
	m = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _lancer() -> void:
	for i in 30:
		await process_frame
	var t = m.tertre
	t._basculer(true)
	await create_timer(1.0).timeout
	m.post.set_shader_parameter("fondu", 0.0)
	var c: Node3D = t.crypte
	var n := int(_arg("n", "6"))
	var j = m.joueur
	j.global_position = c.to_global(ORIGINE + Vector3(0, 0.1, 4.0))
	j.rotation.y = c.global_rotation.y
	var groupes := {}
	for ty in ["draugr", "squelette"]:
		var l: Array = []
		var t0 := Time.get_ticks_usec()
		for i in n:
			var x := (i - (n - 1) * 0.5) * 1.0
			var types := ["squelette", "squelette_archer", "squelette"] if ty == "squelette" else ["draugr", "draugr", "draugr"]
			var d: CharacterBody3D = m.creer_draugr(types[i % 3], c.to_global(ORIGINE + Vector3(x, 0.05, 0)), c.global_rotation.y, true, {"ident": "mes_%s_%d" % [ty, i], "debout": true})
			l.append(d)
		print("CREATION %s : %.2f ms pour %d (%.2f ms/ennemi)" % [ty, (Time.get_ticks_usec() - t0) / 1000.0, n, (Time.get_ticks_usec() - t0) / 1000.0 / n])
		groupes[ty] = l
	for i in 10:
		await process_frame
	for ty in groupes:
		for d: CharacterBody3D in groupes[ty]:
			d.anim.speed_scale = 1.0
			d.anim.play("Sword_Idle")
			d.set_physics_process(false)
	var res := {"aucun": [], "draugr": [], "squelette": []}
	for tour in 3:
		for cas in ["aucun", "draugr", "squelette"]:
			for ty in groupes:
				for d: CharacterBody3D in groupes[ty]:
					d.visible = ty == cas
			res[cas].append(await _mesurer())
	for cas in res:
		var g := 0.0
		var cpu := 0.0
		for r in res[cas]:
			g += r[0] / 3.0
			cpu += r[1] / 3.0
		print("RENDU %-9s gpu=%.3f ms cpu=%.3f ms appels=%d primitives=%d" % [cas, g, cpu, res[cas][0][2], res[cas][0][3]])
	quit(0)

func _mesurer() -> Array:
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 30:
		await RenderingServer.frame_post_draw
	var g := 0.0
	var cpu := 0.0
	for i in 120:
		await RenderingServer.frame_post_draw
		g += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	var appels := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	return [g / 120.0, cpu / 120.0, appels, prims]
