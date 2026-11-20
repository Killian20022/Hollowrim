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
const DISTANCE_LOD := 18.0      # m (+ 10 x la hauteur du modèle) : bascule des bêtes v2 sur leur maillage lointain
const HUMAINS := ["pq_villageois", "pq_villageoise", "pq_chasseur", "pq_chasseresse"]
## Habitants du village (persos/quaternius_jeu, 2026-11-04) : variantes SALIES des humains (laine teinte terne, boue au bas, usure, virage
## froid ; sources_blender/persos_quaternius/habitants.json) ; même rig UAL, mêmes clips que les humains du jeu.
const HABITANTS := ["pq_hab_paysan_a", "pq_hab_paysan_b", "pq_hab_paysan_c", "pq_hab_paysanne_a", "pq_hab_paysanne_b", "pq_hab_paysanne_c",
	"pq_hab_chasseur_a", "pq_hab_chasseur_b", "pq_hab_chasseresse_a", "pq_hab_chasseresse_b"]
static var _anciens := -1

## `-- --persos-anciens` : avant/après. Les habitants reprennent les corps Humain.creer, la faune et les bêtes Quaternius ne sont pas posées.
static func anciens() -> bool:
	if _anciens < 0:
		_anciens = 1 if OS.get_cmdline_user_args().has("--persos-anciens") else 0
	return _anciens == 1

static func est_humain(id: String) -> bool:
	return id in HUMAINS or id.begins_with("pq_hab_")

static var _materiau: ShaderMaterial
static var _scenes := {}
static var _mats_tex := {}
static var _betes_anciennes := -1

## Bêtes v2 (art/animaux_v2, 2026-11-20 : fourrure géométrique, texture peinte de poils, LOD « _loin ») : `pq_<x>_v2.glb` + `.png`.
## `-- --animaux-anciens` remet les bêtes Quaternius v1 (avant/après, retour arrière).
static func animaux_anciens() -> bool:
	if _betes_anciennes < 0:
		_betes_anciennes = 1 if OS.get_cmdline_user_args().has("--animaux-anciens") else 0
	return _betes_anciennes == 1

## Id du modèle à poser pour une bête : sa version v2 si elle existe (et pas --animaux-anciens), sinon l'id v1.
static func id_bete(id: String, v2: String) -> String:
	if v2 == "" or animaux_anciens() or not ResourceLoader.exists(DOSSIER % v2):
		return id
	return v2

## Matériau ps1_perso d'un modèle texturé (même réglages que materiau(), texture peinte du modèle).
static func materiau_tex(id: String) -> ShaderMaterial:
	if not _mats_tex.has(id):
		var chemin := (DOSSIER % id).get_basename() + ".png"
		if not ResourceLoader.exists(chemin):
			_mats_tex[id] = materiau()
		else:
			var m := materiau().duplicate() as ShaderMaterial
			m.set_shader_parameter("tex_base", load(chemin))
			Palette.suivre(m)
			_mats_tex[id] = m
	return _mats_tex[id]

static func materiau() -> ShaderMaterial:
	if _materiau == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("tex_base", ImageTexture.create_from_image(img))
		m.set_shader_parameter("grille", 135.0)
		m.set_shader_parameter("affine", Palette.AFFINE)
		Palette.suivre(m)
		_materiau = m
	return _materiau

static func creer(id: String) -> Node3D:
	if not _scenes.has(id):
		_scenes[id] = load(DOSSIER % id) as PackedScene
	var racine: Node3D = (_scenes[id] as PackedScene).instantiate()
	racine.set_meta("pq", id)
	var mat := materiau_tex(id) if id.ends_with("_v2") else materiau()
	var loin: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if String(mi.name).ends_with("_loin"):
			loin.append(mi)
	if not loin.is_empty():
		# LOD : maillage proche (fourrure) jusqu'à D, maillage lointain (corps décimé, sans mèches) au-delà ; D suit la taille
		var aabb := AABB()
		for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
			if not loin.has(mi):
				aabb = mi.get_aabb()
		var d := DISTANCE_LOD + 10.0 * aabb.size.y
		for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
			if loin.has(mi):
				mi.visibility_range_begin = d
			else:
				mi.visibility_range_end = d
	var ap := racine.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if est_humain(id):
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
		for nom: StringName in [&"Eat", &"Idle_2"]:
			if lib.has_animation(nom):
				lib.get_animation(nom).loop_mode = Animation.LOOP_LINEAR
		for alias: Array in [["Jog_Fwd", "Run"], ["Sprint", "Run"], ["Sword_Idle", "Idle"], ["Death01", "Death"], ["Hit_Chest", "Hit"]]:
			if lib.has_animation(alias[1]) and not lib.has_animation(alias[0]):
				lib.add_animation(alias[0], lib.get_animation(alias[1]))
	return racine

## Nom du clip Idle / marche / attaque / mort selon le type (humains : clips UAL du jeu).
static func clip(id: String, role: String) -> String:
	if est_humain(id):
		return {"idle": "Idle", "marche": "Walk", "attaque": "Sword_Attack", "mort": "Death01"}.get(role, "Idle")
	return {"idle": "Idle", "marche": "Walk", "attaque": "Attack", "mort": "Death"}.get(role, "Idle")
