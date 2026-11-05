class_name EmploiDuTemps
extends RefCounted
## Emploi du temps des civils (lot vie_pnj P1) : pur calcul, sans nœud. Lit data/vie/planning.json.
##   mode(fiche, heure, id) -> "poste" (travail) | "soir" (feu, longue maison) | "maison" (rentre, dort)
## Fenêtres : poste = [reveil, debut_soir[ ; soir = [debut_soir, rentree[ ; maison = [rentree, reveil[ (traverse minuit). Chaque PNJ est décalé
## de ±`etalement` heures, dérivé de son id (stable d'une partie à l'autre, sans toucher au flux d'aléa du monde).

const DONNEES := "res://data/vie/planning.json"
static var _cache := {}

static func donnees() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	if not FileAccess.file_exists(DONNEES):
		push_warning("Vie : planning introuvable : " + DONNEES)
		return {}
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	if not (json is Dictionary):
		push_warning("Vie : planning invalide : " + DONNEES)
		return {}
	_cache = json
	return json

## Fiche fusionnée d'un PNJ : défauts du type (paysan, chasseur…), puis fiche propre à l'id, puis horaires du profil.
static func fiche(id: String, type := "") -> Dictionary:
	var d := donnees()
	var f: Dictionary = {}
	var t: Dictionary = (d.get("types", {}) as Dictionary).get(type, {})
	f.merge(t, true)
	f.merge((d.get("pnj", {}) as Dictionary).get(id, {}), true)
	var p: Dictionary = (d.get("profils", {}) as Dictionary).get(String(f.get("profil", "travailleur")), {})
	for k in p:
		if not f.has(k):
			f[k] = p[k]
	return f

## Décalage de l'id en heures, dans [-etalement, +etalement] (déterministe).
static func decalage(id: String) -> float:
	var e := float(donnees().get("etalement", 0.25))
	var h := id.hash() % 2001                       # 0..2000
	return (float(h) / 1000.0 - 1.0) * e

static func _dans(h: float, a: float, b: float) -> bool:
	return (h >= a and h < b) if a <= b else (h >= a or h < b)

static func mode(f: Dictionary, heure: float, id: String) -> String:
	if f.has("toujours"):
		return String(f["toujours"])
	var dec := decalage(id)
	var reveil := float(f.get("reveil", 6.5)) + dec
	var debut_soir := float(f.get("debut_soir", 18.5)) + dec
	var rentree := float(f.get("rentree", 21.5)) + dec
	var h := fposmod(heure, 24.0)
	if _dans(h, reveil, debut_soir):
		return "poste"
	if _dans(h, debut_soir, rentree):
		return "soir"
	return "maison"
