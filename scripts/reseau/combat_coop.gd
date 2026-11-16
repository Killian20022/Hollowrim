class_name CombatCoop
extends Node
## COOP LOT 4a — ennemis et dégâts multi-cibles. Voir docs/reseau_lot4a.md.
## L'HÔTE détient l'IA des ennemis ; l'invité n'a que des marionnettes (ennemi.marionnette = true : IA coupée, animation / position / PV
## répliqués par le Replicateur). Hors ligne (solo) : toutes les fonctions sont sans effet.
##   CombatCoop.enregistrer(ennemi)        à appeler (différé) en fin de _ready : id stable, réplication, échelle PV/dégâts
##   CombatCoop.maj_cible(ennemi, dt)      hôte : choisit `ennemi.joueur` (joueur le plus proche / menaçant, menace persistante)
##   CombatCoop.envoyer_coup(...)          marionnette : transmet le coup (arme, dégâts calculés localement, position) à l'hôte
##   CombatCoop.noter_mort(...)            hôte : diffuse la mort (ragdoll chez les invités)
##   CombatCoop.facteur_pv(n) / facteur_degats(n)    mise à l'échelle (data/coop/echelle.json)
## Évènements (Reseau.envoyer_evenement) : cb_coup (invité -> hôte), cb_impact / cb_mort (hôte -> invités), cb_coup_subi (hôte -> victime),
## cb_coup_res (victime -> hôte), cb_pv (PV d'un joueur, pour l'affichage chez les autres).
## `Reseau` est résolu à l'exécution (PauseCoop.R()) : ce script est aussi préchargé par des tests lancés en `-s`.

const FICHIER := "res://data/coop/echelle.json"
const EV_COUP := "cb_coup"
const EV_IMPACT := "cb_impact"
const EV_MORT := "cb_mort"
const EV_SUBI := "cb_coup_subi"
const EV_RES := "cb_coup_res"
const EV_PV := "cb_pv"
const PERTINENCE := 120.0
## Propriétés de dégâts mises à l'échelle (celles qui existent sur l'ennemi ; valeur de base mémorisée à l'enregistrement).
const CHAMPS_DEGATS := ["degats", "degats_tir", "degats_givre", "degats_zone", "_degats_souffle"]

static var _donnees := {}
static var _reg := {}               # id -> ennemi
static var _inst: CombatCoop
static var _abonne := false
static var _derniers := {}          # "pair|id" -> ms du dernier coup accepté
## Journal (tests, débogage) : [{type, ...}].
static var journal: Array = []
## Dernier résultat renvoyé par une victime (pair -> "touche" / "bloque" / "esquive"…), côté hôte.
static var dernier_res := {}

# ---------------------------------------------------------------------------------------------------- accès
static func R() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Reseau")

static func _rep() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Replicateur")

static func en_ligne() -> bool:
	var r := R()
	return r != null and r.est_en_ligne()

static func est_hote() -> bool:
	var r := R()
	return r == null or r.est_hote()

static func est_marionnette() -> bool:
	return en_ligne() and not est_hote()

static func nb_joueurs() -> int:
	var r := R()
	return maxi(1, r.joueurs().size()) if r != null and r.est_en_ligne() else 1

static func table() -> Dictionary:
	if _donnees.is_empty():
		var t: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER)) if FileAccess.file_exists(FICHIER) else null
		_donnees = t if t is Dictionary else {}
	return _donnees

static func _val(section: String, cle: String, defaut: float) -> float:
	var s: Variant = table().get(section, {})
	return float((s as Dictionary).get(cle, defaut)) if s is Dictionary else defaut

## Joueur local (groupe « joueur_local », posé par joueur.gd).
static func joueur_local() -> Node3D:
	var arbre := Engine.get_main_loop() as SceneTree
	return arbre.get_first_node_in_group("joueur_local") as Node3D if arbre != null else null

