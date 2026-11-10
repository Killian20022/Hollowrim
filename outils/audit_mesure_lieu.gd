extends SceneTree
## Audit perf 2026-11-04 : mesure d'UN lieu, de jour ou de nuit (fenêtre nécessaire, vsync coupé) :
##   godot --path . --disable-vsync --script res://outils/audit_mesure_lieu.gd -- --nouvelle --paisible --lieu=temoin|place|foret|halle|crypte|grotte|combat [--heure=12] [--duree=20]
## --capture=<fichier.png> : enregistre aussi une image du rendu (après la mesure), pour les planches avant|après.
## 10 s de stabilisation puis --duree s de mesure. Imprime une ligne « LIEU … » : gpu_med, gpu_p95, gpu_max, dt (temps réel par image) med/p95/p99/max,
## images > 16,7 ms et > 33 ms, appels de dessin, primitives, objets, mémoire (statique, vidéo, textures, tampons), nœuds, charge de la machine.
## « combat » : SANS --paisible ; 6 ennemis réveillés autour du joueur dans l'arène de la crypte + sorts maintenus (raccourcis 1 à 3 en rotation).
const SCENE := preload("res://scenes/foret_test.tscn")
const STAB := 10.0

var m: Node3D
var j: CharacterBody3D
var rid: RID
var lieu := "temoin"
var duree := 20.0
var t := 0.0
var phase := "init"
var gpu := PackedFloat32Array()
var cpu := PackedFloat32Array()
var dts := PackedFloat32Array()
var appels := 0.0
var prims := 0.0
var objets := 0.0
var n := 0
var prec_us := 0
var ennemis: Array = []
var t_sort := 0.0
var rac := 0
var tp := PackedFloat32Array()
var tph := PackedFloat32Array()

## Sonde de temps : deux nœuds de priorité extrême encadrent TOUS les _process / _physics_process (et animations internes) de l'arbre.
class Sonde extends Node:
	var debut := false
	var us := 0
	var t0 := 0
	var sonde_debut: Sonde
	var cumul := PackedFloat32Array()
	var actif := false
	func _process(_dt: float) -> void:
		_tic()
	func _physics_process(_dt: float) -> void:
		_tic()
	func _tic() -> void:
		var maintenant := Time.get_ticks_usec()
		if debut:
			t0 = maintenant
		elif actif:
			cumul.append((maintenant - sonde_debut.t0) / 1000.0)

## Profil par script (--profil) : une sonde après chaque groupe de nœuds (priorité = rang du groupe × 10) ; la différence de deux horodatages = coût du groupe.
class SondeGroupe extends Node:
	var idx := 0
	var hote
	func _process(_dt: float) -> void:
		hote.tic(idx, false)
	func _physics_process(_dt: float) -> void:
		hote.tic(idx, true)

var etiquettes: Array[String] = []
var cout := [PackedFloat64Array(), PackedFloat64Array()]    # [process, physics] : µs cumulées par groupe
var prec := [0, 0]
var mesure_groupes := false

func tic(idx: int, ph: bool) -> void:
	var now := Time.get_ticks_usec()
	var k := 1 if ph else 0
	if idx > 0 and mesure_groupes:
		cout[k][idx] += now - prec[k]
	prec[k] = now

func _grouper() -> void:
	var idx_de: Dictionary = {}
	for nd in m.find_children("*", "", true, false):
		var sc: Script = nd.get_script()
		var nom: String
		if nd is Skeleton3D:
			nom = "(Skeleton3D + modificateurs IK/tête/pieds)"
		elif nd is AnimationMixer:
			nom = "(AnimationPlayer/Tree)"
		elif sc != null:
			nom = sc.resource_path.get_file()
		else:
			nom = "(" + nd.get_class() + ")"
		if not idx_de.has(nom):
			idx_de[nom] = idx_de.size() + 1
		var g: int = idx_de[nom]
		nd.process_priority = g * 10
		nd.process_physics_priority = g * 10
	etiquettes.resize(idx_de.size() + 1)
	etiquettes[0] = "(autres : joueur, monde, nœuds créés après le début)"
	for nom in idx_de:
		etiquettes[idx_de[nom]] = nom
	for k in 2:
		cout[k].resize(etiquettes.size())
	for g in range(0, etiquettes.size()):
		var sd := SondeGroupe.new()
		sd.idx = g
		sd.hote = self
		sd.process_priority = g * 10 + 5 if g > 0 else -100000
		sd.process_physics_priority = sd.process_priority
		root.add_child(sd)

