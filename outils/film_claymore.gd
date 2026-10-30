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
	["repos_2m:0.0", "garde de repos"], ["sprint_2m:0.0", "course"], ["garde_2m:0.0", "blocage à deux mains"],
	["encaisse_2m:0.06", "coup encaissé"],
	["c2_a:0.30", "1 diagonale : armé"], ["c2_a:0.46", "1 diagonale : frappe"], ["c2_a:0.58", "1 diagonale : fin"],
	["c2_b:0.24", "2 horizontal : armé"], ["c2_b:0.38", "2 horizontal : frappe"], ["c2_b:0.50", "2 horizontal : fin"],
	["c2_c:0.40", "3 vertical : armé"], ["c2_c:0.53", "3 vertical : frappe"],
	["charge_2m:0.70", "puissante : charge tenue"], ["lourd_2m:0.18", "puissante : frappe"], ["lourd_2m:0.30", "puissante : fin"],
	["c2_c:0.70", "3 vertical : suivi"],
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
	var imgs: Array[Image] = []
	if _arg("vue") == "cote":
		# contrôle de la prise : caméra de côté (à droite, un peu au-dessus), qui regarde les mains
		var cam := Camera3D.new()
		mains.add_child(cam)
		cam.position = Vector3(0.75, 0.15, -0.35)
		cam.look_at_from_position(cam.global_position, mains.to_global(Vector3(0.05, -0.25, -0.45)), Vector3.UP)
		cam.fov = 60.0
		cam.make_current()
	for i in POSES.size():
		mains._pose_figee = String(POSES[i][0])
		_texte("%s  (%s)" % [POSES[i][1], POSES[i][0]])
		await _attendre(0.25)
		var piv: Node3D = mains.pivot_torche
		print("DEBUG %s cible_g=%s main_g=%s main_d=%s epee=%s" % [POSES[i][0], mains.to_local(piv.global_position), mains.to_local(mains._accroche_g.global_position), mains.to_local(mains._accroche_d.global_position), mains.pivot_epee.position])
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(dossier.path_join("pose_%02d_%s.png" % [i, String(POSES[i][0]).replace(":", "_")]))
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
	planche.save_png(dossier.path_join("planche_poses.png"))
	print("PLANCHE ", dossier.path_join("planche_poses.png"))

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
