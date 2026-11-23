extends SceneTree
## Vue fixe du marché (tonneaux, caisses, sacs) pour comparer -- --sans-cassables-partout : avant / après (mêmes pixels attendus).
##   godot --path . --script res://outils/capture_cassables_partout.gd -- --nouvelle --paisible --sortie=<fichier.png> [--vue=x,z,cx,cz]
const SCENE := preload("res://scenes/foret_test.tscn")

func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var s: Node3D = SCENE.instantiate()
	root.add_child(s)
	current_scene = s
	for i in 2400:
		await process_frame
		if s.village != null and s.village.get("prets") == true:
			break
	var j: CharacterBody3D = s.joueur
	s.cycle.heure = 11.0
	s.hud.aide_t = 0.0
	j.mains.visible = false
	j.set_physics_process(false)
	var v := _arg("vue", "47.0,33.6,50.5,31.0").split_floats(",")
	j.global_position = Vector3(v[0], float(s.hauteur(v[0], v[1])) + 0.02, v[1])
	var cible := Vector3(v[2], float(s.hauteur(v[2], v[3])) + 0.4, v[3])
	for i in 60:
		await process_frame
		var d: Vector3 = cible - j.camera.global_position
		j.rotation.y = atan2(-d.x, -d.z)
		j.tete.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_arg("sortie", "user://capture_cass.png"))
	print("CAPTURE ", _arg("sortie"))
	quit(0)
