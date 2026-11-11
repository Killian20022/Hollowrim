extends SceneTree
## Captures du premier combat guidé (FENÊTRE, via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/capture_combat_guide.gd -- --nouvelle --sortie=<dossier>
## Écrit : les quatre bulles du guide face au draugr isolé (bloquer, frapper, coup puissant, se soigner) et la bulle « vol vu ».
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node
var sortie := "res://captures/combat_guide"

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
	var a: Aides = m.aides
	var d: CharacterBody3D = a.guide_cible
	var j: CharacterBody3D = m.joueur
	m.hud.aide_t = 0.0
	a.actif = true
	# le joueur 5 m au sud-ouest du rôdeur, face à lui
	j.global_position = d.global_position + Vector3(-3.0, 0.3, 4.0)
	var v := d.global_position - j.global_position
	j.rotation.y = atan2(-v.x, -v.z)
	await create_timer(1.2).timeout
	a.vues = {}
	a._file.clear()
	a._cle = ""
	d.etat = d.TRAQUE
	a._sonder()
	await create_timer(1.0).timeout
	await _capturer("01_bloquer")
	for cle in ["guide_frappe", "guide_puissant"]:
		a._montrer(cle)
		await create_timer(0.8).timeout
		await _capturer("02_frapper" if cle == "guide_frappe" else "03_coup_puissant")
	j.vie = j.vie_max * 0.45
	a._montrer("guide_soin")
	a._g_vie = j.vie   # sinon le guide croit qu'il s'est déjà soigné et retire la bulle
	await create_timer(0.8).timeout
	await _capturer("04_se_soigner")
	a._cle = ""
	a.vues = {}
	a.proposer("vol")
	a._repit = 0.0
	await create_timer(0.9).timeout
	await _capturer("05_vol_vu")
	print("CAPTURES FINIES")
	quit()
