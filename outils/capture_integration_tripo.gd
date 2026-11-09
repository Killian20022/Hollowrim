extends SceneTree
## Preuves de l'intégration des modèles Tripo (ModelesTripo) : planches de photos dans le vrai jeu (foret_test), fenêtre HORS ÉCRAN (godot_slot.sh).
##   --vue=village : le jarl (villageois « chef ») et les trois gardes Tripo (halle_o, ronde_place, ronde_nord), de face, + plan large.
##   --vue=crypte  : draugr guerrier, archer draugr, squelette (mains nues), archer squelette, dans le vestibule de la crypte, + plan large.
## Avec --modeles-anciens les MÊMES personnages sont pris : planche des anciens corps. Écrit <sortie>/<vue>_<nom>.png et <sortie>/planche_<vue>.png.
##   godot --path . --resolution 960x540 --script res://outils/capture_integration_tripo.gd -- --nouvelle --vue=village [--modeles-anciens] --sortie=<dossier>
const SCENE := "res://scenes/foret_test.tscn"
var m: Node3D
var j: CharacterBody3D
var cam: Camera3D
var sortie := "user://integration_tripo"
var suffixe := ""
var photos: Array = []      # [nom, Image]

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _attendre(n: int) -> void:
	for i in n:
		if is_instance_valid(j):
			j.vie = j.vie_max
		await process_frame

func _photo(nom: String) -> void:
	for cl in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false      # HUD, sous-titres
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.save_png(sortie.path_join("%s%s.png" % [nom, suffixe]))
	photos.append([nom, im])
	print("PHOTO ", nom)

## Caméra à `dist` m devant la cible (son +Z local), à hauteur de poitrine, légèrement en 3/4.
func _cadrer(c: Node3D, dist := 3.0, cote := 0.6, h_oeil := 1.45, h_vise := 1.0) -> void:
	var b := c.global_transform.basis
	var p := c.global_position + b.z.normalized() * dist + b.x.normalized() * cote
	p.y = c.global_position.y + h_oeil
	cam.global_position = p
	cam.look_at(c.global_position + Vector3(0, h_vise, 0), Vector3.UP)

func _figer(n: Node) -> void:
	n.process_mode = Node.PROCESS_MODE_DISABLED

func _planche(vue: String) -> void:
	var w := 480
	var h := 270
	var cols := 3
	var rangs := ceili(photos.size() / float(cols))
	var pl := Image.create(w * cols, h * rangs, false, Image.FORMAT_RGBA8)
	pl.fill(Color(0.05, 0.05, 0.05))
	for i in photos.size():
		var im: Image = (photos[i][1] as Image).duplicate()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_NEAREST)
		pl.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	pl.save_png(sortie.path_join("planche_%s%s.png" % [vue, suffixe]))
	print("PLANCHE ", vue, " ", photos.size(), " photos")

func _go() -> void:
	sortie = _arg("sortie", sortie)
	if OS.get_cmdline_user_args().has("--modeles-anciens"):
		suffixe = "_anciens"
	DirAccess.make_dir_recursive_absolute(sortie)
	Effets.niveau_force = 1
	RetourImpact.muet = true
	var sc := (load(SCENE) as PackedScene).instantiate()
	sc.set_meta("test", true)
	root.add_child(sc)
	current_scene = sc
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
	while not m.village.prets:
		await process_frame
	j = m.joueur
	j.vie_max = 100000.0
	j.vie = 100000.0
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	m.cycle.heure = 11.0
	m.cycle._process(0.0)
	if m.get("hud") != null:
		if "aide_t" in m.hud:
			m.hud.aide_t = 0.0
		m.hud.visible = false
	j.mains.visible = false
	for c in j.camera.get_children():
		if c is Node3D:
			c.visible = false
	var vue := _arg("vue", "village")
	print("CAPTURE vue=", vue, " tripo gardes=", ModelesTripo.actif("gardes"), " jarl=", ModelesTripo.actif("jarl"), " ennemis=", ModelesTripo.actif("ennemis"))
	if vue == "crypte":
		await _crypte()
	else:
		await _village()
	_planche(vue)
	sc.queue_free()      # crypte : sortir avec la scène encore en place bloquait la fermeture
	for i in 5:
		await process_frame
	quit(0)

