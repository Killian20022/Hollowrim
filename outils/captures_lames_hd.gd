extends SceneTree
## Lames HD (branche armes/lames_hd) : planches avant (Quaternius CC0) / après (modèles maison sources_blender/lames_hd/) des quatre
## lames du catalogue (epee_soldat, sabre_pillard, epee_doree, dague_acier) + planche « famille » avec la claymore v4.
## FENÊTRE hors écran (godot_slot.sh) :
##   godot --path . --resolution 960x540 --audio-driver Dummy --script res://outils/captures_lames_hd.gd --
##         --nouvelle --sortie=<dossier> --etiquette=avant|apres [--armes=a,b] [--parties=studio,fps,famille,assembler]
## studio  : <dossier>/brut/<etiq>_<id>_<vue>.png : entiere (plat), entiere_34, garde, pommeau, lame ; + « MESURE tris ».
## fps     : <dossier>/brut/<etiq>_<id>_fps_repos.png / _fps_garde.png (scène test_combat, jour).
## famille : <dossier>/famille_<etiq>.png : les quatre lames + la claymore v4 à la même échelle.
## assembler : <dossier>/<id>_avant_apres.png (bloc avant en haut, après en bas, filet jaune), d'après les images brutes.
const DT := 1.0 / 60.0
const ARMES := ["epee_soldat", "sabre_pillard", "epee_doree", "dague_acier"]
const VUES := ["entiere", "entiere_34", "garde", "pommeau", "lame", "fps_repos"]

var s: Node
var j: CharacterBody3D
var mains: Node3D
var dossier := ""
var etiq := ""

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		if j != null:
			j.vigueur = j.vigueur_max
		await process_frame

func _go() -> void:
	RetourImpact.muet = true
	dossier = _arg("sortie", "res://captures/lames_hd")
	etiq = _arg("etiquette", "x")
	DirAccess.make_dir_recursive_absolute(dossier.path_join("brut"))
	var armes := _arg("armes", ",".join(ARMES)).split(",")
	var parties := _arg("parties", "studio,fps,famille,assembler").split(",")
	if parties.has("studio"):
		for id in armes:
			await _studio(id)
	if parties.has("famille"):
		await _famille()
	if parties.has("fps"):
		await _fps(armes)
	if parties.has("assembler"):
		for id in armes:
			_assembler(id)
	print("FIN_CAPTURES")
	quit(0)

# ------------------------------------------------------------------ studio (fond neutre, lumière fixe)
func _studio_vp(taille := Vector2i(480, 270)) -> Array:
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
	env.ambient_light_energy = 0.5
	we.environment = env
	vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-30, -35, 0)
	sol.light_energy = 1.3
	vp.add_child(sol)
	var cam := Camera3D.new()
	vp.add_child(cam)
	return [vp, cam]

## « avant » : les modèles Quaternius CC0 tels que les montaient les anciens .tscn (glb, remap des matériaux, échelle de la dague).
const AVANT := {
	"epee_soldat": ["01_sword", {"lame.0": "acier_q", "lame.3": "acier_fil", "fer": "fer", "cuir": "cuir"}, 1.0, 0.0, 0.175],
	"sabre_pillard": ["02_sword_2", {"lame.0": "acier_q", "lame.3": "acier_fil", "fer": "fer", "cuir": "cuir"}, 1.0, 0.0, 0.164],
	"epee_doree": ["03_sword_golden", {"or.0": "or_lame", "or.4": "or", "fer": "fer", "cuir": "cuir"}, 1.0, 0.0, 0.172],
	"dague_acier": ["04_dagger", {"lame.0": "acier_q", "lame.3": "acier_fil", "fer": "fer", "cuir": "cuir"}, 1.3, -0.009, 0.1041],
}

