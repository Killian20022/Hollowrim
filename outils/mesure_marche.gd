extends SceneTree
## Diagnostic : où regarde le modèle (orteils vs pied, yeux vs tête) et quelle foulée ont Walk / Jog_Fwd.
## godot --headless -s res://outils/mesure_marche.gd

func _initialize() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	var h: Node3D = Humain.creer({"corps": "homme", "tenue": {}})
	root.add_child(h)
	var sq: Skeleton3D = h.find_child("Skeleton3D", true, false)
	var ap: AnimationPlayer = h.get_node("Animations")
	print("racine basis z=", h.global_transform.basis.z, " squelette basis z=", sq.global_transform.basis.z, " parent=", sq.get_parent().name, " scale=", sq.global_transform.basis.get_scale())
	var nd: Node = sq
	while nd != h.get_parent():
		print("  noeud ", nd.name, " rot=", (nd as Node3D).rotation_degrees, " sc=", (nd as Node3D).scale)
		nd = nd.get_parent()
	for b in ["foot_l", "ball_l", "Head", "pelvis", "root"]:
		print(b, " -> ", sq.find_bone(b))
	var dev := sq.get_bone_global_pose(sq.find_bone("ball_l")).origin - sq.get_bone_global_pose(sq.find_bone("foot_l")).origin
	print("repos : ball_l - foot_l = ", dev, "  (z>0 => regarde +Z)")
	for mi: MeshInstance3D in sq.find_children("Eyes", "MeshInstance3D", false, false):
		print("yeux centre z=", mi.get_aabb().get_center().z)
	for nom in ["Idle", "Walk", "Walk_Formal", "Jog_Fwd", "Sprint", "Sword_Idle"]:
		var a := ap.get_animation(nom)
		ap.play(nom)
		ap.pause()
		var pieds := {}
		var bassin0 := Vector3.ZERO
		var n := 60
		var zs_l: Array = []
		var ys_l: Array = []
		var zs_r: Array = []
		for i in n + 1:
			ap.seek(a.length * i / n, true)
			ap.advance(0.0)
			await process_frame
			var pl := (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("foot_l"))).origin
			var pr := (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("foot_r"))).origin
			var bp := sq.get_bone_global_pose(sq.find_bone("pelvis")).origin
			if i == 0: bassin0 = bp
			if i == n: print("  ", nom, " bassin dérive début->fin : ", bp - bassin0)
			zs_l.append(pl.z)
			ys_l.append(pl.y)
			zs_r.append(pr.z)
		var mn: float = zs_l.min()
		var mx: float = zs_l.max()
		print(nom, " durée=", a.length, " amplitude pied_l z=", mx - mn, " (min ", mn, " max ", mx, ")")
		# vitesse du pied d'appui = pente max négative de z (le pied recule par rapport au corps)
		var pente := 0.0
		for i in n:
			var d: float = (zs_l[i + 1] - zs_l[i]) / (a.length / n)
			pente = minf(pente, d)
		var moy := 0.0
		var k := 0
		for i in n:
			var d2: float = (zs_l[i + 1] - zs_l[i]) / (a.length / n)
			if d2 < pente * 0.6:
				moy += d2
				k += 1
		# appui : pied à moins de 4 cm de son point bas ; vitesse du corps = recul du pied / durée d'appui
		var ymin: float = ys_l.min()
		var premier := -1
		var dernier := -1
		var nb := 0
		for i in n:
			if ys_l[i] < ymin + 0.04:
				nb += 1
				if premier < 0: premier = i
				dernier = i
		if nb > 1:
			print("   APPUI : ", nb * a.length / n, " s, recul pied ", zs_l[premier] - zs_l[dernier], " m => vitesse corps ~ ", (zs_l[premier] - zs_l[dernier]) / ((dernier - premier) * a.length / n), " m/s")
		print("   vitesse du pied d'appui (m/s, signe - = pied recule vers -Z => avance +Z) : ", moy / maxf(k, 1), " pic ", pente)
	quit()
