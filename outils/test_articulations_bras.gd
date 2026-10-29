extends SceneTree
## Continuité du bras droit dans les clips des coups (bras_epee.tres, retarget Mixamo) : pas d'avant-bras « disloqué ».
##   godot --headless --path . --script res://outils/test_articulations_bras.gd [-- --detail]
## Sans scène de jeu : le squelette de bras_fps.glb est posé directement par les pistes des clips, échantillonnées à 60 et
## 30 i/s. Critères, pour chaque coup (combo 1-2-3, charge et coup puissant) :
##   - aucun os ne change de longueur (épaule → coude, coude → poignet, ±1 mm) ;
##   - torsion autour de l'axe de l'os, d'une image à l'autre (bras, avant-bras, main) : ≤ 15° à 60 i/s, ≤ 30° à 30 i/s ;
##   - coude sans saut : plan épaule-coude-poignet ≤ 20° par image à 60 i/s, et accélération du coude bornée
##     (|E(i+1) - 2 E(i) + E(i-1)| ≤ ACCEL_COUDE à 60 i/s) ;
##   - raccords : chaque coup commence et finit sur la tenue de repos (clip « repos »), la charge finit où le coup puissant
##     commence (≤ 1° par os) — retour en garde sans à-coup.

const BRAS := preload("res://assets/modeles/joueur/bras_fps.glb")
const BIBLIOTHEQUE := preload("res://assets/animations/bras_epee.tres")
const CLIPS := ["coup_a", "coup_b", "coup_c", "charge_lourd", "lourd"]
const OS_ANIMES := ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]
const TORSION_MAX_60 := 15.0
const TORSION_MAX_30 := 30.0
const PLAN_MAX_60 := 20.0
const ACCEL_COUDE := 0.10
const RACCORD_MAX := 1.0

var _ok := true
var sq: Skeleton3D
var detail := false


func _init() -> void:
	_tester.call_deferred()


func _verif(cond: bool, msg: String) -> void:
	print(("OK     " if cond else "ECHEC  ") + msg)
	if not cond:
		_ok = false


