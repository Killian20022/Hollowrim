class_name Palette
## Textures procédurales en palette (rendu pixel) et matériaux PS1 partagés par tout le jeu.
## Règle de direction artistique : textures 32 px, 4 teintes, toujours le shader ps1.

const PS1 := preload("res://shaders/ps1.gdshader")
const AFFINE := 0.55  # 1 = PS1 pur, mais les grands triangles proches se tordent trop

const NEIGE := ["#7f90ad", "#9cadc8", "#b9c6dc", "#d6e0ee"]
const ROCHE := ["#2e323b", "#41464f", "#565c67", "#6d7480"]
const AIGUILLES := ["#0b1814", "#12261d", "#1b3626", "#274a33"]
const ECORCE := ["#22170f", "#311f14", "#43301f", "#56402a"]
const ACIER := ["#3a4458", "#56627a", "#8a96ad", "#b9c3d6"]
const CUIR := ["#1e140e", "#2c1d13", "#3d2a1b", "#4f3825"]
const FOURRURE := ["#2a2c33", "#3b3e47", "#50545e", "#6a6e78"]
const PLANCHES := ["#1b1510", "#2a2018", "#3a2d21", "#4b3b2b"]
const FOIN := ["#4a3c1c", "#62502a", "#7a6636", "#947e46"]
const OSSEMENT := ["#6b6452", "#8f8670", "#b3aa8f", "#d2c9ad"]

static var materiaux: Array[ShaderMaterial] = []
static var tex_neige: ImageTexture
static var _cache := {}
static var _rng := RandomNumberGenerator.new()
static var _ps1_actif := true

static func _hash(x: int, y: int, g: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (g * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0

static func _valeur_periodique(x: float, y: float, p: int, g: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - xi
	var fy := y - yi
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(posmod(xi, p), posmod(yi, p), g)
	var b := _hash(posmod(xi + 1, p), posmod(yi, p), g)
	var c := _hash(posmod(xi, p), posmod(yi + 1, p), g)
	var d := _hash(posmod(xi + 1, p), posmod(yi + 1, p), g)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

## Texture tuilable : bruit périodique sur 3 octaves, quantifié dans la palette.
static func texture(taille: int, palette: Array, periode: int, graine: int, grain: float, rng: RandomNumberGenerator = null) -> ImageTexture:
	if rng == null:
		rng = _rng
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	var couleurs: Array[Color] = []
	for hex in palette:
		couleurs.append(Color(hex))
	for y in taille:
		for x in taille:
			var v := 0.0
			var amp := 0.5
			var per := periode
			for o in 3:
				v += _valeur_periodique(float(x) / taille * per, float(y) / taille * per, per, graine * 10 + o) * amp
				amp *= 0.5
				per *= 2
			v = v / 0.875 + (rng.randf() - 0.5) * grain
			img.set_pixel(x, y, couleurs[clampi(int(v * couleurs.size()), 0, couleurs.size() - 1)])
	return ImageTexture.create_from_image(img)

## Texture mise en cache par nom (pour les objets créés après le monde).
static func tex(nom: String, palette: Array, periode := 4, grain := 0.4) -> ImageTexture:
	if not _cache.has(nom):
		_cache[nom] = texture(32, palette, periode, nom.hash() & 0xff, grain)
	return _cache[nom]

static func materiau(base: Texture2D, echelle_uv := Vector2.ONE, teinte := Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1
	m.set_shader_parameter("tex_base", base)
	m.set_shader_parameter("tex_neige", tex_neige if tex_neige else base)
	m.set_shader_parameter("uv_echelle", echelle_uv)
	m.set_shader_parameter("teinte", teinte)
	_appliquer(m, _ps1_actif)
	materiaux.append(m)
	return m

static func _appliquer(m: ShaderMaterial, actif: bool) -> void:
	m.set_shader_parameter("grille", 135.0 if actif else 0.0)
	m.set_shader_parameter("affine", AFFINE if actif else 0.0)

static func regler_ps1(actif: bool) -> void:
	_ps1_actif = actif
	for m in materiaux:
		_appliquer(m, actif)

static var _conversions := {}

## Passe un modèle importé (KayKit…) au rendu PS1 : texture réduite à `taille` px en
## plus-proche-voisin, shader ps1, teinte commune.
static func convertir(racine: Node, taille := 128, teinte := Color.WHITE, saturation := 1.0) -> void:
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var tex: Texture2D = mat.albedo_texture if mat is BaseMaterial3D else null
			if tex == null:
				continue
			var cle := "%d:%d:%s:%f" % [tex.get_rid().get_id(), taille, teinte.to_html(), saturation]
			if not _conversions.has(cle):
				var img := tex.get_image()
				if img.is_compressed():
					img.decompress()
				img.resize(taille, taille, Image.INTERPOLATE_NEAREST)
				var m := materiau(ImageTexture.create_from_image(img), Vector2.ONE, teinte)
				m.set_shader_parameter("saturation", saturation)
				_conversions[cle] = m
			mi.set_surface_override_material(s, _conversions[cle])

## Matériau lumineux sans ombrage (flammes, yeux, runes).
static func lueur(couleur: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = couleur
	return m

## Police pixel du jeu (Kenney Pixel, nette : ni lissage ni sous-pixel). Une copie par
## appelant : la garder dans une variable statique fait planter Godot à la fermeture.
static func police() -> FontFile:
	var p := (load("res://assets/polices/Kenney Pixel.ttf") as FontFile).duplicate()
	p.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	p.hinting = TextServer.HINTING_NONE
	p.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	p.generate_mipmaps = false
	return p

## À appeler quand le monde se ferme : les ressources gardées dans des variables statiques
## seraient sinon libérées après l'arrêt du moteur de rendu (plantage à la fermeture).
static func vider() -> void:
	materiaux.clear()
	_cache.clear()
	_conversions.clear()
	tex_neige = null
