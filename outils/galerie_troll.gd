extends "res://outils/galerie_guerrier.gd"
## Galerie du Troll de givre : même banc que galerie_guerrier.gd (rendu 640x360, crépuscule/nuit, passe ps1_post, modes
## planche / anims / gros / cout), avec --perso=troll (défaut) ou --perso=guerrier (comparaison).
##   godot --path . --script res://outils/galerie_troll.gd -- --sortie=<dossier absolu> --perso=troll [--mode=planche|anims|cout]

func _arg(nom: String, defaut: String) -> String:
	if nom == "perso" and defaut == "guerrier":
		defaut = "troll"
	return super._arg(nom, defaut)

func _construire(quoi: String) -> Node3D:
	if quoi != "troll":
		return super._construire(quoi)
	GuerrierNordique.chrono = true
	var t0 := Time.get_ticks_usec()
	var n := TrollGivre.creer({})
	print("TROLL creer %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	sv.add_child(n)
	return n

## Caméras du banc du guerrier rehaussées pour une créature de ~2,5 m (--hauteur=1.45 par défaut pour le troll, 1 pour le guerrier).
func _photo(az_deg: float, dist: float, cam_h: float, cible_h: float) -> Image:
	var k := float(_arg("hauteur", "1.45" if _arg("perso", "guerrier") == "troll" else "1.0"))
	return await super._photo(az_deg, dist * float(_arg("recul", "1.0")), cam_h * k, cible_h * k)
