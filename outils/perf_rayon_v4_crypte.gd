extends "res://outils/film_rayon_noir.gd"
## FPS du rayon noir v4 dans la crypte (sans --fixed-fps) : ... --script res://outils/perf_rayon_v4_crypte.gd -- --nouvelle --paisible --crypte=0,-24,0,-4
const Mes := preload("res://outils/mesure_rayon_v4.gd")

func _film() -> void:
	var mur := _mur()
	await _regarder(mur[0], 0.4)
	await Mes.perf(self)