func _rapport_groupes() -> void:
	var lst: Array = []
	for g in range(1, etiquettes.size()):
		lst.append(["#%d %s" % [g, etiquettes[g]], cout[0][g] / 1000.0 / n, cout[1][g] / 1000.0 / n])
	lst.sort_custom(func(a, b): return a[1] + a[2] > b[1] + b[2])
	var tp_tot := 0.0
	var tph_tot := 0.0
	for e in lst:
		tp_tot += e[1]
		tph_tot += e[2]
	print("PROFIL ===== coût moyen PAR IMAGE (ms) : process %.2f + physics %.2f (tous les pas de l'image) =====" % [tp_tot, tph_tot])
	for e in lst.slice(0, 25):
		print("PROFIL %-52s process=%.3f  physics=%.3f  total=%.3f ms" % [e[0], e[1], e[2], e[1] + e[2]])

var sondes_p: Array[Sonde] = []
var sondes_ph: Array[Sonde] = []

func _poser_sondes() -> void:
	for ph in [false, true]:
		var a := Sonde.new()
		var b := Sonde.new()
		a.debut = true
		b.sonde_debut = a
		a.process_priority = -100000
		b.process_priority = 100000
		a.process_physics_priority = -100000
		b.process_physics_priority = 100000
		root.add_child(a)
		root.add_child(b)
		a.set_process(not ph)
		b.set_process(not ph)
		a.set_physics_process(ph)
		b.set_physics_process(ph)
		(sondes_ph if ph else sondes_p).assign([a, b])

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _go() -> void:
	lieu = _arg("lieu", "temoin")
	duree = float(_arg("duree", "20"))
	var t0 := Time.get_ticks_msec()
	m = SCENE.instantiate()
	root.add_child(m)
	current_scene = m
	j = m.joueur
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	print("LIEU instanciation du monde %d ms" % (Time.get_ticks_msec() - t0))
	for k in 60:
		await process_frame
	match lieu:
		"temoin", "place":
			pass   # --pose passé au jeu
		"foret":
			_vers_foret()
		"halle":      # intérieur le plus chargé (halle de Gunnar : tables servies) ; A/B des objets vivants : -- --sans-objets-vivants
			var th := Time.get_ticks_msec()
			while m.village.get("prets") != true and Time.get_ticks_msec() - th < 90000:
				await process_frame
			var ip: Interieur = m.village.interieur("halle")
			j.global_position = ip.to_global(Vector3(3.4, ip.sol_y + 0.05, 0.9))
			j.velocity = Vector3.ZERO
			j.rotation.y = ip.global_rotation.y + deg_to_rad(25.0)      # vers la table servie côté +X et le foyer
			j.tete.rotation.x = deg_to_rad(-14.0)
			for k in 30:
				await process_frame
		"crypte", "combat":
			var tt := Time.get_ticks_msec()
			while not m.tertre._donjon_pret() and Time.get_ticks_msec() - tt < 90000:
				await process_frame
			m.tertre._basculer(true)
			m._sous_terre(true)
			j.mains.visible = true
			j.global_position = m.tertre.crypte.to_global(Vector3(0, 0.1, -66.0 if lieu == "combat" else -25.0))
			j.velocity = Vector3.ZERO
			for k in 30:
				await process_frame
			if lieu == "combat":
				await _reveiller()
		"grotte":
			var tt2 := Time.get_ticks_msec()
			while m.grotte_acces.grotte == null and Time.get_ticks_msec() - tt2 < 90000:
				await process_frame
			m.grotte = m.grotte_acces.obtenir()
			m.grotte_acces.montrer(true)
			m._sous_terre(true)
			m.grotte.ambiance(m._env)
			var routes: Dictionary = m.grotte.routes_test()
			var best: Array = []
			for id in routes:
				if (routes[id] as Array).size() > best.size():
					best = routes[id]
			var p: Vector3 = best[best.size() / 2]
			j.global_position = p + Vector3(0, 0.1, 0)
			j.velocity = Vector3.ZERO
			j.rotation.y = atan2(-(best[best.size() / 2 + 1] - p).x, -(best[best.size() / 2 + 1] - p).z)
	# heure figée (jour ou nuit comparables), éclairage appliqué une fois
	if _arg("heure") != "":
		m.cycle.heure = float(_arg("heure"))
	m.cycle._process(0.0)
	if lieu != "combat":
		m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	_experience(_arg("exp"))
	_sans(_arg("sans"))
	_poser_sondes()
	if _arg("profil") == "groupes":
		_grouper()
	print("LIEU %s heure=%.1f pos=%s exp=%s" % [lieu, m.cycle.heure, j.global_position, _arg("exp")])
	prec_us = Time.get_ticks_usec()
	phase = "mesure"

