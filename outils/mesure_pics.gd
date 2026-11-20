extends SceneTree
## Pics du PREMIER passage (saccades ressenties par le joueur) : monde chargé à froid, puis parcours scripté par les VRAIS chemins du jeu
## (marche depuis le feu, entrée de la crypte par le fondu, entrée de la grotte par le fondu), puis 2e passage identique pour comparer.
## Fenêtre nécessaire (GPU réel), vsync coupé :
##   godot --path . --disable-vsync --script res://outils/mesure_pics.gd -- --nouvelle --paisible --cible=place|crypte|grotte|village [--etale]
## --etale : entrée du monde comme l'écran de chargement (arbre en pause, Jeu.chargement_etale) jusqu'à `pret` : donjon, ennemis, grotte et
##   préchauffages finis AVANT le parcours, comme en partie (sans lui, l'outil marche pendant que les fils de fond tournent encore).
## combat (sans --paisible) : entrée dans la crypte par le fondu, 6 gardiens réunis dans l'arène, puis une épée de feu
##   (effet d'élément), 6 coups, le 1er sort de chaque raccourci (1 à 3, deux mains, 3 s), 2e tour des sorts, enfin les 6 ennemis tués.
## village : tour des bâtiments enterables (intérieurs paresseux construits / libérés à la demande), entrée par chaque porte.
## Pics RELATIFS (machine partagée) : une ligne « SAUT » pour chaque image > 33 ms ET > 2,2 x la médiane des 30 précédentes ;
## « PICS » donne aussi sauts=.. (nombre de ces images) : c'est la grandeur à suivre quand la machine est chargée.
## Chaque ligne PIC/SAUT donne aussi obj+N (objets créés pendant l'image) et nds+N (nœuds).
## Sortie : « PIC <ms> [tronçon] A/B/C + pipelines compilés pendant l'image » pour chaque image > 33 ms, puis
## « PICS <tronçon> moy=.. pire=.. >33=.. n=.. » par tronçon, et « PICS chargement ... » (temps jusqu'au monde prêt).
## A = process (scripts, animations), B = soumission du rendu (compilations de pipelines comprises), C = présentation + physique.
const SEUIL := 33.0

var m: Node3D
var rid: RID
var cible := "place"
var _t_pf := 0
var _t_pre := 0
var _t_post := 0
var _a := 0.0
var _b := 0.0
var _c := 0.0
var prec := 0
var nom := ""            # tronçon en cours (vide : pas d'enregistrement)
var dts: PackedFloat32Array = PackedFloat32Array()
var pip_prec := 0
var t0 := 0
var debug := false
var dt_s := 0.016       # durée de la dernière image (s)
var _hist: Array[float] = []   # 30 dernières images (ms) : médiane glissante pour les sauts
var _sauts := 0
var _obj_prec := 0
var _ajouts := {}       # nœuds ajoutés pendant l'image : « parent/nom (classe) » -> nombre (imprimé sur un saut)
var _nds_prec := 0

func _init() -> void:
	_demarrer.call_deferred()

func _arg(n: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + n:
			return "1"
		if a.begins_with("--" + n + "="):
			return a.substr(n.length() + 3)
	return defaut

## Détail des compilations de pipelines : surface (à la création des instances, en fond), spécialisation, dessin (bloquante), maillage, canevas.
func _pip_detail() -> PackedInt32Array:
	return PackedInt32Array([int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))])

var _pd_prec := PackedInt32Array([0, 0, 0, 0, 0])

func _pipelines() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))

