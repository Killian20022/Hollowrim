class_name PersosQuat
## Personnages, monstres et animaux QUATERNIUS (CC0) convertis au rendu PS1 (sources_blender/scripts/pq_convertir.py).
## Le glb contient : un Skeleton3D, UN maillage aux couleurs de sommet (accrochées à la palette de la bible), des clips
## Idle / Walk / Run / Attack / Death / Hit (monstres, animaux). Les humains (rig UBC = rig UAL) n'ont pas de clips : on leur
## donne la bibliothèque UAL du jeu (Humain.bibliotheque()), comme aux autres humains.
##
##   PersosQuat.creer("pq_loup") -> Node3D  (AnimationPlayer « Animations », Skeleton3D ; méta « pq » = id)
##   Rendu : shaders/ps1_perso.gdshader (grille d'écran, mapping affine, liseré froid), même matériau pour tout le monde.

const SHADER := preload("res://shaders/ps1_perso.gdshader")
const DOSSIER := "res://assets/modeles/persos_quat/%s.glb"
const HUMAINS := ["pq_villageois", "pq_villageoise", "pq_chasseur", "pq_chasseresse"]

static var _materiau: ShaderMaterial
static var _scenes := {}

static func materiau() -> ShaderMaterial:
	if _materiau == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("tex_base", ImageTexture.create_from_image(img))
		m.set_shader_parameter("grille", 135.0)
		m.set_shader_parameter("affine", Palette.AFFINE)
		Palette.materiaux.append(m)
		_materiau = m
	return _materiau

static func creer(id: String) -> Node3D:
	if not _scenes.has(id):
		_scenes[id] = load(DOSSIER % id) as PackedScene
	var racine: Node3D = (_scenes[id] as PackedScene).instantiate()
	racine.set_meta("pq", id)
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = materiau()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var ap := racine.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if id in HUMAINS:
		if ap != null:
			ap.get_parent().remove_child(ap)
			ap.free()
		ap = AnimationPlayer.new()
		ap.name = "Animations"
		racine.add_child(ap)
		ap.root_node = NodePath("..")
		ap.add_animation_library("", Humain.bibliotheque())
	elif ap != null:
		ap.name = "Animations"
		var lib := ap.get_animation_library("")
		for nom: StringName in lib.get_animation_list():
			if nom in [&"Idle", &"Walk", &"Run"]:
				lib.get_animation(nom).loop_mode = Animation.LOOP_LINEAR
		# alias aux noms que l'IA des ennemis (EnnemiBase._bouger / _jouer) demande : même clip, nom du contrat des humains
		for alias: Array in [["Jog_Fwd", "Run"], ["Sprint", "Run"], ["Sword_Idle", "Idle"], ["Death01", "Death"], ["Hit_Chest", "Hit"]]:
			if lib.has_animation(alias[1]) and not lib.has_animation(alias[0]):
				lib.add_animation(alias[0], lib.get_animation(alias[1]))
	return racine

## Nom du clip Idle / marche / attaque / mort selon le type (humains : clips UAL du jeu).
static func clip(id: String, role: String) -> String:
	if id in HUMAINS:
		return {"idle": "Idle", "marche": "Walk", "attaque": "Sword_Attack", "mort": "Death01"}.get(role, "Idle")
	# Idle des rigs « EnemyArmature » (géant, squelette) = pose de liaison en T dans le pack d'origine : on joue la marche à la place
	if role == "idle" and id in ["pq_geant", "pq_squelette"]:
		return "Walk"
	return {"idle": "Idle", "marche": "Walk", "attaque": "Attack", "mort": "Death"}.get(role, "Idle")
