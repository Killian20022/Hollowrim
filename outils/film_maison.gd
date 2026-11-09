extends SceneTree
## ESSAI Tripo (branche essai/maison) : maison nordique, intérieur de taverne et armure Tripo allégés, passés au shader ps1 du jeu, posés dans le village enneigé.
##   plan  : godot --path . --script res://outils/film_maison.gd -- --mode=plan --sortie=/tmp/x   (vue du dessus + vues fixes)
##   film  : godot --path . --write-movie f.avi --fixed-fps 30 --resolution 1280x720 --script res://outils/film_maison.gd -- --mode=film
##   fixes : --mode=stills --sortie=dossier  (vues PNG pour la planche comparative)
## Modèles : assets/essai_tripo/{cottage,taverne,armure}.glb (voir outils/essai_maison_allege.py).
const DT := 1.0 / 30.0
## Emplacements MONDE (x, z) ; réglés d'après la vue du dessus.
var P_MAISON := Vector2(33.0, 32.0)
var P_TAVERNE := Vector2(46.0, 41.0)
var P_ARMURE := Vector2(41.0, 34.0)   # place du village, entre la maison et la taverne
var m: Node
var cam: Camera3D
var args := {}

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		args[s.get_slice("=", 0)] = s.get_slice("=", 1) if "=" in s else "1"
	if args.has("maison"):
		P_MAISON = _v2(args["maison"])
	if args.has("taverne"):
		P_TAVERNE = _v2(args["taverne"])
	if args.has("armure"):
		P_ARMURE = _v2(args["armure"])
	_go.call_deferred()

func _v2(s: String) -> Vector2:
	var p := s.split(",")
	return Vector2(float(p[0]), float(p[1]))

func _ps1(racine: Node, neige: bool, teinte := Color.WHITE) -> void:
	if args.has("sans-ps1"):
		return
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null:
				var tex: Texture2D = (src as BaseMaterial3D).albedo_texture
				var mat := Palette.materiau(tex, Vector2.ONE, teinte, true)
				if not neige:
					mat.set_shader_parameter("tex_neige", tex)
				mi.set_surface_override_material(s, mat)

func _charger(chemin: String) -> Node3D:
	return (load(chemin) as PackedScene).instantiate() as Node3D

## Pose le modèle `n` : pied (bas de la boîte) au sol à (x, z), échelle `e`, lacet `ang` degrés.
func _poser(n: Node3D, p: Vector2, e: float, ang: float, y_off := 0.0) -> void:
	m.add_child(n)
	n.scale = Vector3.ONE * e
	n.rotation.y = deg_to_rad(ang)
	var mn := INF
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mn = minf(mn, (mi.global_transform * mi.get_aabb()).position.y)
	var sol: float = m.hauteur(p.x, p.y)
	n.global_position = Vector3(p.x, sol - (mn - n.global_position.y) + y_off, p.y)

var maison: Node3D
var taverne: Node3D
var armure: Node3D

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
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 400.0
	m.add_child(cam)
	cam.make_current()
	maison = _charger("res://assets/essai_tripo/cottage.glb")
	_ps1(maison, false, Color(1.9, 1.9, 1.9))
	_poser(maison, P_MAISON, 12.0, float(args.get("lacet", "0")))
	taverne = _charger("res://assets/essai_tripo/taverne.glb")
	_ps1(taverne, false, Color(1.5, 1.5, 1.5))
	_poser(taverne, P_TAVERNE, 7.0, 0.0, 0.05)
	armure = _monter_armure()
	m.add_child(armure)
	armure.rotation.y = deg_to_rad(float(args.get("alac", "-20")))
	armure.global_position = Vector3(P_ARMURE.x, m.hauteur(P_ARMURE.x, P_ARMURE.y), P_ARMURE.y)
	_vider()
	for i in 30:
		await process_frame
	_vider()
	match String(args.get("mode", "film")):
		"plan":
			await _plan()
		"scan":
			_scan()
		"stills":
			await _stills()
		_:
			await _film()
	quit(0)

