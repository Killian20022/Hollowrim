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

# ---------- Extensions lot 6 (salon sans IP). Valeurs par défaut = comportement ENet inchangé. ----------

## Message lisible de la dernière indisponibilité / erreur (vide si tout va bien).
var message := ""

## Le transport est-il utilisable ici (plugin présent, réglages complets) ? ENet : toujours.
func disponible() -> bool:
	return true

## Le transport sait-il faire un salon à code court (sans IP) ?
func salon_supporte() -> bool:
	return false

## Étape asynchrone avant heberger()/rejoindre() (initialisation, connexion au service). true = prêt.
func preparer_async() -> bool:
	return true

## Hôte : crée un salon et renvoie son code court (6 caractères), "" en cas d'échec (voir `message`).
## À appeler AVANT Reseau.heberger(). Sans salon : renvoie "".
func ouvrir_salon_async() -> String:
	message = "Ce transport n'a pas de salon : utiliser l'adresse IP."
	return ""

## Invité : trouve le salon `code`. true = trouvé ; ensuite Reseau.rejoindre("") se connecte à son hôte.
func rejoindre_salon_async(_code: String) -> bool:
	message = "Ce transport n'a pas de salon : utiliser l'adresse IP."
	return false

## Ferme le salon (hôte ou invité). Sans effet s'il n'y en a pas.
func fermer_salon_async() -> void:
	pass
