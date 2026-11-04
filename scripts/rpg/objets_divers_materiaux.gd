class_name ObjetsDiversMateriaux
## Matériaux PS1 « réalistes » des objets divers (assets/modeles/objets/<id>.glb, source sources_blender/objets/objets_divers.py) :
## potions, vivres, tomes, ingrédients, reliques, objets de quête. Même principe que BijouxMateriaux : posés par NOM de matériau
## Blender, shader_matiere d'EpeesLongues (reflet en paliers, bord vitreux, profondeur, lueur), textures 64 x 64 peintes au BRUIT
## (fbm + hachage, jamais de tramage ordonné), alpha = brillance du texel, projection boîte dans le repère du modèle.
##   verre            verre soufflé verdâtre, translucide (bulles, coulures) : on voit le liquide au travers
##   liquide_soin / liquide_mana / liquide_vigueur   liquide profond (couche interne qui glisse), légère lueur
##   liege, cire, ficelle, cuir des coiffes          bouchons, cachets, liens
##   croute, farine, viande                          pain de seigle, viande séchée (fibres, gras)
##   os_vieux, croc                                  os jauni sale, ivoire de croc
##   toile, cendre                                   sachet de lin, poussière de tombe
##   ecaille                                         écaille de dragon (bronze vert sombre, stries)
##   roche, veine_fer, veine_argent, cristal_givre   minerais et cristal (profondeur, translucide)
##   chapeau_lumineux, pied_champi, mousse           champignon luminescent
##   fourrure, peau                                  fourrure de troll givrée
##   fer_rouille, cuivre                             lame antique, anneau de cuivre (vert-de-gris)
##   or_m, argent_m, bronze_m, fer_m, cuir_m          matières des bijoux, texture moins dense (pièces > 5 cm : coupe, reliquaire, livres, clé)
##   pages, reliure_feu/givre/eclair/tenebres/vie/brune/claire   livres
##   sceau_os, sceau_givre, sceau_eau                pierres des fragments de sceau
## Les noms communs (or, argent, bronze, fer, cuir, os, gemme, saphir, rubis, jade, amethyste, bois, obsidienne) restent à
## BijouxMateriaux / EpeesLongues (ObjetMonde.visuel appelle BijouxMateriaux.habiller puis ObjetsDiversMateriaux.habiller).
## LISIBILITÉ : comme les bijoux, une légère lueur propre (mt_lueur) garde ces petits objets visibles sur les pavés sombres.