## Positions de tous les joueurs (local d'abord ; solo : `[defaut]`) — faune, niveaux de détail.
static func positions_joueurs(defaut: Vector3) -> Array[Vector3]:
	var res: Array[Vector3] = [defaut]
	var r := R()
	if r != null and r.est_en_ligne():
		for id: int in r.registre.ids():
			var n: Node = r.registre.noeud(id)
			if n is Node3D and (n as Node3D).is_inside_tree() and (n as Node3D).global_position != defaut:
				res.append((n as Node3D).global_position)
	return res

## Pour les effets qui visent une caméra (secousse, arrêt sur image) : le joueur local si `j` est un avatar distant.
static func local_ou(j: Node) -> Node:
	if j != null and is_instance_valid(j) and j.get("est_local") != false:
		return j
	var l := joueur_local()
	return l if l != null else j

# ---------------------------------------------------------------------------------------------------- échelle PV / dégâts
static func facteur_pv(n: int) -> float:
	return 1.0 + float(table().get("pv_par_joueur", 0.6)) * float(clampi(n, 1, int(table().get("joueurs_max", 4))) - 1)

static func facteur_degats(n: int) -> float:
	return 1.0 + float(table().get("degats_par_joueur", 0.2)) * float(clampi(n, 1, int(table().get("joueurs_max", 4))) - 1)

static func _vivant(e: Node) -> bool:
	return is_instance_valid(e) and (not e.has_method("vivant") or bool(e.call("vivant")))

## Applique les facteurs du nombre de joueurs actuel à l'ennemi (PV : vie conservée en PROPORTION de vie_max ; dégâts : valeurs de base × facteur).
static func appliquer_echelle(e: Node) -> void:
	if not is_instance_valid(e) or not e.has_meta("coop_base_vie_max") or bool(e.get("marionnette")):
		return
	var n := nb_joueurs()
	var f := facteur_pv(n)
	var fd := facteur_degats(n)
	if is_equal_approx(f, float(e.get_meta("coop_facteur", 1.0))) and is_equal_approx(fd, float(e.get_meta("coop_facteur_deg", 1.0))):
		return
	var vm_ancien := float(e.get("vie_max"))
	var vm := float(e.get_meta("coop_base_vie_max")) * f
	if vm_ancien > 0.0 and _vivant(e):
		e.set("vie", clampf(float(e.get("vie")) / vm_ancien * vm, 1.0, vm))
	e.set("vie_max", vm)
	for p: String in CHAMPS_DEGATS:
		if e.has_meta("coop_base_" + p):
			e.set(p, float(e.get_meta("coop_base_" + p)) * fd)
	e.set_meta("coop_facteur", f)
	e.set_meta("coop_facteur_deg", fd)

# ---------------------------------------------------------------------------------------------------- enregistrement
static func id_de(e: Node3D) -> String:
	var ident := String(e.get("ident")) if e.get("ident") != null else ""
	if ident != "":
		return "e:" + ident
	return "e:%s@%d" % [e.name, hash(Vector3(snappedf(e.position.x, 0.01), 0.0, snappedf(e.position.z, 0.01)))]

## Un ennemi existe (host et invité, génération identique) : id stable, réplication, échelle. Idempotent. Appelé EN DIFFÉRÉ par les ennemis
## (`CombatCoop.enregistrer.call_deferred(self)`) pour que les sous-classes aient fini de régler vie_max / degats.
static func enregistrer(noeud: Variant) -> void:
	if not is_instance_valid(noeud) or not (noeud is Node3D):   # appel différé : l'ennemi a pu être libéré entre-temps
		return
	var e: Node3D = noeud
	if e.has_meta("coop_id") or not e.is_inside_tree():
		return
	var id := id_de(e)
	e.set_meta("coop_id", id)
	e.set_meta("coop_base_vie_max", float(e.get("vie_max")))
	for p: String in CHAMPS_DEGATS:
		if e.get(p) != null:
			e.set_meta("coop_base_" + p, float(e.get(p)))
	e.set_meta("coop_facteur", 1.0)
	e.set_meta("coop_facteur_deg", 1.0)
	var j: Variant = e.get("joueur")
	e.set_meta("coop_local", j if j is Node else null)
	_reg[id] = e
	_installer()
	var rep := _rep()
	if rep != null:
		rep.enregistrer(id, e, Callable(CombatCoop, "_etat").bind(e), Callable(CombatCoop, "_appliquer").bind(e), PERTINENCE)
	if est_marionnette():
		e.set("marionnette", true)
	else:
		appliquer_echelle(e)

