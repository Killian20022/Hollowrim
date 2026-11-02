extends RefCounted
## Pièces d'armure livrées par une branche « armures HD » mais pas encore dans data/objets/armures.json (l'agent DONNÉES les y
## reporte) : sources_blender/armures/*/pieces.json ({"objets": {id: fiche}}) injectées dans Inventaire.OBJETS pour les TESTS et les
## CAPTURES seulement (jamais en jeu). Renvoie les ids ajoutés.
##   const PiecesEssai := preload("res://outils/pieces_essai.gd") ; PiecesEssai.injecter()

static func injecter() -> Array[String]:
	var ajoutes: Array[String] = []
	var racine := "res://sources_blender/armures/"
	for d in DirAccess.get_directories_at(racine):
		var f := racine + d + "/pieces.json"
		if not FileAccess.file_exists(f):
			continue
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
		if not j is Dictionary:
			continue
		var o: Dictionary = j.get("objets", {})
		for id: String in o:
			if not Inventaire.OBJETS.has(id):
				Inventaire.OBJETS[id] = o[id]
				ajoutes.append(id)
	return ajoutes
