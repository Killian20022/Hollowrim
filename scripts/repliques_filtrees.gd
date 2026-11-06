class_name RepliquesFiltrees
extends RefCounted
## RÉPLIQUES FILTRÉES (mécanisme inspiré d'OpenMW, contenu original) : data/dialogue/repliques.json.
## Chaque réplique : {id, sujet, filtres{…}, texte[…], hasard?, cumul?, effets[…]}. Pour un sujet et un contexte, la PREMIÈRE
## réplique dont tous les filtres passent gagne : l'ORDRE DU FICHIER EST LA PRIORITÉ (le particulier avant le général).
## Exception voulue : `cumul: "<groupe>"` — après la gagnante, toutes les répliques suivantes valides du même groupe sont dites
## à sa suite (deux quêtes qui avancent dans la même conversation).
## Filtres (tous facultatifs ; absent = indifférent) :
##   pnj (id ou liste), faction (celle du PNJ : « garde », « village »…), marchand (bool),
##   rang_min (rang du joueur dans `rang_faction`, sinon dans la faction du PNJ ; -1 = non membre, nœud « rangs » absent = -1),
##   disposition (palier « chaleureux » / « neutre » / « froid » / « refus », ou liste) ; disposition_min (score 0-100),
##   journal ({quete, min, max, fini, fait, echouee} ou liste de ces conditions ; l'INDEX de la quête = nombre d'étapes faites,
##     0 = pas commencée ; fini = index à son maximum ; fait = id d'une étape déjà franchie),
##   heure ([debut, fin] en heures, boucle à minuit si debut > fin ; « nuit » / « jour »), lieu (id ou liste),
##   vu (liste d'événements déjà survenus), maison (bool : maison achetée), choix (bool : choix moral fait).
## Effets : {"signaler": "evt"}, {"journal": {"quete", "index"}} (avance l'index, jamais en arrière), {"donner": {"objet", "n"}},
## {"disposition": "aide"} (mémoire du PNJ), {"echec": "quete"}.
## Le contexte est un simple Dictionary (voir `contexte`) : l'outil outils/lister_repliques.gd en fabrique sans scène.

const FICHIER := "res://data/dialogue/repliques.json"
const NUIT := [18.5, 6.5]   # = Vie.FEUX (soirée) : les mêmes bornes que les répliques contextuelles des civils
const JOUR := [6.5, 18.5]

static var _cache: Array = []
static var _factions: Array = []

static func charger(chemin := FICHIER) -> Array:
	if chemin == FICHIER and not _cache.is_empty():
		return _cache
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin)) if FileAccess.file_exists(chemin) else null
	var liste: Array = (d as Dictionary).get("repliques", []) if d is Dictionary else []
	if d == null:
		push_warning("Répliques : %s illisible" % chemin)
	if chemin == FICHIER:
		_cache = liste
		_factions = []
		for r: Dictionary in liste:
			var f: Dictionary = r.get("filtres", {})
			for cle in ["faction", "rang_faction"]:
				if f.has(cle) and not f[cle] in _factions:
					_factions.append(f[cle])
	return liste

# ------------------------------------------------------------------------------------------------------------ contexte

