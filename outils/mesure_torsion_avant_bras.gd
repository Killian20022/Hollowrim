extends SceneTree
## Mesure de la pronation des avant-bras dans les clips des coups (bras_epee.tres) : torsion propre de lowerarm (ce que
## porte l'os du coude) et torsion totale main / charnière du coude (TorsionAvantBras.decomposer), à 60 i/s.
##   godot --headless --path . --script res://outils/mesure_torsion_avant_bras.gd [-- --detail] [--tous : tous les clips]

const BRAS := preload("res://assets/modeles/joueur/bras_fps.glb")
const BIBLIOTHEQUE := preload("res://assets/animations/bras_epee.tres")
const CLIPS := ["repos", "coup_a", "coup_b", "coup_c", "charge_lourd", "lourd"]

var sq: Skeleton3D

func _init() -> void:
	_go.call_deferred()

func _squelette(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _squelette(c)
		if s:
			return s
	return null

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

func _go() -> void:
	var detail := "--detail" in OS.get_cmdline_user_args()
	var bras: Node3D = BRAS.instantiate()
	root.add_child(bras)
	sq = _squelette(bras)
	var il := sq.find_bone("lowerarm_r")
	var ih := sq.find_bone("hand_r")
	var clips: Array = CLIPS
	if "--tous" in OS.get_cmdline_user_args():
		clips = Array(BIBLIOTHEQUE.get_animation_list())
	for clip in clips:
		var anim: Animation = BIBLIOTHEQUE.get_animation(clip)
		var n := floori(anim.length * 60.0 + 1e-6) + 1
		var mn := [1e9, 1e9]
		var mx := [-1e9, -1e9]
		var pas := 0.0
		var prec := NAN
		for i in n:
			_poser(anim, minf(i / 60.0, anim.length))
			var d := TorsionAvantBras.decomposer(sq, il, ih)
			var tc := rad_to_deg(float(d[1]))
			var tt := rad_to_deg(float(d[2]))
			if not is_nan(prec):
				pas = maxf(pas, absf(wrapf(tt - prec, -180.0, 180.0)))
			prec = tt
			mn = [minf(mn[0], tc), minf(mn[1], tt)]
			mx = [maxf(mx[0], tc), maxf(mx[1], tt)]
			if detail:
				print("  %s t=%.3f coude %+6.1f total %+6.1f poignet %+6.1f" % [clip, i / 60.0, tc, tt, tt - tc])
		print("%-18s torsion du coude %+6.1f..%+6.1f°   torsion totale %+6.1f..%+6.1f° (pas max %.1f°/image)" % [clip, mn[0], mx[0], mn[1], mx[1], pas])
	quit(0)
