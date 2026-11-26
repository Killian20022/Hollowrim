class_name RealismePnj
## [pnj/realisme_v1, 2026-11-26] Passe « moins Playmobil » sur les PNJ maison (archétypes Guerrier / Chasseresse / Mage dérivés par
## PnjNordique) : retour utilisateur « revois un peu les PNJ que tu as créés toi, au niveau des détails, qu'ils fassent parfois un peu
## moins Playmobil et plus réels dans tout ». Cible de réalisme : les modèles joueur fournis (Jeux/references/joueur_base).
## Appliquée APRÈS la construction de l'archétype (maillages, squelette, animations, armures INCHANGÉS ; seules les images des
## matériaux sont repeintes, sur des COPIES : l'archétype partagé n'est pas touché) :
##   - visage : traits peints dans l'atlas de peau (orbites creusées, arcade, arêtes et ailes du nez, sillons nasogéniens, commissures,
##     pommettes, menton), rougeur du froid (nez, pommettes), barbe naissante, rides selon l'âge, grain de peau (VisagePnj) ;
##   - étoffes : couleurs ramenées vers des tons nordiques désaturés, plis verticaux, ourlets crottés de boue, taches, zones râpées ;
##   - cheveux / barbe : mèches (sillons sombres et reflets le long des brins) au lieu d'un aplat « casque » ;
##   - variations entre individus : graine propre à chaque PNJ (taches, plis, rides), âge, rougeur, salissure (table PROFILS).
## Désactivable : argument utilisateur `--pnj-realisme-ancien` (rendu d'avant, planches avant/après).
## Ne s'applique PAS à « eirik » ni « garde » (corps de la crypte, chantier compagnon_mort) ni aux corps Tripo.

static var _ancien := -1
## Images précalculées (outils/generer_realisme_pnj.gd, VERSION++ après toute modif des peintures) : rien n'est repeint au lancement.
const DOSSIER := "res://assets/pnj/realisme"
const VERSION := 2
static var enregistrer := false
static var chrono := false

## Profils par id de PnjNordique : sexe (h|f), age (0 jeune, 1 mûr, 2 vieux), barbe (barbe naissante 0-1), rougeur (0-1),
## sale (salissure des étoffes 0-1), desat (désaturation des étoffes 0-1), taille (échelle du corps, variation entre individus).
const PROFILS := {
	"forgeron":          {"sexe": "h", "age": 1, "barbe": 0.8, "rougeur": 0.9, "sale": 0.9, "desat": 0.15, "taille": 1.0},
	"chasseuse":         {"sexe": "f", "age": 0, "barbe": 0.0, "rougeur": 0.6, "sale": 0.55, "desat": 0.20, "taille": 0.99},
	"volva":             {"sexe": "f", "age": 2, "barbe": 0.0, "rougeur": 0.25, "sale": 0.45, "desat": 0.22, "taille": 0.98},
	"ancienne":          {"sexe": "f", "age": 2, "barbe": 0.0, "rougeur": 0.45, "sale": 0.55, "desat": 0.22, "taille": 0.96},
	"chef":              {"sexe": "f", "age": 1, "barbe": 0.0, "rougeur": 0.5, "sale": 0.35, "desat": 0.15, "taille": 1.0},
	"garde_lance":       {"sexe": "h", "age": 1, "barbe": 0.6, "rougeur": 0.6, "sale": 0.5, "desat": 0.15, "taille": 1.0},
	"hab_paysan_a":      {"sexe": "h", "age": 1, "barbe": 0.7, "rougeur": 0.8, "sale": 0.85, "desat": 0.25, "taille": 0.98},
	"hab_paysan_b":      {"sexe": "h", "age": 0, "barbe": 0.55, "rougeur": 0.5, "sale": 0.7, "desat": 0.25, "taille": 1.02},
	"hab_paysan_c":      {"sexe": "h", "age": 2, "barbe": 0.5, "rougeur": 0.7, "sale": 0.7, "desat": 0.30, "taille": 0.96},
	"hab_paysanne_a":    {"sexe": "f", "age": 1, "barbe": 0.0, "rougeur": 0.7, "sale": 0.7, "desat": 0.28, "taille": 0.97},
	"hab_paysanne_b":    {"sexe": "f", "age": 2, "barbe": 0.0, "rougeur": 0.5, "sale": 0.6, "desat": 0.30, "taille": 0.95},
	"hab_paysanne_c":    {"sexe": "f", "age": 0, "barbe": 0.0, "rougeur": 0.6, "sale": 0.9, "desat": 0.30, "taille": 0.98},
	"hab_chasseur_a":    {"sexe": "h", "age": 1, "barbe": 0.85, "rougeur": 0.7, "sale": 0.75, "desat": 0.22, "taille": 1.03},
	"hab_chasseur_b":    {"sexe": "h", "age": 0, "barbe": 0.6, "rougeur": 0.6, "sale": 0.75, "desat": 0.25, "taille": 0.99},
	"hab_chasseresse_a": {"sexe": "f", "age": 0, "barbe": 0.0, "rougeur": 0.55, "sale": 0.65, "desat": 0.22, "taille": 1.0},
	"hab_chasseresse_b": {"sexe": "f", "age": 1, "barbe": 0.0, "rougeur": 0.65, "sale": 0.65, "desat": 0.25, "taille": 0.98},
	"hab_receleur":      {"sexe": "h", "age": 2, "barbe": 0.6, "rougeur": 0.45, "sale": 0.6, "desat": 0.25, "taille": 0.97},
	# ennemis maison (EnnemisNordiques._def_corps) : bandits de la grotte et archers bandits, plus crasseux
	"bandit":            {"sexe": "h", "age": 1, "barbe": 0.9, "rougeur": 0.6, "sale": 1.0, "desat": 0.22},
	"bandit_archer_h":   {"sexe": "h", "age": 0, "barbe": 0.7, "rougeur": 0.55, "sale": 0.95, "desat": 0.22},
	"bandit_archere":    {"sexe": "f", "age": 0, "barbe": 0.0, "rougeur": 0.55, "sale": 0.95, "desat": 0.22},
}

