extends SceneTree
## Arme à DEUX MAINS (branche combat/claymore_2mains) : planche des poses clés et film en vue de jeu.
## FENÊTRE (via godot_slot.sh : hors écran) :
##   poses : godot --path . --resolution 960x540 --script res://outils/film_claymore.gd -- --nouvelle --poses --sortie=<dossier>
##           [--arme=claymore|coeur_de_braise] → <dossier>/pose_NN_<nom>.png + planche_poses.png (grille 4 colonnes)
##   film  : godot --path . --write-movie <f.avi> --fixed-fps 60 --resolution 960x540 --script res://outils/film_claymore.gd --
##           --nouvelle --film [--armes=claymore,coeur_de_braise]
##           garde (repos, marche), combo 1-2-3, blocage à deux mains contre 2 draugrs actifs, puissante chargée ; puis la
##           même séquence (sans blocage) avec la 2e arme.
const DT := 1.0 / 60.0
const POSES := [
	["repos_2m:0.0", "garde de repos (penchée à droite)"], ["garde_2m:0.0", "blocage à deux mains"],
	["c2_a:0.30", "1 diagonale : armé"], ["c2_a:0.50", "1 diagonale : arc"], ["c2_a:0.60", "1 diagonale : arc"], ["c2_a:0.80", "1 diagonale : suivi bas"],
	["c2_b:0.20", "2 retour : départ"], ["c2_b:0.42", "2 retour : arc"], ["c2_b:0.52", "2 retour : arc"], ["c2_b:0.70", "2 retour : fin haute"],
	["c2_c:0.40", "3 vertical : armé"], ["c2_c:0.60", "3 vertical : arc"], ["c2_c:0.70", "3 vertical : arc"], ["c2_c:0.88", "3 vertical : aux pieds"],
	["charge_2m:0.70", "puissante : charge tenue"], ["lourd_2m:0.30", "puissante : arc"],
]

var s: Node
var j: CharacterBody3D
var mains: Node3D
var l: Label

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		await process_frame

func _etiquette(parent: Node) -> void:
	var calque := CanvasLayer.new()
	calque.layer = 60
	parent.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(10, 300)
	calque.add_child(l)

func _texte(t: String) -> void:
	l.text = t
	print("ETAPE ", t)

func _equiper(id: String) -> void:
	mains.equipement.equiper("droite", load("res://data/armes/%s.tres" % id))
	await _attendre(0.8)

func _go() -> void:
	RetourImpact.muet = false
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _attendre(0.7)
	_etiquette(s)
	if _arg("poses") != "":
		await _poses()
	else:
		await _film()
	quit(0)

func _poses() -> void:
	var dossier := _arg("sortie", "res://captures/claymore")
	DirAccess.make_dir_recursive_absolute(dossier)
	await _equiper(_arg("arme", "claymore"))
	s.placer_joueur(Vector3(0, 0, 4.0), 0.0, -4.0)
	var vues: Array = ["jeu", "cote"] if _arg("vue") == "les_deux" else [_arg("vue", "jeu")]
	var cam_jeu := root.get_viewport().get_camera_3d()
	for vue in vues:
		var cam: Camera3D = null
		if vue == "cote":
			# contrôle de la prise : caméra de côté (à droite, un peu au-dessus), qui regarde les mains
			cam = Camera3D.new()
			mains.add_child(cam)
			cam.position = Vector3(0.95, 0.05, -0.30)
			cam.look_at_from_position(cam.global_position, mains.to_global(Vector3(0.0, -0.15, -0.50)), Vector3.UP)
			cam.fov = 70.0
			cam.make_current()
		var imgs: Array[Image] = []
		for i in POSES.size():
			mains._pose_figee = String(POSES[i][0])
			_texte("%s  (%s)" % [POSES[i][1], POSES[i][0]])
			await _attendre(0.25)
			var img := root.get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.save_png(dossier.path_join("%s_pose_%02d_%s.png" % [vue, i, String(POSES[i][0]).replace(":", "_")]))
			imgs.append(img)
		mains._pose_figee = ""
		var w := imgs[0].get_width() / 2
		var h := imgs[0].get_height() / 2
		var col := 4
		var planche := Image.create(w * col, h * ceili(imgs.size() / float(col)), false, Image.FORMAT_RGBA8)
		for i in imgs.size():
			var im := imgs[i]
			im.resize(w, h, Image.INTERPOLATE_BILINEAR)
			planche.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % col) * w, (i / col) * h))
		planche.save_png(dossier.path_join("planche_poses_%s.png" % vue))
		print("PLANCHE ", dossier.path_join("planche_poses_%s.png" % vue))
		if cam != null:
			cam.queue_free()
			cam_jeu.make_current()
	if _arg("planche_lame") != "":
		await _planche_lame(dossier)

