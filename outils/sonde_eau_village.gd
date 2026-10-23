extends SceneTree
## Sonde du relief pour l'eau du village (C7c) : lac de la combe SO (composante connexe sous -0,8 m), profil de la rivière
## (lit du maillage vs niveau d'eau), débordements, hauteurs aux points clés (source, pont, quai, moulin, gué).
##   godot --headless --path . --script res://outils/sonde_eau_village.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D

func _init() -> void:
	_lancer.call_deferred()

func hm(x: float, z: float) -> float:
	return DetailsSol.hauteur_maillage(m, x, z)

func _lancer() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 3:
		await process_frame
	# --- lac : cases de 0,5 m sous -0,8, composante connexe du centre (-20 ; 44)
	var x0 := -80.0
	var z0 := -5.0
	var pas := 0.5
	var nx := int(110.0 / pas)
	var nz := int(100.0 / pas)
	var bas := PackedByteArray()
	bas.resize(nx * nz)
	var hmin := INF
	for j in nz:
		for i in nx:
			var h := hm(x0 + (i + 0.5) * pas, z0 + (j + 0.5) * pas)
			bas[j * nx + i] = 1 if h < -0.8 else 0
	var dep := Vector2i(int((-20.0 - x0) / pas), int((44.0 - z0) / pas))
	print("centre du lac : h = %.2f" % hm(-20, 44))
	var vu := {}
	var pile := [dep]
	vu[dep] = true
	var bmin := Vector2(INF, INF)
	var bmax := Vector2(-INF, -INF)
	var bord := false
	var prof_max := 0.0
	while not pile.is_empty():
		var c: Vector2i = pile.pop_back()
		var x := x0 + (c.x + 0.5) * pas
		var z := z0 + (c.y + 0.5) * pas
		bmin = bmin.min(Vector2(x, z))
		bmax = bmax.max(Vector2(x, z))
		prof_max = maxf(prof_max, -0.8 - hm(x, z))
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= nz:
				bord = true
				continue
			if bas[n.y * nx + n.x] == 1 and not vu.has(n):
				vu[n] = true
				pile.append(n)
	print("lac : %.0f m², boîte x %.1f..%.1f z %.1f..%.1f, profondeur max %.2f, touche le cadre de sonde : %s" % [vu.size() * pas * pas, bmin.x, bmax.x, bmin.y, bmax.y, prof_max, bord])
	# zone témoin x -58..4, z -64..4 ?
	var dans_temoin := 0
	for c: Vector2i in vu:
		var x := x0 + (c.x + 0.5) * pas
		var z := z0 + (c.y + 0.5) * pas
		if x > -58 and x < 4 and z > -64 and z < 4:
			dans_temoin += 1
	print("lac : cases dans la zone témoin : %d" % dans_temoin)
	# histogramme de profondeur
	var histo := {}
	for c: Vector2i in vu:
		var p := -0.8 - hm(x0 + (c.x + 0.5) * pas, z0 + (c.y + 0.5) * pas)
		var b := int(floorf(p * 2.0))
		histo[b] = int(histo.get(b, 0)) + 1
	var cles := histo.keys()
	cles.sort()
	for b in cles:
		print("  prof %.1f..%.1f : %.0f m²" % [b * 0.5, b * 0.5 + 0.5, histo[b] * pas * pas])
	# --- rivière : profil le long de l'axe
	print("rivière : abscisse | x z | eau | lit maillage axe | min berge à hw+0.5 | hauteur()")
	var R := ReliefVillage.RIVIERE
	for i in R.size() - 1:
		var a := Vector2(R[i][0], R[i][1])
		var b := Vector2(R[i + 1][0], R[i + 1][1])
		var l := a.distance_to(b)
		var n := maxi(1, int(l / 2.0))
		for k in n:
			var p := a.lerp(b, float(k) / n)
			var r := ReliefVillage.riviere(p.x, p.y)
			var dirv: Vector2 = r["direction"]
			var perp := Vector2(-dirv.y, dirv.x)
			var hw: float = r["demi_largeur"]
			var b1 := hm(p.x + perp.x * (hw + 0.5), p.y + perp.y * (hw + 0.5))
			var b2 := hm(p.x - perp.x * (hw + 0.5), p.y - perp.y * (hw + 0.5))
			print("  %5.1f | %5.1f %5.1f | %5.2f | %5.2f | %5.2f %5.2f | %5.2f" % [r["abscisse"], p.x, p.y, r["eau"], hm(p.x, p.y), b1, b2, m.hauteur(p.x, p.y)])
	# débordements : cases à plus de hw+0,3 de l'axe (≤ 12 m) où le maillage est sous le niveau d'eau du point le plus proche
	var deb := 0
	var sec := 0
	var exemples := []
	var x := 10.0
	while x <= 92.0:
		var z := 50.0
		while z <= 72.0:
			var r := ReliefVillage.riviere(x, z)
			if not r.is_empty():
				var d: float = r["distance"]
				var hw: float = r["demi_largeur"]
				var h := hm(x, z)
				if d > hw + 0.3 and d < hw + 3.0 and h < float(r["eau"]) and x > 18.5:
					deb += 1
					if exemples.size() < 12:
						exemples.append("(%.1f;%.1f) h %.2f eau %.2f d %.1f" % [x, z, h, r["eau"], d])
				if d < hw - 1.0 and h > float(r["eau"]) - 0.05 and x > 22.5:
					sec += 1
			z += 0.5
		x += 0.5
	print("débordements (cases 0,5 m) : %d %s" % [deb, exemples])
	print("lit à sec au milieu : %d" % sec)
	# points clés
	for e in [["source lèvre", 90, 57], ["source amont", 92, 57], ["source 94", 94, 57], ["bassin", 86.5, 58], ["gué", 78, 59], ["gué n", 78, 57], ["gué s", 78, 61.5],
			["pont n", 44, 57], ["pont n2", 44, 58.5], ["pont s", 44, 64.5], ["pont s2", 44, 66], ["quai 29", 29, 57.2], ["quai 38", 38, 57.2], ["quai bord", 33, 58.5],
			["moulin lèvre", 22, 61], ["moulin pied", 18, 61], ["moulin 20", 20, 61], ["roue", 21.5, 61], ["maison M", 25.5, 55.5], ["rive S 21.5", 21.5, 63.5],
			["rive N 21.5", 21.5, 58.5], ["lac 15", 15, 61], ["lac 12", 12, 61]]:
		print("%s (%.1f;%.1f) : maillage %.2f hauteur %.2f eau %s" % [e[0], e[1], e[2], hm(e[1], e[2]), m.hauteur(e[1], e[2]), ReliefVillage.niveau_eau(e[1], e[2])])
	quit(0)
