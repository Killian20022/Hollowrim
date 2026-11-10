class_name ConversationsVie
extends RefCounted
## Causeries entre PNJ (lot vie/metiers) : deux civils proches et libres s'arrêtent, se tournent l'un vers l'autre et échangent 2 à 4
## répliques courtes (data/vie/conversations.json), dites en sous-titre (dialogue.dire_au_passage) quand le joueur est à portée d'oreille.
## Choix de l'échange : rôles (id, type, métier, « habitant », « * »), filtres de RepliquesFiltrees (heure, journal des quêtes,
## disposition du joueur, vu…) et filtres propres : meteo (« tempete » / « calme », cycle.tempete), danger (récent), moment (« poste » /
## « soir »). Le plus précis l'emporte ; les 10 derniers échanges dits sont évités.
## Coût : piloté par l'horloge de Vie (2 Hz), une recherche toutes les PERIODE s, seulement près du joueur (R_JOUEUR), une causerie à
## la fois ; aucune requête physique par image (une seule vérification de trajet au départ d'une causerie où l'un rejoint l'autre).

signal ligne_dite(nom: String, texte: String, id_echange: String)

const FICHIER := "res://data/vie/conversations.json"
const PERIODE := 3.0          # s entre deux recherches de causeurs
const R_JOUEUR := 28.0        # m : on ne cherche des causeurs qu'autour du joueur
const R_FIN := 40.0           # m : plus loin, la causerie s'interrompt (et le village repasse en détail allégé)
const R_PAIRE := 6.0          # m : distance maximale entre les deux
const R_FACE := 2.4           # m : en deçà ils se parlent sur place ; au-delà, celui qui peut bouger rejoint l'autre
const DIST_CAUSER := 1.3      # m : distance de causerie après le déplacement
const R_ENTENDRE := 14.0      # m : sous-titre si le joueur est à portée d'oreille
const ATTENTE_MAX := 14.0     # s : le marcheur n'arrive pas, on abandonne
const REPOS_PNJ := Vector2(90.0, 200.0)   # s : pas de nouvelle causerie pour lui avant
const REPOS_GLOBAL := 12.0    # s entre deux causeries
const MEMOIRE := 10
const DANGER_RECENT := 180.0  # s : un danger de moins de 3 min colore les causeries (= Vie.MEMOIRE_DANGER)

var vie: Vie
var echanges: Array = []
var actif: Dictionary = {}
var dites := 0                # répliques dites depuis le début (tests)
var causeries := 0            # causeries menées à leur terme (tests)
var force_meteo := ""         # tests : « tempete » / « calme »
var _prochain := 4.0
var _h_prec := 0.0
var _repos := {}
var _recents: Array = []

func _init(v: Vie) -> void:
	vie = v
	echanges = charger()

static func charger() -> Array:
	if not FileAccess.file_exists(FICHIER):
		return []
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if not (j is Dictionary):
		push_warning("Conversations : JSON invalide : " + FICHIER)
		return []
	return (j as Dictionary).get("echanges", [])

func actives() -> bool:
	return not actif.is_empty()

## Appelé à chaque tick de Vie (2 Hz) avec l'horloge du village (s).
func tick(h: float, menaces: Array) -> void:
	var dt := clampf(h - _h_prec, 0.0, 1.0)
	_h_prec = h
	if not actif.is_empty():
		_suivre(h, dt, menaces)
		return
	if h < _prochain or not Metiers.actif():
		return
	_prochain = h + PERIODE
	if h - vie.dernier_danger < 20.0 or not menaces.is_empty() and _menace_pres(menaces):
		return
	_chercher(h)

func _menace_pres(menaces: Array) -> bool:
	var pj := vie.joueur.global_position
	for e: Node3D in menaces:
		if e.global_position.distance_to(pj) < 30.0:
			return true
	return false

# ------------------------------------------------------------------------------------------------------------ recherche
func _libre(c: Dictionary, h: float) -> bool:
	var n: Node3D = c["n"]
	if not is_instance_valid(n) or c["fuit"] or not String(c["mode"]) in ["poste", "soir"]:
		return false
	if h < float(_repos.get(String(c["id"]), -1.0)) or not n.has_method("libre_pour_causer") or not n.libre_pour_causer():
		return false
	var pj := vie.joueur.global_position
	return Vector2(n.global_position.x - pj.x, n.global_position.z - pj.z).length() < R_JOUEUR and absf(n.global_position.y - pj.y) < 6.0

## Il peut quitter sa place pour rejoindre l'autre : ni assis, ni à un ouvrage fixe (enclume, étal, puits).
static func mobile(n: Node3D) -> bool:
	return not n.assis() and is_nan(n._cap_fixe())