static func retirer(e: Node) -> void:
	if e == null or not e.has_meta("coop_id"):
		return
	var id := String(e.get_meta("coop_id"))
	_reg.erase(id)
	var rep := _rep()
	if rep != null:
		rep.retirer(id)

static func ennemi(id: String) -> Node:
	var e: Variant = _reg.get(id)   # non typé : le nœud peut avoir été libéré
	return e as Node if is_instance_valid(e) else null

static func ids() -> Array:
	var r := _reg.keys()
	r.sort()
	return r

## Remet l'état statique à zéro (tests, retour au menu).
static func reinitialiser() -> void:
	_reg.clear()
	_derniers.clear()
	journal.clear()
	dernier_res.clear()

static func _installer() -> void:
	if _inst != null and is_instance_valid(_inst):
		return
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre == null:
		return
	_inst = CombatCoop.new()
	_inst.name = "CombatCoop"
	arbre.root.add_child.call_deferred(_inst)
	if not _abonne and R() != null:
		_abonne = true
		var r := R()
		r.abonner(EV_COUP, Callable(CombatCoop, "_sur_coup"))
		r.abonner(EV_IMPACT, Callable(CombatCoop, "_sur_impact"))
		r.abonner(EV_MORT, Callable(CombatCoop, "_sur_mort"))
		r.abonner(EV_SUBI, Callable(CombatCoop, "_sur_subi"))
		r.abonner(EV_RES, Callable(CombatCoop, "_sur_res"))
		r.abonner(EV_PV, Callable(CombatCoop, "_sur_pv"))

# ---------------------------------------------------------------------------------------------------- ciblage (hôte)
static func _valide(n: Node) -> bool:
	return n != null and is_instance_valid(n) and n is Node3D and (n as Node3D).is_inside_tree() \
		and not bool(n.get("mort")) and not bool(n.get("a_terre"))

## Pair (identifiant réseau) d'un nœud joueur ; 0 si inconnu.
static func pair_de(n: Node) -> int:
	var r := R()
	if r == null:
		return 0
	for id: int in r.registre.ids():
		if r.registre.noeud(id) == n:
			return id
	var l := joueur_local()
	return r.mon_id() if n == l else 0

## Joueurs ciblables (debout, ni mort ni à terre) : le joueur local + les avatars du registre.
static func candidats(local: Node) -> Array[Node3D]:
	var res: Array[Node3D] = []
	if _valide(local):
		res.append(local as Node3D)
	var r := R()
	if r != null and r.est_en_ligne():
		for id: int in r.registre.ids():
			var n: Node = r.registre.noeud(id)
			if n != local and _valide(n) and not res.has(n as Node3D):
				res.append(n as Node3D)
	return res

## Score = distance - bonus de menace - fidélité envers la cible actuelle ; le plus petit gagne. Aucun candidat : on garde `courante` (ou le local).
static func choisir_cible(e: Node3D, local: Node, courante: Node) -> Node3D:
	var cs := candidats(local)
	if cs.is_empty():
		return (courante if courante is Node3D and is_instance_valid(courante) else local) as Node3D
	var menace: Dictionary = e.get_meta("coop_menace", {})
	var fidele := _val("menace", "fidelite_m", 3.0)
	var meilleur: Node3D = null
	var smin := INF
	for c in cs:
		var s := e.global_position.distance_to(c.global_position)
		s -= minf(float(menace.get(pair_de(c), 0.0)) * _val("menace", "m_par_degat", 0.08), _val("menace", "bonus_max_m", 8.0))
		if c == courante:
			s -= fidele
		if s < smin:
			smin = s
			meilleur = c
	return meilleur

## Un joueur a blessé l'ennemi : sa menace monte (la cible peut basculer sur lui).
static func noter_menace(e: Node, pair: int, degats: float) -> void:
	var m: Dictionary = e.get_meta("coop_menace", {})
	m[pair] = float(m.get(pair, 0.0)) + degats
	e.set_meta("coop_menace", m)

