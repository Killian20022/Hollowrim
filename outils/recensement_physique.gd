extends SceneTree
## Recensement de la physique du monde réel + coût d'encodage de la réplication (passe d'optimisation 2026-11-20, physique_reseau_exe).
##   godot --headless --path . --script res://outils/recensement_physique.gd -- --nouvelle [--attente=20] [--lieu=village|crypte]
## Imprime : corps par type (statiques, cinématiques/joueur, rigides éveillés/endormis, aires surveillantes), formes par type
## (dont faces des trimesh), puis le coût d'UN tick d'envoi de Replicateur côté hôte (fournisseurs + quantification + var_to_bytes
## de toutes les entités enregistrées) et la part réellement pertinente pour un joueur placé au joueur local.
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
	_replication(m)
	quit(0)

func _recenser(m: Node) -> void:
	var corps := {}
	var formes := {}
	var faces_trimesh := 0
	var trimesh_max := 0
	var aires_surv := 0
	var rig_eveil := 0
	var rig_dort := 0
	var phys_script := {}
	for n in root.find_children("*", "", true, false):
		if n is CollisionObject3D:
			var c := n.get_class()
			corps[c] = int(corps.get(c, 0)) + 1
			if n is RigidBody3D:
				if (n as RigidBody3D).sleeping or (n as RigidBody3D).freeze:
					rig_dort += 1
				else:
					rig_eveil += 1
			if n is Area3D and (n as Area3D).monitoring:
				aires_surv += 1
		if n is CollisionShape3D and (n as CollisionShape3D).shape != null and not (n as CollisionShape3D).disabled:
			var s: Shape3D = (n as CollisionShape3D).shape
			var cs := s.get_class()
			formes[cs] = int(formes.get(cs, 0)) + 1
			if s is ConcavePolygonShape3D:
				var f := (s as ConcavePolygonShape3D).get_faces().size() / 3
				faces_trimesh += f
				trimesh_max = maxi(trimesh_max, f)
		if n.is_physics_processing() and n.get_script() != null:
			var nom: String = (n.get_script() as Script).resource_path.get_file()
			phys_script[nom] = int(phys_script.get(nom, 0)) + 1
	print("RECENS corps : %s" % str(corps))
	print("RECENS formes : %s ; trimesh : %d faces au total, %d max" % [str(formes), faces_trimesh, trimesh_max])
	print("RECENS rigides éveillés=%d endormis/figés=%d ; aires surveillantes=%d" % [rig_eveil, rig_dort, aires_surv])
	var cles := phys_script.keys()
	cles.sort_custom(func(a, b): return phys_script[a] > phys_script[b])
	var l: Array = []
	for k in cles.slice(0, 15):
		l.append("%s=%d" % [k, phys_script[k]])
	print("RECENS _physics_process actifs : " + ", ".join(l))
	print("RECENS moniteurs : actifs=%d paires=%d îlots=%d ; ticks=%d max_pas=%d" % [Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT),
		Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame])

func _replication(m: Node) -> void:
	var rep: Node = root.get_node_or_null("Replicateur")
	if rep == null:
		print("RECENS pas de Replicateur")
		return
	var ent: Dictionary = rep.get("_ent")
	var j: Node3D = m.get("joueur")
	var pos := j.global_position
	var meilleurs := []
	for essai in 5:
		var t0 := Time.get_ticks_usec()
		var octets := 0
		for id in ent:
			var e: Dictionary = ent[id]
			if not is_instance_valid(e["noeud"]) or not (e["four"] as Callable).is_valid():
				continue
			octets += var_to_bytes(rep.call("_quantifier", (e["four"] as Callable).call())).size()
		meilleurs.append((Time.get_ticks_usec() - t0) / 1000.0)
		await process_frame
	var pert := 0
	var proches := 0
	for id in ent:
		var e: Dictionary = ent[id]
		if is_instance_valid(e["noeud"]) and rep.call("_pertinent", e, pos):
			pert += 1
			if (e["noeud"] as Node3D).global_position.distance_to(pos) <= 40.0:
				proches += 1
	meilleurs.sort()
	print("RECENS réplication : %d entités enregistrées, encodage d'un tick hôte : min %.3f ms / méd %.3f ms ; pertinentes pour un joueur au joueur local : %d (dont %d à < 40 m)" % [
		ent.size(), meilleurs[0], meilleurs[2], pert, proches])
