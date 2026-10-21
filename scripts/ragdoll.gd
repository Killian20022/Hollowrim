class_name Ragdoll
extends Node
## Ragdoll d'un Humain (squelette Quaternius) : à la mort ou à la chute, le corps passe de
## l'animation à la physique, à partir de la pose animée courante, et épouse le terrain.
##
##   var rd := Ragdoll.equiper(personnage)            # peut se faire au moment de la mort
##   rd.declencher(impulsion, point_d_impact)         # coup : N·s, point en coordonnées monde
##   rd.endormir_apres(6.0)                           # fige le corps une fois immobile
##
## CALQUES (documentés ici, à reprendre dans project.godot si on les nomme) :
##   - le terrain et les décors sont sur le calque 1 (bit 1, valeur 1) ;
##   - les os du ragdoll sont sur le calque 5 (valeur 16, « cadavres ») ;
##   - masque des os = 1 seulement : ils butent sur le terrain/décors mais PAS sur les autres
##     os (ni ceux du même corps, ni ceux d'un autre cadavre : le calque 5 n'est pas dans leur masque).
##   - le joueur : s'il est lui aussi sur le calque 1, les os le heurteraient ; on les en
##     dispense avec `ignorer(joueur)` (exception de collision, par corps).
## CÔTÉ APPELANT : la capsule du CharacterBody3D du mort doit être désactivée
##   (collision_layer = 0, collision_mask = 0, set_physics_process(false), vitesse nulle),
##   sinon elle reste debout dans le décor et gêne les autres.

const CALQUE_OS := 16
const MASQUE_DEFAUT := 1

## Table des os physiques (ordre : parents avant enfants).
## nom : [enfant (longueur et axe), forme, taille_a, taille_b, masse, joint, extra]
##   forme "capsule" : taille_a = rayon ; forme "boite" : taille_a = largeur, taille_b = épaisseur.
##   extra : "longueur" (force la longueur), "debut" (décalage de départ le long de l'os),
##           "bas" (descend la forme), "vers_haut" (axe = vertical monde, pas de bone enfant).
## Chaque os porte son suffixe _l/_r automatiquement pour les os marqués « * ».
const DEFS := [
	["pelvis", "spine_01", "boite", 0.32, 0.2, 12.0, "aucun", {"longueur": 0.2, "debut": -0.09}],
	["spine_01", "spine_03", "boite", 0.28, 0.18, 8.0, "cone", {"swing": 30.0, "twist": 20.0}],
	["spine_03", "neck_01", "boite", 0.34, 0.22, 14.0, "cone", {"swing": 35.0, "twist": 25.0, "longueur": 0.3}],
	["Head", "", "capsule", 0.1, 0.0, 5.0, "cone", {"swing": 35.0, "twist": 40.0, "longueur": 0.24, "vers_haut": true}],
	["upperarm_*", "lowerarm_*", "capsule", 0.045, 0.0, 2.5, "cone", {"swing": 100.0, "twist": 40.0}],
	["lowerarm_*", "hand_*", "capsule", 0.04, 0.0, 1.5, "charniere", {"flexion": 150.0, "avant": true}],
	["hand_*", "middle_01_*", "capsule", 0.035, 0.0, 0.5, "cone", {"swing": 50.0, "twist": 20.0, "allonge": 0.06}],
	["thigh_*", "calf_*", "capsule", 0.085, 0.0, 9.0, "cone", {"swing": 75.0, "twist": 25.0}],
	["calf_*", "foot_*", "capsule", 0.06, 0.0, 4.0, "charniere", {"flexion": 150.0, "avant": false}],
	["foot_*", "ball_*", "capsule", 0.04, 0.0, 3.0, "cone", {"swing": 60.0, "twist": 40.0, "longueur_plus": 0.05, "debut": -0.04}],
]

## Masse totale du corps (kg), répartie au prorata des masses de la table.
var masse_totale := 70.0
## Masque de collision des os (terrain et décors).
var masque := MASQUE_DEFAUT
var personnage: Node3D
var squelette: Skeleton3D
var simulateur: PhysicalBoneSimulator3D
## Os physiques par nom d'os du squelette.
var os: Dictionary = {}
var actif := false

