extends SceneTree
## Test headless de l'option --persos-tous (essai « voir les 6 nouveaux persos ») : le monde démarre, les 6 persos existent,
## sont sur le sol, ne se chevauchent pas, regardent le joueur, qui est devant eux ; la vraie sauvegarde n'est ni lue ni écrite.
##   godot --headless --path . --script res://outils/test_persos_tous.gd -- --persos-tous
var echecs := 0

func ok(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var monde_gd := load("res://scripts/monde.gd")
	var reel := "user://sauvegarde.json"
	var avant := FileAccess.get_modified_time(reel) if FileAccess.file_exists(reel) else -1
	ok(monde_gd.fichier_sauvegarde() != reel, "sauvegarde de test utilisée (%s)" % monde_gd.fichier_sauvegarde())
	var scene := (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 40:
		await process_frame
	var persos := get_nodes_in_group("persos_tous")
	ok(persos.size() == 6, "6 persos présents (%d)" % persos.size())
	var noms := {}
	for p: Node3D in persos:
		noms[p.get_meta("nom")] = true
		var space := root.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 3.0, p.global_position + Vector3.DOWN * 3.0)
		var r := space.intersect_ray(q)
		ok(not r.is_empty() and absf(r["position"].y - p.global_position.y) < 0.5,
			"%s sur le sol (écart %.2f m)" % [p.get_meta("nom"), absf(r["position"].y - p.global_position.y) if not r.is_empty() else 99.0])
		var ap := p.get_node("Animations") as AnimationPlayer
		ok(ap.is_playing(), "%s en animation (%s)" % [p.get_meta("nom"), ap.current_animation])
	ok(noms.size() == 6, "6 noms distincts")
	var mini := 99.0
	for i in persos.size():
		for j in range(i + 1, persos.size()):
			mini = minf(mini, (persos[i].global_position - persos[j].global_position).length())
	ok(mini >= 2.4, "aucun chevauchement : distance mini %.2f m" % mini)
	var joueur: Node3D = scene.joueur
	var centre := Vector3.ZERO
	for p: Node3D in persos:
		centre += p.global_position / 6.0
	var d := joueur.global_position - centre
	d.y = 0.0
	ok(d.length() > 3.0 and d.length() < 8.0, "joueur à %.1f m devant la rangée" % d.length())
	var regard := -joueur.global_basis.z
	ok(regard.dot(-d.normalized()) > 0.9, "joueur regarde la rangée (cos %.2f)" % regard.dot(-d.normalized()))
	var face: Vector3 = persos[2].global_basis.z
	ok(face.dot(d.normalized()) > 0.9, "persos tournés vers le joueur (cos %.2f)" % face.dot(d.normalized()))
	scene.sauvegarder()   # même un enregistrement forcé ne doit toucher que le fichier de test
	var apres := FileAccess.get_modified_time(reel) if FileAccess.file_exists(reel) else -1
	ok(apres == avant, "user://sauvegarde.json intacte (mtime %d -> %d)" % [avant, apres])
	print("TEST PERSOS TOUS : ", "ECHEC (%d)" % echecs if echecs > 0 else "OK")
	quit(1 if echecs > 0 else 0)