func _squelette(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _squelette(c)
		if s:
			return s
	return null


## Pose le squelette à l'instant t du clip (pistes de rotation et de position des os animés).
func _poser(anim: Animation, t: float) -> void:
	for i in anim.get_track_count():
		var chemin := String(anim.track_get_path(i))
		var os := chemin.get_slice(":", 1)
		var b := sq.find_bone(os)
		if b < 0:
			continue
		match anim.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				sq.set_bone_pose_rotation(b, anim.rotation_track_interpolate(i, t))
			Animation.TYPE_POSITION_3D:
				sq.set_bone_pose_position(b, anim.position_track_interpolate(i, t))


## Torsion (degrés) d'une rotation autour de l'axe Y local de l'os (décomposition balancement-torsion).
static func _torsion(q: Quaternion) -> float:
	var t := Quaternion(0.0, q.y, 0.0, q.w)
	if t.length() < 1e-9:
		return 0.0
	t = t.normalized()
	return rad_to_deg(2.0 * atan2(t.y, t.w)) if t.w >= 0.0 else rad_to_deg(2.0 * atan2(-t.y, -t.w))


func _echantillons(anim: Animation, freq: float) -> Array:
	var n := floori(anim.length * freq + 1e-6) + 1
	var out := []
	for i in n:
		var t := minf(i / freq, anim.length)
		_poser(anim, t)
		var p := {}
		for nom in OS_ANIMES:
			p[nom] = sq.get_bone_pose_rotation(sq.find_bone(nom))
		var ep := sq.get_bone_global_pose(sq.find_bone("upperarm_r")).origin
		var co := sq.get_bone_global_pose(sq.find_bone("lowerarm_r")).origin
		var po := sq.get_bone_global_pose(sq.find_bone("hand_r")).origin
		p["t"] = t
		p["epaule"] = ep
		p["coude"] = co
		p["poignet"] = po
		out.append(p)
	return out


func _ecart_pose(a: Dictionary, b: Dictionary) -> float:
	var m := 0.0
	for nom in OS_ANIMES:
		m = maxf(m, rad_to_deg((a[nom] as Quaternion).angle_to(b[nom])))
	return m


func _tester() -> void:
	detail = "--detail" in OS.get_cmdline_user_args()
	var bras: Node3D = BRAS.instantiate()
	root.add_child(bras)
	sq = _squelette(bras)
	_verif(sq != null, "squelette de bras_fps.glb trouvé")
	if sq == null:
		quit(1)
		return
	var l1_ref := sq.get_bone_global_rest(sq.find_bone("upperarm_r")).origin.distance_to(sq.get_bone_global_rest(sq.find_bone("lowerarm_r")).origin)
	var l2_ref := sq.get_bone_global_rest(sq.find_bone("lowerarm_r")).origin.distance_to(sq.get_bone_global_rest(sq.find_bone("hand_r")).origin)
	var repos: Animation = BIBLIOTHEQUE.get_animation("repos")
	var pose_repos: Dictionary = _echantillons(repos, 60.0)[0]
	var bords := {}
	for clip in CLIPS:
		var anim: Animation = BIBLIOTHEQUE.get_animation(clip)
		_verif(anim != null, "%s : clip présent" % clip)
		if anim == null:
			continue
		var e60 := _echantillons(anim, 60.0)
		var e30 := _echantillons(anim, 30.0)
		bords[clip] = [e60[0], e60[-1]]
		# longueurs
		var dl := 0.0
		for p in e60:
			dl = maxf(dl, absf((p["epaule"] as Vector3).distance_to(p["coude"]) - l1_ref))
			dl = maxf(dl, absf((p["coude"] as Vector3).distance_to(p["poignet"]) - l2_ref))
		_verif(dl <= 0.001, "%s : longueurs du bras constantes (écart max %.4f m)" % [clip, dl])
		# torsions d'une image à l'autre
		for cas in [[e60, TORSION_MAX_60, 60], [e30, TORSION_MAX_30, 30]]:
			var ech: Array = cas[0]
			var pire := {}
			var ou := {}
			for nom in ["upperarm_r", "lowerarm_r", "hand_r"]:
				pire[nom] = 0.0
				ou[nom] = 0.0
			for i in range(1, ech.size()):
				for nom in ["upperarm_r", "lowerarm_r", "hand_r"]:
					var d := absf(_torsion((ech[i - 1][nom] as Quaternion).inverse() * ech[i][nom]))
					if d > pire[nom]:
						pire[nom] = d
						ou[nom] = ech[i]["t"]
			var lim: float = cas[1]
			_verif(pire["upperarm_r"] <= lim and pire["lowerarm_r"] <= lim and pire["hand_r"] <= lim,
				"%s : torsion par image à %d i/s ≤ %.0f° (bras %.1f° à %.3f s, avant-bras %.1f° à %.3f s, main %.1f° à %.3f s)" % [
					clip, cas[2], lim, pire["upperarm_r"], ou["upperarm_r"], pire["lowerarm_r"], ou["lowerarm_r"], pire["hand_r"], ou["hand_r"]])
		# coude : plan et accélération
		var plan := 0.0
		var t_plan := 0.0
		var acc := 0.0
		var t_acc := 0.0
		for i in range(1, e60.size()):
			var a: Dictionary = e60[i - 1]
			var b: Dictionary = e60[i]
			var na: Vector3 = ((a["coude"] as Vector3) - a["epaule"]).cross((a["poignet"] as Vector3) - a["coude"])
			var nb: Vector3 = ((b["coude"] as Vector3) - b["epaule"]).cross((b["poignet"] as Vector3) - b["coude"])
			if na.length() > 1e-6 and nb.length() > 1e-6:
				var d := rad_to_deg(na.angle_to(nb))
				if d > plan:
					plan = d
					t_plan = b["t"]
			if i + 1 < e60.size():
				var c: Dictionary = e60[i + 1]
				var ac := ((c["coude"] as Vector3) - 2.0 * (b["coude"] as Vector3) + (a["coude"] as Vector3)).length()
				if ac > acc:
					acc = ac
					t_acc = b["t"]
		_verif(plan <= PLAN_MAX_60, "%s : plan du coude continu (%.1f° par image max à %.3f s ; ≤ %.0f)" % [clip, plan, t_plan, PLAN_MAX_60])
		_verif(acc <= ACCEL_COUDE, "%s : coude sans saut (accélération %.3f m par image² max à %.3f s ; ≤ %.2f)" % [clip, acc, t_acc, ACCEL_COUDE])
		if detail:
			for i in range(1, e60.size()):
				print("   %s t=%.3f torsion bras %+5.1f avant-bras %+5.1f main %+5.1f" % [clip, e60[i]["t"],
					_torsion((e60[i - 1]["upperarm_r"] as Quaternion).inverse() * e60[i]["upperarm_r"]),
					_torsion((e60[i - 1]["lowerarm_r"] as Quaternion).inverse() * e60[i]["lowerarm_r"]),
					_torsion((e60[i - 1]["hand_r"] as Quaternion).inverse() * e60[i]["hand_r"])])
	# raccords avec la tenue de repos (retour en garde) et charge -> coup puissant
	for clip in ["coup_a", "coup_b", "coup_c"]:
		if bords.has(clip):
			var d0 := _ecart_pose(bords[clip][0], pose_repos)
			var d1 := _ecart_pose(bords[clip][1], pose_repos)
			_verif(d0 <= RACCORD_MAX and d1 <= RACCORD_MAX, "%s : part de la tenue de repos et y revient (écarts %.2f° / %.2f°)" % [clip, d0, d1])
	if bords.has("charge_lourd") and bords.has("lourd"):
		var d0 := _ecart_pose(bords["charge_lourd"][0], pose_repos)
		var d1 := _ecart_pose(bords["charge_lourd"][1], bords["lourd"][0])
		var d2 := _ecart_pose(bords["lourd"][1], pose_repos)
		_verif(d0 <= RACCORD_MAX and d1 <= RACCORD_MAX and d2 <= RACCORD_MAX,
			"coup puissant : repos → charge → coup → repos sans saut (écarts %.2f° / %.2f° / %.2f°)" % [d0, d1, d2])
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)

