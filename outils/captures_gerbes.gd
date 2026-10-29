extends SceneTree
## SÉQUENCES IMAGE PAR IMAGE des gerbes de pixels du corps à corps (passe « intensité du retour de combat », suite du lot L6)
## dans scenes/test_combat.tscn (FENÊTRE hors écran, via godot_slot.sh, --fixed-fps 60 : une image = 1/60 s, séquences
## reproductibles) :
##   godot --path . --script res://outils/captures_gerbes.gd --fixed-fps 60 --disable-vsync -- --nouvelle --sortie=<dossier>
##   godot --path . --script res://outils/captures_gerbes.gd -- --nouvelle --planche=<avant>,<apres>,<dossier des planches>
## Cas : coup lourd sur un draugr, sur un squelette, sur le troll de givre, coup paré au bouclier d'un draugr ancien, coup
## bloqué puis parade parfaite au bouclier du JOUEUR, coup d'épée sur le dragon de givre posé. Chaque cas : IMAGES images
## (<cas>_<k>.png, 640x360). N'utilise que des API d'avant la passe : sert aussi pour les images « avant ».
## --planche : une planche par cas (<cas>.jpg) : ligne du haut = avant (liseré rouge), ligne du bas = après (liseré vert),
## IMAGES colonnes, recadrage CADRE autour du centre de l'écran (pixels natifs, sans lissage).

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const TROLL := preload("res://scripts/troll_givre_ia.gd")
const DT := 1.0 / 60.0
## Images capturées après l'impact (en images à 60 i/s).
const INSTANTS := [1, 2, 3, 5, 8, 12, 20]
const CAS := ["draugr", "squelette", "troll", "bouclier", "bouclier_joueur", "dragon"]
## Recadrage des planches (x, y, l, h) dans l'image 640x360, par cas.
const CADRE := {"draugr": Rect2i(150, 40, 340, 260), "squelette": Rect2i(150, 40, 340, 260), "troll": Rect2i(130, 0, 380, 290),
	"bouclier": Rect2i(150, 40, 340, 260), "bouclier_joueur": Rect2i(60, 60, 400, 290), "dragon": Rect2i(80, 20, 480, 320)}

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
	root.get_viewport().get_texture().get_image().save_png(sortie.path_join(nom + ".png"))
	print("CAPTURE ", nom)

## Images de la séquence, l'impact ayant lieu juste avant l'appel.
func _sequence(nom: String) -> void:
	var t := 0
	for k in INSTANTS.size():
		await _pas(int(INSTANTS[k]) - t)
		t = int(INSTANTS[k])
		await _sauver("%s_%d" % [nom, k])

func _draugr(genre: String, pos: Vector3) -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = genre
	d.joueur = j
	d.hud = s.hud
	d.ident = "capt_gerbe_%d" % _n
	d.position = pos
	s.add_child(d)
	d.vie = 300.0
	d.vie_max = 300.0
	d.set_physics_process(true)
	d._changer(d.TRAQUE)
	return d

func _coup(e: CharacterBody3D, lourd: bool, h: float) -> String:
	var info := {"point": e.global_position + Vector3(0, h, 0.25), "direction": Vector3(-1, -0.15, 0.1).normalized(), "zone": "torse",
		"attaque": "lourde" if lourd else "legere", "stagger": 28.0 if lourd else 12.0}
	j.ennemi_vise = e
	return e.recevoir_coup(34.0 if lourd else 14.0, j.global_position, lourd, info)

func _cas_coup(genre: String) -> void:
	s.placer_joueur(Vector3.ZERO, 0.0, -4.0)
	mains.combat.forcer(EtatCombat.REPOS)
	var e := _draugr(genre, Vector3(0.0, 0, -1.7))
	e.combat.profil.chance_blocage = 0.0
	await _pas(25)
	e.set_physics_process(false)
	_coup(e, true, 1.2 * e.combat.hauteur / 1.8)
	e.set_physics_process(true)
	await _sequence(genre if genre == "squelette" else "draugr")
	e.queue_free()
	await _pas(30)

func _cas_troll() -> void:
	s.placer_joueur(Vector3.ZERO, 0.0, 6.0)
	mains.combat.forcer(EtatCombat.REPOS)
	_n += 1
	var t := CharacterBody3D.new()
	t.set_script(TROLL)
	t.joueur = j
	t.hud = s.hud
	t.ident = "capt_troll_%d" % _n
	t.position = Vector3(0.0, 0.05, -2.6)
	s.add_child(t)
	await _pas(20)
	t.set_physics_process(false)
	t.vie = 400.0
	_coup(t, true, 1.3 * t.combat.hauteur / 1.8)
	await _sequence("troll")
	t.queue_free()
	await _pas(30)

func _cas_bouclier() -> void:
	s.placer_joueur(Vector3.ZERO, 0.0, -4.0)
	var e := _draugr("guerrier", Vector3(0.0, 0, -1.7))
	e.combat.profil.chance_blocage = 1.0
	await _pas(25)
	var r := ""
	for essai in 12:
		e.set_physics_process(false)
		e.etat = e.TRAQUE
		r = _coup(e, false, 1.2)
		e.set_physics_process(true)
		if r == "bloque":
			break
		await _pas(40)
	print("BOUCLIER : ", r)
	await _sequence("bouclier")
	e.queue_free()
	await _pas(30)

