extends SceneTree
## Lot L1 « coffre à couvercle » (docs/INSPIRATION_IGNITE.md §2.6), en deux processus comme test_sauvegarde :
##   -s res://outils/test_coffre_l1.gd -- ecrire     coffres de la crypte en deux pièces (couvercles posés, deux coffres royaux),
##                                                   ouverture animée (courbe, rebond, durée), lueur brève qui s'éteint, état noté,
##                                                   pièces versées à l'ouverture (L2) : ouvert même après la mort ; fenêtre de butin
##                                                   (L3) : couvercle animé sous la fenêtre, objet laissé = « Fouiller le coffre » ; sauvegarde
##   -s res://outils/test_coffre_l1.gd -- verifier   rechargement : le coffre vidé est OUVERT d'emblée (sans animation), les autres
##                                                   fermés ; objets laissés relus (ButinTables.restes), sans double ; grotte : couvercles
##                                                   posés, ouverture animée, ouvert après la mort
const SCENE := preload("res://scenes/foret_test.tscn")
var FICHIER: String = load("res://scripts/monde.gd").fichier_test()

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred(OS.get_cmdline_user_args()[0])

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _attendre(s: float) -> void:
	for i in int(ceil(s * 60.0)):
		await process_frame

func _lumieres(n: Node) -> int:
	return n.find_children("*", "OmniLight3D", true, false).size()

func _tester(etape: String) -> void:
	if FICHIER == "user://sauvegarde.json" or load("res://scripts/monde.gd").fichier_sauvegarde() != FICHIER:
		print("TEST COFFRE L1 : ÉCHEC (le jeu viserait la vraie sauvegarde, test annulé)")
		quit(1)
		return
	if etape == "ecrire":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(0.3)
	var t: Node3D = m.tertre
	var q: Node = m.quetes
	var j: CharacterBody3D = m.joueur
	t.attendre_donjon()
	await _attendre(0.2)
	var cv: Dictionary = t._couvercles
	if etape == "ecrire":
		await _ecrire(t, q, j, cv)
	else:
		await _verifier(t, q, j, cv)
	print("ECHECS : %d" % _echecs)
	quit(_echecs)

