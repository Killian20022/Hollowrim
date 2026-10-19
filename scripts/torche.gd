class_name Torche
## Torche tenue en main : manche de bois noueux, tête de chiffons goudronnés, flamme en
## plusieurs couches, étincelles, fumée. Repère : +Y le long du manche, origine au poing.

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

static func _mat(nom: String, couleurs: Array, periode: int, grain: float, uv: Vector2, teinte := Color.WHITE, emission := Color.BLACK) -> ShaderMaterial:
	var m := Palette.materiau(Palette.tex(nom, couleurs, periode, grain), uv, teinte)
	m.set_shader_parameter("tex_neige", m.get_shader_parameter("tex_base"))
	if emission != Color.BLACK:
		m.set_shader_parameter("emission", emission)
	return m

static func _systeme(parent: Node3D, pos: Vector3, nombre: int, duree: float, taille: float, pm: ParticleProcessMaterial, coords_locales: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = nombre
	p.lifetime = duree
	p.local_coords = coords_locales
	p.position = pos
	p.process_material = pm
	p.fixed_fps = 30
	p.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 3, 2))
	var q := QuadMesh.new()
	q.size = Vector2(taille, taille)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.vertex_color_use_as_albedo = true
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mq.no_depth_test = false
	q.material = mq
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

static func _pm(rayon: float, v_min: float, v_max: float, ecart: float, grav: Vector3, couleurs: Array, echelle_min: float, echelle_max: float, courbe_fin := 0.3) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = rayon
	pm.direction = Vector3.UP
	pm.spread = ecart
	pm.initial_velocity_min = v_min
	pm.initial_velocity_max = v_max
	pm.gravity = grav
	pm.scale_min = echelle_min
	pm.scale_max = echelle_max
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.08
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in couleurs.size():
		offs.append(float(i) / (couleurs.size() - 1))
		cols.append(couleurs[i])
	g.offsets = offs
	g.colors = cols
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	# rétrécit en montant : les langues finissent en pointe
	var c := Curve.new()
	c.add_point(Vector2(0, 1.0))
	c.add_point(Vector2(0.5, 0.75))
	c.add_point(Vector2(1, courbe_fin * 0.3))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	return pm

