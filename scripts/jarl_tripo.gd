class_name JarlTripo
## Jarl généré par Tripo (essai, branche essai/tripo) : MÊME squelette que les humains nordiques (65 os de homme_vetu.glb, mêmes noms,
## même pose de repos) + 3 chaînes de 4 os de cape ; donc les mêmes clips (Humain.bibliotheque() : Idle, Walk, Idle_Talking, Interact,
## Sitting_Idle…), PiedsAuSol, SuiviTete, Ragdoll… marchent tels quels. La cape est animée par un SpringBoneSimulator3D (3 chaînes) avec des
## capsules de collision sur cuisses, mollets et bassin. Contrat de Humain.creer : racine -> Skeleton3D + AnimationPlayer « Animations ».
##   JarlTripo.creer() -> Node3D      (modèle : sources_blender/scripts/tripo_jarl_rig.py -> assets/pnj/tripo_jarl_rig.glb)
## Utilisé par PnjNordique.creer("jarl_tripo") (habitant « hab_jarl_tripo » de data/habitants.json, inactif sauf argument --jarl-tripo).

const GLB := preload("res://assets/pnj/tripo_jarl_rig.glb")
const CHAINES := ["cape_l", "cape_c", "cape_r"]
## Manteau de laine lourd : revient lentement (raideur faible), très amorti (pas de gigue), tombe droit.
static var RAIDEUR := 0.08
static var AMORTI := 0.45
static var GRAVITE := 2.0

static func creer(ressorts := true, avec_collisions := true) -> Node3D:
	var racine: Node3D = GLB.instantiate()
	racine.name = "PnjJarlTripo"
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
				var tex: Texture2D = (src as BaseMaterial3D).albedo_texture
				var mat := Palette.materiau(tex, Vector2.ONE, Color.WHITE, true)   # double face : l'intérieur du manteau
				mat.set_shader_parameter("tex_neige", tex)
				mi.set_surface_override_material(s, mat)
		mi.extra_cull_margin = 0.3      # T-pose du glb : la boîte englobante suit déjà les os, marge pour la cape qui vole
	var ap := AnimationPlayer.new()
	ap.name = "Animations"
	racine.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", Humain.bibliotheque())
	if ressorts:
		_ressorts(sq, avec_collisions)
	racine.set_meta("pnj_nordique", "jarl_tripo")
	return racine

static func _ressorts(sq: Skeleton3D, avec_collisions: bool) -> void:
	var sim := SpringBoneSimulator3D.new()
	sim.name = "Cape"
	sq.add_child(sim)       # après les autres modificateurs éventuels (PiedsAuSol est ajouté plus tard : le ressort lit le corps déjà posé s'il passe avant)
	sim.set_setting_count(CHAINES.size())
	# capsules de collision : cuisses et mollets (les jambes ne traversent pas la cape en marchant)
	var caps: Array[SpringBoneCollisionCapsule3D] = []
	for def: Array in [["thigh_l", "calf_l", 0.075], ["thigh_r", "calf_r", 0.075], ["calf_l", "foot_l", 0.06], ["calf_r", "foot_r", 0.06]]:
		var c := SpringBoneCollisionCapsule3D.new()
		c.name = "Col_" + String(def[0]) + ("_bas" if String(def[0]).begins_with("calf") else "")
		sim.add_child(c)
		c.bone_name = def[0]
		var v: Vector3 = sq.get_bone_rest(sq.find_bone(def[1])).origin      # vecteur os -> enfant, dans le repère de l'os
		c.radius = def[2]
		c.height = v.length() + 2.0 * float(def[2])      # hauteur totale, demi-sphères comprises
		c.position_offset = v * 0.5
		c.rotation_offset = Quaternion(Vector3.UP, v.normalized())
		caps.append(c)
	for i in CHAINES.size():
		var n: String = CHAINES[i]
		sim.set_root_bone_name(i, n + "_1")
		sim.set_end_bone_name(i, n + "_4")
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_direction(i, SpringBoneSimulator3D.BONE_DIRECTION_FROM_PARENT)
		sim.set_end_bone_length(i, 0.25)
		sim.set_radius(i, 0.03)
		sim.set_rotation_axis(i, SpringBoneSimulator3D.ROTATION_AXIS_ALL)
		sim.set_stiffness(i, RAIDEUR)
		sim.set_drag(i, AMORTI)
		sim.set_gravity(i, GRAVITE)
		sim.set_gravity_direction(i, Vector3.DOWN)
		sim.set_enable_all_child_collisions(i, avec_collisions)
