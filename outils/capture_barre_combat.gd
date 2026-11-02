extends SceneTree
## Barre d'objets en VRAI combat (sans démo) sur scenes/test_combat.tscn, draugr actif qui charge le joueur :
##   godot --path . --script res://outils/capture_barre_combat.gd -- --nouvelle [--barre=a] [--sortie=captures/barre/combat_reel]
## 1. combat.png : en combat, vie entamée (cartouche des mains + jauges) ;
## 2. combat_change.png : touche 2 pressée en plein combat (sort de feu | épée) → ruban déroulé ;
## 3. combat_nuit.png : la même chose de nuit, ruban replié.

const SCENE := preload("res://scenes/test_combat.tscn")

var s: Node3D
var sortie := "res://captures/barre/combat_reel"

func _init() -> void:
	_go.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _capturer(nom: String) -> void:
	await _images(3)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var dossier := ProjectSettings.globalize_path(sortie)
	DirAccess.make_dir_recursive_absolute(dossier)
	img.save_png(dossier.path_join(nom + ".png"))
	print("CAPTURE ", nom, " ", img.get_size())

func _monter(options: Dictionary) -> void:
	if s != null:
		s.queue_free()
		await process_frame
	s = SCENE.instantiate()
	s.options = options
	root.add_child(s)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _images(30)

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	for nuit in [false, true]:
		await _monter({"sans-aide": ""} if not nuit else {"sans-aide": "", "nuit": ""})
		s.placer_joueur(Vector3(0, 0, 3), 0.0, -4.0)
		s.joueur.vie = 58.0
		# le draugr charge : on attend qu'il soit en combat (au plus ~6 s)
		for i in 360:
			await process_frame
			if s.draugr != null and s.draugr.has_method("en_combat") and s.draugr.en_combat():
				break
		s.joueur.vie = 58.0
		await _images(30)
		if nuit:
			await _capturer("combat_nuit")
			continue
		await _capturer("combat")
		var magie: Variant = s.joueur.mains.get("magie") if s.joueur.get("mains") != null else null
		if magie != null and magie.has_method("raccourci"):
			magie.raccourci(1)
		await _images(14)
		await _capturer("combat_change")
	quit(0)
