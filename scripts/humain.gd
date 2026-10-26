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
const PIECES := ["tunique", "pantalon", "bottes", "ceinture", "mante", "brassards", "gants",
	"robe", "cape", "cape_courte", "tablier", "capuche", "epaulieres", "haillons", "pteruges", "sacoche", "carquois", "manchettes"]
## Pièces de silhouette (sources_blender/scripts/personnages_accessoires.py) : type de texture qu'elles empruntent.
const TYPE_TEX := {"robe": "tunique", "cape": "tunique", "cape_courte": "tunique", "tablier": "tunique", "capuche": "tunique",
	"haillons": "tunique", "pteruges": "tunique", "epaulieres": "brassards", "sacoche": "bottes", "carquois": "bottes", "manchettes": "mante"}

## Variante d'étoffe par défaut de chaque pièce (PersonnagesTextures, lot 4) : « neutre » = tissage gris que la couleur de `tenue` teinte
## (anciens appels : galerie, Eirik) ; les rôles choisissent leurs variantes par `etoffes` et la teinte est alors blanche.
const DEFAUT := {"tunique": "neutre", "pantalon": "neutre", "bottes": "cuir_a", "ceinture": "cuir_a", "mante": "gris", "brassards": "cuir_a", "gants": "cuir_a",
	"surcotte": "neutre", "robe": "neutre", "cape": "gris", "cape_courte": "gris", "tablier": "cuir_a", "capuche": "neutre", "epaulieres": "fer", "haillons": "lin",
	"pteruges": "cuir_a", "sacoche": "cuir_b", "carquois": "cuir_a", "manchettes": "gris"}
const DEFAUT_DRAUGR := {"tunique": "draugr", "pantalon": "draugr", "bottes": "draugr", "ceinture": "draugr", "mante": "draugr", "brassards": "draugr", "gants": "cuir_b",
	"surcotte": "draugr", "robe": "draugr", "cape": "draugr", "cape_courte": "draugr", "tablier": "draugr", "capuche": "draugr", "epaulieres": "draugr",
	"haillons": "draugr", "pteruges": "draugr", "sacoche": "draugr", "carquois": "draugr", "manchettes": "draugr"}

static var _shaders_perso := {}

## Variante de ps1.gdshader pour les personnages : mipmaps plus proche voisin sur la texture de base (à 8 m le tissage à 64 texels/m
## est réduit ~3 fois : sans mipmaps, il scintille). Les autres textures du jeu gardent le shader d'origine.
static func shader_perso(double_face: bool) -> Shader:
	if not _shaders_perso.has(double_face):
		var sh := Shader.new()
		var code: String = Palette.PS1.code.replace("uniform sampler2D tex_base : source_color, filter_nearest, repeat_enable;", "uniform sampler2D tex_base : source_color, filter_nearest_mipmap, repeat_enable;")
		if double_face:
			code = code.replace("render_mode diffuse_lambert, specular_disabled;", "render_mode diffuse_lambert, specular_disabled, cull_disabled;")
		sh.code = code
		_shaders_perso[double_face] = sh
	return _shaders_perso[double_face]

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

## Scènes importées (corps ~16 Mo, cheveux, casques, bouclier) gardées en mémoire : `load(x).instantiate()` seul relâchait la
## PackedScene aussitôt (le nœud créé ne la retient pas) et le personnage suivant relisait tout le fichier (corps : 0,6-1 s ; une
## coupe de cheveux : 0,2-0,6 s), à chaque PNJ quand le préchargement (Prechargement, coupé en --headless) ne la retenait pas.
## Mêmes fichiers, même importeur : aucun effet sur le rendu. Lecture seule une fois remplie ; verrou : les archétypes se
## construisent aussi dans des fils (EnnemisNordiques.prechauffer_fil).
static var _scenes := {}
static var _scenes_mx := Mutex.new()

static func scene(chemin: String) -> PackedScene:
	_scenes_mx.lock()
	var ps: PackedScene = _scenes.get(chemin)
	_scenes_mx.unlock()
	if ps == null:
		ps = load(chemin) as PackedScene
		if ps != null:
			_scenes_mx.lock()
			_scenes[chemin] = ps
			_scenes_mx.unlock()
	return ps

static func creer(options: Dictionary) -> Node3D:
	var racine: Node3D = scene(CORPS[options.get("corps", "homme")]).instantiate()
	var squelette: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	var draugr: bool = options.get("draugr", false)
	var tenue: Dictionary = options.get("tenue", {})
	var peau: Color = options.get("peau", Color(0.95, 0.85, 0.8))
	for mi: MeshInstance3D in squelette.find_children("*", "MeshInstance3D", false, false):
		var nom := String(mi.name)
		if nom in PIECES:
			mi.visible = tenue.has(nom)
			if mi.visible:
				var etoffes: Dictionary = options.get("etoffes", {})
				var variante: String = etoffes.get(nom, (DEFAUT_DRAUGR if draugr else DEFAUT)[nom])
				var tex := PersonnagesTextures.tex(TYPE_TEX.get(nom, nom) + "_" + variante)
				var teinte: Color = Color.WHITE if (etoffes.has(nom) or draugr) else tenue[nom]
				var m := Palette.materiau(tex, Vector2.ONE, teinte, true)
				m.shader = shader_perso(true)
				m.set_shader_parameter("tex_neige", tex)
				mi.material_override = m
		elif nom.begins_with("SuperHero") or nom.begins_with("Superhero"):
			# corps entier : seulement pour le draugr (chair desséchée sous des haillons)
			mi.visible = true
			if not draugr:
				mi.material_override = _sous_couche(tenue)
		elif nom == "peau":
			mi.visible = not draugr
		if nom == "Eyes" and draugr:
			mi.material_override = Palette.lueur(Color(0.6, 1.8, 2.4))
	# peau, yeux, sourcils : textures d'origine réduites, ternies
	var teinte_peau := Color(0.55, 0.62, 0.68) if draugr else peau
	_peau(squelette, options.get("corps", "homme"), draugr, teinte_peau, Color(0.2, 0.2, 0.22) if draugr else options.get("teinte_cheveux", Color(0.3, 0.2, 0.12)) * 0.75)
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
	if tenue.has("capuche"):
		var coupe2: Node = squelette.get_node_or_null(String(options.get("cheveux", "")))
		if coupe2:
			coupe2.visible = false
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

