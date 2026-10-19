class_name Humain
## Fabrique de personnages humains (corps Quaternius aux proportions réelles, vêtements
## nordiques modélisés dans Blender sur le même squelette, animations partagées).
##
## Humain.creer({
##   "corps": "homme" | "femme",
##   "tenue": {"tunique": Color, "pantalon": Color, "mante": Color…}  (pièces absentes = cachées),
##   "cheveux": "Hair_Long", "barbe": true, "teinte_cheveux": Color, "peau": Color,
##   "draugr": false,
## }) -> Node3D  (avec un AnimationPlayer « Animations » et un Skeleton3D)

const CORPS := {
	"homme": "res://assets/modeles/humains/homme_vetu.glb",
	"femme": "res://assets/modeles/humains/femme_vetue.glb",
}
const ANIMATIONS := preload("res://assets/modeles/humains/animations.glb")
const BOUCLE := ["Idle", "Walk", "Walk_Formal", "Jog_Fwd", "Sprint", "Sword_Idle", "Idle_Talking", "Idle_Torch",
	"Sitting_Idle", "Fixing_Kneeling", "Spell_Simple_Idle", "Crouch_Idle", "Crouch_Fwd", "Sitting_Talking"]
const PIECES := ["tunique", "pantalon", "bottes", "ceinture", "mante", "brassards", "gants"]

## Texture de chaque pièce : [palette, période, grain, échelle UV]
const ETOFFES := {
	"tunique": [["#3a3a3a", "#474747", "#545454", "#616161"], 8, 0.5, Vector2(6, 6)],
	"pantalon": [["#353535", "#404040", "#4b4b4b", "#565656"], 8, 0.5, Vector2(6, 6)],
	"bottes": [["#1e140e", "#2c1d13", "#3d2a1b", "#4f3825"], 4, 0.5, Vector2(4, 4)],
	"ceinture": [["#1e140e", "#2c1d13", "#3d2a1b", "#4f3825"], 4, 0.5, Vector2(4, 4)],
	"mante": [["#2a2c33", "#3b3e47", "#50545e", "#6a6e78"], 8, 0.9, Vector2(10, 10)],
	"brassards": [["#1e140e", "#2c1d13", "#3d2a1b", "#4f3825"], 4, 0.5, Vector2(4, 4)],
	"gants": [["#1e140e", "#2c1d13", "#3d2a1b", "#4f3825"], 4, 0.5, Vector2(4, 4)],
}

static var _bibliotheque: AnimationLibrary

static func bibliotheque() -> AnimationLibrary:
	if _bibliotheque == null:
		var source: Node = ANIMATIONS.instantiate()
		var ap: AnimationPlayer = source.find_child("AnimationPlayer", true, false)
		_bibliotheque = ap.get_animation_library("").duplicate(true)
		for nom in BOUCLE:
			if _bibliotheque.has_animation(nom):
				_bibliotheque.get_animation(nom).loop_mode = Animation.LOOP_LINEAR
		source.free()
	return _bibliotheque

static func creer(options: Dictionary) -> Node3D:
	var racine: Node3D = load(CORPS[options.get("corps", "homme")]).instantiate()
	var squelette: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	var draugr: bool = options.get("draugr", false)
	var tenue: Dictionary = options.get("tenue", {})
	var peau: Color = options.get("peau", Color(0.95, 0.85, 0.8))
	for mi: MeshInstance3D in squelette.find_children("*", "MeshInstance3D", false, false):
		var nom := String(mi.name)
		if nom in PIECES:
			mi.visible = tenue.has(nom)
			if mi.visible:
				var e: Array = ETOFFES[nom]
				var tex := Palette.tex("etoffe_" + nom, e[0], e[1], e[2])
				var m := Palette.materiau(tex, e[3], tenue[nom])
				m.set_shader_parameter("tex_neige", tex)
				if draugr:
					m.set_shader_parameter("saturation", 0.25)
				mi.material_override = m
		elif nom.begins_with("SuperHero") or nom.begins_with("Superhero"):
			# corps entier : seulement pour le draugr (chair desséchée sous des haillons)
			mi.visible = draugr
		elif nom == "peau":
			mi.visible = not draugr
		if nom == "Eyes" and draugr:
			mi.material_override = Palette.lueur(Color(0.6, 1.8, 2.4))
	# peau, yeux, sourcils : textures d'origine réduites, ternies
	var teinte_peau := Color(0.55, 0.62, 0.68) if draugr else peau
	Palette.convertir(squelette, 128, teinte_peau, 0.2 if draugr else 0.75)
	_corriger_neige(squelette)
	if options.has("cheveux"):
		_greffer(squelette, options["cheveux"], options.get("teinte_cheveux", Color(0.5, 0.35, 0.2)))
	if options.get("barbe", false):
		_greffer(squelette, "Hair_Beard", options.get("teinte_cheveux", Color(0.5, 0.35, 0.2)))
	if options.has("casque"):
		_accrocher(squelette, "Head", "res://assets/modeles/equipement/%s.glb" % options["casque"], Transform3D(Basis(), _origine_tete(squelette)), draugr)
		# les cheveux passeraient à travers le casque (la barbe reste)
		var coupe: Node = squelette.get_node_or_null(String(options.get("cheveux", "")))
		if coupe and options["casque"] != "couronne_givre":
			coupe.visible = false
	if options.get("bouclier", false):
		# bouclier porté dans le dos, face peinte vers l'arrière
		var dos := Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.3, -0.2))
		_accrocher(squelette, "spine_03", "res://assets/modeles/equipement/bouclier_rond.glb", dos, draugr)
	var ap := AnimationPlayer.new()
	ap.name = "Animations"
	racine.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", bibliotheque())
	return racine

