class_name AvantBras
## Matières des avant-bras FPS « runes » (bras_fps.glb, sources_blender/scripts/avant_bras_runes.py ; références
## Jeux/references/avant_bras_magie/bras_*_1100.jpg). Modèle COMMUN à tous les équipements (épée, torche, bouclier, sorts,
## main vide) : mains.gd les pose par nom de matière Blender (ab_*). Textures peintes au pixel (64², plus proche voisin),
## pas de tramage : bruit de valeur seulement. Les creux et les pointes claires viennent des couleurs de sommet.

const T := 64
## Calque de rendu 18 : les maillages des avant-bras (mains.gd). Les auras des mains ne l'éclairent pas (lumière de 4 m
## posée dans la paume : bras brûlés à blanc) ; la lueur courte de RunesOrbite l'éclaire à la place.
const CALQUE := 1 << 17
static var _mats := {}

static func materiaux() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	_mats = {
		"ab_gant": Palette.materiau(_tex("gant"), Vector2(1, 1), Color(0.84, 0.8, 0.77), true),   # cuir brun moyen (v8b : doigts lisibles, plus clair que le brassard ; avant : cuir sombre 2026-10-29)
		"ab_cuir": Palette.materiau(_tex("cuir"), Vector2(1, 1), Color(0.95, 0.9, 0.86), true),
		"ab_tresse": Palette.materiau(_tex("tresse"), Vector2(1, 1), Color(0.95, 0.9, 0.86), true),
		"ab_metal": Palette.materiau(_tex("metal"), Vector2(1, 1), Color(0.7, 0.7, 0.74), true),
		"ab_fer": Palette.materiau(_tex("fer"), Vector2(1, 1), Color(0.85, 0.85, 0.88), true),
		"ab_sangle": Palette.materiau(_tex("sangle"), Vector2(1, 1), Color(0.8, 0.76, 0.74), true),
		"ab_fourrure": Palette.materiau(_tex("fourrure"), Vector2(1, 1), Color(0.8, 0.79, 0.78), true),
	}
	return _mats

static var _textures := {}

static func _tex(nom: String) -> ImageTexture:
	if not _textures.has(nom):
		_textures[nom] = ImageTexture.create_from_image(peindre(nom))
	return _textures[nom]

# ------------------------------------------------------------------ bruit (valeur, périodique sur la tuile)
static func _h(x: int, y: int, g: int) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (g * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0

## Bruit de valeur lissé, périodique de période `p` (diviseur de T) : la texture se raccorde.
static func _bruit(x: float, y: float, p: int, g: int) -> float:
	var s := float(T) / p
	var fx := x / s
	var fy := y / s
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - x0
	var ty := fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _h(posmod(x0, p), posmod(y0, p), g)
	var b := _h(posmod(x0 + 1, p), posmod(y0, p), g)
	var c := _h(posmod(x0, p), posmod(y0 + 1, p), g)
	var d := _h(posmod(x0 + 1, p), posmod(y0 + 1, p), g)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)

static func _fbm(x: float, y: float, g: int) -> float:
	return _bruit(x, y, 4, g) * 0.5 + _bruit(x, y, 8, g + 1) * 0.3 + _bruit(x, y, 16, g + 2) * 0.2

## Rampe de couleurs (k 0..1) quantifiée en `pas` tons : pixel art, pas de dégradé continu.
static func _rampe(cols: Array, k: float, pas := 6) -> Color:
	k = clampf(round(clampf(k, 0.0, 1.0) * (pas - 1)) / (pas - 1), 0.0, 1.0)
	var f := k * (cols.size() - 1)
	var i := mini(int(f), cols.size() - 2)
	return (cols[i] as Color).lerp(cols[i + 1], f - i)