## --exp=glow|ombre|brume|ciel|post|tout : coupe UN poste pour chiffrer son coût GPU (diagnostic, sans toucher au jeu).
func _experience(e: String) -> void:
	var env: Environment = m._env
	for x in e.split(",", false):
		match x:
			"glow": env.glow_enabled = false
			"brume": env.fog_enabled = false
			"ombre":
				for l in m.find_children("*", "DirectionalLight3D", true, false):
					(l as DirectionalLight3D).shadow_enabled = false
			"lumieres":
				for l in m.find_children("*", "Light3D", true, false):
					if not (l is DirectionalLight3D):
						(l as Light3D).visible = false
			"post":
				for c in root.find_children("*", "CanvasItem", true, false):
					if c is ColorRect or c is TextureRect:
						(c as CanvasItem).visible = false

## --sans=a,b : coupe _process/_physics_process des nœuds dont le script contient « a » ou « b » (diagnostic CPU : l'écart de dt_med chiffre le poste).
## --sans=tous coupe tout sauf le joueur et le monde. --profil : classement des scripts par nombre de nœuds actifs + TIME_PROCESS/TIME_PHYSICS_PROCESS.
func _sans(liste: String) -> void:
	if liste == "":
		return
	var motifs := liste.split(",", false)
	var k := 0
	for nd in m.find_children("*", "", true, false):
		if nd is AnimationMixer and ("anim" in motifs or "tous" in motifs):
			(nd as AnimationMixer).active = false
			k += 1
		var sc: Script = nd.get_script()
		if sc == null or nd == j or nd == m:
			continue
		var chemin := sc.resource_path.get_file()
		for mo in motifs:
			if mo == "tous" or chemin.contains(mo):
				nd.set_process(false)
				nd.set_physics_process(false)
				k += 1
				break
	print("LIEU sans : %d nœuds coupés (%s)" % [k, liste])

func _profil() -> void:
	var par: Dictionary = {}
	for nd in m.find_children("*", "", true, false):
		var sc: Script = nd.get_script()
		var nom := sc.resource_path.get_file() if sc != null else "(" + nd.get_class() + ")"
		var pr: bool = nd.is_processing()
		var ph: bool = nd.is_physics_processing()
		if not (pr or ph):
			continue
		if sc == null and not (nd is AnimationMixer or nd is GPUParticles3D):
			nom = "(moteur " + nd.get_class() + ")"
		var e: Array = par.get(nom, [0, 0, 0])
		e[0] += 1
		e[1] += 1 if pr else 0
		e[2] += 1 if ph else 0
		par[nom] = e
	var na := 0
	var nsk := 0
	var nbs := 0
	var nrb := 0
	for nd in m.find_children("*", "", true, false):
		if nd is AnimationMixer and (nd as AnimationMixer).active:
			na += 1
		elif nd is Skeleton3D:
			nsk += 1
			nbs += (nd as Skeleton3D).get_bone_count()
		elif nd is RigidBody3D and not (nd as RigidBody3D).sleeping:
			nrb += 1
	print("PROFIL AnimationMixer actifs=%d  Skeleton3D=%d (os=%d)  RigidBody éveillés=%d" % [na, nsk, nbs, nrb])
	var cles := par.keys()
	cles.sort_custom(func(a, b): return par[a][0] > par[b][0])
	for c in cles.slice(0, 40):
		print("PROFIL %-34s nœuds=%d process=%d physics=%d" % [c, par[c][0], par[c][1], par[c][2]])

