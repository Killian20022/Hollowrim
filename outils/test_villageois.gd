extends SceneTree
## Test headless : godot --headless -s res://outils/test_villageois.gd
## Instancie dialogue.gd et un villageois avec un faux joueur.

class FauxJoueur extends CharacterBody3D:
	var en_dialogue := false
	var mort := false
	var camera: Camera3D

func _initialize() -> void:
	var liste: Array = load("res://scripts/villageois.gd").charger()
	print("villageois chargés : ", liste.size())
	var monde := Node3D.new()
	root.add_child(monde)
	var sol := StaticBody3D.new()
	var f := CollisionShape3D.new()
	f.shape = BoxShape3D.new()
	(f.shape as BoxShape3D).size = Vector3(60, 1, 60)
	sol.position.y = -0.5
	sol.add_child(f)
	monde.add_child(sol)
	var j := FauxJoueur.new()
	j.camera = Camera3D.new()
	j.camera.position.y = 1.6
	j.add_child(j.camera)
	monde.add_child(j)
	j.position = Vector3(0, 0.1, 2.0)
	var d: Control = load("res://scripts/dialogue.gd").new()
	d.joueur = j
	root.add_child(d)
	var pnjs: Array = []
	for i in liste.size():
		var p: CharacterBody3D = load("res://scripts/villageois.gd").new()
		p.donnees = liste[i]
		p.joueur = j
		p.dialogue = d
		p.points = [Vector3(i * 3.0 - 6.0, 0.1, -10), Vector3(i * 3.0 - 6.0, 0.1, -16)]
		p.position = p.points[0]
		monde.add_child(p)
		pnjs.append(p)
	await process_frame
	var p0: CharacterBody3D = pnjs[0]
	p0.global_position = Vector3(0, 0.1, 0)
	await create_timer(0.5).timeout
	j.global_position = Vector3(0, 0.1, 1.5)
	await create_timer(0.5).timeout
	print("pos pnj ", p0.global_position, " joueur ", j.global_position, " cam ", j.camera.global_position, " dot ", (-j.camera.global_transform.basis.z).dot((p0.global_position + Vector3.UP * 1.4 - j.camera.global_position).normalized()))
	print("invite active : ", d._invites.size(), " ouvert : ", d._ouvert)
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.pressed = true
	d._unhandled_input(e)
	print("ouvert : ", d._ouvert, " en_dialogue : ", j.en_dialogue)
	await create_timer(1.0).timeout
	d._unhandled_input(e)
	d._unhandled_input(e)
	print("texte : ", d._texte.text, " | hauteur ligne : ", d._police.get_height(16), " lignes : ", d._texte.get_line_count())
	for k in 8:
		d._unhandled_input(e)
		await create_timer(0.1).timeout
	d._unhandled_input(e)
	print("après lecture ouvert : ", d._ouvert, " en_dialogue : ", j.en_dialogue)
	d.dire_au_passage("Test", "Bonjour")
	await create_timer(1.0).timeout
	print("deja_parle : ", p0.deja_parle)
	# promenade forcée
	for p in pnjs:
		p._prochaine_promenade = 0.1
	await create_timer(6.0).timeout
	print("OK fin")
	quit()
