extends SceneTree
## Planches image par image et films du combo léger (diagonale → horizontal G→D → estoc) et des finishers multiples
## (épée plantée, pommeau puis estoc, dos, plongé au sol, décapitation), joués EN TEMPS RÉEL dans scenes/test_combat.tscn
## (vrai joueur, vrais ennemis draugr.gd : draugr, bandit, squelette ; ralentis, arrêts sur image et sang compris).
##   godot --path . [--write-movie <fichier.avi> --fixed-fps 30] --script res://outils/captures_coups_finishers.gd --
##     --sortie=<dossier> [--seq=combo,combo_marche,plantee,pommeau,dos,plonge,decapitation,plantee_squelette] [--images]
##     [--gore=0|1|2]
## --images : planche <sortie>/<seq>.png (une vignette par image, légendée : temps, état, clip) ; sans --images, seul le
## film est écrit (--write-movie). Le ralenti du finisher allonge la séquence (temps réel du jeu).

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var sortie := ""
var images_on := false
var l: Label
var _ennemis: Array = []

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _monter() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await process_frame
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(8, 8)
	calque.add_child(l)
	if is_instance_valid(s.mannequin):
		s.mannequin.visible = false
		s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
		s.mannequin.remove_from_group("cibles_combat")

func _ennemi(type: String, p: Vector3, lacet: float) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = type
	d.joueur = j
	d.hud = s.hud
	d.ident = "capture_%d" % _ennemis.size()
	d.position = p
	d.rotation.y = lacet
	s.add_child(d)
	_ennemis.append(d)
	for i in 6:
		await physics_frame
	d.combat.profil.chance_blocage = 0.0
	d._bouclier = 0.0
	return d

func _nettoyer() -> void:
	for d in _ennemis:
		if is_instance_valid(d):
			d.queue_free()
	_ennemis.clear()
	for i in 3:
		await process_frame

## Joueur à `dist` m devant l'ennemi (ou derrière : dos), face à lui, au repos.
func _placer_face(d: Node3D, dist: float, dos := false) -> void:
	var avant := Vector3(d.global_transform.basis.z.x, 0, d.global_transform.basis.z.z).normalized()
	var p := d.global_position + avant * (dist * (-1.0 if dos else 1.0))
	var v := d.global_position - p
	s.placer_joueur(Vector3(p.x, 0.0, p.z), rad_to_deg(atan2(-v.x, -v.z)), -6.0)
	j.vigueur = j.vigueur_max
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains.defense = DefenseJoueur.new()

func _etat() -> String:
	var e := String(EtatCombat.NOMS[mains.combat.etat])
	if mains.combat.etat == EtatCombat.FINISHER:
		var m: Dictionary = mains._m
		var t: float = mains._fin_t
		var ph := "elan"
		for k in ["frappe", "pommeau", "contact", "retrait", "verrou", "suivi"]:
			if m.has(k) and t >= float(m[k]):
				ph = {"frappe": "coup", "pommeau": "pommeau", "contact": "DEDANS", "retrait": "retrait", "verrou": "suivi", "suivi": "suivi"}[k]
		return "%s %s %s t=%.2f" % [e, mains._fin_type, ph, t]
	return "%s %s %s" % [e, mains._geste_nom, mains.anim.clip]

## Enregistre `duree` s (temps réel du jeu) ; `actions` : {instant (s) : [appuyer|relacher|vitesse:<x>,<z>]}.
func _sequence(nom: String, duree: float, actions: Dictionary) -> void:
	var images := []
	var t := 0.0
	var faits := {}
	var vit := Vector3.ZERO
	var n := 0
	while t < duree:
		for k in actions.keys():
			if not faits.has(k) and t >= float(k):
				faits[k] = true
				for a: String in actions[k]:
					if a == "appuyer":
						mains.entrees.appuyer()
					elif a == "relacher":
						mains.entrees.relacher()
					elif a.begins_with("vitesse:"):
						var c := a.substr(8).split(",")
						vit = j.global_transform.basis * Vector3(float(c[0]), 0.0, float(c[1]))
		if vit != Vector3.ZERO:
			j.velocity.x = vit.x
			j.velocity.z = vit.z
		await process_frame
		t += root.get_process_delta_time()
		n += 1
		if images_on:
			l.text = "%s #%02d %4dms  %s" % [nom, n, roundi(t * 1000.0), _etat()]
			await RenderingServer.frame_post_draw
			images.append(root.get_viewport().get_texture().get_image())
	if images_on:
		_planche(nom, images)

