class_name Incantation
extends RefCounted
## État d'UNE main qui tient un sort (logique pure, sans rendu) : REPOS → INCANTE (incantation) → CHARGE (maintien) ou
## CANALISE (maintien) ou départ immédiat → RECUPERATION → REPOS. La double incantation lie les deux mains : la main
## « meneuse » lance la version double, la « suiveuse » l'accompagne (pose, aura) sans rien lancer elle-même.

enum { REPOS, INCANTE, CHARGE, CANALISE, RECUPERATION }
const NOMS := ["repos", "incante", "charge", "canalise", "recuperation"]

var main := "gauche"
var etat := REPOS
var t := 0.0
var sort: DonneesSort
## Bouton tenu.
var tenu := false
## Charge 0..1 (CHARGE, ZONE chargée).
var charge := 0.0
var double := false
var meneuse := true
## Durée de la récupération en cours (sort.recuperation, ou plus longue après une interruption).
var duree_recup := 0.25
## Appui mémorisé (horloge MainSort) pendant une récupération ou un coup d'épée ; -1 = aucun.
var tampon := -1.0
## Dernier départ (pose « lance » brève) : s depuis le lancement.
var depuis_lancement := 9.0
var interrompue := false

func nom() -> String:
	return NOMS[etat]

func active() -> bool:
	return etat in [INCANTE, CHARGE, CANALISE]

func libre() -> bool:
	return etat == REPOS

func changer(e: int) -> void:
	etat = e
	t = 0.0
	if e == REPOS:
		charge = 0.0
		double = false
		meneuse = true
		interrompue = false