const VERRE := ["#0a120e", "#13201a", "#1f3128", "#30473b", "#466152", "#617d6c", "#84a08c", "#adc6b0", "#d9eadb"]
const LIQ_ROUGE := ["#0e0103", "#220207", "#3a040c", "#560814", "#760e1c", "#9a1626", "#c02434", "#e04a4e", "#f88a80"]
const LIQ_BLEU := ["#01040e", "#030a20", "#061636", "#0b2550", "#12386e", "#1c5090", "#2a6cb4", "#4a92d8", "#8cc4f4"]
const LIQ_VERT := ["#020a03", "#051607", "#09240d", "#0f3616", "#174c20", "#22662c", "#30823a", "#4aa250", "#86cc80"]
const LIEGE := ["#1a120a", "#2a1d10", "#3c2a18", "#503a22", "#664b2e", "#7c5e3c", "#92714c", "#a8865e"]
const CIRE := ["#120203", "#220407", "#36070c", "#4c0b12", "#62101a", "#7a1822", "#94242c", "#b23a3a"]
const CHANVRE := ["#1c160c", "#2c2414", "#3e341e", "#52462a", "#665836", "#7a6b44", "#8e7e54", "#a49266"]
const CROUTE := ["#140904", "#221007", "#32180a", "#43200e", "#552a13", "#683518", "#7c421f", "#904f27", "#a45e31"]
const FARINE := ["#4a4034", "#605446", "#786a5a", "#90826e", "#a89a84", "#c0b29a"]
const VIANDE := ["#0e0404", "#1a0706", "#280b09", "#38100c", "#4a1610", "#5c1e15", "#70281b", "#863522"]
const GRAS := ["#5a4632", "#76603f", "#93794e", "#ad9260"]
const OS_VIEUX := ["#1e170e", "#2e2416", "#40331f", "#54442a", "#6a5736", "#7f6a44", "#958054", "#ab9666", "#c1ac7c"]
const CROC := ["#2a2418", "#3e3624", "#544a33", "#6c6044", "#857857", "#9e916c", "#b7aa84", "#cfc39e", "#e4dabb"]
const TOILE := ["#1c1912", "#2a261c", "#3a3527", "#4c4534", "#5e5641", "#71684f", "#857b5e", "#988e6e"]
const CENDRE := ["#141313", "#201f1e", "#2e2c2a", "#3d3b38", "#4e4b47", "#605c57", "#736e68", "#86817a"]
const ECAILLE := ["#070706", "#0f0e0c", "#181612", "#221f19", "#2d2920", "#3a3428", "#484030", "#574d39", "#6a5d45", "#857456"]
const ROCHE := ["#0c0c0d", "#151516", "#1e1e20", "#28282a", "#333335", "#3f3f41", "#4c4b4d", "#5a595a", "#6a6869"]
const HEMATITE := ["#120806", "#1e0d09", "#2c130d", "#3c1a11", "#4e2416", "#622e1b", "#783a22", "#8e482a"]
const ROUILLE := ["#3a1a0a", "#55270f", "#713614", "#8c461a", "#a65822"]
const ARGENT_VIF := ["#101114", "#1c1e22", "#2a2d32", "#3b3f45", "#50555c", "#686e75", "#838990", "#a0a6ac", "#c0c5c9", "#e2e6e8", "#f8fafb"]
const GIVRE := ["#06121c", "#0c1f2e", "#153044", "#20465e", "#2f5f7a", "#437b96", "#5e9ab2", "#82bacc", "#aed8e4", "#e2f6fa"]
const LUMINEUX := ["#02100f", "#04201d", "#08332e", "#0e4a42", "#166459", "#228172", "#36a08f", "#58c0ad", "#8ee0cf", "#d0fff2"]
const CREME := ["#2a2620", "#3e392f", "#544d40", "#6c6452", "#857c66", "#9e957c", "#b6ad94", "#ccc4ac"]
const MOUSSE := ["#070a04", "#0d1307", "#141d0b", "#1c2810", "#253416", "#2f411c", "#3a4f23", "#475e2c"]
const FOURRURE := ["#17171a", "#222226", "#2e2e32", "#3b3b3f", "#4a4a4d", "#5a5a5c", "#6c6b6b", "#807e7c", "#96938f", "#b2aea8", "#d6d6d8"]
const PEAU := ["#20160d", "#302214", "#42301d", "#563f27", "#6a4f32", "#7e603e", "#92724c"]
const FER_FORGE := ["#0c0d0f", "#141619", "#1d2024", "#272b30", "#33383e", "#41474e", "#525960", "#666d74", "#7e858b"]
const CUIVRE := ["#120a07", "#1e110c", "#2e1b13", "#3f261a", "#523222", "#663f2a", "#7a4d34", "#8e5c3f", "#a26c4c", "#b8805e"]
const VERT_DE_GRIS := ["#14201a", "#1f3027", "#2b4236", "#3a5646", "#4d6c58", "#64846c"]
const PARCHEMIN := ["#2a2116", "#3c3020", "#50422c", "#665639", "#7c6a48", "#927f58", "#a8946a", "#bcaa7e", "#d0c094"]
const RELIURES := {
	"reliure_feu": ["#120403", "#200806", "#320c08", "#46120b", "#5c1a10", "#742416", "#8e321e", "#a84428"],
	"reliure_givre": ["#06090e", "#0c121a", "#141c28", "#1e2838", "#2a374a", "#38485e", "#4a5c74", "#60748c"],
	"reliure_eclair": ["#0b0610", "#140a1c", "#1e102a", "#2a173a", "#38204c", "#482a5e", "#5a3672", "#6e4486"],
	"reliure_tenebres": ["#060607", "#0b0b0d", "#121215", "#1a1a1e", "#232328", "#2e2e34", "#3a3a42", "#484852"],
	"reliure_vie": ["#0c0204", "#160408", "#22060c", "#300a12", "#400e18", "#52141f", "#661c28", "#7c2632"],
	"reliure_brune": ["#0f0905", "#190f09", "#25160d", "#321e12", "#402717", "#4f301d", "#603b24", "#72472c"],
	"reliure_claire": ["#1e140b", "#2e2012", "#3f2c1a", "#523a23", "#66492d", "#7a5938", "#8e6a45", "#a27c54"],
}
const SCEAU_OS := ["#2a2419", "#3c3424", "#504632", "#665a42", "#7c6f54", "#938668", "#aa9d7e", "#c0b495", "#d4caae"]
const SCEAU_GIVRE := ["#10161c", "#1a222a", "#26303a", "#333f4b", "#42505e", "#536272", "#677788", "#7e8e9e", "#98a8b6"]
const SCEAU_EAU := ["#040b0c", "#081416", "#0e1e21", "#15292d", "#1d353a", "#264247", "#315056", "#3e6066"]

