class_name MageTripo
## Mage généré par Tripo (essai, branche essai/mage) : robe à capuche et col de fourrure, MÊME squelette que les humains nordiques (65 os de
## homme_vetu.glb) + 2 chaînes de 3 os de jupe (« tab_f_* » devant, « tab_b_* » derrière) animées par un SpringBoneSimulator3D (collisions sur
## cuisses et mollets), en plus de poids lissés sur les cuisses ; donc mêmes clips (Humain.bibliotheque() : Idle, Walk, Spell_Simple_*...),
## PiedsAuSol, SuiviTete, Ragdoll… Le BÂTON runique (cristal de glace) est celui du mage actuel (MageNordique.Acc.baton, main droite) et
## le sort part de la main gauche (clips Spell_Simple_*) comme avant.
##   MageTripo.creer({"baton": true}) -> Node3D      (modèle : sources_blender/scripts/tripo_mage_prep.py puis tripo_mage_rig.py)
## Branché derrière l'argument utilisateur `--mage-tripo` : MageNordique.creer(...) y renvoie ce modèle (mage ennemi, pilote de test) et le PNJ
## « tripo_mage » (data/habitants_tripo.json) l'utilise ; sans l'argument le jeu est inchangé.

const GLB := preload("res://assets/pnj/tripo_mage_rig.glb")
const CHAINES := ["tab_f", "tab_b"]
## Robe de laine lourde : revient lentement, très amortie, tombe droit.
static var RAIDEUR := 0.12
static var AMORTI := 0.45
static var GRAVITE := 1.8
## Teinte de la texture : les modèles Tripo sont sombres (robe anthracite) ; léger éclaircissement pour rester lisible au village et en intérieur.
static var TEINTE := Color(1.35, 1.35, 1.4)

static func actif() -> bool:
	return OS.get_cmdline_user_args().has("--mage-tripo")

static func creer(options := {}) -> Node3D:
	var racine: Node3D = GLB.instantiate()
	racine.name = "MageTripo"
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
				var tex: Texture2D = (src as BaseMaterial3D).albedo_texture
				var mat := Palette.materiau(tex, Vector2.ONE, TEINTE, true)     # double face : intérieur de la capuche et de la robe
				mat.set_shader_parameter("tex_neige", tex)
				mi.set_surface_override_material(s, mat)
		mi.extra_cull_margin = 0.5      # T-pose du glb : la boîte englobante suit déjà les os ; marge pour la robe et le bâton
	var ap := AnimationPlayer.new()
	ap.name = "Animations"
	racine.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", Humain.bibliotheque())
	if options.get("baton", true):
		_baton(sq)
	if options.get("ressorts", true):
		_ressorts(sq, options.get("collisions", true))
	racine.set_meta("mage_nordique", true)
	racine.set_meta("mage_tripo", true)
	racine.set_meta("visage", false)
	racine.set_meta("corps", "homme")
	racine.set_meta("pnj_nordique", "tripo_mage")
	return racine

## Bâton du mage actuel (hampe runique + orbe de glace) rigide sur hand_r, redressé après l'animation par BatonDroit.
static func _baton(sq: Skeleton3D) -> void:
	var acc := MageNordique.Acc.new(sq)
	acc.baton()
	sq.add_child(acc.construire(sq.create_skin_from_rest_transforms()))
	var bd := MageNordique.BatonDroit.new()
	bd.name = "BatonDroit"
	var info: Array = sq.get_meta("baton")
	bd.os_ = info[0]
	bd.prise = sq.get_bone_global_rest(info[0]).affine_inverse() * (info[1] as Transform3D)
	sq.add_child(bd)

static func _ressorts(sq: Skeleton3D, avec_collisions: bool) -> void:
	var sim := SpringBoneSimulator3D.new()
	sim.name = "Robe"
	sq.add_child(sim)
	sim.set_setting_count(CHAINES.size())
	for def: Array in [["thigh_l", "calf_l", 0.085], ["thigh_r", "calf_r", 0.085], ["calf_l", "foot_l", 0.065], ["calf_r", "foot_r", 0.065]]:
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
