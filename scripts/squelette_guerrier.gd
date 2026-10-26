class_name SqueletteGuerrier
## Squelette nordique (refonte D/squelettes, au niveau du draugr) : ossements modelés dans Blender (crâne anatomique E/crane_squelette :
## orbites profondes et sombres, cavité nasale en cœur inversé, pommettes, tempes creusées, mandibule distincte entrouverte, dents une à une ; colonne vertèbre par vertèbre, 20 côtes + sternum, clavicules et omoplates, bassin à ailes
## iliaques, fémur/tibia/péroné, humérus/radius/cubitus, mains en poing, pieds à 5 rayons) + restes d'équipement nordique
## (casque à nasal rouillé, capuche et cape en lambeaux, pagne, ceinture, brassard, bouclier de planches ébréché, épée ébréchée,
## hache barbue, arc, carquois).
## Même squelette que les humains (RIG18 + 4 feuilles du ragdoll) : animations de Humain.bibliotheque() et Ragdoll tels quels.
## Modèle : sources_blender/scripts/squelette_nordique.py -> assets/modeles/squelettes/squelette_nordique.glb ; atlas 512² peint par le même
## script (bake Cycles AO + cavité + arêtes, quantifié en rampes, bruit — jamais de Bayer), mipmaps pixel art précalculées par
## outils/generer_squelette.gd. Matériaux = ceux du draugr (shader ps1_draugr : lueur froide au fond des orbites = alpha de couleur 0).
##
##   SqueletteGuerrier.creer({"arme": "epee" | "arc" | "hache", "casque": bool}) -> Node3D (Skeleton3D + AnimationPlayer « Animations »)
##   SqueletteGuerrier.modele(arme)  -> copie (duplicate) d'un gabarit préconstruit (jeu : aucune construction après le chargement)
## Variantes : guerrier (« epee » : casque, bouclier, épée), archer (« arc » : capuche, carquois, arc), sbire (« hache » : crâne nu, hache).
## Le sbire a son propre atlas (« _nu » : ossements cuits sans casque ni capuche ; avec l'atlas commun, la voûte du crâne, cuite dans
## l'ombre des couvre-chefs, sortait noire/brune = un bonnet). Même UV, même maillage : seule la texture change (2 matériaux de plus).

const GLB := preload("res://assets/modeles/squelettes/squelette_nordique.glb")
const DOSSIER := "res://assets/personnages"
const RES := "res://assets/personnages/squelette_nordique.res"
const PNG := "res://sources_blender/squelette_nordique_atlas.png"
const RES_NU := "res://assets/personnages/squelette_nordique_nu.res"
const PNG_NU := "res://sources_blender/squelette_nordique_atlas_nu.png"
## Variantes à crâne nu (atlas _nu)
const CRANE_NU := ["hache"]
const VERSION := 6
## Maillages visibles par variante (les autres sont cachés : ils ne coûtent rien au rendu)
const PIECES := {
	"epee": ["squelette", "lambeaux", "casque", "bouclier", "epee"],
	"arc": ["squelette", "lambeaux", "capuche", "carquois", "arc"],
	"hache": ["squelette", "lambeaux", "hache"],
}
## Étoffes : double face, texels découpés (trous)
const ETOFFES := ["lambeaux", "capuche"]
const SATURATION_OS := 0.6

static var _tex: ImageTexture
static var _mat_os: ShaderMaterial
static var _mat_etoffe: ShaderMaterial
static var _tex_nu: ImageTexture
static var _mat_os_nu: ShaderMaterial
static var _mat_etoffe_nu: ShaderMaterial
static var _gabarits := {}
static var _mx := Mutex.new()
static var _arc_mesh: Mesh
static var _arc_skin: Skin

## Atlas mipmappé (précalcul .res ; repli : PNG + mipmaps calculées, ~1 s)
static func image(nu := false) -> Image:
	var res := RES_NU if nu else RES
	if ResourceLoader.exists(res):
		var a := ResourceLoader.load(res) as Image
		if a != null and a.get_meta("version", -1) == VERSION and a.has_mipmaps():
			return a
	var p := Image.load_from_file(ProjectSettings.globalize_path(PNG_NU if nu else PNG))
	p.convert(Image.FORMAT_RGBA8)
	return GuerrierTextures.mips_pixel(p)

