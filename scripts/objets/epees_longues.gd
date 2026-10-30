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
## L9 REFLET DE LAME (docs/INSPIRATION_IGNITE.md §2.14) : lame, lame_or et obsidienne (preset « l9 » de MATIERES, shader_matiere) = ps1 + 1-2 px clairs
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

## RÉALISME : palettes des matières usées (neutres, pas de teinte « jouet ») et presets du shader_matiere.
const ACIER_USE := ["#0b0c0e", "#15171a", "#202328", "#2d3137", "#3c4148", "#4e545b", "#62686f", "#797f85", "#93989d", "#b0b4b7", "#d0d3d4", "#eef0ef"]
const CRASSE := ["#0d0a07", "#17120c", "#221a11", "#2e2316", "#3b2e1e", "#4a3a27"]
const OXYDE := ["#24130a", "#3a1e0e", "#552c14", "#6e3a1b", "#87502a", "#9c6334"]
const OR_PATINE := ["#151009", "#241b0f", "#352816", "#4a391e", "#614b27", "#7a5f31", "#94753d", "#ad8c4c", "#c5a462", "#dabd7e", "#ead6a4"]
const FER_FORGE := ["#0c0d0f", "#141619", "#1d2024", "#272b30", "#33383e", "#41474e", "#525960", "#666d74", "#7e858b", "#9aa0a5"]
const CUIR_GRAIN := ["#0f0905", "#190f09", "#25160d", "#321e12", "#402717", "#4f301d", "#603b24", "#72472c"]
const BOIS_FUT := ["#120b06", "#1c120a", "#28190e", "#352214", "#432b1a", "#523521", "#62402a", "#734c33", "#84593c"]
const BOIS_PLANCHE := ["#0f0a06", "#19110a", "#25190f", "#322215", "#3f2b1b", "#4d3522", "#5c402a", "#6b4b33", "#7b583c", "#8c6747"]
const FIL_COUTURE := ["#4a3e2a", "#75653f", "#a08c5e"]
const RUBIS_PROFOND := ["#090003", "#140108", "#21020d", "#320413", "#46071a", "#5d0b22", "#78122b", "#962036", "#ba3a4c", "#e88a8c"]
const SAPHIR_PROFOND := ["#010309", "#030716", "#050e26", "#091838", "#0f244f", "#163469", "#204886", "#3062a6", "#5288c8", "#a2c4ec"]
const GEMME_PROFOND := ["#04101a", "#081c2a", "#0f2c40", "#183f58", "#245672", "#346f8e", "#4f8ead", "#86bdd4"]

