class_name PiedsAuSol
extends SkeletonModifier3D
## Les pieds épousent le sol (terrain irrégulier, pentes), à l'arrêt comme en marche.
##
##   PiedsAuSol.equiper(personnage, corps_characterbody)
##
## À chaque image, APRÈS l'animation : un rayon descend sous chaque pied ; le pied suit
## l'animation mais décalé de la seule différence entre le sol réel sous lui et le sol plat
## sous le CharacterBody3D (origine aux pieds) : la foulée est conservée. Le bassin descend
## du pied le plus bas, une IK à deux os (TwoBoneIK3D) replie les jambes, le pied s'incline
## selon la normale du sol (angle limité). Tout est lissé dans le temps.
## Ordre des nœuds sous le Skeleton3D : ce modificateur, puis l'IK, puis l'orienteur de pieds.
## Coupé automatiquement quand Ragdoll.declencher() est appelé (groupe « pieds_au_sol »).

## Active/désactive tout (équivalent de `active`, propage à l'IK et à l'orienteur).
var actif := true:
	set(v):
		actif = v
		set_active(v)
		if _ik:
			_ik.active = v
		if _orienteur:
			_orienteur.active = v
## Vitesse de lissage (1/s). Plus grand = plus réactif.
var lissage := 14.0
## Inclinaison maximale du pied (degrés).
var angle_max := 35.0
## Descente maximale du bassin (m) et montée maximale.
var bassin_bas_max := 0.45
var bassin_haut_max := 0.12
## Calques du sol (les CharacterBody3D sont toujours ignorés).
var masque := 1
## Marge de sécurité : le pied ne descend jamais sous le sol + ce rapport de sa hauteur de repos.
var garde := 0.5

var corps: CharacterBody3D
var _ik: TwoBoneIK3D
var _orienteur: Orienteur
var _cibles: Array[Node3D] = []
var _poles: Array[Node3D] = []
var _os := {}                       # indices : pelvis, cuisse[2], mollet[2], pied[2]
var _decal := [0.0, 0.0]
var _rot: Array[Quaternion] = [Quaternion(), Quaternion()]
var _base_pied: Array[Basis] = [Basis(), Basis()]
var _finale := {}                   # os → pose globale finale (bassin, jambes) de la dernière image
var _h_repos := 0.08
var _avant := Vector3.BACK

## Pose globale d'un os (repère du squelette) reconstruite depuis les poses LOCALES : dans un
## modificateur, get_bone_global_pose() peut rendre une valeur périmée (cache), pas get_bone_pose().
static func pose_globale(sq: Skeleton3D, i: int) -> Transform3D:
	var t := sq.get_bone_pose(i)
	var p := sq.get_bone_parent(i)
	while p >= 0:
		t = sq.get_bone_pose(p) * t
		p = sq.get_bone_parent(p)
	return t

## Pose un os à une pose globale donnée en modifiant sa pose locale (parents déjà à jour).
static func poser_globale(sq: Skeleton3D, i: int, voulue: Transform3D) -> void:
	var p := sq.get_bone_parent(i)
	var local := (pose_globale(sq, p).affine_inverse() if p >= 0 else Transform3D.IDENTITY) * voulue
	sq.set_bone_pose_position(i, local.origin)
	sq.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())

## Orienteur de pieds : après l'IK, applique l'inclinaison au sol aux os des pieds.
class Orienteur extends SkeletonModifier3D:
	var pilote: PiedsAuSol
	func _process_modification() -> void:
		var sq := get_skeleton()
		if sq == null or pilote == null:
			return
		var inv := sq.global_transform.basis.inverse()
		for k in 2:
			var i: int = pilote._os["pied"][k]
			var pose := PiedsAuSol.pose_globale(sq, i)
			var voulue := Basis(pilote._rot[k]) * pilote._base_pied[k]
			PiedsAuSol.poser_globale(sq, i, Transform3D(inv * voulue, pose.origin))
		# pose finale du bassin et des jambes, pour pouvoir la rendre définitive (ragdoll)
		for i: int in pilote._chaine():
			pilote._finale[i] = PiedsAuSol.pose_globale(sq, i)

static func equiper(perso: Node3D, corps_porteur: CharacterBody3D) -> Node:
	var sq := perso.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null:
		return null
	var p := PiedsAuSol.new()
	p.name = "PiedsAuSol"
	p.corps = corps_porteur
	sq.add_child(p)
	p._construire(sq)
	return p

