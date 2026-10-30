class_name Plaies
## Plaies persistantes sur le corps, à l'endroit touché : un Decal (projeté sur le maillage skinné, il suit l'animation et le
## ragdoll) accroché à l'os le plus proche par un BoneAttachment3D. Les décals ne touchent que les maillages marqués du calque
## CALQUE (ajouté aux maillages de l'ennemi par marquer()) : pas de plaie projetée sur le sol ni sur le joueur.
## Rendu Mobile : au plus 8 décals par maillage → MAX_PAR_CORPS plaies par ennemi (les plus anciennes s'effacent).
##   Plaies.ajouter(modele, point, normale, direction, taille, couleur, matiere) -> Decal
## Matières : "chair" (entaille sanglante), "os" (fissure), "bois" (copeau).
## Sang v2 (2026-10-30) : l'entaille de chair COULE (la texture passe par ETAPES images aux coulures de plus en plus longues) et
## GOUTTE (GouttesSang, depuis le bas des coulures, quelques secondes) ; Plaies.tacher() pose une éclaboussure (giclée d'un
## voisin) sur un corps : liste à part, au plus MAX_TACHES (6 plaies + 2 taches = 8 décals, la limite du rendu Mobile).

const CALQUE := 1 << 19          # calque de rendu 20 : « corps qui reçoivent des plaies »
## Échelle des plaies (réglage, sondes).
static var echelle := 1.0
const MAX_PAR_CORPS := 6
const MAX_TACHES := 2
## Sang v2 : images de l'écoulement d'une entaille, intervalle entre deux images (s), gouttes lâchées par plaie.
const ETAPES := 6
const PAS_ECOULEMENT := 0.45
const GOUTTES_PAR_PLAIE := 7
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
	var variante := randi() % 3
	var coule := matiere == "chair" and SangLame.actif
	d.texture_albedo = Sang.texture_entaille(variante, 0) if coule else Sang.texture(sorte, variante)
	# lèvres de la plaie en couleur de palette (le cœur de la fente est sombre dans la texture) : chair vive des vivants, chair
	# brun-rouge éteinte des draugrs (sang sombre) ; plus de rouge saturé ×3 qui « peignait » la cotte
	d.modulate = couleur_levres(couleur) if matiere == "chair" else couleur
	d.albedo_mix = 1.0
	d.cull_mask = CALQUE
	d.normal_fade = 0.25
	d.upper_fade = 0.15
	d.lower_fade = 0.15
	# filtrage des décals : réglage du projet rendering/textures/decals/filter = plus proche (texels nets)
	var reduit := Sang.niveau() == 1 and matiere == "chair"
	var t := taille * (0.7 if reduit else 1.0) * echelle
	# entaille fine et allongée dans le sens de la lame ; profondeur 26 cm (50 cm traversait le corps et barbouillait le dos
	# et les lambeaux) — le point vient du tracé de lame (mains.gd), sur la surface touchée
	d.size = Vector3(t, 0.26, t * 0.5) if matiere == "chair" else Vector3(t, 0.5, t * 0.75)
	if coule:
		d.size.z = t * 1.25   # texture 32 x 40 : la fente en haut (rang 8), les coulures dessous
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
	# sang v2 : la fente (rang 8 sur 40) reste au point d'impact, le décal descend de 0,3 × sa hauteur
	var bas := z * d.size.z * 0.3 if coule else Vector3.ZERO
	d.transform = accroche.global_transform.affine_inverse() * Transform3D(Basis(x, y, z), point - y * (0.05 if matiere == "chair" else 0.08) + bas)
	l.append(d)
	modele.set_meta("plaies", l)
	if coule:
		ecouler(d, variante, sang_couleur_goutte(couleur), 1.0 if couleur.r >= 0.3 else 0.55)
	return d

