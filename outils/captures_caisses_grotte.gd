extends SceneTree
## Captures des caisses cassables de la grotte (matières jute / laine / lin / pierre_v2 des modules Quaternius : texture « Invalid image: null »
## avant la correction de GrotteDecor.PAINT_PARENT). FENÊTRE hors écran via godot_slot.sh, --fixed-fps 60.
##   godot --path . --fixed-fps 60 --audio-driver Dummy --script res://outils/captures_caisses_grotte.gd -- --nouvelle --paisible --sortie=<dossier>
## Se place devant les 3 premières caisses de la grotte (groupe « cassables », genre caisse) : une vue chacune.
const SCENE := preload("res://scenes/foret_test.tscn")
var m: Node3D
var sortie := ""

func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	_go.call_deferred()

func _images(n: int) -> void:
	for i in n:
		await process_frame

func _capturer(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(sortie)
	img.save_png(sortie.path_join(nom + ".png"))
	print("CAPTURE ", nom, " ", img.get_size())

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(30)
	var ga: Node3D = m.grotte_acces
	ga.attendre_exterieur()
	ga.obtenir()
	ga.montrer(true)
	m._aller_grotte("4,0,0,0")
	await _images(60)
	m.hud.aide_t = 0.0
	m.joueur.mains.visible = false
	var caisses: Array = []
	for c in get_nodes_in_group("cassables"):
		if c is Cassable and (c as Cassable).genre == "caisse" and ga.is_ancestor_of(c):
			caisses.append(c)
	print("CAISSES : ", caisses.size())
	var j: CharacterBody3D = m.joueur
	var k := 0
	for c: Cassable in caisses:
		if k >= 3:
			break
		var cp := c.global_position + Vector3(0, 0.35, 0)
		# vue à ~1,6 m, du côté de la caisse tourné vers le centre de la galerie (le joueur est déposé au sol le plus proche)
		var d := Vector3(sin(0.6 + k), 0, cos(0.6 + k))
		j.global_position = Vector3(cp.x, cp.y - 0.3, cp.z) + d * 1.6
		j.velocity = Vector3.ZERO
		j.rotation.y = atan2(d.x, d.z)
		await _images(25)
		var v: Vector3 = cp - j.camera.global_position
		j.tete.rotation.x = atan2(v.y, Vector2(v.x, v.z).length())
		await _images(15)
		await _capturer("caisse_%d" % k)
		k += 1
	quit(0)
