class_name ReseauTransportENet
extends ReseauTransport
## Transport ENet (UDP) : tests locaux et parties en LAN / IP directe. Au plus 4 joueurs (hôte + 3 invités).

const MAX_JOUEURS := 4

func creer_hote(port: int) -> MultiplayerPeer:
	var pair := ENetMultiplayerPeer.new()
	erreur = pair.create_server(port, MAX_JOUEURS + 3)   # places de poignée en plus : « partie pleine » est refusée avec un message (Reseau._sur_poignee)
	return pair if erreur == OK else null

func creer_client(ip: String, port: int) -> MultiplayerPeer:
	var pair := ENetMultiplayerPeer.new()
	erreur = pair.create_client(ip, port)
	return pair if erreur == OK else null

func nom() -> String:
	return "ENet"
