extends SceneTree
## Test sans fenêtre des visuels de la magie (scripts/magie/effets_magie.gd, contrat avec la branche magie/sorts) :
## appelle TOUTES les fonctions du contrat pour toutes les écoles / formes / statuts / réactions, fait tourner la scène,
## vérifie les plafonds (particules, émetteurs, lumières, éclairs, pics, disques, statuts) sous un déluge d'effets,
## puis que tout s'éteint et retourne au pool (pas de fuite) et que les couches additives sont retirées.
##   godot --headless --path . --script res://outils/test_effets_magie.gd -- --nouvelle
var echecs := 0
var monde: Node3D

func _init() -> void:
	_lancer.call_deferred()

func verifier(cond: bool, texte: String) -> void:
	if cond:
		print("  ok  ", texte)
	else:
		print("  ÉCHEC ", texte)
		echecs += 1

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _plafonds(etape: String) -> void:
	var s := EffetsMagie.stats()
	verifier(s.particules <= GestionMagie.MAX_PARTICULES, "%s : particules %d <= %d" % [etape, s.particules, GestionMagie.MAX_PARTICULES])
	verifier(s.emetteurs <= GestionMagie.MAX_EMETTEURS, "%s : émetteurs %d <= %d" % [etape, s.emetteurs, GestionMagie.MAX_EMETTEURS])
	verifier(s.lumieres <= GestionMagie.MAX_LUMIERES, "%s : lumières %d <= %d" % [etape, s.lumieres, GestionMagie.MAX_LUMIERES])
	verifier(s.eclairs <= GestionMagie.MAX_ECLAIRS, "%s : éclairs %d <= %d" % [etape, s.eclairs, GestionMagie.MAX_ECLAIRS])
	verifier(s.disques <= GestionMagie.MAX_DISQUES, "%s : disques %d <= %d" % [etape, s.disques, GestionMagie.MAX_DISQUES])
	verifier(s.statuts <= GestionMagie.MAX_STATUTS, "%s : statuts %d <= %d" % [etape, s.statuts, GestionMagie.MAX_STATUTS])
	verifier(s.pics <= GestionMagie.MAX_PICS * 3, "%s : pics %d <= %d" % [etape, s.pics, GestionMagie.MAX_PICS * 3])

func _plafonds_fins(etape: String) -> void:
	var s := EffetsMagie.stats()
	verifier(s.particules <= GestionMagie.MAX_PARTICULES_FIN, "%s : particules %d <= %d" % [etape, s.particules, GestionMagie.MAX_PARTICULES_FIN])
	verifier(s.emetteurs <= GestionMagie.MAX_EMETTEURS_FIN, "%s : émetteurs %d <= %d" % [etape, s.emetteurs, GestionMagie.MAX_EMETTEURS_FIN])
	verifier(s.lumieres <= GestionMagie.MAX_LUMIERES, "%s : lumières %d <= %d" % [etape, s.lumieres, GestionMagie.MAX_LUMIERES])
	verifier(s.bouffees <= 12, "%s : boules procédurales %d <= 12" % [etape, s.bouffees])

func _cible(pos: Vector3) -> Node3D:
	var c := Node3D.new()
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.6, 1.8, 0.4)
	mi.mesh = b
	mi.position.y = 0.9
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ps1.gdshader")
	mi.material_override = m
	c.add_child(mi)
	monde.add_child(c)
	c.position = pos
	return c

