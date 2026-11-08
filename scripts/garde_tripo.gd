class_name GardeTripo
## Gardes générés par Tripo (essai, branche essai/tripo) : lancier, garde à l'épée, archer. MÊME squelette que les humains nordiques (65 os de
## homme_vetu.glb) + 2 chaînes de 3 os de tabard (« tab_f_* » devant, « tab_b_* » derrière) animées par un SpringBoneSimulator3D (collisions
## sur cuisses et mollets) ; donc mêmes clips (Humain.bibliotheque()), PiedsAuSol, SuiviTete, Ragdoll… L'arme est rigide (lance et épée sur la
## main droite, arc et carquois sur spine_03). Lancier : le bras droit reste figé dans la pose A du modèle dans tous les clips (la hampe ne se balance pas).
##   GardeTripo.creer("tripo_garde_lance" | "tripo_garde_epee" | "tripo_archer") -> Node3D   (modèles : sources_blender/scripts/tripo_rig.py)
## Utilisé par PnjNordique.creer(id), habitants de data/habitants_tripo.json (inactifs sauf argument --jarl-tripo ou --gardes-tripo).

const MODELES := {
	"tripo_garde_lance": preload("res://assets/pnj/tripo_garde_lance_rig.glb"),
	"tripo_garde_epee": preload("res://assets/pnj/tripo_garde_epee_rig.glb"),
	"tripo_archer": preload("res://assets/pnj/tripo_archer_rig.glb"),
}
const EPEE := preload("res://assets/modeles/joueur/epee_nordique.glb")
static var EPEE_ROT := Vector3(120, 0, 0)
static var EPEE_POS := Vector3(0, 0.02, -0.035)
const CHAINES := ["tab_f", "tab_b"]
## Tabard de laine : plus léger que la cape du jarl, mais amorti.
static var RAIDEUR := 0.15
static var AMORTI := 0.40
static var GRAVITE := 1.6
const BRAS_DROIT := ["upperarm_r", "lowerarm_r", "hand_r"]

static func creer(id: String, ressorts := true, avec_collisions := true) -> Node3D:
	var racine: Node3D = (MODELES[id] as PackedScene).instantiate()
	racine.name = "Pnj" + id.capitalize().replace(" ", "")
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
				var tex: Texture2D = (src as BaseMaterial3D).albedo_texture
				var mat := Palette.materiau(tex, Vector2.ONE, Color.WHITE, true)   # double face
				mat.set_shader_parameter("tex_neige", tex)
				mi.set_surface_override_material(s, mat)
		mi.extra_cull_margin = 0.5      # T-pose du glb : la boîte englobante suit déjà les os ; marge pour l'arme et l'arc
	var ap := AnimationPlayer.new()
	ap.name = "Animations"
	racine.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", _bibliotheque(sq, id == "tripo_garde_lance"))
	match id:
		"tripo_garde_epee":
			_epee_au_flanc(sq)
		"tripo_archer":
			ChasseresseNordique.equiper_arc(racine, sq)      # le vrai arc du jeu : porté le long du corps, bandé (corde tirée) puis relâché (clips Pistol_*)
		"tripo_garde_lance":
			var m := LanceDroite.new()
			m.name = "LanceDroite"
			m.os_haut = sq.find_bone("upperarm_r")
			m.os_parent = sq.get_bone_parent(m.os_haut)
			m.cible = ROT_BRAS_DROIT * sq.get_bone_global_rest(m.os_haut).basis.get_rotation_quaternion()
			sq.add_child(m)
	if ressorts:
		_ressorts(sq, avec_collisions)
	racine.set_meta("pnj_nordique", id)
	return racine

## Bibliothèque des humains ; pour le lancier, copie dont le bras droit reste figé dans la pose A du modèle (la hampe reste verticale, ne se
## balance pas) : rotation ROT_BRAS_DROIT de l'os upperarm_r (tripo_rig.py, ligne ROTGODOT r), lowerarm_r et hand_r au repos. La bibliothèque commune n'est pas modifiée.
const ROT_BRAS_DROIT := Quaternion(0.0, 0.47019, 0.37495, 0.79896)
static func _bibliotheque(sq: Skeleton3D, bras_fige: bool) -> AnimationLibrary:
	var src := Humain.bibliotheque()
	if not bras_fige:
		return src
	var figes := {}
	for nom: String in BRAS_DROIT:
		var i := sq.find_bone(nom)
		var rep := sq.get_bone_rest(i).basis.get_rotation_quaternion()
		if nom == "upperarm_r":
			var gp := sq.get_bone_global_rest(sq.get_bone_parent(i)).basis.get_rotation_quaternion()
			rep = gp.inverse() * ROT_BRAS_DROIT * gp * rep
		figes[nom] = rep
	var lib := AnimationLibrary.new()
	for nom: StringName in src.get_animation_list():
		var a := src.get_animation(nom).duplicate() as Animation
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var os_nom := String(a.track_get_path(t)).get_slice(":", 1)
			if not figes.has(os_nom):
				continue
			while a.track_get_key_count(t) > 0:
				a.track_remove_key(t, 0)
			a.rotation_track_insert_key(t, 0.0, figes[os_nom])
		lib.add_animation(nom, a)
	return lib

