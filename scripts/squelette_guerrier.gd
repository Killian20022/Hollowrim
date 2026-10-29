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
## C10 (refonte visuelle) : 8 paires de côtes en bandes séparées par du vide, creux cuits au noir, arête claire (rampe « arete ») ;
## VARIANTES DE TEINTE à coût nul (TEINTES : givre, sang, braise ; « ivoire » = l'os validé) : mêmes maillages, mêmes gabarits,
## matériaux clonés une fois (teinte, lueur des orbites, motifs du shader lus dans l'ALPHA des texels d'os : dessus / fissures).
##   SqueletteGuerrier.modele(arme, teinte) ; teinte tirée de l'identifiant par EnnemisNordiques.teinte_squelette.

const GLB := preload("res://assets/modeles/squelettes/squelette_nordique.glb")
const DOSSIER := "res://assets/personnages"
const RES := "res://assets/personnages/squelette_nordique.res"
const PNG := "res://sources_blender/squelette_nordique_atlas.png"
const RES_NU := "res://assets/personnages/squelette_nordique_nu.res"
const PNG_NU := "res://sources_blender/squelette_nordique_atlas_nu.png"
## Variantes à crâne nu (atlas _nu)
const CRANE_NU := ["hache"]
const VERSION := 7
## Maillages visibles par variante (les autres sont cachés : ils ne coûtent rien au rendu)
const PIECES := {
	"epee": ["squelette", "lambeaux", "casque", "bouclier", "epee"],
	"arc": ["squelette", "lambeaux", "capuche", "carquois", "arc"],
	"hache": ["squelette", "lambeaux", "hache"],
}
## Étoffes : double face, texels découpés (trous)
const ETOFFES := ["lambeaux", "capuche"]
const SATURATION_OS := 0.6
## Variantes de teinte (C10). os / etoffe = facteurs de teinte ; lueur = émission du fond des orbites ; motifs du shader ps1_draugr :
## dessus (givre, suie) et fissure (sang séché, braises) : Color(r, g, b, force) ; braise = émission des fissures.
const TEINTES := {
	"givre": {"os": Color(0.84, 0.94, 1.12), "etoffe": Color(0.86, 0.93, 1.06), "lueur": Vector3(3.0, 5.4, 7.6),
		"dessus": Color(0.78, 0.89, 0.97, 0.85), "fissure": Color(0.16, 0.26, 0.36, 0.6), "braise": Vector3.ZERO},
	"sang": {"os": Color(1.02, 0.66, 0.58), "etoffe": Color(1.0, 0.80, 0.76), "lueur": Vector3(8.0, 1.0, 0.6), "saturation": 0.9,
		"dessus": Color(0.36, 0.05, 0.03, 0.6), "fissure": Color(0.20, 0.015, 0.01, 0.95), "braise": Vector3.ZERO},
	"braise": {"os": Color(0.50, 0.43, 0.39), "etoffe": Color(0.60, 0.54, 0.50), "lueur": Vector3(8.5, 3.6, 0.5),
		"dessus": Color(0.16, 0.145, 0.14, 0.6), "fissure": Color(0.85, 0.30, 0.05, 1.0), "braise": Vector3(1.2, 0.34, 0.04)},
}
## Part de chaque teinte (tirage déterministe par identifiant) ; le reste = ivoire.
const PARTS_TEINTES := [["givre", 0.26], ["sang", 0.22], ["braise", 0.18]]

static var _tex: ImageTexture
static var _mat_os: ShaderMaterial
static var _mat_etoffe: ShaderMaterial
static var _tex_nu: ImageTexture
static var _mat_os_nu: ShaderMaterial
static var _mat_etoffe_nu: ShaderMaterial
static var _gabarits := {}
static var _mx := Mutex.new()
static var _arc_mesh: Mesh
static var _mats_teinte := {}     # teinte -> [os, etoffe, os_nu, etoffe_nu]
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
	return mips_alpha(p)

