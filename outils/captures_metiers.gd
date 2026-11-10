extends SceneTree
## Captures du lot vie/metiers (fenêtre hors écran via godot_slot.sh) :
##   planche : 6 PNJ à leur métier, caméra 1re personne à hauteur d'homme, une case chacun (+ gros plans) -> <sortie>/planche_metiers.png
##     godot --path . --resolution 960x540 --script res://outils/captures_metiers.gd -- --nouvelle --sans-mains --mode=planche --sortie=<dossier>
##   film : causerie sur la place (Eirwen rejoint Sigrún), sous-titres -> --write-movie <f.avi> --fixed-fps 30
##     godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/captures_metiers.gd -- --nouvelle --sans-mains --mode=film
##   --ids=a,b,… : PNJ de la planche ; --plan=id:az:dist : angle (degrés autour du PNJ, 0 = devant lui) et distance d'un plan.
const SCENE := "res://scenes/foret_test.tscn"
## [id, étiquette, index d'étape à montrer, angle autour du PNJ (deg, 0 = face), distance (m), temps dans l'étape (s)]
const PLANS := [
	["forgeron", "Brodd, forgeron : à genoux à l'enclume", 0, 70.0, 2.6, 2.0, Vector2(28.6, 37.2)],
	["hab_paysan_3", "Marchand derrière son étal", 1, 0.0, 2.4, 0.45, Vector2(51.3, 32.7)],
	["ancienne", "Grima tire l'eau du puits", 1, 80.0, 2.6, 0.9],
	["hab_paysan_2", "Le vieux, assis sur le banc", 0, 20.0, 2.3, 2.0],
	["hab_chasseur_2", "Chasseur au tas de bois", 2, 0.0, 2.4, 2.0, Vector2(55.0, 52.6)],
	["hab_paysanne_3", "Lavandière au bord de l'eau", 0, 75.0, 2.6, 2.0],
	["chef", "Gunnar Aldrsson (Tripo), longue maison", 1, 25.0, 2.3, 0.9],
	["hab_mage_tripo", "Mage Eirwen (Tripo) lit les runes", 1, 15.0, 2.3, 1.5, Vector2(38.7, 40.2)],
]
var m: Node3D
var j: CharacterBody3D
var vie: Vie
var etiquette: Label

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return d

func _cam(pos: Vector3, cible: Vector3) -> void:
	j.global_position = pos
	j.velocity = Vector3.ZERO
	var d := cible - (pos + Vector3(0, j.tete.position.y, 0))
	j.rotation.y = atan2(-d.x, -d.z)
	j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _go() -> void:
	var sc := (load(SCENE) as PackedScene).instantiate()
	root.add_child(sc)
	m = sc if sc.get("pret") != null else sc.find_child("Monde", true, false)
	while m == null or m.get("pret") != true:
		await process_frame
	j = m.joueur
	j.mort = false
	j.vie = 100000.0
	if m.get("hud") != null:
		m.hud.visible = false
	j.mains.visible = false
	for i in 90:
		await process_frame
	vie = m.get_node("Vie")
	m.cycle.process_mode = Node.PROCESS_MODE_DISABLED
	m.cycle.heure = float(_arg("heure", "10.5"))
	m.cycle._process(0.0)
	vie.tick()
	var calque := CanvasLayer.new()
	calque.layer = 50
	root.add_child(calque)
	etiquette = Label.new()
	etiquette.position = Vector2(10, 8)
	etiquette.add_theme_font_size_override("font_size", 18)
	etiquette.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	etiquette.add_theme_color_override("font_outline_color", Color.BLACK)
	etiquette.add_theme_constant_override("outline_size", 5)
	calque.add_child(etiquette)
	for i in 60:
		await process_frame
	if _arg("mode", "planche") == "film":
		await _film()
	else:
		await _planche()
	quit()