## Preset par matière : teinte (albédo), boite (texels / m : projection boîte, sinon UV du modèle), metal, poli (netteté du reflet),
## bord (reflet vitreux rasant), profondeur (gemmes), lueur, opacite (< 1 : translucide), reflet (teinte du reflet),
## l9 [éclat de biseau, fil constant] (lames à UV propres seulement).
const MATIERES := {
	"lame": {"teinte": Color(1.06, 1.06, 1.08), "metal": 0.8, "poli": 0.85, "reflet": Color(0.94, 0.98, 1.05), "l9": [0.75, 0.02]},
	"lame_or": {"teinte": Color(1.04, 1.0, 0.96), "metal": 0.72, "poli": 0.7, "reflet": Color(1.06, 0.92, 0.66), "l9": [0.7, 0.02], "reflet_l9": Color(1.0, 0.9, 0.66)},
	"acier_q": {"teinte": Color(1.04, 1.04, 1.06), "boite": 4.0, "metal": 0.75, "poli": 0.75, "reflet": Color(0.94, 0.98, 1.05)},
	"acier_fil": {"teinte": Color(1.06, 1.06, 1.08), "boite": 4.0, "metal": 0.85, "poli": 0.95, "reflet": Color(0.96, 0.99, 1.05)},
	"fer": {"teinte": Color(1.0, 1.0, 1.02), "boite": 4.0, "metal": 0.5, "poli": 0.35, "reflet": Color(0.95, 0.96, 1.0)},
	"fer_rivete": {"teinte": Color(1.0, 1.0, 1.02), "boite": 2.5, "metal": 0.45, "poli": 0.3, "reflet": Color(0.95, 0.96, 1.0)},
	"or": {"teinte": Color(1.0, 1.0, 1.0), "boite": 4.0, "metal": 0.72, "poli": 0.6, "reflet": Color(1.06, 0.9, 0.62)},
	"or_lame": {"teinte": Color(1.0, 1.0, 1.0), "boite": 4.0, "metal": 0.75, "poli": 0.75, "reflet": Color(1.06, 0.92, 0.66)},
	"cuir": {"teinte": Color(1.0, 1.0, 1.0), "boite": 5.0, "bord": 0.15, "poli": 0.2},
	"bois": {"teinte": Color(1.0, 1.0, 1.0), "boite": 3.0, "bord": 0.08, "poli": 0.1},
	"planches": {"teinte": Color(1.0, 1.0, 1.0), "boite": 2.5, "bord": 0.06, "poli": 0.1},
	"gemme": {"teinte": Color(1.0, 1.0, 1.0), "bord": 0.8, "poli": 1.0, "profondeur": 0.04, "lueur": 0.18, "reflet": Color(0.9, 0.96, 1.0)},
	"rubis": {"teinte": Color(1.08, 1.0, 1.0), "bord": 0.45, "poli": 1.0, "metal": 0.05, "profondeur": 0.05, "lueur": 0.34, "opacite": 0.78, "reflet": Color(1.0, 0.93, 0.94)},
	"saphir": {"teinte": Color(1.0, 1.0, 1.08), "bord": 0.45, "poli": 1.0, "metal": 0.05, "profondeur": 0.05, "lueur": 0.36, "opacite": 0.78, "reflet": Color(0.92, 0.96, 1.04)},
	"emeraude": {"teinte": Color(1.0, 1.0, 1.0), "bord": 0.8, "poli": 1.0, "profondeur": 0.04, "lueur": 0.18, "reflet": Color(0.92, 1.0, 0.95)},
	"obsidienne": {"teinte": Color(0.95, 0.95, 1.0), "metal": 0.12, "bord": 0.85, "poli": 1.0, "reflet": Color(0.88, 0.84, 1.0), "l9": [0.7, 0.03], "reflet_l9": Color(0.8, 0.72, 1.0)},
}

static var _mats := {}
static var _shader_lueur: Shader
static var _shader_verre: Shader

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
## Métadonnée `remap_materiaux` de la racine (facultative, ex. {"lame": "fer"} : boucliers CC0 dont le dos et le cerclage
## portent le nom « lame ») : nom Blender -> matériau PS1 à poser à la place.
static func habiller(racine: Node, ombres := false) -> void:
	var mats := materiaux()
	var remap: Dictionary = racine.get_meta("remap_materiaux", {})
	var mailles: Array = racine.find_children("*", "MeshInstance3D", true, false)
	if racine is MeshInstance3D:
		mailles.append(racine)
	for mi: MeshInstance3D in mailles:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombres else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var complet := m.resource_name if m else ""
			var nom := complet.get_slice(".", 0)
			nom = String(remap.get(complet, remap.get(nom, nom)))      # clé « lame.3 » (surface précise) avant « lame »
			if mats.has(nom):
				mi.set_surface_override_material(s, mats[nom])

## Matériaux PS1 par nom de matériau Blender (partagés par toutes les épées).
## RÉALISME (branche armes/realisme) : chaque matière = une texture dont l'ALPHA porte la BRILLANCE du texel (1 poli, 0 rugueux,
## crasse, oxyde) + un preset de MATIERES rendu par shader_matiere() (reflet d'environnement en paliers, éclat étroit, bord vitreux,
## profondeur des gemmes). Une fonction de texture par matière (_acier_lame, _fer_forge, _cuir_fusee, _cristal_profond…).
## Le verre (Larme-de-Givre, citée comme réussie) garde son shader « verre » d'origine.
static func materiaux() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	var acier := _acier_lame()
	_mats = {
		"lame": _matiere("lame", acier),
		"lame_or": _matiere("lame_or", _lame_or_patine(acier)),
		"acier_q": _matiere("acier_q", _acier_brosse(false)),
		"acier_fil": _matiere("acier_fil", _acier_brosse(true)),
		"fer": _matiere("fer", _fer_forge(false)),
		"fer_rivete": _matiere("fer_rivete", _fer_forge(true)),
		"or": _matiere("or", _or_patine(false)),
		"or_lame": _matiere("or_lame", _or_patine(true)),
		"cuir": _matiere("cuir", _cuir_fusee()),
		"bois": _matiere("bois", _bois(false)),
		"planches": _matiere("planches", _bois(true)),
		"gemme": _matiere("gemme", _cristal_profond(GEMME_PROFOND, 19)),
		"rubis": _matiere("rubis", _cristal_profond(RUBIS_PROFOND, 41)),
		"saphir": _matiere("saphir", _cristal_profond(SAPHIR_PROFOND, 63)),
		"verre": _verre(_cristal(EMERAUDE, 57), 0.5),
		"emeraude": _matiere("emeraude", _cristal_profond(EMERAUDE, 5)),
		"obsidienne": _matiere("obsidienne", _obsidienne()),
		"veine": _lueur(ImageTexture.create_from_image(_veine()), Color.WHITE, 1.4),
		"entrelacs": Palette.materiau(ImageTexture.create_from_image(_entrelacs()), Vector2.ONE, Color(1.12, 1.06, 0.98)),
	}
	# glb de Blender : couleurs de sommet d'alpha nul, lues comme « neige » par le shader -> neige = base
	for m: ShaderMaterial in _mats.values():
		m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
	return _mats

