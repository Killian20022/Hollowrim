extends SceneTree
## Captures de l'onglet Carte (branche rpg/carte) dans le VRAI monde (scenes/foret_test.tscn) :
##   godot --path . --script res://outils/captures_carte.gd -- --nouvelle --sortie=<dossier>
## Si la coquille du lot C (MenuPersonnage, avec l'entrée « carte » dans ONGLETS) est présente, le menu est ouvert sur la
## Carte comme en jeu ; sinon l'onglet est posé seul sur un fond de vélin (essai sur la branche rpg/carte).
## Mode capture : la partie n'est jamais sauvegardée (--nouvelle) ; lieux marqués découverts et quêtes lancées en mémoire.

const SCENE := preload("res://scenes/foret_test.tscn")

var _dossier := ""
var m: Node
var o: OngletCarte

func _init() -> void:
	_lancer.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _capture(nom: String) -> void:
	await _images(8)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_dossier)
	img.save_png(_dossier.path_join(nom + ".png"))
	var x2 := img.duplicate()
	x2.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	x2.save_png(_dossier.path_join(nom + "_x2.png"))
	print("CAPTURE ", _dossier.path_join(nom + ".png"))

## Pose le curseur (survol) sur un point monde : fiche du marqueur affichée.
func _survoler(p: Vector3) -> void:
	await _images(30)
	var s := o.ecran(Vector3(p.x, o.carte.hauteur(p.x, p.z), p.z))
	o.survol_impose = s - o.rect_carte().position

func _lancer() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			_dossier = a.substr(9)
	if _dossier == "" or DisplayServer.get_name() == "headless":
		print("captures : fenêtre et --sortie=<dossier> nécessaires")
		quit(1)
		return
	m = SCENE.instantiate()
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	while not m.pret and Time.get_ticks_msec() - t0 < 300000:
		await process_frame
	await _images(30)
	m.hud.aide_t = 0.0
	# partie avancée (en mémoire) : lieux découverts, trois quêtes en cours, joueur sur le chemin du village
	for l: Dictionary in Lieux.liste():
		if l["decouvrable"]:
			m.hud.lieux_vus[l["nom"]] = true
	m.quetes.signaler("parle:forgeron")
	m.quetes.signaler("parle:garde")
	m.quetes.signaler("parle:chef")   # la plus récente = la quête suivie (L'anneau de givre → tertre)
	m.hud._annonces.clear()
	m.hud._avis.clear()
	var pj := Vector3(14.0, 0.0, 12.0)
	m.joueur.global_position = Vector3(pj.x, m.hauteur(pj.x, pj.z) + 0.1, pj.z)
	m.joueur.rotation.y = atan2(-(44.0 - pj.x), -(40.0 - pj.z))   # regarde vers Skarnholt (avant = -Z local)
	await _images(10)
	# coquille du lot C si elle existe et connaît l'onglet ; sinon onglet seul sur vélin
	var coquille: Node = null
	for n in m.find_children("*", "CanvasLayer", true, false):
		if n.has_method("ouvrir") and n.has_method("onglet") and n.get("ONGLETS") != null:
			coquille = n
	if coquille != null and coquille.onglet("carte") != null:
		coquille.ouvrir("carte")
		await _images(5)
		o = coquille.onglet("carte")
		print("coquille MenuPersonnage : onglet Carte ouvert")
	else:
		var calque := CanvasLayer.new()
		calque.layer = 45
		calque.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(calque)
		var fond := ColorRect.new()
		fond.color = Color("#cdb88e")
		fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		calque.add_child(fond)
		o = OngletCarte.new()
		o.joueur = m.joueur
		calque.add_child(o)
		o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		o.visible = true
		paused = true
		o.ouvrir()
		print("pas de coquille : onglet seul")
	await _images(20)
	# 1. ouverture (centrée sur le joueur), sans survol
	await _capture("1_ouverture_joueur")
	# 2. vue d'ensemble
	o.regarder(Vector2(8, 0), 9999.0, true)
	o.survol_impose = Vector2(-1, -1)
	o.rect_carte()
	await _images(10)
	o.survol_impose = Vector2(2000, 2000)   # hors carte : pas de réticule, pas de fiche
	await _capture("2_vue_ensemble")
	# 3. zoom sur le village (noms des maisons)
	o.regarder(Vector2(46, 46), OngletCarte.DIST_MIN * 1.4, true)
	await _images(10)
	await _capture("3_zoom_village")
	# 4. marqueur de quête : F (aller à la quête suivie), fiche au survol
	o.regarder(o.cible, o._dist_max * 0.42, true)
	var titre := o.centrer_quete()
	await _images(60)
	for c: Dictionary in Lieux.cibles_quetes(m.quetes, m):
		if c["titre"] == titre:
			await _survoler(c["pos"])
	print("quête suivie : ", titre)
	await _capture("4_marqueur_quete")
	# 5. le joueur (flèche orientée), fiche « Vous »
	o.regarder(Vector2(pj.x, pj.z), o._dist_max * 0.3, true)
	await _survoler(m.joueur.global_position)
	await _capture("5_joueur")
	# 6. début de partie : rien de découvert, aucune quête (seuls les repères visibles de loin)
	m.hud.lieux_vus.clear()
	m.quetes.etat.clear()
	o.regarder(Vector2(10, 5), o._dist_max * 0.7, true)
	o.survol_impose = Vector2(2000, 2000)
	await _capture("6_debut_de_partie")
	print("captures finies (%d ms)" % (Time.get_ticks_msec() - t0))
	quit(0)
