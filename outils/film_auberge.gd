extends SceneTree
## Auberge h2 « la Chope » (chaumière + taverne Tripo, reprise G2 de l'audit 2026-11-10) : vues fixes avant/après, MÊME cadrage
## (repère de l'intérieur `h2`, indépendant de la taille du modèle), un garde posé à côté de la porte pour l'échelle, intérieur de
## jour (13 h) et de nuit (23 h) à hauteur d'homme (œil à 1,7 m), gros plans des texels.
##   godot --path . --resolution 960x540 --script res://outils/film_auberge.gd -- --nouvelle --sans-mains --paisible --sortie=<dossier>
## Imprime « AUBERGE … » (emprise de l'intérieur, porte, position des PNJ de la maison).
const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var cam: Camera3D
var sortie := "user://film_auberge"
var ip: Interieur
var garde: Node3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return ""

func _attendre(n: int) -> void:
	for i in n:
		await process_frame

func _shot(nom: String) -> void:
	await _attendre(8)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(sortie.path_join(nom + ".png"))
	print("CAPTURE ", nom)

func _poser(oeil: Vector3, vise: Vector3) -> void:
	cam.global_transform = Transform3D(Basis.looking_at(vise - oeil, Vector3.UP), oeil)

## Point du repère de l'intérieur (porte en +Z), `y` compté depuis le sol réel du dehors sous ce point.
func _dehors(x: float, y: float, z: float) -> Vector3:
	var g := ip.to_global(Vector3(x, 0, z))
	return Vector3(g.x, m.hauteur(g.x, g.z) + y, g.z)

func _monde(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, m.hauteur(x, z) + y, z)

func _dedans(x: float, y: float, z: float) -> Vector3:
	return ip.to_global(Vector3(x, ip.sol_y + y, z))

func _heure(h: float) -> void:
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	m.cycle.heure = h
	m.cycle._process(0.0)
	var vie: Vie = m.vie
	vie._heure_prec = -1.0
	vie.tick()

func _go() -> void:
	if _arg("sortie") != "":
		sortie = _arg("sortie")
	DirAccess.make_dir_recursive_absolute(sortie)
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
	var t0 := Time.get_ticks_msec()
	while not m.village.prets and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	await _attendre(120)
	if m.get("hud") != null:
		m.hud.visible = false
	if m.get("dialogue") != null:
		m.dialogue.visible = false
	m.joueur.mains.visible = false
	m.joueur.vie = 1.0e6
	m.joueur.set_physics_process(false)
	m.joueur.visible = false
	cam = Camera3D.new()
	m.add_child(cam)
	cam.current = true
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 300.0
	ip = m.village.interieur("h2")
	if ip == null:
		print("AUBERGE pas d'intérieur h2")
		quit(1)
		return
	var zp := ip.porte_locale.z
	print("AUBERGE demi=%s porte=%s sol_y=%.2f haut_max=%s" % [ip.demi, ip.porte_locale, ip.sol_y, ip.get_meta("haut_max", "?")])
	# garde à 1,6 m à droite de la porte (vu du dehors), 1,2 m devant, face au dehors
	garde = GardesVillage.creer_modele({"taille": 1.0, "largeur": 1.0})
	m.add_child(garde)
	garde.global_position = _dehors(1.7, 0.0, zp + 1.3)
	garde.global_rotation.y = ip.global_rotation.y
	_heure(13.0)
	m.joueur.global_position = _dehors(0, 0.2, zp + 6.0)
	await _attendre(60)
	# vue de dessus (orthographique, 44 m), porte vers le bas de l'image
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 44.0
	var c0 := _dehors(0, 0, 0)
	cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, ip.global_basis * Vector3.FORWARD), c0 + Vector3(0, 30, 0))
	var env: Environment = m.get_viewport().find_world_3d().environment if m.get_viewport().find_world_3d().environment != null else null
	for we: WorldEnvironment in m.find_children("*", "WorldEnvironment", true, false):
		env = we.environment
	var brume := env != null and env.fog_enabled
	var vol := env != null and env.volumetric_fog_enabled
	if env != null:
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
	await _shot("plan")
	if env != null:
		env.fog_enabled = brume
		env.volumetric_fog_enabled = vol
	if OS.get_cmdline_user_args().has("--seulement-plan"):
		quit(0)
		return
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	# --- dehors (repère de la porte : x à droite vu du dehors, z vers le dehors) ---------------------------------
	cam.fov = 55.0
	_poser(_dehors(-3.0, 4.5, zp + 19.0), _dehors(0, 2.2, 0))
	await _shot("ext_loin")
	_poser(_dehors(-1.0, 1.7, zp + 11.0), _dehors(0.5, 1.9, zp))
	await _shot("ext_homme")
	_poser(_dehors(-12.0, 3.0, zp + 8.0), _dehors(0, 2.5, 0))
	await _shot("ext_biais")
	# cadrages FIXES (monde), identiques avant/après quel que soit l'emplacement de l'auberge : depuis la place (homme), et de haut
	_poser(_monde(47.0, 1.7, 38.0), _monde(52.5, 2.6, 52.0))
	await _shot("fixe_place")
	_poser(_monde(42.0, 9.0, 36.0), _monde(52.5, 1.5, 52.5))
	await _shot("fixe_haut")
	cam.fov = 50.0
	_poser(_dehors(-0.6, 1.7, zp + 4.5), _dehors(0.6, 1.4, zp))
	await _shot("ext_porte")
	cam.fov = 30.0
	_poser(_dehors(0.0, 1.6, zp + 2.6), _dehors(0.0, 1.5, zp))
	await _shot("gros_facade")
	# --- dedans : on attend la construction (à la demande) ------------------------------------------------------
	m.joueur.global_position = _dedans(0, 0.2, zp - 1.0)
	t0 = Time.get_ticks_msec()
	while (not ip.construit or ip.en_cours) and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	await _attendre(120)
	for h in [13.0, 23.0]:
		_heure(h)
		await _attendre(150)
		var suf := "jour" if h < 20.0 else "nuit"
		_pnj(suf)
		cam.fov = 70.0
		var dx := ip.demi.x
		var dz := ip.demi.y
		_poser(_dedans(0.0, 1.7, zp - 0.6), _dedans(0.0, 1.2, -dz))
		await _shot("int_entree_" + suf)
		_poser(_dedans(dx * 0.5, 1.7, dz * 0.4), _dedans(-dx, 1.2, -dz * 0.5))
		await _shot("int_salle_" + suf)
		_poser(_dedans(-dx * 0.5, 1.7, -dz * 0.3), _dedans(dx, 1.2, dz * 0.4))
		await _shot("int_retour_" + suf)
		_poser(_dedans(0.0, 1.7, 0.0), _dedans(0.0, 2.6, -dz))
		await _shot("int_haut_" + suf)
		if suf == "jour":
			cam.fov = 35.0
			_poser(_dedans(dx * 0.3, 1.6, 0.0), _dedans(-dx, 1.0, -dz * 0.2))
			await _shot("gros_texels")
	print("CAPTURES finies")
	quit(0)

func _pnj(suf: String) -> void:
	for c: Dictionary in m.vie.civils:
		var id := String(c["id"])
		if String(c["f"].get("maison", "")) == "h2" or ip.habitants.has(id):
			var n: Node3D = c["n"]
			var loc := ip.to_local(n.global_position)
			print("AUBERGE %s %s mode=%s dedans=%s local=%s visible=%s" % [suf, id, c["mode"], ip.dedans(loc, 0.1), loc, n.visible])
