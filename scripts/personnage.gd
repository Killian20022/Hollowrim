class_name Personnage
## Fabrique des personnages « base unifiee » : `Personnage.creer(def: PersoDef) -> Node3D` (meme contrat que `Humain.creer` : un AnimationPlayer
## « Animations » et un Skeleton3D ; les animations Quaternius jouent telles quelles, les os de RIG18 portent les memes noms).
## Un kit par morphologie (assets/modeles/persos/kit_<sexe>.glb, genere par sources_blender/scripts/base_persos.py) contient TOUTES les pieces
## skinnees sur un seul squelette : corps, bagues, tetes 1-3, cheveux 1-3, barbes 1-2, accessoires. creer() instancie le kit et libere les pieces
## inutiles ; les materiaux sont PARTAGES (2 par morphologie : cull / double face), les couleurs sont des parametres d'instance.

const CHEMIN := "res://assets/modeles/persos/kit_%s.glb"
const SHADER := preload("res://shaders/perso.gdshader")

static var _scenes := {}
static var _mats := {}
static var _doubles := {}

static func _scene(sexe: String) -> PackedScene:
	if not _scenes.has(sexe):
		_scenes[sexe] = load(CHEMIN % sexe)
	return _scenes[sexe]

## Materiau partage d'une morphologie ; `double` : etoffes fines (cull_disabled + texels decoupes).
static func materiau(sexe: String, double: bool) -> ShaderMaterial:
	var cle := "%s:%s" % [sexe, double]
	if not _mats.has(cle):
		var sh := Shader.new()
		var code := SHADER.code
		if double:
			code = code.replace("specular_disabled;//CULL", "specular_disabled, cull_disabled;").replace("//DECOUPE", "if (t.a < 0.5) { discard; }")
		sh.code = code
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("atlas", PersoAtlas.texture(sexe))
		Palette._appliquer(m, Palette._ps1_actif)
		Palette.materiaux.append(m)
		_mats[cle] = m
	return _mats[cle]

static func _pieces_double(sexe: String) -> Dictionary:
	if not _doubles.has(sexe):
		var d := {}
		var rects: Dictionary = PersoAtlas.infos(sexe).get("rects", {})
		for cle: String in rects:
			if rects[cle].get("double", false):
				d[cle.get_slice(".", 0)] = true
		_doubles[sexe] = d
	return _doubles[sexe]

## Noms des pieces gardees pour une definition.
static func pieces_de(def: PersoDef) -> PackedStringArray:
	var l := PackedStringArray(["corps", "bagues", "tete_%d" % def.tete])
	if def.cheveux > 0 and not def.a("capuche") and def.casque == "":
		l.append("cheveux_%d" % def.cheveux)
	elif def.cheveux > 0 and def.casque != "" and def.casque == "couronne_givre":
		l.append("cheveux_%d" % def.cheveux)
	if def.barbe > 0 and def.corps == "homme":
		l.append("barbe_%d" % def.barbe)
	for a in def.accessoires:
		l.append(a)
	return l

static func creer(def: PersoDef) -> Node3D:
	var racine: Node3D = _scene(def.corps).instantiate()
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	var gardees := pieces_de(def)
	var dbl := _pieces_double(def.corps)
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		var nom := String(mi.name)
		if not gardees.has(nom):
			sq.remove_child(mi)
			mi.free()
			continue
		mi.material_override = materiau(def.corps, dbl.has(nom))
		mi.set_instance_shader_parameter("c_peau", def.peau)
		mi.set_instance_shader_parameter("c_tun", def.tunique)
		mi.set_instance_shader_parameter("c_pan", def.pantalon)
		mi.set_instance_shader_parameter("c_cuir", def.cuir)
		mi.set_instance_shader_parameter("c_sur", def.sur)
		mi.set_instance_shader_parameter("c_cheveux", def.couleur_cheveux)
		mi.set_instance_shader_parameter("c_four", def.fourrure)
		mi.set_instance_shader_parameter("c_iris", def.iris)
	if def.casque != "":
		Humain._accrocher(sq, "Head", "res://assets/modeles/equipement/%s.glb" % def.casque, Transform3D(Basis(), Humain._origine_tete(sq)), false)
	if def.bouclier:
		var dos := Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.3, -0.2))
		Humain._accrocher(sq, "spine_03", "res://assets/modeles/equipement/bouclier_rond.glb", dos, false)
	var ap := AnimationPlayer.new()
	ap.name = "Animations"
	racine.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", Humain.bibliotheque())
	if def.echelle != 1.0:
		racine.scale = Vector3.ONE * def.echelle
	racine.set_meta("perso_def", def)
	PersoRessorts.equiper(racine, def)
	return racine

static func vider() -> void:
	_scenes.clear()
	_mats.clear()
	_doubles.clear()
	PersoAtlas.vider()
