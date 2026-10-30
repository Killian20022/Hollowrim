extends SceneTree
## Planche des ARMES INTÉGRÉES (branche armes/integration) : alignement à l'échelle des 20 armes du catalogue (règle tous les
## 10 cm), puis chaque arme EN MAIN dans le vrai jeu (équipée par EquipementMains, prise et repères du modèle, bouclier au
## bras gauche avec l'épée de soldat à droite) ; puis l'écran d'inventaire (I) et la boutique de la forge de Brodd.
##   godot --path . --disable-vsync --script outils/captures_armes_integrees.gd -- --nouvelle --paisible --sortie=<dossier>
## Sorties : planche_armes_en_main.png, inventaire_armes.png, marchand_armes.png, fps_<id>.png.
const VUE_LACET := 0.0   # lacet absolu : la clairière (fond dégagé), comme la planche des épées hybrides
const COLS := 4
const CW := 480
const CH := 270
const TXT := 64
const H_ALIGN := 560
var dossier := "res://captures/integration_armes"
var m: Node
var ids: Array[String] = []
var fps := {}
var alignement: Image

func _init() -> void:
	_lancer.call_deferred()

func _attendre(n: int) -> void:
	for i in n:
		await process_frame

func _lancer() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			dossier = a.substr(9)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dossier))
	var ordre := ["dague", "une_main", "epee_longue", "deux_mains", "masse", "marteau", "bouclier"]
	for f in ordre:
		ids.append_array(CatalogueArmes.ids_famille(f))
	m = (load("res://scenes/foret_test.tscn") as PackedScene).instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _attendre(60)
	await _alignement()
	await _en_main()
	await _assembler()
	await _inventaire()
	await _marchand()
	print("captures_armes_integrees : fini -> ", ProjectSettings.globalize_path(dossier))
	quit()

func _sauver(img: Image, nom: String) -> void:
	img.save_png(ProjectSettings.globalize_path(dossier.path_join(nom)))
	print("CAPTURE ", nom, " ", img.get_size())

func _ecran() -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

# ------------------------------------------------------------------ alignement à l'échelle
func _alignement() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(960, H_ALIGN / 2)
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
	cam.size = 1.75          # hauteur visible (m)
	cam.position = Vector3(0, 0.875 - 0.12, 3)   # bas de l'image à y = -0,12 (sous les pommeaux)
	vp.add_child(cam)
	var largeur := cam.size * 960.0 / (H_ALIGN / 2.0)
	var pas := largeur / (ids.size() + 1)
	for k in ids.size():
		var d := CatalogueArmes.donnees(ids[k])
		var e: Node3D = (load(d.modele) as PackedScene).instantiate()
		EpeesLongues.habiller(e)
		var piv := Node3D.new()
		vp.add_child(piv)
		piv.add_child(e)
		piv.position = Vector3(-largeur * 0.5 + pas * (k + 1), 0, 0)
		if d.famille == "bouclier":
			e.rotation = Vector3(0, deg_to_rad(-90), 0)   # face peinte (+X) vers la caméra
			e.position = Vector3(0, 0.4, 0)
		else:
			e.rotation = Vector3(0, deg_to_rad(20), 0)
			e.position = Vector3(0, -0.03, 0)            # centre du poing à y = 0 : toutes les armes « tenues » à la même hauteur
	await _attendre(10)
	alignement = vp.get_texture().get_image()
	alignement.convert(Image.FORMAT_RGBA8)
	alignement.resize(1920, H_ALIGN, Image.INTERPOLATE_NEAREST)
	vp.queue_free()

# ------------------------------------------------------------------ en main
func _en_main() -> void:
	var j = m.joueur
	var magie = j.mains.magie
	m.calque.visible = false
	m.cycle.heure = 12.0
	j.rotation.y = deg_to_rad(VUE_LACET)
	j.tete.rotation.x = deg_to_rad(-2.0)
	for id in ids:
		if j.inventaire != null:
			j.inventaire.ajouter(id)
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
		fps[id] = img
		_sauver(img, "fps_%s.png" % id)
	m.calque.visible = true

func _texte(parent: Node, t: String, pos: Vector2, taille: int, couleur := Color("#f2e6c8")) -> void:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	parent.add_child(l)

func _image_rect(parent: Node, img: Image, pos: Vector2, taille: Vector2) -> void:
	var t := TextureRect.new()
	t.texture = ImageTexture.create_from_image(img)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = pos
	parent.add_child(t)
	t.size = taille

