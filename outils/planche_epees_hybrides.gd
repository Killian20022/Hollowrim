extends SceneTree
## Planche de choix des ÉPÉES HYBRIDES (essai, branche essai/epees_hybrides) : alignement à l'échelle (règle en cm), puis par épée
## une vue de profil rapprochée et une vue FPS en main (jour), à côté de l'épée actuelle (metal) et de la claymore Quaternius n°05.
##   godot --path . --disable-vsync --script outils/planche_epees_hybrides.gd -- --nouvelle --paisible --mains=repos --sortie=<png>
## Modèles : assets/modeles/armes/hybrides/<id>.glb (source sources_blender/epees_hybrides/epees_hybrides.py, + hybrides_info.json).
const DOSSIER := "res://assets/modeles/armes/hybrides/"
const INFO := "res://sources_blender/epees_hybrides/hybrides_info.json"
const CLAYMORE := "res://assets/modeles/armes/cc0_essai/05_claymore.glb"
const SAPHIR := ["#01060f", "#031026", "#06204a", "#0b3470", "#14509a", "#2272c4", "#58a4e8", "#b8e2ff"]
const W := 1920
const H_ALIGN := 640
const CELL := Vector2i(960, 630)
var sortie := "res://captures/planche_hybrides.png"
var ids: Array[String] = []
var info := {}
var vues := {}     # id -> Image (profil rapproché)
var fps := {}      # id -> Image
var alignement: Image
var _mat_saphir: ShaderMaterial

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	info = JSON.parse_string(FileAccess.get_file_as_string(INFO))
	ids.assign(["ref_metal", "ref_claymore"])
	var h: Array = info.keys()
	h.sort()
	ids.append_array(h)
	var m: Node = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for i in 60:
		await process_frame
	await _vues_neutres()
	await _fps(m)
	await _assembler()
	quit()

func _charger(id: String) -> Node3D:
	if id == "ref_metal":
		return EpeesLongues.instancier("metal")
	var e: Node3D = (load(CLAYMORE if id == "ref_claymore" else DOSSIER + id + ".glb") as PackedScene).instantiate()
	EpeesLongues.habiller(e)
	if _mat_saphir == null:
		_mat_saphir = EpeesLongues._lueur(EpeesLongues._cristal(SAPHIR, 63), Color(0.95, 1.0, 1.08), 0.25)
		_mat_saphir.set_shader_parameter("tex_neige", _mat_saphir.get_shader_parameter("tex_base"))
	for mi: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mt := mi.mesh.surface_get_material(s)
			if mt and mt.resource_name.begins_with("saphir"):
				mi.set_surface_override_material(s, _mat_saphir)
	return e

## Boîte englobante (repère local de l'épée).
func _boite(e: Node3D) -> AABB:
	var b := AABB()
	var premier := true
	for mi: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
		var t: Transform3D = e.global_transform.affine_inverse() * mi.global_transform
		var a: AABB = t * mi.get_aabb()
		b = a if premier else b.merge(a)
		premier = false
	return b

func _scene_neutre(taille: Vector2i) -> Array:
	var vp := SubViewport.new()
	vp.size = taille
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#3a3d44")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a90a0")
	env.ambient_light_energy = 0.55
	we.environment = env
	vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, -40, 0)
	sol.light_energy = 1.25
	vp.add_child(sol)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	return [vp, cam]

func _image(vp: SubViewport, echelle: int) -> Image:
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(img.get_width() * echelle, img.get_height() * echelle, Image.INTERPOLATE_NEAREST)
	return img

func _vues_neutres() -> void:
	# 1) alignement à l'échelle : pommeaux posés sur y = 0, rendu 960 x 320 agrandi x2
	var r := _scene_neutre(Vector2i(W / 2, H_ALIGN / 2))
	var vp: SubViewport = r[0]
	var cam: Camera3D = r[1]
	cam.size = 1.8
	var pas := 0.52
	var x0 := -pas * (ids.size() - 1) * 0.5
	cam.position = Vector3(0, 0.9 - 0.06, 3)
	for k in ids.size():
		var e := _charger(ids[k])
		vp.add_child(e)
		e.rotation = Vector3(0, deg_to_rad(20), 0)
		var b := _boite(e)
		e.position = Vector3(x0 + pas * k, -b.position.y, 0)
	for i in 10:
		await process_frame
	alignement = _image(vp, 2)
	vp.queue_free()
	# 2) profil rapproché, épée couchée (pointe à droite), légèrement de trois quarts : 480 x 150 agrandi x2
	r = _scene_neutre(Vector2i(480, 150))
	vp = r[0]
	cam = r[1]
	cam.size = 0.53
	cam.position = Vector3(0, 0, 3)
	for id in ids:
		var piv := Node3D.new()
		vp.add_child(piv)
		var e := _charger(id)
		piv.add_child(e)
		e.rotation = Vector3(deg_to_rad(-22), deg_to_rad(28), 0)
		var b := _boite(e)
		e.position = -Vector3(0, b.position.y + b.size.y * 0.5, 0)
		piv.rotation = Vector3(0, 0, deg_to_rad(-90))
		for i in 8:
			await process_frame
		vues[id] = _image(vp, 2)
		piv.queue_free()
	vp.queue_free()

