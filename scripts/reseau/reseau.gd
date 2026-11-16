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

var transport: ReseauTransport = ReseauTransportENet.new()   # interchangeable (EOS / Steam plus tard)
var registre := RegistreJoueurs.new()

var _en_ligne := false
var _hote := true
var _abonnes := {}   # type -> Array[Callable]

func _ready() -> void:
	registre.ajouter(ID_HOTE)   # solo : l'hôte local est déjà là
	multiplayer.peer_connected.connect(_pair_connecte)
	multiplayer.peer_disconnected.connect(_pair_deconnecte)
	multiplayer.connected_to_server.connect(_connecte_au_serveur)
	multiplayer.connection_failed.connect(_connexion_ratee)
	multiplayer.server_disconnected.connect(_serveur_perdu)

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
	_remettre_registre()
	return OK

## Coupe la connexion et revient en solo (hôte local, joueurs() = [1]).
func deconnecter() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_en_ligne = false
	_hote = true
	_remettre_registre()

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
func envoyer_evenement(type: String, id: Variant = 0, donnees: Dictionary = {}, vers: int = 0) -> void:
	if not _en_ligne:
		return
	if vers == 0:
		if _hote:
			evenement.rpc(type, id, donnees)
		else:
			evenement.rpc_id(ID_HOTE, type, id, donnees)
	else:
		evenement.rpc_id(vers, type, id, donnees)

## RPC générique (ne pas appeler directement : passer par envoyer_evenement). Distribue aux abonnés du type.
@rpc("any_peer", "call_remote", "reliable")
func evenement(type: String, id: Variant, donnees: Dictionary) -> void:
	_distribuer(type, multiplayer.get_remote_sender_id(), id, donnees)

## Distribue localement un évènement (aussi utilisable en solo pour passer par le même chemin de code).
func _distribuer(type: String, expediteur: int, id: Variant, donnees: Dictionary) -> void:
	if not _abonnes.has(type):
		return
	for c: Callable in (_abonnes[type] as Array).duplicate():
		if c.is_valid():
			c.call(expediteur, id, donnees)

func emettre_local(type: String, id: Variant = 0, donnees: Dictionary = {}) -> void:
	_distribuer(type, mon_id(), id, donnees)

# ---------- Interne ----------

func _remettre_registre() -> void:
	registre.vider()
	registre.ajouter(ID_HOTE)   # l'id d'un invité est ajouté à sa connexion réussie

func _pair_connecte(id: int) -> void:
	registre.ajouter(id)
	joueur_connecte.emit(id)

func _pair_deconnecte(id: int) -> void:
	registre.retirer(id)
	joueur_deconnecte.emit(id)

func _connecte_au_serveur() -> void:
	registre.ajouter(multiplayer.get_unique_id())
	connexion_reussie.emit()

func _connexion_ratee() -> void:
	deconnecter()
	connexion_echouee.emit()

func _serveur_perdu() -> void:
	var anciens := registre.ids()
	deconnecter()
	for id in anciens:
		if id != ID_HOTE:
			joueur_deconnecte.emit(id)
	joueur_deconnecte.emit(ID_HOTE)
