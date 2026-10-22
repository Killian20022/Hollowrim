extends SceneTree
## Gros plans VETEMENTS de la chasseresse (passe vetements) ; copie reduite de galerie_guerrier.gd. Galerie du Guerrier nordique pilote (itérations rapides hors du monde) : rendu 640x360, caméra du jeu (FOV 72°),
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
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/chasseresse_vet"))
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
	var n := _construire("archer_homme" if _arg("homme", "") != "" else "chasseresse")
	print("CONSTRUCTION %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	for i in 4:
		await process_frame
	_regler("crepuscule")
	_poser(n, "Idle", 0.3)
	# nom : [azimut, distance, hauteur camera, hauteur visee]
	var vues := {
		"g1_torse": [0.0, 0.85, 1.40, 1.28], "g1_torse34": [-35.0, 0.85, 1.40, 1.28],
		"g1_ceinture": [0.0, 0.85, 1.05, 0.95], "g1_ceinture34": [-35.0, 0.85, 1.05, 0.95],
		"g1_jupe": [0.0, 0.95, 0.75, 0.62], "g1_jupe34": [-40.0, 0.95, 0.75, 0.62],
		"g1_bottes": [-20.0, 0.9, 0.45, 0.28], "g1_dos": [180.0, 1.0, 1.30, 1.15], "g1_dos34": [150.0, 1.0, 1.10, 0.95],
		"g1_col": [-25.0, 0.7, 1.52, 1.42], "g1_bras": [-70.0, 0.9, 1.25, 1.15]}
	if _arg("homme", "") != "":
		vues = {"h2m_face": [0.0, 2.0, 1.45, 0.95], "h2m_34": [-35.0, 2.0, 1.45, 0.95], "h2m_dos": [180.0, 2.0, 1.45, 0.95],
			"h1_torse34": [-35.0, 0.85, 1.40, 1.30], "h1_jupe34": [-40.0, 0.95, 0.75, 0.66], "h1_dos": [180.0, 1.0, 1.30, 1.18]}
	for nom: String in vues:
		var v: Array = vues[nom]
		var img: Image = await _photo(v[0], v[1], v[2], v[3])
		img.resize(W * 2, H * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(sortie + "/%s.png" % nom)
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
	if quoi == "archer_homme":
		# archer bandit à corps homme, teinté comme en jeu (EnnemisNordiques) : on cherche une identité qui tire un homme
		for i in 40:
			n = EnnemisNordiques.creer({"archer": true, "ident": "capt%d" % i, "apparence": {"tenue": {}, "draugr": false}})
			if n != null and n.get_meta("archer_homme", false):
				break
			if n != null:
				n.free()
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