## Bouclier du joueur : coup de face bloqué (séquence), puis parade parfaite (séquence « _parade »).
func _cas_bouclier_joueur() -> void:
	var magie: Node = mains.magie
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "bouclier")
	s.placer_joueur(Vector3.ZERO, 0.0, -4.0)
	mains.combat.forcer(EtatCombat.REPOS)
	await _pas(50)
	mains.entrees.forcer_garde(30.0)
	await _pas(40)   # garde tenue depuis longtemps : bloc, pas parade
	var devant := j.global_position + Vector3(0, 0, -1.5)
	print("BOUCLIER JOUEUR : ", j.recevoir_coup(20.0, devant))
	await _sequence("bouclier_joueur")
	mains.entrees.forcer_garde(0.0)
	j.vie = j.vie_max
	j.vigueur = j.vigueur_max
	await _pas(60)
	mains.combat.forcer(EtatCombat.REPOS)
	mains.defense = DefenseJoueur.new()
	mains.entrees.forcer_garde(5.0)
	await _pas(4)
	print("PARADE JOUEUR : ", j.recevoir_coup(20.0, devant))
	await _sequence("bouclier_joueur_parade")
	mains.entrees.forcer_garde(0.0)
	j.vie = j.vie_max
	await _pas(40)

func _cas_dragon() -> void:
	s.placer_joueur(Vector3.ZERO, 0.0, 10.0)
	mains.combat.forcer(EtatCombat.REPOS)
	var d: CharacterBody3D = load("res://scripts/dragon.gd").new()
	d.joueur = j
	d.hud = s.hud
	d.hauteur_sol = func(_x: float, _z: float) -> float: return 0.0
	d.centre = Vector3(0, 0, -60)
	d.position = Vector3(0, 0, -5.5)
	s.add_child(d)
	d._atterrir()
	d.global_position = Vector3(0, 0, -5.5)
	d.rotation.y = PI * 0.5   # flanc face au joueur
	d.set_physics_process(false)
	await _pas(20)
	print("DRAGON : ", d.recevoir_coup(20.0, j.global_position, true))
	await _sequence("dragon")
	d.queue_free()
	await _pas(30)

func _planche(avant: String, apres: String, dest: String) -> void:
	DirAccess.make_dir_recursive_absolute(dest)
	var noms: Array = CAS.duplicate()
	noms.insert(noms.find("bouclier_joueur") + 1, "bouclier_joueur_parade")
	for nom: String in noms:
		var c: Rect2i = CADRE.get(nom, CADRE.get(nom.trim_suffix("_parade"), Rect2i(120, 30, 400, 290)))
		var marge := 6
		var im := Image.create(INSTANTS.size() * (c.size.x + marge) + marge, 2 * (c.size.y + marge) + marge, false, Image.FORMAT_RGB8)
		im.fill(Color(0.07, 0.07, 0.07))
		var ok := false
		for ligne in 2:
			var dossier := avant if ligne == 0 else apres
			var y := marge + ligne * (c.size.y + marge)
			im.fill_rect(Rect2i(0, y, marge - 2, c.size.y), Color(0.85, 0.15, 0.1) if ligne == 0 else Color(0.2, 0.8, 0.25))
			for k in INSTANTS.size():
				var f := dossier.path_join("%s_%d.png" % [nom, k])
				if not FileAccess.file_exists(f):
					continue
				var src := Image.load_from_file(f)
				src.convert(Image.FORMAT_RGB8)
				im.blit_rect(src, c, Vector2i(marge + k * (c.size.x + marge), y))
				ok = true
		if ok:
			im.save_jpg(dest.path_join(nom + ".jpg"), 0.92)
			print("PLANCHE ", dest.path_join(nom + ".jpg"))

func _go() -> void:
	var pl := _arg("planche")
	if pl != "":
		var p := pl.split(",")
		_planche(p[0], p[1], p[2])
		quit(0)
		return
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/gerbes"))
	DirAccess.make_dir_recursive_absolute(sortie)
	RetourImpact.muet = true
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	Sang.niveau_force = 2
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": "", "nuit": ""} if _arg("nuit") != "" else {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	current_scene = s
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mains.pas_manuel = true
	s.mannequin.position = Vector3(30, 0, 30)
	for i in 60:
		await process_frame
	var seuls := _arg("cas")
	for c: String in CAS:
		if seuls != "" and not (c in seuls.split(",")):
			continue
		match c:
			"draugr":
				await _cas_coup("guerrier")
			"squelette":
				await _cas_coup("squelette")
			"troll":
				await _cas_troll()
			"bouclier":
				await _cas_bouclier()
			"bouclier_joueur":
				await _cas_bouclier_joueur()
			"dragon":
				await _cas_dragon()
	quit(0)
