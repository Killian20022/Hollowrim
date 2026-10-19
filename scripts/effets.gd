class_name Effets
## Effets de combat partagés : éclats (sang, poussière d'os, étincelles), arrêt sur image.

static func eclats(parent: Node, position: Vector3, couleur: Color, nombre := 14, vitesse := 3.0, lumineux := false) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = nombre
	p.lifetime = 0.9
	p.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 75.0
	pm.initial_velocity_min = vitesse * 0.4
	pm.initial_velocity_max = vitesse
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	p.process_material = pm
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.05
	if lumineux:
		cube.material = Palette.lueur(couleur)
	else:
		var m := StandardMaterial3D.new()
		m.albedo_color = couleur
		cube.material = m
	p.draw_pass_1 = cube
	var scene := parent.get_tree().current_scene
	(scene if scene else parent.get_tree().root).add_child(p)
	p.global_position = position
	p.emitting = true
	p.finished.connect(p.queue_free)

## Fige le jeu une fraction de seconde : donne du poids aux coups.
static func arret_image(arbre: SceneTree, duree: float) -> void:
	Engine.time_scale = 0.03
	await arbre.create_timer(duree, true, false, true).timeout
	Engine.time_scale = 1.0
