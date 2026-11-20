extends "res://outils/audit_mesure_lieu.gd"
## Opti 2026-11-20 (domaine appels_dessin) : RÉPARTITION des appels de dessin et primitives d'un lieu, par origine.
##   godot --path . --disable-vsync --script res://outils/audit_appels.gd -- --nouvelle --paisible --lieu=place --pose=35,30,221,-8 [--heure=21]
## Même mise en place que audit_mesure_lieu.gd (lieux, --heure, --pose). Après la stabilisation, chaque groupe de
## GeometryInstance3D est masqué à tour de rôle (3 images) : l'écart chiffre ses appels et primitives, passe
## principale (visible) et passe d'ombres séparées. Grandeurs indépendantes de la charge de la machine.
## Lignes « APPELS total … » puis « APPELS <groupe> … » triées. --fin=<n> : nombre de groupes détaillés par matière (6).

var _fait := false

func _process(dt: float) -> bool:
	if phase != "mesure":
		return false
	t += dt
	if t < STAB or _fait:
		return false
	_fait = true
	phase = "fin"
	_repartition.call_deferred()
	return false

func _info(type: int, info: int) -> int:
	return RenderingServer.viewport_get_render_info(rid, type, info)

func _lire() -> Array:
	var V := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var S := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW
	var D := RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
	var P := RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME
	var O := RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME
	return [_info(V, D), _info(S, D), _info(V, P), _info(S, P), _info(V, O), _info(S, O)]

func _attendre(k := 3) -> void:
	for i in k:
		await process_frame

func _origine(gi: Node) -> String:
	# enfant direct du monde (ou du village / du tertre / des intérieurs) + script le plus proche
	var chemin: Array[String] = []
	var sc_nom := ""
	var nd: Node = gi
	while nd != null and nd != m:
		var sc: Script = nd.get_script()
		if sc_nom == "" and sc != null and sc.resource_path != "":
			sc_nom = sc.resource_path.get_file()
		chemin.push_front(String(nd.name))
		nd = nd.get_parent()
	if nd == null:
		chemin = ["(hors monde) " + String(gi.get_parent().name if gi.get_parent() else "")]
	var tete := chemin[0] if chemin.size() > 0 else "?"
	if chemin.size() > 1 and tete in ["Village", "village", "Tertre", "tertre"]:
		var deux := chemin[1]
		if deux.begins_with("@"):
			deux = "@" + deux.get_slice("@", 1)
		tete += "/" + deux
	return "%s :: %s" % [tete, sc_nom if sc_nom != "" else "-"]

func _matiere(gi: GeometryInstance3D) -> String:
	var mat: Material = gi.material_override
	if mat == null and gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
		var mi := gi as MeshInstance3D
		mat = mi.get_active_material(0)
	if gi is MultiMeshInstance3D:
		return "(multimesh) " + (mat.resource_path.get_file() if mat else "")
	if mat == null:
		return "(sans)"
	if mat.resource_path != "":
		return mat.resource_path.get_file()
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
		var tx := ""
		for nom in ["albedo_tex", "tex", "texture_albedo", "tex_base"]:
			var v = (mat as ShaderMaterial).get_shader_parameter(nom)
			if v is Texture2D:
				tx = (v as Texture2D).resource_path.get_file()
				if tx == "":
					tx = "tex#%d" % (v as Texture2D).get_rid().get_id()
				break
		return (mat as ShaderMaterial).shader.resource_path.get_file() + " " + tx
	return mat.get_class()

