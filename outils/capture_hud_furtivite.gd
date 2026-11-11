extends SceneTree
## Captures de l'œil de furtivité (scripts/hud_furtivite.gd) sur scenes/test_combat.tscn (FENÊTRE, via godot_slot.sh : hors écran) :
##   godot --path . --script res://outils/capture_hud_furtivite.gd -- --nouvelle [--sortie=<dossier>]
## Joueur accroupi, jauge forcée à 0 (inaperçu), 0,5 (soupçon) et 1 (repéré) : <nom>.png (640x360) et <nom>_bas_x3.png.

const SCENE := preload("res://scenes/test_combat.tscn")

var s: Node3D
var sortie := "res://captures/hud_furtivite"

func _init() -> void:
	_go.call_deferred()

func _capturer(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var dossier := sortie if sortie.is_absolute_path() and not sortie.begins_with("res://") else ProjectSettings.globalize_path(sortie)
	DirAccess.make_dir_recursive_absolute(dossier)
	img.save_png(dossier.path_join(nom + ".png"))
	var bas := img.get_region(Rect2i(0, img.get_height() - 90, img.get_width(), 90))
	bas.resize(bas.get_width() * 3, bas.get_height() * 3, Image.INTERPOLATE_NEAREST)
	bas.save_png(dossier.path_join(nom + "_bas_x3.png"))
	print("CAPTURE ", dossier.path_join(nom + ".png"), " ", img.get_size())

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30:
		await process_frame
	s.placer_joueur(Vector3(0, 0, 3), 0.0, -4.0)
	var j: Node = s.joueur
	j.s_accroupir(true)
	for cas in [["accroupi_inapercu", 0.0], ["accroupi_soupcon", 0.5], ["accroupi_repere", 1.0]]:
		for i in 60:   # l'œil s'ouvre en douceur : on maintient la jauge
			j.signaler_vigilance(cas[1])
			await process_frame
		var oeil: Control = s.hud.get_children().filter(func(c): return c.get_script() == load("res://scripts/hud_furtivite.gd"))[0]
		print("OEIL taille ", oeil.size, " alpha ", oeil._alpha, " ouvert ", oeil._ouvert, " detection ", j.detection)
		await _capturer(cas[0])
	quit(0)