## Matière réaliste : texture (alpha = brillance) + preset MATIERES[nom].
static func _matiere(nom: String, img: Image) -> ShaderMaterial:
	var p: Dictionary = MATIERES[nom]
	var m := Palette.materiau(ImageTexture.create_from_image(img), Vector2.ONE, p.get("teinte", Color.WHITE))
	var op := float(p.get("opacite", 1.0))
	m.shader = shader_matiere(op < 1.0)
	m.set_shader_parameter("mt_boite", 1.0 if p.has("boite") else 0.0)
	m.set_shader_parameter("mt_texels", float(p.get("boite", 4.0)))
	for k in ["metal", "poli", "bord", "profondeur", "lueur"]:
		m.set_shader_parameter("mt_" + k, float(p.get(k, 0.0)))
	m.set_shader_parameter("mt_opacite", op)
	m.set_shader_parameter("mt_reflet", p.get("reflet", Color.WHITE))
	var l9: Array = p.get("l9", [0.0, 0.0])      # L9 : éclat glissant sur les biseaux (lames à UV propres seulement)
	m.set_shader_parameter("reflet_force", l9[0])
	m.set_shader_parameter("reflet_fil", l9[1])
	m.set_shader_parameter("reflet_couleur", p.get("reflet_l9", Color(0.86, 0.93, 1.0)))
	m.set_shader_parameter("reflet_largeur", 0.045)
	return m