## L'entaille coule (images successives) puis goutte depuis le bas de ses coulures (sang sombre des draugrs : moins de gouttes).
static func ecouler(d: Decal, variante: int, couleur: Color, abondance: float) -> void:
	var tw := d.create_tween()
	for e in range(1, ETAPES):
		tw.tween_interval(PAS_ECOULEMENT * (1.0 + e * 0.35))
		tw.tween_callback(func() -> void:
			var t_us := Time.get_ticks_usec()
			d.texture_albedo = Sang.texture_entaille(variante, e)
			SangLame.cout_us += Time.get_ticks_usec() - t_us)
	if Sang.niveau() < 2:
		return
	var tg := d.create_tween()
	var n := roundi(GOUTTES_PAR_PLAIE * abondance)
	tg.tween_interval(0.5)
	for g in n:
		tg.tween_interval(randf_range(0.35, 0.9) * (1.0 + g * 0.25))
		tg.tween_callback(func() -> void:
			if not is_instance_valid(d) or not d.is_inside_tree():
				return
			var t_us := Time.get_ticks_usec()
			var b := d.global_transform.basis
			# bas d'une coulure : sous la fente, à la surface du corps (le décal est rentré de 5 cm le long de sa normale)
			var p := d.global_position + b.z.normalized() * d.size.z * randf_range(0.18, 0.45) + b.x.normalized() * d.size.x * randf_range(-0.3, 0.3) + b.y.normalized() * 0.07
			GouttesSang.lacher(d, p, couleur, Vector3(randf_range(-0.1, 0.1), -0.2, randf_range(-0.1, 0.1)))
			SangLame.cout_us += Time.get_ticks_usec() - t_us)

static func sang_couleur_goutte(sang: Color) -> Color:
	return Color(sang.r * 1.15, sang.g, sang.b)

## Éclaboussure (giclée d'un voisin) sur le corps de `modele`, au point (surface tournée vers la giclée, normale vers la source).
static func tacher(modele: Node3D, point: Vector3, normale: Vector3, taille: float, couleur: Color) -> Decal:
	if modele == null or not modele.is_inside_tree() or Sang.niveau() == 0:
		return null
	marquer(modele)
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	var accroche: Node3D = modele
	if sq != null:
		preparer(modele)
		accroche = _accroche_proche(sq, point)
		if accroche == null:
			return null
	var l: Array = modele.get_meta("taches", [])
	l = l.filter(func(d: Variant) -> bool: return is_instance_valid(d))
	while l.size() >= MAX_TACHES:
		(l.pop_front() as Node).queue_free()
	var d := Decal.new()
	d.name = "Tache"
	d.texture_albedo = Sang.texture("giclure", randi() % 3)
	d.modulate = Color(minf(couleur.r * 2.2, 1.0), minf(couleur.g * 2.0, 1.0), minf(couleur.b * 2.0, 1.0))
	d.albedo_mix = 1.0
	d.cull_mask = CALQUE
	d.normal_fade = 0.3
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.size = Vector3(taille, 0.5, taille)
	accroche.add_child(d)
	var y := normale.normalized() if normale.length() > 0.01 else Vector3.UP
	var x := Vector3.DOWN - y * Vector3.DOWN.dot(y)
	if x.length() < 0.05:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized().rotated(y, randf_range(-0.5, 0.5))
	d.transform = accroche.global_transform.affine_inverse() * Transform3D(Basis(x, y, x.cross(y)), point)
	l.append(d)
	modele.set_meta("taches", l)
	return d

static func nombre_taches(modele: Node3D) -> int:
	if modele == null or not modele.has_meta("taches"):
		return 0
	var l: Array = modele.get_meta("taches")
	return l.filter(func(d: Variant) -> bool: return is_instance_valid(d)).size()

## Couleur des lèvres d'une entaille d'après la couleur du sang du profil : sang sombre (draugr) → chair brun-rouge éteinte,
## sang vif (bandit) → rouge de la palette « sang » de GerbePixels.
static func couleur_levres(sang: Color) -> Color:
	return Color("#8a2a1c") if sang.r < 0.3 else Color("#b8261e")

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
