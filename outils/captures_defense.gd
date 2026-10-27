extends SceneTree
## Captures de la défense (phase 3) en vue FPS dans scenes/test_combat.tscn (FENÊTRE, via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/captures_defense.gd -- --sortie=<dossier> [--film]
## Planches : garde (repos, garde, coup bloqué, parade parfaite, garde brisée) ; parade parfaite + contre-attaque contre un
## draugr qui attaque vraiment ; finisher (décapitation) depuis le joueur.
## --film : le même enchaînement en continu pour Movie Maker (ajouter --write-movie <fichier.avi> --fixed-fps 30 avant « -- »).

const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var sortie := ""

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _monter(options: Dictionary) -> void:
	if s != null:
		s.queue_free()
		await process_frame
	s = SCENE.instantiate()
	s.options = options
	root.add_child(s)
	current_scene = s
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()

## n pas de 1/60 s : combat du joueur (pas manuel) puis le moteur (draugr, physique, rendu).
func _pas(n: int) -> void:
	for i in n:
		mains.avancer(DT * Engine.time_scale)
		await physics_frame

func _planche(nom: String, images: Array, colonnes := 0) -> void:
	var w := 320
	var h := 180
	var c := colonnes if colonnes > 0 else images.size()
	var p := Image.create(w * c, h * ceili(images.size() / float(c)), false, Image.FORMAT_RGBA8)
	for i in images.size():
		var im: Image = images[i]
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % c) * w, (i / c) * h))
	p.save_png(sortie.path_join(nom + ".png"))
	print("PLANCHE ", nom, " (", images.size(), " vues)")

## Draugr devant le joueur (à `dist` m, tourné vers lui), joueur à l'origine face à -Z.
func _draugr_devant(dist: float, actif: bool) -> CharacterBody3D:
	var d: CharacterBody3D = s.draugr
	d.global_position = Vector3(0, 0, -dist)
	d.rotation.y = 0.0
	d.vie = 400.0
	d.vie_max = 400.0
	d.combat.profil.chance_blocage = 0.0
	d.set_physics_process(actif)
	d.set_process(true)
	s.placer_joueur(Vector3.ZERO, 0.0, -6.0)
	return d

## Lève la garde juste avant l'impact de la prochaine attaque du draugr (parade parfaite) ; renvoie quand elle est parée.
func _parer(d: CharacterBody3D, avance := 0.07, images := []) -> void:
	d._recharge = 0.0
	d._changer(d.TRAQUE)
	var leve := false
	var vu_armer := false
	for i in 240:
		if d.etat == d.ATTAQUE:
			var duree: float = d._duree(d._attaque) / d._rythme
			if not vu_armer and d._t >= duree * 0.3 and images is Array and images.size() < 1 and _arg("film") == "":
				vu_armer = true
				images.append(await _image())   # le draugr arme son coup
			if not leve and d._t >= duree * 0.42 - avance:
				mains.entrees.forcer_garde(0.7)
				leve = true
		if mains.defense.nb_parades > 0:
			return
		await _pas(1)

func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/combat_defense"))
	DirAccess.make_dir_recursive_absolute(sortie)
	Sang.niveau_force = 2
	if _arg("film") != "":
		await _film()
		quit()
		return
	RetourCoups.arret_actif = false
	if _arg("poses") != "":
		await _poses()
		quit()
		return
	await _monter({"draugr": "fige", "sans-aide": ""})
	mains.pas_manuel = true
	s.mannequin.position = Vector3(-2.6, 0, -3.2)   # hors du cadre du draugr

	# --- 1. garde : repos, garde levée, coup bloqué (encaisse), parade parfaite (éclat), garde brisée
	var d := _draugr_devant(1.6, false)
	await _pas(30)
	var imgs := [await _image()]
	mains.entrees.forcer_garde(60.0)
	await _pas(25)
	imgs.append(await _image())
	j.recevoir_coup(15.0, Vector3(0, 0, -1.5))
	await _pas(4)
	imgs.append(await _image())
	await _pas(30)
	mains.entrees.forcer_garde(0.0)
	await _pas(40)
	mains.defense = DefenseJoueur.new()
	mains.entrees.forcer_garde(60.0)
	await _pas(2)
	j.recevoir_coup(15.0, Vector3(0, 0, -1.5))
	await _pas(3)
	imgs.append(await _image())
	await _pas(30)
	j.vigueur = 2.0
	j.recevoir_coup(25.0, Vector3(0, 0, -1.5))
	await _pas(10)
	imgs.append(await _image())
	j.vigueur = j.vigueur_max
	mains.entrees.forcer_garde(0.0)
	await _pas(80)
	await _planche("garde_repos_garde_bloque_parade_brisee", imgs)

	# --- 2. parade parfaite contre la vraie attaque du draugr, puis contre-attaque
	j.vie = j.vie_max
	mains.defense = DefenseJoueur.new()
	d = _draugr_devant(1.5, true)
	await _pas(20)
	imgs = []
	await _parer(d, 0.07, imgs)
	await _pas(2)
	imgs.append(await _image())          # parade : étincelles, la lame chasse l'arme
	await _pas(8)
	imgs.append(await _image())          # le draugr titube
	mains.entrees.appuyer()
	await _pas(2)
	mains.entrees.relacher()
	await _pas(5)
	imgs.append(await _image())          # contre armé
	await _pas(5)
	imgs.append(await _image())          # contre : frappe
	await _pas(8)
	imgs.append(await _image())          # contre : suivi, sang
	await _planche("parade_parfaite_contre", imgs)
	print("CONTRE : ", d.combat.dernier_resultat.get("reaction"), " posture ", d.combat.ratio_posture(), " finisher ", d.finisher_possible(j))

	# --- 3. finisher (décapitation) depuis le joueur
	await _pas(25)
	if d.finisher_possible(j) == "":
		d.combat.briser_posture()
		d._etourdir()
	d.set_physics_process(false)
	j.rotation.y = deg_to_rad(12.0)
	await _pas(5)
	imgs = [await _image()]              # cible ouverte (étourdie)
	mains.entrees.appuyer()
	await _pas(1)
	mains.entrees.relacher()
	await _pas(8)
	imgs.append(await _image())          # élan, caméra verrouillée
	await _pas(10)
	imgs.append(await _image())          # coup : impact
	await _pas(4)
	imgs.append(await _image())          # la tête part, jet de sang
	await _pas(14)
	imgs.append(await _image())          # suivi
	await _pas(40)
	imgs.append(await _image())          # après
	await _planche("finisher_decapitation", imgs)
	print("FINISHER : ", mains.dernier_finisher)

