extends SceneTree
## Coût CPU du module ImpactCorps (sans fenêtre, réglages de la couche fine) : 3 draugrs, chaque école sous son pire cas
## (jets factices par le point d'accroche + statuts), moyenne du temps de ImpactCorps._process par image. Mise au point
## de la perf (outils/perf_impact_ecoles.gd mesure le vrai jeu avec fenêtre).
##   godot --headless --path . --script res://outils/bench_impact_ecoles.gd -- --nouvelle
var monde: Node3D

func _init() -> void:
	_go.call_deferred()

func _draugr(pos: Vector3) -> Node3D:
	var d: Node3D = DraugrNordique.creer({})
	monde.add_child(d)
	d.position = pos
	d.add_to_group("cibles_magie")
	return d

func _go() -> void:
	monde = Node3D.new()
	root.add_child(monde)
	current_scene = monde
	GestionMagie.forcer_fin = true
	var gm := GestionMagie.obtenir()
	for k in 3:
		await process_frame
	var ic := ImpactCorps.obtenir(gm)
	var corps: Array[Node3D] = [_draugr(Vector3(-1, 0, -4)), _draugr(Vector3(0, 0, -4.3)), _draugr(Vector3(1, 0, -4))]
	var main := Node3D.new()
	monde.add_child(main)
	main.position = Vector3(0, 1.4, 0)
	var t0 := Time.get_ticks_msec()
	while not (SurfaceCorps.pret(corps[0])) and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	for k in 30:
		await process_frame
	# --balayage : comme la mesure en jeu (perf_impact_ecoles), le jet ne touche qu'UN corps à la fois (il passe de l'un à
	# l'autre toutes les 20 images), statuts sur les trois ; « feu+elec » = jet de flammes ET arc sur le même corps.
	# LOD (ImpactCorps.lod : fréquence réduite des foyers non touchés) coupé / actif ALTERNÉ, --tours=N fois.
	var balayage := OS.get_cmdline_user_args().has("--balayage")
	var tours := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tours="):
			tours = int(a.substr(8))
	var ecoles := ["feu", "electricite", "tenebres", "glace"] + (["feu+elec"] if balayage else [])
	var res := {}
	for tour in tours:
		for ecole: String in ecoles:
			for lod: bool in ([false, true] if balayage else [ImpactCorps.lod]):
				ImpactCorps.lod = lod
				var r := await _bench(gm, corps, main, ecole, balayage)
				var cle := "%s %s" % [ecole, "LOD" if lod else "sans LOD"]
				if not res.has(cle):
					res[cle] = []
				(res[cle] as Array).append(r)
				print("BENCH %s : %.0f µs par image (module %.0f + points d'accroche %.0f) pour %d foyers (%.0f µs par corps), %d particules réservées" % [cle, r[0] + r[1], r[0], r[1], r[2], (r[0] + r[1]) / 3.0, r[3]])
	for cle: String in res:
		var l: Array = res[cle]
		var s := 0.0
		var mini := INF
		for r: Array in l:
			s += float(r[0]) + float(r[1])
			mini = minf(mini, float(r[0]) + float(r[1]))
		print("BENCH_MOYEN %s : %.0f µs par image (meilleur %.0f) sur %d tours" % [cle, s / l.size(), mini, l.size()])
	GestionMagie.forcer_fin = false
	quit()

func _bench(gm: GestionMagie, corps: Array[Node3D], main: Node3D, ecole: String, balayage: bool) -> Array:
	EffetsMagie.tout_arreter()
	for k in 10:
		await process_frame
	var ecs: Array = ["feu", "electricite"] if ecole == "feu+elec" else [ecole]
	var jets := []
	for e: String in ecs:
		for c in corps:
			jets.append({"ecole": e, "origine": main, "portee": 6.0, "largeur": 0.6, "dbl": false, "emit": [], "gerbe": [],
				"gerbe_cible": null, "cible": c, "fin_pos": c.global_position + Vector3.UP * 1.1, "t_bout": 0.0, "eclair": {}})
	var sts := {"feu": "brulure", "electricite": "choc", "tenebres": "corruption", "glace": "gel"}
	var c0 := 0
	var i0 := 0
	var accroche := 0
	for k in 200:
		if k == 40:
			c0 = ImpactCorps.duree_maj_us
			i0 = ImpactCorps.images_maj
		var ta := Time.get_ticks_usec()
		if ecole != "glace":
			for n in jets.size():
				if not balayage or n % corps.size() == (k / 20) % corps.size():
					ImpactCorps.jet_gerbe(gm, jets[n])
		elif k % 20 == 0:
			for i in corps.size():
				if not balayage or i == (k / 20) % corps.size():
					ImpactCorps.impact(gm, "glace", corps[i].global_position + Vector3.UP * 1.1, Vector3.BACK, 0.8)
		if k % 12 == 0:
			for c in corps:
				for e: String in ecs:
					ImpactCorps.statut(gm, c, sts[e], 3.0)
		if k >= 40:
			accroche += Time.get_ticks_usec() - ta
		await process_frame
	var us := float(ImpactCorps.duree_maj_us - c0) / maxf(float(ImpactCorps.images_maj - i0), 1.0)
	return [us, accroche / 160.0, ImpactCorps.stats().foyers, ImpactCorps.stats().particules]