var _infos: Dictionary = {}   # nom → {parent, centre (repère os), axe_charniere (repère modèle au repos)}
var _anim: AnimationPlayer
var _delai_sommeil := -1.0
var _temps := 0.0
var _immobile := 0.0
var _positions: Dictionary = {}
var _fige := false

## Construit les os physiques du personnage (Humain.creer). Retourne le nœud Ragdoll,
## enfant du personnage (null si le squelette est introuvable).
static func equiper(perso: Node3D) -> Node:
	var sq := perso.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null:
		return null
	var existant := perso.get_node_or_null("Ragdoll")
	if existant:
		return existant
	var r := Ragdoll.new()
	r.name = "Ragdoll"
	perso.add_child(r)
	r._construire(perso, sq)
	return r

func _construire(perso: Node3D, sq: Skeleton3D) -> void:
	personnage = perso
	squelette = sq
	_anim = perso.get_node_or_null("Animations") as AnimationPlayer
	simulateur = PhysicalBoneSimulator3D.new()
	simulateur.name = "SimulateurRagdoll"
	sq.add_child(simulateur)
	# repère du modèle au repos : avant = direction pied → orteils, à plat
	var pied := sq.get_bone_global_rest(sq.find_bone("foot_l")).origin
	var orteil := sq.get_bone_global_rest(sq.find_bone("ball_l")).origin
	var avant := Vector3(orteil.x - pied.x, 0.0, orteil.z - pied.z).normalized()
	var total := 0.0
	for d in DEFS:
		total += d[5] * (2.0 if String(d[0]).ends_with("*") else 1.0)
	for d in DEFS:
		for cote in (["_l", "_r"] if String(d[0]).ends_with("*") else [""]):
			_creer_os(d, cote, avant, masse_totale * d[5] / total)

func _nom(n: String, cote: String) -> String:
	return n.trim_suffix("*") + cote.trim_prefix("_") if n.ends_with("*") else n

func _creer_os(d: Array, cote: String, avant: Vector3, masse: float) -> void:
	var nom := _nom(d[0], cote)
	var i := squelette.find_bone(nom)
	if i < 0:
		return
	var extra: Dictionary = d[7]
	var repos := squelette.get_bone_global_rest(i)
	var base := repos.basis.orthonormalized()
	var inv := base.inverse()
	# axe de l'os (repère de l'os) et longueur
	var axe: Vector3
	var longueur: float
	if extra.get("vers_haut", false):
		axe = (inv * Vector3.UP).normalized()
		longueur = 0.0
	else:
		var enfant := squelette.find_bone(_nom(d[1], cote))
		var v := squelette.get_bone_global_rest(enfant).origin - repos.origin
		axe = (inv * v).normalized()
		longueur = v.length()
	longueur += float(extra.get("longueur_plus", 0.0)) + float(extra.get("allonge", 0.0))
	if extra.has("longueur"):
		longueur = extra["longueur"]
	var debut: float = extra.get("debut", 0.0)
	# base orthonormée de la forme : y le long de l'os, x vers la droite du modèle
	var droite := inv * Vector3.RIGHT
	var x := droite - axe * axe.dot(droite)
	if x.length() < 0.2:
		x = inv * avant
		x -= axe * axe.dot(x)
	x = x.normalized()
	var forme_base := Basis(x, axe, x.cross(axe))
	var centre := axe * (debut + longueur * 0.5) - (inv * Vector3.UP) * float(extra.get("bas", 0.0))
	var cs := CollisionShape3D.new()
	if d[2] == "capsule":
		var c := CapsuleShape3D.new()
		c.radius = d[3]
		c.height = maxf(longueur + c.radius, c.radius * 2.0 + 0.01)
		cs.shape = c
	else:
		var b := BoxShape3D.new()
		b.size = Vector3(d[3], maxf(longueur, 0.04), d[4])
		cs.shape = b
	cs.transform = Transform3D(forme_base, centre)
	var pb := PhysicalBone3D.new()
	pb.name = nom
	simulateur.add_child(pb)
	pb.bone_name = nom
	pb.add_child(cs)
	pb.mass = masse
	pb.friction = 1.0
	pb.bounce = 0.0
	pb.linear_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
	pb.angular_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
	pb.linear_damp = 0.15
	pb.angular_damp = 3.0
	pb.collision_layer = CALQUE_OS
	pb.collision_mask = masque
	# articulation : repère placé à l'origine de l'os
	var parent := ""
	var p := squelette.get_bone_parent(i)
	while p >= 0:
		if _est_os_physique(squelette.get_bone_name(p)):
			parent = squelette.get_bone_name(p)
			break
		p = squelette.get_bone_parent(p)
	var info := {"parent": parent, "centre": centre, "joint": d[6]}
	match d[6]:
		"cone":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			# axe de torsion = X du repère de l'articulation, aligné sur l'os
			var y := axe.cross(Vector3.RIGHT if absf(axe.x) < 0.9 else Vector3.UP).normalized()
			pb.joint_offset = Transform3D(Basis(axe, y, axe.cross(y)), Vector3.ZERO)
			pb.set("joint_constraints/swing_span", extra["swing"])
			pb.set("joint_constraints/twist_span", extra["twist"])
		"charniere":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			# axe de la charnière = Z du repère ; la flexion positive amène le bout de l'os
			# vers l'arrière (genou) ou vers l'avant (coude)
			var vers := avant if extra["avant"] else -avant
			var axe_monde := (base * axe).cross(vers).normalized()
			info["axe_charniere"] = axe_monde
			info["flexion"] = extra["flexion"]
			var zl := inv * (-axe_monde)
			var xl := axe
			var bs := Basis(xl, zl.cross(xl), zl)
			pb.joint_offset = Transform3D(bs, Vector3.ZERO)
			pb.set("joint_constraints/angular_limit_enabled", true)
			# l'angle de la charnière tourne autour de +Z = -axe_monde : il vaut -flexion (cf. flexion())
			pb.set("joint_constraints/angular_limit_lower", -float(extra["flexion"]))
			pb.set("joint_constraints/angular_limit_upper", 5.0)
	_infos[nom] = info
	os[nom] = pb

