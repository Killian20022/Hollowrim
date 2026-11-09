extends SceneTree
## ESSAI Tripo (essai/puits) : le puits de la place. Vues fixes et film en première personne.
##   --mode=stills --sortie=dossier   village (jour, avec un habitant pour l'échelle), gros plan, plongées dans le conduit
##   --mode=film                      (avec --write-movie) approche à pied, regard dans le puits
## `-- --sans-tripo` rend l'ancien puits aux mêmes cadrages (planche avant/après). Fenêtre hors écran via godot_slot.sh.
const DT := 1.0 / 30.0
var m: Node
var cam: Camera3D
var args := {}
var c := Vector3.ZERO     # centre du puits (sol)

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		args[s.get_slice("=", 0)] = s.get_slice("=", 1) if "=" in s else "1"
	_go.call_deferred()

func _vue(pos: Vector3, vise: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(vise, Vector3.UP)

func _capt(chemin: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(chemin)

func _go() -> void:
	m = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(m)
	while not m.pret:
		await process_frame
	for i in 90:
		await process_frame
	var j: CharacterBody3D = m.joueur
	j.process_mode = Node.PROCESS_MODE_DISABLED
	j.mains.visible = false
	j.visible = false
	if m.hud != null:
		m.hud.visible = false
	m.cycle.heure = 12.0
	m.cycle._process(0.0)
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 400.0
	cam.near = 0.05
	m.add_child(cam)
	cam.make_current()
	var p := m.find_child("PuitsTripo", true, false) as Node3D
	if p != null:
		c = p.global_position
	else:
		c = Vector3(42.0, m.hauteur(42.0, 38.0), 38.0)
	print("PUITS centre ", c, " tripo=", p != null)
	_habitant_a_cote()
	for i in 10:
		await process_frame
	match String(args.get("mode", "stills")):
		"film":
			await _film()
		_:
			await _stills()
	quit(0)

## Un habitant du village debout à côté du puits (échelle), figé.
func _habitant_a_cote() -> void:
	var v: Node3D = null
	for n in get_nodes_in_group("villageois"):
		v = n
		break
	if v == null:
		print("PUITS pas d'habitant")
		return
	v.process_mode = Node.PROCESS_MODE_DISABLED
	var q := c + Vector3(1.9, 0, 0.9)
	v.global_position = Vector3(q.x, m.hauteur(q.x, q.z), q.z)
	v.rotation.y = deg_to_rad(float(args.get("hab", "230")))
	print("PUITS habitant ", v.name, " en ", v.global_position)

func _stills() -> void:
	var dos := String(args.get("sortie", "/tmp/puits"))
	DirAccess.make_dir_recursive_absolute(dos)
	cam.fov = 55.0
	_vue(c + Vector3(6.5, 2.6, 7.0), c + Vector3(0.3, 1.2, 0.2))
	await _capt(dos + "/village.png")
	_vue(c + Vector3(-5.5, 2.4, 6.0), c + Vector3(0, 1.2, 0))
	await _capt(dos + "/village_b.png")
	cam.fov = 50.0
	_vue(c + Vector3(3.6, 1.6, 4.0), c + Vector3(0.2, 1.0, 0.1))
	await _capt(dos + "/gros.png")
	cam.fov = 60.0
	for k in 6:     # gros plans tout autour (contre-jour, de près) : là où les cassures se voient
		var az := deg_to_rad(30.0 + 60.0 * k)
		var d := 2.3 if k % 2 == 0 else 1.6
		_vue(c + Vector3(sin(az) * d, 1.15, cos(az) * d), c + Vector3(0, 1.1 if k % 3 else 1.6, 0))
		await _capt(dos + "/gros_%d.png" % k)
	if args.has("diag"):     # diagnostic : seau et conduit sans le noir, vus de près dans le puits
		for mi: MeshInstance3D in m.find_child("PuitsTripo", true, false).find_children("*", "MeshInstance3D", true, false):
			for k in mi.mesh.get_surface_count():
				var mt := mi.get_active_material(k)
				if mt is ShaderMaterial and (mt as ShaderMaterial).shader.resource_path.ends_with("puits_conduit.gdshader"):
					(mt as ShaderMaterial).set_shader_parameter("clair", 1.0)
		cam.fov = 70.0
		_vue(c + Vector3(0.2, 1.8, 0.7), c + Vector3(0, -2.0, 0))
		await _capt(dos + "/diag_seau_haut.png")
		_vue(c + Vector3(0.1, 1.6, 0.3), c + Vector3(0, -4.5, 0))
		await _capt(dos + "/diag_seau_bas.png")
	_vue(c + Vector3(1.4, 0.3, 1.0), c + Vector3(0, 1.9, 0))     # toit vu de dessous
	await _capt(dos + "/toit_dessous.png")
	_vue(c + Vector3(-1.6, 2.6, -1.2), c + Vector3(0, 1.6, 0))     # toit vu de dessus
	await _capt(dos + "/toit_dessus.png")
	cam.fov = 65.0
	# plongée : debout au bord de la margelle, regard vers le fond
	_vue(c + Vector3(0.0, 1.7, 1.25), c + Vector3(0.0, -2.0, -0.1))
	await _capt(dos + "/plongee_bord.png")
	_vue(c + Vector3(0.15, 1.75, 0.55), c + Vector3(0.0, -3.0, -0.05))
	await _capt(dos + "/plongee_pic.png")
	cam.fov = 80.0
	_vue(c + Vector3(0.3, 1.7, 0.7), c + Vector3(-0.2, -1.0, -0.4))
	await _capt(dos + "/plongee_large.png")
	# vue de côté : le regard rase la margelle
	cam.fov = 60.0
	_vue(c + Vector3(0.0, 1.3, 1.5), c + Vector3(0.0, -0.4, -0.3))
	await _capt(dos + "/plongee_oblique.png")

func _film() -> void:
	print("FILM debut")
	var T := 14.0
	var n := int(T / DT)
	var a := deg_to_rad(float(args.get("ang", "35")))
	var dir := Vector3(sin(a), 0, cos(a))
	var depart := c + dir * 9.0
	var bord := c + dir * 1.25
	cam.fov = 70.0
	for i in n:
		var t := i * DT
		var pos: Vector3
		var vise: Vector3
		if t < 8.0:        # marche vers le puits, regard à hauteur d'yeux sur le toit
			var k := smoothstep(0.0, 1.0, t / 8.0)
			var p := depart.lerp(bord, k)
			pos = Vector3(p.x, m.hauteur(p.x, p.z) + 1.7, p.z)
			vise = c + Vector3(0, 1.6 - 0.8 * k, 0)
		else:              # arrêt au bord, la tête s'incline vers le fond
			var k := smoothstep(0.0, 1.0, (t - 8.0) / 4.0)
			pos = Vector3(bord.x, c.y + 1.7, bord.z)
			vise = c + Vector3(0, lerpf(0.8, -3.5, k), 0) - dir * lerpf(0.0, 0.1, k)
		_vue(pos, vise)
		await process_frame
	print("FILM fin")