## Presets (clés du shader_matiere) ; boite = RÉPÉTITIONS de la texture 64 px par m (projection boîte) : environ 1 / taille de
## l'objet, sinon la texture se répète plusieurs fois sur la pièce et scintille (pas de mipmaps en ps1) ; opacite < 1 = translucide.
const PRESETS := {
	"verre": {"teinte": Color(1.0, 1.06, 1.02), "boite": 10.0, "bord": 0.9, "poli": 1.0, "lueur": 0.12, "opacite": 0.26, "reflet": Color(0.92, 1.0, 0.96)},
	"liquide_soin": {"teinte": Color(1.1, 1.0, 1.0), "boite": 12.0, "bord": 0.3, "poli": 0.9, "profondeur": 0.05, "lueur": 0.75, "reflet": Color(1.0, 0.9, 0.9)},
	"liquide_mana": {"teinte": Color(1.0, 1.02, 1.1), "boite": 12.0, "bord": 0.3, "poli": 0.9, "profondeur": 0.05, "lueur": 0.75, "reflet": Color(0.9, 0.95, 1.05)},
	"liquide_vigueur": {"teinte": Color(1.0, 1.08, 1.0), "boite": 12.0, "bord": 0.3, "poli": 0.9, "profondeur": 0.05, "lueur": 0.75, "reflet": Color(0.92, 1.04, 0.92)},
	"liege": {"boite": 45.0, "bord": 0.05, "poli": 0.1, "lueur": 0.3},
	"cire": {"boite": 30.0, "bord": 0.25, "poli": 0.55, "lueur": 0.35},
	"ficelle": {"boite": 30.0, "bord": 0.08, "poli": 0.1, "lueur": 0.3},
	"croute": {"boite": 6.0, "bord": 0.1, "poli": 0.25, "lueur": 0.25},
	"farine": {"boite": 6.0, "bord": 0.05, "poli": 0.15, "lueur": 0.25},
	"viande": {"boite": 7.0, "bord": 0.2, "poli": 0.4, "lueur": 0.3},
	"os_vieux": {"boite": 5.0, "bord": 0.2, "poli": 0.3, "lueur": 0.35},
	"croc": {"boite": 10.0, "bord": 0.3, "poli": 0.55, "lueur": 0.4},
	"toile": {"boite": 10.0, "bord": 0.06, "poli": 0.1, "lueur": 0.3},
	"cendre": {"boite": 12.0, "bord": 0.0, "poli": 0.05, "lueur": 0.3},
	"ecaille": {"boite": 7.0, "metal": 0.25, "bord": 0.45, "poli": 0.65, "lueur": 0.3, "reflet": Color(0.94, 1.02, 0.92)},
	"roche": {"boite": 7.0, "bord": 0.05, "poli": 0.2, "lueur": 0.22},
	"veine_fer": {"boite": 9.0, "metal": 0.4, "poli": 0.4, "lueur": 0.3, "reflet": Color(1.0, 0.92, 0.86)},
	"veine_argent": {"teinte": Color(1.02, 1.03, 1.06), "boite": 9.0, "metal": 0.85, "poli": 0.85, "lueur": 0.6, "reflet": Color(0.94, 0.98, 1.06)},
	"cristal_givre": {"teinte": Color(1.0, 1.03, 1.08), "bord": 0.6, "poli": 1.0, "metal": 0.05, "profondeur": 0.06, "lueur": 0.5, "opacite": 0.84, "reflet": Color(0.9, 0.97, 1.04)},
	"chapeau_lumineux": {"boite": 20.0, "bord": 0.2, "poli": 0.5, "lueur": 1.15},
	"pied_champi": {"boite": 25.0, "bord": 0.1, "poli": 0.2, "lueur": 0.4},
	"mousse": {"boite": 9.0, "bord": 0.05, "poli": 0.1, "lueur": 0.2},
	"fourrure": {"teinte": Color(1.0, 1.02, 1.06), "boite": 4.0, "bord": 0.1, "poli": 0.05, "lueur": 0.18},
	"peau": {"boite": 6.0, "bord": 0.1, "poli": 0.2, "lueur": 0.25},
	"fer_rouille": {"boite": 3.5, "metal": 0.35, "poli": 0.3, "lueur": 0.3, "reflet": Color(0.98, 0.95, 0.92)},
	"cuivre": {"boite": 50.0, "metal": 0.7, "poli": 0.6, "lueur": 0.5, "reflet": Color(1.06, 0.86, 0.72)},
	"pages": {"boite": 7.0, "bord": 0.05, "poli": 0.1, "lueur": 0.3},
	"sceau_os": {"boite": 6.0, "bord": 0.12, "poli": 0.3, "lueur": 0.3},
	"sceau_givre": {"boite": 6.0, "bord": 0.3, "poli": 0.5, "lueur": 0.3, "reflet": Color(0.92, 0.98, 1.06)},
	"sceau_eau": {"boite": 6.0, "bord": 0.4, "poli": 0.6, "lueur": 0.28, "reflet": Color(0.9, 1.0, 1.02)},
	"reliure": {"boite": 5.0, "bord": 0.18, "poli": 0.25, "lueur": 0.3},
}

