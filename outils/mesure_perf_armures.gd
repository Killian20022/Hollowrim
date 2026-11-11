extends SceneTree
## Mesure GPU/CPU de 6 personnages en armure lourde dans le village (passe 2 « géométrie » des armures lourdes, avant/après).
## 6 corps (Humain) en marche sur place devant la halle, armures fer / acier / obsidienne / or / acier / or chargées depuis --dossier
## (défaut : res://assets/modeles/armures/porte/ ; avant : un dossier de copies des glb d'un ancien commit) ; --sans : corps nus.
## 4 s de stabilisation puis 12 s de moyenne (médiane, 90e centile).
##   godot --path . --disable-vsync --resolution 960x540 --script res://outils/mesure_perf_armures.gd -- --nouvelle --paisible --heure=12 [--dossier=res://…/] [--sans]
const FAMILLES := [["casque_fer", "cuirasse_fer", "gantelets_fer", "bottes_fer"],
	["casque_acier_nordique", "cuirasse_acier_nordique", "gantelets_acier_nordique", "bottes_acier_nordique"],
	["casque_obsidienne", "cuirasse_obsidienne", "gantelets_obsidienne", "bottes_obsidienne"],
	["casque_or", "cuirasse_or", "gantelets_or", "bottes_or"]]
var monde: Node3D
var t := 0.0
var n := 0
var gpu := PackedFloat32Array()
var cpu := PackedFloat32Array()
var rid: RID
var pret := false
var tris := 0

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--" + nom + "="):
			return a.get_slice("=", 1)
	return defaut

func _init() -> void:
	monde = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child.call_deferred(monde)
	_demarrer.call_deferred()

func _demarrer() -> void:
	var t0 := Time.get_ticks_msec()
	while monde.get("joueur") == null and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
	var j: CharacterBody3D = monde.joueur
	for i in 120:
		await process_frame
	var dossier := _arg("dossier", "res://assets/modeles/armures/porte/")
	var sans := _arg("sans") != ""
	var centre := Vector3(50.0, 0.0, 30.0)
	centre.y = monde.hauteur(centre.x, centre.z)
	j.global_position = centre + Vector3(0, 0.2, 9.0)
	var ordre := [0, 1, 2, 3, 1, 3]
	for k in 6:
		var h := Humain.creer({"corps": "homme", "barbe": true, "cheveux": "Hair_Long", "tenue": {}})
		monde.add_child(h)
		var p := centre + Vector3(-3.0 + 1.2 * k, 0.0, (k % 2) * 0.8)
		p.y = monde.hauteur(p.x, p.z)
		h.global_position = p
		var sq: Skeleton3D = h.find_child("Skeleton3D", true, false)
		if not sans:
			for id: String in FAMILLES[ordre[k]]:
				var mi := ArmureVisible.charger_chemin(dossier.path_join(id + ".glb"), "", ArmureVisible.preset_de(id))
				if mi == null:
					print("ABSENT ", id)
					continue
				sq.add_child(mi)
				mi.skeleton = NodePath("..")
				for s in mi.mesh.get_surface_count():
					tris += mi.mesh.surface_get_array_index_len(s) / 3
		var ap: AnimationPlayer = h.find_child("AnimationPlayer", true, false)
		if ap != null:
			for nom in ["Walk", "walk", "Idle"]:
				if ap.has_animation(nom):
					ap.play(nom)
					ap.seek(0.13 * k, true)
					break
	var cam := Camera3D.new()
	cam.far = 120.0
	root.add_child(cam)
	cam.current = true
	cam.global_position = centre + Vector3(0.0, 1.7, 5.5)
	cam.look_at(centre + Vector3(0, 1.0, 0), Vector3.UP)
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	pret = true

func _process(delta: float) -> bool:
	if not pret:
		return false
	t += delta
	if t < 4.0:
		return false
	n += 1
	gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	cpu.append(delta * 1000.0)
	if t >= 16.0:
		var g := gpu.duplicate(); g.sort()
		var c := cpu.duplicate(); c.sort()
		var sg := 0.0
		for x in gpu: sg += x
		var sc := 0.0
		for x in cpu: sc += x
		print("MESURE_ARMURES dossier=%s sans=%s tris_armures=%d gpu_ms=%.2f gpu_med=%.2f gpu_p90=%.2f image_ms=%.2f image_p90=%.2f images=%d" % [_arg("dossier", "porte"), _arg("sans"), tris, sg / n, g[n / 2], g[n * 9 / 10], sc / n, c[n * 9 / 10], n])
		quit(0)
	return false
