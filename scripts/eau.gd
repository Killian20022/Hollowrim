class_name Eau
extends Node3D
## Eau réutilisable (rivière, ruisseau, lac, bassin souterrain, flaque) : voir docs/EAU.md.
##
##   var eau := Eau.creer(&"riviere", Rect2(-30, -20, 60, 40), 0.0, hauteur_terrain, {"variante": Eau.Variante.PLAQUES})
##   add_child(eau)
##
## - `region`   : rectangle monde (x, z, largeur, profondeur) couvert par la carte d'eau et le maillage ;
## - `niveau`   : hauteur de la surface (m) ; `hauteur` : Callable(x, z) -> float, hauteur du FOND/du terrain ;
## - options    : "variante" (Eau.Variante), "courant" (Callable(x, z) -> Vector2, m/s relatifs à `vitesse`), "turbulences"
##                (Array de [Vector2 centre, rayon, force 0..1] : pied de cascade, rapides), "brume" (bool), "params" (Dictionary
##                de paramètres du shader qui écrasent le préréglage), "resolution" (cases de carte par mètre, 4 par défaut),
##                "variantes" (Callable(x, z) -> Vector2(variante, intensité 0..1) : glace qui change le long du cours d'eau).
## La profondeur, le courant et les turbulences sont précalculés UNE fois dans une texture (RGBA8) : le shader ne devine rien à l'écran.

enum Variante { LIQUIDE, PARTIELLE, GLACE, BORDS_GELES, PLAQUES }

const SHADER := preload("res://shaders/eau.gdshader")
const PROF_MAX := 3.0        # m encodés dans le canal B (avec un décalage de -0,25 m pour repérer le bord)
const PAS_MAILLE := 2.0      # m : taille des carreaux du maillage (la forme exacte vient du shader)

## Préréglages : paramètres du shader (voir eau.gdshader) + clés « _… » lues ici.
const PRESETS := {
	&"riviere": {
		"c_peu": Color("#5a97a8"), "c_moyen": Color("#2b5a82"), "c_profond": Color("#14305a"), "c_clair": Color("#b5d3e6"),
		"absorption": 0.95, "transparence": 1.5, "vitesse": 1.0, "ond_amp": 1.0, "ond_taille": 1.0, "etirement": 0.45, "eclats": 1.0,
		"reflet_force": 0.85, "reflet_flou": 1.0, "ecume_force": 1.0, "vaguelettes": 1.0, "cadence": 7.0, "spec_force": 1.0,
		"_brume": false,
	},
	&"ruisseau": {
		"c_peu": Color("#6aa5b0"), "c_moyen": Color("#3a6f8c"), "c_profond": Color("#244a6e"), "c_clair": Color("#c4dcea"),
		"absorption": 1.7, "transparence": 0.9, "vitesse": 1.3, "ond_amp": 0.9, "ond_taille": 0.7, "etirement": 0.4, "eclats": 1.0,
		"reflet_force": 0.4, "reflet_flou": 1.2, "ecume_force": 1.0, "vaguelettes": 1.0, "cadence": 8.0, "spec_force": 0.8,
		"_brume": false,
	},
	&"lac": {
		"c_peu": Color("#4f8ea3"), "c_moyen": Color("#24507c"), "c_profond": Color("#0f2a52"), "c_clair": Color("#a9c8de"),
		"absorption": 0.55, "transparence": 1.2, "vitesse": 0.0, "derive": Vector2(0.05, 0.02), "ond_amp": 0.5, "ond_taille": 2.2,
		"etirement": 1.0, "eclats": 0.8, "reflet_force": 1.0, "reflet_flou": 0.5, "ecume_force": 0.6, "vaguelettes": 0.8,
		"cadence": 4.0, "spec_force": 1.2, "reflet_portee": 70.0, "fondu_loin": 70.0,
		"_brume": true,
	},
	&"bassin_souterrain": {
		"c_peu": Color("#3d6a82"), "c_moyen": Color("#1b3a5e"), "c_profond": Color("#0a1630"), "c_clair": Color("#7fa6c8"),
		"absorption": 0.8, "transparence": 1.1, "vitesse": 0.0, "derive": Vector2(0.015, 0.0), "ond_amp": 0.4, "ond_taille": 1.4,
		"etirement": 1.0, "eclats": 0.6, "reflet_force": 1.0, "reflet_flou": 0.8, "ecume_force": 0.5, "vaguelettes": 0.6,
		"cadence": 4.0, "spec_force": 2.4, "fondu_loin": 40.0,
		"_brume": false,
	},
	&"flaque": {
		"c_peu": Color("#4d7a8c"), "c_moyen": Color("#2f5675"), "c_profond": Color("#1e3d5c"), "c_clair": Color("#b0cbdc"),
		"absorption": 3.0, "transparence": 5.0, "vitesse": 0.0, "ond_amp": 0.15, "ond_taille": 1.0, "etirement": 1.0, "eclats": 0.25,
		"reflet_force": 1.0, "reflet_flou": 0.4, "ecume_force": 0.3, "vaguelettes": 0.0, "cadence": 3.0, "spec_force": 1.4,
		"_brume": false,
	},
}

