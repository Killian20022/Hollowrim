class_name EpeesLongues
## Les cinq épées longues de la planche « combat à l'épée » (métal, or, rubis, verre, obsidienne) :
## modèles assets/modeles/armes/epees/<variante>.glb (source : sources_blender/epees_longues/epees_longues.py),
## habillés en matériaux PS1 par NOM de matériau Blender, comme corps_joueur._epee / mains._habiller.
##
## Repère commun (= epee_nordique.glb) : +Y le long de la lame, +X tranchant / quillons (sens des jointures), origine
## telle que le centre du poing est à y = 0,03 (MILIEU_POIGNEE de mains.gd). Une épée longue se pose donc à la place de
## epee_nordique.glb avec la même transformation de prise (PRISE_D / PRISE).
## Nœuds vides de chaque glb : `prise` (centre du poing), `garde` (base de la lame), `pointe` (bout de la lame).
##
## Usage :  var e := EpeesLongues.instancier("rubis")      # Node3D habillé
##          var p := EpeesLongues.repere(e, "pointe")       # Node3D (tracé de lame)
##
## Matériaux (nom Blender -> rendu) :
##   lame       acier poli (texture ObjetsTextures « lame », la même que l'épée du joueur)
##   lame_or    acier doré gravé (rinceaux et runes dans la gorge)
##   fer        fer forgé sombre (gardes, pommeaux)
##   or         or gravé (garde et pommeau de l'épée en or)
##   cuir       cuir tressé (ObjetsTextures « tresse »)
##   gemme      pierre bleu pâle (garde de l'épée en métal)
##   rubis      cristal rouge à facettes + lueur rouge (shader « lueur » : émission = albédo × force)
##   saphir     cristal bleu nuit à facettes + lueur bleue (shader « lueur ») : lame de Croc-de-Givre (hybride n°8)
##   verre      cristal émeraude TRANSLUCIDE (shader « verre » : alpha + reflet de bord + légère lueur)
##   emeraude   gemmes vertes opaques, légère lueur
##   obsidienne verre volcanique noir à reflets
##   veine      fissures rouge sombre rougeoyantes (shader « lueur »)
##   entrelacs  bronze patiné gravé d'entrelacs (L9 : garde et pommeau de l'épée unique de Skarnholt)
## L9 REFLET DE LAME (docs/INSPIRATION_IGNITE.md §2.14) : lame, lame_or et obsidienne passent par shader_reflet() = ps1 + 1-2 px clairs
## sur les BISEAUX du tranchant (faces dont la normale du modèle penche vers ±X) : un éclat court qui GLISSE le long de la lame avec
## l'angle de vue (position = onde triangle de l'angle caméra / lame), plus un fil faible constant ; en paliers, sans dégradé lisse.
## Les variantes de shader sont dérivées de shaders/ps1.gdshader par remplacement de texte (comme
## Palette.shader_double_face) : grille d'accroche, affine, neige, éclair de coup… restent identiques. Rien de lourd :
## ni écran lu (SCREEN_TEXTURE), ni réfraction, ni lumière dynamique : compatible rendu Web (Compatibility).

const VARIANTES := ["metal", "or", "rubis", "verre", "obsidienne"]
## L9 : épées uniques (même repère et mêmes matériaux, hors des cinq de la planche) : assets/modeles/armes/epees/<nom>.glb.
const UNIQUES := ["skarnholt"]
const DOSSIER := "res://assets/modeles/armes/epees/"

## Stats d'exemple de la planche (dégâts, vitesse, poids) : indicatif, pour le code de combat.
const STATS := {
	"metal": {"degats": 10, "vitesse": "moyenne", "poids": "moyen"},
	"or": {"degats": 12, "vitesse": "rapide", "poids": "leger"},
	"rubis": {"degats": 18, "vitesse": "moyenne", "poids": "moyen"},
	"verre": {"degats": 16, "vitesse": "tres_rapide", "poids": "leger"},
	"obsidienne": {"degats": 22, "vitesse": "lente", "poids": "lourd"},
}

