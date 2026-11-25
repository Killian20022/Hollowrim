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
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as ShaderMaterial
			if m == null:
				continue
			var t := m.get_shader_parameter("tex_base") as Texture2D
			if t == null:
				continue
			var img := t.get_image()
			if img == null:
				continue
			img = img.duplicate() as Image
			if img.is_compressed():
				img.decompress()
			img.clear_mipmaps()
			img.convert(Image.FORMAT_RGBA8)
			match genre:
				"peau":
					VisagePnj.peindre(img, p, graine)
				"cheveux", "barbe":
					_meches(img, graine + s, genre == "barbe")
				_:
					_usure(img, genre, p, graine + s * 17 + nom.length() * 31)
			var nouvelle := GuerrierTextures.mips_pixel(img) if genre != "peau" else _mips(img)
			var tex := ImageTexture.create_from_image(nouvelle)
			var m2 := m.duplicate() as ShaderMaterial
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
	n.set_meta("realisme_pnj", id)

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
	# plis : lignes verticales ondulées (étoffes souples), plus nombreux sur jupe, cape, mante
	var nplis := {"haut": 9, "bas": 7, "mante": 6, "cape": 10, "capuche": 5, "jupe": 12, "cuir": 3, "bottes": 4}.get(genre, 5) as int
	var plis: Array = []
	for k in nplis:
		var x0 := int(_h(k, 1, g) * W)
		var y0 := int((_h(k, 2, g) * 0.55 + (0.1 if genre in ["haut", "bas", "cuir"] else 0.0)) * H)
		plis.append([x0, y0, 1.5 + _h(k, 3, g) * 3.0, 0.5 + _h(k, 4, g)])
	# ourlet crotté : fraction basse de l'image
	var bas0 := {"bas": 0.70, "bottes": 0.45, "jupe": 0.72, "cape": 0.78, "mante": 0.85, "haut": 0.86, "capuche": 0.9}.get(genre, 0.9) as float
	for y in H:
		var v := float(y) / H
		for x in W:
			var c := img.get_pixel(x, y)
			if c.a < 0.05:
				continue
			c = _vers_nordique(c, desat)
			var f := 1.0
			# grain du tissu / cuir : variation fine, jamais de damier
			f += (_h(x, y, g + 5) - 0.5) * 0.07
			# salissure diffuse en grandes plages
			var nb := bruit(x, y, W, H, 6, 3, g + 11)
			f -= (nb - 0.5) * 0.16 * sale
			# taches
			var nt := bruit(x, y, W, H, 14, 7, g + 13)
			if nt > 0.80 - 0.06 * sale:
				f -= 0.13 * smoothstep(0.78 - 0.06 * sale, 0.9, nt)
			# zones râpées, plus claires et ternes (étoffes et cuirs portés)
			var nr := bruit(x, y, W, H, 9, 5, g + 17)
			if nr > 0.76 and genre != "bottes":
				var k := smoothstep(0.76, 0.9, nr)
				f += 0.10 * k
				c = _vers_nordique(c, 0.25 * k)
			# plis
			for pl: Array in plis:
				if y < int(pl[1]):
					continue
				var amp: float = pl[2]
				var xp := float(pl[0]) + sin(float(y) * 0.11 * float(pl[3]) + float(pl[0])) * amp
				var dx := float(x) - xp
				var dw := dx if dx > -W * 0.5 else dx + W
				if dw > W * 0.5:
					dw -= W
				var fondu := clampf(float(y - int(pl[1])) / 12.0, 0.0, 1.0)
				if absf(dw) < 0.8:
					f -= 0.20 * fondu
				elif dw >= 0.8 and dw < 1.8:
					f += 0.07 * fondu
			# ourlet : assombri, boue et éclaboussures
			if v > bas0:
				var t := (v - bas0) / (1.0 - bas0)
				var nboue := bruit(x, y, W, H, 24, 6, g + 19)
				var kb := clampf(t * t * (0.5 + nboue) * sale * 1.25, 0.0, 0.85)
				c = c.lerp(Color(boue.r, boue.g, boue.b, c.a), kb * 0.75)
				f -= 0.18 * t * sale
			elif v > bas0 - 0.18 and _h(x, y, g + 23) > 0.985 - 0.01 * sale:
				c = c.lerp(Color(boue.r, boue.g, boue.b, c.a), 0.6)      # éclaboussures au-dessus de l'ourlet
			f = clampf(f, 0.45, 1.3)
			img.set_pixel(x, y, Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a))

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
