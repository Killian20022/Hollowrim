extends SceneTree
## Captures du combat à l'épée dans scenes/test_combat.tscn (FENÊTRE, via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/captures_combat_epee.gd -- --sortie=<dossier> [--film]
## Planches (une image par séquence, vignettes côte à côte) : coups légers enchaînés, coup lourd chargé, rebond sur le
## mur avec le tracé de lame, marche / sprint / saut (animations passives), repos jour et nuit.
## --film : scénario joué en continu pour Movie Maker (ajouter --write-movie <fichier.avi> --fixed-fps 30 avant « -- ») :
## combo sur le mannequin, coup lourd, puis combat contre le draugr.

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
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()

## Maintient des actions de déplacement pendant n images (réappuyées à chaque image : une fenêtre hors écran sans
## focus relâche les actions pressées par script).
func _tenir(actions: Array, n: int) -> void:
	for i in n:
		for a in ["avant", "course", "saut"]:
			if a in actions:
				Input.action_press(a)
			else:
				Input.action_release(a)
		await physics_frame
	await process_frame

## Avance le combat à pas fixe (pas_manuel) puis laisse le moteur poser l'IK et rendre.
func _pas(duree: float) -> void:
	for i in roundi(duree / DT):
		mains.avancer(DT)
	await process_frame
	await process_frame

func _planche(nom: String, images: Array) -> void:
	var w := 320
	var h := 180
	var p := Image.create(w * images.size(), h, false, Image.FORMAT_RGBA8)
	for i in images.size():
		var im: Image = images[i]
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	p.save_png(sortie.path_join(nom + ".png"))
	print("PLANCHE ", nom, " (", images.size(), " vues)")

