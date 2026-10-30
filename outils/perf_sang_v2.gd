extends SceneTree
## Coût du SANG V2 (combat/sang_v2) : scenes/test_combat.tscn, 3 draugrs serrés frappés en boucle (coups programmés : giclées,
## plaies, gerbes), sang v2 coupé puis actif, après une passe de chauffe, en alternance (A B B A A B B A), FENÊTRE (temps GPU mesuré) via godot_slot.sh :
##   godot --path . --disable-vsync --script res://outils/perf_sang_v2.gd -- --nouvelle
## Imprime par passe (médianes par image) : temps CPU de process (ms/image), temps de rendu CPU et GPU du viewport (ms/image), et le temps CPU propre
## au sang v2 (SangLame + GouttesSang, µs/image). Ligne finale « SURCOUT » : moyenne(actif) − moyenne(coupé).

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const IMAGES := 480

var s: Node3D
var _n := 0

func _init() -> void:
	_go.call_deferred()

func _ennemi(pos: Vector3) -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "guerrier"
	d.joueur = s.joueur
	d.hud = s.hud
	d.ident = "perf_sang_%d" % _n
	d.position = pos
	d.rotation.y = atan2(-pos.x, -pos.z) + PI
	s.add_child(d)
	d.vie = 1e6
	d.vie_max = 1e6
	d.combat.profil.chance_blocage = 0.0
	d.combat.profil.posture_max = 1e6
	d.combat.posture = 1e6
	return d

func _passe(actif: bool, cibles: Array) -> Dictionary:
	SangLame.actif = actif
	if is_instance_valid(SangLame.instance):
		SangLame.instance.nettoyer()
	for k in 60:
		await process_frame
	var vp := root.get_viewport().get_viewport_rid()
	var proc := PackedFloat32Array()
	var rcpu := PackedFloat32Array()
	var rgpu := PackedFloat32Array()
	var us0 := SangLame.cout_us + GouttesSang.cout_us
	for f in IMAGES:
		if f % 18 == 0:
			var d: Node3D = cibles[(f / 18) % cibles.size()]
			var dir := Vector3(1, -0.2, 0) if (f / 18) % 2 == 0 else Vector3(-1, -0.2, 0)
			var vers: Vector3 = s.joueur.global_position - d.global_position
			vers.y = 0.0
			vers = vers.normalized()
			d.recevoir_coup(1.0, s.joueur.global_position, false, {"type": "tranchant", "point": d.global_position + Vector3(0, 1.0, 0) + vers * 0.2,
				"direction": dir.normalized(), "normale": vers, "attaque": "legere", "instant": 0.1, "charge": 0.0, "arme": "epee_metal"})
		await process_frame
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		rcpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		rgpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	var us := SangLame.cout_us + GouttesSang.cout_us - us0
	# MÉDIANES (machine partagée par plusieurs agents : les moyennes prennent les pics des autres processus)
	var r := {"proc": _mediane(proc), "rcpu": _mediane(rcpu), "rgpu": _mediane(rgpu), "propre_us": float(us) / IMAGES}
	print("PASSE %s : process %.3f ms, rendu CPU %.3f ms, rendu GPU %.3f ms, sang v2 propre %.1f µs/image, gouttes en vol %d" % [
		"actif" if actif else "coupé", r["proc"], r["rcpu"], r["rgpu"], r["propre_us"], GouttesSang.en_vol()])
	return r

func _mediane(a: PackedFloat32Array) -> float:
	a.sort()
	return a[a.size() / 2]

func _go() -> void:
	Sang.niveau_force = 2
	RetourCoups.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport().get_viewport_rid(), true)
	s.mannequin.position = Vector3(-6.0, 0, 5.0)
	s.placer_joueur(Vector3(0, 0, 0.4), 0.0, -4.0)
	var cibles := [_ennemi(Vector3(-0.75, 0, -1.25)), _ennemi(Vector3(0.15, 0, -1.45)), _ennemi(Vector3(1.0, 0, -1.3))]
	for d in cibles:
		d.set_physics_process(false)
	for k in 90:
		await process_frame
	var res := {true: [], false: []}
	await _passe(false, cibles)   # chauffe (shaders compilés, caches) : non comptée
	await _passe(true, cibles)
	for actif in [false, true, true, false, false, true, true, false]:
		res[actif].append(await _passe(actif, cibles))
	var moy := func(l: Array, cle: String) -> float:
		var t := 0.0
		for r: Dictionary in l:
			t += float(r[cle])
		return t / l.size()
	print("SURCOUT : process %+.3f ms, rendu CPU %+.3f ms, rendu GPU %+.3f ms ; sang v2 propre %.1f µs/image (CPU)" % [
		moy.call(res[true], "proc") - moy.call(res[false], "proc"), moy.call(res[true], "rcpu") - moy.call(res[false], "rcpu"),
		moy.call(res[true], "rgpu") - moy.call(res[false], "rgpu"), moy.call(res[true], "propre_us")])
	quit()
