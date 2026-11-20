extends SceneTree
## Coût des PERSONNAGES (domaine persos_anim, passe d'optimisation 2026-11-20), A/B ENTRELACÉ dans un même lancement (bruit de la machine partagée
## réparti sur toutes les phases) :
##   godot --path . --disable-vsync --script res://outils/mesure_persos_ab.gd -- --nouvelle --paisible --lieu=place|temoin|combat [--pose=35,30,221,-8]
##        [--heure=12] [--phases=base,sans_modif,sans_anim,sans_ressorts,sans_ombres,sans_persos] [--images=180] [--tours=4]
## Chaque phase coupe UN poste sur TOUS les personnages (hors joueur) pendant --images images, puis le rend ; les phases tournent --tours fois.
## Imprime par phase : temps de process médian (moniteur Godot : scripts + animations + mise à jour différée des squelettes/modificateurs), dt médian,
## GPU médian, appels, primitives ; et un inventaire (squelettes, os, maillages skinnés visibles, modificateurs actifs par classe, AnimationMixer actifs).
## Diagnostic SEUL : les phases « sans_* » ne sont pas des réglages du jeu.
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var j: Node3D
var rid: RID
var phases: PackedStringArray
var images := 180
var tours := 4
var k_phase := 0
var k_img := 0
var res := {}          # phase -> {tp:[], dt:[], gpu:[], ap:[], pr:[]}
var prec := 0
var actif := false
var sauve: Array = []  # [objet, propriété, valeur] à rendre

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
	var lieu := _arg("lieu", "place")
	phases = _arg("phases", "base,sans_modif,sans_anim,sans_ressorts,sans_ombres,sans_persos").split(",", false)
	images = int(_arg("images", "180"))
	tours = int(_arg("tours", "4"))
	m = SCENE.instantiate()
	root.add_child(m)
	current_scene = m
	j = m.joueur
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for k in 60:
		await process_frame
	var th := Time.get_ticks_msec()
	while m.village.get("prets") != true and Time.get_ticks_msec() - th < 90000:
		await process_frame
	if lieu == "combat":
		await _combat()
	if _arg("heure") != "":
		m.cycle.heure = float(_arg("heure"))
	m.cycle._process(0.0)
	if lieu != "combat":
		m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	var tf := Time.get_ticks_msec()
	while _fils() != "" and Time.get_ticks_msec() - tf < 180000:     # travaux de fond (intérieurs, crypte, grotte) finis : mesure au repos
		await process_frame
	print("PERSOS fils de fond terminés après %d ms (reste « %s »)" % [Time.get_ticks_msec() - tf, _fils()])
	for k in 600:      # 10 s de stabilisation (60 i/s)
		await process_frame
	_inventaire("avant")
	for p in phases:
		res[p] = {"tp": PackedFloat32Array(), "dt": PackedFloat32Array(), "gpu": PackedFloat32Array(), "ap": PackedFloat32Array(), "pr": PackedFloat32Array()}
	_entrer(phases[0])
	prec = Time.get_ticks_usec()
	actif = true

func _persos() -> Array[Skeleton3D]:
	var l: Array[Skeleton3D] = []
	for sk: Skeleton3D in m.find_children("*", "Skeleton3D", true, false):
		if j != null and j.is_ancestor_of(sk):
			continue
		l.append(sk)
	return l

func _racine(sk: Skeleton3D) -> Node3D:
	var n: Node = sk
	while n != null and n != m:
		if n is CharacterBody3D or n is RigidBody3D:
			return n
		n = n.get_parent()
	return sk.get_parent() as Node3D

func _poser(o: Object, prop: String, v: Variant) -> void:
	sauve.append([o, prop, o.get(prop)])
	o.set(prop, v)

