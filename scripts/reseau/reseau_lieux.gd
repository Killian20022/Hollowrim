class_name ReseauLieux
extends RefCounted
## Coop, lot 2c : lieux (crypte, grotte, tumulus), portes, coffres, contenants, butin au sol. L'HÔTE ARBITRE, l'invité DEMANDE.
## Tout est statique et paresseux ; hors ligne (solo) chaque appel exécute l'action locale tout de suite : comportement inchangé.
##
##   ReseauLieux.reclamer(cle, si_gagne, si_perdu := Callable(), type := "coffre")
##       « premier arrivé » : un seul joueur obtient `cle` (coffre, contenant, objet unique/au sol). Le gagnant exécute `si_gagne`
##       (verse le butin chez lui) ; les autres exécutent `si_perdu` puis les rappels `sur_pris` (marquer vidé, couvercle ouvert…).
##       Invité : la réponse arrive plus tard (aller-retour hôte) : l'action locale n'est PAS faite sur-le-champ.
##   ReseauLieux.router_porte(id) -> bool
##       à appeler en tête de l'action d'une porte/mécanisme ; vrai = « ne rien faire maintenant » (invité : demande envoyée, l'effet
##       arrive par diffusion ; hôte : déjà ouverte). Faux = appliquer l'effet localement (l'hôte l'a diffusé, ou c'est la diffusion).
##   ReseauLieux.enregistrer_porte(id, appliquer: Callable)    effet local rejoué quand la diffusion de `id` arrive
##   ReseauLieux.sur_pris(rappel(cle, type, qui))              un AUTRE joueur a obtenu `cle` (par défaut : ButinTables.piller)
##   ReseauLieux.sur_etat(rappel)                              ré-applique l'état (portes, coffres) après l'import d'un instantané
##   ReseauLieux.poser_quetes(q, prefixes)                     état « vus » du lieu, exporté dans l'instantané (rejoindre en cours)
## Contributeur d'instantané : « lieux » (portes ouvertes, clés `vus` des lieux, contenants pillés, attributions).

const EV_DEMANDE := "lieu_demande"   # invité -> hôte : (cle, {"type", "genre"})
const EV_PRIS := "lieu_pris"         # hôte -> tous : (cle, {"qui", "type"}) ; qui = peer gagnant
const EV_PORTE_DEMANDE := "lieu_porte_demande"
const EV_PORTE := "lieu_porte"       # hôte -> tous : (id, null)

static var _pret := false
static var _attribue := {}           # hôte : cle -> peer gagnant
static var _attente := {}            # invité : cle -> {"gagne", "perdu"}
static var _portes := {}             # id -> true (ouvertes, côté hôte et appliquées chez les invités)
static var _portes_appliquer := {}   # id -> Callable
static var _distant := false
static var _rappels_pris: Array[Callable] = []
static var _rappels_etat: Array[Callable] = []
static var _quetes: Object = null
static var _prefixes: Array = ["crypte:", "meca:"]
static var _contributeur_ok := false

# ---------------------------------------------------------------------------------------------------- mise en route
static func _init_reseau() -> void:
	if _pret:
		return
	_pret = true
	reseau().abonner(EV_DEMANDE, ReseauLieux._sur_demande)
	reseau().abonner(EV_PRIS, ReseauLieux._sur_pris_evt)
	reseau().abonner(EV_PORTE_DEMANDE, ReseauLieux._sur_porte_demande)
	reseau().abonner(EV_PORTE, ReseauLieux._sur_porte_evt)
	_brancher_contributeur()

## Branche le contributeur « lieux » sur l'autoload Rejoindre (lot 2a) s'il existe (recherche dynamique : aucun couplage de compilation).
static func _brancher_contributeur() -> void:
	if _contributeur_ok:
		return
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre == null:
		return
	var r := arbre.root.get_node_or_null("Rejoindre")
	if r != null and r.has_method("contributeur"):
		r.call("contributeur", "lieux", Callable(ReseauLieux, "exporter"), Callable(ReseauLieux, "importer"))
		_contributeur_ok = true

