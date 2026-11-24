class_name PvpCoop
extends RefCounted
## Coop, PvP : les joueurs peuvent se blesser, se saisir et se projeter avec leurs sorts, flèches et objets télékinésés.
## Réglage « pvp » (activé par défaut) : choisi par l'HÔTE (menu Multijoueur > Héberger, sauvegardé dans user://multijoueur.cfg),
## diffusé à tous ; `--sans-pvp` (argument utilisateur) le désactive pour cette session. Désactivé : tout est comme avant
## (aucun tir allié, les avatars sont ignorés par les sorts et les flèches).
##
## PRINCIPES (cohérents avec les lots 2c / 4c / 4d et combat_coop.gd)
##  - AUTORITÉ HÔTE : l'attaquant (hôte ou invité) DEMANDE ; l'hôte valide (pvp actif, pairs connus, cible debout, portée, plafond de
##    dégâts, cadence) puis applique. Hôte -> victime : CombatCoop.EV_SUBI (le coup est résolu chez la VICTIME : armure, garde,
##    esquive, mise « à terre » par joueur.gd / ATerre comme d'habitude) ; l'invité qui attaque passe par `pvp_coup`.
##  - DÉGÂTS ÉQUILIBRÉS : × FACTEUR_DEGATS, un coup ne dépasse jamais PART_MAX de la vie max de la victime (pas de one-shot).
##  - ÉTATS (saisie / lévitation / lancer) : `pvp_op` (op = tenir / projeter / lacher) routé par l'hôte vers le PROPRIÉTAIRE de
##    l'avatar visé, où PvpVictime lui retire le contrôle pendant la saisie (position autoritaire = celle de l'attaquant, via l'hôte),
##    puis applique l'impulsion au relâchement (vol balistique, dégâts d'impact limités, jamais mortels : 1 PV minimum).
## Tout est statique et paresseux ; hors ligne, chaque appel est un no-op.

const EV_REGLAGE := "pvp_reglage"
const EV_COUP := "pvp_coup"
const EV_OP := "pvp_op"
const FICHIER_PREFS := "user://multijoueur.cfg"

const FACTEUR_DEGATS := 0.6
const PART_MAX := 0.4              # d'un coup : au plus 40 % de la vie max de la victime
const DEGATS_BRUTS_MAX := 120.0    # plafond de ce qu'un invité peut déclarer (avant facteur)
const PORTEE_MAX := 160.0
const DELAI_MS := 30
const VITESSE_OP_MAX := 32.0
const ECART_TENUE_MAX := 25.0      # m : point de saisie annoncé / attaquant
const OPS := ["tenir", "projeter", "lacher"]
const PERIODE_AGREGAT := 0.12      # s : dégâts continus (rayons, souffles) regroupés avant envoi

static var pvp := true
static var _pret := false
static var _derniers := {}         # hôte : clé (att*100000+cible) -> ms du dernier coup validé
static var _agreg := {}            # pair visé -> {deg, orig, opt, t}
## Journal des évènements reçus / validés (tests).
static var journal: Array = []
static var refuses := 0

# ---------------------------------------------------------------------------------------------------- base
static func reseau() -> Node:
	return ReseauLieux.reseau()

static func en_ligne() -> bool:
	return ReseauProjectiles.en_ligne()

static func est_hote() -> bool:
	return ReseauProjectiles.est_hote()

static func mon_id() -> int:
	return ReseauProjectiles.mon_id()

## Argument utilisateur `--sans-pvp`.
static func arg_sans_pvp() -> bool:
	return OS.get_cmdline_user_args().has("--sans-pvp")

static func charger_reglage(chemin := FICHIER_PREFS) -> bool:
	var c := ConfigFile.new()
	if c.load(chemin) == OK:
		return bool(c.get_value("multi", "pvp", true))
	return true

static func sauver_reglage(on: bool, chemin := FICHIER_PREFS) -> void:
	var c := ConfigFile.new()
	c.load(chemin)
	c.set_value("multi", "pvp", on)
	c.save(chemin)