static var _mats := {}

static func materiaux() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	_mats = {
		"verre": _matiere("verre", _verre()),
		"liquide_soin": _matiere("liquide_soin", EpeesLongues._cristal_profond(LIQ_ROUGE, 141)),
		"liquide_mana": _matiere("liquide_mana", EpeesLongues._cristal_profond(LIQ_BLEU, 143)),
		"liquide_vigueur": _matiere("liquide_vigueur", EpeesLongues._cristal_profond(LIQ_VERT, 147)),
		"liege": _matiere("liege", _pores(LIEGE, 151)),
		"cire": _matiere("cire", _lisse(CIRE, 153, 0.55)),
		"ficelle": _matiere("ficelle", _fibres(CHANVRE, 157, 2, 24, 0.55)),
		"croute": _matiere("croute", _croute(false)),
		"farine": _matiere("farine", _croute(true)),
		"viande": _matiere("viande", _viande()),
		"os_vieux": _matiere("os_vieux", _os(OS_VIEUX, 171, 0.5)),
		"croc": _matiere("croc", _os(CROC, 173, 0.62)),
		"toile": _matiere("toile", _toile()),
		"cendre": _matiere("cendre", _grain(CENDRE, 181, 0.55, 0.25)),
		"ecaille": _matiere("ecaille", _ecaille()),
		"roche": _matiere("roche", _grain(ROCHE, 191, 0.5, 0.3)),
		"veine_fer": _matiere("veine_fer", _veine_fer()),
		"veine_argent": _matiere("veine_argent", _metal(ARGENT_VIF, 197, 0.62)),
		"cristal_givre": _matiere("cristal_givre", EpeesLongues._cristal_profond(GIVRE, 199)),
		"chapeau_lumineux": _matiere("chapeau_lumineux", _chapeau()),
		"pied_champi": _matiere("pied_champi", _fibres(CREME, 211, 3, 18, 0.62)),
		"mousse": _matiere("mousse", _grain(MOUSSE, 213, 0.55, 0.35)),
		"fourrure": _matiere("fourrure", _fourrure()),
		"peau": _matiere("peau", _lisse(PEAU, 219, 0.55)),
		"fer_rouille": _matiere("fer_rouille", _fer_rouille()),
		"cuivre": _matiere("cuivre", _cuivre()),
		"pages": _matiere("pages", _pages()),
		"sceau_os": _matiere("sceau_os", _grain(SCEAU_OS, 231, 0.6, 0.22)),
		"sceau_givre": _matiere("sceau_givre", _givre_pierre()),
		"sceau_eau": _matiere("sceau_eau", _grain(SCEAU_EAU, 237, 0.55, 0.3)),
	}
	var bm := BijouxMateriaux.materiaux()
	for nom: String in ["or", "argent", "bronze", "fer", "cuir"]:
		var d := (bm[nom] as ShaderMaterial).duplicate() as ShaderMaterial
		d.set_shader_parameter("mt_texels", 9.0)
		Palette.suivre(d)                      # suit le réglage ps1 (regler_ps1) comme les autres
		_mats[nom + "_m"] = d
	var g := 241
	for nom: String in RELIURES:
		_mats[nom] = _matiere("reliure", _cuir(RELIURES[nom], g))
		g += 2
	for m: ShaderMaterial in _mats.values():
		m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))   # glb : alpha de sommet 0 = neige -> neige = base
	return _mats

