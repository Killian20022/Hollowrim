extends "res://outils/film_rayon_noir.gd"
## Mesure + captures du rayon noir v4 DANS LA CRYPTE (voir mesure_rayon_v4_ouvert.gd). Ajouter --crypte=0,-24,0,-4.

const Mes := preload("res://outils/mesure_rayon_v4.gd")

func _film() -> void:
	var mur := _mur()
	await _regarder(mur[0], 0.4)
	await Mes.mesurer(self, "crypte")
