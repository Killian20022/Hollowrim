extends SceneTree
## Captures du lot L7 sur scenes/test_combat.tscn (FENÊTRE, via godot_slot.sh : hors écran) : inventaire (I) et menu pause (Échap)
## avec le cadre ornementé (MenuStyle.cadre), aide des touches, annonce centrée.
##   godot --path . --script res://outils/capture_menus_l7.gd -- --nouvelle [--sortie=captures/menus_l7]

const SCENE := preload("res://scenes/test_combat.tscn")

var s: Node3D
var sortie := "res://captures/menus_l7"

func _init() -> void:
	_go.call_deferred()

func _capturer(nom: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var dossier := ProjectSettings.globalize_path(sortie) if sortie.begins_with("res://") else sortie
	DirAccess.make_dir_recursive_absolute(dossier)
	img.save_png(dossier.path_join(nom + ".png"))
	print("CAPTURE ", dossier.path_join(nom + ".png"), " ", img.get_size())

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40:
		await process_frame
	s.placer_joueur(Vector3(0, 0, 3), 0.0, -4.0)
	s.hud.demarrer()
	s.hud.annonce("Épée", "Niveau 16")
	for i in 30:
		await process_frame
	await _capturer("annonce_niveau_aide")
	s.hud.aide_t = 0.0
	s.inventaire_ui.ouvrir()
	await _capturer("inventaire")
	s.inventaire_ui.basculer()
	var pause := CanvasLayer.new()
	pause.set_script(preload("res://scripts/menu_pause.gd"))
	pause.set("monde", s)
	root.add_child(pause)
	await process_frame
	pause.ouvrir()
	await _capturer("menu_pause")
	paused = false
	quit()
