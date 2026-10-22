extends SceneTree
## Galerie du Mage nordique (copie de galerie_guerrier.gd) (itérations rapides hors du monde) : rendu 640x360, caméra du jeu (FOV 72°),
## lumière « crépuscule » (soleil bas orangé + ciel bleu) ou « nuit + torche », passe finale ps1_post.
##   godot --path . --script res://outils/galerie_pnj.gd -- --sortie=<dossier absolu> [--mode=planche|anims|gros|cout]
##        [--sans-capuche] [--perso=mage|guerrier|draugr|rien] [--lumiere=crepuscule|nuit|torche]
## planche : 3 colonnes (face, 3/4, dos) x 3 lignes (2, 4, 8 m) ; anims : bande idle, marche, course, attaque, coup, mort (3/4, 3 m) ;
## gros : 2 m face/3/4 agrandi x2 ; stats : triangles, surfaces, passes.
const W := 640
const H := 360
const POST := preload("res://shaders/ps1_post.gdshader")
const VILL := preload("res://scripts/villageois.gd")

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
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/mage"))
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
	var ids: Array = _arg("ids", ",".join(PnjNordique.IDS)).split(",")
	var lumiere := _arg("lumiere", "crepuscule")
	_regler(lumiere)
	var az := float(_arg("az", "35"))
	var dist := float(_arg("dist", "3.4"))
	var cw := 330
	var comp := _arg("anciens", "1") == "1"
	var planche := Image.create(cw * ids.size(), H * (2 if comp else 1), false, Image.FORMAT_RGBA8)
	var c := 0
	for id: String in ids:
		if comp:
			var o := _ancien(id)
			if o:
				sv.add_child(o)
				_poser(o, "Idle", 0.25)
				var img: Image = await _photo(az, dist, 1.4, 0.95)
				planche.blit_rect(img, Rect2i((W - cw) / 2, 0, cw, H), Vector2i(c * cw, 0))
				o.queue_free()
		var t0 := Time.get_ticks_usec()
		var n := PnjNordique.creer(id)
		print("PNJ %s : %.0f ms, %d triangles" % [id, (Time.get_ticks_usec() - t0) / 1000.0, _tris(n)])
		sv.add_child(n)
		_poser(n, _arg("anim", "Idle"), float(_arg("t", "0.25")))
		var img2: Image = await _photo(az, dist, 1.4, 0.95)
		planche.blit_rect(img2, Rect2i((W - cw) / 2, 0, cw, H), Vector2i(c * cw, H if comp else 0))
		n.queue_free()
		await process_frame
		c += 1
	planche.save_png(sortie + "/%s.png" % _arg("nom", "planche_%s_az%d" % [lumiere, int(az)]))
	print("GALERIE : ", sortie)
	quit(0)

func _ancien(id: String) -> Node3D:
	var app: Dictionary = VILL.APPARENCES
	match id:
		"garde_lance": return Humain.creer(app["garde"])
		"eirik": return Humain.creer({"corps": "homme", "cheveux": "Hair_SimpleParted", "teinte_cheveux": Color(0.85, 0.55, 0.3), "peau": Color(0.75, 0.75, 0.8),
			"tenue": {"tunique": Color(0.4, 0.5, 0.42), "pantalon": Color(0.6, 0.55, 0.5), "bottes": Color.WHITE, "ceinture": Color.WHITE, "mante": Color(0.9, 0.85, 0.8)}})
	return Humain.creer(app[id]) if app.has(id) else null

func _tris(n: Node3D) -> int:
	var t := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			t += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
	return t

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

