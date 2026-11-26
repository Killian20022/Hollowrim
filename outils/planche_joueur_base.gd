extends SceneTree
## joueur_base : planches et films du corps du joueur (homme / femme) dans le VRAI monde (scenes/foret_test.tscn : brouillard, post-process
## PS1, cycle jour/nuit), nouvelle partie, point de départ.
##   planches : godot --path . --resolution 960x540 --script res://outils/planche_joueur_base.gd -- --nouvelle --paisible --sortie=<dossier>
##              [--heure=13|23] [--sexes=homme,femme] [--familles=aucune,fer]
##              -> <sexe>_<famille>_<heure>_{face,profil,dos,tq}.png, <sexe>_<heure>_{tete,main}.png
##   film     : godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 1280x720 --script res://outils/planche_joueur_base.gd
##              -- --nouvelle --paisible --film --apparence=<sexe> [--heure=…] : caméra de jeu 3e personne, marche, course, combo d'épée,
##              ralenti du coup, puis mort (ragdoll).
const DT := 1.0 / 30.0
const ARMURES := {
	"aucune": [],
	"fer": ["casque_fer", "cuirasse_fer", "gantelets_fer", "bottes_fer"],
	"cuir": ["capuche_cuir", "armure_cuir", "gants_cuir", "bottes_cuir"],
	"acier": ["casque_acier_nordique", "cuirasse_acier_nordique", "gantelets_acier_nordique", "bottes_acier_nordique"],
	"verre": ["casque_verre", "cuirasse_verre", "gantelets_verre", "bottes_verre"],
}
var m: Node
var j: CharacterBody3D
var cam: Camera3D
var sortie := ""
var heure := 13.0
var sexes := ["homme", "femme"]
var familles := ["aucune", "fer"]
var film := false
var l: Label

func _init() -> void:
	_go.call_deferred()

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		if j != null:
			j.vigueur = j.vigueur_max
		if m != null and m.get("cycle") != null:
			m.cycle.heure = heure
		await process_frame

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
		elif a.begins_with("--heure="):
			heure = float(a.substr(8))
		elif a.begins_with("--sexes="):
			sexes = Array(a.substr(8).split(","))
		elif a.begins_with("--familles="):
			familles = Array(a.substr(11).split(","))
		elif a == "--film":
			film = true
	if sortie != "":
		DirAccess.make_dir_recursive_absolute(sortie)
	Jeu.nouvelle_partie = true
	m = (load(Jeu.SCENE_JEU) as PackedScene).instantiate()
	root.add_child(m)
	var t := 0.0
	while not m.pret and t < 200.0:
		await process_frame
		t += DT
	j = m.joueur
	m.cycle.heure = heure
	# clairière du cercle (dégagée) : rien entre la caméra et le joueur ; vrai 960x540 / 1280x720 (le projet étire un 640x360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720) if film else Vector2i(960, 540)
	var px := float(_arg("x", "3.0"))
	var pz := float(_arg("z", "-2.0"))
	j.global_position = Vector3(px, m.hauteur(px, pz) + 0.05, pz)
	j.rotation.y = deg_to_rad(float(_arg("lacet", "200")))
	j.velocity = Vector3.ZERO
	var calque := CanvasLayer.new()
	calque.layer = 90
	root.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(10, 8)
	calque.add_child(l)
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n != calque:
			(n as CanvasLayer).visible = false
	j.basculer_vue(true)
	j.mains.magie.equiper("droite", "epee")
	j.mains.magie.equiper("gauche", "torche" if heure >= 19.0 or heure < 6.0 else "vide")
	await _attendre(1.5)
	if film:
		await _film()
	else:
		await _planches()
	quit()

func _arg(n: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + n + "="):
			return a.substr(n.length() + 3)
	return d

func _equiper(f: String) -> void:
	for e in ["tete", "torse", "mains", "pieds"]:
		j.equipement_corps.retirer(e)
	for id: String in ARMURES.get(f, []):
		if Inventaire.connu(id):
			j.inventaire.ajouter(id, 1)
			var r: String = j.equipement_corps.equiper(id)
			if r != "":
				print("REFUS ", id, " : ", r)

