extends SceneTree
## Captures de la magie (scenes/test_magie.tscn ; FENÊTRE via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/captures_magie.gd -- --sortie=<dossier> [--poses] [--film]
## --poses : une image par pose de main (repos, charge, canalisation, double, épée + sort, bouclier) → <sortie>/pose_<nom>.png
## sans option : le pilote automatique (§10) et une image à chaque `moment` → <sortie>/<nn>_<moment>.png
## --film : le pilote seul (ajouter --write-movie <fichier.avi> --fixed-fps 30 avant « -- »).
## Avec les BOUCHONS d'EffetsMagie (sphères colorées) tant que la branche magie/effets n'est pas fusionnée.

const SCENE := preload("res://scenes/test_magie.tscn")

var s: Node3D
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

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()

func _sauver(nom: String) -> void:
	if sortie == "":
		return
	var img := await _image()
	img.save_png(sortie.path_join(nom + ".png"))
	print("CAPTURE ", nom)

func _attendre(t: float) -> void:
	await create_timer(t).timeout

func _go() -> void:
	sortie = _arg("sortie")
	if sortie != "":
		DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	var opts := {"draugr": "fige", "sans-aide": ""}
	if _arg("poses") == "" :
		opts["pilote"] = ""
	s.options = opts
	root.add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await process_frame
	if _arg("poses") != "":
		await _poses()
		quit(0)
		return
	s.moment.connect(func(nom: String) -> void:
		_n += 1
		_sauver.call("%02d_%s" % [_n, nom]))
	while not s.pilote_fini:
		await process_frame
	await _attendre(0.3)
	quit(0)

func _poses() -> void:
	var m: MainSort = s.magie
	var cas := [
		["repos_feu_epee", "jet_flammes", "epee", "", 0.0],
		["incante_feu", "jet_flammes", "epee", "gauche", 0.1],
		["canalise_feu", "jet_flammes", "epee", "gauche", 0.6],
		["charge_boule", "boule_feu", "epee", "gauche", 0.7],
		["repos_glace_elec", "lance_givre", "chaine_eclairs", "", 0.0],
		["double_feu", "jet_flammes", "jet_flammes", "deux", 0.6],
		["canalise_drain", "drain_vie", "epee", "gauche", 0.6],
		["zone_levee", "explosion_obscure", "epee", "gauche", 0.6],
		["canalise_arc_droite", "vide", "arc_electrique", "droite", 0.6],
		["bouclier", "bouclier", "epee", "", 0.0],
		["bouclier_garde", "bouclier", "epee", "garde", 0.4],
		["torche_epee", "torche", "epee", "", 0.0],
		["protection", "protection", "soin", "deux_diff", 0.6],
	]
	for c in cas:
		m.equiper("droite", c[2])
		m.equiper("gauche", c[1])
		s.placer_joueur(Vector3(0, 0, 1.6), 0.0)
		s.joueur.mana = 100.0
		m.recharges.clear()
		await _attendre(0.5)
		match c[3]:
			"gauche", "droite":
				m.appuyer(c[3])
			"deux", "deux_diff":
				m.appuyer("gauche")
				m.appuyer("droite")
			"garde":
				s.joueur.mains.entrees.forcer_garde(2.0)
		await _attendre(c[4])
		await _sauver("pose_" + c[0])
		m.relacher("gauche")
		m.relacher("droite")
		await _attendre(0.6)