## Appelé par l'IA de l'ennemi à chaque image physique (hôte / solo). Hors ligne : ne fait rien.
static func maj_cible(e: Node3D, dt: float) -> void:
	if not en_ligne() or bool(e.get("marionnette")):
		return
	var t := float(e.get_meta("coop_t_cible", 0.0)) - dt
	if t > 0.0:
		e.set_meta("coop_t_cible", t)
		return
	var periode := _val("menace", "periode_s", 0.25)
	e.set_meta("coop_t_cible", periode)
	var m: Dictionary = e.get_meta("coop_menace", {})
	if not m.is_empty():
		var k := pow(0.5, (periode - t) / maxf(_val("menace", "demi_vie_s", 6.0), 0.1))
		for p in m.keys():
			m[p] = float(m[p]) * k
			if float(m[p]) < 0.5:
				m.erase(p)
	var local: Variant = e.get_meta("coop_local", null)
	if local == null or not is_instance_valid(local):
		local = joueur_local()
	var courante: Variant = e.get("joueur")
	var c := choisir_cible(e, local, courante if courante is Node else null)
	if c != null and c != courante and c is CharacterBody3D:
		e.set("joueur", c)
		var ls: Variant = e.get("lanceur_sorts")
		if ls != null:
			ls.set("cible_joueur", c)

# ---------------------------------------------------------------------------------------------------- réplication d'état
static func _etat(e: Node3D) -> Dictionary:
	var d := {"pos": e.global_position, "a_lacet": e.rotation.y, "vie": float(e.get("vie")), "vm": float(e.get("vie_max")), "vis": e.visible,
		"mort": not _vivant(e)}
	var a: Variant = e.get("anim")
	if e.get("_anim") != null:
		d["anim"] = String(e.get("_anim"))
		if a is AnimationPlayer:
			d["vit"] = (a as AnimationPlayer).speed_scale
	if e.has_method("coop_etat"):
		d.merge(e.call("coop_etat"))
	return d

static func _appliquer(d: Dictionary, e: Node3D) -> void:
	if not is_instance_valid(e) or not bool(e.get("marionnette")):
		return
	e.set("vie", float(d["vie"]))
	e.set("vie_max", float(d["vm"]))
	if bool(d["mort"]):
		if _vivant(e):
			_mourir_local(e, e.global_position - e.global_transform.basis.z, 20.0, false, "")
		return
	if not _vivant(e):
		return
	e.global_position = d["pos"]
	e.rotation.y = float(d["a_lacet"])
	e.visible = bool(d["vis"])
	var nom := String(d.get("anim", ""))
	if nom != "" and nom != String(e.get("_anim")):
		if e.has_method("coop_jouer"):
			e.call("coop_jouer", nom)
		elif e.has_method("_jouer"):
			e.call("_jouer", nom, 0.2)
	var a: Variant = e.get("anim")
	if a is AnimationPlayer and d.has("vit"):
		(a as AnimationPlayer).speed_scale = float(d["vit"])
	if e.has_method("coop_appliquer"):
		e.call("coop_appliquer", d)

static func _mourir_local(e: Node, origine: Vector3, quantite: float, puissant: bool, sorte: String) -> void:
	if e.get_method_argument_count("_mourir") >= 5:
		e.call("_mourir", origine, quantite, puissant, {}, sorte)
	else:
		e.call("_mourir")

# ---------------------------------------------------------------------------------------------------- coups des joueurs
## Garde les valeurs simples (bool, nombres, chaînes, Vector3) : un Dictionary d'info peut contenir des nœuds (collider, lanceur).
static func _propre(info: Dictionary) -> Dictionary:
	var p := {}
	for k in info:
		var v: Variant = info[k]
		if typeof(v) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR3, TYPE_VECTOR2, TYPE_STRING_NAME]:
			p[k] = v
	return p

