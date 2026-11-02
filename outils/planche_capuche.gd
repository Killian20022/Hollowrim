extends SceneTree
## Planche de la capuche des mages (persos/capuche_v3) : rendu du jeu (640x360, FOV 72°, ps1_post), hors du monde.
##   godot --path . --script res://outils/planche_capuche.gd -- --sortie=<dossier absolu> --perso=mage|volva|ancienne
##        [--lumiere=jour|crepuscule] [--etiquette=AVANT|APRÈS] [--avant (ancienne capuche)]
## Écrit <perso>_<lumiere>_<vue>.png (vues : pres_*, tete_* (gros plan de la tête), jeu_face, jeu_34, jeu_profil, jeu_dos,
## mvt_marche_a, mvt_marche_b, mvt_sort, mvt_coup, mvt_tete_a, mvt_tete_b) : vignettes carrées 360x360 (près : agrandies x2).
##   godot --path . --script res://outils/planche_capuche.gd -- --assembler --avant=<dossier> --apres=<dossier> --sortie=<dossier>
## assemble les planches AVANT | APRÈS (une ligne par vue, mêmes noms de fichiers dans les deux dossiers).
const W := 640
const H := 360
const POST := preload("res://shaders/ps1_post.gdshader")
const VUES_PRES := [["pres_face", 0.0], ["pres_34", 40.0], ["pres_profil", 90.0], ["pres_dos", 180.0]]
const VUES_TETE := [["tete_face", 0.0], ["tete_34", 40.0], ["tete_profil", 90.0], ["tete_dos", 180.0]]
const VUES_JEU := [["jeu_face", 0.0], ["jeu_34", 40.0], ["jeu_profil", 90.0], ["jeu_dos", 180.0]]
## mouvement : [nom, clip, instant, azimut°]
const VUES_MVT := [["mvt_marche_a", "Walk", 0.25, 50.0], ["mvt_marche_b", "Walk", 0.75, 90.0], ["mvt_sort", "Spell_Simple_Shoot", 0.4, 40.0],
	["mvt_coup", "Hit_Chest", 0.4, 30.0], ["mvt_course", "Jog_Fwd", 0.3, 70.0], ["mvt_parle", "Idle_Talking", 0.5, 25.0]]

var sv: SubViewport
var cam: Camera3D
var env: Environment
var soleil: DirectionalLight3D
var etiquette: Label

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
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/capuche_v3"))
	DirAccess.make_dir_recursive_absolute(sortie)
	if _arg("assembler", "") != "":
		_assembler(_arg("avant", ""), _arg("apres", ""), sortie)
		quit(0)
		return
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
	cam.fov = 72.0
	cam.near = 0.03
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
	var calque2 := CanvasLayer.new()
	calque2.layer = 2
	sv.add_child(calque2)
	etiquette = Label.new()
	etiquette.position = Vector2(150, 4)
	etiquette.add_theme_font_size_override("font_size", 12)
	etiquette.add_theme_color_override("font_color", Color(1, 1, 0.85))
	etiquette.add_theme_color_override("font_outline_color", Color.BLACK)
	etiquette.add_theme_constant_override("outline_size", 4)
	calque2.add_child(etiquette)
	# --avant : l'ancienne capuche (chemin d'origine de MageNordique, inchangé) pour les planches AVANT / APRÈS
	CapucheMage.actif = _arg("avant", "") == ""
	var perso := _arg("perso", "mage")
	var n: Node3D
	if perso == "mage":
		n = MageNordique.creer({})
	else:
		n = PnjNordique.creer(perso)
	sv.add_child(n)
	var dbg := _arg("debug", "")
	if dbg != "":
		var cap := n.find_child("capuche", true, false) as MeshInstance3D
		if dbg == "sans_contour":
			var m := (cap.material_override as ShaderMaterial).duplicate() as ShaderMaterial
			m.next_pass = null
			cap.material_override = m
		elif dbg == "simple":
			var m3 := GuerrierNordique.materiau((cap.material_override as ShaderMaterial).get_shader_parameter("tex_base"), false)
			cap.material_override = m3
		elif dbg == "sans_capuche":
			cap.visible = false
		elif dbg == "blanc":
			var m2 := StandardMaterial3D.new()
			m2.albedo_color = Color(0.8, 0.8, 0.8)
			cap.material_override = m2
	for i in 4:
		await process_frame
	var lum := _arg("lumiere", "jour")
	_regler(lum)
	var tag := _arg("etiquette", "")
	# hauteur des yeux du perso (os Head au repos + 7 cm)
	var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
	var tete_y := sq.get_bone_global_rest(sq.find_bone("Head")).origin.y + 0.08
	_poser(n, "Idle", 0.25)
	for v: Array in VUES_PRES:
		etiquette.text = "%s  %s  %s" % [tag, perso, v[0]]
		var img: Image = await _photo(v[1], 0.95, tete_y + 0.03, tete_y - 0.10)
		var c := img.get_region(Rect2i((W - H) / 2, 0, H, H))
		c.save_png(sortie.path_join("%s_%s_%s.png" % [perso, lum, v[0]]))
	for v: Array in VUES_TETE:
		etiquette.text = "%s  %s  %s" % [tag, perso, v[0]]
		var img: Image = await _photo(v[1], 0.55, tete_y + 0.02, tete_y - 0.05)
		img.get_region(Rect2i((W - H) / 2, 0, H, H)).save_png(sortie.path_join("%s_%s_%s.png" % [perso, lum, v[0]]))
	# --rapide : gros plans seulement (itérations de finition)
	if _arg("rapide", "") != "":
		print("PLANCHE CAPUCHE (rapide) : ", sortie)
		quit(0)
		return
	for v: Array in VUES_JEU:
		etiquette.text = "%s  %s  %s" % [tag, perso, v[0]]
		var img: Image = await _photo(v[1], 2.6, 1.62, 1.15)
		img.get_region(Rect2i((W - H) / 2, 0, H, H)).save_png(sortie.path_join("%s_%s_%s.png" % [perso, lum, v[0]]))
	for v: Array in VUES_MVT:
		_poser(n, v[1], v[2])
		etiquette.text = "%s  %s  %s" % [tag, perso, v[0]]
		var img: Image = await _photo(v[3], 1.25, tete_y, tete_y - 0.25)
		img.get_region(Rect2i((W - H) / 2, 0, H, H)).save_png(sortie.path_join("%s_%s_%s.png" % [perso, lum, v[0]]))
	# bande de marche (8 instants, 3/4) : la capuche en mouvement
	var bande := Image.create(240 * 8, 300, false, Image.FORMAT_RGBA8)
	for k in 8:
		_poser(n, "Walk", k / 8.0)
		etiquette.text = "%s %d/8" % [tag, k + 1]
		var img: Image = await _photo(45.0, 1.5, tete_y, tete_y - 0.3)
		bande.blit_rect(img, Rect2i((W - 240) / 2, 20, 240, 300), Vector2i(k * 240, 0))
	bande.save_png(sortie.path_join("%s_%s_bande_marche.png" % [perso, lum]))
	print("PLANCHE CAPUCHE : ", sortie)
	quit(0)

