extends SceneTree
## Capture EN JEU des personnages vivants (monde reel, shaders et eclairage du jeu) : charge la scene principale, cherche un villageois (--id=forgeron)
## ou les bandits, place le joueur devant lui et enregistre une image.
##   godot --path . --script res://outils/capture_perso_jeu.gd -- --nouvelle --paisible --heure=12 --id=forgeron --dist=3 --sortie=res://captures/persos/jeu/forgeron.png
## Sans --id : liste les positions des villageois et quitte.
var t := 0.0
var etat := 0

func _init() -> void:
	root.add_child((load("res://scenes/foret_test.tscn") as PackedScene).instantiate())

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _process(delta: float) -> bool:
	t += delta
	if t < 6.0:
		return false
	var id := _arg("id", "")
	if etat == 0:
		for p in get_nodes_in_group("villageois"):
			print("VILLAGEOIS ", p.donnees.get("id"), " ", p.global_position)
		if id == "":
			quit(0)
			return true
		var cible: Node3D = null
		for p in get_nodes_in_group("villageois"):
			if p.donnees.get("id") == id:
				cible = p
		if cible == null:
			push_error("villageois introuvable : " + id)
			quit(1)
			return true
		var joueur: CharacterBody3D = cible.joueur
		var dist := float(_arg("dist", "3.0"))
		var az := deg_to_rad(float(_arg("az", "0")))
		var dir := Vector3(sin(az), 0, cos(az))
		joueur.global_position = cible.global_position + dir * dist + Vector3(0, 0.1, 0)
		joueur.rotation.y = atan2(dir.x, dir.z)
		joueur.tete.rotation.x = deg_to_rad(float(_arg("tangage", "-3")))
		cible.set_physics_process(false) if _arg("fige", "") != "" else null
		etat = 1
		t = 5.0
		return false
	if etat == 1 and t > 7.5:
		var img := root.get_viewport().get_texture().get_image()
		var chemin := ProjectSettings.globalize_path(_arg("sortie", "res://captures/persos/jeu/capture.png"))
		DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
		img.save_png(chemin)
		print("capture : ", chemin)
		quit(0)
	return false
