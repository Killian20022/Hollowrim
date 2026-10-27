class_name Plaies
## Plaies persistantes sur le corps, à l'endroit touché : un Decal (projeté sur le maillage skinné, il suit l'animation et le
## ragdoll) accroché à l'os le plus proche par un BoneAttachment3D. Les décals ne touchent que les maillages marqués du calque
## CALQUE (ajouté aux maillages de l'ennemi par marquer()) : pas de plaie projetée sur le sol ni sur le joueur.
## Rendu Mobile : au plus 8 décals par maillage → MAX_PAR_CORPS plaies par ennemi (les plus anciennes s'effacent).
##   Plaies.ajouter(modele, point, normale, direction, taille, couleur, matiere) -> Decal
## Matières : "chair" (entaille sanglante), "os" (fissure), "bois" (copeau).

const CALQUE := 1 << 19          # calque de rendu 20 : « corps qui reçoivent des plaies »
## Échelle des plaies (réglage, sondes).
static var echelle := 1.0
const MAX_PAR_CORPS := 6
## Os candidats (le plus proche du point d'impact porte la plaie).
const OS_PLAIES := ["Head", "neck_01", "spine_03", "spine_02", "spine_01", "pelvis", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r",
	"thigh_l", "thigh_r", "calf_l", "calf_r"]

static func marquer(modele: Node3D) -> void:
	if modele == null or modele.has_meta("plaies_marque"):
		return
	modele.set_meta("plaies_marque", true)
	for mi: MeshInstance3D in modele.find_children("*", "MeshInstance3D", true, false):
		mi.layers |= CALQUE

static func nombre(modele: Node3D) -> int:
	if modele == null or not modele.has_meta("plaies"):
		return 0
	var l: Array = modele.get_meta("plaies")
	return l.filter(func(d: Variant) -> bool: return is_instance_valid(d)).size()

static func ajouter(modele: Node3D, point: Vector3, normale: Vector3, direction: Vector3, taille: float, couleur: Color, matiere := "chair") -> Decal:
	if modele == null or not modele.is_inside_tree():
		return null
	if matiere == "chair" and Sang.niveau() == 0:
		return null
	marquer(modele)
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	var accroche: Node3D = modele    # sans squelette (mannequin, décor) : la plaie suit le modèle entier
	if sq != null:
		preparer(modele)
		accroche = _accroche_proche(sq, point)
		if accroche == null:
			return null
	var l: Array = modele.get_meta("plaies", [])
	l = l.filter(func(d: Variant) -> bool: return is_instance_valid(d))
	while l.size() >= MAX_PAR_CORPS:
		(l.pop_front() as Node).queue_free()
	var d := Decal.new()
	d.name = "Plaie"
	var sorte := "entaille" if matiere == "chair" else ("fissure" if matiere == "os" else "copeau")
	d.texture_albedo = Sang.texture(sorte, randi() % 3)
	d.modulate = Color(minf(couleur.r * 3.0, 1.0), minf(couleur.g * 3.0, 1.0), minf(couleur.b * 3.0, 1.0)) if matiere == "chair" else couleur
	d.albedo_mix = 1.0
	d.cull_mask = CALQUE
	d.normal_fade = 0.25
	d.upper_fade = 0.15
	d.lower_fade = 0.15
	# filtrage des décals : réglage du projet rendering/textures/decals/filter = plus proche (texels nets)
	var reduit := Sang.niveau() == 1 and matiere == "chair"
	var t := taille * (0.7 if reduit else 1.0) * echelle
	d.size = Vector3(t, 0.5, t * 0.75)   # profondeur 50 cm : le point estimé (sans info de l'épée) n'est pas toujours sur la peau
	accroche.add_child(d)
	# repère : Y = normale (le décal projette le long de -Y), X = sens de la lame projeté sur la surface
	var y := normale.normalized() if normale.length() > 0.01 else Vector3.UP
	var x := direction - y * direction.dot(y)
	if x.length() < 0.05:
		x = y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	if z.dot(Vector3.DOWN) < 0.0 and matiere == "chair":
		x = -x   # les coulures (bas de la texture = +Z du décal) descendent
		z = -z
	# repère local : l'inverse du BoneAttachment (qui porte l'échelle du modèle) : la plaie garde sa taille en mètres
	d.transform = accroche.global_transform.affine_inverse() * Transform3D(Basis(x, y, z), point - y * 0.08)
	l.append(d)
	modele.set_meta("plaies", l)
	return d

## Longueur (m) du segment de chaque os, le long de son axe Y (pour trouver le membre le plus proche du point).
const LONGUEUR := {"Head": 0.2, "neck_01": 0.1, "spine_03": 0.18, "spine_02": 0.14, "spine_01": 0.14, "pelvis": 0.12}

## Crée les accroches des os (une fois) : leur position suit l'animation et le ragdoll (get_bone_global_pose n'est pas fiable
## hors des modificateurs).
static func preparer(modele: Node3D) -> void:
	if modele == null or modele.has_meta("plaies_accroches"):
		return
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	if sq == null:
		return
	var l: Array[BoneAttachment3D] = []
	for nom: String in OS_PLAIES:
		var i := sq.find_bone(nom)
		if i < 0:
			continue
		var a := BoneAttachment3D.new()
		a.name = "Plaies_" + nom
		a.bone_name = nom
		sq.add_child(a)
		a.global_transform = sq.global_transform * sq.get_bone_global_pose(i)
		l.append(a)
	modele.set_meta("plaies_accroches", l)

static func _accroche_proche(sq: Skeleton3D, point: Vector3) -> BoneAttachment3D:
	var modele := sq.get_parent() as Node3D
	while modele != null and not modele.has_meta("plaies_accroches"):
		modele = modele.get_parent() as Node3D
	if modele == null:
		return null
	var meilleur: BoneAttachment3D = null
	var dmin := INF
	for a: BoneAttachment3D in modele.get_meta("plaies_accroches"):
		if not is_instance_valid(a):
			continue
		var o := a.global_position
		var b := o + a.global_basis.y.normalized() * float(LONGUEUR.get(a.bone_name, 0.26))
		var ab := b - o
		var k := clampf((point - o).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var dist := point.distance_to(o + ab * k)
		if dist < dmin:
			dmin = dist
			meilleur = a
	return meilleur