## Réglage choisi par l'hôte (menu) : sauvegardé, appliqué et diffusé.
static func definir(on: bool, sauver := true) -> void:
	installer()
	pvp = on
	if sauver:
		sauver_reglage(on)
	if en_ligne() and est_hote():
		reseau().envoyer_evenement(EV_REGLAGE, 0, {"on": on})

static func installer() -> void:
	if _pret:
		return
	var r := reseau()
	if r == null:
		return
	_pret = true
	CombatCoop._installer()   # abonnements des coups subis (EV_SUBI) : la victime résout le coup chez elle
	pvp = false if arg_sans_pvp() else charger_reglage()
	r.abonner(EV_REGLAGE, PvpCoop._sur_reglage)
	r.abonner(EV_COUP, PvpCoop._sur_coup)
	r.abonner(EV_OP, PvpCoop._sur_op)
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre != null:
		var n := PvpHorloge.new()
		n.name = "PvpHorloge"
		arbre.root.add_child.call_deferred(n)

static func reinitialiser() -> void:
	_derniers.clear()
	_agreg.clear()
	journal.clear()
	refuses = 0

## Vrai si le PvP s'applique (en ligne et réglage actif).
static func actif() -> bool:
	if not en_ligne():
		return false
	installer()
	return pvp and not arg_sans_pvp()

# ---------------------------------------------------------------------------------------------------- cibles
static func pair_de(n: Object) -> int:
	if n == null or not is_instance_valid(n) or not (n is Node):
		return 0
	var nom := String((n as Node).name)
	if nom.begins_with("Joueur_"):
		return nom.substr(7).to_int()
	return 0

static func _debout(n: Node) -> bool:
	return n != null and is_instance_valid(n) and n.is_inside_tree() and n.get("mort") != true and n.get("a_terre") != true

## `n` est l'avatar d'un autre joueur que ce PvP peut viser.
static func pvp_cible(n: Object) -> bool:
	return actif() and ReseauProjectiles.est_avatar(n) and pair_de(n) > 0 and _debout(n as Node)

static func avatars_cibles() -> Array:
	var res := []
	if not actif():
		return res
	for a in ReseauProjectiles.avatars():
		if pair_de(a) > 0 and _debout(a):
			res.append(a)
	return res

## Elements.cibles_dans + avatars des autres joueurs quand le PvP est actif.
static func cibles(p: Vector3, rayon: float) -> Array:
	var res := Elements.cibles_dans(p, rayon)
	var ajout := false
	for a in avatars_cibles():
		if not res.has(a) and Elements._centre(a).distance_to(p) <= rayon + 0.4:
			res.append(a)
			ajout = true
	if ajout:
		res.sort_custom(func(a: Node, b: Node) -> bool: return Elements._centre(a).distance_squared_to(p) < Elements._centre(b).distance_squared_to(p))
	return res

## RID des avatars à exclure des rayons d'un projectile ENNEMI ou d'une copie distante ; vide pour un tir du joueur local en PvP.
static func exclus_pour_tir_local() -> Array[RID]:
	return [] if actif() else ReseauProjectiles.exclus_avatars()

# ---------------------------------------------------------------------------------------------------- coups
## Coup du joueur local sur l'avatar `cible`. `continu` : dégâts de rayon / souffle (regroupés avant envoi). Renvoie "touche" ou "".
static func coup(cible: Node, degats: float, origine: Vector3, options := {}, continu := false) -> String:
	if not pvp_cible(cible) or degats <= 0.0:
		return ""
	var pair := pair_de(cible)
	var opt := CombatCoop._propre(options)
	if continu:
		var a: Dictionary = _agreg.get(pair, {"deg": 0.0, "orig": origine, "opt": opt, "t": 0.0})
		a["deg"] = float(a["deg"]) + degats
		a["orig"] = origine
		a["opt"] = opt
		_agreg[pair] = a
		return "touche"
	_envoyer_coup(pair, degats, origine, opt)
	return "touche"

static func _envoyer_coup(pair: int, degats: float, origine: Vector3, opt: Dictionary) -> void:
	if est_hote():
		_valider_coup(mon_id(), pair, degats, origine, opt)
	else:
		reseau().envoyer_evenement(EV_COUP, pair, {"deg": degats, "orig": origine, "opt": opt}, 1)

