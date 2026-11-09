extends SceneTree
## Captures de l'accueil du joueur (FENÊTRE, via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/captures_accueil.gd -- --nouvelle --prologue --aides --sortie=<dossier>
## Écrit : arrivée (pages 1 et 3), premier objectif + cartouche des touches, bulles d'aide (combat, coffre, menu),
## dialogue « après » (Gunnar une fois l'anneau rendu), fin du premier chapitre.
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node
var sortie := "res://captures/accueil"

func _init() -> void:
	_go.call_deferred()

func _capturer(nom: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var dossier := sortie if sortie.is_absolute_path() else ProjectSettings.globalize_path(sortie)
	DirAccess.make_dir_recursive_absolute(dossier)
	var x2 := img.duplicate() as Image
	x2.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	x2.save_png(dossier.path_join(nom + ".png"))
	print("CAPTURE ", nom, " ", img.get_size())

func _villageois(id: String) -> Node3D:
	for v in m.get_tree().get_nodes_in_group("villageois"):
		if v.donnees.get("id") == id:
			return v
	return null

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame
	await create_timer(1.6).timeout
	await _capturer("01_arrivee_page1")
	m.narration.page = 2
	m.narration._t = 0.0
	await create_timer(1.3).timeout
	await _capturer("02_arrivee_page3")
	m.narration.page = 3
	m.narration._t = 0.0
	m.narration._terminer()
	await create_timer(1.0).timeout
	m.hud._objectif_t = 4.0
	await create_timer(0.6).timeout
	await _capturer("03_premier_objectif_et_touches")
	m.hud.aide_t = 0.0
	var a: Aides = m.aides
	for cle in ["ennemi", "coffre", "menu", "sort"]:
		a._cle = ""
		a._repit = 0.0
		a._file.clear()
		a.proposer(cle)
		await create_timer(1.2).timeout
		await _capturer("04_bulle_" + cle)
	a._cle = ""
	# dialogue « après » : l'anneau est rendu, Gunnar parle du hameau et de Kaldborg
	m.quetes.importer({"etat": {"anneau_givre": 6, "bienvenue": 2, "horizon_sud": 2}, "vus": ["fini:anneau_givre"], "journal": []})
	var chef := _villageois("chef")
	chef.deja_parle = true
	var j: CharacterBody3D = m.joueur
	j.global_position = chef.global_position + Vector3(0.0, 0.1, 2.2)
	var d := chef.global_position - j.global_position
	j.rotation.y = atan2(-d.x, -d.z)
	await create_timer(0.5).timeout
	m.dialogue._ouvrir(chef)
	await create_timer(3.5).timeout
	await _capturer("05_dialogue_apres_gunnhild")
	m.dialogue._fermer()
	m.narration.lancer(m.quetes.texte("epilogue_titre")[0], m.quetes.texte("epilogue"), m.quetes.texte("epilogue_sous_titre")[0])
	m.narration.page = 1
	await create_timer(2.2).timeout
	await _capturer("06_fin_premier_chapitre")
	quit()