## Étoffes repeintes (nom du MeshInstance3D -> genre de pièce).
const ETOFFES := {"tunique": "haut", "pantalon": "bas", "mante": "mante", "cape": "cape", "capuche": "capuche", "jupe": "jupe",
		"brassards": "cuir", "bottes": "bottes", "ceinture": "cuir", "gants": "cuir"}
const CHEVEUX := ["Hair_Long", "Hair_Beard", "Hair_Buns", "Hair_SimpleParted", "Hair_Buzzed", "Hair_Long_Tied"]

static func ancien() -> bool:
	if _ancien < 0:
		_ancien = 1 if OS.get_cmdline_user_args().has("--pnj-realisme-ancien") else 0
	return _ancien == 1

static func concerne(id: String) -> bool:
	return PROFILS.has(id) and not ancien()

## Échelle du corps du PNJ (1 si non concerné) : villageois.gd l'applique au modèle (variation de stature entre individus).
static func taille(id: String) -> float:
	return float((PROFILS.get(id, {}) as Dictionary).get("taille", 1.0)) if concerne(id) else 1.0

## Repeint les matériaux du PNJ `n` (créé par PnjNordique pour `id`). Sans effet si l'id n'a pas de profil.
static func appliquer(n: Node3D, id: String) -> void:
	if not concerne(id):
		return
	var p: Dictionary = PROFILS[id]
	var graine := absi(hash(id)) % 100000
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var nom := String(mi.name)
		var genre := ""
		if nom == "peau":
			genre = "peau"
		elif ETOFFES.has(nom):
			genre = ETOFFES[nom]
		elif nom in CHEVEUX:
			genre = "barbe" if nom == "Hair_Beard" else "cheveux"
		if genre == "":
			if nom == "accessoires" or nom.begins_with("@") or nom in ["arc_porte", "jupe_bl", "cape_bl"]:
				for s in mi.mesh.get_surface_count():
					var tb := (mi.get_active_material(s) as ShaderMaterial).get_shader_parameter("tex_base") as Texture2D if mi.get_active_material(s) is ShaderMaterial else null
					if nom == "accessoires" and s == 0 and tb != null and tb.get_width() >= 256:
						_repeindre(mi, s, "yeux", p, graine, "%s_%s_%d" % [id, nom, s])     # atlas des accessoires : yeux en amande (cartes R_OEIL)
					elif nom == "accessoires" and s == 1:
						_regler(mi, s, {"saturation": SAT_ACCESSOIRES, "teinte": FOURRURE})     # cartes découpées : fourrure, mèches (moins blanc plastique)
					else:
						_regler(mi, s, {"saturation": SAT_ACCESSOIRES})     # pièces modelées (tresses, ceintures, plastron) : un peu ternies
			continue
		for s in mi.mesh.get_surface_count():
			var tb0 := (mi.get_active_material(s) as ShaderMaterial).get_shader_parameter("tex_base") as Texture2D if mi.get_active_material(s) is ShaderMaterial else null
			if genre in ["cheveux", "barbe"] and tb0 != null and tb0.get_width() * tb0.get_height() > 128 * 128:
				# grande texture de chevelure (mage) : pas repeinte (ni copiée sur disque), seulement ternie
				_regler(mi, s, {"saturation": float(SAT[genre]), "teinte": Color(VAL_CHEVEUX, VAL_CHEVEUX * 0.97, VAL_CHEVEUX * 0.97)})
				continue
			var t0 := Time.get_ticks_usec()
			_repeindre(mi, s, genre, p, graine + s * 17 + nom.length() * 31, "%s_%s_%d" % [id, nom, s])
			if chrono:
				print("RealismePnj %s %s s%d : %.0f ms" % [id, nom, s, (Time.get_ticks_usec() - t0) / 1000.0])
	n.set_meta("realisme_pnj", id)

