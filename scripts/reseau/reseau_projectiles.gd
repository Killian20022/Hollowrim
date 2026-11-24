class_name ReseauProjectiles
extends RefCounted
## Coop, lot 4c : flèches, sorts, projectiles ennemis, pièges et mécanismes. Tout est statique et paresseux (comme ReseauLieux) ;
## hors ligne (solo) chaque appel est un no-op : le comportement solo est inchangé. Voir docs/reseau_lot4c.md.
##
## PRINCIPES
##  - Trajectoire DÉTERMINISTE : l'émetteur annonce `proj_spawn` / `sort_spawn` (départ, direction, vitesse…) ; chaque machine fait voler sa
##    propre COPIE (`distant = true`), sans état continu. L'invité qui tire envoie à l'hôte, qui relaie aux autres invités.
##  - Dégâts SUR LES ENNEMIS : seule la copie du TIREUR touche. Hôte : il applique (DegatsCombat). Invité : il envoie `proj_coup` /
##    `sort_coup` (id de la cible, dégâts, point) ; l'hôte VALIDE (pair connu, cible vivante, portée, plafond de dégâts, cadence) puis applique.
##  - Dégâts SUR LES JOUEURS : la VICTIME décide. Les projectiles ennemis (annoncés par l'hôte) et les zones ennemies sont rejoués
##    chez chacun, et ne touchent que le joueur LOCAL (garde, parade, esquive, armure locales). Les avatars distants sont ignorés.
##  - Pas de tir allié : flèches et sorts du joueur ignorent les avatars (groupes « ennemis » / « cibles_combat » seulement).
##  - Soin / protection : un sort de soin ou de protection canalisé soigne / protège aussi les alliés proches (RAYON_ALLIE).
##
## API : installer(), nouvel_id(), annoncer_fleche_joueur(p), annoncer_ennemi(p, genre, d), annoncer_sort(p, s, k, taille, ennemi),
##   fx_zone / fx_chaine / fx_decharge, deleguer_coup_sort(...), soigner_allies / proteger_allies, absorber_allie(degats, options),
##   id_cible(n) / trouver_cible(id, point), est_avatar(n), exclus_avatars(), cible_locale(n),
##   router_meca(noeud, action, arg), piege_evenement(ident, type, d), enregistrer_meca(ident, noeud).

const EV_SPAWN := "proj_spawn"
const EV_COUP := "proj_coup"
const EV_FIN := "proj_fin"
const EV_SORT_SPAWN := "sort_spawn"
const EV_SORT_FX := "sort_fx"
const EV_SORT_COUP := "sort_coup"
const EV_SOIN := "sort_soin"
const EV_PROTECTION := "sort_protection"
const EV_PIEGE := "piege_evt"
const EV_MECA_DEMANDE := "meca_demande"
const EV_MECA := "meca_evt"

const RAYON_ALLIE := 6.0
const PART_SOIN_ALLIE := 0.75
const PART_PROTECTION_ALLIE := 0.5
const SOIN_MAX_PAR_EVENT := 40.0
const DEGATS_MAX_FLECHE := 60.0
const FACTEUR_MAX_SORT := 8.0
const PORTEE_MAX := 160.0
const MARGE_CIBLE := 4.0
const DELAI_MIN_COUP_MS := 80
const PERIODE_PIEGE_SYNC := 2.0

static var _pret := false
static var _n := 0
static var _vivants := {}       # id -> Projectile (copies et originaux de cette machine)
static var _copie := false      # vrai pendant la création d'une copie distante (pas de ré-annonce)
static var _derniers := {}      # hôte : pair -> dernier coup validé (ms)
static var _lanceurs := {}      # hôte : pair -> LanceurSorts de l'avatar (coups de sort validés)
static var _sorts := {}
static var _protection := {}    # protection d'un allié reçue : {fin, phys, mag}
static var _acc_soin := {}      # pair -> vie à envoyer
static var _t_protec := {}      # pair -> prochain envoi (ms)
static var _pieges := {}        # ident -> Node (pièges et mécanismes de CETTE machine)
## Journal des évènements reçus et validés (tests) : [{type, id, ...}].
static var journal: Array = []
## Vrai : l'hôte a refusé des coups invalides (compteur, tests).
static var refuses := 0

