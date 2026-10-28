extends SceneTree
## Captures du RETOUR DE COMBAT au corps à corps (lot L6) dans scenes/test_combat.tscn (FENÊTRE hors écran, via godot_slot.sh) :
##   godot --path . --script res://outils/captures_retour_combat.gd -- --sortie=<dossier> [--nuit]
## Écrit <cas>_<k>.png (640x360) : coup lourd sur un draugr, coup lourd sur un squelette (os qui volent puis au sol), coup paré
## au bouclier d'un draugr ancien, finisher (épée plantée) sur un squelette, barre de l'ennemi avec son nom (agrandie x3),
## chiffres de dégâts activés (normal, critique, bloqué). Marche aussi sur une version d'avant le lot L6 (comparaison) : les
## classes nouvelles sont cherchées à l'exécution.

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const DT := 1.0 / 60.0

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var sortie := ""
var _n := 0

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _pas(n: int) -> void:
	for i in n:
		mains.avancer(DT * Engine.time_scale)
		await physics_frame

func _sauver(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.save_png(sortie.path_join(nom + ".png"))
	# bande du haut (nom + barre de l'ennemi) agrandie x3
	var haut := im.get_region(Rect2i(im.get_width() / 2 - 110, 0, 220, 60))
	haut.resize(660, 180, Image.INTERPOLATE_NEAREST)
	haut.save_png(sortie.path_join(nom + "_haut_x3.png"))
	print("CAPTURE ", nom)

func _ennemi(genre: String, pos: Vector3, lacet: float) -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = genre
	d.joueur = j
	d.hud = s.hud
	d.ident = "capt_l6_%d" % _n
	d.position = pos
	d.rotation.y = lacet
	s.add_child(d)
	d.vie = 300.0
	d.vie_max = 300.0
	d.set_physics_process(true)
	d._changer(d.TRAQUE)
	return d

func _coup(e: CharacterBody3D, lourd: bool, zone := "torse", crit := false) -> String:
	var h: float = float({"tete": 1.6, "torse": 1.2, "jambes": 0.6}[zone]) * e.combat.hauteur / 1.8
	var info := {"point": e.global_position + Vector3(0, h, 0.22), "direction": Vector3(-1, -0.15, 0.1).normalized(), "zone": zone,
		"attaque": "lourde" if lourd else "legere", "stagger": 28.0 if lourd else 12.0}
	if crit:
		info["critique"] = true
	j.ennemi_vise = e
	return e.recevoir_coup(34.0 if lourd else 14.0, j.global_position, lourd, info)

func _cas_coup(nom: String, genre: String, instants: Array, lourd := true) -> void:
	s.placer_joueur(Vector3.ZERO, 0.0, -4.0)
	mains.combat.forcer(EtatCombat.REPOS)
	var e := _ennemi(genre, Vector3(0.0, 0, -1.7), 0.0)
	e.combat.profil.chance_blocage = 0.0
	await _pas(25)
	e.set_physics_process(false)
	_coup(e, lourd)
	e.set_physics_process(true)
	var t := 0
	for k in instants.size():
		await _pas(int(instants[k]) - t)
		t = int(instants[k])
		await _sauver("%s_%d" % [nom, k])
	if genre == "squelette":
		# regard vers le sol : les os retombés
		e.visible = false
		j.tete.rotation.x = -0.95
		await _pas(3)
		await _sauver("%s_sol" % nom)
		j.tete.rotation.x = 0.0
	e.queue_free()
	await _pas(5)

func _cas_bouclier() -> void:
	s.placer_joueur(Vector3.ZERO, 0.0, -4.0)
	var e := _ennemi("guerrier", Vector3(0.0, 0, -1.7), 0.0)
	e.combat.profil.chance_blocage = 1.0
	await _pas(25)
	var r := ""
	for essai in 12:
		e.set_physics_process(false)
		e.etat = e.TRAQUE
		r = _coup(e, false)
		e.set_physics_process(true)
		if r == "bloque":
			break
		await _pas(20)
	print("BOUCLIER : ", r)
	var pas := [2, 4, 6]
	for k in pas.size():
		await _pas(int(pas[k]))
		await _sauver("bouclier_%d" % k)
	e.queue_free()
	await _pas(5)

func _cas_finisher(genre: String) -> void:
	Finishers.force = "plantee"
	s.placer_joueur(Vector3.ZERO, 0.0, -4.0)
	mains.combat.forcer(EtatCombat.REPOS)
	await _pas(10)
	var e := _ennemi(genre, Vector3(0.2, 0, -1.8), 0.0)
	e.combat.profil.chance_blocage = 0.0
	await _pas(10)
	e.combat.briser_posture()
	e._etourdir()
	e.set_physics_process(false)
	await _pas(10)
	j.ennemi_vise = e
	mains.entrees.appuyer()
	await _pas(1)
	mains.entrees.relacher()
	var seq: SequenceFinisher = mains._seq
	if seq == null:
		print("PAS DE SEQUENCE")
		return
	var m := seq.m
	var c := float(m.get("contact", 0.3))
	var instants := [c + 0.03, c + 0.15, float(m.get("retrait", c + 0.6)) + 0.05, float(m.get("mort", c + 1.0)) + 0.25]
	for k in instants.size():
		while seq.t + DT * 0.5 < float(instants[k]) and mains.combat.etat == EtatCombat.FINISHER:
			await _pas(1)
		await _sauver("finisher_%s_%d" % [genre, k])
	await _pas(90)
	await _sauver("finisher_%s_%d" % [genre, instants.size()])
	Finishers.force = ""
	e.queue_free()
	await _pas(5)

func _cas_chiffres() -> void:
	var cd: Variant = load("res://scripts/combat/chiffres_degats.gd") if ResourceLoader.exists("res://scripts/combat/chiffres_degats.gd") else null
	if cd != null:
		cd.force_actif = 1
	s.placer_joueur(Vector3.ZERO, 0.0, -4.0)
	var e := _ennemi("guerrier", Vector3(-0.5, 0, -2.2), 0.0)
	var e2 := _ennemi("sbire", Vector3(0.9, 0, -2.6), 0.0)
	e.combat.profil.chance_blocage = 0.0
	await _pas(25)
	e.set_physics_process(false)
	e2.set_physics_process(false)
	_coup(e2, false)
	await _pas(8)
	_coup(e, true, "tete", true)
	await _pas(6)
	e.combat.profil.chance_blocage = 1.0
	e.etat = e.TRAQUE
	var r := _coup(e, false)
	await _pas(2)
	e2.vie = 300.0
	_coup(e2, false)
	await _pas(3)
	print("CHIFFRES : 3e coup ", r)
	await _sauver("chiffres_0")
	await _pas(14)
	await _sauver("chiffres_1")
	if cd != null:
		cd.force_actif = -1
	e.queue_free()
	e2.queue_free()
	await _pas(5)

func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/retour_combat"))
	DirAccess.make_dir_recursive_absolute(sortie)
	RetourImpact.muet = false
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	Sang.niveau_force = 2
	s = SCENE.instantiate()
	var o := {"draugr": "aucun", "sans-aide": ""}
	if _arg("nuit") != "":
		o["nuit"] = ""
	s.options = o
	root.add_child(s)
	current_scene = s
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mains.pas_manuel = true
	s.mannequin.position = Vector3(30, 0, 30)
	for i in 60:
		await process_frame
	await _cas_coup("draugr", "guerrier", [2, 5, 10])
	await _cas_coup("squelette", "squelette", [2, 6, 14, 70])
	var eo: Variant = root.find_child("EclatsOs", true, false)
	if eo != null:
		print("OS : ", eo.get_children().filter(func(c: Node) -> bool: return (c as Node3D).visible).map(func(c: Node3D) -> String: return str(c.global_position.snapped(Vector3.ONE * 0.01))))
	await _cas_bouclier()
	await _cas_finisher("squelette")
	await _cas_finisher("guerrier")
	await _cas_chiffres()
	quit(0)
