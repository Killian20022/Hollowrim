class_name ReseauCorps
extends Node
## LOT 4d — gore, ragdoll, cadavres, butin des corps, effets de coup en coop (docs/reseau_lot4d.md).
##  - MORT : l'HÔTE décide (membre tranché, décapitation, sort, force du ragdoll, graine) dans `arbitrer_mort` et diffuse le plan
##    (évènement « corps_mort ») ; chaque invité rejoue `_mourir` de SON ennemi avec ce plan (même démembrement, mêmes impulsions, même graine
##    des tirages de Demembrement). Aucune réplication image par image : le ragdoll est simulé chez chacun ; une fois le corps figé chez
##    l'hôte, celui-ci envoie le bassin + la tête (« corps_repos ») et l'invité recale son cadavre (Ragdoll.recaler).
##  - BUTIN DES CORPS : Butin.cle_reseau = « corps:<ident> » ; la fouille et les pièces sont « premier arrivé » (ReseauLieux.reclamer, type
##    « corps »). Contributeur Rejoindre « cadavres » : corps encore fouillables, pour un invité qui arrive en cours de partie.
##  - EFFETS DE COUP : l'hôte qui valide un coup diffuse « corps_impact » ; les invités jouent sang / gerbe / étincelles / son.
##  - Plafond de ragdolls actifs en ligne (max_ragdolls) : le plus ancien est figé tout de suite.
## Solo : tout est inerte (arbitrer_mort renvoie son entrée, aucun nœud créé). `Reseau` est résolu à l'exécution (tests `-s`).

const EV_MORT := "corps_mort"
const EV_REPOS := "corps_repos"
const EV_IMPACT := "corps_impact"
static var max_ragdolls := 8   # tests : abaissé
const DELAI_REPOS := 8.0          # s : un invité fige son corps de force après ce délai si l'hôte a déjà envoyé la position finale

static var _noeud: ReseauCorps
## Plan en cours d'application chez un invité (lu par arbitrer_mort).
static var plan_impose := {}
## Contenu de butin décidé par l'hôte (ident -> Dictionary), consommé par EnnemiBase/Draugr._laisser_butin via contenu_de.
static var contenus := {}
static var _butins := {}          # cle_reseau -> Butin
static var _en_impact := false
## Tests : nombre d'effets de coup rejoués depuis l'hôte.
static var impacts_joues := 0

var _ragdolls: Array = []         # [{"id", "rd"}]
var _attente := {}                # ident -> {"rd", "t"} (invité : corps en attente de la position finale)
var _repos := {}                  # ident -> {"bassin", "tete"} reçu
var _role := ""

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

static func est_invite() -> bool:
	return en_ligne() and not est_hote()

## Crée le nœud (une fois) sous la racine : abonnements aux évènements, rappels du butin, contributeur « cadavres ».
static func assurer() -> void:
	if _noeud != null and is_instance_valid(_noeud):
		return
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre == null or arbre.root == null or R() == null:
		return
	_noeud = ReseauCorps.new()
	_noeud.name = "ReseauCorps"
	arbre.root.add_child.call_deferred(_noeud)
	R().abonner(EV_MORT, ReseauCorps._sur_mort)
	R().abonner(EV_REPOS, ReseauCorps._sur_repos)
	R().abonner(EV_IMPACT, ReseauCorps._sur_impact)
	ReseauLieux.sur_pris(Callable(ReseauCorps, "_sur_pris"))
	ReseauLieux.sur_etat(Callable(ReseauCorps, "_balayer_butins"))
	var rj := arbre.root.get_node_or_null("Rejoindre")
	if rj != null:
		rj.call("contributeur", "cadavres", Callable(ReseauCorps, "exporter"), Callable(ReseauCorps, "importer"))

## Tests : libère l'état statique (entre deux scénarios).
static func reinitialiser() -> void:
	plan_impose = {}
	contenus.clear()
	_butins.clear()

static func trouver(ident: String) -> Node:
	if ident == "":
		return null
	var arbre := Engine.get_main_loop() as SceneTree
	for n in arbre.get_nodes_in_group("ennemis"):
		if str(n.get("ident")) == ident:
			return n
	for n in arbre.get_nodes_in_group("bete_quat"):
		if str(n.get("ident")) == ident:
			return n
	return null

