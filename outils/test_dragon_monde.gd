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
	m.quetes.etat["anneau_givre"] = 5
	m.quetes.signaler("parle:chef")
	await process_frame
	print("dragon apparu : ", m.dragon != null, " état=", m.dragon.nom_etat() if m.dragon else "")
	m.joueur.global_position = m.dragon.centre + Vector3(0, 0.2, 0)
	var vu := {}
	for i in 6000:  # 2 à 3 passes en piqué avant l'atterrissage
		await physics_frame
		vu[m.dragon.nom_etat()] = true
		if m.dragon.nom_etat() == "AU_SOL":
			break
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
