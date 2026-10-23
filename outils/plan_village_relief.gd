extends SceneTree
## Lot C7-PLAN : exporte le relief (ancien relief + aplanissement de la grotte, 1 m) en texte pour le plan de masse du village v2.
##   godot --headless --path . --script res://outils/plan_village_relief.gd -- --sortie=<fichier> [--zone=x0,x1,z0,z1]
## Par défaut toute la cuvette jouable (mur invisible à 108 m) : -110..110 sur x et z.
var X0 := -110
var X1 := 110
var Z0 := -110
var Z1 := 110

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var sortie := "res://captures/plan_village_relief.txt"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
		elif a.begins_with("--zone="):
			var b := a.substr(7).split(",")
			X0 = int(b[0]); X1 = int(b[1]); Z0 = int(b[2]); Z1 = int(b[3])
	var monde = (load("res://scripts/monde.gd") as GDScript).new()
	monde.rng.seed = 1234
	monde.bruit.seed = 7
	monde.bruit.frequency = 0.009
	monde.bruit.fractal_octaves = 4
	monde.bruit_detail.seed = 11
	monde.bruit_detail.frequency = 0.06
	monde.h_centre = monde._hauteur_brute(0.0, 0.0)
	for k in 8:
		var a := TAU * k / 8.0
		monde.h_village += monde._hauteur_brute(monde.VILLAGE.x + cos(a) * 30.0, monde.VILLAGE.z + sin(a) * 30.0) / 8.0
		monde.h_cercle += monde._hauteur_brute(monde.CERCLE.x + cos(a) * 16.0, monde.CERCLE.z + sin(a) * 16.0) / 8.0
	monde.h_grotte = monde._hauteur_ancienne(GrotteAcces.SITE.x - 1.0, GrotteAcces.SITE.y)
	var f := FileAccess.open(sortie, FileAccess.WRITE)
	f.store_line("# x0=%d x1=%d z0=%d z1=%d pas=1 ; h_village=%.3f h_centre=%.3f h_grotte=%.3f ; une ligne par z" % [X0, X1, Z0, Z1, monde.h_village, monde.h_centre, monde.h_grotte])
	for z in range(Z0, Z1 + 1):
		var l := PackedStringArray()
		for x in range(X0, X1 + 1):
			l.append("%.2f" % GrotteAcces.aplani(x, z, monde._hauteur_ancienne(x, z), monde.h_grotte))
		f.store_line(",".join(l))
	f.close()
	print("relief ecrit : ", sortie)
	quit()
