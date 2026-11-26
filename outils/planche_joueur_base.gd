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
var mode_mains := false
var mode_dos_jeu := false
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
		elif a == "--mains":
			mode_mains = true
		elif a == "--dos-jeu":
			mode_dos_jeu = true
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
	var ips := root.get_node_or_null("CompteurIps")     # compteur d'IPS (option du joueur) : il se ré-affiche tout seul sinon
	if ips != null:
		ips.process_mode = Node.PROCESS_MODE_DISABLED
		ips.visible = false
	j.basculer_vue(true)
	j.mains.magie.equiper("droite", "epee")
	j.mains.magie.equiper("gauche", "torche" if heure >= 19.0 or heure < 6.0 else "vide")
	await _attendre(1.5)
	if film:
		await _film()
	elif mode_mains:
		await _mains_v3()
	elif mode_dos_jeu:
		await _dos_jeu()
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

## Centre du poing `c` ("l" | "r") dans le monde (JoueurBase.prise, sinon l'os de la main).
func _poing(c: String) -> Vector3:
	var sq: Skeleton3D = j.corps.modele.find_child("Skeleton3D", true, false)
	var i := sq.find_bone("hand_" + c)
	var g := sq.global_transform * sq.get_bone_global_pose(i)
	if sq.has_meta("prise_" + c):
		var t: Transform3D = sq.get_meta("prise_" + c)
		return g * (t * Vector3(0, JoueurBase.POING_ARME if c == "r" else 0.0, 0))
	return g.origin

## Gros plans v3 (passe 3) : tête face / dos ; poing droit (épée) et gauche (torche, bouclier, arc, sort) au repos, en garde, au
## milieu d'un coup et en course, deux angles chacun. Pose lue à l'instant de la capture (skeleton_updated).
func _mains_v3() -> void:
	cam = Camera3D.new()
	cam.fov = 38.0
	m.add_child(cam)
	cam.current = true
	var hn := "nuit" if heure >= 19.0 or heure < 6.0 else "jour"
	for s: String in sexes:
		j.definir_apparence(s)
		_equiper("aucune")
		j.mains.magie.equiper("droite", "epee")
		j.mains.magie.equiper("gauche", "torche")
		await _attendre(1.0)
		var ht := _os("Head").y - j.global_position.y
		_placer(0.0, 0.7, ht + 0.03, ht + 0.06)
		await _attendre(0.15)
		await _capture("%s_%s_v3_tete_face" % [s, hn], "%s - tete (face)" % s)
		_placer(180.0, 0.7, ht + 0.03, ht + 0.06)
		await _attendre(0.15)
		await _capture("%s_%s_v3_tete_dos" % [s, hn], "%s - tete (dos)" % s)
		for etat: String in ["repos", "garde", "coup", "course"]:
			if etat == "garde":
				j.mains.entrees.forcer_garde(3.0)
				await _attendre(0.6)
			elif etat == "coup":
				j.mains.entrees.forcer_garde(0.0)
				await _attendre(0.5)
				j.mains.entrees.appuyer()
				await _attendre(0.05)
				j.mains.entrees.relacher()
				await _attendre(0.28)
			elif etat == "course":
				Input.action_press("course")
				Input.action_press("avant")
				await _attendre(0.9)
			else:
				await _attendre(0.4)
			var lent := Engine.time_scale
			Engine.time_scale = 0.0001 if etat in ["coup", "course"] else 1.0    # image figée pendant les trois prises de vue
			for v: Array in [["r", -55.0, 0.05], ["r", 125.0, 0.12], ["l", 60.0, 0.05]]:
				var cible := _poing(v[0])
				_placer(v[1], 0.55, 0.0, v[2], cible)
				await process_frame
				await _capture("%s_%s_v3_main_%s_%s_%d" % [s, hn, etat, v[0], int(v[1])], "%s - %s - main %s (%s)" % [s, etat, "droite epee" if v[0] == "r" else "gauche torche", etat])
			Engine.time_scale = lent
			if etat == "course":
				Input.action_release("avant")
				Input.action_release("course")
				await _attendre(0.8)
				j.global_position = Vector3(3.0, m.hauteur(3.0, -2.0) + 0.05, -2.0)
				j.velocity = Vector3.ZERO
		# autres objets tenus : bouclier, sort, arc (poing gauche)
		for g: Array in [["bouclier", "droite", "epee", "gauche", "bouclier"], ["sort", "droite", "epee", "gauche", "boule_feu"], ["arc", "droite", "arc_chasseur", "gauche", ""]]:
			j.mains.magie.equiper(g[1], g[2])
			j.mains.magie.equiper(g[3], g[4])
			await _attendre(1.2)
			for v: Array in [["l", 60.0, 0.05], ["l", -120.0, 0.1]]:
				_placer(v[1], 0.6, 0.0, v[2], _poing(v[0]))
				await process_frame
				await _capture("%s_%s_v3_main_%s_%s_%d" % [s, hn, g[0], v[0], int(v[1])], "%s - %s (main gauche)" % [s, g[0]])
		j.mains.magie.equiper("droite", "epee")
		j.mains.magie.equiper("gauche", "torche")