## Remplace, par nom de matériau Blender, les matériaux importés connus ici (les autres sont laissés tels quels).
static func habiller(racine: Node, ombres := false) -> void:
	var mats := materiaux()
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

static func connu(nom: String) -> bool:
	return materiaux().has(nom)

static func _matiere(preset: String, img: Image) -> ShaderMaterial:
	var p: Dictionary = PRESETS[preset]
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

# ------------------------------------------------------------------ textures 64 x 64 (bruit à seuil, alpha = brillance)
const S := 64

static func _f(x: int, y: int, cx: int, cy: int, g: int, oct := 3) -> float:
	return ObjetsTextures._fbm(x, y, S, S, cx, cy, g, oct)

static func _h(x: int, y: int, g: int) -> float:
	return EpeesLongues._h(x, y, g)

static func _pix(img: Image, x: int, y: int, pal: Array, l: float, b: float) -> void:
	EpeesLongues._pix(img, x, y, pal, l, b, 0.14)          # faible gigue : surfaces lisibles, pas de « sel et poivre »

static func _img() -> Image:
	return Image.create(S, S, false, Image.FORMAT_RGBA8)

## Grain minéral : fbm à deux échelles, quelques grains clairs et creux sombres (pierre, cendre, mousse).
static func _grain(pal: Array, g: int, base: float, ampl: float) -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var l := base + (_f(x, y, 4, 4, g) - 0.5) * ampl * 2.0 + (_f(x, y, 16, 16, g + 1, 2) - 0.5) * ampl
			var b := 0.3
			var hh := _h(x, y, g + 2)
			if hh > 0.97:
				l += 0.15
				b = 0.8
			elif hh < 0.03:
				l -= 0.15
				b = 0.1
			_pix(img, x, y, pal, l, b)
	return img

## Fibres orientées (ficelle, fourrure, chair du pied) : bruit étiré cx x cy, mèches claires.
static func _fibres(pal: Array, g: int, cx: int, cy: int, base: float) -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var f := _f(x, y, cx, cy, g)
			var l := base + (f - 0.5) * 0.7 + (_f(x, y, 8, 8, g + 1, 2) - 0.5) * 0.25
			var b := 0.25 + clampf((f - 0.5) * 1.5, 0.0, 0.6)
			_pix(img, x, y, pal, l, b)
	return img

## Surface lisse à peine marbrée (cire, peau tannée).
static func _lisse(pal: Array, g: int, base: float) -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var l := base + (_f(x, y, 3, 3, g) - 0.5) * 0.35
			var b := 0.55 + (_f(x, y, 6, 6, g + 1) - 0.5) * 0.6
			if _h(x, y, g + 3) > 0.985:
				l -= 0.12
			_pix(img, x, y, pal, l, b)
	return img

## Liège : fond tacheté, pores sombres allongés.
static func _pores(pal: Array, g: int) -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var l := 0.55 + (_f(x, y, 8, 8, g) - 0.5) * 0.5
			if _f(x, y, 12, 4, g + 1, 2) > 0.66:
				l -= 0.3
			if _h(x, y, g + 2) > 0.95:
				l -= 0.2
			_pix(img, x, y, pal, l, 0.1)
	return img

## Verre soufflé : coulures verticales, bulles claires, quelques voiles.
static func _verre() -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var l := 0.55 + (_f(x, y, 2, 8, 401) - 0.5) * 0.35
			var b := 1.0
			if _h(x, y, 403) > 0.985:
				l = 0.95                                          # bulle
			elif _f(x, y, 6, 6, 405, 2) > 0.66:
				l += 0.1
				b = 0.7                                           # voile
			_pix(img, x, y, VERRE, l, b)
	return img

