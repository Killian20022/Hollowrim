class_name Rangs
extends Node
## FACTIONS HUMAINES JOUABLES et leurs RANGS (data/factions_joueur.json ; ne pas confondre avec data/factions.json, les camps des
## ennemis). Mécanisme inspiré de Daggerfall Unity (Guild.cs, CalculateNewRank, MIT) ; contenu 100 % original.
##   - une RÉPUTATION par faction (en plus de la réputation légale de Skarnholt, Crime.reputation, que ce nœud ne touche pas) ;
##   - un RANG par faction : -1 = non membre, 0.. = rang ; on y entre en le demandant au chef (options du dialogue, ServicesPnj) ;
##   - la PROMOTION se calcule à la demande, en parlant au chef : on monte tant que le rang suivant est mérité (réputation >=
##     rep_min, meilleure compétence >= skill_haut, seconde >= skill_bas), des rangs peuvent être sautés, au plus une fois tous les
##     `delai_jours` jours de jeu (horloge Marchand.heures) ; le refus DIT CE QUI MANQUE ;
##   - une réputation négative exclut (rang -1, immédiatement) ; aider une faction fait baisser sa rivale (jamais sous 0 par ricochet).
## CONTRAT (utilisé pour filtrer les répliques de dialogue ; groupe « rangs ») : rang(faction) -> int, reputation(faction) -> float,
## ajouter_reputation(faction, delta). Sauvegarde : exporter / restaurer (clé « rangs » du monde ; absente = non membre partout).
## Avantages appliqués : remise des marchands (Marchand.faveur -> Rangs.remise), repos « bien reposé » dans tout lit libre
## (Sommeil -> Rangs.repos_bien), objets du rang donnés à la promotion.

const DONNEES := "res://data/factions_joueur.json"
const GROUPE := "rangs"
const REP_MIN := -50.0
const REP_MAX := 100.0
const REMISE_MAX := 0.3

## Nœud en service (un par monde) : lu par les fonctions statiques (Marchand, Sommeil).
static var courant: Rangs = null

var d := {}
var joueur: CharacterBody3D
var hud: Control
var _rep := {}       # faction -> réputation
var _rang := {}      # faction -> rang (absent = -1)
var _dernier := {}   # faction -> heure de jeu (Marchand.heures) de la dernière adhésion ou promotion

static func creer(monde_: Node) -> Rangs:
	var r := Rangs.new()
	r.name = "Rangs"
	r.joueur = monde_.joueur
	r.hud = monde_.hud
	monde_.add_child(r)
	return r

func _init() -> void:
	if FileAccess.file_exists(DONNEES):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
		if j is Dictionary:
			d = j

func _enter_tree() -> void:
	courant = self

func _exit_tree() -> void:
	if courant == self:
		courant = null

func _ready() -> void:
	add_to_group(GROUPE)

# ======================================================================================================== contrat

## Rang de la faction : -1 = non membre (ou faction inconnue), 0.. = rang atteint.
func rang(faction: String) -> int:
	return int(_rang.get(faction, -1)) if d.get("factions", {}).has(faction) else -1

## Réputation de la faction (0 au départ ; négative : exclusion).
func reputation(faction: String) -> float:
	return float(_rep.get(faction, 0.0))

## Ajoute `delta` à la réputation de la faction (bornée). Un gain retire une part à ses rivales (jamais sous 0 par ricochet) ;
## une réputation devenue négative exclut le membre sur-le-champ.
func ajouter_reputation(faction: String, delta: float) -> void:
	_ajouter(faction, delta, true)

# ======================================================================================================== données

func factions() -> Array:
	return (d.get("factions", {}) as Dictionary).keys()

func fiche(faction: String) -> Dictionary:
	return d.get("factions", {}).get(faction, {})

func nom(faction: String) -> String:
	return String(fiche(faction).get("nom", faction))

func nb_rangs(faction: String) -> int:
	return (fiche(faction).get("rangs", []) as Array).size()

func nom_rang(faction: String, r: int) -> String:
	var l: Array = fiche(faction).get("rangs", [])
	return String(l[r].get("nom", "")) if r >= 0 and r < l.size() else "Non membre"

func delai_heures() -> float:
	return float(d.get("delai_jours", 7.0)) * 24.0