func _demarrer() -> void:
	cible = _arg("cible", "place")
	node_added.connect(func(n: Node) -> void:
		if nom == "":
			return
		var p := n.get_parent()
		var cle := "%s<%s" % [n.get_class(), (str(p.name) if p != null else "?")]
		var gp := p.get_parent() if p != null else null
		if gp != null:
			cle += "<" + str(gp.name)
		_ajouts[cle] = int(_ajouts.get(cle, 0)) + 1)
	debug = _arg("detail") != ""
	process_frame.connect(func() -> void:
		var n := Time.get_ticks_usec()
		if _t_post > 0:
			_c = (n - _t_post) / 1000.0
		_t_pf = n)
	RenderingServer.frame_pre_draw.connect(func() -> void:
		_t_pre = Time.get_ticks_usec()
		_a = (_t_pre - _t_pf) / 1000.0)
	RenderingServer.frame_post_draw.connect(func() -> void:
		_t_post = Time.get_ticks_usec()
		_b = (_t_post - _t_pre) / 1000.0)
	t0 = Time.get_ticks_msec()
	m = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	var etale := _arg("etale") != ""
	if etale:
		Jeu.chargement_etale = true
		paused = true
	root.add_child(m)
	current_scene = m
	if etale:
		while m.get("pret") != true and Time.get_ticks_msec() - t0 < 180000:
			await process_frame
		Jeu.chargement_etale = false
		paused = false
		print("PICS monde pret (chargement etale) a %d ms" % (Time.get_ticks_msec() - t0))
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	m.joueur.mains.visible = false
	prec = Time.get_ticks_usec()
	pip_prec = _pipelines()
	# chargement : jusqu'aux intérieurs prêts (le joueur attend au feu, comme en partie)
	nom = "chargement"
	while not m.village.prets and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	_clore()
	print("PICS monde pret (interieurs) a %d ms" % (Time.get_ticks_msec() - t0))
	await _attendre(1.0)
	if _arg("attendre-fils") != "":
		var tf := Time.get_ticks_msec()
		while _fils().replace("P", "") != "" and Time.get_ticks_msec() - tf < 120000:
			await process_frame
		print("PICS fils de fond termines apres %d ms" % (Time.get_ticks_msec() - tf))
	match cible:
		"place":
			await _place()
		"crypte":
			await _crypte()
		"grotte":
			await _grotte()
		"village":
			await _village()
		"combat":
			await _combat()
	print("PICS FIN")
	quit(0)