# ---------------------------------------------------------------------------------------------------- mort
## Appelé par `_mourir` (EnnemiBase, Draugr) une fois les décisions prises, avant le ragdoll. `dec` : membre, decapiter, effet_sort, force,
## montee, os, point, dir, vitesse, sorte, origine, quantite, puissant, info {point, direction, normale, zone}. Renvoie les décisions à appliquer :
## solo / hors ligne = `dec` tel quel ; hôte en ligne = `dec` + graine, diffusé ; invité = le plan reçu (le rejeu local ne décide rien).
## `f_contenu` : Callable() -> Dictionary, contenu du butin du corps (tiré une seule fois, par l'hôte).
static func arbitrer_mort(e: Node, dec: Dictionary, f_contenu := Callable()) -> Dictionary:
	if not en_ligne():
		return dec
	var ident := str(e.get("ident") if e.get("ident") != null else "")
	if not plan_impose.is_empty():
		var p: Dictionary = plan_impose.duplicate()
		if Demembrement.niveau() == 0:
			p["membre"] = ""            # réglage gore local à 0 : pas de coupe, quoi que l'hôte ait décidé
			p["decapiter"] = false
		Demembrement._rng.seed = int(p.get("graine", 1))
		return p
	if not est_hote() or ident == "":
		return dec
	assurer()
	var plan := dec.duplicate()
	plan["graine"] = int(hash(ident)) ^ int(Time.get_ticks_msec())
	plan["pos"] = (e as Node3D).global_position
	plan["lacet"] = (e as Node3D).rotation.y
	if f_contenu.is_valid():
		var c: Variant = f_contenu.call()
		if c is Dictionary:
			plan["contenu"] = c
			contenus[ident] = c
	Demembrement._rng.seed = int(plan["graine"])
	var rep := _rep()
	if rep != null:
		rep.call("diffuser", EV_MORT, ident, plan, 0, false)
	return plan

## Contenu du butin décidé par l'hôte pour `ident` (consommé), sinon `repli`.
static func contenu_de(ident: String, repli: Dictionary) -> Dictionary:
	if contenus.has(ident):
		var c: Dictionary = contenus[ident]
		contenus.erase(ident)
		return c
	return repli

## À appeler après Ragdoll.declencher : suit le corps (plafond de ragdolls actifs, position finale).
static func suivre_ragdoll(ident: String, rd: Ragdoll) -> void:
	if rd == null or not en_ligne():
		return
	assurer()
	if _noeud != null:
		_noeud._suivre(ident, rd)

func _suivre(ident: String, rd: Ragdoll) -> void:
	_ragdolls = _ragdolls.filter(func(d: Dictionary) -> bool: return is_instance_valid(d["rd"]) and not (d["rd"] as Ragdoll).est_fige())
	_ragdolls.append({"id": ident, "rd": rd})
	while _ragdolls.size() > max_ragdolls:
		var vieux: Dictionary = _ragdolls.pop_front()
		(vieux["rd"] as Ragdoll).forcer_figer()
	if ident == "":
		return
	if est_hote():
		rd.fige.connect(_envoyer_repos.bind(ident, rd), CONNECT_ONE_SHOT)
	else:
		_attente[ident] = {"rd": rd, "t": 0.0}

func _envoyer_repos(ident: String, rd: Ragdoll) -> void:
	var b := rd.os.get("pelvis") as Node3D
	var t := rd.os.get("Head") as Node3D
	if b == null or not est_hote() or _rep() == null:
		return
	_rep().call("diffuser", EV_REPOS, ident, {"bassin": b.global_position, "tete": t.global_position if t != null else b.global_position}, 0, false)

static func _sur_mort(exp: int, id: Variant, d: Variant) -> void:
	if exp != 1 or est_hote() or not (d is Dictionary):
		return
	var e := trouver(String(id))
	if e == null or (e.has_method("vivant") and not e.vivant()):
		return
	var plan: Dictionary = d
	if plan.has("contenu"):
		contenus[String(id)] = plan["contenu"]
	var pos: Vector3 = plan.get("pos", (e as Node3D).global_position)
	if (e as Node3D).global_position.distance_to(pos) > 0.4:
		(e as Node3D).global_position = pos          # la marionnette traînait derrière l'hôte : on la recale avant la chute
	(e as Node3D).rotation.y = float(plan.get("lacet", (e as Node3D).rotation.y))
	plan_impose = plan
	var info: Dictionary = plan.get("info", {})
	e.call("_mourir", plan.get("origine", Vector3.ZERO), float(plan.get("quantite", 20.0)), bool(plan.get("puissant", false)),
		{"info": info} if not info.is_empty() else {}, String(plan.get("sorte", "legere")))
	plan_impose = {}