func _construire(sq: Skeleton3D) -> void:
	add_to_group("pieds_au_sol")
	_os = {"pelvis": sq.find_bone("pelvis"), "cuisse": [], "mollet": [], "pied": []}
	var cotes := ["l", "r"]
	for c in cotes:
		_os["cuisse"].append(sq.find_bone("thigh_" + c))
		_os["mollet"].append(sq.find_bone("calf_" + c))
		_os["pied"].append(sq.find_bone("foot_" + c))
	var pied := sq.get_bone_global_rest(_os["pied"][0]).origin
	_h_repos = pied.y
	var ib := sq.find_bone("ball_l")      # RIG18 : pas d'orteils, le pied regarde +Z du modele
	if ib >= 0:
		var orteil := sq.get_bone_global_rest(ib).origin
		_avant = Vector3(orteil.x - pied.x, 0.0, orteil.z - pied.z).normalized()
	_ik = TwoBoneIK3D.new()
	_ik.name = "IKJambes"
	_orienteur = Orienteur.new()
	_orienteur.name = "OrienteurPieds"
	_orienteur.pilote = self
	for k in 2:
		var cible := Node3D.new()
		cible.name = "CiblePied_" + cotes[k]
		var pole := Node3D.new()
		pole.name = "PoleGenou_" + cotes[k]
		sq.add_child(cible)
		sq.add_child(pole)
		_cibles.append(cible)
		_poles.append(pole)
	sq.add_child(_ik)
	sq.add_child(_orienteur)
	_ik.set_setting_count(2)
	for k in 2:
		_ik.set_root_bone_name(k, "thigh_" + cotes[k])
		_ik.set_middle_bone_name(k, "calf_" + cotes[k])
		_ik.set_end_bone_name(k, "foot_" + cotes[k])
		_ik.set_target_node(k, _ik.get_path_to(_cibles[k]))
		_ik.set_pole_node(k, _ik.get_path_to(_poles[k]))
	actif = actif

## Os modifiés par ce module, parents avant enfants.
func _chaine() -> Array[int]:
	var r: Array[int] = [_os["pelvis"]]
	for k in 2:
		r.append(_os["cuisse"][k])
		r.append(_os["mollet"][k])
		r.append(_os["pied"][k])
	return r

## Rend définitive la dernière pose corrigée (bassin abaissé, jambes pliées, pieds inclinés) :
## à appeler avant de couper l'animation, pour que le ragdoll parte de ce qu'on voyait à l'écran.
func appliquer_pose_finale() -> void:
	var sq := get_skeleton()
	if sq == null or _finale.is_empty():
		return
	for i: int in _chaine():
		if _finale.has(i):
			PiedsAuSol.poser_globale(sq, i, _finale[i])
	sq.force_update_all_bone_transforms()

func _sol(depart: Vector3, bas: float, exclus: Array[RID]) -> Dictionary:
	var espace := corps.get_world_3d().direct_space_state
	for essai in 3:
		var q := PhysicsRayQueryParameters3D.create(depart, depart + Vector3.DOWN * bas, masque, exclus)
		var r := espace.intersect_ray(q)
		if r.is_empty() or not (r.collider is CharacterBody3D):
			return r
		exclus.append((r.collider as CharacterBody3D).get_rid())
	return {}

func _process_modification_with_delta(delta: float) -> void:
	var sq := get_skeleton()
	if sq == null or corps == null or not corps.is_inside_tree() or not actif:
		return
	var xf := sq.global_transform
	var inv := xf.basis.inverse()
	var f := 1.0 - exp(-lissage * delta)
	var influence := get_influence()
	var origine := corps.global_position
	var cible_y := [0.0, 0.0]
	var sol_y := [origine.y, origine.y]
	var pf: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	for k in 2:
		var i: int = _os["pied"][k]
		var pose := pose_globale(sq, i)
		pf[k] = xf * pose.origin
		_base_pied[k] = xf.basis * pose.basis
		var depart := Vector3(pf[k].x, maxf(pf[k].y, origine.y) + 0.5, pf[k].z)
		var r := _sol(depart, depart.y - origine.y + 1.0, [corps.get_rid()] as Array[RID])
		var h_anim := pf[k].y - origine.y
		var poids := clampf(1.0 - (h_anim - _h_repos) / 0.3, 0.0, 1.0) * influence
		var normale := Vector3.UP
		var brut := 0.0
		if not r.is_empty():
			sol_y[k] = r.position.y
			brut = r.position.y - origine.y
			normale = r.normal
		cible_y[k] = brut * poids
		_decal[k] = lerpf(_decal[k], cible_y[k], f)
		var angle := minf(Vector3.UP.angle_to(normale), deg_to_rad(angle_max)) * poids
		var axe := Vector3.UP.cross(normale)
		var q := Quaternion(axe.normalized(), angle) if axe.length() > 0.001 and angle > 0.0 else Quaternion()
		_rot[k] = _rot[k].slerp(q, f)
	# bassin : descend (ou monte un peu) avec le pied le plus bas
	var decal_bassin := clampf(minf(_decal[0], _decal[1]), -bassin_bas_max, bassin_haut_max)
	var ip: int = _os["pelvis"]
	var pp := pose_globale(sq, ip)
	poser_globale(sq, ip, Transform3D(pp.basis, pp.origin + inv * Vector3(0.0, decal_bassin, 0.0)))
	for k in 2:
		var y: float = pf[k].y + _decal[k]
		var plancher: float = sol_y[k] + _h_repos * garde
		if influence > 0.0 and y < plancher:
			y = plancher
		var but := Vector3(pf[k].x, y, pf[k].z)
		_cibles[k].global_position = but
		# pôle : le genou reste dans son plan de flexion d'origine
		var hanche := xf * pose_globale(sq, _os["cuisse"][k]).origin
		var genou := xf * pose_globale(sq, _os["mollet"][k]).origin
		var jambe := but - hanche
		var t := clampf((genou - hanche).dot(jambe) / maxf(jambe.length_squared(), 0.0001), 0.0, 1.0)
		var dir := genou - (hanche + jambe * t)
		if dir.length() < 0.01:
			dir = xf.basis * _avant
		_poles[k].global_position = genou + dir.normalized()
