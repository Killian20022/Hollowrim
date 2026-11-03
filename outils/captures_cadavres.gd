extends SceneTree
## Captures « cadavres fouillables » (fenêtre hors écran via godot_slot.sh) : un gardien de la crypte tué (cadavre + invite de fouille),
## puis la même dépouille restaurée comme après un chargement de partie (Butin.restaurer, vrai modèle en pose Death01).
##   godot --path . --fixed-fps 60 --audio-driver Dummy --script res://outils/captures_cadavres.gd -- --nouvelle --paisible --sortie=<dossier>
const SCENE := preload("res://scenes/foret_test.tscn")
const BUTIN := preload("res://scripts/butin.gd")

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
	var f := sortie.path_join(nom + ".png")
	img.save_png(f)
	print("CAPTURE ", f, " ", img.get_size())

## Le joueur à `dist` m du point, en regardant vers lui.
func _face(p: Vector3, dist: float) -> void:
	var j: CharacterBody3D = m.joueur
	var depuis: Vector3 = m.tertre.crypte.to_global(Vector3(-24, 0.1, -17))      # côté salle (dégagé)
	var d := depuis - p
	d.y = 0.0
	var pos := p + d.normalized() * dist
	pos.y = p.y + 0.1
	j.global_position = pos
	var v := p + Vector3(0, 0.3, 0) - (pos + Vector3(0, 1.62, 0))
	j.rotation.y = atan2(-v.x, -v.z)
	j.tete.rotation.x = atan2(v.y, Vector2(v.x, v.z).length())
	j.velocity = Vector3.ZERO

func _go() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(30)
	var t: Node3D = m.tertre
	t.attendre_donjon()
	t._basculer(true)
	await _images(60)
	var c: Node3D = t.crypte
	m.joueur.global_position = c.to_global(Vector3(-24, 0.1, -17))
	await _images(40)
	m.hud.aide_t = 0.0
	var g = null
	for id: String in m.draugrs:
		if id.begins_with("cr_") and is_instance_valid(m.draugrs[id]):
			g = m.draugrs[id]
			break
	var pos: Vector3 = g.global_position
	var lieu := pos
	g._mourir()
	await _images(150)      # le ragdoll retombe ; on s'approche : invite « Fouiller » visible
	lieu = g.global_position
	_face(lieu, 2.2)
	await _images(40)
	await _capturer("1_cadavre_avant_fouille")
	# comme après un chargement : plus de ragdoll, la dépouille revient de la sauvegarde
	var butin: Node3D = g._butin
	var cle: String = butin.cle_sauvegarde
	butin.queue_free()
	g.queue_free()
	await _images(5)
	ButinTables.corps[cle] = {"pos": [lieu.x, lieu.y, lieu.z], "nom": "Gardien", "modele": g.spec_depouille() if is_instance_valid(g) else {"type": "squelette", "ident": "cr_ossuaire_sq1", "lacet": 0.8}}
	ButinTables.restes[cle] = {"os_draugr": 1}
	BUTIN.restaurer(c, m.joueur, m.hud)
	await _images(40)
	await _capturer("2_depouille_restauree")
	quit()
