extends SceneTree
## Captures des répliques filtrées et du journal daté (FENÊTRE, via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/captures_dialogue_filtre.gd -- --nouvelle --paisible --sortie=<dossier>
## Écrit : Ylva (même PNJ) de jour puis de nuit avec l'anneau en cours, puis son « après » (anneau pas commencé) ;
## le journal des quêtes avec ses entrées datées (jour de jeu, heure) — le menu des quêtes est ouvert à la fin.
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node
var sortie := "res://captures/dialogue_filtre"

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

func _dialogue(id: String, heure: float, nom: String) -> void:
	m.cycle.heure = heure
	m.cycle._process(0.0)
	m.hud.aide_t = 0.0
	await create_timer(0.8).timeout   # le village se met à l'heure (ses habitants rejoignent leur poste)
	var v := _villageois(id)
	v.deja_parle = true
	var j: CharacterBody3D = m.joueur
	j.global_position = v.global_position + Vector3(0.0, 0.1, 2.2)
	var d := v.global_position - j.global_position
	j.rotation.y = atan2(-d.x, -d.z)
	await process_frame
	var ouvert: bool = m.dialogue.engager(v)
	print("dialogue ", id, " à ", heure, " h : ouvert=", ouvert, " lignes=", m.dialogue._lignes.size(), " endormi=", v.get("etat"))
	await create_timer(3.6).timeout
	if m.dialogue._lignes.size() > 2:   # la réplique du moment (« la nuit tombe ») vient d'abord : on passe à celle du journal
		m.dialogue._suite()
		await create_timer(3.0).timeout
	print("   encore ouvert : ", m.dialogue._ouvert)
	await _capturer(nom)
	m.dialogue._fermer()

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
	await create_timer(1.0).timeout
	# journal daté sur trois jours de jeu
	m.quetes.importer({"etat": {"bienvenue": 2, "anneau_givre": 4, "frere_ylva": 3}, "vus": [], "dates": {
		"bienvenue:0": [1, 21.0], "bienvenue:1": [1, 21.5], "anneau_givre:0": [1, 21.6], "frere_ylva:0": [1, 21.7],
		"anneau_givre:1": [2, 9.5], "frere_ylva:1": [2, 11.0], "frere_ylva:2": [2, 14.2], "anneau_givre:2": [3, 8.2], "anneau_givre:3": [3, 10.4]}})
	m.cycle.jour = 3
	# 1 et 2 : même PNJ, anneau en cours, jour puis nuit ; 3 : anneau pas commencé
	await _dialogue("chasseuse", 12.0, "dialogue_1_ylva_jour_anneau_en_cours")
	await _dialogue("chasseuse", 19.5, "dialogue_2_ylva_nuit_anneau_en_cours")
	m.quetes.importer({"etat": {"frere_ylva": 3}, "vus": []})
	await _dialogue("chasseuse", 12.0, "dialogue_3_ylva_jour_anneau_pas_commence")
	# journal : le menu des quêtes montre l'état daté
	m.quetes.importer({"etat": {"bienvenue": 2, "anneau_givre": 4, "frere_ylva": 3}, "vus": [], "dates": {
		"bienvenue:0": [1, 21.0], "bienvenue:1": [1, 21.5], "anneau_givre:0": [1, 21.6], "frere_ylva:0": [1, 21.7],
		"anneau_givre:1": [2, 9.5], "frere_ylva:1": [2, 11.0], "frere_ylva:2": [2, 14.2], "anneau_givre:2": [3, 8.2], "anneau_givre:3": [3, 10.4]}})
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n.has_method("ouvrir") and "_onglets" in n:
			n.ouvrir("quetes")
	await create_timer(1.0).timeout
	await _capturer("journal_quetes_dates")
	quit()