## Faction dont `id_pnj` est le chef ("" si aucune).
func faction_du_chef(id_pnj: String) -> String:
	for f: String in factions():
		if String(fiche(f).get("chef", "")) == id_pnj:
			return f
	return ""

func _seuil(faction: String, cle: String, r: int) -> float:
	var l: Array = fiche(faction).get(cle, [])
	return float(l[r]) if r >= 0 and r < l.size() else 0.0

func rep_min(faction: String, r: int) -> float:
	return _seuil(faction, "rep_min", r)

func skill_haut(faction: String, r: int) -> int:
	return int(_seuil(faction, "skill_haut", r))

func skill_bas(faction: String, r: int) -> int:
	return int(_seuil(faction, "skill_bas", r))

# ======================================================================================================== rangs

## Compétences de la faction triées de la plus haute à la plus basse : [[nom, niveau]…].
func competences(faction: String) -> Array:
	var l: Array = []
	for c: String in fiche(faction).get("competences", []):
		l.append([c, joueur.progression.competence(c) if joueur != null else 0])
	l.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	return l

## Ce qui manque pour mériter le rang `r` : textes lisibles, vide = mérité (« 30 de réputation », « Une main à 35 »).
func manque(faction: String, r: int) -> Array[String]:
	var m: Array[String] = []
	var rep := reputation(faction)
	if rep < rep_min(faction, r):
		m.append("%d de réputation" % ceili(rep_min(faction, r)))
	var cs := competences(faction)
	if not cs.is_empty():
		if int(cs[0][1]) < skill_haut(faction, r):
			m.append("%s à %d" % [Parchemin.nom_competence(String(cs[0][0])), skill_haut(faction, r)])
		if cs.size() > 1 and int(cs[1][1]) < skill_bas(faction, r):
			m.append("%s à %d" % [Parchemin.nom_competence(String(cs[1][0])), skill_bas(faction, r)])
	return m

func merite(faction: String, r: int) -> bool:
	return manque(faction, r).is_empty()

## Rang que la réputation et les compétences permettent d'atteindre, en partant du rang actuel (on peut sauter des rangs) ;
## -1 si la réputation est négative ; le rang actuel si rien ne change.
func rang_merite(faction: String) -> int:
	if reputation(faction) < 0.0:
		return -1
	var r := rang(faction)
	while r + 1 < nb_rangs(faction) and merite(faction, r + 1):
		r += 1
	return r

## Jours de jeu restant avant la prochaine promotion (0 = possible).
func delai_restant(faction: String) -> float:
	var depuis := Marchand.heures - minf(float(_dernier.get(faction, 0.0)), Marchand.heures)
	var reste := delai_heures() - depuis
	return reste / 24.0 if reste > 0.01 else 0.0   # 0,01 h de tolérance : l'horloge est un flottant

func _heure() -> float:
	return Marchand.heures

# ======================================================================================================== actions (dialogue du chef)

func _voix(faction: String, cle: String) -> Array:
	return (fiche(faction).get("voix", {}) as Dictionary).get(cle, [])

func _dire(faction: String, cle: String) -> String:
	var l := _voix(faction, cle)
	return String(l.pick_random()) if not l.is_empty() else ""

## « a », « a et b », « a, b et c ».
func _liste(m: Array) -> String:
	if m.size() < 2:
		return String(m[0]) if m.size() == 1 else ""
	return "%s et %s" % [", ".join(m.slice(0, m.size() - 1)), m[m.size() - 1]]

## Demande d'adhésion : renvoie les répliques du chef. Rang 0 si la réputation n'est pas négative et que le rang 0 est mérité.
func adherer(faction: String) -> Array:
	if not d.get("factions", {}).has(faction):
		return []
	if rang(faction) >= 0:
		return [_dire(faction, "deja")]
	var m := manque(faction, 0)
	if reputation(faction) < 0.0:
		return [_dire(faction, "adhesion_refus"), "Ta réputation chez nous est ruinée : il te faut remonter au moins à 0 (tu en es à %d)." % roundi(reputation(faction))]
	if not m.is_empty():
		return [_dire(faction, "adhesion_refus"), "Il te faut %s." % _liste(m)]
	_fixer_rang(faction, 0)
	_avis("%s : %s" % [nom(faction), nom_rang(faction, 0)])
	return [_dire(faction, "adhesion")]