func _lancer() -> void:
	print("test_effets_magie")
	# --- contrat : signatures présentes
	var attendu := {"aura_main": 3, "jet": 6, "projectile_visuel": 2, "impact": 4, "zone": 4, "chaine": 2, "statut_cible": 3,
		"enchant_arme": 3, "reaction": 3, "double": 2}
	var methodes := {}
	for m in (load("res://scripts/magie/effets_magie.gd") as Script).get_script_method_list():
		methodes[m.name] = (m.args as Array).size()
	for nom in attendu:
		verifier(methodes.get(nom, -1) == attendu[nom], "contrat : EffetsMagie.%s(%d arguments)" % [nom, attendu[nom]])

	monde = Node3D.new()
	root.add_child(monde)
	current_scene = monde
	var cam := Camera3D.new()
	monde.add_child(cam)
	cam.position = Vector3(0, 1.6, 4)
	cam.current = true
	var sol := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(40, 0.2, 40)
	cs.shape = bs
	sol.add_child(cs)
	monde.add_child(sol)
	sol.position.y = -0.1
	var main_g := Node3D.new()
	var main_d := Node3D.new()
	cam.add_child(main_g)
	cam.add_child(main_d)
	main_g.position = Vector3(-0.25, -0.2, -0.45)
	main_d.position = Vector3(0.25, -0.2, -0.45)
	var cibles: Array[Node3D] = []
	for i in 5:
		cibles.append(_cible(Vector3(-4 + i * 2.0, 0, -6)))
	var epee := Node3D.new()
	var lame := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.9, 0.01)
	lame.mesh = bm
	lame.position.y = 0.5
	epee.add_child(lame)
	main_d.add_child(epee)

	EffetsMagie.prechauffer()
	await _images(5)

	# --- toutes les fonctions, toutes les écoles
	var projectiles: Array[Node3D] = []
	for ecole in EffetsMagie.ECOLES:
		EffetsMagie.aura_main(main_g, ecole, 0.8)
		await _images(3)
		for k in 6:
			EffetsMagie.jet(ecole, main_g, -cam.global_basis.z, 6.0, 1.2, true)
			await process_frame
		EffetsMagie.jet(ecole, main_g, -cam.global_basis.z, 6.0, 1.2, false)
		for forme in EffetsMagie.FORMES:
			var p := EffetsMagie.projectile_visuel(ecole, forme)
			verifier(p is Node3D, "projectile_visuel(%s, %s) renvoie un Node3D" % [ecole, forme])
			monde.add_child(p)
			p.position = Vector3(0, 1.5, 0)
			projectiles.append(p)
		EffetsMagie.impact(ecole, Vector3(0, 0, -3), Vector3.UP, 1.0)
		EffetsMagie.zone(ecole, Vector3(0, 0, -5), 2.5, 1.0)
		EffetsMagie.enchant_arme(epee, ecole, true)
		EffetsMagie.double(ecole, true)
		EffetsMagie.aura_main(main_d, ecole, 1.0)
		await _images(4)
		EffetsMagie.double(ecole, false)
		EffetsMagie.aura_main(main_d, ecole, 0.0)
		# les projectiles avancent (traînées, orientation)
		for k in 5:
			for p in projectiles:
				p.position += Vector3(0, 0, -0.3)
			await process_frame
	var pts: Array[Vector3] = [main_g.global_position]
	for c in cibles:
		pts.append(c.global_position + Vector3.UP)
	EffetsMagie.chaine("electricite", pts)
	EffetsMagie.chaine("tenebres", pts)
	for statut in EffetsMagie.STATUTS:
		for c in cibles:
			EffetsMagie.statut_cible(c, statut, 1.5)
	for nom in EffetsMagie.REACTIONS:
		EffetsMagie.reaction(nom, Vector3(2, 0, -4), 2.0)
	await _images(10)
	_plafonds("toutes les fonctions")
	var s := EffetsMagie.stats()
	verifier(s.statuts == mini(20, GestionMagie.MAX_STATUTS), "statuts actifs plafonnés : %d" % s.statuts)
	var voilees := 0
	for c in cibles:
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).material_overlay != null:
				voilees += 1
	verifier(voilees >= 3, "couches additives posées sur les cibles (%d)" % voilees)
	verifier(lame.material_overlay != null, "enchantement : couche additive sur la lame")
	verifier(lame.material_override == null and lame.mesh == bm, "enchantement : modèle et matériau d'origine intacts")

	# --- 3 effets simultanés + 5 cibles avec statut (mesure CPU indicative en headless)
	EffetsMagie.tout_arreter()
	await _images(120)
	EffetsMagie.aura_main(main_g, "feu", 1.0)
	EffetsMagie.zone("glace", Vector3(0, 0, -5), 3.0, 10.0)
	for c in cibles:
		EffetsMagie.statut_cible(c, ["brulure", "gel", "choc", "corruption", "brulure"][cibles.find(c)], 10.0)
	var t0 := Time.get_ticks_usec()
	for k in 120:
		EffetsMagie.jet("electricite", main_g, -cam.global_basis.z, 8.0, 1.0, true)
		await process_frame
	var us := (Time.get_ticks_usec() - t0) / 120.0
	s = EffetsMagie.stats()
	print("  mesure : 3 effets + 5 statuts : %.2f ms par image (headless, CPU seul), %d particules, %d émetteurs, %d éclairs" % [us / 1000.0, s.particules, s.emetteurs, s.eclairs])
	_plafonds("3 effets + 5 statuts")

	# --- déluge : les plafonds tiennent, les refus sont comptés
	for k in 60:
		EffetsMagie.impact(EffetsMagie.ECOLES[k % 6], Vector3(randf_range(-5, 5), 0, randf_range(-8, -2)), Vector3.UP, 2.0)
		EffetsMagie.zone(EffetsMagie.ECOLES[k % 6], Vector3(randf_range(-5, 5), 0, randf_range(-8, -2)), 3.0, 2.0)
		EffetsMagie.reaction(EffetsMagie.REACTIONS[k % 6], Vector3(0, 0, -4), 2.5)
		EffetsMagie.chaine("electricite", pts)
		if k % 10 == 0:
			await process_frame
	await _images(3)
	_plafonds("déluge")
	verifier(EffetsMagie.stats().refus > 0, "déluge : des effets refusés au plafond (%d)" % EffetsMagie.stats().refus)

	# --- extinction : rien ne fuit
	EffetsMagie.aura_main(main_g, "feu", 0.0)
	EffetsMagie.jet("electricite", main_g, Vector3.FORWARD, 8.0, 1.0, false)
	EffetsMagie.enchant_arme(epee, "feu", false)
	for c in cibles:
		for statut in EffetsMagie.STATUTS:
			EffetsMagie.statut_cible(c, statut, 0.0)
	for p in projectiles:
		p.queue_free()
	var t_fin := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_fin < 6000:
		await process_frame
		if EffetsMagie.stats().emetteurs == 0 and EffetsMagie.stats().eclairs == 0 and EffetsMagie.stats().disques == 0 and EffetsMagie.stats().pics == 0:
			break
	await _images(3)
	s = EffetsMagie.stats()
	print("  après extinction : ", s)
	verifier(s.emetteurs == 0 and s.particules == 0, "extinction : plus d'émetteur ni de particule (%d / %d)" % [s.emetteurs, s.particules])
	verifier(s.eclairs == 0 and s.disques == 0 and s.pics == 0, "extinction : plus d'éclair, de disque ni de pic")
	verifier(s.lumieres == 0, "extinction : lumières éteintes (%d)" % s.lumieres)
	verifier(s.auras == 0 and s.jets == 0 and s.statuts == 0 and s.enchants == 0 and s.projectiles == 0, "extinction : aucun effet persistant")
	verifier(s.pool > 0 and s.pool <= GestionMagie.POOL_GARDE, "pool d'émetteurs recyclés : %d" % s.pool)
	voilees = 0
	for c in cibles:
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).material_overlay != null:
				voilees += 1
	verifier(voilees == 0 and lame.material_overlay == null, "couches additives retirées")

	# --- couche fine (« Détail des sorts » Moyen / Élevé) : réglages fins, couches compagnes, flux et auras procéduraux.
	# Sans fenêtre il n'y a pas de couche (SubViewport) : on force ses réglages pour vérifier plafonds et extinction.
	print("  couche fine (réglages forcés)")
	GestionMagie.forcer_fin = true
	for c in cibles:
		c.add_to_group("cibles_magie")
	var fins: Array[Node3D] = []
	for ecole in EffetsMagie.ECOLES:
		EffetsMagie.aura_main(main_g, ecole, 1.0)
		EffetsMagie.double(ecole, true)
		EffetsMagie.aura_main(main_d, ecole, 1.0)
		for k in 8:
			EffetsMagie.jet(ecole, main_g, (cibles[2].global_position + Vector3.UP - main_g.global_position).normalized(), 9.0, 1.2, true)
			await process_frame
		for forme in EffetsMagie.FORMES:
			var p := EffetsMagie.projectile_visuel(ecole, forme)
			monde.add_child(p)
			p.position = Vector3(0, 1.5, -1)
			fins.append(p)
		EffetsMagie.impact(ecole, Vector3(0, 0, -3), Vector3.UP, 1.5)
		EffetsMagie.zone(ecole, Vector3(0, 0, -5), 2.5, 1.0)
		EffetsMagie.statut_cible(cibles[0], "brulure", 1.0)
		await _images(3)
		_plafonds_fins("couche fine, " + ecole)
	s = EffetsMagie.stats()
	verifier(s.proceduraux > 0, "couche fine : flux, auras et boules procéduraux créés (%d)" % s.proceduraux)
	verifier(s.particules > GestionMagie.MAX_PARTICULES * 0.5, "couche fine : particules fines nombreuses (%d)" % s.particules)
	for ecole in EffetsMagie.ECOLES:
		EffetsMagie.double(ecole, false)
	EffetsMagie.aura_main(main_g, "feu", 0.0)
	EffetsMagie.aura_main(main_d, "feu", 0.0)
	EffetsMagie.jet("feu", main_g, Vector3.FORWARD, 9.0, 1.2, false)
	for p in fins:
		p.queue_free()
	t_fin = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_fin < 8000:
		await process_frame
		s = EffetsMagie.stats()
		if s.emetteurs == 0 and s.proceduraux == 0 and s.bouffees == 0 and s.eclairs == 0 and s.disques == 0:
			break
	await _images(3)
	s = EffetsMagie.stats()
	print("  couche fine, après extinction : ", s)
	verifier(s.emetteurs == 0 and s.particules == 0, "couche fine, extinction : plus d'émetteur ni de particule (%d / %d)" % [s.emetteurs, s.particules])
	verifier(s.proceduraux == 0 and s.bouffees == 0, "couche fine, extinction : plus de flux, d'aura ni de boule procédurale (%d / %d)" % [s.proceduraux, s.bouffees])
	verifier(s.auras == 0 and s.jets == 0 and s.projectiles == 0, "couche fine, extinction : aucun effet persistant")
	GestionMagie.forcer_fin = false
	print("test_effets_magie : ", "TOUT OK" if echecs == 0 else "ECHECS : %d" % echecs)
	quit(0 if echecs == 0 else 1)
