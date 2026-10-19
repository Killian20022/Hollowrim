extends SceneTree
## Test sans fenêtre : godot --headless -s res://outils/test_mort_ragdoll.gd
## Un draugr reçoit un coup mortel puissant (puis un léger sur un second draugr) venant de -X :
## il doit tomber dans le sens du coup (bassin déplacé vers +X), sans qu'aucun os passe sous le
## terrain, et finir figé ; le coup léger le fait reculer moins. Les poses sont lues sur des
## BoneAttachment3D (get_bone_global_pose n'est pas fiable hors des modificateurs).
const SCENE := preload("res://scenes/foret_test.tscn")
const OS_MESURES := ["pelvis", "spine_03", "Head", "hand_l", "hand_r", "foot_l", "foot_r", "calf_l", "calf_r"]

var _ok := true

func _init() -> void:
	_tester.call_deferred()

func _verifier(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false

func _attaches(d: Node3D) -> Dictionary:
	var sq: Skeleton3D = d.modele.find_child("Skeleton3D", true, false)
	var res := {}
	for n in OS_MESURES:
		var ba := BoneAttachment3D.new()
		ba.bone_name = n
		sq.add_child(ba)
		res[n] = ba
	return res

## Tue un draugr posé en (x, z) par un coup venu de -X ; renvoie {deplacement, pire_dessous, fige}.
func _mort(m: Node, x: float, z: float, puissant: bool) -> Dictionary:
	var d: CharacterBody3D = m.creer_draugr("guerrier", Vector3(x, m.hauteur(x, z) + 0.05, z), 0.0, false, {"vie_imposee": 10.0})
	for i in 30:
		await physics_frame
	var att := _attaches(d)
	await process_frame
	var depart: Vector3 = (att["pelvis"] as Node3D).global_position
	var origine := d.global_position + Vector3(-1.8, 0.0, 0.0)
	var r: String = d.recevoir_coup(500.0 if puissant else 11.0, origine, puissant)
	_verifier(r == "tue", "coup %s : le draugr meurt (%s)" % ["puissant" if puissant else "léger", r])
	_verifier(d.collision_layer == 0 and d.collision_mask == 0, "capsule coupée à la mort")
	var pire := 1e9
	var rd: Ragdoll = d._ragdoll
	_verifier(rd != null and rd.actif, "ragdoll déclenché")
	var n := 0
	while n < 1200 and not (rd and rd.est_fige()):
		await physics_frame
		n += 1
		for k in att:
			var p: Vector3 = (att[k] as Node3D).global_position
			pire = minf(pire, p.y - m.hauteur(p.x, p.z))
	var fin: Vector3 = (att["pelvis"] as Node3D).global_position
	var dep := fin - depart
	print("   bassin déplacé de ", dep, " ; pire hauteur au-dessus du terrain ", snappedf(pire, 0.001), " ; figé après ", n, " images")
	return {"deplacement": dep, "pire": pire, "fige": rd != null and rd.est_fige()}

func _tester() -> void:
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	for i in 10:
		await process_frame
	m.joueur.global_position = Vector3(60, m.hauteur(60, 60) + 1.0, 60)  # loin : le draugr reste calme
	var fort: Dictionary = await _mort(m, 4.0, -4.0, true)
	var leger: Dictionary = await _mort(m, 4.0, 4.0, false)
	var df: Vector3 = fort["deplacement"]
	var dl: Vector3 = leger["deplacement"]
	_verifier(df.x > 1.0, "coup puissant : tombe dans le sens du coup (+X : %.2f m)" % df.x)
	_verifier(absf(df.z) < df.x, "coup puissant : la chute est dans l'axe du coup")
	_verifier(dl.x > 0.0, "coup léger : tombe tout de même du bon côté (%.2f m)" % dl.x)
	_verifier(dl.x < df.x * 0.7, "coup léger : recule moins (%.2f < %.2f m)" % [dl.x, df.x])
	_verifier(fort["pire"] > -0.05 and leger["pire"] > -0.05, "aucun os sous le terrain")
	_verifier(fort["fige"] and leger["fige"], "les corps finissent figés")
	print("TEST MORT RAGDOLL : ", "OK" if _ok else "ÉCHEC")
	quit()
