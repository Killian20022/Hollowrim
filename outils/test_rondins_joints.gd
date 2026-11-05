extends SceneTree
## Retours exe 5 (« les murs des maisons font des vagues ») : la texture des rondins vus de près (intérieurs) doit avoir ses
## bords sombres (joints) au DESSUS et au DESSOUS du rondin, et son milieu clair sur la face avant ET la face arrière.
##   godot --headless --path . --script res://outils/test_rondins_joints.gd
## Contrôle aussi que la géométrie ne dépend pas de l'option (même graine → mêmes sommets) et que le bâti extérieur
## (option absente) garde l'ancienne projection.
var _echecs := 0

func _init() -> void:
	_tester()
	print("RÉSULTAT : %s (%d échec(s))" % ["OK" if _echecs == 0 else "ÉCHEC", _echecs])
	quit(0 if _echecs == 0 else 1)

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

## v dans la bande (0..1) de chaque triangle du fût, rangé par la direction de sa normale (avant +z, arrière −z, haut, bas).
func _bandes(f: BatiGeo.Maillage, strate: int) -> Dictionary:
	var d := {"avant": [], "arriere": [], "haut": [], "bas": []}
	for i in range(0, f.v.size(), 3):
		var n: Vector3 = f.n[i]
		var v := (f.uv[i].y + f.uv[i + 1].y + f.uv[i + 2].y) / 3.0 - strate
		if n.z > 0.85:
			d["avant"].append(v)
		elif n.z < -0.85:
			d["arriere"].append(v)
		elif n.y > 0.85:
			d["haut"].append(v)
		elif n.y < -0.85:
			d["bas"].append(v)
	return d

func _tester() -> void:
	var strate := 2
	var a: Array = BatiGeo.rondin(3.0, 0.125, 1234, 0.006, strate, 1.5, 1.0, true)
	var b: Array = BatiGeo.rondin(3.0, 0.125, 1234, 0.006, strate, 1.5, 1.0, false)
	var fa: BatiGeo.Maillage = a[0]
	var fb: BatiGeo.Maillage = b[0]
	var meme := fa.v.size() == fb.v.size()
	if meme:
		for i in fa.v.size():
			if fa.v[i].distance_to(fb.v[i]) > 1e-6:
				meme = false
				break
	_verif(meme, "même graine : géométrie identique avec ou sans joints_haut_bas (seules les UV changent)")
	var d := _bandes(fa, strate)
	for cote in ["avant", "arriere", "haut", "bas"]:
		_verif((d[cote] as Array).size() > 0, "faces %s trouvées" % cote)
	var milieu := true
	for v in d["avant"] + d["arriere"]:
		milieu = milieu and absf(v - 0.5) < 0.15
	_verif(milieu, "faces avant et arrière au milieu clair de la bande (|v − 0,5| < 0,15) : %s %s" % [d["avant"], d["arriere"]])
	var joints := true
	for v in d["haut"]:
		joints = joints and v < 0.2
	for v in d["bas"]:
		joints = joints and v > 0.8
	_verif(joints, "dessus au bord haut (v < 0,2), dessous au bord bas (v > 0,8) : %s %s" % [d["haut"], d["bas"]])
	var dans := true
	for uv in fa.uv:
		dans = dans and uv.y >= strate and uv.y <= strate + 1.0
	_verif(dans, "toutes les UV restent dans la bande de la strate (pas de débord sur la bande voisine)")
	# sans l'option (bâti extérieur validé) : ancienne projection, la bande tourne depuis l'anneau k = 0
	var dbx := _bandes(fb, strate)
	var avant_b: Array = dbx["avant"]
	_verif(avant_b.size() > 0 and absf(avant_b[0] - 0.93 * 7.5 / 8.0) < 0.05, "sans l'option : projection d'origine inchangée (face avant v ≈ 0,87) : %s" % [avant_b])
