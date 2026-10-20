extends SceneTree
## Mesure des traversées du squelette guerrier EN MOUVEMENT : sur chaque animation, 32 poses d'un cycle ; bouclier (points du disque,
## os lowerarm_l) et lame (points de la lame, os hand_r) contre des volumes d'exclusion du corps (cuisses, tibias, cage thoracique,
## bassin, tête, bras). Profondeur = rayon - distance à l'axe ; seuil de traversée = 1,5 cm.
##   godot --headless --path . --script res://outils/test_squelette_traversees.gd -- --nouvelle [--detail]
## Les coordonnées sont celles du modèle au repos (Godot : x, z -> y, -y -> z) tirées du script Blender.
const ANIMS := ["Idle", "Sword_Idle", "Walk", "Jog_Fwd", "Sprint", "Sword_Attack", "Punch_Cross", "Hit_Chest", "Hit_Head", "Death01"]
const SEUIL := 0.015
# volumes du corps : [nom, os, A, B, rayon] (axe A-B, repère modèle au repos, Godot)
const CORPS := [
	["cuisse_l", "thigh_l", Vector3(0.114, 0.971, -0.036), Vector3(0.114, 0.542, -0.036), 0.045],
	["cuisse_r", "thigh_r", Vector3(-0.114, 0.971, -0.036), Vector3(-0.114, 0.542, -0.036), 0.045],
	["tibia_l", "calf_l", Vector3(0.114, 0.542, -0.036), Vector3(0.114, 0.086, -0.088), 0.035],
	["tibia_r", "calf_r", Vector3(-0.114, 0.542, -0.036), Vector3(-0.114, 0.086, -0.088), 0.035],
	["cage", "spine_03", Vector3(0.0, 1.22, 0.0), Vector3(0.0, 1.46, 0.0), 0.11],
	["bassin", "pelvis", Vector3(0.0, 0.99, -0.01), Vector3(0.0, 0.99, -0.01), 0.10],
	["tete", "Head", Vector3(0.0, 1.72, -0.02), Vector3(0.0, 1.72, -0.02), 0.10],
	["bras_l", "upperarm_l", Vector3(0.212, 1.456, -0.065), Vector3(0.463, 1.456, -0.073), 0.035],
	["avbras_l", "lowerarm_l", Vector3(0.463, 1.456, -0.073), Vector3(0.706, 1.456, -0.065), 0.03],
	["bras_r", "upperarm_r", Vector3(-0.212, 1.456, -0.065), Vector3(-0.463, 1.456, -0.073), 0.035],
	["avbras_r", "lowerarm_r", Vector3(-0.463, 1.456, -0.073), Vector3(-0.706, 1.456, -0.065), 0.03],
]
# points testés : [nom, os, point (repère modèle au repos), contre quels volumes (préfixes ignorés)]
var _pts: Array = []
var _volumes: Array = []
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _b2g(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)

func _dist_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 1e-9 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _tester() -> void:
	var perso := SqueletteGuerrier.creer({"arme": "epee"})
	root.add_child(perso)
	var sq: Skeleton3D = perso.find_child("Skeleton3D", true, false)
	var ap: AnimationPlayer = perso.get_node("Animations")
	await process_frame
	# marqueurs : attachés aux os, posés au repos
	var att := {}
	for nom in ["thigh_l", "thigh_r", "calf_l", "calf_r", "spine_03", "pelvis", "Head", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_r"]:
		var ba := BoneAttachment3D.new()
		ba.bone_name = nom
		sq.add_child(ba)
		att[nom] = ba
	await process_frame
	await process_frame
	var marq := func(os_nom: String, p: Vector3) -> Node3D:
		var n := Node3D.new()
		att[os_nom].add_child(n)
		n.global_position = perso.to_global(p)
		return n
	for v in CORPS:
		_volumes.append({"nom": v[0], "a": marq.call(v[1], v[2]), "b": marq.call(v[1], v[3]), "r": v[4]})
	# bouclier : centre (0.600, -0.090, 1.456 Blender), rayon 0.225, plan XZ ; 17 points (centre, 8 sommets, 8 mi-rayons)
	var c := Vector3(0.600, 0.065 - 0.155, 1.456)
	var R := 0.225
	_pts.append(["bouclier", marq.call("lowerarm_l", _b2g(c.x, c.y - 0.03, c.z))])
	for k in 8:
		var a := deg_to_rad(22.5 + 45 * k)
		_pts.append(["bouclier", marq.call("lowerarm_l", _b2g(c.x + R * cos(a) * 1.08, c.y + 0.014, c.z + R * sin(a) * 1.08))])
		_pts.append(["bouclier", marq.call("lowerarm_l", _b2g(c.x + R * 0.5 * cos(a), c.y + 0.014, c.z + R * 0.5 * sin(a)))])
	# lame : 9 points de la poignée à la pointe (repère de la prise, cf. squelette_guerrier.py)
	var O := Vector3(-0.849425, 0.063159, 1.447565)
	var YB := Vector3(-0.24307, -0.969901, -0.014458)
	for k in 9:
		var p := O + YB * (0.12 + 0.67 * k / 8.0)
		_pts.append(["lame", marq.call("hand_r", _b2g(p.x, p.y, p.z))])
	await process_frame
	var detail := OS.get_cmdline_user_args().has("--detail")
	print("%-13s %-9s %s" % ["animation", "pire", "traversées (pose max : volume)"])
	for nom in ANIMS:
		if not ap.has_animation(nom):
			continue
		var dur := ap.get_animation(nom).length
		var pire := {}   # "bouclier>cage" -> [profondeur, t]
		var n_pose := 0
		for k in 32:
			ap.play(nom)
			ap.seek(dur * k / 32.0, true)
			ap.pause()
			for i in 2:
				await process_frame
			var viol := false
			for pt in _pts:
				var pos: Vector3 = (pt[1] as Node3D).global_position
				for vol in _volumes:
					var r: float = vol["r"]
					var d := _dist_seg(pos, (vol["a"] as Node3D).global_position, (vol["b"] as Node3D).global_position)
					# on ne teste pas un objet contre le bras qui le porte
					if pt[0] == "bouclier" and String(vol["nom"]).ends_with("_l") and String(vol["nom"]).begins_with("a"):
						continue
					if pt[0] == "bouclier" and vol["nom"] == "bras_l":
						continue
					if pt[0] == "lame" and String(vol["nom"]).ends_with("_r") and String(vol["nom"]).find("bras") >= 0:
						continue
					var prof := r - d
					if prof > SEUIL:
						var cle := "%s>%s" % [pt[0], vol["nom"]]
						viol = true
						if not pire.has(cle) or prof > pire[cle][0]:
							pire[cle] = [prof, k]
			if viol:
				n_pose += 1
		var txt := ""
		var maxi := 0.0
		for cle in pire:
			txt += " %s %.0f mm (pose %d)" % [cle, pire[cle][0] * 1000.0, pire[cle][1]]
			maxi = maxf(maxi, pire[cle][0])
		print("%-13s %3d/32 poses avec traversée, pire %.0f mm :%s" % [nom, n_pose, maxi * 1000.0, txt])
	SqueletteGuerrier.vider()
	Humain.vider()
	quit()
