extends SceneTree
## Essai Tripo : le mage Tripo (scripts/mage_tripo.gd) à côté du mage actuel (MageNordique, option "ancien") et d'un garde Tripo (épée), dans la scène
## forêt/village. Deux modes (argument --mode=) :
##   photos : planche face / profil / dos / 3-4 (planche.png) + vues séparées + vues au crépuscule et de nuit
##   film   : idle -> marche vers la caméra -> incantation (Spell_Simple_Enter / Idle / Shoot / Exit) du mage Tripo, les deux autres en idle
##   godot --path . [--write-movie f.avi --fixed-fps 30] --resolution 960x540 --script res://outils/film_tripo_mage.gd -- --mode=photos|film --nouvelle --sortie=<dossier>
const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var j: CharacterBody3D
var cam: Camera3D
var modeles: Array = []       # [mage actuel, mage Tripo, garde Tripo] de gauche à droite (vus de face)
var origine := Vector3.ZERO
var lat := Vector3.RIGHT      # axe latéral de la caméra
var dirc := Vector3.FORWARD   # direction caméra -> sujets
var img := 0

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _pf() -> void:
	img += 1
	if img % 15 == 0:
		_cacher()
	await process_frame

func _cacher() -> void:
	for n in get_nodes_in_group("villageois"):
		if n is Node3D:
			(n as Node3D).visible = false
	if m.get("dialogue") != null and m.dialogue.get("_invite") != null:
		m.dialogue._invite.visible = false

func _att(sec: float) -> void:
	for i in roundi(sec * 30.0):
		await _pf()

func _heure(h: float) -> void:
	m.cycle.heure = h
	m.cycle._process(0.0)

func _sol(p: Vector3) -> Vector3:
	return Vector3(p.x, m.hauteur(p.x, p.z), p.z)

func _fixe(nom: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.save_png(_arg("sortie", "user://mage").path_join(nom + ".png"))

func _cap(n: Node3D, d: Vector3) -> void:
	n.rotation.y = atan2(d.x, d.z)

func _jouer(n: Node3D, clip: String, fondu := 0.15) -> void:
	var ap: AnimationPlayer = n.find_child("Animations", true, false)
	if ap != null and ap.has_animation(clip):
		ap.play(clip, fondu)

func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_arg("sortie", "user://mage"))
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
		if m == null:
			m = sc if sc.get("pret") != null else null
	j = m.joueur
	j.mort = false
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	for n in get_nodes_in_group("villageois"):
		if n.get("_delai_interpelle") != null:
			n._delai_interpelle = 99999.0
	for c in j.camera.get_children():
		if c is Node3D:
			c.visible = false
	if m.get("vie") != null:
		m.vie.set_process(false)
	if m.get("dialogue") != null:
		m.dialogue.set_process(false)
	_cacher()
	_heure(11.0)
	await _att(2.0)
	# emplacement : place libre du village (autour de l'habitant « hab_mage_tripo »), soleil dans le dos de la caméra, 3 voies de 1,5 m et 5 m de recul
	var v: Node3D = null
	while v == null:
		for n in get_nodes_in_group("villageois"):
			if n.get("donnees") is Dictionary and n.donnees.get("id") == "hab_mage_tripo":
				v = n
		if v == null:
			await process_frame
	var dl: Vector3 = -m.cycle.lumiere.global_transform.basis.z
	var sun_h := Vector3(dl.x, 0.0, dl.z).normalized()
	var cand: Array = []
	for dx in range(-14, 15, 2):
		for dz in range(-14, 15, 2):
			cand.append(Vector3(dx, 0, dz))
	cand.sort_custom(func(a1: Vector3, b1: Vector3) -> bool: return a1.length() < b1.length())
	var trouve := false
	for seuil in [0.5, -2.0]:
		for off: Vector3 in cand:
			var s0 := _sol(v.global_position + off)
			for k in 16:
				var d := Vector3(sin(k * TAU / 16.0), 0.0, cos(k * TAU / 16.0))
				if d.dot(sun_h) < seuil:
					continue
				var l2 := Vector3(d.z, 0.0, -d.x)
				var ok: bool = v.chemin_libre(s0 - d * 5.5, s0 + d * 1.5)
				for dec in [-2.0, 0.0, 2.0]:
					ok = ok and v.chemin_libre(s0 + l2 * dec - d * 2.0, s0 + l2 * dec + d * 3.5)
				ok = ok and m.hauteur(s0.x, s0.z) > -50.0 and absf(m.hauteur(s0.x, s0.z) - m.hauteur(s0.x - d.x * 5.0, s0.z - d.z * 5.0)) < 0.8
				if ok:
					origine = s0
					dirc = d
					lat = l2
					trouve = true
					break
			if trouve:
				break
		if trouve:
			break
	print("PLACE %s cap %s" % [origine, dirc])
	if not trouve:
		push_error("aucune place libre")
		quit(1)
		return
	var mc := MageNordique.creer({"ancien": true})
	mc.name = "MageActuel"
	var mt := MageTripo.creer({})
	var gt := GardeTripo.creer("tripo_garde_epee")
	modeles = [mc, mt, gt]
	var offs := [1.5, 0.0, -1.5]
	for i in 3:
		m.add_child(modeles[i])
		modeles[i].global_position = _sol(origine + lat * offs[i])
		_jouer(modeles[i], "Idle")
	cam = Camera3D.new()
	cam.fov = 38.0
	m.add_child(cam)
	cam.current = true
	if _arg("mode", "photos") == "photos":
		await _photos()
	else:
		await _film()
	print("FIN %d" % img)
	quit(0)

