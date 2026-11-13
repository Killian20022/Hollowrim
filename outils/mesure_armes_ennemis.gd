extends SceneTree
## Coût des armes des ennemis : une salle de crypte PLEINE (24 ennemis en vue : draugrs, squelettes, bandits), mesurée AVEC leurs armes du catalogue
## puis SANS (armes retirées des mains), même caméra, mêmes corps animés ; ms de rendu CPU / GPU par image (RenderingServer, moyenne et pire image).
## FENÊTRE (godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/mesure_armes_ennemis.gd -- --nouvelle [--n=24] [--images=240]
const SCENE := preload("res://scenes/foret_test.tscn")

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _tris(n: Node) -> int:
	var t := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			t += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
	return t

func _mesurer(images: int, vp: RID, etiquette: String) -> Dictionary:
	for i in 40:
		await process_frame
	var cpu := 0.0
	var gpu := 0.0
	var pire := 0.0
	var tri := 0.0
	for i in images:
		await RenderingServer.frame_post_draw
		var c := RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		var g := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += c
		gpu += g
		pire = maxf(pire, g)
		tri += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var r := {"cpu": cpu / images, "gpu": gpu / images, "gpu_pire": pire, "primitives": tri / images}
	print("MESURE %s : CPU rendu %.2f ms, GPU %.2f ms (pire %.2f), %.0f k primitives par image" % [etiquette, r["cpu"], r["gpu"], r["gpu_pire"], r["primitives"] / 1000.0])
	return r

func _go() -> void:
	var n := int(_arg("n", "24"))
	var images := int(_arg("images", "240"))
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	current_scene = m
	var j: CharacterBody3D = m.joueur
	for i in 5:
		await physics_frame
	var t = m.tertre
	t._passer(true)
	for i in 1200:
		if t.dedans:
			break
		await process_frame
	await create_timer(1.6, true, false, true).timeout
	m.post.set_shader_parameter("fondu", 0.0)
	var c: Node3D = t.crypte
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	j.global_position = c.to_global(Vector3(0.0, 0.1, -22.5))
	for k in 20:
		t._gerer_zones()
		await physics_frame
	for id in m.draugrs.keys():
		var d = m.draugrs[id]
		if is_instance_valid(d):
			d.visible = false
			d.process_mode = Node.PROCESS_MODE_DISABLED
			d.global_position += Vector3(0, -50, 0)
	var lacet := c.global_rotation.y
	var corps: Array[CharacterBody3D] = []
	var app_b := GrotteJeu.apparence_humain(1, "")
	for k in n:
		var type: String = ["sbire", "squelette", "sbire", "guerrier"][k % 4]
		var opts := {"ident": "mes_%d" % k, "dort": false}
		if k % 4 == 2:
			opts["apparence"] = app_b
		var col := k % 6
		var rang := k / 6
		var pos := c.to_global(Vector3(-3.6 + col * 1.4, 0.05, -27.0 - rang * 1.5))
		var e: CharacterBody3D = m.creer_draugr(type, pos, lacet, false, opts)
		e.global_position = pos
		corps.append(e)
	await physics_frame
	for e in corps:
		e.set_physics_process(false)
		e.set_process(false)
	var cam := Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	cam.global_position = c.to_global(Vector3(0.0, 1.7, -21.5))
	cam.look_at(c.to_global(Vector3(0.0, 1.0, -28.5)))
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var armes := 0
	var tris_avec := 0
	var vus := {}
	for e in corps:
		var id := ArmesEnnemis.arme_de(e.modele)
		if id != "":
			armes += 1
			vus[id] = int(vus.get(id, 0)) + 1
		tris_avec += _tris(e.modele)
	print("SALLE : %d ennemis, %d armés du catalogue %s, %d triangles de corps + armes" % [n, armes, str(vus), tris_avec])
	var avec: Dictionary = await _mesurer(images, vp, "AVEC armes")
	var tris_armes := 0
	for e in corps:
		var acc: Node = (e.modele.find_child("Skeleton3D", true, false) as Skeleton3D).get_node_or_null("Arme")
		if acc != null:
			tris_armes += _tris(acc)
			acc.get_parent().remove_child(acc)
			acc.queue_free()
	print("SALLE : armes seules %d triangles" % tris_armes)
	var sans: Dictionary = await _mesurer(images, vp, "SANS armes")
	print("COUT DES ARMES : CPU %+.2f ms, GPU %+.2f ms par image pour %d ennemis (%d armes, %d triangles d'armes)" % [float(avec["cpu"]) - float(sans["cpu"]), float(avec["gpu"]) - float(sans["gpu"]), n, armes, tris_armes])
	print("FIN")
	quit(0)
