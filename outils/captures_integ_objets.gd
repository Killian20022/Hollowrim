extends SceneTree
## Captures de contrôle de l'INTÉGRATION objets/armures (branche integration/objets) dans le VRAI JEU (scenes/foret_test.tscn,
## FENÊTRE hors écran via godot_slot.sh) :
##   godot --path . --fixed-fps 60 --audio-driver Dummy --script res://outils/captures_integ_objets.gd -- --nouvelle --paisible --sortie=<dossier>
## Vues : menu Sac (aperçu 3D d'une armure), Équipement, héros à la 3e personne avec 4 ensembles (cuir, fourrure, fer, acier
## nordique) face / dos + caméra de jeu, bras FPS gantés, armure lâchée au sol, étal de Brodd, râtelier de la maison.
const SCENE := preload("res://scenes/foret_test.tscn")
const ENSEMBLES := {
	"cuir": ["capuche_cuir", "armure_cuir", "gants_cuir", "bottes_cuir"],
	"fourrure": ["casque_fourrure", "armure_fourrure", "gants_fourrure", "bottes_fourrure"],
	"fer": ["casque_fer", "cuirasse_fer", "gantelets_fer", "bottes_fer"],
	"acier": ["casque_acier_nordique", "cuirasse_acier_nordique", "gantelets_acier_nordique", "bottes_acier_nordique"],
}
var m: Node3D
var j: CharacterBody3D
var sortie := "res://captures/integ_objets"

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	_go.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _midi() -> void:
	m.cycle.heure = 12.0
	m.cycle._process(0.0)

func _capturer(nom: String) -> void:
	await _images(4)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var dossier := ProjectSettings.globalize_path(sortie) if sortie.begins_with("res://") else sortie
	DirAccess.make_dir_recursive_absolute(dossier)
	img.save_png(dossier.path_join(nom + ".png"))
	print("CAPTURE ", nom, " ", img.get_size())

func _sol(x: float, z: float) -> float:
	var h := float(m.hauteur(x, z))
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 3.0, z), Vector3(x, h - 3.0, z))
	q.exclude = [j.get_rid()]
	var r := m.get_world_3d().direct_space_state.intersect_ray(q)
	var y := float(r["position"].y) if not r.is_empty() else h
	return y + ObjetMonde.hausse_sol(Vector3(x, y, z), m)

func _interface(v: bool) -> void:
	for cl in m.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = v
	if m.hud != null:
		m.hud.visible = v

