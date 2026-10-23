extends SceneTree
## C7c : le VRAI joueur ne reste coincé ni dans le lit de la rivière ni dans le lac (eau libre, glace, pied de la cascade du moulin).
## Pour chaque point de départ, 8 caps, course + sauts ; succès d'un cap = le joueur finit hors de l'eau (sol au-dessus du niveau
## d'eau + 0,2 m, ou sur un ouvrage) sans passer sous le terrain. Un point est « coincé » si AUCUN cap n'en sort.
##   godot --headless --path . --script res://outils/sonde_c7c_sorties.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D

func _init() -> void:
	_lancer.call_deferred()

func _dans_eau(g: Vector3) -> bool:
	var n := ReliefVillage.niveau_eau(g.x, g.z)
	if not is_nan(n):
		return g.y < n + 0.2
	return EauVillage.sous_le_lac(g.x, g.z, m.hauteur(g.x, g.z)) and g.y < EauVillage.LAC_NIVEAU + 0.2 and m.hauteur(g.x, g.z) < EauVillage.LAC_NIVEAU

func _lancer() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 6:
		await physics_frame
	var j: CharacterBody3D = m.joueur
	var departs: Array = []   # [nom, Vector2, durée s]
	var R := ReliefVillage.RIVIERE
	for i in R.size() - 2:   # lit de la rivière, tous les ~5 m (sauf le lac)
		var a := Vector2(R[i][0], R[i][1])
		var b := Vector2(R[i + 1][0], R[i + 1][1])
		var n := maxi(1, int(a.distance_to(b) / 5.0))
		for k in n:
			var p := a.lerp(b, float(k) / n)
			departs.append(["lit %.0f;%.0f" % [p.x, p.y], p, 4.0])
	for e in [["piege audit 18;69.5", Vector2(18, 69.5), 4.0], ["pied cascade moulin", Vector2(17.5, 61), 5.0], ["eau libre 15;61", Vector2(15, 61), 6.0],
			["eau libre 10;64", Vector2(10, 64), 8.0], ["eau libre 12;57", Vector2(12, 57), 8.0], ["sous l'arche", Vector2(44, 61.5), 4.0],
			["sous le quai", Vector2(33, 59.5), 4.0], ["bassin source", Vector2(86.5, 58), 4.0], ["glace -20;44", Vector2(-20, 44), 30.0],
			["glace 0;60", Vector2(0, 60), 20.0], ["glace -40;30", Vector2(-40, 30), 25.0]]:
		departs.append(e)
	j.set_physics_process(true)
	Input.action_press("course")
	Input.action_press("avant")
	var coinces := 0
	var sous_sol := 0
	for d in departs:
		var p: Vector2 = d[1]
		var ok := 0
		var details := ""
		for c in 8:
			var ang := c * TAU / 8.0
			var y0: float = m.hauteur(p.x, p.y)
			var lac := EauVillage.sous_le_lac(p.x, p.y, y0)
			j.global_position = Vector3(p.x, maxf(y0, EauVillage.LAC_NIVEAU if lac else y0) + 0.4, p.y)
			j.velocity = Vector3.ZERO
			j.rotation.y = ang
			var pire := 0.0
			for f in int(float(d[2]) * 60.0):
				if f % 40 == 20:
					Input.action_press("saut")
				elif f % 40 == 21:
					Input.action_release("saut")
				j.vigueur = j.vigueur_max
				await physics_frame
				var g := j.global_position
				pire = minf(pire, g.y - m.hauteur(g.x, g.z))
				if f > 45 and j.is_on_floor() and not _dans_eau(g):
					break   # sorti : inutile de courir plus longtemps
			var g := j.global_position
			if pire < -1.0:
				sous_sol += 1
				details += " SOUS-SOL(%.1f)" % pire
			if not _dans_eau(g) and pire >= -1.0:
				ok += 1
		if ok == 0:
			coinces += 1
		print("%-22s (%.1f;%.1f) : %d/8 caps sortent de l'eau%s%s" % [d[0], p.x, p.y, ok, details, "  <-- COINCÉ" if ok == 0 else ""])
	Input.action_release("avant")
	Input.action_release("course")
	print("SORTIES C7c : %d départs, %d coincé(s), %d passage(s) sous le sol" % [departs.size(), coinces, sous_sol])
	quit(0 if coinces == 0 and sous_sol == 0 else 1)
