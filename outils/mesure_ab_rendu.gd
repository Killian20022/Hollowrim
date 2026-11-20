extends "res://outils/audit_mesure_lieu.gd"
## Opti 2026-11-20 (gpu_rendu) : A/B ENTRELACÉ DANS UN SEUL LANCEMENT. Même mise en place que audit_mesure_lieu.gd (lieux,
## --heure, --pose…), puis, après la stabilisation, on fait tourner une liste de réglages (--ab=base,ombre0,glow0,…) :
## chaque réglage tient --tranche s (défaut 1,5 s ; les 0,4 premières secondes sont écartées), et la liste est répétée
## --tours fois (défaut 6). Le bruit de la machine partagée touche alors tous les réglages pareil.
##   godot --path . --disable-vsync --script res://outils/mesure_ab_rendu.gd -- --nouvelle --paisible --lieu=temoin --pose=2.5,8.5,16,4 --heure=21 --ab=base,ombre0
## Imprime « AB <réglage> gpu_med=… gpu_p95=… cpu_med=… dt_med=… appels=… prims=… ombre_appels=… ombre_prims=… » (médianes
## sur tous les tours) et l'écart au premier réglage de la liste. Réglages connus : voir _appliquer().

var _cfgs: PackedStringArray
var _tranche := 1.5
var _tours := 6
var _ic := 0
var _tour := 0
var _t_cfg := 0.0
var _res := {}          # nom -> {gpu, cpu, dt, appels, prims, sa, sp}
var _orig := {}
var _vp_rid: RID

