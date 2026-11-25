extends "res://outils/film_rayon_v3.gd"
## Mesure + captures du rayon noir v4, EN PLEIN AIR (arène de film_rayon_v3, nuit), vue 1re personne.
##   godot --path . --fixed-fps 60 --resolution 1280x720 --script res://outils/mesure_rayon_v4_ouvert.gd -- --nouvelle --paisible --images=<dossier>
## Imprime « MESURE <t> sombre=… » pour chaque instant après le déclenchement et enregistre les images (avec / sans le rayon).

const Mes := preload("res://outils/mesure_rayon_v4.gd")

func _film() -> void:
	if _arg("heure") != "" and s.get("cycle") != null:
		s.cycle.heure = float(_arg("heure"))   # ex. --heure=11 : plein jour
		await _attendre(1.0)
	await _site_ouvert()
	if _arg("diag") != "":
		await Mes.diagnostic(self)
	else:
		await Mes.mesurer(self, "ouvert")
