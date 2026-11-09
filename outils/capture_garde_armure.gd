extends SceneTree
## ESSAI Tripo : le garde (Gardien nordique) portant l'armure dorée Tripo.
##   --mode=iter  --sortie=dossier   scène simple (sol, soleil), poses de repos + marche, vues rapprochées (réglage des pièces)
##   --mode=stills                   village (foret_test) : face / profil / dos / 3/4 en marche
##   --mode=film (avec --write-movie)  village : marche du garde, caméra qui tourne autour
const DT := 1.0 / 30.0
var args := {}
var m: Node
var cam: Camera3D
var garde: Node3D
var anim: AnimationPlayer

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		args[s.get_slice("=", 0)] = s.get_slice("=", 1) if "=" in s else "1"
	_go.call_deferred()

func _capt(chemin: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(chemin)

func _vue(pos: Vector3, vise: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(vise, Vector3.UP)

func _go() -> void:
	var mode := String(args.get("mode", "iter"))
	var sol := Vector3.ZERO
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.05
	cam.far = 400.0
	if mode == "iter" or args.has("simple"):
		var we := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.55, 0.62, 0.7)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.7, 0.72, 0.78)
		env.ambient_light_energy = 0.8
		we.environment = env
		root.add_child(we)
		var soleil := DirectionalLight3D.new()
		soleil.rotation_degrees = Vector3(-45, 35, 0)
		soleil.light_energy = 1.1
		root.add_child(soleil)
		var plan := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(40, 40)
		plan.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.4, 0.3)
		plan.material_override = mat
		root.add_child(plan)
		root.add_child(cam)
		cam.make_current()
		m = root
	else:
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
		m.add_child(cam)
		cam.make_current()
		# espace dégagé le plus proche de la place du village (x est, z sud)
		for i in 5:
			await process_frame
		var p0 := Vector3(float(args.get("cx", "44")), 0.0, float(args.get("cz", "36")))
		if not args.has("fixe"):
			p0 = _libre(p0)
		sol = Vector3(p0.x, m.hauteur(p0.x, p0.z), p0.z)
		print("ARMURE place libre ", sol)
	garde = GardesVillage.creer_modele({"armure_tripo": true, "poil": 1, "peau": 2})
	m.add_child(garde)
	garde.global_position = sol
	anim = garde.get_node("Animations")
	for i in 10:
		await process_frame
	match mode:
		"iter":
			await _iter()
		"stills":
			await _stills()
		"film":
			await _film()
		"extremites":
			await _extremites()
	if mode == "film":
		quit(0)
	else:
		OS.kill(OS.get_process_id())   # quit() reste parfois suspendu (fuites au vidage de la boucle) : capture déjà écrite

func _jouer(nom: String, t := 0.0) -> void:
	anim.play(nom)
	anim.seek(t, true)
	anim.pause()

func _orbite(ang_deg: float, dist: float, haut: float, vise_h := 1.0) -> void:
	var c := garde.global_position
	var a := deg_to_rad(ang_deg)
	_vue(c + Vector3(sin(a) * dist, haut, cos(a) * dist), c + Vector3(0, vise_h, 0))

