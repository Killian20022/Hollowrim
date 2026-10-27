extends SceneTree
## Planches et films des FINISHERS alignés et des RÉACTIONS aux coups, dans scenes/test_combat.tscn (FENÊTRE hors écran, via
## godot_slot.sh) :
##   godot --path . --script res://outils/captures_finishers.gd -- --sortie=<dossier> [--finishers=plantee,dos,...]
##         [--genres=guerrier,sbire,squelette,bandit] [--film] [--reactions] [--nuit]
## Planches (par finisher et gabarit) : vue FPS image par image + vue DE CÔTÉ (caméra témoin : la lame est-elle DANS le corps ?).
## --film : chaque finisher en continu (ajouter --write-movie <fichier.avi> --fixed-fps 30 avant « -- »).
## --reactions : coups légers / lourds sur la tête, le torse, les jambes de chaque gabarit (planches FPS + côté).

const SCENE := preload("res://scenes/test_combat.tscn")
const DRAUGR := preload("res://scripts/draugr.gd")
const GROTTE := preload("res://scripts/grotte_jeu.gd")
const DT := 1.0 / 60.0

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var sortie := ""
var _n := 0
var _cote: Camera3D

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
	_cote = Camera3D.new()
	_cote.fov = 50.0
	s.add_child(_cote)
	for i in 40:
		await process_frame

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()

func _pas(n: int) -> void:
	for i in n:
		mains.avancer(DT * Engine.time_scale)
		await physics_frame

## Vue de côté de la victime (caméra témoin à 2,2 m sur son flanc, à hauteur de poitrine).
func _vue_cote(cible: Node3D, haut := 1.25) -> Image:
	var c := cible.global_position
	var vj := j.global_position - c
	vj.y = 0.0
	var lat := Vector3.UP.cross(vj.normalized())   # côté de l'épée (la torche ne masque pas le contact)
	var milieu := (c + j.global_position) * 0.5
	_cote.global_position = milieu + lat * 2.3 + Vector3(0, haut + 0.1, 0)
	_cote.look_at(milieu + Vector3(0, haut - 0.15, 0), Vector3.UP)
	_cote.current = true
	await process_frame
	var im := await _image()
	j.camera.current = true
	return im

func _planche(nom: String, images: Array, colonnes: int, w := 480, h := 270) -> void:
	var c := colonnes
	var p := Image.create(w * c, h * ceili(images.size() / float(c)), false, Image.FORMAT_RGBA8)
	for i in images.size():
		var im: Image = images[i]
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_NEAREST)
		p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % c) * w, (i / c) * h))
	p.save_png(sortie.path_join(nom + ".png"))
	print("PLANCHE ", nom, " (", images.size(), " vues)")

func _ennemi(genre: String, pos: Vector3, lacet: float) -> CharacterBody3D:
	_n += 1
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = "sbire" if genre == "bandit" else genre
	if genre == "bandit":
		d.apparence = GROTTE.apparence_humain(1)
	d.joueur = j
	d.hud = s.hud
	d.ident = "capt_fin_%d" % _n
	d.position = pos
	d.rotation.y = lacet
	s.add_child(d)
	d.vie = 300.0
	d.vie_max = 300.0
	d.combat.profil.chance_blocage = 0.0
	d.set_physics_process(false)
	return d

func _ouvrir(d: CharacterBody3D, sol: bool) -> void:
	if sol:
		d._chuter(Vector3.ZERO)
		d.set_physics_process(true)
		await _pas(40)
		d.set_physics_process(false)
		d.combat.au_sol = true
	else:
		d.combat.briser_posture()
		d._etourdir()
		d.set_physics_process(false)

const CAS := {"plantee": [false, 0.0], "dos": [false, PI], "pommeau": [false, 0.0], "decapitation": [false, 0.0], "plonge": [true, 0.0]}

## Instants (temps de la séquence) des vues FPS et des vues de côté, par finisher.
func _instants(nom: String, m: Dictionary) -> Array:
	var c := float(m.get("contact", 0.3))
	var l := [0.0, float(m.get("arme", 0.15)), float(m.get("frappe", 0.2)), c, c + 0.05]
	if m.has("contact2"):
		l = [0.0, float(m["arme"]), c, c + 0.08, 0.42, float(m["contact2"]) - 0.03, float(m["contact2"])]
	if m.has("plante"):
		l += [float(m["plante"]) + 0.2, float(m["retrait"]) - 0.02, (float(m["retrait"]) + float(m["sortie"])) * 0.5, float(m["sortie"]) + 0.01, float(m["mort"]) + 0.08, float(m["suivi"])]
	else:
		l += [float(m.get("fin_frappe", c + 0.06)), float(m.get("suivi", c + 0.2)), float(m.get("suivi", c + 0.2)) + 0.25]
	return l

