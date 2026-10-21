extends SceneTree
## Planche de captures des mécanismes de donjon (FENÊTRE nécessaire ; en --headless le script monte la scène sans enregistrer d'images) :
##   godot --path . --script outils/captures_mecanismes.gd -- --nouvelle --paisible --sortie=<dossier absolu ou res://...> [--x2]
## Les mécanismes sont posés en ligne sur une dalle d'essai à côté du point d'arrivée ; une vue par mécanisme et par état.
func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var dossier := "res://captures/mecanismes"
	var x2 := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			dossier = a.substr(9)
		elif a == "--x2":
			x2 = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	var m: Node = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for i in 30:
		await process_frame
	var j: CharacterBody3D = m.joueur
	var base: Vector3 = j.global_position
	var labo := Node3D.new()
	m.add_child(labo)
	Mecanisme.collision(labo, base + Vector3(40, -0.5, -20), Vector3(200, 1, 90))
	m.calque.visible = false
	j.mains.visible = false
	var z := base.z - 20.0
	var vues := {}      # nom -> [position joueur, lacet°, tangage°]
	var x := base.x + 4.0
	# 1. statues (une bien orientée, deux non), puis résolues
	var st = Mecanisme.statues(labo, [Vector3(x, base.y, z), Vector3(x + 2.5, base.y, z), Vector3(x + 5, base.y, z)], [0, 1, 2], "cap_statues", Callable())
	vues["statues"] = [Vector3(x + 2.5, base.y, z + 5.5), 0.0, -8.0]
	x += 14.0
	# 2. braseros : deux allumés dans l'ordre
	var br = Mecanisme.braseros(labo, [Vector3(x, base.y, z), Vector3(x + 2.5, base.y, z), Vector3(x + 5, base.y, z)], [1, 0, 2], "cap_braseros", Callable())
	br.activer(1)
	br.activer(0)
	vues["braseros"] = [Vector3(x + 2.5, base.y, z + 5.0), 0.0, -8.0]
	x += 14.0
	# 3. socles : deux fragments posés sur trois
	var inv = j.inventaire
	for id in ["fragment_sceau_os", "fragment_sceau_givre"]:
		inv.ajouter(id)
	var so = Mecanisme.socles(labo, [Vector3(x, base.y, z), Vector3(x + 2.5, base.y, z), Vector3(x + 5, base.y, z)], ["fragment_sceau_os", "fragment_sceau_givre", "fragment_sceau_eau"], "cap_socles", Callable())
	so.poser(0)
	so.poser(1)
	vues["socles"] = [Vector3(x + 2.5, base.y, z + 4.5), 0.0, -10.0]
	x += 14.0
	# 4. murs : intact (fissures) et cassé
	var w1 = Mecanisme.mur_fragile(labo, Vector3(x, base.y + 1.3, z), Vector3(3.0, 2.6, 0.6), 0.0, "cap_mur1", Callable())
	var w2 = Mecanisme.mur_fragile(labo, Vector3(x + 5, base.y + 1.3, z), Vector3(3.0, 2.6, 0.6), 0.0, "cap_mur2", Callable())
	w2.casser(false)
	vues["mur"] = [Vector3(x + 1.0, base.y, z + 5.0), 0.0, -4.0]
	x += 14.0
	# 5. dalle à fléchettes et sa bouche
	Piege.dalle_flechettes(labo, Vector3(x, base.y, z), Vector3(x + 0.0, base.y + 1.0, z - 5.0), Vector3(0, 0, 1), "cap_dalle")
	vues["dalle"] = [Vector3(x, base.y, z + 4.0), 0.0, -12.0]
	vues["dalle_bouche"] = [Vector3(x, base.y, z - 8.0), 180.0, -6.0]
	x += 14.0
	# 6. souffle de givre : annonce puis souffle
	var sg = Piege.souffle_givre(labo, Vector3(x, base.y + 1.0, z - 4.0), Vector3(0, 0, 1), 7.0, 6.0, "cap_souffle")
	vues["souffle_annonce"] = [Vector3(x + 5.0, base.y, z + 6.0), 40.0, -6.0]
	vues["souffle"] = [Vector3(x + 5.0, base.y, z + 6.0), 40.0, -6.0]
	for i in 10:
		await process_frame
	var vide: bool = DisplayServer.get_name() == "headless"
	for n in vues:
		var v: Array = vues[n]
		j.global_position = v[0] + Vector3(0, 0.1, 0)
		j.rotation.y = deg_to_rad(v[1])
		j.tete.rotation.x = deg_to_rad(v[2])
		if n == "souffle_annonce":
			sg.temps = 6.0 - 6.0 * 0.3 - 0.8
		elif n == "souffle":
			sg.temps = 6.0 - 6.0 * 0.3 + 0.5
		for i in 25:
			await process_frame
		if vide:
			continue
		var img := root.get_viewport().get_texture().get_image()
		if x2:
			img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(ProjectSettings.globalize_path(dossier + "/" + n + ".png"))
	print("captures mécanismes : %d vues%s" % [vues.size(), " (headless : rien d'enregistré)" if vide else ""])
	quit()