## Planches de la lame : (1) ancienne n°05 / nouvelle claymore longue, à la même échelle ; (2) gros plan de la nouvelle, avant /
## après les matériaux réalistes (EpeesLongues seul / ClaymoreMateriaux), même lumière.
func _planche_lame(dossier: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 270)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#3a3d44")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a90a0")
	env.ambient_light_energy = 0.5
	we.environment = env
	vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-30, -35, 0)
	sol.light_energy = 1.3
	vp.add_child(sol)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.95
	cam.position = Vector3(0, 0.62, 3)
	vp.add_child(cam)
	var vieille: Node3D = load("res://assets/modeles/armes/deux_mains/claymore.glb").instantiate()
	EpeesLongues.habiller(vieille)
	var neuve: Node3D = load("res://assets/modeles/armes/deux_mains/claymore_longue.glb").instantiate()
	ClaymoreMateriaux.habiller(neuve)
	var avant: Node3D = load("res://assets/modeles/armes/deux_mains/claymore_longue.glb").instantiate()
	EpeesLongues.habiller(avant)
	for n: Node3D in [vieille, neuve, avant]:
		vp.add_child(n)
	# (1) ancienne / nouvelle, couchées en biais pour tenir dans le cadre 16:9 : face puis trois quarts
	avant.visible = false
	var planche := Image.create(480 * 2 * 2, 270 * 2, false, Image.FORMAT_RGBA8)
	for k in 2:
		vieille.position = Vector3(-0.32, 0.12, 0)
		neuve.position = Vector3(0.32, -0.08, 0)
		for n: Node3D in [vieille, neuve]:
			n.rotation = Vector3(0, 0, 0) if k == 0 else Vector3(deg_to_rad(-12), deg_to_rad(40), deg_to_rad(-6))
		await _attendre(0.15)
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(480 * 2, 270 * 2, Image.INTERPOLATE_NEAREST)
		planche.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(480 * 2 * k, 0))
	planche.save_png(dossier.path_join("planche_lame_ancienne_n05_vs_longue.png"))
	print("PLANCHE ", dossier.path_join("planche_lame_ancienne_n05_vs_longue.png"))
	# (2) gros plan : garde, talon gainé, crochets, début de la lame ; avant (gauche) / après (droite)
	vieille.visible = false
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 40.0
	var gros := Image.create(480 * 2 * 2, 270 * 2, false, Image.FORMAT_RGBA8)
	for k in 2:
		neuve.visible = k == 1
		avant.visible = k == 0
		for n: Node3D in [neuve, avant]:
			n.position = Vector3.ZERO
			n.rotation = Vector3(deg_to_rad(-10), deg_to_rad(30), deg_to_rad(-75))
		cam.position = Vector3(0.05, 0.10, 0.62)
		cam.look_at(Vector3(0.12, 0.03, 0.0))
		await _attendre(0.15)
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(480 * 2, 270 * 2, Image.INTERPOLATE_NEAREST)
		gros.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(480 * 2 * k, 0))
	gros.save_png(dossier.path_join("planche_claymore_de_pres_avant_apres_realisme.png"))
	print("PLANCHE ", dossier.path_join("planche_claymore_de_pres_avant_apres_realisme.png"))
	vp.queue_free()

func _clic(maintien := 0.05) -> void:
	mains.entrees.appuyer()
	await _attendre(maintien)
	mains.entrees.relacher()

func _film() -> void:
	var armes := _arg("armes", "claymore,coeur_de_braise").split(",")
	print("DEBUT_SEQUENCE %.3f" % (Engine.get_process_frames() / 60.0))
	for n in armes.size():
		var id := armes[n]
		s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -4.0)
		await _equiper(id)
		var nom: String = mains.arme.nom
		mains.combat.forcer(EtatCombat.REPOS)
		j.vigueur = j.vigueur_max
		_texte("%s : garde à deux mains" % nom)
		await _attendre(1.6)
		# deux draugrs devant, actifs
		var d1: Node = s.creer_draugr(Vector3(-0.9, 0, 3.0), n > 0)
		var d2: Node = s.creer_draugr(Vector3(0.9, 0, 3.3), n > 0)
		for d in [d1, d2]:
			d.look_at(j.global_position, Vector3.UP, true)
		await _attendre(0.3)
		_texte("%s : combo 1 diagonale, 2 horizontal, 3 vertical" % nom)
		mains._combo = 0
		for k in 3:
			await _clic()
			await _attendre(0.78)
		await _attendre(0.9)
		if n == 0:
			_texte("%s : blocage à deux mains (clic droit)" % nom)
			mains.entrees.forcer_garde(2.8)   # garde tenue (= clic droit maintenu) pendant que les draugrs frappent
			await _attendre(3.2)
		j.vigueur = j.vigueur_max
		_texte("%s : coup puissant (maintenu)" % nom)
		mains.entrees.appuyer()
		await _attendre(0.95)
		mains.entrees.relacher()
		await _attendre(1.6)
		_texte("%s : combo" % nom)
		for k in 3:
			await _clic()
			await _attendre(0.78)
		await _attendre(1.2)
		for d in [d1, d2]:
			if is_instance_valid(d):
				d.queue_free()
		await _attendre(0.2)
	print("FIN_SEQUENCE")
