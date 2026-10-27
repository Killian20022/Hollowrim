class_name Statuts
extends Node
## Statuts élémentaires d'une cible (ennemi, mannequin), centralisés : un nœud enfant « Statuts » créé à la première
## application (Statuts.de(cible)). Appliqués par le système de dégâts (Elements.apres_coup, appelé par
## DegatsCombat.appliquer) : tout coup qui porte un `info.statut` le pose ici. Règles et valeurs : docs/MAGIE.md.
##   brulure          dégâts de feu `puissance`/s (tics de 0,5 s, sans arrêt sur image) ; coupe la régénération du troll
##   brulure_obscure  brûlure de ténèbres (réaction flammes obscures) : rend 30 % des dégâts au lanceur
##   gel              ralentit de `puissance` (0..0,9) ; à ≥ 0,75 la cible est presque figée
##   choc             titube `puissance` s (subir_choc / _tituber) puis 1,5 s d'immunité (pas d'étourdissement en boucle)
##   corruption       la cible reçoit `puissance` de dégâts en plus (plafond +40 %) ; s'ajoute au drain
## Les durées se rafraîchissent (la plus longue l'emporte) ; puissances : la plus forte l'emporte.

signal change

const NOM := "Statuts"
const TIC := 0.5
const GEL_MAX := 0.9
const CORRUPTION_MAX := 0.4
const IMMUNITE_CHOC := 1.5
const PART_DRAIN_OBSCUR := 0.3

var cible: Node3D
## nom -> {"duree": s restantes, "duree_max": s, "puissance": float, "source": Node}
var actifs := {}
var _immunites := {}
var _tic := 0.0
## Recharge des réactions élémentaires (Elements) sur cette cible.
var recharge_reaction := 0.0
## Dégâts infligés par les statuts (tests, débogage).
var total_inflige := 0.0

static func de(c: Node, creer := true) -> Statuts:
	if c == null or not is_instance_valid(c):
		return null
	var s := c.get_node_or_null(NOM) as Statuts
	if s == null and creer and c is Node3D:
		s = Statuts.new()
		s.name = NOM
		s.cible = c
		c.add_child(s)
	return s

static func a(c: Node, nom: String) -> bool:
	var s := de(c, false)
	return s != null and s.actifs.has(nom)

static func puissance(c: Node, nom: String) -> float:
	var s := de(c, false)
	return float(s.actifs[nom]["puissance"]) if s != null and s.actifs.has(nom) else 0.0

## Facteur de vitesse (déplacement et animation de marche) : 1 sans gel, 0,1 presque figé.
static func facteur_vitesse(c: Node) -> float:
	return 1.0 - minf(puissance(c, "gel"), GEL_MAX)

## Multiplicateur des dégâts reçus (corruption).
static func multiplicateur_recu(c: Node) -> float:
	return 1.0 + minf(puissance(c, "corruption"), CORRUPTION_MAX)

## Liste lisible (HUD de la cible, tests) : [{nom, duree, puissance}].
func liste() -> Array:
	var r := []
	for n in actifs:
		r.append({"nom": n, "duree": actifs[n]["duree"], "puissance": actifs[n]["puissance"]})
	return r

## Pose (ou rafraîchit) un statut. Renvoie vrai s'il a pris.
func appliquer(nom: String, duree: float, p: float, source: Node = null) -> bool:
	if nom == "" or duree <= 0.0 or cible == null or not _vivante():
		return false
	if nom == "choc" and _immunites.get("choc", 0.0) > 0.0:
		return false
	var e: Dictionary = actifs.get(nom, {"duree": 0.0, "duree_max": 0.0, "puissance": 0.0, "source": source})
	e["duree"] = maxf(float(e["duree"]), duree)
	e["duree_max"] = maxf(float(e["duree_max"]), duree)
	e["puissance"] = maxf(float(e["puissance"]), p)
	if source != null:
		e["source"] = source
	if nom == "gel":
		e["puissance"] = minf(float(e["puissance"]), GEL_MAX)
	actifs[nom] = e
	if nom == "choc":
		_immunites["choc"] = IMMUNITE_CHOC + p
		_secouer(p)
	EffetsMagie.statut_cible(cible, nom, duree)
	change.emit()
	return true