const GANT := [Color("#211710"), Color("#38291d"), Color("#523d2c"), Color("#6d543f"), Color("#8b6e55")]   # v8b : cuir brun moyen, peu saturé
const CUIR := [Color("#1a120d"), Color("#2c1f17"), Color("#3f2d22"), Color("#56412f"), Color("#705742")]   # passe 4 : plus clair, lisible dans le coin bas
const FER := [Color("#1d1c1c"), Color("#3a3836"), Color("#5a5652"), Color("#7e7872"), Color("#a7a098")]
const FOURRURE := [Color("#3e3a37"), Color("#6c6762"), Color("#98928b"), Color("#c4beb6"), Color("#e8e4dd")]
const FIL := Color("#7a6248")

static func peindre(nom: String) -> Image:
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	for y in T:
		for x in T:
			img.set_pixel(x, y, _pixel(nom, x, y))
	return img

static func _pixel(nom: String, x: int, y: int) -> Color:
	match nom:
		"gant":
			# cuir de gant noir-brun : grain fin, plis clairs usés, quelques éraflures
			var k := _fbm(x, y, 3) * 0.75 + _h(x, y, 5) * 0.18
			var pli := absf(_bruit(x * 1.0, y * 2.0, 8, 11) - 0.5)
			if pli < 0.035:
				k += 0.22
			if _h(x, y, 7) > 0.985:
				k += 0.35
			return _rampe(GANT, k - 0.05)
		"cuir":
			# coque du brassard : cuir épais sombre, couture claire le long des deux bords (v = 0 et v = 1 de la tuile)
			var k := _fbm(x, y, 21) * 0.8 + _h(x, y, 22) * 0.15
			if y < 2 or y > T - 3:
				return _rampe(CUIR, 0.05)
			if (y == 4 or y == T - 5) and x % 4 < 2:
				return FIL
			if y == 5 or y == T - 4:
				k -= 0.2
			return _rampe(CUIR, k)
		"tresse":
			# lanière tressée : chevrons de brins (u le long du tour, v autour de la section), rangs de perles de fer aux bords
			var v := float(y) / T
			var bord := absf(v - 0.25) < 0.035 or absf(v - 0.75) < 0.035
			if bord and x % 5 < 2:
				return _rampe(FER, 0.55 + 0.35 * _h(x, y, 31))
			var brin := fposmod((x + absf(y - T * 0.5) * 0.9) / 7.0, 1.0)
			var k := 0.30 + 0.45 * sin(brin * PI) + (_fbm(x, y, 33) - 0.5) * 0.35
			if brin < 0.12:
				k = 0.05
			if absf(v - 0.5) > 0.38:
				k *= 0.6
			return _rampe(CUIR, k)
		"metal":
			# plaque nordique : cadre en relief, entrelacs (deux bandes qui se croisent) et losange runique gravés,
			# fond piqué plus sombre, usure claire sur les arêtes
			var u := (x + 0.5) / T
			var v := (y + 0.5) / T
			var usure := _fbm(x, y, 41)
			var cadre := u < 0.08 or u > 0.92 or v < 0.08 or v > 0.92
			if cadre:
				var arete := u < 0.03 or u > 0.97 or v < 0.03 or v > 0.97
				return _rampe(FER, (0.85 if arete else 0.62) + (usure - 0.5) * 0.3)
			if u < 0.11 or u > 0.89 or v < 0.11 or v > 0.89:
				return _rampe(FER, 0.12)
			var fond := 0.30 + (usure - 0.5) * 0.25 + (0.12 if _h(x, y, 43) > 0.9 else 0.0)
			var meilleur := 9.0
			var dessus := -1
			for s: float in [-1.0, 1.0]:
				var c: float = 0.5 + s * 0.22 * sin((v - 0.11) / 0.78 * TAU * 1.5)
				var d := absf(u - c)
				if d < meilleur:
					meilleur = d
					# entrelacs : au croisement, la bande du dessus alterne
					dessus = 0 if s < 0.0 else 1
			var croise := int(floor((v - 0.11) / 0.78 * 3.0 + 0.5))
			var largeur := 0.065
			# losange runique au centre de chaque boucle
			var lv := fposmod((v - 0.11) / 0.78 * 3.0, 1.0)
			var los := absf(u - 0.5) / 0.13 + absf(lv - 0.5) / 0.32
			if meilleur < largeur:
				if meilleur > largeur - 0.022:
					return _rampe(FER, 0.08)          # trait de gravure qui borde la bande
				var masque := (croise + dessus) % 2 == 0 and absf(lv - 0.0) < 0.06
				return _rampe(FER, (0.25 if masque else 0.7) + (usure - 0.5) * 0.3)
			if los > 0.8 and los < 1.0:
				return _rampe(FER, 0.72)
			if los < 0.45 and (absf(u - 0.5) < 0.012 or absf(lv - 0.5) < 0.02):
				return _rampe(FER, 0.08)              # rune (croix) gravée dans le losange
			return _rampe(FER, fond)
		"fer":
			var k := 0.45 + (_fbm(x, y, 51) - 0.5) * 0.5 + (0.2 if _h(x, y, 52) > 0.93 else 0.0)
			return _rampe(FER, k)
		"sangle":
			# sangle de cuir plus sombre, double piqûre claire (v = 0,2 et 0,8), bords rognés
			var v := float(y) / T
			if v < 0.06 or v > 0.94:
				return _rampe(CUIR, 0.0)
			if (absf(v - 0.2) < 0.02 or absf(v - 0.8) < 0.02) and x % 4 < 2:
				return FIL.darkened(0.15)
			return _rampe(CUIR, 0.15 + (_fbm(x, y, 61) - 0.5) * 0.4 + _h(x, y, 62) * 0.1)
		"fourrure":
			# mèches grises et blanches : stries le long de v (pied sombre -> pointe claire), mèches de teintes différentes
			var v := float(y) / T
			var meche := int(x / 3)
			var clair := _h(meche, 0, 71)
			var strie := _h(x, int(y / 6), 72)
			var k := 0.15 + 0.55 * v + 0.35 * (clair - 0.4) + (strie - 0.5) * 0.25
			if x % 3 == 0:
				k -= 0.15
			return _rampe(FOURRURE, k, 7)
	return Color.MAGENTA

