extends SceneTree
## Film de la caméra « corps » (CameraCorps, MouvementsPassifs) dans scenes/test_combat.tscn, pour Movie Maker :
##   godot --path . --write-movie <fichier.avi> --fixed-fps 30 --script res://outils/captures_camera_corps.gd -- --nouvelle
## (fenêtre hors écran via godot_slot.sh). Séquences enchaînées, chacune annoncée par une ligne
##   SEGMENT <nom> <première image> <dernière image>
## (images du film) pour la découpe : marche, sprint, virages souris, saut / atterrissages (sur place, 2 m, 4 m), combat
## (mannequin : coups légers et lourd ; draugr actif : impacts, coups reçus, garde).
## Options au défaut (100 %) sauf --tete=, --arme=, --secousses= (0..1) ou --reduit ; rien n'est écrit dans options.cfg.

const SCENE := preload("res://scenes/test_combat.tscn")

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var _titre: Label
var _debut := 0
## Mesures du segment en cours (caméra et bras réels, à chaque image) : max |position| (m), |rotation| (rad), décalage.
var _mes := {}

func _process(_dt: float) -> bool:
	if j != null and not _mes.is_empty():
		var c: Camera3D = j.camera
		_mes["tete_y"] = maxf(_mes["tete_y"], absf(c.position.y))
		_mes["tete_x"] = maxf(_mes["tete_x"], absf(c.position.x))
		_mes["tangage"] = maxf(_mes["tangage"], absf(c.rotation.x))
		_mes["lacet"] = maxf(_mes["lacet"], absf(c.rotation.y))
		_mes["roulis"] = maxf(_mes["roulis"], absf(c.rotation.z))
		_mes["decalage"] = maxf(_mes["decalage"], Vector2(c.h_offset, c.v_offset).length())
		_mes["bras"] = maxf(_mes["bras"], mains.passifs.decalage_d.origin.length())
		_mes["bras_rot"] = maxf(_mes["bras_rot"], mains.passifs.rot_affichee.length())
	return false

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _image() -> int:
	return Engine.get_frames_drawn()

func _segment(nom: String, texte: String) -> void:
	_debut = _image()
	_titre.text = texte
	_mes = {"tete_y": 0.0, "tete_x": 0.0, "tangage": 0.0, "lacet": 0.0, "roulis": 0.0, "decalage": 0.0, "bras": 0.0, "bras_rot": 0.0}
	print("DEBUT %s %d" % [nom, _debut])

func _fin(nom: String) -> void:
	print("SEGMENT %s %d %d" % [nom, _debut, _image()])
	print("MESURE %s : tête y %.2f cm, x %.2f cm, tangage %.2f°, lacet %.2f°, roulis %.2f°, secousse %.2f cm ; bras %.2f cm, inertie %.2f°" % [nom,
		_mes["tete_y"] * 100.0, _mes["tete_x"] * 100.0, rad_to_deg(_mes["tangage"]), rad_to_deg(_mes["lacet"]), rad_to_deg(_mes["roulis"]),
		_mes["decalage"] * 100.0, _mes["bras"] * 100.0, rad_to_deg(_mes["bras_rot"])])
	_mes = {}

## Maintient des actions pendant n ticks de physique (réappuyées : la fenêtre hors écran n'a pas le focus).
func _tenir(actions: Array, n: int, souris_px := 0.0) -> void:
	for i in n:
		for a in ["avant", "course", "saut", "gauche", "droite"]:
			if a in actions:
				Input.action_press(a)
			else:
				Input.action_release(a)
		if souris_px != 0.0:
			_souris(Vector2(souris_px, 0.0))
		await physics_frame
	for a in ["avant", "course", "saut", "gauche", "droite"]:
		Input.action_release(a)

## Comme joueur._unhandled_input + mains._unhandled_input pour un mouvement de souris (pixels d'écran).
func _souris(d: Vector2) -> void:
	var k := 0.0022 * Jeu.sensibilite
	j.rotate_y(-d.x * k)
	j.tete.rotation.x = clampf(j.tete.rotation.x - d.y * k, -1.45, 1.45)
	mains.passifs.souris(d * Jeu.sensibilite)
	mains.noter_souris(d)

func _attendre(n: int) -> void:
	for i in n:
		await physics_frame

## --options=<dossier> : captures du panneau Options (thème pixel du menu pause), grille principale puis sous-panneau
## « Caméra » (rien n'est enregistré : aucun curseur n'est touché).
func _options(dossier: String) -> void:
	var m := PanelContainer.new()
	m.set_script(preload("res://scripts/menu_options.gd"))
	var fond := ColorRect.new()
	fond.color = Color(0.1, 0.11, 0.14)
	fond.size = Vector2(640, 360)
	root.add_child(fond)
	root.add_child(m)
	for i in 10:
		await process_frame
		m.position = ((Vector2(640, 360) - m.size) * 0.5).floor()
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(dossier.path_join("options_grille.png"))
	m.call("_basculer_camera")
	for i in 5:
		await process_frame
		m.reset_size()
		m.position = ((Vector2(640, 360) - m.size) * 0.5).floor()
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(dossier.path_join("options_camera.png"))
	quit()

