extends SceneTree
## Test sans fenêtre de l'ESQUIVE du joueur (nuit 2026-11-05, docs/COMBAT.md « Esquive ») dans scenes/test_combat.tscn :
##   godot --headless --path . --script res://outils/test_esquive.gd
## 1. Pas de côté : distance ≈ ESQUIVE_DISTANCE en ESQUIVE_DUREE s, du bon côté ; en arrière sans direction ; coût de vigueur.
## 2. Invulnérabilité : "esquive" (aucun dégât) dans les ESQUIVE_INVULNERABLE premières secondes, "touche" ensuite.
## 3. Refus : sans assez de vigueur, pendant une esquive, pendant l'attente, mort.
## 4. Mains : refusée pendant un coup (préparation / phase active), chargée, déséquilibre ; permise au repos, en garde.
## 5. Annulation de la récupération : coup raté = tout de suite ; coup touché = après ESQUIVE_ANNULE_TOUCHE s ; combo STRICT intact.
## 6. Caméra : inclinaison pendant l'esquive, nulle avant et après.
const SCENE := preload("res://scenes/test_combat.tscn")
const DT := 1.0 / 60.0

var _ok := true
var s: Node3D
var j: CharacterBody3D
var mains: Node3D

func _init() -> void:
	_tester.call_deferred()

func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _pas(n: int) -> void:
	for i in n:
		mains.avancer(DT)
		await physics_frame

func _reset() -> void:
	s.placer_joueur(Vector3.ZERO, 0.0)
	j.vie = j.vie_max
	j.vigueur = j.vigueur_max
	j.esquive_t = -1.0
	j._esquive_attente = 0.0
	j.velocity = Vector3.ZERO
	mains.entrees.forcer_garde(0.0)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains.combat.forcer(EtatCombat.REPOS)
	mains._combo = 0
	mains._depuis_coup = 9.0
	await _pas(3)