func _est_os_physique(nom: String) -> bool:
	for d in DEFS:
		if nom == _nom(d[0], "_l") or nom == _nom(d[0], "_r") or nom == d[0]:
			return true
	return false

## Les os du corps n'entreront pas en collision avec ce corps (joueur, autre PNJ…).
func ignorer(corps: PhysicsBody3D) -> void:
	for pb: PhysicalBone3D in os.values():
		pb.add_collision_exception_with(corps)

## Flexion actuelle (rad) d'une charnière (coude/genou) par rapport au repos, positive = pliée.
func flexion(nom: String) -> float:
	var info: Dictionary = _infos.get(nom, {})
	if not info.has("axe_charniere") or not os.has(nom) or not os.has(info["parent"]):
		return 0.0
	var base := squelette.global_transform.basis
	var i := squelette.find_bone(nom)
	var pi := squelette.find_bone(info["parent"])
	var e: PhysicalBone3D = os[nom]
	var p: PhysicalBone3D = os[info["parent"]]
	var rel_enfant := e.global_basis * (base * squelette.get_bone_global_rest(i).basis).inverse()
	var rel_parent := p.global_basis * (base * squelette.get_bone_global_rest(pi).basis).inverse()
	var q := (rel_parent.orthonormalized().inverse() * rel_enfant.orthonormalized()).get_rotation_quaternion()
	var axe: Vector3 = base * (info["axe_charniere"] as Vector3)
	return wrapf(2.0 * atan2(Vector3(q.x, q.y, q.z).dot(axe), q.w), -PI, PI)