func _planche() -> void:
	var sortie := _arg("sortie", ProjectSettings.globalize_path("res://captures/metiers"))
	DirAccess.make_dir_recursive_absolute(sortie)
	vie.conversations._prochain = 1.0e9
	if m.get("dialogue") != null:
		m.dialogue.visible = false      # ni sous-titres d'interpellation ni invite « E Parler » sur la planche
	var ids := _arg("ids", "").split(",", false)
	var cases: Array[Image] = []
	var plans: Array = PLANS.duplicate(true)
	# --essais=id:x,z;x,z : plusieurs caméras d'essai pour un même PNJ (images <id>_e<k>.png)
	var es := _arg("essais", "")
	if es != "":
		var id_e := es.get_slice(":", 0)
		var base: Array = []
		for p: Array in PLANS:
			if p[0] == id_e:
				base = p
		plans = []
		var k := 0
		for xz in es.get_slice(":", 1).split(";", false):
			var q := base.duplicate()
			q.resize(8)
			q[6] = Vector2(float(xz.get_slice(",", 0)), float(xz.get_slice(",", 1)))
			q[7] = "%s_e%d" % [id_e, k]
			plans.append(q)
			k += 1
		ids = []
	for p: Array in plans:
		if not ids.is_empty() and not String(p[0]) in ids:
			continue
		var c := vie.civil(String(p[0]))
		if c.is_empty():
			print("absent : ", p[0])
			continue
		var n: Node3D = c["n"]
		# l'étape montrée, figée au temps voulu
		var et: Array = n.metier.get("etapes", [])
		if not et.is_empty():
			n._m_i = int(p[2]) % et.size()
			n._m_t = 1000.0
			n._anim = ""
			n._jouer(String(et[n._m_i]["clip"]), 0.0)
		var face := n.global_transform.basis.z
		face.y = 0.0
		face = face.normalized()
		var bas: bool = n.assis() or n._anim in ["Fixing_Kneeling", "Crouch_Idle"]
		var cible := n.global_position + Vector3(0, 0.75 if bas else 1.0, 0)
		var cp := Vector3.ZERO
		if p.size() > 6 and p[6] != null:
			var c2: Vector2 = p[6]
			cp = Vector3(c2.x, float(m.hauteur(c2.x, c2.y)) + 0.05, c2.y)
		# premier angle d'où l'on voit le PNJ (aucun mur entre l'œil et lui, ni l'œil dans un mur)
		for daz in ([] if cp != Vector3.ZERO else [0.0, 35.0, -35.0, 70.0, -70.0, 110.0, -110.0]):
			for k in [1.0, 0.8, 1.2]:
				var dir: Vector3 = face.rotated(Vector3.UP, deg_to_rad(float(p[3]) + float(daz)))
				var q: Vector3 = n.global_position + dir * float(p[4]) * float(k)
				q.y = float(m.hauteur(q.x, q.z)) + 0.05
				if _vue_libre(q + Vector3(0, j.tete.position.y, 0), cible, n):
					cp = q
					break
			if cp != Vector3.ZERO:
				break
		if cp == Vector3.ZERO:
			print("pas de vue libre : ", p[0])
			var q2 := n.global_position + face * float(p[4])
			cp = Vector3(q2.x, float(m.hauteur(q2.x, q2.z)) + 0.05, q2.z)
		for i in 20:
			await process_frame
			_cam(cp, cible)
		n._anim = ""
		n._jouer(String(et[n._m_i]["clip"]) if not et.is_empty() else "Idle", 0.0)
		n.anim.seek(float(p[5]), true)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 120:
			await process_frame
		n.anim.seek(float(p[5]), true)
		etiquette.text = String(p[1])
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_png(sortie.path_join("%s.png" % (p[7] if p.size() > 7 and p[7] != null else p[0])))
		cases.append(img)
		print("plan ", p[0], " clip ", n._anim, " pos ", n.global_position)
	if cases.is_empty():
		return
	var w := cases[0].get_width() / 2
	var h := cases[0].get_height() / 2
	var col := 2
	var rangs := ceili(cases.size() / float(col))
	var planche := Image.create(w * col, h * rangs, false, Image.FORMAT_RGB8)
	for i in cases.size():
		var im := cases[i].duplicate() as Image
		im.resize(w, h, Image.INTERPOLATE_NEAREST)
		planche.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % col) * w, (i / col) * h))
	planche.save_png(sortie.path_join("planche_metiers.png"))
	print("PLANCHE ", sortie.path_join("planche_metiers.png"))

func _vue_libre(oeil: Vector3, cible: Vector3, n: Node3D) -> bool:
	var es := j.get_world_3d().direct_space_state
	var excl: Array[RID] = [j.get_rid(), (n as CollisionObject3D).get_rid()]
	for ab in [[oeil, cible], [cible, oeil]]:
		var rq := PhysicsRayQueryParameters3D.create(ab[0], ab[1])
		rq.exclude = excl
		rq.hit_from_inside = true
		if not es.intersect_ray(rq).is_empty():
			return false
	# l'œil n'est pas dans un volume (mur, toit) : petite sphère
	var sp := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.35
	sp.shape = sh
	sp.transform = Transform3D(Basis(), oeil)
	sp.exclude = excl
	return es.intersect_shape(sp, 1).is_empty()

func _film() -> void:
	var sig: Node3D = vie.civil("volva")["n"]
	var eir: Node3D = vie.civil("hab_mage_tripo")["n"]
	var cv := vie.conversations
	cv._prochain = 1.0e9
	for v: Node in m.get_tree().get_nodes_in_group("villageois"):
		v.set("_delai_interpelle", 30.0)     # mise en scène : pas d'interpellation du joueur avant la causerie (pendant, elles sont coupées par le jeu)
	var axe := (eir.global_position - sig.global_position)
	axe.y = 0.0
	axe = axe.normalized()
	var mil := sig.global_position + axe * 0.65          # milieu de la causerie : Eirwen rejoint Sigrún à 1,3 m
	var cote := axe.cross(Vector3.UP)
	var puits := Vector3(42.0, mil.y, 38.0)
	if (mil + cote).distance_to(puits) < (mil - cote).distance_to(puits):
		cote = -cote                                       # du côté opposé au puits
	var cp := mil + cote * float(_arg("recul", "3.0")) + axe * 0.8
	cp.y = float(m.hauteur(cp.x, cp.z)) + 0.05
	var vise := mil + axe * 0.5 + Vector3(0, 1.25, 0)
	_cam(cp, vise)
	cv.ligne_dite.connect(func(nom: String, t: String, idx: String) -> void: print("REPLIQUE %s : %s (%s)" % [nom, t, idx]))
	var total := int(float(_arg("duree", "16")) * 30.0)
	for i in total:
		if i == 30:
			print("causerie lancée : ", cv.forcer("hab_mage_tripo", "volva"))
		_cam(cp, vise)
		await process_frame
