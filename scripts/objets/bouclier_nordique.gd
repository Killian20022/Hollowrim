class_name BouclierNordique
## Bouclier rond nordique du joueur (main gauche) : assets/modeles/armes/bouclier_nordique.glb (source :
## sources_blender/scripts/bouclier_nordique.py), habillé en matériaux PS1 par NOM de matériau Blender, comme
## EpeesLongues : textures pixel art dessinées ici (palettes limitées, bruit à seuil — jamais de tramage ordonné).
##
## Repère (DonneesArme) : origine au centre du poing sur la poignée centrale, +Y le long de la poignée, +X = la face peinte
## (côté des jointures : le poing est dans le creux de l'umbo). Nœuds vides : `prise`, `umbo`, `bord_haut`.
##
## Matériaux : bouclier_face (planches peintes en tourbillon rouge sang / ocre, bande sombre cloutée, peinture écaillée,
## entailles de lame), bouclier_dos (planches brutes), fer (cerclage, umbo : le fer des épées), cuir (poignée tressée).
## Texture de la face : 128 x 128 sur le disque entier (UV plane), ~190 texels/m.

const ROUGE := ["#1c0705", "#300d09", "#48150e", "#621e13", "#7c2a19", "#953a22", "#a84e2e"]
const OCRE := ["#33261a", "#4f3f28", "#6d5a38", "#8a7448", "#a68e5c", "#bea672", "#d0bb88"]
const BOIS := ["#160f08", "#251a0f", "#362716", "#4a361f", "#5e4629", "#735834", "#8a6c42", "#a08250"]
const SOMBRE := ["#0c0a08", "#16130f", "#211c17", "#2c261f", "#39322a"]
const CLOU := ["#2a2a2c", "#4a4a4e", "#707076", "#9a9aa2"]

## Bord intérieur du cerclage de fer (part du rayon) : la peinture s'arrête là.
const R_CERCLE := 0.935

static var _mats := {}

## Remplace les matériaux importés par les matériaux PS1, par nom (ombres : vue à la 3e personne).
static func habiller(racine: Node, ombres := false) -> void:
	var mats := materiaux()
	var mailles: Array = racine.find_children("*", "MeshInstance3D", true, false)
	if racine is MeshInstance3D:
		mailles.append(racine)
	for mi: MeshInstance3D in mailles:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombres else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 1.0
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var nom := m.resource_name.get_slice(".", 0) if m else ""
			if mats.has(nom):
				mi.set_surface_override_material(s, mats[nom])

static func materiaux() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	_mats = {
		"bouclier_face": Palette.materiau(ImageTexture.create_from_image(face()), Vector2.ONE, Color(1.08, 1.04, 1.0)),
		"bouclier_dos": Palette.materiau(ImageTexture.create_from_image(dos()), Vector2.ONE, Color(0.95, 0.92, 0.9)),
		"fer": Palette.materiau(ObjetsTextures.tex("fer"), Vector2.ONE, Color(0.66, 0.66, 0.72)),
		"cuir": Palette.materiau(ObjetsTextures.tex("tresse"), Vector2.ONE),
	}
	# glb de Blender : couleurs de sommet d'alpha nul, lues comme « neige » par le shader -> neige = base
	for m: ShaderMaterial in _mats.values():
		m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
	return _mats

static func _c(r: Array, l: float, x: int, y: int, j := 0.45) -> Color:
	return Color(r[ObjetsTextures._ton(l, r.size(), x, y, j)])

static func _h(x: int, y: int, g: int) -> float:
	return ObjetsTextures._h(x, y, g)

static func _fbm(x: int, y: int, w: int, h: int, cx: int, cy: int, g: int, oct := 3) -> float:
	return ObjetsTextures._fbm(x, y, w, h, cx, cy, g, oct)

## Planches : 7 planches le long de v (largeurs inégales), fibre étirée, joints sombres. Renvoie [luminosité, joint].
static func _planche(x: int, y: int, S: int) -> Array:
	var bords := [0, 17, 35, 54, 73, 92, 110, S]
	var k := 0
	while k < bords.size() - 2 and x >= bords[k + 1]:
		k += 1
	var joint: bool = x == int(bords[k]) or x == int(bords[k + 1]) - 1
	var fibre := _fbm(x * 4, y, S * 4, S, 4, 2, 31 + k, 3)
	var l := 0.42 + (_h(k, 3, 17) - 0.5) * 0.18 + (fibre - 0.5) * 0.5
	l += 0.08 * sin((float(y) / S * 3.0 + fibre * 1.8 + k) * TAU)
	return [l, joint]

