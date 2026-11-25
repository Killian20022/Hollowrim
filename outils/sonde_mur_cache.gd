extends SceneTree
## Sonde : largeur réelle de la galerie H (cache) et épaisseur de roche jusqu'à la galerie voisine, pour poser le mur fragile sans qu'il perce.
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var pere := Node3D.new()
	root.add_child(pere)
	var g := Grotte.creer(pere, null, {})
	await process_frame
	for s: float in [5.4, 6.5, 7.5, 8.5, 9.5]:
		var ligne := "H s=%.1f" % s
		for y: float in [0.4, 1.5, 2.8]:
			var c := g.sol_en("H", s, 0.0) + Vector3(0, y, 0)
			var R := g.droite("H", s)
			for sg: float in [-1.0, 1.0]:
				var h1 := g.rayon(c, R * sg, 12.0)
				if h1.is_empty():
					ligne += "  y%.1f %s: -" % [y, "g" if sg < 0 else "d"]
					continue
				var p1: Vector3 = h1["p"]
				var h2 := g.rayon(p1 + R * sg * 0.02, R * sg, 12.0)
				var ep := 99.0 if h2.is_empty() else (h2["p"] as Vector3).distance_to(p1)
				ligne += "  y%.1f %s: paroi %.2f roche %.2f" % [y, "g" if sg < 0 else "d", p1.distance_to(c), ep]
		print(ligne)
	quit(0)
