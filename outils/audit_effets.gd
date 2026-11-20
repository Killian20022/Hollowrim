extends "res://outils/audit_mesure_lieu.gd"
## Domaine effets_lumieres (opti 2026-11-20) : même mesure que audit_mesure_lieu.gd, plus
##   - un INVENTAIRE des lumières (dans le champ, ombres, objets touchés), des particules et des transparents au moment de la mesure ;
##   - des SÉRIES entrelacées dans UN seul lancement (même monde, même charge de machine) :
##       --series="base;lumieres;base;lumieres"   (configs séparées par « ; », coupes d'une config séparées par « , »)
##     coupes : lumieres (omni/spot), neige, particules, feux (FeuFixe), transparents, eau, halos (cartes halo/lueur)
##     Chaque config est mesurée --duree s après 2 s de reprise ; une ligne « SERIE <config> … » par passage, puis l'inventaire.
## Diagnostic uniquement : rien n'est changé au jeu (les coupes sont rétablies entre deux configs).
## godot --path . --disable-vsync --script res://outils/audit_effets.gd -- --nouvelle --paisible --lieu=place --heure=21 --pose=35,30,221,-8

var _series: PackedStringArray = []
var _i_serie := 0
var _caches: Array = []      # [nœud, visible d'avant] des coupes en cours
var _res: Dictionary = {}
var _ordre: Array = []       # [config, gpu_med, cpu_rendu] dans l'ordre des passages    # config -> [ [gpu_med, dt_med, dt_p99, appels, prims, objets], ... ]

func _experience(e: String) -> void:
	var s := _arg("series")
	if s != "":
		_series = s.split(";", false)
		_appliquer(_series[0])
	else:
		super._experience(e)
		_appliquer(e)

func _cacher(n: Node) -> void:
	var nd := n as Node3D
	if nd == null or not nd.visible:
		return
	_caches.append([nd, true])
	nd.visible = false

var _props: Array = []       # [objet, propriété, valeur d'avant]
func _regler(o: Object, prop: String, v: Variant) -> void:
	_props.append([o, prop, o.get(prop)])
	o.set(prop, v)

func _retablir() -> void:
	for pr: Array in _props:
		if is_instance_valid(pr[0]):
			(pr[0] as Object).set(pr[1], pr[2])
	_props.clear()
	for c: Array in _caches:
		if is_instance_valid(c[0]):
			(c[0] as Node3D).visible = c[1]
	_caches.clear()