func _repartition() -> void:
	m.process_mode = Node.PROCESS_MODE_DISABLED      # personnages, particules et animations figés : les écarts ne mesurent plus que le groupe masqué
	if _arg("lister") != "":
		_lister(_arg("lister"))
	var tous: Array = []
	for nd in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := nd as GeometryInstance3D
		if gi.is_visible_in_tree():
			tous.append(gi)
	await _attendre(4)
	# temps du rendu, image figée : médianes sur 90 images (GPU du viewport, CPU de rendu + préparation)
	var g := PackedFloat32Array()
	var cc := PackedFloat32Array()
	for i in 90:
		await process_frame
		g.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cc.append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
	print("APPELS temps fige gpu_med=%.2f gpu_p10=%.2f cpu_med=%.2f" % [_pct(g, 0.5), _pct(g, 0.1), _pct(cc, 0.5)])
	var base := _lire()
	print("APPELS total heure=%.1f pos=%s visibles: appels=%d prims=%d objets=%d | ombres: appels=%d prims=%d objets=%d | GI visibles dans l'arbre=%d" % [
		m.cycle.heure, j.global_position, base[0], base[2], base[4], base[1], base[3], base[5], tous.size()])
	var groupes: Dictionary = {}
	for gi in tous:
		var k := _origine(gi)
		if not groupes.has(k):
			groupes[k] = []
		groupes[k].append(gi)
	var res: Array = []
	for k in groupes:
		var r := await _mesurer(groupes[k])
		var ombre := 0
		for gi in groupes[k]:
			if (gi as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				ombre += 1
		res.append([k, r, (groupes[k] as Array).size(), ombre])
	res.sort_custom(func(a, b): return a[1][0] + a[1][1] > b[1][0] + b[1][1])
	for e in res:
		var r: Array = e[1]
		if r[0] + r[1] == 0 and r[2] + r[3] < 1000:
			continue
		print("APPELS %-60s vis=%4d omb=%4d | prims vis=%7d omb=%7d | GI=%d (ombre %d)" % [e[0], r[0], r[1], r[2], r[3], e[2], e[3]])
	# détail par matière des plus gros groupes
	var nfin := int(_arg("fin", "6"))
	for e in res.slice(0, nfin):
		var parmat: Dictionary = {}
		for gi in groupes[e[0]]:
			var km := _matiere(gi)
			if not parmat.has(km):
				parmat[km] = []
			parmat[km].append(gi)
		var sous: Array = []
		for km in parmat:
			var r2 := await _mesurer(parmat[km])
			sous.append([km, r2, (parmat[km] as Array).size()])
		sous.sort_custom(func(a, b): return a[1][0] + a[1][1] > b[1][0] + b[1][1])
		print("APPELS --- détail %s" % e[0])
		for s in sous.slice(0, 14):
			var r2: Array = s[1]
			print("APPELS       %-54s vis=%4d omb=%4d | prims vis=%7d omb=%7d | GI=%d" % [s[0], r2[0], r2[1], r2[2], r2[3], s[2]])
	if _arg("png") != "":
		await capturer(_arg("png"))
	quit(0)

## --lister=<motif> : chaque GeometryInstance3D visible dont le chemin contient le motif (nom, maillage, surfaces, triangles, ombre).
func _lister(motif: String) -> void:
	_dans_champ(AABB())
	for nd in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := nd as GeometryInstance3D
		var ch := String(gi.get_path())
		if not gi.is_visible_in_tree() or not (ch.contains(motif) or _origine(gi).contains(motif)):
			continue
		var surf := 0
		var tris := 0
		var nom_m := ""
		var msh: Mesh = null
		if gi is MeshInstance3D:
			msh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
			msh = (gi as MultiMeshInstance3D).multimesh.mesh
		if msh != null:
			surf = msh.get_surface_count()
			nom_m = msh.resource_path.get_file() if msh.resource_path != "" else msh.resource_name
			for i in surf:
				if msh is ArrayMesh:
					var ix := (msh as ArrayMesh).surface_get_array_index_len(i)
					tris += (ix if ix > 0 else (msh as ArrayMesh).surface_get_array_len(i)) / 3
		var bb := gi.global_transform * gi.get_aabb()
		var dans := _dans_champ(bb)
		var d := bb.get_center().distance_to(cam_pos)
		print("LISTE %s | %s | %s surf=%d tris=%d ombre=%d vr=%.0f-%.0f champ=%d d=%.0f taille=%.0f mat=%s" % [ch.substr(maxi(0, ch.length() - 110)), gi.get_class(), nom_m, surf, tris, gi.cast_shadow, gi.visibility_range_begin, gi.visibility_range_end, 1 if dans else 0, d, bb.size.length(), _matiere(gi)])

var cam_pos := Vector3.ZERO
var _plans: Array = []
func _dans_champ(bb: AABB) -> bool:
	if _plans.is_empty():
		var cam := root.get_viewport().get_camera_3d()
		_plans = cam.get_frustum()
		cam_pos = cam.global_position
	for pl: Plane in _plans:
		var pv := bb.position + Vector3(bb.size.x if pl.normal.x < 0 else 0.0, bb.size.y if pl.normal.y < 0 else 0.0, bb.size.z if pl.normal.z < 0 else 0.0)
		if pl.is_point_over(pv):
			return false
	return true

func _mesurer(liste: Array) -> Array:
	var avant := _lire()
	for gi in liste:
		(gi as GeometryInstance3D).visible = false
	await _attendre(3)
	var apres := _lire()
	for gi in liste:
		(gi as GeometryInstance3D).visible = true
	await _attendre(2)
	var r: Array = []
	for i in 4:
		r.append(avant[i] - apres[i])
	return r
