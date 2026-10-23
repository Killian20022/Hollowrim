class_name Cascade
extends Node3D
## Cascade : nappe (géométrie Blender `Chute`, shader eau_chute) + falaise de blocs (`Falaise`, matière roche du jeu)
## + gouttelettes + écume au pied + brume discrète. Origine du nœud = LÈVRE (haut de l'eau amont) ; l'eau coule vers +X local
## (tourner le nœud pour l'orienter) et tombe de `hauteur` m ; `largeur` m de large.
## Le bassin d'arrivée est une Eau à part : lui passer `zone_turbulence()` dans ses options "turbulences".

const MODELE := "res://assets/modeles/eau/cascade.glb"
const SHADER := preload("res://shaders/eau_chute.gdshader")
const H_MODELE := 1.5
const L_MODELE := 3.0

var hauteur := 1.5
var largeur := 3.0
var cycle: Node = null
var temps_force := -1.0
var chute: MeshInstance3D
var falaise: MeshInstance3D
var materiau: ShaderMaterial
var gouttes: GPUParticles3D
var ecume: GPUParticles3D
var brume: GPUParticles3D
var _t_ciel := 0.0

static func creer(h: float, l: float, options := {}) -> Cascade:
	var c := Cascade.new()
	c.name = "Cascade"
	c.hauteur = h
	c.largeur = l
	c.construire(options)
	return c

## [centre Vector2 (monde), rayon, force] du pied de chute, à passer à Eau.creer (options "turbulences").
func zone_turbulence(rayon := 2.2) -> Array:
	var p := global_transform * Vector3(0.55, 0.0, 0.0)
	return [Vector2(p.x, p.z), rayon, 1.0]

func construire(options := {}) -> void:
	var scene := load(MODELE) as PackedScene
	var racine: Node = scene.instantiate()
	add_child(racine)
	chute = racine.find_child("Chute", true, false) as MeshInstance3D
	falaise = racine.find_child("Falaise", true, false) as MeshInstance3D
	# le modèle est exporté Y haut, à l'échelle H_MODELE × L_MODELE : on l'étire pour la hauteur / largeur demandées
	racine.scale = Vector3(1.0, hauteur / H_MODELE, largeur / L_MODELE)
	materiau = ShaderMaterial.new()
	materiau.shader = SHADER
	materiau.set_shader_parameter("ruido", Eau.texture_ruido())
	materiau.set_shader_parameter("echelle_y", hauteur / H_MODELE)
	for k in options.get("params", {}):
		materiau.set_shader_parameter(k, options["params"][k])
	chute.material_override = materiau
	chute.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	falaise.material_override = TexturesBati.m_roche()
	_particules()

func _particules() -> void:
	var h := hauteur
	var l := largeur
	# gouttelettes projetées hors de la nappe
	gouttes = GPUParticles3D.new()
	gouttes.name = "Gouttelettes"
	gouttes.amount = 70
	gouttes.lifetime = 0.9
	gouttes.local_coords = false
	gouttes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gouttes.visibility_aabb = AABB(Vector3(-3, -h - 2, -l), Vector3(7, h + 4, l * 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.12, h * 0.42, l * 0.42)
	pm.direction = Vector3(1, 0.15, 0)
	pm.spread = 55.0
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, -7.0, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	gouttes.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mq.albedo_color = Color(0.82, 0.9, 1.0)
	mq.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	mq.distance_fade_min_distance = 0.3
	mq.distance_fade_max_distance = 1.0
	q.material = mq
	gouttes.draw_pass_1 = q
	gouttes.position = Vector3(0.3, -h * 0.5, 0)
	add_child(gouttes)
	# écume projetée au pied
	ecume = GPUParticles3D.new()
	ecume.name = "EcumePied"
	ecume.amount = 48
	ecume.lifetime = 1.1
	ecume.local_coords = false
	ecume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ecume.visibility_aabb = AABB(Vector3(-2, -h - 1, -l), Vector3(6, 3, l * 2))
	var pe := ParticleProcessMaterial.new()
	pe.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pe.emission_box_extents = Vector3(0.35, 0.02, l * 0.4)
	pe.direction = Vector3(0.6, 1, 0)
	pe.spread = 40.0
	pe.initial_velocity_min = 0.5
	pe.initial_velocity_max = 1.6
	pe.gravity = Vector3(0, -6.5, 0)
	pe.scale_min = 0.8
	pe.scale_max = 2.0
	ecume.process_material = pe
	var qe := QuadMesh.new()
	qe.size = Vector2(0.05, 0.05)
	qe.material = mq
	ecume.draw_pass_1 = qe
	ecume.position = Vector3(0.7, -h + 0.03, 0)
	add_child(ecume)
	# brume discrète : voiles verticaux tramés au pied
	brume = GPUParticles3D.new()
	brume.name = "Brume"
	brume.amount = 8
	brume.lifetime = 5.0
	brume.preprocess = 5.0
	brume.local_coords = false
	brume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brume.visibility_aabb = AABB(Vector3(-3, -h - 1, -l), Vector3(8, h + 3, l * 2))
	var pb := ParticleProcessMaterial.new()
	pb.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pb.emission_box_extents = Vector3(0.4, 0.1, l * 0.45)
	pb.direction = Vector3(0.5, 1, 0)
	pb.spread = 20.0
	pb.initial_velocity_min = 0.12
	pb.initial_velocity_max = 0.35
	pb.gravity = Vector3.ZERO
	pb.scale_min = 0.9
	pb.scale_max = 1.6
	var rampe := Gradient.new()
	rampe.set_color(0, Color(1, 1, 1, 0.0))
	rampe.set_color(1, Color(1, 1, 1, 0.0))
	rampe.add_point(0.25, Color(1, 1, 1, 0.45))
	rampe.add_point(0.6, Color(1, 1, 1, 0.3))
	var tr := GradientTexture1D.new()
	tr.gradient = rampe
	pb.color_ramp = tr
	brume.process_material = pb
	var qb := QuadMesh.new()
	qb.size = Vector2(1.4, 1.4)
	var mb := StandardMaterial3D.new()
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	mb.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mb.vertex_color_use_as_albedo = true
	mb.albedo_color = Color(0.5, 0.58, 0.7)
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
	mb.albedo_texture = g
	qb.material = mb
	brume.draw_pass_1 = qb
	brume.position = Vector3(0.9, -h + 0.5, 0)
	add_child(brume)

func _ready() -> void:
	if cycle == null and get_parent() != null and get_parent().get("cycle") is Node:
		cycle = get_parent().get("cycle")
	_synchroniser()

func _process(dt: float) -> void:
	_t_ciel -= dt
	if _t_ciel <= 0.0:
		_t_ciel = 0.25
		_synchroniser()
	if temps_force >= 0.0:
		materiau.set_shader_parameter("temps_force", temps_force)

func _synchroniser() -> void:
	if cycle == null or brume == null:
		return
	var fb: Color = cycle.call("couleur_brume")
	var mb: StandardMaterial3D = brume.draw_pass_1.material
	mb.albedo_color = Color(fb.r * 1.2 + 0.03, fb.g * 1.2 + 0.03, fb.b * 1.2 + 0.04, 1.0)
	# gouttelettes et écume : un peu plus sombres la nuit (elles ne brillent pas)
	var jour: float = cycle.call("clarte")
	var q: StandardMaterial3D = gouttes.draw_pass_1.material
	var k := lerpf(0.42, 1.0, maxf(jour, cycle.call("chaleur") * 0.8))
	q.albedo_color = Color(0.82 * k, 0.9 * k, 1.0 * k)
