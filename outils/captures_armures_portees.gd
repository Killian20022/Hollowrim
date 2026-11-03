extends SceneTree
## Captures de l'ARMURE PORTÉE (scripts/rpg/armure_visible.gd) sur le héros à la 3e personne, scène de combat de jour :
##   planches : godot --path . --resolution 960x540 --script res://outils/captures_armures_portees.gd -- --nouvelle --sortie=<dossier>
##              [--familles=cuir,fourrure,os] -> <famille>_face.png, _tq.png, _dos.png, _profil.png, _sol.png, (+ sans_armure_*.png)
##   film     : godot --path . --write-movie <f.avi> --fixed-fps 30 --resolution 960x540 --script res://outils/captures_armures_portees.gd
##              -- --nouvelle --film [--familles=…] : par famille, marche (caméra de jeu, de dos puis de 3/4 face) + combo 1-2-3-4.
const DT := 1.0 / 30.0
const PIECES := {
	"cuir": ["capuche_cuir", "armure_cuir", "gants_cuir", "bottes_cuir"],
	"fourrure": ["casque_fourrure", "armure_fourrure", "gants_fourrure", "bottes_fourrure"],
	"os": ["casque_os", "cuirasse_os", "gants_os", "bottes_os"],
	"fer": ["casque_fer", "cuirasse_fer", "gantelets_fer", "bottes_fer"],
	"acier": ["casque_acier_nordique", "cuirasse_acier_nordique", "gantelets_acier_nordique", "bottes_acier_nordique"],
	"uniques": ["heaume_jarl", "cuirasse_gardiens", "gantelets_hrafn", "bottes_rodeur"],
	"uniques2": ["capuche_thaumaturge", "brigandine_braise", "gants_cuir", "bottes_cuir"],
	"rubis": ["casque_rubis", "cuirasse_rubis", "gantelets_rubis", "bottes_rubis"],
	"saphir": ["casque_saphir", "cuirasse_saphir", "gantelets_saphir", "bottes_saphir"],
	"rubis_enchante": ["casque_rubis_enchante", "cuirasse_rubis_enchante", "gantelets_rubis_enchante", "bottes_rubis_enchante"],
	"saphir_enchante": ["casque_saphir_enchante", "cuirasse_saphir_enchante", "gantelets_saphir_enchante", "bottes_saphir_enchante"],
}
const NOMS := {"sans_armure": "Heros sans armure (reference)", "cuir": "CUIR", "fourrure": "FOURRURE", "os": "OS DE DRAUGR",
	"fer": "FER", "acier": "ACIER NORDIQUE", "uniques": "UNIQUES (Jarl, gardiens, Hrafn, rodeur)", "uniques2": "UNIQUES (thaumaturge, braise) + cuir",
	"rubis": "RUBIS", "saphir": "SAPHIR", "rubis_enchante": "RUBIS ENCHANTE", "saphir_enchante": "SAPHIR ENCHANTE"}
var s: Node
var j: CharacterBody3D
var mains: Node3D
var cam: Camera3D
var l: Label
var sortie := ""
var familles: Array = ["cuir", "fourrure", "os"]
var film := false
var jambes := false
var studio := false        # --studio : pose de repos (mains vides), face + gros plans (gemme-noyau, heaume, jambes) + cuirasse posée de face
var chevilles := false     # gros plans des chevilles (bottes portées), sert au contrôle des fentes

func _init() -> void:
	_go.call_deferred()

func _attendre(sec: float) -> void:
	for i in maxi(1, roundi(sec / DT)):
		j.mana = j.mana_max
		j.vigueur = j.vigueur_max
		_soleil_de_face()
		await process_frame

