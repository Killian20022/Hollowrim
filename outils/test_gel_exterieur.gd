extends SceneTree
## Test headless du gel du monde extérieur sous terre (monde._geler_exterieur) : villageois, village, draugrs de dehors gelés à l'entrée
## sous terre, COLLISION du terrain conservée, ennemis déjà désactivés jamais réveillés, tout reprend à la sortie.
##   godot --headless --path . --script outils/test_gel_exterieur.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _images(n: int) -> void:
	for i in n:
		await physics_frame

func _sol(x: float, z: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 80.0, z), Vector3(x, -20.0, z))
	return not m.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	await _images(5)
	var vill: Array = get_nodes_in_group("villageois")
	var ext: Array = []
	for d in m.draugrs.values():
		if is_instance_valid(d) and d.has_meta("exterieur"):
			ext.append(d)
	_verif(vill.size() >= 5 and ext.size() >= 4, "monde de dehors présent (%d villageois, %d draugrs de dehors)" % [vill.size(), ext.size()])
	var deja: Node = ext[0]
	deja.process_mode = Node.PROCESS_MODE_DISABLED      # un ennemi déjà désactivé par ailleurs (paisible)
	var x := m.VILLAGE.x + 3.0
	var z := m.VILLAGE.z + 3.0
	_verif(vill[0].is_physics_processing() and m.village.is_processing(), "avant : villageois et village actifs")
	_verif(_sol(x, z), "avant : le sol du village est solide")
	m._sous_terre(true)
	await _images(3)
	var tous_geles := true
	for v in vill:
		tous_geles = tous_geles and not v.is_physics_processing()
	_verif(tous_geles, "sous terre : tous les villageois sont gelés")
	_verif(not m.village.is_processing(), "sous terre : le village est gelé")
	var geles := 0
	for d in ext:
		if not d.is_physics_processing():
			geles += 1
	_verif(geles == ext.size(), "sous terre : les %d draugrs de dehors sont gelés" % ext.size())
	_verif(m.joueur.is_physics_processing(), "sous terre : le joueur n'est pas gelé")
	_verif(m.tertre.is_processing(), "sous terre : le tertre tourne toujours")
	_verif(_sol(x, z), "sous terre : la collision du sol du village est conservée")
	_verif(_sol(0.0, 0.0), "sous terre : la collision du terrain est conservée")
	m._sous_terre(false)
	await _images(3)
	var tous_vivants := true
	for v in vill:
		tous_vivants = tous_vivants and v.is_physics_processing()
	_verif(tous_vivants and m.village.is_processing(), "dehors : villageois et village reprennent")
	var reveilles := 0
	for d in ext:
		if d != deja and d.is_physics_processing():
			reveilles += 1
	_verif(reveilles == ext.size() - 1, "dehors : les draugrs de dehors reprennent")
	_verif(deja.process_mode == Node.PROCESS_MODE_DISABLED, "dehors : l'ennemi déjà désactivé reste désactivé")
	print("ECHECS : %d" % _echecs if _echecs > 0 else "TEST GEL EXTERIEUR : OK")
	quit(1 if _echecs > 0 else 0)
