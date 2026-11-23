extends "res://outils/film_sorts_esprit.gd"
## FILM du RAYON NOIR (sort continu des ténèbres : data/sorts/rayon_noir.tres, scripts/magie/rayon_noir.gd) en vue FPS, dans la crypte,
## pilote automatique : canalisation sur un draugr qui approche, balayage vers un squelette, puis vers un mur (le rayon s'y arrête,
## la tache ronge et en laisse d'autres), runes qui glissent le long du rayon, relâchement (le rayon se dissipe en fumée).
## Réutilise l'outillage de film_sorts_esprit.gd (crypte, ennemis à IA active, regard lissé, captures).
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/film_rayon_noir.gd -- --nouvelle
##         --crypte=0,-24,0,-4 --paisible [--images=<dossier>] [--zoom=<fov>] [--sans-lumiere-film] [--perf]
## --zoom : champ de vision réduit (planche de gros plans) ; --perf : imprime les FPS (moyenne par phase) au lieu d'un film.
## Lumière de tournage (film seulement) : une lueur neutre très faible près du joueur (--sans-lumiere-film la coupe).

var _ips: Array = []
var _phase := ""

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
	var y0 := j.global_position.y
	var n := 0
	while n < 30 * 60 and not (s.tertre != null and s.tertre.dedans and j.global_position.y < y0 - 3.0):
		await process_frame
		n += 1
	await _attendre(2.5)
	magie.eq.apprendre_tout()
	magie.equiper("droite", "epee")
	if j.touche.is_connected(magie._sur_touche):
		j.touche.disconnect(magie._sur_touche)   # film : les coups reçus n'interrompent pas le sort
	_etiquette(s)
	var hud = s.get("hud")
	if hud != null:
		hud.set("aide_t", 0.0)
	var cip := root.get_node_or_null("CompteurIps")
	if cip != null:
		cip.visible = false
		cip.process_mode = Node.PROCESS_MODE_DISABLED
	if _arg("perf") != "":
		Engine.max_fps = 0   # mesure : pas de plafond (option « limite d'IPS »)
	if _arg("zoom") != "":
		j.camera.fov = float(_arg("zoom"))
	if _arg("sans-lumiere-film") == "":
		var lf := OmniLight3D.new()
		lf.light_color = Color(0.85, 0.82, 0.8)
		lf.light_energy = 0.35
		lf.omni_range = 9.0
		lf.shadow_enabled = false
		j.add_child(lf)
		lf.position = Vector3(0.4, 1.9, 0.6)
	await _regarder(_devant(5.0) + Vector3.UP * 1.4, 0.1)
	await _film()
	_texte("")
	await _attendre(0.6)
	print("FIN_SEQUENCE")
	for e in magie.journal.slice(-20):
		print("MAGIE ", e)
	if not _ips.is_empty():
		_bilan_ips()
	quit(0)

## Une image (comme film_sorts_esprit) + relevé des FPS réels (--perf).
func _image() -> void:
	_t_film += DT
	if j != null:
		j.vie = j.vie_max
	await process_frame
	if _arg("perf") != "":
		_ips.append([_phase, Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])

func _bilan_ips() -> void:
	var par := {}
	for e in _ips:
		if not par.has(e[0]):
			par[e[0]] = []
		(par[e[0]] as Array).append(float(e[1]))
	for k in par:
		var l: Array = par[k]
		l.sort()
		var moy := 0.0
		for v in l:
			moy += v
		print("IPS %s : moyenne %.1f, min %.1f, médiane %.1f (%d images)" % [k, moy / l.size(), l[0], l[l.size() / 2], l.size()])

