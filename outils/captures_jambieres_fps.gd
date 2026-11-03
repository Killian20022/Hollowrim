extends SceneTree
## Captures 960x540 des JAMBIÈRES (emplacement « jambes ») et des GANTS / GANTELETS en 1re personne (ArmureVisible._habiller_fps).
## FENÊTRE (godot_slot.sh : hors écran).
##   godot --path . --script res://outils/captures_jambieres_fps.gd -- --nouvelle --fps --sortie=<dossier> [--gants=gants_cuir,gantelets_fer]
##     -> <gants>_repos.png (épée au poing, sort tenu en attente à gauche), _epee.png (épée levée : attaque puissante armée), _sort.png (sort en charge
##        à la main gauche, épée à droite), _torche.png (torche à gauche)
##   godot --path . --script res://outils/captures_jambieres_fps.gd -- --nouvelle --heros --sortie=<dossier>
##     -> heros_<combinaison>.png (torse + jambières différents, 3/4 dos puis face), sol_jambieres.png (paires posées au sol)
const DT := 1.0 / 60.0
const GANTS := ["gants_cuir", "gantelets_fer", "gantelets_acier_nordique", "gantelets_verre", "gantelets_obsidienne"]
const COMBOS := {
	"fer_et_or": ["cuirasse_fer", "jambieres_or"],
	"cuir_et_acier": ["armure_cuir", "jambieres_acier_nordique"],
	"obsidienne_et_verre": ["cuirasse_obsidienne", "jambieres_verre"],
	"jambieres_seules": ["", "jambieres_fourrure"],
	"acier_seules": ["", "jambieres_acier_nordique"],
	"torse_sans_jambieres": ["cuirasse_os", ""],
}
var s: Node3D
var j: CharacterBody3D
var mains: Node3D
var sortie := ""
var cam: Camera3D

func _init() -> void:
	_go.call_deferred()

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
		if a == "--" + nom:
			return "1"
	return defaut

func _plein_ecran() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 540)
	await process_frame

