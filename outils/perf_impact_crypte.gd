extends SceneTree
## Coût du FEU SUR LE CORPS (socle ImpactCorps) dans la VRAIE crypte (foret_test, vrai joueur, vraies mains, vraie logique) :
## 3 gardiens réveillés, alignés devant le joueur et figés ; raccourci 3 (jet de flammes dans les deux mains), double
## incantation qui BALAIE les trois corps (ils prennent tous feu). Mesures alternées dans la même séance :
## ImpactCorps actif (après) / coupé (avant : gerbe en boîte + voile de statut) → l'écart ne dépend pas de la charge du PC.
## La PREMIÈRE phase est le tout premier jet sur des corps (après la préchauffe du chargement) : pire image et pipelines
## compilés pendant sa première seconde.
##   godot --path . --disable-vsync --script res://outils/perf_impact_crypte.gd -- --nouvelle [--detail-sorts=retro|moyen|eleve] [--tours=2]
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var j: CharacterBody3D
var cibles: Array[Node3D] = []
var _t := 0.0
var _touches := 0

func _init() -> void:
	_go.call_deferred()

func _pipes() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _go() -> void:
	ImpactCorps.trace = true
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
	# 3 gardiens ordinaires : on réveille les zones autour de chacun, puis on les aligne devant le joueur
	var cr: Node3D = m.tertre.crypte
	var premier := Vector3.ZERO
	var face := Vector3.FORWARD
	for g: Dictionary in m.tertre.donjon.gardiens:
		if cibles.size() >= 3:
			break
		var ty := String(g["type"])
		if ty == "squelette_archer" or (g["extra"] as Dictionary).has("boss") or (g["extra"] as Dictionary).has("si"):
			continue
		var pos: Vector3 = cr.to_global(g["pos"])
		var fc := Basis(Vector3.UP, cr.global_rotation.y + float(g["lacet"])).z
		j.global_position = pos + fc * 4.5 + Vector3(0, 0.1, 0)
		var t0 := Time.get_ticks_msec()
		var id := String(g["ident"])
		while not (m.draugrs.has(id) and is_instance_valid(m.draugrs[id])) and Time.get_ticks_msec() - t0 < 4000:
			m.tertre._gerer_zones()
			await process_frame
		if m.draugrs.has(id) and is_instance_valid(m.draugrs[id]):
			if cibles.is_empty():
				premier = pos
				face = fc
			cibles.append(m.draugrs[id])
	if cibles.size() < 3:
		print("PERF_IMPACT : seulement %d gardiens" % cibles.size())
		if cibles.is_empty():
			quit(1)
			return
	# direction DÉGAGÉE depuis le premier gardien (sinon le jet bute sur un pilier ou un mur : « cible <null> »)
	var espace := m.get_world_3d().direct_space_state
	var exclus: Array[RID] = [j.get_rid()]
	for c in cibles:
		if c is CollisionObject3D:
			exclus.append((c as CollisionObject3D).get_rid())
	var meilleure := -1.0
	var face0 := face
	for k in 16:
		var d := Basis(Vector3.UP, TAU * k / 16.0) * face0
		var libre := 9.0
		for h: float in [0.6, 1.2, 1.7]:
			for lat: float in [-1.2, 0.0, 1.2]:
				var dep := premier + Vector3.UP * h + d.cross(Vector3.UP).normalized() * lat
				var q := PhysicsRayQueryParameters3D.create(dep, dep + d * 6.0)
				q.exclude = exclus
				var r := espace.intersect_ray(q)
				libre = minf(libre, dep.distance_to(r.position) if not r.is_empty() else 6.0)
		if libre > meilleure + 0.05:
			meilleure = libre
			face = d
	print("  direction dégagée : %.1f m libres" % meilleure)
	j.global_position = premier + face * 4.2 + Vector3(0, 0.1, 0)
	var cote := face.cross(Vector3.UP).normalized()
	for i in cibles.size():
		var c := cibles[i]
		if c.has_method("figer"):
			c.figer(true)
		c.global_position = premier + cote * (float(i) - 1.0) * 0.95 + face * absf(float(i) - 1.0) * 0.4
		c.look_at(j.global_position, Vector3.UP, true)
	for k in 60:
		_viser(0.0)
		await process_frame
	var vps: Array[RID] = [root.get_viewport_rid()]
	var gm := GestionMagie.obtenir()
	if gm.couche != null and gm.couche.vp != null:
		vps.append(gm.couche.vp.get_viewport_rid())
	for v in vps:
		RenderingServer.viewport_set_measure_render_time(v, true)
	var base := await _mesurer(240, false, vps)
	if OS.get_cmdline_user_args().has("--diag-embraser"):
		# diagnostic : pipelines compilés par le SEUL feu sur le corps (sans jet), puis par le seul jet (module coupé)
		var q0 := _pipes()
		var c1 := cibles[mini(1, cibles.size() - 1)]
		ImpactCorps.embraser(c1, "feu", c1.global_position + Vector3.UP * 1.1, (c1.global_position - j.global_position).normalized(), 1.0, 2.0)
		var pire0 := 0.0
		var tq := Time.get_ticks_usec()
		for k in 60:
			_viser(0.0)
			await process_frame
			pire0 = maxf(pire0, (Time.get_ticks_usec() - tq) / 1000.0)
			tq = Time.get_ticks_usec()
		print("  DIAG feu sur le corps seul (embraser) : %d pipelines, pire image %.1f ms" % [_pipes() - q0, pire0])
		EffetsMagie.tout_arreter()
		for k in 30:
			await process_frame
	var magie: Node = j.mains.magie
	magie.raccourci(2)   # touche 3 : jet de flammes / jet de flammes
	for k in 10:
		await process_frame
	var tours := int(_arg("tours", "4"))
	print("  gardiens : ", cibles.map(func(c: Node3D) -> String: return "%s %s vie=%s" % [c.name, c.get_class(), c.get("vie")]))
	var res := {true: [], false: []}
	var premier_impact := ""
	for tour in tours:
		for actif: bool in ([true] if _arg("seul") == "apres" else [false] if _arg("seul") == "avant" else [false, true] if _arg("premier") == "avant" else [true, false]):
			ImpactCorps.actif = actif
			EffetsMagie.tout_arreter()
			for k in 20:
				_viser(0.0)
				await process_frame
			# les deux mains libres (récupération du jet précédent finie), sinon l'appui est refusé : « jets [] »
			var att := 0
			while att < 180 and not ((magie.inc["gauche"] as Incantation).libre() and (magie.inc["droite"] as Incantation).libre()):
				_viser(0.0)
				att += 1
				await process_frame
			var p0 := _pipes()
			var pire := 0.0
			magie.appuyer("gauche")
			magie.appuyer("droite")
			var t_prec := Time.get_ticks_usec()
			for k in 60:
				_tenir()
				await process_frame
				var n := Time.get_ticks_usec()
				pire = maxf(pire, (n - t_prec) / 1000.0)
				t_prec = n
			print("  phase actif=%s, 1re seconde : pire image %.1f ms, %d pipelines compilés" % [actif, pire, _pipes() - p0])
			if premier_impact == "":
				premier_impact = "1er jet sur les corps (%s) : pire image %.1f ms, %d pipelines compilés pendant la 1re seconde" % ["après" if actif else "avant", pire, _pipes() - p0]
			var c0 := ImpactCorps.cout_us
			var i0 := ImpactCorps.cout_images
			_touches = 0
			var r := await _mesurer(240, true, vps)
			var cpu_module := float(ImpactCorps.cout_us - c0) / maxf(float(ImpactCorps.cout_images - i0), 1.0) / 1000.0
			var s := EffetsMagie.stats()
			var sc := ImpactCorps.stats()
			var vus := []
			for jj: Dictionary in GestionMagie.instance._jets.values():
				vus.append(str(jj.cible) + (" touche" if jj.touche else ""))
			print("  phase actif=%s : jets %s ; cibles %s" % [actif, vus, cibles.map(func(c: Node3D) -> String: return "%s vie=%s" % [c.name, c.get("vie")] if is_instance_valid(c) else "libéré")])
			r.append(s.particules)
			r.append(sc.foyers)
			r.append(pire)
			r.append(cpu_module)
			r.append(_touches / 240.0)
			if r[8] < 0.5:
				print("  phase actif=%s ÉCARTÉE : un jet touche un gardien sur %d %% des images seulement" % [actif, int(r[8] * 100)])
			elif tour > 0 or tours == 1:   # le 1er tour (premiers jets, caches) n'entre pas dans les moyennes
				res[actif].append(r)
			magie.relacher("gauche")
			magie.relacher("droite")
			for k in 30:
				await process_frame
	var niveau: String = "rétro" if gm.couche == null or not gm.couche.fine() else ["rétro", "moyen", "élevé"][gm.couche.niveau]
	var moy := func(liste: Array, i: int) -> float:
		var t := 0.0
		for r: Array in liste:
			t += float(r[i])
		return t / maxf(liste.size(), 1)
	print("PERF_IMPACT détail %s, %d corps : sans sort %.2f ms (GPU %.2f)" % [niveau, cibles.size(), base[0], base[1]])
	for actif: bool in [false, true]:
		for r: Array in res[actif]:
			print("  %s : %.2f ms (GPU %.2f = fenêtre %.2f + couche %.2f) ; pire %.1f ms ; CPU du module %.3f ms ; %d particules, %d foyers ; jet sur un gardien %d %% des images" % [
				"APRÈS (ImpactCorps)" if actif else "AVANT (gerbe)", r[0], r[1], r[2], r[3], r[6], r[7], r[4], r[5], int(r[8] * 100)])
	print("PERF_IMPACT écart après - avant : temps d'image %+.2f ms, GPU %+.2f ms, CPU du module %.3f ms (moyennes de %d tours, le 1er écarté) ; %s" % [
		moy.call(res[true], 0) - moy.call(res[false], 0), moy.call(res[true], 1) - moy.call(res[false], 1), moy.call(res[true], 7), res[true].size(), premier_impact])
	quit()

