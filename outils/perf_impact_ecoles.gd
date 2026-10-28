extends SceneTree
## Coût des ÉCOLES SUR LE CORPS (socle ImpactCorps, agent B) dans la VRAIE crypte (foret_test, vrai joueur, vraies mains,
## vraie logique des sorts) : 3 gardiens réveillés, alignés devant le joueur et figés. Pire cas par école, les deux mains :
##   feu         : double jet de flammes qui balaie les 3 corps (référence : socle + feu de l'agent A)
##   electricite : double arc électrique (propagation : les 3 corps en choc)
##   tenebres    : double drain de vie qui balaie les 3 corps (corruption sur les 3)
##   glace       : éclats de glace en double, relancés dès la recharge, en balayant (gel sur les 3)
##   feu+elec    : jet de flammes (gauche) + arc électrique (droite) : feu ET choc sur les mêmes corps (cumul A + B)
##   feu+glace   : jet de flammes (gauche) + éclats de glace (droite)
## Mesures ALTERNÉES dans la même séance : ImpactCorps actif (après) / coupé (avant) → l'écart ne dépend pas de la charge du
## PC. Le 1er passage de chaque école (après la préchauffe du chargement) donne la pire image et les pipelines compilés.
##   godot --path . --disable-vsync --script res://outils/perf_impact_ecoles.gd -- --nouvelle [--detail-sorts=retro|moyen|eleve]
##       [--ecoles=electricite,glace,…] [--tours=3]
const SCENE := preload("res://scenes/foret_test.tscn")
const SORTS := {
	"feu": ["jet_flammes", "jet_flammes", true],
	"electricite": ["arc_electrique", "arc_electrique", true],
	"tenebres": ["drain_vie", "drain_vie", true],
	"glace": ["eclat_glace", "eclat_glace", false],
	"feu+elec": ["jet_flammes", "arc_electrique", true],
	"feu+glace": ["jet_flammes", "eclat_glace", false],
}

var m: Node3D
var j: CharacterBody3D
var cibles: Array[Node3D] = []
var _t := 0.0
var _vus := 0
var _mediane := 0.0      # médiane du temps d'image de la dernière mesure (ms) : moins sensible aux à-coups des autres processus

func _init() -> void:
	_go.call_deferred()

func _pipes() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))

func _detail_pipes() -> String:
	return "s%d sp%d d%d m%d" % [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)]