# ------------------------------------------------------------------ variantes du shader ps1
## Matière réaliste (opaque, ou translucide pour les gemmes) = ps1 + L9 (éclat de biseau) + :
##  - mt_boite : UV en projection boîte dans le repère du MODÈLE (`mt_texels` répétitions par m) : pièces Quaternius aux UV
##    automatiques (fini les aplats « camouflage ») ;
##  - mt_metal / mt_poli : reflet d'un ciel d'hiver EN PALIERS (sol sombre, horizon clair, zénith moyen) qui multiplie l'albédo (métal
##    = couleur du reflet), modulé par la brillance du texel (alpha) : rayures et biseaux brillent, crasse et oxyde restent mats ;
##    + éclat de soleil étroit (exposant selon `mt_poli`), lui aussi en paliers. Tout passe par l'ALBÉDO : éclairé par la scène
##    (sombre en crypte, pas de mt_lueur), aucune passe en plus ;
##  - mt_bord : reflet vitreux non teinté aux angles rasants (obsidienne, gemmes, sheen du cuir) ;
##  - mt_profondeur : couche interne de la gemme relue décalée selon la vue (voiles et inclusions qui glissent : mt_profondeur) ;
##  - mt_opacite < 1 : translucide comme le verre (bords rasants plus opaques), pour rubis et saphir.
static var _shader_matiere := {}
static func shader_matiere(translucide := false) -> Shader:
	if _shader_matiere.has(translucide):
		return _shader_matiere[translucide]
	var s := Shader.new()
	var code := Palette.PS1.code
	if translucide:
		code = code.replace("render_mode diffuse_lambert, specular_disabled;", "render_mode diffuse_lambert, specular_disabled, depth_draw_always;")
	code = code \
		.replace("uniform vec3 emission : source_color = vec3(0.0);", "uniform vec3 emission : source_color = vec3(0.0);\nuniform vec3 reflet_couleur : source_color = vec3(0.86, 0.93, 1.0);\nuniform float reflet_force = 1.0;\nuniform float reflet_fil = 0.07;\nuniform float reflet_biseau = 0.32;\nuniform vec2 reflet_y = vec2(0.09, 0.96);\nuniform float reflet_largeur = 0.07;\nuniform float mt_boite = 0.0;\nuniform float mt_texels = 4.0;\nuniform float mt_metal = 0.0;\nuniform float mt_poli = 0.5;\nuniform float mt_bord = 0.0;\nuniform float mt_profondeur = 0.0;\nuniform float mt_lueur = 0.0;\nuniform float mt_opacite = 1.0;\nuniform vec3 mt_reflet : source_color = vec3(1.0);\nvarying vec3 l9_pos;\nvarying vec3 l9_n;\nvarying vec3 l9_vue;") \
		.replace("void vertex() {\n", "void vertex() {\n\tl9_pos = VERTEX;\n\tl9_n = NORMAL;\n\tl9_vue = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz - VERTEX;\n") \
		.replace("\tvec2 uv = uv_aff.xy / uv_aff.z;\n", "\tvec2 uv = uv_aff.xy / uv_aff.z;\n\tif (mt_boite > 0.5) {\n\t\tvec3 bx_n = abs(normalize(l9_n));\n\t\tuv = (bx_n.x > bx_n.y && bx_n.x > bx_n.z ? l9_pos.zy : (bx_n.y > bx_n.z ? l9_pos.xz : l9_pos.xy)) * mt_texels;\n\t}\n") \
		.replace("\tROUGHNESS = 1.0;\n}", _CODE_L9 + _CODE_MATIERE + (_CODE_TRANSLUCIDE if translucide else "") + "\t}\n\tROUGHNESS = 1.0;\n}")
	s.code = code
	_shader_matiere[translucide] = s
	return s

const _CODE_L9 := "\t{\n\t\tvec3 nm = normalize(l9_n);\n\t\tvec3 vm = normalize(l9_vue);\n\t\tfloat biseau = step(reflet_biseau, abs(nm.x));\n\t\tfloat v = (l9_pos.y - reflet_y.x) / (reflet_y.y - reflet_y.x);\n\t\tfloat dans = step(0.0, v) * step(v, 1.0);\n\t\tfloat ph = fract(0.5 + 1.15 * vm.y + 0.6 * vm.x * sign(nm.x) + 0.35 * vm.z);\n\t\tfloat c = abs(ph * 2.0 - 1.0);\n\t\tfloat g = 1.0 - abs(v - c) / reflet_largeur;\n\t\tfloat palier = step(0.5, g) + step(0.0, g) * 0.45 * (1.0 - step(0.5, g));\n\t\tEMISSION += reflet_couleur * (reflet_force * palier + reflet_fil) * biseau * dans;\n\t}\n"
const _CODE_MATIERE := """	{
		vec3 mt_nv = normalize(NORMAL);
		vec3 mt_vv = normalize(VIEW);
		float mt_fr = 1.0 - clamp(dot(mt_nv, mt_vv), 0.0, 1.0);
		mt_fr = floor(mt_fr * mt_fr * 4.0) / 4.0;
		float mt_b = texture(tex_base, uv).a;
		vec3 mt_r = normalize((INV_VIEW_MATRIX * vec4(reflect(-mt_vv, mt_nv), 0.0)).xyz);
		float mt_e = mt_r.y < -0.12 ? 0.26 : (mt_r.y < 0.08 ? 1.0 : (mt_r.y < 0.42 ? 0.74 : 0.6));
		mt_e = mix(0.6, mt_e, mt_poli * mt_b);
		float mt_s = pow(max(dot(mt_r, normalize(vec3(-0.45, 0.72, 0.52))), 0.0), mix(6.0, 160.0, mt_poli));
		mt_s = step(0.5, mt_s) + 0.35 * step(0.12, mt_s) * (1.0 - step(0.5, mt_s));
		if (mt_profondeur > 0.0) {
			vec3 mt_vm = normalize(l9_vue);
			vec3 mt_in = texture(tex_base, uv * vec2(1.0, 0.7) + vec2(0.37, 0.11) - mt_vm.xy * mt_profondeur).rgb;
			ALBEDO = ALBEDO * 0.65 + mt_in * mt_in * 2.2 * teinte.rgb;
		}
		float mt_km = mt_metal * mix(0.35, 1.0, mt_b);
		ALBEDO = mix(ALBEDO, ALBEDO * mt_reflet * mt_e * 2.5, mt_km);
		ALBEDO += mt_reflet * mt_e * mt_bord * mt_fr * mt_b * 0.25;
		ALBEDO += mt_reflet * mt_s * (mt_km + mt_bord * 0.5) * mt_b * 0.9;
		EMISSION += ALBEDO * ALBEDO * mt_lueur * 2.0;
"""
const _CODE_TRANSLUCIDE := "\t\tALPHA = clamp(mt_opacite + mt_fr * 0.5, 0.0, 1.0);\n\t\tEMISSION += ALBEDO * mt_fr * 0.5;\n"

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
	return shader_matiere(false)     # RÉALISME : le reflet L9 fait partie du shader des matières

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