func _poser_cam(dist: float, haut := 1.25) -> void:
	var c := _sol(origine) + Vector3(0, haut, 0)
	var pos := _sol(origine) - dirc * dist
	cam.global_position = Vector3(pos.x, m.hauteur(pos.x, pos.z) + 1.5, pos.z)
	cam.look_at(c, Vector3.UP)

func _orienter(deg: float) -> void:
	# deg = 0 : de face (les sujets regardent la caméra) ; 90 : de profil ; 180 : de dos
	var d := (-dirc).rotated(Vector3.UP, deg_to_rad(deg))
	for n: Node3D in modeles:
		_cap(n, d)

func _photos() -> void:
	_poser_cam(4.4)
	var vues := {"face": 0.0, "profil": 90.0, "dos": 180.0, "trois_quarts": 40.0}
	for nom: String in vues:
		_orienter(vues[nom])
		await _att(0.5)
		await _fixe(nom)
	# planche 2x2
	var ims := []
	for nom: String in ["face", "profil", "dos", "trois_quarts"]:
		var im := Image.load_from_file(_arg("sortie", "user://mage").path_join(nom + ".png"))
		im.convert(Image.FORMAT_RGBA8)
		ims.append(im)
	var w: int = ims[0].get_width()
	var h: int = ims[0].get_height()
	var pl := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for k in 4:
		pl.blit_rect(ims[k], Rect2i(0, 0, w, h), Vector2i((k % 2) * w, (k / 2) * h))
	pl.save_png(_arg("sortie", "user://mage").path_join("planche.png"))
	# lumière : crépuscule et nuit, de face, gros plan sur le mage Tripo
	_orienter(0.0)
	for hh in [17.5, 20.5, 8.0]:
		_heure(hh)
		await _att(0.6)
		await _fixe("lumiere_%02d" % int(hh))
	_heure(11.0)
	_poser_cam(2.6, 1.45)
	# gros plan sur le mage Tripo
	var c := _sol(modeles[1].global_position) + Vector3(0, 1.45, 0)
	cam.look_at(c, Vector3.UP)
	cam.global_position = _sol(modeles[1].global_position) - dirc * 2.2 + Vector3(0, 1.0, 0)
	cam.look_at(c, Vector3.UP)
	await _att(0.5)
	await _fixe("gros_plan_mage")
	_heure(11.0)

func _film() -> void:
	var mt: Node3D = modeles[1]
	var depart := _sol(origine + dirc * 5.0)
	_poser_cam(4.4)
	_orienter(0.0)
	modeles[0].visible = true
	# 1. idle de face (3 s)
	print("PLAN idle debut %d" % img)
	await _att(3.0)
	# 2. marche : le mage Tripo s'éloigne vers le fond puis revient (profil puis face), les autres restent
	print("PLAN marche debut %d" % img)
	_jouer(mt, "Walk")
	var base := mt.global_position
	var fond := base + dirc * 3.0
	_cap(mt, dirc)
	var t := 0.0
	while t < 2.2:
		mt.global_position += dirc * 1.3 / 30.0
		mt.global_position.y = m.hauteur(mt.global_position.x, mt.global_position.z)
		await _pf()
		t += 1.0 / 30.0
	_cap(mt, -dirc)
	t = 0.0
	while t < 2.2:
		mt.global_position -= dirc * 1.3 / 30.0
		mt.global_position.y = m.hauteur(mt.global_position.x, mt.global_position.z)
		await _pf()
		t += 1.0 / 30.0
	# profil : passage latéral
	_cap(mt, lat)
	t = 0.0
	while t < 1.6:
		mt.global_position += lat * 1.3 / 30.0
		mt.global_position.y = m.hauteur(mt.global_position.x, mt.global_position.z)
		await _pf()
		t += 1.0 / 30.0
	mt.global_position = _sol(base)
	_cap(mt, -dirc)
	_jouer(mt, "Idle")
	await _att(0.6)
	# 3. incantation
	print("PLAN incantation debut %d" % img)
	_jouer(mt, "Spell_Simple_Enter", 0.1)
	await _att(1.1)
	_jouer(mt, "Spell_Simple_Idle", 0.1)
	await _att(1.0)
	_jouer(mt, "Spell_Simple_Shoot", 0.05)
	await _att(1.0)
	_jouer(mt, "Spell_Simple_Exit", 0.1)
	await _att(1.2)
	_jouer(mt, "Idle")
	await _att(0.8)
