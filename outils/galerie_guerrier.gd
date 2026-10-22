extends SceneTree
## Galerie du Guerrier nordique pilote (itérations rapides hors du monde) : rendu 640x360, caméra du jeu (FOV 72°),
## lumière « crépuscule » (soleil bas orangé + ciel bleu) ou « nuit + torche », passe finale ps1_post.
##   godot --path . --script res://outils/galerie_guerrier.gd -- --sortie=<dossier absolu> [--mode=planche|anims|gros|stats]
##        [--casque] [--bouclier=bras|dos|] [--perso=guerrier|draugr|garde_avant]
## planche : 3 colonnes (face, 3/4, dos) x 3 lignes (2, 4, 8 m) ; anims : bande idle, marche, course, attaque, coup, mort (3/4, 3 m) ;
## gros : 2 m face/3/4 agrandi x2 ; stats : triangles, surfaces, passes.
const W := 640
const H := 360
const POST := preload("res://shaders/ps1_post.gdshader")
const DRAUGR := preload("res://scripts/draugr.gd")

var sv: SubViewport
var cam: Camera3D
var env: Environment
var soleil: DirectionalLight3D
var torche: OmniLight3D
var sol: MeshInstance3D

func _init() -> void:
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _lancer() -> void:
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/guerrier"))
	DirAccess.make_dir_recursive_absolute(sortie)
	sv = SubViewport.new()
	sv.size = Vector2i(W, H)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	soleil = DirectionalLight3D.new()
	soleil.shadow_enabled = true
	sv.add_child(soleil)
	torche = OmniLight3D.new()
	torche.light_color = Color(1.0, 0.62, 0.32)
	torche.omni_range = 9.0
	torche.omni_attenuation = 1.2
	sv.add_child(torche)
	sol = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	sol.mesh = pm
	sol.material_override = Palette.materiau(Palette.tex("neige_galerie", Palette.NEIGE, 4, 0.4), Vector2(30, 30))
	sv.add_child(sol)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
	cam.far = 200.0
	sv.add_child(cam)
	var calque := CanvasLayer.new()
	sv.add_child(calque)
	var post := ColorRect.new()
	post.size = Vector2(W, H)
	var pmat := ShaderMaterial.new()
	pmat.shader = POST
	pmat.set_shader_parameter("vignette", 0.0)
	post.material = pmat
	calque.add_child(post)
	var t0 := Time.get_ticks_usec()
	var n := _construire(_arg("perso", "guerrier"))
	print("CONSTRUCTION %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	for i in 4:
		await process_frame
	var mode := _arg("mode", "planche")
	if n:
		_stats(n)
	var lumiere := _arg("lumiere", "crepuscule")
	if mode == "planche":
		_regler(lumiere)
		var planche := Image.create(W * 3, H * 3, false, Image.FORMAT_RGBA8)
		_poser(n, "Idle" if _arg("perso", "guerrier") != "draugr" else "Sword_Idle", 0.25)
		var r := 0
		for d: float in [2.0, 4.0, 8.0]:
			var c := 0
			for az: float in [0.0, 35.0, 180.0]:
				var img: Image = await _photo(az, d, 1.6, 1.0 if d < 3.0 else 0.95)
				planche.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(c * W, r * H))
				c += 1
			r += 1
		planche.save_png(sortie + "/planche_%s.png" % lumiere)
		# zoom x2 de la rangée à 2 m (bande centrale de 220 px de large)
		var zoom := Image.create(440 * 3, H * 2, false, Image.FORMAT_RGBA8)
		for c2 in 3:
			var reg := planche.get_region(Rect2i(c2 * W + 210, 0, 220, H))
			reg.resize(440, H * 2, Image.INTERPOLATE_NEAREST)
			zoom.blit_rect(reg, Rect2i(0, 0, 440, H * 2), Vector2i(c2 * 440, 0))
		zoom.save_png(sortie + "/zoom2m_%s.png" % lumiere)
	elif mode == "gros":
		_regler(lumiere)
		_poser(n, "Idle", 0.25)
		var pl := Image.create(W * 2, H, false, Image.FORMAT_RGBA8)
		var c := 0
		for vue: Array in [[15.0, 0.9, 1.62, 1.6], [-30.0, 1.4, 1.5, 1.35]]:
			var img: Image = await _photo(vue[0], vue[1], vue[2], vue[3])
			pl.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(c * W, 0))
			c += 1
		pl.resize(W * 2, H, Image.INTERPOLATE_NEAREST)
		pl.save_png(sortie + "/gros_%s.png" % lumiere)
	elif mode == "vet":
		# passe vêtements : vues à 2 m (face, 3/4, dos), gros plans à 1 m, 4 m et 8 m ; une PNG par vue (640x360), crépuscule
		_regler(lumiere)
		_poser(n, "Idle", 0.3)
		# [azimut°, distance m, hauteur caméra m, hauteur visée m, champ de vision°]
		var vues := {
			"2m_face": [0.0, 2.0, 1.6, 1.0, 72.0], "2m_34": [-35.0, 2.0, 1.6, 1.0, 72.0], "2m_dos": [180.0, 2.0, 1.6, 1.0, 72.0],
			"4m_face": [0.0, 4.0, 1.6, 0.95, 72.0], "4m_34": [-35.0, 4.0, 1.6, 0.95, 72.0], "4m_dos": [180.0, 4.0, 1.6, 0.95, 72.0],
			"8m_face": [0.0, 8.0, 1.6, 0.95, 72.0], "8m_34": [-35.0, 8.0, 1.6, 0.95, 72.0], "8m_dos": [180.0, 8.0, 1.6, 0.95, 72.0],
			"gros_torse": [-20.0, 1.0, 1.45, 1.3, 42.0], "gros_ceinture": [-15.0, 1.0, 1.15, 0.95, 42.0], "gros_bas": [-25.0, 1.1, 0.9, 0.72, 42.0],
			"gros_bottes": [-30.0, 1.0, 0.6, 0.3, 42.0], "gros_dos": [170.0, 1.1, 1.45, 1.2, 46.0], "gros_epaule": [-55.0, 1.0, 1.6, 1.42, 42.0],
			"gros_bras": [40.0, 1.0, 1.3, 1.15, 42.0], "gros_cape_dos": [180.0, 1.2, 1.0, 0.75, 46.0], "gros_dos_haut": [160.0, 1.0, 1.7, 1.5, 42.0]}
		for k: String in vues:
			var v: Array = vues[k]
			cam.fov = v[4]
			var img: Image = await _photo(v[0], v[1], v[2], v[3])
			img.save_png(sortie + "/%s.png" % k)
		cam.fov = 72.0
	elif mode == "anims":
		_regler(lumiere)
		var clips := [["Idle", 0.3], ["Walk", 0.25], ["Walk", 0.75], ["Jog_Fwd", 0.3], ["Sprint", 0.4], ["Sword_Idle", 0.3], ["Sword_Attack", 0.35], ["Sword_Attack", 0.6], ["Hit_Chest", 0.4], ["Death01", 0.5], ["Death01", 1.0]]
		var cw := 320
		var bande := Image.create(cw * clips.size(), H, false, Image.FORMAT_RGBA8)
		var i := 0
		for cl: Array in clips:
			_poser(n, cl[0], cl[1])
			var img: Image = await _photo(float(_arg("az", "40")), 3.2, 1.3, 0.9)
			bande.blit_rect(img, Rect2i((W - cw) / 2, 0, cw, H), Vector2i(i * cw, 0))
			i += 1
		bande.save_png(sortie + "/anims_%s_az%s.png" % [lumiere, _arg("az", "40")])
	elif mode == "cout":
		# ms GPU du SubViewport (moyenne sur 120 images), personnage à 3 m en 3/4, n exemplaires côte à côte
		_regler(lumiere)
		var nb := int(_arg("nombre", "1"))
		var copies: Array[Node3D] = [n]
		if n:
			n.position.x = 0.0
			for k in range(1, nb):
				var c2 := _construire(_arg("perso", "guerrier"))
				c2.position.x = (k - (nb - 1) / 2.0) * 0.9
				copies.append(c2)
			for c3 in copies:
				_poser(c3, "Sword_Idle" if c3.find_child("Animations", true, false).has_animation("Sword_Idle") else "Idle", 0.25)
		await _photo(35.0, 3.0 + 0.3 * nb, 1.6, 1.0)
		var vp := sv.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		for i in 30:
			await RenderingServer.frame_post_draw
		var gpu := 0.0
		var cpu := 0.0
		for i in 120:
			await RenderingServer.frame_post_draw
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		var dc := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var pr := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var dco := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		print("COUT perso=%s nombre=%d gpu=%.3f ms cpu=%.3f ms draw_calls=%d draw_calls_ombre=%d primitives=%d" % [_arg("perso", "guerrier"), nb, gpu / 120.0, cpu / 120.0, dc, dco, pr])
	print("GALERIE : ", sortie)
	quit(0)

