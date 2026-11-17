extends Node
## Autoload « Reseau » : couche réseau du multijoueur coop (hôte = monde, chaque joueur = son personnage). CONTRAT FIGÉ (lot 0) :
##   heberger(port) / rejoindre(ip, port) / deconnecter() / est_hote() / est_en_ligne() / mon_id() / joueurs()
##   signaux joueur_connecte(id), joueur_deconnecte(id), connexion_reussie, connexion_echouee
## Solo = aucun pair réseau : est_hote() = true, est_en_ligne() = false, mon_id() = 1, joueurs() = [1].
## Évènements génériques : s'abonner avec abonner(type, callable(expediteur, id, donnees)), émettre avec envoyer_evenement(...).
## Voir docs/reseau_lot0.md.

signal joueur_connecte(id: int)
signal joueur_deconnecte(id: int)
signal connexion_reussie
signal connexion_echouee

const PORT_DEFAUT := 24565
const ID_HOTE := 1
## Numéro de protocole échangé dans la poignée de main (lot 5b) : à incrémenter dès que le format des évènements change.
## Une version différente est refusée avec un message lisible. 4 joueurs au plus (hôte compris).
const VERSION_PROTOCOLE := 1
const MAX_JOUEURS := 4
const DELAI_POIGNEE := 6.0   # secondes : un pair qui ne se présente pas est coupé

var transport: ReseauTransport = ReseauTransportENet.new()   # interchangeable ; choisi au démarrage dans _ready (--transport=enet|eos)
var registre := RegistreJoueurs.new()

## Version envoyée à l'hôte (modifiable par les tests pour simuler un jeu d'une autre version).
var version_locale := VERSION_PROTOCOLE
## Nom du joueur local (écran Multijoueur) ; envoyé dans la poignée de main, affiché dans la liste des joueurs.
var nom_joueur := "Joueur"
## Dernière erreur de connexion, en français (vide si tout va bien) : lue par l'écran Multijoueur après connexion_echouee.
var derniere_erreur := ""
## Hôte : informations sur la partie, envoyées à chaque invité qui se présente (ex. {"lancee": bool, "monde": String}).
var infos_partie := {}
## Invité : informations reçues de l'hôte à la poignée de main.
var infos_hote := {}

var _en_ligne := false
var _hote := true
var _abonnes := {}   # type -> Array[Callable]
var _en_attente := {}   # hôte : pairs connectés qui n'ont pas encore fini la poignée de main (id -> true)
var _poignee_en_cours := false   # invité : poignée envoyée, réponse attendue

func _ready() -> void:
	transport = ReseauTransportChoix.depuis_arguments()   # ENet par défaut ; EOS seulement si demandé ET disponible
	registre.ajouter(ID_HOTE)   # solo : l'hôte local est déjà là
	multiplayer.peer_connected.connect(_pair_connecte)
	multiplayer.peer_disconnected.connect(_pair_deconnecte)
	multiplayer.connected_to_server.connect(_connecte_au_serveur)
	multiplayer.connection_failed.connect(_connexion_ratee)
	multiplayer.server_disconnected.connect(_serveur_perdu)
	abonner("poignee", _sur_poignee)
	abonner("poignee_ok", _sur_poignee_ok)
	abonner("poignee_refus", _sur_poignee_refus)
	abonner("poignee_arrivee", _sur_arrivee)

# ---------- API publique ----------

func heberger(port: int = PORT_DEFAUT) -> Error:
	if _en_ligne:
		return ERR_ALREADY_IN_USE
	var pair := transport.creer_hote(port)
	if pair == null:
		return transport.erreur if transport.erreur != OK else FAILED
	multiplayer.multiplayer_peer = pair
	_en_ligne = true
	_hote = true
	derniere_erreur = ""
	_remettre_registre()
	return OK

func rejoindre(ip: String, port: int = PORT_DEFAUT) -> Error:
	if _en_ligne:
		return ERR_ALREADY_IN_USE
	var pair := transport.creer_client(ip, port)
	if pair == null:
		return transport.erreur if transport.erreur != OK else FAILED
	multiplayer.multiplayer_peer = pair
	_en_ligne = true
	_hote = false
	derniere_erreur = ""
	_remettre_registre()
	return OK

## Coupe la connexion et revient en solo (hôte local, joueurs() = [1]).
func deconnecter() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_en_ligne = false
	_hote = true
	_en_attente.clear()
	_poignee_en_cours = false
	infos_hote = {}
	_remettre_registre()

func max_joueurs() -> int:
	return MAX_JOUEURS

func est_hote() -> bool:
	return _hote

func est_en_ligne() -> bool:
	return _en_ligne

func mon_id() -> int:
	return multiplayer.get_unique_id() if _en_ligne else ID_HOTE

## Identifiants réseau des joueurs présents (triés, hôte = 1 en premier).
func joueurs() -> Array[int]:
	return registre.ids()

# ---------- Évènements génériques ----------

