extends SceneTree
## Test sans fenêtre : marche, course et sauts autour et à travers le cercle de pierres runiques
## (le « sanctuaire »), en simulant les touches comme au clavier ; note toute perte de vie et sa source.
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node
var pertes: Array = []

func _init() -> void:
	_tester.call_deferred()

## Marche vers `cible` (plan XZ) en pressant « avant » ; s'arrête à 1 m. Renvoie quand arrivé ou au bout du temps.
func _aller(cible: Vector3, court: bool, saute: bool) -> void:
	var j: CharacterBody3D = m.joueur
	var n := 0
	while n < 1500:
		var vers := cible - j.global_position
		vers.y = 0.0
		if vers.length() < 1.0:
			break
		j.rotation.y = atan2(-vers.x, -vers.z)
		Input.action_press("avant")
		if court:
			Input.action_press("course")
		if saute and n % 50 == 0:
			Input.action_press("saut")
		else:
			Input.action_release("saut")
		await physics_frame
		n += 1
		j.vigueur = j.vigueur_max
	Input.action_release("avant")
	Input.action_release("course")
	Input.action_release("saut")

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 10:
		await process_frame
	var j: CharacterBody3D = m.joueur
	# Les draugrs de surface (visibles) ont le droit de frapper : on ne garde que ceux de la crypte,
	# sous le sol, qui ne doivent jamais toucher quelqu'un qui marche dehors.
	for e in get_nodes_in_group("ennemis"):
		if e.global_position.y > -50.0:
			e.queue_free()
	await process_frame
	print("ennemis sous terre : ", get_nodes_in_group("ennemis").size())
	var c: Vector3 = m.CERCLE
	j.touche.connect(func(d: float) -> void:
		var proches := []
		for e in get_nodes_in_group("ennemis"):
			if is_instance_valid(e):
				proches.append("%s@%.1fm etat=%d" % [e.ident if "ident" in e else e.name, e.global_position.distance_to(j.global_position), e.etat if "etat" in e else -1])
		pertes.append("coup %.1f pos=%s origine=%s ennemis=%s" % [d, j.global_position, j.origine_dernier_coup, proches]))
	for essai in 3:  # marche, course, course + sauts
		var court := essai >= 1
		var saute := essai == 2
		for k in 4:
			var a := TAU * k / 4.0 + 0.4
			var debut := c + Vector3(cos(a), 0, sin(a)) * 22.0
			var fin := c - Vector3(cos(a), 0, sin(a)) * 22.0
			j.global_position = Vector3(debut.x, m.hauteur(debut.x, debut.z) + 0.3, debut.z)
			j.velocity = Vector3.ZERO
			await _aller(fin, court, saute)
			print("trajet ", essai, "/", k, " fini en ", j.global_position, " vie=", snappedf(j.vie, 0.1))
		for r in [14.0, 9.0, 5.0]:  # tours du cercle
			for q in 12:
				var a2 := TAU * q / 12.0
				var p: Vector3 = c + Vector3(cos(a2), 0, sin(a2)) * r
				await _aller(p, court, saute)
			print("tour r=", r, " essai ", essai, " vie=", snappedf(j.vie, 0.1))
	for ligne in pertes:
		print(ligne)
	var coups_marche := pertes.size()
	# contrôle : un draugr éveillé, au même niveau, frappe toujours
	pertes.clear()
	var lieu: Vector3 = Vector3(c.x + 14.0, m.hauteur(c.x + 14.0, c.z) + 0.3, c.z)
	j.global_position = lieu
	j.vie = j.vie_max
	var d: CharacterBody3D = m.creer_draugr("sbire", lieu + Vector3(3.0, 0, 0), 0.0, false)
	for i in 600:
		await physics_frame
	var frappe: bool = j.vie < j.vie_max - 1.0
	print("contrôle : draugr éveillé frappe = ", frappe, " vie=", snappedf(j.vie, 0.1))
	print("TEST DEGATS SANCTUAIRE : ", "OK" if (coups_marche == 0 and frappe and d != null) else "ÉCHEC (%d coups en marchant)" % coups_marche)
	quit()