func _village() -> void:
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.05
	m.add_child(cam)
	cam.make_current()
	await _attendre(120)
	var cibles: Array = []
	for v in get_nodes_in_group("villageois"):
		if "donnees" in v and String(v.donnees.get("id", "")) == "chef" and not v.has_method("alerter"):
			cibles.append(["jarl_chef", v])
	for id in ["halle_o", "ronde_place", "ronde_nord"]:
		for g in m.get_node("GardesVillage").gardes:
			if String(g.donnees.get("id", "")) == id:
				cibles.append(["garde_" + id, g])
	# tous côte à côte sur la place, figés en Idle, tournés vers la caméra (+Z) ; repositionnés avant chaque photo
	var base := Vector3(33.0, 0.0, 43.0)
	for i in cibles.size():
		var n: Node3D = cibles[i][1]
		_figer(n)
		var ap: AnimationPlayer = n.get("anim")
		if ap:
			ap.process_mode = Node.PROCESS_MODE_ALWAYS
			ap.play("Idle")
		print("CIBLE ", cibles[i][0], " corps=", n.modele.name, " tripo=", n.modele.has_meta("pnj_nordique") and String(n.modele.get_meta("pnj_nordique", "")).contains("tripo") or n.modele.scene_file_path.contains("tripo") or String(n.modele.name).to_lower().contains("tripo"))
	j.global_position = Vector3(base.x + 2.4, m.hauteur(base.x + 2.4, base.z + 12.0) + 0.2, base.z + 12.0)
	var aligner := func() -> void:
		for i in cibles.size():
			var n: Node3D = cibles[i][1]
			var x := base.x + i * 1.8
			n.global_position = Vector3(x, m.hauteur(x, base.z) + 0.02, base.z)
			n.rotation.y = 0.0
	aligner.call()
	await _attendre(30)
	for c: Array in cibles:
		aligner.call()
		_cadrer(c[1], 2.6, 0.35)
		await _attendre(4)
		await _photo("village_" + String(c[0]))
	aligner.call()
	cam.fov = 66.0
	var mil := base + Vector3((cibles.size() - 1) * 0.9, 0, 0)
	cam.global_position = Vector3(mil.x + 3.2, m.hauteur(mil.x + 3.2, mil.z + 3.8) + 1.8, mil.z + 3.8)
	cam.look_at(Vector3(mil.x, m.hauteur(mil.x, mil.z) + 1.0, mil.z), Vector3.UP)
	await _attendre(4)
	await _photo("village_ensemble")

func _crypte() -> void:
	for i in 5:
		await physics_frame
	var t = m.tertre
	t._passer(true)
	var t_max := Time.get_ticks_msec() + 30000
	while not t.dedans and Time.get_ticks_msec() < t_max:      # le donjon est bâti sur un fil : la bascule attend qu'il soit prêt
		await process_frame
	await create_timer(1.6, true, false, true).timeout
	print("CRYPTE dedans=", t.dedans)
	var c: Node3D = t.crypte
	j.global_position = c.to_global(Vector3(0.0, 0.1, -21.0))
	j.velocity = Vector3.ZERO
	if j.mains.get("torche_lumiere") != null:
		j.mains.torche_lumiere.visible = true
	for k in 20:
		t._gerer_zones()
		await physics_frame
	for id in m.draugrs.keys():
		var d = m.draugrs[id]
		if is_instance_valid(d):
			d.visible = false
			d.process_mode = Node.PROCESS_MODE_DISABLED
			d.global_position += Vector3(0, -50, 0)
	var lacet := c.global_rotation.y
	var face := Basis(Vector3.UP, lacet).z      # +Z local de la crypte : vers le joueur
	var defs := [["draugr_guerrier", "guerrier", {}], ["draugr_archer", "sbire", {"archer": true}], ["squelette", "squelette", {"variante": "epee"}], ["squelette_archer", "squelette_archer", {}]]
	var cibles: Array = []
	for i in defs.size():
		var dx := -2.4 + i * 1.6
		var pos: Vector3 = c.to_global(Vector3(dx, 0.05, -27.0))
		var opts: Dictionary = (defs[i][2] as Dictionary).duplicate()
		opts["ident"] = "integ_" + String(defs[i][0])
		opts["dort"] = false
		var d: CharacterBody3D = m.creer_draugr(String(defs[i][1]), pos, lacet, false, opts)
		cibles.append([defs[i][0], d])
	await _attendre(20)
	for x: Array in cibles:
		var d: Node3D = x[1]
		_figer(d)
		var ap: AnimationPlayer = d.get("anim")
		if ap:
			ap.process_mode = Node.PROCESS_MODE_ALWAYS
			ap.play("Pistol_Aim_Neutral" if (bool(d.get("archer")) or String(x[0]).ends_with("archer")) and ap.has_animation("Pistol_Aim_Neutral") else ("Sword_Idle" if ap.has_animation("Sword_Idle") else "Idle"))
		d.global_rotation.y = lacet      # face au joueur (+Z de la crypte)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.05
	m.add_child(cam)
	cam.make_current()
	var lum := OmniLight3D.new()      # torche d'appoint (la crypte est noire hors torches)
	lum.omni_range = 9.0
	lum.light_energy = 1.6
	lum.light_color = Color(1.0, 0.78, 0.55)
	m.add_child(lum)
	await _attendre(10)
	for x: Array in cibles:
		var d: Node3D = x[1]
		cam.global_position = d.global_position + face * 2.4 + Vector3(0, 1.4, 0) + Basis(Vector3.UP, lacet).x * 0.35
		cam.look_at(d.global_position + Vector3(0, 1.0, 0), Vector3.UP)
		lum.global_position = cam.global_position + Vector3(0, 0.6, 0)
		await _attendre(4)
		await _photo("crypte_" + String(x[0]))
	var mil: Vector3 = c.to_global(Vector3(0.0, 0.05, -27.0))
	cam.global_position = mil + face * 6.0 + Vector3(0, 1.9, 0)
	cam.look_at(mil + Vector3(0, 1.0, 0), Vector3.UP)
	lum.global_position = cam.global_position + Vector3(0, 0.5, 0)
	await _attendre(4)
	await _photo("crypte_ensemble")