func _construire(quoi: String) -> Node3D:
	var n: Node3D
	if quoi == "rien":
		return null
	if quoi == "draugr":
		var d := CharacterBody3D.new()
		d.set_script(DRAUGR)
		d.set("type", "guerrier")
		d.set("dort", false)
		sv.add_child(d)
		d.set_physics_process(false)
		return d
	if quoi == "forgeron" or quoi == "garde" or quoi == "chef_bandit":
		n = PnjNordique.creer(quoi) if quoi != "chef_bandit" else GuerrierNordique.creer({"casque": true, "bouclier": "dos", "epee": true})
		sv.add_child(n)
		return n
	if quoi == "chasseresse":
		n = ChasseresseNordique.creer({})
		sv.add_child(n)
		return n
	var opts := {"casque": _arg("casque", "") != "", "bouclier": _arg("bouclier", "bras"), "sous_couche": _arg("sous-couche", "") != ""}
	GuerrierNordique.chrono = true
	n = GuerrierNordique.creer(opts)
	sv.add_child(n)
	return n

func _poser(n: Node3D, nom: String, t: float) -> void:
	var ap := n.find_child("Animations", true, false) as AnimationPlayer
	if not ap.has_animation(nom):
		push_error("animation absente " + nom)
		return
	ap.play(nom)
	ap.seek(ap.get_animation(nom).length * t, true)
	ap.pause()

