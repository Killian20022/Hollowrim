extends SceneTree
## Film « un ennemi à la fois » (1280x720) : caméra derrière l'épaule du joueur (~2,6 m), un ennemi armé du catalogue s'approche, fait 2 attaques
## (la 1re en temps réel, la 2e au ralenti x0,25), meurt (ralenti), lâche son arme ; plan final sur l'arme posée au sol (cadrée à côté du corps).
## Ennemis : draugr hache de guerre, squelette gourdin, bandit sabre de pillard, bandit costaud marteau de guerre.
##   godot --path . --write-movie <f.avi> --fixed-fps 60 --resolution 1280x720 --script res://outils/film_armes_ennemis_un_a_un.gd -- --nouvelle
##         [--cas=0,1,2,3] [--photos=<dossier>]   (photos : une image à chaque coup et sur l'arme au sol)
const POS_J := Vector3(0.0, 0.0, 7.0)
const RALENTI := 0.25

var s: Node
var j: CharacterBody3D
var l: Label
var cam: Camera3D
var _photos := ""
var _n_photo := 0
var _suivi: Node3D
var _suivi_actif := false

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _etiquette(parent: Node) -> void:
	var calque := CanvasLayer.new()
	calque.layer = 60
	parent.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.position = Vector2(16, 50)
	calque.add_child(l)

func _texte(nom: String, mode: String) -> void:
	l.text = "%s   |   %s" % [nom, mode]

func _images(n: int) -> void:
	for i in n:
		j.vie = j.vie_max
		if is_instance_valid(_suivi) and _suivi_actif:
			# la caméra reste à son poste derrière l'épaule et vise le milieu entre le joueur et l'ennemi (il ne sort jamais du cadre)
			cam.global_position = j.global_position + Vector3(1.4, 1.9, 3.0)
			var but := (j.global_position + _suivi.global_position) * 0.5 + Vector3(0, 1.1, 0)
			cam.look_at(but, Vector3.UP)
		await process_frame

func _photo(nom: String) -> void:
	if _photos == "":
		return
	await RenderingServer.frame_post_draw
	_n_photo += 1
	root.get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [_photos, _n_photo, nom])

func _ennemi(type: String, arme: String, p: Vector3, app: Dictionary) -> CharacterBody3D:
	for k in 600:
		var d := CharacterBody3D.new()
		d.set_script(load("res://scripts/draugr.gd"))
		d.type = type
		d.joueur = j
		d.hud = s.hud
		d.ident = "film1_%s_%d" % [type, k]
		if not app.is_empty():
			d.apparence = app
		d.position = p
		d.rotation.y = atan2(POS_J.x - p.x, POS_J.z - p.z)
		s.add_child(d)
		if String(d._arme) == arme:
			d.vie_max = 900.0
			d.vie = 900.0
			d._bouclier = 0.0
			d.combat.profil.chance_blocage = 0.0
			d.combat.profil.posture_max = 9999.0
			d.combat.posture = 9999.0
			return d
		d.queue_free()
		await process_frame
	return null

## Attend `n` attaques de `e` (front montant de ATTAQUE puis retour) ; renvoie quand la n-ième est finie. Ralenti avant la n-ième si `lent`.
func _attaque(e: CharacterBody3D, nom: String, lent: bool) -> void:
	var en_cours := false
	var garde := 0
	for i in 2400:
		if lent and not en_cours and e.etat != e.ATTAQUE:
			# le ralenti démarre dès que l'ennemi se prépare (il est à portée et traque)
			if (e.global_position - j.global_position).length() < 3.4:
				Engine.time_scale = RALENTI
		_texte(nom, "ralenti x0,25" if Engine.time_scale < 1.0 else "temps réel")
		if e.etat == e.ATTAQUE and not en_cours:
			en_cours = true
			garde = 0
		if en_cours:
			garde += 1
			if garde == 20 or garde == 36:
				await _photo("coup_%s" % nom.get_slice(" ", 0))
			if e.etat != e.ATTAQUE:
				return
		await _images(1)

## Caméra derrière l'épaule droite du joueur (~3 m derrière lui, 1,4 m à droite, un peu au-dessus), vers la zone de combat.
func _cam_epaule() -> void:
	cam.global_position = POS_J + Vector3(1.4, 1.9, 3.0)
	cam.look_at(POS_J + Vector3(0.1, 1.1, -2.2), Vector3.UP)
	cam.make_current()

func _cas(i: int, nom: String, type: String, arme: String, app: Dictionary) -> void:
	_cam_epaule()
	Engine.time_scale = 1.0
	var e: CharacterBody3D = await _ennemi(type, arme, POS_J + Vector3(0.9, 0.0, -6.5), app)
	if e == null:
		print("ENNEMI_INTROUVABLE ", nom)
		return
	_texte(nom, "temps réel")
	# approche puis 1re attaque en temps réel
	_suivi = e
	_suivi_actif = true
	await _attaque(e, nom, false)
	await _images(40)
	# 2e attaque au ralenti
	await _attaque(e, nom, true)
	Engine.time_scale = RALENTI
	await _images(10)
	# mort au ralenti
	e._mourir(j.global_position, 60.0, true)
	for k in 150:
		_texte(nom, "ralenti x0,25")
		await _images(1)
	Engine.time_scale = 1.0
	await _images(90)
	# plan sur l'arme au sol : caméra du côté opposé au corps, derrière l'arme
	_suivi_actif = false
	var b: Node3D = e._butin
	var w: Node3D = b.get_node_or_null(ArmesEnnemis.SOL) if b != null else null
	if w != null:
		var corps := e.global_position
		corps.y = w.global_position.y
		var dir := w.global_position - corps
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.05 else Vector3(0, 0, 1)
		cam.global_position = w.global_position + dir * 1.2 + Vector3(0, 0.9, 0)
		cam.look_at(w.global_position, Vector3.UP)
		cam.make_current()
		_texte(nom, "l'arme tombée au sol")
		await _images(30)
		await _photo("sol_%s" % nom.get_slice(" ", 0))
		await _images(150)
	_cam_epaule()
	e.queue_free()
	if b != null:
		b.queue_free()
	await _images(5)

func _go() -> void:
	RetourImpact.muet = false
	_photos = _arg("photos", "")
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.position = Vector3(-6.0, 0.0, -6.0)
	_etiquette(s)
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.05
	s.add_child(cam)
	j.basculer_vue(true)
	s.placer_joueur(POS_J, 0.0, -6.0)
	j.camera_tp.recaler()
	j.vigueur = j.vigueur_max
	var app_b: Dictionary = GrotteJeu.apparence_humain(1, "")
	var app_c: Dictionary = GrotteJeu.apparence_humain(2, "casque_nasal")
	var defs := [
		["draugr — hache de guerre", "sbire", "hache_guerre", {}],
		["squelette — gourdin", "squelette", "gourdin", {}],
		["bandit — sabre de pillard", "sbire", "sabre_pillard", app_b],
		["bandit costaud — marteau de guerre", "sbire", "marteau_guerre", app_c]]
	var voulus := _arg("cas", "0,1,2,3").split(",")
	await _images(30)
	print("DEBUT_SEQUENCE")
	for i in defs.size():
		if str(i) in voulus:
			var d: Array = defs[i]
			await _cas(i, String(d[0]), String(d[1]), String(d[2]), d[3])
	print("FIN_SEQUENCE")
	quit(0)
