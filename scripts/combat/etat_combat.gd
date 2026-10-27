class_name EtatCombat
extends RefCounted
## Machine à états du combat du joueur (indépendante du rendu) : un seul état à la fois, transitions autorisées
## listées dans TRANSITIONS (pas de transition illogique, pas d'attaque infinie : une attaque passe toujours par
## RECUPERATION). Les noms anglais (débogage, docs/COMBAT.md) suivent la liste de la spécification.

signal change(ancien: int, nouveau: int)

enum { REPOS, MOUVEMENT, ATTAQUE_LEGERE, CHARGE_LOURDE, ATTAQUE_LOURDE, GARDE, PARADE, DESEQUILIBRE, RECUPERATION, EQUIPER, CONTRE, FINISHER }

const NOMS := ["Idle", "Moving", "LightAttack", "HeavyCharge", "HeavyAttack", "Blocking", "Parrying", "Staggered", "Recovery", "Equip", "Counter", "Finisher"]

## Depuis chaque état, les états accessibles. DESEQUILIBRE (rebond sur un mur ou un bouclier, coup encaissé) est
## accessible de partout ; EQUIPER seulement au calme.
const TRANSITIONS := {
	REPOS: [MOUVEMENT, ATTAQUE_LEGERE, PARADE, GARDE, DESEQUILIBRE, EQUIPER],
	MOUVEMENT: [REPOS, ATTAQUE_LEGERE, PARADE, GARDE, DESEQUILIBRE, EQUIPER],
	# PARADE : annulation explicite pendant la préparation (avant la phase active, mains._avancer_geste)
	ATTAQUE_LEGERE: [CHARGE_LOURDE, RECUPERATION, DESEQUILIBRE, PARADE],
	CHARGE_LOURDE: [ATTAQUE_LOURDE, DESEQUILIBRE, REPOS],
	ATTAQUE_LOURDE: [RECUPERATION, DESEQUILIBRE],
	PARADE: [GARDE, REPOS, MOUVEMENT, DESEQUILIBRE],
	GARDE: [PARADE, REPOS, MOUVEMENT, DESEQUILIBRE],
	DESEQUILIBRE: [REPOS, MOUVEMENT, GARDE, PARADE],
	RECUPERATION: [REPOS, MOUVEMENT, ATTAQUE_LEGERE, PARADE, DESEQUILIBRE],
	EQUIPER: [REPOS, MOUVEMENT],
}

## Phase 3 (défense) : contre-attaque (après une parade parfaite) et finisher, ajoutés sans retoucher la table de base.
const TRANSITIONS_PHASE3 := {
	REPOS: [CONTRE, FINISHER],
	MOUVEMENT: [CONTRE, FINISHER],
	GARDE: [CONTRE, FINISHER],
	PARADE: [CONTRE, FINISHER],
	RECUPERATION: [CONTRE, FINISHER],
	ATTAQUE_LEGERE: [FINISHER],
	CONTRE: [RECUPERATION, DESEQUILIBRE],
	FINISHER: [RECUPERATION],
}

var etat := REPOS
## Temps passé dans l'état courant (s).
var t := 0.0
## Transitions refusées (débogage, tests).
var refus := 0

func changer(nouvel: int) -> bool:
	if nouvel == etat:
		return true
	if not (nouvel in TRANSITIONS.get(etat, []) or nouvel in TRANSITIONS_PHASE3.get(etat, [])):
		refus += 1
		return false
	var ancien := etat
	etat = nouvel
	t = 0.0
	change.emit(ancien, nouvel)
	return true

## Changement imposé de l'extérieur (tests, scripts de scène) : ne passe pas par la table.
func forcer(nouvel: int) -> void:
	var ancien := etat
	etat = nouvel
	t = 0.0
	if ancien != nouvel:
		change.emit(ancien, nouvel)

func avancer(dt: float) -> void:
	t += dt

func nom() -> String:
	return NOMS[etat]

func attaque() -> bool:
	return etat in [ATTAQUE_LEGERE, CHARGE_LOURDE, ATTAQUE_LOURDE, CONTRE, FINISHER]

func defense() -> bool:
	return etat in [GARDE, PARADE]

func calme() -> bool:
	return etat in [REPOS, MOUVEMENT]
