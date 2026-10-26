extends SceneTree
## [D/pnj_village_v2] Planche d'un PNJ du village (PnjNordique.creer) en studio, rendu PS1 : 2 lignes (MIDI : soleil haut blanc ;
## CRÉPUSCULE : soleil bas orangé + ciel froid) x 4 vues (face 3 m, 3/4 2,5 m, profil 2,5 m, visage de près 0,9 m).
##   godot --path . --script res://outils/planche_pnj_village.gd -- --sortie=<dossier absolu> [--ids=volva,ancienne] [--nom=apres]
## Une image par PNJ : <sortie>/<id>_<nom>.png (tuiles 320 x 427, rendu interne 240 x 320 agrandi x 4/3 au plus proche).
## Imprime triangles, surfaces et temps de création de chaque PNJ.
const W := 240
const H := 320
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
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	soleil = DirectionalLight3D.new()
	soleil.shadow_enabled = true
	sv.add_child(soleil)
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	sol.mesh = pm
	sol.material_override = Palette.materiau(Palette.tex("neige_galerie", Palette.NEIGE, 4, 0.4), Vector2(30, 30))
	sv.add_child(sol)
	cam = Camera3D.new()
	cam.fov = 50.0
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
	var ids: Array = _arg("ids", "volva,ancienne,chef,forgeron,chasseuse,garde,garde_lance,eirik").split(",")
	# az, distance, hauteur caméra, cible
	var vues := [[0.0, 3.2, 1.25, 0.95], [40.0, 2.6, 1.35, 1.0], [90.0, 2.6, 1.35, 1.0], [12.0, 0.80, 1.60, 1.56]]
	var lumieres := [
		{"fond": Color(0.62, 0.70, 0.82), "amb": Color(0.70, 0.76, 0.88), "amb_e": 0.75, "col": Color(1.0, 0.96, 0.90), "e": 1.25, "rot": Vector3(-55, -30, 0)},
		{"fond": Color(0.34, 0.33, 0.45), "amb": Color(0.42, 0.48, 0.66), "amb_e": 0.55, "col": Color(1.0, 0.66, 0.42), "e": 0.95, "rot": Vector3(-12, -55, 0)}]
	var TW := W * 4 / 3
	var TH := H * 4 / 3
	for id: String in ids:
		var t0 := Time.get_ticks_usec()
		var n: Node3D = PnjNordique.archetype_seul(id) if _arg("modele", "pnj") == "archetype" else PnjNordique.creer(id)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		print("PLANCHE %s : %.0f ms, %d triangles, %d surfaces" % [id, ms, _tris(n), _surfaces(n)])
		sv.add_child(n)
		_poser(n, "Idle", 0.25)
		var planche := Image.create(TW * 4 + 6, TH * 2 + 2, false, Image.FORMAT_RGBA8)
		planche.fill(Color(0.1, 0.1, 0.1))
		for li in 2:
			var l: Dictionary = lumieres[li]
			env.background_color = l["fond"]
			env.ambient_light_color = l["amb"]
			env.ambient_light_energy = l["amb_e"]
			soleil.light_color = l["col"]
			soleil.light_energy = l["e"]
			soleil.rotation_degrees = l["rot"]
			for k in vues.size():
				var v: Array = vues[k]
				var img: Image = await _photo(v[0], v[1], v[2], v[3])
				img.resize(TW, TH, Image.INTERPOLATE_NEAREST)
				planche.blit_rect(img, Rect2i(0, 0, TW, TH), Vector2i(k * (TW + 2), li * (TH + 2)))
		var chemin := sortie + "/%s_%s.png" % [id, _arg("nom", "planche")]
		planche.save_png(chemin)
		print("PLANCHE : ", chemin)
		n.queue_free()
		await process_frame
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
