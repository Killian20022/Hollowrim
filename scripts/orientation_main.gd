extends SkeletonModifier3D
## Après l'IK des bras : oriente la main pour que l'objet tenu (épée, torche) suive sa
## cible, dans les limites d'un vrai poignet :
## - inclinaison latérale (radiale / cubitale) : l'axe de l'objet ne s'écarte pas de plus
##   de `deviation_max` du plan perpendiculaire à l'avant-bras ;
## - flexion / extension : les jointures ne tournent pas de plus de `flexion_max` autour
##   de l'axe de l'objet par rapport au prolongement de l'avant-bras.
## Les poses globales du squelette ne sont pas à jour pendant les modificateurs : on
## remonte la chaîne des poses locales (qui contiennent le résultat de l'IK).

var os := ""
var cible: Node3D          ## repère voulu pour la main (objet tenu × prise⁻¹)
var prise := Transform3D() ## repère de l'objet dans la main
var deviation_max := deg_to_rad(35.0)
var flexion_max := deg_to_rad(55.0)
## Angle permis entre l'axe de l'objet et l'avant-bras (rad). Négatif : déduit de deviation_max (plan perpendiculaire
## à ± deviation_max, comportement d'origine). Les coups d'épée (mains.gd) imposent un cône étroit autour d'un angle
## fixe : POIGNET RIGIDE, l'épée prolonge l'avant-bras.
var angle_min := -1.0
var angle_max := -1.0

func _globale(sq: Skeleton3D, i: int) -> Transform3D:
	var t := Transform3D()
	while i >= 0:
		t = sq.get_bone_pose(i) * t
		i = sq.get_bone_parent(i)
	return t

func _process_modification_with_delta(_dt: float) -> void:
	var sq := get_skeleton()
	if sq == null or cible == null or not is_instance_valid(cible):
		return
	var i := sq.find_bone(os)
	if i < 0:
		return
	var parent := _globale(sq, sq.get_bone_parent(i))
	var main := sq.get_bone_pose(i)
	# avant-bras : du coude au poignet (repère du squelette)
	var f := (parent * main.origin - parent.origin).normalized()
	# objet tel que voulu par la pose
	var objet := (sq.global_transform.affine_inverse() * cible.global_transform * prise).basis.orthonormalized()
	var a := objet.y.normalized()
	# inclinaison bornée : angle objet / avant-bras dans [amin, amax]
	var amin := angle_min if angle_min >= 0.0 else PI * 0.5 - deviation_max
	var amax := angle_max if angle_max >= 0.0 else PI * 0.5 + deviation_max
	var alpha := acos(clampf(a.dot(f), -1.0, 1.0))
	if alpha < amin or alpha > amax:
		var plan := a - f * a.dot(f)
		if plan.length_squared() < 1e-8:
			plan = f.cross(Vector3.UP) if absf(f.y) < 0.9 else f.cross(Vector3.RIGHT)
		plan = plan.normalized()
		var ac := clampf(alpha, amin, amax)
		a = (f * cos(ac) + plan * sin(ac)).normalized()
	# jointures dans le prolongement de l'avant-bras, flexion bornée vers la pose voulue
	var neutre := (f - a * a.dot(f)).normalized()
	var voulu := (objet.x - a * a.dot(objet.x)).normalized()
	var angle := neutre.signed_angle_to(voulu, a)
	var x := neutre.rotated(a, clampf(angle, -flexion_max, flexion_max))
	var repere := Basis(x, a, x.cross(a)) * prise.basis.orthonormalized().inverse()
	sq.set_bone_pose_rotation(i, (parent.basis.orthonormalized().inverse() * repere.orthonormalized()).get_rotation_quaternion())
