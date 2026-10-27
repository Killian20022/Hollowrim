class_name ZoneMagie
extends Node3D
## Zone persistante (tempête statique) : frappe les cibles dans `rayon` toutes les `intervalle` s pendant `duree` s ; le
## rappel fait les dégâts (LanceurSorts). Attraction (vortex) : tire les cibles vers le centre via leur `_recul`.

var rayon := 4.0
var duree := 5.0
var intervalle := 0.5
var attraction := 0.0
var rappel: Callable
var _t := 0.0
var _tic := 0.0

func _physics_process(dt: float) -> void:
	_t += dt
	_tic += dt
	if attraction > 0.0:
		attirer(global_position, rayon, attraction)
	if _tic >= intervalle:
		_tic -= intervalle
		for c in Elements.cibles_dans(global_position, rayon):
			if rappel.is_valid():
				rappel.call(c)
	if _t >= duree:
		queue_free()

## Attire vers `centre` les cibles dans `rayon` (draugr, EnnemiBase : propriété `_recul`, amortie par l'ennemi).
static func attirer(centre: Vector3, rayon: float, force: float) -> void:
	for c in Elements.cibles_dans(centre, rayon):
		if c.get("_recul") is Vector3:
			var v: Vector3 = centre - (c as Node3D).global_position
			v.y = 0.0
			if v.length() > 0.6:
				c.set("_recul", v.normalized() * force)
