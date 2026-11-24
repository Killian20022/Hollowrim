extends SceneTree
## Film « casse réaliste » (2026-11-24) : bûche, chaise, tonneau, jarre, sac et pelle lancés contre un mur, côte à côte, deux fois :
## lancer DOUX (4 m/s : la bûche, la chaise, le sac et la pelle rebondissent, la jarre et le tonneau cèdent) puis lancer VIOLENT (10 m/s :
## chacun casse À SA MANIÈRE : bûche fendue en 2, chaise démontée par pièces, tonneau en douelles, jarre en tessons, sac déchiré, pelle cassée net).
## Même chaîne qu'en jeu : CasseObjets.morceaux / eclater / effets, seuils de MATIERES.
##   godot --path . --fixed-fps 30 --disable-vsync --script res://outils/film_casse_realiste.gd -- --sortie=<dossier> [--planche=<dossier>]

const NOMS := [["q_buche", "buche", 4.0, "Bûche"], ["q_chaise", "meuble_leger", 6.0, "Chaise"], ["q_tonneau", "tonneau", 40.0, "Tonneau"],
	["q_jarre", "poterie", 4.0, "Jarre"], ["q_sac", "tissu", 25.0, "Sac"], ["q_pelle", "bois_outil", 2.5, "Pelle"]]
const ECART := 1.55
const MUR_Z := -5.0

var sortie := ""
var planche := ""
var n := 0
var cam: Camera3D
var legende: Label
var objets := []
var arene: Node3D

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _image() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/f_%05d.png" % [sortie, n])
	n += 1

func _filmer(k: int) -> void:
	for i in k:
		await _image()

func _statique(parent: Node, pos: Vector3, taille: Vector3, couleur: Color) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = taille
	cs.shape = bx
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	mi.material_override = m
	b.add_child(mi)
	parent.add_child(b)
	b.position = pos

func _monter() -> void:
	arene = Node3D.new()
	root.add_child(arene)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.20, 0.26, 0.36)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.64, 0.72)
	e.ambient_light_energy = 0.9
	env.environment = e
	arene.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -25, 0)
	sol.light_energy = 1.0
	arene.add_child(sol)
	_statique(arene, Vector3(0, -0.25, 0), Vector3(20, 0.5, 14), Color(0.22, 0.30, 0.20))
	_statique(arene, Vector3(0, 2.0, MUR_Z - 0.25), Vector3(20, 4.5, 0.5), Color(0.62, 0.55, 0.46))
	cam = Camera3D.new()
	cam.fov = 52.0
	arene.add_child(cam)
	cam.position = Vector3(0, 1.9, 3.2)
	cam.look_at(Vector3(0, 0.55, -2.0))
	cam.current = true
	var cl := CanvasLayer.new()
	arene.add_child(cl)
	legende = Label.new()
	legende.position = Vector2(10, 6)
	legende.add_theme_font_size_override("font_size", 18)
	legende.add_theme_color_override("font_outline_color", Color.BLACK)
	legende.add_theme_constant_override("outline_size", 5)
	cl.add_child(legende)

