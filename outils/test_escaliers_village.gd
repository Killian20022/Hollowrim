extends SceneTree
## C7a : le vrai joueur monte et descend les 3 volées de l'escalier de la haute rue (rampes de collision invisibles),
## en marchant puis en courant, au milieu et près des joues : il arrive en haut (z > 83, y ≈ terrasse 3), ne passe jamais
## sous le terrain (tolérance 0,7 m : la rampe passe au milieu des contremarches, sous la surface lissée de hauteur())
## et ne reste pas coincé ; puis redescend jusqu'au pied.
##   godot --headless --fixed-fps 60 --path . --script outils/test_escaliers_village.gd -- --nouvelle --paisible
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _trajet(x: float, z0: float, z1: float, courir: bool) -> Dictionary:
	var j: CharacterBody3D = m.joueur
	j.global_position = Vector3(x, m.hauteur(x, z0) + 0.15, z0)
	j.velocity = Vector3.ZERO
	j.rotation.y = PI if z1 > z0 else 0.0    # avant = -Z du joueur
	j.set("vigueur", 1000.0)
	for i in 5:
		await physics_frame
	Input.action_press("avant")
	if courir:
		Input.action_press("course")
	var sous := 0.0
	var t := 0.0
	var arrive := false
	while t < 12.0:
		await physics_frame
		t += 1.0 / 60.0
		j.set("vigueur", 1000.0)
		var p := j.global_position
		sous = minf(sous, p.y - m.hauteur(p.x, p.z))
		if (z1 > z0 and p.z >= z1) or (z1 < z0 and p.z <= z1):
			arrive = true
			break
	Input.action_release("avant")
	Input.action_release("course")
	return {"arrive": arrive, "t": t, "p": j.global_position, "sous": sous}

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 10:
		await physics_frame
	var h3: float = ReliefVillage.H_T3
	for x: float in [44.0, 42.6, 45.4]:
		for courir: bool in [false, true]:
			var mode := "course" if courir else "marche"
			# C7 fusion : le pont de C7c (z 57..66, 3,2 m de large) prolonge le pied de la 1re volée : on part des marches (z 67) ;
			# la tour-clocher de C7b (z 85..90) ferme le haut de la rue : arrivée testée sur T3 dès z 83,5
			var zb := 67.0
			var r: Dictionary = await _trajet(x, zb, 83.5, courir)
			_verif(r["arrive"] and absf((r["p"] as Vector3).y - h3) < 0.6, "montée x=%.1f (%s) : arrivée z=%.1f y=%.2f (terrasse %.2f) en %.1f s" % [x, mode, r["p"].z, r["p"].y, h3, r["t"]])
			_verif(r["sous"] > -0.7, "montée x=%.1f (%s) : jamais sous le terrain (min %.2f m)" % [x, mode, r["sous"]])
			var d: Dictionary = await _trajet(x, 83.5, zb, courir)
			_verif(d["arrive"], "descente x=%.1f (%s) : arrivée z=%.1f y=%.2f en %.1f s" % [x, mode, d["p"].z, d["p"].y, d["t"]])
			_verif(d["sous"] > -0.7, "descente x=%.1f (%s) : jamais sous le terrain (min %.2f m)" % [x, mode, d["sous"]])
	print("ECHECS : %d" % _echecs)
	m.queue_free()
	await process_frame
	quit(1 if _echecs > 0 else 0)
