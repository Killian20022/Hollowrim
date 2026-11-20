class_name Neige   # (référencée par preload : pas besoin de réimport)
extends RefCounted
## Chute de neige du dehors (5000 flocons autour du joueur), sortie de monde.gd (`_neige`) pour être mesurée seule
## (outils/banc_neige.gd) : mêmes réglages, même rendu.

## `graine` >= 0 : flocons aux mêmes places d'un lancement à l'autre (captures A/B, --graine-neige).
static func creer(graine := -1) -> GPUParticles3D:
	var neige := GPUParticles3D.new()
	neige.amount = 5000
	neige.lifetime = 9.0
	neige.preprocess = 9.0
	neige.local_coords = false
	neige.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 50, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 1, 28)
	pm.direction = Vector3(0.35, -1, 0.15)
	pm.spread = 15.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0.1, -0.25, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.0
	pm.turbulence_noise_scale = 6.0
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.06
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	neige.process_material = pm
	if graine >= 0:
		neige.use_fixed_seed = true
		neige.seed = graine
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mq.albedo_color = Color(0.85, 0.9, 1.0)
	# un flocon collé à l'objectif deviendrait un gros carré : il s'efface en tramage
	mq.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	mq.distance_fade_min_distance = 0.4
	mq.distance_fade_max_distance = 1.5
	q.material = mq
	neige.draw_pass_1 = q
	return neige