func _image(nom: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var im := root.get_viewport().get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	im.save_png(sortie.path_join(nom + ".png"))
	print("CAPTURE ", nom, " ", im.get_size())

func _equiper(ids: Array) -> void:
	for e in ["tete", "torse", "mains", "pieds", "jambes"]:
		j.equipement_corps.retirer(e)
	for id: String in ids:
		if id == "":
			continue
		j.inventaire.ajouter(id, 1)
		var r: String = j.equipement_corps.equiper(id)
		if r != "":
			print("REFUS ", id, " : ", r)

func _attendre(n: int) -> void:
	for i in n:
		j.mana = j.mana_max
		j.vigueur = j.vigueur_max
		await process_frame

func _go() -> void:
	sortie = _arg("sortie", ProjectSettings.globalize_path("res://captures/jambieres_fps"))
	DirAccess.make_dir_recursive_absolute(sortie)
	if _arg("fps") != "":
		await _fps()
	else:
		await _heros()
	quit()

# ------------------------------------------------------------------------------------------------------------- 1re personne
func _fps() -> void:
	s = load("res://scenes/test_magie.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame
	await _plein_ecran()
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
	mains.pas_manuel = true
	RetourCoups.arret_actif = false
	RetourImpact.muet = true
	var liste: Array = Array(_arg("gants", ",".join(GANTS)).split(",", false))
	for g in liste:
		_equiper(["jambieres_cuir", g] if g != "aucun" else [])
		for inst in ["repos", "epee", "sort", "torche"]:
			await _instant(String(g), inst)

func _instant(g: String, inst: String) -> void:
	var m: MainSort = s.magie
	m.equiper("droite", "epee")
	m.equiper("gauche", "jet_flammes" if inst in ["repos", "sort"] else ("torche" if inst == "torche" else "vide"))
	s.placer_joueur(Vector3(0, 0, 1.6), 0.0)
	mains.combat.forcer(EtatCombat.REPOS)
	mains.entrees.relacher()
	mains.entrees.tampon = -1.0
	mains._combo = 0
	for i in 60:
		j.mana = j.mana_max
		mains.avancer(DT)
		await process_frame
	var n := 0
	match inst:
		"epee":
			n = 62
		"sort":
			n = 40
	for i in n + 1:
		j.mana = j.mana_max
		j.vigueur = j.vigueur_max
		m.recharges.clear()
		match inst:
			"epee":
				if i == 0:
					mains.entrees.appuyer()
				elif i == 52:
					mains.entrees.relacher()
			"sort":
				if i == 5:
					m.appuyer("gauche")
		mains.avancer(DT)
		await process_frame
	j.camera.current = true
	await _image("%s_%s" % [g, inst])
	m.relacher("gauche")
	m.relacher("droite")
	mains.entrees.relacher()
	for i in 90:
		mains.avancer(DT)
	await process_frame

# ------------------------------------------------------------------------------------------------------------- héros
func _soleil_de_face() -> void:
	var c := root.get_viewport().get_camera_3d()
	if c == null or s.soleil == null:
		return
	var avant := -c.global_transform.basis.z
	avant.y = 0.0
	if avant.length() < 0.01:
		return
	avant = avant.normalized().rotated(Vector3.UP, deg_to_rad(-25.0))
	s.soleil.global_transform = Transform3D(Basis.looking_at((avant + Vector3(0, -0.85, 0)).normalized(), Vector3.UP), s.soleil.global_position)

func _placer_cam(deg: float, dist: float, h: float, hc: float) -> void:
	var p := j.global_position
	var dir := (-j.global_transform.basis.z).rotated(Vector3.UP, deg_to_rad(deg))
	cam.global_position = p + dir * dist + Vector3(0, hc, 0)
	cam.look_at(p + Vector3(0, h, 0), Vector3.UP)

func _heros() -> void:
	s = load("res://scenes/test_combat.tscn").instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	mains = j.mains
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.mannequin.visible = false
	s.mannequin.process_mode = Node.PROCESS_MODE_DISABLED
	s.placer_joueur(Vector3(0, 0, 6.0), 0.0, -6.0)
	j.basculer_vue(true)
	for n in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	mains.magie.equiper("droite", "vide")
	mains.magie.equiper("gauche", "vide")
	await _plein_ecran()
	cam = Camera3D.new()
	cam.fov = 34.0
	s.add_child(cam)
	cam.current = true
	await _attendre(60)
	for k in COMBOS:
		_equiper(COMBOS[k])
		var mj := j.corps.armure.maillage("jambes") as MeshInstance3D
		print(k, " zones ", j.corps.armure.zones(), " jambes=", j.corps.armure.porte("jambes"), " mat=", mj.get_surface_override_material(0).resource_name if mj else "-", " tris=", mj.mesh.surface_get_array_index_len(0) / 3 if mj else 0)
		await _attendre(40)
		j.rotation.y = 0.0
		for v in [["face", 0.0], ["dos", 180.0], ["profil", 90.0]]:
			_soleil_de_face()
			_placer_cam(v[1], 3.3, 0.95, 1.1)
			_soleil_de_face()
			await _attendre(10)
			await _image("heros_%s_%s" % [k, v[0]])
	# paires posées au sol
	var ids := ["jambieres_cuir", "jambieres_fer", "jambieres_os", "jambieres_verre", "jambieres_obsidienne", "jambieres_or"]
	for i in ids.size():
		var n := ArmureVisible.instancier_sol(ids[i])
		if n == null:
			print("SOL MANQUE ", ids[i])
			continue
		s.add_child(n)
		var devant := -j.global_transform.basis.z
		n.global_position = j.global_position + devant * 1.5 + devant.cross(Vector3.UP) * (-1.0 + 0.4 * i)
	_equiper([])
	await _attendre(20)
	var centre := j.global_position + (-j.global_transform.basis.z) * 1.5
	cam.global_position = centre + Vector3(0, 3.4, 2.6)
	cam.look_at(centre, Vector3.UP)
	await _attendre(10)
	await _image("sol_jambieres")