func _chercher(h: float) -> bool:
	var libres: Array = []
	for c: Dictionary in vie.civils:
		if _libre(c, h):
			libres.append(c)
	var paires: Array = []
	for i in libres.size():
		for j in range(i + 1, libres.size()):
			var a: Node3D = libres[i]["n"]
			var b: Node3D = libres[j]["n"]
			var d := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
			if d < R_PAIRE and absf(a.global_position.y - b.global_position.y) < 1.0:
				paires.append([d, libres[i], libres[j]])
	paires.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	for p: Array in paires:
		if _essayer(p[1], p[2], float(p[0]), h):
			return true
	return false

## Lance la causerie entre les civils ca et cb (dictionnaires de Vie.civils) si un échange leur convient. Vrai si elle commence.
func _essayer(ca: Dictionary, cb: Dictionary, d: float, h: float) -> bool:
	var a: Node3D = ca["n"]
	var b: Node3D = cb["n"]
	var marcheur: Node3D = null
	var spot := Vector3.INF
	if d > R_FACE:
		# celui qui est en pause de promenade d'abord, sinon le premier qui peut bouger
		var cands: Array = [b, a] if b.etat == 2 else [a, b]
		for m: Node3D in cands:
			if mobile(m):
				marcheur = m
				break
		if marcheur == null:
			return false
		var autre: Node3D = b if marcheur == a else a
		var v := marcheur.global_position - autre.global_position
		v.y = 0.0
		spot = autre.global_position + v.normalized() * DIST_CAUSER
		spot.y = float(vie.monde.hauteur(spot.x, spot.z)) if vie.monde.has_method("hauteur") else autre.global_position.y
		if not marcheur.chemin_libre(marcheur.global_position, spot):
			return false
	var choix := choisir(a, b, ca, cb)
	if choix.is_empty():
		return false
	var pa: Node3D = choix["a"]
	var pb: Node3D = choix["b"]
	for n: Node3D in [pa, pb]:
		var autre: Node3D = pb if n == pa else pa
		n.commencer_causerie(autre, spot if n == marcheur else Vector3.INF)
	actif = {"a": pa, "b": pb, "e": choix["e"], "i": 0, "t": 0.6, "debut": h}
	_recents.append(String(choix["e"].get("id", "")))
	if _recents.size() > MEMOIRE:
		_recents.pop_front()
	return true

# ------------------------------------------------------------------------------------------------------------ choix de l'échange
static func _cle(n: Node3D) -> Array:
	var d: Dictionary = n.donnees
	var id := String(d.get("id", ""))
	var cles := ["*", id, String(d.get("type", ""))]
	if id.begins_with("hab_"):
		cles.append("habitant")
	var m: Dictionary = n.get("metier") if n.get("metier") is Dictionary else {}
	if m.has("nom"):
		cles.append(String(m["nom"]))
	return cles

static func _accepte(sel: Variant, n: Node3D) -> int:
	var cles := _cle(n)
	for s in (sel if sel is Array else [sel]):
		if String(s) in cles:
			return 0 if String(s) == "*" else 1
	return -1

func meteo() -> String:
	if force_meteo != "":
		return force_meteo
	var c: Node = vie.monde.get("cycle")
	return "tempete" if c != null and float(c.get("tempete")) > 0.5 else "calme"

## Refus d'un échange pour (a parle en premier, b répond) ; "" = valide. Contexte de RepliquesFiltrees pris sur `a` (disposition du joueur envers lui).
func refus(e: Dictionary, a: Node3D, b: Node3D, ca: Dictionary) -> String:
	if _accepte(e.get("a", "*"), a) < 0 or _accepte(e.get("b", "*"), b) < 0:
		return "roles"
	if e.has("meteo") and String(e["meteo"]) != meteo():
		return "meteo"
	if e.has("danger") and bool(e["danger"]) != (vie.horloge() - vie.dernier_danger < DANGER_RECENT):
		return "danger"
	if e.has("moment") and String(e["moment"]) != String(ca.get("mode", "")):
		return "moment"
	if e.has("filtres"):
		var ctx := RepliquesFiltrees.contexte(a, vie.monde.get("quetes"))
		var r := RepliquesFiltrees.refus(e, ctx)
		if r != "":
			return r
	return ""

const TYPES := ["paysan", "paysanne", "chasseur", "chasseresse"]