func _entrer(p: String) -> void:
	for sk in _persos():
		match p:
			"sans_modif":
				for c in sk.get_children():
					if c is SkeletonModifier3D and not (c is SpringBoneSimulator3D):
						_poser(c, "active", false)
			"sans_ressorts":
				for c in sk.get_children():
					if c is SpringBoneSimulator3D:
						_poser(c, "active", false)
			"sans_anim":
				var r := _racine(sk)
				for a: AnimationMixer in r.find_children("*", "AnimationMixer", true, false):
					_poser(a, "active", false)
			"sans_ombres":
				var r2 := _racine(sk)
				for g: GeometryInstance3D in r2.find_children("*", "GeometryInstance3D", true, false):
					_poser(g, "cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			"sans_persos":
				var r3 := _racine(sk)
				if r3 != null:
					_poser(r3, "visible", false)
					_poser(r3, "process_mode", Node.PROCESS_MODE_DISABLED)

func _sortir() -> void:
	sauve.reverse()
	for s in sauve:
		if is_instance_valid(s[0]):
			(s[0] as Object).set(s[1], s[2])
	sauve.clear()

func _process(_dt: float) -> bool:
	if not actif:
		return false
	var now := Time.get_ticks_usec()
	var d := (now - prec) / 1000.0
	prec = now
	if j != null and "vie" in j:
		j.vie = j.vie_max
	k_img += 1
	if k_img > 20:     # 20 images de mise en régime après chaque bascule
		var r: Dictionary = res[phases[k_phase % phases.size()]]
		r["tp"].append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		r["dt"].append(d)
		r["gpu"].append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		r["ap"].append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		r["pr"].append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if k_img >= images + 20:
		_sortir()
		k_img = 0
		k_phase += 1
		if k_phase >= phases.size() * tours:
			actif = false
			_fin.call_deferred()
			return false
		_entrer(phases[k_phase % phases.size()])
	return false

func _med(a: PackedFloat32Array, q := 0.5) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[mini(b.size() - 1, int(b.size() * q))]

func _inventaire(quand: String) -> void:
	var nsk := 0
	var nvis := 0
	var nos := 0
	var nskin := 0
	var nmix := 0
	var mods := {}
	for sk in _persos():
		nsk += 1
		if not sk.is_visible_in_tree():
			continue
		nvis += 1
		nos += sk.get_bone_count()
		for c in sk.get_children():
			if c is SkeletonModifier3D and (c as SkeletonModifier3D).active:
				var cl: String = c.get_class()
				var sc: Script = c.get_script()
				if sc != null:
					cl = sc.resource_path.get_file() if sc.resource_path != "" else "classe interne " + str(sc.get_instance_base_type())
				mods[cl] = int(mods.get(cl, 0)) + 1
		var r := _racine(sk)
		for mi: MeshInstance3D in r.find_children("*", "MeshInstance3D", true, false):
			if mi.skin != null or (mi.skeleton != NodePath("") and mi.mesh != null and mi.is_visible_in_tree()):
				nskin += 1
		for a: AnimationMixer in r.find_children("*", "AnimationMixer", true, false):
			if a.active:
				nmix += 1
	print("PERSOS %s squelettes=%d visibles=%d os_visibles=%d maillages_skinnes=%d animationmixer_actifs=%d modificateurs_actifs=%s" % [quand, nsk, nvis, nos, nskin, nmix, str(mods)])

func _fin() -> void:
	_inventaire("apres")
	var b: Dictionary = res[phases[0]]
	for p in phases:
		var r: Dictionary = res[p]
		print("PHASE %-14s n=%d process_med=%.3f (p95 %.3f) dt_med=%.2f gpu_med=%.2f appels=%.0f prims=%.0f | ecart process vs %s = %+.3f ms, gpu %+.2f ms" % [
			p, r["tp"].size(), _med(r["tp"]), _med(r["tp"], 0.95), _med(r["dt"]), _med(r["gpu"]), _med(r["ap"]), _med(r["pr"]), phases[0],
			_med(r["tp"]) - _med(b["tp"]), _med(r["gpu"]) - _med(b["gpu"])])
	quit(0)

## Arène de la crypte avec 6 ennemis réveillés (comme audit_mesure_lieu --lieu=combat, sans les sorts).
func _combat() -> void:
	var tt := Time.get_ticks_msec()
	while not m.tertre._donjon_pret() and Time.get_ticks_msec() - tt < 90000:
		await process_frame
	m.tertre._basculer(true)
	m._sous_terre(true)
	j.mains.visible = true
	var t = m.tertre
	t.attendre_donjon()
	t.dedans = true
	var cr: Node3D = t.crypte
	cr.visible = true
	for g: Dictionary in t.donjon.gardiens:
		var ex: Dictionary = g["extra"]
		if String(g["type"]) == "squelette_archer" or ex.has("boss") or ex.has("si") or ex.has("reveil_evt"):
			continue
		j.global_position = cr.to_global(g["pos"]) + Vector3(0, 0.1, 3.0)
		for k in 8:
			t._gerer_zones()
			await process_frame
		if _vivants().size() >= 6:
			break
	var ennemis := _vivants().slice(0, 6)
	var centre := cr.to_global(Vector3(0, 0.1, -66.0))
	j.global_position = centre
	j.velocity = Vector3.ZERO
	for i in ennemis.size():
		var a := TAU * i / maxf(1.0, ennemis.size())
		var e: Node3D = ennemis[i]
		e.process_mode = Node.PROCESS_MODE_INHERIT
		e.visible = true
		e.global_position = centre + Vector3(cos(a) * 5.0, 0.2, sin(a) * 5.0)
	print("PERSOS combat : %d ennemis réunis" % ennemis.size())

func _vivants() -> Array:
	var r: Array = []
	for id in m.draugrs:
		var e = m.draugrs[id]
		if is_instance_valid(e) and e is Node3D and e.has_method("vivant") and e.vivant():
			r.append(e)
	return r

## Travaux de fond en cours (copie d'audit_mesure_lieu._fils).
func _fils() -> String:
	var s := ""
	var vil: Node = m.get("village")
	if vil != null and vil.get("prets") == false: s += "V"
	var tr: Node = m.get("tertre")
	if tr != null and tr.get("bati") == true:
		if _n(tr, "_tache") >= 0: s += "C"
		if _n(tr, "_tache_en") >= 0: s += "E"
		if not (tr.get("_reste_donjon") as Array).is_empty() or not (tr.get("_etapes_fin") as Array).is_empty(): s += "D"
	var ga: Node = m.get("grotte_acces")
	if ga != null:
		if _n(ga, "_tache_ext") >= 0: s += "X"
		if _n(ga, "_tache") >= 0: s += "G"
		var jeu: Object = ga.get("jeu")
		if jeu != null and _n(jeu, "_tache_en") >= 0: s += "e"
		var pr = ga.get("prechauffe")
		if pr != null and is_instance_valid(pr) and not pr.fini: s += "P"
	return s

func _n(o: Object, prop: String) -> int:
	var v: Variant = o.get(prop)
	return int(v) if v != null else -1