## Appelé à chaque image par PvpHorloge : envoie les dégâts continus accumulés.
static func _vider_agregats(dt: float) -> void:
	for pair: int in _agreg.keys():
		var a: Dictionary = _agreg[pair]
		a["t"] = float(a["t"]) + dt
		if float(a["t"]) >= PERIODE_AGREGAT:
			_agreg.erase(pair)
			if actif():
				_envoyer_coup(pair, float(a["deg"]), a["orig"], a["opt"])

## Coup d'un SORT (LanceurSorts.frapper).
static func frapper_sort(lanceur: Node3D, cible: Node, quantite: float, s: DonneesSort, point: Vector3, direction: Vector3, continu: bool) -> String:
	var opt := {"type": s.type_degats, "recul": 1.5 if continu else 2.5}
	match s.statut:
		"gel":
			opt["ralenti"] = Vector2(s.duree_statut, 1.0 - clampf(s.puissance_statut, 0.0, 0.8))
		"choc":
			opt["secousse"] = 0.6
	var origine: Vector3 = lanceur.global_position if lanceur != null else point - direction
	return coup(cible, quantite, origine, opt, continu)

## Flèche du joueur local qui touche un avatar.
static func coup_fleche(cible: Node, degats: float, point: Vector3, dir: Vector3) -> String:
	return coup(cible, degats, point - dir.normalized() * 2.0, {"type": "perforant", "recul": 3.0})

## Objet / arme télékinésés qui percutent un avatar.
static func coup_objet(cible: Node, degats: float, point: Vector3, v: Vector3) -> String:
	var recul := clampf(v.length() * 0.4, 3.0, 9.0)
	return coup(cible, degats, point - v.normalized() * 2.0, {"recul": recul})

## HÔTE : valide un coup (de `att` sur `pair`) puis l'applique. Renvoie "" si refusé.
static func _valider_coup(att: int, pair: int, degats: float, origine: Vector3, opt: Dictionary) -> String:
	if not est_hote() or not actif() or att == pair or not reseau().joueurs().has(att) or not reseau().joueurs().has(pair):
		return _refus("pvp inactif ou pairs inconnus", att, pair)
	if not is_finite(degats) or degats <= 0.0 or degats > DEGATS_BRUTS_MAX:
		return _refus("dégâts hors bornes", att, pair)
	var victime: Node = ReseauProjectiles.joueur_local() if pair == 1 else ReseauProjectiles.avatar(pair)
	if not _debout(victime):
		return _refus("victime à terre ou morte", att, pair)
	var attaquant: Node3D = ReseauProjectiles.joueur_local() if att == 1 else ReseauProjectiles.avatar(att)
	if attaquant != null and (victime as Node3D).global_position.distance_to(attaquant.global_position) > PORTEE_MAX:
		return _refus("trop loin", att, pair)
	var cle := att * 100000 + pair
	var t := Time.get_ticks_msec()
	if t - int(_derniers.get(cle, -100000)) < DELAI_MS:
		return _refus("cadence", att, pair)
	_derniers[cle] = t
	var vmax := float(victime.get("vie_max")) if victime.get("vie_max") != null else 100.0
	var deg := minf(degats * FACTEUR_DEGATS, maxf(8.0, vmax * PART_MAX))
	var o := CombatCoop._propre(opt)
	if o.has("recul"):
		o["recul"] = clampf(float(o["recul"]), 0.0, 9.0)
	journal.append({"type": EV_COUP, "att": att, "cible": pair, "deg": deg})
	if pair == 1:
		return String((victime as Node).call("recevoir_coup", deg, origine, o))
	CombatCoop._coup_vers(deg, origine, o, pair)
	return "touche"

static func _refus(raison: String, att: int, pair: int) -> String:
	refuses += 1
	journal.append({"type": EV_COUP, "att": att, "cible": pair, "refuse": raison})
	return ""

