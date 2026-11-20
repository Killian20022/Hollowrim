extends SceneTree
## Recensement de la physique du monde réel + coût d'encodage de la réplication (passe d'optimisation 2026-11-20, physique_reseau_exe).
##   godot --headless --path . --script res://outils/recensement_physique.gd -- --nouvelle --paisible [--attente=20] [--pos=x,z [--rayon=6] [--essai-hm]]
## Imprime : corps par type, formes par type (faces des trimesh), rigides éveillés (dans l'espace physique), _physics_process actifs,
## temps physique moyen (TIME_PHYSICS_PROCESS = scripts + Jolt + requêtes), puis le coût d'UN tick d'envoi de Replicateur côté hôte
## (fournisseurs + quantification + var_to_bytes de toutes les entités) et, avec l'opti, des seules entités attendues par un pair.
## --pos : joueur posé là ; formes touchées dans un rayon, coût de move_and_slide du joueur (µs/appel) ; --essai-hm : même mesure sans
## le terrain maillé, puis avec le terrain en HeightMapShape3D (essai, rien n'est gardé).
func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + nom:
			return "1"
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _go() -> void:
	var m: Node = (load(Jeu.SCENE_JEU) as PackedScene).instantiate()
	root.add_child(m)
	current_scene = m
	var t0 := Time.get_ticks_msec()
	while m.get("pret") != true and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
	await create_timer(float(_arg("attente", "20"))).timeout
	_recenser(m)
	await _temps_physique("tel quel")
	await _replication(m)
	if _arg("pos") != "":
		await _autour(m)
	quit(0)

func _temps_physique(et: String) -> void:
	var s := 0.0
	for k in 120:
		await physics_frame
		s += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	print("RECENS temps physique (%s) : %.2f ms par image physique (moyenne 120)" % [et, s / 120.0])

func _recenser(_m: Node) -> void:
	var corps := {}
	var formes := {}
	var faces_trimesh := 0
	var trimesh_max := 0
	var rig_eveil := 0
	var rig_hors := 0
	var phys_script := {}
	var groupes := {}
	for n in root.find_children("*", "", true, false):
		if n is CollisionObject3D:
			var c := n.get_class()
			corps[c] = int(corps.get(c, 0)) + 1
			if n is RigidBody3D:
				var rb := n as RigidBody3D
				if not rb.can_process() and rb.disable_mode == CollisionObject3D.DISABLE_MODE_REMOVE:
					rig_hors += 1
				elif not (rb.sleeping or rb.freeze):
					rig_eveil += 1
		if n is CollisionShape3D and (n as CollisionShape3D).shape != null and not (n as CollisionShape3D).disabled:
			var sh: Shape3D = (n as CollisionShape3D).shape
			var cs := sh.get_class()
			formes[cs] = int(formes.get(cs, 0)) + 1
			if sh is ConcavePolygonShape3D:
				var f := (sh as ConcavePolygonShape3D).get_faces().size() / 3
				faces_trimesh += f
				trimesh_max = maxi(trimesh_max, f)
			var pa := n.get_parent().get_parent()
			var k2: String = cs + " sous " + (String(pa.name).rstrip("0123456789_@") if pa != null else "?")
			groupes[k2] = int(groupes.get(k2, 0)) + 1
		if n.is_physics_processing() and n.get_script() != null:
			var nom: String = (n.get_script() as Script).resource_path.get_file()
			phys_script[nom] = int(phys_script.get(nom, 0)) + 1
	print("RECENS corps : %s" % str(corps))
	print("RECENS formes : %s ; trimesh : %d faces au total, %d max" % [str(formes), faces_trimesh, trimesh_max])
	print("RECENS rigides dans l'espace et éveillés=%d ; hors de l'espace (process désactivé)=%d" % [rig_eveil, rig_hors])
	print("RECENS formes par grand-parent : " + _top(groupes, 14))
	print("RECENS _physics_process actifs : " + _top(phys_script, 15))
	print("RECENS ticks=%d max_pas=%d" % [Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame])

func _top(d: Dictionary, n: int) -> String:
	var cles := d.keys()
	cles.sort_custom(func(a, b): return d[a] > d[b])
	var l: Array = []
	for k in cles.slice(0, n):
		l.append("%s=%d" % [k, d[k]])
	return ", ".join(l)

