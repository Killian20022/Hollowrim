extends SceneTree
## Planches avant / après du portage « avant-bras étape 1 + os de torsion » (fps/avant_bras_v2). FENÊTRE (godot_slot.sh :
## hors écran), scène test_magie, ambiance crépuscule (cadrage des références Jeux/references/avant_bras_magie/).
##   1) instants : godot --path <worktree> --script res://outils/captures_avant_bras_v2.gd -- --sortie=<dossier> \
##        --prefixe=<nom> [--instants=repos_double,repos_epee,estoc,zone_charge,zone_lance] [--gros]
##      → <dossier>/<prefixe>_<instant>_jeu.png (vue de jeu 480×270) [+ _gros.png : gros plan de l'avant-bras gauche]
##      Le script ne dépend que de l'interface commune (MainSort, mains.avancer, pas_manuel) : il tourne aussi sur une
##      branche sans tenue « runes » ni os de torsion (colonne « avant »).
##   2) planche : godot --headless --path . --script res://outils/captures_avant_bras_v2.gd -- --sortie=<dossier> \
##        --planche=<nom> --colonnes=<pref>_jeu:<titre>,<pref>_jeu:<titre> --instants=a,b,c
##      → <dossier>/<nom>.png : une ligne par instant, une colonne par source, image ×2 (plus proche voisin) ; le titre
##      (--titre=… à l'étape 1) et l'instant sont écrits en haut à gauche de chaque image.

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0
const W := 480
const H := 270
## instant -> [sort gauche, droite, action, nombre d'images avant la capture]
const INSTANTS := {
	"repos_double": ["jet_flammes", "jet_flammes", "", 60],
	"repos_epee": ["jet_flammes", "epee", "", 60],
	"estoc": ["jet_flammes", "epee", "estoc", 13],
	"puissante": ["jet_flammes", "epee", "puissante", 62],
	"zone_charge": ["explosion_obscure", "jet_flammes", "zone", 50],
	"zone_lance": ["explosion_obscure", "jet_flammes", "zone", 95],
	"zone_fin": ["explosion_obscure", "jet_flammes", "zone", 110],
}

var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var sq: Skeleton3D
var sortie := ""
var cam_gp: Camera3D
var _acc := {}
var l: Label


func _init() -> void:
	_go.call_deferred()


func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut


func _image() -> Image:
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	im.resize(W, H, Image.INTERPOLATE_NEAREST)
	return im


func _monter() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame
	sq = mains.get("_sq")
	var env: Environment = s.env
	env.background_color = Color(0.30, 0.27, 0.31)
	env.ambient_light_color = Color(0.52, 0.48, 0.56)
	env.ambient_light_energy = 0.42
	var so: DirectionalLight3D = s.soleil
	so.basis = Basis.looking_at(Vector3(-0.2, -0.25, 0.95), Vector3.UP)
	so.light_color = Color(1.0, 0.72, 0.52)
	so.light_energy = 0.55
	for n in root.find_children("*", "CanvasLayer", true, false):
		for c in n.get_children():
			var garder: bool = c is ColorRect and (c as ColorRect).material is ShaderMaterial
			if c is CanvasItem and not garder:
				(c as CanvasItem).visible = false
	for n in root.find_children("*", "Label3D", true, false):
		(n as Label3D).visible = false
	for nom in ["mannequin", "mannequin2", "mannequin3"]:
		var mq = s.get(nom)
		if mq is Node3D:
			(mq as Node3D).visible = false
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(8, 8)
	calque.add_child(l)
	cam_gp = Camera3D.new()
	cam_gp.fov = 38.0
	cam_gp.near = 0.01
	s.add_child(cam_gp)
	for n in ["lowerarm_l", "hand_l"]:
		var a := BoneAttachment3D.new()
		a.bone_name = n
		sq.add_child(a)
		_acc[n] = a
	mains.pas_manuel = true
	RetourCoups.arret_actif = false
	RetourImpact.muet = true