const OR := ["#2a1806", "#452a0a", "#664010", "#8a5a18", "#b07a22", "#d29e36", "#ecc45a", "#fbe89a"]
const OR_ACIER := ["#1e1810", "#30281a", "#463a24", "#62502e", "#80683a", "#9e8448", "#bca25a", "#d8c278", "#efe0a6", "#fdf6d8"]
const RUBIS := ["#140103", "#2a0306", "#44050a", "#640a10", "#881218", "#b01e26", "#e05458", "#ffb0a8"]
const SAPHIR := ["#01060f", "#031026", "#06204a", "#0b3470", "#14509a", "#2272c4", "#58a4e8", "#b8e2ff"]
const EMERAUDE := ["#04170e", "#082a19", "#0e4226", "#165e37", "#20804a", "#36a462", "#62c886", "#b2f0cc"]
const OBSIDIENNE := ["#040306", "#09070c", "#100d14", "#18141e", "#221c2a", "#302838", "#463c52", "#6a5c78"]
const VEINE := ["#2a0402", "#4e0904", "#7a1406", "#a8240a", "#d44412", "#f2782a", "#ffb35a"]
const GEMME := ["#2a4a6a", "#3e6a90", "#5a90b8", "#82b8d8", "#b4dcef", "#eefaff"]
const BRONZE := ["#140d06", "#24180b", "#3a2812", "#563d1c", "#745428", "#946e38", "#b48c4c", "#d4b070"]
## Reflet de lame (L9) : couleur de l'éclat par matériau ; [couleur, force de l'éclat, fil constant].
const REFLETS := {"lame": [Color(0.86, 0.93, 1.0), 1.0, 0.07], "lame_or": [Color(1.0, 0.92, 0.7), 0.9, 0.06],
	"obsidienne": [Color(0.8, 0.72, 1.0), 0.8, 0.05]}

static var _mats := {}
static var _shader_lueur: Shader
static var _shader_verre: Shader
static var _shader_reflet: Shader

## Instance habillée de la variante (« metal », « or », « rubis », « verre », « obsidienne »).
static func instancier(variante: String) -> Node3D:
	var e: Node3D = load(DOSSIER + variante + ".glb").instantiate()
	e.name = "epee_" + variante
	habiller(e)
	return e

## Nœud vide `prise`, `garde` ou `pointe` d'une épée instanciée.
static func repere(epee: Node, nom: String) -> Node3D:
	return epee.find_child(nom, true, false) as Node3D

## Remplace les matériaux importés par les matériaux PS1, par nom. `ombres` : l'arme projette une ombre (vue à la 3e personne).
static func habiller(racine: Node, ombres := false) -> void:
	var mats := materiaux()
	var mailles: Array = racine.find_children("*", "MeshInstance3D", true, false)
	if racine is MeshInstance3D:
		mailles.append(racine)
	for mi: MeshInstance3D in mailles:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombres else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var nom := m.resource_name.get_slice(".", 0) if m else ""
			if mats.has(nom):
				mi.set_surface_override_material(s, mats[nom])

## Matériaux PS1 par nom de matériau Blender (partagés par toutes les épées).
static func materiaux() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	var lame := ObjetsTextures.lame()
	_mats = {
		"lame": Palette.materiau(ImageTexture.create_from_image(lame), Vector2.ONE, Color(1.3, 1.3, 1.38)),
		"lame_or": Palette.materiau(ImageTexture.create_from_image(_lame_or(lame)), Vector2.ONE, Color(1.15, 1.12, 1.05)),
		"fer": Palette.materiau(ObjetsTextures.tex("fer"), Vector2.ONE, Color(0.62, 0.62, 0.7)),
		"or": Palette.materiau(ImageTexture.create_from_image(_or_grave()), Vector2.ONE, Color(1.1, 1.05, 1.0)),
		"cuir": Palette.materiau(ObjetsTextures.tex("tresse"), Vector2.ONE),
		"gemme": _lueur(ImageTexture.create_from_image(_facettes(GEMME, 8, 8, 3)), Color(1.45, 1.45, 1.5), 0.35),
		"rubis": _lueur(_cristal(RUBIS, 41), Color(1.0, 0.95, 0.95), 0.22),
		"saphir": _lueur(_cristal(SAPHIR, 63), Color(0.95, 1.0, 1.08), 0.25),
		"verre": _verre(_cristal(EMERAUDE, 57), 0.5),
		"emeraude": _lueur(ImageTexture.create_from_image(_facettes(EMERAUDE, 8, 8, 5)), Color(1.1, 1.15, 1.1), 0.3),
		"obsidienne": Palette.materiau(ImageTexture.create_from_image(_obsidienne()), Vector2.ONE, Color(0.85, 0.85, 1.0)),
		"veine": _lueur(ImageTexture.create_from_image(_veine()), Color.WHITE, 1.4),
		"entrelacs": Palette.materiau(ImageTexture.create_from_image(_entrelacs()), Vector2.ONE, Color(1.12, 1.06, 0.98)),
	}
	for nom: String in REFLETS:      # L9 : reflet de lame (même texture, même teinte : seul le shader change)
		var m: ShaderMaterial = _mats[nom]
		m.shader = shader_reflet()
		m.set_shader_parameter("reflet_couleur", REFLETS[nom][0])
		m.set_shader_parameter("reflet_force", REFLETS[nom][1])
		m.set_shader_parameter("reflet_fil", REFLETS[nom][2])
	# glb de Blender : couleurs de sommet d'alpha nul, lues comme « neige » par le shader -> neige = base
	for m: ShaderMaterial in _mats.values():
		m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
	return _mats