func _os(nom: String) -> Vector3:
	var sq: Skeleton3D = j.corps.modele.find_child("Skeleton3D", true, false)
	return (sq.global_transform * sq.get_bone_global_pose(sq.find_bone(nom))).origin

func _placer(deg: float, dist: float, h: float, hc: float, cible := Vector3.INF) -> void:
	var p := j.global_position
	var devant := -j.global_transform.basis.z
	var dir := devant.rotated(Vector3.UP, deg_to_rad(deg))
	var c := (p + Vector3(0, h, 0)) if cible == Vector3.INF else cible
	cam.global_position = c + dir * dist + Vector3(0, hc - h, 0)
	cam.look_at(c, Vector3.UP)

func _capture(nom: String, texte: String) -> void:
	l.text = texte
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(sortie.path_join(nom + ".png"))
	print("CAPTURE ", nom)

func _planches() -> void:
	cam = Camera3D.new()
	cam.fov = 38.0
	m.add_child(cam)
	cam.current = true
	var hn := "nuit" if heure >= 19.0 or heure < 6.0 else "jour"
	for s: String in sexes:
		j.definir_apparence(s)
		await _attendre(0.6)
		var ht := _os("Head").y - j.global_position.y      # hauteur de la tête (homme ~1,55, femme ~1,45)
		for f: String in familles:
			_equiper(f)
			await _attendre(0.8)
			for v: Array in [["face", 0.0], ["tq", 35.0], ["profil", 90.0], ["dos", 180.0]]:
				_placer(v[1], 3.4, ht * 0.58, ht * 0.75)
				await _attendre(0.15)
				await _capture("%s_%s_%s_%s" % [s, f, hn, v[0]], "%s - %s - %s - %s" % [s, f, hn, v[0]])
		_equiper("aucune")
		await _attendre(0.5)
		_placer(15.0, 0.75, ht + 0.03, ht + 0.06)
		await _attendre(0.15)
		await _capture("%s_%s_tete" % [s, hn], "%s - tete" % s)
		_placer(160.0, 0.75, ht + 0.03, ht + 0.06)
		await _attendre(0.15)
		await _capture("%s_%s_tete_dos" % [s, hn], "%s - tete (dos)" % s)
		var mr := _os("hand_r")
		_placer(-60.0, 0.6, 0.0, 0.08, mr)
		await _attendre(0.15)
		await _capture("%s_%s_main" % [s, hn], "%s - main droite (epee)" % s)

func _appui(action: String, sec: float) -> void:
	Input.action_press(action)
	await _attendre(sec)
	Input.action_release(action)

func _film() -> void:
	var s := String(j.apparence)
	var f: String = String(familles[0]) if familles.size() > 0 else "aucune"
	_equiper(f)
	j.camera_tp.set("_orbite", 0.0)
	l.text = "%s - marche" % s
	await _attendre(0.8)
	await _appui("avant", 2.6)
	await _attendre(0.4)
	j.camera_tp.set("_orbite", deg_to_rad(150.0))
	l.text = "%s - marche (3/4 face)" % s
	await _attendre(0.6)
	await _appui("avant", 2.0)
	l.text = "%s - course" % s
	Input.action_press("course")
	await _appui("avant", 2.6)
	Input.action_release("course")
	await _attendre(0.6)
	j.camera_tp.set("_orbite", deg_to_rad(110.0))
	l.text = "%s - combo d'epee 1-2-3-4" % s
	await _attendre(0.5)
	for k in 4:
		j.mains.entrees.appuyer()
		await _attendre(0.05)
		j.mains.entrees.relacher()
		await _attendre(0.45)
	await _attendre(0.6)
	l.text = "%s - coup (ralenti x0,25)" % s
	Engine.time_scale = 0.25
	j.mains.entrees.appuyer()
	await _attendre(0.05)
	j.mains.entrees.relacher()
	await _attendre(2.2)
	Engine.time_scale = 1.0
	await _attendre(0.6)
	l.text = "%s - mort (ragdoll)" % s
	j.recevoir_coup(9999.0, j.global_position - j.global_transform.basis.z * 2.0)
	await _attendre(4.0)
