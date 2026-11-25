extends "res://outils/film_feu_v2.gd"
## FILM de l'IMPACT DU JET DE FLAMMES (chantier magie/feu_impact_sol) : jet sur le sol (vue plongeante), balayage sol -> mur, mur.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 1280x720 --script res://outils/film_feu_sol.gd -- --nouvelle
##         --paisible --detail-sorts=eleve [--crypte] [--feu-v1] [--images=<dossier>]

func _film_feu() -> void:
	var crypte := _arg("crypte") != ""
	await _debut("impact du jet de flammes")
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "jet_flammes")
	await _attendre(0.5)
	_phase = "jet"
	var o: Vector3 = j.camera.global_position
	var av: Vector3 = -j.camera.global_basis.z
	av.y = 0.0
	av = av.normalized()
	if _mur_n != null:
		_mur_n.global_position = Vector3(o.x + 1.4, o.y + 0.6, o.z - 14.0)
		_mur_p = _mur_n.global_position
	_texte("jet sur le sol")
	await _regarder(o + av * 2.6 + Vector3.DOWN * 1.5, 0.5)
	magie.appuyer("gauche")
	await _attendre(0.25)
	await _capture("sol_0")
	await _attendre(0.45)
	await _capture("sol_1")
	await _attendre(0.6)
	await _capture("sol_2")
	_texte("balayage sol vers mur")
	if _mur_n != null:
		_mur_n.global_position = Vector3(o.x + 1.4, o.y + 0.6, o.z - 4.4)
		for k in 5:
			var t := float(k) / 4.0
			await _regarder(o + av * lerpf(3.0, 4.2, t) + Vector3.DOWN * lerpf(1.5, -0.4, t), 0.45)
	await _attendre(0.5)
	_texte("jet sur le mur")
	await _capture("mur_0")
	await _attendre(1.0)
	await _capture("mur_1")
	magie.relacher("gauche")
	await _attendre(0.5)
	await _capture("fin")
	await _attendre(1.0)
