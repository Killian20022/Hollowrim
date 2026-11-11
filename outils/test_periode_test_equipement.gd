extends SceneTree
## Période de test de l'équipement (intégration n°3, 2026-11-12) : Jeu.PERIODE_TEST_EQUIPEMENT = l'exe se comporte comme
## --test-butin sur une NOUVELLE partie. Ici (mode outil : la période ne s'applique jamais aux tests) on passe --test-butin et on
## vérifie le contenu du sac : TOUTES les armes (dont la claymore, l'arc et des flèches), TOUTES les armures (enchantées et uniques
## comprises), tous les bijoux, sac sans limite de poids, armes listées dans l'écran I.
##   godot --headless --fixed-fps 60 --path . --script outils/test_periode_test_equipement.gd -- --nouvelle --test-butin
const SCENE := preload("res://scenes/foret_test.tscn")
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _tester() -> void:
	_verif(Jeu.mode_outil(), "mode outil reconnu (la période de test ne touche jamais les tests sans --test-butin)")
	_verif(Jeu.test_butin_argument() and Jeu.test_butin(), "--test-butin actif")
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 30:
		await physics_frame
	var inv: Inventaire = m.joueur.inventaire
	var manquants := []
	var n := {"arme": 0, "armure": 0, "bijou": 0}
	for id in Inventaire.ids_connus():
		var c := Inventaire.categorie_de(id)
		if n.has(c):
			n[c] += 1
			if not inv.a(id):
				manquants.append(id)
	_verif(manquants.is_empty(), "armes %d, armures %d, bijoux %d : tous dans le sac (manquants : %s)" % [n["arme"], n["armure"], n["bijou"], str(manquants)])
	for id in ["claymore", "coeur_de_braise", "sang_du_roi", "croc_de_givre", "grand_marteau", "arc_chasseur", "epee_hrafn",
			"hache_kolbeinn", "epee_obsidienne", "cuirasse_or_serment", "casque_saphir_ymir", "cuirasse_gardiens", "jambieres_saphir"]:
		if Inventaire.connu(id):
			_verif(inv.a(id), "%s dans le sac" % id)
	_verif(not Inventaire.connu("fleche") or inv.nombre("fleche") >= 100, "flèches données (%d)" % inv.nombre("fleche"))
	m.joueur.recalculer_stats()
	_verif(inv.capacite() > 5000.0 and not inv.surcharge(), "sac sans limite de poids (%d / %d)" % [roundi(inv.poids()), roundi(inv.capacite())])
	var magie: Variant = m.joueur.mains.get("magie")
	_verif(magie != null, "équipement des mains présent")
	if magie != null:
		var armes: Array[String] = magie.eq.objets_possedes("armes")
		_verif(armes.has("claymore") and armes.has("epee_or") and armes.has("hache_kolbeinn"), "écran I : claymore, épée d'or, hache de Kolbeinn équipables (%d armes)" % armes.size())
	print("ECHECS : %d" % _echecs)
	print("RESULTAT : " + ("OK" if _echecs == 0 else "ECHEC"))
	quit(0 if _echecs == 0 else 1)