# ------------------------------------------------------------------ fondu près de l'œil (combat/bras_vide_1p, 2026-11-26)
## Ce que font les jeux en vue 1re personne : un bras qui passe tout contre l'œil (contre-attaque : il balaie la vue
## pendant 2 images) s'efface en TRAME 4x4 (même grain que le tramage PS1). Le fondu est UNIFORME par bras (paramètre
## d'instance `fondu_bras`, calculé ici depuis la distance de ses os à la caméra), pas par pixel : la trame retire alors
## les mêmes pixels à toutes les couches du bras (manche, doublure, brassard), on ne voit donc jamais son intérieur.
## Plein au-delà de FONDU_LOIN de l'œil (surface du bras), effacé à FONDU_PRES. Variante des shaders des bras seulement
## (le `discard` ne touche pas les autres matériaux du monde).
const FONDU_PRES := 0.12
const FONDU_LOIN := 0.29   # surface : os à 0,36 m (les coups ordinaires restent au-delà, 0,36 m au plus près ; contre : 0,24)
const RAYON_BRAS := 0.07   # des os à la surface de la manche / du brassard
const _CODE_FONDU := """
instance uniform float fondu_bras = 1.0;
const float TRAME_OEIL[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
void fragment() {
	if (fondu_bras < 0.999) {
		ivec2 q_oeil = ivec2(FRAGCOORD.xy) % 4;
		if (fondu_bras < (TRAME_OEIL[q_oeil.y * 4 + q_oeil.x] + 0.5) / 16.0) {
			discard;
		}
	}
"""
static var _variantes := {}   # Shader -> même shader avec le fondu
static var _deja := {}        # matière d'origine -> sa copie à fondu (partagée entre les bras)