## Saturation (uniforme `saturation` du shader ps1_perso, multipliée) par genre de pièce : peau moins orangée « poupée », cheveux
## moins vifs (roux orange vif, blond paille), étoffes et cuirs passés.
const SAT := {"peau": 0.78, "cheveux": 0.62, "barbe": 0.66, "etoffe": 0.70, "yeux": 0.82}
const SAT_ACCESSOIRES := 0.82
## Fourrures et mèches découpées (surface 1 des accessoires) : gris-brun un peu plus sombre (le blanc pur faisait « plastique » au soleil).
const FOURRURE := Color(0.84, 0.82, 0.80)
## Cheveux légèrement assombris (les aplats clairs font « casque » au soleil).
const VAL_CHEVEUX := 0.86

## Duplique le matériau de la surface et en multiplie les paramètres numériques / couleur (clés de `reglages`).
static func _regler(mi: MeshInstance3D, s: int, reglages: Dictionary) -> void:
	var m := mi.get_active_material(s) as ShaderMaterial
	if m == null:
		return
	var m2 := m.duplicate() as ShaderMaterial
	_appliquer_reglages(m, m2, reglages)
	if m.next_pass != null:
		m2.next_pass = m.next_pass
	Palette.suivre(m2)
	if mi.material_override == m:
		mi.material_override = m2
	else:
		mi.set_surface_override_material(s, m2)

static func _appliquer_reglages(m: ShaderMaterial, m2: ShaderMaterial, reglages: Dictionary) -> void:
	for k: String in reglages:
		var v = m.get_shader_parameter(k)
		if k == "saturation":
			m2.set_shader_parameter(k, (float(v) if v != null else 1.0) * float(reglages[k]))
		elif k == "teinte":
			var c: Color = v if v is Color else Color.WHITE
			var f: Color = reglages[k]
			m2.set_shader_parameter(k, Color(c.r * f.r, c.g * f.g, c.b * f.b, c.a))

static var _cache_tex := {}
static var _mx := Mutex.new()

## Visage seul (gardes maison : corps du Gardien sous l'armure validée, seul le visage se voit). Profil tiré des données du garde
## (poil gris = âgé, rasé = barbe naissante plus marquée) ; images en cache par profil (14 gardes, 5 ou 6 visages différents).
static func appliquer_visage_garde(n: Node3D, g: Dictionary) -> void:
	if ancien():
		return
	var ip := int(g.get("poil", 0))
	var p := {"sexe": "h", "age": 2 if ip == 4 else (1 if ip in [0, 3, 5] else 0), "barbe": 0.8 if g.get("rase", false) else 0.45,
			"rougeur": 0.55 + 0.1 * (ip % 3)}
	var mi := n.find_child("peau", true, false) as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		_repeindre(mi, s, "peau", p, 7000 + ip * 13 + int(g.get("peau", 0)), "garde_%d_%d_%d_%d" % [ip, int(g.get("peau", 0)), 1 if g.get("rase", false) else 0, s], true)
	n.set_meta("realisme_pnj", "garde_maison")

