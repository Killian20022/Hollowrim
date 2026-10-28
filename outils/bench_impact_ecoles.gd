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
	for ecole in ["feu", "electricite", "tenebres", "glace"]:
		EffetsMagie.tout_arreter()
		for k in 10:
			await process_frame
		var jets := []
		for c in corps:
			jets.append({"ecole": ecole, "origine": main, "portee": 6.0, "largeur": 0.6, "dbl": false, "emit": [], "gerbe": [],
				"gerbe_cible": null, "cible": c, "fin_pos": c.global_position + Vector3.UP * 1.1, "t_bout": 0.0, "eclair": {}})
		var st: String = {"feu": "brulure", "electricite": "choc", "tenebres": "corruption", "glace": "gel"}[ecole]
		var c0 := 0
		var i0 := 0
		var accroche := 0
		for k in 200:
			if k == 40:
				c0 = ImpactCorps.duree_maj_us
				i0 = ImpactCorps.images_maj
			var ta := Time.get_ticks_usec()
			if ecole != "glace":
				for jj: Dictionary in jets:
					ImpactCorps.jet_gerbe(gm, jj)
			elif k % 20 == 0:
				for c in corps:
					ImpactCorps.impact(gm, "glace", c.global_position + Vector3.UP * 1.1, Vector3.BACK, 0.8)
			if k % 12 == 0:
				for c in corps:
					ImpactCorps.statut(gm, c, st, 3.0)
			if k >= 40:
				accroche += Time.get_ticks_usec() - ta
			await process_frame
		var us := float(ImpactCorps.duree_maj_us - c0) / maxf(float(ImpactCorps.images_maj - i0), 1.0)
		var ua := accroche / 160.0
		print("BENCH %s : %.0f µs par image (module %.0f + points d'accroche %.0f) pour %d foyers (%.0f µs par corps), %d particules réservées" % [ecole, us + ua, us, ua, ImpactCorps.stats().foyers, (us + ua) / 3.0, ImpactCorps.stats().particules])
	GestionMagie.forcer_fin = false
	quit()
