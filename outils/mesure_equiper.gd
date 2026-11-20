extends SceneTree
## Coût d'un ÉQUIPEMENT d'arme en partie (opti saccades 2026-11-20) : durée de l'appel equiper (signaux : mains 1re personne, corps 3e personne,
## magie) puis de l'image suivante, pour chaque arme, 1re fois puis 2e fois ; et le détail : effet d'élément seul, couche de neige.
##   godot --path . --disable-vsync --script res://outils/mesure_equiper.gd -- --nouvelle --paisible [--armes=epee_hrafn,epee_metal,...]
## Sortie : « EQUIP <arme> <passage> appel=.. image=.. » puis « EQUIP_DETAIL … ».
const SCENE := preload("res://scenes/foret_test.tscn")

func _init() -> void:
	_go.call_deferred()

func _image() -> float:
	var t := Time.get_ticks_usec()
	await process_frame
	return (Time.get_ticks_usec() - t) / 1000.0

func _go() -> void:
	var m: Node3D = SCENE.instantiate()
	Jeu.chargement_etale = true
	paused = true
	root.add_child(m)
	current_scene = m
	while m.get("pret") != true:
		await process_frame
	Jeu.chargement_etale = false
	paused = false
	for k in 120:
		await process_frame
	var j = m.joueur
	var ids := "epee_hrafn,epee_metal,epee_verre,epee_obsidienne,hache_kolbeinn,epee_hrafn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--armes="):
			ids = a.substr(8)
	var vus := {}
	for id in ids.split(","):
		var d := load("res://data/armes/%s.tres" % id) as DonneesArme
		if d == null:
			continue
		var t0 := Time.get_ticks_usec()
		j.mains.equipement.equiper("droite", d)
		var appel := (Time.get_ticks_usec() - t0) / 1000.0
		var im := await _image()
		var im2 := await _image()
		vus[id] = int(vus.get(id, 0)) + 1
		print("EQUIP %-16s passage=%d appel=%.1f ms image_suivante=%.1f ms puis %.1f ms element=%s" % [id, vus[id], appel, im, im2, d.element_type])
		for k in 30:
			await process_frame
	# détail : effet d'élément seul (nœud vide), 1re fois par élément
	for t: String in EffetElementLame.TYPES:
		var n := Node3D.new()
		m.add_child(n)
		var t0 := Time.get_ticks_usec()
		EffetElementLame.poser_type(n, t, Vector3.ZERO, Vector3(0, 0.8, 0))
		var appel := (Time.get_ticks_usec() - t0) / 1000.0
		var im := await _image()
		print("EQUIP_DETAIL effet_element %s appel=%.1f image=%.1f" % [t, appel, im])
		n.queue_free()
	var t1 := Time.get_ticks_usec()
	var c := CoucheNeige.creer(m)
	print("EQUIP_DETAIL couche_neige creer=%.1f ms (%s) image=%.1f" % [(Time.get_ticks_usec() - t1) / 1000.0, c != null, await _image()])
	quit(0)