## Face peinte 128 x 128 (disque entier) : tourbillon de 8 bras rouge sang / ocre, bande sombre cloutée sous le cerclage,
## écailles de peinture (bois nu), entailles de lame, crasse.
static func face() -> Image:
	var S := 128
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	# entailles : segments (u0, v0, u1, v1) en coordonnées 0..1
	var entailles := [[0.22, 0.30, 0.42, 0.18], [0.62, 0.70, 0.83, 0.58], [0.30, 0.78, 0.47, 0.86], [0.70, 0.22, 0.76, 0.40], [0.15, 0.55, 0.27, 0.62]]
	for y in S:
		for x in S:
			var u := (x + 0.5) / S
			var v := (y + 0.5) / S
			var d := Vector2(u - 0.5, v - 0.5)
			var r := d.length() * 2.0
			var p: Array = _planche(x, y, S)
			var bois_l: float = p[0]
			var crasse := _fbm(x, y, S, S, 5, 5, 71, 3)
			var c: Color
			if r >= R_CERCLE:
				c = _c(SOMBRE, 0.3, x, y)          # sous le cerclage (invisible)
			else:
				# peinture : tourbillon (bras courbés), bande sombre près du bord
				var a := atan2(d.y, d.x) + r * 1.5
				var bras := posmod(floori(a / (TAU / 8.0) + 8.0), 2)
				var lp := 0.55 + (bois_l - 0.42) * 0.55 + (crasse - 0.5) * 0.35
				var peinture: Color
				if r > 0.86:
					peinture = _c(SOMBRE, lp * 0.9 + 0.1, x, y)
				elif bras == 0:
					peinture = _c(ROUGE, lp, x, y)
				else:
					peinture = _c(OCRE, lp - 0.05, x, y)
				# liseré sombre entre les bras (coup de pinceau)
				var frac := fposmod(a / (TAU / 8.0), 1.0)
				if r <= 0.86 and (frac < 0.03 or frac > 0.97) and r > 0.26:
					peinture = _c(SOMBRE, 0.55, x, y)
				# écailles : plus nombreuses près du bord et sur la moitié basse (les coups, le sol)
				var usure := _fbm(x, y, S, S, 8, 8, 53, 3)
				var seuil := 0.70 - smoothstep(0.55, 0.93, r) * 0.16 - clampf(v - 0.5, 0.0, 0.5) * 0.12
				var nu := usure > seuil
				# entailles de lame : bois nu clair, bord sombre
				var dans_entaille := 0
				for e in entailles:
					var a0 := Vector2(e[0], e[1])
					var a1 := Vector2(e[2], e[3])
					var t := clampf((Vector2(u, v) - a0).dot(a1 - a0) / (a1 - a0).length_squared(), 0.0, 1.0)
					var dist := (Vector2(u, v) - a0.lerp(a1, t)).length() * S
					if dist < 0.7:
						dans_entaille = 2
					elif dist < 1.5 and dans_entaille == 0:
						dans_entaille = 1
				if dans_entaille == 2:
					c = _c(BOIS, bois_l + 0.32, x, y)
				elif dans_entaille == 1:
					c = _c(BOIS, bois_l - 0.22, x, y)
				elif nu:
					c = _c(BOIS, bois_l + 0.05, x, y)   # bois nu, plus clair que la peinture
				else:
					c = peinture
				if p[1] and not nu:
					c = c.darkened(0.35)                  # joints des planches sous la peinture
				elif p[1]:
					c = _c(BOIS, 0.1, x, y)
			# clous de la bande : 20 têtes de fer
			var ang := fposmod(atan2(d.y, d.x) / TAU * 20.0, 1.0)
			if absf(r - 0.9) < 0.022 and (ang < 0.09 or ang > 0.91):
				c = Color(CLOU[clampi(int((1.0 - v) * 3.0 + _h(x, y, 5) * 1.2), 0, 3)])
			img.set_pixel(x, y, c)
	return img

## Dos 64 x 64 : planches brutes (sans peinture), pointes des clous rabattues.
static func dos() -> Image:
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var p: Array = _planche(x * 2, y * 2, 128)
			var l: float = p[0] - 0.08
			var c := _c(BOIS, l, x, y)
			if p[1]:
				c = _c(BOIS, 0.08, x, y)
			var d := Vector2((x + 0.5) / S - 0.5, (y + 0.5) / S - 0.5)
			var ang := fposmod(atan2(d.y, d.x) / TAU * 20.0, 1.0)
			if absf(d.length() * 2.0 - 0.9) < 0.03 and (ang < 0.1 or ang > 0.9):
				c = Color(CLOU[1])
			img.set_pixel(x, y, c)
	return img