# ------------------------------------------------------------------ variantes du shader ps1
## Lueur texturée : l'émission suit les pixels clairs de la texture (facettes du rubis, fissures des veines).
static func shader_lueur() -> Shader:
	if _shader_lueur == null:
		_shader_lueur = Shader.new()
		_shader_lueur.code = Palette.PS1.code \
			.replace("uniform vec3 emission : source_color = vec3(0.0);", "uniform vec3 emission : source_color = vec3(0.0);\nuniform float lueur = 0.0;") \
			.replace("EMISSION = emission + ", "EMISSION = emission + ALBEDO * ALBEDO * lueur * 2.0 + ")
	return _shader_lueur

## Verre : translucide (ALPHA), reflet de bord (bords rasants plus opaques et clairs), légère lueur propre.
## Tri par objet de Godot (transparent après l'opaque) ; pas de lecture de l'écran.
static func shader_verre() -> Shader:
	if _shader_verre == null:
		_shader_verre = Shader.new()
		_shader_verre.code = Palette.PS1.code \
			.replace("render_mode diffuse_lambert, specular_disabled;", "render_mode diffuse_lambert, specular_disabled, depth_draw_always;") \
			.replace("uniform vec3 emission : source_color = vec3(0.0);", "uniform vec3 emission : source_color = vec3(0.0);\nuniform float opacite = 0.5;\nuniform float lueur = 0.0;") \
			.replace("\tROUGHNESS = 1.0;\n}", "\tfloat bord_v = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));\n\tbord_v = floor(bord_v * bord_v * 4.0) / 4.0;   // en paliers : pas de dégradé lisse\n\tALPHA = clamp(opacite + bord_v * 0.45, 0.0, 1.0);\n\tEMISSION += ALBEDO * (lueur + bord_v * 0.8);\n\tROUGHNESS = 1.0;\n}")
	return _shader_verre

## L9 : reflet de lame. Varyings dans le repère du MODÈLE (le glb : +Y le long de la lame, ±X les tranchants) : la face est un biseau
## si |normale.x| > reflet_biseau (plat et gorge : < 0,25 ; biseaux : 0,42 à 0,7 selon la lame). Position de l'éclat le long de la lame
## (0 = garde, 1 = pointe, reflet_y en m) = onde triangle de la direction de la caméra vue depuis la lame : il glisse quand l'arme ou la
## caméra tourne (coups, balancement, tour d'un présentoir). Deux paliers (cœur 1, bord 0,45) : 1 à 2 px à 480 x 270.
static func shader_reflet() -> Shader:
	if _shader_reflet == null:
		_shader_reflet = Shader.new()
		_shader_reflet.code = Palette.PS1.code \
			.replace("uniform vec3 emission : source_color = vec3(0.0);", "uniform vec3 emission : source_color = vec3(0.0);\nuniform vec3 reflet_couleur : source_color = vec3(0.86, 0.93, 1.0);\nuniform float reflet_force = 1.0;\nuniform float reflet_fil = 0.07;\nuniform float reflet_biseau = 0.32;\nuniform vec2 reflet_y = vec2(0.09, 0.96);\nuniform float reflet_largeur = 0.07;\nvarying vec3 l9_pos;\nvarying vec3 l9_n;\nvarying vec3 l9_vue;") \
			.replace("void vertex() {\n", "void vertex() {\n\tl9_pos = VERTEX;\n\tl9_n = NORMAL;\n\tl9_vue = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz - VERTEX;\n") \
			.replace("\tROUGHNESS = 1.0;\n}", "\t{\n\t\tvec3 nm = normalize(l9_n);\n\t\tvec3 vm = normalize(l9_vue);\n\t\tfloat biseau = step(reflet_biseau, abs(nm.x));\n\t\tfloat v = (l9_pos.y - reflet_y.x) / (reflet_y.y - reflet_y.x);\n\t\tfloat dans = step(0.0, v) * step(v, 1.0);\n\t\tfloat ph = fract(0.5 + 1.15 * vm.y + 0.6 * vm.x * sign(nm.x) + 0.35 * vm.z);\n\t\tfloat c = abs(ph * 2.0 - 1.0);\n\t\tfloat g = 1.0 - abs(v - c) / reflet_largeur;\n\t\tfloat palier = step(0.5, g) + step(0.0, g) * 0.45 * (1.0 - step(0.5, g));\n\t\tEMISSION += reflet_couleur * (reflet_force * palier + reflet_fil) * biseau * dans;\n\t}\n\tROUGHNESS = 1.0;\n}")
	return _shader_reflet