## Intensité par défaut de chaque variante (part gelée, largeur de rive, densité de plaques : 0..1).
const INTENSITE := {Variante.LIQUIDE: 0.0, Variante.PARTIELLE: 0.5, Variante.GLACE: 1.0, Variante.BORDS_GELES: 0.6, Variante.PLAQUES: 0.55}

static var _ruido: ImageTexture

var preset: StringName = &"riviere"
var variante: int = Variante.LIQUIDE
var region := Rect2()
var niveau := 0.0
var materiau: ShaderMaterial
var surface: MeshInstance3D
var cycle: Node = null          # cycle.gd : ciel simplifié et lumière propre (renseigné tout seul si le parent a un `cycle`)
var temps_force := -1.0         # >= 0 : temps imposé (captures reproductibles)
var brume: GPUParticles3D = null
var _gel: Image
var _prof := PackedFloat32Array()
var _res := 4.0
var _cw := 0
var _ch := 0
var _t_ciel := 0.0

# --- création ----------------------------------------------------------------------------

static func creer(nom_preset: StringName, zone: Rect2, niveau_m: float, hauteur: Callable, options := {}) -> Eau:
	var e := Eau.new()
	e.name = "Eau_" + String(nom_preset)
	e.preset = nom_preset
	e.variante = int(options.get("variante", Variante.LIQUIDE))
	e.construire(zone, niveau_m, hauteur, options)
	return e

static func noms_presets() -> Array:
	return PRESETS.keys()

static func reglages(nom: StringName) -> Dictionary:
	return (PRESETS[nom] as Dictionary).duplicate()

## Texture de bruit partagée (128², R,G = champs lisses, B = crêtes) : sert aux ondes, à l'écume, à la glace.
static func texture_ruido() -> ImageTexture:
	if _ruido != null:
		return _ruido
	var n := 128
	var champs: Array[Image] = []
	for k in 3:
		var f := FastNoiseLite.new()
		f.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		f.seed = 9100 + k * 37
		f.frequency = [0.05, 0.065, 0.045][k]
		f.fractal_type = FastNoiseLite.FRACTAL_FBM
		f.fractal_octaves = 2
		var im := f.get_seamless_image(n, n, false)
		im.convert(Image.FORMAT_L8)
		champs.append(im)
	var sortie := Image.create(n, n, false, Image.FORMAT_RGB8)
	# étalement du contraste (le bruit simplex reste dans ~[0,25 ; 0,75])
	var mini := PackedFloat32Array([1.0, 1.0, 1.0])
	var maxi := PackedFloat32Array([0.0, 0.0, 0.0])
	for k in 3:
		for y in n:
			for x in n:
				var v := champs[k].get_pixel(x, y).r
				mini[k] = minf(mini[k], v)
				maxi[k] = maxf(maxi[k], v)
	for y in n:
		for x in n:
			var c := Color()
			for k in 3:
				var v := (champs[k].get_pixel(x, y).r - mini[k]) / maxf(maxi[k] - mini[k], 0.001)
				if k == 2:
					v = 1.0 - absf(2.0 * v - 1.0)   # crêtes : ligne claire là où le champ passe par sa médiane
				c[k] = v
			sortie.set_pixel(x, y, c)
	_ruido = ImageTexture.create_from_image(sortie)
	return _ruido

