extends SceneTree
## Mesure de perf des ARMURES PORTÉES (passe 2 « géométrie » des précieuses, 2026-11-11) : N mannequins habillés des glb portés
## (matériaux PS1 « matière » d'ArmureVisible), squelettes animés chaque image (skinning recalculé), caméra qui les voit tous.
## AVEC fenêtre (mesure GPU) :
##   godot --path . --resolution 960x540 --disable-vsync --script res://outils/perf_armures_p2.gd -- [--dossier=res://…/porte/]
##         [--familles=verre,rubis,saphir,cuir,fourrure,uniques,uniques2] [--n=12] [--images=400] [--sortie=<json>]
## Écrit : temps GPU / CPU par image (médiane, p95), primitives, appels de dessin, triangles des glb chargés.
const PIECES := {
	"cuir": ["capuche_cuir", "armure_cuir", "gants_cuir", "bottes_cuir"],
	"fourrure": ["casque_fourrure", "armure_fourrure", "gants_fourrure", "bottes_fourrure"],
	"verre": ["casque_verre", "cuirasse_verre", "gantelets_verre", "bottes_verre"],
	"rubis": ["casque_rubis", "cuirasse_rubis", "gantelets_rubis", "bottes_rubis"],
	"saphir": ["casque_saphir", "cuirasse_saphir", "gantelets_saphir", "bottes_saphir"],
	"uniques": ["heaume_jarl", "cuirasse_gardiens", "gantelets_hrafn", "bottes_rodeur"],
	"uniques2": ["capuche_thaumaturge", "brigandine_braise", "gants_cuir", "bottes_cuir"],
}
var dossier := "res://assets/modeles/armures/porte/"
var familles: Array = ["verre", "rubis", "saphir", "cuir", "fourrure", "uniques", "uniques2"]
var n := 12
var images := 400
var sortie := ""
var squelettes: Array[Skeleton3D] = []
var tris_total := 0

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dossier="):
			dossier = a.get_slice("=", 1)
		elif a.begins_with("--familles="):
			familles = Array(a.get_slice("=", 1).split(","))
		elif a.begins_with("--n="):
			n = int(a.get_slice("=", 1))
		elif a.begins_with("--images="):
			images = int(a.get_slice("=", 1))
		elif a.begins_with("--sortie="):
			sortie = a.get_slice("=", 1)
	_lancer.call_deferred()

func _habiller(racine: Node, chemin: String) -> void:
	for mi in racine.find_children("*", "MeshInstance3D", true, false):
		ArmureVisible._habiller_maillage(mi, chemin)
		for s in mi.mesh.get_surface_count():
			tris_total += mi.mesh.surface_get_array_index_len(s) / 3

func _lancer() -> void:
	var monde := Node3D.new()
	root.add_child(monde)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.72)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	monde.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 30, 0)
	sol.shadow_enabled = true
	monde.add_child(sol)
	var cols := 6
	for i in n:
		var f: String = familles[i % familles.size()]
		var groupe := Node3D.new()
		groupe.position = Vector3((i % cols - (cols - 1) * 0.5) * 0.9, 0, -float(i / cols) * 1.4)
		monde.add_child(groupe)
		for id: String in PIECES[f]:
			var chemin := dossier + id + ".glb"
			var ps := load(chemin) as PackedScene
			if ps == null:
				push_error("introuvable " + chemin)
				continue
			var inst := ps.instantiate()
			groupe.add_child(inst)
			_habiller(inst, chemin)
			for sq in inst.find_children("*", "Skeleton3D", true, false):
				squelettes.append(sq)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.3, 3.6)
	cam.look_at_from_position(cam.position, Vector3(0, 0.9, -0.7))
	monde.add_child(cam)
	cam.current = true
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var gpu: Array = []
	var cpu: Array = []
	var prim := 0
	var dessins := 0
	for k in images + 60:
		var t := k / 30.0
		for j in squelettes.size():
			var sq := squelettes[j]
			for b in mini(sq.get_bone_count(), 24):
				sq.set_bone_pose_rotation(b, sq.get_bone_rest(b).basis.get_rotation_quaternion() * Quaternion(Vector3(1, 0, 0), sin(t * 3.0 + j + b) * 0.05))
		await process_frame
		if k >= 60:
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
			prim = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			dessins = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	gpu.sort()
	cpu.sort()
	var res := {"dossier": dossier, "n": n, "familles": familles, "tris_charges": tris_total, "squelettes": squelettes.size(),
		"gpu_med_ms": gpu[gpu.size() / 2], "gpu_p95_ms": gpu[int(gpu.size() * 0.95)], "cpu_med_ms": cpu[cpu.size() / 2],
		"primitives": prim, "appels_dessin": dessins}
	print("PERF_ARMURES ", JSON.stringify(res))
	if sortie != "":
		var fh := FileAccess.open(sortie, FileAccess.WRITE)
		fh.store_string(JSON.stringify(res, "\t"))
	quit(0)