## Éclairage de face : le soleil vient de derrière la caméra active (un peu au-dessus, un peu de côté).
func _soleil_de_face() -> void:
	var c := root.get_viewport().get_camera_3d()
	if c == null or s.soleil == null:
		return
	var avant := -c.global_transform.basis.z
	avant.y = 0.0
	if avant.length() < 0.01:
		return
	avant = avant.normalized().rotated(Vector3.UP, deg_to_rad(-25.0))
	var dir := (avant + Vector3(0, -0.85, 0)).normalized()
	s.soleil.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), s.soleil.global_position)

func _equiper_famille(f: String) -> void:
	for e in ["tete", "torse", "mains", "pieds"]:
		j.equipement_corps.retirer(e)
	for id: String in PIECES.get(f, f.split("+")):
		if Inventaire.connu(id):
			j.inventaire.ajouter(id, 1)
			var r: String = j.equipement_corps.equiper(id)
			if r != "":
				print("REFUS ", id, " : ", r)
	print("FAMILLE ", f, " portées : ", j.corps.armure.zones())

func _capture(nom: String, rect := Rect2i(), texte := "") -> void:
	_soleil_de_face()
	var k0 := root.get_viewport().get_visible_rect().size.y / 540.0
	l.text = texte
	l.position = Vector2(rect.position) * k0 + Vector2(4, 2)
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	if rect.size != Vector2i.ZERO:
		# rect donné pour 960x540 : mis à l'échelle de l'image réelle
		var k := img.get_height() / 540.0
		img = img.get_region(Rect2i(Vector2i(Vector2(rect.position) * k), Vector2i(Vector2(rect.size) * k)))
		if k != 1.0:
			img.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_NEAREST)
	print("  image ", root.get_viewport().get_texture().get_size())
	img.save_png(sortie.path_join(nom + ".png"))
	print("CAPTURE ", nom)

## Caméra fixe : regarde le héros depuis la direction `deg` (0 = de face, 180 = de dos), à `dist` m, visée à `h` m.
func _placer_cam(deg: float, dist := 2.5, h := 1.0, hc := 1.15) -> void:
	var p := j.global_position
	var devant := -j.global_transform.basis.z
	var dir := devant.rotated(Vector3.UP, deg_to_rad(deg))
	cam.global_position = p + dir * dist + Vector3(0, hc, 0)
	cam.look_at(p + Vector3(0, h, 0), Vector3.UP)

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
		elif a.begins_with("--familles="):
			familles = a.substr(11).split(",")
		elif a == "--film":
			film = true
		elif a == "--jambes":
			jambes = true
		elif a == "--chevilles":
			chevilles = true
		elif a == "--studio":
			studio = true
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.visible = false
	s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	var calque := CanvasLayer.new()
	calque.layer = 60
	s.add_child(calque)
	l = Label.new()
	l.add_theme_font_override("font", Palette.police())
	l.add_theme_font_size_override("font_size", 12 if not film else 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(10, 8)
	calque.add_child(l)
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -6.0)
	j.basculer_vue(true)
	if not film:
		for n in root.find_children("*", "CanvasLayer", true, false):
			if n != calque:
				(n as CanvasLayer).visible = false   # planches : sans l'interface
	mains.magie.equiper("droite", "epee")
	mains.magie.equiper("gauche", "vide")
	await _attendre(1.0)
	if film:
		await _film()
	elif studio:
		await _studio()
	elif chevilles:
		await _chevilles()
	elif jambes:
		await _jambes()
	else:
		await _planches()
	quit()