func _planche(nom: String, images: Array, colonnes := 8) -> void:
	if images.is_empty():
		return
	var w := 320
	var h := 180
	var p := Image.create(w * colonnes, h * ceili(images.size() / float(colonnes)), false, Image.FORMAT_RGBA8)
	for k in images.size():
		var im: Image = images[k]
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((k % colonnes) * w, (k / colonnes) * h))
	p.save_png(sortie.path_join(nom + ".png"))
	print("PLANCHE ", nom, " ", images.size(), " images")

func _finisher(nom: String, type: String, type_ennemi: String, contexte: String, dos := false) -> void:
	await _nettoyer()
	var d := await _ennemi(type_ennemi, s.POS_DRAUGR, 0.6)
	d.set_physics_process(true)
	_placer_face(d, 1.9, dos)
	match contexte:
		"etourdi":
			d.combat.briser_posture()
			d._etourdir()
		"apres_parade":
			d.combat.subir_parade()
		"sol":
			d._chuter(Vector3.ZERO)
			# il tombe (Death01 accélérée) : on attend qu'il soit à terre
			await create_timer(d._duree("Death01") / 1.6 * 0.95).timeout
			d.combat.au_sol = true
	mains.finisher_force = type
	await _sequence(nom, 2.6, {0.5: ["appuyer"], 0.55: ["relacher"]})
	mains.finisher_force = ""
	print("FINISHER %s : type %s, cible %s, résultat %s" % [nom, mains.dernier_finisher.get("type", "?"), type_ennemi, mains.dernier_finisher.get("resultat", "?")])

func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/coups_finishers"))
	images_on = _arg("images") != ""
	DirAccess.make_dir_recursive_absolute(sortie)
	RetourImpact.muet = true
	if _arg("gore") != "":
		Jeu.option("combat", "gore")
		Jeu.options["combat"]["gore"] = int(_arg("gore"))   # sans écrire le fichier d'options
	await _monter()
	var seqs := Array(_arg("seq", "combo,combo_marche,plantee,pommeau,dos,plonge,decapitation,plantee_squelette").split(",", false))
	for q in seqs:
		match q:
			"combo", "combo_marche":
				await _nettoyer()
				var d := await _ennemi("guerrier", s.POS_DRAUGR, 0.6)
				d.vie = 9999.0
				d.set_physics_process(false)
				_placer_face(d, 2.1)
				var act := {0.4: ["appuyer"], 0.45: ["relacher"], 0.82: ["appuyer"], 0.87: ["relacher"], 1.24: ["appuyer"], 1.29: ["relacher"]}
				if q == "combo_marche":
					act[0.1] = ["vitesse:-0.6,-0.9"]
				await _sequence(q, 2.2, act)
			"plantee":
				await _finisher("plantee", "plantee", "guerrier", "etourdi")
			"pommeau":
				await _finisher("pommeau", "pommeau", "bandit", "apres_parade")
			"dos":
				await _finisher("dos", "dos", "sbire", "etourdi", true)
			"plonge":
				await _finisher("plonge", "plonge", "sbire", "sol")
			"decapitation":
				await _finisher("decapitation", "decapitation", "sbire", "etourdi")
			"plantee_squelette":
				await _finisher("plantee_squelette", "plantee", "squelette", "etourdi")
	quit()