func _appliquer(cfg: String) -> void:
	_retablir()
	for x in cfg.split(",", false):
		if x.begins_with("lum:"):      # lum:<script> : lumières dont le premier ancêtre scripté est <script>.gd (ex. lum:interieur)
			for l in m.find_children("*", "Light3D", true, false):
				if not (l is DirectionalLight3D) and _origine(l) == x.substr(4) + ".gd":
					_cacher(l)
			continue
		match x:
			"lumieres":
				for l in m.find_children("*", "Light3D", true, false):
					if not (l is DirectionalLight3D):
						_cacher(l)
			"neige":
				if m.get("neige") != null:
					_cacher(m.neige)
			"neige_turb0":
				_regler(m.neige.process_material, "turbulence_enabled", false)
			"neige_ombre0":
				_regler(m.neige, "cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			"neige_fige":      # flocons figés (mêmes places d'une config à l'autre : captures comparables au pixel)
				_regler(m.neige, "speed_scale", 0.0)
			"neige_fps15":
				_regler(m.neige, "fixed_fps", 15)
			"neige_moitie":
				_regler(m.neige, "amount_ratio", 0.5)
			"neige_petite":      # flocons de taille nulle : le dessin ne coûte plus que les sommets (sépare traitement et pixels)
				_regler(m.neige.draw_pass_1, "size", Vector2(0.0005, 0.0005))
			"particules":
				for p in m.find_children("*", "GPUParticles3D", true, false):
					_cacher(p)
				for p in m.find_children("*", "CPUParticles3D", true, false):
					_cacher(p)
			"feux":
				for f in m.find_children("*", "FeuFixe", true, false):
					_cacher(f)
			"transparents":
				for g in m.find_children("*", "GeometryInstance3D", true, false):
					if not (g is GPUParticles3D) and _transparent(g):
						_cacher(g)
			"halos":
				for g in m.find_children("*", "GeometryInstance3D", true, false):
					var mt: Material = (g as GeometryInstance3D).material_override
					if mt is ShaderMaterial and (mt as ShaderMaterial).shader != null and ((mt as ShaderMaterial).shader.resource_path.get_file() in ["halo_sprite.gdshader", "feu_halo_sol.gdshader", "brume_halo.gdshader", "feu_chaleur.gdshader"]):
						_cacher(g)
			"eau":
				for g in m.find_children("*", "", true, false):
					var sc: Script = g.get_script()
					if sc != null and (sc.resource_path.get_file() in ["eau.gd", "cascade.gd"]):
						_cacher(g)
	if cfg != "" and cfg != "base":
		print("EFFETS config « %s » : %d nœuds cachés" % [cfg, _caches.size()])

var _ombre_appels := 0.0
var _ombre_prims := 0.0
var _ombre_n := 0
## Passe d'OMBRE seule (indépendant de la charge de la machine) : appels et primitives dessinés dans les cartes d'ombre.
func _process(dt: float) -> bool:
	var r: bool = super._process(dt)
	if phase == "mesure" and t >= STAB and rid.is_valid():
		_ombre_appels += RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		_ombre_prims += RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		_ombre_n += 1
	return r

func _terminer() -> void:
	if _series.is_empty():
		super._terminer()
		return
	_ligne_serie(_series[_i_serie])
	if _arg("png-series") != "":      # --png-series=<dossier Windows> : une image par passage, AVANT de rétablir (planches avant|après)
		await capturer("%s/%02d_%s.png" % [_arg("png-series"), _i_serie, _series[_i_serie].replace(",", "+").replace(":", "-")])
	_i_serie += 1
	if _i_serie < _series.size():
		_appliquer(_series[_i_serie])
		gpu.clear()
		cpu.clear()
		dts.clear()
		tp.clear()
		tph.clear()
		appels = 0.0
		prims = 0.0
		objets = 0.0
		n = 0
		t = STAB - 2.0
		prec_us = Time.get_ticks_usec()
		phase = "mesure"
		return
	_retablir()
	_bilan()
	_inventaire()
	if _arg("png") != "":
		await capturer(_arg("png"))
	quit(0)

func _ligne_serie(cfg: String) -> void:
	var s33 := 0
	for d in dts:
		if d > 33.0:
			s33 += 1
	var v := [_pct(gpu, 0.5), _pct(dts, 0.5), _pct(dts, 0.99), appels / maxf(1, n), prims / maxf(1, n), objets / maxf(1, n), _pct(gpu, 0.95), s33, _pct(cpu, 0.5)]
	_ordre.append([cfg, v[0], v[8]])
	if not _res.has(cfg):
		_res[cfg] = []
	(_res[cfg] as Array).append(v)
	print("SERIE %-28s ombre_appels=%d ombre_prims=%d" % [cfg, _ombre_appels / maxf(1, _ombre_n), _ombre_prims / maxf(1, _ombre_n)])
	_ombre_appels = 0.0
	_ombre_prims = 0.0
	_ombre_n = 0
	print("SERIE %-28s cpu_rendu=%.2f gpu_med=%.2f gpu_p95=%.2f dt_med=%.2f dt_p99=%.2f >33=%d appels=%d prims=%d objets=%d n=%d" % [cfg, v[8], v[0], v[6], v[1], v[2], s33, v[3], v[4], v[5], n])

func _bilan() -> void:
	# écart APPARIÉ : chaque passage d'une coupe comparé à la moyenne des passages « base » qui l'encadrent (le bruit lent s'annule)
	var ecarts := {}
	for i in _ordre.size():
		var c: String = _ordre[i][0]
		if c == "base":
			continue
		var av := -1
		var ap := -1
		for k in range(i - 1, -1, -1):
			if _ordre[k][0] == "base":
				av = k
				break
		for k in range(i + 1, _ordre.size()):
			if _ordre[k][0] == "base":
				ap = k
				break
		if av < 0 and ap < 0:
			continue
		var bg := 0.0
		var bc := 0.0
		var nb := 0
		for k in [av, ap]:
			if k >= 0:
				bg += _ordre[k][1]
				bc += _ordre[k][2]
				nb += 1
		if not ecarts.has(c):
			ecarts[c] = [PackedFloat32Array(), PackedFloat32Array()]
		ecarts[c][0].append(_ordre[i][1] - bg / nb)
		ecarts[c][1].append(_ordre[i][2] - bc / nb)
	for c in ecarts:
		var g: PackedFloat32Array = ecarts[c][0]
		var cc: PackedFloat32Array = ecarts[c][1]
		var gs := g.duplicate()
		gs.sort()
		var cs := cc.duplicate()
		cs.sort()
		print("ECART %-28s gpu (coupe - base) médiane=%+.2f ms [%s] | cpu_rendu médiane=%+.2f ms" % [c, gs[gs.size() / 2], ", ".join(Array(g).map(func(x): return "%+.2f" % x)), cs[cs.size() / 2]])
	for cfg in _res:
		var l: Array = _res[cfg]
		var g := PackedFloat32Array()
		for v: Array in l:
			g.append(v[0])
		g.sort()
		var v0: Array = l[0]
		print("BILAN %-28s gpu_med(médiane des passages)=%.2f [%s] appels=%d prims=%d" % [cfg, g[g.size() / 2], ", ".join(Array(g).map(func(x): return "%.2f" % x)), v0[3], v0[4]])

func _fin() -> void:
	super._fin()
	if _series.is_empty():
		_inventaire()

static func _shader_transparent(sh: Shader) -> bool:
	if sh == null:
		return false
	var c := sh.code
	if c.contains("blend_add") or c.contains("blend_mul") or c.contains("blend_sub") or c.contains("depth_draw_never"):
		return true
	return c.contains("ALPHA") and not c.contains("ALPHA_SCISSOR") and not c.contains("depth_prepass_alpha")

static func _mat_transparent(mt: Material) -> bool:
	if mt is BaseMaterial3D:
		return (mt as BaseMaterial3D).transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS] or (mt as BaseMaterial3D).blend_mode != BaseMaterial3D.BLEND_MODE_MIX
	if mt is ShaderMaterial:
		return _shader_transparent((mt as ShaderMaterial).shader)
	return false

