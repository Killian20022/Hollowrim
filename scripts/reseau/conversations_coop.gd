class_name ConversationsCoop
extends RefCounted
## LOT 5a — conversations avec les PNJ en coop : VERROU simple. Un PNJ ne parle qu'à UN joueur à la fois ; l'hôte arbitre.
##  - Le dialogue reste LOCAL (chaque joueur lit ses répliques et choisit chez lui) ; les effets (quêtes, services, commerce) passent par l'hôte
##    comme les autres actions (Quetes, MarchandCoop, Crime). Seule l'OCCUPATION du PNJ est partagée.
##  - `prendre(pnj, refuse)` avant de parler : faux = occupé par un autre joueur (le Dialogue n'ouvre pas la boîte). Invité : réponse
##    optimiste d'après les verrous connus ; si l'hôte donne finalement le PNJ à un autre (course), `refuse` est rappelé et le Dialogue se ferme.
##  - L'hôte fige le PNJ pendant que l'invité lui parle (`_en_conversation`, `_conv_distante`), comme pour une conversation locale.
## Évènements : conv_demande, conv_fin (invité -> hôte) ; conv_verrou (hôte -> tous : id, détenteur ou 0) ; conv_refus (hôte -> demandeur).
## Solo / hors ligne : `prendre` renvoie toujours vrai, rien n'est envoyé.

const EV_DEMANDE := "conv_demande"
const EV_FIN := "conv_fin"
const EV_VERROU := "conv_verrou"
const EV_REFUS := "conv_refus"

static var _pret := false
static var _verrous := {}          # id de PNJ -> détenteur (peer id)
static var _refuse := Callable()   # rappelé chez l'invité quand l'hôte refuse après coup

static func R() -> Node:
	return PauseCoop.R()

static func brancher() -> void:
	var r := R()
	if _pret or r == null:
		return
	_pret = true
	r.abonner(EV_DEMANDE, ConversationsCoop._sur_demande)
	r.abonner(EV_FIN, ConversationsCoop._sur_fin)
	r.abonner(EV_VERROU, ConversationsCoop._sur_verrou)
	r.abonner(EV_REFUS, ConversationsCoop._sur_refus)
	r.joueur_deconnecte.connect(ConversationsCoop._sur_deconnecte)
	var rj := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Rejoindre")
	if rj != null:
		rj.contributeur("conversations", Callable(ConversationsCoop, "exporter"), Callable(ConversationsCoop, "importer"))

static func reinitialiser() -> void:
	_verrous.clear()
	_refuse = Callable()

## Identifiant réseau d'un PNJ du village ("" : pas un villageois, aucun verrou).
static func id_de(pnj: Node) -> String:
	if pnj == null or not is_instance_valid(pnj) or not pnj.is_in_group("villageois"):
		return ""
	return ReseauMondeVivant.id_de(pnj)

## Détenteur actuel (peer id) du PNJ, 0 s'il est libre.
static func detenteur(pnj: Node) -> int:
	return int(_verrous.get(id_de(pnj), 0))

static func occupe_par_autre(pnj: Node) -> bool:
	var d := detenteur(pnj)
	return d != 0 and d != R().mon_id()

## Prend le PNJ pour parler. Faux : un autre joueur lui parle déjà.
static func prendre(pnj: Node, refuse := Callable()) -> bool:
	var r := R()
	if r == null or not r.est_en_ligne():
		return true
	var id := id_de(pnj)
	if id == "":
		return true
	brancher()
	var moi: int = r.mon_id()
	var d := int(_verrous.get(id, 0))
	if d != 0 and d != moi and r.registre.a(d):
		return false
	_verrous[id] = moi
	_refuse = refuse
	if r.est_hote():
		_appliquer(id, moi)
		r.envoyer_evenement(EV_VERROU, id, moi)
	else:
		r.envoyer_evenement(EV_DEMANDE, id, null)
	return true

## Le joueur local a fini de parler.
static func liberer(pnj: Node) -> void:
	var r := R()
	if r == null or not r.est_en_ligne():
		return
	var id := id_de(pnj)
	if id == "" or int(_verrous.get(id, 0)) != r.mon_id():
		return
	_verrous.erase(id)
	_refuse = Callable()
	if r.est_hote():
		_appliquer(id, 0)
		r.envoyer_evenement(EV_VERROU, id, 0)
	else:
		r.envoyer_evenement(EV_FIN, id, null)

# ---------------------------------------------------------------------------------------------------- hôte
static func _sur_demande(exp: int, id: Variant, _d: Variant) -> void:
	var r := R()
	if r == null or not r.est_hote():
		return
	var cle := String(id)
	var d := int(_verrous.get(cle, 0))
	if d != 0 and d != exp and r.registre.a(d):
		r.envoyer_evenement(EV_REFUS, cle, d, exp)      # occupé : le demandeur se retire
		return
	_verrous[cle] = exp
	_appliquer(cle, exp)
	r.envoyer_evenement(EV_VERROU, cle, exp)

static func _sur_fin(exp: int, id: Variant, _d: Variant) -> void:
	var r := R()
	if r == null or not r.est_hote():
		return
	var cle := String(id)
	if int(_verrous.get(cle, 0)) != exp:
		return
	_verrous.erase(cle)
	_appliquer(cle, 0)
	r.envoyer_evenement(EV_VERROU, cle, 0)

static func _sur_deconnecte(id: int) -> void:
	var r := R()
	if r == null or not r.est_hote():
		return
	for cle: String in _verrous.keys():
		if int(_verrous[cle]) == id:
			_verrous.erase(cle)
			_appliquer(cle, 0)
			r.envoyer_evenement(EV_VERROU, cle, 0)

## L'hôte fige / libère le PNJ du village `id` quand un INVITÉ lui parle.
static func _appliquer(id: String, qui: int) -> void:
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre == null:
		return
	for n in arbre.get_nodes_in_group("villageois"):
		if ReseauMondeVivant.id_de(n) != id:
			continue
		if qui > 1:
			n.set("_conv_distante", true)
			n.set("_en_conversation", true)
			n.set("_debut_conversation", 0.0)
		elif bool(n.get("_conv_distante")):
			n.set("_conv_distante", false)
			if n.has_method("fin_conversation"):
				n.fin_conversation()
		return

# ---------------------------------------------------------------------------------------------------- invité
static func _sur_verrou(exp: int, id: Variant, d: Variant) -> void:
	if exp != 1 or R().est_hote():
		return
	var qui := int(d)
	if qui == 0:
		_verrous.erase(String(id))
	else:
		_verrous[String(id)] = qui

## L'hôte a donné le PNJ à un autre joueur entre-temps.
static func _sur_refus(exp: int, id: Variant, d: Variant) -> void:
	if exp != 1 or R().est_hote():
		return
	_verrous[String(id)] = int(d)
	if _refuse.is_valid():
		var c := _refuse
		_refuse = Callable()
		c.call()

static func exporter() -> Dictionary:
	return {"verrous": _verrous.duplicate()}

static func importer(d: Dictionary) -> void:
	var r := R()
	if r != null and r.est_hote():
		return
	_verrous = {}
	for k in d.get("verrous", {}):
		_verrous[String(k)] = int(d["verrous"][k])