func _vers_foret() -> void:
	# point le plus dense en arbres (rayon 14 m), hors village / cercle / feu
	var best := Vector3.ZERO
	var bn := -1
	var pts: Array = []
	for tr: Transform3D in m.arbres:
		pts.append(Vector2(tr.origin.x, tr.origin.z))
	var x := -100.0
	while x <= 100.0:
		var z := -100.0
		while z <= 100.0:
			var c := Vector2(x, z)
			if c.distance_to(Vector2(44, 40)) > 40.0 and c.distance_to(Vector2.ZERO) > 20.0 and c.distance_to(Vector2(-38, -34)) > 20.0:
				var k := 0
				for p: Vector2 in pts:
					if p.distance_squared_to(c) < 196.0:
						k += 1
				if k > bn:
					bn = k
					best = Vector3(x, 0, z)
			z += 6.0
		x += 6.0
	print("LIEU foret : %d arbres à 14 m autour de (%.0f, %.0f) sur %d arbres" % [bn, best.x, best.z, pts.size()])
	j.global_position = Vector3(best.x, m.hauteur(best.x, best.z) + 0.1, best.z)
	j.velocity = Vector3.ZERO
	j.rotation.y = 0.5

func _reveiller() -> void:
	var t = m.tertre
	t.attendre_donjon()
	t.dedans = true
	var cr: Node3D = t.crypte
	cr.visible = true
	for g: Dictionary in t.donjon.gardiens:
		var ex: Dictionary = g["extra"]
		if String(g["type"]) == "squelette_archer" or ex.has("boss") or ex.has("si") or ex.has("reveil_evt"):
			continue
		var pos: Vector3 = cr.to_global(g["pos"])
		j.global_position = pos + Vector3(0, 0.1, 3.0)
		for k in 8:
			t._gerer_zones()
			await process_frame
		if _vivants().size() >= 6:
			break
	ennemis = _vivants().slice(0, 6)
	print("LIEU combat : %d ennemis vivants réunis" % ennemis.size())
	var centre := cr.to_global(Vector3(0, 0.1, -66.0))
	j.global_position = centre
	j.velocity = Vector3.ZERO
	for i in ennemis.size():
		var a := TAU * i / maxf(1.0, ennemis.size())
		var e: Node3D = ennemis[i]
		e.process_mode = Node.PROCESS_MODE_INHERIT
		e.visible = true
		e.global_position = centre + Vector3(cos(a) * 5.0, 0.2, sin(a) * 5.0)
	for k in 30:
		await process_frame

func _vivants() -> Array:
	var r: Array = []
	for id in m.draugrs:
		var e = m.draugrs[id]
		if is_instance_valid(e) and e is Node3D and e.has_method("vivant") and e.vivant():
			r.append(e)
	return r

func _process(dt: float) -> bool:
	if phase == "init" or phase == "fin":
		return false
	t += dt
	var now := Time.get_ticks_usec()
	if _arg("profil") != "" and t >= STAB and n == 0:
		_profil()
	tp.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0) if t >= STAB else null
	tph.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0) if t >= STAB else null
	var d_ms := (now - prec_us) / 1000.0
	prec_us = now
	if lieu != "foret" or true:
		j.vie = j.vie_max
		j.mana = 100.0
	if lieu == "combat":
		_sorts(dt)
	if t < STAB:
		return false
	if n == 0:
		mesure_groupes = true
		sondes_p[1].actif = true
		sondes_ph[1].actif = true
	n += 1
	var g := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	gpu.append(g)
	cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	dts.append(d_ms)
	appels += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	objets += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	if t >= STAB + duree:
		phase = "fin"
		_terminer.call_deferred()
	return false

