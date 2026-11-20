extends SceneTree
## Opti 2026-11-20 (appels de dessin) : A/B de l'occlusion des bâtiments (scripts/occultation.gd) sur des poses fixes, DANS LE MÊME
## lancement et le même état figé : pour chaque pose, image + appels avec l'occlusion du viewport allumée puis coupée.
##   godot --path . --disable-vsync --script res://outils/planche_occlusion.gd -- --nouvelle --paisible [--heure=21] --sortie=<dossier Windows>
## Sortie : <dossier>/occ_<pose>_avec.png et _sans.png, lignes « OCC <pose> avec: appels=… prims=… | sans: … ».
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var j: CharacterBody3D
var rid: RID

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _attendre(k: int) -> void:
	for i in k:
		await process_frame

func _go() -> void:
	m = SCENE.instantiate()
	root.add_child(m)
	current_scene = m
	j = m.joueur
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var t0 := Time.get_ticks_msec()
	while m.village.get("prets") != true and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
	if _arg("heure") != "":
		m.cycle.heure = float(_arg("heure"))
	m.cycle._process(0.0)
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	var sortie := _arg("sortie", "C:/Users/lopezk19/Jeux/rendus/opti_2026-11-20/appels_dessin")
	# [nom, Callable de pose]
	var poses: Array = [
		["place", func() -> void: _monde(35.0, 30.0, 221.0, -8.0)],
		["haute_rue", func() -> void: _monde(46.0, 82.0, 175.0, -14.0)],
		["derriere_h1", func() -> void: _monde(37.0, 62.0, 0.0, -4.0)],
		["halle_table", func() -> void: _dedans("halle", Vector3(3.4, 0.05, 0.9), 25.0, -14.0)],
		["halle_porte", func() -> void: _dedans("halle", Vector3(-3.0, 0.05, -1.2), 160.0, -4.0)],
		["h1_porte", func() -> void: _dedans("h1", Vector3(0.0, 0.05, -0.8), 0.0, -4.0)],
		["h4_fenetres", func() -> void: _dedans("h4", Vector3(0.0, 0.05, 0.6), 180.0, -2.0)],
		["ferme_a", func() -> void: _dedans("ferme_a", Vector3(0.0, 0.05, -0.6), 0.0, -4.0)],
	]
	var filtre := _arg("poses")
	for p: Array in poses:
		if filtre != "" and not (String(p[0]) in filtre.split(",")):
			continue
		await (p[1] as Callable).call()
		m.process_mode = Node.PROCESS_MODE_INHERIT
		await _attendre(40)
		m.process_mode = Node.PROCESS_MODE_DISABLED
		var res := []
		for occ in [true, false]:
			root.get_viewport().use_occlusion_culling = occ
			await _attendre(4)
			var V := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
			var D := RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
			var P := RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME
			var S := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW
			res.append([RenderingServer.viewport_get_render_info(rid, V, D), RenderingServer.viewport_get_render_info(rid, V, P), RenderingServer.viewport_get_render_info(rid, S, D), RenderingServer.viewport_get_render_info(rid, S, P)])
			await RenderingServer.frame_post_draw
			var im := root.get_viewport().get_texture().get_image()
			im.convert(Image.FORMAT_RGB8)
			im.save_png("%s/occ_%s_%s.png" % [sortie, p[0], "avec" if occ else "sans"])
		# temps CPU du rendu (médiane), occlusion allumée / coupée en alternance par paquets de 10 images (même état figé)
		var cpu := [PackedFloat32Array(), PackedFloat32Array()]
		var gpu := [PackedFloat32Array(), PackedFloat32Array()]
		for k in 12:
			var occ := k % 2 == 0
			root.get_viewport().use_occlusion_culling = occ
			await _attendre(2)
			for i in 10:
				await process_frame
				cpu[0 if occ else 1].append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
				gpu[0 if occ else 1].append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		root.get_viewport().use_occlusion_culling = true
		print("OCC %-12s pos=%s avec: appels=%d prims=%d ombres=%d/%d cpu=%.2f gpu=%.2f | sans: appels=%d prims=%d ombres=%d/%d cpu=%.2f gpu=%.2f" % [p[0], j.global_position, res[0][0], res[0][1], res[0][2], res[0][3], _med(cpu[0]), _med(gpu[0]), res[1][0], res[1][1], res[1][2], res[1][3], _med(cpu[1]), _med(gpu[1])])
	quit(0)

func _monde(x: float, z: float, lacet: float, tangage: float) -> void:
	j.global_position = Vector3(x, m.hauteur(x, z) + 0.1, z)
	j.velocity = Vector3.ZERO
	j.rotation.y = deg_to_rad(lacet)
	j.tete.rotation.x = deg_to_rad(tangage)

func _dedans(id: String, loc: Vector3, lacet: float, tangage: float) -> void:
	var ip: Interieur = m.village.interieur(id)
	if ip == null:
		print("OCC pas d'intérieur ", id)
		return
	if not ip.construit:
		m.village.construire_interieur_maintenant(ip)
	j.global_position = ip.to_global(Vector3(loc.x, ip.sol_y + loc.y, loc.z))
	j.velocity = Vector3.ZERO
	j.rotation.y = ip.global_rotation.y + deg_to_rad(lacet)
	j.tete.rotation.x = deg_to_rad(tangage)
	await process_frame

func _med(a: PackedFloat32Array) -> float:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2] if b.size() > 0 else 0.0