func _assembler() -> void:
	var lignes := int(ceil(ids.size() / float(COLS)))
	var haut := 60 + H_ALIGN + 30
	var vp := SubViewport.new()
	vp.size = Vector2i(COLS * CW, haut + lignes * (CH + TXT))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var fond := ColorRect.new()
	fond.color = Color("#1c1e24")
	fond.size = Vector2(vp.size)
	vp.add_child(fond)
	_texte(vp, "ARMES INTÉGRÉES : 20 armes du catalogue, à l'échelle (poings alignés à 0 ; règle tous les 10 cm), puis en main dans le jeu (bouclier au bras gauche).", Vector2(16, 14), 24)
	_image_rect(vp, alignement, Vector2(0, 60), Vector2(1920, H_ALIGN))
	var px_m := H_ALIGN / 1.75
	var y0 := 60 + H_ALIGN - 0.12 * px_m       # y = 0 (centre des poings)
	for c in range(-1, 16):
		var y := y0 - c * 0.1 * px_m
		if y < 60:
			break
		var r := ColorRect.new()
		r.color = Color(1, 1, 1, 0.35 if c % 5 == 0 else 0.14)
		r.position = Vector2(0, y)
		r.size = Vector2(1920 if c % 5 == 0 else 30, 1)
		vp.add_child(r)
		if c % 5 == 0:
			_texte(vp, "%s m" % String.num(c * 0.1, 1).replace(".", ","), Vector2(4, y - 20), 15, Color("#c8c0a8"))
	var largeur := 1.75 * 960.0 / (H_ALIGN / 2.0)
	var pas := largeur / (ids.size() + 1)
	for k in ids.size():
		var x := 960.0 + (-largeur * 0.5 + pas * (k + 1)) * (1920.0 / largeur)
		_texte(vp, "%d" % (k + 1), Vector2(x - 8, 60 + H_ALIGN + 2), 18, Color("#ffd88a"))
	for k in ids.size():
		var id: String = ids[k]
		var o := Vector2((k % COLS) * CW, haut + (k / COLS) * (CH + TXT))
		_image_rect(vp, fps[id], o, Vector2(CW, CH))
		var d := CatalogueArmes.donnees(id)
		var s := CatalogueArmes.stats(id)
		var f := Inventaire.objet(id)
		var coul := Color(ButinTables.COULEURS_RARETE.get(String(f["rarete"]), "#f2e6c8"))
		_texte(vp, "%d  %s" % [k + 1, d.nom], o + Vector2(8, CH + 2), 19, coul)
		var l2 := "%s, %s" % [CatalogueArmes.nom_famille(d.famille), CatalogueArmes.nom_materiau(d.materiau)]
		if d.famille == "bouclier":
			l2 += "  ·  garde %d %%  ·  %s kg  ·  %d po" % [roundi(d.reduction_garde * 100.0), FenetreButin.poids_texte(float(s["poids"])), int(s["valeur"])]
		else:
			l2 += "  ·  %d/%d  ·  vit. %s  ·  %s kg  ·  %d po" % [roundi(d.degats_leger), roundi(d.degats_lourd), String.num(d.vitesse, 2).replace(".", ","), FenetreButin.poids_texte(float(s["poids"])), int(s["valeur"])]
		_texte(vp, l2, o + Vector2(8, CH + 28), 14, Color("#d8cfb8"))
	await _attendre(10)
	var img := vp.get_texture().get_image()
	_sauver(img, "planche_armes_en_main.png")
	vp.queue_free()

# ------------------------------------------------------------------ inventaire et marchand
func _inventaire() -> void:
	var j = m.joueur
	var magie = j.mains.magie
	magie.equiper("droite", "claymore")
	await _attendre(30)
	var ui: InventaireMains = m.inventaire_ui
	ui.categorie = "armes"
	ui.ouvrir()
	await _attendre(10)
	for b in ui._liste.get_children():
		if b is Button and String(b.get_meta("id", "")) == "croc_de_givre":
			b.grab_focus()
	await _attendre(10)
	_sauver(await _ecran(), "inventaire_armes.png")
	ui.fermer()
	await _attendre(5)

func _marchand() -> void:
	var j = m.joueur
	j.inventaire.pieces = 1500
	var mb: Marchand = m.marchand
	Marchand.etat("forgeron")   # état de la période courante (tirage à graine fixe)
	var st := Marchand.stock("forgeron")
	var n := 0
	for id in st:
		if CatalogueArmes.connu(String(id)):
			n += 1
	print("forge de Brodd, période 0 : ", st, " (", n, " armes du catalogue)")
	mb.ouvrir("forgeron")
	await _attendre(10)
	for i in mb.lignes.size():
		if CatalogueArmes.connu(String(mb.lignes[i]["id"])):
			mb._choisir(i)
			break
	await _attendre(10)
	_sauver(await _ecran(), "marchand_armes.png")
