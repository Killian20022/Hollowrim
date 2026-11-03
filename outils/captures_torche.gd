extends SceneTree
## Captures (et film) de la torche en gros pixels : 1re personne (arrêt, marche, course, virage, saut) puis 3e personne.
##   godot --path <worktree> --script res://outils/captures_torche.gd -- --nouvelle --sortie=<dossier> --prefixe=<avant|apres>
##   ajouter --film (avec --write-movie <f.avi> --fixed-fps 30) : enchaîne arrêt, marche, course, virage, arrêt, sans captures.
## Fenêtre (godot_slot.sh : hors écran), scène test_combat, crépuscule sombre pour que la flamme et sa lumière se lisent.
## Les PNG sont enregistrés en 960x540 (agrandissement au plus proche voisin).

const SCENE := preload("res://scenes/test_combat.tscn")
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var sortie := ""
var prefixe := "apres"
var titre: Label

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _tenir(actions: Array, n: int, souris_px := 0.0) -> void:
	for i in n:
		for a in ["avant", "course", "saut", "gauche", "droite"]:
			if a in actions:
				Input.action_press(a)
			else:
				Input.action_release(a)
		if souris_px != 0.0:
			var d := Vector2(souris_px, 0.0)
			var k := 0.0022 * Jeu.sensibilite
			j.rotate_y(-d.x * k)
			mains.passifs.souris(d * Jeu.sensibilite)
			mains.noter_souris(d)
		await physics_frame
	for a in ["avant", "course", "saut", "gauche", "droite"]:
		Input.action_release(a)

func _attendre(n: int) -> void:
	for i in n:
		await physics_frame

func _photo(nom: String) -> void:
	if sortie == "":
		return
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	im.resize(960, 540, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(sortie)
	var c := sortie.path_join("%s_%s.png" % [prefixe, nom])
	im.save_png(c)
	print("CAPTURE ", c)

func _penombre() -> void:
	var env: Environment = s.env
	env.background_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_color = Color(0.30, 0.34, 0.46)
	env.ambient_light_energy = 0.30
	var so: DirectionalLight3D = s.soleil
	so.light_energy = 0.12
	so.light_color = Color(0.55, 0.65, 0.95)

func _go() -> void:
	prefixe = _arg("prefixe", "apres")
	sortie = _arg("sortie")
	var film := _arg("film") != ""
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame
	_penombre()
	titre = Label.new()
	titre.add_theme_font_override("font", Palette.police())
	titre.add_theme_font_size_override("font_size", Palette.TAILLE_POLICE)
	titre.position = Vector2(6, 4)
	var cl := CanvasLayer.new()
	cl.layer = 70
	s.add_child(cl)
	cl.add_child(titre)
	if not mains.torche_sortie:
		mains.set("torche_sortie", true)
	var p := 60
	s.placer_joueur(Vector3(6, 0, -17), 180.0)
	await _attendre(40)
	if film:
		titre.text = "Arret"
		await _attendre(p * 2)
		titre.text = "Marche"
		await _tenir(["avant"], p * 2)
		titre.text = "Course"
		await _tenir(["avant", "course"], p * 2)
		titre.text = "Virage en courant"
		for k in 3:
			await _tenir(["avant", "course"], p / 2, 1400.0 / 60.0)
			await _tenir(["avant", "course"], p / 2, -1400.0 / 60.0)
		titre.text = "Saut"
		await _tenir(["avant", "saut"], 2)
		await _tenir(["avant"], p)
		titre.text = "Arret"
		await _attendre(p * 3)
		quit()
		return
	await _attendre(60)
	await _photo("1p_arret")
	await _tenir(["avant"], 70)
	await _photo("1p_marche")
	await _tenir(["avant", "course"], 100)
	await _photo("1p_course")
	await _tenir(["avant", "course"], 45, 1300.0 / 60.0)
	await _photo("1p_virage")
	await _tenir([], 4)
	await _attendre(90)
	await _photo("1p_arret2")
	# troisième personne
	j.basculer_vue(true)
	s.placer_joueur(Vector3(6, 0, -17), 180.0)
	await _attendre(60)
	await _photo("3p_arret")
	await _tenir(["avant"], 70)
	await _photo("3p_marche")
	await _tenir(["avant", "course"], 100)
	await _photo("3p_course")
	await _tenir(["avant", "course"], 40, 1300.0 / 60.0)
	await _photo("3p_virage")
	quit()