static func _sur_coup(exp: int, id: Variant, d: Variant) -> void:
	if not est_hote() or exp == 1 or not (d is Dictionary):
		return
	var dd := d as Dictionary
	if not (dd.get("orig") is Vector3) or not (dd.get("opt") is Dictionary):
		return
	_valider_coup(exp, int(id), float(dd.get("deg", 0.0)), dd["orig"], dd["opt"])

# ---------------------------------------------------------------------------------------------------- états : saisie, lévitation, lancer
## Opération du joueur local sur l'avatar `cible` : "tenir" {p: pieds}, "projeter" / "lacher" {v: vitesse}.
static func op(cible: Node, nom: String, d: Dictionary) -> void:
	if not pvp_cible(cible) or not OPS.has(nom):
		return
	var pair := pair_de(cible)
	if est_hote():
		_router_op(mon_id(), pair, nom, d)
	else:
		var dd := d.duplicate()
		dd["op"] = nom
		reseau().envoyer_evenement(EV_OP, pair, dd, 1)

## HÔTE : valide et route vers la victime (ou l'applique si c'est l'hôte).
static func _router_op(att: int, pair: int, nom: String, d: Dictionary) -> void:
	if not est_hote() or not actif() or att == pair or not OPS.has(nom) or not reseau().joueurs().has(pair):
		_refus("op refusée", att, pair)
		return
	var victime: Node = ReseauProjectiles.joueur_local() if pair == 1 else ReseauProjectiles.avatar(pair)
	if not _debout(victime):
		_refus("op : victime à terre", att, pair)
		return
	var dd := {}
	if d.get("v") is Vector3:
		var v: Vector3 = d["v"]
		if not v.is_finite():
			_refus("op : vitesse invalide", att, pair)
			return
		dd["v"] = v.limit_length(VITESSE_OP_MAX)
	if d.get("p") is Vector3:
		var p: Vector3 = d["p"]
		var attaquant: Node3D = ReseauProjectiles.joueur_local() if att == 1 else ReseauProjectiles.avatar(att)
		if not p.is_finite() or (attaquant != null and p.distance_to(attaquant.global_position) > ECART_TENUE_MAX):
			_refus("op : point de saisie trop loin", att, pair)
			return
		dd["p"] = p
	dd["op"] = nom
	dd["de"] = att
	journal.append({"type": EV_OP, "att": att, "cible": pair, "op": nom})
	if pair == 1:
		_appliquer_op(dd)
	else:
		reseau().envoyer_evenement(EV_OP, att, dd, pair)

static func _sur_op(exp: int, id: Variant, d: Variant) -> void:
	if not (d is Dictionary):
		return
	var dd := d as Dictionary
	if est_hote():
		if exp != 1:
			_router_op(exp, int(id), String(dd.get("op", "")), dd)
	elif exp == 1:
		_appliquer_op(dd)

## VICTIME : applique l'opération reçue à son propre joueur.
static func _appliquer_op(d: Dictionary) -> void:
	var j := ReseauProjectiles.joueur_local()
	if j == null or not actif():
		return
	var v := PvpVictime.pour(j)
	journal.append({"type": "op_recue", "op": String(d.get("op", ""))})
	match String(d.get("op", "")):
		"tenir":
			v.tenir(d.get("p", j.global_position))
		"projeter", "lacher":
			v.lancer(d.get("v", Vector3.ZERO))

# ---------------------------------------------------------------------------------------------------- réglage
static func _sur_reglage(exp: int, _id: Variant, d: Variant) -> void:
	if exp != 1 or est_hote() or not (d is Dictionary):
		return
	pvp = bool((d as Dictionary).get("on", true))
	journal.append({"type": EV_REGLAGE, "on": pvp})

## Nœud d'horloge : dégâts continus regroupés, rediffusion périodique du réglage par l'hôte.
class PvpHorloge extends Node:
	var _t := 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _physics_process(dt: float) -> void:
		if not PvpCoop.en_ligne():
			return
		PvpCoop._vider_agregats(dt)
		_t += dt
		if _t >= 3.0:
			_t = 0.0
			if PvpCoop.est_hote():
				PvpCoop.reseau().envoyer_evenement(PvpCoop.EV_REGLAGE, 0, {"on": PvpCoop.pvp})