func _iter() -> void:
	var dos := String(args.get("sortie", "/tmp/w/iter"))
	DirAccess.make_dir_recursive_absolute(dos)
	garde.rotation.y = 0.0
	for pose in ["Idle", "Walk"]:
		_jouer(pose, 0.3 if pose == "Walk" else 0.0)
		for v in [["face", 0.0], ["profil", 90.0], ["dos", 180.0], ["tq", 40.0]]:
			cam.fov = 17.0
			_orbite(v[1], 5.0, 1.2, 0.95)
			await _capt("%s/%s_%s.png" % [dos, pose, v[0]])
	# armure seule (corps masqué) : vérifie la pose des pièces sur le squelette
	var sq := garde.find_child("Skeleton3D", true, false) as Skeleton3D
	var etat := {}
	for c in sq.get_children():
		if c is MeshInstance3D and c.name != "Armure_armure":
			etat[c] = (c as MeshInstance3D).visible
			(c as MeshInstance3D).visible = false
	for pose in ["Idle", "Walk"]:
		_jouer(pose, 0.3 if pose == "Walk" else 0.0)
		for v in [["face", 0.0], ["profil", 90.0], ["dos", 180.0]]:
			cam.fov = 17.0
			_orbite(v[1], 5.0, 1.2, 0.95)
			await _capt("%s/nu_%s_%s.png" % [dos, pose, v[0]])
	_jouer("Idle")
	cam.fov = 12.0
	for a in [0, 90, 180]:
		_orbite(a, 3.0, 1.70, 1.68)
		await _capt(dos + "/nu_tete_%d.png" % a)
	for c: MeshInstance3D in etat:
		c.visible = etat[c]
	cam.fov = 12.0
	for a in [0, 90, 180]:
		_orbite(a, 3.0, 1.70, 1.68)
		await _capt(dos + "/tete_%d.png" % a)
	cam.fov = 10.0
	_orbite(60.0, 3.5, 2.3, 1.70)
	await _capt(dos + "/tete_dessus.png")
	cam.fov = 14.0
	for a in [90, 40, 0]:
		_orbite(a, 3.5, 0.5, 0.3)
		await _capt(dos + "/pieds_%d.png" % a)
	cam.fov = 22.0
	_orbite(25.0, 3.0, 1.9, 1.5)
	await _capt(dos + "/haut.png")
	_orbite(25.0, 3.0, 0.5, 0.4)
	await _capt(dos + "/bas.png")

## Marche du garde en cercle (rayon R autour de `centre`) ; la caméra le suit à l'azimut relatif `az` (0 = devant lui, 90 = son profil, 180 = derrière).
const R_MARCHE := 3.0
var _t_marche := 0.0
var centre := Vector3.ZERO

func _pas(az_deg: float, dist: float, haut: float, vise_h: float, fov: float) -> void:
	_t_marche += DT
	var w := 1.03 / R_MARCHE
	var th := _t_marche * w
	if args.has("droit"):   # marche en ligne droite (cap --cap en degrés), plus lisible qu'un cercle dans une rue
		var cap := deg_to_rad(float(args.get("cap", "0")))
		var d := _t_marche * 1.03
		var x0 := centre.x + sin(cap) * d
		var z0 := centre.z + cos(cap) * d
		garde.global_position = Vector3(x0, m.hauteur(x0, z0), z0)
		garde.rotation.y = cap
	elif args.has("surplace"):   # pas sur place (caméra qui tourne autour) : aucun décor ne s'interpose
		garde.global_position = Vector3(centre.x, (m.hauteur(centre.x, centre.z) if m.has_method("hauteur") else centre.y), centre.z)
		garde.rotation.y = 0.0
	else:
		var x := centre.x + sin(th) * R_MARCHE
		var z := centre.z + (1.0 - cos(th)) * R_MARCHE
		garde.global_position = Vector3(x, m.hauteur(x, z), z)
		var tang := Vector3(cos(th), 0, sin(th))
		garde.rotation.y = atan2(tang.x, tang.z)
	var az := garde.rotation.y + deg_to_rad(az_deg)
	var p := garde.global_position
	cam.fov = fov
	var cible := p + Vector3(0, vise_h, 0)
	var pos := _cam_claire(cible, az, dist, haut)
	_vue(pos, cible)

var _decal := 0.0
var _ech := 1.0
## Position de caméra dégagée : l'azimut voulu, sinon le plus proche azimut / la plus courte distance où aucun obstacle ne coupe la vue.
func _cam_claire(cible: Vector3, az: float, dist: float, haut: float) -> Vector3:
	var sp: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var libre := func(d_az: float, f: float) -> bool:
		var pos := cible + Vector3(sin(az + d_az) * dist * f, haut - cible.y + garde.global_position.y, cos(az + d_az) * dist * f)
		return sp.intersect_ray(PhysicsRayQueryParameters3D.create(cible, pos)).is_empty()
	if not libre.call(_decal, _ech):
		var trouve := false
		for f in [1.0, 0.8, 0.65, 0.5]:
			for d in [0.0, 0.26, -0.26, 0.52, -0.52, 0.78, -0.78, 1.05, -1.05]:
				if libre.call(d, f):
					_decal = d
					_ech = f
					trouve = true
					break
			if trouve:
				break
	return cible + Vector3(sin(az + _decal) * dist * _ech, haut - cible.y + garde.global_position.y, cos(az + _decal) * dist * _ech)