func _viser(decalage: float) -> void:
	# vise le corps du milieu, décalé latéralement de `decalage` radians
	var c: Node3D = cibles[mini(1, cibles.size() - 1)]
	var cam: Node3D = j.camera
	var v: Vector3 = c.global_position + Vector3(0, 1.1, 0) - cam.global_position
	j.rotation.y = atan2(-v.x, -v.z) + decalage
	j.tete.rotation.x = clampf(atan2(v.y, Vector2(v.x, v.z).length()), -1.0, 0.6)

func _tenir() -> void:
	# balayage lent : le double jet passe d'un corps à l'autre (tous les trois prennent feu)
	_t += 1.0 / 60.0
	_viser(sin(_t * 2.2) * 0.2)
	j.mana = 100.0
	j.vie = j.vie_max
	# les gardiens ne meurent pas pendant la mesure (le feu les tuerait en ~3 s : ragdoll, puis cadavre retiré)
	for c in cibles:
		if is_instance_valid(c) and "vie" in c:
			c.vie = 1000.0

func _mesurer(n: int, sort: bool, vps: Array[RID]) -> Array:
	var gm := GestionMagie.instance
	if vps.size() < 2 and gm != null and gm.couche != null and gm.couche.vp != null:
		vps.append(gm.couche.vp.get_viewport_rid())
		RenderingServer.viewport_set_measure_render_time(vps[1], true)
	var t0 := Time.get_ticks_usec()
	var g := [0.0, 0.0]
	for k in n:
		if sort:
			_tenir()
		else:
			_viser(0.0)
			j.vie = j.vie_max
		await process_frame
		if sort:
			for jj: Dictionary in gm._jets.values():
				if cibles.has(jj.cible):
					_touches += 1
					break
		for i in vps.size():
			g[i] += RenderingServer.viewport_get_measured_render_time_gpu(vps[i])
	var dt := (Time.get_ticks_usec() - t0) / 1000.0 / n
	return [dt, (g[0] + g[1]) / n, g[0] / n, g[1] / n]