## Présentoir : poteau de bois + traverse ; pièces de l'armure (une seule de chaque dans le glb : gantelet, jambière, botte miroités en négatif sur X).
func _monter_armure() -> Node3D:
	var racine := Node3D.new()
	racine.name = "ArmureSurPresentoir"
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color("#4a3322")
	bois.roughness = 1.0
	var piece := func(nom: String, pos: Vector3, e := Vector3.ONE, rot := Vector3.ZERO) -> void:
		var n := _charger("res://assets/essai_tripo/armure.glb")
		var src := n.find_child(nom, true, false) as MeshInstance3D
		print("FILM piece ", nom, " ", src.get_aabb().size)
		var copie := MeshInstance3D.new()
		copie.mesh = src.mesh
		copie.position = pos
		copie.scale = e
		copie.rotation_degrees = rot
		copie.name = nom
		racine.add_child(copie)
		_ps1(copie, false, Color(2.2, 2.1, 1.9))
		n.free()
	_boite(racine, Vector3(0, 0.05, 0), Vector3(0.9, 0.1, 0.6), bois)
	_boite(racine, Vector3(0, 0.9, 0), Vector3(0.08, 1.7, 0.08), bois)
	_boite(racine, Vector3(0, 1.28, 0), Vector3(0.9, 0.07, 0.08), bois)
	var E := Vector3.ONE * 2.6
	piece.call("torse", Vector3(0, 1.23, 0.0), E)
	piece.call("casque", Vector3(0, 1.66, 0.0), E)
	piece.call("gantelet", Vector3(-0.45, 1.15, 0.0), E)
	piece.call("gantelet", Vector3(0.45, 1.15, 0.0), Vector3(-E.x, E.y, E.z))
	piece.call("jambiere", Vector3(-0.2, 0.65, 0.0), E)
	piece.call("jambiere", Vector3(0.2, 0.65, 0.0), Vector3(-E.x, E.y, E.z))
	piece.call("botte", Vector3(-0.22, 0.22, 0.0), E)
	piece.call("botte", Vector3(0.22, 0.22, 0.0), Vector3(-E.x, E.y, E.z))
	return racine

## Décor seul : ni villageois, ni gardes, ni faune devant les modèles.
func _vider() -> void:
	for g in ["villageois", "gardes_village", "faune", "bete_quat", "ennemis"]:
		for n in get_nodes_in_group(g):
			if n is Node3D:
				(n as Node3D).visible = false

