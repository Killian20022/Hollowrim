extends SceneTree
## Reproduction / mesure : combats dans la VRAIE crypte (foret_test, vrai joueur, vraies mains) contre les gardiens (squelettes
## et draugrs), coups légers / lourds / finishers. Avec fenêtre (temps d'image réels, compilations de pipelines) :
##   godot --path . --log-file <fichier> --disable-vsync --script res://outils/repro_crypte_combat.gd -- --nouvelle [--n=6] [--csv=C:/x.csv]
##         [--types=squelette,draugr] [--direct [--finisher]] [--gore=0|1|2]
## --direct : coups appliqués directement (temps CPU de l'appel mesuré), sinon vraies mains (mains.attaquer) ; --finisher : posture
## brisée au 4e coup puis finisher. --log-file : sans lui, le journal du projet (%APPDATA%/Hollowrim/logs) est celui du jeu exporté
## et ses rotations effacent les journaux du joueur.
## Imprime chaque image > 40 ms (avec ce qui venait de se passer), une ligne par coup (images, pire, gel = temps à time_scale < 1,
## pipelines compilés), puis un résumé : moyennes par sorte de coup, time_scale final, cadavres, corps rigides.
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var j: CharacterBody3D
var _evts: Array = []         # derniers événements (pour étiqueter les pics)
var _pics: Array = []
var _dts := PackedFloat32Array()
var _prec_us := 0
var _mesure := false
var _csv: FileAccess
var _pipe0 := 0
var _ts_bloque := 0
var _cible
var _coup := {}               # coup en cours : {nom, t0, max, gel (ms à time_scale < 1), pipes, n, vie0}
var _coups: Array = []

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _pipes() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))

func _evt(s: String) -> void:
	_evts.append([Time.get_ticks_msec(), s])
	if _evts.size() > 12:
		_evts.pop_front()

func _compter(classe: String) -> int:
	return root.find_children("*", classe, true, false).size()

func _sur_image() -> void:
	var n := Time.get_ticks_usec()
	var dt := (n - _prec_us) / 1000.0
	_prec_us = n
	if not _mesure:
		return
	_dts.append(dt)
	if Engine.time_scale < 0.99:
		_ts_bloque += 1
	else:
		_ts_bloque = 0
	var p := _pipes()
	if dt > 40.0:
		var recents := []
		for e in _evts:
			if Time.get_ticks_msec() - int(e[0]) < 400:
				recents.append(e[1])
		_pics.append([dt, p - _pipe0, recents])
		print("PIC %.1f ms  pipelines +%d  ts=%.2f  evts=%s" % [dt, p - _pipe0, Engine.time_scale, recents])
	_pipe0 = p
	var vp := root.get_viewport_rid()
	var proc := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var rcpu := RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	var rgpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
	if dt > 40.0:
		print("     detail : process %.1f  physique %.1f  rendu cpu %.1f  gpu %.1f" % [proc, phys, rcpu, rgpu])
	if not _coup.is_empty():
		_coup["max"] = maxf(_coup["max"], dt)
		_coup["proc"] = maxf(_coup.get("proc", 0.0), proc)
		_coup["phys"] = maxf(_coup.get("phys", 0.0), phys)
		_coup["rcpu"] = maxf(_coup.get("rcpu", 0.0), rcpu)
		_coup["rgpu"] = maxf(_coup.get("rgpu", 0.0), rgpu)
		_coup["n"] += 1
		_coup["somme"] += dt
		if Engine.time_scale < 0.99:
			_coup["gel"] += dt
		_coup["pipes"] = p - int(_coup["p0"])
	if _csv:
		_csv.store_line("%.2f,%.2f,%d" % [dt, Engine.time_scale, p])

func _go() -> void:
	if _arg("csv") != "":
		_csv = FileAccess.open(_arg("csv"), FileAccess.WRITE)
	if _arg("gore") != "":
		Sang.niveau_force = int(_arg("gore"))
	m = SCENE.instantiate()
	root.add_child(m)
	current_scene = m
	j = m.joueur
	process_frame.connect(_sur_image)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for k in 30:
		await process_frame
	var tt := Time.get_ticks_msec()
	while not m.tertre._donjon_pret() and Time.get_ticks_msec() - tt < 60000:
		await process_frame
	# le préchauffage du monde (PrechauffeRendu) tourne pendant les ~2 premières secondes de jeu, comme en partie
	for k in 120:
		await process_frame
	m.tertre._basculer(true)
	m._sous_terre(true)
	for k in 30:
		await process_frame
	var types := _arg("types", "squelette,draugr").split(",")
	var n_max := int(_arg("n", "6"))
	var choisis: Array = []
	var par_type := {}
	for g: Dictionary in m.tertre.donjon.gardiens:
		var ty := String(g["type"])
		var cle := "squelette" if ty.begins_with("squelette") else "draugr"
		if not cle in types or ty == "squelette_archer" or (g["extra"] as Dictionary).has("si") or (g["extra"] as Dictionary).has("reveil_evt") or (g["extra"] as Dictionary).has("boss"):
			continue
		if int(par_type.get(cle, 0)) >= ceili(n_max / float(types.size())):
			continue
		par_type[cle] = int(par_type.get(cle, 0)) + 1
		choisis.append(g)
	print("REPRO gardiens choisis : ", choisis.map(func(g): return "%s(%s)" % [g["ident"], g["type"]]))
	_pipe0 = _pipes()
	_prec_us = Time.get_ticks_usec()
	_mesure = true
	var i := 0
	for g: Dictionary in choisis:
		await _combattre(g, i)
		i += 1
	_mesure = false
	await _bilan()