## S'abonne aux évènements `type` : `rappel.call(expediteur: int, id: Variant, donnees: Dictionary)`.
func abonner(type: String, rappel: Callable) -> void:
	if not _abonnes.has(type):
		_abonnes[type] = []
	if not (_abonnes[type] as Array).has(rappel):
		(_abonnes[type] as Array).append(rappel)

func desabonner(type: String, rappel: Callable) -> void:
	if _abonnes.has(type):
		(_abonnes[type] as Array).erase(rappel)

## Envoie un évènement. `vers` : 0 = tout le monde sauf moi (invité : à l'hôte seulement), sinon un pair précis.
## Fiable et ordonné. Hors ligne : sans effet (l'appelant local gère son propre effet).
func envoyer_evenement(type: String, id: Variant = 0, donnees: Variant = null, vers: int = 0) -> void:
	if not _en_ligne:
		return
	if vers == 0:
		if _hote:
			evenement.rpc(type, id, donnees)
		else:
			evenement.rpc_id(ID_HOTE, type, id, donnees)
	else:
		evenement.rpc_id(vers, type, id, donnees)

## Alias (prototype lot 1).
func emettre(type: String, id: Variant = 0, donnees: Variant = null, vers: int = 0) -> void:
	envoyer_evenement(type, id, donnees, vers)

## RPC générique (ne pas appeler directement : passer par envoyer_evenement). Distribue aux abonnés du type.
@rpc("any_peer", "call_remote", "reliable")
func evenement(type: String, id: Variant, donnees: Variant) -> void:
	var exp := multiplayer.get_remote_sender_id()
	if _hote and _en_ligne and not registre.a(exp) and type != "poignee":
		return   # pair pas encore présenté (poignée de main) : rien d'autre n'est écouté
	_distribuer(type, exp, id, donnees)

## Distribue localement un évènement (aussi utilisable en solo pour passer par le même chemin de code).
func _distribuer(type: String, expediteur: int, id: Variant, donnees: Variant) -> void:
	if not _abonnes.has(type):
		return
	for c: Callable in (_abonnes[type] as Array).duplicate():
		if c.is_valid():
			c.call(expediteur, id, donnees)

func emettre_local(type: String, id: Variant = 0, donnees: Variant = null) -> void:
	_distribuer(type, mon_id(), id, donnees)

# ---------- Interne ----------

func _remettre_registre() -> void:
	registre.vider()
	registre.ajouter(ID_HOTE, {"nom": _nom_valide(nom_joueur)} if _hote else {})   # l'id d'un invité est ajouté à la poignée de main

## Chargement du monde = quelques secondes sans lire le réseau : on allonge le délai avant que ENet ne tienne un pair pour perdu
## (limite de relances 32, minimum 15 s, maximum 90 s ; par défaut 5 s / 30 s).
func _tolerer(id: int) -> void:
	var pair := multiplayer.multiplayer_peer
	if pair is ENetMultiplayerPeer:
		var p := (pair as ENetMultiplayerPeer).get_peer(id)
		if p != null:
			p.set_timeout(32, 15000, 90000)

func _pair_connecte(id: int) -> void:
	_tolerer(id)
	if _hote:
		# l'invité n'existe pour le jeu qu'une fois la poignée de main acceptée (version, place libre)
		_en_attente[id] = true
		get_tree().create_timer(DELAI_POIGNEE).timeout.connect(func() -> void:
			if _en_attente.has(id) and _en_ligne:
				_en_attente.erase(id)
				_couper(id))
		return
	# invité : l'hôte (id 1) est présenté par la poignée de main ; les autres invités arrivent par « poignee_arrivee »
	pass

func _pair_deconnecte(id: int) -> void:
	_en_attente.erase(id)
	if not registre.a(id):
		return
	registre.retirer(id)
	joueur_deconnecte.emit(id)

func _connecte_au_serveur() -> void:
	_tolerer(ID_HOTE)
	_poignee_en_cours = true
	envoyer_evenement("poignee", version_locale, {"nom": nom_joueur, "version": version_locale}, ID_HOTE)
	get_tree().create_timer(DELAI_POIGNEE + 2.0).timeout.connect(func() -> void:
		if _poignee_en_cours and _en_ligne and not _hote:
			_echec("L'hôte ne répond pas à la poignée de main : son jeu est sans doute d'une autre version.")
	)

func _connexion_ratee() -> void:
	_echec("Impossible de joindre l'hôte : vérifier l'adresse, le port et le pare-feu.")

func _serveur_perdu() -> void:
	var anciens := registre.ids()
	deconnecter()
	derniere_erreur = "Connexion à l'hôte perdue."
	for id in anciens:
		if id != ID_HOTE:
			joueur_deconnecte.emit(id)
	joueur_deconnecte.emit(ID_HOTE)

## Échec de connexion côté invité : retour hors ligne, message lisible, signal.
func _echec(message: String) -> void:
	_poignee_en_cours = false
	deconnecter()
	derniere_erreur = message
	connexion_echouee.emit()

