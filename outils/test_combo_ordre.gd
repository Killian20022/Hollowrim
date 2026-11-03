extends SceneTree
## Test sans fenêtre de l'ORDRE DU COMBO D'ÉPÉE (exigence utilisateur : 1er clic = coup 1, 2e = coup 2, … 4e, puis retour au 1er) :
##   godot --headless --path . --script res://outils/test_combo_ordre.gd -- --nouvelle
## Chaque scénario joue 12 clics et vérifie que la suite des coups LÉGERS lancés est exactement coup_a6, coup_b6, coup_t6,
## coup_c6, coup_a6… (CoupsUneMain.COMBO) : spam, rythme normal, pause d'1 s, clic pendant le coup, contre un mur, coup arrêté
## par une parade ennemie, après une garde, en se déplaçant (avant, arrière, côtés), souris balayée. Plus : coup puissant sans
## effet sur le compteur, vraie pause (≥ 2 s) et changement d'arme = retour au coup 1, garde qui annule un coup = pas de reset.

const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0

var _ok := true
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var _nouveau := false
var _vus: Array = []

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _pas() -> void:
	mains.avancer(DT)
	if _nouveau:
		_nouveau = false
		_vus.append(CoupsUneMain.COMBO.find(mains._geste_nom))

func _attendre(d: float) -> void:
	for i in roundi(d / DT):
		_pas()
	await process_frame

func _clic(tenu := 0.05) -> void:
	j.vigueur = j.vigueur_max
	mains.entrees.appuyer()
	for i in roundi(tenu / DT):
		_pas()
	mains.entrees.relacher()

func _reset(pos: Vector3, lacet: float) -> void:
	s.placer_joueur(pos, lacet)
	j.vigueur = j.vigueur_max
	j.velocity = Vector3.ZERO
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains.entrees.gele = false
	mains._combo = 0
	mains._depuis_coup = 9.0
	mains._pose_courante = mains._pose_repos()
	mains.defense = DefenseJoueur.new()
	mains.joueur.ennemi_vise = null
	var mc: CombatEnnemi = s.mannequin.combat
	mc.posture = mc.profil.posture_max
	mc.etourdi = 0.0
	mc.fenetre_parade = 0.0
	_vus.clear()
	_nouveau = false
	await physics_frame
	await physics_frame

## Attendu : n coups 0,1,2,3,0,1…
func _attendu(n: int) -> Array:
	var r := []
	for i in n:
		r.append(i % 4)
	return r

func _loin() -> void:
	await _reset(Vector3(0, 0, s.POS_MANNEQUIN.z + 6.0), 0.0)   # hors de portée du mannequin : ni touche ni finisher

func _suite_ok(nom: String, n: int) -> void:
	_verif(_vus == _attendu(n), "%s : %d coups %s" % [nom, _vus.size(), _vus])

