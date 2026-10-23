extends SceneTree
## Test sans fenêtre : finir la quête principale fait venir le dragon ; on le tue à l'épée.
const SCENE := preload("res://scenes/foret_test.tscn")

func _init() -> void:
	_tester.call_deferred()

func _tester() -> void:
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	for i in 10:
		await process_frame
	# les fils de construction (crypte, modèles d'ennemis, grotte) doivent être finis : le dragon refait son maillage d'aile à chaque image
	# et un crash moteur (signal 11 dans dragon.gd _poser_aile) est survenu quand cela tombait pendant la construction en fil d'exécution (suite complète, 3 Godot actifs)
	var t_att := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_att < 120000 and not (m.tertre._donjon_pret() and m.grotte_acces.grotte != null):
		await process_frame
	print("constructions en fil finies après ", Time.get_ticks_msec() - t_att, " ms")
	for i in 5:
		await process_frame
	m.quetes.etat["anneau_givre"] = 5
	m.quetes.signaler("parle:chef")
	await process_frame
	print("dragon apparu : ", m.dragon != null, " état=", m.dragon.nom_etat() if m.dragon else "")
	m.joueur.global_position = m.dragon.centre + Vector3(0, 0.2, 0)
	var vu := {}
	var i_att := 0
	for i in 6000:  # 2 à 3 passes en piqué avant l'atterrissage
		await physics_frame
		# le test vérifie les états du dragon, pas la survie du joueur : sous le souffle (2 ou 3 passes tirées au sort) il pouvait mourir,
		# le dragon repartait alors en TOURNOIE et n'atterrissait plus jamais (échec ~1 fois sur 4)
		m.joueur.vie = 100.0
		vu[m.dragon.nom_etat()] = true
		i_att = i
		if m.dragon.nom_etat() == "AU_SOL":
			break
	print("images attendues : ", i_att, " mort joueur : ", m.joueur.mort)
	print("états vus : ", vu.keys(), " joueur vie=", snappedf(m.joueur.vie, 1))
	# on le frappe là où l'épée vise
	var coups := 0
	while m.dragon.vivant() and coups < 200:
		m.joueur.vie = 100.0
		var p: Vector3 = m.dragon.point_impact()
		m.joueur.global_position = p + (m.joueur.global_position - p).normalized() * 1.6
		m.dragon.recevoir_coup(40.0, m.joueur.global_position, true)
		coups += 1
		await physics_frame
	print("dragon vivant : ", m.dragon.vivant(), " après ", coups, " coups ; vaincu noté : ", m.dragon_vaincu)
	print("TEST DRAGON : ", "OK" if (not m.dragon.vivant() and m.dragon_vaincu and vu.has("PIQUE")) else "ÉCHEC")
	quit()
