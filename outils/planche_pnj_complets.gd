extends SceneTree
## [D/pnj] Planche « PNJ complets » : pour chaque PNJ, l'archétype de référence (tel que confectionné, options d'armes du PNJ, AUCUNE
## retouche) puis le PNJ du jeu (PnjNordique.creer), en lumière de JOUR (soleil haut blanc, ciel clair) : face, 3/4, buste de face.
##   godot --path . --script res://outils/planche_pnj_complets.gd -- --sortie=<dossier absolu> [--nom=avant] [--ids=volva,ancienne]
## Une ligne par PNJ : ARCHÉTYPE face | 3/4 | buste || PNJ face | 3/4 | buste. Imprime aussi triangles et temps de création.
const W := 640
const H := 360
const CW := 220
const POST := preload("res://shaders/ps1_post.gdshader")

var sv: SubViewport
var cam: Camera3D
var env: Environment
var soleil: DirectionalLight3D

func _init() -> void:
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

## Archétype de référence de chaque PNJ (mêmes options que le PNJ : armes, corps ; rien de retouché).
static func archetype_de(id: String) -> Node3D:
	match id:
		"garde": return GuerrierNordique.creer({"casque": true, "bouclier": "bras", "epee": true})
		"garde_lance": return GardienNordique.creer({"bouclier": "dos", "lance": true})
		"forgeron": return GuerrierNordique.creer({"casque": false, "bouclier": "", "epee": false, "avant_bras_nus": true})
		"chasseuse": return ChasseresseNordique.creer({})
		"volva": return MageNordique.creer({"baton": true, "capuche": true, "corps": "femme"})
		"ancienne": return MageNordique.creer({"baton": false, "capuche": true, "corps": "femme"})
		"chef": return ChasseresseNordique.creer({"arc": false, "carquois": false, "couteau": false})
		"eirik": return GuerrierNordique.creer({"casque": false, "bouclier": "", "epee": false})
	return null

func _lancer() -> void:
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/pnj"))
	DirAccess.make_dir_recursive_absolute(sortie)
	sv = SubViewport.new()
	sv.size = Vector2i(W, H)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.70, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.76, 0.88)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	soleil = DirectionalLight3D.new()
	soleil.shadow_enabled = true
	soleil.light_color = Color(1.0, 0.96, 0.90)
	soleil.light_energy = 1.25
	soleil.rotation_degrees = Vector3(-50, -30, 0)
	sv.add_child(soleil)
	var sol := MeshInstance3D.new()
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
	var ids: Array = _arg("ids", "garde,forgeron,chasseuse,volva,ancienne,chef,eirik").split(",")
	var vues := [[0.0, 3.0, 1.3, 0.92], [35.0, 3.0, 1.3, 0.92], [0.0, 1.25, 1.5, 1.42]]     # az, distance, hauteur caméra, cible
	var planche := Image.create(CW * 6 + 8, H * ids.size(), false, Image.FORMAT_RGBA8)
	planche.fill(Color(0.1, 0.1, 0.1))
	var ligne := 0
	for id: String in ids:
		for col in 2:
			var t0 := Time.get_ticks_usec()
			var n: Node3D = archetype_de(id) if col == 0 else PnjNordique.creer(id)
			if n == null:
				continue
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			print("PLANCHE %s %s : %.0f ms, %d triangles, %d surfaces" % [id, "archetype" if col == 0 else "pnj", ms, _tris(n), _surfaces(n)])
			sv.add_child(n)
			_poser(n, "Idle", 0.25)
			for k in vues.size():
				var v: Array = vues[k]
				var img: Image = await _photo(v[0], v[1], v[2], v[3])
				planche.blit_rect(img, Rect2i((W - CW) / 2, 0, CW, H), Vector2i(col * (CW * 3 + 8) + k * CW, ligne * H))
			n.queue_free()
			await process_frame
		ligne += 1
	var chemin := sortie + "/%s.png" % _arg("nom", "planche")
	planche.save_png(chemin)
	print("PLANCHE : ", chemin)
	quit(0)

func _tris(n: Node3D) -> int:
	var t := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			t += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
	return t

func _surfaces(n: Node3D) -> int:
	var s := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh != null and mi.is_visible_in_tree():
			s += mi.mesh.get_surface_count()
	return s

func _poser(n: Node3D, nom: String, t: float) -> void:
	var ap := n.find_child("Animations", true, false) as AnimationPlayer
	if not ap.has_animation(nom):
		return
	ap.play(nom)
	ap.seek(ap.get_animation(nom).length * t, true)
	ap.pause()

func _photo(az_deg: float, dist: float, cam_h: float, cible_h: float) -> Image:
	var az := deg_to_rad(az_deg)
	cam.global_position = Vector3(sin(az) * dist, cam_h, cos(az) * dist)
	cam.look_at(Vector3(0, cible_h, 0), Vector3.UP)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