func _tester() -> void:
	RetourCoups.arret_actif = false
	RetourImpact.muet = true
	Sang.niveau_force = 2
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	current_scene = s
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await physics_frame
	mains.pas_manuel = true
	s.mannequin.position = Vector3(-8, 0, -8)

	# 1. pas de côté (droite), en arrière, coût
	await _reset()
	var p0: Vector3 = j.global_position
	var v0: float = j.vigueur
	_verif(j.esquiver(Vector2(1, 0)), "esquive vers la droite acceptée")
	_verif(is_equal_approx(v0 - j.vigueur, ReglagesCombat.ESQUIVE_COUT), "coût de vigueur = ESQUIVE_COUT (%.0f)" % (v0 - j.vigueur))
	await _pas(int(ReglagesCombat.ESQUIVE_DUREE / DT) + 4)
	var d: Vector3 = j.global_position - p0
	_verif(d.x > ReglagesCombat.ESQUIVE_DISTANCE * 0.8 and d.x < ReglagesCombat.ESQUIVE_DISTANCE * 1.15 and absf(d.z) < 0.3, "pas de côté droit de ≈ %.1f m (%.2f, %.2f)" % [ReglagesCombat.ESQUIVE_DISTANCE, d.x, d.z])
	_verif(j.esquive_t < 0.0, "l'esquive est terminée après ESQUIVE_DUREE")
	await _reset()
	p0 = j.global_position
	j.esquiver(Vector2(-1, 0))
	await _pas(int(ReglagesCombat.ESQUIVE_DUREE / DT) + 4)
	d = j.global_position - p0
	_verif(d.x < -ReglagesCombat.ESQUIVE_DISTANCE * 0.8, "pas de côté gauche (%.2f)" % d.x)
	await _reset()
	p0 = j.global_position
	j.esquiver(Vector2.ZERO)
	await _pas(int(ReglagesCombat.ESQUIVE_DUREE / DT) + 4)
	d = j.global_position - p0
	_verif(d.z > ReglagesCombat.ESQUIVE_DISTANCE * 0.8 and absf(d.x) < 0.3, "sans direction : en arrière, face à -Z donc vers +Z (%.2f, %.2f)" % [d.x, d.z])
	await _reset()
	p0 = j.global_position
	j.esquiver(Vector2(0, -1))
	await _pas(int(ReglagesCombat.ESQUIVE_DUREE / DT) + 4)
	d = j.global_position - p0
	_verif(d.z > ReglagesCombat.ESQUIVE_DISTANCE * 0.8, "touche « avant » seule : l'esquive part en arrière, jamais en avant (%.2f)" % d.z)

	# 2. invulnérabilité
	await _reset()
	j.esquiver(Vector2(1, 0))
	await _pas(2)
	var r: String = j.recevoir_coup(30.0, Vector3(0, 0, -2))
	_verif(r == "esquive" and is_equal_approx(j.vie, j.vie_max), "coup reçu pendant la fenêtre d'invulnérabilité : \"esquive\", aucun dégât (%s, vie %.0f)" % [r, j.vie])
	_verif(j.esquives_evitees == 1, "compteur de coups évités")
	await _pas(int(ReglagesCombat.ESQUIVE_INVULNERABLE / DT) + 3)
	r = j.recevoir_coup(30.0, Vector3(0, 0, 2))
	_verif(r == "touche" and j.vie < j.vie_max, "après la fenêtre (encore en mouvement) le coup touche (%s, vie %.0f)" % [r, j.vie])

	# 3. refus
	await _reset()
	j.vigueur = ReglagesCombat.ESQUIVE_COUT - 1.0
	_verif(not j.esquiver(Vector2(1, 0)), "refusée sans assez de vigueur")
	await _reset()
	j.esquiver(Vector2(1, 0))
	_verif(not j.esquiver(Vector2(1, 0)), "refusée pendant une esquive")
	await _pas(int(ReglagesCombat.ESQUIVE_DUREE / DT) + 2)
	_verif(not j.esquiver(Vector2(1, 0)), "refusée pendant l'attente qui suit")
	await _pas(int(ReglagesCombat.ESQUIVE_ATTENTE / DT) + 3)
	_verif(j.esquiver(Vector2(1, 0)), "de nouveau possible après l'attente")
	await _reset()
	j.mort = true
	_verif(not j.esquiver(Vector2(1, 0)), "refusée quand on est mort")
	j.mort = false

	# 4. mains : refus pendant un coup, permis au calme / en garde
	await _reset()
	_verif(mains.peut_esquiver(), "permise au repos")
	mains.entrees.forcer_garde(0.5)
	await _pas(6)
	_verif(mains.combat.defense() and mains.peut_esquiver(), "permise en garde (%s)" % mains.combat.nom())
	await _reset()
	mains.entrees.appuyer()
	await _pas(3)
	mains.entrees.relacher()
	_verif(mains.combat.etat == EtatCombat.ATTAQUE_LEGERE, "(un coup est lancé : %s)" % mains.combat.nom())
	_verif(not mains.peut_esquiver() and not j.esquiver(Vector2(1, 0)), "refusée pendant la préparation / la frappe d'un coup")
	for etat in [EtatCombat.CHARGE_LOURDE, EtatCombat.ATTAQUE_LOURDE, EtatCombat.DESEQUILIBRE, EtatCombat.CONTRE, EtatCombat.FINISHER, EtatCombat.EQUIPER]:
		mains.combat.forcer(etat)
		_verif(not mains.peut_esquiver(), "refusée dans l'état %s" % mains.combat.nom())

	# 5. annulation de la récupération, combo strict
	await _reset()
	mains.entrees.appuyer()
	await _pas(2)
	mains.entrees.relacher()
	var t := 0
	while mains.combat.etat != EtatCombat.RECUPERATION and t < 120:
		await _pas(1)
		t += 1
	_verif(mains.combat.etat == EtatCombat.RECUPERATION, "le coup raté (dans le vide) arrive en récupération")
	_verif(not mains._coup_touche, "coup raté : _coup_touche faux")
	var combo_avant: int = mains._combo
	_verif(combo_avant == 1, "le compteur de combo a déjà avancé au coup 2 (%d)" % combo_avant)
	_verif(j.esquiver(Vector2(1, 0)), "coup raté : l'esquive annule la récupération tout de suite")
	_verif(mains.combat.etat == EtatCombat.REPOS and mains._combo == combo_avant, "état REPOS, combo inchangé (%d)" % mains._combo)
	mains.entrees.appuyer()
	await _pas(2)
	mains.entrees.relacher()
	_verif(mains.combat.etat == EtatCombat.ATTAQUE_LEGERE and mains._geste_nom == mains._profil()["combo"][1], "le clic suivant donne bien le coup 2 du combo strict (%s)" % mains._geste_nom)
	await _reset()
	mains._coup_touche = true
	mains.combat.forcer(EtatCombat.RECUPERATION)
	await _pas(2)
	_verif(not j.esquiver(Vector2(1, 0)), "coup TOUCHÉ : refusée dans les premiers instants de la récupération")
	await _pas(int(ReglagesCombat.ESQUIVE_ANNULE_TOUCHE / DT) + 2)
	mains.combat.forcer(EtatCombat.RECUPERATION)
	mains.combat.t = ReglagesCombat.ESQUIVE_ANNULE_TOUCHE + 0.01
	_verif(j.esquiver(Vector2(1, 0)), "coup touché : permise après ESQUIVE_ANNULE_TOUCHE s")

	# 6. caméra
	await _reset()
	var z0: float = absf(j.camera.rotation.z)
	j.esquiver(Vector2(1, 0))
	await _pas(int(ReglagesCombat.ESQUIVE_DUREE / DT * 0.5))
	var z1: float = j.camera.rotation.z
	_verif(z1 < -0.04, "caméra inclinée vers la droite pendant l'esquive (roulis %.3f rad)" % z1)
	await _pas(int(ReglagesCombat.ESQUIVE_DUREE / DT) + 10)
	_verif(absf(j.camera.rotation.z) <= z0 + 0.02, "caméra redressée après (%.3f)" % j.camera.rotation.z)

	print("TEST_ESQUIVE ", "OK" if _ok else "ECHECS")
	quit(0 if _ok else 1)
