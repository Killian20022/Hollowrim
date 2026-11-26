extends "res://outils/audit_trous_crypte.gd"
## Diagnostic d'une fissure de l'audit des vides : pour une vue (point, n° de vue), rend la vue en jeu (fond magenta), puis une passe
## « identité » (chaque GeometryInstance3D de la crypte d'une couleur unie) et liste, pour les pixels magenta, les objets dessinés
## juste au-dessus / au-dessous / à gauche / à droite, et la position monde (passe P) du pixel.
##   godot --path . --script res://outils/diag_fissure_crypte.gd -- --nouvelle --paisible --crypte=0,0.5,0,0 --sortie=C:/chemin
##         --point=25,-4 --vues=21,23
var _ids: Array = []

func _go() -> void:
	sortie = _arg("sortie", "")
	DirAccess.make_dir_recursive_absolute(sortie)
	s = load("res://scenes/foret_test.tscn").instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	current_scene = s
	j = s.joueur
	var n := 0
	while n < 60 * 90 and not (s.tertre != null and s.tertre.dedans):
		await process_frame
		n += 1
	t = s.tertre
	t.attendre_donjon()
	for i in 90:
		await process_frame
	t.crypte.visible = true
	for c in s.get_children():
		if c is Node3D and c != t.crypte and c != j and (c as Node3D).visible:
			(c as Node3D).visible = false
	s._ouvrir_donjon("s1,s2,s3,secret,herse")
	if t.donjon.portes.has("secret"):
		(t.donjon.portes["secret"] as Node3D).rotation.y = -PI * 0.5
	for k in get_nodes_in_group("cassables"):
		if not (k is Cassable) and k.has_method("casser"):
			k.casser(false)
	j.set_physics_process(false)
	j.set_process(false)
	j.visible = false
	var cip := root.get_node_or_null("CompteurIps")
	if cip != null:
		cip.set_process(false)
		cip.set("visible", false)
	var hud = s.get("hud")
	if hud != null and hud is CanvasItem:
		(hud as CanvasItem).visible = false
	for i in 30:
		await process_frame
	sv = SubViewport.new()
	sv.size = Vector2i(L, H)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(sv)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
	cam.far = 200.0
	sv.add_child(cam)
	cam.make_current()
	mat_p_cull = _mat_p("cull_disabled", "1.0")
	mat_p_double = _mat_p("cull_disabled", "0.5")
	var pc := _arg("point", "25,-4").split(",")
	var p: Vector3 = t.crypte.to_global(Vector3(float(pc[0]), 0, float(pc[1])))
	p.y = t.crypte.global_position.y + 0.0
	var vues := Array(_arg("vues", "21,23").split(","))
	j.global_position = p
	for k in 3:
		t._gerer_zones()
	t.salles.rafraichir(true)
	for vs in vues:
		var kk := int(vs)
		cam.environment = _env_j()
		_viser(p, kk)
		for k in 4:
			await RenderingServer.frame_post_draw
		var img := sv.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_png("%s/v%d_jeu.png" % [sortie, kk])
		var mg := _magenta(img)
		print("VUE %d : %d px magenta" % [kk, mg.size()])
		if mg.is_empty():
			continue
		# passe identité, matériaux du jeu gardés mais remplacés : couleur unie par objet, culling arrière comme en jeu
		var sauve := {}
		_ids.clear()
		var pile: Array = [t.crypte]
		while not pile.is_empty():
			var nd: Node = pile.pop_back()
			pile.append_array(nd.get_children())
			if nd is GeometryInstance3D and (nd as GeometryInstance3D).is_visible_in_tree():
				var gi := nd as GeometryInstance3D
				var i := _ids.size()
				_ids.append(gi)
				var m := StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.albedo_color = Color8((i * 37) % 256, (i / 7 * 53) % 256, 40 + (i % 7) * 30)
				m.disable_fog = true
				sauve[gi] = gi.material_override
				gi.material_override = m
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(1, 0, 1)
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		cam.environment = env
		for k in 4:
			await RenderingServer.frame_post_draw
		var iid := sv.get_texture().get_image()
		iid.convert(Image.FORMAT_RGB8)
		iid.save_png("%s/v%d_id.png" % [sortie, kk])
		for gi in sauve:
			gi.material_override = sauve[gi]
		var par_col := {}
		for i in _ids.size():
			var gi: GeometryInstance3D = _ids[i]
			par_col[Color8((i * 37) % 256, (i / 7 * 53) % 256, 40 + (i % 7) * 30).to_html(false)] = gi
		var stats := {}
		var ens := {}
		for idx in mg:
			ens[idx] = true
		var echant := 0
		for idx in mg:
			var x := idx % L
			var y := idx / L
			var c_id := iid.get_pixel(x, y).to_html(false)
			var lab := "ID@pixel=" + (str(par_col[c_id].get_path()) if par_col.has(c_id) else c_id)
			stats[lab] = int(stats.get(lab, 0)) + 1
			for d: Vector2i in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
				var q := Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= L or q.y >= H or ens.has(q.y * L + q.x):
					continue
				var cc := iid.get_pixel(q.x, q.y).to_html(false)
				var nm := (str(par_col[cc].get_path()).replace(str(t.crypte.get_path()), "") if par_col.has(cc) else cc)
				var cle := "%s %s" % [str(d), nm]
				stats[cle] = int(stats.get(cle, 0)) + 1
			if echant < 6 and echant * (mg.size() / 6) <= mg.find(idx):
				var o := cam.project_ray_origin(Vector2(x + 0.5, y + 0.5) * Vector2(1, 1))
				var dir := cam.project_ray_normal(Vector2(x + 0.5, y + 0.5))
				print("  px (%d,%d) rayon local o=%s dir=%s" % [x, y, t.crypte.to_local(o), t.crypte.global_basis.inverse() * dir])
				echant += 1
		var cles := stats.keys()
		cles.sort_custom(func(a, b) -> bool: return stats[a] > stats[b])
		for c in cles.slice(0, 25):
			print("  %5d  %s" % [stats[c], c])
	quit(0)
