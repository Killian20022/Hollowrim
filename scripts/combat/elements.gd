class_name Elements
## Dégâts élémentaires, statuts, réactions entre écoles et combos épée + statut, branchés sur le chemin UNIQUE des coups
## du joueur (DegatsCombat.appliquer appelle avant_coup puis apres_coup). Données : data/magie/reactions.json (réactions,
## combos de l'épée) ; règles et équilibrage : docs/MAGIE.md.
##
## Clés d'`info` lues ici (en plus du contrat de l'épée, docs/DEGATS.md) :
##   ecole ("feu", "glace", "electricite", "tenebres") : élément du coup (sort, ou lame enchantée)
##   statut, duree_statut, puissance_statut : statut posé si le coup porte
##   lanceur (le joueur) : paie le mana des réactions, reçoit le drain
##   drain : part des dégâts rendue en vie au lanceur
##   continu : tic d'un sort canalisé (pas d'arrêt sur image, pas de plaie)
##   reaction_de : coup né d'une réaction ou d'un statut (ne relance ni réaction ni combo)
## Écrit : combo (nom du combo de l'épée), enchant (école de la lame), reaction (nom de la réaction déclenchée).

const FICHIER := "res://data/magie/reactions.json"
const ATTAQUES_EPEE := ["legere", "lourde", "chargee_max", "contre"]

static var _table := {}
## Le joueur (posé par MainSort) : lame enchantée, soin des combos.
static var joueur: Node
## Journal des réactions et combos (tests, débogage) : [{nom, genre, cible, position}].
static var journal: Array = []

static func table() -> Dictionary:
	if _table.is_empty():
		var t = JSON.parse_string(FileAccess.get_file_as_string(FICHIER)) if FileAccess.file_exists(FICHIER) else null
		_table = t if t is Dictionary else {"regles": [], "combos_epee": {}}
	return _table

static func resistance(cible: Node, type: String) -> float:
	var c = cible.get("combat") if cible != null else null
	if c is CombatEnnemi:
		return float((c as CombatEnnemi).profil.resistances.get(type, 1.0))
	return 1.0

static func _magie() -> Node:
	if joueur == null or not is_instance_valid(joueur):
		return null
	var m = joueur.get("mains")
	return m.get("magie") if m != null else null

## Avant recevoir_coup : corruption de la cible, lame enchantée, combo de l'épée sur une cible qui porte un statut.
## Modifie `info` (même dictionnaire) ; renvoie les dégâts à transmettre.
static func avant_coup(cible: Node, degats: float, info: Dictionary) -> float:
	if cible == null or info.has("reaction_de"):
		return degats
	var epee: bool = String(info.get("attaque", "")) in ATTAQUES_EPEE and String(info.get("type", "tranchant")) == "tranchant" and not info.has("ecole")
	if epee:
		var magie := _magie()
		# phase 5 : lame enchantée (dégâts de l'école en plus, selon la résistance de la cible, et son statut)
		if magie != null and magie.has_method("enchantement_actif"):
			var en: Dictionary = magie.enchantement_actif()
			if not en.is_empty():
				var s: DonneesSort = en["sort"]
				degats += s.degats_enchant * resistance(cible, s.type_degats)
				info["enchant"] = s.ecole
				info["ecole"] = s.ecole
				info["statut"] = s.statut
				info["duree_statut"] = s.duree_statut
				info["puissance_statut"] = s.puissance_statut
				info["lanceur"] = joueur
		# combos épée + statut (le premier statut trouvé dans l'ordre de la table)
		var st := Statuts.de(cible, false)
		if st != null:
			var combos: Dictionary = table().get("combos_epee", {})
			for nom_statut in combos:
				if nom_statut.begins_with("_") or not st.actifs.has(nom_statut):
					continue
				var c: Dictionary = combos[nom_statut]
				degats *= float(c.get("mult_degats", 1.0))
				if info.has("stagger"):
					info["stagger"] = float(info["stagger"]) * float(c.get("mult_stagger", 1.0))
				if c.has("prolonge"):
					st.prolonger(nom_statut, float(c["prolonge"]))
				if c.get("soin_part", 0.0) > 0.0:
					info["drain"] = float(c["soin_part"])
					info["lanceur"] = joueur
				if c.get("consomme", false):
					st.retirer(nom_statut)
				info["combo"] = String(c.get("nom", nom_statut))
				journal.append({"nom": info["combo"], "genre": "combo", "cible": cible, "position": (cible as Node3D).global_position})
				break
		# épée juste après un sort sur la même cible (ouverture du guerrier-mage)
		var m2 := _magie()
		if m2 != null and m2.has_method("bonus_apres_sort"):
			degats *= float(m2.bonus_apres_sort(cible))
	degats *= Statuts.multiplicateur_recu(cible)
	return degats

