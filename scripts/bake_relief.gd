class_name BakeRelief
## Relief CUIT par Blender (sources_blender/scripts/bake_persos.py : AO large + AO fine + courbure, Cycles, sans fenêtre),
## QUANTIFIÉ dans la palette de la texture : pas de normal map, pas de tramage, pas de dégradé — seulement des aplats.
## Le masque (PNG en niveaux de gris, même taille que la texture, ligne 0 = haut) code, par texel :
##   0 neutre (ou texel partagé par plusieurs pièces : jamais cuit) · 64 ombre · 128 creux · 192 arête claire.
## Un texel marqué prend, parmi les couleurs DÉJÀ présentes dans la texture, la plus proche de « sa couleur assombrie (ou
## éclaircie) » ; sans candidat assez proche (contour sombre, blanc pur…), il garde sa couleur. L'alpha n'est jamais touché.

const FACTEURS := [1.0, 0.82, 0.64, 1.0]      # multiplicateur de cible : neutre, ombre, creux, (arête : voir ECLAIRCIR)
const ECLAIRCIR := 1.20
const ECART_LUM := 0.025                      # écart de luminance minimal entre l'ancien et le nouveau ton
const PORTEE := 0.16                          # distance RVB maximale entre la cible et le ton retenu

static func masque(chemin: String) -> Image:
	var abs_chemin := ProjectSettings.globalize_path(chemin)
	if not FileAccess.file_exists(abs_chemin):
		return null
	var m := Image.load_from_file(abs_chemin)
	if m == null:
		return null
	m.convert(Image.FORMAT_L8)
	return m

## Applique le masque de niveaux à `img` (RGBA8) ; renvoie le nombre de texels modifiés dans `stats` si fourni.
static func appliquer(img: Image, chemin_masque: String, force := 1.0, stats := {}) -> Image:
	var m := masque(chemin_masque)
	if m == null:
		return img
	if m.get_size() != img.get_size():
		m.resize(img.get_width(), img.get_height(), Image.INTERPOLATE_NEAREST)
	var w := img.get_width()
	var h := img.get_height()
	# palette = couleurs opaques déjà présentes
	var pal := {}
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				pal[Color(c.r, c.g, c.b, 1.0)] = true
	var tons: Array = pal.keys()
	var lums := PackedFloat32Array()
	for t: Color in tons:
		lums.append(t.get_luminance())
	var cache := {}
	var n := [0, 0, 0, 0]
	for y in h:
		for x in w:
			var niv := int(roundf(m.get_pixel(x, y).r * 255.0 / 64.0))
			if niv <= 0 or niv > 3:
				continue
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var cle := Color(c.r, c.g, c.b, float(niv))
			if not cache.has(cle):
				cache[cle] = _voisin(Color(c.r, c.g, c.b, 1.0), niv, force, tons, lums)
			var r: Color = cache[cle]
			if r != Color(c.r, c.g, c.b, 1.0):
				img.set_pixel(x, y, Color(r.r, r.g, r.b, c.a))
				n[niv] += 1
	stats["texels"] = n
	stats["tons"] = tons.size()
	return img

static func _voisin(c: Color, niv: int, force: float, tons: Array, lums: PackedFloat32Array) -> Color:
	var cible: Color
	var l0 := c.get_luminance()
	if niv == 3:
		var f := 1.0 + (ECLAIRCIR - 1.0) * force
		cible = Color(minf(c.r * f + 0.02, 1.0), minf(c.g * f + 0.02, 1.0), minf(c.b * f + 0.02, 1.0))
	else:
		var f := 1.0 - (1.0 - float(FACTEURS[niv])) * force
		cible = Color(c.r * f, c.g * f, c.b * f)
	var meilleur := c
	var dmin := PORTEE * PORTEE
	for k in tons.size():
		var t: Color = tons[k]
		if niv == 3:
			if lums[k] < l0 + ECART_LUM:
				continue
		elif lums[k] > l0 - ECART_LUM:
			continue
		var d := (t.r - cible.r) * (t.r - cible.r) + (t.g - cible.g) * (t.g - cible.g) + (t.b - cible.b) * (t.b - cible.b)
		if d < dmin:
			dmin = d
			meilleur = t
	return meilleur