func _planches() -> void:
	DirAccess.make_dir_recursive_absolute(sortie)
	cam = Camera3D.new()
	cam.fov = 40.0
	s.add_child(cam)
	cam.current = true
	var vues := {"face": 0.0, "tq": 40.0, "profil": 90.0, "dos": 180.0}
	var cadre := Rect2i(300, 0, 360, 540)
	for f in ["sans_armure"] + familles:
		if f == "sans_armure":
			_equiper_famille("")
		else:
			_equiper_famille(f)
		l.text = ""
		await _attendre(0.6)
		for v in vues:
			_placer_cam(vues[v], 3.6, 0.95, 1.2)
			await _attendre(0.15)
			await _capture("%s_%s" % [f, v], cadre, "%s - %s" % [NOMS.get(f, f), {"face": "face", "tq": "3/4", "profil": "profil", "dos": "dos"}[v]])
		# gros plan du haut du corps (tête, épaules, mains) de 3/4 face et de 3/4 dos
		for v in {"buste": 30.0, "buste_dos": 150.0}:
			_placer_cam({"buste": 30.0, "buste_dos": 150.0}[v], 1.5, 1.35, 1.55)
			await _attendre(0.15)
			await _capture("%s_%s" % [f, v], Rect2i(240, 0, 480, 540), "buste " + ("3/4 face" if v == "buste" else "3/4 dos"))
		if f == "sans_armure":
			continue
		# pièces posées au sol, devant le héros (vue plongeante)
		var poses: Array[Node3D] = []
		var ids: Array = PIECES.get(f, [])
		for i in ids.size():
			var n := ArmureVisible.instancier_sol(ids[i])
			if n == null:
				continue
			s.add_child(n)
			var devant := -j.global_transform.basis.z
			var cote := devant.cross(Vector3.UP)
			n.global_position = j.global_position + devant * 1.6 + cote * (-1.05 + 0.7 * i)
			n.rotation.y = j.rotation.y + PI
			poses.append(n)
		j.visible = false
		var c := j.global_position + (-j.global_transform.basis.z) * 1.6
		cam.global_position = c + (-j.global_transform.basis.z) * 2.3 + Vector3(0, 1.7, 0)
		cam.look_at(c + Vector3(0, 0.1, 0), Vector3.UP)
		await _attendre(0.2)
		await _capture("%s_sol" % f, Rect2i(120, 70, 720, 400), "pieces posees au sol (sol/<id>.glb)")
		for n in poses:
			n.queue_free()
		j.visible = true

func _film() -> void:
	for f in familles:
		_equiper_famille(f)
		j.camera_tp.set("_orbite", 0.0)
		l.text = "Armure %s : marche (de dos)" % f
		await _attendre(0.6)
		Input.action_press("avant")
		await _attendre(2.2)
		Input.action_release("avant")
		await _attendre(0.4)
		l.text = "Armure %s : combo 1-2-3-4" % f
		for k in 4:
			mains.entrees.appuyer()
			await _attendre(0.05)
			mains.entrees.relacher()
			await _attendre(0.42)
		await _attendre(0.6)
		j.camera_tp.set("_orbite", deg_to_rad(150.0))
		l.text = "Armure %s : de 3/4 face" % f
		await _attendre(0.5)
		Input.action_press("avant")
		await _attendre(1.6)
		Input.action_release("avant")
		await _attendre(0.3)
		for k in 4:
			mains.entrees.appuyer()
			await _attendre(0.05)
			mains.entrees.relacher()
			await _attendre(0.42)
		await _attendre(0.8)
		s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -6.0)
		j.camera_tp.recaler()


## Planche « jambes » : par famille, torse seul / bottes seules / torse + bottes, de face, de profil et de dos, cadré sur le bas du
## corps (contrôle : aucune partie de jambe ne disparaît entre les pièces).
func _chevilles() -> void:
	DirAccess.make_dir_recursive_absolute(sortie)
	cam = Camera3D.new()
	cam.fov = 40.0
	s.add_child(cam)
	cam.current = true
	for f in familles:
		_equiper_famille(f)
		await _attendre(0.5)
		for v in {"face": 0.0, "g": -35.0, "d": 35.0, "dos": 180.0}:
			_placer_cam({"face": 0.0, "g": -35.0, "d": 35.0, "dos": 180.0}[v], 0.9, 0.16, 0.30)
			await _attendre(0.12)
			await _capture("c_%s_%s" % [f, v], Rect2i(240, 0, 480, 540), "%s chevilles %s" % [NOMS.get(f, f), v])

