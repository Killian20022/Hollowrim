extends SceneTree
## Test headless : godot --headless -s res://outils/test_ragdoll.gd
## Pieds au sol (pente 15°, Walk puis Idle) puis ragdoll (impulsion forte, puis faible).

const PENTE := -15.0   # degrés autour de X : le sol monte vers +Z
var _n: Vector3
var _ok := true
var recul_fort := 0.0

func _h(x: float, z: float) -> float:
	return -(_n.x * x + _n.z * z) / _n.y

func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_ok = false
		print("  ÉCHEC : ", msg)

func _monde() -> Node3D:
	var monde := Node3D.new()
	root.add_child(monde)
	var sol := StaticBody3D.new()
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(40, 0.4, 40)
	f.shape = b
	sol.add_child(f)
	var basis := Basis(Vector3.RIGHT, deg_to_rad(PENTE))
	_n = basis * Vector3.UP
	sol.transform = Transform3D(basis, -_n * 0.2)
	monde.add_child(sol)
	return monde

func _perso(monde: Node3D, x: float, avec_pieds: bool) -> Array:
	var corps := CharacterBody3D.new()
	corps.collision_layer = 2
	monde.add_child(corps)
	corps.global_position = Vector3(x, _h(x, 0.0), 0.0)
	var p := Humain.creer({"corps": "homme", "tenue": {"tunique": Color.GRAY, "pantalon": Color.DIM_GRAY, "bottes": Color.BLACK}})
	corps.add_child(p)
	var pieds: Node = PiedsAuSol.equiper(p, corps) if avec_pieds else null
	# les os lus par get_bone_global_pose ignorent les modificateurs : on mesure via des BoneAttachment3D
	var sq: Skeleton3D = p.find_child("Skeleton3D", true, false)
	for n in ["foot_l", "foot_r", "hand_r", "Head", "pelvis"]:
		var ba := BoneAttachment3D.new()
		ba.name = "mesure_" + n
		ba.bone_name = n
		sq.add_child(ba)
	return [corps, p, pieds]

func _os(p: Node3D, n: String) -> Vector3:
	return (p.find_child("Skeleton3D", true, false).get_node("mesure_" + n) as Node3D).global_position

func _pieds(p: Node3D, corps: Node3D) -> Array:
	return [_os(p, "foot_l"), _os(p, "foot_r")]

func _initialize() -> void:
	var monde := _monde()
	for _i in 3:
		await physics_frame
	# --- pieds au sol ---
	var a := _perso(monde, -2.0, true)
	var temoin := _perso(monde, 2.0, false)
	var corps: CharacterBody3D = a[0]
	var p: Node3D = a[1]
	var ap: AnimationPlayer = p.get_node("Animations")
	var ap_t: AnimationPlayer = temoin[1].get_node("Animations")
	var h_repos := 0.0
	for phase in ["Walk", "Idle"]:
		ap.play(phase)
		ap_t.play(phase)
		var mini := 1e9
		var maxi := -1e9
		var mini_t := 1e9
		var duree := 3.0 if phase == "Walk" else 2.0
		var t0 := Time.get_ticks_msec()
		var t := 0.0
		while t < duree:
			await process_frame
			t = (Time.get_ticks_msec() - t0) / 1000.0
			if t < 0.8:
				continue
			var pa := _pieds(p, corps)
			var pt := _pieds(temoin[1], temoin[0])
			for k in 2:
				var e: float = pa[k].y - _h(pa[k].x, pa[k].z)
				mini = minf(mini, e)
				maxi = maxf(maxi, e)
				var et: float = pt[k].y - _h(pt[k].x, pt[k].z)
				mini_t = minf(mini_t, et)
		print("%s : hauteur cheville/sol  avec=[%.3f ; %.3f]  sans module (témoin) min=%.3f" % [phase, mini, maxi, mini_t])
		if phase == "Idle":
			_verifier(mini > 0.03 and maxi < 0.10, "pieds pas posés sur la pente à l'arrêt")
		else:
			_verifier(mini > 0.03, "pied enfoncé en marche")
	# --- ragdoll ---
	for cas in [["fort", Vector3(0, 0, -400.0)], ["faible", Vector3(0, 0, -50.0)]]:
		corps.queue_free()
		temoin[0].queue_free()
		var c := _perso(monde, 0.0, true)
		var cp: Node3D = c[1]
		var cap: AnimationPlayer = cp.get_node("Animations")
		cap.play("Idle")
		for _i in 90:
			await process_frame
		var rd: Ragdoll = Ragdoll.equiper(cp) as Ragdoll
		rd.endormir_apres(2.0)
		var avant := _os(cp, "pelvis")
		var os_avant := {}
		for n in ["foot_l", "hand_r", "Head"]:
			os_avant[n] = _os(cp, n)
		rd.declencher(cas[1], Vector3(0, 1.2, 0.2), "")
		# pas de saut de pose : un pas de physique plus tard, les os sont là où ils étaient
		await physics_frame
		await physics_frame
		await process_frame
		var saut := 0.0
		for n in os_avant:
			var q := _os(cp, n)
			saut = maxf(saut, q.distance_to(os_avant[n]))
		var t := 0.0
		var genou_min := 9.0
		var genou_repos := 9.0
		while t < 6.0:
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			var gl := minf(rd.flexion("calf_l"), rd.flexion("calf_r"))
			genou_min = minf(genou_min, gl)
			if t > 5.0:
				genou_repos = minf(genou_repos, gl)
		var sous := 1e9
		var haut_max := -1e9
		for nom: String in rd.os:
			var pb: PhysicalBone3D = rd.os[nom]
			var e := pb.global_position.y - _h(pb.global_position.x, pb.global_position.z)
			sous = minf(sous, e)
			haut_max = maxf(haut_max, e)
		var apres := (rd.os["pelvis"] as PhysicalBone3D).global_position
		var recul := Vector3(apres.x - avant.x, 0, apres.z - avant.z).dot(Vector3(cas[1]).normalized())
		var pelvis_h := apres.y - _h(apres.x, apres.z)
		print("%s : saut de pose=%.3f m, os le plus bas=%.3f m, os le plus haut=%.3f m, pelvis à %.3f m du sol, recul=%.2f m, genou min=%.1f° (au repos %.1f°), figé=%s" % [cas[0], saut, sous, haut_max, pelvis_h, recul, rad_to_deg(genou_min), rad_to_deg(genou_repos), rd.est_fige()])
		_verifier(cas[0] == "fort" or saut < 0.05, "saut de pose au déclenchement")
		_verifier(sous > -0.05, "un os traverse le sol")
		_verifier(pelvis_h < 0.4, "pelvis loin du sol")
		_verifier(genou_repos > deg_to_rad(-10.0) and genou_min > deg_to_rad(-60.0), "genou hyper-étendu")
		_verifier(rd.est_fige(), "pas figé")
		if cas[0] == "fort":
			_verifier(recul > 0.8, "pas assez de recul")
			recul_fort = recul
		else:
			_verifier(recul > 0.0 and recul < 0.6 * recul_fort, "le coup faible doit déplacer bien moins que le fort")
		# le corps fige : plus de mouvement
		var fige := (rd.os["pelvis"] as PhysicalBone3D).global_position
		for _i in 30:
			await physics_frame
		_verifier(fige.distance_to((rd.os["pelvis"] as PhysicalBone3D).global_position) < 0.001, "bouge après figeage")
		corps = c[0]
		temoin = [Node3D.new()]
		monde.add_child(temoin[0])
	print("TEST RAGDOLL : ", "OK" if _ok else "ÉCHEC")
	quit(0 if _ok else 1)