func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/combat_epee"))
	DirAccess.make_dir_recursive_absolute(sortie)
	RetourCoups.arret_actif = false
	if _arg("film") != "":
		await _film()
		quit()
		return
	await _monter({"draugr": "fige", "sans-aide": ""})
	mains.pas_manuel = true
	# --- repos (scène de test, jour)
	s.placer_joueur(Vector3.ZERO, 0.0)
	await _pas(0.5)
	var repos := await _image()
	repos.save_png(sortie.path_join("repos_scene_jour.png"))
	# --- combo de coups légers : préparation, phase active, fin, pour chacun des trois gestes
	var imgs := []
	for c in 3:
		mains.entrees.appuyer()
		await _pas(0.05)
		mains.entrees.relacher()
		await _pas(0.05)
		imgs.append(await _image())      # armé
		await _pas(0.10)
		imgs.append(await _image())      # milieu de la phase active
		await _pas(0.12)
		imgs.append(await _image())      # fin / récupération
		await _pas(0.15)
	await _planche("coups_legers_combo", imgs)
	await _pas(0.8)
	# --- directions selon le contexte (phase 4) : en avançant, pas à droite, pas à gauche, en reculant (armé, milieu)
	imgs = []
	for v in [Vector3(0, 0, -3.2), Vector3(3.2, 0, 0), Vector3(-3.2, 0, 0), Vector3(0, 0, 2.5)]:
		await _pas(0.6)
		j.velocity = v
		mains.entrees.appuyer()
		mains.avancer(DT)
		mains.entrees.relacher()
		await _pas(0.10)
		imgs.append(await _image())
		await _pas(0.09)
		imgs.append(await _image())
		j.velocity = Vector3.ZERO
		await _pas(0.4)
	await _planche("directions_avant_droite_gauche_recul", imgs)
	# --- coup lourd : charge, pleine charge, frappe, fin
	imgs = []
	mains.entrees.appuyer()
	await _pas(0.45)
	imgs.append(await _image())
	await _pas(1.0)
	imgs.append(await _image())          # pleine charge (tremblement, reflet)
	mains.entrees.relacher()
	await _pas(0.15)
	imgs.append(await _image())
	await _pas(0.10)
	imgs.append(await _image())
	await _pas(0.25)
	imgs.append(await _image())
	await _planche("coup_lourd", imgs)
	await _pas(0.8)
	# --- mur : rebond, avec le tracé de lame affiché (débogage)
	mains.basculer_debogage(true)
	s.placer_joueur(Vector3(-1.9, 0, 1.0), 90.0)
	await _pas(0.4)
	imgs = []
	mains.entrees.appuyer()
	await _pas(0.05)
	mains.entrees.relacher()
	await _pas(0.12)
	imgs.append(await _image())
	await _pas(0.05)
	imgs.append(await _image())
	await _pas(0.12)
	imgs.append(await _image())
	await _planche("mur_rebond_trace", imgs)
	# tracé sur le mannequin, vu de côté par une caméra de débogage
	s.placer_joueur(Vector3.ZERO, 0.0)
	await _pas(0.6)
	mains.entrees.appuyer()
	await _pas(0.05)
	mains.entrees.relacher()
	await _pas(0.5)
	var c := Camera3D.new()
	s.add_child(c)
	c.global_position = Vector3(2.6, 1.9, -0.4)
	c.look_at(Vector3(0, 1.3, -1.2))
	c.current = true
	await _pas(0.02)
	(await _image()).save_png(sortie.path_join("trace_lame_cote.png"))
	c.queue_free()
	j.camera.current = true
	mains.basculer_debogage(false)
	# --- animations passives : repos, marche, sprint, saut (vrai déplacement du joueur, temps réel)
	mains.pas_manuel = false
	s.placer_joueur(Vector3(0, 0, 2.0), 180.0)   # face à +Z : terrain dégagé
	imgs = []
	for i in 20:
		await process_frame
	imgs.append(await _image())
	await _tenir(["avant"], 40)
	imgs.append(await _image())          # marche
	await _tenir(["avant"], 9)
	imgs.append(await _image())          # marche, autre phase du pas
	await _tenir(["avant", "course"], 50)
	imgs.append(await _image())          # sprint : épée abaissée, torche stabilisée
	await _tenir(["avant", "course"], 7)
	imgs.append(await _image())
	await _tenir([], 6)
	imgs.append(await _image())          # arrêt brutal : léger retour des bras
	await _tenir(["saut"], 2)
	await _tenir([], 5)
	imgs.append(await _image())          # impulsion du saut
	for i in 60:
		await _tenir([], 1)
		if j.is_on_floor():
			break
	await _tenir([], 3)
	imgs.append(await _image())          # atterrissage
	await _planche("passifs_repos_marche_sprint_saut", imgs)
	# --- nuit
	await _monter({"draugr": "fige", "sans-aide": "", "nuit": ""})
	s.placer_joueur(Vector3.ZERO, 0.0)
	for i in 30:
		await process_frame
	(await _image()).save_png(sortie.path_join("repos_scene_nuit.png"))
	quit()

## Scénario continu pour Movie Maker (30 i/s imposés par --fixed-fps) : mannequin puis draugr actif.
func _film() -> void:
	RetourCoups.arret_actif = true
	await _monter({"draugr": "aucun", "sans-aide": ""})
	s.placer_joueur(Vector3(0, 0, 0.3), 0.0)
	for i in 30:
		await process_frame
	for c in 3:
		mains.attaquer(false)
		await create_timer(0.42).timeout
	await create_timer(0.6).timeout
	mains.entrees.appuyer()
	await create_timer(1.3).timeout
	mains.entrees.relacher()
	await create_timer(1.2).timeout
	# draugr : il arrive, on frappe, on pare, on frappe
	var d: CharacterBody3D = s.creer_draugr(Vector3(0.6, 0, -5.0), false)
	s.mannequin.position = Vector3(-2.2, 0, -1.5)
	for i in 420:
		await process_frame
		var vers := d.global_position - j.global_position
		vers.y = 0.0
		j.rotation.y = lerp_angle(j.rotation.y, atan2(-vers.x, -vers.z), 0.15)
		if d.vivant() and vers.length() < 2.5:
			if d.etat == d.ATTAQUE and not mains.combat.attaque():
				mains.entrees.forcer_garde(0.4)
			elif i % 18 == 0:
				mains.attaquer(i % 72 == 0)
		if not d.vivant() and i > 60:
			break
	await create_timer(2.0).timeout
