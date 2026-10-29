class_name Inventaire
extends RefCounted
## Sac du joueur : objets empilés par identifiant, plus les pièces.
## Catalogue = OBJETS (ci-dessous) + data/butin/objets.json (consommables, armes et tomes trouvables : docs/BUTIN.md) ;
## lire un objet par Inventaire.objet(id) / Inventaire.connu(id), jamais OBJETS seul.

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
	# donjons : objets de quête (valeur 0) et objets de valeur ; consommables (potions, nourriture) : data/butin/objets.json
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

const FICHIER_BUTIN := "res://data/butin/objets.json"
static var _butin := {}
static var _butin_lu := false

var pieces := 0
var objets := {}

## Fiche d'un objet : {nom, poids, valeur, [rarete, categorie, icone, effets]} ; {} si inconnu.
static func objet(id: String) -> Dictionary:
	if OBJETS.has(id):
		return OBJETS[id]
	if not _butin_lu:   # publié d'un coup puis marqué lu (lecture possible depuis le fil de construction de la crypte)
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_BUTIN)) if FileAccess.file_exists(FICHIER_BUTIN) else null
		_butin = d.get("objets", {}) if d is Dictionary else {}
		_butin_lu = true
	return _butin.get(id, {})

static func connu(id: String) -> bool:
	return not objet(id).is_empty()

## Catégorie d'un objet du sac : « consommable », « arme » ou « divers » (défaut).
static func categorie_de(id: String) -> String:
	return String(objet(id).get("categorie", "divers"))

## Identifiants du sac d'une catégorie, dans l'ordre d'arrivée.
func ids_de(categorie: String) -> Array[String]:
	var r: Array[String] = []
	for id in objets:
		if categorie_de(id) == categorie:
			r.append(String(id))
	return r

func nombre(id: String) -> int:
	return pieces if id == "pieces" else int(objets.get(id, 0))

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
	return "pièces" if id == "pieces" else String(objet(id).get("nom", id))

func poids() -> float:
	var total := 0.0
	for id in objets:
		total += float(objet(id).get("poids", 0.0)) * objets[id]
	return total

## Capacité du sac (poids) : au-delà, le joueur est surchargé (marche lente, pas de course). Les poids vont de 0,1 (anneau) à 10 (épée).
const CAPACITE := 100.0

func capacite() -> float:
	return CAPACITE

func surcharge() -> bool:
	return poids() > capacite() + 0.001

## Combien d'exemplaires de `id` le sac peut encore recevoir sans dépasser la capacité (grand nombre si l'objet ne pèse rien).
func place_pour(id: String) -> int:
	var w := float(objet(id).get("poids", 0.0))
	if id == "pieces" or w <= 0.0:
		return 9999
	return maxi(0, int(floorf((capacite() - poids() + 0.001) / w)))

func exporter() -> Dictionary:
	return {"pieces": pieces, "objets": objets.duplicate()}

func importer(d: Dictionary) -> void:
	pieces = int(d.get("pieces", 0))
	objets = {}
	for id in d.get("objets", {}):
		if connu(id):
			objets[id] = int(d["objets"][id])
	change.emit()