func _boite(parent: Node3D, pos: Vector3, taille: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func _vue(pos: Vector3, vise: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(vise, Vector3.UP)

func _capt(chemin: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(chemin)

func _plan() -> void:
	var dos := String(args.get("sortie", "/tmp/maison_plan"))
	for n: Node3D in [maison, taverne, armure]:
		var bb := AABB(Vector3(1e5, 1e5, 1e5), Vector3.ZERO)
		var prem := true
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = mi.global_transform * mi.get_aabb()
			bb = ab if prem else bb.merge(ab)
			prem = false
		print("FILM ", n.name, " pos=", n.global_position, " aabb=", bb, " vis=", n.visible, " sol=", m.hauteur(n.global_position.x, n.global_position.z))
	DirAccess.make_dir_recursive_absolute(dos)
	for cx in [P_MAISON.x]:
		for cz in [P_MAISON.y]:
			var c := Vector3(cx, m.hauteur(cx, cz), cz)
			cam.fov = 75.0
			_vue(c + Vector3(0, 40, 4), c)
			await _capt(dos + "/dessus_%d_%d.png" % [cx, cz])
	var mp := maison.global_position
	_vue(mp + Vector3(-9, 5, 11), mp + Vector3(0, 2.5, 0))
	await _capt(dos + "/maison.png")
	var tp := taverne.global_position
	_vue(tp + Vector3(-7, 8, 9), tp + Vector3(0, 1.0, 0))
	await _capt(dos + "/taverne.png")
	var ap := armure.global_position
	_vue(ap + Vector3(0.5, 1.6, -3.0), ap + Vector3(0, 1.0, 0))
	await _capt(dos + "/armure.png")

func _stills() -> void:
	var dos := String(args.get("sortie", "/tmp/maison_stills"))
	DirAccess.make_dir_recursive_absolute(dos)
	cam.fov = 40.0
	var mp := maison.global_position
	_vue(mp + Vector3(7.0, 8.0, 11.0), mp + Vector3(0, 1.5, 0))
	await _capt(dos + "/maison.png")
	var tp := taverne.global_position
	_vue(tp + Vector3(-7.0, 8.5, 9.0), tp + Vector3(0, 1.0, 0))
	await _capt(dos + "/taverne.png")
	var ap := armure.global_position
	_vue(ap + Vector3(1.2, 1.7, 3.6), ap + Vector3(0, 1.0, 0))
	await _capt(dos + "/armure.png")

func _film() -> void:
	var mp := maison.global_position + Vector3(0, 2.6, 0)
	var tp := taverne.global_position + Vector3(0, 1.0, 0)
	var ap := armure.global_position + Vector3(0, 1.0, 0)
	var total := 27.0
	print("FILM debut")
	var n := int(total / DT)
	for i in n:
		var t := i * DT
		var p: Vector3
		var v: Vector3
		if t < 9.0:           # tour de la maison, côté place
			var k := t / 9.0
			var a := lerpf(-0.2, 2.3, k)
			var r := lerpf(15.0, 12.0, k)
			p = mp + Vector3(sin(a) * r, lerpf(6.0, 4.5, k), cos(a) * r)
			v = mp
		elif t < 18.0:        # vol vers la taverne, plongée sur la pièce, puis vers la place
			var k := (t - 9.0) / 9.0
			var ks := k * k * (3.0 - 2.0 * k)
			var d0 := mp + Vector3(sin(2.3) * 12.0, 4.5, cos(2.3) * 12.0)
			var d1 := tp + Vector3(-5.0, 8.5, 8.5)
			var d2 := tp + Vector3(-2.5, 4.2, 5.5)
			p = d0.lerp(d1, minf(ks * 2.0, 1.0)).lerp(d2, maxf(ks * 2.0 - 1.0, 0.0))
			v = mp.lerp(tp, minf(ks * 2.0, 1.0))
		else:                 # armure en gros plan, orbite lente
			var k := (t - 18.0) / 9.0
			var ks := k * k * (3.0 - 2.0 * k)
			var a := lerpf(0.3, 0.3 + TAU * 0.6, ks)
			var r := lerpf(5.0, 3.0, ks)
			p = ap + Vector3(sin(a) * r, lerpf(1.2, 0.6, ks), cos(a) * r)
			v = ap + Vector3(0, 0.1, 0)
		_vue(p, v)
		await process_frame
	print("FILM fini")

## Cherche des emplacements libres (rayons physiques sur une grille fine) dans la zone x 28-52, z 26-48 : carrés de rayon `rayon` m sans obstacle.
func _scan() -> void:
	var sp: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var R := float(args.get("rayon", "1.3"))
	var res := []
	for cx in range(28, 53):
		for cz in range(26, 49):
			var ok := true
			for dx in [-R, 0.0, R]:
				for dz in [-R, 0.0, R]:
					var x: float = cx + dx
					var z: float = cz + dz
					var h: float = m.hauteur(x, z)
					var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 20.0, z), Vector3(x, h - 3.0, z))
					var r: Dictionary = sp.intersect_ray(q)
					if not r.is_empty() and absf((r.position as Vector3).y - h) > 0.15:
						ok = false
			if ok:
				res.append("%d,%d" % [cx, cz])
	print("FILM scan ", res.size(), " ", res)
