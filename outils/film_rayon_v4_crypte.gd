extends "res://outils/film_rayon_noir.gd"
## FILM du rayon noir v4, 1re personne, DANS LA CRYPTE : ... --script res://outils/film_rayon_v4_crypte.gd -- --nouvelle --paisible --crypte=0,-24,0,-4
const Mes := preload("res://outils/mesure_rayon_v4.gd")

func _film() -> void:
	var mur := _mur()
	var o: Vector3 = j.camera.global_position
	await Mes.film(self, [mur[0], mur[1], mur[0] + (mur[1] - mur[0]) * -1.2])
