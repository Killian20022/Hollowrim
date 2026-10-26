extends SceneTree
## D/gardes_village : la garde de Skarnholt dans le vrai monde.
##   - au moins 14 gardes créés (data/gardes.json) + Haldor (data/villageois.json) = 15, tous à leur place, aucun ennemi ;
##   - 60 s de jeu (joueur au milieu du village, tous éveillés) : aucun coincé (compteur `blocages`), aucun sous le sol,
##     aucun hors de l'enceinte, chaque ronde a marché ;
##   - répliques : lignes propres puis réplique commune ; de nuit, les rondes portent une torche ;
##   - un ennemi « en combat » dans l'enceinte met les gardes proches en alerte, qui retombe quand il disparaît.
##   godot --headless --fixed-fps 60 --path . --script res://outils/test_gardes_village.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	var n := int(s * 60.0)
	for i in n:
		await physics_frame

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 60000:
		await physics_frame
	for i in 10:
		await physics_frame
	var gv: Node = m.get_node_or_null("GardesVillage")
	_verif(gv != null, "gestionnaire GardesVillage branché dans le monde")
	if gv == null:
		_fin()
		return
	var gardes: Array = gv.gardes
	var haldor := false
	for v: Node in get_nodes_in_group("villageois"):
		if "donnees" in v and str((v.donnees as Dictionary).get("nom", "")).begins_with("Haldor"):
			haldor = true
	_verif(gardes.size() >= 14, "%d gardes créés (data/gardes.json)" % gardes.size())
	_verif(haldor, "Haldor, garde nommé de la porte, toujours là (total %d gardes)" % (gardes.size() + (1 if haldor else 0)))
	var types := {}
	for g: Node in gardes:
		types[g.service] = types.get(g.service, 0) + 1
		if g.is_in_group("ennemis") or g.en_combat():
			_verif(false, "%s compté comme ennemi / en combat" % g.name)
	print("services : ", types)
	# joueur au centre de la place : tous à moins de 90 m (éveillés), mais loin des rondes (ne les gêne pas)
	var j: CharacterBody3D = m.joueur
	j.global_position = Vector3(44.0, m.hauteur(44.0, 40.0) + 0.2, 40.0)
	j.velocity = Vector3.ZERO
	m.cycle.heure = 12.0
	await _attendre(60.0)
	var sous := 0
	var dehors := 0
	var coinces := 0
	for g: Node3D in gardes:
		var p := g.global_position
		var dy: float = p.y - m.hauteur(p.x, p.z)
		var ok_sol: bool = g.service == "vigie" or dy > -0.7
		var ok_in: bool = ReliefVillage.dans_enceinte(p.x, p.z, 1.0)
		if not ok_sol:
			sous += 1
		if not ok_in:
			dehors += 1
		if g.blocages > 0:
			coinces += 1
			print("  %s : renonce à (%.1f ; %.1f)" % [g.name, g.dernier_blocage.x, g.dernier_blocage.z])
		var info := "%-18s %-6s (%.1f ; %.1f) dy=%.2f marché %.1f m, blocages %d, lod %d" % [g.name, g.service, p.x, p.z, dy, g.parcouru, g.blocages, g.lod]
		print("  " + info)
		if g.service == "ronde":
			_verif(g.parcouru > 15.0, "%s a fait sa ronde (%.1f m en 60 s)" % [g.name, g.parcouru])
		elif g.service == "poste":
			_verif(g.parcouru < 2.0, "%s est resté à son poste (%.1f m)" % [g.name, g.parcouru])
	_verif(coinces == 0, "aucun garde coincé après 60 s (%d)" % coinces)
	_verif(sous == 0, "aucun garde sous le sol (%d)" % sous)
	_verif(dehors == 0, "aucun garde hors du village (%d)" % dehors)
	# répliques
	var g0: Node = gardes[0]
	var l1: Array = g0.parler()
	g0.fin_conversation()
	var l2: Array = g0.parler()
	g0.fin_conversation()
	_verif(l1.size() >= 1 and str(l1[0]).length() > 5, "1re conversation : lignes propres (« %s »)" % str(l1[0]))
	_verif(l2.size() == 1 and str(l2[0]).length() > 5 and l2[0] != l1[0], "ensuite : réplique commune (« %s »)" % str(l2[0]))
	# nuit : torches des rondes
	m.cycle.heure = 22.0
	await _attendre(1.0)
	var torches := 0
	var rondes := 0
	for g: Node in gardes:
		if g.service == "ronde":
			rondes += 1
			if g.porte_torche():
				torches += 1
	_verif(rondes > 0 and torches == rondes, "de nuit, %d/%d rondes portent une torche" % [torches, rondes])
	m.cycle.heure = 12.0
	await _attendre(1.0)
	var eteintes := 0
	for g: Node in gardes:
		if g.porte_torche():
			eteintes += 1
	_verif(eteintes == 0, "de jour, torches rangées (%d allumées)" % eteintes)
	# alerte : un faux ennemi en combat près de la longue maison
	var sc := GDScript.new()
	sc.source_code = "extends Node3D\nfunc en_combat() -> bool:\n\treturn true\nfunc vivant() -> bool:\n\treturn true\n"
	sc.reload()
	var e := Node3D.new()
	e.set_script(sc)
	e.add_to_group("ennemis")
	m.add_child(e)
	e.global_position = Vector3(44.0, m.hauteur(44.0, 29.0), 29.0)
	await _attendre(1.5)
	var alerte := 0
	for g: Node in gardes:
		if g.etat == 3:   # ALERTE
			alerte += 1
	_verif(alerte >= 2, "ennemi dans l'enceinte : %d gardes en alerte" % alerte)
	e.queue_free()
	await _attendre(1.5)
	var reste := 0
	for g: Node in gardes:
		if g.etat == 3:
			reste += 1
	_verif(reste == 0, "ennemi parti : fin de l'alerte (%d encore en alerte)" % reste)
	_fin()

func _fin() -> void:
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : " + ("OK" if _echecs == 0 else "ÉCHEC"))
	m.queue_free()
	await process_frame
	quit(1 if _echecs > 0 else 0)
