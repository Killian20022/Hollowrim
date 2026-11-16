class_name ReseauTransport
extends RefCounted
## Interface d'un transport réseau (ENet aujourd'hui ; EOS / Steam plus tard). Un transport ne fait que fabriquer
## le MultiplayerPeer ; toute la logique de jeu passe par l'autoload Reseau.

## Crée le pair de l'hôte (id 1). Renvoie null et remplit `erreur` en cas d'échec.
func creer_hote(_port: int) -> MultiplayerPeer:
	push_error("ReseauTransport.creer_hote non implémenté")
	return null

## Crée le pair d'un invité qui se connecte à `ip:port`.
func creer_client(_ip: String, _port: int) -> MultiplayerPeer:
	push_error("ReseauTransport.creer_client non implémenté")
	return null

## Dernière erreur Godot rencontrée par creer_hote / creer_client (OK si tout va bien).
var erreur: Error = OK

## Nom lisible du transport (journaux, interface).
func nom() -> String:
	return "inconnu"