func _transparent(g: Node) -> bool:
	var gi := g as GeometryInstance3D
	if gi.material_override != null and _mat_transparent(gi.material_override):
		return true
	if gi is MeshInstance3D:
		var mi := gi as MeshInstance3D
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var mt := mi.get_active_material(s)
				if mt != null and _mat_transparent(mt):
					return true
	if gi is MultiMeshInstance3D:
		var mm := (gi as MultiMeshInstance3D).multimesh
		if mm != null and mm.mesh != null:
			for s in mm.mesh.get_surface_count():
				var mt := mm.mesh.surface_get_material(s)
				if mt != null and _mat_transparent(mt):
					return true
	return false

func _dans_champ(cam: Camera3D, c: Vector3, r: float) -> bool:
	for pl: Plane in cam.get_frustum():
		if pl.distance_to(c) > r:
			return false
	return true

func _inventaire() -> void:
	var cam := root.get_viewport().get_camera_3d()
	var lum := 0
	var lum_vis := 0
	var lum_ombre := 0
	var lum_champ := 0
	var lum_champ_ombre := 0
	var portees := 0.0
	var par_script := {}
	var geo: Array = []
	for g in m.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if gi.is_visible_in_tree() and not (gi is GPUParticles3D):
			var ab := gi.global_transform * gi.get_aabb()
			if ab.size.length() < 2000.0:
				geo.append(ab)
	var touches_tot := 0
	var lignes: Array = []
	for l in m.find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D:
			continue
		lum += 1
		var li := l as Light3D
		if not li.is_visible_in_tree():
			continue
		lum_vis += 1
		var r: float = (li as OmniLight3D).omni_range if li is OmniLight3D else (li as SpotLight3D).spot_range
		var c := li.global_position
		if li.shadow_enabled:
			lum_ombre += 1
		var dcam := cam.global_position.distance_to(c) if cam != null else 0.0
		var eteinte_fondu := li.distance_fade_enabled and dcam > li.distance_fade_begin + li.distance_fade_length
		var champ := cam != null and _dans_champ(cam, c, r) and not eteinte_fondu
		if champ:
			lum_champ += 1
			portees += r
			if li.shadow_enabled:
				lum_champ_ombre += 1
			var sph := AABB(c - Vector3(r, r, r), Vector3(r, r, r) * 2.0)
			var t2 := 0
			for ab: AABB in geo:
				if sph.intersects(ab):
					t2 += 1
			touches_tot += t2
			var cle := _origine(li)
			var e: Array = par_script.get(cle, [0, 0, 0.0, 0])
			e[0] += 1
			e[1] += t2
			e[2] += r
			e[3] += 1 if li.shadow_enabled else 0
			par_script[cle] = e
			lignes.append([t2, "%s r=%.1f E=%.2f ombre=%s fondu=%s d=%.1f touche=%d" % [String(li.get_path()).right(70), r, li.light_energy, str(li.shadow_enabled), str(li.distance_fade_enabled), dcam, t2]])
	print("EFFETS lumières : total=%d visibles=%d ombre=%d | dans le champ=%d (ombre %d) portée moy=%.1f | somme lumière x instance touchée=%d sur %d instances visibles" % [
		lum, lum_vis, lum_ombre, lum_champ, lum_champ_ombre, portees / maxf(1.0, lum_champ), touches_tot, geo.size()])
	for cle in par_script:
		var e: Array = par_script[cle]
		print("EFFETS   lum[%s] n=%d touche=%d portée_moy=%.1f ombre=%d" % [cle, e[0], e[1], e[2] / e[0], e[3]])
	lignes.sort_custom(func(a, b): return a[0] > b[0])
	for x in lignes.slice(0, 12):
		print("EFFETS     ", x[1])
	var np := 0
	var np_vis := 0
	var np_champ := 0
	var quant := 0.0
	var quant_champ := 0.0
	var pscript := {}
	for p in m.find_children("*", "GPUParticles3D", true, false):
		var gp := p as GPUParticles3D
		np += 1
		if not gp.is_visible_in_tree():
			continue
		np_vis += 1
		var q := gp.amount * gp.amount_ratio
		quant += q
		var ab := gp.global_transform * gp.visibility_aabb
		var cle := _origine(gp)
		var e: Array = pscript.get(cle, [0, 0.0, 0, 0.0, 0])
		e[0] += 1
		e[1] += q
		e[4] += 1 if gp.emitting else 0
		if cam != null and _dans_champ(cam, ab.get_center(), ab.size.length() * 0.5):
			np_champ += 1
			quant_champ += q
			e[2] += 1
			e[3] += q
		pscript[cle] = e
	var orph := {}
	for p in m.get_children():
		if p is GPUParticles3D:
			var gp := p as GPUParticles3D
			var dm: Mesh = gp.draw_pass_1
			var mt: Material = gp.material_override if gp.material_override != null else (dm.surface_get_material(0) if dm != null and dm.get_surface_count() > 0 else null)
			var ms := mt.get_class() + ((":" + (mt as ShaderMaterial).shader.resource_path.get_file()) if mt is ShaderMaterial and (mt as ShaderMaterial).shader != null else "")
			var k := "%s %s n=%d vie=%.2f one_shot=%s emet=%s fini_signal=%d" % [String(gp.name).get_slice("@", 1) if String(gp.name).begins_with("@") else String(gp.name), (dm.get_class() if dm != null else "-") + "/" + ms, gp.amount, gp.lifetime, str(gp.one_shot), str(gp.emitting), gp.finished.get_connections().size()]
			orph[k] = int(orph.get(k, 0)) + 1
	for k in orph:
		print("EFFETS   racine: %3d x %s" % [orph[k], k])
	var ombre_p := {}
	for p in m.find_children("*", "GPUParticles3D", true, false):
		var gp := p as GPUParticles3D
		if gp.is_visible_in_tree() and gp.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			var k := _origine(gp)
			ombre_p[k] = int(ombre_p.get(k, 0)) + 1
	print("EFFETS particules qui projettent une ombre (visibles) : %s" % str(ombre_p))
	print("EFFETS particules GPU : total=%d visibles=%d (quantité %.0f) dans le champ=%d (quantité %.0f) CPUParticles=%d" % [np, np_vis, quant, np_champ, quant_champ, m.find_children("*", "CPUParticles3D", true, false).size()])
	for cle in pscript:
		var e: Array = pscript[cle]
		print("EFFETS   part[%s] visibles=%d émettent=%d qte=%.0f | champ=%d qte=%.0f" % [cle, e[0], e[4], e[1], e[2], e[3]])
	var nt := 0
	var nt_champ := 0
	var tscript := {}
	for g in m.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree() or gi is GPUParticles3D or not _transparent(gi):
			continue
		nt += 1
		var ab := gi.global_transform * gi.get_aabb()
		if cam != null and _dans_champ(cam, ab.get_center(), ab.size.length() * 0.5 + gi.extra_cull_margin):
			nt_champ += 1
			var cle := _origine(gi)
			tscript[cle] = int(tscript.get(cle, 0)) + 1
	print("EFFETS transparents (hors particules) : visibles=%d dans le champ=%d" % [nt, nt_champ])
	for cle in tscript:
		print("EFFETS   transp[%s] champ=%d" % [cle, tscript[cle]])

## Origine d'un nœud : premier ancêtre portant un script (nom du fichier) ou nom du parent.
func _origine(nd: Node) -> String:
	var a := nd.get_parent()
	while a != null and a != m:
		var sc: Script = a.get_script()
		if sc != null:
			return sc.resource_path.get_file()
		a = a.get_parent()
	return String(nd.get_parent().name) if nd.get_parent() != null else "?"
