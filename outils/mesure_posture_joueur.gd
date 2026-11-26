extends SceneTree
## joueur_base passe 2 : posture des corps du joueur (homme, femme) contre l'ancien héros, MÊME clip, MÊME instant.
##   godot --headless --path . --script res://outils/mesure_posture_joueur.gd [-- --clips=Sword_Idle,Idle,Walk] [--json=<f>]
## Par modèle / clip / instant : écart latéral des chevilles / largeur des hanches, angle des genoux (180 = tendu),
## orientation des pieds (0 = vers l'avant, + = vers l'extérieur), hauteur du bassin. Critères (brief passe 2) au repos :
## chevilles <= hanches x 1,3, genoux >= 165 deg, pieds +-15 deg.
var resultats := {}

func _init() -> void:
	_go.call_deferred()

func _arg(n: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + n + "="):
			return a.substr(n.length() + 3)
	return d

func _p(sq: Skeleton3D, nom: String) -> Vector3:
	return sq.get_bone_global_pose(sq.find_bone(nom)).origin

func _mesurer(sq: Skeleton3D) -> Dictionary:
	var r := {}
	var hl := _p(sq, "thigh_l"); var hr := _p(sq, "thigh_r")
	var kl := _p(sq, "calf_l"); var kr := _p(sq, "calf_r")
	var fl := _p(sq, "foot_l"); var fr := _p(sq, "foot_r")
	var bl := _p(sq, "ball_l"); var br := _p(sq, "ball_r")
	r["hanches"] = absf(hl.x - hr.x)
	r["chevilles"] = absf(fl.x - fr.x)
	r["ratio"] = r["chevilles"] / maxf(r["hanches"], 0.001)
	r["genou_l"] = rad_to_deg((hl - kl).angle_to(fl - kl))
	r["genou_r"] = rad_to_deg((hr - kr).angle_to(fr - kr))
	# pied : +Z = devant ; gauche du perso = +X ; + = pointe vers l'extérieur
	var dl := Vector2(bl.x - fl.x, bl.z - fl.z)
	var dr := Vector2(br.x - fr.x, br.z - fr.z)
	r["pied_l"] = rad_to_deg(atan2(dl.x, dl.y))
	r["pied_r"] = -rad_to_deg(atan2(dr.x, dr.y))
	r["bassin"] = _p(sq, "pelvis").y
	r["tete"] = _p(sq, "Head").y
	return r

func _go() -> void:
	var clips := Array(_arg("clips", "Sword_Idle,Idle,Idle_Torch,Spell_Simple_Idle,Walk,Jog_Fwd,Sprint,Sword_Attack,Hit_Chest").split(","))
	var modeles := {
		"homme": JoueurBase.creer("homme"),
		"femme": JoueurBase.creer("femme"),
		"ancien": HerosSkarnholt.creer({}),
	}
	for n: String in modeles:
		root.add_child(modeles[n])
	await process_frame
	for n: String in modeles:
		var m: Node3D = modeles[n]
		var sq: Skeleton3D = m.find_child("Skeleton3D", true, false)
		var ap: AnimationPlayer = m.get_node("Animations")
		resultats[n] = {}
		sq.reset_bone_poses()
		await process_frame
		resultats[n]["repos"] = _mesurer(sq)
		for c: String in clips:
			if not ap.has_animation(c):
				print("PAS DE CLIP ", c)
				continue
			var lg := ap.get_animation(c).length
			for f in [0.0, 0.25, 0.5, 0.75]:
				ap.play(c)
				ap.speed_scale = 0.0
				ap.seek(lg * f, true)
				for _i in 30:         # PostureJoueur fond son poids en ~0,15 s
					await process_frame
				# pose FINALE (après les modificateurs) : lue pendant skeleton_updated, avant que le squelette ne remette la pose du clip
				var lu := {}
				var lire := func() -> void:
					lu.merge(_mesurer(sq), true)
				sq.skeleton_updated.connect(lire, CONNECT_ONE_SHOT)
				while lu.is_empty():
					await process_frame
				resultats[n]["%s@%.2f" % [c, f]] = lu
	for cle: String in resultats["homme"]:
		print("== ", cle)
		for n: String in ["ancien", "homme", "femme"]:
			var r: Dictionary = resultats[n].get(cle, {})
			if r.is_empty():
				continue
			print("  %-7s chev/hanch %.2f (%.3f/%.3f)  genoux %5.1f %5.1f  pieds %+5.1f %+5.1f  bassin %.3f tete %.3f" % [n, r.ratio, r.chevilles, r.hanches, r.genou_l, r.genou_r, r.pied_l, r.pied_r, r.bassin, r.tete])
	var j := _arg("json", "")
	if j != "":
		var fa := FileAccess.open(j, FileAccess.WRITE)
		fa.store_string(JSON.stringify(resultats, "  "))
	quit()
