class_name Decapitation
## Décapitation d'un personnage skinné (draugr, squelette, bandit : squelette RIG18 / Quaternius, os « Head » enfant de « neck_01 »).
##   var tete := Decapitation.decapiter(modele, impulsion, couleur_sang, sang)   -> RigidBody3D (null si impossible)
## Corps : un modificateur (CouTranche, DERNIER modificateur du squelette, après le ragdoll) écrase l'os Head (échelle ~0) : tout ce
## qui est pesé sur la tête (crâne, casque, cheveux, masque) se replie au sommet du cou → moignon ; un bouchon de chair (ou d'os)
## ferme la coupe, un jet de sang pulsé en jaillit.
## Tête : copie des maillages visibles avec une peau (Skin) refaite où TOUTES les attaches non-tête se replient sur un point de la
## coupe : il ne reste que la tête (et la base du cou), posée sur un squelette d'un seul os, dans un corps rigide lancé dans le sens
## du coup (rotation), qui roule et laisse des traces de sang.
## Les têtes coupées disparaissent après DUREE s (comme les cadavres, draugr.gd) ; au plus MAX_TETES en même temps.

const DUREE := 30.0
const MAX_TETES := 6
const CALQUE_CADAVRES := 16
static var _tetes: Array = []

class CouTranche extends SkeletonModifier3D:
	var os := -1
	func _process_modification() -> void:
		var sq := get_skeleton()
		if sq != null and os >= 0:
			sq.set_bone_pose_scale(os, Vector3.ONE * 0.001)

static func peut(modele: Node3D) -> bool:
	if modele == null or modele.has_meta("decapite"):
		return false
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	return sq != null and sq.find_bone("Head") >= 0 and sq.find_bone("neck_01") >= 0

static func decapiter(modele: Node3D, impulsion: Vector3, couleur: Color, sang := true, matiere := "chair") -> RigidBody3D:
	if not peut(modele):
		return null
	var sq := modele.find_child("Skeleton3D", true, false) as Skeleton3D
	var h := sq.find_bone("Head")
	var cou := sq.find_bone("neck_01")
	modele.set_meta("decapite", true)
	# transform visible de la tête (accroche à jour, voir Plaies.preparer) ou pose de l'os
	var t_tete := sq.global_transform * sq.get_bone_global_pose(h)
	var t_cou := sq.global_transform * sq.get_bone_global_pose(cou)
	for a in sq.get_children():
		if a is BoneAttachment3D and (a as BoneAttachment3D).bone_name == "Head" and String(a.name).begins_with("Plaies_"):
			t_tete = (a as Node3D).global_transform
		elif a is BoneAttachment3D and (a as BoneAttachment3D).bone_name == "neck_01" and String(a.name).begins_with("Plaies_"):
			t_cou = (a as Node3D).global_transform
	# point de coupe dans le repère de la tête : un peu sous l'articulation (la base du crâne)
	var repos_tete := sq.get_bone_global_rest(h)
	var repos_cou := sq.get_bone_global_rest(cou)
	var coupe_local := repos_tete.affine_inverse() * repos_cou.origin.lerp(repos_tete.origin, 0.75)
	var monde := modele.get_tree().current_scene if modele.get_tree().current_scene else modele.get_tree().root
	# --- tête : corps rigide + copie des maillages
	var rb := RigidBody3D.new()
	rb.name = "TeteCoupee"
	rb.mass = 4.5
	rb.collision_layer = CALQUE_CADAVRES
	rb.collision_mask = 1
	rb.angular_damp = 1.2
	rb.linear_damp = 0.1
	rb.continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.18
	rb.physics_material_override = pm
	var echelle := t_tete.basis.get_scale().x
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.11 * echelle
	cs.shape = sph
	cs.position = Vector3(0, 0.09 * echelle, 0)
	rb.add_child(cs)
	monde.add_child(rb)
	rb.global_transform = Transform3D(t_tete.basis.orthonormalized(), t_tete.origin)
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	sk.add_bone("Head")
	rb.add_child(sk)
	sk.global_transform = t_tete   # avec l'échelle du modèle : Head (identité) = la tête visible
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		if not mi.visible or mi.mesh == null or mi.skin == null:
			continue
		var copie := MeshInstance3D.new()
		copie.name = mi.name
		copie.mesh = mi.mesh
		copie.skin = _peau_tete(mi.skin, sq, h, coupe_local)
		copie.material_override = mi.material_override
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s)
			if m != null:
				copie.set_surface_override_material(s, m)
		copie.cast_shadow = mi.cast_shadow
		copie.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))   # boîtes d'os de la peau d'origine : plus valables
		sk.add_child(copie)
		copie.skeleton = NodePath("..")
		_copier_instances(mi, copie)
	# pièces rigides accrochées à la tête (casques glb des humains, couronnes) : elles partent avec elle
	for a in sq.get_children():
		if a is BoneAttachment3D and (a as BoneAttachment3D).bone_name == "Head" and not String(a.name).begins_with("Plaies_"):
			for piece in a.get_children():
				if piece is Node3D:
					var g := (piece as Node3D).global_transform
					piece.reparent(sk, false)
					(piece as Node3D).global_transform = g
	# --- corps : la tête se replie au sommet du cou (dernier modificateur, après le ragdoll)
	var ct := CouTranche.new()
	ct.name = "CouTranche"
	ct.os = h
	sq.add_child(ct)
	sq.move_child(ct, -1)
	# bouchons de la coupe (chair à vif ou os) et jet
	var accroche := BoneAttachment3D.new()
	accroche.name = "Coupe"
	accroche.bone_name = "neck_01"
	sq.add_child(accroche)
	accroche.global_transform = t_cou
	var haut_cou := sq.get_bone_rest(h).origin    # tête dans le repère du cou
	var axe := haut_cou.normalized()
	var base_bouchon := _base_vers(axe)
	var c_chair := Color(0.55, 0.06, 0.05) if matiere == "chair" else Color(0.7, 0.66, 0.55)
	_bouchon(accroche, Transform3D(base_bouchon, haut_cou), c_chair, 0.05)
	_bouchon(sk, Transform3D(_base_vers(Vector3.DOWN), coupe_local), c_chair, 0.05)
	if sang and matiere == "chair":
		Sang.jet(accroche, Transform3D(base_bouchon, haut_cou), couleur, 2.6)
		Sang.giclee(rb, t_tete.origin, impulsion.normalized(), 3.0, couleur)
		_gouttes_tete(rb, couleur)
	else:
		Sang.eclats_matiere(rb, t_tete.origin, impulsion.normalized(), 2.0, couleur)
	# lancer : impulsion du coup + rotation (la tête tourne sur elle-même)
	rb.apply_central_impulse(impulsion)
	rb.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-6, 6), randf_range(-9, 9))
	_tetes.append(rb)
	_tetes = _tetes.filter(func(x: Variant) -> bool: return is_instance_valid(x))
	while _tetes.size() > MAX_TETES:
		(_tetes.pop_front() as Node).queue_free()
	rb.get_tree().create_timer(DUREE).timeout.connect(func() -> void:
		if is_instance_valid(rb):
			rb.queue_free())
	modele.set_meta("tete_coupee", rb)
	return rb