## Demande de promotion : calcule le nouveau rang, applique (objets du rang) ou explique ce qui manque ou le délai restant.
func promouvoir(faction: String) -> Array:
	if not d.get("factions", {}).has(faction):
		return []
	var r0 := rang(faction)
	if r0 < 0:
		return adherer(faction)
	if reputation(faction) < 0.0:
		_exclure(faction)
		return [_dire(faction, "exclu")]
	if r0 >= nb_rangs(faction) - 1:
		return [_dire(faction, "sommet")]
	var r1 := rang_merite(faction)
	if r1 <= r0:
		var m := manque(faction, r0 + 1)
		var l := [_dire(faction, "refus"), "Pour devenir %s, il te faut %s." % [nom_rang(faction, r0 + 1), _liste(m)]]
		var dj := delai_restant(faction)
		if dj > 0.0:
			l.append("Et le délai : reviens dans %d jour(s)." % ceili(dj))
		return l
	var dj := delai_restant(faction)
	if dj > 0.0:
		return [String(_dire(faction, "delai")) % [nom_rang(faction, r1), ceili(dj)]]
	for r in range(r0 + 1, r1 + 1):
		_donner_objets(faction, r)
	_fixer_rang(faction, r1)
	_avis("%s : %s" % [nom(faction), nom_rang(faction, r1)])
	var lignes: Array = []
	for t: String in _voix(faction, "promotion"):
		lignes.append(t % nom_rang(faction, r1) if t.contains("%s") else t)
	return lignes

func _fixer_rang(faction: String, r: int) -> void:
	_rang[faction] = r
	_dernier[faction] = _heure()
	if r >= 0 and is_inside_tree():
		Sons.interface(self, ["ui_quete_fin"], -9.0)

func _exclure(faction: String) -> void:
	if rang(faction) < 0:
		return
	_rang[faction] = -1
	_dernier[faction] = _heure()
	_avis("Exclu : %s" % nom(faction))

func _donner_objets(faction: String, r: int) -> void:
	var o: Dictionary = (fiche(faction).get("rangs", []) as Array)[r].get("objets", {})
	if joueur == null:
		return
	for id: String in o:
		joueur.inventaire.ajouter(id, int(o[id]))
		_avis("+ %s" % joueur.inventaire.nom(id))

func _ajouter(faction: String, delta: float, rivalites: bool) -> void:
	if not d.get("factions", {}).has(faction) or delta == 0.0:
		return
	_rep[faction] = clampf(reputation(faction) + delta, REP_MIN, REP_MAX)
	if reputation(faction) < 0.0 and rang(faction) >= 0:
		_exclure(faction)
	if rivalites and delta > 0.0:
		var riv: Dictionary = fiche(faction).get("rivalites", {})
		for autre: String in riv:
			if not d.get("factions", {}).has(autre):
				continue
			var perte := delta * float(riv[autre])
			_rep[autre] = maxf(minf(0.0, reputation(autre)), reputation(autre) - perte)   # jamais sous 0 par ricochet

## Récompense de quête (data/quetes.json, recompense.reputation : {faction: points}) : avis du HUD, rivalités comprises.
func recompenser(rep: Dictionary) -> void:
	for f: String in rep:
		if not d.get("factions", {}).has(f):
			continue
		ajouter_reputation(f, float(rep[f]))
		_avis("Réputation %s : %+d" % [nom(f), int(rep[f])])

func _avis(t: String) -> void:
	if hud != null and hud.has_method("avis"):
		hud.avis(t)

# ======================================================================================================== crimes (data : « crime »)

func _crime() -> Dictionary:
	return d.get("crime", {})

## Faction qui tient la juridiction (Skarnholt -> Garde du jarl) ; "" si aucune.
func faction_juridiction(juridiction: String) -> String:
	return String(_crime().get("juridictions", {}).get(juridiction, ""))

## Points de réputation perdus par la faction de la juridiction pour un crime VU de ce type (0 si inconnu).
func perte_crime(type: String) -> float:
	return float(_crime().get("vu", {}).get(type, 0.0))

## Faction d'un PNJ du village : clé de Crime.cle_pnj (« garde:<id> » = garde du village, « pnj:<id> » = villageois) ; "" si aucune.
func faction_du_membre(cle: String) -> String:
	if cle.begins_with("garde:"):
		return faction_juridiction("skarnholt")
	return String(_crime().get("membres", {}).get(cle.trim_prefix("pnj:"), ""))

