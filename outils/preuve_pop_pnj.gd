extends SceneTree
## Preuve « aucun PNJ n'apparaît à l'écran » après le chargement (naissance différée des villageois, Monde._naissances_differees).
## Fenêtre nécessaire (hors écran via godot_slot) : le monde entre comme par l'écran de chargement (étalé, arbre en pause), puis,
## à chaque villageois qui naît, on projette son corps (pieds, ventre, tête) à l'écran de la caméra du joueur : naissance « visible »
## = au moins un point dans l'image, devant la caméra, à moins de 65 m. Imprime « POP » par naissance visible et un bilan.
##   godot --path . --script res://outils/preuve_pop_pnj.gd -- --nouvelle --sortie=<dossier> [--scenario=depart|village]
## depart : le joueur regarde le feu de camp (vue de départ) ; village : il regarde d'abord vers le village (les villageois dans le champ
## attendent), se détourne à 12 s (ils naissent alors), se retourne à 20 s (ils sont là, aucun n'a surgi sous ses yeux).
var m: Node3D
var pops := 0
var nes := 0
var t0 := 0

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _visible(v: Node3D) -> bool:
	var cam := root.get_viewport().get_camera_3d()
	var r := root.get_viewport().get_visible_rect()
	for dy in [0.0, 0.9, 1.8]:
		var p := v.global_position + Vector3(0, dy, 0)
		if cam.is_position_behind(p) or cam.global_position.distance_to(p) > 65.0:
			continue
		if r.has_point(cam.unproject_position(p)):
			return true
	return false

func _ne(n: Node) -> void:
	if not (n is CharacterBody3D) or n.get("donnees") == null or n.get("quetes") == null:
		return
	await process_frame   # _ready du villageois joué : position finale
	nes += 1
	var vu := _visible(n)
	if vu:
		pops += 1
	print("%s %s à %.1f s, %.0f m du joueur" % ["POP " if vu else "né  ", n.donnees.get("id", "?"), (Time.get_ticks_msec() - t0) / 1000.0, m.joueur.global_position.distance_to(n.global_position)])

func _photo(nom: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(_arg("sortie", "user://") .path_join(nom + ".png"))

func _go() -> void:
	var scenario := _arg("scenario", "depart")
	Jeu.chargement_etale = true
	m = (load(Jeu.SCENE_JEU) as PackedScene).instantiate()
	paused = true
	root.add_child(m)
	current_scene = m
	while m.get("pret") != true:
		await process_frame
	Jeu.chargement_etale = false
	paused = false
	t0 = Time.get_ticks_msec()
	m.child_entered_tree.connect(func(n: Node) -> void: _ne(n))
	var lacet0: float = m.joueur.rotation.y
	if scenario == "village":
		m.joueur.rotation.y = atan2(-(35.0 - 2.5), -(30.0 - 8.5))   # regarde la place du village (35, 30)
	var pnj_attendus: int = m._pnj_differes.size()
	print("PREUVE %s : %d villageois en attente à la fin du chargement" % [scenario, pnj_attendus])
	var jalons := [0.5, 3.0, 8.0, 14.0, 20.0, 26.0, 32.0]
	var i := 0
	while Time.get_ticks_msec() - t0 < 34000:
		await process_frame
		var s := (Time.get_ticks_msec() - t0) / 1000.0
		if scenario == "village":
			if s > 12.0 and s < 20.0:
				m.joueur.rotation.y = lacet0
			elif s >= 20.0:
				m.joueur.rotation.y = atan2(-(35.0 - 2.5), -(30.0 - 8.5))
		if i < jalons.size() and s >= jalons[i]:
			await _photo("%s_%02d_s" % [scenario, int(jalons[i])])
			i += 1
	print("PREUVE %s : %d naissances, %d visibles à l'écran (POP), %d en attente restante" % [scenario, nes, pops, m._pnj_differes.size()])
	quit()
