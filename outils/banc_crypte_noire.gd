extends SceneTree
## Bug « crypte noire » (2026-11-23) : FPS avant / après la correction (pièces du tertre dans SalleActive), A/B ENTRELACÉ dans le même
## lancement et à la même pose : « avant » = décor visible selon l'ancien calcul (salle la plus proche à 8 m parmi les modules, pièces
## du tertre ignorées), « après » = calcul actuel. Les mises à jour de SalleActive sont suspendues pendant la mesure.
##   godot --path . --disable-vsync --script res://outils/banc_crypte_noire.gd -- --nouvelle --paisible [--heure=12] [--cycles=6]
## Lignes : « BANC <pose> avant: x FPS (n visibles) | apres: y FPS (m visibles) ».
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var j: CharacterBody3D
var sa: SalleActive

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _attendre(k: int) -> void:
	for i in k:
		await process_frame

func _go() -> void:
	m = SCENE.instantiate()
	root.add_child(m)
	current_scene = m
	j = m.joueur
	var t0 := Time.get_ticks_msec()
	while (m.village.get("prets") != true or not m.tertre.bati) and Time.get_ticks_msec() - t0 < 300000:
		await process_frame
	if _arg("heure") != "":
		m.cycle.heure = float(_arg("heure"))
	await _attendre(30)
	var tr: Node3D = m.tertre
	j.global_position = tr.porte_dehors + Vector3(0, 0.3, 0.6)
	j.rotation.y = tr.orientation
	await _attendre(30)
	tr._passer(true)
	while not tr.dedans:
		await process_frame
	await _attendre(90)
	sa = tr.salles
	var c: Node3D = tr.crypte
	var cycles := int(_arg("cycles", "6"))
	# [nom, position (repère crypte), lacet° (0 = vers -Z, le couloir)]
	var poses := [["vestibule_arrivee", Vector3(0, 0.1, 0.5), 0.0], ["niches", Vector3(0, 0.1, -10.0), 0.0],
		["prep_vers_herse", Vector3(0, 0.1, -24.0), 0.0], ["couloir_herse", Vector3(0, 0.1, -36.0), 0.0]]
	for p: Array in poses:
		j.global_position = c.to_global(p[1])
		j.rotation.y = c.global_rotation.y + deg_to_rad(p[2])
		j.velocity = Vector3.ZERO
		sa.rafraichir(true)
		var neuf := sa._visibles.duplicate()
		var ancien := _ancien(c.to_local(j.global_position))
		sa._t = -1e9                    # SalleActive suspendue : on impose nous-mêmes le décor visible
		await _attendre(30)
		var fa: Array = []
		var fb: Array = []
		var na := 0
		var nb := 0
		for k in cycles:
			sa._appliquer_decor(ancien)
			na = _nb_visibles()
			await _attendre(10)
			fa.append(await _fps(1.0))
			sa._appliquer_decor(neuf)
			nb = _nb_visibles()
			await _attendre(10)
			fb.append(await _fps(1.0))
		fa.sort()
		fb.sort()
		print("BANC %s avant: %.1f FPS (%d visibles, salles %s) | apres: %.1f FPS (%d visibles, salles %s)" % [p[0], fa[fa.size() / 2], na, str(ancien.keys()), fb[fb.size() / 2], nb, str(neuf.keys())])
		sa._t = 0.0
	quit()

## Ancien calcul (fef05e41) : salle la plus proche à 8 m parmi les MODULES seulement ; les pièces du tertre restent visibles (non classées).
func _ancien(p: Vector3) -> Dictionary:
	var pieces := {}
	for id: String in sa.salles.keys():
		if sa.salles[id].get("piece", false):
			pieces[id] = sa.salles[id]
	for id: String in pieces:
		sa.salles.erase(id)
	var voisins_sauves := {}
	for id: String in sa.salles:
		voisins_sauves[id] = (sa.salles[id]["voisins"] as Array).duplicate()
		sa.salles[id]["voisins"] = (sa.salles[id]["voisins"] as Array).filter(func(v: String) -> bool: return not pieces.has(v))
	var res := sa._calculer_actives(sa.salle_de(p, 8.0))
	for id: String in voisins_sauves:
		sa.salles[id]["voisins"] = voisins_sauves[id]
	for id: String in pieces:
		sa.salles[id] = pieces[id]
		res[id] = true
	return res

func _nb_visibles() -> int:
	var n := 0
	for e: Dictionary in sa._noeuds.values():
		if (e["n"] as GeometryInstance3D).visible:
			n += 1
	return n

func _fps(duree: float) -> float:
	var n := 0
	var t := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t < duree * 1e6:
		await process_frame
		n += 1
	return n / ((Time.get_ticks_usec() - t) / 1e6)
