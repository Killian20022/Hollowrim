class_name ReseauTransportEOS
extends ReseauTransport
## Transport EOS (Epic Online Services, gratuit) : P2P avec relais Epic (pas d'IP, pas de redirection de port) + salon à code court.
## Plugin visé : « Epic Online Services Godot » (EOSG, MIT) de 3ddelano, qui fournit la classe native EOSGMultiplayerPeer
## (MultiplayerPeerExtension) et les assistants HPlatform / HAuth / HLobbies. Voir docs/reseau_lot6.md.
## ISOLATION : aucun identifiant du plugin n'est écrit en dur ici (ClassDB + chargement dynamique de l'adaptateur) ;
## sans plugin le projet compile, disponible() renvoie false et `message` dit quoi faire. ENet reste le transport par défaut.
## Plugin 2.3.1 installé et vérifié en Godot 4.7.2 (classe et signatures du pair confirmées) ; reste à valider avec un vrai compte Epic.

const MAX_JOUEURS := 4
const CLASSE_PAIR := "EOSGMultiplayerPeer"
const ADAPTATEUR := "res://scripts/reseau/reseau_eos_adaptateur.gd"
const CFG := "user://eos.cfg"                  # JAMAIS commité (user:// est hors du dépôt)
const CFG_EXE := "eos.cfg"                     # variante : fichier posé À CÔTÉ de l'exe (un seul fichier fourni avec le zip)
const CLES_OBLIGATOIRES := ["product_name", "product_version", "product_id", "sandbox_id", "deployment_id", "client_id", "client_secret"]
const SOCKET_DEFAUT := "hollowrim"

var chemin_cfg := chemin_cfg_defaut()
## Nom affiché du joueur dans EOS (écran Multijoueur) ; vide = « nom_joueur » de eos.cfg.
var nom_joueur := ""
## Outil d'essai uniquement (2 instances sur la même machine) : Device ID recréé à chaque connexion (identité différente).
var device_id_jetable := false
var _adaptateur: RefCounted = null
var _code := ""
var _hote_id := ""
var _pret := false
static var _actif: ReseauTransportEOS = null   # transport dont EOS a été initialisé (pour la sortie propre)
const DELAI_CONNEXION := 15.0
const DELAI_SALON := 15.0
const DELAI_REJOINDRE := 20.0   # inclut les réessais de recherche (indexation Epic différée)

## Le plugin (classe native EOSGMultiplayerPeer) est-il chargé ?
static func plugin_present() -> bool:
	return ClassDB.class_exists(CLASSE_PAIR)

## Fichier de réglages à utiliser : `eos.cfg` à côté de l'exe s'il existe, sinon `user://eos.cfg` (%APPDATA%\\Hollowrim).
static func chemin_cfg_defaut() -> String:
	if not OS.has_feature("editor"):
		var a_cote := OS.get_executable_path().get_base_dir().path_join(CFG_EXE)
		if FileAccess.file_exists(a_cote):
			return a_cote
	return CFG

## Explication destinée au joueur quand EOS n'est pas utilisable (affichée dans le menu Multijoueur).
func aide_configuration() -> String:
	if not plugin_present():
		return "Le jeu par Internet n'est pas disponible dans cette version (plugin Epic absent). Utilisez l'adresse IP."
	var r := lire_cfg(chemin_cfg)
	if not r.fichier:
		return "Jeu par Internet non configuré : placez le fichier eos.cfg à côté de Hollowrim.exe (fichier fourni par l'organisateur, voir Hollowrim_EPIC_PAS_A_PAS.txt)."
	if not (r.manquants as Array).is_empty():
		return "eos.cfg incomplet : il manque %s." % ", ".join(r.manquants)
	return message

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
		message = "le plugin EOSG (classe %s) n'est pas installé dans addons/ (voir docs/EOS_PAS_A_PAS.md)." % CLASSE_PAIR
		return false
	var r := lire_cfg(chemin_cfg)
	if not r.fichier:
		message = "fichier de réglages eos.cfg absent (à placer à côté de Hollowrim.exe, ou dans %s ; voir docs/EOS_PAS_A_PAS.md)." % CFG
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
	var valeurs: Dictionary = r.valeurs
	if nom_joueur.strip_edges() != "":
		valeurs["nom_joueur"] = nom_joueur.strip_edges()
	if device_id_jetable:
		valeurs["device_id_jetable"] = "true"
	var err: String = await _avec_delai(func(): return await _adaptateur.call("preparer", valeurs), DELAI_CONNEXION,
		"EOS : connexion trop longue (plus de %d s) : vérifier l'accès Internet puis réessayer." % int(DELAI_CONNEXION))
	if err != "":
		message = err
		erreur = FAILED
		return false
	_pret = true
	_actif = self
	return true

func ouvrir_salon_async() -> String:
	if not await preparer_async():
		return ""
	var code := ReseauSalonCode.generer()
	var err: String = await _avec_delai(func(): return await _adaptateur.call("creer_salon", code, MAX_JOUEURS), DELAI_SALON,
		"EOS : création du salon trop longue (plus de %d s) : réessayer." % int(DELAI_SALON))
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
	var rep: Dictionary = await _avec_delai(func(): return await _adaptateur.call("trouver_salon", c), DELAI_REJOINDRE,
		{"erreur": "EOS : recherche du salon trop longue (plus de %d s) : réessayer." % int(DELAI_REJOINDRE)})
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

## Arrêt propre du SDK EOS avant de quitter le processus (sinon quit() peut rester bloqué). Sans effet si EOS n'a pas démarré.
func arreter_async() -> void:
	if _adaptateur != null and _pret:
		await _adaptateur.call("arreter")
	_pret = false
	_code = ""
	_hote_id = ""

## Sortie rapide du jeu quand EOS a été initialisé : quitte le salon et se déconnecte (1 s au plus) puis sortie forcée
## (le shutdown du SDK plante et le quit() normal reste bloqué). Renvoie true si elle a pris la main (le processus sera tué) ;
## false si EOS n'a pas été initialisé : le comportement de sortie reste alors inchangé. Un seul appel : Jeu.quitter().
static func sortie_propre() -> bool:
	if _actif == null or not _actif._pret:
		return false
	_actif._sortie_async()
	return true

func _sortie_async() -> void:
	var etat := {"fini": false}
	(func():
		await arreter_async()
		etat.fini = true).call()
	var t0 := Time.get_ticks_msec()
	while not etat.fini and Time.get_ticks_msec() - t0 < 1000:
		await Engine.get_main_loop().create_timer(0.05).timeout
	OS.kill(OS.get_process_id())

## Exécute `appel` (coroutine) avec un délai maximal ; renvoie `si_delai` si elle n'a pas fini à temps.
func _avec_delai(appel: Callable, delai: float, si_delai: Variant) -> Variant:
	var etat := {"fini": false, "val": null}
	(func():
		etat.val = await appel.call()
		etat.fini = true).call()
	var t0 := Time.get_ticks_msec()
	while not etat.fini and Time.get_ticks_msec() - t0 < delai * 1000.0:
		await Engine.get_main_loop().create_timer(0.1).timeout
	return etat.val if etat.fini else si_delai

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
