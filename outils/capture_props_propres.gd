extends SceneTree
## Vues JOUEUR de chaque ensemble extérieur (compositions des abords, tablées/postes du village, feu de camp du départ) pour les planches
## avant/après du chantier props_propres. Une vue d'ensemble (~5,5 m) et un gros plan (~3 m) par lieu, dans le dossier --sortie.
##   godot --path . --script res://outils/capture_props_propres.gd -- --nouvelle --paisible --sortie=<dossier> [--lieux=a,b] [--heure=12]
## Écrit aussi <dossier>/lieux.txt (nom x z) ; la liste des lieux vient du registre d'AbordsProps (+ « camp_depart »).
const SCENE := preload("res://scenes/foret_test.tscn")

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var s: Node3D = SCENE.instantiate()
	root.add_child(s)
	current_scene = s
	for i in 3000:
		await process_frame
		if s.village != null and s.village.get("prets") == true and s.has_node("AbordsProps"):
			break
	for i in 90:
		await process_frame
	var dossier := _arg("sortie", "user://props_propres")
	DirAccess.make_dir_recursive_absolute(dossier)
	var j: CharacterBody3D = s.joueur
	s.cycle.heure = float(_arg("heure", "12"))
	s.hud.aide_t = 0.0
	j.mains.visible = false
	j.set_physics_process(false)
	# lieux : centre des items de chaque composition
	var lieux := {}
	for e: Array in AbordsProps.registre:
		var n: String = e[0]
		if not lieux.has(n):
			lieux[n] = []
		lieux[n].append((e[2] as Transform3D).origin)
	var centres := {"camp_depart": Vector3(0, 0, -2.0)}
	for n: String in lieux:
		var c := Vector3.ZERO
		for p: Vector3 in lieux[n]:
			c += p
		centres[n] = c / float((lieux[n] as Array).size())
	# lieux supplémentaires « nom:x:z » (village fondu, entrée de grotte) via --extra=
	for e in _arg("extra", "").split(",", false):
		var q := e.split(":")
		centres[q[0]] = Vector3(float(q[1]), 0, float(q[2]))
	var filtre := _arg("lieux", "")
	var ft := FileAccess.open(dossier.path_join("lieux.txt"), FileAccess.WRITE)
	var espace: PhysicsDirectSpaceState3D = s.get_world_3d().direct_space_state
	for n: String in centres:
		if filtre != "" and not (n in filtre.split(",")):
			continue
		var c: Vector3 = centres[n]
		ft.store_line("%s %.1f %.1f" % [n, c.x, c.z])
		var cible := Vector3(c.x, float(s.hauteur(c.x, c.z)) + 0.6, c.z)
		var faits := 0
		for d: float in [5.0, 3.2]:
			var meilleur := Vector3.INF
			var meilleur_score := -1.0
			for k in 16:
				var t := TAU * float(k) / 16.0
				var cam := Vector3(c.x + cos(t) * d, 0, c.z + sin(t) * d)
				cam.y = float(s.hauteur(cam.x, cam.z)) + 1.62
				if s.arbres_autour(cam, 1.2) > 0:
					continue
				var libre := 0.0
				for u: float in [0.25, 0.5, 0.75]:
					var q := cam.lerp(cible, u)
					if float(s.hauteur(q.x, q.z)) < q.y - 0.3:
						libre += 1.0
				var rq := PhysicsRayQueryParameters3D.create(cam, cible)
				var hit := espace.intersect_ray(rq)
				if hit.is_empty() or (hit["position"] as Vector3).distance_to(cible) < 1.8:
					libre += 2.0
				var dedans := PhysicsPointQueryParameters3D.new()
				dedans.position = cam
				if not espace.intersect_point(dedans, 1).is_empty():
					libre = -5.0
				# préfère le même côté (est/sud) pour comparer avant/après : bruit déterministe en k
				var score := libre + 0.01 * float(k)
				if score > meilleur_score:
					meilleur_score = score
					meilleur = cam
			if meilleur == Vector3.INF:
				continue
			j.global_position = Vector3(meilleur.x, float(s.hauteur(meilleur.x, meilleur.z)) + 0.02, meilleur.z)
			for i in 20:
				await process_frame
				var dv: Vector3 = cible - j.camera.global_position
				j.rotation.y = atan2(-dv.x, -dv.z)
				j.tete.rotation.x = atan2(dv.y, Vector2(dv.x, dv.z).length())
			for i in 12:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(dossier.path_join("%s_%d.png" % [n, faits]))
			faits += 1
		print("CAPTURE ", n, " ", faits)
	ft.close()
	quit(0)
