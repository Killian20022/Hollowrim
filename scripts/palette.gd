class_name Palette
## Textures procédurales en palette (rendu pixel) et matériaux PS1 partagés par tout le jeu.
## Règle de direction artistique : textures 32 px, 4 teintes, toujours le shader ps1.

const PS1 := preload("res://shaders/ps1.gdshader")
const AFFINE := 0.55  # 1 = PS1 pur, mais les grands triangles proches se tordent trop

const NEIGE := ["#8796b2", "#97a6c0", "#a8b6cd", "#b9c5da", "#c9d3e5"]
const ROCHE := ["#2e323b", "#41464f", "#565c67", "#6d7480"]
const AIGUILLES := ["#0b1814", "#12261d", "#1b3626", "#274a33"]
const ECORCE := ["#22170f", "#311f14", "#43301f", "#56402a"]
const ACIER := ["#3a4458", "#56627a", "#8a96ad", "#b9c3d6"]
const CUIR := ["#1e140e", "#2c1d13", "#3d2a1b", "#4f3825"]
const FOURRURE := ["#2a2c33", "#3b3e47", "#50545e", "#6a6e78"]
const PLANCHES := ["#1b1510", "#2a2018", "#3a2d21", "#4b3b2b"]
const FOIN := ["#4a3c1c", "#62502a", "#7a6636", "#947e46"]
const OSSEMENT := ["#6b6452", "#8f8670", "#b3aa8f", "#d2c9ad"]
# sol écologique de la zone témoin (lot D)
const TERRE := ["#443a39", "#52453f", "#63544d", "#766560"]
const NEIGE_PIETINEE := ["#6f7c95", "#7f8ca5", "#909db5", "#a3afc5"]
const AIGUILLES_SOL := ["#78726f", "#898386", "#9a959a", "#aba8b1"]  # neige sale / brun-gris, peu contrastée
const MOUSSE := ["#1c2a20", "#25372a", "#304433", "#3d5240"]

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
		# graine fixe propre à la texture : grain reproductible, indépendant de l'ordre de création
		rng = RandomNumberGenerator.new()
		rng.seed = graine * 7919 + taille * 31 + periode
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

## Comme `texture`, avec mipmaps (sol du lot D : filtre nearest_mipmap, moins de scintillement
## au loin). `rng` est OBLIGATOIRE et propre à l'appelant : le RNG statique partagé change
## les textures du village. `fin(img, rng)` retouche l'image avant les mipmaps (cailloux, traces…).
static func texture_mip(taille: int, palette: Array, periode: int, graine: int, grain: float, rng: RandomNumberGenerator, fin: Callable = Callable()) -> ImageTexture:
	var img := texture(taille, palette, periode, graine, grain, rng).get_image()
	if fin.is_valid():
		fin.call(img, rng)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Terre : petits cailloux clairs isolés.
static func texture_terre() -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = 4101
	return texture_mip(32, TERRE, 5, 41, 0.35, r, func(img: Image, rr: RandomNumberGenerator) -> void:
		for k in 14:
			var x := rr.randi_range(0, 31)
			var y := rr.randi_range(0, 31)
			img.set_pixel(x, y, Color(TERRE[3]))
			if k % 3 == 0:
				img.set_pixel((x + 1) % 32, y, Color(TERRE[2])))

## Neige piétinée : plus sombre et bleutée que la neige, traces horizontales de pas.
static func texture_neige_pietinee() -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = 4102
	return texture_mip(32, NEIGE_PIETINEE, 4, 42, 0.3, r, func(img: Image, rr: RandomNumberGenerator) -> void:
		for k in 7:
			var x := rr.randi_range(0, 31)
			var y := rr.randi_range(0, 31)
			for l in rr.randi_range(3, 6):
				img.set_pixel((x + l) % 32, y, Color(NEIGE_PIETINEE[0])))

## Aiguilles de sapin tombées, pailletées de neige.
static func texture_aiguilles_sol() -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = 4103
	return texture_mip(32, AIGUILLES_SOL, 8, 43, 0.6, r, func(img: Image, rr: RandomNumberGenerator) -> void:
		_pailleter_img(img, rr, 0.24))

## Mousse gelée, pailletée de neige.
static func texture_mousse() -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = 4104
	return texture_mip(32, MOUSSE, 6, 44, 0.45, r, func(img: Image, rr: RandomNumberGenerator) -> void:
		_pailleter_img(img, rr, 0.04))

static func _pailleter_img(img: Image, rr: RandomNumberGenerator, part: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if rr.randf() < part:
				img.set_pixel(x, y, Color("#b9c5da"))

## Texture mise en cache par nom (pour les objets créés après le monde).
static func tex(nom: String, palette: Array, periode := 4, grain := 0.4) -> ImageTexture:
	if not _cache.has(nom):
		_cache[nom] = texture(32, palette, periode, nom.hash() & 0xff, grain)
	return _cache[nom]

static var _ps1_double: Shader

## Variante de ps1.gdshader sans élimination des faces arrière : pour les pièces fines et ouvertes
## (vêtements découpés dans le corps, cheveux) dont on verrait sinon le vide à travers l'étoffe.
static func shader_double_face() -> Shader:
	if _ps1_double == null:
		_ps1_double = Shader.new()
		_ps1_double.code = PS1.code.replace("render_mode diffuse_lambert, specular_disabled;", "render_mode diffuse_lambert, specular_disabled, cull_disabled;")
	return _ps1_double

static func materiau(base: Texture2D, echelle_uv := Vector2.ONE, teinte := Color.WHITE, double_face := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader_double_face() if double_face else PS1
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
	_ps1_double = null

## Paillettes : quelques pixels très clairs (cristaux de neige qui accrochent la lumière).
static func pailleter(tex: ImageTexture, part: float, couleur := Color("#eef4ff")) -> ImageTexture:
	var img := tex.get_image()
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for y in img.get_height():
		for x in img.get_width():
			if r.randf() < part:
				img.set_pixel(x, y, couleur)
	return ImageTexture.create_from_image(img)

## Bruit doux en niveaux de gris pour `tex_macro` (filtré, sans palette).
static func texture_macro() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = 5
	n.frequency = 0.02
	n.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.width = 128
	t.height = 128
	t.seamless = true
	t.noise = n
	return t