## Gros plan : au-dessus et côté extérieur de l'avant-bras gauche, perpendiculaire à lui (comme captures_torsion_avant_bras).
func _cadrer() -> void:
	var co: Vector3 = (_acc["lowerarm_l"] as Node3D).global_position
	var po: Vector3 = (_acc["hand_l"] as Node3D).global_position
	var mi := co.lerp(po, 0.5)
	var b: Basis = j.camera.global_transform.basis
	var a := (po - co).normalized()
	var d := b.y - b.x * 0.7 + b.z * 0.2
	d = (d - a * a.dot(d)).normalized()
	var pos := mi + d * 0.5
	cam_gp.global_transform = Transform3D(Basis.looking_at(mi - pos, b.y), pos)


func _instant(nom: String, prefixe: String, gros: bool) -> void:
	var c: Array = INSTANTS[nom]
	var m: MainSort = s.magie
	m.equiper("droite", c[1])
	m.equiper("gauche", c[0])
	s.placer_joueur(Vector3(0, 0, 1.6), 0.0)
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	for i in 60:
		j.mana = j.mana_max
		mains.avancer(DT)
		await process_frame
	var action: String = c[2]
	var n: int = c[3]
	for i in n + 1:
		j.mana = j.mana_max
		j.vigueur = j.vigueur_max
		m.recharges.clear()
		match action:
			"estoc":
				if i == 0:
					mains.entrees.appuyer()
				elif i == 2:
					mains.entrees.relacher()
			"puissante":
				if i == 0:
					mains.entrees.appuyer()
				elif i == 52:
					mains.entrees.relacher()
			"zone":
				if i == 10:
					m.appuyer("gauche")
				elif i == 88:
					m.relacher("gauche")
		mains.avancer(DT)
		if action == "estoc" and i == 1:
			mains._geste_nom = "estoc_combo"
			mains._preparer_geste(false)
		await process_frame
	j.camera.current = true
	l.text = "%s\n%s" % [_arg("titre", prefixe), nom]
	await process_frame
	await process_frame
	(await _image()).save_png(sortie.path_join("%s_%s_jeu.png" % [prefixe, nom]))
	print("CAPTURE %s_%s_jeu" % [prefixe, nom])
	if gros:
		_cadrer()
		cam_gp.current = true
		await process_frame
		await process_frame
		(await _image()).save_png(sortie.path_join("%s_%s_gros.png" % [prefixe, nom]))
		print("CAPTURE %s_%s_gros" % [prefixe, nom])
		j.camera.current = true
	m.relacher("gauche")
	m.relacher("droite")
	mains.entrees.relacher()
	for i in 90:
		mains.avancer(DT)
	await process_frame


func _planche(nom: String, colonnes: Array, instants: Array) -> void:
	var titre_h := 0
	var p := Image.create(W * 2 * colonnes.size(), titre_h + H * 2 * instants.size(), false, Image.FORMAT_RGBA8)
	p.fill(Color(0.08, 0.08, 0.09))
	for r in instants.size():
		for k in colonnes.size():
			var spec: String = colonnes[k]
			var suff := spec.get_slice(":", 0)    # ex. avant_jeu → avant_<instant>_jeu.png
			var f := sortie.path_join("%s_%s_%s.png" % [suff.get_slice("_", 0), instants[r], suff.get_slice("_", 1)])
			var im := Image.load_from_file(f)
			if im == null:
				print("MANQUE ", f)
				continue
			im.convert(Image.FORMAT_RGBA8)
			im.resize(W * 2, H * 2, Image.INTERPOLATE_NEAREST)
			p.blit_rect(im, Rect2i(0, 0, W * 2, H * 2), Vector2i(k * W * 2, titre_h + r * H * 2))
	var f := sortie.path_join(nom + ".png")
	p.save_png(f)
	print("PLANCHE ", f)


func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/avant_bras_v2"))
	DirAccess.make_dir_recursive_absolute(sortie)
	var instants := Array(_arg("instants", "repos_double,repos_epee,estoc,zone_charge,zone_lance").split(",", false))
	if _arg("planche") != "":
		await _planche(_arg("planche"), Array(_arg("colonnes").split(",", false)), instants)
		quit()
		return
	await _monter()
	var prefixe := _arg("prefixe", "apres")
	for nom in instants:
		await _instant(nom, prefixe, _arg("gros") != "")
	quit()
