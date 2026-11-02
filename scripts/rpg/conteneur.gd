class_name Conteneur
extends RefCounted
## Conteneur générique d'objets empilés par identifiant (+ pièces) : base du sac (Inventaire), du coffre loué chez Grima et
## du coffre de la maison (Stockage). Les fiches viennent toujours de Inventaire.objet(id) (registre unique, data/objets/).
## Contrat : docs/RPG.md §4. Aucune règle d'interface ici.

signal change

var pieces := 0
var objets := {}

func nombre(id: String) -> int:
	return pieces if id == "pieces" else int(objets.get(id, 0))

func ajouter(id: String, nombre := 1) -> void:
	if id == "pieces":
		pieces += nombre
	else:
		objets[id] = objets.get(id, 0) + nombre
	change.emit()

func retirer(id: String, nombre := 1) -> void:
	if id == "pieces":
		pieces = maxi(0, pieces - nombre)
		change.emit()
		return
	objets[id] = objets.get(id, 0) - nombre
	if objets[id] <= 0:
		objets.erase(id)
	change.emit()

func a(id: String) -> bool:
	return objets.get(id, 0) > 0

func nom(id: String) -> String:
	return "pièces" if id == "pieces" else String(Inventaire.objet(id).get("nom", id))

func poids() -> float:
	var total := 0.0
	for id in objets:
		total += float(Inventaire.objet(id).get("poids", 0.0)) * objets[id]
	return total

## Capacité en poids ; INF = sans limite (coffres). Le sac la redéfinit (Inventaire.capacite).
func capacite() -> float:
	return INF

## Combien d'exemplaires de `id` peuvent encore entrer sans dépasser la capacité (9999 si sans limite ou sans poids).
func place_pour(id: String) -> int:
	var w := float(Inventaire.objet(id).get("poids", 0.0))
	if id == "pieces" or w <= 0.0 or is_inf(capacite()):
		return 9999
	return maxi(0, int(floorf((capacite() - poids() + 0.001) / w)))

## Identifiants d'une catégorie (Inventaire.CATEGORIES), dans l'ordre d'arrivée.
func ids_de(categorie: String) -> Array[String]:
	var r: Array[String] = []
	for id in objets:
		if Inventaire.categorie_de(id) == categorie:
			r.append(String(id))
	return r

func vide() -> bool:
	return objets.is_empty() and pieces == 0

func exporter() -> Dictionary:
	return {"pieces": pieces, "objets": objets.duplicate()}

## Relit {pieces, objets} : identifiants renommés traduits (Inventaire.ALIAS), inconnus ignorés (jamais de plantage).
func importer(d: Dictionary) -> void:
	pieces = int(d.get("pieces", 0))
	objets = {}
	var o: Variant = d.get("objets", {})
	if o is Dictionary:
		for id in o:
			var vrai := Inventaire.alias(String(id))
			if Inventaire.connu(vrai):
				objets[vrai] = int(objets.get(vrai, 0)) + int(o[id])
	change.emit()
