class_name Inventaire
extends RefCounted
## Sac du joueur : objets empilés par identifiant, plus les pièces.

signal change

const OBJETS := {
	"os_draugr": {"nom": "Os de draugr", "poids": 0.5, "valeur": 2},
	"poussiere_tombe": {"nom": "Poussière de tombe", "poids": 0.1, "valeur": 6},
	"lame_antique": {"nom": "Lame antique ébréchée", "poids": 8.0, "valeur": 25},
	"amulette_givre": {"nom": "Amulette de givre", "poids": 0.3, "valeur": 40},
	"anneau_givre": {"nom": "Anneau de givre", "poids": 0.1, "valeur": 0},
	"amulette_eirik": {"nom": "Amulette d’Eirik", "poids": 0.2, "valeur": 0},
	"epee_skarnholt": {"nom": "Épée de Skarnholt", "poids": 9.0, "valeur": 120},
	"ecaille_dragon": {"nom": "Écaille de dragon", "poids": 2.0, "valeur": 80},
}

var pieces := 0
var objets := {}

func ajouter(id: String, nombre := 1) -> void:
	if id == "pieces":
		pieces += nombre
	else:
		objets[id] = objets.get(id, 0) + nombre
	change.emit()

func retirer(id: String, nombre := 1) -> void:
	objets[id] = objets.get(id, 0) - nombre
	if objets[id] <= 0:
		objets.erase(id)
	change.emit()

func a(id: String) -> bool:
	return objets.get(id, 0) > 0

func nom(id: String) -> String:
	return "pièces" if id == "pieces" else OBJETS[id]["nom"]

func poids() -> float:
	var total := 0.0
	for id in objets:
		total += OBJETS[id]["poids"] * objets[id]
	return total

func exporter() -> Dictionary:
	return {"pieces": pieces, "objets": objets.duplicate()}

func importer(d: Dictionary) -> void:
	pieces = int(d.get("pieces", 0))
	objets = {}
	for id in d.get("objets", {}):
		if OBJETS.has(id):
			objets[id] = int(d["objets"][id])
	change.emit()
