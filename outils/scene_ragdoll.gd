extends SceneTree
## Capture du ragdoll en fenêtre :
## Godot_..._console.exe --path 'C:\Users\lopezk19\Jeux\nordique' -s res://outils/scene_ragdoll.gd
## Un humain debout sur une pente, pieds au sol, reçoit un coup de face ; image du corps tombé
## enregistrée dans captures/ragdoll.png (avant le coup : captures/ragdoll_debout.png).

const PENTE := -15.0

func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 540)
	var monde := Node3D.new()
	root.add_child(monde)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.65, 0.78)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	monde.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-50, -30, 0)
	monde.add_child(soleil)
	# sol en pente, visible
	var sol := StaticBody3D.new()
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(40, 0.4, 40)
	f.shape = b
	sol.add_child(f)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = b.size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.5, 0.3)
	mi.material_override = mat
	sol.add_child(mi)
	var basis := Basis(Vector3.RIGHT, deg_to_rad(PENTE))
	var n := basis * Vector3.UP
	sol.transform = Transform3D(basis, -n * 0.2)
	monde.add_child(sol)
	await physics_frame
	var corps := CharacterBody3D.new()
	monde.add_child(corps)
	var p := Humain.creer({"corps": "homme", "tenue": {"tunique": Color(0.55, 0.2, 0.15), "pantalon": Color(0.3, 0.25, 0.2), "bottes": Color(0.15, 0.1, 0.07)},
		"cheveux": "Hair_Long", "barbe": true})
	corps.add_child(p)
	PiedsAuSol.equiper(p, corps)
	(p.get_node("Animations") as AnimationPlayer).play("Idle")
	var cam := Camera3D.new()
	monde.add_child(cam)
	cam.fov = 50
	cam.global_position = Vector3(3.2, 1.6, 2.4)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.current = true
	for _i in 60:
		await process_frame
	_capturer("debout")
	var rd := Ragdoll.equiper(p) as Ragdoll
	rd.endormir_apres(3.0)
	rd.declencher(Vector3(0, 40, -260), Vector3(0, 1.3, 0.2))
	for _i in 240:
		await physics_frame
	var pelvis := (rd.os["pelvis"] as PhysicalBone3D).global_position
	cam.global_position = pelvis + Vector3(2.6, 1.6, -0.6)
	cam.look_at(pelvis)
	for _i in 3:
		await process_frame
	_capturer("ragdoll")
	print("pelvis ", pelvis, " figé ", rd.est_fige())
	quit()

func _capturer(nom: String) -> void:
	var img := root.get_texture().get_image()
	var chemin := "C:/Users/lopezk19/Jeux/nordique/captures/%s.png" % ("ragdoll_debout" if nom == "debout" else "ragdoll")
	print("capture ", chemin, " -> ", img.save_png(chemin), " ", img.get_size())
