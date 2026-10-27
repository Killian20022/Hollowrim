extends SceneTree
## Planche comparative du JOUEUR « garde amélioré » (chantier perso/joueur_garde) : garde du village / joueur d'avant / héros.
## Hors du monde (comme galerie_gardien_vet.gd) : rendu 640x360 au shader ps1 + passe ps1_post, lumière crépuscule ou nuit + torche.
##   godot --path . --script res://outils/galerie_heros.gd -- --sortie=<dossier absolu> [--persos=garde,avant,heros] [--lumiere=crepuscule|torche]
##        [--mode=planche|anims|stats] [--sans-casque]
## planche : une ligne par perso, colonnes face / 3/4 / profil / dos / vue de la caméra à la 3e personne (nuque) ; anims : poses de combat du héros.
const W := 640
const H := 360
const CW := 240     # largeur d'une case (recadrage portrait)
const POST := preload("res://shaders/ps1_post.gdshader")
const CORPS := preload("res://scripts/corps_joueur.gd")
const EPEE := preload("res://assets/modeles/joueur/epee_nordique.glb")
## Tenue du joueur d'avant ce chantier (corps_joueur.gd, b244b4a) : gardée ici pour la planche avant / après.
const APPARENCE_AVANT := {
	"corps": "homme",
	"tenue": {
		"tunique": Color(0.35, 0.4, 0.55), "pantalon": Color(0.8, 0.75, 0.7), "bottes": Color.WHITE,
		"ceinture": Color.WHITE, "mante": Color(1.1, 1.0, 0.95), "brassards": Color.WHITE, "gants": Color.WHITE, "manchettes": Color.WHITE, "sacoche": Color.WHITE,
	},
	"etoffes": {"tunique": "bleu", "mante": "gris", "pantalon": "brun", "bottes": "cuir_a", "ceinture": "cuir_a", "brassards": "cuir_c", "gants": "cuir_a", "manchettes": "gris", "sacoche": "cuir_a"},
	"cheveux": "Hair_SimpleParted", "teinte_cheveux": Color(0.42, 0.28, 0.17), "barbe": true,
}

var sv: SubViewport
var cam: Camera3D
var env: Environment
var soleil: DirectionalLight3D
var torche: OmniLight3D

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
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/joueur_garde"))
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
	var lumiere := _arg("lumiere", "crepuscule")
	_regler(lumiere)
	var persos := _arg("persos", "garde,avant,heros").split(",")
	var mode := _arg("mode", "planche")
	if mode == "planche":
		# face, 3/4, profil, dos, caméra 3e personne (derrière, épaule droite, 1,7 m)
		var vues := [[0.0, 2.0, 1.4, 1.0], [-35.0, 2.0, 1.4, 1.0], [-90.0, 2.0, 1.4, 1.0], [180.0, 2.0, 1.4, 1.0], [168.0, 2.7, 1.75, 1.45],
			[0.0, 0.95, 1.5, 1.38], [-40.0, 0.95, 1.5, 1.38], [-90.0, 0.95, 1.55, 1.45], [180.0, 0.95, 1.6, 1.42]]   # + gros plans (buste)
		var planche := Image.create(CW * vues.size(), H * persos.size(), false, Image.FORMAT_RGBA8)
		var r := 0
		for p: String in persos:
			var t0 := Time.get_ticks_usec()
			var n := _construire(p)
			print("CONSTRUCTION %s %.1f ms" % [p, (Time.get_ticks_usec() - t0) / 1000.0])
			_stats(p, n)
			for i in 4:
				await process_frame
			_poser(n, "Idle" if p == "garde" else "Sword_Idle", 0.25)
			var c := 0
			for v: Array in vues:
				var img: Image = await _photo(v[0], v[1], v[2], v[3])
				planche.blit_rect(img, Rect2i((W - CW) / 2, 0, CW, H), Vector2i(c * CW, r * H))
				c += 1
			n.queue_free()
			await process_frame
			r += 1
		planche.save_png(sortie + "/planche_%s_%s.png" % [_arg("nom", "comparaison"), lumiere])
	elif mode == "anims":
		var n := _construire(persos[0])
		for i in 4:
			await process_frame
		var clips := [["Sword_Idle", 0.3], ["Walk", 0.25], ["Jog_Fwd", 0.3], ["Sword_Attack", 0.28], ["Sword_Attack", 0.5], ["Sword_Attack", 0.81], ["Idle_Torch", 0.3], ["Hit_Chest", 0.4], ["Jump", 0.3]]
		var bande := Image.create(CW * clips.size(), H * 2, false, Image.FORMAT_RGBA8)
		var i := 0
		for cl: Array in clips:
			_poser(n, cl[0], cl[1])
			for k in 2:
				var img: Image = await _photo(-40.0 if k == 0 else 150.0, 2.8, 1.4, 0.95)
				bande.blit_rect(img, Rect2i((W - CW) / 2, 0, CW, H), Vector2i(i * CW, k * H))
			i += 1
		bande.save_png(sortie + "/anims_%s_%s.png" % [persos[0], lumiere])
	print("GALERIE : ", sortie)
	quit(0)

func _construire(quoi: String) -> Node3D:
	var n: Node3D
	match quoi:
		"garde":
			n = GardesVillage.creer_modele({"bouclier": "bras"})
		"avant":
			n = Humain.creer(APPARENCE_AVANT)
			_epee(n)
		_:
			n = HerosSkarnholt.creer({"casque": _arg("sans-casque", "") == ""})
			_epee(n)
			var sq: Skeleton3D = n.find_child("Skeleton3D", true, false)
			var acc := BoneAttachment3D.new()
			acc.bone_name = "hand_l"
			sq.add_child(acc)
			var pv := Node3D.new()
			pv.transform = CORPS.PRISE_GAUCHE
			acc.add_child(pv)
			Torche.construire(pv)
	sv.add_child(n)
	return n

func _epee(n: Node3D) -> void:
	var sq: Skeleton3D = n.find_child("Skeleton3D", true, false)
	var acc := BoneAttachment3D.new()
	acc.bone_name = "hand_r"
	sq.add_child(acc)
	var arme: Node3D = EPEE.instantiate()
	arme.transform = CORPS.PRISE
	acc.add_child(arme)
	var acier := Palette.tex("acier", Palette.ACIER, 4, 0.3)
	var m := Palette.materiau(acier, Vector2.ONE, Color(0.9, 0.95, 1.05))
	m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
	for mi: MeshInstance3D in arme.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, m)

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
		soleil.light_color = Color(1.0, 0.68, 0.42)
		soleil.light_energy = 1.3
		soleil.rotation_degrees = Vector3(-14, -50, 0)
		torche.visible = false
	else:
		env.background_color = Color(0.03, 0.035, 0.06)
		env.ambient_light_color = Color(0.22, 0.27, 0.42)
		env.ambient_light_energy = 0.3
		soleil.light_color = Color(0.5, 0.6, 0.9)
		soleil.light_energy = 0.25
		soleil.rotation_degrees = Vector3(-40, 30, 0)
		torche.visible = true
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

func _stats(nom: String, n: Node3D) -> void:
	var tris := 0
	var surfaces := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if not (mi.mesh is ArrayMesh) or not mi.visible:
			continue
		for s in mi.mesh.get_surface_count():
			surfaces += 1
			var nb: int = mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)
			tris += nb / 3
	print("STATS %s triangles=%d surfaces=%d" % [nom, tris, surfaces])
