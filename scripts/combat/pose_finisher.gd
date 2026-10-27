class_name PoseFinisher
extends SkeletonModifier3D
## Pose de la VICTIME d'un finisher, ajoutée par-dessus l'animation (comme ReactionOs) : canaux en radians posés à chaque image
## par SequenceFinisher (scripts/combat/finishers.gd décrit leurs clés). Repère du CORPS (repere : base monde de l'ennemi ;
## +Z = devant, +X = sa gauche vue de face… peu importe : seules les rotations autour de ses axes comptent) :
##   buste    flexion avant du buste (+ : se plie en avant, sur la lame ; − : se cambre en arrière)
##   torsion  rotation du buste autour de la verticale
##   lateral  inclinaison du buste sur le côté
##   tete     tête et nuque (+ : tombe en avant ; − : rejetée en arrière)
##   bras     les deux bras se lèvent vers l'avant (agrippe la lame / l'agresseur ; − : écartés en arrière)
##   coudes   flexion des coudes
##   genoux   flexion des genoux (le bassin descend : SequenceFinisher abaisse le modèle d'autant)
##   tremble  amplitude des spasmes (bruit rapide sur buste, tête, bras)
## Os du gabarit RIG18 / Quaternius (draugr, squelette, bandit) : spine_01-03, neck_01, Head, upperarm/lowerarm, thigh/calf.

var repere := Basis()
var buste := 0.0
var torsion := 0.0
var lateral := 0.0
var tete := 0.0
var bras := 0.0
var coudes := 0.0
var genoux := 0.0
var tremble := 0.0
var _t := 0.0
var _ids := {}

const BUSTE := {"spine_01": 0.3, "spine_02": 0.3, "spine_03": 0.4}
const TETE := {"neck_01": 0.4, "Head": 0.6}

func _id(sq: Skeleton3D, nom: String) -> int:
	if not _ids.has(nom):
		_ids[nom] = sq.find_bone(nom)
	return _ids[nom]

## Tourne l'os `nom` de `angle` autour de l'axe MONDE `axe` (par-dessus sa pose courante).
func _tourner(sq: Skeleton3D, nom: String, axe: Vector3, angle: float) -> void:
	if absf(angle) < 1e-4:
		return
	var i := _id(sq, nom)
	if i < 0:
		return
	var base_sq := sq.global_transform.basis.orthonormalized()
	var g := sq.get_bone_global_pose(i).basis.orthonormalized()
	var axe_os := ((base_sq * g).inverse() * axe).normalized()
	sq.set_bone_pose_rotation(i, sq.get_bone_pose_rotation(i) * Quaternion(axe_os, angle))

func _process_modification_with_delta(delta: float) -> void:
	var sq := get_skeleton()
	if sq == null:
		return
	_t += minf(delta, 0.05)
	var droite := repere.x.normalized()
	var haut := repere.y.normalized()
	var avant := repere.z.normalized()
	# spasmes : sinus incommensurables (pas de hasard par image : même rendu à toute cadence)
	var s1 := sin(_t * 31.0) * 0.6 + sin(_t * 47.0) * 0.4
	var s2 := sin(_t * 37.0 + 1.3) * 0.6 + sin(_t * 59.0) * 0.4
	var b := buste + tremble * s1 * 0.5
	var h := tete + tremble * s2
	for nom: String in BUSTE:
		var k: float = BUSTE[nom]
		_tourner(sq, nom, droite, b * k)
		_tourner(sq, nom, haut, torsion * k)
		_tourner(sq, nom, avant, lateral * k)
	for nom: String in TETE:
		_tourner(sq, nom, droite, h * float(TETE[nom]))
	# bras : une rotation autour de l'axe droite du corps lève le bras pendant vers l'avant (signe −)
	var br := bras + tremble * s2 * 0.6
	for c in ["l", "r"]:
		_tourner(sq, "upperarm_" + c, droite, -br)
		_tourner(sq, "lowerarm_" + c, droite, -coudes)
	if genoux > 1e-3:
		for c in ["l", "r"]:
			_tourner(sq, "thigh_" + c, droite, -genoux)
			_tourner(sq, "calf_" + c, droite, genoux * 2.0)
			_tourner(sq, "foot_" + c, droite, -genoux)

## Abaissement du bassin (m) pour des genoux pliés de `g` rad (cuisse + jambe ≈ 0,9 m à l'échelle 1).
static func baisse(g: float, echelle := 1.0) -> float:
	return 0.9 * echelle * (1.0 - cos(g))
