extends SceneTree
## Mesure du coût de la magie dans la VRAIE crypte (foret_test, vrai joueur, vraies mains, vraie logique des sorts) :
## raccourci 3 (« Pyromancien » : jet de flammes dans les deux mains), double incantation tenue face à un gardien.
## Avec fenêtre (temps réels) :
##   godot --path . --disable-vsync --script res://outils/perf_magie_crypte.gd -- --nouvelle [--detail-sorts=retro|moyen|eleve]
## Imprime : temps d'image moyen et GPU (fenêtre + couche fine) sans sort puis avec le double jet, pire image et pipelines
## compilés pendant la première seconde du sort (à-coup du premier sort).
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var j: CharacterBody3D

func _init() -> void:
	_go.call_deferred()

func _pipes() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))

func _go() -> void:
	m = SCENE.instantiate()
	root.add_child(m)
	current_scene = m
	j = m.joueur
	for k in 30:
		await process_frame
	var tt := Time.get_ticks_msec()
	while not m.tertre._donjon_pret() and Time.get_ticks_msec() - tt < 60000:
		await process_frame
	for k in 150:   # préchauffage du monde (PrechauffeRendu, vitrine des effets) comme en partie
		await process_frame
	m.tertre._basculer(true)
	m._sous_terre(true)
	for k in 30:
		await process_frame
	# un gardien ordinaire, réveillé devant le joueur
	var cible: Node3D = null
	var cr: Node3D = m.tertre.crypte
	for g: Dictionary in m.tertre.donjon.gardiens:
		var ty := String(g["type"])
		if ty == "squelette_archer" or (g["extra"] as Dictionary).has("boss") or (g["extra"] as Dictionary).has("si"):
			continue
		var pos: Vector3 = cr.to_global(g["pos"])
		var face := Basis(Vector3.UP, cr.global_rotation.y + float(g["lacet"])).z
		j.global_position = pos + face * 4.5 + Vector3(0, 0.1, 0)
		var t0 := Time.get_ticks_msec()
		var id := String(g["ident"])
		while not (m.draugrs.has(id) and is_instance_valid(m.draugrs[id])) and Time.get_ticks_msec() - t0 < 4000:
			m.tertre._gerer_zones()
			await process_frame
		if m.draugrs.has(id):
			cible = m.draugrs[id]
			break
	if cible == null:
		print("PERF_CRYPTE : aucun gardien")
		quit(1)
		return
	if cible.has_method("figer"):
		cible.figer(true)
	var vps: Array[RID] = [root.get_viewport_rid()]
	for v in vps:
		RenderingServer.viewport_set_measure_render_time(v, true)
	for k in 30:
		_viser(cible)
		await process_frame
	var base := await _mesurer(240, cible, false)
	var magie: Node = j.mains.magie
	magie.raccourci(2)   # touche 3 : jet de flammes / jet de flammes
	for k in 10:
		await process_frame
	var p0 := _pipes()
	var pire := 0.0
	magie.appuyer("gauche")
	magie.appuyer("droite")
	var t_prec := Time.get_ticks_usec()
	for k in 60:
		_tenir(cible)
		await process_frame
		var n := Time.get_ticks_usec()
		pire = maxf(pire, (n - t_prec) / 1000.0)
		t_prec = n
	var pipes := _pipes() - p0
	# la couche fine (si active) est un SubViewport : on mesure aussi son temps GPU
	var gm := GestionMagie.instance
	if gm != null and gm.couche != null and gm.couche.vp != null:
		vps.append(gm.couche.vp.get_viewport_rid())
		RenderingServer.viewport_set_measure_render_time(gm.couche.vp.get_viewport_rid(), true)
	for k in 30:
		_tenir(cible)
		await process_frame
	var avec := await _mesurer(240, cible, true, vps)
	var s := EffetsMagie.stats()
	var niveau: String = "rétro" if gm == null or gm.couche == null or not gm.couche.fine() else ["rétro", "moyen", "élevé"][gm.couche.niveau]
	print("PERF_CRYPTE détail %s : sans sort %.2f ms (GPU %.2f) ; double jet de flammes %.2f ms (GPU %.2f = fenêtre %.2f + couche %.2f) ; +%.2f ms ; %d particules, %d émetteurs, %d jets ; 1re seconde du sort : pire image %.1f ms, %d pipelines compilés" % [
		niveau, base[0], base[1], avec[0], avec[1], avec[2], avec[3], avec[0] - base[0], s.particules, s.emetteurs, s.jets, pire, pipes])
	magie.relacher("gauche")
	magie.relacher("droite")
	for k in 20:
		await process_frame
	quit()

func _viser(e: Node3D) -> void:
	var cam: Node3D = j.camera
	var v: Vector3 = e.global_position + Vector3(0, 1.1, 0) - cam.global_position
	j.rotation.y = atan2(-v.x, -v.z)
	j.tete.rotation.x = clampf(atan2(v.y, Vector2(v.x, v.z).length()), -1.0, 0.6)

func _tenir(e: Node3D) -> void:
	_viser(e)
	j.mana = 100.0
	j.vie = j.vie_max

func _mesurer(n: int, e: Node3D, sort: bool, vps: Array[RID] = []) -> Array:
	if vps.is_empty():
		vps = [root.get_viewport_rid()]
	var t0 := Time.get_ticks_usec()
	var g := [0.0, 0.0]
	for k in n:
		if sort:
			_tenir(e)
		else:
			_viser(e)
			j.vie = j.vie_max
		await process_frame
		for i in vps.size():
			g[i] += RenderingServer.viewport_get_measured_render_time_gpu(vps[i])
	var dt := (Time.get_ticks_usec() - t0) / 1000.0 / n
	return [dt, (g[0] + g[1]) / n, g[0] / n, g[1] / n]
