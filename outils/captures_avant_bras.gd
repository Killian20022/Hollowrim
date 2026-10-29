extends SceneTree
## Captures des avant-bras FPS et de la magie au repos (cadrage des références Jeux/references/avant_bras_magie/
## bras_*_1100.jpg) — FENÊTRE via godot_slot.sh (hors écran) :
##   godot --path . --script res://outils/captures_avant_bras.gd -- --sortie=<dossier> [--cas=a,b,…] [--film=<n>]
## Cas : double_feu (défaut), epee_feu, torche_epee, bouclier, vide, deux_armes, charge_feu.
## --film=<n> : n images espacées de 0,1 s du premier cas (respiration, doigts, runes) → <cas>_fNN.png.
## --marche : le joueur avance pendant la capture (balancement des mains).
## --sans-ps1 : post-traitement et accroche PS1 coupés (planche « rendu sans ps1 »).
## --ambiance=crepuscule (défaut, ciel gris-mauve et soleil bas devant, comme bras_feu_1100.jpg) | nuit.
## HUD masqué (le rectangle du post-traitement ps1 reste) ; scène test_magie.

const SCENE := preload("res://scenes/test_magie.tscn")
const CAS := {
	"double_feu": ["jet_flammes", "jet_flammes"],
	"epee_feu": ["jet_flammes", "epee"],
	"torche_epee": ["torche", "epee"],
	"bouclier": ["bouclier", "epee"],
	"vide": ["vide", "vide"],
	"charge_feu": ["boule_feu", "boule_feu"],
}

var s: Node3D
var sortie := ""

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _sauver(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(sortie.path_join(nom + ".png"))
	print("CAPTURE ", nom)

func _attendre(t: float) -> void:
	await create_timer(t).timeout

func _go() -> void:
	sortie = _arg("sortie", "user://captures_avant_bras")
	DirAccess.make_dir_recursive_absolute(sortie)
	s = SCENE.instantiate()
	var ambiance := _arg("ambiance", "crepuscule")
	s.options = {"draugr": "aucun", "sans-aide": ""}
	if ambiance == "nuit":
		s.options["nuit"] = ""
	root.add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await process_frame
	if ambiance == "crepuscule":
		var env: Environment = s.env
		env.background_color = Color(0.30, 0.27, 0.31)
		env.ambient_light_color = Color(0.52, 0.48, 0.56)
		env.ambient_light_energy = 0.42
		var so: DirectionalLight3D = s.soleil
		so.basis = Basis.looking_at(Vector3(-0.2, -0.25, 0.95), Vector3.UP)   # soleil bas, au fond : contre-jour
		so.light_color = Color(1.0, 0.72, 0.52)
		so.light_energy = 0.55
	# HUD, aide et titres masqués ; le rectangle du post-traitement ps1 (ColorRect au shader ps1_post) reste
	for n in root.find_children("*", "CanvasLayer", true, false):
		for c in n.get_children():
			var garder: bool = c is ColorRect and (c as ColorRect).material is ShaderMaterial
			if c is CanvasItem and not garder:
				(c as CanvasItem).visible = false
			elif garder and _arg("sans-ps1") != "":
				((c as ColorRect).material as ShaderMaterial).set_shader_parameter("actif", false)
	if _arg("sans-ps1") != "":
		Palette.regler_ps1(false)
	# cadrage des références : ni étiquettes de mannequins ni mannequins devant les mains
	for n in root.find_children("*", "Label3D", true, false):
		(n as Label3D).visible = false
	for nom in ["mannequin", "mannequin2", "mannequin3"]:
		var mq = s.get(nom)
		if mq is Node3D:
			(mq as Node3D).visible = false
	var m: MainSort = s.magie
	var liste := _arg("cas", "double_feu").split(",")
	var film := int(_arg("film", "0"))
	for nom in liste:
		var c: Array = CAS.get(nom, CAS["double_feu"])
		m.equiper("droite", c[1])
		m.equiper("gauche", c[0])
		s.placer_joueur(Vector3(0, 0, 1.6), 0.0)
		s.joueur.mana = 100.0
		await _attendre(1.2)
		if nom == "charge_feu":
			m.appuyer("gauche")
			m.appuyer("droite")
			await _attendre(0.8)
		if _arg("marche") != "":
			Input.action_press("avant")
		if film > 0:
			for k in film:
				await _sauver("%s_f%02d" % [nom, k])
				await _attendre(0.1)
		else:
			await _sauver(nom)
			if _arg("dbg-os") != "":
				await _dbg_os()
		Input.action_release("avant")
		m.relacher("gauche")
		m.relacher("droite")
		await _attendre(0.3)
	quit(0)

## --dbg-os : positions des os des bras (après IK, via BoneAttachment3D) dans le repère caméra et à l'écran (0..1).
func _dbg_os() -> void:
	var cam: Camera3D = s.joueur.camera
	var sq: Skeleton3D = s.joueur.mains.get("_sq")
	var acc := []
	for nom in ["upperarm_l", "lowerarm_l", "hand_l", "middle_01_l", "upperarm_r", "lowerarm_r", "hand_r", "middle_01_r"]:
		var a := BoneAttachment3D.new()
		a.bone_name = nom
		sq.add_child(a)
		acc.append(a)
	await process_frame
	await process_frame
	for a: BoneAttachment3D in acc:
		var g := a.global_position
		var e := cam.unproject_position(g) / Vector2(root.get_viewport().get_visible_rect().size)
		print("OS ", a.bone_name, " cam=", cam.global_transform.affine_inverse() * g, " ecran=", e)
		a.queue_free()
	for k in ["gauche", "droite"]:
		var pm: Node3D = s.magie.paume[k]
		if pm != null:
			print("OS paume_", k, " ecran=", cam.unproject_position(pm.global_position) / Vector2(root.get_viewport().get_visible_rect().size))