func _fps(m: Node) -> void:
	var j = m.joueur
	var mains = j.mains
	var accroche: Node3D = mains._accroche_d
	var origine: Node3D = mains._modele_arme_d
	var prise: Transform3D = origine.transform
	origine.visible = false
	m.calque.visible = false
	j.tete.rotation.x = deg_to_rad(-4.0)
	j.rotation.y += deg_to_rad(-35.0)
	for i in 20:
		await process_frame
	mains.set_process(false)
	var piv: Node3D = mains.pivot_epee
	piv.position += Vector3(0.03, -0.03, 0.10)
	piv.rotate_object_local(Vector3.FORWARD, deg_to_rad(-28.0))
	piv.rotate_object_local(Vector3.RIGHT, deg_to_rad(-12.0))
	m.cycle.heure = 12.0
	for id in ids:
		var e := _charger(id)
		accroche.add_child(e)
		e.transform = prise
		for i in 30:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		fps[id] = img
		print("fps ", id, " ", img.get_size())
		e.queue_free()

func _texte(parent: Node, t: String, pos: Vector2, taille: int, couleur := Color("#f2e6c8"), largeur := 0.0) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	if largeur > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(largeur, 0)
		l.size = Vector2(largeur, 0)
	parent.add_child(l)
	return l

func _image_rect(parent: Node, img: Image, pos: Vector2, taille: Vector2) -> void:
	var t := TextureRect.new()
	t.texture = ImageTexture.create_from_image(img)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = pos
	parent.add_child(t)
	t.size = taille

func _fiche(id: String) -> Array:
	if id == "ref_metal":
		return ["REF A", "Épée actuelle du jeu (acier)", "1 main et demie · 1,10 m · réf.", "lame et garde : nôtres (epees_longues.py)"]
	if id == "ref_claymore":
		return ["REF B", "Claymore Quaternius n°05", "2 mains · 1,45 m · 1033 tris", "LA référence de style (lame rubis)"]
	var f: Dictionary = info[id]
	var mains: String = {1.0: "1 main", 1.5: "1 main et demie (épée longue)", 2.0: "2 mains"}[float(f["mains"])]
	return ["%d" % (ids.find(id) - 1), String(f["nom"]),
		"%s · %s m (lame %s m) · %d tris" % [mains, String.num(f["longueur"], 2).replace(".", ","), String.num(f["lame"], 2).replace(".", ","), int(f["triangles"])],
		"Lame : %s\nMonture : %s" % [f["origine_lame"], f["origine_garde"]]]

func _assembler() -> void:
	var lignes := int(ceil(ids.size() / 2.0))
	var haut := 70 + H_ALIGN + 40
	var vp := SubViewport.new()
	vp.size = Vector2i(W, haut + lignes * CELL.y)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var fond := ColorRect.new()
	fond.color = Color("#1c1e24")
	fond.size = Vector2(vp.size)
	vp.add_child(fond)
	_texte(vp, "ÉPÉES HYBRIDES : nos lames + montures Quaternius (CC0), ou l'inverse. Alignées à l'échelle (règle tous les 10 cm).", Vector2(20, 18), 30)
	_image_rect(vp, alignement, Vector2(0, 70), Vector2(W, H_ALIGN))
	# règle : y = 0 au bas de l'image du rendu (centre caméra 0,84 m, hauteur 1,8 m)
	var px_m := H_ALIGN / 1.8
	var y_sol := 70 + H_ALIGN * 0.5 + (0.84) * px_m
	for c in range(0, 18):
		var y := y_sol - c * 0.1 * px_m
		var trait := ColorRect.new()
		trait.color = Color(1, 1, 1, 0.16 if c % 5 else 0.35)
		trait.position = Vector2(0, y)
		trait.size = Vector2(W if c % 5 == 0 else 40, 1)
		vp.add_child(trait)
		if c % 5 == 0:
			_texte(vp, "%s m" % String.num(c * 0.1, 1).replace(".", ","), Vector2(4, y - 22), 18, Color("#c8c0a8"))
	var pas := 0.52
	var x_px := W / (1.8 * float(W) / H_ALIGN)
	for k in ids.size():
		var x := W * 0.5 + (-pas * (ids.size() - 1) * 0.5 + pas * k) * x_px
		_texte(vp, _fiche(ids[k])[0], Vector2(x - 30, 70 + H_ALIGN + 4), 24, Color("#ffd88a"))
	for k in ids.size():
		var id: String = ids[k]
		var o := Vector2((k % 2) * CELL.x, haut + (k / 2) * CELL.y)
		var cadre := ColorRect.new()
		cadre.color = Color("#25282f") if (k / 2 + k % 2) % 2 == 0 else Color("#2b2e36")
		cadre.position = o
		cadre.size = Vector2(CELL)
		vp.add_child(cadre)
		_image_rect(vp, vues[id], o + Vector2(0, 0), Vector2(960, 300))
		_image_rect(vp, fps[id], o + Vector2(0, 305), Vector2(560, 315))
		var f := _fiche(id)
		_texte(vp, f[0], o + Vector2(575, 312), 40, Color("#ffd88a"))
		_texte(vp, f[1], o + Vector2(575, 362), 28)
		_texte(vp, f[2], o + Vector2(575, 402), 19, Color("#e0d6bc"), 375)
		_texte(vp, f[3], o + Vector2(575, 470), 17, Color("#b8b0a0"), 375)
	for i in 10:
		await process_frame
	var img := vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	img.save_png(sortie)
	for id in ids:
		fps[id].save_png(sortie.get_base_dir().path_join("fps_%s.png" % id))
		vues[id].save_png(sortie.get_base_dir().path_join("profil_%s.png" % id))
	alignement.save_png(sortie.get_base_dir().path_join("alignement.png"))
	print("planche_epees_hybrides : ", sortie, " ", img.get_size())
