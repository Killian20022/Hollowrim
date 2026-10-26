extends SceneTree
## Galerie des gardes de Skarnholt (D/gardes_village), hors du monde (même cadre que galerie_gardien.gd : 640x360, FOV 72°, ps1_post).
##   godot --path . --script res://outils/galerie_gardes.gd -- --sortie=<dossier absolu>
## Sorties : visages.png (les 14 gardes de face, 1 m), gros.png (garde de porte : face 1,4 m, 3/4 1,6 m ; crépuscule),
##           ronde_nuit.png (garde de ronde avec torche, nuit : 3/4 et dos, 2,2 m), groupe.png (les 14 côte à côte, 7 m).
const W := 640
const H := 360
const POST := preload("res://shaders/ps1_post.gdshader")

var sv: SubViewport
var cam: Camera3D
var env: Environment
var soleil: DirectionalLight3D
var lampe: OmniLight3D
var modeles: Array = []
var donnees: Array = []

func _init() -> void:
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _lancer() -> void:
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/gardes/galerie"))
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
	lampe = OmniLight3D.new()
	lampe.light_color = Color(1.0, 0.62, 0.32)
	lampe.omni_range = 9.0
	sv.add_child(lampe)
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	sol.mesh = pm
	sol.material_override = Palette.materiau(Palette.tex("neige_galerie", Palette.NEIGE, 4, 0.4), Vector2(30, 30))
	sv.add_child(sol)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
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
	donnees = GardesVillage.donnees().get("gardes", [])
	for g: Dictionary in donnees:
		var n := GardesVillage.creer_modele(g)
		sv.add_child(n)
		_poser(n, "Idle", 0.25)
		modeles.append(n)
	for i in 4:
		await process_frame
	# 1. visages : chacun seul, de face à 1 m, bande centrale 220 px
	_lumiere("crepuscule")
	var cw := 220
	var vis := Image.create(cw * 7, H * 2, false, Image.FORMAT_RGBA8)
	for k in modeles.size():
		_seul(k)
		var h: float = (modeles[k] as Node3D).scale.y
		var img: Image = await _photo(Vector3.ZERO, 0.0, 1.0, 1.62 * h, 1.55 * h)
		vis.blit_rect(img, Rect2i((W - cw) / 2, 0, cw, H), Vector2i((k % 7) * cw, (k / 7) * H))
	vis.save_png(sortie + "/visages.png")
	# 2. gros plan d'un garde de porte (bouclier au bras)
	var pl := Image.create(W * 2, H, false, Image.FORMAT_RGBA8)
	_seul(0)
	pl.blit_rect(await _photo(Vector3.ZERO, 10.0, 1.4, 1.6, 1.45), Rect2i(0, 0, W, H), Vector2i(0, 0))
	pl.blit_rect(await _photo(Vector3.ZERO, 35.0, 1.7, 1.55, 1.25), Rect2i(0, 0, W, H), Vector2i(W, 0))
	pl.save_png(sortie + "/gros.png")
	# 3. ronde de nuit : torche à la main gauche, bouclier dans le dos
	var ir := -1
	for k in donnees.size():
		if donnees[k].get("type", "") == "ronde":
			ir = k
			break
	if ir >= 0:
		_seul(ir)
		var t3 := GardesVillage.equiper_torche(modeles[ir])
		await process_frame
		GardesVillage.caler_torche(t3, modeles[ir])
		_lumiere("nuit")
		var rn := Image.create(W * 2, H, false, Image.FORMAT_RGBA8)
		rn.blit_rect(await _photo(Vector3.ZERO, -35.0, 2.2, 1.5, 1.05), Rect2i(0, 0, W, H), Vector2i(0, 0))
		rn.blit_rect(await _photo(Vector3.ZERO, 160.0, 2.2, 1.5, 1.05), Rect2i(0, 0, W, H), Vector2i(W, 0))
		rn.save_png(sortie + "/ronde_nuit.png")
		t3.get_parent().queue_free()
	# 4. groupe : tous côte à côte (carrures, barbes, teintes)
	_lumiere("crepuscule")
	for k in modeles.size():
		var n: Node3D = modeles[k]
		n.visible = true
		n.position = Vector3((k - (modeles.size() - 1) / 2.0) * 0.85, 0, 0)
	var grp := Image.create(W * 2, H * 2, false, Image.FORMAT_RGBA8)
	var img2: Image = await _photo(Vector3.ZERO, 0.0, 7.0, 1.4, 1.0)
	img2.resize(W * 2, H * 2, Image.INTERPOLATE_NEAREST)
	grp.blit_rect(img2, Rect2i(0, 0, W * 2, H * 2), Vector2i.ZERO)
	grp.save_png(sortie + "/groupe.png")
	print("GALERIE GARDES : %d modèles -> %s" % [modeles.size(), sortie])
	quit(0)

func _seul(k: int) -> void:
	for i in modeles.size():
		(modeles[i] as Node3D).visible = i == k
		(modeles[i] as Node3D).position = Vector3.ZERO

func _poser(n: Node3D, nom: String, t: float) -> void:
	var ap := n.find_child("Animations", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(nom):
		return
	ap.play(nom)
	ap.seek(ap.get_animation(nom).length * t, true)
	ap.pause()

func _lumiere(mode: String) -> void:
	if mode == "crepuscule":
		env.background_color = Color(0.42, 0.45, 0.55)
		env.ambient_light_color = Color(0.42, 0.48, 0.66)
		env.ambient_light_energy = 0.55
		soleil.light_color = Color(1.0, 0.68, 0.42)
		soleil.light_energy = 1.3
		soleil.rotation_degrees = Vector3(-14, -50, 0)
		lampe.visible = false
	else:
		env.background_color = Color(0.03, 0.035, 0.06)
		env.ambient_light_color = Color(0.22, 0.27, 0.42)
		env.ambient_light_energy = 0.3
		soleil.light_color = Color(0.5, 0.6, 0.9)
		soleil.light_energy = 0.25
		soleil.rotation_degrees = Vector3(-40, 30, 0)
		lampe.visible = false     # seule la torche du garde éclaire

func _photo(centre: Vector3, az_deg: float, dist: float, cam_h: float, cible_h: float) -> Image:
	var az := deg_to_rad(az_deg)
	cam.global_position = centre + Vector3(sin(az) * dist, cam_h, cos(az) * dist)
	cam.look_at(centre + Vector3(0, cible_h, 0), Vector3.UP)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
