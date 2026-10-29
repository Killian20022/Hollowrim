extends SceneTree
## Os de torsion des avant-bras (bras_fps.glb + TorsionAvantBras) : la pronation va en douceur du coude au poignet.
##   godot --headless --path . --script res://outils/test_torsion_avant_bras.gd [-- --detail]
## Rig : lowerarm_twist_01/02_l/r présents, enfants de lowerarm, même orientation au repos, sur l'axe coude → poignet ;
## les peaux de la peau, de la manche et du brassard les utilisent.
## Clips des coups (bras_epee.tres, 60 i/s), modificateur appliqué sur la pose des pistes :
##   - la main (donc l'épée) ne bouge pas : repère global identique (≤ 0,1 mm, ≤ 0,01°) ;
##   - lowerarm n'a plus de torsion propre sur la charnière du coude (≤ 0,5°) ;
##   - twist_01 porte un tiers de la torsion totale, twist_02 la totalité (≤ 0,5°, TorsionAvantBras.FRACTIONS) ;
##   - écart de torsion entre deux os voisins de l'avant-bras ≤ ECART_MAX ; torsion totale continue d'une image à
##     l'autre (≤ PAS_MAX à 60 i/s).

const BRAS := preload("res://assets/modeles/joueur/bras_fps.glb")
const BIBLIOTHEQUE := preload("res://assets/animations/bras_epee.tres")
const CLIPS := ["repos", "coup_a", "coup_b", "coup_c", "charge_lourd", "lourd"]
const ECART_MAX := 60.0
const PAS_MAX := 20.0

var _ok := true
var sq: Skeleton3D


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


func _globale(i: int) -> Transform3D:
	var t := Transform3D()
	while i >= 0:
		t = sq.get_bone_pose(i) * t
		i = sq.get_bone_parent(i)
	return t


func _poser(anim: Animation, t: float) -> void:
	for i in anim.get_track_count():
		var b := sq.find_bone(String(anim.track_get_path(i)).get_slice(":", 1))
		if b < 0:
			continue
		match anim.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				sq.set_bone_pose_rotation(b, anim.rotation_track_interpolate(i, t))
			Animation.TYPE_POSITION_3D:
				sq.set_bone_pose_position(b, anim.position_track_interpolate(i, t))


## Torsion (degrés) de l'os `it` par rapport à lowerarm autour de l'axe coude → poignet.
func _torsion_os(il: int, it: int, ih: int) -> float:
	var axe := sq.get_bone_rest(ih).origin.normalized()
	var q := Quaternion((sq.get_bone_pose(it).basis * sq.get_bone_rest(it).basis.inverse()).orthonormalized())
	return rad_to_deg(TorsionAvantBras._torsion_autour(q, axe))