## MARIONNETTE (invité) : transmet le coup à l'hôte, qui valide et applique. Résultat optimiste « touche » (retour visuel immédiat).
static func envoyer_coup(e: Node3D, quantite: float, origine: Vector3, puissant: bool, info: Dictionary) -> String:
	if not _vivant(e) or not e.has_meta("coop_id"):
		return ""
	if info.has("reaction_de"):
		return "touche"   # tics de statuts nés en local : non synchronisés (voir docs)
	var l := joueur_local()
	R().envoyer_evenement(EV_COUP, String(e.get_meta("coop_id")), {"deg": quantite, "orig": origine, "puis": puissant, "info": _propre(info),
		"pos": l.global_position if l != null else origine})
	journal.append({"type": "envoye", "id": e.get_meta("coop_id"), "deg": quantite})
	return "touche"

static func _refus(raison: String, exp: int, id: String) -> void:
	journal.append({"type": "refus", "raison": raison, "de": exp, "id": id})

static func _sur_coup(exp: int, id: Variant, d: Variant) -> void:
	if not est_hote() or not (d is Dictionary) or exp == 1:
		return
	var ident := String(id)
	var e: Node3D = ennemi(ident) as Node3D
	if e == null or not _vivant(e):
		_refus("ennemi", exp, ident)
		return
	var deg := float(d.get("deg", 0.0))
	if not is_finite(deg) or deg <= 0.0 or deg > _val("validation", "degats_max", 600.0):
		_refus("degats", exp, ident)
		return
	var av: Node = R().registre.noeud(exp)
	if not _valide(av):
		_refus("avatar", exp, ident)
		return
	var info: Dictionary = (d["info"] as Dictionary).duplicate() if d.get("info") is Dictionary else {}
	var distant := info.has("ecole") or info.has("projectile") or bool(info.get("distance", false)) or String(info.get("type", "")) == "perforant"
	var taille := float(e.get("taille")) if e.get("taille") != null else 1.0
	var portee := _val("validation", "portee_distance_m", 90.0) if distant else \
		_val("validation", "portee_melee_m", 6.0) + _val("validation", "portee_melee_par_taille_m", 1.5) * maxf(taille - 1.0, 0.0) + (3.0 if e.has_method("altitude") else 0.0)
	if (av as Node3D).global_position.distance_to(e.global_position) > portee:
		_refus("portee", exp, ident)
		return
	var cle := "%d|%s" % [exp, ident]
	var t := Time.get_ticks_msec()
	if t - int(_derniers.get(cle, -100000)) < int(_val("validation", "cadence_min_s", 0.1) * 1000.0):
		_refus("cadence", exp, ident)
		return
	_derniers[cle] = t
	info["attaquant"] = exp
	noter_menace(e, exp, deg)
	var res := String(e.call("recevoir_coup", deg, d.get("orig", e.global_position), bool(d.get("puis", false)), info))
	journal.append({"type": "applique", "id": ident, "de": exp, "deg": deg, "res": res})
	R().envoyer_evenement(EV_IMPACT, ident, {"res": res, "par": exp, "pt": info.get("point", e.global_position + Vector3(0, 1.0, 0))})

static func _sur_impact(exp: int, id: Variant, d: Variant) -> void:
	if exp != 1 or est_hote():
		return
	var e := ennemi(String(id))
	if e == null or not _vivant(e):
		return
	if e.has_method("_eclair"):
		e.call("_eclair")
	journal.append({"type": "impact", "id": String(id), "res": String((d as Dictionary).get("res", "")) if d is Dictionary else ""})

## HÔTE : l'ennemi meurt (appelé au début de _mourir) -> les marionnettes meurent aussi (ragdoll chez l'invité).
static func noter_mort(e: Node3D, origine: Vector3, quantite: float, puissant: bool, sorte: String) -> void:
	if not en_ligne() or not est_hote() or bool(e.get("marionnette")) or not e.has_meta("coop_id"):
		return
	R().envoyer_evenement(EV_MORT, String(e.get_meta("coop_id")), {"orig": origine, "q": quantite, "puis": puissant, "sorte": sorte})