## Film continu (Movie Maker, --fixed-fps 30) : garde et blocage, parade parfaite, contre-attaque, finisher.
func _film() -> void:
	RetourCoups.arret_actif = true
	await _monter({"draugr": "fige", "sans-aide": ""})
	mains.pas_manuel = true
	s.mannequin.position = Vector3(-2.6, 0, -3.2)
	var d := _draugr_devant(1.5, false)
	await _pas(45)
	# garde levée, deux coups bloqués
	mains.entrees.forcer_garde(60.0)
	await _pas(30)
	for k in 2:
		j.recevoir_coup(12.0, Vector3(0, 0, -1.5))
		await _pas(30)
	mains.entrees.forcer_garde(0.0)
	await _pas(30)
	# parade parfaite contre la vraie attaque, contre-attaque, finisher
	mains.defense = DefenseJoueur.new()
	d.set_physics_process(true)
	await _parer(d, 0.07)
	await _pas(10)
	mains.entrees.appuyer()
	await _pas(2)
	mains.entrees.relacher()
	await _pas(40)
	if d.finisher_possible(j) == "":
		d.combat.briser_posture()
		d._etourdir()
	d.set_physics_process(false)
	await _pas(20)
	mains.entrees.appuyer()
	await _pas(1)
	mains.entrees.relacher()
	await _pas(150)

## Réglage des poses (sans ennemi) : garde, encaisse, parade, garde brisée, puis contre (armé, milieu, fin) et finisher de
## taille (élan, milieu, fin) figés dans le vrai état de combat (coude et poignet compris).
func _poses() -> void:
	await _monter({"draugr": "aucun", "sans-aide": ""})
	mains.pas_manuel = true
	s.mannequin.position = Vector3(0, 0, -1.6)
	s.placer_joueur(Vector3.ZERO, 0.0, -6.0)
	await _pas(20)
	var imgs := []
	mains.entrees.forcer_garde(60.0)
	await _pas(25)
	imgs.append(await _image())
	mains._encaisse = 0.18
	await _pas(3)
	imgs.append(await _image())
	mains._parade_eclat = 0.14
	await _pas(3)
	imgs.append(await _image())
	j.vigueur = 1.0
	j.recevoir_coup(30.0, Vector3(0, 0, -1.5))
	await _pas(9)
	imgs.append(await _image())
	j.vigueur = j.vigueur_max
	mains.entrees.forcer_garde(0.0)
	await _pas(90)
	# contre-attaque figée : fin de la préparation (armé), milieu de la frappe, fin
	for etape in [0.085, 0.15, 0.21]:
		mains.combat.forcer(EtatCombat.REPOS)
		mains._pose_courante = mains._pose_repos()
		await _pas(30)
		mains.defense.contre = 0.6
		mains.entrees.appuyer()
		await _pas(1)
		mains.entrees.relacher()
		while mains._t_geste < etape and mains.combat.etat == EtatCombat.CONTRE:
			mains.avancer(1.0 / 240.0)
		await process_frame
		imgs.append(await _image())
	# finisher de taille figé : élan, milieu du coup, fin
	for etape in [0.25, 0.32, 0.375]:
		mains.combat.forcer(EtatCombat.REPOS)
		mains._pose_courante = mains._pose_repos()
		await _pas(30)
		s.mannequin.combat.briser_posture()
		s.mannequin.tete.visible = true
		mains.entrees.appuyer()
		await _pas(1)
		mains.entrees.relacher()
		while mains._fin_t < etape and mains.combat.etat == EtatCombat.FINISHER:
			mains.avancer(1.0 / 240.0)
		await process_frame
		imgs.append(await _image())
		await _pas(60)
	await _planche("poses_defense", imgs, 5)