func _regler(mode: String) -> void:
	if mode == "crepuscule":
		env.background_color = Color(0.42, 0.45, 0.55)
		env.ambient_light_color = Color(0.42, 0.48, 0.66)
		env.ambient_light_energy = 0.55
		soleil.visible = true
		soleil.light_color = Color(1.0, 0.68, 0.42)
		soleil.light_energy = 1.3
		soleil.rotation_degrees = Vector3(-14, -50, 0)
		torche.visible = false
	else:
		env.background_color = Color(0.03, 0.035, 0.06)
		env.ambient_light_color = Color(0.22, 0.27, 0.42)
		env.ambient_light_energy = 0.3
		soleil.visible = true
		soleil.light_color = Color(0.5, 0.6, 0.9)
		soleil.light_energy = 0.25
		soleil.rotation_degrees = Vector3(-40, 30, 0)
		torche.visible = mode == "torche"
		torche.light_energy = 2.2

func _photo(az_deg: float, dist: float, cam_h: float, cible_h: float) -> Image:
	var az := deg_to_rad(az_deg)
	cam.global_position = Vector3(sin(az) * dist, cam_h, cos(az) * dist)
	cam.look_at(Vector3(0, cible_h, 0), Vector3.UP)
	var cote := Vector3(cos(az), 0, -sin(az))
	torche.global_position = cam.global_position + cote * 0.9 + Vector3(0, 0.2, 0)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _stats(n: Node3D) -> void:
	var tris := 0
	var surfaces := 0
	var passes := 0
	var mats := {}
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var t_mi := 0
		for s in mi.mesh.get_surface_count():
			surfaces += 1
			var nb: int = mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)
			t_mi += nb / 3
			var m: Material = mi.get_surface_override_material(s)
			if m == null:
				m = mi.material_override
			if m == null:
				m = mi.mesh.surface_get_material(s)
			passes += 1
			if m and m.next_pass:
				passes += 1
			mats[m] = true
		tris += t_mi
		print("  PIECE %s : %d triangles" % [mi.name, t_mi])
	print("STATS triangles=%d surfaces=%d passes=%d materiaux=%d" % [tris, surfaces, passes, mats.size()])
