class_name EntreesCombat
extends RefCounted
## Entrées de combat, séparées de la logique : appui / relâchement d'attaque horodatés, mémoire d'entrée (input buffer)
## et garde. Alimenté par la souris (mains.gd), par les tests (attaquer()) et plus tard par une manette.

## Durée de validité d'un appui mémorisé pendant un coup (s) : un clic un peu tôt n'est pas perdu.
const TAMPON := 0.35

var horloge := 0.0
## Bouton d'attaque tenu, et depuis quand (horloge).
var attaque_tenue := false
var appui_debut := -1.0
## Appui mémorisé (horloge de l'appui), -1 = aucun ; relâché depuis (pour savoir si c'était un clic court).
var tampon := -1.0
var tampon_relache := false
var garde_tenue := false
var _garde_forcee_fin := -1.0

func avancer(dt: float) -> void:
	horloge += dt
	if tampon >= 0.0 and horloge - tampon > TAMPON:
		tampon = -1.0

func appuyer() -> void:
	attaque_tenue = true
	appui_debut = horloge
	tampon = horloge
	tampon_relache = false

func relacher() -> void:
	attaque_tenue = false
	if tampon >= 0.0:
		tampon_relache = true

## Durée d'appui du bouton d'attaque (0 s'il n'est pas tenu).
func duree_appui() -> float:
	return horloge - appui_debut if attaque_tenue else 0.0

## Consomme l'appui mémorisé : vrai s'il y en avait un.
func consommer() -> bool:
	if tampon < 0.0:
		return false
	tampon = -1.0
	return true

## Garde imposée pendant `duree` secondes (tests, cinématiques), même sans bouton.
func forcer_garde(duree: float) -> void:
	_garde_forcee_fin = horloge + duree

func veut_garde() -> bool:
	return garde_tenue or horloge < _garde_forcee_fin