static func _ressorts(sq: Skeleton3D, avec_collisions: bool) -> void:
	var sim := SpringBoneSimulator3D.new()
	sim.name = "Tabard"
	sq.add_child(sim)
	sim.set_setting_count(CHAINES.size())
	for def: Array in [["thigh_l", "calf_l", 0.075], ["thigh_r", "calf_r", 0.075], ["calf_l", "foot_l", 0.06], ["calf_r", "foot_r", 0.06]]:
		var c := SpringBoneCollisionCapsule3D.new()
		c.name = "Col_" + String(def[0]) + ("_bas" if String(def[0]).begins_with("calf") else "")
		sim.add_child(c)
		c.bone_name = def[0]
		var v: Vector3 = sq.get_bone_rest(sq.find_bone(def[1])).origin
		c.radius = def[2]
		c.height = v.length() + 2.0 * float(def[2])
		c.position_offset = v * 0.5
		c.rotation_offset = Quaternion(Vector3.UP, v.normalized())
	for i in CHAINES.size():
		var n: String = CHAINES[i]
		sim.set_root_bone_name(i, n.replace("tab_f", "tab_f_1").replace("tab_b", "tab_b_1"))
		sim.set_end_bone_name(i, n + "_3")
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_direction(i, SpringBoneSimulator3D.BONE_DIRECTION_FROM_PARENT)
		sim.set_end_bone_length(i, 0.15)
		sim.set_radius(i, 0.03)
		sim.set_rotation_axis(i, SpringBoneSimulator3D.ROTATION_AXIS_ALL)
		sim.set_stiffness(i, RAIDEUR)
		sim.set_drag(i, AMORTI)
		sim.set_gravity(i, GRAVITE)
		sim.set_gravity_direction(i, Vector3.DOWN)
		sim.set_enable_all_child_collisions(i, avec_collisions)

## Lancier : le bras droit garde, dans le repère du MONDE, l'orientation de la pose A du modèle (hampe verticale) : on corrige chaque image
## l'inclinaison du torse (en marche, spine_03 se penche d'une vingtaine de degrés) sur l'os du bras. L'épaule suit le torse, la hampe reste droite.
class LanceDroite extends SkeletonModifier3D:
	var os_haut := -1
	var os_parent := -1
	var cible := Quaternion.IDENTITY      # orientation voulue de upperarm_r dans l'espace du squelette

	func _process_modification_with_delta(_dt: float) -> void:
		var sq := get_skeleton()
		if sq == null or os_haut < 0:
			return
		var gp := sq.get_bone_global_pose(os_parent).basis.get_rotation_quaternion()
		sq.set_bone_pose_rotation(os_haut, gp.inverse() * cible)

## Épée du jeu (epee_nordique.glb, mêmes matières que l'épée du joueur) TENUE dans la main droite (BoneAttachment3D sur « hand_r »).
static func _epee_au_flanc(sq: Skeleton3D) -> void:
	var acc := BoneAttachment3D.new()
	acc.name = "EpeeMain"
	acc.bone_name = "hand_r"
	sq.add_child(acc)
	var arme: Node3D = EPEE.instantiate()
	arme.name = "EpeeJeu"
	arme.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(EPEE_ROT.x), deg_to_rad(EPEE_ROT.y), deg_to_rad(EPEE_ROT.z))), EPEE_POS)
	acc.add_child(arme)
	var acier := Palette.tex("acier", Palette.ACIER, 4, 0.3)
	var mats := {
		"lame": Palette.materiau(acier, Vector2.ONE, Color(0.9, 0.95, 1.05)),
		"fer": Palette.materiau(acier, Vector2(2, 2), Color(0.5, 0.52, 0.6)),
		"cuir": Palette.materiau(Palette.tex("cuir", Palette.CUIR, 4, 0.5), Vector2(1, 2)),
	}
	for m: ShaderMaterial in mats.values():
		m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
	for mi: MeshInstance3D in arme.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			var nom := mat.resource_name.get_slice(".", 0) if mat else ""
			if mats.has(nom):
				mi.set_surface_override_material(i, mats[nom])
