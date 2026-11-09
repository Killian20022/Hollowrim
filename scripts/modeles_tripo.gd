class_name ModelesTripo
## Modèles Tripo PAR DÉFAUT (validés le 2026-11-08) : gardes du village (lancier, garde à l'épée, archer : GardeTripo), jarl Gunnar Aldrsson
## (JarlTripo, à la place du chef), draugr guerrier, archer draugr, squelette à mains nues (EnnemiTripo) et gobelin de la grotte des bandits.
## Les ANCIENS corps (GuerrierNordique / Gardien des gardes, PnjNordique du chef, DraugrNordique, SqueletteGuerrier, bandit guetteur)
## ne sont pas supprimés : ils restent chargeables pour d'autres factions (voir docs/MODELES_TRIPO.md).
##   Pour toute la partie : argument utilisateur `--modeles-anciens` (tous les groupes) ou `--modeles-anciens=gardes,jarl,ennemis,gobelin`
##   (seulement ceux-là). Les anciennes options `--gardes-tripo`, `--jarl-tripo`, `--ennemis-tripo`, `--gobelin-tripo` sont acceptées sans effet.
##   Pour UN personnage : « "modele_ancien": true » dans ses données (data/gardes.json, data/villageois.json, ennemis de la grotte) ou dans
##   les options d'un ennemi (monde.creer_draugr) : il garde l'ancien corps même si les autres sont en Tripo.
## Ne pas confondre avec `--pnj-anciens` / `--persos-anciens` (corps encore plus anciens : Humain Quaternius, avant les PNJ nordiques).

const GROUPES := ["gardes", "jarl", "ennemis", "gobelin"]
static var _anciens := {}     # groupe -> bool, lu une fois

## Vrai si le groupe utilise les modèles Tripo (défaut), faux avec --modeles-anciens[=…groupe…].
static func actif(groupe: String) -> bool:
	if _anciens.is_empty():
		_lire(OS.get_cmdline_user_args())
	return not bool(_anciens.get(groupe, false))

## Vrai si les données d'un personnage imposent l'ancien corps : « "modele_ancien": true » (gardes, villageois, ennemis, specs d'EnnemisNordiques).
## (Pas « modele » : data/villageois.json s'en sert déjà pour le corps Humain, et draugr.gd pour son Node3D.)
static func ancien_impose(donnees: Dictionary) -> bool:
	return bool(donnees.get("modele_ancien", false))

## Tests : relit les arguments (ou `args` simulés), au lieu du cache.
static func relire(args: Variant = null) -> void:
	_anciens.clear()
	_lire(args if args is Array or args is PackedStringArray else OS.get_cmdline_user_args())

static func _lire(args: Variant) -> void:
	for g: String in GROUPES:
		_anciens[g] = false
	for a: String in args:
		if a == "--modeles-anciens":
			for g: String in GROUPES:
				_anciens[g] = true
		elif a.begins_with("--modeles-anciens="):
			for g: String in a.trim_prefix("--modeles-anciens=").split(",", false):
				if _anciens.has(g.strip_edges()):
					_anciens[g.strip_edges()] = true