func _marche_pose() -> void:
	anim.play("Walk")
	anim.speed_scale = 1.0
	centre = garde.global_position
	_t_marche = 0.0

func _stills() -> void:
	var dos := String(args.get("sortie", "/tmp/w/stills"))
	DirAccess.make_dir_recursive_absolute(dos)
	m.cycle.heure = 12.0
	_marche_pose()
	for v in [["face", 0.0], ["profil", 90.0], ["dos", 180.0], ["trois_quarts", 40.0]]:
		for i in 45:
			_pas(v[1], 4.4, 2.1, 1.0, 36.0)
			await process_frame
		await _capt("%s/garde_marche_%s.png" % [dos, v[0]])
	if args.has("compare"):   # côte à côte avec un garde du village sans l'armure (même modèle, même pose de repos)
		var g2 := GardesVillage.creer_modele({"poil": 1, "peau": 2, "bouclier": "dos", "type": "ronde"})   # bouclier au dos : main gauche libre
		m.add_child(g2)
		var a2: AnimationPlayer = g2.get_node("Animations")
		anim.play("Idle")
		a2.play("Idle")
		for v in [["face", 0.0], ["profil", 90.0]]:
			for i in 30:
				garde.global_position = Vector3(centre.x, m.hauteur(centre.x, centre.z), centre.z)
				garde.rotation.y = 0.0
				var dx := Vector3(1.0, 0, 0) if v[0] == "face" else Vector3(0, 0, -0.9)
				var p2 := garde.global_position + dx
				g2.global_position = Vector3(p2.x, m.hauteur(p2.x, p2.z), p2.z)
				g2.rotation.y = 0.0
				var c := garde.global_position + dx * 0.5 + Vector3(0, 0.95, 0)
				var az := deg_to_rad(v[1])
				cam.fov = 30.0
				_vue(c + Vector3(sin(az) * 5.0, 0.35, cos(az) * 5.0), c)
				await process_frame
			await _capt("%s/comparaison_%s.png" % [dos, v[0]])
		# proportion des mains : même cadrage (même distance, même angle, visée sur l'os de la main) pour le garde en armure
		# et pour le garde du village côte à côte (au repos)
		garde.global_position = Vector3(centre.x, m.hauteur(centre.x, centre.z), centre.z)
		var p3 := garde.global_position + Vector3(2.0, 0, 0)
		g2.global_position = Vector3(p3.x, m.hauteur(p3.x, p3.z), p3.z)
		g2.global_rotation = garde.global_rotation
		for v in [["face", 0.0], ["profil", 90.0]]:
			for qui in [["armure", garde, g2], ["normal", g2, garde]]:
				(qui[1] as Node3D).visible = true
				(qui[2] as Node3D).visible = false
				for i in 20:
					var sq := (qui[1] as Node3D).find_child("Skeleton3D", true, false) as Skeleton3D
					var c := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("lowerarm_l")).origin
					var c2 := sq.global_transform * sq.get_bone_global_pose(sq.find_bone("hand_l")).origin
					# visée sur le poignet, à 1,1 m : avant-bras et main entiers dans le cadre, même cadrage pour les deux gardes
					var vise := c.lerp(c2, 1.0)
					var az := deg_to_rad(v[1])
					var dir := (qui[1] as Node3D).global_basis * Vector3(sin(az), 0.0, cos(az))
					cam.fov = 30.0
					_vue(vise + dir.normalized() * 1.1 + Vector3(0, 0.03, 0), vise)
					await process_frame
				await _capt("%s/proportion_main_%s_%s.png" % [dos, v[0], qui[0]])
		garde.visible = true
		g2.queue_free()
		_marche_pose()
	for v in [["torse", 25.0, 2.6, 1.7, 1.35, 22.0], ["tete", 20.0, 2.2, 1.6, 1.5, 22.0], ["jambes", 25.0, 2.8, 0.7, 0.55, 34.0]]:
		for i in 30:
			_pas(v[1], v[2], v[3], v[4], v[5])
			await process_frame
		await _capt("%s/garde_%s.png" % [dos, v[0]])