## Partie neuve / retour au menu : oublie tout.
static func reinitialiser() -> void:
	_attribue.clear()
	_attente.clear()
	_portes.clear()
	_distant = false

## Monde quitté : lâche les rappels (lambdas de tertre.gd, grotte…) et les quêtes. Gardés dans des variables STATIQUES, ils
## n'étaient libérés qu'au déchargement des scripts, APRÈS celui des scripts qui les ont créés : plantage à la sortie (code 5).
static func vider() -> void:
	reinitialiser()
	_portes_appliquer.clear()
	_rappels_pris.clear()
	_rappels_etat.clear()
	_quetes = null

static func poser_quetes(q: Object, prefixes: Array = []) -> void:
	_quetes = q
	for p in prefixes:
		if not _prefixes.has(p):
			_prefixes.append(p)
	_init_reseau()

static func sur_pris(rappel: Callable) -> void:
	if not _rappels_pris.has(rappel):
		_rappels_pris.append(rappel)
	_init_reseau()

static func sur_etat(rappel: Callable) -> void:
	if not _rappels_etat.has(rappel):
		_rappels_etat.append(rappel)
	_init_reseau()

static func enregistrer_porte(id: String, appliquer: Callable) -> void:
	_portes_appliquer[id] = appliquer
	_init_reseau()

## Autoload Reseau, résolu à l'exécution (ce script est préchargé par des tests en `-s` avant l'enregistrement des autoloads).
## Opti cpu_scripts (2026-11-20) : 46 appelants (pièges, projectiles, lieux…), plusieurs fois par pas ; le nœud Reseau (autoload)
## est gardé tant qu'il est dans l'arbre (sinon recherché comme avant : même résultat).
static var _reseau_garde: Node
static func reseau() -> Node:
	if is_instance_valid(_reseau_garde) and _reseau_garde.is_inside_tree():
		return _reseau_garde
	_reseau_garde = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Reseau")
	return _reseau_garde

static func _en_ligne() -> bool:
	return reseau().est_en_ligne()

static func _vus() -> Dictionary:
	return _quetes.get("vus") if _quetes != null and is_instance_valid(_quetes) else {}

## Clé déjà prise (hôte) : attribuée cette session, coffre déjà vidé (vus) ou contenant pillé.
static func deja_pris(cle: String) -> bool:
	return _attribue.has(cle) or _vus().has(cle) or ButinTables.est_pille(cle)

# ---------------------------------------------------------------------------------------------------- premier arrivé
static func reclamer(cle: String, si_gagne: Callable, si_perdu := Callable(), type := "coffre") -> void:
	if not _en_ligne():
		si_gagne.call()
		return
	_init_reseau()
	if reseau().est_hote():
		if deja_pris(cle):
			if si_perdu.is_valid():
				si_perdu.call()
			return
		_attribue[cle] = reseau().mon_id()
		reseau().envoyer_evenement(EV_PRIS, cle, {"qui": reseau().mon_id(), "type": type})
		si_gagne.call()
	else:
		if _attente.has(cle):
			return
		_attente[cle] = {"gagne": si_gagne, "perdu": si_perdu}
		reseau().envoyer_evenement(EV_DEMANDE, cle, {"type": type}, 1)

static func _sur_demande(expediteur: int, cle: Variant, d: Variant) -> void:
	if not reseau().est_hote():
		return
	var c := String(cle)
	var type := String((d as Dictionary).get("type", "coffre")) if d is Dictionary else "coffre"
	if deja_pris(c):
		# perdu : on dit au demandeur qui a gagné (l'hôte par défaut si la clé vient d'une sauvegarde)
		reseau().envoyer_evenement(EV_PRIS, c, {"qui": int(_attribue.get(c, 1)), "type": type, "seul": true}, expediteur)
		return
	_attribue[c] = expediteur
	reseau().envoyer_evenement(EV_PRIS, c, {"qui": expediteur, "type": type})
	_appliquer_pris_autre(c, type, expediteur)   # l'hôte n'est pas le gagnant : il marque le contenant comme pris