## Coupe un pair (hôte) : laisse partir le dernier message avant de fermer.
func _couper(id: int) -> void:
	if not _en_ligne:
		return
	var pair := multiplayer.multiplayer_peer
	if pair is ENetMultiplayerPeer and (pair as ENetMultiplayerPeer).get_peer(id) == null:
		return   # déjà parti
	if pair != null and not (pair is OfflineMultiplayerPeer):
		pair.disconnect_peer(id)

# ---------- Poignée de main (lot 5b) ----------

## Décision d'accueil de l'hôte (testable seule) : {"ok": bool, "raison": String, "nom": String (nom unique retenu)}.
func decision_poignee(version: int, nom_demande: String) -> Dictionary:
	if version != VERSION_PROTOCOLE:
		return {"ok": false, "nom": "", "raison": "Version différente : l'hôte joue en version %d du protocole, vous en version %d. Mettre le jeu à jour." % [VERSION_PROTOCOLE, version]}
	if registre.taille() >= MAX_JOUEURS:
		return {"ok": false, "nom": "", "raison": "La partie est pleine (%d joueurs au plus)." % MAX_JOUEURS}
	# nom unique dans la partie (il sert aussi de nom de fichier du personnage)
	var nom := _nom_valide(nom_demande)
	var base := nom
	var n := 2
	while _nom_pris(nom):
		nom = "%s (%d)" % [base, n]
		n += 1
	return {"ok": true, "nom": nom, "raison": ""}

func _sur_poignee(expediteur: int, version: Variant, d: Variant) -> void:
	if not _hote or not _en_attente.has(expediteur):
		return
	_en_attente.erase(expediteur)
	var dec := decision_poignee(int(version), String((d as Dictionary).get("nom", "")) if d is Dictionary else "")
	if not dec["ok"]:
		_refuser(expediteur, dec["raison"])
		return
	var nom: String = dec["nom"]
	var presents := []
	for i in registre.ids():
		presents.append({"id": i, "nom": String(registre.infos(i).get("nom", "Joueur"))})
	registre.ajouter(expediteur, {"nom": nom})
	envoyer_evenement("poignee_ok", expediteur, {"version": VERSION_PROTOCOLE, "nom": nom, "presents": presents, "infos": infos_partie.duplicate(true)}, expediteur)
	for i in registre.ids():   # les autres invités apprennent l'arrivée
		if i != ID_HOTE and i != expediteur:
			envoyer_evenement("poignee_arrivee", expediteur, {"nom": nom}, i)
	joueur_connecte.emit(expediteur)

func _refuser(id: int, raison: String) -> void:
	envoyer_evenement("poignee_refus", id, {"raison": raison}, id)
	get_tree().create_timer(0.5).timeout.connect(func() -> void: _couper(id))

func _nom_pris(nom: String) -> bool:
	for i in registre.ids():
		if String(registre.infos(i).get("nom", "")) == nom:
			return true
	return false

## Nom affichable : espaces rognés, 20 caractères au plus, jamais vide.
static func _nom_valide(nom: String) -> String:
	var r := nom.strip_edges().replace("\n", " ").replace("\t", " ").left(20).strip_edges()
	return r if r != "" else "Joueur"

func _sur_poignee_ok(expediteur: int, _id: Variant, d: Variant) -> void:
	if _hote or expediteur != ID_HOTE or not _poignee_en_cours or not d is Dictionary:
		return
	_poignee_en_cours = false
	var dd := d as Dictionary
	registre.ajouter(ID_HOTE, {"nom": "Hôte"})
	for p in dd.get("presents", []):
		if p is Dictionary:
			registre.ajouter(int(p["id"]), {"nom": String(p.get("nom", "Joueur"))})
	registre.ajouter(multiplayer.get_unique_id(), {"nom": String(dd.get("nom", nom_joueur))})
	infos_hote = dd.get("infos", {}) if dd.get("infos", {}) is Dictionary else {}
	joueur_connecte.emit(ID_HOTE)
	for p in dd.get("presents", []):
		if p is Dictionary and int(p["id"]) != ID_HOTE:
			joueur_connecte.emit(int(p["id"]))
	connexion_reussie.emit()

func _sur_poignee_refus(expediteur: int, _id: Variant, d: Variant) -> void:
	if _hote or expediteur != ID_HOTE or not _poignee_en_cours:
		return
	_echec(String((d as Dictionary).get("raison", "Connexion refusée par l'hôte.")) if d is Dictionary else "Connexion refusée par l'hôte.")

func _sur_arrivee(expediteur: int, id: Variant, d: Variant) -> void:
	if _hote or expediteur != ID_HOTE or registre.a(int(id)):
		return
	registre.ajouter(int(id), {"nom": String((d as Dictionary).get("nom", "Joueur")) if d is Dictionary else "Joueur"})
	joueur_connecte.emit(int(id))
