extends SceneTree
## [C7b] Sonde des emplacements du bâti v2 (sans fenêtre) : pour chaque bâtiment du plan, hauteurs du sol aux coins,
## terrasse (ReliefVillage.terrasse), distance signée à la palissade, eau sous l'emprise, arbres et rochers dans l'emprise.
##   godot --headless --path . --script res://outils/sonde_c7b.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")
# [id, x, z, longueur (axe local X), largeur (axe local Z), lacet monde (degrés), dedans (vrai = dans l'enceinte)]
const BATIS := [
	["I1", 44, 21, 14, 7, 0, true], ["I2", 27, 36, 5.2, 7.0, 90, true], ["I3", 28, 47, 7, 5, 90, true],
	["I4", 63, 29, 8, 5.5, -90, true], ["I5", 59.5, 47, 8, 5.5, 180, true], ["EN", 66.5, 41.3, 7, 5, -90, true],
	["H1", 36, 53, 7, 5, 180, true], ["H2", 54, 55.5, 6, 4.5, 180, true], ["H3", 35.5, 71, 6, 5, 0, true],
	["H4", 54, 77, 6, 5, 0, true], ["H5", 36, 85, 6, 5, 0, true], ["H6", 60, 20.5, 7, 5, -30, true],
	["M", 25.5, 55.5, 6, 6, 90, true], ["T", 45, 87.5, 5.2, 5.2, 0, true],
	["FA", 83, 21.5, 9, 6, 0, false], ["GA", 89.5, 23, 7, 5, 90, false], ["FB", 61, 3.5, 8, 5, 0, false],
	["GB", 67.5, 6, 6, 5, 90, false], ["MV", 94, 31, 5.5, 5.5, 0, false]]

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 3:
		await process_frame
	print("h_village = %.2f" % m.h_village)
	for b in BATIS:
		var a := deg_to_rad(float(b[5]))
		var bas := Basis(Vector3.UP, a)
		var hs: Array = []
		var ter: Array = []
		var dpal := -INF
		var eau := false
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var c := Vector3(b[1], 0, b[2]) + bas * Vector3(sx * (float(b[3]) * 0.5 + 0.8), 0, sz * (float(b[4]) * 0.5 + 0.8))
				hs.append(snappedf(DetailsSol.hauteur_maillage(m, c.x, c.z), 0.01))
				ter.append(ReliefVillage.terrasse(c.x, c.z, m.h_village))
				dpal = maxf(dpal, ReliefVillage.distance_palissade(c.x, c.z))
				if not is_nan(ReliefVillage.niveau_eau(c.x, c.z)):
					eau = true
		var arbres := 0
		for t: Transform3D in m.arbres:
			var l := bas.inverse() * (t.origin - Vector3(b[1], t.origin.y, b[2]))
			if absf(l.x) < float(b[3]) * 0.5 + 1.5 and absf(l.z) < float(b[4]) * 0.5 + 1.5:
				arbres += 1
		print("%s (%.1f;%.1f) sol coins %s terr %s  pal max %.2f  eau %s  arbres %d" % [b[0], b[1], b[2], str(hs), str(ter), dpal, str(eau), arbres])
	quit(0)
