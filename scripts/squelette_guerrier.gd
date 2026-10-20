class_name SqueletteGuerrier
## Squelette nordique guerrier : ossements purs (≠ draugr), 590 triangles avec épée (596 avec arc), pièces rigides 1 os par sommet.
## Même squelette que les humains (RIG18 + 4 os feuilles du ragdoll) : animations de Humain.bibliotheque() et Ragdoll utilisés tels quels.
## Modèle : sources_blender/scripts/squelette_guerrier.py -> assets/modeles/squelettes/squelette_guerrier.glb (maillages « squelette », « epee », « arc »).
## Atlas 256² peint par le même script (1 îlot par face, DENSITE_PERSO texels/m) ; précalculé par outils/generer_squelette.gd.
##
##   SqueletteGuerrier.creer({"arme": "epee" | "arc"}) -> Node3D (Skeleton3D + AnimationPlayer « Animations »)

const GLB := preload("res://assets/modeles/squelettes/squelette_guerrier.glb")
const DOSSIER := "res://assets/personnages"
const RES := "res://assets/personnages/squelette_guerrier.res"
const PNG := "res://sources_blender/squelette_guerrier_atlas.png"
const VERSION := 1
## Texels par mètre de l'atlas (la valeur est cuite dans les UV par le script Blender : la changer = rejouer le script).
const DENSITE_PERSO := 32.0
## Lueur froide des orbites (surface 1 du maillage « squelette »), minime : lisible de nuit.
const LUEUR_ORBITES := Color(0.10, 0.24, 0.36)

static var _tex: ImageTexture
static var _mat: ShaderMaterial
static var _mat_orbites: StandardMaterial3D

static func image() -> Image:
	var a: Image = null
	if ResourceLoader.exists(RES):
		a = ResourceLoader.load(RES) as Image
		if a != null and a.get_meta("version", -1) != VERSION:
			a = null
	if a == null:
		a = Image.load_from_file(ProjectSettings.globalize_path(PNG))
	return a

static func materiaux() -> void:
	if _mat != null:
		return
	var a := image().duplicate() as Image
	a.convert(Image.FORMAT_RGBA8)
	a.generate_mipmaps()
	_tex = ImageTexture.create_from_image(a)
	_mat = Palette.materiau(_tex, Vector2.ONE, Color.WHITE)
	_mat.shader = Humain.shader_perso(false)
	_mat.set_shader_parameter("tex_neige", _tex)
	_mat.set_shader_parameter("saturation", 0.9)
	_mat_orbites = Palette.lueur(LUEUR_ORBITES)

static func creer(options := {}) -> Node3D:
	materiaux()
	var racine: Node3D = GLB.instantiate()
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	var arme: String = options.get("arme", "epee")
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		var nom := String(mi.name)
		if nom == "epee" or nom == "arc":
			mi.visible = nom == arme
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, _mat_orbites if s == 1 else _mat)
	var ap := AnimationPlayer.new()
	ap.name = "Animations"
	racine.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", Humain.bibliotheque())
	return racine

static func vider() -> void:
	_tex = null
	_mat = null
	_mat_orbites = null
