extends SceneTree
## ESSAI Tripo v2 : l'auberge h2 du village (extérieur cottage + intérieur taverne Tripo) et l'armure portée par un mannequin.
##   --mode=stills --sortie=dossier   vues fixes (extérieur 4 côtés, entrée, intérieur, armure)   --mode=film   (avec --write-movie)
##   --mode=avant                     mêmes vues avec `--sans-tripo` (à lancer séparément pour la planche avant/après)
const DT := 1.0 / 30.0
var m: Node
var cam: Camera3D
var args := {}
var pivot: Node3D
var ip: Interieur
var armure: Node3D

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
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 400.0
	cam.near = 0.05
	m.add_child(cam)
	cam.make_current()
	for i in m.find_children("*", "Interieur", true, false):
		if (i as Interieur).id == "h2":
			pivot = i.get_parent() as Node3D
	if pivot == null:
		print("FILM pivot introuvable")
		quit(1)
		return
	print("FILM pivot ", pivot, " demi ", ip_demi())
	ip = pivot.find_child("Interieur", true, false) as Interieur
	ip.village.construire_interieur_maintenant(ip)
	for i in 20:
		await process_frame
	_armure()
	for i in 20:
		await process_frame
	match String(args.get("mode", "stills")):
		"film":
			await _film()
		_:
			await _stills()
	quit(0)

## Mannequin (poteau, bras, jambes en bois) à taille du joueur (1,8 m) portant les pièces de l'armure, posé sur la place devant l'auberge.
func _armure() -> void:
	armure = Node3D.new()
	armure.name = "ArmureMannequin"
	m.add_child(armure)
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color("#4a3322")
	bois.roughness = 1.0
	var box := func(pos: Vector3, taille: Vector3) -> void:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = taille
		mi.mesh = b
		mi.material_override = bois
		mi.position = pos
		armure.add_child(mi)
	box.call(Vector3(0, 0.04, 0), Vector3(0.7, 0.08, 0.7))
	box.call(Vector3(-0.1, 0.45, 0), Vector3(0.1, 0.9, 0.1))
	box.call(Vector3(0.1, 0.45, 0), Vector3(0.1, 0.9, 0.1))
	box.call(Vector3(0, 1.25, 0), Vector3(0.34, 0.6, 0.2))
	box.call(Vector3(0, 1.62, 0), Vector3(0.12, 0.16, 0.12))
	box.call(Vector3(-0.3, 1.3, 0), Vector3(0.12, 0.5, 0.12))
	box.call(Vector3(0.3, 1.3, 0), Vector3(0.12, 0.5, 0.12))
	# pièces : hauteurs réelles visées (casque 0,26 m, torse 0,5 m, jambière 0,45 m, botte 0,25 m, gantelet 0,3 m)
	var vise := {"casque": 0.27, "torse": 0.62, "gantelet": 0.30, "jambiere": 0.48, "botte": 0.26}
	var place := [["casque", Vector3(0, 1.74, 0), 1.0], ["torse", Vector3(0, 1.28, 0), 1.0], ["gantelet", Vector3(-0.36, 1.05, 0), 1.0], ["gantelet", Vector3(0.36, 1.05, 0), -1.0],
		["jambiere", Vector3(-0.14, 0.55, 0), 1.0], ["jambiere", Vector3(0.14, 0.55, 0), -1.0], ["botte", Vector3(-0.14, 0.16, 0), 1.0], ["botte", Vector3(0.14, 0.16, 0), -1.0]]
	for pc: Array in place:
		var n := (load("res://assets/essai_tripo/armure.glb") as PackedScene).instantiate()
		var src := n.find_child(pc[0], true, false) as MeshInstance3D
		var copie := MeshInstance3D.new()
		copie.mesh = src.mesh
		var hh := src.get_aabb().size.y
		# orientation : la plus grande dimension verticale (Y du glb = haut) ; échelle pour la hauteur visée
		var e: float = vise[pc[0]] / hh
		copie.scale = Vector3(e * pc[2], e, e)
		copie.position = pc[1]
		armure.add_child(copie)
		MaisonTripo.ps1(copie, Color(1.25, 1.2, 1.1))
		n.free()
	var p0 := _libre(pivot.global_transform * Vector3(0, 0, 5.0))
	armure.global_position = Vector3(p0.x, m.hauteur(p0.x, p0.z), p0.z)
	print("FILM armure en ", p0)
	armure.rotation.y = deg_to_rad(float(args.get("alac", "0")))

## Point libre (aucun obstacle sur un carré de 0,9 m de demi-côté) le plus proche de `c`, par rayons physiques.
func _libre(c: Vector3) -> Vector3:
	var sp: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var meilleur := c
	var dm := 1e9
	for ix in range(-10, 11):
		for iz in range(-10, 11):
			var q := c + Vector3(ix * 0.5, 0, iz * 0.5)
			var ok := true
			for dx in [-0.9, 0.0, 0.9]:
				for dz in [-0.9, 0.0, 0.9]:
					var x: float = q.x + dx
					var z: float = q.z + dz
					var h: float = m.hauteur(x, z)
					var r: Dictionary = sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, h + 20.0, z), Vector3(x, h - 2.0, z)))
					if not r.is_empty() and absf((r.position as Vector3).y - h) > 0.15:
						ok = false
			var d := q.distance_to(c)
			if ok and d < dm:
				dm = d
				meilleur = q
	return meilleur

