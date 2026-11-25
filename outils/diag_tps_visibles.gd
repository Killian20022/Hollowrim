extends SceneTree
## Diagnostic : après un raccourci clavier réel, liste ce qui est visible sous le corps du joueur (3e personne).
const SCENE := preload("res://scenes/test_combat.tscn")
var s: Node3D
var j: CharacterBody3D

func _init() -> void:
	_go.call_deferred()

func _liste(t: String) -> void:
	print("== ", t, " :: ", j.mains.magie.eq.mains["gauche"].get("id"), " | ", j.mains.magie.eq.mains["droite"].get("id"))
	for n in j.corps.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var chemin := str(j.corps.get_path_to(mi))
		if chemin.contains("Skeleton3D/") and not chemin.contains("Attach") and not chemin.contains("Copie") and not chemin.contains("Tps"):
			continue
		if chemin.contains("Armure") or chemin.contains("armure"):
			continue
		print("   VIS ", chemin)

func _go() -> void:
	s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	j = s.joueur
	var mg: MainSort = j.mains.magie
	mg.eq.apprendre_tout()
	j.basculer_vue(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 30:
		await process_frame
	s.inventaire_ui.equiper("droite", "epee")
	s.inventaire_ui.equiper("gauche", "bouclier")
	for i in 20:
		await process_frame
	_liste("epee+bouclier")
	for k in [KEY_3, KEY_5]:
		s.inventaire_ui.equiper("droite", "epee")
		s.inventaire_ui.equiper("gauche", "bouclier")
		for i in 20:
			await process_frame
		for p in [true, false]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			e.keycode = k
			e.pressed = p
			Input.parse_input_event(e)
			await process_frame
		for i in 30:
			await process_frame
		_liste("touche %d" % k)
	quit(0)