func _poser(rang: int, vitesse: float) -> void:
	var nom: String = NOMS[rang][0]
	var matiere: String = NOMS[rang][1]
	var masse: float = NOMS[rang][2]
	var M := ObjetsVivants.materiaux_interieur()
	var morc := ObjetsVivants.morceaux_q(nom, func(m: String) -> Material: return M.get(m, M["bois"]))
	var bb := ObjetsVivants.boite_morceaux(morc)
	var am := ArrayMesh.new()
	for m: Array in morc:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m[0])
		am.surface_set_material(am.get_surface_count() - 1, m[1])
	var b := RigidBody3D.new()
	b.collision_layer = 0
	b.collision_mask = 1
	b.mass = masse
	b.contact_monitor = true
	b.max_contacts_reported = 4
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = bb.size
	cs.shape = bx
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.position = -bb.get_center()
	b.add_child(mi)
	arene.add_child(b)
	var x := (rang - 2.5) * ECART
	b.position = Vector3(x, bb.size.y * 0.5 + 0.45, 1.5)
	b.linear_velocity = Vector3(0, 2.2, -vitesse)      # petit arc : il arrive sur le mur à mi-hauteur
	b.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)) * 0.5
	var lab := Label3D.new()
	lab.text = String(NOMS[rang][3])
	lab.pixel_size = 0.006
	lab.font_size = 48
	lab.outline_size = 10
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	arene.add_child(lab)
	lab.position = Vector3(x, 1.7, MUR_Z + 0.3)
	var o := {"b": b, "mi": mi, "bb": bb, "mat": matiere, "masse": masse, "mesh": am, "casse": false, "v": b.linear_velocity, "nom": NOMS[rang][3], "lab": lab}
	objets.append(o)
	b.body_entered.connect(func(_c: Node) -> void: _contact(o))

func _contact(o: Dictionary) -> void:
	if o["casse"]:
		return
	var b: RigidBody3D = o["b"]
	var v: Vector3 = o["v"]
	var e := CasseObjets.energie(v, float(o["masse"]))
	if e >= CasseObjets.seuil(String(o["mat"])):
		o["casse"] = true
		var xf: Transform3D = (o["mi"] as MeshInstance3D).global_transform
		var pt := b.global_position + v.normalized() * 0.2
		b.visible = false
		b.collision_mask = 0
		b.set_deferred("freeze", true)
		var res := CasseObjets.eclater(arene, o["mesh"], xf, String(o["mat"]), float(o["masse"]), pt, v * 0.3, 7)
		var t: Vector3 = (o["bb"] as AABB).size
		CasseObjets.effets(arene, b.global_position, b.global_position - Vector3(0, t.y * 0.5, 0), pt, String(o["mat"]), maxf(t.x, maxf(t.y, t.z)))
		print("FILM %s : %.0f J >= %.0f J -> %d morceaux" % [o["nom"], e, CasseObjets.seuil(String(o["mat"])), res.size()])
	else:
		CasseObjets.son_choc(arene, String(o["mat"]), b.global_position, e)
		print("FILM %s : %.0f J < %.0f J -> rebondit" % [o["nom"], e, CasseObjets.seuil(String(o["mat"]))])

func _manche(titre: String, vitesse: float, images: int, cliche: String, i_cliche: int) -> void:
	legende.text = titre
	for o: Dictionary in objets:
		(o["lab"] as Node).queue_free()
		if is_instance_valid(o["b"]):
			(o["b"] as Node).queue_free()
	for e: Node in arene.get_children():
		if e.name == "Eclat":
			e.queue_free()
	objets.clear()
	for k in NOMS.size():
		_poser(k, vitesse)
	for i in images:
		for o: Dictionary in objets:
			if is_instance_valid(o["b"]) and not o["casse"]:
				o["v"] = (o["b"] as RigidBody3D).linear_velocity
		await _image()
		if i == i_cliche and planche != "":
			root.get_texture().get_image().save_png("%s/%s.png" % [planche, cliche])

func _go() -> void:
	sortie = _arg("sortie", "")
	planche = _arg("planche", "")
	DirAccess.make_dir_recursive_absolute(sortie)
	if planche != "":
		DirAccess.make_dir_recursive_absolute(planche)
	root.size = Vector2i(1280, 720)
	var ips := root.get_node_or_null("CompteurIps")
	if ips != null:
		ips.set("visible", false)
		ips.process_mode = Node.PROCESS_MODE_DISABLED
	_monter()
	await _filmer(10)
	await _manche("Lancer doux (4 m/s) : seuls tonneau et jarre cèdent", 4.0, 110, "doux", 80)
	await _manche("Lancer violent (10 m/s) : chacun casse à sa manière", 10.0, 150, "violent", 40)
	print("FILM %d images dans %s" % [n, sortie])
	quit(0)