## Après recevoir_coup : réaction élémentaire (consomme le statut présent) sinon pose du statut du coup, drain.
static func apres_coup(cible: Node, resultat: String, info: Dictionary, degats: float) -> void:
	if cible == null or not is_instance_valid(cible) or not (resultat in ["touche", "tue"]):
		return
	var lanceur: Node = info.get("lanceur")
	var ecole := String(info.get("ecole", ""))
	var reagi := false
	if ecole != "" and not info.has("reaction_de"):
		reagi = _reagir(cible, ecole, info, lanceur)
	if not reagi and resultat == "touche" and String(info.get("statut", "")) != "":
		var st := Statuts.de(cible)
		if st != null:
			st.appliquer(String(info["statut"]), float(info.get("duree_statut", 3.0)), float(info.get("puissance_statut", 1.0)), lanceur)
	var drain := float(info.get("drain", 0.0))
	if drain > 0.0 and lanceur != null and is_instance_valid(lanceur) and lanceur.has_method("soigner"):
		lanceur.soigner(degats * resistance(cible, String(info.get("type", ""))) * drain)

## Cherche une règle (statut présent sur la cible × école du coup) ; la déclenche si la cible n'est pas en recharge et si
## le lanceur paie le mana. Renvoie vrai si une réaction a eu lieu.
static func _reagir(cible: Node, ecole: String, info: Dictionary, lanceur: Node) -> bool:
	var st := Statuts.de(cible, false)
	if st == null or st.recharge_reaction > 0.0:
		return false
	for r: Dictionary in table().get("regles", []):
		if String(r["ecole"]) != ecole or not st.actifs.has(String(r["statut"])):
			continue
		var cout := float(r.get("cout_mana", 0.0))
		if lanceur != null and lanceur.has_method("depenser_mana") and not lanceur.depenser_mana(cout):
			return false   # pas assez de mana : coup normal, pas de réaction
		st.retirer(String(r["statut"]))
		st.recharge_reaction = float(r.get("recharge_cible", 2.5))
		declencher(r, cible, lanceur)
		info["reaction"] = String(r["nom"])
		return true
	return false

## Effet d'une réaction : dégâts de zone (la cible comprise), statut appliqué, chaîne éventuelle, effet visuel.
static func declencher(r: Dictionary, cible: Node, lanceur: Node) -> void:
	var centre: Vector3 = _centre(cible)
	var rayon := float(r.get("rayon", 0.0))
	var victimes: Array = [cible]
	if rayon > 0.0:
		for e in cibles_dans(centre, rayon):
			if e != cible:
				victimes.append(e)
	if int(r.get("chaine", 0)) > 0:
		victimes = [cible]
		var pts: Array[Vector3] = [centre]
		var reste := int(r["chaine"])
		for e in cibles_dans(centre, rayon):
			if reste <= 0:
				break
			if e != cible:
				victimes.append(e)
				pts.append(_centre(e))
				reste -= 1
		EffetsMagie.chaine("tenebres", pts)
	var origine: Vector3 = (lanceur as Node3D).global_position if lanceur is Node3D else centre + Vector3(0, 0, 1)
	for v in victimes:
		var info := {"type": String(r.get("type_degats", "magique")), "attaque": "sort", "stagger": 10.0, "reaction_de": String(r["nom"]),
			"lanceur": lanceur, "point": _centre(v)}
		DegatsCombat.appliquer(v, float(r.get("degats", 10.0)), origine, false, info)
		var applique := String(r.get("applique", ""))
		if applique != "" and is_instance_valid(v):
			var sv := Statuts.de(v)
			if sv != null:
				sv.appliquer(applique, float(r.get("duree", 2.0)), float(r.get("puissance", 0.5)), lanceur)
	EffetsMagie.reaction(String(r["nom"]), centre, maxf(rayon, 1.0))
	journal.append({"nom": String(r["nom"]), "genre": "reaction", "cible": cible, "position": centre})

## Cibles vivantes (groupes « ennemis » et « cibles_combat ») dont le centre est à moins de `rayon` de `p`, les plus proches d'abord.
static func cibles_dans(p: Vector3, rayon: float) -> Array:
	var arbre := Engine.get_main_loop() as SceneTree
	var res := []
	if arbre == null:
		return res
	for g in ["ennemis", "cibles_combat"]:
		for e in arbre.get_nodes_in_group(g):
			if not (e is Node3D) or not is_instance_valid(e) or res.has(e):
				continue
			if e.has_method("vivant") and not e.vivant():
				continue
			if e.get("est_mort") == true:
				continue
			if _centre(e).distance_to(p) <= rayon + 0.4:
				res.append(e)
	res.sort_custom(func(a, b): return _centre(a).distance_squared_to(p) < _centre(b).distance_squared_to(p))
	return res

static func _centre(e: Node) -> Vector3:
	if e.has_method("point_impact"):
		return e.point_impact()
	return (e as Node3D).global_position + Vector3(0, 1.1, 0)
