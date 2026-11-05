class_name Factions
## Table des FACTIONS des ennemis et de la faune (data/factions.json, retours exe 5) : draugr, araignee, pillard, troll, mage, loup,
## faune, et leurs relations deux à deux (« allie », « neutre », « hostile »). Une source unique pour :
##   - le PLACEMENT : deux factions hostiles ne partagent jamais un repaire (outils/test_factions.gd mesure tous les postes) ;
##   - l'IA : deux ennemis de factions hostiles qui se croisent se battent (Rivalites).
## Faction d'un ennemi vivant : Factions.de(noeud) (propriété `faction` si elle est posée, sinon déduite du script : espèce de
## BeteQuat, bandit humain de draugr.gd = pillard…). Faction d'un poste dans les données d'un lieu : Factions.de_donnees(d, lieu).

const FICHIER := "res://data/factions.json"

static var _table: Dictionary = {}
static var _rel: Dictionary = {}

static func table() -> Dictionary:
	if _table.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
		assert(d is Dictionary, "data/factions.json illisible")
		_table = d
		_rel.clear()
		for r: Array in _table["relations"]:
			_rel[_cle(String(r[0]), String(r[1]))] = String(r[2])
	return _table

static func _cle(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

static func noms() -> Array:
	return (table()["factions"] as Dictionary).keys()

static func existe(f: String) -> bool:
	return (table()["factions"] as Dictionary).has(f)

static func distance_min() -> float:
	return float(table().get("distance_min", 15.0))

## « allie », « neutre » ou « hostile » ; une faction inconnue (ou vide : le joueur, un PNJ) est neutre envers tous.
static func relation(a: String, b: String) -> String:
	table()
	if a == "" or b == "":
		return "neutre"
	if a == b:
		return "allie"
	return String(_rel.get(_cle(a, b), "neutre"))

static func hostiles(a: String, b: String) -> bool:
	return relation(a, b) == "hostile"

## Factions hostiles à `f` (la faune n'en a aucune : elle fuit, elle ne se bat pas).
static func ennemies_de(f: String) -> Array:
	var r: Array = []
	for g: String in noms():
		if hostiles(f, g):
			r.append(g)
	return r

## Faction d'un nom d'IA ou d'une espèce (« araignee », « troll_givre », « cerf »…) ; "" si inconnu.
static func de_ia(nom: String) -> String:
	return String((table()["ia"] as Dictionary).get(nom, ""))

## Faction d'un ennemi de draugr.gd (pas d'IA propre) selon le lieu : « grotte » (bandits) → pillard, « crypte » / « surface » → draugr.
static func de_lieu(lieu: String) -> String:
	return String((table()["types_draugr"] as Dictionary).get(lieu, "draugr"))

## Faction d'un poste d'ennemi dans les données d'un lieu (grotte_donnees « ennemis », crypte_donjon._e) : champ « faction » imposé,
## sinon son « ia » (dans `extra` pour la crypte), sinon la faction par défaut du lieu.
static func de_donnees(d: Dictionary, lieu: String) -> String:
	if d.has("faction"):
		return String(d["faction"])
	var ia := String(d.get("ia", (d.get("extra", {}) as Dictionary).get("ia", "")))
	if ia != "":
		return de_ia(ia)
	return de_lieu(lieu)

## Faction d'un ennemi vivant. Ordre : propriété `faction` non vide, espèce (BeteQuat), script à IA propre, bandit humain (draugr.gd).
static func de(n: Object) -> String:
	if n == null or not is_instance_valid(n):
		return ""
	var f: Variant = n.get("faction")
	if f is String and f != "":
		return f
	var esp: Variant = n.get("espece")
	if esp is String and esp != "":
		return de_ia(esp)
	var s := n.get_script() as Script
	var chemin := s.resource_path.get_file().get_basename() if s != null else ""
	match chemin:
		"troll_givre_ia":
			return "troll"
		"mage_nordique_ia":
			return "mage"
		"draugr":
			return "pillard" if n.get("_humain") == true else "draugr"
	return ""