## Croûte de seigle : brun sombre crevassé ; `farine` : poudrée de farine par plaques (dessus et entailles).
static func _croute(farine: bool) -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var l := 0.58 + (_f(x, y, 3, 3, 411) - 0.5) * 0.4
			var b := 0.35
			var cr := _f(x, y, 10, 10, 413, 2)
			if absf(cr - 0.5) < 0.018:
				l -= 0.18                                         # craquelure
				b = 0.1
			var fa := _f(x, y, 4, 4, 415)
			if (farine and fa > 0.5) or (not farine and fa > 0.74):
				_pix(img, x, y, FARINE, 0.2 + (fa - 0.5) * 2.0, 0.1)
				continue
			_pix(img, x, y, CROUTE, l, b)
	return img

## Viande séchée : fibres rouge sombre, marbrures de gras jaunâtre, brillance grasse.
static func _viande() -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var f := _f(x, y, 24, 3, 421)
			var l := 0.5 + (f - 0.5) * 0.6 + (_f(x, y, 4, 4, 423) - 0.5) * 0.3
			var gr := _f(x, y, 12, 2, 425, 2)
			if gr > 0.71:
				_pix(img, x, y, GRAS, 0.2 + (gr - 0.71) * 3.0, 0.7)
				continue
			_pix(img, x, y, VIANDE, l, 0.35 + f * 0.4)
	return img

## Os : stries longues, taches de terre, petites piqûres.
static func _os(pal: Array, g: int, base: float) -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var l := base + (_f(x, y, 20, 3, g) - 0.5) * 0.3 + (_f(x, y, 4, 4, g + 1) - 0.5) * 0.3
			var b := 0.45
			if _f(x, y, 5, 5, g + 2) > 0.64:
				l -= 0.25                                         # terre / crasse
				b = 0.1
			if _h(x, y, g + 3) > 0.98:
				l -= 0.3
			_pix(img, x, y, pal, l, b)
	return img

## Toile de lin : fils croisés irréguliers (deux bruits étirés), salissures.
static func _toile() -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var a := _f(x, y, 32, 2, 431, 2)
			var c := _f(x, y, 2, 32, 433, 2)
			var l := 0.5 + (maxf(a, c) - 0.5) * 0.7 + (_f(x, y, 4, 4, 435) - 0.5) * 0.3
			if _f(x, y, 5, 5, 437) > 0.66:
				l -= 0.2
			_pix(img, x, y, TOILE, l, 0.15)
	return img

## Écaille : stries concentriques sombres (lignes de croissance) sur bronze vert, arêtes polies.
static func _ecaille() -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var w := y + (_f(x, y, 4, 4, 441) - 0.5) * 10.0
			var s := absf(fmod(w, 7.0) - 3.5) / 3.5
			var l := 0.45 + s * 0.25 + (_f(x, y, 8, 8, 443) - 0.5) * 0.25
			var b := 0.3 + s * 0.7
			if _h(x, y, 445) > 0.985:
				l += 0.2
			_pix(img, x, y, ECAILLE, l, b)
	return img

## Hématite : métal brun-rouge sombre, plaques de rouille orangée mates.
static func _veine_fer() -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var r := _f(x, y, 5, 5, 451)
			if r > 0.6:
				_pix(img, x, y, ROUILLE, (r - 0.6) * 3.5 + (_h(x, y, 453) - 0.5) * 0.3, 0.05)
				continue
			var l := 0.5 + (_f(x, y, 12, 12, 455, 2) - 0.5) * 0.6
			_pix(img, x, y, HEMATITE, l, 1.0 if _h(x, y, 457) > 0.9 else 0.5)
	return img

## Métal natif (argent) : facettes claires, creux noircis.
static func _metal(pal: Array, g: int, base: float) -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var n := _f(x, y, 6, 6, g)
			var l := base + (n - 0.5) * 0.6
			var b := 0.9
			if _f(x, y, 4, 4, g + 1) > 0.63:
				l -= 0.35
				b = 0.2
			if _h(x, y, g + 2) > 0.97:
				l = 0.97
				b = 1.0
			_pix(img, x, y, pal, l, b)
	return img