func _equiper(ids: Array) -> void:
	for e in ["tete", "torse", "mains", "pieds"]:
		j.equipement_corps.retirer(e)
	for id: String in ids:
		j.inventaire.ajouter(id, 1)
		var r: String = j.equipement_corps.equiper(id)
		if r != "":
			print("REFUS ", id, " : ", r)
	print("PORTE ", ids, " zones ", j.corps.armure.zones() if j.corps != null and j.corps.armure != null else "?")

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(90)
	if m.get("village") != null and m.village.has_signal("bati_fini") and not m.village.bati:
		await m.village.bati_fini
	m.hud.aide_t = 0.0
	m.hud.lieux_vus["Skarnholt"] = true
	_midi()
	j = m.joueur
	var inv: Inventaire = j.inventaire
	inv.pieces = 9000
	for o: Array in [["epee_soldat", 1], ["hache_guerre", 1], ["potion_soin", 3], ["pain_seigle", 2], ["anneau_braise", 1]]:
		inv.ajouter(o[0], o[1])
	for id in ENSEMBLES["acier"] + ENSEMBLES["fer"] + ["armure_cuir", "armure_fourrure", "casque_os"]:
		inv.ajouter(id, 1)
	_equiper(ENSEMBLES["fer"])

	# --- 1. menu Sac : aperçu 3D d'une armure ; Équipement
	var ui: InventaireMains = m.inventaire_ui
	ui.ouvrir("sac")
	await _images(10)
	var sac := ui.onglet("sac") as OngletSac
	sac.filtrer("armure")
	sac.choisir("cuirasse_acier_nordique")
	sac.queue_redraw()
	await _images(40)
	await _capturer("01_menu_sac_apercu_cuirasse_acier")
	sac.choisir("casque_fer")
	sac.queue_redraw()
	await _images(40)
	await _capturer("02_menu_sac_apercu_casque_fer")
	ui.changer_onglet("equipement")
	var oe := ui.onglet("equipement") as OngletEquipement
	oe.sel = 1
	oe.queue_redraw()
	await _images(30)
	await _capturer("03_menu_equipement")
	ui.fermer()
	await _images(10)

	# --- 2. héros à la 3e personne, 4 ensembles, face / dos (caméra fixe) + caméra de jeu
	_interface(false)
	var c := Vector3(38.2, 0.0, 44.4)
	j.global_position = Vector3(c.x, _sol(c.x, c.z) + 0.1, c.z)
	j.velocity = Vector3.ZERO
	j.rotation.y = 0.0
	j.basculer_vue(true)
	await _images(40)
	j.set_physics_process(false)
	var cam := Camera3D.new()
	cam.fov = 40.0
	m.add_child(cam)
	for f: String in ENSEMBLES:
		_equiper(ENSEMBLES[f])
		_midi()
		await _images(30)
		var p := j.global_position
		var devant := -j.global_transform.basis.z
		for v: Array in [["face", 0.0], ["dos", 180.0]]:
			var dir := devant.rotated(Vector3.UP, deg_to_rad(v[1] + 20.0))
			cam.global_position = p + dir * 3.2 + Vector3(0, 1.25, 0)
			cam.look_at(p + Vector3(0, 0.95, 0), Vector3.UP)
			cam.current = true
			await _images(12)
			await _capturer("1%d_heros_%s_%s" % [ENSEMBLES.keys().find(f), f, v[0]])
		cam.current = false
		j.camera_tp.set("_orbite", 0.0)
		j.camera_tp.recaler()
		j.camera_tp.camera.current = true
		await _images(20)
		await _capturer("1%d_heros_%s_camera_jeu" % [ENSEMBLES.keys().find(f), f])

	# --- 3. 1re personne : bras gantés (gantelets d'acier nordique portés)
	j.basculer_vue(false)
	j.mains.visible = true
	j.tete.rotation.x = -0.35
	await _images(40)
	_midi()
	await _capturer("20_fps_gantelets_acier")
	j.mains.visible = false

	# --- 4. armure lâchée au sol (Lacher -> ObjetMonde, glb « sol »)
	j.set_physics_process(true)
	for oid: String in ["cuirasse_fer", "casque_os", "armure_fourrure"]:
		j.inventaire.ajouter(oid, 1)
		print("LACHER ", oid, " ", Lacher.lacher(j, m.hud, oid, 1))
		j.rotation.y += 0.9
		await _images(6)
	await _images(20)
	j.set_physics_process(false)
	var pied := j.global_position
	cam.global_position = pied + Vector3(0.3, 1.9, 2.4)
	cam.look_at(pied + Vector3(0, 0.1, 0), Vector3.UP)
	cam.current = true
	j.visible = false
	_midi()
	await _images(20)
	await _capturer("30_armures_lachees_au_sol")
	j.visible = true

	# --- 5. étal de Brodd
	var et: Node3D = m.find_child("Etal_forgeron", true, false)
	if et != null:
		print("ETAL brodd : ", et.pieces())
		var avant: Vector3 = et.global_transform * Vector3(0.35, 0.0, 1.45)
		avant.y = _sol(avant.x, avant.z) + 1.6
		var haut: Vector3 = et.global_transform * Vector3(0.0, 0.62, 0.0)
		cam.global_position = avant
		cam.look_at(haut, Vector3.UP)
		_midi()
		await _images(20)
		await _capturer("40_etal_brodd")
		var loin: Vector3 = et.global_transform * Vector3(1.4, 0.0, 3.4)
		loin.y = _sol(loin.x, loin.z) + 1.65
		cam.global_position = loin
		cam.look_at(haut, Vector3.UP)
		await _images(12)
		await _capturer("41_etal_brodd_recul")
	else:
		print("INFO pas d'étal de Brodd")
	cam.current = false

	# --- 6. râtelier de la maison (achetée, armes dans le coffre)
	var sv: ServicesPnj = m.services
	print("MAISON ", sv.acheter_maison())
	var km := Stockage.conteneur("coffre_maison")
	for id in ["claymore", "marteau_guerre", "epee_doree", "hache_guerre"]:
		km.ajouter(id, 1)
	sv._actualiser_ratelier()
	var im: Interieur = m.village.interieur(Stockage.MAISON)
	im.basculer(true, false)
	j.global_position = im.to_global(Vector3(-1.7, 0.5, -0.1))
	j.velocity = Vector3.ZERO
	m._viser(im.to_global(ServicesPnj.RATELIER + Vector3(0, 0.75, 0)))
	await _images(300)
	_midi()
	await _capturer("50_maison_ratelier")
	j.global_position = im.to_global(Vector3(-2.9, 0.5, -0.3))
	m._viser(im.to_global(ServicesPnj.RATELIER + Vector3(0, 0.6, 0)))
	await _images(30)
	await _capturer("51_maison_ratelier_pres")
	quit(0)