## Gros plans des mains et des pieds (repos : face / profil ; marche : 3/4), caméra visant l'os lui-même.
func _os_pos(nom: String) -> Vector3:
	var sq := garde.find_child("Skeleton3D", true, false) as Skeleton3D
	var i := sq.find_bone(nom)
	return sq.global_transform * sq.get_bone_global_pose(i).origin

func _vise_os(nom: String, az_deg: float, dist: float, dh: float, fov: float) -> void:
	var c := _os_pos(nom)
	var az := garde.rotation.y + deg_to_rad(az_deg)
	cam.fov = fov
	_vue(c + Vector3(sin(az) * dist, dh, cos(az) * dist), c)

func _extremites() -> void:
	var dos := String(args.get("sortie", "/tmp/w/ext"))
	DirAccess.make_dir_recursive_absolute(dos)
	if m.get("cycle") != null:
		m.cycle.heure = 12.0
	centre = garde.global_position
	anim.play("Idle")
	# repos
	for v in [["main_face", "hand_l", 20.0, 0.9, 0.1, 24.0], ["main_profil", "hand_l", 90.0, 0.9, 0.1, 24.0], ["main_dos", "hand_l", 150.0, 0.9, 0.15, 24.0],
			["pied_profil", "foot_l", 90.0, 1.1, 0.12, 26.0], ["pied_face", "foot_l", 10.0, 1.1, 0.3, 26.0], ["pied_34", "foot_l", 45.0, 1.1, 0.3, 26.0]]:
		for i in 20:
			garde.rotation.y = 0.0
			_vise_os(v[1], v[2], v[3], v[4], v[5])
			await process_frame
		await _capt("%s/%s.png" % [dos, v[0]])
	# marche sur place (plusieurs instants du pas)
	args["surplace"] = "1"
	_marche_pose()
	for v in [["main_marche", "hand_l", 60.0, 1.0, 0.15, 26.0], ["pied_marche", "foot_l", 80.0, 1.3, 0.15, 30.0]]:
		for k in 3:
			for i in 9:
				_pas(0.0, 4.0, 2.0, 1.0, 36.0)
				_vise_os(v[1], v[2], v[3], v[4], v[5])
				await process_frame
			await _capt("%s/%s_%d.png" % [dos, v[0], k])

func _film() -> void:
	m.cycle.heure = 12.0
	_marche_pose()
	# face (4 s), profil (4 s), dos (4 s), orbite lente 3/4 avec gros plan (6 s)
	var plan := [[0.0, 4.6, 1.5, 1.0, 34.0, 4.0], [90.0, 4.6, 1.5, 1.0, 34.0, 4.0], [180.0, 4.6, 1.5, 1.0, 34.0, 4.0]]
	print("FILM debut")
	for p in plan:
		for i in int(p[5] / DT):
			_pas(p[0], p[1], p[2], p[3], p[4])
			await process_frame
	var n := int(7.0 / DT)
	for i in n:
		var k := float(i) / n
		_pas(lerpf(-40.0, 140.0, k), lerpf(5.0, 2.8, k), lerpf(1.8, 1.4, k), lerpf(1.0, 1.25, k), lerpf(34.0, 24.0, k))
		await process_frame
	print("FILM fini")

func _libre(c: Vector3) -> Vector3:
	var sp: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var meilleur := c
	var dm := 1e9
	for ix in range(-16, 17):
		for iz in range(-16, 17):
			var q := Vector3(c.x + ix * 1.0, 0, c.z + iz * 1.0)
			var ok := true
			for dx in [-6.0, -3.0, 0.0, 3.0, 6.0]:
				for dz in [-3.0, 0.0, 3.0, 6.0, 9.0]:
					var x: float = q.x + dx
					var z: float = q.z + dz
					var h: float = m.hauteur(x, z)
					var r: Dictionary = sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, h + 20.0, z), Vector3(x, h - 2.0, z)))
					if not r.is_empty() and absf((r.position as Vector3).y - h) > 0.15:
						ok = false
			var d := Vector2(q.x - c.x, q.z - c.z).length()
			if ok and d < dm:
				dm = d
				meilleur = q
	return meilleur
