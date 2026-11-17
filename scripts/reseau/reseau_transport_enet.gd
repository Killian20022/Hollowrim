class_name ReseauTransportENet
extends ReseauTransport
## Transport ENet (UDP) : tests locaux et parties en LAN / IP directe. Au plus 4 joueurs (hôte + 3 invités).

const MAX_JOUEURS := 4

func creer_hote(port: int) -> MultiplayerPeer:
	var pair := ENetMultiplayerPeer.new()
	erreur = pair.create_server(port, MAX_JOUEURS - 1)
	return Resilience.preparer(pair, true, "", port) if erreur == OK else null   # lot 7 : enveloppe (simulateur + mesures)

func creer_client(ip: String, port: int) -> MultiplayerPeer:
	var pair := ENetMultiplayerPeer.new()
	erreur = pair.create_client(ip, port)
	return Resilience.preparer(pair, false, ip, port) if erreur == OK else null   # lot 7

func nom() -> String:
	return "ENet"