func _modele(id: String) -> Node3D:
	if etiq == "avant" and AVANT.has(id):
		var av: Array = AVANT[id]
		var r := Node3D.new()
		r.set_meta("remap_materiaux", av[1])
		var g: Node3D = (load("res://assets/modeles/armes/cc0_essai/%s.glb" % av[0]) as PackedScene).instantiate()
		g.scale = Vector3.ONE * float(av[2])
		g.position.y = float(av[3])
		r.add_child(g)
		var mg := Marker3D.new()
		mg.name = "garde"
		mg.position.y = float(av[4])
		r.add_child(mg)
		EpeesLongues.habiller(r)
		return r
	var a: DonneesArme = CatalogueArmes.donnees(id)
	var m: Node3D = (load(a.modele) as PackedScene).instantiate()
	if a.habillage == "claymore":
		ClaymoreMateriaux.habiller(m)
	else:
		EpeesLongues.habiller(m)
	return m

func _local(e: Node, n: Node) -> Transform3D:
	var t := Transform3D()
	while n != null and n != e:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

func _boite(m: Node3D) -> AABB:
	var b := AABB()
	var premier := true
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		var bb := _local(m, mi) * mi.get_aabb()
		b = bb if premier else b.merge(bb)
		premier = false
	return b

func _tris(m: Node3D) -> int:
	var tris := 0
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		for sidx in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(sidx)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return tris

func _repere_y(m: Node3D, nom: String, defaut: float) -> float:
	var n := m.find_child(nom, true, false)
	return _local(m, n).origin.y if n else defaut

func _vue(vp: SubViewport) -> Image:
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(960, 540, Image.INTERPOLATE_NEAREST)
	return img

func _studio(id: String) -> void:
	var r := _studio_vp()
	var vp: SubViewport = r[0]
	var cam: Camera3D = r[1]
	var m := _modele(id)
	vp.add_child(m)
	var b := _boite(m)
	var lg := b.size.y
	var yc := b.get_center().y
	var yg := _repere_y(m, "garde", 0.17)
	var k := clampf(lg / 1.05, 0.5, 1.4)    # dague : caméra plus proche
	print("MESURE %s %s tris=%d longueur=%.3f y[%.3f ; %.3f] largeur=%.3f garde=%.3f" % [etiq, id, _tris(m), lg, b.position.y, b.end.y, b.size.x, yg])
	var yp := b.position.y
	var ylame := yg + (b.end.y - yg) * 0.35
	var vues := [
		["entiere", true, lg * 0.6, Vector3(0, 0, 3), Vector3.ZERO, Vector3(0, 0, -PI / 2), Vector3(-yc, 0, 0)],
		["entiere_34", true, lg * 0.6, Vector3(0, 0, 3), Vector3.ZERO, Vector3(deg_to_rad(55), 0, -PI / 2), Vector3(-yc, 0, 0)],
		["garde", false, 38.0, Vector3(0.13 * k, yg + 0.03 * k, 0.30 * k), Vector3(0, yg - 0.02 * k, 0), Vector3(0, deg_to_rad(18), 0), Vector3.ZERO],
		["pommeau", false, 36.0, Vector3(-0.08 * k, yp + 0.09 * k, 0.24 * k), Vector3(0, yp + 0.05 * k, 0), Vector3(0, deg_to_rad(-20), 0), Vector3.ZERO],
		["lame", false, 40.0, Vector3(0.07 * k, yg + 0.15 * k, 0.17 * k), Vector3(0, yg + 0.19 * k, 0), Vector3(0, deg_to_rad(18), 0), Vector3.ZERO],
	]
	for v in vues:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL if v[1] else Camera3D.PROJECTION_PERSPECTIVE
		if v[1]:
			cam.size = v[2]
		else:
			cam.fov = v[2]
		cam.position = v[3]
		cam.look_at(v[4])
		m.rotation = v[5]
		m.position = v[6]
		await _attendre(0.15)
		_vue(vp).save_png(dossier.path_join("brut/%s_%s_%s.png" % [etiq, id, v[0]]))
	vp.queue_free()
	await _attendre(0.05)

