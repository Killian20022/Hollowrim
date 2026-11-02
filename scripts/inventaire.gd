class_name Inventaire
extends Conteneur
## Sac du joueur (Conteneur : objets empilés par identifiant + pièces) ET registre unique des fiches d'objets.
## Registre = data/objets/*.json (un fichier par catégorie, docs/RPG.md §2) + CatalogueArmes (data/armes/catalogue_armes.json :
## les 20 armes famille x matériau, fiches calculées). Lire une fiche par Inventaire.objet(id) / Inventaire.connu(id).
## (Avant le lot 0 RPG : constante OBJETS du code + data/butin/objets.json ; mêmes identifiants, mêmes fiches.)

const DOSSIER_OBJETS := "res://data/objets/"
## Catégories (champ `categorie` des fiches) ; absent = « divers ».
const CATEGORIES := ["arme", "armure", "bijou", "consommable", "ingredient", "quete", "divers"]
## Emplacements de corps (champ `emplacement` des armures et bijoux) : EquipementCorps. Les mains restent à EquipementMains.
const EMPLACEMENTS := ["tete", "torse", "mains", "pieds", "cou", "anneau"]
## Identifiants renommés : ancien -> nouveau (sauvegardes, conteneurs). Aucun renommage à ce jour ; ne jamais en retirer une ligne.
const ALIAS := {}

## Toutes les fiches de data/objets/ (id -> fiche), lues une fois au chargement du script. Garde le nom historique OBJETS
## (dragon.gd, quetes.gd, mecanisme.gd, tests) ; _butin = même dictionnaire (compatibilité de test_marchands).
static var OBJETS: Dictionary = _lire_registre()
static var _butin: Dictionary = OBJETS

static func _lire_registre() -> Dictionary:
	var tout := {}
	var fichiers := Array(DirAccess.get_files_at(DOSSIER_OBJETS))
	fichiers.sort()
	for f: String in fichiers:
		if not f.ends_with(".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER_OBJETS + f))
		if not d is Dictionary:
			push_warning("Objets : %s illisible" % f)
			continue
		var o: Dictionary = d.get("objets", {})
		for id in o:
			if tout.has(id):
				push_warning("Objets : %s défini deux fois (%s)" % [id, f])
			tout[id] = o[id]
	return tout

## Fiche d'un objet : {nom, poids, valeur, categorie, rarete, [emplacement, armure, type_armure, icone, effets, quete,
## description]} ; {} si inconnu. Ne pas modifier le dictionnaire rendu (partagé).
static func objet(id: String) -> Dictionary:
	if id.contains("+"):   # lot E : objet amélioré à la forge de Brodd, « <id>+<n> » (Forge.fiche_amelioree, docs/RPG.md §2)
		return Forge.fiche_amelioree(id)
	if OBJETS.has(id):
		return OBJETS[id]
	return CatalogueArmes.fiche_objet(id)   # armes trouvables (data/armes/catalogue_armes.json) : 20 armes, stats par famille et matériau

static func fiche(id: String) -> Dictionary:
	return objet(id)

static func connu(id: String) -> bool:
	return not objet(id).is_empty()

## Identifiant actuel d'un identifiant peut-être renommé (ALIAS).
static func alias(id: String) -> String:
	var vu := 0
	while ALIAS.has(id) and vu < 8:
		id = String(ALIAS[id])
		vu += 1
	return id

## Tous les identifiants connus (registre + catalogue d'armes), registre d'abord.
static func ids_connus() -> Array[String]:
	var r: Array[String] = []
	for id in OBJETS:
		r.append(String(id))
	for id in CatalogueArmes.ids():
		if not OBJETS.has(id):
			r.append(String(id))
	return r

## Catégorie d'un objet : une de CATEGORIES (« divers » par défaut).
static func categorie_de(id: String) -> String:
	return String(objet(id).get("categorie", "divers"))

## Emplacement de corps ("" si l'objet ne se porte pas sur le corps).
static func emplacement_de(id: String) -> String:
	return String(objet(id).get("emplacement", ""))

## Objet de quête : invendable, impossible à lâcher ou à déposer.
static func est_quete(id: String) -> bool:
	return bool(objet(id).get("quete", false))

## Capacité du sac (poids) : au-delà, le joueur est surchargé (marche lente, pas de course). Lot A (Q5 a) : 150 + vigueur ;
## armes allégées (1,5 à 11 kg), armures 0,5 à 17 kg : 6-8 armes + une armure lourde complète tiennent.
const CAPACITE := 150.0

## Bonus de charge (attribut vigueur, perks, bijoux) posé par joueur.recalculer_stats() ; 0 tant que rien ne le change.
var capacite_bonus := 0.0

func capacite() -> float:
	return CAPACITE + capacite_bonus

func surcharge() -> bool:
	return poids() > capacite() + 0.001
