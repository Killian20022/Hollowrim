extends SceneTree
## Coût du RETOUR DE COMBAT du lot L6 (gerbes de pixels, os qui volent, chiffres de dégâts) dans la VRAIE crypte (foret_test,
## vrai joueur, vrai HUD) : 3 gardiens réveillés, alignés devant le joueur et figés, frappés à l'épée (CombatEnnemi complet :
## sang, plaies, sons, réactions) au rythme d'un combat très chargé (un coup toutes les 12 images, léger / lourd / critique,
## un sur quatre paré). Phases alternées dans la même séance : L6 actif (après) / L6 coupé (GerbePixels.actif, EclatsOs.actif,
## chiffres) → l'écart ne dépend pas de la charge du PC ; coupé = AUCUNE gerbe (pas même les anciens cubes) : l'écart est un
## majorant du coût ajouté. La PREMIÈRE phase est le tout premier coup (après la préchauffe du chargement) : pire image et
## pipelines compilés pendant sa première seconde.
##   godot --path . --disable-vsync --script res://outils/perf_retour_crypte.gd -- --nouvelle [--tours=3]
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var j: CharacterBody3D
var cibles: Array[Node3D] = []
var _k := 0

func _init() -> void:
	_go.call_deferred()

func _pipes() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

## --parties=gerbes,os,chiffres : parties du lot L6 activées dans les phases « actif » (diagnostic ; défaut : toutes).
func _regler(actif: bool) -> void:
	var p := _arg("parties", "gerbes,os,chiffres").split(",")
	GerbePixels.actif = actif and p.has("gerbes")
	EclatsOs.actif = actif and p.has("os")
	ChiffresDegats.force_actif = 1 if actif and p.has("chiffres") else 0

func _go() -> void:
	RetourImpact.arret_actif = false   # pas d'arrêt sur image : il fausserait les temps d'image
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
		print("PERF_RETOUR : aucun gardien")
		quit(1)
		return
	# direction dégagée depuis le premier gardien
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
	j.global_position = premier + face * 2.6 + Vector3(0, 0.1, 0)
	var cote := face.cross(Vector3.UP).normalized()
	for i in cibles.size():
		var c := cibles[i]
		c.global_position = premier + cote * (float(i) - 1.0) * 0.95 + face * absf(float(i) - 1.0) * 0.3
		c.look_at(j.global_position, Vector3.UP, true)
		c.set_physics_process(false)
		if "vie" in c:
			c.vie = 5000.0
	print("  gardiens : ", cibles.map(func(c: Node3D) -> String: return "%s (%s)" % [c.get("nom_affiche"), c.get("type")]))
	for k in 60:
		_viser()
		await process_frame
	var vps: Array[RID] = [root.get_viewport_rid()]
	RenderingServer.viewport_set_measure_render_time(vps[0], true)
	var tours := int(_arg("tours", "3"))
	var res := {true: [], false: []}
	var premier_coup := ""
	for tour in tours:
		for actif: bool in ([true, false] if tour % 2 == 0 else [false, true]):   # ordre alterné : la phase qui suit l'autre n'est pas toujours la même
			_regler(actif)
			for k in 30:
				_viser()
				await process_frame
			var p0 := _pipes()
			var e0 := GerbePixels.emissions
			var u0 := GerbePixels.cout_us + EclatsOs.cout_us + ChiffresDegats.cout_us
			var pire := 0.0
			var t_prec := Time.get_ticks_usec()
			var t0 := Time.get_ticks_usec()
			var gpu := 0.0
			var n := 240
			for k in n:
				_frapper(k)
				await process_frame
				var t := Time.get_ticks_usec()
				pire = maxf(pire, (t - t_prec) / 1000.0)
				t_prec = t
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vps[0])
			var dt := (Time.get_ticks_usec() - t0) / 1000.0 / n
			var pipes := _pipes() - p0
			var cpu_l6 := float(GerbePixels.cout_us + EclatsOs.cout_us + ChiffresDegats.cout_us - u0) / n / 1000.0
			print("  tour %d L6 %s : %.2f ms / image (GPU %.2f), pire %.1f ms, %d pipelines, %d gerbes, CPU du lot L6 %.3f ms / image" % [tour, "ACTIF" if actif else "coupé", dt, gpu / n, pire, pipes, GerbePixels.emissions - e0, cpu_l6])
			if premier_coup == "":
				premier_coup = "premiers coups (L6 actif, après la préchauffe) : pire image %.1f ms, %d pipelines compilés" % [pire, pipes]
			if tour > 1 or tours <= 2:   # les 2 premiers tours (premiers coups, caches, pipelines du socle) n'entrent pas dans les moyennes
				res[actif].append([dt, gpu / n, pire, cpu_l6])
	var moy := func(l: Array, i: int) -> float:
		var t := 0.0
		for r: Array in l:
			t += float(r[i])
		return t / maxf(l.size(), 1)
	print("PERF_RETOUR %d gardiens : coupé %.2f ms (GPU %.2f) ; actif %.2f ms (GPU %.2f) ; écart %+.2f ms (GPU %+.2f) ; CPU du lot L6 %.3f ms / image ; pire actif %.1f / coupé %.1f ms ; %s" % [
		cibles.size(), moy.call(res[false], 0), moy.call(res[false], 1), moy.call(res[true], 0), moy.call(res[true], 1),
		moy.call(res[true], 0) - moy.call(res[false], 0), moy.call(res[true], 1) - moy.call(res[false], 1), moy.call(res[true], 3), moy.call(res[true], 2), moy.call(res[false], 2), premier_coup])
	_regler(true)
	ChiffresDegats.force_actif = -1
	quit()

func _viser() -> void:
	var c: Node3D = cibles[mini(1, cibles.size() - 1)]
	var cam: Node3D = j.camera
	var v: Vector3 = c.global_position + Vector3(0, 1.1, 0) - cam.global_position
	j.rotation.y = atan2(-v.x, -v.z)
	j.tete.rotation.x = clampf(atan2(v.y, Vector2(v.x, v.z).length()), -1.0, 0.6)
	j.vie = j.vie_max

## Un coup toutes les 12 images sur un gardien (tour à tour) : léger, lourd, critique ; un sur quatre de face au bouclier.
func _frapper(k: int) -> void:
	_viser()
	if k % 12 != 0:
		return
	_k += 1
	var c: Node3D = cibles[_k % cibles.size()]
	if not is_instance_valid(c) or not c.has_method("recevoir_coup"):
		return
	c.vie = 5000.0
	if c.get("combat") is CombatEnnemi:
		(c.combat as CombatEnnemi).etourdi = 0.0
		(c.combat as CombatEnnemi).posture = (c.combat as CombatEnnemi).profil.posture_max
	var sorte := _k % 4
	var vers := (j.global_position - c.global_position).normalized()
	var origine := j.global_position if sorte == 3 else c.global_position - vers * 2.0   # 3 : de face (bouclier possible)
	var info := {"point": c.global_position + Vector3(0, 1.2, 0) + vers * 0.25, "direction": vers.cross(Vector3.UP).normalized(),
		"zone": ["torse", "tete", "torse", "bras"][sorte], "attaque": ["legere", "lourde", "lourde", "legere"][sorte]}
	if sorte == 2:
		info["critique"] = true
	if sorte == 3:
		c.set("etat", c.get("TRAQUE"))
	c.recevoir_coup(30.0 if sorte in [1, 2] else 12.0, origine, sorte in [1, 2], info)
	j.ennemi_vise = c
