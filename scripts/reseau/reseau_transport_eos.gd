class_name ReseauTransportEOS
extends ReseauTransport
## Transport EOS (Epic Online Services, gratuit) : P2P avec relais Epic (pas d'IP, pas de redirection de port) + salon à code court.
## Plugin visé : « Epic Online Services Godot » (EOSG, MIT) de 3ddelano, qui fournit la classe native EOSGMultiplayerPeer
## (MultiplayerPeerExtension) et les assistants HPlatform / HAuth / HLobbies. Voir docs/reseau_lot6.md.
## ISOLATION : aucun identifiant du plugin n'est écrit en dur ici (ClassDB + chargement dynamique de l'adaptateur) ;
## sans plugin le projet compile, disponible() renvoie false et `message` dit quoi faire. ENet reste le transport par défaut.
## ÉCRIT CONTRE LA DOC/LE CODE SOURCE DU PLUGIN, NON TESTÉ AVEC LE PLUGIN INSTALLÉ (pas de compte Epic côté développement).

const MAX_JOUEURS := 4
const CLASSE_PAIR := "EOSGMultiplayerPeer"
const ADAPTATEUR := "res://scripts/reseau/reseau_eos_adaptateur.gd"
const CFG := "user://eos.cfg"                  # JAMAIS commité (user:// est hors du dépôt)
const CLES_OBLIGATOIRES := ["product_name", "product_version", "product_id", "sandbox_id", "deployment_id", "client_id", "client_secret"]
const SOCKET_DEFAUT := "hollowrim"

var chemin_cfg := CFG
var _adaptateur: RefCounted = null
var _code := ""
var _hote_id := ""
var _pret := false

## Le plugin (classe native EOSGMultiplayerPeer) est-il chargé ?
static func plugin_present() -> bool:
	return ClassDB.class_exists(CLASSE_PAIR)

## Lit le fichier de réglages. Renvoie {valeurs: Dictionary, manquants: Array[String], fichier: bool}.
static func lire_cfg(chemin: String = CFG) -> Dictionary:
	var valeurs := {}
	var fichier := false
	var c := ConfigFile.new()
	if c.load(chemin) == OK:
		fichier = true
		for cle in c.get_section_keys("eos"):
			valeurs[cle] = str(c.get_value("eos", cle, ""))
	var manquants: Array[String] = []
	for cle in CLES_OBLIGATOIRES:
		if str(valeurs.get(cle, "")).strip_edges() == "":
			manquants.append(cle)
	return {"valeurs": valeurs, "manquants": manquants, "fichier": fichier}

func nom() -> String:
	return "EOS"

func salon_supporte() -> bool:
	return true

func disponible() -> bool:
	message = ""
	if not plugin_present():
		message = "le plugin EOSG (classe %s) n'est pas installé dans addons/ (voir docs/reseau_lot6.md, étape 6)." % CLASSE_PAIR
		return false
	var r := lire_cfg(chemin_cfg)
	if not r.fichier:
		message = "fichier de réglages %s absent (voir docs/reseau_lot6.md, étape 5)." % chemin_cfg
		return false
	if not (r.manquants as Array).is_empty():
		message = "réglages EOS manquants dans %s : %s." % [chemin_cfg, ", ".join(r.manquants)]
		return false
	if not ResourceLoader.exists(ADAPTATEUR):
		message = "adaptateur %s introuvable." % ADAPTATEUR
		return false
	return true

func code_salon() -> String:
	return _code

func nom_socket() -> String:
	# 1 à 32 caractères alphanumériques (règle du plugin)
	return ("hr" + _code) if _code != "" else SOCKET_DEFAUT

# ---------- Interface ReseauTransport ----------

