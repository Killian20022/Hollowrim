extends SceneTree
## Test headless : l'archer tire vraiment (armement annoncé, flèche en vol, dégâts), la flèche s'arrête dans un mur,
## la garde du joueur la pare. godot --headless --path . --script outils/test_archer.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _fleches() -> Array:
	var r := []
	for n in m.get_children():
		if n is Projectile:
			r.append(n)
	return r

func _poser(p: Vector3) -> Vector3:
	return Vector3(p.x, m.hauteur(p.x, p.z) + 0.05, p.z)

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 8:
		await physics_frame
	for e in get_nodes_in_group("ennemis"):
		e.set_physics_process(false)  # on neutralise les ennemis du décor
	var j = m.joueur
	var a0: Vector3 = j.global_position
	# zone dégagée : à l'écart de tout
	var A := _poser(Vector3(a0.x, 0, a0.z))
	j.global_position = A
	j.rotation.y = 0.0  # regarde vers -z
	j.velocity = Vector3.ZERO
	var archer: CharacterBody3D = m.creer_draugr("squelette_archer", _poser(A + Vector3(0, 0, -10)), PI, false, {"ident": "t_archer"})
	for i in 3:
		await physics_frame
	_verif(archer.archer, "squelette_archer est archer d'office")
	_verif(archer._ligne_de_vue(), "ligne de vue dégagée à 10 m")
	# 1. tir réel : armement annoncé puis flèche, dégâts
	var vie0: float = j.vie
	var vu_vise := false
	var fleche: Projectile = null
	var vues := []
	m.child_entered_tree.connect(func(n: Node) -> void:
		if n is Projectile:
			vues.append(n))
	var t_vise := 0.0
	for i in 600:
		await physics_frame
		j.global_position.x = A.x
		j.global_position.z = A.z
		if archer.etat == archer.VISE:
			vu_vise = true
			t_vise += get_physics_process_time_proxy()
		if j.vie < vie0 - 0.5:
			break
	_verif(vu_vise, "armement annoncé (état VISE) avant le tir")
	_verif(vues.size() >= 1, "une flèche est apparue (%d)" % vues.size())
	_verif(j.vie < vie0 - 5.0 and j.vie > vie0 - 15.0, "la flèche touche : vie %.1f -> %.1f (≈ -10)" % [vie0, j.vie])
	archer.set_physics_process(false)
	for f in _fleches():
		f.queue_free()
	await physics_frame
	# 2. mur : la flèche se fiche dedans, pas de dégâts, et la ligne de vue est coupée
	var mur := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(8, 5, 0.6)
	forme.shape = boite
	mur.add_child(forme)
	m.add_child(mur)
	mur.global_position = A + Vector3(0, 2, -5)
	await physics_frame
	await physics_frame
	_verif(not archer._ligne_de_vue(), "mur : plus de ligne de vue")
	j.vie = 100.0
	var depart: Vector3 = archer.global_position + Vector3(0, 1.4, 0)
	var f2 := Projectile.tirer(m, depart, Projectile.cap_visee(depart, A + Vector3(0, 1.1, 0)), archer, 10.0, j)
	for i in 120:
		await physics_frame
		if f2.plantee:
			break
	_verif(f2.plantee and f2.resultat == "mur", "la flèche se fiche dans le mur (résultat : %s)" % f2.resultat)
	_verif(f2.global_position.z < A.z - 4.0, "elle s'arrête avant le joueur (z=%.1f)" % f2.global_position.z)
	_verif(j.vie == 100.0, "aucun dégât derrière le mur")
	mur.queue_free()
	await physics_frame
	# 3. parade : joueur de face, garde levée à l'instant de l'impact
	j.vigueur = j.vigueur_max
	var proche := A + Vector3(0, 1.1, -3.0)
	var f3 := Projectile.tirer(m, proche, Vector3(0, 0, 1), archer, 10.0, j)
	var rr := {"res": ""}
	f3.touche.connect(func(r: String) -> void: rr["res"] = r)
	j.mains.etat = j.mains.GARDE
	j.mains.temps_garde = 0.0
	for i in 40:
		await physics_frame
		if rr["res"] != "":
			break
		j.mains.etat = j.mains.GARDE
		j.mains.temps_garde = 0.0
	var res: String = rr["res"]
	_verif(res == "parade" or res == "bloque", "garde : la flèche est parée (%s)" % res)
	_verif(j.vie >= 99.0, "peu ou pas de dégâts avec la garde (vie %.1f)" % j.vie)
	# 4. portée de la chute : cap_visee compense bien (la flèche arrive à hauteur de torse à 15 m)
	j.mains.etat = j.mains.REPOS
	var d15 := A + Vector3(0, 0, -15)
	var dep := d15 + Vector3(0, 1.4, 0)
	var f4 := Projectile.tirer(m, dep, Projectile.cap_visee(dep, A + Vector3(0, 1.1, 0)), archer, 0.0, j)
	var haut := 99.0
	for i in 200:
		await physics_frame
		if not is_instance_valid(f4) or f4.resultat != "":
			break
		if f4.global_position.z > A.z - 1.0:
			haut = f4.global_position.y - A.y
			break
	_verif(haut > 0.4 and haut < 2.0, "visée compensée : la flèche arrive à %.2f m au-dessus du sol à 15 m" % haut)
	print("TEST ARCHER : ", "OK" if _echecs == 0 else "ÉCHEC (%d)" % _echecs)
	quit()

func get_physics_process_time_proxy() -> float:
	return 1.0 / 60.0