static func materiaux() -> void:
	if _mat_os != null:
		return
	_tex = ImageTexture.create_from_image(image())
	_mat_os = DraugrNordique.materiau(_tex, false, false, true, "squelette_os")
	_mat_etoffe = DraugrNordique.materiau(_tex, true, true, true, "squelette_etoffe")
	# os : saturation réduite (sous la torche orangée, l'ivoire ne vire pas au saumon) ; même réglage que la chair du draugr, moins fort
	_mat_os.set_shader_parameter("saturation", SATURATION_OS)
	_tex_nu = ImageTexture.create_from_image(image(true))
	_mat_os_nu = DraugrNordique.materiau(_tex_nu, false, false, true, "squelette_os_nu")
	_mat_etoffe_nu = DraugrNordique.materiau(_tex_nu, true, true, true, "squelette_etoffe_nu")
	_mat_os_nu.set_shader_parameter("saturation", SATURATION_OS)

## Construction complète (instance du glb + matériaux + animations). Préférer modele() en jeu.
static func creer(options := {}) -> Node3D:
	materiaux()
	var arme: String = options.get("arme", "epee")
	if not PIECES.has(arme):
		arme = "epee"
	var visibles: Array = (PIECES[arme] as Array).duplicate()
	if options.has("casque"):
		visibles.erase("casque")
		if options["casque"]:
			visibles.append("casque")
	var racine: Node3D = GLB.instantiate()
	racine.name = "SqueletteNordique"
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	var nu := CRANE_NU.has(arme)
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		var nom := String(mi.name)
		mi.visible = visibles.has(nom)
		var m := (_mat_etoffe_nu if nu else _mat_etoffe) if ETOFFES.has(nom) else (_mat_os_nu if nu else _mat_os)
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, m)
	var ap := AnimationPlayer.new()
	ap.name = "Animations"
	racine.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", Humain.bibliotheque())
	racine.set_meta("variante", "squelette_" + arme)
	return racine

## Gabarit de la variante `arme` (construit une fois, hors de l'arbre ; sûr depuis un fil de chargement).
static func gabarit(arme: String) -> Node3D:
	_mx.lock()
	var g: Node3D = _gabarits.get(arme)
	if g == null:
		g = creer({"arme": arme})
		_gabarits[arme] = g
	_mx.unlock()
	return g

## Copie neuve d'un gabarit (≈ duplicate, sans recharger le glb ni refaire les matériaux).
static func modele(arme: String) -> Node3D:
	var n := gabarit(arme).duplicate() as Node3D
	n.set_meta("variante", "squelette_" + arme)
	return n

## Préconstruit les 3 variantes (chargement).
static func prechauffer() -> void:
	for a: String in PIECES:
		gabarit(a)

## Arc seul (maillage + peau, même rig) pour les archers humains / draugrs : MeshInstance3D neuf, à poser sous un Skeleton3D.
static func arc() -> MeshInstance3D:
	if _arc_mesh == null:
		var src: Node3D = GLB.instantiate()
		var a := src.find_child("arc", true, false) as MeshInstance3D
		_arc_mesh = a.mesh
		_arc_skin = a.skin
		src.free()
	var mi := MeshInstance3D.new()
	mi.name = "arc"
	mi.mesh = _arc_mesh
	mi.skin = _arc_skin
	return mi

static func vider() -> void:
	_mx.lock()
	for k: String in _gabarits:
		if is_instance_valid(_gabarits[k]):
			(_gabarits[k] as Node).free()
	_gabarits.clear()
	_mx.unlock()
	_tex = null
	_mat_os = null
	_mat_etoffe = null
	_tex_nu = null
	_mat_os_nu = null
	_mat_etoffe_nu = null
	_arc_mesh = null
	_arc_skin = null