static func _sur_pris_evt(expediteur: int, cle: Variant, d: Variant) -> void:
	if expediteur != 1 or not (d is Dictionary):
		return
	var c := String(cle)
	var qui := int((d as Dictionary).get("qui", 0))
	var type := String((d as Dictionary).get("type", "coffre"))
	var att: Dictionary = _attente.get(c, {})
	_attente.erase(c)
	if qui == reseau().mon_id():
		if att.has("gagne"):
			(att["gagne"] as Callable).call()
		return
	if att.has("perdu") and (att["perdu"] as Callable).is_valid():
		(att["perdu"] as Callable).call()
	_appliquer_pris_autre(c, type, qui)

static func _appliquer_pris_autre(cle: String, type: String, qui: int) -> void:
	if type == "contenant" or type == "unique":
		ButinTables.piller(cle)    # contenant cassable / objet unique : la partie locale se vide d'elle-même (sondage de est_pille)
	_attribue[cle] = qui
	for r in _rappels_pris.duplicate():
		if r.is_valid():
			r.call(cle, type, qui)
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre != null and type == "unique":
		arbre.call_group("objets_uniques", "actualiser")

# ---------------------------------------------------------------------------------------------------- portes
static func router_porte(id: String) -> bool:
	if not _en_ligne():
		return false
	_init_reseau()
	if _distant:
		_portes[id] = true
		return false
	if reseau().est_hote():
		if _portes.has(id):
			return true
		_portes[id] = true
		reseau().envoyer_evenement(EV_PORTE, id, null)
		return false
	reseau().envoyer_evenement(EV_PORTE_DEMANDE, id, null, 1)
	return true

static func _sur_porte_demande(_exp: int, id: Variant, _d: Variant) -> void:
	if not reseau().est_hote():
		return
	var i := String(id)
	if _portes.has(i):
		return
	_portes[i] = true
	reseau().envoyer_evenement(EV_PORTE, i, null)
	_rejouer_porte(i)

static func _sur_porte_evt(expediteur: int, id: Variant, _d: Variant) -> void:
	if expediteur != 1:
		return
	_rejouer_porte(String(id))

static func _rejouer_porte(id: String) -> void:
	_portes[id] = true
	var c: Callable = _portes_appliquer.get(id, Callable())
	if c.is_valid():
		_distant = true
		c.call()
		_distant = false

static func porte_ouverte(id: String) -> bool:
	return _portes.has(id)

# ---------------------------------------------------------------------------------------------------- instantané (rejoindre en cours)
static func exporter() -> Dictionary:
	var vus: Array = []
	for k: String in _vus():
		for p: String in _prefixes:
			if k.begins_with(p):
				vus.append(k)
				break
	vus.sort()
	var att := {}
	for k in _attribue:
		att[k] = _attribue[k]
	var pi: Array = _portes.keys()
	pi.sort()
	return {"vus": vus, "portes": pi, "attribue": att}

static func importer(d: Dictionary) -> void:
	var v := _vus()
	for k in d.get("vus", []):
		v[String(k)] = true
	for k in d.get("portes", []):
		_portes[String(k)] = true
	var att: Dictionary = d.get("attribue", {})
	for k in att:
		_attribue[String(k)] = int(att[k])
		if not _est_cle_vus(String(k)):
			ButinTables.piller(String(k))      # contenant / unique pris : sa copie locale se vide d'elle-même
	for r in _rappels_etat.duplicate():
		if r.is_valid():
			r.call()

static func _est_cle_vus(cle: String) -> bool:
	for p: String in _prefixes:
		if cle.begins_with(p):
			return true
	return false

## Raccourci pour les tests / outils : le lieu a-t-il enregistré ce rappel ?
static func nb_rappels() -> int:
	return _rappels_pris.size() + _rappels_etat.size() + _portes_appliquer.size()
