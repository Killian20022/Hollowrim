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
	# donjons : objets de quête (valeur 0) et objets de valeur (pas de consommables)
	"fragment_sceau_os": {"nom": "Fragment du sceau des Os", "poids": 0.6, "valeur": 0},
	"fragment_sceau_givre": {"nom": "Fragment du sceau du Givre", "poids": 0.6, "valeur": 0},
	"fragment_sceau_eau": {"nom": "Fragment du sceau de l’Eau", "poids": 0.6, "valeur": 0},
	"cle_archives": {"nom": "Clé des archives", "poids": 0.2, "valeur": 0},
	"minerai_fer": {"nom": "Minerai de fer", "poids": 3.0, "valeur": 12},
	"minerai_argent": {"nom": "Minerai d’argent", "poids": 2.5, "valeur": 45},
	"cristal_givre": {"nom": "Cristal de givre", "poids": 0.8, "valeur": 70},
	"champignon_lumineux": {"nom": "Champignon lumineux", "poids": 0.1, "valeur": 8},
	"relique_offrande": {"nom": "Relique d’offrande royale", "poids": 1.5, "valeur": 90},
	"registre_hrafn": {"nom": "Registre de Hrafn", "poids": 0.8, "valeur": 0},
	"journal_sigrun": {"nom": "Journal de Solveig", "poids": 0.3, "valeur": 0},
	"broche_sigrun": {"nom": "Broche de Solveig", "poids": 0.1, "valeur": 0},
	"hache_kolbeinn": {"nom": "Hache de Kolbeinn le Gelé", "poids": 7.0, "valeur": 200},
	"fourrure_troll": {"nom": "Fourrure de troll givrée", "poids": 4.0, "valeur": 60},
	"croc_troll": {"nom": "Croc de troll", "poids": 0.3, "valeur": 18},
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