func _attendre(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await process_frame

func _poser(p: Vector3, lacet: float, tang := 0.0) -> void:
	m.joueur.global_position = p
	m.joueur.velocity = Vector3.ZERO
	m.joueur.rotation.y = lacet
	m.joueur.tete.rotation.x = deg_to_rad(tang)

## Marche (téléportation lissée) le long de points monde x,z au sol, regard dans le sens de la marche.
func _marcher(pts: Array, vitesse: float, sol: Callable) -> void:
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var d := a.distance_to(b)
		var f := 0.0
		var lacet := atan2(-(b - a).x, -(b - a).y)
		while f < d:
			var p := a.lerp(b, f / d)
			_poser(sol.call(p), lacet)
			await process_frame
			f += vitesse * clampf(dt_s, 0.004, 0.05)   # pas plafonné : une saccade ne fait pas sauter le tronçon
	return

func _tourner(centre: Vector3, duree: float) -> void:
	var t := 0.0
	while t < duree:
		_poser(centre, TAU * t / duree, -4.0)
		await process_frame
		t += clampf(dt_s, 0.004, 0.05)

func _sol_monde(p: Vector2) -> Vector3:
	return Vector3(p.x, m.hauteur(p.x, p.y) + 0.1, p.y)

const CHEMIN_PLACE := [Vector2(3, 9), Vector2(19, 17.5), Vector2(35, 30), Vector2(39.5, 42)]

func _place() -> void:
	for passage in [1, 2]:
		_poser(_sol_monde(CHEMIN_PLACE[0]), 0.0)
		await _attendre(1.5)
		nom = "approche_%d" % passage
		await _marcher(CHEMIN_PLACE.slice(0, 3), 5.0, _sol_monde)
		_clore()
		nom = "place_%d" % passage
		await _marcher(CHEMIN_PLACE.slice(2), 5.0, _sol_monde)
		await _tourner(_sol_monde(CHEMIN_PLACE[3]), 4.0)
		_clore()

## Tour du village : pour chaque bâtiment enterable, marche de 30 m dehors jusqu'à 7 m de sa porte, puis entrée par la porte jusqu'au
## centre et tour sur place (intérieurs paresseux construits en approche, libérés en s'éloignant : la marche suivante passe loin).
func _village() -> void:
	var ips: Array = m.village.interieurs
	for passage in [1, 2]:
		for ip: Interieur in ips:
			var porte: Vector3 = ip.to_global(ip.porte_locale)
			var centre: Vector3 = ip.to_global(Vector3(0, ip.sol_y + 0.05, 0))
			var dehors := porte + (porte - centre) * Vector3(1, 0, 1)
			dehors = porte + (dehors - porte).normalized() * 7.0
			var loin := porte + (dehors - porte).normalized() * 30.0
			var sol := func(p: Vector2) -> Vector3: return Vector3(p.x, m.hauteur(p.x, p.y) + 0.1, p.y)
			_poser(sol.call(Vector2(loin.x, loin.z)), 0.0)
			await _attendre(0.6)
			nom = "vers_%s_%d" % [ip.id, passage]
			await _marcher([Vector2(loin.x, loin.z), Vector2(dehors.x, dehors.z)], 5.0, sol)
			_clore()
			nom = "dans_%s_%d" % [ip.id, passage]
			var y_in := centre.y
			var dedans := func(p: Vector2) -> Vector3: return Vector3(p.x, y_in, p.y)
			await _marcher([Vector2(dehors.x, dehors.z), Vector2(porte.x, porte.z), Vector2(centre.x, centre.z)], 3.5, dedans)
			await _tourner(centre, 3.0)
			_clore()

func _combat() -> void:
	var j: CharacterBody3D = m.joueur
	m.tertre._passer(true)
	var t := Time.get_ticks_msec()
	nom = "entree_crypte"
	while not m.tertre.dedans and Time.get_ticks_msec() - t < 30000:
		await process_frame
	await _attendre(0.8)
	_clore()
	var tr = m.tertre
	tr.attendre_donjon()
	var cr: Node3D = tr.crypte
	nom = "reveil"
	for g: Dictionary in tr.donjon.gardiens:
		var ex: Dictionary = g["extra"]
		if String(g["type"]) == "squelette_archer" or ex.has("boss") or ex.has("si") or ex.has("reveil_evt"):
			continue
		_poser(cr.to_global(g["pos"]) + Vector3(0, 0.1, 3.0), cr.global_rotation.y)
		for k in 8:
			tr._gerer_zones()
			await process_frame
		if _vivants().size() >= 6:
			break
	_clore()
	var ens: Array = _vivants().slice(0, 6)
	print("PICS combat : %d ennemis" % ens.size())
	var centre := cr.to_global(Vector3(0, 0.1, -66.0))
	_poser(centre, cr.global_rotation.y)
	for i in ens.size():
		var a := TAU * i / maxf(1.0, ens.size())
		var e: Node3D = ens[i]
		e.process_mode = Node.PROCESS_MODE_INHERIT
		e.visible = true
		e.global_position = centre + Vector3(cos(a) * 4.0, 0.2, sin(a) * 4.0)
	m.joueur.mains.visible = true
	await _attendre(1.0)
	var viser := func() -> void:
		j.vie = j.vie_max
		j.mana = 100.0
		var c: Node3D = null
		for e in ens:
			if is_instance_valid(e) and e.vivant():
				c = e
				break
		if c != null:
			var v: Vector3 = c.global_position + Vector3(0, 1.1, 0) - j.camera.global_position
			j.rotation.y = atan2(-v.x, -v.z)
			j.tete.rotation.x = clampf(atan2(v.y, Vector2(v.x, v.z).length()), -1.0, 0.6)
	nom = "epee_feu"
	j.mains.equipement.equiper("droite", load("res://data/armes/epee_hrafn.tres"))
	for k in 6:
		viser.call()
		j.mains.attaquer(k == 5)
		await _attendre(0.9)
	_clore()
	var magie: Node = j.mains.magie
	for tour in [1, 2]:
		for rac in 3:
			nom = "sort%d_%d" % [rac + 1, tour]
			magie.raccourci(rac)
			await _attendre(0.3)
			magie.appuyer("gauche")
			magie.appuyer("droite")
			var t2 := 0.0
			while t2 < 3.0:
				viser.call()
				await process_frame
				t2 += clampf(dt_s, 0.004, 0.05)
			magie.relacher("gauche")
			magie.relacher("droite")
			await _attendre(0.5)
			_clore()
	nom = "mises_a_mort"
	for e in ens:
		if is_instance_valid(e) and e.vivant():
			e.recevoir_coup(9999.0, j.global_position, true, {})
			await _attendre(0.6)
	await _attendre(2.0)
	_clore()

func _vivants() -> Array:
	var r: Array = []
	for id in m.draugrs:
		var e = m.draugrs[id]
		if is_instance_valid(e) and e is Node3D and e.has_method("vivant") and e.vivant():
			r.append(e)
	return r

func _crypte() -> void:
	# même chemin que le joueur : marche jusqu'à la façade, fondu, attente « dedans »
	m.tertre._passer(true)
	var t := Time.get_ticks_msec()
	nom = "entree_crypte"
	while not m.tertre.dedans and Time.get_ticks_msec() - t < 30000:
		await process_frame
	await _attendre(0.8)
	_clore()
	var cr: Node3D = m.tertre.crypte
	var loc := func(p: Vector2) -> Vector3: return cr.to_global(Vector3(p.x, 0.1, p.y))
	for passage in [1, 2]:
		_poser(loc.call(Vector2(0, 0.5)), cr.global_rotation.y)
		await _attendre(0.5)
		nom = "colonne_haut_%d" % passage
		await _marcher([Vector2(0, 0.5), Vector2(0, -22)], 6.5, loc)
		_clore()
		nom = "colonne_22_48_%d" % passage
		await _marcher([Vector2(0, -22), Vector2(0, -48)], 6.5, loc)
		_clore()
		nom = "colonne_bas_%d" % passage
		await _marcher([Vector2(0, -48), Vector2(0, -66)], 6.5, loc)
		_clore()
		nom = "arene_%d" % passage
		await _tourner(loc.call(Vector2(0, -71)), 3.0)
		_clore()

func _grotte() -> void:
	var ga: Node3D = m.grotte_acces
	nom = "marche_grotte"
	await _marcher([Vector2(3, 9), Vector2(60, -20), Vector2(84, -27)], 6.0, _sol_monde)
	_clore()
	var t := Time.get_ticks_msec()
	nom = "attente_grotte"       # immobile devant l'entrée : intégration de la grotte (pose de la coque solide, préchauffage)
	while ga.grotte == null and Time.get_ticks_msec() - t < 30000:
		await process_frame
	print("PICS grotte prete ; prechauffe en cours=%s (attente %d ms)" % [ga.prechauffe != null and is_instance_valid(ga.prechauffe) and not ga.prechauffe.fini, Time.get_ticks_msec() - t])
	await _attendre(float(_arg("delai", "6")))
	_clore()
	print("PICS prechauffe finie=%s" % [ga.prechauffe == null or not is_instance_valid(ga.prechauffe) or ga.prechauffe.fini])
	nom = "entree_grotte"
	ga._passer(true)
	t = Time.get_ticks_msec()
	while not ga.dedans and Time.get_ticks_msec() - t < 10000:
		await process_frame
	await _attendre(2.0)
	_clore()
	var g: Node = ga.grotte
	var routes: Dictionary = g.routes_test()
	var l: Array = routes.values()[0]
	nom = "grotte_route"
	var k := 0
	while k < mini(l.size(), 400):
		var p: Vector3 = l[k]
		var q: Vector3 = l[mini(k + 4, l.size() - 1)]
		var dir := q - p
		_poser(p + Vector3(0, 0.1, 0), atan2(-dir.x, -dir.z))
		await process_frame
		k += 1
	_clore()

## Travaux de fond en cours (lettres) : V intérieurs du village, C fil de la crypte, E modèles d'ennemis, D pose du donjon par tranches,
## X extérieur de la grotte, G fil de la grotte, P préchauffage de la grotte.
func _fils() -> String:
	var s := ""
	if m == null:
		return s
	if m.village != null and not m.village.prets: s += "V"
	var tr: Node = m.tertre
	if tr != null:
		if int(tr.get("_tache")) >= 0: s += "C"
		if int(tr.get("_tache_en")) >= 0: s += "E"
		if not (tr.get("_reste_donjon") as Array).is_empty() or not (tr.get("_etapes_fin") as Array).is_empty(): s += "D"
	var ga: Node = m.grotte_acces
	if ga != null:
		if int(ga.get("_tache_ext")) >= 0: s += "X"
		if int(ga.get("_tache")) >= 0: s += "G"
		var pr = ga.get("prechauffe")
		if pr != null and is_instance_valid(pr) and not pr.fini: s += "P"
	return s

func _process(_dt: float) -> bool:
	var n := Time.get_ticks_usec()
	var ms := (n - prec) / 1000.0
	prec = n
	dt_s = ms / 1000.0
	var pip := _pipelines()
	var dp := pip - pip_prec
	pip_prec = pip
	var pd := _pip_detail()
	var det := "s%d/sp%d/d%d/m%d/c%d" % [pd[0] - _pd_prec[0], pd[1] - _pd_prec[1], pd[2] - _pd_prec[2], pd[3] - _pd_prec[3], pd[4] - _pd_prec[4]]
	_pd_prec = pd
	var ob := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var nd := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var dob := ob - _obj_prec
	var dnd := nd - _nds_prec
	_obj_prec = ob
	_nds_prec = nd
	var med := 0.0
	if _hist.size() >= 10:
		var tri := _hist.duplicate()
		tri.sort()
		med = tri[tri.size() / 2]
	_hist.append(ms)
	if _hist.size() > 30:
		_hist.pop_front()
	if nom == "":
		return false
	dts.append(ms)
	var saut := ms > SEUIL and med > 0.0 and ms > 2.2 * med
	if saut:
		_sauts += 1
	if saut or (ms > SEUIL and _arg("tous") != "") or (debug and dp > 0):
		var jp: Vector3 = m.joueur.global_position if m != null and m.joueur != null else Vector3.ZERO
		if cible == "crypte" and m.tertre.dedans:
			jp = m.tertre.crypte.to_local(jp)
		print("%s %6.1f ms [%s] t=%.1f s med=%.1f A=%.1f B=%.1f C=%.1f pipelines+%d (%s) obj%+d nds%+d fils=%s | joueur (%.1f, %.1f, %.1f) gpu=%.1f" % ["SAUT" if saut else "PIC", ms, nom, (Time.get_ticks_msec() - t0) / 1000.0, med, _a, _b, _c, dp, det, dob, dnd, _fils(), jp.x, jp.y, jp.z,
			RenderingServer.viewport_get_measured_render_time_gpu(rid)])
		if dnd > 5 or _ajouts.size() > 0:
			var cles := _ajouts.keys()
			cles.sort_custom(func(x, y) -> bool: return int(_ajouts[x]) > int(_ajouts[y]))
			var txt := []
			for c in cles.slice(0, 6):
				txt.append("%s x%d" % [c, _ajouts[c]])
			print("   ajouts : " + " ; ".join(txt))
	_ajouts.clear()
	return false

func _clore() -> void:
	if dts.is_empty():
		nom = ""
		return
	var s := 0.0
	var mx := 0.0
	var n33 := 0
	for v in dts:
		s += v
		mx = maxf(mx, v)
		if v > SEUIL:
			n33 += 1
	var tri := dts.duplicate()
	tri.sort()
	var p99: float = tri[mini(tri.size() - 1, int(tri.size() * 0.99))]
	var med: float = tri[tri.size() / 2]
	print("PICS %-18s moy=%6.2f med=%6.2f p99=%6.1f pire=%7.1f >33=%3d sauts=%3d n=%d (t=%.1f s, fils=%s)" % [nom, s / dts.size(), med, p99, mx, n33, _sauts, dts.size(), (Time.get_ticks_msec() - t0) / 1000.0, _fils()])
	_sauts = 0
	dts = PackedFloat32Array()
	nom = ""