static func _lueur(tex: Texture2D, teinte: Color, force: float) -> ShaderMaterial:
	var m := Palette.materiau(tex, Vector2.ONE, teinte)
	m.shader = shader_lueur()
	m.set_shader_parameter("lueur", force)
	return m

static func _verre(tex: Texture2D, opacite: float) -> ShaderMaterial:
	var m := Palette.materiau(tex, Vector2.ONE, Color(1.1, 1.2, 1.1))
	m.shader = shader_verre()
	m.set_shader_parameter("opacite", opacite)
	m.set_shader_parameter("lueur", 0.08)
	return m

# ------------------------------------------------------------------ textures (pixel art, palettes limitées, bruit à seuil)
static func _c(r: Array, i: int) -> Color:
	return Color(r[clampi(i, 0, r.size() - 1)])

static func _h(x: int, y: int, g: int) -> float:
	return ObjetsTextures._h(x, y, g)

static func _lum(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11

## Lame d'acier doré : la lame d'acier repeinte dans une rampe or pâle, rinceaux gravés le long de la gorge.
static func _lame_or(acier: Image) -> Image:
	var img := acier.duplicate() as Image
	var W := img.get_width()
	var H := img.get_height()
	for y in H:
		var v := 1.0 - float(y) / (H - 1)
		for x in W:
			var u := (x + 0.5) / W
			var l := _lum(acier.get_pixel(x, y)) * 1.15
			# gravure : rinceau sinueux dans la gorge, de la garde aux deux tiers
			if v > 0.10 and v < 0.62 and absf(u - 0.5) < 0.16:
				var s := 0.5 + 0.10 * sin(v * 70.0)
				if absf(u - s) < 0.035 or (int(v * 140.0) % 9 == 0 and absf(u - 0.5) < 0.12):
					l = 0.08
			img.set_pixel(x, y, _c(OR_ACIER, ObjetsTextures._ton(l, OR_ACIER.size(), x, y, 0.4)))
	return img

## Or gravé (garde, pommeau) : métal martelé repeint en or, filets et volutes en creux.
static func _or_grave() -> Image:
	var fer := ObjetsTextures.fer()
	var S := fer.get_width()
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var l := _lum(fer.get_pixel(x, y)) * 1.9 + 0.18
			if y % 16 == 2 or y % 16 == 13:
				l = 0.12                                                  # filets
			elif y % 16 > 4 and y % 16 < 12 and absf(fmod(x + 3.0 * sin(y * 0.8), 8.0) - 4.0) < 0.6:
				l = 0.22                                                  # volutes
			elif y % 16 == 3:
				l += 0.3                                                  # arête claire du filet
			img.set_pixel(x, y, _c(OR, ObjetsTextures._ton(l, OR.size(), x, y, 0.4)))
	return img

## Petites facettes (gemmes) : losanges à tons francs, une étincelle.
static func _facettes(rampe: Array, w: int, h: int, g: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var f := absf(x - w * 0.5 + 0.5) + absf(y - h * 0.5 + 0.5)
			var l := 0.75 - f / (w * 0.9) + (_h(x, y, g) - 0.5) * 0.2
			if x == 2 and y == 2:
				l = 1.0
			img.set_pixel(x, y, _c(rampe, ObjetsTextures._ton(l, rampe.size(), x, y, 0.3)))
	return img

## Lame de cristal 32 x 128 (u = travers, v = longueur, ligne 0 = pointe) : bandes de facettes le long de l'arête,
## fractures internes en biais, fil plus clair, cœur sombre.
static func _cristal(rampe: Array, g: int) -> ImageTexture:
	var W := 32
	var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var v := 1.0 - float(y) / (H - 1)
		for x in W:
			var u := (x + 0.5) / W
			var au := absf(u - 0.5) * 2.0
			var l := 0.42
			# facettes : paliers selon la distance à l'arête, décalés en dents de scie le long de la lame
			var palier := int(au * 4.0 + 0.6 * sin(v * 23.0 + float(int(v * 9.0)) * 1.7))
			l = [0.62, 0.40, 0.52, 0.30, 0.78][clampi(palier, 0, 4)]
			if au > 0.9:
				l = 0.88                                                  # fil lumineux
			# fractures internes (traits en biais)
			var diag := fmod(v * 11.0 - u * 1.6 + _h(int(v * 6.0), 0, g) * 3.0, 1.0)
			if diag > 0.47 and diag < 0.52 and au < 0.8:
				l += 0.22
			if _h(x, y, g + 1) > 0.97:
				l = 0.98                                                  # éclats
			if v < 0.06:
				l *= 0.6                                                  # talon pris dans la garde
			img.set_pixel(x, y, _c(rampe, ObjetsTextures._ton(l, rampe.size(), x, y, 0.4)))
	return ImageTexture.create_from_image(img)

## Obsidienne 32 x 128 : noir vitreux, conchoïdes (arcs clairs), reflets rouge sombre près des veines.
static func _obsidienne() -> Image:
	var W := 32
	var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var v := 1.0 - float(y) / (H - 1)
		for x in W:
			var u := (x + 0.5) / W
			var au := absf(u - 0.5) * 2.0
			var n := ObjetsTextures._fbm(x, y, W, H, 3, 8, 23, 2)
			var l := 0.28 + (n - 0.5) * 0.35
			var arc := fmod(n * 9.0 + au * 2.0, 1.0)
			if arc < 0.07:
				l += 0.4                                                  # arête d'éclat conchoïdal
			if au > 0.9:
				l = 0.62                                                  # fil taillé, plus clair
			var c := _c(OBSIDIENNE, ObjetsTextures._ton(l, OBSIDIENNE.size(), x, y, 0.4))
			if au < 0.42 and _h(x, y / 2, 29) > 0.9 and v < 0.9:
				c = _c(VEINE, 1)                                          # reflet rouge sombre au bord des veines
			img.set_pixel(x, y, c)
	return img

## Veines 16 x 128 : fissure brillante sinueuse sur fond braise sombre.
static func _veine() -> Image:
	var W := 16
	var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var v := 1.0 - float(y) / (H - 1)
		var axe := 0.5 + 0.28 * sin(v * 31.0) + 0.12 * sin(v * 83.0 + 1.0)
		for x in W:
			var u := (x + 0.5) / W
			var d := absf(u - axe)
			var l := 0.18 + _h(x, y, 31) * 0.12
			if d < 0.07:
				l = 0.95
			elif d < 0.16:
				l = 0.62
			# rameaux
			if int(v * 40.0) % 5 == 0 and absf(u - axe - 0.18) < 0.08:
				l = maxf(l, 0.7)
			img.set_pixel(x, y, _c(VEINE, ObjetsTextures._ton(l, VEINE.size(), x, y, 0.4)))
	return img

## L9 : entrelacs 32 x 16 (garde et pommeau des épées uniques) : deux rubans en diagonale qui passent alternativement dessus et
## dessous à chaque croisement, cœur clair, bords sombres, fond creusé presque noir ; bronze patiné.
static func _entrelacs() -> Image:
	var W := 32
	var H := 16
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var a := posmod(x + y, 8)
			var b := posmod(x - y, 8)
			var da := absf(a - 3.5)      # 0 au centre du ruban
			var db := absf(b - 3.5)
			var dessus_a := posmod(int(floor((x + y) / 8.0)) + int(floor((x - y) / 8.0)), 2) == 0
			var l := 0.06                # fond creusé
			var ra := da < 2.0
			var rb := db < 2.0
			if ra and (not rb or dessus_a):
				l = 0.85 - da * 0.22
			elif rb:
				l = 0.85 - db * 0.22
			if (ra and absf(da - 2.0) < 0.6 and not (rb and not dessus_a)) or (rb and absf(db - 2.0) < 0.6 and not (ra and dessus_a)):
				l = 0.16                 # liseré sombre du ruban
			l += (_h(x, y, 71) - 0.5) * 0.12
			img.set_pixel(x, y, _c(BRONZE, ObjetsTextures._ton(l, BRONZE.size(), x, y, 0.3)))
	return img
