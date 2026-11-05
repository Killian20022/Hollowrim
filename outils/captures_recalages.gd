extends SceneTree
## Captures « avant / après » d'objets recalés (audit 2026-11-04, lot bugs). FENÊTRE hors écran via godot_slot.sh, --fixed-fps 60.
##   godot --path . --fixed-fps 60 --audio-driver Dummy --script res://outils/captures_recalages.gd -- --nouvelle --paisible --sortie=<dossier>
##        --vue=nom:x:z:hauteur_de_visee:distance:lacet_degres  (répétable ; x, z en repère monde, la hauteur est celle du relief)
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var sortie := ""
var vues: Array = []

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
		elif a.begins_with("--vue="):
			vues.append(a.substr(6).split(":"))
	_go.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(60)
	m.hud.aide_t = 0.0
	m.joueur.mains.visible = false
	var j: CharacterBody3D = m.joueur
	for v: Array in vues:
		var x := float(v[1])
		var z := float(v[2])
		var sol: float = m.hauteur(x, z)
		var cible := Vector3(x, sol + float(v[3]), z)
		var lacet := deg_to_rad(float(v[5]))
		var d := Vector3(sin(lacet), 0, cos(lacet))
		var px := x + d.x * float(v[4])
		var pz := z + d.z * float(v[4])
		j.global_position = Vector3(px, m.hauteur(px, pz) + 0.1, pz)
		j.velocity = Vector3.ZERO
		j.rotation.y = atan2(d.x, d.z)
		await _images(25)
		var dv: Vector3 = cible - j.camera.global_position
		j.tete.rotation.x = atan2(dv.y, Vector2(dv.x, dv.z).length())
		await _images(15)
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(sortie)
		img.save_png(sortie.path_join(String(v[0]) + ".png"))
		print("CAPTURE ", v[0])
	quit(0)