## Repeint la surface `s` de `mi` (copie du matériau). `cle` : nom de l'image précalculée (assets/pnj/realisme/<cle>.res, relue si
## sa version et l'empreinte de l'image source correspondent ; sinon recalculée, et écrite si `enregistrer`) ; `partage` : texture
## partagée en mémoire entre PNJ de même clé (gardes).
static func _repeindre(mi: MeshInstance3D, s: int, genre: String, p: Dictionary, graine: int, cle: String, partage := false) -> void:
	var m := mi.get_active_material(s) as ShaderMaterial
	if m == null:
		return
	var t := m.get_shader_parameter("tex_base") as Texture2D
	if t == null:
		return
	var tex: Texture2D = null
	var cle_m := "%s|%s" % [cle, t.get_rid()]
	if partage:
		_mx.lock()
		tex = _cache_tex.get(cle_m)
		_mx.unlock()
	if tex == null:
		var img := t.get_image()
		if img == null:
			return
		img = img.duplicate() as Image
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		var empreinte := hash(img.get_data())
		var chemin := "%s/%s.res" % [DOSSIER, cle]
		var pret: Image = null
		if ResourceLoader.exists(chemin):
			var lu := ResourceLoader.load(chemin) as Image
			if lu != null and lu.get_meta("version", -1) == VERSION and lu.get_meta("source", 0) == empreinte:
				pret = lu
		if pret == null:
			match genre:
				"peau":
					VisagePnj.peindre(img, p, graine)
				"yeux":
					_yeux(img, graine)
				"cheveux", "barbe":
					_meches(img, graine, genre == "barbe")
				_:
					_usure(img, genre, p, graine)
			pret = GuerrierTextures.mips_pixel(img) if genre != "peau" else _mips(img)
			if enregistrer:
				pret.set_meta("version", VERSION)
				pret.set_meta("source", empreinte)
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
				ResourceSaver.save(pret, chemin, ResourceSaver.FLAG_COMPRESS)
		tex = ImageTexture.create_from_image(pret)
		if partage:
			_mx.lock()
			_cache_tex[cle_m] = tex
			_mx.unlock()
	var m2 := m.duplicate() as ShaderMaterial
	var reg := {"saturation": float(SAT.get(genre, SAT["etoffe"]))}
	if genre == "cheveux" or genre == "barbe":
		reg["teinte"] = Color(VAL_CHEVEUX, VAL_CHEVEUX * 0.97, VAL_CHEVEUX * 0.97)
	elif genre == "peau":
		reg["teinte"] = Color(0.96, 0.94, 0.95)
	_appliquer_reglages(m, m2, reg)
	m2.set_shader_parameter("tex_base", tex)
	if m2.get_shader_parameter("tex_neige") is Texture2D:
		m2.set_shader_parameter("tex_neige", tex)
	if m.next_pass != null:
		m2.next_pass = m.next_pass
	Palette.suivre(m2)
	if mi.material_override == m:
		mi.material_override = m2
	else:
		mi.set_surface_override_material(s, m2)

static func _mips(img: Image) -> Image:
	var c := img.duplicate() as Image
	c.generate_mipmaps()
	return c

# ------------------------------------------------------------------------------------------------ bruit
static func _h(x: int, y: int, g: int) -> float:
	var v := (x * 374761393 + y * 668265263 + g * 2147483647) & 0x7fffffff
	v = ((v ^ (v >> 13)) * 1274126177) & 0x7fffffff
	return float(v & 0xffff) / 65535.0

## Bruit de valeurs périodique (w x h pixels, cx x cy cellules).
static func bruit(x: int, y: int, w: int, h: int, cx: int, cy: int, g: int) -> float:
	var fx := float(x) / w * cx
	var fy := float(y) / h * cy
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _h(posmod(ix, cx), posmod(iy, cy), g)
	var b := _h(posmod(ix + 1, cx), posmod(iy, cy), g)
	var c := _h(posmod(ix, cx), posmod(iy + 1, cy), g)
	var d := _h(posmod(ix + 1, cx), posmod(iy + 1, cy), g)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)

