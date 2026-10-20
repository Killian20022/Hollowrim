class_name PersoRessorts
extends Node
## Ressorts des vetements (capes, pans, capuche) : os SECONDAIRES hors RIG18 (cape_1, cape_2, capuche_1, pan_av_1, pan_ar_1 : 5 os, 26 au total)
## animes par un SpringBoneSimulator3D (amorti, gravite, inertie du deplacement du personnage) avec COLLISIONS sur le dos, le bassin, les cuisses
## et les mollets : une cape ne traverse jamais le dos, un pan ou une robe ne traversent pas la jambe qui avance.
## Coupe au-dela de DIST_MAX m de la camera (les os reviennent a leur pose de repos) : cout nul au loin ; mesure : docs/PERSONNAGES_TECH.md.
##
##   PersoRessorts.equiper(modele, def)   (appele par Personnage.creer ; rien si la definition n'a aucun vetement a ressort)

const DIST_MAX := 15.0
const DIST_REPRISE := 13.5      # hysteresis : pas de clignotement a la limite

## chaine -> parametres du ressort. rigidite : ramene a la pose ANIMEE (haute = la cape suit le buste penche, faible = elle pend d'aplomb) ; frottement : amortit ;
## gravite : tire vers le bas ; rayon : sphere de collision de l'articulation. Regles trouvees a la galerie animee (outils/galerie_base.gd --live) : rigidite basse, gravite forte.
const CHAINES := {
	"cape": {"racine": "cape_1", "fin": "cape_2", "longueur": 0.28, "rigidite": 0.12, "frottement": 0.25, "gravite": 5.0, "rayon": 0.045},
	"capuche": {"racine": "capuche_1", "fin": "capuche_1", "longueur": 0.14, "rigidite": 0.5, "frottement": 0.35, "gravite": 2.0, "rayon": 0.035},
	"pan_av": {"racine": "pan_av_1", "fin": "pan_av_1", "longueur": 0.30, "rigidite": 0.25, "frottement": 0.35, "gravite": 4.0, "rayon": 0.05},
	"pan_ar": {"racine": "pan_ar_1", "fin": "pan_ar_1", "longueur": 0.28, "rigidite": 0.25, "frottement": 0.35, "gravite": 4.0, "rayon": 0.05},
}
## accessoire -> chaines
const PAR_ACCESSOIRE := {"cape_courte": ["cape"], "cape_longue": ["cape"], "capuche": ["capuche"], "tablier": ["pan_av"], "robe": ["pan_av", "pan_ar"]}

var simulateur: SpringBoneSimulator3D
var _actif := true

static func chaines_de(def: PersoDef) -> Array:
	var l: Array = []
	for a in def.accessoires:
		for c: String in PAR_ACCESSOIRE.get(a, []):
			if not l.has(c):
				l.append(c)
	return l

static func equiper(modele: Node3D, def: PersoDef) -> PersoRessorts:
	var chaines := chaines_de(def)
	if chaines.is_empty() or not def.ressorts:
		return null
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null:
		return null
	var r := PersoRessorts.new()
	r.name = "PersoRessorts"
	modele.add_child(r)
	var sim := SpringBoneSimulator3D.new()
	sim.name = "Ressorts"
	r.simulateur = sim
	sq.add_child(sim)
	sim.set_setting_count(chaines.size())
	for i in chaines.size():
		var c: Dictionary = CHAINES[chaines[i]]
		sim.set_root_bone_name(i, c["racine"])
		sim.set_end_bone_name(i, c["fin"])
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_direction(i, SpringBoneSimulator3D.BONE_DIRECTION_FROM_PARENT)
		sim.set_end_bone_length(i, c["longueur"])
		sim.set_radius(i, c["rayon"])
		sim.set_stiffness(i, c["rigidite"])
		sim.set_drag(i, c["frottement"])
		sim.set_gravity(i, c["gravite"])
		sim.set_gravity_direction(i, Vector3.DOWN)
		sim.set_enable_all_child_collisions(i, true)
	_collisions(sim, sq)
	# l'IK des pieds et le suivi de la tete (ajoutes apres) doivent passer AVANT les ressorts : on se replace en dernier apres leur creation
	r._replacer.call_deferred()
	return r

func _replacer() -> void:
	if is_instance_valid(simulateur) and simulateur.get_parent():
		var p := simulateur.get_parent()
		p.move_child(simulateur, p.get_child_count() - 1)

## Collisions : capsules ajustees sur les os du corps (axe de l'os vers son enfant, dans le repere de l'os).
static func _collisions(sim: SpringBoneSimulator3D, sq: Skeleton3D) -> void:
	# [os, enfant, rayon, debut, fin] ; debut/fin : fraction de la longueur de l'os couverte
	var defs := [
		["spine_01", "spine_03", 0.150, -0.15, 1.1],
		["spine_03", "neck_01", 0.150, -0.2, 0.7],
		["pelvis", "spine_01", 0.175, -0.9, 1.0],
		["thigh_l", "calf_l", 0.108, 0.0, 1.0], ["thigh_r", "calf_r", 0.108, 0.0, 1.0],
		["calf_l", "foot_l", 0.072, 0.0, 1.0], ["calf_r", "foot_r", 0.072, 0.0, 1.0],
	]
	for d in defs:
		var i := sq.find_bone(d[0])
		var e := sq.find_bone(d[1])
		if i < 0 or e < 0:
			continue
		var repos := sq.get_bone_global_rest(i)
		var v := sq.get_bone_global_rest(e).origin - repos.origin
		var axe := (repos.basis.orthonormalized().inverse() * v).normalized()
		var long := v.length() * (float(d[4]) - float(d[3]))
		var cap := SpringBoneCollisionCapsule3D.new()
		cap.name = "Col_" + String(d[0])
		sim.add_child(cap)
		cap.bone_name = d[0]
		cap.radius = d[2]
		cap.height = long + 2.0 * float(d[2])
		cap.position_offset = axe * (v.length() * (float(d[3]) + float(d[4])) * 0.5)
		cap.rotation_offset = Quaternion(Vector3.UP, axe)

func _process(_dt: float) -> void:
	if simulateur == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.global_position.distance_to(simulateur.global_position)
	if _actif and d > DIST_MAX:
		_actif = false
		simulateur.active = false
	elif not _actif and d < DIST_REPRISE:
		_actif = true
		simulateur.reset()
		simulateur.active = true