## Mipmaps pixel art (vote de couleur, comme GuerrierTextures.mips_pixel) qui GARDENT l'alpha des texels opaques : il porte le masque
## des motifs de teinte (C10). Les texels d'alpha <= 0,5 (trous des étoffes) restent découpés.
static func mips_alpha(img: Image) -> Image:
	var niveaux: Array[Image] = [img]
	var cur := img
	while cur.get_width() > 1 or cur.get_height() > 1:
		var w := maxi(1, cur.get_width() / 2)
		var h := maxi(1, cur.get_height() / 2)
		var nxt := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var cnt := {}
				var opaques := 0
				for dd: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var c := cur.get_pixel(mini(x * 2 + dd.x, cur.get_width() - 1), mini(y * 2 + dd.y, cur.get_height() - 1))
					if c.a > 0.5:
						opaques += 1
						cnt[c] = int(cnt.get(c, 0)) + 1
				if opaques >= 2:
					var best := Color.BLACK
					var bn := 0
					for k: Color in cnt:
						if cnt[k] > bn or (cnt[k] == bn and k.get_luminance() < best.get_luminance()):
							bn = cnt[k]
							best = k
					nxt.set_pixel(x, y, best)
				else:
					nxt.set_pixel(x, y, Color(0, 0, 0, 0))
		niveaux.append(nxt)
		cur = nxt
	var data := PackedByteArray()
	for n in niveaux:
		data.append_array(n.get_data())
	return Image.create_from_data(img.get_width(), img.get_height(), true, Image.FORMAT_RGBA8, data)

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
	for t: String in TEINTES:
		var d: Dictionary = TEINTES[t]
		_mats_teinte[t] = [_cloner(_mat_os, d, true), _cloner(_mat_etoffe, d, false), _cloner(_mat_os_nu, d, true), _cloner(_mat_etoffe_nu, d, false)]

## Clone d'un matériau du squelette pour une teinte (une fois par teinte ; contour partagé), inscrit dans Palette (bascule PS1).
static func _cloner(m: ShaderMaterial, d: Dictionary, os_: bool) -> ShaderMaterial:
	var c := m.duplicate() as ShaderMaterial
	c.set_shader_parameter("teinte", d["os"] if os_ else d["etoffe"])
	c.set_shader_parameter("lueur", d["lueur"])
	if os_:
		c.set_shader_parameter("motif_dessus", d["dessus"])
		c.set_shader_parameter("motif_fissure", d["fissure"])
		c.set_shader_parameter("motif_lueur", d["braise"])
		if d.has("saturation"):
			c.set_shader_parameter("saturation", d["saturation"])
	Palette.materiaux.append(c)
	Palette._appliquer(c, Palette._ps1_actif)
	return c

## Matériau de la pièce `nom` pour la teinte `teinte` (« » ou « ivoire » = matériaux de base).
static func _mat_de(nom: String, nu: bool, teinte: String) -> ShaderMaterial:
	var et := ETOFFES.has(nom)
	if _mats_teinte.has(teinte):
		return _mats_teinte[teinte][(2 if nu else 0) + (1 if et else 0)]
	return (_mat_etoffe_nu if nu else _mat_etoffe) if et else (_mat_os_nu if nu else _mat_os)

## Pose les matériaux de la teinte sur un squelette (copie d'un gabarit : quelques set_surface_override_material, pas de construction).
static func teinter(racine: Node3D, teinte: String) -> void:
	materiaux()
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	var nu := CRANE_NU.has(String(racine.get_meta("variante", "")).trim_prefix("squelette_"))
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		var m := _mat_de(String(mi.name), nu, teinte)
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, m)
	racine.set_meta("teinte", teinte if _mats_teinte.has(teinte) else "ivoire")

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
		var m := _mat_de(nom, nu, String(options.get("teinte", "")))
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, m)
	var ap := AnimationPlayer.new()
	ap.name = "Animations"
	racine.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", Humain.bibliotheque())
	racine.set_meta("variante", "squelette_" + arme)
	racine.set_meta("teinte", String(options.get("teinte", "")) if TEINTES.has(String(options.get("teinte", ""))) else "ivoire")
	return racine

## Gabarit de la variante `arme` (construit une fois, hors de l'arbre ; sûr depuis un fil de chargement).
static func gabarit(arme: String) -> Node3D:
	FilVerrou.verrouiller(_mx)      # fil principal : vide la file du serveur de rendu si le fil des ennemis bâtit un gabarit (voir FilVerrou)
	var g: Node3D = _gabarits.get(arme)
	if g == null:
		g = creer({"arme": arme})
		_gabarits[arme] = g
	_mx.unlock()
	return g

## Copie neuve d'un gabarit (≈ duplicate, sans recharger le glb ni refaire les matériaux) ; `teinte` : clé de TEINTES (« » = ivoire).
static func modele(arme: String, teinte := "") -> Node3D:
	var n := gabarit(arme).duplicate() as Node3D
	n.set_meta("variante", "squelette_" + arme)
	if TEINTES.has(teinte):
		teinter(n, teinte)
	else:
		n.set_meta("teinte", "ivoire")
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
	FilVerrou.verrouiller(_mx)
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
	_mats_teinte.clear()
	_arc_mesh = null
	_arc_skin = null