## Points perdus par la faction dont un membre vient d'être tué.
func perte_membre_tue(faction: String) -> float:
	return float(_crime().get("membre_tue", {}).get(faction, 0.0))

## Retire des points de réputation à une faction (avis du HUD, exclusion si elle devient négative). Renvoie les points RÉELLEMENT perdus
## (la réputation est bornée).
func retirer_reputation(faction: String, points: float) -> float:
	if not d.get("factions", {}).has(faction) or points <= 0.0:
		return 0.0
	var avant := reputation(faction)
	_ajouter(faction, -points, false)
	var perdu := avant - reputation(faction)
	if perdu >= 0.5:
		_avis("Réputation %s : %d" % [nom(faction), -roundi(perdu)])
	return perdu

## Rend des points (dette réglée) : ne touche pas aux rivales, ne réintègre personne.
func rendre_reputation(faction: String, points: float) -> void:
	if not d.get("factions", {}).has(faction) or points <= 0.0:
		return
	var avant := reputation(faction)
	_ajouter(faction, points, false)
	if reputation(faction) - avant >= 0.5:
		_avis("Réputation %s : %+d" % [nom(faction), roundi(reputation(faction) - avant)])

# ======================================================================================================== avantages

## Avantages en vigueur d'une faction : fusion des rangs 0..rang (le plus haut remplace) ; vide si non membre.
func avantages(faction: String) -> Dictionary:
	var res := {}
	var r := rang(faction)
	var l: Array = fiche(faction).get("rangs", [])
	for i in range(0, mini(r + 1, l.size())):
		var a: Dictionary = l[i].get("avantages", {})
		for k: String in a:
			if a[k] is Dictionary:
				var sous: Dictionary = res.get(k, {})
				sous.merge(a[k], true)
				res[k] = sous
			else:
				res[k] = a[k]
	return res

## Part du prix en faveur du joueur chez le marchand `id_marchand` (somme des factions, bornée).
func remise_de(id_marchand: String) -> float:
	var t := 0.0
	for f: String in factions():
		t += float((avantages(f).get("remise", {}) as Dictionary).get(id_marchand, 0.0))
	return minf(t, REMISE_MAX)

func repos_bien_actif() -> bool:
	for f: String in factions():
		if bool(avantages(f).get("repos_bien", false)):
			return true
	return false

static func remise(id_marchand: String) -> float:
	return courant.remise_de(id_marchand) if courant != null and is_instance_valid(courant) else 0.0

static func repos_bien() -> bool:
	return courant != null and is_instance_valid(courant) and courant.repos_bien_actif()

# ======================================================================================================== options de dialogue

## Choix proposés par le chef d'une faction (ServicesPnj.options) : adhérer ou demander une promotion. Les actions renvoient les
## répliques à dire (Dialogue les affiche).
func options(id_pnj: String) -> Array:
	var f := faction_du_chef(id_pnj)
	if f == "":
		return []
	if rang(f) < 0:
		return [{"texte": "Rejoindre : %s" % nom(f), "action": func() -> Array: return adherer(f)}]
	if rang(f) >= nb_rangs(f) - 1:
		return []
	return [{"texte": "Demander une promotion", "action": func() -> Array: return promouvoir(f)}]

# ======================================================================================================== sauvegarde

func exporter() -> Dictionary:
	return {"v": 1, "rep": _rep.duplicate(), "rang": _rang.duplicate(), "dernier": _dernier.duplicate()}

## Ancienne partie (sans clé « rangs ») : non membre partout, réputation 0.
func restaurer(e: Dictionary) -> void:
	_rep = {}
	_rang = {}
	_dernier = {}
	var f_ok: Dictionary = d.get("factions", {})
	for k: Variant in (e.get("rep", {}) as Dictionary if e.get("rep") is Dictionary else {}):
		if f_ok.has(String(k)):
			_rep[String(k)] = clampf(float(e["rep"][k]), REP_MIN, REP_MAX)
	for k: Variant in (e.get("rang", {}) as Dictionary if e.get("rang") is Dictionary else {}):
		if f_ok.has(String(k)):
			_rang[String(k)] = clampi(int(e["rang"][k]), -1, nb_rangs(String(k)) - 1)
	for k: Variant in (e.get("dernier", {}) as Dictionary if e.get("dernier") is Dictionary else {}):
		if f_ok.has(String(k)):
			_dernier[String(k)] = float(e["dernier"][k])