func _process(dt: float) -> bool:
	if phase == "init" or phase == "fin":
		return false
	t += dt
	var now := Time.get_ticks_usec()
	var d_ms := (now - prec_us) / 1000.0
	prec_us = now
	j.vie = j.vie_max
	j.mana = 100.0
	if lieu == "combat":
		_sorts(dt)
	if t < STAB:
		return false
	if _cfgs.is_empty():
		_cfgs = _arg("ab", "base").split(",", false)
		_tranche = float(_arg("tranche", "1.5"))
		_tours = int(_arg("tours", "6"))
		_vp_rid = root.get_viewport_rid()
		for c in _cfgs:
			_res[c] = {"gpu": PackedFloat32Array(), "cpu": PackedFloat32Array(), "dt": PackedFloat32Array(), "appels": PackedFloat32Array(), "prims": PackedFloat32Array(), "sa": PackedFloat32Array(), "sp": PackedFloat32Array()}
		_memoriser()
		if _arg("inventaire-ombres") != "":
			_inventaire_ombres()
		_appliquer(_cfgs[0])
		_t_cfg = 0.0
		return false
	_t_cfg += dt
	if _t_cfg > 0.4:
		var r: Dictionary = _res[_cfgs[_ic]]
		_ajouter(r, "gpu", RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid))
		_ajouter(r, "cpu", RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid) + RenderingServer.get_frame_setup_time_cpu())
		_ajouter(r, "dt", d_ms)
		_ajouter(r, "appels", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_ajouter(r, "prims", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		_ajouter(r, "sa", RenderingServer.viewport_get_render_info(_vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		_ajouter(r, "sp", RenderingServer.viewport_get_render_info(_vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
	if _t_cfg >= _tranche:
		_ic += 1
		if _ic >= _cfgs.size():
			_ic = 0
			_tour += 1
			if _tour >= _tours:
				phase = "fin"
				_fin_ab.call_deferred()
				return false
		_appliquer(_cfgs[_ic])
		_t_cfg = 0.0
	return false

## (un PackedFloat32Array lu dans un Dictionary est une COPIE : on réassigne)
func _ajouter(r: Dictionary, cle: String, v: float) -> void:
	var a: PackedFloat32Array = r[cle]
	a.append(v)
	r[cle] = a

func _fin_ab() -> void:
	var g0 := -1.0
	var c0 := -1.0
	print("AB lieu=%s heure=%.1f tours=%d tranche=%.1f s autres_godot=? (voir le lanceur)" % [lieu, m.cycle.heure, _tours, _tranche])
	for c in _cfgs:
		var r: Dictionary = _res[c]
		var g := _pct(r["gpu"], 0.5)
		var cp := _pct(r["cpu"], 0.5)
		if g0 < 0.0:
			g0 = g
			c0 = cp
		print("AB %-22s gpu_med=%.3f gpu_p95=%.3f (Δ %+.3f) cpu_rendu_med=%.3f (Δ %+.3f) dt_med=%.2f dt_p99=%.2f appels=%d prims=%d ombre_appels=%d ombre_prims=%d n=%d" % [
			c, g, _pct(r["gpu"], 0.95), g - g0, cp, cp - c0, _pct(r["dt"], 0.5), _pct(r["dt"], 0.99), int(_pct(r["appels"], 0.5)), int(_pct(r["prims"], 0.5)),
			int(_pct(r["sa"], 0.5)), int(_pct(r["sp"], 0.5)), (r["gpu"] as PackedFloat32Array).size()])
	# --planche=<dossier Windows> : une image par réglage (même pose, même heure), pour les planches avant | après
	if _arg("planche") != "":
		for ic in _cfgs.size():
			var c := _cfgs[ic]
			_appliquer(c)
			for k in 20:
				await process_frame
			var f := _arg("planche").path_join("%s_%s_%d_%s.png" % [lieu, str(int(m.cycle.heure)), ic, c.replace("+", "-")])
			await capturer(f)
			print("AB image ", f)
	_appliquer("base")
	if _arg("png") != "":
		await capturer(_arg("png"))
	quit(0)

func _lunes() -> Array:
	return m.find_children("*", "DirectionalLight3D", true, false)

func _memoriser() -> void:
	if _arg("sans-mains") != "" and j.mains != null:
		j.mains.visible = false     # planches : ni bras ni torche (images comparables)
	var env: Environment = m._env
	_orig["glow"] = env.glow_enabled
	_orig["fen"] = DisplayServer.window_get_size()
	_orig["fog"] = env.fog_enabled
	_orig["bg"] = env.background_mode
	_orig["ciel_mode"] = env.sky.process_mode if env.sky != null else 0
	_orig["ciel_rad"] = env.sky.radiance_size if env.sky != null else 0
	_orig["fond"] = env.background_color
	var l: DirectionalLight3D = _lunes()[0]
	_orig["ombre"] = l.shadow_enabled
	_orig["mode"] = l.directional_shadow_mode
	_orig["dist"] = l.directional_shadow_max_distance
	_orig["split1"] = l.directional_shadow_split_1
	_orig["atlas"] = int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096))
	_orig["filtre"] = int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 2))
	_orig["blend"] = l.directional_shadow_blend_splits
	if m.mat_terrain != null:
		_orig["sol_carte"] = m.mat_terrain.get_shader_parameter("sol_carte")
		_orig["prio_sol"] = m.mat_terrain.render_priority
	print("AB réglages d'origine : ", _orig)

func _appliquer(cfg: String) -> void:
	var env: Environment = m._env
	# retour à la base
	env.glow_enabled = _orig["glow"]
	env.fog_enabled = _orig["fog"]
	env.background_mode = _orig["bg"]
	m._ciel.set_shader_parameter("aurore_saut", 0.0 if _arg("sans-opti-aurore") != "" else 0.002)
	if env.sky != null:
		if env.sky.process_mode != _orig["ciel_mode"]:
			env.sky.process_mode = _orig["ciel_mode"]
		if env.sky.radiance_size != _orig["ciel_rad"]:
			env.sky.radiance_size = _orig["ciel_rad"]
	for n in _lunes():
		var l := n as DirectionalLight3D
		l.shadow_enabled = _orig["ombre"]
		l.directional_shadow_mode = _orig["mode"]
		l.directional_shadow_max_distance = _orig["dist"]
		l.directional_shadow_split_1 = _orig["split1"]
		l.directional_shadow_blend_splits = _orig["blend"]
	RenderingServer.directional_shadow_atlas_set_size(_orig["atlas"], true)
	RenderingServer.environment_glow_set_use_bicubic_upscale(int(ProjectSettings.get_setting("rendering/environment/glow/upscale_mode", 1)) == 1)
	RenderingServer.directional_soft_shadow_filter_set_quality(_orig["filtre"])
	if m.arriere_plan != null:
		m.arriere_plan.visible = true
	if m.mat_terrain != null and _orig.has("sol_carte"):
		m.mat_terrain.set_shader_parameter("sol_carte", _orig["sol_carte"])
		m.mat_terrain.render_priority = _orig["prio_sol"]
	_post_visible(true)
	var ps1: Shader = Palette.PS1
	if _ps1_code_orig != "" and ps1.code != _ps1_code_orig:
		ps1.code = _ps1_code_orig
	var couche_voulue := CoucheMagie.RETRO
	var fen: Vector2i = _orig["fen"]
	if _lum_eteintes:
		_lumieres_visibles(true)
	# réglage(s) demandé(s) : « a+b » combine
	for x in cfg.split("+", false):
		match x:
			"base": pass
			"ombre0":
				for n in _lunes():
					(n as DirectionalLight3D).shadow_enabled = false
			"atlas2048": RenderingServer.directional_shadow_atlas_set_size(2048, true)
			"atlas3072": RenderingServer.directional_shadow_atlas_set_size(3072, true)
			"atlas1024": RenderingServer.directional_shadow_atlas_set_size(1024, true)
			"atlas2560": RenderingServer.directional_shadow_atlas_set_size(2560, true)
			"filtre_dur": RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			"filtre_tresbas": RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
			"ortho":
				for n in _lunes():
					(n as DirectionalLight3D).directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			"dist40":
				for n in _lunes():
					(n as DirectionalLight3D).directional_shadow_max_distance = 40.0
			"blend":
				for n in _lunes():
					(n as DirectionalLight3D).directional_shadow_blend_splits = true
			"glow0": env.glow_enabled = false
			"glow_lin": RenderingServer.environment_glow_set_use_bicubic_upscale(false)
			"brume0": env.fog_enabled = false
			"ciel0":
				env.background_mode = Environment.BG_COLOR
			"aurore_avant": m._ciel.set_shader_parameter("aurore_saut", 0.0)
			"ciel_inc": env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
			"ciel_qual": env.sky.process_mode = Sky.PROCESS_MODE_QUALITY
			"monts0":
				if m.arriere_plan != null:
					m.arriere_plan.visible = false
			"sol0":
				if m.mat_terrain != null:
					m.mat_terrain.set_shader_parameter("sol_carte", false)
			"sol_dernier":      # terrain dessiné APRÈS les autres opaques (test de profondeur précoce sur le sol caché)
				if m.mat_terrain != null:
					m.mat_terrain.render_priority = 100
			"sol_avant":        # ordre d'avant l'opti (priorité 0), = --sans-opti-sol-dernier
				if m.mat_terrain != null:
					m.mat_terrain.render_priority = 0
			"sol_premier":
				if m.mat_terrain != null:
					m.mat_terrain.render_priority = -100
			"ps1_complet":      # shader commun AVEC tout le code du sol (comme avant l'opti ps1 léger)
				if _ps1_code_orig == "":
					_ps1_code_orig = ps1.code
				if not ps1.code.begins_with("#define SOL"):
					ps1.code = "#define SOL\n" + _ps1_code_orig
			"post0": _post_visible(false)
			"lum0": _lumieres_visibles(false)
			"eleve": couche_voulue = CoucheMagie.ELEVE      # réglage par défaut du JEU (Options > Détail des sorts : Élevé)
			"moyen": couche_voulue = CoucheMagie.MOYEN
			"fen1080": fen = Vector2i(1920, 1080)          # plein écran 1080p simulé (fenêtre hors écran)
			_:
				push_error("AB : réglage inconnu " + x)
	if DisplayServer.window_get_size() != fen:
		DisplayServer.window_set_size(fen)
	var gm = GestionMagie.instance
	if gm != null and gm.couche != null and gm.couche.niveau != couche_voulue:
		gm.couche.regler(couche_voulue)

func _post_visible(v: bool) -> void:
	if m.calque == null:
		return
	for c in m.calque.get_children():
		if c is ColorRect and (c as ColorRect).material == m.post:
			(c as ColorRect).visible = v

var _ps1_code_orig := ""
var _lum_cache: Array = []
var _lum_eteintes := false
func _lumieres_visibles(v: bool) -> void:
	_lum_eteintes = not v
	if not v:
		_lum_cache.clear()
		for l in m.find_children("*", "Light3D", true, false):
			if not (l is DirectionalLight3D) and (l as Light3D).visible:
				_lum_cache.append(l)
	for l in _lum_cache:
		if is_instance_valid(l):
			(l as Light3D).visible = v

## --inventaire-ombres : géométries qui projettent une ombre du soleil/de la lune à moins de la portée des ombres de la caméra,
## regroupées par « famille » (script du parent le plus proche, sinon nom du nœud), avec leurs triangles (MultiMesh : × instances).
func _inventaire_ombres() -> void:
	var cam := root.get_viewport().get_camera_3d()
	var portee: float = _orig.get("dist", 62.0)
	var fam := {}
	var tot_n := 0
	var tot_t := 0
	for n in m.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not g.is_visible_in_tree():
			continue
		var aabb := g.global_transform * g.get_aabb()
		var c := aabb.get_center()
		var r := aabb.size.length() * 0.5
		if c.distance_to(cam.global_position) - r > portee:
			continue
		var tris := 0
		var inst := 1
		var mesh: Mesh = null
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			var mm := (g as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			inst = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		if mesh != null:
			for s in mesh.get_surface_count():
				var a := mesh.surface_get_arrays(s)
				if a.size() > 0:
					var idx = a[Mesh.ARRAY_INDEX]
					tris += (idx.size() / 3) if idx != null and idx.size() > 0 else ((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
		tris *= inst
		var p: Node = g
		var nom := ""
		while p != null and p != m:
			if p.get_script() != null:
				nom = (p.get_script() as Script).resource_path.get_file()
				break
			p = p.get_parent()
		if nom == "":
			nom = g.get_parent().name if g.get_parent() != null else g.name
		var cle := "%s/%s" % [nom, g.get_class()]
		if not fam.has(cle):
			fam[cle] = [0, 0, 0.0]
		fam[cle][0] += 1
		fam[cle][1] += tris
		fam[cle][2] = maxf(fam[cle][2], aabb.size.length())
		tot_n += 1
		tot_t += tris
	var l := fam.keys()
	l.sort_custom(func(a, b): return fam[a][1] > fam[b][1])
	print("OMBRES inventaire (portée %.0f m) : %d géométries, %d triangles" % [portee, tot_n, tot_t])
	for k in l.slice(0, 30):
		print("OMBRES %-60s n=%4d tris=%8d taille_max=%.1f m" % [k, fam[k][0], fam[k][1], fam[k][2]])