static func _sur_repos(exp: int, id: Variant, d: Variant) -> void:
	if exp != 1 or est_hote() or not (d is Dictionary) or _noeud == null:
		return
	_noeud._repos[String(id)] = d
	_noeud._appliquer_repos()

func _process(dt: float) -> void:
	var r := R()
	var role := "" if r == null or not r.est_en_ligne() else ("hote" if r.est_hote() else "invite")
	if role != _role:
		_role = role
		get_tree().call_group("faune_gestion", "basculer_reseau", role == "invite")
	if not _attente.is_empty():
		for id in _attente:
			_attente[id]["t"] = float(_attente[id]["t"]) + dt
		_appliquer_repos()

func _appliquer_repos() -> void:
	for id in _attente.keys():
		var a: Dictionary = _attente[id]
		var rd := a["rd"] as Ragdoll
		if not is_instance_valid(rd):
			_attente.erase(id)
			_repos.erase(id)
			continue
		if not _repos.has(id):
			if float(a["t"]) > 40.0:
				_attente.erase(id)
			continue
		if not rd.est_fige() and float(a["t"]) < DELAI_REPOS:
			continue                       # le corps local bouge encore : on attend son repos
		rd.forcer_figer()
		var d: Dictionary = _repos[id]
		rd.recaler(d["bassin"], d["tete"])
		_attente.erase(id)
		_repos.erase(id)

# ---------------------------------------------------------------------------------------------------- effets de coup
## Appelé par CombatEnnemi.effets_impact : l'hôte (qui valide le coup) fait jouer sang / gerbes / étincelles / son chez les invités.
## `r["info"]["qui"]` (facultatif) = pair de l'attaquant : il a déjà joué l'effet chez lui et ne le rejoue pas.
static func diffuser_impact(c: Object, r: Dictionary) -> void:
	if _en_impact or not en_ligne() or not est_hote() or _rep() == null:
		return
	var corps: Node = c.get("corps")
	if corps == null:
		return
	var ident := str(corps.get("ident") if corps.get("ident") != null else "")
	if ident == "" or not r.has("info"):
		return
	var i: Dictionary = r["info"]
	assurer()
	_rep().call("diffuser", EV_IMPACT, ident, {
		"point": i.get("point", Vector3.ZERO), "dir": i.get("direction", Vector3.FORWARD), "normale": i.get("normale", Vector3.UP),
		"zone": String(i.get("zone", "torse")), "impact": String(r.get("impact", "leger")), "degats": float(r.get("degats", 0.0)),
		"magie": i.has("ecole"), "continu": bool(i.get("continu", false)), "type": String(i.get("type", "tranchant")),
		"arme": i.has("arme"), "qui": int(i.get("qui", 0))}, 0, false)

static func _sur_impact(exp: int, id: Variant, d: Variant) -> void:
	if exp != 1 or est_hote() or not (d is Dictionary):
		return
	if int((d as Dictionary).get("qui", 0)) == int(R().mon_id()):
		return
	var e := trouver(String(id))
	if e != null:
		jouer_impact(e, d)

