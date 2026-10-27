extends SceneTree
## Captures de l'interface de combat (HudCombat en mode démo) sur le vrai décor de scenes/test_combat.tscn
## (FENÊTRE, via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/capture_hud_combat.gd -- --nouvelle [--sortie=captures/hud_combat]
## Écrit pour chaque cas <nom>.png (640x360), <nom>_x2.png (agrandie, plus proche voisin) et <nom>_bas_x3.png
## (bande du bas, 640x90 agrandie x3, pour juger les pixels).

const SCENE := preload("res://scenes/test_combat.tscn")

var s: Node3D
var sortie := "res://captures/hud_combat"

func _init() -> void:
	_go.call_deferred()

func _monter(options: Dictionary) -> void:
	if s != null:
		s.queue_free()
		await process_frame
	s = SCENE.instantiate()
	s.options = options
	root.add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await process_frame

func _capturer(nom: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var dossier := ProjectSettings.globalize_path(sortie)
	DirAccess.make_dir_recursive_absolute(dossier)
	img.save_png(dossier.path_join(nom + ".png"))
	var x2 := img.duplicate() as Image
	x2.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	x2.save_png(dossier.path_join(nom + "_x2.png"))
	var bas := img.get_region(Rect2i(0, img.get_height() - 90, img.get_width(), 90))
	bas.resize(bas.get_width() * 3, bas.get_height() * 3, Image.INTERPOLATE_NEAREST)
	bas.save_png(dossier.path_join(nom + "_bas_x3.png"))
	print("CAPTURE ", dossier.path_join(nom + ".png"), " ", img.get_size())

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	# [nom, nuit, double, instant figé]
	for cas in [["jour_demo", false, false, 1.3], ["nuit_demo_mana_bas", true, false, 4.5], ["jour_double", false, true, 1.9]]:
		var opts := {"draugr": "aucun", "sans-aide": ""}
		if cas[1]:
			opts["nuit"] = ""
		await _monter(opts)
		s.placer_joueur(Vector3(0, 0, 3), 0.0, -4.0)
		var ui: Control = s.hud.combat_ui
		ui.demo = true
		ui.demo_double = cas[2]
		ui.demo_t = cas[3]
		await _capturer(cas[0])
	# données réelles (sans démo) : vie entamée, torche sortie → main gauche = torche (repli sans signal)
	await _monter({"draugr": "aucun", "sans-aide": ""})
	s.placer_joueur(Vector3(0, 0, 3), 0.0, -4.0)
	s.joueur.vie = 64.0
	s.joueur.vigueur = 30.0
	for i in 40:
		await process_frame
	await _capturer("jour_reel")
	quit(0)
