extends SceneTree
## Lot L1 « coffre à couvercle » (docs/INSPIRATION_IGNITE.md §2.6), en deux processus comme test_sauvegarde :
##   -s res://outils/test_coffre_l1.gd -- ecrire     coffres de la crypte en deux pièces (couvercles posés, deux coffres royaux),
##                                                   ouverture animée (courbe, rebond, durée), lueur brève qui s'éteint, état noté,
##                                                   contenu versé à l'ouverture (L2) : ouvert même après la mort ; sauvegarde
##   -s res://outils/test_coffre_l1.gd -- verifier   rechargement : le coffre vidé est OUVERT d'emblée (sans animation), les autres
##                                                   fermés ; grotte : couvercles posés, ouverture animée, ouvert après la mort
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
	# ouverture animée du coffre de la salle de préparation
	var c: CoffreCouvercle = cv["cof_prep"]
	var it: Node3D = t._inter["cof_prep"]
	var l0 := _lumieres(t.crypte)
	var possible: bool = t.d2.lumiere_possible(c.lueur_pos, CoffreCouvercle.LUEUR_PORTEE)
	it.parler()
	_verif(q.vus.has("crypte:cof_prep") and not it.actif, "ouverture : état noté (quetes.vus[crypte:cof_prep]), interaction retirée")
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
	# L2 : plus de bourse (contenu versé à l'ouverture) ; coffre royal ouvert puis mort : il RESTE ouvert (rien à reperdre)
	await _attendre(0.3)
	var royal: CoffreCouvercle = cv["cof_tresor3"]
	(t._inter["cof_tresor3"] as Node3D).parler()
	await _attendre(0.8)
	_verif(absf(royal.angle() - CoffreCouvercle.ANGLE) < 0.001, "coffre royal ouvert (%.1f°)" % rad_to_deg(royal.angle()))
	t.dedans = true
	t.reinitialiser([])
	_verif(royal.ouvert and absf(royal.angle() - CoffreCouvercle.ANGLE) < 0.001 and q.vus.has("crypte:cof_tresor3") and not (t._inter["cof_tresor3"] as Node3D).actif,
		"mort après l'ouverture : coffre royal toujours ouvert et vidé (contenu déjà au sac, pas de double)")
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
	var autres := 0
	for id in cv:
		if id != "cof_prep" and id != "cof_tresor3" and (cv[id] as CoffreCouvercle).ouvert:
			autres += 1
	_verif(autres == 0 and (cv["cof_tresor3"] as CoffreCouvercle).ouvert, "rechargement : coffre royal (ouvert avant la mort) ouvert, les %d autres coffres fermés" % (cv.size() - 2))
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
	await _attendre(0.25)
	var mi := cg.angle()
	await _attendre(0.6)
	_verif(mi > 0.3 and absf(cg.angle() - CoffreCouvercle.ANGLE) < 0.001, "grotte : ouverture animée (%.0f° à 0,25 s, %.1f° à la fin)" % [rad_to_deg(mi), rad_to_deg(cg.angle())])
	_verif(cg.get_parent() == g, "grotte : couvercle sous la grotte")
	jeu.reinitialiser([])
	_verif(cg.ouvert and absf(cg.angle() - CoffreCouvercle.ANGLE) < 0.001, "grotte : mort après l'ouverture → coffre toujours ouvert (contenu déjà au sac)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