## Passe en ragdoll depuis la pose animée courante.
##   impulsion : quantité de mouvement du coup (N·s, monde). ~60 = coup léger (le corps
##   s'effondre), ~350 = coup puissant (projeté à ~5 m/s).
##   point : point d'impact (monde) ; l'os le plus proche reçoit la plus grande part.
##   os_touche : nom d'os imposé (ex. "Head"), sinon déduit du point.
##   vitesse : vitesse du personnage au moment de la mort (conservée, ex. en course).
func declencher(impulsion: Vector3, point: Vector3, os_touche := "", vitesse := Vector3.ZERO) -> void:
	if actif or simulateur == null:
		return
	actif = true
	for n in squelette.get_children():
		if n.is_in_group("pieds_au_sol"):
			n.call("appliquer_pose_finale")   # on part de la pose corrigée visible à l'écran
			n.set("actif", false)
	if _anim:
		_anim.active = false
	squelette.force_update_all_bone_transforms()
	simulateur.physical_bones_start_simulation()
	# limites des charnières recentrées sur la pose de départ (l'articulation prend la pose animée pour origine).
	# Angle de la charnière = -(flexion - phi) : flexion dans [-5, max] <=> angle dans [phi - max, 5 + phi].
	# (L'ancien signe inversé laissait le genou s'hyper-étendre jusqu'à -90°.)
	for nom: String in os:
		var info: Dictionary = _infos[nom]
		if info["joint"] == "charniere":
			var phi := rad_to_deg(flexion(nom))
			var pb: PhysicalBone3D = os[nom]
			pb.set("joint_constraints/angular_limit_lower", phi - float(info["flexion"]))
			pb.set("joint_constraints/angular_limit_upper", 5.0 + phi)
	# l'os touché : celui dont l'axe est le plus près du point
	var cible := os_touche
	if not os.has(cible):
		var meilleur := INF
		for nom: String in os:
			var pb: PhysicalBone3D = os[nom]
			var c := pb.global_transform * (_infos[nom]["centre"] as Vector3)
			var dist := c.distance_to(point)
			if dist < meilleur:
				meilleur = dist
				cible = nom
	# la moitié de l'impulsion met tout le corps en mouvement (même vitesse pour tous les os,
	# donc proportionnelle à la masse) ; l'autre moitié frappe l'os touché et le tronc
	# (plafonnée à ~7 m/s par os pour qu'une tête ou une main ne soit pas catapultée).
	var m_total := 0.0
	for pb: PhysicalBone3D in os.values():
		m_total += pb.mass
	for pb: PhysicalBone3D in os.values():
		pb.apply_central_impulse(impulsion * 0.5 * pb.mass / m_total)
	var parts := {"pelvis": 0.2, "spine_03": 0.3}
	parts[cible] = parts.get(cible, 0.0) + 0.5
	for k: String in parts:
		if not os.has(k):
			continue
		var pb: PhysicalBone3D = os[k]
		var imp: Vector3 = (impulsion * 0.5 * parts[k]).limit_length(pb.mass * 7.0)
		if k == cible and os_touche == "" and point != Vector3.ZERO:
			var decal := point - pb.global_position
			pb.apply_impulse(imp, decal.limit_length(0.25))
		else:
			pb.apply_central_impulse(imp)
	if vitesse != Vector3.ZERO:
		for pb: PhysicalBone3D in os.values():
			pb.apply_central_impulse(vitesse * pb.mass)
	_temps = 0.0
	_immobile = 0.0
	set_physics_process(_delai_sommeil >= 0.0)

## Une fois `secondes` écoulées depuis le déclenchement ET le corps quasi immobile ~0,5 s (au plus tard 5 s après), tous les
## os sont figés (corps statiques : plus aucun calcul de physique, la pose reste).
## À appeler avant ou après declencher().
func endormir_apres(secondes: float) -> void:
	_delai_sommeil = secondes
	set_physics_process(actif)

func est_fige() -> bool:
	return _fige

func _ready() -> void:
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not actif or _fige or _delai_sommeil < 0.0:
		return
	_temps += delta
	var bouge := 0.0
	for nom: String in os:
		var p: Vector3 = (os[nom] as PhysicalBone3D).global_position
		bouge = maxf(bouge, p.distance_to(_positions.get(nom, p)))
		_positions[nom] = p
	_immobile = _immobile + delta if bouge / delta < 0.3 else 0.0
	if (_temps >= _delai_sommeil and _immobile > 0.5) or _temps >= _delai_sommeil + 5.0:
		_figer()

func _figer() -> void:
	_fige = true
	for pb: PhysicalBone3D in os.values():
		PhysicsServer3D.body_set_mode(pb.get_rid(), PhysicsServer3D.BODY_MODE_STATIC)
	set_physics_process(false)
