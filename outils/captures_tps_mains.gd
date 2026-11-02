extends SceneTree
## Captures fixes de la 3e personne (branche tps/mains_sorts) : une image par configuration des deux mains, caméra tournée autour du joueur.
##   godot --path . --resolution 960x540 --script res://outils/captures_tps_mains.gd -- --nouvelle --sortie=<dossier> [--jour=1] [--vues=01,10] [--distance=m] [--orbite=°] [--tangage=°]
## Chaque ligne : [nom, main droite, main gauche, action, orbite°] ; action : "" (repos), "maintenir:<main>:<s>" (charge / jet tenu),
## "lancer:<main>" (relâché 0,25 s après l'appui), "double" (les deux mains ensemble). Planche : <sortie>/planche.png.
## N'utilise que l'interface du joueur et de la magie : tourne aussi sur une version « avant ».
const DT := 1.0 / 30.0
const VUES := [
	["01_epee_torche", "epee", "torche", "", -120.0],
	["02_epee_feu_repos", "epee", "jet_flammes", "", -120.0],
	["03_epee_feu_jet", "epee", "jet_flammes", "maintenir:gauche:1.4", -120.0],
	["04_epee_givre_jet", "epee", "souffle_givre", "maintenir:gauche:1.4", -120.0],
	["05_epee_foudre_jet", "epee", "arc_electrique", "maintenir:gauche:1.4", -120.0],
	["06_boule_feu_charge", "epee", "boule_feu", "maintenir:gauche:1.0", -120.0],
	["07_lance_givre_droite_torche", "lance_givre", "torche", "maintenir:droite:1.0", -60.0],
	["08_double_feu", "jet_flammes", "jet_flammes", "double", -160.0],
	["09_epee_bouclier", "epee", "bouclier", "", -120.0],
	["10_claymore", "claymore_longue", "vide", "", -120.0],
	["11_mains_nues", "vide", "vide", "", -150.0],
	["12_dos_feu_jet", "epee", "jet_flammes", "maintenir:gauche:1.4", 0.0],
]

var s: Node
var j: CharacterBody3D
var mg: Node

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		j.mana = j.mana_max
		await process_frame

func _go() -> void:
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""} if _arg("jour", "") != "" else {"draugr": "aucun", "sans-aide": "", "nuit": ""}
	root.add_child(s)
	j = s.joueur
	mg = j.mains.magie
	if mg.eq.has_method("apprendre_tout"):
		mg.eq.apprendre_tout()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.visible = false
	s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	s.hud.visible = false
	j.basculer_vue(true)
	if _arg("distance", "") != "":
		j.camera_tp.bras.spring_length = float(_arg("distance"))
	var dossier := _arg("sortie", "res://captures/tps_mains")
	DirAccess.make_dir_recursive_absolute(dossier)
	await _attendre(1.0)
	var imgs: Array[Image] = []
	var filtre := _arg("vues", "").split(",", false)
	for v in VUES:
		if not filtre.is_empty() and not filtre.has(String(v[0]).substr(0, 2)):
			continue
		s.placer_joueur(Vector3(0, 0, 6.0), 0.0, float(_arg("tangage", "-6")))
		for m in ["droite", "gauche"]:
			var r: String = mg.equiper(m, "vide")
		mg.equiper("droite", String(v[1]))
		var r2: String = mg.equiper("gauche", String(v[2]))
		if r2 != "":
			print("REFUS ", v[0], " ", r2)
		j.camera_tp.set("_orbite", deg_to_rad(float(_arg("orbite", str(v[4])))))
		j.camera_tp.recaler()
		await _attendre(1.2)
		var act: String = v[3]
		if act.begins_with("maintenir:"):
			var p := act.split(":")
			mg.appuyer(p[1])
			await _attendre(float(p[2]))
		elif act == "double":
			mg.appuyer("gauche")
			mg.appuyer("droite")
			await _attendre(1.4)
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(dossier.path_join(String(v[0]) + ".png"))
		imgs.append(img)
		print("CAPTURE ", v[0])
		for m in ["droite", "gauche"]:
			mg.relacher(m)
		await _attendre(0.8)
	# planche : centre de l'image (le personnage), à demi-taille
	var cw := imgs[0].get_width()
	var ch := imgs[0].get_height()
	var zone := Rect2i(int(cw * 0.2), int(ch * 0.12), int(cw * 0.6), int(ch * 0.76))
	var w := zone.size.x * 2 / 3
	var h := zone.size.y * 2 / 3
	var col := 4
	var planche := Image.create(w * col, h * ceili(imgs.size() / float(col)), false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		var im := imgs[i].get_region(zone)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		planche.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % col) * w, (i / col) * h))
	planche.save_png(dossier.path_join("planche.png"))
	print("PLANCHE ", dossier)
	quit(0)
