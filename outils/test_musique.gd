extends SceneTree
## Test sans fenêtre : musique.gd choisit la bonne piste selon la situation.
const SCENE := preload("res://scenes/foret_test.tscn")

func _init() -> void:
	_tester.call_deferred()

func _tester() -> void:
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	for i in 10:
		await process_frame
	m.tertre.dedans = false
	var mu: Node = null
	for e in m.get_children():
		if e.get_script() != null and e.get_script().resource_path.ends_with("musique.gd"):
			mu = e
	print("musique présente : ", mu != null, " dedans=", m.tertre.dedans)
	if mu == null:
		quit(1)
		return
	var ok := true
	# forêt
	m.joueur.global_position = Vector3(0, 5, 20)
	await _attendre(5)
	ok = _verif("forêt", mu.piste, "foret") and ok
	# village
	m.joueur.global_position = Vector3(m.VILLAGE.x, 5, m.VILLAGE.z)
	await _attendre(5)
	ok = _verif("village", mu.piste, "village") and ok
	# crypte
	m.tertre._passer(true)
	# l'entrée attend, écran noir, que le donjon (bâti en fil d'exécution) soit prêt : on attend la bascule, puis la musique
	var t_att := 0.0
	while not m.tertre.dedans and t_att < 30.0:
		await create_timer(0.25).timeout
		t_att += 0.25
	await create_timer(1.5).timeout
	ok = _verif("crypte", mu.piste, "crypte") and ok
	m.tertre._passer(false)
	await create_timer(1.5).timeout
	# combat : un draugr en traque près du joueur
	var d: Node3D = m.draugrs.values()[0]
	d.global_position = m.joueur.global_position + Vector3(5, 0, 0)
	d.etat = d.TRAQUE
	await _attendre(5)
	ok = _verif("combat", mu.piste, "combat") and ok
	# sortie : temporisation de 6 s
	d.etat = d.MORT
	await _attendre(5)
	ok = _verif("combat (temporisé)", mu.piste, "combat") and ok
	mu._sortie_combat = 0.0
	await _attendre(5)
	print("après combat : ", mu.piste)
	# lecteurs
	var jouent := 0
	for c in mu.get_children():
		if c is AudioStreamPlayer and c.playing:
			jouent += 1
	print("lecteurs en lecture : ", jouent)
	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)

func _attendre(n: int) -> void:
	for i in n:
		await process_frame

func _verif(nom: String, vu: String, attendu: String) -> bool:
	print(nom, " → ", vu, " ", "ok" if vu == attendu else "ATTENDU " + attendu)
	return vu == attendu
