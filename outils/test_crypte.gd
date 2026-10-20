extends SceneTree
## Test headless de la crypte (lot 7a) : le décor ne doit pas gêner le parcours. Rayons horizontaux à 0,5 m et 1,4 m
## le long du chemin du joueur (entrée → couloir → salle → alcôve / levier → herse), sol sous chaque point, et
## inventaire des collisions du décor. godot --headless --path . --script outils/test_crypte.gd
const SCENE := preload("res://scenes/foret_test.tscn")

var m: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await physics_frame
	var c: Node3D = m.tertre.crypte
	var ss := m.get_world_3d().direct_space_state
	# les êtres vivants (draugrs, PNJ, joueur) se déplacent selon la sauvegarde : seul le décor est testé
	var vivants: Array[RID] = []
	for n in m.find_children("*", "CharacterBody3D", true, false):
		vivants.append((n as CharacterBody3D).get_rid())
	var chemin := [
		Vector3(0, 0, 0.5), Vector3(0, 0, -4), Vector3(0, 0, -12), Vector3(0, 0, -19), Vector3(0, 0, -25),
		Vector3(5.5, 0, -25), Vector3(0, 0, -25), Vector3(-6.5, 0, -25), Vector3(-9.0, 0, -24.0), Vector3(-7.5, 0, -25),
		Vector3(0, 0, -25), Vector3(0, 0, -31.5), Vector3(0, 0, -32.5),
		Vector3(0, 0, -42.5), Vector3(0, 0, -47.5),
	]
	for i in chemin.size() - 1:
		for h in [0.5, 1.4]:
			var a: Vector3 = c.to_global(chemin[i] + Vector3(0, h, 0))
			var b: Vector3 = c.to_global(chemin[i + 1] + Vector3(0, h, 0))
			var q := PhysicsRayQueryParameters3D.create(a, b)
			q.exclude = vivants
			var r := ss.intersect_ray(q)
			if i == 12 and not m.tertre._herse_ouverte:     # segment qui traverse la herse baissée : doit être bloqué
				_verif(not r.is_empty(), "segment %d→%d à %.1f m arrêté par la herse baissée" % [i, i + 1, h])
				continue
			_verif(r.is_empty(), "segment %d→%d à %.1f m dégagé%s" % [i, i + 1, h, "" if r.is_empty() else " (touche %s en %s)" % [(r["collider"] as Node).name, r["position"]]])
	for p: Vector3 in chemin:
		var o: Vector3 = c.to_global(p + Vector3(0, 1.0, 0))
		var qs := PhysicsRayQueryParameters3D.create(o, o + Vector3(0, -2.0, 0))
		qs.exclude = vivants
		var r := ss.intersect_ray(qs)
		_verif(not r.is_empty() and absf(r["position"].y - c.global_position.y) < 0.05, "sol à y=0 sous %s" % [p])
	var n := 0
	for s in m.tertre.corps.get_children():
		if s is CollisionShape3D:
			n += 1
	print("collisions du corps de la crypte : ", n)
	# la herse bloque bien le passage tant que le levier n'est pas tiré
	# (une partie sauvegardée peut l'avoir levée : on ne vérifie que si elle est baissée ; lancer avec -- --nouvelle sinon)
	if not m.tertre._herse_ouverte:
		var hs := ss.intersect_ray(PhysicsRayQueryParameters3D.create(c.to_global(Vector3(0, 1.0, -31.0)), c.to_global(Vector3(0, 1.0, -35.0))))
		_verif(not hs.is_empty(), "la herse arrête un rayon de la salle vers le tombeau")
	else:
		print("herse levée par la sauvegarde : contrôle sauté")
	print("TOUT OK" if _echecs == 0 else "ECHECS : %d" % _echecs)
	quit(_echecs)
