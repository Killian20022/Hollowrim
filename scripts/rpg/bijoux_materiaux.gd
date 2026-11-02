class_name BijouxMateriaux
## Matériaux PS1 « réalistes » des bijoux (assets/modeles/bijoux/<id>.glb, source sources_blender/bijoux/bijoux.py), posés par
## NOM de matériau Blender comme EpeesLongues.habiller : même shader_matiere (reflet d'environnement en paliers, éclat étroit,
## bord vitreux, PROFONDEUR des gemmes), mêmes générateurs de texture (alpha = brillance du texel), mais une densité de
## projection boîte adaptée aux petites pièces (un anneau fait 3 cm : 4 texels / m donneraient un aplat).
##   or        or patiné (EpeesLongues._or_patine)            argent   argent terni (gris froid, noirci dans les creux)
##   bronze    bronze patiné vert-de-gris par plaques         fer      fer noir forgé (EpeesLongues._fer_forge)
##   cuir      lacet de cuir (EpeesLongues._cuir_fusee)       os       griffe / ivoire jauni, stries
##   gemme     cristal de givre pâle (translucide, lueur)     saphir / rubis   cristaux profonds d'EpeesLongues
##   jade      cabochon vert laiteux opaque                    amethyste  violet profond, translucide
## Usage : BijouxMateriaux.habiller(noeud) (toutes les MeshInstance3D du nœud) ; BijouxMateriaux.materiaux() -> {nom: ShaderMaterial}.

const ARGENT := ["#0d0e10", "#17191c", "#23262a", "#30343a", "#40454c", "#535960", "#686f76", "#7f868c", "#989ea3", "#b3b8bc", "#cfd3d6", "#eceff0"]
const BRONZE := ["#120c06", "#1f150a", "#2e1f0f", "#3e2a15", "#50371c", "#644624", "#7a582e", "#906b3a", "#a88048", "#c09a5e"]
const VERT_DE_GRIS := ["#14201a", "#1f3027", "#2b4236", "#3a5646", "#4d6c58", "#64846c"]
const OS_IVOIRE := ["#2a2218", "#3d3324", "#524632", "#6a5c43", "#827457", "#9b8c6c", "#b3a483", "#c9bb9b", "#ddd1b4", "#eee5cc"]
const JADE := ["#03140b", "#062214", "#0b331e", "#12472a", "#1c5e38", "#2a7848", "#3f925c", "#62ad78", "#96cca0", "#cfeacf"]
const AMETHYSTE := ["#07020d", "#110519", "#1d0a29", "#2b103b", "#3b1750", "#4e2068", "#652d84", "#8044a2", "#a26ac2", "#d2acea"]
const GIVRE := ["#06121c", "#0c1f2e", "#153044", "#20465e", "#2f5f7a", "#437b96", "#5e9ab2", "#82bacc", "#aed8e4", "#e2f6fa"]

## Presets (mêmes clés que EpeesLongues.MATIERES) ; boite = texels / m (petites pièces : forte densité).
const PRESETS := {
	"or": {"boite": 70.0, "metal": 0.75, "poli": 0.7, "reflet": Color(1.06, 0.9, 0.62)},
	"argent": {"teinte": Color(1.02, 1.03, 1.06), "boite": 70.0, "metal": 0.8, "poli": 0.8, "reflet": Color(0.94, 0.98, 1.06)},
	"bronze": {"boite": 45.0, "metal": 0.55, "poli": 0.45, "reflet": Color(1.04, 0.88, 0.66)},
	"fer": {"teinte": Color(0.92, 0.92, 0.95), "boite": 60.0, "metal": 0.5, "poli": 0.4, "reflet": Color(0.95, 0.96, 1.0)},
	"cuir": {"teinte": Color(1.45, 1.25, 1.05), "boite": 40.0, "bord": 0.15, "poli": 0.2},
	"os": {"teinte": Color(1.0, 0.98, 0.94), "bord": 0.25, "poli": 0.35},
	"gemme": {"teinte": Color(1.0, 1.02, 1.06), "bord": 0.6, "poli": 1.0, "metal": 0.05, "profondeur": 0.05, "lueur": 0.34, "opacite": 0.86, "reflet": Color(0.9, 0.97, 1.04)},
	"saphir": {"teinte": Color(1.0, 1.0, 1.08), "bord": 0.45, "poli": 1.0, "metal": 0.05, "profondeur": 0.05, "lueur": 0.44, "opacite": 0.88, "reflet": Color(0.92, 0.96, 1.04)},
	"rubis": {"teinte": Color(1.08, 1.0, 1.0), "bord": 0.45, "poli": 1.0, "metal": 0.05, "profondeur": 0.05, "lueur": 0.42, "opacite": 0.88, "reflet": Color(1.0, 0.93, 0.94)},
	"jade": {"bord": 0.55, "poli": 0.9, "profondeur": 0.03, "lueur": 0.16, "reflet": Color(0.92, 1.0, 0.95)},
	"amethyste": {"teinte": Color(1.04, 1.0, 1.08), "bord": 0.45, "poli": 1.0, "metal": 0.05, "profondeur": 0.05, "lueur": 0.42, "opacite": 0.88, "reflet": Color(0.98, 0.92, 1.04)},
}