func _detail_pipes_vec() -> Array:
	return [int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))]

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

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
	if cibles.is_empty():
		print("PERF_ECOLES : aucun gardien")
		quit(1)
		return
	# le joueur À LA PLACE du premier gardien (son sol existe : devant lui, la crypte peut être un trou → filet anti-chute),
	# puis les 3 gardiens alignés à 4 m devant le joueur dans une direction dégagée ET au sol vérifié ; IA coupée
	# (plus de marche ni d'attaque), animations conservées
	var pj := premier + Vector3(0, 0.15, 0)
	for c in cibles:
		c.set_physics_process(false)
		c.global_position += Vector3(0, -50, 0)   # écartés le temps de choisir la direction (rayons)
	j.global_position = pj
	j.velocity = Vector3.ZERO
	for k in 5:
		await process_frame
	var esp := j.get_world_3d().direct_space_state
	var vers := Vector3.FORWARD
	var meilleure := -1.0
	for k in 16:
		var dv := Vector3(cos(TAU * k / 16.0), 0.0, sin(TAU * k / 16.0))
		var q := PhysicsRayQueryParameters3D.create(pj + Vector3.UP * 1.0, pj + Vector3.UP * 1.0 + dv * 7.0)
		q.exclude = [j.get_rid()]
		var r := esp.intersect_ray(q)
		var l: float = 7.0 if r.is_empty() else (pj + Vector3.UP).distance_to(r.position)
		var cote_k := dv.cross(Vector3.UP).normalized()
		var sol_ok := 0
		for i in 3:
			var p := pj + dv * 4.0 + cote_k * (float(i) - 1.0) * 0.95
			var qs := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 1.0)
			var rs := esp.intersect_ray(qs)
			if not rs.is_empty() and absf((rs.position as Vector3).y - pj.y) < 0.4:
				sol_ok += 1
		var sc := minf(l, 7.0) + 10.0 * sol_ok
		if sc > meilleure:
			meilleure = sc
			vers = dv
	var cote: Vector3 = vers.cross(Vector3.UP).normalized()
	var sol_y := pj.y - 0.15
	for i in cibles.size():
		var c := cibles[i]
		c.global_position = Vector3(pj.x, sol_y, pj.z) + vers * (4.0 - absf(float(i) - 1.0) * 0.3) + cote * (float(i) - 1.0) * 0.95
		c.look_at(Vector3(pj.x, c.global_position.y, pj.z), Vector3.UP, true)
	for k in 30:
		await process_frame
	print("  joueur ", j.global_position, " (posé ", pj, ") ; score de direction %.1f ; gardiens " % meilleure, cibles.map(func(c: Node3D) -> String: return "%.1f m" % c.global_position.distance_to(j.global_position)))
	for k in 60:
		_viser(0.0)
		await process_frame
	var vps: Array[RID] = [root.get_viewport_rid()]
	var gm := GestionMagie.obtenir()
	if gm.couche != null and gm.couche.vp != null:
		vps.append(gm.couche.vp.get_viewport_rid())
	for v in vps:
		RenderingServer.viewport_set_measure_render_time(v, true)
	var base := await _mesurer(240, false, vps, "")
	var niveau: String = "rétro" if gm.couche == null or not gm.couche.fine() else ["rétro", "moyen", "élevé"][gm.couche.niveau]
	print("PERF_ECOLES détail %s, %d corps : sans sort %.2f ms (GPU %.2f)" % [niveau, cibles.size(), base[0], base[1]])
	# (2026-10-28) le monde charge encore en tâche de fond (kit de la grotte, troll…) : ses pipelines tombaient dans le
	# 1er passage du 1er sort mesuré. On attend qu'aucun pipeline ne compile pendant 180 images (45 s au plus).
	var p_calme := _pipes()
	var n_calme := 0
	var t_calme := Time.get_ticks_msec()
	var p_monde := 0
	while n_calme < 180 and Time.get_ticks_msec() - t_calme < 45000:
		_viser(0.0)
		j.vie = j.vie_max
		await process_frame
		var pn := _pipes()
		if pn != p_calme:
			p_monde += pn - p_calme
			p_calme = pn
			n_calme = 0
		else:
			n_calme += 1
	print("PERF_ECOLES monde au calme après %.1f s (%d pipelines du monde compilés en attendant)" % [(Time.get_ticks_msec() - t_calme) / 1000.0, p_monde])
	var tours := int(_arg("tours", "3"))
	var liste: Array = (_arg("ecoles", "feu,electricite,tenebres,glace,feu+elec,feu+glace") as String).split(",")
	var magie: Node = j.mains.magie
	for ecole: String in liste:
		var sp: Array = SORTS[ecole]
		magie.equiper("gauche", sp[0])
		magie.equiper("droite", sp[1])
		for k in 10:
			await process_frame
		var res := {true: [], false: []}
		var premier_passage := ""
		for tour in tours:
			# 1er tour : AVANT d'abord (il compile ce qui est commun : jet, aura, lumières) → les pipelines compilés au 1er
			# passage APRÈS sont ceux propres aux corps (doivent être 0 : préchauffés)
			for actif: bool in ([false, true] if tour == 0 else [true, false]):
				ImpactCorps.actif = actif
				EffetsMagie.tout_arreter()
				for c in cibles:
					var st := Statuts.de(c, false)
					if st != null:
						for n in ["brulure", "gel", "choc", "corruption"]:
							st.retirer(n)
				for k in 20:
					_viser(0.0)
					await process_frame
				var p0 := _pipes()
				var pire := 0.0
				_t = 0.0
				if sp[2]:
					magie.appuyer("gauche")
					magie.appuyer("droite")
				var t_prec := Time.get_ticks_usec()
				var diag := ""
				var pp := _pipes()
				var dp := _detail_pipes_vec()
				for k in 60:
					_tenir(sp, magie, k)
					await process_frame
					var n := Time.get_ticks_usec()
					pire = maxf(pire, (n - t_prec) / 1000.0)
					t_prec = n
					if tour == 0 and actif and OS.get_cmdline_user_args().has("--diag-pipes") and _pipes() != pp:
						# image et nombre de chaque compilation pendant le 1er passage APRÈS (attribution, mise au point)
						var dd := _detail_pipes_vec()
						diag += "i%d:+%d(s+%d sp+%d d+%d m+%d) " % [k, _pipes() - pp, dd[0] - dp[0], dd[1] - dp[1], dd[2] - dp[2], dd[3] - dp[3]]
						pp = _pipes()
						dp = dd
				if diag != "":
					print("  DIAG_PIPES %s : %s" % [ecole, diag])
				if tour == 0:
					premier_passage += "1er passage %s : pire image %.1f ms, %d pipelines compilés ; " % ["après" if actif else "avant", pire, _pipes() - p0]
				var c0 := ImpactCorps.duree_maj_us
				var i0 := ImpactCorps.images_maj
				var r := await _mesurer(240, true, vps, ecole, sp, magie)
				var cpu := float(ImpactCorps.duree_maj_us - c0) / maxf(float(ImpactCorps.images_maj - i0), 1.0) / 1000.0
				r.append(EffetsMagie.stats().particules)
				r.append(_vus)
				r.append(pire)
				r.append(cpu)
				r.append(_mediane)
				if tour > 0 or tours == 1:
					res[actif].append(r)
				magie.relacher("gauche")
				magie.relacher("droite")
				for k in 40:
					await process_frame
		var moy := func(l: Array, i: int) -> float:
			var t := 0.0
			for x: Array in l:
				t += float(x[i])
			return t / maxf(l.size(), 1)
		var av: Array = res[false]
		var ap: Array = res[true]
		print("PERF_ECOLES %s : AVANT %.2f ms (GPU %.2f) ; APRÈS %.2f ms (GPU %.2f = fenêtre %.2f + couche %.2f) ; écart %+.2f ms (GPU %+.2f) ; écart MÉDIAN %+.2f ms (%.2f → %.2f) ; CPU du module %.3f ms ; %d particules, %d foyers ; pire image après %.1f ms ; %s" % [
			ecole, moy.call(av, 0), moy.call(av, 1), moy.call(ap, 0), moy.call(ap, 1), moy.call(ap, 2), moy.call(ap, 3),
			moy.call(ap, 0) - moy.call(av, 0), moy.call(ap, 1) - moy.call(av, 1), moy.call(ap, 8) - moy.call(av, 8), moy.call(av, 8), moy.call(ap, 8),
			moy.call(ap, 7), int(moy.call(ap, 4)), int(moy.call(ap, 5)), moy.call(ap, 6), premier_passage])
	quit()

