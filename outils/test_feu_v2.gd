extends SceneTree
## Test sans fenêtre du FEU v2 (scripts/magie/feu_v2.gd) : réglages de la couche fine forcés (pas de SubViewport sans fenêtre).
##   - orbe : 3 coques + 1 maillage de flammèches (plafond BRINS_ORBE), dans le calque de la couche fine, éteinte = invisible ;
##   - projectile de boule de feu : porte une orbe v2 (`--feu-v1` : l'ancienne boule runique, pas d'orbe) ;
##   - impact : une explosion v2 qui se libère seule ; la zone qui la suit n'en redessine pas une seconde ;
##   - jet sur un mur : léchage + filets créés, roussi laissé, TOUT disparaît à l'arrêt du jet (aucun nœud FeuV2 résiduel).
##   godot --headless --path . --script res://outils/test_feu_v2.gd -- --nouvelle
var echecs := 0

func _init() -> void:
	_lancer.call_deferred()

func verifier(cond: bool, texte: String) -> void:
	print("  ok  " if cond else "  ÉCHEC ", texte)
	if not cond:
		echecs += 1

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _compter(racine: Node, nom: String) -> int:
	return racine.find_children(nom + "*", "Node3D", true, false).size()

func _lancer() -> void:
	print("test_feu_v2")
	GestionMagie.forcer_fin = true
	var monde := Node3D.new()
	root.add_child(monde)
	current_scene = monde
	# mur à 5 m en -Z pour le jet
	var mur := StaticBody3D.new()
	mur.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(10, 6, 0.5)
	cs.shape = bx
	mur.add_child(cs)
	monde.add_child(mur)
	mur.position = Vector3(0, 2, -5)
	var main_g := Node3D.new()
	monde.add_child(main_g)
	main_g.position = Vector3(-0.2, 1.4, -0.5)
	await _images(3)

	# --- orbe
	var o := FeuV2.orbe(monde, Vector3.BACK, 1.0)
	var corps: Array = o.get_meta("corps")
	verifier(corps.size() == 3, "orbe : 3 coques (%d)" % corps.size())
	var lg: MeshInstance3D = o.get_meta("langues")
	verifier(lg.layers == CoucheMagie.CALQUE and (corps[0] as MeshInstance3D).layers == CoucheMagie.CALQUE, "orbe : dans le calque de la couche fine")
	var nb_sommets: int = (lg.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	verifier(nb_sommets == FeuV2.BRINS_ORBE * FeuV2.POINTS_BRIN * 2, "orbe : %d sommets de flammèches (plafond %d brins)" % [nb_sommets, FeuV2.BRINS_ORBE])
	FeuV2.regler(o, 0.0, 0.0)
	verifier(not o.visible, "orbe éteinte : invisible")
	FeuV2.regler(o, 1.0, 1.0)
	verifier(o.visible, "orbe allumée : visible")
	o.queue_free()

	# --- projectile
	var avant := int(FeuV2.crees["orbe"])
	var p := EffetsMagie.projectile_visuel("feu", "boule", 1.0)
	monde.add_child(p)
	verifier(int(FeuV2.crees["orbe"]) == avant + 1 and _compter(p, "OrbeFeuV2") == 1, "boule de feu : une orbe v2 sur le projectile")
	var p2 := EffetsMagie.projectile_visuel("glace", "eclat", 1.0)
	monde.add_child(p2)
	verifier(_compter(p2, "OrbeFeuV2") == 0, "éclat de glace : pas d'orbe de feu")
	await _images(3)
	p.queue_free()
	p2.queue_free()

	# --- impact puis zone : une seule explosion
	var e0 := int(FeuV2.crees["explosion"])
	EffetsMagie.impact("feu", Vector3(0, 0, -3), Vector3.UP, 1.2)
	EffetsMagie.zone("feu", Vector3(0, 0, -3), 2.2, 0.3)
	await _images(2)
	verifier(int(FeuV2.crees["explosion"]) == e0 + 1, "impact + zone : %d explosion(s) v2 (1 attendue)" % (int(FeuV2.crees["explosion"]) - e0))
	var gm := GestionMagie.obtenir()
	verifier(_compter(gm, "ExplosionFeuV2") == 1, "explosion présente dans la scène")

	# --- jet sur le mur
	var l0 := int(FeuV2.crees["lechage"])
	var j0 := int(FeuV2.crees["jet"])
	for k in 40:
		EffetsMagie.jet("feu", main_g, Vector3.FORWARD, 9.0, 1.2, true)
		await process_frame
	verifier(int(FeuV2.crees["lechage"]) == l0 + 1, "jet sur un mur : un léchage v2 (%d)" % (int(FeuV2.crees["lechage"]) - l0))
	verifier(int(FeuV2.crees["jet"]) == j0 + 1, "jet : un seul jeu de filets (%d)" % (int(FeuV2.crees["jet"]) - j0))
	verifier(_compter(gm, "RoussiFeuV2") >= 1, "jet sur un mur : roussi laissé (%d)" % _compter(gm, "RoussiFeuV2"))
	verifier(_compter(gm, "RoussiFeuV2") <= 14, "roussis plafonnés à 14")
	EffetsMagie.jet("feu", main_g, Vector3.FORWARD, 9.0, 1.2, false)
	await _images(4)
	verifier(_compter(gm, "LechageFeuV2") == 0 and _compter(gm, "FiletsJetFeuV2") == 0, "jet arrêté : léchage et filets libérés")

	# --- `--feu-v1` : ancien rendu
	GestionMagie.feu_v1 = true
	var a1 := int(FeuV2.crees["orbe"])
	var pv1 := EffetsMagie.projectile_visuel("feu", "boule", 1.0)
	monde.add_child(pv1)
	verifier(int(FeuV2.crees["orbe"]) == a1 and _compter(pv1, "OrbeFeuV2") == 0, "feu_v1 : ancienne boule runique, pas d'orbe v2")
	GestionMagie.feu_v1 = false
	pv1.queue_free()

	# --- extinction : explosion et roussis se libèrent seuls
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000 and (_compter(gm, "ExplosionFeuV2") > 0 or _compter(gm, "RoussiFeuV2") > 0):
		await process_frame
	verifier(_compter(gm, "ExplosionFeuV2") == 0, "explosion libérée seule")
	verifier(_compter(gm, "RoussiFeuV2") == 0, "roussis effacés")
	GestionMagie.forcer_fin = false
	print("test_feu_v2 : ", "TOUT OK" if echecs == 0 else "ECHECS : %d" % echecs)
	quit(0 if echecs == 0 else 1)
