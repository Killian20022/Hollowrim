class_name Metiers
extends RefCounted
## Gestes de métier (lot vie/metiers) : data/vie/metiers.json. Au poste de jour (et au feu du soir), un habitant enchaîne les étapes
## de son métier (clips EXISTANTS de Humain.bibliotheque(), commune aux corps PnjNordique, Humain et Tripo) au rythme d'une minuterie
## de villageois.gd (aucun _process en plus, aucune requête physique). Ici : lecture du fichier, résolution du métier d'un habitant,
## postes déplacés (étal, banc, bord du puits, tas de bois) appliqués aux données AVANT que le monde ne crée les corps.

const FICHIER := "res://data/vie/metiers.json"

static var _d: Dictionary = {}

static func donnees() -> Dictionary:
	if _d.is_empty() and FileAccess.file_exists(FICHIER):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
		if j is Dictionary:
			_d = j
		else:
			push_warning("Metiers : JSON invalide : " + FICHIER)
	return _d

static func actif() -> bool:
	return not OS.get_cmdline_user_args().has("--sans-metiers")

## Métier par nom ({} si inconnu) ; le nom est recopié dans la clé « nom ».
static func metier(nom: String) -> Dictionary:
	var m: Dictionary = (donnees().get("metiers", {}) as Dictionary).get(nom, {})
	if m.is_empty():
		return {}
	var out := m.duplicate(true)
	out["nom"] = nom
	return out

## Nom du métier d'un habitant (données de villageois.json / habitants.json) : pnj[id].metier, sinon celui de son lieu ; "" = aucun.
static func nom_pour(d: Dictionary) -> String:
	if not actif():
		return ""
	var p: Dictionary = (donnees().get("pnj", {}) as Dictionary).get(String(d.get("id", "")), {})
	if p.has("metier"):
		return String(p["metier"])
	if d.has("activite"):
		return ""          # activité propre (habitants.json) : on la garde telle quelle
	return String((donnees().get("lieux", {}) as Dictionary).get(String(d.get("lieu", "")), ""))

## Métier de la soirée au lieu `lieu` (« feu ») : "" = l'ancienne activité (Idle_Talking).
static func du_soir(lieu: String) -> String:
	return String((donnees().get("soirs", {}) as Dictionary).get(lieu, "")) if actif() else ""

## Recopie dans les données des habitants les postes de métier (pos, cap, vers, sedentaire) : à appeler sur la liste de Villageois.charger().
static func appliquer(liste: Array) -> void:
	if not actif():
		return
	var pnj: Dictionary = donnees().get("pnj", {})
	for d: Dictionary in liste:
		var p: Dictionary = pnj.get(String(d.get("id", "")), {})
		if p.is_empty():
			continue
		if p.has("pos"):
			d["pos"] = p["pos"]
		if p.has("sedentaire"):
			d["sedentaire"] = p["sedentaire"]
		if p.has("cap"):
			d["cap"] = float(p["cap"])
		elif p.has("vers") and p.has("pos"):
			d["cap"] = cap_vers(Vector2(float(p["pos"][0]), float(p["pos"][1])), Vector2(float(p["vers"][0]), float(p["vers"][1])))
		if p.has("vers"):
			d["metier_vers"] = p["vers"]

## Cap (degrés, convention des données : 0 = vers +Z) de `de` vers `vers` (plan x, z).
static func cap_vers(de: Vector2, vers: Vector2) -> float:
	var v := vers - de
	return rad_to_deg(atan2(v.x, v.y))

## Durée d'une étape (s) : min..max tiré au sort, sinon la longueur du clip (joué une fois).
static func duree(etape: Dictionary, anim: AnimationPlayer) -> float:
	if etape.has("min"):
		return randf_range(float(etape["min"]), float(etape.get("max", etape["min"])))
	var c := String(etape.get("clip", "Idle"))
	return anim.get_animation(c).length if anim != null and anim.has_animation(c) else 2.0