## Précision d'un échange : rôle nommé (id, métier) 3, type d'habitant 2, « habitant » 1, « * » 0 ; +1 par filtre.
static func precision(e: Dictionary) -> int:
	var k := 0
	for r in ["a", "b"]:
		var meilleur := 0
		for s in (e.get(r, "*") if e.get(r, "*") is Array else [e.get(r, "*")]):
			var v := 0 if s == "*" else (1 if s == "habitant" else (2 if s in TYPES else 3))
			meilleur = v if meilleur == 0 else mini(meilleur, v)
		k += meilleur
	k += (e.get("filtres", {}) as Dictionary).size()
	for f in ["meteo", "danger", "moment"]:
		if e.has(f):
			k += 1
	return k

## {"e", "a", "b"} : l'échange retenu et qui parle en premier ; {} si aucun ne convient.
func choisir(a: Node3D, b: Node3D, ca: Dictionary = {}, cb: Dictionary = {}) -> Dictionary:
	var valides: Array = []
	for e: Dictionary in echanges:
		if refus(e, a, b, ca) == "":
			valides.append({"e": e, "a": a, "b": b})
		elif refus(e, b, a, cb) == "":
			valides.append({"e": e, "a": b, "b": a})
	if valides.is_empty():
		return {}
	var frais := valides.filter(func(v: Dictionary) -> bool: return not String(v["e"].get("id", "")) in _recents)
	if not frais.is_empty():
		valides = frais
	var best := -1
	for v: Dictionary in valides:
		best = maxi(best, precision(v["e"]))
	var tops := valides.filter(func(v: Dictionary) -> bool: return precision(v["e"]) == best)
	return tops.pick_random()

# ------------------------------------------------------------------------------------------------------------ déroulé
func _suivre(h: float, dt: float, _menaces: Array) -> void:
	var a: Node3D = actif["a"]
	var b: Node3D = actif["b"]
	if not _tient(a, b):
		finir()
		return
	if not (a.en_place_pour_causer() and b.en_place_pour_causer()):
		if h - float(actif["debut"]) > ATTENTE_MAX:
			finir()
		return
	actif["t"] = float(actif["t"]) - dt
	if float(actif["t"]) > 0.0:
		return
	var lignes: Array = actif["e"].get("lignes", [])
	var i := int(actif["i"])
	if i >= lignes.size():
		causeries += 1
		finir()
		return
	var l: Array = lignes[i]
	var qui: Node3D = a if String(l[0]) == "a" else b
	var autre: Node3D = b if qui == a else a
	var texte := String(l[1])
	qui.parler_causerie(true)
	autre.parler_causerie(false)
	dites += 1
	ligne_dite.emit(qui.nom_affiche(), texte, String(actif["e"].get("id", "")))
	var pj := vie.joueur.global_position
	var dlg: Node = vie.monde.get("dialogue")
	if dlg != null and pj.distance_to(qui.global_position) < R_ENTENDRE and not bool(vie.joueur.get("en_dialogue")):
		dlg.dire_au_passage(qui.nom_affiche(), texte)
	actif["i"] = i + 1
	actif["t"] = clampf(0.9 + texte.length() * 0.045, 2.2, 4.6)

func _tient(a: Node3D, b: Node3D) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b) or a.causerie != b or b.causerie != a:
		return false
	if a.occupe() or b.occupe() or a.est_endormi() or b.est_endormi():
		return false
	for n: Node3D in [a, b]:
		var c := vie.civil(String(n.donnees.get("id", "")))
		if c.is_empty() or c["fuit"]:
			return false
	return a.global_position.distance_to(vie.joueur.global_position) < R_FIN

## Termine la causerie en cours (les deux reprennent leur vie ; repos avant la suivante).
func finir() -> void:
	if actif.is_empty():
		return
	var h := vie.horloge()
	for n: Variant in [actif["a"], actif["b"]]:
		if is_instance_valid(n):
			(n as Node3D).finir_causerie()
			_repos[String((n as Node3D).donnees.get("id", ""))] = h + randf_range(REPOS_PNJ.x, REPOS_PNJ.y)
	actif = {}
	_prochain = h + REPOS_GLOBAL

## Tests : force une causerie entre deux civils (ids) maintenant ; vrai si elle commence.
func forcer(id_a: String, id_b: String) -> bool:
	var ca := vie.civil(id_a)
	var cb := vie.civil(id_b)
	if ca.is_empty() or cb.is_empty() or not actif.is_empty():
		return false
	var a: Node3D = ca["n"]
	var b: Node3D = cb["n"]
	_repos.erase(id_a)
	_repos.erase(id_b)
	var d := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
	return _essayer(ca, cb, d, vie.horloge())