func _tester() -> void:
	var detail := "--detail" in OS.get_cmdline_user_args()
	var bras: Node3D = BRAS.instantiate()
	root.add_child(bras)
	sq = _squelette(bras)
	_verif(sq != null, "squelette de bras_fps.glb trouvé")
	if sq == null:
		quit(1)
		return
	# --- rig
	for c in ["l", "r"]:
		var il := sq.find_bone("lowerarm_" + c)
		var ih := sq.find_bone("hand_" + c)
		var axe := sq.get_bone_rest(ih).origin.normalized()
		for n in ["lowerarm_twist_01_", "lowerarm_twist_02_"]:
			var it := sq.find_bone(n + c)
			_verif(it >= 0, "%s%s présent" % [n, c])
			if it < 0:
				continue
			var r := sq.get_bone_rest(it)
			var ecart := rad_to_deg(Quaternion(r.basis.orthonormalized()).angle_to(Quaternion.IDENTITY))
			var hors_axe := (r.origin - axe * axe.dot(r.origin)).length()
			_verif(sq.get_bone_parent(it) == il and ecart < 0.05 and hors_axe < 0.001,
				"%s%s : enfant de lowerarm, même orientation (%.3f°), sur l'axe (%.4f m)" % [n, c, ecart, hors_axe])
	var peaux := {}
	for mi: MeshInstance3D in bras.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null:
			continue
		for k in mi.skin.get_bind_count():
			var nom := String(mi.skin.get_bind_name(k))
			if nom.begins_with("lowerarm_twist_"):
				peaux[mi.name] = true
	for n in ["peau_bras", "manches", "brassard_r", "brassard_l", "revers_r", "gants"]:
		_verif(peaux.has(n), "%s : poids sur les os de torsion" % n)
	# --- clips des coups
	var tb := TorsionAvantBras.new()
	var il := sq.find_bone("lowerarm_r")
	var ih := sq.find_bone("hand_r")
	var it1 := sq.find_bone("lowerarm_twist_01_r")
	var it2 := sq.find_bone("lowerarm_twist_02_r")
	for clip in CLIPS:
		var anim: Animation = BIBLIOTHEQUE.get_animation(clip)
		var n := floori(anim.length * 60.0 + 1e-6) + 1
		var d_main := 0.0
		var d_rot := 0.0
		var coude := 0.0
		var frac := 0.0
		var ecart := 0.0
		var pas := 0.0
		var t_min := 1e9
		var t_max := -1e9
		var prec := NAN
		var avant_max := 0.0
		for i in n:
			_poser(anim, minf(i / 60.0, anim.length))
			avant_max = maxf(avant_max, absf(rad_to_deg(float(TorsionAvantBras.decomposer(sq, il, ih)[1]))))
			var h0 := _globale(ih)
			tb.appliquer(sq)
			var h1 := _globale(ih)
			d_main = maxf(d_main, h0.origin.distance_to(h1.origin))
			# écart d'orientation par les axes (angle_to en flottants 32 bits plafonne vers 0,05°)
			for k in 3:
				d_rot = maxf(d_rot, rad_to_deg((h0.basis[k] - h1.basis[k]).length()))
			var d := TorsionAvantBras.decomposer(sq, il, ih)
			coude = maxf(coude, absf(rad_to_deg(float(d[1]))))
			var t := float(tb.torsion["r"])
			var t1 := _torsion_os(il, it1, ih)
			var t2 := _torsion_os(il, it2, ih)
			frac = maxf(frac, maxf(absf(t1 - t * float(TorsionAvantBras.FRACTIONS[0])), absf(t2 - t * float(TorsionAvantBras.FRACTIONS[1]))))
			ecart = maxf(ecart, maxf(absf(t1), maxf(absf(t2 - t1), absf(rad_to_deg(float(d[2])) - t2))))
			if not is_nan(prec):
				pas = maxf(pas, absf(t - prec))
			prec = t
			t_min = minf(t_min, t)
			t_max = maxf(t_max, t)
			if detail:
				print("   %s t=%.3f torsion %+6.1f  twist_01 %+6.1f  twist_02 %+6.1f" % [clip, i / 60.0, t, t1, t2])
		_verif(d_main <= 0.0001 and d_rot <= 0.01, "%s : main inchangée (%.6f m, %.4f°)" % [clip, d_main, d_rot])
		_verif(coude <= 0.5, "%s : coude sans torsion propre (%.2f° ; avant : jusqu'à %.0f°)" % [clip, coude, avant_max])
		_verif(frac <= 0.5, "%s : twist_01 = 1/3, twist_02 = totalité (écart %.2f°)" % [clip, frac])
		_verif(ecart <= ECART_MAX, "%s : torsion répartie, écart entre os voisins %.1f° ≤ %.0f (torsion %+.0f..%+.0f°)" % [clip, ecart, ECART_MAX, t_min, t_max])
		_verif(pas <= PAS_MAX, "%s : torsion continue, %.1f° par image max à 60 i/s ≤ %.0f" % [clip, pas, PAS_MAX])
	tb.free()
	print("RESULTAT : ", "OK" if _ok else "ECHEC")
	quit(0 if _ok else 1)