func _tester() -> void:
	RetourCoups.arret_actif = false
	s = SCENE.instantiate()
	s.options = {"draugr": "fige", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	for i in 10:
		await physics_frame
	mains.pas_manuel = true
	s.draugr._bouclier = 0.0
	mains.combat.change.connect(func(_a: int, n: int) -> void:
		if n == EtatCombat.ATTAQUE_LEGERE:
			_nouveau = true)
	_verif(CoupsUneMain.COMBO == ["diag_dg6", "revers_gd6", "taille_dg6", "estoc_combo6"] and ProfilsAnimation.profil("epee_longue")["combo"] == CoupsUneMain.COMBO, "combo validé v6 : diagonale, revers, taille, estoc")
	_verif(not mains.VARIANTES_CONTEXTE, "variantes contextuelles désactivées")

	print("-- 12 clics, rythmes variés")
	# rythme normal : un clic après chaque coup (0,7 s)
	await _loin()
	for i in 12:
		await _clic()
		await _attendre(0.65)
	await _attendre(0.5)
	_suite_ok("rythme normal", 12)

	# pause d'1 s entre les clics (le combo ne doit PAS repartir)
	await _loin()
	for i in 12:
		await _clic()
		await _attendre(1.0)
	_suite_ok("pause d'1 s", 12)

	# spam : un clic toutes les 0,12 s, 12 clics ; un clic pendant un coup est mis en tampon (un seul), jamais de coup hors ordre
	await _loin()
	for i in 12:
		await _clic(0.04)
		await _attendre(0.08)
	await _attendre(1.0)
	_verif(_vus.size() >= 5 and _vus == _attendu(_vus.size()), "spam : %d coups lancés pour 12 clics, ordre exact %s" % [_vus.size(), _vus])

	# clic pendant le coup : 2 clics rapprochés (0,15 s, pendant la préparation / la frappe) = 2 coups, aucun perdu ni doublé
	await _loin()
	for i in 6:
		await _clic(0.04)
		await _attendre(0.11)
		await _clic(0.04)
		await _attendre(1.1)
	_suite_ok("clic pendant le coup (6 paires)", 12)
	# clic tardif, pendant la fin de la frappe
	await _loin()
	for i in 6:
		await _clic(0.04)
		await _attendre(0.30)
		await _clic(0.04)
		await _attendre(1.1)
	_suite_ok("clic pendant la frappe (6 paires)", 12)

	# clic maintenu un peu long pendant le coup précédent : ne fige pas le coup en cours et n'en fait pas un coup puissant
	await _loin()
	await _clic(0.04)
	await _attendre(0.12)
	mains.entrees.appuyer()
	await _attendre(0.25)
	mains.entrees.relacher()
	await _attendre(1.2)
	_verif(_vus == [0, 1] and not mains._lourd, "second clic tenu 0,25 s pendant le coup 1 : coup 2 léger, pas de charge %s" % [_vus])

	print("-- contre un mur")
	await _reset(Vector3(-1.9, 0, 1.0), 90.0)
	for i in 12:
		await _clic()
		await _attendre(0.75)
	_suite_ok("contre un mur (chaque coup rebondit)", 12)
	await _reset(Vector3(-1.9, 0, 1.0), 90.0)
	for i in 6:
		await _clic(0.04)
		await _attendre(0.12)
		await _clic(0.04)
		await _attendre(1.0)
	_verif(_vus.size() >= 8 and _vus == _attendu(_vus.size()), "mur + clics rapprochés : %s" % [_vus])

	print("-- coup arrêté par une parade ennemie")
	await _loin()
	for i in 12:
		await _clic()
		await _attendre(0.12)
		mains._issue_arret = "rebond"
		mains.trace.arretee = true
		mains._rebondir()   # même chemin que _resoudre_impact -> « rebond » (cible qui bloque)
		await _attendre(0.7)
	_suite_ok("coups bloqués par l'ennemi", 12)

	print("-- après une garde")
	await _loin()
	for i in 12:
		await _clic()
		await _attendre(0.6)
		mains.entrees.forcer_garde(0.3)
		await _attendre(0.6)
	_suite_ok("garde entre chaque coup", 12)

	print("-- en se déplaçant et souris balayée")
	for ctx in [["en avançant", Vector3(0, 0, -3.2), Vector2.ZERO], ["en reculant", Vector3(0, 0, 2.5), Vector2.ZERO],
			["pas à droite", Vector3(3.2, 0, 0), Vector2.ZERO], ["pas à gauche", Vector3(-3.2, 0, 0), Vector2.ZERO],
			["souris vers la droite", Vector3.ZERO, Vector2(150, 0)], ["souris vers la gauche", Vector3.ZERO, Vector2(-150, 0)],
			["souris vers le bas", Vector3.ZERO, Vector2(0, 150)], ["souris vers le haut", Vector3.ZERO, Vector2(0, -150)]]:
		await _loin()
		for i in 12:
			j.velocity = ctx[1]
			mains.noter_souris(ctx[2])
			await _clic()
			await _attendre(0.65)
		j.velocity = Vector3.ZERO
		_suite_ok(String(ctx[0]), 12)

	print("-- compteur : coup puissant, pauses, changement d'arme, garde")
	await _loin()
	await _clic()
	await _attendre(0.65)
	await _clic()
	await _attendre(0.65)
	var c_avant: int = mains._combo
	mains.entrees.appuyer()
	await _attendre(0.6)
	mains.entrees.relacher()
	await _attendre(1.2)
	_vus.pop_back()   # le départ du clic maintenu est un coup léger tant qu'il n'a pas atteint le seuil de charge
	_verif(mains._combo == c_avant and c_avant == 2, "coup puissant : le compteur des légers ne bouge pas (%d)" % mains._combo)
	await _clic()
	await _attendre(0.7)
	_verif(_vus == [0, 1, 2], "après un puissant, le léger suivant est le coup 3 %s" % [_vus])
	# vraie pause de 2 s : retour au coup 1
	await _attendre(2.2)
	await _clic()
	await _attendre(0.7)
	_verif(_vus == [0, 1, 2, 0], "pause de plus de 2 s : retour au coup 1 %s" % [_vus])
	# changement d'arme / rengainage
	await _clic()
	await _attendre(0.7)
	mains.reinitialiser_combo()
	await _clic()
	await _attendre(0.7)
	_verif(_vus == [0, 1, 2, 0, 1, 0], "changement d'arme : retour au coup 1 %s" % [_vus])
	# garde qui annule un coup en préparation : le compteur ne bouge pas et ne repart pas à zéro
	await _loin()
	await _clic()
	await _attendre(0.65)
	mains.entrees.appuyer()
	for i in 3:
		_pas()
	mains.entrees.relacher()
	mains.entrees.forcer_garde(0.3)
	await _attendre(0.8)
	var c_garde: int = mains._combo
	await _clic()
	await _attendre(0.7)
	_verif(c_garde == 1 and _vus.back() == 1, "garde qui annule le coup 2 en préparation : le coup 2 est rejoué au clic suivant %s" % [_vus])
	# après la mort : retour au coup 1
	j.mort = true
	_pas()
	j.mort = false
	_verif(mains._combo == 0, "mort : retour au coup 1")

	# transition du côté opposé : le coup n'est pas remplacé, la préparation est plus longue
	await _loin()
	await _clic()
	await _attendre(0.2)
	_verif(mains._geste_nom == "diag_dg6", "coup 1 = diag_dg6 (finit à gauche)")
	await _attendre(0.6)
	mains._cote_fin = -1
	mains._combo = 1
	mains._depuis_coup = 0.0
	mains.combat.forcer(EtatCombat.RECUPERATION)
	mains._geste = ProfilsAnimation.geste(mains.arme.profil, "diag_dg6")
	mains.entrees.appuyer()
	for i in 6:
		_pas()
	mains.entrees.relacher()
	_verif(mains._geste_nom == "revers_gd6", "coup 2 = revers_gd6 sans miroir quel que soit le côté de fin (%s)" % mains._geste_nom)

	print("RESULTAT : %s" % ("OK" if _ok else "ECHEC"))
	quit(0 if _ok else 1)