## Contexte d'une conversation avec le PNJ `n` (nœud à `donnees`, peut être null) ; `quetes` = scripts/quetes.gd (peut être null).
static func contexte(n: Node, quetes: Node) -> Dictionary:
	charger()
	var d: Dictionary = {}
	if n != null and is_instance_valid(n):
		var dn: Variant = n.get("donnees")
		if dn is Dictionary:
			d = dn
	var id := String(d.get("id", ""))
	var faction := String(d.get("faction", ""))
	if faction == "":
		faction = "garde" if (id == "garde" or String(d.get("type", "")) == "garde" or (n != null and n.is_in_group("gardes_village"))) else "village"
	var ctx := {"pnj": id, "faction": faction, "lieu": String(d.get("lieu", "")), "marchand": n != null and Marchand.pour_pnj(n) != "",
		"heure": 12.0, "jour": 1, "disposition": "neutre", "score": 50.0, "rangs": {}, "index": {}, "echecs": {}, "vus": {},
		"quetes": {}, "maison": false, "choix": false}
	if quetes != null:
		ctx["quetes"] = quetes.donnees
		ctx["index"] = quetes.etat
		ctx["vus"] = quetes.vus
		ctx["echecs"] = quetes.echecs
		ctx["maison"] = Stockage.maison_achetee
		ctx["choix"] = quetes.choix_fait() != ""
		var cyc: Variant = quetes.get_parent().get("cycle") if quetes.get_parent() != null else null
		if cyc != null:
			ctx["heure"] = float(cyc.heure)
			ctx["jour"] = int(cyc.jour)
	if n != null and is_instance_valid(n) and Disposition.courante != null and is_instance_valid(Disposition.courante) \
			and Disposition.courante.crime.cle_pnj(n) != "":
		ctx["disposition"] = Disposition.courante.palier(n)
		ctx["score"] = Disposition.courante.score(n)
	var arbre: SceneTree = n.get_tree() if n != null and n.is_inside_tree() else null
	var rangs: Node = arbre.get_first_node_in_group("rangs") if arbre != null else null   # livré par la branche des rangs de faction
	for f in _factions + [faction]:
		ctx["rangs"][f] = int(rangs.rang(String(f))) if rangs != null and rangs.has_method("rang") else -1
	return ctx

# ------------------------------------------------------------------------------------------------------------ évaluation

static func _liste(v: Variant) -> Array:
	return v if v is Array else [v]

static func taille(quetes: Dictionary, id: String) -> int:
	for q: Dictionary in quetes.get("quetes", []):
		if q["id"] == id:
			return (q["etapes"] as Array).size()
	return -1

static func position(quetes: Dictionary, id: String, etape: String) -> int:
	for q: Dictionary in quetes.get("quetes", []):
		if q["id"] == id:
			for i in (q["etapes"] as Array).size():
				if q["etapes"][i]["id"] == etape:
					return i
	return -1

static func _fenetre(v: Variant) -> Array:
	if v is String:
		return NUIT if v == "nuit" else JOUR
	return v as Array

static func _dans(h: float, f: Array) -> bool:
	var a := float(f[0])
	var b := float(f[1])
	return (h >= a and h < b) if a <= b else (h >= a or h < b)

static func _cond_journal(c: Dictionary, ctx: Dictionary) -> bool:
	var qid := String(c.get("quete", ""))
	var idx := int(ctx["index"].get(qid, 0))
	var n := taille(ctx["quetes"], qid)
	if c.has("min") and idx < int(c["min"]):
		return false
	if c.has("max") and idx > int(c["max"]):
		return false
	if c.has("fini") and (n >= 0 and idx >= n) != bool(c["fini"]):
		return false
	if c.has("fait") and not (position(ctx["quetes"], qid, String(c["fait"])) in range(0, idx)):
		return false
	if c.has("echouee") and bool(ctx.get("echecs", {}).has(qid)) != bool(c["echouee"]):
		return false
	return true