# ------------------------------------------------------------------ RÉALISME : textures (alpha = brillance du texel)
static func _pix(img: Image, x: int, y: int, pal: Array, l: float, b: float, jitter := 0.35) -> void:
	var c := _c(pal, ObjetsTextures._ton(l, pal.size(), x, y, jitter))
	c.a = clampf(b, 0.0, 1.0)
	img.set_pixel(x, y, c)

## Rayures fines : n traits de 4 à 26 texels, presque tous dans le sens de la longueur (polissage, fourreau), quelques-uns en
## travers (coups) ; +1 = rayure claire (accroche la lumière), -1 = sillon sombre. `tuile` : la texture se répète.
static func _rayures(W: int, H: int, g: int, n: int, tuile: bool) -> PackedFloat32Array:
	var r := PackedFloat32Array()
	r.resize(W * H)
	for i in n:
		var x0 := _h(i, 1, g) * W
		var y0 := _h(i, 2, g) * H
		var ang := (_h(i, 3, g) - 0.5) * 0.7
		if _h(i, 4, g) > 0.82:
			ang = (_h(i, 5, g) - 0.5) * PI
		var lon := 4.0 + _h(i, 6, g) * 22.0
		var val := 1.0 if _h(i, 7, g) > 0.35 else -1.0
		var t := 0.0
		while t < lon:
			var px := int(floor(x0 + sin(ang) * t))
			var py := int(floor(y0 + cos(ang) * t))
			if tuile:
				px = posmod(px, W)
				py = posmod(py, H)
			if px >= 0 and px < W and py >= 0 and py < H:
				r[py * W + px] = val
			t += 0.7
	return r