static var _mats_peau := {}

## Peau, yeux et sourcils (lot 4) : atlas redessinés par PersonnagesTextures (réduction en moyenne, rampe de 10 tons, visage lisible),
## au lieu de la texture d'origine réduite au plus proche voisin. Un peu de lumière propre à la peau (`emission`) : pas de visage noir la nuit.
static func _peau(squelette: Skeleton3D, corps: String, draugr: bool, teinte: Color, teinte_sourcils: Color) -> void:
	for mi: MeshInstance3D in squelette.find_children("*", "MeshInstance3D", false, false):
		if mi.material_override != null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var nom := mat.resource_name if mat else ""
			var tex_nom := ""
			if nom.contains("Superhero") or nom.contains("SuperHero"):
				tex_nom = "peau_%s%s" % [corps, "_draugr" if draugr else ""]
			elif nom.contains("Eyes"):
				tex_nom = "yeux_draugr" if draugr else "yeux"
			elif nom.contains("Hair"):
				tex_nom = "sourcils"
			else:
				continue
			var t_mat := teinte_sourcils if tex_nom == "sourcils" else teinte
			var cle := "%s:%s" % [tex_nom, t_mat.to_html()]
			if not _mats_peau.has(cle):
				var m := Palette.materiau(PersonnagesTextures.tex(tex_nom), Vector2.ONE, t_mat)
				m.shader = shader_perso(false)
				m.set_shader_parameter("saturation", 0.55 if draugr else 0.9)
				if tex_nom.begins_with("peau"):
					m.set_shader_parameter("emission", Color(0.03, 0.04, 0.05) if draugr else Color(0.05, 0.04, 0.04))
				_mats_peau[cle] = m
			mi.set_surface_override_material(s, _mats_peau[cle])

## Sous-couche : le corps entier, rentré de 1,6 cm (les vêtements sont à 1 à 5 cm de la peau), sous
## l'étoffe. Les vêtements sont découpés dans le corps : sans elle, la moindre fissure entre deux
## pièces (tremblement des sommets, animation) laisse voir le vide. Rentrée, elle ne traverse pas l'étoffe.
static func _sous_couche(tenue: Dictionary) -> ShaderMaterial:
	var base: Color = tenue.get("pantalon", tenue.get("tunique", Color(0.5, 0.5, 0.5)))
	var tex := PersonnagesTextures.tex("pantalon_neutre")
	var m := Palette.materiau(tex, Vector2.ONE, base * 0.6)
	m.set_shader_parameter("tex_neige", tex)
	m.set_shader_parameter("gonfle", -0.016)
	return m

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
	var piece: Node3D = scene(chemin).instantiate()
	piece.transform = squelette.get_bone_global_rest(squelette.find_bone(os)).affine_inverse() * repere
	accroche.add_child(piece)
	for mi: MeshInstance3D in piece.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var nom := m.resource_name.get_slice(".", 0) if m else "fer"
			var def: Array = MATIERES.get(nom, MATIERES["fer"])
			var tex := Palette.tex("matiere_" + nom, def[0], 4, 0.4)
			var mat := Palette.materiau(tex, Vector2(2, 2), def[1], true)
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
	var source: Node = scene("res://assets/modeles/humains/cheveux/%s.gltf" % nom).instantiate()
	var mi := source.find_child(nom, true, false) as MeshInstance3D
	if mi == null:
		mi = source.find_children("*", "MeshInstance3D", true, false)[0]
	mi.get_parent().remove_child(mi)
	source.free()
	squelette.add_child(mi)
	mi.skeleton = NodePath("..")
	var mat := mi.get_active_material(0) as BaseMaterial3D
	var tex: Texture2D = mat.albedo_texture if mat else null
	var m := Palette.materiau(tex if tex else Palette.tex("cheveux", ["#2a1a10", "#3b2414", "#4a2e18", "#5a3a20"]), Vector2.ONE, teinte, true)
	m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
	m.set_shader_parameter("saturation", 0.6)
	mi.material_override = m

static func vider() -> void:
	_bibliotheque = null
	_scenes_mx.lock()
	_scenes.clear()
	_scenes_mx.unlock()
	_mats_peau.clear()
	_shaders_perso.clear()
	PersonnagesTextures.vider()