## Direction (depuis l'œil) d'un mur entre 3,5 et 8 m, en tournant de ±50 à ±140° : point visé et un second point à côté (balayage).
func _mur() -> Array:
	var o: Vector3 = j.camera.global_position
	var av := -j.global_basis.z
	av.y = 0.0
	av = av.normalized()
	var monde := j.get_world_3d().direct_space_state
	var meilleur: Array = []
	var note_max := -1.0
	for i in 36:
		var deg := 60.0 + 240.0 * float(i) / 35.0   # derrière les ennemis (devant : 0°)
		var d := (av.rotated(Vector3.UP, deg_to_rad(deg)) + Vector3.DOWN * 0.12).normalized()
		var q := PhysicsRayQueryParameters3D.create(o, o + d * 9.0, 1)
		q.exclude = [j.get_rid()]
		var r := monde.intersect_ray(q)
		if r.is_empty():
			continue
		var p: Vector3 = r["position"]
		var nrm: Vector3 = r["normal"]
		var dist := o.distance_to(p)
		var face := nrm.dot(-d)
		if dist < 3.5 or dist > 7.5 or absf(nrm.y) > 0.3 or face < 0.7:
			continue
		# second point : 1,8 m le long du mur, plus bas ; il doit être sur le même mur, visible
		var lat := nrm.cross(Vector3.UP).normalized()
		var p2 := p + lat * 1.8 + Vector3.DOWN * 0.35
		var q2 := PhysicsRayQueryParameters3D.create(o, p2 + (p2 - o).normalized() * 0.3, 1)
		q2.exclude = [j.get_rid()]
		var r2 := monde.intersect_ray(q2)
		if r2.is_empty() or (r2["position"] as Vector3).distance_to(p2) > 0.35:
			continue
		# mur franc : quatre points à 0,9 m autour sont sur le même plan (pas une arête de pilier)
		var plat := true
		var w2 := nrm.cross(lat)
		for dv: Vector3 in [lat, -lat, w2, -w2]:
			var a := p + nrm * 0.25 + dv * 0.9
			var q3 := PhysicsRayQueryParameters3D.create(a, a - nrm * 0.5, 1)
			var r3 := monde.intersect_ray(q3)
			if r3.is_empty() or absf(((r3["position"] as Vector3) - p).dot(nrm)) > 0.06:
				plat = false
				break
		if not plat:
			continue
		var note := face - absf(dist - 5.0) * 0.1
		if note > note_max:
			note_max = note
			meilleur = [p, p2]
	if meilleur.is_empty():
		print("FILM pas de mur franc trouvé")
		return [_devant(6.0, 3.0) + Vector3.UP * 1.2, _devant(6.0, 4.5) + Vector3.UP * 0.8]
	print("FILM mur à %.1f m" % o.distance_to(meilleur[0]))
	return meilleur

func _film() -> void:
	magie.raccourci_sort_gauche(RayonNoir.ID)   # touche Y : rayon noir dans la main gauche
	var dr := _draugr(_libre(8.0, -0.8), "guerrier")
	var sq := _draugr(_libre(7.0, 2.4), "squelette")
	await _attendre(0.3)
	await _debut("Rayon noir (Y) : maintenir — 9 mana /s")
	# film : ils avancent au pas (la charge contre un lanceur, ~4,8 m/s, les collerait au joueur en 1 s et masquerait le rayon)
	for d in [dr, sq]:
		d.set("_course", 0.9)
		_ia(d)
	await _regarder(Elements._centre(dr), 0.35)
	_phase = "repos"
	await _attendre(3.0 if _arg("perf") != "" else 0.3)   # --perf : 3 s de référence (même cadrage, sans rayon)
	# 1) sur le draugr : allumage depuis la main, l'ombre rampe sur lui
	_phase = "draugr"
	magie.appuyer("gauche")
	await _attendre(0.26)
	await _capture("allumage")
	await _regarder(Vector3.ZERO, 0.6, dr)
	await _capture("draugr")
	_texte("l'ombre ronge le draugr (corruption)")
	await _regarder(Vector3.ZERO, 2.1, dr)
	await _capture("draugr_runes")
	# 2) balayage vers le squelette
	_phase = "squelette"
	_texte("balayage : le squelette")
	await _regarder(Elements._centre(sq) if is_instance_valid(sq) else _devant(5.0, 2.0) + Vector3.UP, 0.55, null)
	await _regarder(Vector3.ZERO, 1.6, sq if SortsEsprit.vivant(sq) else null)
	await _capture("squelette")
	print("FILM draugr %.0f PV ; squelette %.0f PV" % [float(dr.vie), float(sq.vie)])
	# 3) vers le mur : le rayon s'arrête à la paroi, la tache ronge, le balayage en laisse d'autres (les ennemis s'arrêtent : ils ne
	#    passent pas dans le rayon pendant ce plan)
	for d in [dr, sq]:
		if is_instance_valid(d):
			d.queue_free()   # hors du plan du mur (sinon ils reviennent dans le rayon, et leur indicateur d'attaque reste à l'écran)
	_phase = "mur"
	var murs := _mur()   # cherché ICI (le joueur a pu être poussé par les ennemis)
	_texte("il s'arrête au premier obstacle")
	await _regarder(murs[0], 0.5)
	await _attendre(1.0)
	await _capture("mur")
	await _regarder(murs[1], 1.4)
	await _capture("balayage")
	# 4) relâcher : le rayon se dissipe en fumée
	_phase = "fin"
	if _arg("perf") != "":
		_phase = "mur_tenu"
		await _attendre(3.0)   # --perf : 3 s de plus rayon tenu sur le mur (taches, fumée)
		_phase = "fin"
	_texte("relâcher : il se dissipe")
	magie.relacher("gauche")
	await _attendre(0.15)
	await _capture("arret")
	await _attendre(1.2)
	print("FILM mana restant %.1f" % j.mana)