## Lame d'acier usée 32 x 128 (même disposition que ObjetsTextures.lame : u = travers, v = longueur, ligne 0 = pointe ; gouttière
## u 0,34-0,66, v 0,10-0,74) : plats brossés en long, biseaux et fil plus clairs et polis, gouttière sombre avec crasse,
## rayures fines, piqûres (plus nombreuses au talon), oxydation au talon et au fond de gouttière, ébréchures du fil.
## Plus de bandes de reflet peintes : le reflet vient du shader (net, étroit, il bouge avec la vue).
static func _acier_lame() -> Image:
	var W := 32
	var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var ray := _rayures(W, H, 101, 46, false)
	for y in H:
		var v := 1.0 - float(y) / (H - 1)
		for x in W:
			var u := (x + 0.5) / W
			var au := absf(u - 0.5) * 2.0
			var brosse := ObjetsTextures._fbm(x, y, W, H, 16, 2, 7, 2)
			var tache := ObjetsTextures._fbm(x, y, W, H, 2, 6, 9, 3)
			var l := 0.42 + (brosse - 0.5) * 0.14 - (tache - 0.5) * 0.12
			var b := 0.7
			var pal: Array = ACIER_USE
			var gorge := v > 0.10 and v < 0.74 and au < 0.34
			if gorge:
				l = 0.27 + (brosse - 0.5) * 0.1
				b = 0.45
				if au > 0.28:
					l = 0.52 if u < 0.5 else 0.16                         # lèvres : éclairée / ombrée
					b = 0.8
				elif au > 0.22:
					l = 0.35 if u < 0.5 else 0.19
				elif tache > 0.52:
					pal = CRASSE                                          # crasse au fond de la gouttière
					l = 0.3 + (tache - 0.52) * 1.6
					b = 0.08
			elif au > 0.88:
				l = 0.74 + (brosse - 0.5) * 0.1                           # fil affûté
				b = 1.0
			elif au > 0.70:
				l = 0.55 + (brosse - 0.5) * 0.12 + (au - 0.7) * 0.4       # biseau
				b = 0.95
				if au > 0.80 and au < 0.83:
					l = 0.40                                              # arête biseau / plat
					b = 0.6
			elif au > 0.34 and au < 0.39:
				l = 0.30                                                  # pli côté gouttière
			var r := ray[y * W + x]
			if r > 0.5 and pal == ACIER_USE:
				l += 0.13
				b = 1.0
			elif r < -0.5 and pal == ACIER_USE:
				l -= 0.10
				b = 0.4
			var seuil := 0.988 - 0.025 * (1.0 - smoothstep(0.0, 0.3, v))
			if _h(x, y, 103) > seuil and au < 0.86:
				l = 0.12                                                  # piqûre
				b = 0.0
			if (v < 0.14 or (gorge and au < 0.22)) and tache > 0.6 and _h(x, y, 104) > 0.35 and au < 0.85:
				pal = OXYDE                                               # oxydation
				l = 0.3 + (tache - 0.6) * 2.0
				b = 0.05
			if au > 0.93 and _h(x, y / 3, 77) > 0.92:
				l = 0.22                                                  # ébréchure
				b = 0.3
			if v < 0.09:
				l *= 0.82                                                 # talon (ricasso) bruni par la forge
			_pix(img, x, y, pal, l, b)
	return img

## Acier doré : la lame usée repeinte en or PATINÉ (bruns olive dans les creux, pas de jaune plat), rinceaux gravés dans la
## gouttière ; la dorure est usée au fil (l'acier réapparaît sur l'affûtage).
static func _lame_or_patine(acier: Image) -> Image:
	var img := acier.duplicate() as Image
	var W := img.get_width()
	var H := img.get_height()
	for y in H:
		var v := 1.0 - float(y) / (H - 1)
		for x in W:
			var u := (x + 0.5) / W
			var au := absf(u - 0.5) * 2.0
			var c := acier.get_pixel(x, y)
			if au > 0.9:
				continue                                                  # fil : acier nu
			var b := c.a
			var l := _lum(c) * 1.2 + 0.03
			if b < 0.1:
				l *= 0.7                                                  # ternissure dans la crasse
			if v > 0.10 and v < 0.62 and au < 0.32:
				var s := 0.5 + 0.10 * sin(v * 70.0)
				if absf(u - s) < 0.035 or (int(v * 140.0) % 9 == 0 and au < 0.24):
					l = 0.1                                               # gravure
					b = 0.1
			_pix(img, x, y, OR_PATINE, l, b * 0.95)
	return img

## Acier brossé 64 x 64 en projection boîte (v = long de la pièce) : `fil` = bande d'affûtage plus claire et polie.
static func _acier_brosse(fil: bool) -> Image:
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var ray := _rayures(S, S, 111 if not fil else 117, 34, true)
	for y in S:
		for x in S:
			var brosse := ObjetsTextures._fbm(x, y, S, S, 32, 2, 13, 2)
			var tache := ObjetsTextures._fbm(x, y, S, S, 3, 3, 14, 3)
			var l := (0.64 if fil else 0.48) + (brosse - 0.5) * 0.16 - (tache - 0.5) * 0.14
			var b := 1.0 if fil else 0.75
			var pal: Array = ACIER_USE
			var r := ray[y * S + x]
			if r > 0.5:
				l += 0.12
				b = 1.0
			elif r < -0.5:
				l -= 0.10
				b = 0.4
			if _h(x, y, 112) > (0.997 if fil else 0.994):
				l = 0.13                                                  # piqûre / ébréchure
				b = 0.0
			if not fil and tache > 0.72:
				pal = CRASSE
				l = 0.35 + (tache - 0.72) * 1.8
				b = 0.1
			elif not fil and tache > 0.68 and _h(x, y, 113) > 0.85:
				pal = OXYDE
				l = 0.35
				b = 0.05
			_pix(img, x, y, pal, l, b)
	return img