## Rejoue localement les effets visuels et sonores d'un coup (sous-ensemble de CombatEnnemi.effets_impact : pas de réaction ni d'arrêt sur image).
static func jouer_impact(e: Node, d: Dictionary) -> void:
	var c: CombatEnnemi = e.get("combat")
	if c == null or c.profil == null or c.corps == null or not c.corps.is_inside_tree():
		return
	var profil: ProfilCible = c.profil
	var p := ProfilImpact.de(String(d.get("impact", "leger")))
	var point: Vector3 = d["point"]
	var dir: Vector3 = d["dir"]
	var zone := String(d.get("zone", "torse"))
	var armure := (profil.armure >= 2.0 or profil.armure_part >= 0.06) and zone in ["torse", "bras"]
	var casque := profil.armure_tete > 0.0 and zone == "tete"
	var part := 0.25 if bool(d.get("continu", false)) else (0.6 if bool(d.get("magie", false)) else 1.0)
	if casque:
		part *= 0.35
	_en_impact = true
	impacts_joues += 1
	if profil.sang and Sang.actif():
		Sang.giclee(c.corps, point, dir, p.sang * part, profil.couleur_sang)
	else:
		Sang.eclats_matiere(c.corps, point, dir, p.sang * 0.8, profil.couleur_sang if not profil.sang else Color(0.45, 0.42, 0.38))
	var dir_g := (Vector3(d.get("normale", -dir)) * 0.7 + dir * 0.5 + Vector3.UP * 0.35).normalized()
	var mat_g := c.matiere_gerbe()
	if not bool(d.get("magie", false)) and not bool(d.get("continu", false)) and mat_g in ["draugr", "sang", "chair"]:
		GerbePixels.emettre(c.corps, point, dir_g, mat_g, GerbePixels.force_de(p.nom) * (0.7 if mat_g == "sang" else 1.0))
	if armure or casque:
		GerbePixels.emettre(c.corps, point - dir * 0.05, dir_g, "etincelles", 0.8 if p.nom in ["leger", "moyen"] else 1.4)
	if not bool(d.get("continu", false)):
		RetourImpact.son_impact(c.corps, profil.matiere, p, point, armure)
		if casque:
			RetourImpact.son(c.corps, "armure", point, p.volume_db, 1.2)
	_en_impact = false

# ---------------------------------------------------------------------------------------------------- butin des corps
static func enregistrer_butin(cle: String, b: Node) -> void:
	_butins[cle] = b

static func retirer_butin(cle: String, b: Node) -> void:
	if _butins.get(cle) == b:
		_butins.erase(cle)

## Un AUTRE joueur a obtenu la fouille (« corps:<id> ») ou les pièces (« corps:<id>:or ») : ce corps se vide chez nous.
static func _sur_pris(cle: String, type: String, qui: int) -> void:
	if type != "corps":
		return
	var est_or := cle.ends_with(":or")
	var b: Node = _butins.get(cle.trim_suffix(":or"))
	if b == null or not is_instance_valid(b):
		return
	if est_or:
		b.call("perdre_or")
	else:
		b.call("perdre_fouille", qui)

## Après l'import d'un instantané : les corps déjà fouillés / pillés par d'autres sont vidés.
static func _balayer_butins() -> void:
	for cle: String in _butins.keys():
		var b: Node = _butins[cle]
		if not is_instance_valid(b):
			continue
		if ReseauLieux.deja_pris(cle) and not bool(b.get("gagnant")):
			b.call("perdre_fouille", 0)
		if ReseauLieux.deja_pris(cle + ":or") and not bool(b.get("or_demande")):
			b.call("perdre_or")

## Hôte : corps encore fouillables (modèle décrit, objets restants, non fouillés par un autre).
static func exporter() -> Dictionary:
	var r := {}
	for cle: String in _butins:
		var b: Node = _butins[cle]
		if not is_instance_valid(b) or (b.get("objets") as Dictionary).is_empty() or (b.get("modele_spec") as Dictionary).is_empty():
			continue
		if ReseauLieux.deja_pris(cle):
			continue
		var p: Vector3 = (b as Node3D).global_position
		r[cle] = {"pos": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)], "nom": String(b.get("nom_corps")),
			"modele": (b.get("modele_spec") as Dictionary).duplicate(), "objets": (b.get("objets") as Dictionary).duplicate()}
	return {"corps": r}

## Invité : repose les corps de l'hôte (dépouille statique + invite « Fouiller ») qu'il n'a pas déjà.
static func importer(d: Dictionary) -> void:
	var arbre := Engine.get_main_loop() as SceneTree
	var j := arbre.get_first_node_in_group("joueur_local") as CharacterBody3D
	if j == null or j.get_parent() == null:
		return
	for cle: String in d.get("corps", {}):
		if _butins.has(cle):
			continue
		var e: Dictionary = d["corps"][cle]
		var pos: Array = e["pos"]
		var b := Node3D.new()
		b.set_script(preload("res://scripts/butin.gd"))
		b.set("joueur", j)
		b.set("hud", j.get("hud"))
		b.set("nom_corps", String(e.get("nom", "Dépouille")))
		b.set("contenu", (e["objets"] as Dictionary).duplicate())
		b.set("cle_reseau", cle)
		b.set("modele_spec", (e.get("modele", {}) as Dictionary).duplicate())
		b.add_child(preload("res://scripts/butin.gd").modele_depouille(b.get("modele_spec"), b))
		j.get_parent().add_child(b)
		(b as Node3D).global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
