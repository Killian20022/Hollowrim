class_name Torche
## Torche tenue en main (lot 6 ; flamme en GROS PIXELS avec inertie : scripts/flamme_torche.gd + shaders/flamme_pixels.gdshader) : manche de bois noueux à bague de fer et lanière de cuir, tête de chiffons goudronnés
## (bandes, bouts qui pendent, coulures de goudron), braises incandescentes, flamme en SPRITES pixel art animés (6 images,
## même famille que les torches murales de la crypte), halo net additif, quelques étincelles carrées nettes, lumière vacillante.
## Repère : +Y le long du manche, origine au poing. Plus aucune particule floue : la flamme est un sprite, partout.

const FLAMME_PIXELS := preload("res://shaders/flamme_pixels.gdshader")
const HALO_SHADER := preload("res://shaders/halo_sprite.gdshader")
const BRAISE_SHADER := preload("res://shaders/braise.gdshader")
const HAUT_TETE := 0.53   # hauteur du pied de la flamme

static func _cone(parent: Node3D, r_bas: float, r_haut: float, h: float, cotes: int, y: float, mat: Material, decal := Vector3.ZERO, incl := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = r_bas
	c.top_radius = r_haut
	c.height = h
	c.radial_segments = cotes
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.position = Vector3(decal.x, y, decal.z)
	mi.rotation_degrees = incl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _mat(nom: String, uv: Vector2, teinte := Color.WHITE) -> ShaderMaterial:
	var m := Palette.materiau(ObjetsTextures.tex(nom), uv, teinte)
	m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
	return m

static func _boite(parent: Node3D, taille: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

## Braises : carrés NETS de 3 à 5 px (shader des gerbes de pixels), tons de la flamme ; monde (local_coords faux) : quand la torche
## avance, elles restent derrière et dessinent la traînée ; elles montent un peu, ralentissent puis s'éteignent par paliers.
static func _etincelles(parent: Node3D, pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 1.1
	p.local_coords = false
	p.position = pos
	p.fixed_fps = 24
	p.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 5, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.03
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3(0, 0.12, 0)
	pm.damping_min = 0.4
	pm.damping_max = 1.2
	pm.scale_min = 0.012
	pm.scale_max = 0.022
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 0.85])
	g.colors = PackedColorArray([Color("#fff5b0"), Color("#ffc83a"), Color("#f07319"), Color("#c43014")])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	gt.width = 64
	pm.color_initial_ramp = gt
	var ga := Gradient.new()
	ga.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	ga.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.8, 0.45, 0.3, 1), Color(0.4, 0.15, 0.1, 0)])
	var gat := GradientTexture1D.new()
	gat.gradient = ga
	pm.color_ramp = gat
	p.process_material = pm
	var q := QuadMesh.new()
	var mq := ShaderMaterial.new()
	mq.shader = preload("res://shaders/gerbe_pixels.gdshader")
	mq.set_shader_parameter("taille_min", 3.0)
	mq.set_shader_parameter("taille_max", 5.0)
	q.material = mq
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

static func _carte(parent: Node3D, pos: Vector3, mat: ShaderMaterial) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.0
	parent.add_child(mi)
	return mi

## Même flamme (même atlas, même rythme brouillé à 10 i/s) pour une applique ou un feu fixe : shader crypte_flamme (mêmes images,
## phase propre à l'instance). `echelle` 1 = flamme de torche murale de la crypte.
static func flamme_fixe(parent: Node3D, pos: Vector3, echelle := 1.0, phase := 0.0) -> MeshInstance3D:
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/crypte_flamme.gdshader")
	sm.set_shader_parameter("atlas", ObjetsTextures.tex("flamme"))
	sm.set_shader_parameter("echelle_u", echelle)
	sm.set_shader_parameter("phase_u", phase)
	var mi := _carte(parent, pos, sm)
	(mi.mesh as QuadMesh).center_offset = Vector3(0, 0.5, 0)
	return mi