## Planche de dos à la vraie caméra de jeu (3e personne, ~3 m, épaule) : repos, marche, avec et sans armure.
func _dos_jeu() -> void:
	var hn := "nuit" if heure >= 19.0 or heure < 6.0 else "jour"
	for s: String in sexes:
		j.definir_apparence(s)
		for f: String in familles:
			_equiper(f)
			j.camera_tp.set("_orbite", 0.0)
			j.camera_tp.recaler()
			await _attendre(1.0)
			await _capture("%s_%s_%s_jeu_dos" % [s, f, hn], "%s - %s - %s - camera de jeu (dos)" % [s, f, hn])
			j.camera_tp.set("_orbite", deg_to_rad(25.0))
			await _attendre(0.5)
			await _capture("%s_%s_%s_jeu_dos25" % [s, f, hn], "%s - %s - %s - camera de jeu (dos, 25 deg)" % [s, f, hn])

func _appui(action: String, sec: float) -> void:
	Input.action_press(action)
	await _attendre(sec)
	Input.action_release(action)

## Pose le joueur dans la clairière du feu (rayon ~11 m sans arbre, feu en 0,0) : x, z, cap en degrés (0 = vers -Z, -90 = vers +X).
func _depart(x: float, z: float, cap: float, orbite: float) -> void:
	j.global_position = Vector3(x, m.hauteur(x, z) + 0.05, z)
	j.rotation.y = deg_to_rad(cap)
	j.velocity = Vector3.ZERO
	j.camera_tp.set("_orbite", deg_to_rad(orbite))
	j.camera_tp.recaler()
	await _attendre(0.5)

## Film v2 : chaque séquence repart d'un point de la clairière, vers l'est, la caméra du côté du centre (aucun arbre entre elle et le corps).
func _film() -> void:
	var s := String(j.apparence)
	var f: String = String(familles[0]) if familles.size() > 0 else "aucune"
	_equiper(f)
	l.text = "%s - repos (garde)" % s
	await _depart(-2.5, 4.0, -90.0, 250.0)
	await _attendre(1.6)
	l.text = "%s - marche" % s
	await _depart(-5.0, 4.0, -90.0, 0.0)
	await _appui("avant", 2.6)
	await _attendre(0.4)
	l.text = "%s - marche (3/4 face)" % s
	await _depart(-4.0, -4.5, -90.0, 150.0)
	await _appui("avant", 2.2)
	l.text = "%s - course" % s
	await _depart(-8.0, 5.5, -90.0, 270.0)
	Input.action_press("course")
	await _appui("avant", 2.0)
	Input.action_release("course")
	await _attendre(0.6)
	l.text = "%s - combo d'epee 1-2-3-4" % s
	await _depart(3.0, 3.0, 200.0, 110.0)
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
