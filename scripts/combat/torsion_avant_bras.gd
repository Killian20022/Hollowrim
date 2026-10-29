extends SkeletonModifier3D
class_name TorsionAvantBras
## Os de torsion des avant-bras (bras_fps.glb : lowerarm_twist_01_l/r, lowerarm_twist_02_l/r, enfants de lowerarm).
## Dernier modificateur du squelette des bras (après animations, IK à deux os, orientation des mains, couche passive) :
##   - la pronation / supination (rotation de la main autour de l'axe coude → poignet) est mesurée par rapport à la
##     charnière du coude (l'avant-bras sans torsion propre, porté par le bras : décomposition balancement-torsion) ;
##   - lowerarm est ramené sur la charnière (torsion 0 au coude : le coude ne vrille plus) ;
##   - la torsion est répartie sur les os de torsion (FRACTIONS : moitié au milieu, totalité au poignet), dont les poids de
##     peau vont progressivement du coude au poignet ;
##   - la main garde EXACTEMENT son repère (l'épée, la torche, les sorts ne bougent pas d'un pixel) : seule la peau de
##     l'avant-bras change.
## Sans os de torsion dans le squelette, ne fait rien.

const COTES := ["l", "r"]
## Part de la torsion totale portée par chaque os de torsion (01 au milieu de l'avant-bras, 02 au poignet).
const FRACTIONS := [0.5, 1.0]
## Torsion totale bornée (degrés, depuis la pose de repos) : au-delà, le poignet portera le reste (anatomie : ~±90° de
## part et d'autre de la position neutre).
const TORSION_MAX := 170.0

## Dernière torsion totale mesurée par côté (degrés) : outils et tests.
var torsion := {"l": 0.0, "r": 0.0}
## Dernière torsion propre de lowerarm retirée (degrés) : ce que portait l'os du coude avant correction.
var torsion_coude := {"l": 0.0, "r": 0.0}

var _os := {}
var _sq_os: Skeleton3D


func _indices(sq: Skeleton3D) -> void:
	_os.clear()
	_sq_os = sq
	for c in COTES:
		var ids := [sq.find_bone("upperarm_" + c), sq.find_bone("lowerarm_" + c), sq.find_bone("hand_" + c),
			sq.find_bone("lowerarm_twist_01_" + c), sq.find_bone("lowerarm_twist_02_" + c)]
		if not ids.has(-1):
			_os[c] = ids


## Mesure, dans le repère du bras (upperarm), de la charnière du coude et de la torsion :
## renvoie [base de lowerarm sans torsion, torsion propre de lowerarm (rad), torsion totale main/charnière (rad), axe].
static func decomposer(sq: Skeleton3D, il: int, ih: int) -> Array:
	var rl := sq.get_bone_rest(il).basis.orthonormalized()
	var pl := sq.get_bone_pose(il)
	var bl := pl.basis.orthonormalized()
	var axe_local := sq.get_bone_rest(ih).origin.normalized()   # axe coude → poignet dans le repère de lowerarm
	var a0 := (rl * axe_local).normalized()
	var a := (bl * axe_local).normalized()
	var blh := Basis(Quaternion(a0, a)) * rl                     # avant-bras porté par le bras, sans torsion propre
	var t_coude := _torsion_autour(Quaternion(bl * blh.inverse()), a)
	var bh := bl * sq.get_bone_pose(ih).basis.orthonormalized()  # main dans le repère du bras
	var rh := sq.get_bone_rest(ih).basis.orthonormalized()
	var t_total := _torsion_autour(Quaternion(bh * (blh * rh).inverse()), a)
	return [blh, t_coude, t_total, a]


## Angle (rad, -PI..PI) de la composante de torsion de q autour de l'axe unitaire a.
static func _torsion_autour(q: Quaternion, a: Vector3) -> float:
	var v := Vector3(q.x, q.y, q.z)
	var p := v.dot(a)
	if absf(p) < 1e-9 and absf(q.w) < 1e-9:
		return PI
	var ang := 2.0 * atan2(p, q.w)
	return wrapf(ang, -PI, PI)


func _process_modification_with_delta(_dt: float) -> void:
	var sq := get_skeleton()
	if sq == null:
		return
	if sq != _sq_os:
		_indices(sq)
	for c in _os:
		var ids: Array = _os[c]
		var il: int = ids[1]
		var ih: int = ids[2]
		var d := decomposer(sq, il, ih)
		var blh: Basis = d[0]
		var t: float = d[2]
		# continuité : pas de saut de ±360° d'une image à l'autre
		var prec := deg_to_rad(float(torsion[c]))
		t = prec + wrapf(t - prec, -PI, PI)
		var lim := deg_to_rad(TORSION_MAX)
		t = clampf(t, -lim, lim)
		torsion[c] = rad_to_deg(t)
		torsion_coude[c] = rad_to_deg(float(d[1]))
		var pl := sq.get_bone_pose(il)
		var ph := sq.get_bone_pose(ih)
		var pl2 := Transform3D(blh, pl.origin)
		var ph2 := pl2.affine_inverse() * pl * ph                   # main : repère global inchangé
		sq.set_bone_pose(il, pl2)
		sq.set_bone_pose(ih, ph2)
		var axe_local := sq.get_bone_rest(ih).origin.normalized()
		for k in FRACTIONS.size():
			var it: int = ids[3 + k]
			var r := sq.get_bone_rest(it)
			var ang := t * float(FRACTIONS[k])
			var ax := (r.basis.orthonormalized().inverse() * axe_local).normalized()
			sq.set_bone_pose(it, Transform3D(r.basis * Basis(ax, ang), r.origin))
