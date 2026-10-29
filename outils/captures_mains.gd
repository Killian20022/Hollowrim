extends SceneTree
## Mains FPS en magie (tenue « runes » à deux sorts) et en tenue d'épée : vue de jeu + gros plans pris DEPUIS L'ŒIL
## (caméra du joueur, champ resserré sur chaque main). FENÊTRE (godot_slot.sh : hors écran), scène test_magie, ambiance
## crépuscule (comme captures_avant_bras_v2).
##   godot --path <worktree> --script res://outils/captures_mains.gd -- --sortie=<dossier> --prefixe=<nom> \
##       [--instants=repos,charge,lancer,epee] [--titre=<texte>]
##   → <dossier>/<prefixe>_<instant>_jeu.png (vue de jeu) et _zoom.png (deux gros plans côte à côte : main gauche | main
##     droite, champ de ZOOM_FOV° depuis l'œil). Planche : outils/captures_avant_bras_v2.gd --planche (mêmes noms).
## Ne dépend que de l'interface commune (MainSort, mains.avancer, pas_manuel) : tourne aussi sur la base (colonne « avant »).

const SCENE := preload("res://scenes/test_magie.tscn")
const DT := 1.0 / 60.0
const ZOOM_FOV := 40.0
## instant -> [sort gauche, sort droite, action, images avant la capture]
const INSTANTS := {
	"repos": ["boule_feu", "boule_feu", "", 70],
	"charge": ["boule_feu", "boule_feu", "charge", 55],
	"lancer": ["boule_feu", "boule_feu", "lancer", 58],
	"epee": ["boule_feu", "epee", "", 70],
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
	cam_gp.fov = ZOOM_FOV
	cam_gp.near = 0.01
	s.add_child(cam_gp)
	for n in ["hand_l", "hand_r", "middle_02_l", "middle_02_r"]:
		var a := BoneAttachment3D.new()
		a.bone_name = n
		sq.add_child(a)
		_acc[n] = a
	(s.magie as MainSort).eq.apprendre_tout()   # fin du « tout disponible » : tous les sorts
	mains.pas_manuel = true
	RetourCoups.arret_actif = false
	RetourImpact.muet = true


## Gros plan depuis l'œil : caméra du joueur, champ resserré, visée entre le poignet et le milieu des doigts.
func _viser(c: String) -> void:
	var cam: Camera3D = j.camera
	var cible: Vector3 = (_acc["hand_" + c] as Node3D).global_position.lerp((_acc["middle_02_" + c] as Node3D).global_position, 0.6)
	var pos: Vector3 = cam.global_position
	cam_gp.global_transform = Transform3D(Basis.looking_at(cible - pos, cam.global_basis.y), pos)


func _instant(nom: String, prefixe: String) -> void:
	var c: Array = INSTANTS[nom]
	var m: MainSort = s.magie
	m.equiper("droite", c[1])
	m.equiper("gauche", c[0])
	s.placer_joueur(Vector3(0, 0, 1.6), 0.0)
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	for i in 60:
		j.mana = j.mana_max
		mains.avancer(DT)
		await process_frame
	var action: String = c[2]
	var n: int = c[3]
	for i in n + 1:
		j.mana = j.mana_max
		m.recharges.clear()
		match action:
			"charge":
				if i == 5:
					m.appuyer("gauche")
			"lancer":
				if i == 5:
					m.appuyer("gauche")
				elif i == 50:
					m.relacher("gauche")
		mains.avancer(DT)
		await process_frame
	var titre := "%s\n%s" % [_arg("titre", prefixe), nom]
	j.camera.current = true
	l.text = titre
	await process_frame
	await process_frame
	(await _image()).save_png(sortie.path_join("%s_%s_jeu.png" % [prefixe, nom]))
	print("CAPTURE %s_%s_jeu" % [prefixe, nom])
	var vues := []
	for cote in ["l", "r"]:
		_viser(cote)
		cam_gp.current = true
		l.text = "%s  main %s" % [titre, "gauche" if cote == "l" else "droite"]
		await process_frame
		await process_frame
		vues.append(await _image())
	j.camera.current = true
	var w: int = vues[0].get_width()
	var h: int = vues[0].get_height()
	# deux gros plans côte à côte, chacun recadré au centre (moitié de largeur)
	var z := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for k in 2:
		z.blit_rect(vues[k], Rect2i(w / 4, 0, w / 2, h), Vector2i(k * w / 2, 0))
	z.save_png(sortie.path_join("%s_%s_zoom.png" % [prefixe, nom]))
	print("CAPTURE %s_%s_zoom" % [prefixe, nom])
	m.relacher("gauche")
	m.relacher("droite")
	for i in 90:
		j.mana = j.mana_max
		mains.avancer(DT)
	await process_frame


func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/mains"))
	DirAccess.make_dir_recursive_absolute(sortie)
	await _monter()
	var prefixe := _arg("prefixe", "apres")
	for nom in Array(_arg("instants", "repos,charge,lancer,epee").split(",", false)):
		await _instant(nom, prefixe)
	quit()
