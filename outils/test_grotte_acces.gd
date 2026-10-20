extends SceneTree
## Test headless de l'entrée de la grotte : la roche est solide (pas de trou, on ne traverse pas le front de roche, le boyau
## est fermé par son bouchon), l'interactif « Entrer dans la grotte » mène dans la grotte (fondu, lumière, cycle coupé), la sortie
## ramène devant la bouche (lumière, cycle, flammes restaurés), la partie sauvegardée sous terre revient dans la grotte, la mort
## sous terre referme la grotte.
##   godot --headless --path . --script outils/test_grotte_acces.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var a: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	await create_timer(s).timeout

func _rayon(de: Vector3, vers: Vector3, vivants: Array[RID]) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(de, vers)
	q.exclude = vivants
	return m.get_world_3d().direct_space_state.intersect_ray(q)

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await physics_frame
	a = m.grotte_acces
	_verif(a != null, "l'accès à la grotte existe dans le monde")
	var t0 := Time.get_ticks_msec()
	a.attendre_exterieur()
	for i in 6:
		await physics_frame
	_verif(a.pret, "extérieur posé dans la scène (fil d'exécution, attente de %d ms ici)" % (Time.get_ticks_msec() - t0))
	print("extérieur : %d facettes, %d ms de construction (en fil d'exécution)" % [a.nb_facettes, a.temps_ms])
	var vivants: Array[RID] = []
	for n in m.find_children("*", "CharacterBody3D", true, false):
		vivants.append((n as CharacterBody3D).get_rid())
	# 1. étanchéité : en tout point d'une grille autour de la bouche, un rayon vers le bas touche le sol ou la roche (pas de trou)
	var trous := 0
	var nb := 0
	for x in range(78, 106, 2):
		for z in range(-42, -11, 2):
			nb += 1
			var r := _rayon(Vector3(x, 60.0, z), Vector3(x, -10.0, z), vivants)
			if r.is_empty():
				trous += 1
	_verif(trous == 0, "aucun trou autour de la bouche (%d rayons verticaux, %d sans impact)" % [nb, trous])
	# le sol de la terrasse est celui du seuil (y = origine de l'accès), le boyau a son bouchon
	var o: Vector3 = a.global_position
	var sol := _rayon(o + Vector3(-2.0, 3.0, 0.0), o + Vector3(-2.0, -3.0, 0.0), vivants)       # 2 m devant le seuil
	_verif(not sol.is_empty() and absf(sol["position"].y - o.y) < 0.05, "terrasse plane au niveau du seuil (écart %.3f m)" % (absf(sol["position"].y - o.y) if not sol.is_empty() else 99.0))
	# 2. le front de roche arrête un joueur : rayons horizontaux vers l'est à 0,5 / 1,5 / 3 m, à gauche et à droite de la voûte
	for dz in [-6.0, -4.0, 4.0, 6.0]:
		for h in [0.6, 1.6]:
			var de := Vector3(o.x - 6.0, o.y + h, o.z + dz)
			var r := _rayon(de, de + Vector3(14.0, 0, 0), vivants)
			_verif(not r.is_empty() and r["position"].x < o.x + 1.0, "front de roche à %.1f m du axe, h=%.1f : arrêté en x=%.2f" % [dz, h, r["position"].x if not r.is_empty() else 999.0])
	# au centre : on entre dans le boyau (3 m) puis le bouchon arrête
	for h in [0.6, 1.5, 2.4]:
		var de := Vector3(o.x - 6.0, o.y + h, o.z)
		var r := _rayon(de, de + Vector3(14.0, 0, 0), vivants)
		_verif(not r.is_empty() and r["position"].x > o.x + 2.5 and r["position"].x < o.x + 4.0, "boyau ouvert puis bouchon à h=%.1f : arrêté en x=%.2f (seuil %.2f)" % [h, r["position"].x if not r.is_empty() else 999.0, o.x])
	# 3. l'interactif d'entrée est là
	var entrer: Node3D = null
	for it in a.find_children("*", "Node3D", true, false):
		if it.get("verbe") == "Entrer dans la grotte":
			entrer = it
	_verif(entrer != null, "interactif « Entrer dans la grotte » présent")
	# 3 bis. une capsule (comme le joueur) monte la rampe depuis l'ouest et entre dans le boyau jusqu'au bouchon
	var capsule := CharacterBody3D.new()
	var cs2 := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs2.shape = cap
	cs2.position.y = 0.9
	capsule.add_child(cs2)
	capsule.floor_snap_length = 0.4
	m.add_child(capsule)
	capsule.global_position = Vector3(56.0, m.hauteur(56.0, GrotteAcces.piste_z(56.0)) + 0.2, GrotteAcces.piste_z(56.0))
	for i in 10:
		await physics_frame
	var route: Array[Vector3] = []
	for x in range(60, 92, 4):
		route.append(Vector3(x, 0, GrotteAcces.piste_z(x)))
	route.append(Vector3(o.x - 0.5, 0, o.z))
	route.append(Vector3(o.x + 2.6, 0, o.z))
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var cible := 0
	var t := 0.0
	var depuis := 0.0
	var pos_ref := capsule.global_position
	var bloque := false
	var pente_max := 0.0
	while cible < route.size() and t < 60.0 and not bloque:
		var p := capsule.global_position
		if Vector2(p.x - route[cible].x, p.z - route[cible].z).length() < 0.5:
			cible += 1
			continue
		var dir := Vector3(route[cible].x - p.x, 0, route[cible].z - p.z).normalized()
		capsule.velocity.x = dir.x * 3.2
		capsule.velocity.z = dir.z * 3.2
		capsule.velocity.y -= 13.0 * dt
		capsule.move_and_slide()
		if capsule.is_on_floor():
			pente_max = maxf(pente_max, rad_to_deg(capsule.get_floor_angle()))
		await physics_frame
		t += dt
		depuis += dt
		if depuis >= 2.0:
			if capsule.global_position.distance_to(pos_ref) < 0.4:
				print("   bloquée en ", capsule.global_position, " (point ", cible, "/", route.size(), ")")
				bloque = true
			pos_ref = capsule.global_position
			depuis = 0.0
	_verif(cible >= route.size(), "capsule : de la piste (x=56) jusqu'au fond du boyau en %.1f s (pente max %.1f°)" % [t, pente_max])
	_verif(capsule.global_position.x > o.x + 2.0 and capsule.global_position.x < o.x + 3.6 and absf(capsule.global_position.y - o.y) < 0.4, "capsule dans le boyau, au niveau du seuil (%s)" % [capsule.global_position])
	var pos_cap := capsule.global_position
	capsule.velocity = Vector3(3.2, 0, 0)
	for i in 30:
		capsule.move_and_slide()
		await physics_frame
	_verif(capsule.global_position.x < o.x + 3.7, "le bouchon arrête la capsule (x = %.2f)" % capsule.global_position.x)
	capsule.queue_free()
	# 4. entrer : fondu → joueur dans la grotte, sous terre
	var j: CharacterBody3D = m.joueur
	j.global_position = a.porte_dehors + Vector3(0, 0.3, 0)
	await _attendre(0.3)
	var env: Environment = m._env
	var heure0: float = m.cycle.heure
	var lignes: Array = entrer.parler()
	_verif(lignes.is_empty(), "l'action d'entrée ne renvoie pas de texte")
	await _attendre(1.6)
	var g: Grotte = a.grotte
	_verif(g != null and a.dedans, "dedans = vrai, grotte construite (fil sûr)")
	_verif(j.global_position.y < -200.0 and absf(j.global_position.x - 20.0) < 30.0, "joueur dans la grotte (%s)" % [j.global_position])
	_verif(g.visible and g.process_mode != Node.PROCESS_MODE_DISABLED, "grotte visible et active")
	var camp_ok: bool = a.bandits.size() == 4
	for b in a.bandits:
		if not is_instance_valid(b) or b.global_position.y > -200.0 or not b.vivant() or b.nom_affiche != "Bandit":
			camp_ok = false
	_verif(camp_ok, "4 bandits vivants au camp, dans la grotte")
	# un bandit tué reste mort dans la sauvegarde
	a.bandits[0].recevoir_coup(999.0, a.bandits[0].global_position + Vector3(1, 0, 0), true)
	_verif(m.cycle.process_mode == Node.PROCESS_MODE_DISABLED and not m.neige.visible and not m.cycle.lumiere.visible, "cycle coupé, neige et lune éteintes sous terre")
	_verif(env.background_mode == Environment.BG_COLOR, "ciel remplacé par la couleur noire")
	_verif(absf(env.fog_density - 0.012) < 0.001, "ambiance de la grotte (brume %.3f)" % env.fog_density)
	_verif(m.post.get_shader_parameter("fondu") < 0.05, "fondu terminé")
	# on marche : le sol est sous les pieds
	await physics_frame
	await physics_frame
	var sous := _rayon(j.global_position + Vector3(0, 0.5, 0), j.global_position + Vector3(0, -2.0, 0), vivants)
	_verif(not sous.is_empty(), "sol sous le joueur dans la grotte")
	# 5. sauvegarde dans la grotte : y sous -182 ; restaurer() redonne la grotte
	m.sauvegarder()
	var d = JSON.parse_string(FileAccess.get_file_as_string(m.fichier_sauvegarde()))
	var py: float = d["joueur"]["position"][1]
	_verif(py < -182.0, "sauvegardé dans la grotte (y = %.1f)" % py)
	_verif(d["draugrs_morts"].has("bandit_0") and not d["draugrs_morts"].has("bandit_1"), "le bandit tué est dans la sauvegarde, pas les autres")
	_verif(m.fichier_sauvegarde().ends_with("sauvegarde_test.json"), "fichier de test, pas la vraie partie")
	_verif(not m.tertre.dedans, "le tertre ne se croit pas dedans")
	# 6. sortie
	var sortie: Node3D = null
	for it in g.find_children("*", "Node3D", true, false):
		if it.get("verbe") == "Sortir de la grotte":
			sortie = it
	_verif(sortie != null, "interactif « Sortir de la grotte » présent")
	sortie.parler()
	await _attendre(1.6)
	_verif(not a.dedans and not g.visible, "dehors : grotte cachée")
	_verif(j.global_position.distance_to(a.porte_dehors) < 1.0, "joueur revenu devant la bouche (%s)" % [j.global_position])
	_verif(j.global_position.y > 0.0, "joueur au-dessus du sol du monde (y = %.1f)" % j.global_position.y)
	_verif(m.cycle.process_mode != Node.PROCESS_MODE_DISABLED and m.neige.visible and m.cycle.lumiere.visible, "cycle, neige et lune restaurés")
	_verif(env.background_mode == Environment.BG_SKY, "ciel restauré")
	_verif(env.fog_density > 0.015, "brume du monde restaurée (%.3f)" % env.fog_density)
	_verif(absf(m.post.get_shader_parameter("tramage") - 1.0) < 0.01, "tramage restauré")
	var mains: Node = j.mains
	var flammes_ok := true
	for i in mains.flammes.size():
		if i != 3 and not mains.flammes[i].visible:
			flammes_ok = false
	_verif(flammes_ok, "flammes de la torche tenue restaurées")
	await _attendre(0.5)
	_verif(m.cycle.heure != heure0, "le cycle jour/nuit repart (%.3f → %.3f)" % [heure0, m.cycle.heure])
	_verif(absf(wrapf(j.rotation.y - a.orientation, -PI, PI)) < 0.01, "regard vers l'extérieur")
	# 7. partie chargée dans la grotte : restaurer() ramène sous terre
	j.global_position = g.monde_sol(30.0, 0.0) + Vector3(0, 0.2, 0)
	a.restaurer()
	await _attendre(0.3)
	_verif(a.dedans and g.visible, "restaurer() : on est de nouveau dans la grotte")
	_verif(env.background_mode == Environment.BG_COLOR and m.cycle.process_mode == Node.PROCESS_MODE_DISABLED, "restaurer() : ambiance souterraine rétablie")
	# 8. mort sous terre : la grotte se referme
	a.reinitialiser()
	await _attendre(0.2)
	_verif(not a.dedans and not g.visible and env.background_mode == Environment.BG_SKY, "mort sous terre : grotte refermée, ciel rétabli")
	# 9. pas de restauration dans la crypte quand on sort de la grotte : y de la crypte (-140) n'est pas pris pour la grotte
	j.global_position = Vector3(0, -140, 0)
	a.restaurer()
	_verif(not a.dedans, "une position dans la crypte (y = -140) n'ouvre pas la grotte")
	j.global_position = Vector3(0, 5, 0)
	print("ECHECS : %d" % _echecs)
	quit(_echecs)
