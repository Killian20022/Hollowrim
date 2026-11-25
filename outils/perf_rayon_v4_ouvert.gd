extends "res://outils/film_rayon_v3.gd"
## FPS du rayon noir v4 en plein air (sans --fixed-fps) : godot --path . --script res://outils/perf_rayon_v4_ouvert.gd -- --nouvelle --paisible
const Mes := preload("res://outils/mesure_rayon_v4.gd")

func _film() -> void:
	await _site_ouvert()
	await Mes.perf(self)