static func shader_fondu(sh: Shader) -> Shader:
	if not _variantes.has(sh):
		var v := Shader.new()
		v.code = sh.code.replace("void fragment() {", _CODE_FONDU)
		_variantes[sh] = v
	return _variantes[sh]

## Passe les matières des maillages skinnés de `racine` (bras 1P) sur la variante à fondu ; à rappeler après un
## changement de matières (ArmureVisible repose ses gants) : les matières déjà converties sont reconnues et sautées.
static func appliquer_fondu(racine: Node) -> void:
	if racine == null:
		return
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.mesh == null or mi.get_meta("det_bras", false):
			continue   # armes et objets tenus (sans peau), copies de l'audit : pas de fondu
		for k in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(k) as ShaderMaterial
			if m == null:
				m = mi.mesh.surface_get_material(k) as ShaderMaterial
			if m == null or m.shader == null or m.has_meta("fondu_oeil") or m.shader.code.contains("fondu_bras"):
				continue
			if not _deja.has(m):
				var m2 := m.duplicate() as ShaderMaterial
				m2.shader = shader_fondu(m.shader)
				m2.set_meta("fondu_oeil", true)
				Palette.suivre(m2)   # suit le réglage ps1 (grille, affine) comme l'original
				_deja[m] = m2
			mi.set_surface_override_material(k, _deja[m])

## Opacité (0-1) du bras `cote` ("l"/"r") : distance de la caméra au segment milieu du bras -> main, moins RAYON_BRAS.
static func opacite(sq: Skeleton3D, cam: Camera3D, cote: String) -> float:
	var ids := [sq.find_bone("upperarm_" + cote), sq.find_bone("lowerarm_" + cote), sq.find_bone("hand_" + cote)]
	if ids.has(-1):
		return 1.0
	var p: Array[Vector3] = []
	for i: int in ids:
		p.append(sq.global_transform * sq.get_bone_global_pose(i).origin)
	var o := cam.global_position
	var d := INF
	for k in 11:
		var t := k / 10.0
		var q: Vector3 = p[0].lerp(p[1], 0.3 + 1.4 * t) if t < 0.5 else p[1].lerp(p[2], (t - 0.5) * 2.0)
		d = minf(d, o.distance_to(q))
	sq.set_meta("d_os_" + cote, d)   # distance caméra -> os du bras (audit)
	return clampf((d - RAYON_BRAS - FONDU_PRES) / (FONDU_LOIN - FONDU_PRES), 0.0, 1.0)

## Installe le fondu sur le squelette des bras : modificateur ajouté EN DERNIER (scripts/combat/fondu_bras.gd).
static func installer_fondu(racine: Node, sq: Skeleton3D) -> void:
	var f := SkeletonModifier3D.new()
	f.set_script(preload("res://scripts/combat/fondu_bras.gd"))
	f.set("racine", racine)
	f.name = "FonduBras"
	sq.add_child(f)

## Pose l'opacité de chaque bras sur ses maillages (avant_bras_l/_r, manche_l/_r).
static func regler_fondu(racine: Node, cam: Camera3D) -> void:
	if racine == null or cam == null:
		return
	var sq: Skeleton3D = racine.find_child("Skeleton3D", true, false)
	if sq == null:
		return
	var a := {"l": opacite(sq, cam, "l"), "r": opacite(sq, cam, "r")}
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.get_meta("det_bras", false):
			continue
		var n := String(mi.name)
		var c := "l" if (n.ends_with("_l") or n.contains("_l_")) else ("r" if (n.ends_with("_r") or n.contains("_r_")) else "")
		if c != "" and absf(float(mi.get_meta("fondu_bras", 1.0)) - a[c]) > 0.001:
			mi.set_meta("fondu_bras", a[c])   # dernière valeur posée (lue sans synchroniser le serveur de rendu)
			mi.set_instance_shader_parameter("fondu_bras", a[c])
