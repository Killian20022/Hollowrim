extends SceneTree
## Planche AVANT / APRÈS du réalisme des armes (branche armes/realisme) : pour chaque arme du catalogue, une vue de près
## (arme entière + détail de la monture ou de la tête, rendues à 480 x 270 par le shader ps1, lumière de jour fixe) et la vue
## EN MAIN dans le vrai jeu (même cadrage que outils/captures_armes_integrees.gd).
##   godot --path . --disable-vsync --script outils/captures_realisme_armes.gd -- --nouvelle --paisible --sortie=<dossier> --phase=avant
##   (puis, après les changements de matériaux)  ... --phase=apres     -> assemble aussi planche_avant_apres.png
## Sorties (dossier) : <phase>/pres_<id>.png, <phase>/detail_<id>.png, <phase>/main_<id>.png ; avant_apres_<id>.png ; planche_avant_apres.png.
const VUE_LACET := 0.0
const CW := 480
const CH := 270
var dossier := "res://captures/realisme_armes"
var phase := "avant"
var m: Node
var ids: Array[String] = []

func _init() -> void:
	_lancer.call_deferred()

func _attendre(n: int) -> void:
	for i in n:
		await process_frame

func _lancer() -> void:
	var seul := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			dossier = a.substr(9)
		elif a.begins_with("--phase="):
			phase = a.substr(8)
		elif a.begins_with("--seul="):
			seul = a.substr(7)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier.path_join(phase)))
	for f in ["dague", "une_main", "epee_longue", "deux_mains", "masse", "marteau", "bouclier"]:
		ids.append_array(CatalogueArmes.ids_famille(f))
	if seul != "":
		ids = ids.filter(func(i): return i in seul.split(","))
	await _de_pres()
	if not OS.get_cmdline_user_args().has("--sans-jeu"):
		m = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
		m.set_meta("test", true)
		root.add_child(m)
		await _attendre(60)
		await _en_main()
	if phase == "apres":
		await _assembler()
	print("captures_realisme_armes : fini -> ", ProjectSettings.globalize_path(dossier))
	quit()

func _sauver(img: Image, nom: String) -> void:
	img.save_png(ProjectSettings.globalize_path(dossier.path_join(nom)))
	print("CAPTURE ", nom, " ", img.get_size())

# ------------------------------------------------------------------ de près (480 x 270, lumière de jour fixe)
func _studio() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(CW, CH)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#454a55")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9aa4b8")
	env.ambient_light_energy = 0.5
	we.environment = env
	vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38, -35, 0)
	sol.light_energy = 1.2
	sol.light_color = Color("#fff4e2")
	vp.add_child(sol)
	return vp

## Points du modèle (repère de l'arme) : coins des boîtes des maillages.
func _points(e: Node3D) -> Array:
	var acc := []
	for mi: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
		var t := e.global_transform.affine_inverse() * mi.global_transform
		var b := mi.get_aabb()
		for i in 8:
			acc.append(t * b.get_endpoint(i))
	return acc

func _de_pres() -> void:
	var vp := _studio()
	var cam := Camera3D.new()
	cam.fov = 24.0
	vp.add_child(cam)
	var piv := Node3D.new()
	vp.add_child(piv)
	for id in ids:
		var d := CatalogueArmes.donnees(id)
		var e: Node3D = (load(d.modele) as PackedScene).instantiate()
		piv.add_child(e)
		EpeesLongues.habiller(e)
		var bouclier := d.famille == "bouclier"
		# arme couchée en diagonale (pointe à droite, un peu vers le haut), plat tourné vers la lumière ; bouclier de 3/4
		if bouclier:
			piv.rotation = Vector3(deg_to_rad(8), deg_to_rad(-90 + 28), 0)
		else:
			piv.basis = Basis(Vector3(0, 0, 1), deg_to_rad(-68)) * Basis(Vector3(0, 1, 0), deg_to_rad(28)) * Basis(Vector3(1, 0, 0), deg_to_rad(-12))
		await _attendre(2)
		var pts := _points(e)
		var mn := Vector3(INF, INF, INF)
		var mx := -mn
		for p: Vector3 in pts:
			var w: Vector3 = piv.basis * p
			mn = mn.min(w)
			mx = mx.max(w)
		var centre := (mn + mx) * 0.5
		var ext := (mx - mn) * 0.5
		var tg := tan(deg_to_rad(cam.fov * 0.5))
		var dist := maxf(ext.y, ext.x * CH / float(CW)) / tg * 1.08 + ext.z
		cam.position = centre + Vector3(0, 0, dist)
		cam.look_at(centre)
		await _attendre(6)
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		_sauver(img, "%s/pres_%s.png" % [phase, id])
		# détail : monture (épées, dagues) ou tête (haches, masse, marteaux), bossage du bouclier
		var cible := Vector3.ZERO
		var g := EpeesLongues.repere(e, "garde")
		var pt := EpeesLongues.repere(e, "pointe")
		var tete := d.famille in ["masse", "marteau"] or id.begins_with("hach")
		if bouclier:
			cible = Vector3.ZERO
		elif tete and g and pt:
			cible = (g.position + pt.position) * 0.5
		elif g:
			cible = g.position + Vector3(0, 0.02, 0)
		var cw: Vector3 = piv.basis * cible
		var f := 0.42 if not bouclier else 0.55
		cam.position = cw + Vector3(0, 0, (dist - ext.z) * f + ext.z * 0.5)
		cam.look_at(cw)
		await _attendre(6)
		img = vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		_sauver(img, "%s/detail_%s.png" % [phase, id])
		e.queue_free()
		await _attendre(1)
	vp.queue_free()