func _jambes() -> void:
	DirAccess.make_dir_recursive_absolute(sortie)
	cam = Camera3D.new()
	cam.fov = 40.0
	s.add_child(cam)
	cam.current = true
	for f in familles:
		var ids: Array = PIECES.get(f, [])
		var torse := ""
		var pieds := ""
		for id: String in ids:
			match Inventaire.emplacement_de(id):
				"torse": torse = id
				"pieds": pieds = id
		for combo in [["torse", [torse]], ["pieds", [pieds]], ["torse_pieds", [torse, pieds]]]:
			_equiper_famille("+".join(combo[1]))
			await _attendre(0.5)
			for v in {"face": 0.0, "profil": 90.0, "dos": 180.0}:
				_placer_cam({"face": 0.0, "profil": 90.0, "dos": 180.0}[v], 2.6, 0.62, 0.75)
				await _attendre(0.12)
				await _capture("j_%s_%s_%s" % [f, combo[0], v], Rect2i(330, 0, 300, 540), "%s %s %s" % [NOMS.get(f, f), combo[0].replace("_", "+"), v])


## Studio : mains vides (pose de repos), de face : silhouette entière, gros plans du torse (gemme-noyau), de la tête et des jambes ;
## puis la cuirasse seule posée au sol, vue de face d'en haut.
func _studio() -> void:
	DirAccess.make_dir_recursive_absolute(sortie)
	cam = Camera3D.new()
	cam.fov = 30.0
	s.add_child(cam)
	cam.current = true
	mains.magie.equiper("droite", "vide")
	mains.magie.equiper("gauche", "vide")
	for f in familles:
		_equiper_famille(f)
		await _attendre(1.0)
		_placer_cam(0.0, 5.2, 0.95, 1.1)
		await _attendre(0.2)
		await _capture("%s_studio" % f, Rect2i(300, 0, 360, 540), "%s - studio" % NOMS.get(f, f))
		_placer_cam(0.0, 5.2, 0.95, 1.1)
		_placer_cam(-25.0, 5.2, 0.95, 1.1)
		await _attendre(0.2)
		await _capture("%s_studio_tq" % f, Rect2i(300, 0, 360, 540), "%s - studio 3/4" % NOMS.get(f, f))
		_placer_cam(-20.0, 3.0, 1.0, 1.25)
		await _attendre(0.2)
		await _capture("%s_a3m" % f, Rect2i(240, 0, 480, 540), "vue a 3 m")
		_placer_cam(0.0, 1.5, 1.38, 1.4)
		await _attendre(0.2)
		await _capture("%s_gp_torse" % f, Rect2i(240, 0, 480, 540), "torse (gemme-noyau)")
		_placer_cam(0.0, 1.3, 1.70, 1.72)
		await _attendre(0.2)
		await _capture("%s_gp_tete" % f, Rect2i(240, 0, 480, 540), "heaume")
		_placer_cam(0.0, 2.4, 0.55, 0.6)
		await _attendre(0.2)
		await _capture("%s_gp_jambes" % f, Rect2i(240, 0, 480, 540), "jambes")
		# cuirasse seule, posée de face
		var ids: Array = PIECES.get(f, [])
		var n := ArmureVisible.instancier_sol(ids[1])
		if n == null:
			continue
		s.add_child(n)
		var devant := -j.global_transform.basis.z
		var c := j.global_position + devant * 1.6
		n.global_position = c
		n.rotation.y = j.rotation.y + PI
		j.visible = false
		cam.global_position = c + devant * 0.9 + Vector3(0, 2.6, 0)
		cam.look_at(c + Vector3(0, 0.05, 0), Vector3.UP)
		await _attendre(0.2)
		await _capture("%s_sol_cuirasse" % f, Rect2i(240, 0, 480, 540), "cuirasse posee")
		n.queue_free()
		j.visible = true
