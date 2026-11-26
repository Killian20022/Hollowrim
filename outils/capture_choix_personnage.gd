extends SceneTree
## joueur_base : capture de l'écran de choix du personnage (écran titre, mode test : aucun monde lancé).
##   godot --path . --resolution 1600x900 --script res://outils/capture_choix_personnage.gd -- --sortie=<dossier>
##   -> choix_homme.png, choix_femme.png
var sortie := ""

func _init() -> void:
	_go.call_deferred()

func _attendre(n: int) -> void:
	for i in n:
		await process_frame

func _go() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	DirAccess.make_dir_recursive_absolute(sortie)
	var titre: Control = (load("res://scenes/ecran_titre.tscn") as PackedScene).instantiate()
	titre.mode_test = true
	root.add_child(titre)
	await _attendre(150)          # apparition du menu
	titre._ouvrir_choix()
	await _attendre(70)
	root.get_viewport().get_texture().get_image().save_png(sortie.path_join("choix_homme.png"))
	print("CAPTURE choix_homme")
	titre._choix.choisir("femme")
	await _attendre(80)
	root.get_viewport().get_texture().get_image().save_png(sortie.path_join("choix_femme.png"))
	print("CAPTURE choix_femme")
	quit()
