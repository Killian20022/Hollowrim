extends "res://outils/film_rayon_v3.gd"
## VUE DE CÔTÉ du rayon noir (contrôle v5 : ce que voit un autre joueur, réseau / 3e personne) : plein air de nuit (--heure=11 : jour),
## rayon tenu 1 s sur une cible, puis une caméra posée à 4 m sur le côté du faisceau. Image : <--images>/cote.png
##   godot --path . --fixed-fps 60 --resolution 1280x720 --script res://outils/cote_rayon_v5.gd -- --nouvelle --paisible --detail-sorts=eleve --images=<dossier>

func _film() -> void:
	if _arg("heure") != "" and s.get("cycle") != null:
		s.cycle.heure = float(_arg("heure"))
		await _attendre(1.0)
	await _site_ouvert()
	var o: Vector3 = j.camera.global_position
	var cible: Vector3 = _cibles[0] + Vector3(0, 0.8, 0)
	await _regarder(cible, 0.4)
	magie.raccourci_sort_gauche(RayonNoir.ID)
	await _attendre(0.4)
	magie.appuyer("gauche")
	await _attendre(1.2)
	var milieu := o.lerp(cible, 0.45)
	var d := (cible - o).normalized()
	var cote := d.cross(Vector3.UP).normalized()
	var cam := Camera3D.new()
	cam.fov = 60.0
	s.add_child(cam)
	cam.global_position = milieu + cote * 4.0 + Vector3.UP * 0.6
	cam.look_at(milieu, Vector3.UP)
	cam.current = true
	await _attendre(0.5)
	Engine.time_scale = 0.0
	for i in 4:
		await process_frame
	if _dossier != "":
		root.get_viewport().get_texture().get_image().save_png(_dossier.path_join("cote.png"))
	Engine.time_scale = 1.0
	magie.relacher("gauche")
	await _attendre(0.4)
