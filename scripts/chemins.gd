class_name Chemins
extends RefCounted
## Sentiers de la zone témoin (feu → cercle → tumulus). API figée ; lot C : vraies polylignes.
## Implémentation de remplacement : aucun chemin. `_pres_du_chemin` de monde.gd (feu → village) reste à part.

var points := PackedVector2Array()  # axe des chemins (polylignes aplaties)
var monde: Node

func _init(monde_: Node = null) -> void:
	monde = monde_

## Distance de (x, z) à l'axe du chemin le plus proche (m).
func distance(_x: float, _z: float) -> float:
	return INF

## Creux/relief du chemin en (x, z), en mètres (0 = pas de chemin).
func profil(_x: float, _z: float) -> float:
	return 0.0

## Vrai si (x, z) est dans le cône de vue dégagé vers le cercle.
func dans_cone_vue(_x: float, _z: float) -> bool:
	return false