## Chapeau luminescent : turquoise, mouchetures claires plus lumineuses, bords sombres.
static func _chapeau() -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var l := 0.5 + (_f(x, y, 4, 4, 461) - 0.5) * 0.4
			var t := _f(x, y, 10, 10, 463, 2)
			if t > 0.64:
				l = 0.85 + (t - 0.64) * 0.6                       # moucheture
			elif _f(x, y, 3, 12, 465) < 0.33:
				l -= 0.25                                         # stries sombres
			_pix(img, x, y, LUMINEUX, l, 0.6)
	return img

## Fer piqué de rouille : fer forgé sombre, larges plaques d'oxyde, éclats encore nus.
static func _fer_rouille() -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var r := _f(x, y, 5, 5, 471)
			var l := 0.45 + (_f(x, y, 14, 3, 473, 2) - 0.5) * 0.4
			if r > 0.5:
				var pal := ROUILLE if r > 0.62 else EpeesLongues.OXYDE
				_pix(img, x, y, pal, (r - 0.5) * 2.5 + (_h(x, y, 475) - 0.5) * 0.4, 0.08)
				continue
			if _h(x, y, 477) > 0.975:
				l = 0.85
			_pix(img, x, y, FER_FORGE, l, 0.65)
	return img

## Cuivre terni : brun rosé poli, vert-de-gris dans les creux.
static func _cuivre() -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var l := 0.58 + (_f(x, y, 6, 6, 481) - 0.5) * 0.35
			var b := 0.85
			var v := _f(x, y, 5, 5, 483)
			if v > 0.6:
				_pix(img, x, y, VERT_DE_GRIS, 0.3 + (v - 0.6) * 1.8, 0.05)
				continue
			if _h(x, y, 485) > 0.97:
				l += 0.15
				b = 1.0
			_pix(img, x, y, CUIVRE, l, b)
	return img

## Tranche des pages : feuillets (lignes horizontales irrégulières), bords jaunis/salis par plaques.
static func _pages() -> Image:
	var img := _img()
	for y in S:
		var ligne := _h(0, y, 491) > 0.55
		for x in S:
			var l := 0.66 + (_f(x, y, 3, 3, 493) - 0.5) * 0.3
			if ligne:
				l -= 0.16 + (_f(x, y, 12, 1, 495, 2) - 0.5) * 0.1
			if _f(x, y, 4, 4, 497) > 0.68:
				l -= 0.2
			_pix(img, x, y, PARCHEMIN, l, 0.1)
	return img

## Cuir de reliure : grain fin, plis sombres, usure claire (coins, arêtes).
static func _cuir(pal: Array, g: int) -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var l := 0.52 + (_f(x, y, 3, 3, g) - 0.5) * 0.36 + (_f(x, y, 16, 16, g + 4, 1) - 0.5) * 0.08
			var b := 0.35
			var pli := _f(x, y, 3, 9, g + 2, 2)
			if absf(pli - 0.5) < 0.012:
				l -= 0.12
				b = 0.1
			var u := _f(x, y, 4, 4, g + 3)
			if u > 0.68:
				l += (u - 0.68) * 1.6                              # usure claire
				b = 0.6
			_pix(img, x, y, pal, l, b)
	return img

## Fourrure de troll : touffes (mèches courtes orientées au hasard par plaques), fond gris sale, pointes givrées claires.
static func _fourrure() -> Image:
	var img := _img()
	for y in S:
		for x in S:
			var o := _f(x, y, 3, 3, 501)                          # orientation des mèches par plaque
			var m := _f(x, y, 22, 6, 503, 2) if o > 0.5 else _f(x, y, 6, 22, 505, 2)
			var l := 0.5 + (m - 0.5) * 0.55 + (_f(x, y, 4, 4, 507) - 0.5) * 0.3
			var b := 0.1 + clampf((m - 0.55) * 1.2, 0.0, 0.3)
			if m > 0.72 and _h(x, y, 509) > 0.5:
				l = 0.95                                          # pointes givrées
			_pix(img, x, y, FOURRURE, l, b)
	return img

## Pierre givrée : gris bleu, cristaux de givre clairs semés, plus brillants.
static func _givre_pierre() -> Image:
	var img := _grain(SCEAU_GIVRE, 233, 0.55, 0.25)
	for y in S:
		for x in S:
			if _f(x, y, 7, 7, 235, 2) > 0.64 and _h(x, y, 236) > 0.4:
				_pix(img, x, y, GIVRE, 0.75 + _h(x, y, 238) * 0.25, 1.0)
	return img
