extends SceneTree
## FPS par SALLE de la crypte du tertre (chantier crypte_trous, 2026-11-25 : coût du décor dessiné jusqu'à 3 portes / 26 m par SalleActive).
## Mode jeu (scène complète, salle active, brume, post-traitement), toutes les portes ouvertes, ennemis figés, HUD caché. Dans chaque salle,
## au point libre le plus central : 1 s de mise en route puis 8 lacets x 0,5 s ; FPS moyen = images / temps, plus objets et primitives.
##   godot --path . --disable-vsync --resolution 1280x720 --script res://outils/fps_salles_crypte.gd -- --nouvelle --paisible
##         --crypte=0,0.5,0,0 --sortie=<fichier.csv> [--salle=id,id] [--tours=2] [--images_salles=<dossier>]
## Écrit le CSV (salle;fps;objets;prims;appels) et imprime « FPS_SALLE » par salle et « FPS_TOTAL ».
var s: Node3D
var t: Node3D
var j: Node3D

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _point(id: String) -> Variant:
	var sa: Dictionary = t.salles.salles[id]
	var r: Rect2 = sa["rect"]
	if r.size == Vector2.ZERO:
		return null
	var ss := s.get_world_3d().direct_space_state
	var c: Node3D = t.crypte
	var exclus: Array[RID] = []
	for nd in s.find_children("*", "CharacterBody3D", true, false):
		exclus.append((nd as CharacterBody3D).get_rid())
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.7
	var best: Variant = null
	var bd := INF
	for ix in 5:
		for iz in 5:
			var x := r.position.x + r.size.x * (ix + 0.5) / 5.0
			var z := r.position.y + r.size.y * (iz + 0.5) / 5.0
			var q := PhysicsRayQueryParameters3D.create(c.to_global(Vector3(x, float(sa["y1"]) - 0.3, z)), c.to_global(Vector3(x, float(sa["y0"]) - 0.6, z)))
			q.exclude = exclus
			q.collision_mask = 1
			var rr := ss.intersect_ray(q)
			if rr.is_empty() or (rr["normal"] as Vector3).y < 0.6:
				continue
			var qp := PhysicsShapeQueryParameters3D.new()
			qp.shape = cap
			qp.transform = Transform3D(Basis(), (rr["position"] as Vector3) + Vector3(0, 0.98, 0))
			qp.exclude = exclus
			qp.collision_mask = 1
			if not ss.intersect_shape(qp, 1).is_empty():
				continue
			var dd := Vector2(x, z).distance_to(r.get_center())
			if dd < bd:
				bd = dd
				best = rr["position"]
	return best

func _go() -> void:
	var sortie := _arg("sortie", "user://fps_salles.csv")
	var filtre: Array = Array(_arg("salle").split(",")) if _arg("salle") != "" else []
	var tours := int(_arg("tours", "2"))
	s = load("res://scenes/foret_test.tscn").instantiate()
	s.set_meta("test", true)
	root.add_child(s)
	current_scene = s
	j = s.joueur
	var k := 0
	while k < 60 * 90 and not (s.tertre != null and s.tertre.dedans):
		await process_frame
		k += 1
	t = s.tertre
	t.attendre_donjon()
	# lancement --crypte sans écran de chargement : le préchauffage du rendu cache la crypte une image sur deux (et la laisse cachée
	# dans la base 156ac5d2, voir tertre._basculer) : arrêté ici, sinon le FPS mesuré est celui d'une crypte NOIRE
	for p in s.find_children("*", "PrechauffeRendu", true, false):
		if (p as PrechauffeRendu).racine == t.crypte:
			(p as PrechauffeRendu).annuler()
	t.crypte.visible = true
	s._ouvrir_donjon("s1,s2,s3,secret,herse")
	for e in get_nodes_in_group("ennemis"):
		if e is Node3D:
			(e as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
	var hud = s.get("hud")
	if hud != null and hud is CanvasItem:
		(hud as CanvasItem).visible = false
	j.set_physics_process(false)
	for i in 120:
		await process_frame
	var ids: Array = []
	for id: String in t.salles.salles:
		if filtre.is_empty() or filtre.has(id):
			ids.append(id)
	ids.sort()
	var res := {}
	for tour in tours:
		for id: String in ids:
			var p: Variant = _point(id)
			if p == null:
				continue
			j.velocity = Vector3.ZERO
			j.global_position = (p as Vector3) + Vector3(0, 0.05, 0)
			for z in 3:
				t._gerer_zones()
			t.salles.rafraichir(true)
			j.tete.rotation.x = deg_to_rad(-4.0)
			var t0 := Time.get_ticks_usec()
			while Time.get_ticks_usec() - t0 < 1000000:
				await process_frame
			var nb := 0
			var obj := 0.0
			var prim := 0.0
			var app := 0.0
			var t1 := Time.get_ticks_usec()
			for a in 8:
				j.rotation.y = t.crypte.global_rotation.y + TAU * a / 8.0
				if a == 0 and _arg("images_salles") != "" and tour == 0:
					for z in 4:
						await process_frame
					root.get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [_arg("images_salles"), id], 0.85)
				var ta := Time.get_ticks_usec()
				while Time.get_ticks_usec() - ta < 500000:
					await process_frame
					nb += 1
					obj += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
					prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
					app += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			var fps := nb / ((Time.get_ticks_usec() - t1) / 1e6)
			var r: Array = res.get(id, [])
			r.append([fps, obj / nb, prim / nb, app / nb])
			res[id] = r
			print("VISIBLES %s %s" % [id, ",".join(PackedStringArray(t.salles._visibles.keys()))])
			if "dernier_permis_us" in t.salles:
				print("PERMIS %s partielles %s : %d noeuds permis, calcul %.1f ms" % [id, ",".join(PackedStringArray(t.salles._partielles.keys())), t.salles._permis.size(), t.salles.dernier_permis_us / 1000.0])
	var f := FileAccess.open(sortie, FileAccess.WRITE)
	f.store_line("salle;fps;objets;prims;appels")
	var somme := 0.0
	for id: String in res:
		var l: Array = res[id]
		var m := [0.0, 0.0, 0.0, 0.0]
		for v: Array in l:
			for i in 4:
				m[i] += float(v[i]) / l.size()
		somme += m[0]
		f.store_line("%s;%.1f;%.0f;%.0f;%.0f" % [id, m[0], m[1], m[2], m[3]])
		print("FPS_SALLE %s %.1f fps objets %.0f prims %.0f appels %.0f" % [id, m[0], m[1], m[2], m[3]])
	print("FPS_TOTAL moyenne des salles %.1f (%d salles)" % [somme / maxf(1.0, res.size()), res.size()])
	f.close()
	quit(0)
