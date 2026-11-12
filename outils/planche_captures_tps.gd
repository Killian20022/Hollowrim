extends SceneTree
## Planche des CAPTURES du corps à la 3e personne (corps_coups_tps.res) : le corps posé image par image (CorpsCoupsTps --tps-clip),
## caméra de jeu tournée autour du joueur. Une image PNG par pose dans --sortie (assemblées ensuite par ffmpeg).
## FENÊTRE (via godot_slot.sh : hors écran) :
##   godot --path . --resolution 640x360 --script res://outils/planche_captures_tps.gd -- --nouvelle --sortie=C:/... --clips=slash_1:0:45:3,...
##         [--orbites=150,90]
var s: Node
var j: CharacterBody3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _go() -> void:
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	s.mannequin.position = Vector3(-16.0, 0.0, -16.0)
	j.basculer_vue(true)
	s.placer_joueur(Vector3(0.0, 0.0, 4.0), 0.0, -12.0)
	for i in 30:
		await process_frame
	var ct: CorpsCoupsTps = j.corps.coups_tps
	var sortie := _arg("sortie", "C:/Users/lopezk19/Jeux/tmp_tps_films/planche")
	DirAccess.make_dir_recursive_absolute(sortie)
	var cam := Camera3D.new()
	cam.fov = 50.0
	s.add_child(cam)
	cam.current = true
	for orb in _arg("orbites", "150").split(","):
		# caméra libre autour du joueur (orbite en degrés depuis l'arrière), 4 m, à hauteur de poitrine
		var a0 := deg_to_rad(float(orb))
		var centre := j.global_position + Vector3(0, 1.0, 0)
		cam.global_position = centre + Vector3(sin(a0), 0.25, cos(a0)) * 4.0
		cam.look_at(centre)
		for spec in _arg("clips", "slash_1:0:45:3").split(","):
			var d := spec.split(":")
			var a := int(d[1])
			var b := int(d[2])
			var pas := int(d[3]) if d.size() > 3 else 3
			var im := a
			while im <= b:
				ct._force = "%s:%d" % [d[0], im]
				for k in 3:
					await process_frame
				var img := root.get_viewport().get_texture().get_image()
				img.save_png("%s/%s_o%s_%03d.png" % [sortie, d[0], orb, im])
				im += pas
	quit(0)
