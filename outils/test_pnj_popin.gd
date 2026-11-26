extends SceneTree
## Bug « pop-in » des PNJ (exe 6, 2026-11-26) : « il n'y avait plus personne et d'un coup je me retourne, il y a tous les PNJ ».
## Nouvelle partie par le chemin de l'écran de chargement (chargement étalé, arbre en pause, 3D coupée), puis à t = fin du chargement + 1 s :
## tous les PNJ (villageois + gardes) à moins de RAYON m du joueur existent, sont visibles (is_visible_in_tree) et, pour chaque cap
## de 30 en 30° (tour complet), ceux qui sont dans le champ de la caméra sont VRAIMENT dessinés : au moins une de leurs pièces est
## retenue par le culling du serveur de rendu (RenderingServer.instances_cull_convex : boîte englobante réelle, peau comprise).
##   godot --path . --script res://outils/test_pnj_popin.gd -- --nouvelle   (FENÊTRE hors écran : le culling a besoin du vrai rendu)
##   --sans-attente : mesure dès la fin du chargement ; --ips : IPS moyens/min sur 3 s (tour sur soi) en plus
const SCENE_CHEMIN := "res://scenes/foret_test.tscn"
const RAYON := 40.0
var _ok := true

func _verif(c: bool, msg: String) -> void:
	print(("OK    " if c else "ECHEC ") + msg)
	if not c:
		_ok = false

func _init() -> void:
	_go.call_deferred()

func _pnj(m: Node) -> Array:
	var l: Array = []
	for g in ["villageois", "gardes_village"]:
		for v in get_nodes_in_group(g):
			if v is Node3D and not l.has(v):
				l.append(v)
	return l

## RID d'instance des pièces dessinables d'un PNJ (pièces visibles seulement).
func _rids(v: Node) -> Array:
	var l: Array = []
	for gi: GeometryInstance3D in v.find_children("*", "GeometryInstance3D", true, false):
		if gi.is_visible_in_tree() and gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			l.append(gi.get_instance())
	return l

