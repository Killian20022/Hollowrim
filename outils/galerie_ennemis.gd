extends SceneTree
## Galerie des ENNEMIS nordiques (pnj/ennemis) : pour chaque ennemi, ANCIEN corps Humain (à gauche) | NOUVEAU archétype + variante (à droite).
##   godot --path . --script res://outils/galerie_ennemis.gd -- --sortie=<dossier abs> [--lumiere=crepuscule|nuit] [--az=35] [--dist=4.6] [--anim=Idle]
##        [--seul=<nom>] [--stats]   (--stats : triangles / surfaces / matériaux de chaque variante, sans image)
const W := 640
const H := 360
const POST := preload("res://shaders/ps1_post.gdshader")
const GJ := preload("res://scripts/grotte_jeu.gd")
const C := Color.WHITE

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

func _app_draugr(guerrier: bool) -> Dictionary:
	var app := {"corps": "homme", "draugr": true, "tenue": {"tunique": Color(0.42, 0.38, 0.34), "ceinture": Color(0.6, 0.6, 0.6), "brassards": Color(0.65, 0.62, 0.6), "haillons": Color.WHITE}}
	if guerrier:
		app["tenue"]["mante"] = Color(0.5, 0.48, 0.45)
		app["tenue"]["bottes"] = Color(0.6, 0.6, 0.6)
		app["tenue"]["epaulieres"] = Color.WHITE
		app["tenue"]["pteruges"] = Color.WHITE
		app["tenue"]["cape_courte"] = Color.WHITE
		app["etoffes"] = {"tunique": "mailles_rouille", "brassards": "draugr"}
		app["casque"] = "casque_draugr"
	return app

## [nom, spec EnnemisNordiques, apparence ancienne]
func _liste() -> Array:
	var svan := _app_draugr(true)
	svan.merge({"corps": "femme", "casque": "couronne_givre", "cheveux": "Hair_Long", "teinte_cheveux": Color(1.1, 1.15, 1.25)}, true)
	return [
		["draugr_epee", {"type": "guerrier", "ident": "guerrier_3", "apparence": _app_draugr(true)}, _app_draugr(true)],
		["draugr_sbire", {"type": "sbire", "ident": "sbire_1", "apparence": _app_draugr(false)}, _app_draugr(false)],
		["draugr_sbire2", {"type": "sbire", "ident": "sbire_7", "apparence": _app_draugr(false)}, _app_draugr(false)],
		["draugr_archer", {"type": "sbire", "archer": true, "ident": "sbire_2", "apparence": _app_draugr(false)}, _app_draugr(false)],
		["bandit_0", {"type": "sbire", "ident": "g_b0", "apparence": GJ.apparence_humain(0)}, GJ.apparence_humain(0)],
		["bandit_1", {"type": "sbire", "ident": "g_b1", "apparence": GJ.apparence_humain(1)}, GJ.apparence_humain(1)],
		["bandit_2", {"type": "sbire", "ident": "g_b2x", "apparence": GJ.apparence_humain(2)}, GJ.apparence_humain(2)],
		["bandit_archer", {"type": "sbire", "archer": true, "ident": "g_a3", "apparence": GJ.apparence_humain(3)}, GJ.apparence_humain(3)],
		["bandit_archer2", {"type": "sbire", "archer": true, "ident": "g_a8", "apparence": GJ.apparence_humain(3)}, GJ.apparence_humain(3)],
		["hrafn", {"type": "sbire", "boss": "hrafn", "ident": "hrafn", "apparence": GJ.apparence_humain(4)}, GJ.apparence_humain(4)],
		["svanhild", {"type": "guerrier", "boss": "svanhild", "ident": "svanhild", "apparence": svan}, svan],
		["jarl", {"type": "guerrier", "boss": "jarl", "ident": "jarl", "apparence": _app_draugr(true)}, _app_draugr(true)],
	]

func _echelle(boss: String) -> float:
	return {"svanhild": 1.12, "hrafn": 1.08, "jarl": 1.12}.get(boss, 1.0)

func _lancer() -> void:
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/ennemis"))
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
	cam.fov = 60.0
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
	var lumiere := _arg("lumiere", "crepuscule")
	_regler(lumiere)
	var liste := _liste()
	var seul := _arg("seul", "")
	var stats := _arg("stats", "") != ""
	var vues: Array[Image] = []
	for e: Array in liste:
		if seul != "" and not String(e[0]).begins_with(seul):
			continue
		var spec: Dictionary = e[1]
		var ech := _echelle(String(spec.get("boss", "")))
		var nv := EnnemisNordiques.creer(spec)
		var an := Humain.creer(e[2])
		for pair: Array in [[an, -1.0], [nv, 1.0]]:
			var n: Node3D = pair[0]
			n.scale = Vector3.ONE * ech
			n.position.x = pair[1] * 0.85
			n.rotation.y = deg_to_rad(float(_arg("rot", "0")))
			sv.add_child(n)
			var ap := n.find_child("Animations", true, false) as AnimationPlayer
			var nom := _arg("anim", "Sword_Idle")
			if not ap.has_animation(nom):
				nom = "Idle"
			ap.play(nom)
			ap.seek(ap.get_animation(nom).length * float(_arg("t", "0.3")), true)
			ap.pause()
		print("VARIANTE %-16s %s" % [e[0], nv.get_meta("variante", "?")])
		if stats:
			print("  ", _stats_ligne(nv))
		else:
			var az := float(_arg("az", "20"))
			var d := float(_arg("dist", "4.6"))
			var img: Image = await _photo(az, d, 1.5, 1.05)
			img.save_png(sortie + "/%s.png" % e[0])
			vues.append(img)
		an.queue_free()
		nv.queue_free()
		await process_frame
	if not vues.is_empty():
		var colonnes := 2
		var lignes := (vues.size() + 1) / 2
		var planche := Image.create(W * colonnes, H * lignes, false, Image.FORMAT_RGBA8)
		for i in vues.size():
			planche.blit_rect(vues[i], Rect2i(0, 0, W, H), Vector2i((i % colonnes) * W, (i / colonnes) * H))
		planche.save_png(sortie + "/planche_%s.png" % lumiere)
	print("GALERIE : ", sortie)
	quit(0)

func _stats_ligne(n: Node3D) -> String:
	var tris := 0
	var surf := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			surf += 1
			tris += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
	return "triangles=%d surfaces=%d os=%d" % [tris, surf, (n.find_child("Skeleton3D", true, false) as Skeleton3D).get_bone_count()]

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

