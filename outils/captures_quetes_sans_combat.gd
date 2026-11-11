extends SceneTree
## Captures des deux quêtes sans combat (FENÊTRE, via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/captures_quetes_sans_combat.gd -- --nouvelle --paisible --sortie=<dossier>
## Écrit : la serrure du grenier (invite), la trappe de la grange (fermée puis ouverte après la vérité), le choix de Grima, le
## journal du grenier ; Ylva au feu le soir avec son choix, le choix de Brodd (le foyer), le journal de l'écorce.
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node
var q: Node
var sortie := "res://captures/quetes_sans_combat"

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

func _parler(id: String) -> void:
	_villageois(id).parler()
	_villageois(id).fin_conversation()

## Le joueur se place à `dist` m de `cible`, la regarde (caméra baissée de `tangage` rad).
func _regarder(cible: Vector3, depuis: Vector3, tangage := -0.15) -> void:
	var j: CharacterBody3D = m.joueur
	j.global_position = depuis
	var d := cible - depuis
	j.rotation.y = atan2(-d.x, -d.z)
	var cam: Node3D = j.get("tete") if j.get("tete") is Node3D else null
	if cam != null:
		cam.rotation.x = tangage
	await create_timer(0.6).timeout

## Conversation jusqu'à la liste des choix (dernière réplique), puis capture.
func _choix(id: String, heure: float, nom: String) -> void:
	m.cycle.heure = heure
	m.cycle._process(0.0)
	await create_timer(0.8).timeout
	var v := _villageois(id)
	v.deja_parle = true
	await _regarder(v.global_position + Vector3(0, 1.4, 0), v.global_position + Vector3(0.0, 0.1, 2.2))
	var d: Control = m.dialogue
	print("dialogue ", id, " : ouvert=", d.engager(v), " lignes=", d._lignes.size(), " choix=", d._options.map(func(o): return o["texte"]))
	for k in 40:
		if d._choix_vis or not d._ouvert:
			break
		d._suite()
		await create_timer(0.15).timeout
	await create_timer(0.8).timeout
	await _capturer(nom)
	d._fermer()

func _journal(id: String, nom: String) -> void:
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n.has_method("ouvrir") and "_onglets" in n:
			n.ouvrir("quetes")
	await create_timer(0.6).timeout
	for o in root.find_children("*", "", true, false):
		if o is OngletQuetes:
			(o as OngletQuetes).choix = id
			(o as OngletQuetes).queue_redraw()
	await create_timer(0.6).timeout
	await _capturer(nom)
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n.has_method("fermer") and "_onglets" in n:
			n.fermer()
	await create_timer(0.4).timeout

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
	await create_timer(1.5).timeout
	q = m.quetes
	m.hud.aide_t = 0.0
	var r: RecitsVillage = m.get_node("RecitsVillage")
	m.cycle.heure = 11.0
	m.cycle._process(0.0)
	# --- le grenier qui maigrit
	_parler("ancienne")
	_parler("ancienne")
	var s: Vector3 = r.serrure.global_position
	var depuis := s + (r.serrure.get_parent() as Node3D).global_basis.z * 1.6
	depuis.y = m.hauteur(depuis.x, depuis.z) + 0.1
	await _regarder(s, depuis, -0.05)
	await create_timer(0.6).timeout
	await _capturer("grenier_1_serrure")
	r.serrure.action.call()
	var t: Vector3 = (r.paille.get_parent() as Node3D).global_position
	var ia := r.paille.get_parent().get_parent() as Node3D
	await _regarder(t, t + ia.global_basis.x * 1.9 + Vector3(0, 0.05, 0), -0.55)
	await create_timer(1.0).timeout
	await _capturer("grenier_2_trappe_grange")
	r.paille.action.call()
	await process_frame
	_parler("chef")
	await _choix("ancienne", 11.0, "grenier_3_choix_grima")
	q.choisir_option("grenier_maigre", "verite")
	await create_timer(0.7).timeout
	await _regarder(t, t + ia.global_basis.x * 1.9 + Vector3(0, 0.05, 0), -0.55)
	await create_timer(0.8).timeout
	await _capturer("grenier_4_trappe_ouverte")
	await _journal("grenier_maigre", "grenier_5_journal")
	# --- l'écorce au fil rouge
	_parler("chasseuse")
	_parler("forgeron")
	_parler("volva")
	_parler("volva")
	m.cycle.heure = 19.2
	m.cycle._process(0.0)
	await create_timer(1.5).timeout
	_villageois("chasseuse").deja_parle = true
	await _choix("chasseuse", 19.2, "ecorce_1_choix_ylva_soir")
	await _choix("forgeron", 19.6, "ecorce_2_choix_brodd")
	await _choix("volva", 20.0, "ecorce_3_choix_sigrun")
	q.choisir_option("fil_rouge", "brulee")
	_parler("volva")
	await _journal("fil_rouge", "ecorce_4_journal")
	quit()