func construire(zone: Rect2, niveau_m: float, hauteur: Callable, options := {}) -> void:
	region = zone
	niveau = niveau_m
	_res = float(options.get("resolution", 4.0))
	_cw = ceili(zone.size.x * _res)
	_ch = ceili(zone.size.y * _res)
	var courant: Callable = options.get("courant", Callable())
	var turbs: Array = options.get("turbulences", [])
	var var_cb: Callable = options.get("variantes", Callable())
	var img := Image.create(_cw, _ch, false, Image.FORMAT_RGBA8)
	_gel = Image.create(_cw, _ch, false, Image.FORMAT_RG8)
	_prof.resize(_cw * _ch)
	var pas := 1.0 / _res
	for j in _ch:
		var z := zone.position.y + (j + 0.5) * pas
		for i in _cw:
			var x := zone.position.x + (i + 0.5) * pas
			var d := niveau - float(hauteur.call(x, z))
			_prof[j * _cw + i] = d
			var fl := Vector2.ZERO
			if d > 0.0 and courant.is_valid():
				fl = courant.call(x, z)
			var a := 0.0
			for t in turbs:
				var dist := Vector2(x, z).distance_to(t[0])
				a = maxf(a, float(t[2]) * (1.0 - smoothstep(0.0, float(t[1]), dist)))
			if var_cb.is_valid():
				var vv: Vector2 = var_cb.call(x, z)
				_gel.set_pixel(i, j, Color(vv.x * 50.0 / 255.0, clampf(vv.y, 0.0, 1.0), 0.0))
			else:
				_gel.set_pixel(i, j, Color(variante * 50.0 / 255.0, float(INTENSITE[variante]), 0.0))
			img.set_pixel(i, j, Color(clampf(fl.x * 0.5 + 0.5, 0.0, 1.0), clampf(fl.y * 0.5 + 0.5, 0.0, 1.0),
				clampf((d + 0.25) / (PROF_MAX + 0.25), 0.0, 1.0), a))
	materiau = ShaderMaterial.new()
	materiau.shader = SHADER
	materiau.set_shader_parameter("carte", ImageTexture.create_from_image(img))
	materiau.set_shader_parameter("carte_rect", Vector4(zone.position.x, zone.position.y, 1.0 / zone.size.x, 1.0 / zone.size.y))
	materiau.set_shader_parameter("ruido", texture_ruido())
	var reg := reglages(preset)
	for k in reg:
		if not String(k).begins_with("_"):
			materiau.set_shader_parameter(k, reg[k])
	var params: Dictionary = options.get("params", {})
	for k in params:
		materiau.set_shader_parameter(k, params[k])
	materiau.set_shader_parameter("carte_glace", ImageTexture.create_from_image(_gel))
	Palette.materiaux.append(materiau)
	_maillage()
	var veut_brume: bool = options.get("brume", reg.get("_brume", false))
	if veut_brume:
		_creer_brume(options.get("brume_zone", zone))

## Change la variante de glace à chaud sur TOUTE l'eau (liquide / partielle / couverte / bords gelés / plaques flottantes).
func definir_variante(v: int, intensite := -1.0) -> void:
	variante = v
	var k: float = intensite if intensite >= 0.0 else float(INTENSITE[v])
	_gel.fill(Color(v * 50.0 / 255.0, k, 0.0))
	materiau.set_shader_parameter("carte_glace", ImageTexture.create_from_image(_gel))

func regler(nom: String, valeur: Variant) -> void:
	materiau.set_shader_parameter(nom, valeur)

func _maillage() -> void:
	if surface != null:
		surface.queue_free()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := ceili(region.size.x / PAS_MAILLE)
	var nz := ceili(region.size.y / PAS_MAILLE)
	var n_carreaux := 0
	for cj in nz:
		for ci in nx:
			var x0 := region.position.x + ci * PAS_MAILLE
			var z0 := region.position.y + cj * PAS_MAILLE
			if not _a_de_l_eau(x0, z0, PAS_MAILLE):
				continue
			var x1 := minf(x0 + PAS_MAILLE, region.end.x)
			var z1 := minf(z0 + PAS_MAILLE, region.end.y)
			var a := Vector3(x0, 0, z0)
			var b := Vector3(x1, 0, z0)
			var c := Vector3(x0, 0, z1)
			var dd := Vector3(x1, 0, z1)
			for p in [a, b, c, b, dd, c]:
				st.set_normal(Vector3.UP)
				st.add_vertex(p)
			n_carreaux += 1
	surface = MeshInstance3D.new()
	surface.name = "Surface"
	surface.mesh = st.commit()
	surface.material_override = materiau
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.position.y = niveau
	add_child(surface)

