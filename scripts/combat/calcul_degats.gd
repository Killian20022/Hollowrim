class_name CalculDegats
## Calcul des dégâts (pur, sans effet de bord) : complète l'info d'un coup puis applique type, armure, résistances, zone, blocage
## et posture. Contrat avec l'épée du joueur (branche combat/epee_fps) : recevoir_coup(degats, origine, puissant, info := {}) où
## info peut contenir "type", "point", "direction", "normale", "zone", "attaque", "arme", "stagger", "collider" ; tout ce qui
## manque est déduit ici (appels actuels de mains.gd, pièges, flèches : info vide).

## Force de stagger par défaut selon l'attaque (avant le poids de la cible).
const STAGGER := {"legere": 12.0, "lourde": 28.0, "chargee_max": 42.0, "contre": 34.0, "finisher": 999.0}
## Multiplicateur de dégâts selon l'attaque (le coup puissant de mains.gd a déjà sa propre base : 1,0).
const MULT_ATTAQUE := {"legere": 1.0, "lourde": 1.0, "chargee_max": 1.25, "contre": 1.3, "finisher": 1.0}
## Multiplicateur des coups critiques (tête au coup lourd, cible étourdie ou au sol).
const CRITIQUE := 1.5
## Os (squelettes) : multiplicateur des coups lourds (règle historique de draugr.gd : +30 %).
const OS_LOURD := 1.3
## Hauteurs relatives (part de la taille de la cible) des zones.
const H_TETE := 0.86
## La lame passe ~12 cm sous le réticule (taille de biais).
const AVANCE_LAME := 0.12
const H_TORSE := 0.52
const LARGEUR_BRAS := 0.2

static var _alterne := 1.0

## Complète `info` (copie) pour un coup de `quantite` venu de `origine` sur `cible` (Node3D au sol, taille `hauteur` m).
## `hauteur_visee` : hauteur (m, au-dessus des pieds de la cible) où passe le regard du joueur à la distance de la cible ; < 0 = inconnue
## (torse). La lame frappe un peu sous le réticule (AVANCE_LAME).
static func completer(info: Dictionary, cible: Node3D, quantite: float, origine: Vector3, puissant: bool, hauteur := 1.8, hauteur_visee := -1.0) -> Dictionary:
	var i := info.duplicate()
	i["quantite"] = quantite
	i["origine"] = origine
	i["puissant"] = puissant
	if not i.has("type") or String(i["type"]) == "":
		i["type"] = "tranchant"
	if not i.has("attaque") or String(i["attaque"]) == "":
		i["attaque"] = "lourde" if puissant else "legere"
	var base := cible.global_position
	var vers_cible := base - origine
	vers_cible.y = 0.0
	var avant := vers_cible.normalized() if vers_cible.length() > 0.01 else -cible.global_transform.basis.z
	var cote := avant.cross(Vector3.UP).normalized()
	# point : zone imposée, sinon là où passe le regard du joueur, sinon le torse ; sur la surface côté attaquant
	if not i.has("point") or not (i["point"] is Vector3):
		var h := hauteur * 0.64
		var z := String(i.get("zone", ""))
		if z == "" and hauteur_visee > 0.0:
			h = clampf(hauteur_visee - AVANCE_LAME, hauteur * 0.15, hauteur * 0.95)
		if z == "tete":
			h = hauteur * 0.9
		elif z == "jambes":
			h = hauteur * 0.3
		elif z == "bras":
			h = hauteur * 0.7
		var lateral := 0.0 if z != "bras" else 0.22 * _alterne
		i["point"] = base + Vector3(0, h, 0) - avant * 0.2 + cote * lateral
	if not i.has("direction") or not (i["direction"] is Vector3) or (i["direction"] as Vector3).length() < 0.01:
		# taille de biais (alternée gauche/droite comme l'épée de mains.gd), qui pousse vers l'arrière de la cible
		_alterne = -_alterne
		i["direction"] = (avant * 0.55 + cote * 0.8 * _alterne + Vector3.DOWN * (0.25 if puissant else 0.1)).normalized()
	else:
		i["direction"] = (i["direction"] as Vector3).normalized()
	if not i.has("normale") or not (i["normale"] is Vector3):
		i["normale"] = -avant
	if not i.has("zone") or String(i["zone"]) == "":
		var p: Vector3 = i["point"]
		var loc := p - base
		var lat := absf(loc.dot(cote))
		i["zone"] = zone_par_hauteur(loc.y / maxf(hauteur, 0.1), lat)
	if not i.has("stagger"):
		i["stagger"] = float(STAGGER.get(i["attaque"], 12.0))
	if not i.has("arme"):
		i["arme"] = "epee"
	return i