## Construit la torche sous `parent`. Renvoie {"flamme": Array[GPUParticles3D] (étincelles), "lumiere": OmniLight3D,
## "haut": Vector3, "visuels": Array[Node3D] (flamme + halo : à masquer avec la torche), "halo_mat": ShaderMaterial}.
static func construire(parent: Node3D) -> Dictionary:
	var bois := _mat("bois", Vector2(1, 1))
	var chiffon := _mat("chiffon", Vector2(2, 1))
	var goudron := _mat("goudron", Vector2(2, 1))
	var cuir := _mat("tresse", Vector2(2, 1))
	var fer := _mat("fer", Vector2(1, 1), Color(0.8, 0.82, 0.9))

	# manche : trois tronçons coniques à 8 pans, légèrement désaxés (noueux), nœud, pommeau
	_cone(parent, 0.021, 0.024, 0.20, 8, 0.02, bois)
	_cone(parent, 0.024, 0.027, 0.17, 8, 0.19, bois, Vector3(0.002, 0, 0.001), Vector3(2, 20, -3))
	_cone(parent, 0.027, 0.031, 0.12, 8, 0.32, bois, Vector3(-0.001, 0, 0.002), Vector3(-2, 50, 3))
	_cone(parent, 0.030, 0.026, 0.035, 8, 0.10, bois, Vector3.ZERO, Vector3(0, 35, 0))
	_cone(parent, 0.017, 0.023, 0.03, 8, -0.075, bois)
	_cone(parent, 0.024, 0.024, 0.008, 8, -0.058, fer)
	# lanière de cuir enroulée au-dessus du poing (tours inclinés)
	for k in 3:
		_cone(parent, 0.0275, 0.0275, 0.009, 8, 0.082 + k * 0.011, cuir, Vector3.ZERO, Vector3(0, k * 25, 4 if k % 2 == 0 else -4))
	_boite(parent, Vector3(0.008, 0.045, 0.003), Vector3(0.026, 0.07, 0.006), Vector3(0, 0, -6), cuir)
	# bague de fer sous la tête, avec ses clous
	_cone(parent, 0.034, 0.034, 0.014, 8, 0.352, fer)
	for k in 4:
		var a := k * PI * 0.5 + 0.4
		_cone(parent, 0.005, 0.002, 0.006, 5, 0.352, fer, Vector3(cos(a) * 0.0355, 0, sin(a) * 0.0355))

	# tête : bandes de chiffon empilées, de travers, puis goudron
	_cone(parent, 0.034, 0.046, 0.045, 9, 0.385, chiffon, Vector3.ZERO, Vector3(0, 10, 0))
	_cone(parent, 0.048, 0.050, 0.04, 9, 0.425, chiffon, Vector3(0.003, 0, -0.002), Vector3(4, 30, -5))
	_cone(parent, 0.050, 0.044, 0.04, 9, 0.462, goudron, Vector3(-0.003, 0, 0.002), Vector3(-5, 60, 6))
	_cone(parent, 0.046, 0.034, 0.035, 9, 0.497, goudron, Vector3(0.002, 0, 0.0), Vector3(3, 15, -4))
	# bouts de chiffon qui pendent et coulures de goudron
	for k in 4:
		var a := k * PI * 0.5 + 0.9
		_boite(parent, Vector3(0.013, 0.07, 0.003), Vector3(cos(a) * 0.051, 0.40, sin(a) * 0.051), Vector3(0, -rad_to_deg(a) + 90.0, 14.0), chiffon)
		_cone(parent, 0.007, 0.0, 0.05, 5, 0.43, goudron, Vector3(cos(a + 0.8) * 0.049, 0, sin(a + 0.8) * 0.049))
	# braises : calotte incandescente (sans éclairage, vacille)
	var bm := ShaderMaterial.new()
	bm.shader = BRAISE_SHADER
	bm.set_shader_parameter("tex", ObjetsTextures.tex("braise"))
	_cone(parent, 0.035, 0.022, 0.02, 9, 0.52, bm)

	# flamme en gros pixels : un pilote (inertie, braises, lumière) au pied de la flamme, un quad au shader flamme_pixels ;
	# halo net (anneaux posterisés) derrière
	var pilote := preload("res://scripts/flamme_torche.gd").new() as Node3D
	pilote.position = Vector3(0, HAUT_TETE - 0.03, 0)   # le pied est enfoncé dans la calotte : la tête bombée le cache et l'arrondit
	parent.add_child(pilote)
	var fm := ShaderMaterial.new()
	fm.shader = FLAMME_PIXELS
	var flamme := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(1, 1)
	fq.center_offset = Vector3(0, 0.5, 0)
	flamme.mesh = fq
	flamme.material_override = fm
	flamme.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flamme.extra_cull_margin = 2.0
	pilote.add_child(flamme)
	var hm := ShaderMaterial.new()
	hm.shader = HALO_SHADER
	hm.set_shader_parameter("halo", ObjetsTextures.tex("halo"))
	hm.set_shader_parameter("taille", 0.34)
	hm.set_shader_parameter("intensite", 0.75)
	var halo := _carte(parent, Vector3(0, HAUT_TETE + 0.1, 0), hm)

	var braises := _etincelles(pilote, Vector3(0, 0.05, 0))
	var systemes: Array[GPUParticles3D] = [braises]

	var lum := OmniLight3D.new()
	lum.light_color = Color(1.0, 0.58, 0.28)
	lum.light_energy = 1.5
	lum.omni_range = 10.0
	lum.omni_attenuation = 1.3
	lum.position = Vector3(0, 0.58, 0.06)
	lum.shadow_enabled = false
	parent.add_child(lum)
	pilote.set("mat", fm)
	pilote.set("lumiere", lum)
	pilote.set("halo", halo)
	pilote.set("braises", braises)
	pilote.set("lumiere_base", lum.position)
	pilote.set("halo_base", halo.position)
	return {"flamme": systemes, "lumiere": lum, "haut": lum.position, "visuels": [pilote, halo], "halo_mat": hm, "pilote": pilote}