## "" si la réplique passe le contexte, sinon le nom du premier filtre qui la refuse (diagnostic).
static func refus(r: Dictionary, ctx: Dictionary) -> String:
	var f: Dictionary = r.get("filtres", {})
	if f.has("pnj") and not String(ctx.get("pnj", "")) in _liste(f["pnj"]):
		return "pnj"
	if f.has("faction") and String(f["faction"]) != String(ctx.get("faction", "")):
		return "faction"
	if f.has("marchand") and bool(f["marchand"]) != bool(ctx.get("marchand", false)):
		return "marchand"
	if f.has("rang_min"):
		var fac := String(f.get("rang_faction", f.get("faction", ctx.get("faction", ""))))
		if int(ctx.get("rangs", {}).get(fac, -1)) < int(f["rang_min"]):
			return "rang_min"
	if f.has("disposition") and not String(ctx.get("disposition", "neutre")) in _liste(f["disposition"]):
		return "disposition"
	if f.has("disposition_min") and float(ctx.get("score", 50.0)) < float(f["disposition_min"]):
		return "disposition_min"
	if f.has("journal"):
		for c: Dictionary in _liste(f["journal"]):
			if not _cond_journal(c, ctx):
				return "journal"
	if f.has("heure") and not _dans(float(ctx.get("heure", 12.0)), _fenetre(f["heure"])):
		return "heure"
	if f.has("lieu") and not String(ctx.get("lieu", "")) in _liste(f["lieu"]):
		return "lieu"
	if f.has("vu"):
		for e in f["vu"]:
			if not ctx.get("vus", {}).has(e):
				return "vu"
	if f.has("maison") and bool(f["maison"]) != bool(ctx.get("maison", false)):
		return "maison"
	if f.has("choix") and bool(f["choix"]) != bool(ctx.get("choix", false)):
		return "choix"
	return ""

static func valide(r: Dictionary, ctx: Dictionary) -> bool:
	return refus(r, ctx) == ""

## Répliques retenues pour `sujet` : la première valide, plus les suivantes de son groupe `cumul`. [] si aucune.
static func choisir(sujet: String, ctx: Dictionary, liste: Array = []) -> Array:
	if liste.is_empty():
		liste = charger()
	var res: Array = []
	var groupe := ""
	for r: Dictionary in liste:
		if String(r.get("sujet", "")) != sujet or not valide(r, ctx):
			continue
		if res.is_empty():
			res.append(r)
			groupe = String(r.get("cumul", ""))
			if groupe == "":
				break
		elif String(r.get("cumul", "")) == groupe:
			res.append(r)
	return res

## Lignes à dire pour les répliques retenues (`hasard` : une seule ligne tirée au sort parmi `texte`).
static func lignes(retenues: Array) -> Array:
	var res: Array = []
	for r: Dictionary in retenues:
		var t: Array = r.get("texte", [])
		if bool(r.get("hasard", false)) and not t.is_empty():
			res.append(String(t.pick_random()))
		else:
			res.append_array(t)
	return res

# ------------------------------------------------------------------------------------------------------------ analyse

## Raisons pour lesquelles une réplique ne peut JAMAIS passer (filtre contradictoire, quête ou étape inconnue, index hors bornes).
static func impossible(r: Dictionary, quetes: Dictionary) -> String:
	var f: Dictionary = r.get("filtres", {})
	if f.has("journal"):
		for c: Dictionary in _liste(f["journal"]):
			var qid := String(c.get("quete", ""))
			var n := taille(quetes, qid)
			if n < 0:
				return "quête inconnue « %s »" % qid
			if c.has("fait") and position(quetes, qid, String(c["fait"])) < 0:
				return "étape inconnue « %s:%s »" % [qid, c["fait"]]
			if int(c.get("min", 0)) > int(c.get("max", n)) or int(c.get("min", 0)) > n:
				return "journal %s : min > max (ou au-delà de %d étapes)" % [qid, n]
			if c.get("fini", false) == true and int(c.get("max", n)) < n:
				return "journal %s : « fini » mais max < %d" % [qid, n]
	if f.has("heure"):
		var h := _fenetre(f["heure"])
		if float(h[0]) == float(h[1]):
			return "fenêtre d'heure vide"
	if f.has("disposition_min") and float(f["disposition_min"]) > 100.0:
		return "disposition_min > 100"
	if f.has("rang_min") and int(f["rang_min"]) > 9:
		return "rang_min > 9"
	if not (r.get("texte", []) as Array).size() > 0 and (r.get("effets", []) as Array).is_empty():
		return "ni texte ni effet"
	return ""