static func _sur_mort(exp: int, id: Variant, d: Variant) -> void:
	if exp != 1 or est_hote() or not (d is Dictionary):
		return
	var e := ennemi(String(id))
	if e == null or not _vivant(e):
		return
	_mourir_local(e, d["orig"], float(d["q"]), bool(d["puis"]), String(d["sorte"]))
	journal.append({"type": "mort", "id": String(id)})

# ---------------------------------------------------------------------------------------------------- coups des ennemis : la VICTIME décide
## HÔTE : un coup porté à l'avatar d'un invité (joueur.gd, est_local faux -> signal coup_distant) est envoyé à la victime.
static func _coup_vers(degats: float, origine: Vector3, options: Dictionary, pair: int) -> void:
	R().envoyer_evenement(EV_SUBI, "", {"deg": degats, "orig": origine, "opt": _propre(options)}, pair)
	journal.append({"type": "subi_envoye", "vers": pair, "deg": degats})

## Branche l'avatar `n` du pair `pair` (idempotent).
static func brancher_avatar(n: Node, pair: int) -> void:
	if n == null or n.has_meta("coop_branche") or not n.has_signal("coup_distant"):
		return
	n.set_meta("coop_branche", true)
	n.connect("coup_distant", Callable(CombatCoop, "_coup_vers").bind(pair))

static func _sur_subi(exp: int, _id: Variant, d: Variant) -> void:
	if exp != 1 or est_hote() or not (d is Dictionary):
		return
	var j := joueur_local()
	if j == null:
		return
	var res := String(j.call("recevoir_coup", float(d["deg"]), d["orig"], d["opt"]))
	journal.append({"type": "subi", "deg": float(d["deg"]), "res": res})
	R().envoyer_evenement(EV_RES, "", {"res": res}, 1)

static func _sur_res(exp: int, _id: Variant, d: Variant) -> void:
	if est_hote() and d is Dictionary:
		dernier_res[exp] = String((d as Dictionary).get("res", ""))

# ---------------------------------------------------------------------------------------------------- PV des joueurs (affichage)
static func _sur_pv(exp: int, id: Variant, d: Variant) -> void:
	var pair := int(id)
	if pair == R().mon_id() or not (d is Dictionary):
		return
	var n: Node = R().registre.noeud(pair)
	if n != null:
		n.set("vie", float(d["v"]))
		n.set("vie_max", float(d["m"]))
	if est_hote() and exp != 1:   # relais vers les autres invités
		R().envoyer_evenement(EV_PV, pair, d)

# ---------------------------------------------------------------------------------------------------- nœud : surveillance périodique
var _t := 0.0
var _en_ligne_prec := false
var _hote_prec := true
var _n_prec := 1
var _pv_envoye := Vector2(-1.0, -1.0)
var _t_pv := 0.0

func _process(dt: float) -> void:
	var r := R()
	if r == null:
		return
	var en_ligne: bool = r.est_en_ligne()
	var hote: bool = r.est_hote()
	var n := nb_joueurs()
	if en_ligne != _en_ligne_prec or hote != _hote_prec:
		_en_ligne_prec = en_ligne
		_hote_prec = hote
		for id in _reg.keys():
			var e: Node = ennemi(id)
			if e != null:
				e.set("marionnette", en_ligne and not hote)
		_n_prec = -1
	if n != _n_prec:
		_n_prec = n
		Effets.coop = n > 1
		if not (en_ligne and not hote):
			for id in _reg.keys():
				appliquer_echelle(ennemi(id))
	_t += dt
	if _t < 0.4:
		return
	_t = 0.0
	for id in _reg.keys():
		if ennemi(id) == null:
			_reg.erase(id)
	if en_ligne and hote:
		for id: int in r.registre.ids():
			if id != r.mon_id():
				brancher_avatar(r.registre.noeud(id), id)
	_t_pv += 0.4
	var j := joueur_local()
	if en_ligne and j != null and r.joueurs().size() > 1:
		var v := Vector2(float(j.get("vie")), float(j.get("vie_max")))
		if v != _pv_envoye or _t_pv > 3.0:
			_pv_envoye = v
			_t_pv = 0.0
			r.envoyer_evenement(EV_PV, r.mon_id(), {"v": v.x, "m": v.y})