## Peau de la tête : les attaches de la tête restent ; toutes les autres sont rattachées à la tête avec une matrice qui écrase
## leurs sommets sur le point de coupe (repère de la tête).
static func _peau_tete(src: Skin, sq: Skeleton3D, h: int, coupe_local: Vector3) -> Skin:
	var s := src.duplicate() as Skin
	var ecrase := Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), coupe_local)
	for i in s.get_bind_count():
		var nom := String(s.get_bind_name(i))
		var os := sq.find_bone(nom) if nom != "" else s.get_bind_bone(i)
		var tete := os == h
		s.set_bind_name(i, "Head")
		s.set_bind_bone(i, 0)
		s.set_bind_pose(i, s.get_bind_pose(i) if tete else ecrase)
	return s

static func _copier_instances(src: MeshInstance3D, dst: MeshInstance3D) -> void:
	for nom in ["eclair"]:
		var v: Variant = src.get_instance_shader_parameter(nom)
		if v != null:
			dst.set_instance_shader_parameter(nom, 0.0)
	for nom in ["c_peau", "c_tun", "c_pan", "c_cuir", "c_sur", "c_cheveux", "c_four", "c_iris"]:
		var v: Variant = src.get_instance_shader_parameter(nom)
		if v != null:
			dst.set_instance_shader_parameter(nom, v)

static func _base_vers(axe: Vector3) -> Basis:
	var y := axe.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))

static func _bouchon(parent: Node3D, t: Transform3D, c: Color, rayon: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Bouchon"
	var cy := CylinderMesh.new()
	cy.top_radius = rayon
	cy.bottom_radius = rayon * 1.1
	cy.height = 0.02
	cy.radial_segments = 8
	cy.rings = 1
	mi.mesh = cy
	mi.material_override = mat_bouchon(c)
	parent.add_child(mi)
	mi.transform = t

## Matériau des bouchons de cou, partagé par couleur (un matériau neuf par coupe coûtait ~25 ms : shader recompilé dès que le
## dernier matériau du même genre avait disparu).
static var _mats_bouchon := {}
static func mat_bouchon(c: Color) -> StandardMaterial3D:
	var cle := str(c)
	if not _mats_bouchon.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_texture = Sang.texture("flaque", 1)
		m.albedo_color = c
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.roughness = 0.3
		_mats_bouchon[cle] = m
	return _mats_bouchon[cle]

## Gouttes et traces quand la tête roule (au plus 5 traces).
static func _gouttes_tete(rb: RigidBody3D, couleur: Color) -> void:
	rb.contact_monitor = true
	rb.max_contacts_reported = 1
	var reste := [5]
	rb.body_entered.connect(func(_b: Node) -> void:
		if reste[0] <= 0 or not is_instance_valid(rb):
			return
		reste[0] -= 1
		var r := Sang.sol_sous(rb, rb.global_position, 0.3, 0.8)
		if not r.is_empty():
			Sang.trace(rb, r["position"], r["normal"], rb.linear_velocity, randf_range(0.18, 0.3), couleur, "giclure"))
