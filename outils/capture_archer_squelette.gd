extends SceneTree
## Gros plans EN JEU d'un archer (vraie crypte foret_test, rendu du jeu) : repos, marche, bander, tirer ; face, profil, trois-quarts ;
## plan entier + gros plan des mains et de l'arc. Le corps est celui que crée monde.creer_draugr (donc le vrai chemin du jeu).
##   godot --path . --script res://outils/capture_archer_squelette.gd -- --nouvelle --cible=squelette_archer|draugr_archer|ancien --sortie=<dossier>
## Écrit <pose>_<vue>_plan.png et <pose>_<vue>_mains.png ; affiche « CORPS ... » (méta tripo_ennemi, variante).
const SCENE := preload("res://scenes/foret_test.tscn")
const POSES := [["repos", "Idle", 0.5], ["marche", "Walk", 0.35], ["bander", "Pistol_Aim_Neutral", 0.6], ["tirer", "Pistol_Shoot", 0.12]]
const VUES := {"face": 0.0, "trois_quarts": 40.0, "profil": 90.0, "trois_quarts_droit": -50.0}
var _poses := {}
var _mains := {}

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _photo(chemin: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(chemin)

func _go() -> void:
	var sortie := _arg("sortie", "user://archer_squelette")
	DirAccess.make_dir_recursive_absolute(sortie)
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	current_scene = m
	var j: CharacterBody3D = m.joueur
	for i in 5:
		await physics_frame
	var t = m.tertre
	t._passer(true)
	# donjon bâti en fond (écran de chargement) : on attend la bascule puis la fin du fondu
	for i in 1200:
		if t.dedans:
			break
		await process_frame
	await create_timer(1.6, true, false, true).timeout
	m.post.set_shader_parameter("fondu", 0.0)
	var c: Node3D = t.crypte
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	j.global_position = c.to_global(Vector3(0.0, 0.1, -22.5))
	if j.mains.get("torche_lumiere") != null:
		j.mains.torche_lumiere.visible = true
	for k in 20:
		t._gerer_zones()
		await physics_frame
	for id in m.draugrs.keys():
		var d = m.draugrs[id]
		if is_instance_valid(d):
			d.visible = false
			d.process_mode = Node.PROCESS_MODE_DISABLED
			d.global_position += Vector3(0, -50, 0)
	var cible := _arg("cible", "squelette_archer")
	var type := "squelette_archer"
	var opts := {"ident": "photo_" + cible, "dort": false, "archer": true}
	match cible:
		"draugr_archer":
			type = "sbire"
		"ancien":
			opts["modele_ancien"] = true
	var lacet := c.global_rotation.y
	var spot := c.to_global(Vector3(0.0, 0.05, -27.0))
	var e = m.creer_draugr(type, spot, lacet, false, opts)
	e.global_position = spot
	await physics_frame
	e.set_physics_process(false)
	e.set_process(false)
	var mod: Node3D = e.modele
	print("CORPS cible=%s tripo=%s variante=%s" % [cible, mod.get_meta("tripo_ennemi", "-"), mod.get_meta("variante", "-")])
	# lumière d'appoint (la torche du joueur est derrière la caméra libre) : comme une torche tenue à 2 m
	var lum := OmniLight3D.new()
	lum.light_color = Color(1.0, 0.72, 0.45)
	lum.light_energy = 2.2
	lum.omni_range = 7.0
	root.add_child(lum)
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.current = true
	var sq := mod.find_child("Skeleton3D", true, false) as Skeleton3D
	# poses APRÈS les modificateurs (PoseArcher) : get_bone_global_pose hors de skeleton_updated rend la pose du clip seul
	sq.skeleton_updated.connect(func() -> void:
		for nom in ["upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r", "Head", "spine_03"]:
			_poses[nom] = sq.get_bone_global_pose(sq.find_bone(nom)).origin
		for cote in ["l", "r"]:
			_mains[cote] = sq.get_bone_global_pose(sq.find_bone("hand_" + cote)))
	var ap: AnimationPlayer = e.anim
	for p: Array in POSES:
		ap.speed_scale = 1.0
		ap.play(String(p[1]), 0.0)
		ap.seek(ap.current_animation_length * float(p[2]), true)
		ap.speed_scale = 0.0      # figé mais toujours « en lecture » (comme en jeu : PoseArcher lit le clip courant)
		for i in 4:
			await process_frame
		var gp := func(nom: String) -> Vector3: return sq.global_transform * (_poses.get(nom, Vector3.ZERO) as Vector3)
		var coude_l: float = rad_to_deg((gp.call("upperarm_l") - gp.call("lowerarm_l")).angle_to(gp.call("hand_l") - gp.call("lowerarm_l")))
		var coude_r: float = rad_to_deg((gp.call("upperarm_r") - gp.call("lowerarm_r")).angle_to(gp.call("hand_r") - gp.call("lowerarm_r")))
		print("POSE %s : main G-D %.2f m ; main D - tête %.2f m ; coude G %.0f° ; coude D %.0f° ; épaule G - main G %.2f m" % [p[0], (gp.call("hand_l") as Vector3).distance_to(gp.call("hand_r")),
			(gp.call("hand_r") as Vector3).distance_to(gp.call("Head")), coude_l, coude_r, (gp.call("upperarm_l") as Vector3).distance_to(gp.call("hand_l"))])
		for vue: String in VUES:
			var a := lacet + deg_to_rad(float(VUES[vue]))
			var dir := Basis(Vector3.UP, a) * Vector3(0, 0, 1)
			# plan entier
			cam.fov = 40.0
			cam.global_position = e.global_position + dir * 2.7 + Vector3(0, 1.2, 0)
			cam.look_at(e.global_position + Vector3(0, 0.95, 0))
			lum.global_position = e.global_position + dir * 2.0 + Vector3(0.6, 1.9, 0)
			await _photo(sortie.path_join("%s_%s_plan.png" % [p[0], vue]))
			# buste : les deux bras entiers, épaule -> doigts
			var bu: Vector3 = gp.call("spine_03")
			cam.fov = 40.0
			cam.global_position = bu + dir * 1.45 + Vector3(0, 0.05, 0)
			cam.look_at(bu + Vector3(0, -0.05, 0))
			await _photo(sortie.path_join("%s_%s_buste.png" % [p[0], vue]))
			# gros plan : milieu des deux mains (arc + main de corde)
			var hl: Vector3 = gp.call("hand_l")
			var hr: Vector3 = gp.call("hand_r")
			var cen := (hl + hr) * 0.5
			var ecart := maxf(hl.distance_to(hr), 0.35)
			cam.fov = 34.0
			cam.global_position = cen + dir * (ecart * 1.6 + 0.6) + Vector3(0, 0.12, 0)
			cam.look_at(cen)
			await _photo(sortie.path_join("%s_%s_mains.png" % [p[0], vue]))
			# gros plans de chaque main (poignée de l'arc à gauche, corde à droite), au point de prise
			for cote in ["l", "r"]:
				var pr: Dictionary = ((EnnemiTripo as Script).get_script_constant_map().get("PRISE_ARC", {}) as Dictionary).get(String(mod.get_meta("tripo_ennemi", "")), {})
				var loc: Vector3 = pr.get("paume_" + cote, Vector3(0, 0.08, 0))
				var pm: Vector3 = sq.global_transform * ((_mains[cote] as Transform3D) * loc)
				cam.fov = 30.0
				cam.global_position = pm + dir * 0.75 + Vector3(0, 0.12, 0)
				cam.look_at(pm)
				await _photo(sortie.path_join("%s_%s_main_%s.png" % [p[0], vue, "g" if cote == "l" else "d"]))
	print("FIN")
	quit(0)