func _go() -> void:
	var t_lancement := Time.get_ticks_msec()
	var m: Node3D
	if OS.get_cmdline_user_args().has("--vrai"):
		# chemin EXACT du bouton « Nouvelle partie » (EcranTitre._lancer) : écran de chargement, scène lue en fond, fin du fondu
		Jeu.nouvelle_partie = true
		var ecran: CanvasLayer = load("res://scripts/ecran_chargement.gd").new()
		ecran.scene_jeu = Jeu.SCENE_JEU
		root.add_child(ecran)
		ecran.demarrer()
		await ecran.termine
		m = current_scene as Node3D
		print("chargement (écran de chargement, fondu compris) : %.1f s" % ((Time.get_ticks_msec() - t_lancement) / 1000.0))
	else:
		Jeu.chargement_etale = true
		m = (load(SCENE_CHEMIN) as PackedScene).instantiate()
		paused = true
		root.get_viewport().disable_3d = true
		root.add_child(m)
		current_scene = m
		while m.get("pret") != true:
			await process_frame
		print("chargement : %.1f s" % ((Time.get_ticks_msec() - t_lancement) / 1000.0))
		Jeu.chargement_etale = false
		root.get_viewport().disable_3d = false
		paused = false
	var j: Node3D = m.joueur
	if _arg("a") != "":
		var f := _arg("a").split_floats(",")
		j.global_position = Vector3(f[0], m.hauteur(f[0], f[1]) + 0.1, f[1])
	var cam := root.get_viewport().get_camera_3d()
	if _arg("film") != "":
		await _film(j, _arg("film"))
	var en_attente := (m.get("_pnj_differes") as Array).size()
	_verif(en_attente == 0, "fin du chargement : %d villageois encore à naître" % en_attente)
	if not OS.get_cmdline_user_args().has("--sans-attente"):
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 1000:
			await process_frame
	var proches: Array = []
	for v in _pnj(m):
		if v.is_inside_tree() and (v as Node3D).global_position.distance_to(j.global_position) < RAYON:
			proches.append(v)
	print("joueur en %s, %d PNJ à moins de %d m" % [str(j.global_position), proches.size(), int(RAYON)])
	_verif(proches.size() >= 5, "au moins 5 PNJ à moins de %d m du départ (%d)" % [int(RAYON), proches.size()])
	var caches: Array = []
	for v in proches:
		var dort: bool = v.has_method("est_endormi") and v.est_endormi()
		if not (v as Node3D).is_visible_in_tree() and not dort:
			caches.append(String(v.name))
	_verif(caches.is_empty(), "PNJ proches visibles (is_visible_in_tree) — cachés : %s" % str(caches))
	# tour sur soi : 12 caps, 3 images chacun (le culling suit l'image rendue)
	var lacet0: float = j.rotation.y
	var manques := {}
	var vus := 0
	var ips: Array = []
	for k in 12:
		j.rotation.y = lacet0 + deg_to_rad(30.0 * k)
		for _i in 3:
			await process_frame
		var planes := cam.get_frustum()
		var dans := {}
		for id in RenderingServer.instances_cull_convex(planes, root.get_world_3d().scenario):
			dans[id] = true
		for v in proches:
			if not (v as Node3D).is_visible_in_tree():
				continue
			var p: Vector3 = (v as Node3D).global_position + Vector3(0, 1.0, 0)
			if not cam.is_position_in_frustum(p) or cam.global_position.distance_to(p) < 1.0:
				continue
			vus += 1
			var dessine := false
			for gi: GeometryInstance3D in v.find_children("*", "GeometryInstance3D", true, false):
				if gi.is_visible_in_tree() and dans.has(gi.get_instance_id()):
					dessine = true
					break
			if not dessine:
				manques[String(v.name)] = int(manques.get(String(v.name), 0)) + 1
	_verif(vus > 0 and manques.is_empty(), "tour de 360° : %d PNJ×cap dans le champ, non dessinés (culling) : %s" % [vus, str(manques)])
	if OS.get_cmdline_user_args().has("--ips"):
		var n := 0
		var t2 := Time.get_ticks_usec()
		var pire := 0.0
		var tp := t2
		while Time.get_ticks_usec() - t2 < 3000000:
			j.rotation.y += deg_to_rad(2.0)
			await process_frame
			var now := Time.get_ticks_usec()
			pire = maxf(pire, (now - tp) / 1000.0)
			tp = now
			n += 1
		print("IPS (tour sur soi, 3 s) : moyenne %.1f, pire image %.1f ms (%.0f IPS)" % [n / ((tp - t2) / 1000000.0), pire, 1000.0 / maxf(pire, 0.001)])
	if _arg("marche") != "":
		await _marche(m, j, cam, _arg("marche"))
	if _arg("suivi") != "":
		await _suivi(m, j, cam, float(_arg("suivi")))
	print("VERDICT " + ("OK" if _ok else "ECHEC"))
	quit(0 if _ok else 1)

func _arg(n: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + n + "="):
			return a.substr(n.length() + 3)
	return ""