func _a_de_l_eau(x0: float, z0: float, w: float) -> bool:
	var i0 := clampi(floori((x0 - region.position.x) * _res) - 1, 0, _cw - 1)
	var i1 := clampi(ceili((x0 + w - region.position.x) * _res) + 1, 0, _cw - 1)
	var j0 := clampi(floori((z0 - region.position.y) * _res) - 1, 0, _ch - 1)
	var j1 := clampi(ceili((z0 + w - region.position.y) * _res) + 1, 0, _ch - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			if _prof[j * _cw + i] > -0.1:
				return true
	return false

# --- requêtes (jeu) ---------------------------------------------------------------------

## Profondeur de l'eau (m) en (x, z) monde ; <= 0 hors de l'eau.
func profondeur_en(x: float, z: float) -> float:
	var i := floori((x - region.position.x) * _res)
	var j := floori((z - region.position.y) * _res)
	if i < 0 or j < 0 or i >= _cw or j >= _ch:
		return -1.0
	return _prof[j * _cw + i]

func contient(x: float, z: float) -> bool:
	return profondeur_en(x, z) > 0.02

## Surface totale de l'eau (m²), pour les mesures.
func surface_m2() -> float:
	var n := 0
	for d in _prof:
		if d > 0.0:
			n += 1
	return n / (_res * _res)

# --- ciel et temps -------------------------------------------------------------------------

func _ready() -> void:
	if cycle == null and get_parent() != null and get_parent().get("cycle") is Node:
		cycle = get_parent().get("cycle")
	_synchroniser()

func _process(dt: float) -> void:
	_t_ciel -= dt
	if _t_ciel <= 0.0:
		_t_ciel = 0.2
		_synchroniser()
	if temps_force >= 0.0:
		materiau.set_shader_parameter("temps_force", temps_force)

## Recopie le ciel du cycle jour/nuit dans le shader (reflets de repli, brume).
func _synchroniser() -> void:
	if cycle == null or materiau == null:
		return
	materiau.set_shader_parameter("ciel_froid", cycle.get("_froid"))
	materiau.set_shader_parameter("ciel_chaud", cycle.get("_chaud"))
	materiau.set_shader_parameter("ciel_haut", cycle.get("_haut"))
	materiau.set_shader_parameter("ciel_dir", cycle.get("_dir_h"))
	materiau.set_shader_parameter("ciel_chaleur", cycle.get("_crep"))
	if brume != null:
		var mb: StandardMaterial3D = brume.draw_pass_1.material
		var fb: Color = cycle.call("couleur_brume")
		mb.albedo_color = Color(fb.r * 1.15 + 0.03, fb.g * 1.15 + 0.03, fb.b * 1.15 + 0.04, 1.0)

# --- brume au-dessus de l'eau ---------------------------------------------------------------

## Quelques grands voiles transparents (tramés par bruit de hachage : aucun tri instable) qui flottent à ras de l'eau.
func _creer_brume(zone: Rect2) -> void:
	brume = GPUParticles3D.new()
	brume.name = "Brume"
	brume.amount = clampi(int(zone.get_area() / 55.0), 6, 40)
	brume.lifetime = 9.0
	brume.preprocess = 9.0
	brume.local_coords = true
	brume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brume.visibility_aabb = AABB(Vector3(zone.position.x - 3.0, -1, zone.position.y - 3.0), Vector3(zone.size.x + 6.0, 4, zone.size.y + 6.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(zone.size.x * 0.5, 0.1, zone.size.y * 0.5)
	pm.direction = Vector3(1, 0.05, 0.3)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.03
	pm.initial_velocity_max = 0.1
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 1.5
	var rampe := Gradient.new()
	rampe.set_color(0, Color(1, 1, 1, 0.0))
	rampe.set_color(1, Color(1, 1, 1, 0.0))
	rampe.add_point(0.3, Color(1, 1, 1, 0.55))
	rampe.add_point(0.7, Color(1, 1, 1, 0.55))
	var tr := GradientTexture1D.new()
	tr.gradient = rampe
	pm.color_ramp = tr
	brume.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(5.0, 1.2)
	q.orientation = PlaneMesh.FACE_Y   # voile à plat, à ras de l'eau (pas de carton qui se retourne)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.5, 0.55, 0.65)
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	g.gradient = gr
	g.width = 64
	g.height = 64
	m.albedo_texture = g
	q.material = m
	brume.draw_pass_1 = q
	brume.position = Vector3(zone.get_center().x, niveau + 0.18, zone.get_center().y)
	add_child(brume)