## Fer forgé 64 x 64 (gardes, pommeaux, têtes de marteau, cerclage) : coups de marteau (cuvettes à lèvre claire), oxyde et
## crasse au fond des creux, arêtes usées plus brillantes. `rivets` : rivets bombés tous les 16 texels, auréole d'oxyde.
static func _fer_forge(rivets: bool) -> Image:
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var hauteur := PackedFloat32Array()
	hauteur.resize(S * S)
	var cuv := []
	for i in 60:
		cuv.append([_h(i, 1, 181) * S, _h(i, 2, 181) * S, 2.0 + _h(i, 3, 181) * 3.5])
	for y in S:
		for x in S:
			var hv := 0.5 + (ObjetsTextures._fbm(x, y, S, S, 4, 4, 21, 3) - 0.5) * 0.4
			for c in cuv:
				var dx := absf(x - c[0])
				dx = minf(dx, S - dx)
				var dy := absf(y - c[1])
				dy = minf(dy, S - dy)
				var d: float = Vector2(dx, dy).length() / c[2]
				if d < 1.0:
					hv -= 0.16 * (1.0 - d * d)
			hauteur[y * S + x] = hv
	var ray := _rayures(S, S, 183, 30, true)
	for y in S:
		for x in S:
			var hv := hauteur[y * S + x]
			var pente := (hv - hauteur[y * S + posmod(x - 1, S)]) + (hv - hauteur[posmod(y - 1, S) * S + x])
			var l := 0.42 + (hv - 0.5) * 0.5 - pente * 1.8
			var b := 0.35 + clampf(-pente * 6.0, 0.0, 0.4)
			var pal: Array = FER_FORGE
			if ray[y * S + x] > 0.5:
				l += 0.1
				b = 0.8
			var creux := ObjetsTextures._fbm(x, y, S, S, 3, 3, 22, 2)
			if hv < 0.38 and creux > 0.58:
				pal = OXYDE if creux > 0.72 and _h(x, y, 185) > 0.4 else CRASSE
				l = 0.25 + (creux - 0.58) * 1.2
				b = 0.05
			if rivets:
				var rx := posmod(x, 16) - 7.5
				var ry := posmod(y, 16) - 7.5
				var d := Vector2(rx, ry).length()
				if d < 2.7:
					pal = FER_FORGE
					l = 0.5 - (rx + ry) * 0.06                            # tête bombée, éclairée en haut à gauche
					b = 0.6
				elif d < 3.5:
					pal = FER_FORGE
					l = 0.16
					b = 0.1
				elif d < 4.6 and _h(x, y, 184) > 0.75:
					pal = OXYDE
					l = 0.3
					b = 0.05
			_pix(img, x, y, pal, l, b)
	return img

## Or patiné 64 x 64 : fonte polie aux reliefs, ternissure brun-olive dans les creux, rayures fines ; `lame` = brossé en long.
static func _or_patine(lame: bool) -> Image:
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var ray := _rayures(S, S, 191, 40, true)
	for y in S:
		for x in S:
			var n := ObjetsTextures._fbm(x, y, S, S, 32, 2, 23, 2) if lame else ObjetsTextures._fbm(x, y, S, S, 4, 4, 23, 3)
			var t := ObjetsTextures._fbm(x, y, S, S, 3, 3, 24, 3)
			var l := 0.56 + (n - 0.5) * 0.25
			var b := 0.8
			if t > 0.58:
				l -= (t - 0.58) * 1.6                                     # ternissure
				b = 0.25
			if ray[y * S + x] > 0.5:
				l += 0.1
				b = 1.0
			elif ray[y * S + x] < -0.5:
				l -= 0.12
				b = 0.3
			if _h(x, y, 192) > 0.99:
				l = 0.15
				b = 0.0
			_pix(img, x, y, OR_PATINE, l, b)
	return img