func _replication(m: Node) -> void:
	var rep: Node = root.get_node_or_null("Replicateur")
	if rep == null:
		print("RECENS pas de Replicateur")
		return
	var ent: Dictionary = rep.get("_ent")
	var j: Node3D = m.get("joueur")
	var pos := j.global_position
	var avant := []
	for essai in 8:
		var t0 := Time.get_ticks_usec()
		for id in ent:
			var e: Dictionary = ent[id]
			if not is_instance_valid(e["noeud"]) or not (e["four"] as Callable).is_valid():
				continue
			var _o := var_to_bytes(rep.call("_quantifier", (e["four"] as Callable).call()))
		avant.append((Time.get_ticks_usec() - t0) / 1000.0)
		await process_frame
	var pert := 0
	var proches := 0
	for id in ent:
		var e: Dictionary = ent[id]
		if is_instance_valid(e["noeud"]) and rep.call("_pertinent", e, pos):
			pert += 1
			if (e["noeud"] as Node3D).global_position.distance_to(pos) <= 40.0:
				proches += 1
	print("RECENS réplication AVANT : %d entités, encodage d'un tick hôte : moyenne %.3f ms (max %.3f) ; pertinentes pour un pair au joueur local : %d (dont %d à < 40 m)" % [
		ent.size(), _moy(avant), avant.max(), pert, proches])
	if not rep.has_method("_attendu"):
		return
	var apres := []
	var nb := 0
	for essai in 8:
		rep.set("_tick", essai)
		var t1 := Time.get_ticks_usec()
		for id in ent:
			var e: Dictionary = ent[id]
			if not is_instance_valid(e["noeud"]) or not rep.call("_attendu", id, e, [pos]):
				continue
			nb += 1
			var _o := var_to_bytes(rep.call("_quantifier", (e["four"] as Callable).call()))
		apres.append((Time.get_ticks_usec() - t1) / 1000.0)
		await process_frame
	print("RECENS réplication APRÈS opti (1 pair au joueur local) : moyenne %.3f ms par tick (max %.3f), %.1f entités encodées par tick" % [_moy(apres), apres.max(), nb / 8.0])

func _moy(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / maxf(1.0, a.size())

## --pos=x,z : joueur posé là ; formes touchées dans un rayon, coût de move_and_slide du joueur.
func _autour(m: Node) -> void:
	var p := _arg("pos").split(",")
	var j: CharacterBody3D = m.get("joueur")
	var x := float(p[0])
	var z := float(p[1])
	j.global_position = Vector3(x, m.call("hauteur", x, z) + 0.1, z)
	for k in 30:
		await physics_frame
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = float(_arg("rayon", "6"))
	q.shape = sph
	q.transform = Transform3D(Basis(), j.global_position)
	q.collision_mask = j.collision_mask
	var res := j.get_world_3d().direct_space_state.intersect_shape(q, 512)
	var vus := {}
	for r in res:
		var co: CollisionObject3D = r["collider"]
		var own := co.shape_find_owner(int(r["shape"]))
		var ow: Object = co.shape_owner_get_owner(own)
		var sh: Shape3D = (ow as CollisionShape3D).shape if ow is CollisionShape3D else null
		if sh == null:
			continue
		var f := (sh as ConcavePolygonShape3D).get_faces().size() / 3 if sh is ConcavePolygonShape3D else 0
		vus[str(co.get_path()).right(70) + " " + sh.get_class() + (" faces=%d" % f if f > 0 else "")] = true
	print("AUTOUR %d formes distinctes à %.0f m de (%.1f, %.1f) :" % [vus.size(), sph.radius, x, z])
	for k in vus:
		print("AUTOUR   " + k)
	var pied := j.global_position
	print("AUTOUR move_and_slide joueur (tel quel) : %.0f µs/appel" % await _mas(j, pied))
	if _arg("essai-hm") == "":
		return
	var ct: StaticBody3D = m.get_meta("corps_terrain")
	var couche := ct.collision_layer
	ct.collision_layer = 0
	await physics_frame
	print("AUTOUR move_and_slide joueur (SANS terrain) : %.0f µs/appel" % await _mas(j, pied))
	var hm := HeightMapShape3D.new()
	var n: int = m.CASES + 1
	hm.map_width = n
	hm.map_depth = n
	var d := PackedFloat32Array()
	d.resize(n * n)
	var h64: PackedFloat64Array = m.hauteurs_maillage
	for i in n * n:
		d[i] = h64[i]
	hm.map_data = d
	var b := StaticBody3D.new()
	b.collision_layer = couche
	var cs := CollisionShape3D.new()
	cs.shape = hm
	var pas: float = m.TAILLE / m.CASES
	cs.scale = Vector3(pas, 1.0, pas)
	b.add_child(cs)
	m.add_child(b)
	await physics_frame
	print("AUTOUR move_and_slide joueur (terrain en HeightMapShape3D) : %.0f µs/appel" % await _mas(j, pied))
	b.queue_free()
	ct.collision_layer = couche

func _mas(j: CharacterBody3D, pied: Vector3) -> float:
	var nb := 0
	for k in 120:
		if k % 4 == 0:
			j.global_position = pied
		j.velocity = Vector3(sin(k * 0.3) * 4.0, -1.0, cos(k * 0.3) * 4.0)
		var t1 := Time.get_ticks_usec()
		j.move_and_slide()
		nb += Time.get_ticks_usec() - t1
		if k % 4 == 3:
			await physics_frame
	return nb / 120.0