func _go() -> void:
	if _arg("options") != "":
		await _options(_arg("options"))
		return
	# options en mémoire seulement
	Jeu.option("affichage", "reduire_mouvements")
	Jeu.options["affichage"]["balancement_arme"] = float(_arg("arme", "1"))
	Jeu.options["affichage"]["mouvement_tete"] = float(_arg("tete", "1"))
	Jeu.options["affichage"]["secousses"] = float(_arg("secousses", "1"))
	Jeu.options["affichage"]["reduire_mouvements"] = _arg("reduit") != ""
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var calque := CanvasLayer.new()
	calque.layer = 70
	s.add_child(calque)
	_titre = Label.new()
	_titre.add_theme_font_override("font", Palette.police())
	_titre.add_theme_font_size_override("font_size", Palette.TAILLE_POLICE)
	_titre.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_titre.position = Vector2(6, 4)
	calque.add_child(_titre)
	var f := CameraCorps.facteurs()
	var reglages := "  [arme %d %% · tête %d %% · secousses %d %%]" % [roundi(f["arme"] * 100), roundi(f["tete"] * 100), roundi(f["secousses"] * 100)]
	for i in 40:
		await process_frame
	var p := 60   # ticks de physique par seconde (défaut du projet)

	# 1. marche (et repos au départ)
	s.placer_joueur(Vector3(6, 0, -17), 180.0)
	await _attendre(20)
	_segment("marche", "Repos puis marche" + reglages)
	await _attendre(p)
	await _tenir(["avant"], p * 3)
	await _attendre(p)
	_fin("marche")
	# 2. sprint
	s.placer_joueur(Vector3(6, 0, -17), 180.0)
	await _attendre(10)
	_segment("sprint", "Course (Maj) puis arrêt" + reglages)
	await _attendre(p / 2)
	await _tenir(["avant", "course"], int(p * 3.2))
	await _attendre(p + p / 2)
	_fin("sprint")
	# 3. virages souris (vif, lent, petits coups de poignet), à l'arrêt puis en marchant
	s.placer_joueur(Vector3(6, 0, -6), 180.0)
	await _attendre(10)
	_segment("virages", "Virages à la souris (vif, lent, va-et-vient)" + reglages)
	await _attendre(p / 2)
	await _tenir([], p / 3, 2400.0 / 60.0)     # ~90° en 1/3 s
	await _attendre(p)
	await _tenir([], p, -700.0 / 60.0)         # ~90° en 1 s
	await _attendre(p)
	for k in 4:
		await _tenir([], p / 6, (1600.0 if k % 2 == 0 else -1600.0) / 60.0)
	await _attendre(p)
	await _tenir(["avant"], p, 900.0 / 60.0)    # virage en marchant
	await _attendre(p)
	_fin("virages")
	# 4. saut sur place, saut en courant, chute de 2 m, chute de 4 m
	s.placer_joueur(Vector3(6, 0, -12), 180.0)
	await _attendre(10)
	_segment("saut", "Saut sur place, saut en marchant, chutes de 2 m et 4 m" + reglages)
	await _attendre(p / 2)
	await _tenir(["saut"], 2)
	await _attendre(p + p / 2)
	await _tenir(["avant"], p / 2)
	await _tenir(["avant", "saut"], 2)
	await _tenir(["avant"], p)
	await _attendre(p)
	for h in [2.0, 4.0]:
		_titre.text = "Chute de %d m" % roundi(h) + reglages
		j.global_position.y += h
		j.velocity = Vector3.ZERO
		await _attendre(p * 2)
		print("CHUTE %.2f m mesurée %.3f m" % [h, j.camera_corps.derniere_chute])
	_fin("saut")
	# 5. combat : mannequin (3 légers, 1 lourd chargé) puis draugr actif (impacts, coups reçus)
	s.placer_joueur(Vector3(0, 0, 0.3), 0.0)
	await _attendre(20)
	_segment("combat", "Combat : coups légers et lourd (mannequin), puis draugr" + reglages)
	await _attendre(p / 2)
	for c in 3:
		mains.attaquer(false)
		await create_timer(0.45).timeout
	await create_timer(0.5).timeout
	mains.entrees.appuyer()
	await create_timer(1.2).timeout
	mains.entrees.relacher()
	await create_timer(1.2).timeout
	var d: CharacterBody3D = s.creer_draugr(Vector3(0.6, 0, -4.0), false)
	s.mannequin.position = Vector3(-2.2, 0, -1.5)
	var gardes := 0
	for i in 540:
		await physics_frame
		if not is_instance_valid(d):
			break
		var vers := d.global_position - j.global_position
		vers.y = 0.0
		j.rotation.y = lerp_angle(j.rotation.y, atan2(-vers.x, -vers.z), 0.12)
		if d.vivant() and vers.length() < 2.6:
			# une garde sur deux : on laisse aussi passer des coups (coup reçu)
			if d.etat == d.ATTAQUE and not mains.combat.attaque() and gardes % 2 == 0:
				mains.entrees.forcer_garde(0.4)
				gardes += 1
			elif d.etat == d.ATTAQUE:
				gardes += 1 if i % 30 == 0 else 0
			elif i % 24 == 0:
				mains.attaquer(i % 96 == 0)
		if not d.vivant() and i > 60:
			break
	await create_timer(1.5).timeout
	_fin("combat")
	# 6. coups reçus (sans garde) : de face, de droite, de gauche ; le draugr est retiré
	if is_instance_valid(d):
		d.queue_free()
	j.vie = j.vie_max
	_segment("coups_recus", "Coups reçus : de face, de droite, de gauche" + reglages)
	await _attendre(p / 2)
	var b := j.global_transform.basis
	for o: Vector3 in [Vector3(0, 0, -1.5), Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0)]:
		j.recevoir_coup(12.0, j.global_position + b * o)
		await _attendre(p + p / 3)
	_fin("coups_recus")
	print("FIN vie %.0f" % j.vie)
	quit()
