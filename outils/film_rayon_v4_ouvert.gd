extends "res://outils/film_rayon_v3.gd"
## FILM du rayon noir v4, 1re personne, EN PLEIN AIR (nuit) : godot --path . --fixed-fps 60 --write-movie <f.avi> --resolution 1280x720
##   --script res://outils/film_rayon_v4_ouvert.gd -- --nouvelle --paisible --images=<dossier>
const Mes := preload("res://outils/mesure_rayon_v4.gd")

func _film() -> void:
	if _arg("heure") != "" and s.get("cycle") != null:
		s.cycle.heure = float(_arg("heure"))   # ex. --heure=11 : plein jour
		await _attendre(1.0)
	await _site_ouvert()
	var o: Vector3 = j.camera.global_position
	await Mes.film(self, [_cibles[1] + Vector3(0, 0.8, 0), _cibles[0] + Vector3(0, 0.8, 0), Vector3(o.x + 6.0, o.y - 0.3, o.z - 30.0)])