# ---------------------------------------------------------------------------------------------------- base
static func reseau() -> Node:
	return ReseauLieux.reseau()

static func en_ligne() -> bool:
	var r := reseau()
	return r != null and r.est_en_ligne()

static func est_hote() -> bool:
	var r := reseau()
	return r == null or r.est_hote()

static func invite() -> bool:
	return en_ligne() and not est_hote()

static func mon_id() -> int:
	var r := reseau()
	return r.mon_id() if r != null else 1

static func nouvel_id() -> String:
	_n += 1
	return "%d:%d" % [mon_id(), _n]

static func joueur_local() -> Node3D:
	var arbre := Engine.get_main_loop() as SceneTree
	return arbre.get_first_node_in_group("joueur_local") as Node3D if arbre != null else null

static func avatar(pair: int) -> Node3D:
	var r := reseau()
	if r == null or pair == mon_id():
		return null
	return r.registre.noeud(pair) as Node3D

## Avatars des AUTRES joueurs (nœuds « Joueur_<id> »).
static func avatars() -> Array:
	var res := []
	if not en_ligne():
		return res
	for id: int in reseau().joueurs():
		var a := avatar(id)
		if a != null and is_instance_valid(a):
			res.append(a)
	return res

static func est_avatar(n: Object) -> bool:
	return n != null and is_instance_valid(n) and "est_local" in n and not bool(n.get("est_local"))

## RID des avatars distants (rayons des projectiles : jamais de tir allié, la victime résout).
static func exclus_avatars() -> Array[RID]:
	var res: Array[RID] = []
	if not en_ligne():
		return res
	for a in avatars():
		if a is CollisionObject3D:
			res.append((a as CollisionObject3D).get_rid())
	return res

## `n` si c'est un joueur résolu ici (local, ou toute autre cible), null si c'est un avatar distant.
static func cible_locale(n: Node) -> Node:
	return null if est_avatar(n) else n

static func _parent_monde() -> Node:
	var j := joueur_local()
	if j != null and j.get_parent() != null:
		return j.get_parent()
	var arbre := Engine.get_main_loop() as SceneTree
	return arbre.current_scene if arbre != null and arbre.current_scene != null else arbre.root

static func installer() -> void:
	if _pret:
		return
	var r := reseau()
	if r == null:
		return
	_pret = true
	PvpCoop.installer()   # PvP : coups et états entre joueurs (scripts/reseau/pvp_coop.gd)
	r.abonner(EV_SPAWN, ReseauProjectiles._sur_spawn)
	r.abonner(EV_COUP, ReseauProjectiles._sur_coup)
	r.abonner(EV_FIN, ReseauProjectiles._sur_fin)
	r.abonner(EV_SORT_SPAWN, ReseauProjectiles._sur_sort_spawn)
	r.abonner(EV_SORT_FX, ReseauProjectiles._sur_sort_fx)
	r.abonner(EV_SORT_COUP, ReseauProjectiles._sur_sort_coup)
	r.abonner(EV_SOIN, ReseauProjectiles._sur_soin)
	r.abonner(EV_PROTECTION, ReseauProjectiles._sur_protection)
	r.abonner(EV_PIEGE, ReseauProjectiles._sur_piege)
	r.abonner(EV_MECA_DEMANDE, ReseauProjectiles._sur_meca_demande)
	r.abonner(EV_MECA, ReseauProjectiles._sur_meca)

static func reinitialiser() -> void:
	_vivants.clear()
	_derniers.clear()
	_lanceurs.clear()
	_acc_soin.clear()
	_protection.clear()
	_pieges.clear()
	journal.clear()
	refuses = 0

## Diffuse un évènement : hôte -> tous les invités ; invité -> hôte (qui relaie, voir _relais).
static func _diffuser(type: String, id: Variant, d: Variant) -> void:
	if en_ligne():
		reseau().envoyer_evenement(type, id, d)

## Hôte : renvoie aux AUTRES invités un évènement reçu d'un invité. Invité : n'accepte que ce qui vient de l'hôte.
static func _relais(expediteur: int, type: String, id: Variant, d: Variant) -> bool:
	if est_hote():
		if expediteur != 1:
			for p: int in reseau().joueurs():
				if p != 1 and p != expediteur:
					reseau().envoyer_evenement(type, id, d, p)
		return true
	return expediteur == 1