func _poser(n: Node3D, nom: String, t: float) -> void:
	var ap := n.find_child("Animations", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(nom):
		push_warning("animation absente " + nom)
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
	else:
		env.background_color = Color(0.62, 0.68, 0.76)
		env.ambient_light_color = Color(0.55, 0.60, 0.70)
		env.ambient_light_energy = 0.65
		soleil.light_color = Color(1.0, 0.96, 0.90)
		soleil.light_energy = 1.25
		soleil.rotation_degrees = Vector3(-42, -35, 0)

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

func _cle_vue(f: String) -> String:
	var g := f.get_basename()
	for cle in ["_pres_", "_tete_", "_jeu_", "_mvt_"]:
		if g.contains(cle):
			return g.substr(g.find(cle) + cle.length())
	return g

## AVANT | APRÈS : pour chaque fichier commun (trié), une paire côte à côte ; les vignettes sont regroupées par 4 paires par ligne.
func _assembler(avant: String, apres: String, sortie: String) -> void:
	var noms := []
	for f in DirAccess.get_files_at(apres):
		if f.ends_with(".png") and FileAccess.file_exists(avant.path_join(f)):
			noms.append(f)
	# ordre de lecture : face, trois-quarts, profil, dos (puis le mouvement)
	var ordre := ["face", "34", "profil", "dos", "marche_a", "marche_b", "course", "sort", "coup", "parle"]
	noms.sort_custom(func(a: String, b: String) -> bool:
		var ka := _cle_vue(a)
		var kb := _cle_vue(b)
		var ia := ordre.find(ka)
		var ib := ordre.find(kb)
		if ia == ib:
			return a < b
		return ia < ib)
	var groupes := {}
	for f: String in noms:
		var g := f.get_basename()
		for cle in ["_pres_", "_tete_", "_jeu_", "_mvt_", "_bande_"]:
			if g.contains(cle):
				g = g.substr(0, g.find(cle) + cle.length() - 1)
		if not groupes.has(g):
			groupes[g] = []
		groupes[g].append(f)
	for g: String in groupes:
		var liste: Array = groupes[g]
		var a0 := Image.load_from_file(avant.path_join(liste[0]))
		var s := a0.get_size()
		var zoom := 2 if (g.ends_with("_pres") or g.ends_with("_tete")) else 1
		var cw := s.x * zoom
		var ch := s.y * zoom
		var bande := g.ends_with("_bande")
		var cols := 1 if bande else liste.size()
		var lignes := liste.size() if bande else 1
		var out := Image.create(cols * cw, 2 * lignes * ch + 8 * lignes, false, Image.FORMAT_RGBA8)
		out.fill(Color(0.1, 0.1, 0.1))
		for i in liste.size():
			for j in 2:
				var img := Image.load_from_file((avant if j == 0 else apres).path_join(liste[i]))
				img.convert(Image.FORMAT_RGBA8)
				if zoom > 1:
					img.resize(cw, ch, Image.INTERPOLATE_NEAREST)
				var x := 0 if bande else i * cw
				var y := (i * 2 * ch + i * 8 if bande else 0) + j * (ch + 8)
				out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, y))
		out.save_png(sortie.path_join("%s__haut_AVANT__bas_APRES.png" % g))
		print("ASSEMBLE ", g)