## Les filtres de `e` sont-ils TOUS vrais dès que ceux de `r` le sont ? (alors `e`, placée avant `r`, masque `r` pour toujours)
static func implique(r: Dictionary, e: Dictionary, quetes: Dictionary) -> bool:
	var fr: Dictionary = r.get("filtres", {})
	var fe: Dictionary = e.get("filtres", {})
	for cle: String in fe:
		match cle:
			"pnj":
				if not fr.has("pnj") or not _sous_ensemble(_liste(fr["pnj"]), _liste(fe["pnj"])):
					return false
			"lieu":
				if not fr.has("lieu") or not _sous_ensemble(_liste(fr["lieu"]), _liste(fe["lieu"])):
					return false
			"disposition":
				if not fr.has("disposition") or not _sous_ensemble(_liste(fr["disposition"]), _liste(fe["disposition"])):
					return false
			"vu":
				if not fr.has("vu") or not _sous_ensemble(fr["vu"], fe["vu"]):
					return false
			"faction", "marchand", "maison", "choix", "rang_faction":
				if not fr.has(cle) or fr[cle] != fe[cle]:
					return false
			"rang_min":
				if not fr.has("rang_min") or int(fr["rang_min"]) < int(fe["rang_min"]) or fr.get("rang_faction", fr.get("faction", "")) != fe.get("rang_faction", fe.get("faction", "")):
					return false
			"disposition_min":
				if not fr.has("disposition_min") or float(fr["disposition_min"]) < float(fe["disposition_min"]):
					return false
			"heure":
				if not fr.has("heure") or not _heure_incluse(_fenetre(fr["heure"]), _fenetre(fe["heure"])):
					return false
			"journal":
				for ce: Dictionary in _liste(fe["journal"]):
					var ok := false
					for cr: Dictionary in _liste(fr.get("journal", [])):
						if cr.get("quete") == ce.get("quete") and _journal_inclus(cr, ce, quetes):
							ok = true
					if not ok:
						return false
			_:
				return false
	return true

static func _sous_ensemble(a: Array, b: Array) -> bool:
	for x in a:
		if not x in b:
			return false
	return true

static func _heure_incluse(a: Array, b: Array) -> bool:
	# a ⊆ b : on échantillonne la fenêtre `a` au quart d'heure (suffisant pour des fenêtres à l'heure ou à la demi-heure)
	for k in 96:
		var h := float(k) * 0.25
		if _dans(h, a) and not _dans(h, b):
			return false
	return true

static func _bornes(c: Dictionary, quetes: Dictionary) -> Array:
	var n := taille(quetes, String(c.get("quete", "")))
	var lo := int(c.get("min", 0))
	var hi := int(c.get("max", n))
	if c.get("fini", false) == true:
		lo = maxi(lo, n)
	elif c.get("fini", true) == false:
		hi = mini(hi, n - 1)
	if c.has("fait"):
		lo = maxi(lo, position(quetes, String(c["quete"]), String(c["fait"])) + 1)
	return [lo, hi]

static func _journal_inclus(cr: Dictionary, ce: Dictionary, quetes: Dictionary) -> bool:
	if ce.has("echouee") and cr.get("echouee") != ce["echouee"]:
		return false
	var a := _bornes(cr, quetes)
	var b := _bornes(ce, quetes)
	return a[0] >= b[0] and a[1] <= b[1]

## Diagnostic de tout le fichier : [{id, raison}] des répliques impossibles ou masquées par une réplique précédente du même sujet.
static func inatteignables(liste: Array, quetes: Dictionary) -> Array:
	var res: Array = []
	for i in liste.size():
		var r: Dictionary = liste[i]
		var imp := impossible(r, quetes)
		if imp != "":
			res.append({"id": String(r.get("id", i)), "raison": imp})
			continue
		for j in i:
			var e: Dictionary = liste[j]
			if String(e.get("sujet", "")) != String(r.get("sujet", "")):
				continue
			if e.get("cumul", "") != "" and e.get("cumul", "") == r.get("cumul", ""):
				continue   # même groupe : elles se disent ensemble, aucune ne masque l'autre
			if implique(r, e, quetes):
				res.append({"id": String(r.get("id", i)), "raison": "masquée par « %s » (placée avant, filtres moins stricts)" % String(e.get("id", j))})
				break
	return res
