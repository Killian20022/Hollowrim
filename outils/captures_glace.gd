extends SceneTree
## Sorts de GLACE en jeu (scenes/test_magie.tscn, vraies mains, vrai lanceur) : preuve du correctif du « triangle bleu »
## au départ des éclats, planches et films. FENÊTRE (via godot_slot.sh : hors écran).
##   godot --path . --script res://outils/captures_glace.gd -- --rafale=<dossier> [--sort=eclat_glace|lance_givre]
##     lance le sort deux fois et enregistre CHAQUE image des 0,25 s qui suivent le départ (rafale_<n>.png) ; journal
##     « PROCHE » : distance minimale (m, axe de la vue) entre l'œil et les sommets des cristaux de chaque projectile,
##     puis « BILAN » : nombre d'images où un cristal passe à moins de 0,2 m de l'œil (le triangle géant).
##   ... -- --planche=<fichier.png> [--sort=…] [--de=0.45] [--pas=0.0333]   12 vignettes à pas fixe à partir de --de
##   godot --path . --write-movie <fichier.avi> --fixed-fps 60 --script res://outils/captures_glace.gd -- --film
##     éclat de glace ×2, lance de givre chargée, double éclat (film de démonstration).

const SCENE := preload("res://scenes/test_magie.tscn")
const PROCHE_MIN := 0.2

var s: Node3D
var m: MainSort
var l: Label
var images_proches := 0
var zmin_global := 1e9

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _attendre(t: float) -> void:
	await create_timer(t, true, false, false).timeout

func _go() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await process_frame
	m = s.magie
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(8, 8)
	calque.add_child(l)
	var sort := _arg("sort", "eclat_glace")
	if _arg("rafale") != "":
		await _rafale(sort, _arg("rafale"))
	elif _arg("planche") != "":
		await _planche(sort, _arg("planche"))
	else:
		await _film()
	quit(0)

func _preparer(gauche: String, droite: String) -> void:
	m.equiper("droite", droite)
	m.equiper("gauche", gauche)
	s.placer_joueur(Vector3(0, 0, 1.6), 0.0)
	_recharger()
	await _attendre(0.6)

func _recharger() -> void:
	s.joueur.mana = s.joueur.mana_max
	m.recharges.clear()

## Distance minimale (axe de la vue, m) entre l'œil et les sommets des cristaux des projectiles de magie.
func _mesurer_proches() -> float:
	var cam: Camera3D = s.joueur.camera
	var vue := cam.global_transform.affine_inverse()
	var zmin := 1e9
	for n in root.find_children("ProjectileMagie", "Node3D", true, false):
		for mi in (n as Node).find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			if mesh == null or not (mi as MeshInstance3D).is_visible_in_tree():
				continue
			var xf: Transform3D = vue * (mi as MeshInstance3D).global_transform
			for v in mesh.get_faces():
				zmin = minf(zmin, -(xf * v).z)
	return zmin

## Émetteurs de particules dont la forme est un cristal 3D (maillage « eclat ») : nom, distance de l'émetteur à l'œil
## (axe de la vue), taille maximale des cristaux.
func _emetteurs_cristaux_proches() -> String:
	var cam: Camera3D = s.joueur.camera
	var vue := cam.global_transform.affine_inverse()
	var res := []
	for p in root.find_children("*", "GPUParticles3D", true, false):
		var gp := p as GPUParticles3D
		if not gp.is_visible_in_tree() or not gp.emitting or gp.draw_pass_1 == null or gp.draw_pass_1 is QuadMesh:
			continue
		var pm := gp.process_material as ParticleProcessMaterial
		res.append("%s@%.2fm(t%.2f)" % [gp.name, -(vue * gp.global_position).z, pm.scale_max if pm != null else -1.0])
	return ",".join(res)

## Sort selon son type : appui bref (rapide) ou charge tenue 1 s (lance).
func _lancer(sort: String, main := "gauche") -> void:
	_recharger()
	m.appuyer(main)
	await _attendre(1.0 if sort == "lance_givre" else 0.08)
	m.relacher(main)

func _rafale(sort: String, dossier: String) -> void:
	DirAccess.make_dir_recursive_absolute(dossier)
	await _preparer(sort, "epee")
	var k := 0
	for essai in 2:
		# enregistre chaque image dès l'appui (incantation comprise) pendant 24 images
		_lancer(sort)
		for f in 24:
			await RenderingServer.frame_post_draw
			var z := _mesurer_proches()
			var zp := _emetteurs_cristaux_proches()
			zmin_global = minf(zmin_global, z)
			if z < PROCHE_MIN:
				images_proches += 1
			var img := root.get_viewport().get_texture().get_image()
			img.save_png(dossier.path_join("rafale_%02d.png" % k))
			print("PROCHE essai %d image %d %s projectile zmin %.3f m ; émetteurs à cristaux %s" % [essai, f, m.inc["gauche"].nom(), z, zp])
			k += 1
		await _attendre(1.2)
	print("BILAN %s : %d image(s) avec un cristal à moins de %.2f m de l'œil ; distance minimale %.3f m" % [sort, images_proches, PROCHE_MIN, zmin_global])

func _planche(sort: String, fichier: String) -> void:
	await _preparer(sort, "epee")
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_constant_override("outline_size", 12)
	var de := float(_arg("de", "0.45"))
	var pas_v := float(_arg("pas", "0.0667"))
	var vignettes: Array[Image] = []
	var t := 0.0
	var lance := false
	var relache := false
	var duree_appui := 1.0 if sort == "lance_givre" else 0.08
	var k := 0
	while k < 12:
		await process_frame
		t += root.get_process_delta_time()
		if not lance and t >= 0.5:
			lance = true
			_recharger()
			m.appuyer("gauche")
		if lance and not relache and t >= 0.5 + duree_appui:
			relache = true
			m.relacher("gauche")
		var z := _mesurer_proches()
		zmin_global = minf(zmin_global, z)
		var mg: Incantation = m.inc["gauche"]
		l.text = "%.2f s  %s  cristal %s" % [t, mg.nom(), ("%.2f m" % z) if z < 1e8 else "-"]
		if t >= de + pas_v * k:
			await RenderingServer.frame_post_draw
			var img := root.get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
			vignettes.append(img)
			k += 1
	var p := Image.create(480 * 4, 270 * 3, false, Image.FORMAT_RGBA8)
	for i in vignettes.size():
		p.blit_rect(vignettes[i], Rect2i(0, 0, 480, 270), Vector2i((i % 4) * 480, (i / 4) * 270))
	p.save_png(fichier)
	print("PLANCHE %s ; cristal le plus proche de l'œil : %.3f m" % [fichier, zmin_global])

func _film() -> void:
	await _preparer("eclat_glace", "epee")
	for e in [["eclat_glace", "Eclat de glace"], ["eclat_glace", "Eclat de glace"], ["lance_givre", "Lance de givre (chargee)"]]:
		if m.eq.sort("gauche") == null or m.eq.sort("gauche").resource_path.get_file().get_basename() != e[0]:
			m.equiper("gauche", e[0])
			await _attendre(0.4)
		l.text = e[1]
		await _lancer(e[0])
		await _attendre(1.3)
	m.equiper("droite", "eclat_glace")
	m.equiper("gauche", "eclat_glace")
	await _attendre(0.5)
	l.text = "Double eclat"
	_recharger()
	m.appuyer("gauche")
	m.appuyer("droite")
	await _attendre(0.08)
	m.relacher("gauche")
	m.relacher("droite")
	await _attendre(1.5)