## --suivi=S : S secondes de jeu, tour sur soi à 30°/s ; toutes les 0,5 s, PNJ à moins de 60 m : visibles / dans le champ / dessinés.
func _suivi(m: Node, j: Node3D, cam: Camera3D, duree: float) -> void:
	var t := 0.0
	var prochain := 0.0
	var prec := ""
	while t < duree:
		await process_frame
		var dt := 1.0 / 60.0
		t += dt
		j.rotation.y += deg_to_rad(30.0) * dt
		if t < prochain:
			continue
		prochain += 0.5
		var dans := {}
		for id in RenderingServer.instances_cull_convex(cam.get_frustum(), root.get_world_3d().scenario):
			dans[id] = true
		var n := 0
		var vis := 0
		var champ := 0
		var dess := 0
		for v in _pnj(m):
			if not v.is_inside_tree() or (v as Node3D).global_position.distance_to(j.global_position) > 60.0:
				continue
			n += 1
			if not (v as Node3D).is_visible_in_tree():
				continue
			vis += 1
			if cam.is_position_in_frustum((v as Node3D).global_position + Vector3(0, 1, 0)):
				champ += 1
				for gi: GeometryInstance3D in v.find_children("*", "GeometryInstance3D", true, false):
					if gi.is_visible_in_tree() and dans.has(gi.get_instance_id()):
						dess += 1
						break
		var l := "%d/%d vis, %d champ, %d dessinés" % [vis, n, champ, dess]
		if champ != dess:
			_verif(false, "t=%.1f s : %s" % [t, l])
		if l != prec:
			print("SUIVI t=%.1f h=%.2f %s" % [t, float(m.cycle.heure), l])
			prec = l

## --film=<dossier> : images de la vue joueur dès la fin du chargement : 1 s immobile puis un tour sur soi en 8 s (une image sur 2, 30 i/s).
func _film(j: Node3D, dossier: String) -> void:
	DirAccess.make_dir_recursive_absolute(dossier)
	var l0 := j.rotation.y
	var k := 0
	for f in 540:
		if f >= 60:
			j.rotation.y = l0 + TAU * float(f - 60) / 480.0
		await process_frame
		if f % 2 == 0:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(dossier.path_join("f_%04d.png" % k))
			k += 1
	j.rotation.y = l0

## --marche=x,z[,dossier] : le joueur va du départ au point (x, z) en 15 s (face à lui), puis tourne sur lui-même en 8 s ; toutes les
## 0,25 s : PNJ à moins de 70 m dans le champ / dessinés ; images de la vue (une sur 2) si un dossier est donné.
func _marche(m: Node, j: Node3D, cam: Camera3D, a: String) -> void:
	var parts := a.split(",")
	var cible := Vector2(float(parts[0]), float(parts[1]))
	var dossier := parts[2] if parts.size() > 2 else ""
	if dossier != "":
		DirAccess.make_dir_recursive_absolute(dossier)
	var p0 := Vector2(j.global_position.x, j.global_position.z)
	var cap := atan2(-(cible.x - p0.x), -(cible.y - p0.y))
	var k := 0
	var prec := ""
	for f in 23 * 60:
		var t := f / 60.0
		if t < 15.0:
			var q := p0.lerp(cible, t / 15.0)
			j.global_position = Vector3(q.x, m.hauteur(q.x, q.y) + 0.1, q.y)
			j.rotation.y = cap
		else:
			j.rotation.y = cap + TAU * (t - 15.0) / 8.0
		await process_frame
		if dossier != "" and f % 2 == 0:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(dossier.path_join("f_%04d.png" % k))
			k += 1
		if f % 15 != 0:
			continue
		var dans := {}
		for id in RenderingServer.instances_cull_convex(cam.get_frustum(), root.get_world_3d().scenario):
			dans[id] = true
		var champ := 0
		var dess := 0
		var vis := 0
		var n := 0
		for v in _pnj(m):
			if not v.is_inside_tree() or (v as Node3D).global_position.distance_to(j.global_position) > 70.0:
				continue
			n += 1
			if not (v as Node3D).is_visible_in_tree():
				continue
			vis += 1
			if cam.is_position_in_frustum((v as Node3D).global_position + Vector3(0, 1, 0)):
				champ += 1
				for gi: GeometryInstance3D in v.find_children("*", "GeometryInstance3D", true, false):
					if gi.is_visible_in_tree() and dans.has(gi.get_instance_id()):
						dess += 1
						break
		var l := "%d/%d vis, %d champ, %d dessinés" % [vis, n, champ, dess]
		if l != prec:
			print("MARCHE t=%.2f %s" % [t, l])
			prec = l