func retirer(nom: String) -> void:
	if actifs.erase(nom):
		EffetsMagie.statut_cible(cible, nom, 0.0)
		change.emit()

## Prolonge un statut déjà posé (combo « embrasement » de l'épée).
func prolonger(nom: String, s: float) -> void:
	if actifs.has(nom):
		actifs[nom]["duree"] = float(actifs[nom]["duree"]) + s

func _vivante() -> bool:
	if cible.has_method("vivant"):
		return bool(cible.vivant())
	return not bool(cible.get("est_mort")) if cible.get("est_mort") != null else true

## Choc : titubement court. L'ennemi peut fournir subir_choc(duree) (garde ses états spéciaux : rage, charge…) ; sinon
## _tituber(recul, duree) de draugr.gd / EnnemiBase ; le mannequin n'a rien (il compte seulement).
func _secouer(duree: float) -> void:
	if cible.has_method("subir_choc"):
		cible.subir_choc(duree)
	elif cible.has_method("_tituber") and cible.get("est_mort") != true:
		cible._tituber(Vector3.ZERO, duree)

func _process(dt: float) -> void:
	if cible == null or not is_instance_valid(cible):
		return
	recharge_reaction = maxf(0.0, recharge_reaction - dt)
	for k in _immunites.keys():
		_immunites[k] = float(_immunites[k]) - dt
		if _immunites[k] <= 0.0:
			_immunites.erase(k)
	if actifs.is_empty():
		return
	if not _vivante():
		actifs.clear()
		return
	_tic += dt
	var tic := _tic >= TIC
	if tic:
		_tic -= TIC
	var fini := []
	for n in actifs:
		var e: Dictionary = actifs[n]
		e["duree"] = float(e["duree"]) - dt
		if tic and n in ["brulure", "brulure_obscure"]:
			var q := float(e["puissance"]) * TIC
			var fait := infliger(q, "feu" if n == "brulure" else "tenebres", e.get("source"))
			if n == "brulure_obscure" and e.get("source") != null and is_instance_valid(e["source"]) and e["source"].has_method("soigner"):
				e["source"].soigner(fait * PART_DRAIN_OBSCUR)
		if float(e["duree"]) <= 0.0:
			fini.append(n)
	for n in fini:
		retirer(n)

## Dégâts d'un statut : résistance du profil de la cible et corruption appliquées, SANS arrêt sur image ni réaction (pas de
## recevoir_coup à chaque tic) ; le dernier point de vie passe par recevoir_coup pour que la mort suive le chemin normal
## (ragdoll, butin, signal mort). Mannequin : ajouté à son total. Renvoie les dégâts faits.
func infliger(q: float, type: String, source: Node = null) -> float:
	var profil: ProfilCible = null
	var combat = cible.get("combat")
	if combat is CombatEnnemi:
		profil = (combat as CombatEnnemi).profil
	if profil != null:
		q *= float(profil.resistances.get(type, 1.0))
	q *= multiplicateur_recu(cible)
	total_inflige += q
	if cible.get("total") != null:   # mannequin d'entraînement
		cible.total = float(cible.total) + q
		return q
	if cible.get("vie") == null:
		return 0.0
	var vie := float(cible.vie)
	if vie - q > 0.5:
		cible.vie = vie - q
		return q
	cible.vie = 0.4
	var origine: Vector3 = (source as Node3D).global_position if source is Node3D else cible.global_position - cible.global_transform.basis.z
	DegatsCombat.appliquer(cible, 5.0, origine, false, {"type": type, "attaque": "statut", "stagger": 0.0, "continu": true, "reaction_de": "statut"})
	return q
