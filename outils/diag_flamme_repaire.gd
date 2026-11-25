extends SceneTree
## Diagnostic : d'où vient la grosse flamme centrale du film ? Sauve 4 images : normale / corps masqué / corps+mains masqués.
const SCENE := preload("res://scenes/foret_test.tscn")
var s: Node3D
func _arg(nom: String, defaut := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + nom + "="):
			return a.substr(nom.length() + 3)
	return defaut
func _init() -> void:
	_go.call_deferred()
func _snap(nom: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_arg("sortie"), nom])
func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_arg("sortie"))
	s = SCENE.instantiate()
	root.add_child(s)
	current_scene = s
	for i in 90:
		await process_frame
	var j: CharacterBody3D = s.joueur
	var g: Grotte = s.grotte
	s.hud.visible = false
	var phys := _arg("phys", "0") == "1"
	j.set_physics_process(phys)
	for i in 20:
		await process_frame
	j.velocity = Vector3.ZERO
	j.global_position = g.monde_sol(10.0, 0.0) + Vector3(0, 0.05, 0)
	j.rotation.y = g.cap_monde(10.0)
	for i in 10:
		await process_frame
	await _snap("a_normal")
	print("corps visible ", j.corps.visible, " pivot_torche ", j.corps.pivot_torche.visible, " troisieme ", j.troisieme)
	j.corps.visible = false
	for i in 3: await process_frame
	await _snap("b_sans_corps")
	j.corps.visible = true
	j.mains.visible = false
	for i in 3: await process_frame
	await _snap("c_sans_mains")
	quit(0)
