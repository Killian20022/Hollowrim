extends SceneTree
## Retours exe 5 (« dans les maisons les murs ne sont pas droits et font des vagues ») : captures et film d'un mur intérieur,
## caméra fixe et proche, pour juger la droiture des rangs et la tenue de la surface quand on se déplace.
##   godot --path . --resolution 1280x720 --script res://outils/capture_murs.gd -- --nouvelle --sans-mains --bats=h1,h3,h4 --sortie=<dossier> [--film] [--sans-grille] [--sans-relief] [--tex-unie]
## Avec --film : à lancer avec --write-movie <f.avi> --fixed-fps 30 ; glissement latéral de 0,8 m face au mur du fond de la 1re maison.
## Sans --film : par maison, deux PNG (face au mur du fond, puis en enfilade le long du mur).
## --exterieur : les mêmes murs vus du dehors (3,2 m).
## Bascules de diagnostic : --sans-grille (accroche des sommets coupée), --sans-relief (relief de texture coupé), --tex-unie
## (texture remplacée par un gris uni : seule la géométrie reste visible).
const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var j: CharacterBody3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.split("=", true, 1)[1]
	return defaut

func _drapeau(nom: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + nom)

## Caméra (œil) au point `p` du repère de l'intérieur, regardant `c` (repère de l'intérieur).
func _cam(ip: Interieur, p: Vector3, c: Vector3) -> void:
	var g := ip.to_global(Vector3(p.x, ip.sol_y + 0.02, p.z))
	j.global_position = g
	j.velocity = Vector3.ZERO
	var oeil := g + Vector3(0, j.tete.position.y, 0)
	var d := ip.to_global(c) - oeil
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

## Applique les bascules de diagnostic aux matières d'intérieur sous `n`.
func _bascules(n: Node) -> void:
	var unie: ImageTexture = null
	if _drapeau("tex-unie"):
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.55, 0.45, 0.36))
		unie = ImageTexture.create_from_image(img)
	for mi in n.find_children("*", "GeometryInstance3D", true, false):
		var mats: Array = []
		if mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null:
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				mats.append((mi as MeshInstance3D).get_active_material(s))
		for mat in mats:
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null and String((mat as ShaderMaterial).shader.resource_path).contains("ps1_interieur"):
				var sm := mat as ShaderMaterial
				if _drapeau("sans-grille"):
					sm.set_shader_parameter("grille", 0.0)
				if _drapeau("sans-relief"):
					sm.set_shader_parameter("relief", 0.0)
				if unie != null:
					sm.set_shader_parameter("tex_base", unie)

func _photo(chemin: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(chemin)
	print("PHOTO ", chemin)

func _preparer(ip: Interieur) -> void:
	var a := ip.demi
	_cam(ip, Vector3(0.0, 0, -a.y + 1.3), Vector3(0.0, ip.sol_y + 1.3, -a.y))
	for i in 40:
		await process_frame
	if not ip.construit:
		m.village.construire_interieur_maintenant(ip)
	for i in 20:
		await process_frame
	_bascules(ip)

func _go() -> void:
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
	j = m.joueur
	j.mort = false
	j.vie = 100000.0
	j.set_physics_process(false)
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	m.cycle.heure = float(_arg("heure", "20.0"))
	m.cycle._process(0.0)
	j.camera.fov = 70.0
	var sortie := _arg("sortie", "user://murs")
	DirAccess.make_dir_recursive_absolute(sortie)
	var bats := _arg("bats", "h1,h3,h4").split(",")
	if _drapeau("film"):
		var ip: Interieur = m.village.interieur(bats[0])
		await _preparer(ip)
		var v: String = _arg("vues", "+X").split(",")[0]
		var n := BatimentsOuverts.Murs.normale(v)
		var t := Vector3(-n.z, 0, n.x)
		var mur := -n * (ip.demi.x if absf(n.x) > 0.5 else ip.demi.y)
		print("FILM début (%s, mur %s)" % [ip.id, v])
		var total := 6 * 30
		for i in total + 1:
			var u := smoothstep(0.0, 1.0, float(i) / total)
			var x := lerpf(-0.6, 0.6, u)
			# glissement latéral, regard parallèle à lui-même : seul le point de vue se déplace
			_cam(ip, mur + n * 1.1 + t * x, mur + t * (x + 0.35) + Vector3(0, ip.sol_y + 1.25, 0))
			await process_frame
		print("FILM fini")
		quit(0)
		return
	var vues := _arg("vues", "-Z,+Z,-X,+X").split(",")
	for id in bats:
		var ip: Interieur = m.village.interieur(id)
		await _preparer(ip)
		for v in vues:
			var n := BatimentsOuverts.Murs.normale(v)       # normale du mur, tournée vers la pièce
			var t := Vector3(-n.z, 0, n.x)  # le long du mur
			var plan := ip.demi.x if absf(n.x) > 0.5 else ip.demi.y
			var mur := -n * plan
			if _drapeau("exterieur"):      # dehors, face au même mur
				_cam(ip, mur - n * 3.2 + t * 0.2, mur + t * 0.7 + Vector3(0, ip.sol_y + 1.2, 0))
			else:
				_cam(ip, mur + n * float(_arg("recul", "1.3")) + t * 0.2, mur + t * 0.7 + Vector3(0, ip.sol_y + 1.25, 0))
			for i in 8:
				await process_frame
			await _photo("%s/%s_%s.png" % [sortie, id, v])
	quit(0)
