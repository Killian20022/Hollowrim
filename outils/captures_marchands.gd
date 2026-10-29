extends SceneTree
## Captures du lot L8 « marchands » (FENÊTRE hors écran via godot_slot.sh) :
##   godot --path . --fixed-fps 60 --audio-driver Dummy --script res://outils/captures_marchands.gd -- --nouvelle --paisible --sortie=<dossier>
## Vues : dialogue de Brodd (« [T] Commercer »), dernière réplique (choix « Commercer / Au revoir »), boutique de Brodd (Acheter, après
## un achat, Vendre avec un objet de quête, étal vide), boutique de Grima, et la boutique en 480x270.
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var sortie := ""
var args := {}

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	sortie = String(args.get("sortie", "res://captures/marchands_l8"))
	_go.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _capturer(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var dossier := ProjectSettings.globalize_path(sortie) if sortie.begins_with("res://") else sortie
	DirAccess.make_dir_recursive_absolute(dossier)
	var f := dossier.path_join(nom + ".png")
	img.save_png(f)
	print("CAPTURE ", f, " ", img.get_size())

func _pnj(id: String) -> Node3D:
	for p in get_nodes_in_group("villageois"):
		if p.donnees.get("id") == id:
			return p
	return null

## Joueur à 1,7 m devant le PNJ, regard sur son visage, PNJ figé.
func _devant(p: Node3D) -> void:
	p.set_physics_process(false)
	var dir: Vector3 = p.global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.BACK
	var j: CharacterBody3D = m.joueur
	j.global_position = p.global_position + dir * 1.7 + Vector3(0, 0.1, 0)
	j.velocity = Vector3.ZERO
	m._viser(p.global_position + Vector3(0, 1.45, 0))

func _jour() -> void:
	m.cycle.heure = 12.0
	m.cycle._process(0.0)

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(60)
	if m.village.has_signal("prets"):
		await _images(30)
	m.hud.aide_t = 0.0          # pas de cartouche d'aide des touches sur les captures
	m.joueur.mains.visible = false
	var j: CharacterBody3D = m.joueur
	var inv: Inventaire = j.inventaire
	var d: Control = m.dialogue
	var mb: Marchand = m.marchand
	var brodd := _pnj("forgeron")
	var grima := _pnj("ancienne")
	# --- dialogue de Brodd
	_jour()
	_devant(brodd)
	await _images(40)
	d._ouvrir(brodd)
	await _images(150)
	_jour()
	await _capturer("1_dialogue_brodd_commercer")
	var n := 0
	while d._ouvert and not d._choix_vis and n < 40:
		d._suite()
		await _images(4)
		n += 1
	await _images(150)
	_jour()
	await _capturer("2_dialogue_brodd_choix")
	# --- boutique de Brodd : Acheter
	inv.pieces = 260
	d.commercer()
	await _images(10)
	await _capturer("3_boutique_brodd_acheter")
	mb._choisir(3)
	mb.traiter()
	await _images(4)
	await _capturer("4_boutique_brodd_apres_achat")
	# --- Vendre (objets du sac, dont un objet de quête)
	for oid: String in ["collier_or", "lame_antique", "potion_soin", "os_draugr", "croc_troll", "anneau_givre", "epee_or"]:
		inv.ajouter(oid, 2 if oid in ["lame_antique", "os_draugr", "potion_soin"] else 1)
	mb.changer_onglet(1)
	mb._choisir(1)
	await _images(4)
	mb._avis_t = 0.0
	await _images(2)
	await _capturer("5_boutique_brodd_vendre")
	# --- 480x270
	mb.changer_onglet(0)
	root.content_scale_size = Vector2i(480, 270)
	await _images(6)
	await _capturer("6_boutique_brodd_480x270")
	root.content_scale_size = Vector2i(640, 360)
	await _images(4)
	# --- étal vide
	inv.pieces = 100000
	while not mb.lignes.is_empty():
		mb.traiter(0, true)
	mb._avis_t = 0.0
	inv.pieces = 412
	await _images(4)
	await _capturer("7_boutique_brodd_etal_vide")
	mb.fermer()
	await _images(4)
	# --- Grima
	_devant(grima)
	await _images(30)
	_jour()
	inv.pieces = 94
	mb.ouvrir("ancienne")
	mb._choisir(1)
	await _images(6)
	await _capturer("8_boutique_grima_acheter")
	mb.fermer()
	quit()