const MATIERES := {
	"fer": [["#3a4458", "#56627a", "#8a96ad", "#b9c3d6"], Color(0.75, 0.78, 0.85)],
	"fer_sombre": [["#22262e", "#2e333d", "#3c424e", "#4b525f"], Color(1, 1, 1)],
	"mailles": [["#2e333d", "#4b525f", "#6a7282", "#2e333d"], Color(0.9, 0.9, 0.95)],
	"gemme": [["#1f3a7a", "#2f5fb8", "#6f9be8", "#b8d8ff"], Color(1.2, 1.3, 1.5)],
	"bois": [["#2a1d14", "#3a2a1d", "#4b3826", "#5c4630"], Color(1, 1, 1)],
	"peinture": [["#5a1a14", "#7a241c", "#8e3024", "#a03a2c"], Color(1, 1, 1)],
}

## Origine des casques : la tête de l'os Head au repos (repère du modèle).
static func _origine_tete(squelette: Skeleton3D) -> Vector3:
	return squelette.get_bone_global_rest(squelette.find_bone("Head")).origin

## Accroche une pièce (exprimée dans le repère du modèle, autour de `repere`) à un os,
## en annulant l'orientation de repos de l'os.
static func _accrocher(squelette: Skeleton3D, os: String, chemin: String, repere: Transform3D, draugr: bool) -> void:
	var accroche := BoneAttachment3D.new()
	accroche.bone_name = os
	squelette.add_child(accroche)
	var piece: Node3D = load(chemin).instantiate()
	piece.transform = squelette.get_bone_global_rest(squelette.find_bone(os)).affine_inverse() * repere
	accroche.add_child(piece)
	for mi: MeshInstance3D in piece.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var nom := m.resource_name.get_slice(".", 0) if m else "fer"
			var def: Array = MATIERES.get(nom, MATIERES["fer"])
			var tex := Palette.tex("matiere_" + nom, def[0], 4, 0.4)
			var mat := Palette.materiau(tex, Vector2(2, 2), def[1])
			mat.set_shader_parameter("tex_neige", tex)
			if nom == "gemme":
				mat.set_shader_parameter("emission", Color(0.2, 0.45, 0.9))
			if draugr and nom != "gemme":
				mat.set_shader_parameter("saturation", 0.3)
				mat.set_shader_parameter("teinte", def[1] * Color(0.75, 0.68, 0.6))
			mi.set_surface_override_material(i, mat)

## Les maillages exportés de Blender ont une couleur de sommet d'alpha nul (lue comme
## « neige » par le shader) : la texture de neige devient la texture de base.
static func _corriger_neige(squelette: Skeleton3D) -> void:
	for mi: MeshInstance3D in squelette.find_children("*", "MeshInstance3D", false, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as ShaderMaterial
			if m:
				m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))

## Coupe de cheveux ou barbe : maillage d'un autre fichier, rattaché à notre squelette.
static func _greffer(squelette: Skeleton3D, nom: String, teinte: Color) -> void:
	var source: Node = load("res://assets/modeles/humains/cheveux/%s.gltf" % nom).instantiate()
	var mi := source.find_child(nom, true, false) as MeshInstance3D
	if mi == null:
		mi = source.find_children("*", "MeshInstance3D", true, false)[0]
	mi.get_parent().remove_child(mi)
	source.free()
	squelette.add_child(mi)
	mi.skeleton = NodePath("..")
	var mat := mi.get_active_material(0) as BaseMaterial3D
	var tex: Texture2D = mat.albedo_texture if mat else null
	var m := Palette.materiau(tex if tex else Palette.tex("cheveux", ["#2a1a10", "#3b2414", "#4a2e18", "#5a3a20"]), Vector2.ONE, teinte)
	m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
	m.set_shader_parameter("saturation", 0.6)
	mi.material_override = m

static func vider() -> void:
	_bibliotheque = null
