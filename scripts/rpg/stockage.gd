class_name Stockage
extends RefCounted
## Coffres sûrs du joueur (Q9 c) : coffre loué chez Grima dès le début, coffre de la maison (à acheter, ~1500 pièces).
## Contenu sauvegardé tel quel (clé « stockage », version 2), jamais renouvelé. Les coffres du monde restent « prendre
## seulement » (ButinTables, FenetreButin). État statique comme Marchand (une seule partie à la fois).
## LOT 0 : registre, transfert, sauvegarde. LOT E (propriétaire de ce fichier) : fenêtre de transfert à deux pages (FenetreCoffre),
## coffres posés dans les intérieurs, achat de la maison, râtelier (ServicesPnj). Contrat : docs/RPG.md §4.
## Maison à acheter : la maison des Frostmark (intérieur « chasseurs » du village : Ylva loge aux séchoirs depuis qu'Eirik a
## disparu), vendue par Gunnar, le chef, PRIX_MAISON pièces ; l'acheteur reçoit la clé (objet de quête cle_maison,
## data/objets/stockage.json) ; coffre et râtelier de la maison accessibles ensuite.


## Coffres connus : id -> {nom, acces}. acces = « depart » (dispo dès le début) | « maison » (après achat).
const COFFRES := {
	"coffre_grima": {"nom": "Coffre loué chez Grima", "acces": "depart"},
	"coffre_maison": {"nom": "Coffre de la maison", "acces": "maison"},
}
const PRIX_MAISON := 1500
## Intérieur du village (Village.interieur(id)) qui devient la maison du joueur, et son nom une fois achetée.
const MAISON := "chasseurs"
const NOM_MAISON := "Maison des Frostmark"
const CLE_MAISON := "cle_maison"

static var _coffres := {}          # id -> Conteneur
static var maison_achetee := false

## Conteneur d'un coffre sûr (créé vide au premier appel) ; null si l'id n'est pas un coffre connu.
static func conteneur(id: String) -> Conteneur:
	if not COFFRES.has(id):
		return null
	if not _coffres.has(id):
		_coffres[id] = Conteneur.new()
	return _coffres[id]

## Le coffre est-il accessible au joueur maintenant ?
static func accessible(id: String) -> bool:
	if not COFFRES.has(id):
		return false
	return String(COFFRES[id]["acces"]) == "depart" or maison_achetee

## "" si `n` exemplaires de `id` peuvent passer de `de` à `vers`, sinon la raison.
static func refus_transfert(de: Conteneur, vers: Conteneur, id: String, n := 1) -> String:
	if de == null or vers == null or n <= 0:
		return "Impossible ici."
	if de.nombre(id) < n:
		return "Pas assez d'exemplaires."
	if id != "pieces" and Inventaire.est_quete(id) and not vers is Inventaire:
		return "Objet de quête : on le garde sur soi."
	return ""

## Déplace `n` exemplaires (ou pièces) : "" si fait, sinon la raison. Le sac peut dépasser sa capacité (surcharge, Q5 a :
## le joueur n'est jamais bloqué) ; un coffre n'a pas de limite.
static func transferer(de: Conteneur, vers: Conteneur, id: String, n := 1) -> String:
	var r := refus_transfert(de, vers, id, n)
	if r != "":
		return r
	de.retirer(id, n)
	vers.ajouter(id, n)
	return ""

## "" si le joueur peut acheter la maison maintenant, sinon la raison.
static func refus_achat_maison(inv: Conteneur) -> String:
	if maison_achetee:
		return "La maison est déjà à vous."
	if inv == null or inv.pieces < PRIX_MAISON:
		return "Il faut %d pièces (vous en avez %d)." % [PRIX_MAISON, 0 if inv == null else inv.pieces]
	return ""

## Achète la maison : paie PRIX_MAISON, donne la clé, ouvre le coffre de la maison. "" si fait, sinon la raison.
static func acheter_maison(inv: Conteneur) -> String:
	var r := refus_achat_maison(inv)
	if r != "":
		return r
	inv.retirer("pieces", PRIX_MAISON)
	if Inventaire.connu(CLE_MAISON) and not inv.a(CLE_MAISON):
		inv.ajouter(CLE_MAISON, 1)
	maison_achetee = true
	return ""

## Nouvelle partie.
static func reinitialiser() -> void:
	_coffres = {}
	maison_achetee = false

static func exporter() -> Dictionary:
	var c := {}
	for id in _coffres:
		if not (_coffres[id] as Conteneur).vide():
			c[id] = (_coffres[id] as Conteneur).exporter()
	return {"coffres": c, "maison_achetee": maison_achetee}

static func importer(d: Dictionary) -> void:
	reinitialiser()
	maison_achetee = bool(d.get("maison_achetee", false))
	var c: Variant = d.get("coffres", {})
	if c is Dictionary:
		for id in c:
			var k := conteneur(String(id))
			if k != null and c[id] is Dictionary:
				k.importer(c[id])