# ------------------------------------------------------------------ en main (même cadrage que la planche d'intégration)
func _ecran() -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _en_main() -> void:
	var j = m.joueur
	var magie = j.mains.magie
	m.calque.visible = false
	m.cycle.heure = 12.0
	for id in ids:
		var d := CatalogueArmes.donnees(id)
		if d.famille == "bouclier":
			magie.equiper("droite", "epee_soldat")
			magie.equiper("gauche", id)
		else:
			magie.equiper("gauche", "vide")
			magie.equiper("droite", id)
		j.rotation.y = deg_to_rad(VUE_LACET)
		j.tete.rotation.x = deg_to_rad(-2.0)
		await _attendre(100)
		var img: Image = await _ecran()
		img.resize(CW, CH, Image.INTERPOLATE_NEAREST)
		_sauver(img, "%s/main_%s.png" % [phase, id])
		if d.famille == "bouclier":
			j.mains.entrees.forcer_garde(3.0)
			await _attendre(40)
			img = await _ecran()
			img.resize(CW, CH, Image.INTERPOLATE_NEAREST)
			_sauver(img, "%s/garde_%s.png" % [phase, id])
			await _attendre(200)
	m.calque.visible = true

# ------------------------------------------------------------------ planche
func _lire(nom: String) -> Image:
	var p := ProjectSettings.globalize_path(dossier.path_join(nom))
	if FileAccess.file_exists(p):
		var i := Image.load_from_file(p)
		i.convert(Image.FORMAT_RGBA8)
		return i
	var v := Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	v.fill(Color("#30333a"))
	return v

func _texte(parent: Node, t: String, pos: Vector2, taille: int, couleur := Color("#f2e6c8")) -> void:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	parent.add_child(l)

func _image_rect(parent: Node, img: Image, pos: Vector2) -> void:
	var t := TextureRect.new()
	t.texture = ImageTexture.create_from_image(img)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = pos
	parent.add_child(t)

## Une fiche par arme : 2 lignes (AVANT, APRÈS) x 3 vues (entière, détail, en main).
const FW := 3 * CW + 70
const FH := 34 + 2 * CH + 8

func _fiche(parent: Node, k: int, id: String, o: Vector2) -> void:
	var d := CatalogueArmes.donnees(id)
	_texte(parent, "%d  %s  (%s, %s)" % [k + 1, d.nom, CatalogueArmes.nom_famille(d.famille), CatalogueArmes.nom_materiau(d.materiau)], o + Vector2(6, 2), 20, Color("#ffd88a"))
	for r in 2:
		var ph := "avant" if r == 0 else "apres"
		var y := o.y + 34 + r * (CH + 4)
		_texte(parent, "AVANT" if r == 0 else "APRÈS", Vector2(o.x + 4, y + CH * 0.5 - 10), 15, Color("#d8cfb8") if r == 0 else Color("#9fe0a0"))
		for c in 3:
			var nom: String = ["pres_", "detail_", "main_"][c] + id + ".png"
			_image_rect(parent, _lire(ph.path_join(nom)), Vector2(o.x + 66 + c * CW, y))

func _assembler() -> void:
	# fiches séparées
	for k in ids.size():
		var vp := SubViewport.new()
		vp.size = Vector2i(FW, FH)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var fond := ColorRect.new()
		fond.color = Color("#1c1e24")
		fond.size = Vector2(vp.size)
		vp.add_child(fond)
		_fiche(vp, k, ids[k], Vector2.ZERO)
		await _attendre(4)
		_sauver(vp.get_texture().get_image(), "avant_apres_%s.png" % ids[k])
		vp.queue_free()
	# planche : 2 colonnes de fiches
	var cols := 2
	var lignes := int(ceil(ids.size() / float(cols)))
	var vp := SubViewport.new()
	vp.size = Vector2i(cols * FW, 60 + lignes * FH)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var fond := ColorRect.new()
	fond.color = Color("#1c1e24")
	fond.size = Vector2(vp.size)
	vp.add_child(fond)
	_texte(vp, "RÉALISME DES ARMES : avant / après. Par arme : vue entière et détail (480 x 270, shader ps1, lumière de jour fixe), puis en main dans le jeu.", Vector2(16, 14), 24)
	for k in ids.size():
		_fiche(vp, k, ids[k], Vector2((k % cols) * FW, 60 + (k / cols) * FH))
	await _attendre(6)
	_sauver(vp.get_texture().get_image(), "planche_avant_apres.png")
	vp.queue_free()
