extends SceneTree
## Test headless du gameplay de la grotte (GrotteJeu) : coffres (bourse, état sauvegardé, refermés à la mort), ressources, journal de Solveig
## et registre de Hrafn (objets + événements de quête), lieux, apparition progressive des ennemis (identifiants fixes, archers « poste »,
## patrouilles, chef), mur fragile (Mecanisme), lumières proches limitées.
##   godot --headless --path . --script outils/test_grotte_jeu.gd -- --nouvelle
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
	for i in int(ceil(s * 60.0)):
		await physics_frame

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(1.0)
	a = m.grotte_acces
	a.attendre_exterieur()
	var g: Grotte = a.obtenir()
	a.montrer(true)
	m._aller_grotte("4,0,0,0")
	var j: CharacterBody3D = m.joueur
	var q: Node = m.quetes
	var jeu: GrotteJeu = a.jeu
	await _attendre(0.5)
	# 1. coffre : ouverture, bourse, état
	var it: Node3D = jeu.interactifs["camp_a"]
	var pieces0: int = j.inventaire.pieces
	it.parler()
	_verif(q.vus.has("grotte:camp_a"), "coffre camp_a : état noté dans quetes.vus")
	var bourse: Node3D = null
	for b in g.get_children():
		if b.has_meta("coffre") and b.get_meta("coffre") == "camp_a":
			bourse = b
	_verif(bourse != null, "coffre camp_a : bourse posée")
	if bourse != null:
		j.global_position = bourse.global_position
		await _attendre(0.3)
	_verif(j.inventaire.pieces >= pieces0 + 90 and j.inventaire.a("amulette_givre"), "coffre camp_a : butin reçu (pièces %d → %d, amulette de givre)" % [pieces0, j.inventaire.pieces])
	# 2. coffre non ramassé : refermé à la mort
	var it2: Node3D = jeu.interactifs["camp_b"]
	it2.parler()
	jeu.reinitialiser([])
	_verif(not q.vus.has("grotte:camp_b") and it2.actif, "coffre camp_b : bourse non ramassée perdue, coffre refermé à la mort")
	_verif(q.vus.has("grotte:camp_a"), "coffre camp_a : vidé reste acquis")
	# 3. ressource
	var res: Node3D = jeu.interactifs["res_champi_a"]
	var n0: int = j.inventaire.objets.get("champignon_lumineux", 0)
	res.parler()
	_verif(j.inventaire.objets.get("champignon_lumineux", 0) == n0 + 1 and q.vus.has("grotte:res_champi_a"), "ressource : champignon lumineux ramassé et noté")
	# 4. journal de Solveig, coffre de l'îlot (broche), registre
	var lignes: Array = (jeu.interactifs["journal_sigrun"] as Node3D).parler()
	_verif(lignes.size() >= 3 and j.inventaire.a("journal_sigrun") and q.vus.has("ramasse:journal_sigrun"), "journal de Solveig : texte (%d lignes), objet, événement ramasse:journal_sigrun" % lignes.size())
	(jeu.interactifs["ilot"] as Node3D).parler()
	var bourse2: Node3D = null
	for b in g.get_children():
		if b.has_meta("coffre") and b.get_meta("coffre") == "ilot":
			bourse2 = b
	if bourse2 != null:
		j.global_position = bourse2.global_position
		await _attendre(0.3)
	_verif(j.inventaire.a("broche_sigrun") and q.vus.has("ramasse:broche_sigrun"), "coffre de l'îlot : broche de Solveig (ramasse:broche_sigrun)")
	(jeu.interactifs["registre_hrafn"] as Node3D).parler()
	_verif(j.inventaire.a("registre_hrafn") and q.vus.has("ramasse:registre_hrafn"), "registre de Hrafn : objet et événement ramasse:registre_hrafn")
	# 5. lieux
	for ac: Dictionary in g.accroches:
		if ac["type"] == "lieu":
			j.global_position = g.to_global(ac["pos"]) + Vector3(0, 0.2, 0)
			jeu._t = 1.0
			jeu.tick(0.0)
	_verif(q.vus.has("lieu:camp_hrafn") and q.vus.has("lieu:ilot_sigrun"), "lieux : lieu:camp_hrafn et lieu:ilot_sigrun signalés")
	# 6. ennemis : apparition progressive depuis le camp
	_verif(jeu.ennemis.has("bandit_4") == false or true, "(info) ennemis déjà apparus : %d" % jeu.ennemis.size())
	jeu.reinitialiser([])
	j.global_position = g.monde_sol(306.0, 0.0) + Vector3(0, 0.2, 0)
	for i in 8:
		jeu._t = 1.0
		jeu.tick(0.0)
	var attendus := ["bandit_0", "bandit_1", "bandit_2", "bandit_3", "bandit_archer_0", "bandit_archer_1", "hrafn"]
	var tous := true
	for id in attendus:
		if not jeu.ennemis.has(id):
			tous = false
			print("   manque : ", id)
	_verif(tous, "camp : bandit_0..3, 2 archers, Hrafn apparus (identifiants fixes)")
	if jeu.ennemis.has("hrafn"):
		var h: CharacterBody3D = jeu.ennemis["hrafn"]
		_verif(h.boss == "hrafn" and h.vie_max >= 200.0, "Hrafn : boss « hrafn » (%.0f PV)" % h.vie_max)
	if jeu.ennemis.has("bandit_archer_0"):
		var ar: CharacterBody3D = jeu.ennemis["bandit_archer_0"]
		_verif(ar.archer and ar.poste and ar.global_position.y > g.to_global(Vector3(0, -5.2, 0)).y, "archer : option archer + poste, juché sur la corniche (y %.2f)" % g.to_local(ar.global_position).y)
	j.global_position = g.monde_sol(120.0, 0.0) + Vector3(0, 0.2, 0)
	for i in 8:
		jeu._t = 1.0
		jeu.tick(0.0)
	if jeu.ennemis.has("bandit_7"):
		_verif((jeu.ennemis["bandit_7"].patrouille as Array).size() == 3, "patrouille de la mine : 3 points")
	else:
		_verif(false, "bandit_7 (patrouille) absent")
	# 7. un ennemi tué reste mort si la sauvegarde le dit
	jeu.reinitialiser(["bandit_0"])
	j.global_position = g.monde_sol(306.0, 0.0) + Vector3(0, 0.2, 0)
	for i in 8:
		jeu._t = 1.0
		jeu.tick(0.0)
	_verif(not jeu.ennemis.has("bandit_0") and jeu.ennemis.has("bandit_1"), "bandit_0 tué dans la sauvegarde : ne revient pas ; les autres reviennent")
	# 8. lumières : au plus MAX_LUM allumées
	var allumees := 0
	for l: OmniLight3D in g.decor.toutes:
		if l.visible:
			allumees += 1
	_verif(allumees <= GrotteJeu.MAX_LUM and allumees > 0, "lumières : %d allumées sur %d (max %d)" % [allumees, g.decor.toutes.size(), GrotteJeu.MAX_LUM])
	# 9. mur fragile
	var murs := get_nodes_in_group("cassables")
	var mur: Node = null
	for n in murs:
		if g.is_ancestor_of(n):
			mur = n
	_verif(mur != null, "mur fragile de la cachette de Hrafn présent (Mecanisme.mur_fragile)")
	if mur != null:
		mur.casser(false)
		_verif(q.vus.has("meca:grotte_mur_cache:casse"), "mur cassé : état meca:grotte_mur_cache:casse noté")
	# 10. troll de givre de la caverne du lac (entrée « ia » des données) : EnnemiBase, debout sur le sol, gelé hors zone, mort sauvegardée
	jeu.reinitialiser([])
	await _attendre(0.1)        # les ennemis retirés (queue_free) disparaissent : sinon le nouveau troll naît dans les anciens et en est éjecté
	var ac_t: Dictionary = {}
	for ac: Dictionary in g.accroches:
		if ac["type"] == "ennemi" and ac["id"] == "troll_lac":
			ac_t = ac
	_verif(not ac_t.is_empty() and ac_t["zone"] == "lac_caverne", "troll_lac : accroche dans la zone lac_caverne")
	if not ac_t.is_empty():
		var cs_t := CapsuleShape3D.new()
		cs_t.radius = 0.75
		cs_t.height = 2.5
		var qp_t := PhysicsShapeQueryParameters3D.new()
		qp_t.shape = cs_t
		qp_t.transform = Transform3D(Basis(), g.to_global(ac_t["pos"]) + Vector3(0, 0.1 + 1.25, 0))
		qp_t.exclude = [j.get_rid()]
		var gene := m.get_world_3d().direct_space_state.intersect_shape(qp_t, 4)
		var noms := []
		for h in gene:
			noms.append(str(h["collider"].name) + " " + str(g.to_local(h["collider"].global_position)))
		_verif(gene.is_empty(), "place libre pour la capsule du troll (0,75 m) à son accroche %s" % [noms])
		j.global_position = g.to_global(g.sol_en("B", 20.0, 0.0)) + Vector3(0, 0.2, 0)
		for i in 10:
			jeu._t = 1.0
			jeu.tick(0.0)
		var tr = jeu.ennemis.get("troll_lac")
		_verif(tr != null and is_instance_valid(tr) and tr is EnnemiBase and String(tr.get_script().resource_path).ends_with("troll_givre_ia.gd"), "troll de givre troll_lac apparu (EnnemiBase)")
		if tr != null and is_instance_valid(tr):
			await _attendre(1.0)
			var ss := m.get_world_3d().direct_space_state
			var r_sol := ss.intersect_ray(PhysicsRayQueryParameters3D.create(tr.global_position + Vector3(0, 1.0, 0), tr.global_position + Vector3(0, -3.0, 0), 1, [tr.get_rid()]))
			var ecart: float = (tr.global_position.y - (r_sol["position"] as Vector3).y) if not r_sol.is_empty() else 99.0
			var depl: float = tr.global_position.distance_to(g.to_global(ac_t["pos"]))
			var lt: Vector3 = g.to_local(tr.global_position)
			_verif(absf(ecart) < 0.25 and tr.is_on_floor() and depl < 1.0, "troll debout sur le sol, resté à son poste (écart au sol %.2f m, %.2f m de son accroche, état %d)" % [ecart, depl, tr.etat])
			_verif(jeu.salles.salle_de(lt, 8.0) == "lac_caverne", "troll localisé dans lac_caverne par SalleActive")
			j.global_position = g.monde_sol(306.0, 0.0) + Vector3(0, 0.2, 0)
			jeu.salles.rafraichir(true)
			_verif(tr.est_gele(), "troll gelé quand le joueur est au camp (hors zone active)")
			j.global_position = g.to_global(g.sol_en("B", 20.0, 0.0)) + Vector3(0, 0.2, 0)
			jeu.salles.rafraichir(true)
			_verif(not tr.est_gele(), "troll dégelé au retour du joueur dans la caverne")
		jeu.reinitialiser(["troll_lac"])
		for i in 10:
			jeu._t = 1.0
			jeu.tick(0.0)
		_verif(not jeu.ennemis.has("troll_lac"), "troll_lac tué dans la sauvegarde : ne revient pas")
	print("ECHECS : %d" % _echecs)
	quit(_echecs)