static var _mats := {}

static func materiaux() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	_mats = {
		"or": _matiere("or", EpeesLongues._or_patine(false)),
		"argent": _matiere("argent", _metal_terni(ARGENT, 301, 0.6)),
		"bronze": _matiere("bronze", _bronze()),
		"fer": _matiere("fer", EpeesLongues._fer_forge(false)),
		"cuir": _matiere("cuir", EpeesLongues._cuir_fusee()),
		"os": _matiere("os", _os()),
		"gemme": _matiere("gemme", EpeesLongues._cristal_profond(GIVRE, 77)),
		"saphir": _matiere("saphir", EpeesLongues._cristal_profond(EpeesLongues.SAPHIR_PROFOND, 63)),
		"rubis": _matiere("rubis", EpeesLongues._cristal_profond(EpeesLongues.RUBIS_PROFOND, 41)),
		"jade": _matiere("jade", EpeesLongues._cristal_profond(JADE, 89)),
		"amethyste": _matiere("amethyste", EpeesLongues._cristal_profond(AMETHYSTE, 97)),
	}
	for m: ShaderMaterial in _mats.values():
		m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))   # glb : alpha de sommet 0 = neige -> neige = base
	return _mats

## Remplace les matériaux importés par les matériaux PS1, par nom de matériau Blender ; noms inconnus : matériaux des épées
## (EpeesLongues.materiaux : lame, emeraude…) en repli.
static func habiller(racine: Node, ombres := false) -> void:
	var mats := materiaux()
	var autres := EpeesLongues.materiaux()
	var mailles: Array = racine.find_children("*", "MeshInstance3D", true, false)
	if racine is MeshInstance3D:
		mailles.append(racine)
	for mi: MeshInstance3D in mailles:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombres else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var nom := (m.resource_name if m else "").get_slice(".", 0)
			if mats.has(nom):
				mi.set_surface_override_material(s, mats[nom])
			elif autres.has(nom):
				mi.set_surface_override_material(s, autres[nom])

static func _matiere(nom: String, img: Image) -> ShaderMaterial:
	var p: Dictionary = PRESETS[nom]
	var m := Palette.materiau(ImageTexture.create_from_image(img), Vector2.ONE, p.get("teinte", Color.WHITE))
	var op := float(p.get("opacite", 1.0))
	m.shader = EpeesLongues.shader_matiere(op < 1.0)
	m.set_shader_parameter("mt_boite", 1.0 if p.has("boite") else 0.0)
	m.set_shader_parameter("mt_texels", float(p.get("boite", 4.0)))
	for k in ["metal", "poli", "bord", "profondeur", "lueur"]:
		m.set_shader_parameter("mt_" + k, float(p.get(k, 0.0)))
	m.set_shader_parameter("mt_opacite", op)
	m.set_shader_parameter("mt_reflet", p.get("reflet", Color.WHITE))
	m.set_shader_parameter("reflet_force", 0.0)
	m.set_shader_parameter("reflet_fil", 0.0)
	return m

## Métal précieux terni 64 x 64 : fines rayures de polissage (claires, brillantes), ternissure sombre par plaques (mate).
static func _metal_terni(pal: Array, g: int, base: float) -> Image:
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var ray := EpeesLongues._rayures(S, S, g, 40, true)
	for y in S:
		for x in S:
			var n := ObjetsTextures._fbm(x, y, S, S, 4, 4, g + 1, 3)
			var t := ObjetsTextures._fbm(x, y, S, S, 3, 3, g + 2, 3)
			var l := base + (n - 0.5) * 0.2
			var b := 0.85
			if t > 0.62:
				l -= (t - 0.62) * 1.6
				b = 0.2
			if ray[y * S + x] > 0.5:
				l += 0.1
				b = 1.0
			elif ray[y * S + x] < -0.5:
				l -= 0.07
				b = 0.4
			EpeesLongues._pix(img, x, y, pal, l, b)
	return img

## Bronze : métal brun doré, plaques de vert-de-gris mates dans les creux.
static func _bronze() -> Image:
	var S := 64
	var img := _metal_terni(BRONZE, 311, 0.56)
	for y in S:
		for x in S:
			var v := ObjetsTextures._fbm(x, y, S, S, 5, 5, 313, 3)
			if v > 0.63:
				EpeesLongues._pix(img, x, y, VERT_DE_GRIS, 0.35 + (v - 0.63) * 1.5, 0.05)
	return img

## Os / griffe : ivoire jauni, stries longitudinales (v), pointe plus sombre et polie.
static func _os() -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		var v := float(y) / (S - 1)
		for x in S:
			var strie := ObjetsTextures._fbm(x, y, S, S, 16, 2, 321, 2)
			var l := 0.66 - v * 0.28 + (strie - 0.5) * 0.22
			var b := 0.35 + v * 0.5
			if EpeesLongues._h(x, y, 322) > 0.985:
				l -= 0.2
			EpeesLongues._pix(img, x, y, OS_IVOIRE, l, b)
	return img