## Évènement destiné à UN pair (`pour`) : l'hôte l'envoie directement, l'invité passe par l'hôte (champ « pour »).
static func _vers_pair(type: String, id: Variant, d: Dictionary, pair: int) -> void:
	if not en_ligne() or pair == mon_id():
		return
	if est_hote():
		reseau().envoyer_evenement(type, id, d, pair)
	else:
		d["pour"] = pair
		reseau().envoyer_evenement(type, id, d, 1)

## Transfert hôte d'un évènement « pour » un autre pair ; vrai = déjà traité (ne pas appliquer ici).
static func _transfert(type: String, id: Variant, d: Dictionary) -> bool:
	if not d.has("pour"):
		return false
	var pour := int(d["pour"])
	if pour == mon_id():
		return false
	if est_hote():
		d.erase("pour")
		reseau().envoyer_evenement(type, id, d, pour)
	return true

static func _id_pair_connu(pair: int) -> bool:
	return reseau().joueurs().has(pair)

# ---------------------------------------------------------------------------------------------------- cibles (ennemis)
## Identifiant réseau d'une cible : `id_reseau` (propriété ou méta, posé par le lot ennemis) sinon `ident`, sinon le nom du nœud.
static func id_cible(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return ""
	if n.has_meta("id_reseau"):
		return String(n.get_meta("id_reseau"))
	var v: Variant = n.get("id_reseau")
	if v is String and String(v) != "":
		return String(v)
	v = n.get("ident")
	if v is String and String(v) != "":
		return "i:" + String(v)
	return "n:" + String(n.name)

static func _cibles() -> Array:
	var arbre := Engine.get_main_loop() as SceneTree
	var res := []
	if arbre == null:
		return res
	for g in ["ennemis", "cibles_combat"]:
		for e in arbre.get_nodes_in_group(g):
			if e is Node3D and is_instance_valid(e) and not res.has(e):
				res.append(e)
	return res

static func _vivant(e: Node) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	if e.get("est_mort") == true:
		return false
	return not e.has_method("vivant") or bool(e.call("vivant"))

## Cible par identifiant ; repli : la cible vivante la plus proche de `point` (< 2 m) si l'identifiant est inconnu.
static func trouver_cible(id: String, point := Vector3.INF) -> Node:
	var meilleur: Node = null
	var dmin := 2.0
	for e in _cibles():
		if id != "" and id_cible(e) == id:
			return e
		if point != Vector3.INF and _vivant(e):
			var d := Elements._centre(e).distance_to(point)
			if d < dmin:
				dmin = d
				meilleur = e
	return meilleur

# ---------------------------------------------------------------------------------------------------- projectiles
static func _suivre(id: String, p: Node) -> void:
	_vivants[id] = p

## Flèche du joueur (ArcJoueur) : annonce le tir aux autres (chacun fait voler sa copie).
static func annoncer_fleche_joueur(p: Projectile, vit: float) -> void:
	if not en_ligne() or _copie or p == null:
		return
	installer()
	p.id_reseau = nouvel_id()
	_suivre(p.id_reseau, p)
	_diffuser(EV_SPAWN, p.id_reseau, {"genre": "fleche_joueur", "depart": p.global_position, "dir": p.vitesse.normalized(), "vit": vit,
		"degats": p.degats, "vref": p.vitesse_reference, "dmin": p.degats_min, "de": mon_id()})

## Projectile ENNEMI (flèche d'archer, trait de givre) : l'hôte seul annonce ; la victime résout chez elle.
static func annoncer_ennemi(p: Projectile, genre: String, vit: float) -> void:
	if not en_ligne() or _copie or not est_hote() or p == null:
		return
	installer()
	p.id_reseau = nouvel_id()
	_suivre(p.id_reseau, p)
	_diffuser(EV_SPAWN, p.id_reseau, {"genre": genre, "depart": p.global_position, "dir": p.vitesse.normalized(), "vit": vit,
		"degats": p.degats, "de": 1})

static func _sur_spawn(expediteur: int, id: Variant, d: Variant) -> void:
	if not (d is Dictionary) or not _relais(expediteur, EV_SPAWN, id, d):
		return
	var dd := d as Dictionary
	var ident := String(id)
	var depart: Vector3 = dd["depart"]
	var dir: Vector3 = dd["dir"]
	var parent := _parent_monde()
	var loc := joueur_local()
	var genre := String(dd["genre"])
	_copie = true
	var p: Projectile = null
	match genre:
		"fleche_joueur":
			var tireur := avatar(int(dd.get("de", 0)))
			p = Projectile.tirer_joueur(parent, depart, dir, tireur as CollisionObject3D, float(dd["degats"]), float(dd["vit"]), false)
			p.vitesse_reference = float(dd.get("vref", 46.0))
			p.degats_min = float(dd.get("dmin", 3.0))
		"fleche":
			p = Projectile.tirer(parent, depart, dir, null, float(dd["degats"]), loc)
		"givre":
			p = Projectile.tirer_givre(parent, depart, dir, null, float(dd["degats"]), loc, float(dd["vit"]))
	_copie = false
	if p == null:
		return
	p.distant = true
	p.id_reseau = ident
	_suivre(ident, p)
	journal.append({"type": EV_SPAWN, "id": ident, "genre": genre})

## Un projectile a fini sa course chez une victime (flèche ennemie qui a touché) : les copies des autres disparaissent.
static func fin(id: String, position: Vector3) -> void:
	if id == "" or not en_ligne():
		return
	_diffuser(EV_FIN, id, {"pos": position})

static func _sur_fin(expediteur: int, id: Variant, d: Variant) -> void:
	if not _relais(expediteur, EV_FIN, id, d):
		return
	var p: Variant = _vivants.get(String(id))
	if p is Projectile and is_instance_valid(p) and not (p as Projectile).plantee:
		(p as Projectile).queue_free()
	_vivants.erase(String(id))

## Invité : une flèche de CE joueur a touché une cible -> l'hôte valide et applique.
static func envoyer_coup_fleche(p: Projectile, cible: Node, degats: float, point: Vector3, dir: Vector3, vitesse: float) -> void:
	if not invite() or p == null:
		return
	reseau().envoyer_evenement(EV_COUP, p.id_reseau, {"cible": id_cible(cible), "degats": degats, "point": point, "dir": dir, "vit": vitesse}, 1)

static func _cadence_ok(pair: int) -> bool:
	var t := Time.get_ticks_msec()
	if t - int(_derniers.get(pair, -100000)) < DELAI_MIN_COUP_MS:
		return false
	_derniers[pair] = t
	return true

static func _sur_coup(expediteur: int, id: Variant, d: Variant) -> void:
	if not est_hote() or expediteur == 1 or not (d is Dictionary):
		return
	var dd := d as Dictionary
	var point: Vector3 = dd.get("point", Vector3.ZERO)
	var degats := float(dd.get("degats", 0.0))
	var cible := trouver_cible(String(dd.get("cible", "")), point)
	var av := avatar(expediteur)
	var ok := _id_pair_connu(expediteur) and cible != null and _vivant(cible) and degats > 0.0 and degats <= DEGATS_MAX_FLECHE \
		and Elements._centre(cible).distance_to(point) <= MARGE_CIBLE and (av == null or av.global_position.distance_to(point) <= PORTEE_MAX) \
		and _cadence_ok(expediteur)
	if not ok:
		refuses += 1
		journal.append({"type": EV_COUP, "id": String(id), "refuse": true, "de": expediteur})
		return
	var dir: Vector3 = dd.get("dir", Vector3.FORWARD)
	var info := {"type": "perforant", "point": point, "direction": dir, "normale": -dir, "zone": DegatsCombat.zone(cible as Node3D, point),
		"attaque": "legere", "arme": "arc", "stagger": 0.35 * clampf(degats / 36.0, 0.2, 1.0), "collider": cible, "affaibli": false,
		"charge": 0.0, "instant": 0.0, "lanceur": av}
	var res := DegatsCombat.appliquer(cible, degats, point - dir * 2.0, false, info)
	journal.append({"type": EV_COUP, "id": String(id), "cible": id_cible(cible), "degats": degats, "resultat": res, "de": expediteur})

# ---------------------------------------------------------------------------------------------------- sorts
static func sort_par_id(id: String) -> DonneesSort:
	if id == "":
		return null
	if _sorts.has(id):
		return _sorts[id]
	var s: DonneesSort = null
	for chemin in ["res://data/sorts/%s.tres", "res://data/sorts/ennemis/%s.tres"]:
		if ResourceLoader.exists(chemin % id):
			s = load(chemin % id) as DonneesSort
			break
	_sorts[id] = s
	return s

## Projectile de sort (joueur : `ennemi` faux ; mage ennemi, annoncé par l'hôte : vrai).
static func annoncer_sort(p: ProjectileSort, s: DonneesSort, k: float, taille: float, ennemi: bool) -> void:
	if not en_ligne() or _copie or p == null or (ennemi and not est_hote()):
		return
	installer()
	p.id_reseau = nouvel_id()
	_suivre(p.id_reseau, p)
	_diffuser(EV_SORT_SPAWN, p.id_reseau, {"sort": s.id, "depart": p.global_position, "dir": p.vitesse.normalized(), "k": k, "taille": taille,
		"ennemi": ennemi, "de": mon_id()})

static func _sur_sort_spawn(expediteur: int, id: Variant, d: Variant) -> void:
	if not (d is Dictionary) or not _relais(expediteur, EV_SORT_SPAWN, id, d):
		return
	var dd := d as Dictionary
	var s := sort_par_id(String(dd.get("sort", "")))
	if s == null:
		return
	var ident := String(id)
	var k := float(dd.get("k", 1.0))
	var taille := float(dd.get("taille", 1.0))
	var ennemi := bool(dd.get("ennemi", false))
	var dir: Vector3 = dd["dir"]
	var loc := joueur_local()
	var rappel: Callable
	if ennemi:
		var lanc := LanceurSorts.new(null, "joueur")
		lanc.cible_joueur = loc
		rappel = func(cible: Node, point: Vector3, normale: Vector3) -> void:
			EffetsMagie.impact(s.ecole, point, normale, k * (1.6 if s.rayon > 0.0 else 0.8))
			if cible != null and cible == loc:
				lanc.frapper(cible, s.degats * k, s, point, dir, false, s.stagger * k)
				fin(ident, point)
	else:
		rappel = func(_cible: Node, point: Vector3, normale: Vector3) -> void:
			EffetsMagie.impact(s.ecole, point, normale, k * (1.6 if s.rayon > 0.0 else 0.8))
			if s.rayon > 0.0:
				EffetsMagie.zone(s.ecole, point, s.rayon, 0.3)
	var visuel := EffetsMagie.projectile_visuel(s.ecole, s.forme, taille)
	var av := avatar(int(dd.get("de", 0)))
	var exclus: Array = [av] if av != null else []
	_copie = true
	var p := ProjectileSort.tirer_sort(_parent_monde(), dd["depart"], dir, s.vitesse, visuel, rappel, exclus, s.traverse, taille)
	_copie = false
	p.genre = {"glace": "givre", "feu": "feu", "electricite": "foudre", "tenebres": "ombre"}.get(s.ecole, "sort")
	p.vise = "joueur" if ennemi else "ennemis"
	p.cible_joueur = loc if ennemi else null
	p.distant = true
	p.id_reseau = ident
	if not ennemi:
		p.add_to_group("projectiles_joueur")
	_suivre(ident, p)
	journal.append({"type": EV_SORT_SPAWN, "id": ident, "sort": s.id, "ennemi": ennemi})

## Effets visuels d'un sort non projectile : « zone » (centre, rayon, durée), « chaine » (points), « decharge », « impact ».
## `ennemi` : le sort vient d'un ennemi (l'hôte annonce) -> chaque machine fait résoudre les dégâts par sa victime locale.
static func _fx(d: Dictionary) -> void:
	if not en_ligne() or _copie:
		return
	installer()
	_diffuser(EV_SORT_FX, nouvel_id(), d)

static func fx_zone(s: DonneesSort, centre: Vector3, k: float, ennemi: bool) -> void:
	if ennemi and not est_hote():
		return
	_fx({"kind": "zone", "sort": s.id, "centre": centre, "k": k, "ennemi": ennemi})

static func fx_chaine(s: DonneesSort, points: Array[Vector3]) -> void:
	var l: Array = []
	for p in points:
		l.append(p)
	_fx({"kind": "chaine", "sort": s.id, "points": l})

static func fx_decharge(s: DonneesSort, depart: Vector3, point: Vector3, k: float, normale: Vector3, ennemi: bool) -> void:
	if ennemi and not est_hote():
		return
	_fx({"kind": "decharge", "sort": s.id, "depart": depart, "point": point, "k": k, "normale": normale, "ennemi": ennemi})

static func _sur_sort_fx(expediteur: int, id: Variant, d: Variant) -> void:
	if not (d is Dictionary) or not _relais(expediteur, EV_SORT_FX, id, d):
		return
	var dd := d as Dictionary
	var s := sort_par_id(String(dd.get("sort", "")))
	if s == null:
		return
	var k := float(dd.get("k", 1.0))
	var ennemi := bool(dd.get("ennemi", false))
	_copie = true
	match String(dd.get("kind", "")):
		"zone":
			var c: Vector3 = dd["centre"]
			EffetsMagie.zone(s.ecole, c, s.rayon, maxf(s.duree_zone, 0.6))
			if ennemi:
				_zone_ennemie_locale(s, c, k)
		"chaine":
			var pts: Array[Vector3] = []
			for v in dd.get("points", []):
				pts.append(v)
			EffetsMagie.chaine(s.ecole, pts)
		"decharge":
			EffetsMagie.decharge(s.ecole, s.forme, dd["depart"], dd["point"], k, dd["normale"])
			EffetsMagie.impact(s.ecole, dd["point"], dd["normale"], 0.5 + 0.8 * k)
			if ennemi:
				_zone_ennemie_locale(s, dd["point"], k, maxf(s.rayon, 1.0) + 0.5)
	_copie = false
	journal.append({"type": EV_SORT_FX, "kind": String(dd.get("kind", "")), "sort": s.id})

## Sort ennemi à zone : la victime LOCALE est touchée si elle est dans le rayon (garde, armure, résistances locales).
static func _zone_ennemie_locale(s: DonneesSort, centre: Vector3, k: float, rayon_fixe := -1.0) -> void:
	var loc := joueur_local()
	if loc == null or bool(loc.get("mort")):
		return
	var rel := loc.global_position - centre
	var dy := absf(rel.y)
	rel.y = 0.0
	var r := rayon_fixe if rayon_fixe > 0.0 else s.rayon + 0.2
	if rel.length() <= r and dy < 1.6:
		var lanc := LanceurSorts.new(null, "joueur")
		lanc.cible_joueur = loc
		lanc.frapper(loc, s.degats * k, s, loc.global_position, loc.global_position - centre)

## Invité : coup de sort sur un ennemi -> l'hôte arbitre. Renvoie vrai si délégué (l'appelant n'applique rien localement).
static func deleguer_coup_sort(cible: Node, quantite: float, s: DonneesSort, point: Vector3, direction: Vector3, continu: bool, stagger: float) -> bool:
	if not invite() or cible == null:
		return false
	installer()
	reseau().envoyer_evenement(EV_SORT_COUP, id_cible(cible), {"sort": s.id, "q": quantite, "point": point, "dir": direction, "continu": continu, "st": stagger}, 1)
	return true

static func _lanceur_hote(pair: int) -> LanceurSorts:
	var av := avatar(pair)
	var l: LanceurSorts = _lanceurs.get(pair)
	if l == null or l.lanceur != av:
		l = LanceurSorts.new(av, "ennemis")
		_lanceurs[pair] = l
	return l

static func _sur_sort_coup(expediteur: int, id: Variant, d: Variant) -> void:
	if not est_hote() or expediteur == 1 or not (d is Dictionary):
		return
	var dd := d as Dictionary
	var s := sort_par_id(String(dd.get("sort", "")))
	var point: Vector3 = dd.get("point", Vector3.ZERO)
	var q := float(dd.get("q", 0.0))
	var cible := trouver_cible(String(id), point)
	var av := avatar(expediteur)
	var ok := s != null and _id_pair_connu(expediteur) and cible != null and _vivant(cible) and q > 0.0 \
		and q <= maxf(s.degats, 1.0) * FACTEUR_MAX_SORT + 5.0 and Elements._centre(cible).distance_to(point) <= MARGE_CIBLE + maxf(s.rayon, 1.0) \
		and (av == null or av.global_position.distance_to(point) <= PORTEE_MAX) and (bool(dd.get("continu", false)) or _cadence_ok(expediteur))
	if not ok:
		refuses += 1
		journal.append({"type": EV_SORT_COUP, "id": String(id), "refuse": true, "de": expediteur})
		return
	var res := _lanceur_hote(expediteur).infliger_distant(cible, q, s, point, dd.get("dir", Vector3.FORWARD), bool(dd.get("continu", false)), float(dd.get("st", -1.0)))
	journal.append({"type": EV_SORT_COUP, "id": String(id), "sort": s.id, "degats": q, "resultat": res, "de": expediteur})

# ---------------------------------------------------------------------------------------------------- soins / protections d'allié
## Le joueur LOCAL soigne les alliés proches (RAYON_ALLIE) : `quantite` = vie du sort (déjà multipliée par les perks) ; PART_SOIN_ALLIE
## pour l'allié. Cumul puis envoi par paquets (>= 1,5 PV) ; `immediat` : envoi tout de suite (sort instantané).
static func soigner_allies(lanceur: Node3D, quantite: float, immediat := false) -> void:
	if not en_ligne() or lanceur == null or quantite <= 0.0 or est_avatar(lanceur):
		return
	installer()
	for a in avatars():
		var pair := _pair_de(a)
		if pair <= 0 or a.global_position.distance_to(lanceur.global_position) > RAYON_ALLIE or bool(a.get("mort")):
			continue
		_acc_soin[pair] = float(_acc_soin.get(pair, 0.0)) + quantite * PART_SOIN_ALLIE
		if immediat or float(_acc_soin[pair]) >= 1.5:
			var q := minf(float(_acc_soin[pair]), SOIN_MAX_PAR_EVENT)
			_acc_soin[pair] = 0.0
			_vers_pair(EV_SOIN, pair, {"q": q, "de": mon_id()}, pair)

static func _pair_de(a: Node) -> int:
	for id: int in reseau().joueurs():
		if reseau().registre.noeud(id) == a:
			return id
	return -1

static func _sur_soin(_exp: int, id: Variant, d: Variant) -> void:
	if not (d is Dictionary) or _transfert(EV_SOIN, id, d):
		return
	var loc := joueur_local()
	if loc != null and loc.has_method("soigner"):
		var q := clampf(float((d as Dictionary).get("q", 0.0)), 0.0, SOIN_MAX_PAR_EVENT)
		loc.call("soigner", q)
		journal.append({"type": EV_SOIN, "q": q, "de": int((d as Dictionary).get("de", 0))})

## Protection canalisée : les alliés proches reçoivent une part de la réduction (aura, sans cône ni coût de mana pour eux).
static func proteger_allies(lanceur: Node3D, s: DonneesSort) -> void:
	if not en_ligne() or lanceur == null or est_avatar(lanceur) or s == null or s.reduction_physique <= 0.0:
		return
	installer()
	var t := Time.get_ticks_msec()
	for a in avatars():
		var pair := _pair_de(a)
		if pair <= 0 or a.global_position.distance_to(lanceur.global_position) > RAYON_ALLIE or t < int(_t_protec.get(pair, 0)):
			continue
		_t_protec[pair] = t + 250
		_vers_pair(EV_PROTECTION, pair, {"phys": s.reduction_physique * PART_PROTECTION_ALLIE, "mag": s.reduction_magique * PART_PROTECTION_ALLIE,
			"duree": 0.7, "de": mon_id()}, pair)

static func _sur_protection(_exp: int, id: Variant, d: Variant) -> void:
	if not (d is Dictionary) or _transfert(EV_PROTECTION, id, d):
		return
	var dd := d as Dictionary
	_protection = {"fin": Time.get_ticks_msec() + int(clampf(float(dd.get("duree", 0.7)), 0.1, 2.0) * 1000.0),
		"phys": clampf(float(dd.get("phys", 0.0)), 0.0, 0.6), "mag": clampf(float(dd.get("mag", 0.0)), 0.0, 0.6)}
	journal.append({"type": EV_PROTECTION})

static func protege_par_allie() -> bool:
	return not _protection.is_empty() and Time.get_ticks_msec() < int(_protection["fin"])

## Appelé par MainSort.absorber : dégâts restants après la protection d'un allié.
static func absorber_allie(degats: float, options: Dictionary) -> float:
	if not protege_par_allie():
		return degats
	var magique := String(options.get("type", "")) in ["feu", "glace", "electricite", "tenebres", "magique"]
	return degats * (1.0 - float(_protection["mag"] if magique else _protection["phys"]))

# ---------------------------------------------------------------------------------------------------- pièges et mécanismes
## Pièges (Piege.Dalle…) et mécanismes (Mecanisme.Base) s'enregistrent par `ident` (même identifiant partout : génération déterministe).
static func enregistrer_meca(ident: String, n: Node) -> void:
	_pieges[ident] = n
	installer()

## L'hôte annonce l'évènement d'un piège (« declenche », « tir », « arme », « phase »).
static func piege_evenement(ident: String, type: String, d := {}) -> void:
	if not en_ligne() or not est_hote():
		return
	var dd: Dictionary = d.duplicate()
	dd["type"] = type
	reseau().envoyer_evenement(EV_PIEGE, ident, dd)

static func _sur_piege(expediteur: int, id: Variant, d: Variant) -> void:
	if expediteur != 1 or est_hote() or not (d is Dictionary):
		return
	var n: Node = _pieges.get(String(id))
	if n != null and is_instance_valid(n) and n.has_method("evenement_distant"):
		n.call("evenement_distant", String((d as Dictionary).get("type", "")), d)
		journal.append({"type": EV_PIEGE, "id": String(id), "evt": String((d as Dictionary).get("type", ""))})

## Mécanisme : « ne rien faire maintenant ». Hôte : applique tout de suite et diffuse (retour faux). Invité : demande à l'hôte (retour vrai).
## Hors ligne ou application d'un évènement distant (`_distant`) : faux.
static func router_meca(n: Node, action: String, arg: Variant) -> bool:
	if not en_ligne() or bool(n.get("_distant")):
		return false
	installer()
	var ident := String(n.get("ident"))
	if est_hote():
		reseau().envoyer_evenement(EV_MECA, ident, {"action": action, "arg": arg, "qui": 1})
		return false
	reseau().envoyer_evenement(EV_MECA_DEMANDE, ident, {"action": action, "arg": arg}, 1)
	return true

static func _sur_meca_demande(expediteur: int, id: Variant, d: Variant) -> void:
	if not est_hote() or expediteur == 1 or not (d is Dictionary):
		return
	var n: Node = _pieges.get(String(id))
	if n == null or not is_instance_valid(n) or not n.has_method("accepter_demande"):
		return
	var dd := d as Dictionary
	if bool(n.call("accepter_demande", String(dd.get("action", "")), dd.get("arg"), expediteur)):
		n.call("appliquer_distant", String(dd["action"]), dd.get("arg"), expediteur)   # l'hôte applique d'abord (et arbitre les conséquences)
		reseau().envoyer_evenement(EV_MECA, String(id), {"action": dd["action"], "arg": dd.get("arg"), "qui": expediteur})
		journal.append({"type": EV_MECA_DEMANDE, "id": String(id), "action": String(dd["action"]), "de": expediteur})

static func _sur_meca(expediteur: int, id: Variant, d: Variant) -> void:
	if not (d is Dictionary) or not _relais(expediteur, EV_MECA, id, d):
		return
	var n: Node = _pieges.get(String(id))
	if n != null and is_instance_valid(n) and n.has_method("appliquer_distant"):
		var dd := d as Dictionary
		n.call("appliquer_distant", String(dd.get("action", "")), dd.get("arg"), int(dd.get("qui", 1)))
		journal.append({"type": EV_MECA, "id": String(id), "action": String(dd.get("action", "")), "qui": int(dd.get("qui", 1))})