func _finisher(nom: String, genre: String) -> void:
	Finishers.force = nom
	s.placer_joueur(Vector3.ZERO, 0.0, -4.0)
	mains.combat.forcer(EtatCombat.REPOS)
	await _pas(10)
	var cas: Array = CAS[nom]
	var e := _ennemi(genre, Vector3(0.2, 0, -1.8), cas[1])
	await _pas(10)
	await _ouvrir(e, cas[0])
	await _pas(10)
	mains.entrees.appuyer()
	await _pas(1)
	mains.entrees.relacher()
	var seq: SequenceFinisher = mains._seq
	if seq == null:
		print("PAS DE SEQUENCE pour ", nom, " / ", genre)
		e.queue_free()
		return
	var m := seq.m
	var instants := _instants(nom, m)
	var fps := []
	var cotes := []
	var haut := 0.45 if cas[0] else 1.25
	for ti: float in instants:
		while seq.t + DT * 0.5 < ti and mains.combat.etat == EtatCombat.FINISHER:
			await _pas(1)
		fps.append(await _image())
		if is_instance_valid(e):
			cotes.append(await _vue_cote(e, haut))
	await _pas(60)
	await _planche("%s_%s_fps" % [nom, genre], fps, 4)
	await _planche("%s_%s_cote" % [nom, genre], cotes, 4)
	var serie: Array = seq.mesure.get("serie", [])
	seq.mesure.erase("serie")
	print("SERIE (t, profondeur vers le dos, latéral) ", serie.slice(0, serie.size(), 4).map(func(v: Vector3) -> String: return "%.2f:%.2f/%.2f" % [v.x, v.y, v.z]))
	print("MESURE %s/%s : %s ; tangages %s ; résultat %s" % [nom, genre, seq.mesure, seq._plans.map(func(p: Dictionary) -> String: return "%.0f°" % rad_to_deg(float(p["tangage"]))), seq.resultat])
	print("INSTANTS %s : %s" % [nom, instants.map(func(x: float) -> String: return "%.2f" % x)])
	e.queue_free()
	await _pas(5)

func _film(noms: Array, genres: Array) -> void:
	RetourCoups.arret_actif = true
	for g: String in genres:
		for nom: String in noms:
			Finishers.force = nom
			s.placer_joueur(Vector3.ZERO, 0.0, -4.0)
			mains.combat.forcer(EtatCombat.REPOS)
			var cas: Array = CAS[nom]
			var e := _ennemi(g, Vector3(0.2, 0, -1.9), cas[1])
			await _pas(20)
			await _ouvrir(e, cas[0])
			await _pas(25)
			mains.entrees.appuyer()
			await _pas(1)
			mains.entrees.relacher()
			await _pas(150)
			e.queue_free()
			await _pas(2)

# ------------------------------------------------------------------ réactions (§8)

## Coup du joueur porté par le vrai tracé : le geste demandé, joué jusqu'à la fin (cible devant, à 1,6 m).
func _coup(geste_lourd: bool) -> void:
	mains.entrees.appuyer()
	if geste_lourd:
		await _pas(40)
	else:
		await _pas(2)
	mains.entrees.relacher()

func _reactions(genres: Array) -> void:
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	for g: String in genres:
		var imgs := []
		var cotes := []
		# léger au torse, lourd au torse, léger à la tête, lourd aux jambes (directement par recevoir_coup : zone et direction
		# maîtrisées, mêmes effets que le tracé de lame)
		var essais := [["legere", "torse", Vector3(-1, -0.2, 0)], ["lourde", "torse", Vector3(-1, -0.1, 0)], ["legere", "tete", Vector3(1, -0.3, 0)], ["lourde", "tete", Vector3(-1, 0.1, 0)], ["lourde", "jambes", Vector3(1, -0.2, 0)]]
		for es: Array in essais:
			s.placer_joueur(Vector3.ZERO, 0.0, -6.0)
			var e := _ennemi(g, Vector3(0, 0, -1.6), 0.0)
			e.set_physics_process(true)
			e._changer(e.TRAQUE)
			await _pas(20)
			e.set_physics_process(false)
			var h: float = float({"tete": 1.6, "torse": 1.2, "jambes": 0.6}[es[1]]) * e.combat.hauteur / 1.8
			var info := {"point": e.global_position + Vector3(0, h, 0.2), "direction": Vector3(es[2]).normalized(), "zone": es[1], "attaque": es[0], "stagger": 12.0 if es[0] == "legere" else 28.0}
			e.recevoir_coup(14.0 if es[0] == "legere" else 34.0, j.global_position, es[0] != "legere", info)
			e.set_physics_process(true)
			# vue FPS 2 images après le coup (sursaut), vue de côté au pic de la réaction (6 images), vue FPS à 12 images
			await _pas(2)
			imgs.append(await _image())
			await _pas(4)
			cotes.append(await _vue_cote(e, 1.2))
			imgs.append(await _image())
			await _pas(6)
			imgs.append(await _image())
			await _pas(30)
			e.queue_free()
			await _pas(2)
		await _planche("reactions_%s_fps" % g, imgs, 3)
		await _planche("reactions_%s_cote" % g, cotes, 5)

func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/finishers_ennemis"))
	DirAccess.make_dir_recursive_absolute(sortie)
	RetourImpact.muet = false
	Sang.niveau_force = 2
	await _monter()
	var noms := _arg("finishers", "plantee,dos,pommeau,decapitation,plonge").split(",")
	var genres := _arg("genres", "guerrier").split(",")
	if _arg("reactions") != "":
		await _reactions(Array(genres))
	elif _arg("film") != "":
		await _film(Array(noms), Array(genres))
	else:
		RetourCoups.arret_actif = false
		RetourImpact.arret_actif = false
		for g: String in genres:
			for nom: String in noms:
				await _finisher(nom, g)
	Finishers.force = ""
	quit(0)