func _combattre(g: Dictionary, i: int) -> void:
	var cr: Node3D = m.tertre.crypte
	var pos: Vector3 = cr.to_global(g["pos"])
	var id := String(g["ident"])
	_evt("approche " + id)
	# le joueur se pose à 2,2 m devant le gardien (dans sa direction de regard) ; les zones font apparaître les gardiens
	var face := Basis(Vector3.UP, cr.global_rotation.y + float(g["lacet"])).z
	j.global_position = pos + face * 2.2 + Vector3(0, 0.1, 0)
	var t0 := Time.get_ticks_msec()
	while not (m.draugrs.has(id) and is_instance_valid(m.draugrs[id])) and Time.get_ticks_msec() - t0 < 4000:
		m.tertre._gerer_zones()
		await process_frame
	if not m.draugrs.has(id):
		print("REPRO %s : n'apparaît pas" % id)
		return
	var e = m.draugrs[id]
	_cible = e
	if e.has_method("alerter"):
		e.alerter()
	if _arg("direct") != "":
		await _direct(e, g)
		return
	var lourd := i % 2 == 1
	var coups := 0
	var t1 := Time.get_ticks_msec()
	var mains = j.mains
	while e.vivant() and Time.get_ticks_msec() - t1 < 25000:
		j.vie = j.vie_max
		j.vigueur = j.vigueur_max
		_viser(e)
		if mains.combat.etat in [EtatCombat.REPOS, EtatCombat.MOUVEMENT, EtatCombat.RECUPERATION]:
			var fin: Dictionary = mains._chercher_finisher()
			if not fin.is_empty():
				_evt("finisher " + String(fin["categorie"]))
			else:
				_evt("coup " + ("lourd" if lourd else "leger"))
			coups += 1
			_fermer_coup()
			var nom_coup := "finisher" if not fin.is_empty() else ("lourd" if lourd and coups % 3 != 0 else "leger")
			_coup = {"nom": nom_coup, "cible": String(g["type"]), "max": 0.0, "gel": 0.0, "p0": _pipes(), "pipes": 0, "n": 0, "somme": 0.0, "vie0": float(e.vie)}
			mains.attaquer(nom_coup == "lourd")
			for k in 3:
				await process_frame
		await process_frame
		# reste au contact
		var v: Vector3 = e.global_position - j.global_position
		v.y = 0.0
		if v.length() > 1.9:
			j.velocity = v.normalized() * 3.0
	_fermer_coup()
	_evt("mort " + id)
	print("REPRO %s (%s) : %s après %d coups, %.1f s, ts=%.2f" % [id, g["type"], "tué" if not e.vivant() else "VIVANT", coups, (Time.get_ticks_msec() - t1) / 1000.0, Engine.time_scale])
	# on regarde le cadavre 2,5 s
	var t2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 2500:
		j.vie = j.vie_max
		await process_frame

## Coups appliqués directement (sans l'animation de l'épée) : temps CPU de l'appel lui-même, puis 0,6 s d'images mesurées.
func _direct(e, g: Dictionary) -> void:
	var seq := ["legere", "legere", "legere", "lourde", "legere", "lourde", "legere", "legere", "lourde", "legere", "legere", "lourde"]
	var arme: DonneesArme = j.mains.arme
	var k := 0
	while e.vivant() and k < 30:
		j.vie = j.vie_max
		_viser(e)
		var att: String = seq[k % seq.size()]
		if k == 3 and _arg("finisher") != "" and e.get("combat") != null:
			e.combat.briser_posture()          # posture brisée : le coup suivant est un finisher (décapitation)
			e._etourdir()
			await process_frame
		var cat := String(e.finisher_possible(j)) if e.has_method("finisher_possible") else ""
		var c0: Vector3 = e.global_position + Vector3(0, 1.2, 0)
		var dirj: Vector3 = (c0 - j.global_position).normalized()
		var info := {"type": "tranchant", "point": c0 - dirj * 0.25, "direction": j.global_transform.basis.x * (1 if k % 2 == 0 else -1), "normale": -dirj,
			"zone": "torse", "attaque": att, "arme": arme.id, "stagger": DegatsCombat.stagger(arme, att), "collider": e}
		_fermer_coup()
		var nom := "finisher" if cat != "" else ("lourd" if att == "lourde" else "leger")
		_coup = {"nom": nom, "cible": String(g["type"]), "max": 0.0, "gel": 0.0, "p0": _pipes(), "pipes": 0, "n": 0, "somme": 0.0, "vie0": float(e.vie)}
		var t := Time.get_ticks_usec()
		if cat != "":
			info["attaque"] = "finisher"
			info["origine"] = j.global_position
			info["stagger"] = 999.0
			info["zone"] = "tete"
			e.subir_finisher(cat, info)
		else:
			DegatsCombat.appliquer(e, (arme.degats_lourd if att == "lourde" else arme.degats_leger) * 0.6, j.global_position, att == "lourde", info)
		_coup["appel"] = (Time.get_ticks_usec() - t) / 1000.0
		_evt("%s appel %.1f ms" % [nom, _coup["appel"]])
		var t2 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t2 < 600:
			j.vie = j.vie_max
			await process_frame
		k += 1
	_fermer_coup()
	_evt("mort")
	var t3 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t3 < 2000:
		await process_frame

