extends "res://outils/film_feu_v2.gd"
## FILM de l'IMPACT DU JET DE FLAMMES (chantier magie/feu_impact_sol) : jet sur le sol (vue plongeante), balayage sol -> mur, mur.
##   godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 1280x720 --script res://outils/film_feu_sol.gd -- --nouvelle
##         --paisible --detail-sorts=eleve [--crypte] [--feu-v1] [--images=<dossier>]

## Mode réel (par défaut) : AUCUN plateau, la vraie forêt du jeu (neige, arbres, brouillard, post-traitement). `--arene` : l'ancien plateau.
func _site_ouvert() -> void:
	if _arg("arene") != "":
		await super._site_ouvert()

func _mur_pose(dist: float) -> void:
	if _arg("arene") != "":
		await super._mur_pose(dist)

func _film_feu() -> void:
	await _debut("impact du jet de flammes")
	magie.equiper("droite", "epee")
	magie.equiper("gauche", "jet_flammes")
	await _attendre(0.5)
	_phase = "jet"
	var o: Vector3 = j.camera.global_position
	var av: Vector3 = -j.camera.global_basis.z
	av.y = 0.0
	av = av.normalized()
	_texte("jet sur le sol")
	await _regarder(o + av * 2.6 + Vector3.DOWN * 1.5, 0.5)
	magie.appuyer("gauche")
	await _attendre(1.6)
	_texte("balayage : sol, arbres, relief")
	# tour d'horizon (jet continu) : le jet rencontre tout ce que la forêt offre (neige, troncs, rochers, feu de camp)
	var y0 := j.rotation.y
	var n := 150
	for k in n:
		j.rotation.y = y0 + TAU * float(k) / n
		j.tete.rotation.x = deg_to_rad(-12.0 - 10.0 * sin(float(k) * 0.35))
		await process_frame
	magie.relacher("gauche")
	await _attendre(0.8)
