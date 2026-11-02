class_name OngletMenu
extends Control
## Base des onglets du menu personnage (docs/RPG.md §8 ; conception §2.10). LOT 0 : base vide et contrat.
## La coquille (MenuPersonnage, lot C) gère : Tab / Échap / B, onglets (LB / RB, Q / E physiques), pause, souris, bandeau
## d'aide. Chaque onglet = un fichier qui hérite de cette classe (lot C : equipement, sac, magie ; lot D : competences,
## personnage, quetes) et ne contient AUCUNE règle de jeu (il appelle Inventaire / EquipementCorps / EquipementMains /
## Progression / Stockage). Rendu : écran logique 480x270, MenuStyle (police 16, Jacquard pour les titres).

## Demande à la coquille d'afficher un message (refus, confirmation) dans son bandeau.
signal message(texte: String)
## Le contenu de l'onglet a changé (ex. compteur à mettre à jour dans l'en-tête de la coquille).
signal contenu_change

var joueur: Node = null   ## joueur courant (CharacterBody3D, scripts/joueur.gd), posé par la coquille avant ouvrir()

## Identifiant stable (« equipement », « sac », « magie », « competences », « personnage », « quetes »).
func id_onglet() -> String:
	return ""

## Titre affiché sur l'onglet.
func titre() -> String:
	return ""

## L'onglet devient visible (le jeu est déjà en pause) : relire l'état, donner le focus.
func ouvrir() -> void:
	pass

## L'onglet est quitté (changement d'onglet ou fermeture du menu).
func fermer() -> void:
	pass

## Événement d'entrée transmis par la coquille : true s'il est consommé (sinon la coquille le traite : onglets, fermeture).
func entree(_e: InputEvent) -> bool:
	return false

## Bandeau d'aide : [[touche, action], …] ex. [["Clic gauche / A", "Équiper"], ["L / Y", "Lâcher"]].
func aide() -> Array:
	return []