static func zone_par_hauteur(rel: float, lateral := 0.0) -> String:
	if rel >= H_TETE:
		return "tete"
	if rel >= H_TORSE:
		return "bras" if lateral > LARGEUR_BRAS else "torse"
	return "jambes"

## Résultat d'un coup. `etat` : {"posture", "etourdi", "au_sol", "de_face", "peut_bloquer", "boss", "en_attaque"}.
## Retour : {"info", "degats", "stagger", "critique", "impact", "bloque", "brise_garde"}.
static func calculer(i: Dictionary, p: ProfilCible, etat: Dictionary) -> Dictionary:
	var r := {"info": i, "degats": 0.0, "stagger": 0.0, "critique": false, "impact": "leger", "bloque": false, "brise_garde": false}
	var attaque := String(i["attaque"])
	var type := String(i["type"])
	var zone := String(i["zone"])
	var stagger := float(i["stagger"]) / maxf(p.poids, 0.1)
	if etat.get("boss", false):
		stagger *= 0.6
	var posture := float(etat.get("posture", p.posture_max))
	# --- blocage au bouclier (coups légers de face ; un coup lourd ne passe que si la garde est déjà entamée)
	if etat.get("peut_bloquer", false) and etat.get("de_face", false) and not etat.get("etourdi", false) and attaque != "finisher":
		var ratio := clampf(posture / maxf(p.posture_max, 1.0), 0.0, 1.0)
		var chance := p.chance_blocage * (0.4 + 0.6 * ratio)
		if attaque in ["lourde", "chargee_max"]:
			chance *= 0.35
		if randf() < chance:
			var usure := stagger * (0.55 if attaque == "legere" else 0.9)
			if posture - usure <= 0.0:
				r["brise_garde"] = true   # la garde cède : le coup passe et la posture tombe
			else:
				r["bloque"] = true
				r["stagger"] = usure
				r["impact"] = "leger"
				return r
	# --- dégâts
	var d := float(i["quantite"]) * float(MULT_ATTAQUE.get(attaque, 1.0))
	d *= float(p.resistances.get(type, 1.0))
	d *= float(p.zones.get(zone, 1.0))
	if type == "tranchant":
		d -= p.armure_tete if zone == "tete" else p.armure
	if p.matiere == "os" and attaque in ["lourde", "chargee_max"]:
		d *= OS_LOURD   # des os secs : les coups puissants les brisent
	d *= 1.0 - clampf(p.armure_part, 0.0, 0.9)
	var critique: bool = etat.get("etourdi", false) or etat.get("au_sol", false) or (zone == "tete" and attaque != "legere")
	if critique:
		d *= CRITIQUE
	r["degats"] = maxf(d, 1.0)
	r["critique"] = critique
	if type == "contondant" and p.matiere == "os":
		stagger *= 1.3
	if zone == "tete":
		stagger *= 1.25
	elif zone == "jambes":
		stagger *= 1.1
	if r["brise_garde"]:
		stagger = maxf(stagger, posture + 1.0)
	r["stagger"] = stagger
	# --- profil d'impact
	var imp := "leger"
	match attaque:
		"lourde", "contre":
			imp = "lourd"
		"chargee_max":
			imp = "critique"
		"finisher":
			imp = "finisher"
		_:
			imp = "moyen" if (zone == "tete" or stagger >= p.seuil_moyen * 1.2) else "leger"
	if critique and imp in ["leger", "moyen"]:
		imp = "lourd"
	elif critique and imp == "lourd":
		imp = "critique"
	r["impact"] = imp
	return r
