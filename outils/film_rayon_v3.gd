extends "res://outils/film_rayon_noir.gd"
## FILM du RAYON NOIR v3 en PLEIN AIR (portée longue) : le joueur reste dehors (pas de descente en crypte), cherche la direction libre la
## plus longue, canalise le rayon dessus (le bout est mesuré et imprimé), puis balaie vers un arbre / un relief.
## Même ligne de commande que film_rayon_noir.gd, sans --crypte : godot ... --script res://outils/film_rayon_v3.gd -- --nouvelle --paisible
##   [--palette-rayon=0|1|2] [--images=<dossier>] [--perf]

func _go() -> void:
	RetourImpact.muet = false
	_dossier = _arg("images", "")
	if _dossier != "":
		DirAccess.make_dir_recursive_absolute(_dossier)
	s = load("res://scenes/foret_test.tscn").instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	current_scene = s
	j = s.joueur
	magie = j.mains.magie
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _attendre(3.0)
	magie.eq.apprendre_tout()
	magie.equiper("droite", "epee")
	if j.touche.is_connected(magie._sur_touche):
		j.touche.disconnect(magie._sur_touche)
	_etiquette(s)
	var hud = s.get("hud")
	if hud != null:
		hud.set("aide_t", 0.0)
	var cip := root.get_node_or_null("CompteurIps")
	if cip != null:
		cip.visible = false
		cip.process_mode = Node.PROCESS_MODE_DISABLED
	if _arg("perf") != "":
		Engine.max_fps = 0
	if _arg("sans-lumiere-film") == "":
		var lf := OmniLight3D.new()
		lf.light_color = Color(0.85, 0.82, 0.8)
		lf.light_energy = 0.35
		lf.omni_range = 9.0
		lf.shadow_enabled = false
		j.add_child(lf)
		lf.position = Vector3(0.4, 1.9, 0.6)
	await _film()
	_texte("")
	await _attendre(0.6)
	print("FIN_SEQUENCE")
	if not _ips.is_empty():
		_bilan_ips()
	quit(0)

## Directions libres sur l'horizontale (±), triées de la plus longue à la plus courte : [[distance, point]...]
func _directions() -> Array:
	var o: Vector3 = j.camera.global_position
	var monde := j.get_world_3d().direct_space_state
	var res: Array = []
	for i in 48:
		var d := Vector3(cos(TAU * i / 48.0), 0.0, sin(TAU * i / 48.0)).normalized()
		var q := PhysicsRayQueryParameters3D.create(o, o + d * 60.0, 1)
		q.exclude = [j.get_rid()]
		var r := monde.intersect_ray(q)
		var dist := 60.0 if r.is_empty() else o.distance_to(r["position"])
		res.append([dist, o + d * minf(dist, 60.0)])
	res.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return res

## Cherche un endroit dégagé (grille autour du départ) : le joueur y est téléporté, tourné vers la plus grande trouée.
func _site_ouvert() -> void:
	var monde := j.get_world_3d().direct_space_state
	var base := j.global_position
	var meilleur := -1.0
	var pos := base
	for gx in range(-8, 9):
		for gz in range(-8, 9):
			var p := base + Vector3(gx * 12.0, 40.0, gz * 12.0)
			var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 120.0, 1)
			var r := monde.intersect_ray(q)
			if r.is_empty() or absf((r["normal"] as Vector3).y) < 0.9:
				continue
			var o: Vector3 = (r["position"] as Vector3) + Vector3.UP * 1.6
			var note := 0.0
			for i in 24:
				var d := Vector3(cos(TAU * i / 24.0), 0.0, sin(TAU * i / 24.0))
				var q2 := PhysicsRayQueryParameters3D.create(o, o + d * 45.0, 1)
				if monde.intersect_ray(q2).is_empty():
					note += 1.0
			if note > meilleur:
				meilleur = note
				pos = r["position"]
	print("FILM site ouvert : %d/24 directions libres à 45 m" % int(meilleur))
	j.global_position = pos + Vector3.UP * 0.3
	await _attendre(1.5)

func _film() -> void:
	await _site_ouvert()
	magie.raccourci_sort_gauche(RayonNoir.ID)
	var dirs := _directions()
	print("FILM directions libres : %.0f m, %.0f m, %.0f m" % [dirs[0][0], dirs[1][0], dirs[2][0]])
	await _regarder(dirs[0][1], 0.8)
	await _debut("Rayon noir (Y) : portée 40 m")
	_phase = "repos"
	await _attendre(3.0 if _arg("perf") != "" else 0.3)
	_phase = "loin"
	magie.appuyer("gauche")
	await _attendre(0.3)
	await _capture("allumage")
	await _attendre(1.6)
	var b: Dictionary = magie.lanceur.derniers_bouts.get("gauche", {})
	if not b.is_empty():
		print("FILM bout du rayon à %.1f m (décor %s)" % [j.camera.global_position.distance_to(b["point"]), str(b["decor"])])
	await _capture("loin")
	# plan de côté : une seconde caméra à 4 m à droite, pour voir le rayon dans toute sa longueur
	_phase = "cote"
	_texte("vue de côté : portée 40 m, tout droit")
	var cam := Camera3D.new()
	cam.fov = 62.0
	s.add_child(cam)
	var o: Vector3 = j.camera.global_position
	var av: Vector3 = -j.camera.global_basis.z
	var dr := av.cross(Vector3.UP).normalized()
	for k in 3:
		var u := float(k) / 2.0
		cam.global_position = o + dr * (3.2 + 1.5 * u) + Vector3.UP * (0.5 + 0.6 * u) - av * (1.5 - 2.5 * u)
		cam.look_at(o + av * (9.0 + 8.0 * u), Vector3.UP)
		cam.make_current()
		await _attendre(0.6 if k < 2 else 0.5)
		if k == 0:
			await _capture("cote")
	j.camera.make_current()
	cam.queue_free()
	_phase = "balayage"
	_texte("il part tout droit, très loin")
	await _regarder(dirs[1][1], 1.8)
	await _capture("balayage")
	var b2: Dictionary = magie.lanceur.derniers_bouts.get("gauche", {})
	if not b2.is_empty():
		print("FILM bout du rayon à %.1f m" % j.camera.global_position.distance_to(b2["point"]))
	await _attendre(1.2)
	_phase = "fin"
	_texte("relâcher : il se dissipe")
	magie.relacher("gauche")
	await _attendre(0.2)
	await _capture("arret")
	await _attendre(1.0)