## Position d'observation à `dist` m de `cible`, au plus près de l'angle voulu (degrés, repère du pivot : 0 = devant la porte) sans mur entre les deux.
func _cam_libre(cible: Vector3, ang_deg: float, dist: float, haut: float) -> Vector3:
	var sp: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var T := pivot.global_transform
	for dd in range(0, 181, 10):
		for sg in [1, -1]:
			var a := deg_to_rad(ang_deg + dd * sg)
			var pos: Vector3 = T * Vector3(sin(a) * dist, haut, cos(a) * dist)
			var r: Dictionary = sp.intersect_ray(PhysicsRayQueryParameters3D.create(pos, cible))
			if r.is_empty() or (r.position as Vector3).distance_to(cible) < 5.0:
				return pos
	return cible + Vector3(0, haut, dist)

func _stills() -> void:
	var dos := String(args.get("sortie", "/tmp/maison_v2"))
	DirAccess.make_dir_recursive_absolute(dos)
	var c := pivot.global_position
	cam.fov = 50.0
	var T := pivot.global_transform
	_vue(_cam_libre(T * Vector3(0, 2.0, 0), 0.0, 15.0, 6.0), T * Vector3(0, 2.0, 0))
	await _capt(dos + "/ext_face.png")
	_vue(_cam_libre(T * Vector3(0, 2.0, 0), 90.0, 15.0, 6.0), T * Vector3(0, 2.0, 0))
	await _capt(dos + "/ext_droite.png")
	_vue(_cam_libre(T * Vector3(0, 2.0, 0), -135.0, 15.0, 6.0), T * Vector3(0, 2.0, 0))
	await _capt(dos + "/ext_arriere.png")
	_vue(_cam_libre(T * Vector3(0, 1.6, 0), 10.0, 6.5, 1.7), T * Vector3(0, 1.6, 0))
	await _capt(dos + "/entree.png")
	cam.fov = 70.0
	var I := ip.global_transform
	print("FILM interieur racine enfants=", ip.racine.get_child_count(), " construit=", ip.construit, " pos=", ip.global_position)
	cam.fov = 100.0
	if args.has("cache-cottage"):
		pivot.find_child("CottageTripo", true, false).visible = false
	_vue(I * Vector3(0, 1.5, 0), I * Vector3(0, 3.5, -1.0))
	await _capt(dos + "/int_plafond.png")
	_vue(I * Vector3(0, 1.5, 0), I * Vector3(ip.demi.x, 1.4, 0))
	await _capt(dos + "/int_mur.png")
	cam.fov = 70.0
	_vue(I * Vector3(0, 1.7, ip.demi.y - 0.4), I * Vector3(0, 1.0, -1.0))
	await _capt(dos + "/int_porte.png")
	_vue(I * Vector3(1.2, 1.6, 0.8), I * Vector3(-1.5, 1.0, -1.0))
	await _capt(dos + "/int_coin.png")
	_vue(I * Vector3(-1.2, 1.6, -0.8), I * Vector3(1.5, 1.0, 1.0))
	await _capt(dos + "/int_coin2.png")
	cam.fov = 45.0
	var a := armure.global_position
	_vue(a + Vector3(1.0, 1.6, 3.0), a + Vector3(0, 1.0, 0))
	await _capt(dos + "/armure.png")
	_vue(a + Vector3(-0.4, 1.8, 1.4), a + Vector3(0, 1.1, 0))
	await _capt(dos + "/armure_gros.png")

func _film() -> void:
	var T := pivot.global_transform
	var I := ip.global_transform
	var a0 := armure.global_position
	print("FILM debut")
	var n := int(30.0 / DT)
	for i in n:
		var t := i * DT
		var p: Vector3
		var v: Vector3
		if t < 9.0:           # tour de l'auberge
			var k := t / 9.0
			var ang := lerpf(-0.5, 1.9, k)
			p = T * Vector3(sin(ang) * 12.0, lerpf(3.5, 5.0, k), cos(ang) * 12.0)
			v = T * Vector3(0, 2.2, 0)
			cam.fov = 55.0
		elif t < 13.0:        # approche et entrée
			var k := (t - 9.0) / 4.0
			var ks := k * k * (3.0 - 2.0 * k)
			p = (T * Vector3(-2.0, 3.0, 11.0)).lerp(T * Vector3(0, 1.7, 2.8), ks)
			v = T * Vector3(0, lerpf(2.0, 1.5, ks), 0)
		elif t < 22.0:        # intérieur : on avance puis on tourne
			var k := (t - 13.0) / 9.0
			var ks := k * k * (3.0 - 2.0 * k)
			cam.fov = 70.0
			p = I * Vector3(lerpf(0.0, -ip.demi.x * 0.4, ks), 1.7, lerpf(ip.demi.y - 0.4, 0.4, ks))
			v = I * Vector3(lerpf(0.0, ip.demi.x, k), 1.0, lerpf(-1.0, -ip.demi.y * 0.5, k))
		else:                 # armure en gros plan
			var k := (t - 22.0) / 8.0
			var ang := lerpf(0.3, 0.3 + TAU * 0.5, k)
			cam.fov = 45.0
			p = a0 + Vector3(sin(ang) * lerpf(3.0, 1.8, k), lerpf(1.7, 1.4, k), cos(ang) * lerpf(3.0, 1.8, k))
			v = a0 + Vector3(0, 1.1, 0)
		_vue(p, v)
		await process_frame
	print("FILM fini")

func ip_demi() -> Vector2:
	var i := pivot.find_child("Interieur", true, false) as Interieur
	return i.demi