## Cuir de fusée 64 x 64 : lanière enroulée en biais (bandes de 8 texels, interstice sombre, bord éclairé), grain fin, couture
## en pointillé au milieu de chaque bande, usure lustrée par la main.
static func _cuir_fusee() -> Image:
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var k := posmod(y + x / 2, 8)
			var grain := (_h(x, y, 201) - 0.5) * 0.12 + (ObjetsTextures._fbm(x, y, S, S, 16, 16, 25, 1) - 0.5) * 0.16
			var lustre := ObjetsTextures._fbm(x, y, S, S, 3, 3, 26, 2)
			var l := 0.45
			var b := 0.12
			var pal: Array = CUIR_GRAIN
			match k:
				0:
					l = 0.1
					b = 0.0
				1:
					l = 0.58
				2, 3, 4:
					l = 0.5
				5:
					l = 0.42
				_:
					l = 0.3
			if k > 0:
				l += grain
			if lustre > 0.6 and k > 0:
				l += 0.08
				b = 0.4
			if k == 4 and posmod(x, 3) == 0:
				pal = FIL_COUTURE                                         # point de couture
				l = 0.7
				b = 0.2
			_pix(img, x, y, pal, l, b)
	return img

## Bois 64 x 64 (v = fil du bois) : fût de hache / marteau (huilé, usé à la main) ou `planches` de bouclier (planches de
## 16 texels, joints sombres, teinte propre à chaque planche, nœud, salissure au bord des joints).
static func _bois(planches: bool) -> Image:
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var pal: Array = BOIS_PLANCHE if planches else BOIS_FUT
	for y in S:
		for x in S:
			var p := x / 16 if planches else 0
			var xp := posmod(x, 16)
			var ph := _h(p, 0, 211)
			var ond := ObjetsTextures._fbm(x, y, S, S, 2, 4, 27, 2)
			var g := fmod(x / 3.2 + ond * 3.0 + ph * 5.0, 1.0)
			var l := 0.42 + (ph - 0.5) * 0.14 + (ObjetsTextures._fbm(x, y, S, S, 4, 16, 28, 2) - 0.5) * 0.18
			var b := 0.1
			if g < 0.22:
				l -= 0.12                                                 # veine
			elif g > 0.85:
				l += 0.05
			if _h(x, y, 212) > 0.97:
				l -= 0.08
			var usure := ObjetsTextures._fbm(x, y, S, S, 3, 3, 29, 2)
			if not planches and usure > 0.62:
				l += 0.08                                                 # poli par la main
				b = 0.3
			if planches:
				if xp == 0:
					l = 0.05                                              # joint
					b = 0.0
				elif xp == 1:
					l += 0.08
				elif xp == 2 or xp == 15:
					l -= 0.1                                              # salissure au bord du joint
				var nd := Vector2((x - 40) * 1.6, y - 22).length()
				if nd < 3.0:
					l = 0.18 + nd * 0.05                                  # nœud
				elif nd < 4.2:
					l -= 0.1
				if usure > 0.66:
					l += 0.06
			_pix(img, x, y, pal, l, b)
	return img

## Cristal profond 32 x 128 (rubis, saphir, gemmes) : cœur sombre et saturé, voiles laiteux et nuages internes, arête médiane
## à peine plus claire, bord mince plus lumineux (lumière transmise), fractures fines, inclusions noires, rares éclats.
static func _cristal_profond(rampe: Array, g: int) -> Image:
	var W := 32
	var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var v := 1.0 - float(y) / (H - 1)
		for x in W:
			var u := (x + 0.5) / W
			var au := absf(u - 0.5) * 2.0
			var l := 0.38 + (ObjetsTextures._fbm(x, y, W, H, 3, 10, g, 3) - 0.5) * 0.36
			var b := 1.0
			if ObjetsTextures._fbm(x, y, W, H, 6, 24, g + 1, 2) > 0.62:
				l += 0.12                                                 # voile laiteux
			if au < 0.07:
				l += 0.08                                                 # arête médiane
			elif au > 0.45 and au < 0.5:
				l -= 0.06                                                 # arête de facette
			if au > 0.86:
				l = 0.55 + (au - 0.86) * 1.2                              # bord mince : lumière transmise
			var diag := fmod(v * 7.0 - u * 1.4 + _h(int(v * 5.0), 0, g) * 3.0, 1.0)
			if diag > 0.48 and diag < 0.505 and au < 0.8:
				l += 0.16                                                 # fracture
				b = 0.7
			if _h(x, y, g + 2) > 0.988:
				l = 0.04                                                  # inclusion
			elif _h(x, y, g + 3) > 0.996:
				l = 0.95                                                  # éclat
			if v < 0.05:
				l *= 0.6
			_pix(img, x, y, rampe, l, b, 0.3)
	return img