## Hôte (id 1). `port` est ignoré (EOS n'a pas de port). Appeler ouvrir_salon_async() avant, sinon socket par défaut.
func creer_hote(_port: int) -> MultiplayerPeer:
	var pair := _nouveau_pair()
	if pair == null:
		return null
	erreur = pair.call("create_server", nom_socket())
	if erreur != OK:
		message = _expliquer(erreur)
		return null
	if pair.has_signal("incoming_connection_request"):
		pair.call("set_auto_accept_connection_requests", false)
		pair.connect("incoming_connection_request", _sur_demande.bind(pair))
	return pair

## Invité. `ip` = identifiant EOS (ProductUserId) de l'hôte ; vide = hôte trouvé par rejoindre_salon_async().
func creer_client(ip: String, _port: int) -> MultiplayerPeer:
	var cible := ip.strip_edges() if ip.strip_edges() != "" else _hote_id
	if cible == "":
		erreur = ERR_INVALID_PARAMETER
		message = "aucun hôte : passer par un salon (rejoindre_salon_async) ou fournir l'identifiant EOS de l'hôte."
		return null
	var pair := _nouveau_pair()
	if pair == null:
		return null
	erreur = pair.call("create_client", nom_socket(), cible)
	if erreur != OK:
		message = _expliquer(erreur)
		return null
	return pair

# ---------- Salon ----------

func preparer_async() -> bool:
	if _pret:
		return true
	if not disponible():
		erreur = ERR_UNAVAILABLE
		return false
	if _adaptateur == null:
		_adaptateur = (load(ADAPTATEUR) as GDScript).new()
	var r := lire_cfg(chemin_cfg)
	var err: String = await _adaptateur.call("preparer", r.valeurs)
	if err != "":
		message = err
		erreur = FAILED
		return false
	_pret = true
	return true

func ouvrir_salon_async() -> String:
	if not await preparer_async():
		return ""
	var code := ReseauSalonCode.generer()
	var err: String = await _adaptateur.call("creer_salon", code, MAX_JOUEURS)
	if err != "":
		message = err
		erreur = FAILED
		return ""
	_code = code
	return code

func rejoindre_salon_async(code: String) -> bool:
	var c := ReseauSalonCode.normaliser(code)
	if c == "":
		message = "code de salon invalide (6 caractères, lettres sans I/L/O et chiffres 2-9)."
		erreur = ERR_INVALID_PARAMETER
		return false
	if not await preparer_async():
		return false
	var rep: Dictionary = await _adaptateur.call("trouver_salon", c)
	if str(rep.get("erreur", "")) != "":
		message = rep.erreur
		erreur = ERR_DOES_NOT_EXIST
		return false
	_code = c
	_hote_id = str(rep.hote)
	return true

func fermer_salon_async() -> void:
	if _adaptateur != null:
		await _adaptateur.call("quitter_salon")
	_code = ""
	_hote_id = ""

# ---------- Interne ----------

func _nouveau_pair() -> MultiplayerPeer:
	if not plugin_present():
		erreur = ERR_UNAVAILABLE
		message = "plugin EOSG absent : transport EOS indisponible, utiliser ENet."
		return null
	var p = ClassDB.instantiate(CLASSE_PAIR)
	if p == null or not (p is MultiplayerPeer):
		erreur = ERR_CANT_CREATE
		message = "impossible de créer %s." % CLASSE_PAIR
		return null
	return p

func _expliquer(err: Error) -> String:
	if err == ERR_UNCONFIGURED:
		return "EOS : utilisateur local non connecté (appeler preparer_async() / ouvrir_salon_async() avant d'héberger ou de rejoindre)."
	return "EOS : échec de création du pair (%s)." % error_string(err)

## Limite de 4 joueurs côté hôte : on accepte tant qu'il reste de la place, sinon on refuse.
func _sur_demande(donnees: Dictionary, pair: Object) -> void:
	var deja := (pair.call("get_all_peers") as Dictionary).size()
	if deja < MAX_JOUEURS - 1:
		pair.call("accept_all_connection_requests")
	else:
		pair.call("deny_all_connection_requests")