func _terminer() -> void:
	_fin()
	if _arg("capture") != "":
		await capturer(_arg("capture"))
	quit(0)

func capturer(chemin: String) -> void:
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.convert(Image.FORMAT_RGB8)
	im.save_png(chemin)

func _sorts(dt: float) -> void:
	var cible: Node3D = null
	var dmin := 1e9
	for e in ennemis:
		if is_instance_valid(e) and e is Node3D:
			var d := (e as Node3D).global_position.distance_to(j.global_position)
			if d < dmin:
				dmin = d
				cible = e
	if cible != null:
		var v: Vector3 = cible.global_position + Vector3(0, 1.1, 0) - j.camera.global_position
		j.rotation.y = atan2(-v.x, -v.z)
		j.tete.rotation.x = clampf(atan2(v.y, Vector2(v.x, v.z).length()), -1.0, 0.6)
	var magie: Node = j.mains.magie
	t_sort -= dt
	if t_sort <= 0.0:
		t_sort = 5.0
		magie.relacher("gauche")
		magie.relacher("droite")
		rac = (rac + 1) % 3
		magie.raccourci(rac)
		magie.appuyer("gauche")
		magie.appuyer("droite")

func _moy(a: PackedFloat32Array) -> float:
	var x := 0.0
	for v in a:
		x += v
	return x / maxf(1.0, a.size())

func _pct(a: PackedFloat32Array, p: float) -> float:
	var b := a.duplicate()
	b.sort()
	return b[mini(b.size() - 1, int(b.size() * p))]

func _fin() -> void:
	if mesure_groupes:
		_rapport_groupes()
	var s16 := 0
	var s33 := 0
	for d in dts:
		if d > 16.7:
			s16 += 1
		if d > 33.0:
			s33 += 1
	print("LIEU %s heure=%.1f gpu_med=%.2f gpu_p95=%.2f gpu_max=%.2f cpu_med=%.2f dt_med=%.2f dt_p95=%.2f dt_p99=%.2f dt_max=%.1f >16.7=%d(%.1f%%) >33=%d n=%d appels=%d prims=%d objets=%d" % [
		lieu, m.cycle.heure, _pct(gpu, 0.5), _pct(gpu, 0.95), _pct(gpu, 1.0), _pct(cpu, 0.5), _pct(dts, 0.5), _pct(dts, 0.95), _pct(dts, 0.99), _pct(dts, 1.0),
		s16, 100.0 * s16 / n, s33, n, appels / n, prims / n, objets / n])
	print("LIEU scripts_process_med=%.2f p95=%.2f ms | scripts_physics_med=%.2f p95=%.2f ms (par pas ; %d pas) | moy process=%.2f" % [
		_pct(sondes_p[1].cumul, 0.5), _pct(sondes_p[1].cumul, 0.95), _pct(sondes_ph[1].cumul, 0.5), _pct(sondes_ph[1].cumul, 0.95), sondes_ph[1].cumul.size(), _moy(sondes_p[1].cumul)])
	print("LIEU temps_process_med=%.2f ms physics_med=%.2f ms (moniteurs Godot, p95 %.2f / %.2f)" % [_pct(tp, 0.5), _pct(tph, 0.5), _pct(tp, 0.95), _pct(tph, 0.95)])
	print("LIEU physique 3D : objets actifs=%d paires=%d îlots=%d | nœuds animés=%d" % [Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT), 0])
	print("LIEU mémoire statique=%.0f Mo vidéo=%.0f Mo textures=%.0f Mo tampons=%.0f Mo noeuds=%d objets=%d orphelins=%d" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