static func _vers_nordique(c: Color, desat: float) -> Color:
	var l := c.get_luminance()
	# désaturation vers un gris légèrement brun-froid (laine, cuir passés) ; la valeur est gardée
	var gris := Color(l * 1.02, l * 1.0, l * 0.97)
	return Color(lerpf(c.r, gris.r, desat), lerpf(c.g, gris.g, desat), lerpf(c.b, gris.b, desat), c.a)

# ------------------------------------------------------------------------------------------------ étoffes
## Usure d'une étoffe (UV métriques du lot 4 : u = tour du corps, v vers le BAS = ourlet). Alpha gardé (ourlets effilochés).
static func _usure(img: Image, genre: String, p: Dictionary, g: int) -> void:
	var W := img.get_width()
	var H := img.get_height()
	var sale := float(p.get("sale", 0.6))
	var desat := float(p.get("desat", 0.2))
	var boue := Color(0.20, 0.16, 0.12)
	# champs de bruit lisses : petites grilles aléatoires agrandies en bilinéaire (natif, rapide)
	var nb := _champ(W, H, 6, 3, g + 11)
	var nt := _champ(W, H, 14, 7, g + 13)
	var nr := _champ(W, H, 9, 5, g + 17)
	var nbo := _champ(W, H, 24, 6, g + 19)
	var bas0 := {"bas": 0.70, "bottes": 0.45, "jupe": 0.72, "cape": 0.78, "mante": 0.85, "haut": 0.86, "capuche": 0.9}.get(genre, 0.9) as float
	var seuil_t := 0.80 - 0.06 * sale
	for y in H:
		var v := float(y) / H
		for x in W:
			var c := img.get_pixel(x, y)
			if c.a < 0.05:
				continue
			c = _vers_nordique(c, desat)
			var f := 1.0 + (_h(x, y, g + 5) - 0.5) * 0.07           # grain du tissu / cuir (jamais de damier)
			f -= (nb.get_pixel(x, y).r - 0.5) * 0.16 * sale           # salissure en grandes plages
			var vt := nt.get_pixel(x, y).r
			if vt > seuil_t:
				f -= 0.13 * smoothstep(seuil_t, seuil_t + 0.12, vt)  # taches
			var vr := nr.get_pixel(x, y).r
			if vr > 0.70 and genre != "bottes":                        # zones râpées : plus claires et ternes
				var k := smoothstep(0.70, 0.85, vr)
				f += 0.10 * k
				c = _vers_nordique(c, 0.25 * k)
			if v > bas0:                                              # ourlet : assombri, boue
				var t := (v - bas0) / (1.0 - bas0)
				var kb := clampf(t * t * (0.5 + nbo.get_pixel(x, y).r) * sale * 1.25, 0.0, 0.85)
				c = c.lerp(Color(boue.r, boue.g, boue.b, c.a), kb * 0.75)
				f -= 0.18 * t * sale
			elif v > bas0 - 0.18 and _h(x, y, g + 23) > 0.985 - 0.01 * sale:
				c = c.lerp(Color(boue.r, boue.g, boue.b, c.a), 0.6)      # éclaboussures au-dessus de l'ourlet
			f = clampf(f, 0.45, 1.3)
			img.set_pixel(x, y, Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a))
	# plis : lignes verticales ondulées (ombre d'un texel, rehaut à côté), tracées le long de chaque pli
	var nplis := {"haut": 9, "bas": 7, "mante": 6, "cape": 10, "capuche": 5, "jupe": 12, "cuir": 3, "bottes": 4}.get(genre, 5) as int
	for k in nplis:
		var x0 := _h(k, 1, g) * W
		var y0 := int((_h(k, 2, g) * 0.55 + (0.1 if genre in ["haut", "bas", "cuir"] else 0.0)) * H)
		var amp := 1.5 + _h(k, 3, g) * 3.0
		var fr := 0.5 + _h(k, 4, g)
		for y in range(y0, H):
			var fondu := clampf(float(y - y0) / 12.0, 0.0, 1.0)
			var xp := posmod(int(roundf(x0 + sin(float(y) * 0.11 * fr + x0) * amp)), W)
			_mul_px(img, xp, y, 1.0 - 0.20 * fondu)
			_mul_px(img, (xp + 1) % W, y, 1.0 + 0.07 * fondu)

static func _mul_px(img: Image, x: int, y: int, f: float) -> void:
	var c := img.get_pixel(x, y)
	if c.a < 0.05:
		return
	img.set_pixel(x, y, Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a))