func _fermer_coup() -> void:
	if _coup.is_empty():
		return
	var touche: bool = _cible != null and is_instance_valid(_cible) and (float(_cible.vie) < float(_coup["vie0"]) or not _cible.vivant())
	_coup["touche"] = touche
	_coups.append(_coup)
	print("COUP %-8s %-10s appel %5.1f ms touche=%s  images %d  moy %.1f ms  pire %.1f ms  gel(time_scale<1) %.0f ms  pipelines +%d | max process %.1f physique %.1f rendu cpu %.1f gpu %.1f" % [_coup["nom"], _coup["cible"], _coup.get("appel", -1.0), touche, _coup["n"], _coup["somme"] / maxf(_coup["n"], 1), _coup["max"], _coup["gel"], _coup["pipes"], _coup.get("proc", 0.0), _coup.get("phys", 0.0), _coup.get("rcpu", 0.0), _coup.get("rgpu", 0.0)])
	_coup = {}

func _viser(e) -> void:
	var cam: Node3D = j.camera
	var v: Vector3 = e.global_position + Vector3(0, 1.2, 0) - cam.global_position
	j.rotation.y = atan2(-v.x, -v.z)
	j.tete.rotation.x = clampf(atan2(v.y, Vector2(v.x, v.z).length()), -1.0, 0.6)

func _bilan() -> void:
	var tri := _dts.duplicate()
	tri.sort()
	var moy := 0.0
	for d in _dts:
		moy += d
	moy /= maxf(_dts.size(), 1)
	var n25 := 0
	var n50 := 0
	for d in _dts:
		if d > 25.0: n25 += 1
		if d > 50.0: n50 += 1
	print("BILAN images %d  moyenne %.1f ms  p99 %.1f  pire %.1f  >25ms %d  >50ms %d" % [_dts.size(), moy, tri[int(tri.size() * 0.99)] if tri.size() > 0 else 0.0, tri[-1] if tri.size() > 0 else 0.0, n25, n50])
	print("BILAN time_scale final %.2f (images consécutives < 1 à la fin : %d)" % [Engine.time_scale, _ts_bloque])
	print("BILAN noeuds %d  RigidBody3D %d  PhysicalBone3D %d  Decal %d  GPUParticles3D %d  AudioStreamPlayer3D %d" % [int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), _compter("RigidBody3D"), _compter("PhysicalBone3D"), _compter("Decal"), _compter("GPUParticles3D"), _compter("AudioStreamPlayer3D")])
	var cr: Node3D = m.tertre.crypte
	for id in m.draugrs:
		var e = m.draugrs[id]
		if not is_instance_valid(e) or not String(id).begins_with("cr_"):
			continue
		if e.vivant():
			continue
		var pl: Vector3 = cr.to_local(e.global_position)
		var os_y := []
		for b in e.find_children("*", "PhysicalBone3D", true, false):
			os_y.append(snappedf(cr.to_local((b as Node3D).global_position).y, 0.01))
		print("BILAN cadavre %s pos locale %s  os y min %s" % [id, pl.snapped(Vector3.ONE * 0.01), os_y.min() if not os_y.is_empty() else "-"])
	for nom in ["leger", "lourd", "finisher"]:
		var l := _coups.filter(func(c): return c["nom"] == nom and c["touche"])
		if l.is_empty():
			continue
		var gel := 0.0
		var pire := 0.0
		var moyc := 0.0
		for c in l:
			gel += c["gel"]
			pire = maxf(pire, c["max"])
			moyc += c["somme"] / maxf(c["n"], 1)
		print("BILAN coups %s touchés : %d  gel moyen %.0f ms  image moyenne %.1f ms  pire image %.1f ms" % [nom, l.size(), gel / l.size(), moyc / l.size(), pire])
	for b in root.find_children("*", "RigidBody3D", true, false):
		print("BILAN corps rigide %s pos locale %s endormi %s" % [b.name, cr.to_local((b as Node3D).global_position).snapped(Vector3.ONE * 0.01), (b as RigidBody3D).sleeping])
	if _csv:
		_csv.close()
	quit(0)