func _ecrire(t: Node3D, q: Node, j: CharacterBody3D, cv: Dictionary) -> void:
	var n_coffres := 0
	for id in t._inter:
		if (t._inter[id] as Node3D).get_meta("genre_donjon", "") == "coffre" and String(id).begins_with("cof_"):
			n_coffres += 1
	print("coffres de la crypte : %d, couvercles : %d" % [n_coffres, cv.size()])
	print("couvercles royaux : ", cv.get("cof_tresor3").modele, " / ", cv.get("cof_jarl").modele)
	_verif(cv.size() >= 20, "crypte : %d couvercles posés à part (coffres qui s'ouvrent)" % cv.size())
	_verif(cv.has("cof_tresor3") and (cv["cof_tresor3"] as CoffreCouvercle).modele == "coffre_royal_couvercle" and cv.has("cof_jarl") and (cv["cof_jarl"] as CoffreCouvercle).modele == "coffre_royal_couvercle",
		"grands coffres royaux : Grand coffre du trésor et Coffre du Jarl")
	var tous_fermes := true
	for id in cv:
		tous_fermes = tous_fermes and absf((cv[id] as CoffreCouvercle).angle()) < 0.001 and not (cv[id] as CoffreCouvercle).is_processing()
	_verif(tous_fermes, "nouvelle partie : tous les couvercles fermés, aucun _process actif")
	var ors := 0
	for id in cv:
		ors += 1 if (cv[id] as CoffreCouvercle).or_visible() else 0
	_verif(ors == cv.size(), "L3 : or de la cuve à part et visible dans les %d coffres fermés" % ors)
	# ouverture animée du coffre de la salle de préparation
	var c: CoffreCouvercle = cv["cof_prep"]
	var it: Node3D = t._inter["cof_prep"]
	var l0 := _lumieres(t.crypte)
	var possible: bool = t.d2.lumiere_possible(c.lueur_pos, CoffreCouvercle.LUEUR_PORTEE)
	it.parler()
	var fb: FenetreButin = m.fenetre_butin
	_verif(q.vus.has("crypte:cof_prep") and fb.ouvert and paused, "ouverture : état noté (quetes.vus[crypte:cof_prep]), fenêtre de butin ouverte (jeu en pause)")
	_verif(c.ouvert and c.is_processing(), "ouverture : couvercle en mouvement")
	var l1 := _lumieres(t.crypte)
	_verif(l1 == l0 + (1 if possible else 0), "lueur : %d lumière temporaire (lumiere_possible = %s)" % [l1 - l0, str(possible)])
	var traces: Array = []
	var maxi := 0.0
	var t_fin := -1.0
	for k in 72:                    # 1,2 s à 60 images/s (--fixed-fps 60 : temps simulé)
		await process_frame
		var s := (k + 1) / 60.0
		maxi = maxf(maxi, c.angle())
		if traces.size() < 40:
			traces.append("%.2f:%.0f°" % [s, rad_to_deg(c.angle())])
		if t_fin < 0.0 and not c.is_processing():
			t_fin = s
	print("courbe d'ouverture : ", " ".join(traces.slice(0, 40, 3)))
	print("angle maxi %.1f°, final %.1f°, fin de l'animation à %.2f s" % [rad_to_deg(maxi), rad_to_deg(c.angle()), t_fin])
	_verif(absf(c.angle() - CoffreCouvercle.ANGLE) < 0.001, "ouvert : angle final %.1f° (attendu %.1f°)" % [rad_to_deg(c.angle()), rad_to_deg(CoffreCouvercle.ANGLE)])
	_verif(maxi > CoffreCouvercle.ANGLE * 1.03 and maxi < CoffreCouvercle.ANGLE * 1.08, "petit rebond : dépasse de %.1f %%" % ((maxi / CoffreCouvercle.ANGLE - 1.0) * 100.0))
	_verif(CoffreCouvercle.courbe(0.25) > 0.5 and CoffreCouvercle.courbe(0.5) == 1.0 and CoffreCouvercle.courbe(0.05) < 0.1, "courbe en S de 0,5 s (0,05 s : %.2f, 0,25 s : %.2f, 0,5 s : %.2f)" % [CoffreCouvercle.courbe(0.05), CoffreCouvercle.courbe(0.25), CoffreCouvercle.courbe(0.5)])
	_verif(_lumieres(t.crypte) == l0, "lueur éteinte et retirée après l'ouverture (aucune lumière permanente)")
	_verif(not c.is_processing(), "plus de _process une fois ouvert")
	_verif(not c.or_visible() and c._or != null, "L3 : l'or de la cuve s'est enfoncé puis a disparu (coffre pillé = vide)")
	fb.tout_prendre()
	_verif(not fb.ouvert and not paused and not it.actif and not ButinTables.a_reste("crypte:cof_prep"), "tout prendre : fenêtre fermée, jeu repris, coffre vidé (plus d'invite)")
	# L2 : plus de bourse (contenu versé à l'ouverture) ; coffre royal ouvert puis mort : il RESTE ouvert (rien à reperdre)
	await _attendre(0.3)
	var royal: CoffreCouvercle = cv["cof_tresor3"]
	var it_r: Node3D = t._inter["cof_tresor3"]
	it_r.parler()
	await _attendre(0.8)
	_verif(absf(royal.angle() - CoffreCouvercle.ANGLE) < 0.001, "coffre royal ouvert (%.1f°)" % rad_to_deg(royal.angle()))
	var n_lignes := fb.lignes.size()
	if n_lignes >= 2:
		fb.prendre(0)                 # un objet pris, le reste laissé dans le coffre
	fb.fermer()
	var reste: Dictionary = ButinTables.reste("crypte:cof_tresor3").duplicate()
	print("coffre royal : %d objets, laissés : %s" % [n_lignes, str(reste)])
	_verif(not reste.is_empty() and it_r.actif and it_r.verbe == "Fouiller le coffre", "fenêtre fermée avant la fin : %d objet(s) laissé(s), « Fouiller le coffre »" % reste.size())
	t.dedans = true
	t.reinitialiser([])
	_verif(royal.ouvert and absf(royal.angle() - CoffreCouvercle.ANGLE) < 0.001 and q.vus.has("crypte:cof_tresor3") and it_r.actif and ButinTables.reste("crypte:cof_tresor3") == reste,
		"mort après l'ouverture : coffre royal toujours ouvert, objets laissés toujours dedans (pièces déjà au sac, pas de double)")
	_verif(c.ouvert and absf(c.angle() - CoffreCouvercle.ANGLE) < 0.001 and q.vus.has("crypte:cof_prep"), "mort : le coffre vidé reste ouvert")
	j.global_position = Vector3(10, m.hauteur(10, 10) + 0.1, 10)
	await _attendre(0.2)
	m.sauvegarder()
	print("ÉCRIT : crypte:cof_prep vidé")

