extends SceneTree
## Captures du débogage F3 des collisions de la lame dans la zone de collisions de scenes/test_combat.tscn (FENÊTRE, via
## godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/captures_collisions.gd -- --nouvelle --sortie=<dossier>
## Une planche par cas : [vue FPS pendant la frappe, vue FPS après le coup, vue de côté après le coup] avec la trajectoire
## de la pointe colorée par phase, la nappe de rayons, les points de contact et les formes de collision (docs/COMBAT.md).

const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0
const CAS := [["mur_fin", "horizontale_gd"], ["coin", "diag_dg"], ["porte", "estoc"], ["porte", "horizontale_gd"],
	["serres", "horizontale_b"], ["derriere", "horizontale_b"], ["poteau", "diag_gd"], ["draugrs", "horizontale_b"], ["loin", "diag_dg"]]

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var sortie := ""
var cam_cote: Camera3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()

func _planche(nom: String, images: Array) -> void:
	var w := 480
	var h := 270
	var p := Image.create(w * images.size(), h, false, Image.FORMAT_RGBA8)
	for i in images.size():
		var im: Image = images[i]
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_NEAREST)
		p.blit_rect(im, Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	p.save_png(sortie.path_join(nom + ".png"))
	print("PLANCHE ", nom)

func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/collisions_profils"))
	DirAccess.make_dir_recursive_absolute(sortie)
	RetourCoups.arret_actif = false
	RetourImpact.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": "", "zone": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame
	mains.pas_manuel = true
	mains.basculer_debogage(true)
	for d in s.zone.cibles["draugrs"]:
		d._bouclier = 0.0
		d.combat.profil.chance_blocage = 0.0
	cam_cote = Camera3D.new()
	cam_cote.fov = 60.0
	s.add_child(cam_cote)
	for c in CAS:
		await _cas(c[0], c[1])
	print("FIN captures_collisions")
	quit(0)

func _cas(poste: String, geste: String) -> void:
	var p: Vector3 = s.zone.poste(poste)
	s.placer_joueur(p, 0.0)
	j.vigueur = j.vigueur_max
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	mains.defense = DefenseJoueur.new()
	s.zone.remettre()
	for i in 30:
		mains.avancer(DT)
		await process_frame
	var images := []
	mains.entrees.appuyer()
	var milieu_pris := false
	for k in 70:
		if k == 3:
			mains.entrees.relacher()
		mains.avancer(DT)
		if k == 0 and mains._geste_nom != geste:
			mains._geste_nom = geste
			mains._preparer_geste(false)
		await process_frame
		if not milieu_pris and mains._actif_lance and mains.combat.t > 0.0 and (mains._t_geste - mains._duree_prep - mains._duree_tenue) > mains._duree_active * 0.45:
			images.append(await _image())
			milieu_pris = true
		if mains.combat.etat == EtatCombat.RECUPERATION and mains.combat.t > 0.08:
			break
	if not milieu_pris:
		images.append(await _image())
	images.append(await _image())
	# vue de côté (le débogage reste dessiné : coordonnées monde)
	var cam_j := root.get_viewport().get_camera_3d()
	cam_cote.global_position = p + Vector3(2.6, 2.6, 0.6)
	cam_cote.look_at(p + Vector3(0, 1.1, -1.3), Vector3.UP)
	cam_cote.make_current()
	await process_frame
	images.append(await _image())
	cam_j.make_current()
	await _planche("f3_%s_%s" % [poste, geste], images)