## Balaie les 3 corps (± 0,95 m autour du milieu, 0,5 aller-retour par seconde).
func _viser(decalage: float) -> void:
	var cam: Node3D = j.camera
	# balayage de l'un à l'autre des gardiens (decalage -1..1 : un peu au-delà des deux du bout)
	var a: Vector3 = cibles[0].global_position
	var z: Vector3 = cibles[cibles.size() - 1].global_position
	var v: Vector3 = a.lerp(z, decalage * 0.5 + 0.5) + Vector3(0, 1.1, 0) - cam.global_position
	j.rotation.y = atan2(-v.x, -v.z)
	j.tete.rotation.x = clampf(atan2(v.y, Vector2(v.x, v.z).length()), -1.0, 0.6)

func _tenir(sp: Array, magie: Node, k: int) -> void:
	_t += 1.0 / 60.0
	_viser(sin(_t * PI) * 1.05)
	j.mana = 100.0
	j.vie = j.vie_max
	for c in cibles:
		if is_instance_valid(c) and c.get("vie") != null:
			c.set("vie", maxf(float(c.get("vie")), 50.0))   # personne ne meurt pendant la mesure
	if not sp[2]:
		# sorts à départ (éclats) : appui / relâche dès la recharge (0,3 s), les deux mains ensemble (double)
		if k % 20 == 0:
			magie.appuyer("gauche" if sp[0] == sp[1] else "droite")
			magie.appuyer("droite")
		elif k % 20 == 2:
			magie.relacher("droite")
			if sp[0] == sp[1]:
				magie.relacher("gauche")
		if sp[0] != sp[1] and k == 0:
			magie.appuyer("gauche")

func _mesurer(n: int, sort: bool, vps: Array[RID], ecole: String, sp: Array = [], magie: Node = null) -> Array:
	var t0 := Time.get_ticks_usec()
	var g := [0.0, 0.0]
	var dts := PackedFloat32Array()
	var t_img := Time.get_ticks_usec()
	for k in n:
		if sort:
			_tenir(sp, magie, k)
		else:
			_viser(0.0)
			j.vie = j.vie_max
		await process_frame
		var t_n := Time.get_ticks_usec()
		dts.append((t_n - t_img) / 1000.0)
		t_img = t_n
		for i in vps.size():
			g[i] += RenderingServer.viewport_get_measured_render_time_gpu(vps[i])
		if sort and k == n / 2:
			_vus = ImpactCorps.stats().foyers
			if _arg("debug") != "":
				var vus := []
				for jj: Dictionary in GestionMagie.instance._jets.values():
					vus.append("%s %s" % [jj.ecole, jj.cible])
				var cam: Node3D = j.camera
				print("  joueur ", j.global_position, " cam ", cam.global_position, " avant ", -cam.global_basis.z, " cibles ", cibles.map(func(c: Node3D) -> String: return "%s vis=%s grp=%s" % [c.global_position, c.is_visible_in_tree(), c.get_groups()]))
				print("  mi-mesure %s : foyers %d ; jets %s ; statuts %s" % [ecole, _vus, vus, cibles.map(func(c: Node3D) -> String: return str(Statuts.de(c, false).liste() if Statuts.de(c, false) != null else []))])
	var dt := (Time.get_ticks_usec() - t0) / 1000.0 / n
	dts.sort()
	_mediane = dts[dts.size() / 2] if dts.size() > 0 else dt
	return [dt, (g[0] + g[1]) / n, g[0] / n, g[1] / n]