# ------------------------------------------------------------------ famille (même échelle)
func _famille() -> void:
	var r := _studio_vp(Vector2i(640, 360))
	var vp: SubViewport = r[0]
	var cam: Camera3D = r[1]
	var ids := ARMES.duplicate()
	ids.append("claymore")
	var x := -0.9
	var ms: Array[Node3D] = []
	for id in ids:
		var m := _modele(id)
		vp.add_child(m)
		m.position = Vector3(x, -0.55, 0)
		ms.append(m)
		x += 0.45
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.95
	for v in [["plat", 0.0], ["34", 38.0]]:
		cam.position = Vector3(0, 0.05, 3)
		cam.look_at(Vector3(0, 0.05, 0))
		for m in ms:
			m.rotation = Vector3(0, deg_to_rad(v[1]), 0)
		await _attendre(0.2)
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		img.save_png(dossier.path_join("famille_%s_%s.png" % [etiq, v[0]]))
		print("PLANCHE ", dossier.path_join("famille_%s_%s.png" % [etiq, v[0]]))
	# gardes et pommeaux côte à côte (perspective, même distance)
	var imgs: Array[Image] = []
	for i in ms.size():
		for m in ms:
			m.visible = false
		var m := ms[i]
		m.visible = true
		m.position = Vector3.ZERO
		m.rotation = Vector3(0, deg_to_rad(12), 0)
		var yg := _repere_y(m, "garde", 0.17)
		var b := _boite(m)
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 34.0
		var yc := (yg + b.position.y) * 0.5
		var dist := 0.30 + (yg - b.position.y) * 0.9
		cam.position = Vector3(0.10, yc + 0.03, dist)
		cam.look_at(Vector3(0, yc, 0))
		await _attendre(0.15)
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		imgs.append(img)
	var w := imgs[0].get_width()
	var h := imgs[0].get_height()
	var pl := Image.create(w * 3, h * 2, false, Image.FORMAT_RGBA8)
	pl.fill(Color("#3a3d44"))
	for i in imgs.size():
		pl.blit_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i((i % 3) * w, (i / 3) * h))
	pl.save_png(dossier.path_join("famille_%s_poignees.png" % etiq))
	print("PLANCHE ", dossier.path_join("famille_%s_poignees.png" % etiq))
	vp.queue_free()
	await _attendre(0.05)

# ------------------------------------------------------------------ 1re personne, en jeu (jour)
func _fps(armes: Array) -> void:
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if s.get("mannequin") != null:
		s.mannequin.visible = false
		s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	if s.get("hud") != null:
		s.hud.visible = false
	await _attendre(0.7)
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -4.0)
	for id in armes:
		mains.equipement.equiper("droite", CatalogueArmes.donnees(id))
		await _attendre(1.2)
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(dossier.path_join("brut/%s_%s_fps_repos.png" % [etiq, id]))
		mains.entrees.forcer_garde(1.2)
		await _attendre(0.7)
		img = root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(dossier.path_join("brut/%s_%s_fps_garde.png" % [etiq, id]))
		await _attendre(0.8)
	s.queue_free()
	j = null
	await _attendre(0.1)

# ------------------------------------------------------------------ planche avant / après
func _bloc(e: String, id: String, w: int, h: int) -> Image:
	var bloc := Image.create(w * 3, h * 2, false, Image.FORMAT_RGBA8)
	bloc.fill(Color("#202226"))
	for i in VUES.size():
		var p := dossier.path_join("brut/%s_%s_%s.png" % [e, id, VUES[i]])
		if not FileAccess.file_exists(p):
			continue
		var im := Image.load_from_file(p)
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		bloc.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % 3) * w, (i / 3) * h))
	return bloc

func _assembler(id: String) -> void:
	var w := 640
	var h := 360
	var av := _bloc("avant", id, w, h)
	var ap := _bloc("apres", id, w, h)
	var pl := Image.create(w * 3, h * 4 + 8, false, Image.FORMAT_RGBA8)
	pl.fill(Color("#f2c200"))
	pl.blit_rect(av, Rect2i(0, 0, w * 3, h * 2), Vector2i(0, 0))
	pl.blit_rect(ap, Rect2i(0, 0, w * 3, h * 2), Vector2i(0, h * 2 + 8))
	pl.save_png(dossier.path_join("%s_avant_haut_apres_bas.png" % id))
	print("PLANCHE ", dossier.path_join("%s_avant_haut_apres_bas.png" % id))
