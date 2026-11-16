extends Node
## STUB du lot 1 (multijoueur) : respecte le CONTRAT FIGÉ de l'autoload `Reseau` ; le lot 0 le remplace à la fusion.
## Aucune logique de prototype ici (elle vit dans scripts/reseau/proto_*.gd).
## Contrat : heberger(port) / rejoindre(ip, port) -> Error, deconnecter(), est_hote(), est_en_ligne(), mon_id(),
## joueurs() -> Array[int] (hôte = 1), signaux joueur_connecte / joueur_deconnecte / connexion_reussie / connexion_echouee,
## RPC générique evenement(type, id, donnees) + abonnement par type : abonner(type, callable(expediteur, id, donnees)).

signal joueur_connecte(id: int)
signal joueur_deconnecte(id: int)
signal connexion_reussie
signal connexion_echouee

const PORT_DEFAUT := 24565
const MAX_JOUEURS := 4

var _abonnes := {}   # type -> Array[Callable]

func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void: joueur_connecte.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: joueur_deconnecte.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: connexion_reussie.emit())
	multiplayer.connection_failed.connect(func() -> void: connexion_echouee.emit())

func heberger(port := PORT_DEFAUT) -> Error:
	var p := ENetMultiplayerPeer.new()
	var e := p.create_server(port, MAX_JOUEURS - 1)
	if e == OK:
		multiplayer.multiplayer_peer = p
	return e

func rejoindre(ip: String, port := PORT_DEFAUT) -> Error:
	var p := ENetMultiplayerPeer.new()
	var e := p.create_client(ip, port)
	if e == OK:
		multiplayer.multiplayer_peer = p
	return e

func deconnecter() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

func est_en_ligne() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not (p is OfflineMultiplayerPeer) and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func est_hote() -> bool:
	return not est_en_ligne() or multiplayer.is_server()

func mon_id() -> int:
	return multiplayer.get_unique_id() if est_en_ligne() else 1

func joueurs() -> Array[int]:
	var r: Array[int] = [mon_id()]
	if est_en_ligne():
		for id in multiplayer.get_peers():
			r.append(id)
	r.sort()
	return r

## S'abonne aux événements d'un type : c(expediteur: int, id: Variant, donnees: Variant).
func abonner(type: String, c: Callable) -> void:
	if not _abonnes.has(type):
		_abonnes[type] = []
	_abonnes[type].append(c)

## Envoi pratique : cible 0 = tout le monde (soi compris), sinon un pair précis.
func emettre(type: String, id: Variant, donnees: Variant, cible := 0) -> void:
	if not est_en_ligne():
		_distribuer(type, 1, id, donnees)
	elif cible == 0:
		evenement.rpc(type, id, donnees)
	else:
		evenement.rpc_id(cible, type, id, donnees)

@rpc("any_peer", "call_local", "reliable")
func evenement(type: String, id: Variant, donnees: Variant) -> void:
	var exped := multiplayer.get_remote_sender_id()
	_distribuer(type, exped if exped != 0 else mon_id(), id, donnees)

func _distribuer(type: String, expediteur: int, id: Variant, donnees: Variant) -> void:
	for c: Callable in _abonnes.get(type, []):
		if c.is_valid():
			c.call(expediteur, id, donnees)