func _verifier(t: Node3D, q: Node, _j: CharacterBody3D, cv: Dictionary) -> void:
	_verif(q.vus.has("crypte:cof_prep"), "rechargement : crypte:cof_prep relu dans quetes.vus")
	var c: CoffreCouvercle = cv.get("cof_prep")
	_verif(c != null and c.ouvert and absf(c.angle() - CoffreCouvercle.ANGLE) < 0.001 and not c.is_processing(),
		"rechargement : le coffre vidé est OUVERT d'emblée (%.1f°, sans animation)" % (rad_to_deg(c.angle()) if c != null else -1.0))
	_verif(not (t._inter["cof_prep"] as Node3D).actif, "rechargement : plus d'invite sur le coffre vidé")
	# L3 : objets laissés dans le coffre royal, relus de la sauvegarde ; rouvert = mêmes objets, pas de pièces en double
	var it_r: Node3D = t._inter["cof_tresor3"]
	var reste: Dictionary = ButinTables.reste("crypte:cof_tresor3").duplicate()
	_verif(not reste.is_empty() and it_r.actif and it_r.verbe == "Fouiller le coffre", "rechargement : objets laissés relus %s, « Fouiller le coffre »" % str(reste))
	var or0: int = _j.inventaire.pieces
	it_r.parler()
	var fb: FenetreButin = m.fenetre_butin
	_verif(fb.ouvert and fb.lignes.size() == reste.size() and fb.pieces == 0, "rechargement : la fenêtre rouvre sur les %d objet(s) laissé(s), sans pièces" % reste.size())
	var avant := {}
	for id: String in reste:
		avant[id] = _j.inventaire.nombre(id)
	fb.tout_prendre()
	var ok := true
	for id: String in reste:
		ok = ok and _j.inventaire.nombre(id) >= int(avant[id]) + 1
	_verif(ok and _j.inventaire.pieces >= or0 and not ButinTables.a_reste("crypte:cof_tresor3") and not it_r.actif and not paused, "tout prendre : objets au sac, coffre vidé, jeu repris")
	var autres := 0
	for id in cv:
		if id != "cof_prep" and id != "cof_tresor3" and (cv[id] as CoffreCouvercle).ouvert:
			autres += 1
	_verif(autres == 0 and (cv["cof_tresor3"] as CoffreCouvercle).ouvert, "rechargement : coffre royal (ouvert avant la mort) ouvert, les %d autres coffres fermés" % (cv.size() - 2))
	_verif(not c.or_visible() and not (cv["cof_tresor3"] as CoffreCouvercle).or_visible() and (cv["cof_jarl"] as CoffreCouvercle).or_visible(),
		"rechargement : coffres ouverts sans or, coffre fermé avec son or (prep %s, trésor %s, jarl %s)" % [c.or_visible(), (cv["cof_tresor3"] as CoffreCouvercle).or_visible(), (cv["cof_jarl"] as CoffreCouvercle).or_visible()])
	# grotte
	var a: Node3D = m.grotte_acces
	a.attendre_exterieur()
	var g: Grotte = a.obtenir()
	a.montrer(true)
	m._aller_grotte("4,0,0,0")
	await _attendre(0.5)
	var jeu: GrotteJeu = a.jeu
	print("grotte : %d coffres, %d couvercles" % [jeu.couvercles.size(), jeu.couvercles.size()])
	_verif(jeu.couvercles.size() >= 4 and jeu.couvercles.has("camp_a"), "grotte : %d couvercles posés" % jeu.couvercles.size())
	var cg: CoffreCouvercle = jeu.couvercles["camp_b"]
	(jeu.interactifs["camp_b"] as Node3D).parler()
	await _attendre(0.25)        # (fenêtre de butin ouverte, jeu en pause : le couvercle s'ouvre quand même)
	var mi := cg.angle()
	await _attendre(0.6)
	_verif(mi > 0.3 and absf(cg.angle() - CoffreCouvercle.ANGLE) < 0.001, "grotte : ouverture animée (%.0f° à 0,25 s, %.1f° à la fin)" % [rad_to_deg(mi), rad_to_deg(cg.angle())])
	_verif(cg.get_parent() == g, "grotte : couvercle sous la grotte")
	m.fenetre_butin.fermer()
	jeu.reinitialiser([])
	_verif(cg.ouvert and absf(cg.angle() - CoffreCouvercle.ANGLE) < 0.001, "grotte : mort après l'ouverture → coffre toujours ouvert (contenu déjà au sac)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