## Bruit lisse W x H : grille cx x cy de valeurs aléatoires, périodique, agrandie en bilinéaire.
static func _champ(W: int, H: int, cx: int, cy: int, g: int) -> Image:
	var petit := Image.create(cx + 1, cy + 1, false, Image.FORMAT_L8)
	for y in cy + 1:
		for x in cx + 1:
			var v := _h(x % cx, y % cy, g)
			petit.set_pixel(x, y, Color(v, v, v))
	petit.resize(W + W / cx, H + H / cy, Image.INTERPOLATE_BILINEAR)
	return petit.get_region(Rect2i(W / cx / 2, H / cy / 2, W, H))

# ------------------------------------------------------------------------------------------------ yeux
## Teintes d'iris (ternes) : gris-bleu, gris, brun, vert-gris, bleu sombre.
const IRIS := [Color("#4c5f72"), Color("#5a5d5e"), Color("#4a3a2c"), Color("#50583f"), Color("#3c4c66")]

## Œil des cartes R_OEIL (16 x 8 de l'atlas des accessoires) : fente en amande (paupière haute lourde qui couvre le haut de l'iris,
## paupière basse), blanc terne et rosé aux coins, iris plus petit et sombre, pupille, reflet d'un texel. Remplace l'œil rond grand
## ouvert « poupée » (et l'iris teinté avec la bande des habitants, qui virait au rouge).
static func _yeux(img: Image, g: int) -> void:
	var r := GuerrierTextures.R_OEIL
	if r.end.x > img.get_width() or r.end.y > img.get_height():
		return
	var iris: Color = IRIS[g % IRIS.size()]
	var peau := Color("#3a2a24")
	for y in r.size.y:
		for x in r.size.x:
			var dx := (x + 0.5 - 8.0) / 8.0
			# amande : demi-hauteur 3,4 texels au centre, nulle aux coins ; le haut plus bas (paupière)
			var demi := 3.4 * (1.0 - dx * dx)
			var haut := 4.0 - demi * 0.80
			var bas := 4.0 + demi * 0.95
			var yc := y + 0.5
			var c := peau
			if yc > haut and yc < bas:
				c = Color("#8d857a") if absf(dx) < 0.55 else Color("#76665c")
				var di := Vector2(x + 0.5 - 8.0, (yc - 4.3) * 1.15).length()
				if di < 2.5:
					c = iris if di > 1.0 else Color("#0e0c0b")
					if di > 1.0 and x == 7 and y == 3:
						c = iris.lightened(0.35)              # reflet
				if yc < haut + 1.0:
					c = c.darkened(0.40)                      # ombre portée de la paupière
			elif yc <= haut and yc > haut - 1.2:
				c = Color("#1e1512")                          # ligne de cils / pli de paupière
			img.set_pixel(r.position.x + x, r.position.y + y, c)

# ------------------------------------------------------------------------------------------------ cheveux
## Mèches : sillons sombres et reflets le long des brins (axe v de l'atlas Quaternius des coupes), variations de teinte par mèche.
static func _meches(img: Image, g: int, barbe: bool) -> void:
	var W := img.get_width()
	var H := img.get_height()
	for y in H:
		for x in W:
			var c := img.get_pixel(x, y)
			if c.a < 0.05:
				continue
			# une mèche = une bande de 2-3 texels en u, ondulant doucement en v
			var u := float(x) + sin(float(y) * 0.35 + _h(x / 3, 0, g) * 6.0) * 0.8
			var bande := bruit(int(u * 8.0), y, W * 8, H, W / 2, 3, g)
			var fil := _h(int(u), y / 3, g + 3)
			var f := 0.78 + bande * 0.38
			if fil < 0.22:
				f -= 0.20            # sillon entre deux mèches
			elif fil > 0.90:
				f += 0.14            # brin qui accroche la lumière
			if barbe:
				f += (_h(x, y, g + 9) - 0.5) * 0.18
			var l := c.get_luminance()
			var cc := Color(lerpf(c.r, l, 0.12), lerpf(c.g, l, 0.12), lerpf(c.b, l, 0.12), c.a)
			img.set_pixel(x, y, Color(clampf(cc.r * f, 0, 1), clampf(cc.g * f, 0, 1), clampf(cc.b * f, 0, 1), c.a))