## Construit la torche sous `parent`. Renvoie {"flamme": Array[GPUParticles3D] (tous les
## systèmes à allumer/éteindre), "lumiere": OmniLight3D}.
static func construire(parent: Node3D) -> Dictionary:
	var bois := _mat("torche_bois", ["#1a110a", "#2a1b10", "#3d2a18", "#54391f"], 4, 0.55, Vector2(1, 3))
	var chiffon := _mat("torche_chiffon", ["#140d08", "#24160d", "#3a2615", "#5a3b1f"], 8, 0.6, Vector2(2, 1))
	var goudron := _mat("torche_goudron", ["#070504", "#0f0a07", "#1a110b", "#2a1a10"], 6, 0.5, Vector2(2, 1))
	var braise := _mat("torche_braise", ["#3a0c04", "#7a1e06", "#c2410c", "#ff7a1a"], 6, 0.7, Vector2(2, 1), Color.WHITE, Color(1.4, 0.4, 0.08))
	var lanière := _mat("torche_cuir", Palette.CUIR, 4, 0.4, Vector2(2, 1))

	# manche : trois tronçons coniques, légèrement désaxés (noueux)
	_cone(parent, 0.021, 0.024, 0.20, 7, 0.02, bois, Vector3(0.000, 0, 0.000), Vector3(0, 0, 0))
	_cone(parent, 0.024, 0.027, 0.17, 6, 0.19, bois, Vector3(0.002, 0, 0.001), Vector3(2, 20, -3))
	_cone(parent, 0.027, 0.031, 0.12, 7, 0.32, bois, Vector3(-0.001, 0, 0.002), Vector3(-2, 50, 3))
	# nœud / excroissance
	_cone(parent, 0.030, 0.026, 0.035, 6, 0.10, bois, Vector3(0.0, 0, 0.0), Vector3(0, 35, 0))
	# pommeau sous la main
	_cone(parent, 0.017, 0.023, 0.03, 6, -0.075, bois)

	# tête : bandes de chiffon empilées, décalées et de travers
	_cone(parent, 0.034, 0.046, 0.045, 7, 0.385, chiffon, Vector3(0, 0, 0), Vector3(0, 10, 0))
	_cone(parent, 0.048, 0.050, 0.04, 7, 0.425, chiffon, Vector3(0.003, 0, -0.002), Vector3(4, 30, -5))
	_cone(parent, 0.050, 0.044, 0.04, 6, 0.462, goudron, Vector3(-0.003, 0, 0.002), Vector3(-5, 60, 6))
	_cone(parent, 0.046, 0.034, 0.035, 7, 0.497, goudron, Vector3(0.002, 0, 0.0), Vector3(3, 15, -4))
	# braises dans le haut des chiffons
	_cone(parent, 0.032, 0.024, 0.02, 6, 0.52, braise, Vector3(0, 0, 0))
	# ficelle sous la tête
	_cone(parent, 0.033, 0.033, 0.012, 7, 0.355, lanière, Vector3(0, 0, 0), Vector3(0, 0, 0))
	_cone(parent, 0.037, 0.037, 0.008, 7, 0.37, lanière, Vector3(0, 0, 0), Vector3(3, 0, -3))

	var systemes: Array[GPUParticles3D] = []
	var base := Vector3(0, 0.52, 0)
	var haut := Vector3(0, 0, 0)
	# cœur jaune-blanc
	systemes.append(_systeme(parent, base + Vector3(0, 0.01, 0), 10, 0.35, 0.055,
		_pm(0.012, 0.15, 0.3, 6.0, Vector3(0, 0.5, 0),
			[Color(1.8, 1.4, 0.7, 0.6), Color(2.0, 1.1, 0.3, 0.5), Color(1.6, 0.8, 0.2, 0.0)], 0.8, 1.1), true))
	# corps orange
	systemes.append(_systeme(parent, base, 18, 0.5, 0.095,
		_pm(0.022, 0.2, 0.4, 8.0, Vector3(0, 0.7, 0),
			[Color(2.6, 1.3, 0.3, 0.8), Color(2.2, 0.8, 0.12, 0.6), Color(1.0, 0.25, 0.04, 0.0)], 0.7, 1.2), true))
	# langues rouges qui montent et s'effilent
	systemes.append(_systeme(parent, base + Vector3(0, 0.03, 0), 12, 0.7, 0.07,
		_pm(0.02, 0.2, 0.4, 14.0, Vector3(0, 0.8, 0),
			[Color(1.8, 0.45, 0.06, 0.7), Color(1.2, 0.2, 0.03, 0.5), Color(0.4, 0.04, 0.0, 0.0)], 0.5, 1.0, 0.1), true))
	# étincelles (coordonnées monde)
	var pm_e := _pm(0.025, 0.25, 0.6, 35.0, Vector3(0, 0.5, 0),
		[Color(3.0, 1.8, 0.5, 1.0), Color(2.0, 0.6, 0.1, 0.8), Color(0.6, 0.1, 0.0, 0.0)], 0.4, 0.8, 1.0)
	systemes.append(_systeme(parent, base + Vector3(0, 0.05, 0), 8, 1.1, 0.012, pm_e, false))
	# fumée sombre discrète (coordonnées monde)
	var pm_f := _pm(0.02, 0.15, 0.25, 12.0, Vector3(0, 0.35, 0),
		[Color(0.18, 0.15, 0.13, 0.0), Color(0.16, 0.14, 0.12, 0.10), Color(0.1, 0.09, 0.09, 0.0)], 1.0, 1.8, 1.0)
	var fum := _systeme(parent, base + Vector3(0, 0.2, 0), 10, 1.6, 0.12, pm_f, false)
	# la fumée est en mélange normal (additive : invisible sur fond clair)
	((fum.draw_pass_1 as QuadMesh).material as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	systemes.append(fum)

	var lum := OmniLight3D.new()
	lum.light_color = Color(1.0, 0.58, 0.28)
	lum.light_energy = 1.5
	lum.omni_range = 10.0
	lum.omni_attenuation = 1.3
	lum.position = Vector3(0, 0.58, 0.06)
	lum.shadow_enabled = false
	parent.add_child(lum)
	haut = lum.position
	return {"flamme": systemes, "lumiere": lum, "haut": haut}
