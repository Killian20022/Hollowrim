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

var _cibles: Array = []

## ARÈNE DÉGAGÉE : grande dalle claire et trois monolithes (à 14, 26 et 38 m), bâtie à 500 m d'altitude (au-dessus du monde, même ciel
## et même lune) : plus d'arbres entre la caméra et le rayon. Le joueur y est téléporté, regardant vers -Z.
func _site_ouvert() -> void:
	var base := Vector3(0.0, 500.0, 0.0)
	var sol := StaticBody3D.new()
	sol.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(300, 1, 300)
	cs.shape = bx
	sol.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bx.size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.36, 0.46)
	m.roughness = 1.0
	mi.material_override = m
	sol.add_child(mi)
	s.add_child(sol)
	sol.global_position = base + Vector3(0, -0.5, 0)
	var piliers := [[Vector3(-5, 0, -14), Vector3(2.5, 6, 2.5)], [Vector3(6, 0, -26), Vector3(3, 8, 3)], [Vector3(0, 0, -38), Vector3(12, 9, 1.5)]]
	_cibles.clear()
	for e in piliers:
		var pb := StaticBody3D.new()
		pb.collision_layer = 1
		var c2 := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		b2.size = e[1]
		c2.shape = b2
		pb.add_child(c2)
		var m2 := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = e[1]
		m2.mesh = bm2
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.2, 0.2, 0.24)
		mt.roughness = 1.0
		m2.material_override = mt
		pb.add_child(m2)
		s.add_child(pb)
		pb.global_position = base + (e[0] as Vector3) + Vector3(0, (e[1] as Vector3).y * 0.5, 0)
		_cibles.append(pb.global_position + Vector3(0, 1.4 - (e[1] as Vector3).y * 0.5 + 0.2, 0))
	j.global_position = base + Vector3(0, 0.3, 0)
	j.velocity = Vector3.ZERO
	j.rotation.y = 0.0
	await _attendre(1.5)

func _directions() -> Array:
	var o: Vector3 = j.camera.global_position
	return [[38.0, Vector3(o.x, o.y, -38.0)], [26.0, _cibles[1] + Vector3(0, 0.8, 0)], [14.0, _cibles[0] + Vector3(0, 0.8, 0)]]

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
		cam.global_position = o + dr * (4.0 + 2.0 * u) + Vector3.UP * (2.2 + 0.8 * u) - av * (1.5 - 2.5 * u)
		cam.look_at(o + av * (9.0 + 8.0 * u), Vector3.UP)
		cam.make_current()
		await _attendre(0.6 if k < 2 else 0.5)
		if k < 3:
			await _capture("cote%d" % k)
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
