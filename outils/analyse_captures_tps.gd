extends SceneTree
## Analyse des captures du corps à la 3e personne (assets/animations/corps_coups_tps.res) : par image (30 i/s), vitesse
## angulaire (repère du squelette) de la main droite, de l'avant-bras et du buste, sauts (discontinuités de la capture), et écart de
## la pose à l'image de départ (retour à la garde ?).
##   godot --headless --path . --script res://outils/analyse_captures_tps.gd -- [--clips=slash_1,slash_2]
const BIB := preload("res://assets/animations/corps_coups_tps.res")
const CORPS := "res://assets/modeles/humains/homme_vetu.glb"
const OS_VUS := ["pelvis", "spine_03", "upperarm_r", "lowerarm_r", "hand_r"]

var sq: Skeleton3D

func _init() -> void:
	var racine: Node3D = (load(CORPS) as PackedScene).instantiate()
	sq = racine.find_child("Skeleton3D", true, false)
	var filtre := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clips="):
			filtre = a.substr(8)
	for nom in BIB.get_animation_list():
		if filtre != "" and not (String(nom) in filtre.split(",")):
			continue
		_analyser(String(nom), BIB.get_animation(nom))
	quit(0)

func _globales(a: Animation, pistes: Dictionary, t: float) -> Dictionary:
	var g := {}
	for i in sq.get_bone_count():
		var q: Quaternion = a.rotation_track_interpolate(pistes[i], t) if pistes.has(i) else sq.get_bone_rest(i).basis.get_rotation_quaternion()
		var p := sq.get_bone_parent(i)
		g[i] = (g[p] as Quaternion) * q if p >= 0 else q
	return g

func _analyser(nom: String, a: Animation) -> void:
	var pistes := {}
	for k in a.get_track_count():
		if a.track_get_type(k) == Animation.TYPE_ROTATION_3D:
			var o := sq.find_bone(String(a.track_get_path(k)).get_slice(":", 1))
			if o >= 0:
				pistes[o] = k
	var n := int(round(a.length * 30.0))
	var idx: Array[int] = []
	for b in OS_VUS:
		idx.append(sq.find_bone(b))
	var g0 := _globales(a, pistes, 0.0)
	var prec := g0
	var ligne := "%s (%.2f s, %d images)" % [nom, a.length, n]
	print("CAPTURE ", ligne)
	for f in range(1, n + 1):
		var g := _globales(a, pistes, f / 30.0)
		var t := "  %3d" % f
		for k in idx.size():
			var i := idx[k]
			var v := rad_to_deg((g[i] as Quaternion).angle_to(prec[i]))
			var d := rad_to_deg((g[i] as Quaternion).angle_to(g0[i]))
			t += " | %-10s %5.1f %5.0f" % [OS_VUS[k], v, d]
		print("IMG ", nom, t)
		prec = g
