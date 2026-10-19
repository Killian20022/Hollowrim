extends SceneTree
func _initialize() -> void:
	var d: Control = load("res://scripts/dialogue.gd").new()
	var j := CharacterBody3D.new()
	d.joueur = j
	root.add_child(d)
	await process_frame
	var t: String = "Une quarantaine d’âmes, une forêt, de la neige. Voilà tout le royaume. Plus dix mots pour remplir."
	print("largeur ", d._police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, " pour ", t.length(), " car. hauteur ", d._police.get_height(16))
	d._texte.text = t
	d._texte.size = Vector2(292, 44)
	await process_frame
	print("lignes ", d._texte.get_line_count(), " ", d._texte.get_minimum_size())
	quit()
