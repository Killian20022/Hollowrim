extends SceneTree
## Sonde : les poses de vues de crypte sont-elles dans le vide, dans un mur, ou sur un sol ?
const SCENE := preload("res://scenes/foret_test.tscn")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var m: Node3D = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 5:
		await physics_frame
	m.tertre.attendre_donjon()
	for i in 10:
		await physics_frame
	m._ouvrir_donjon("s1,s2,s3,secret,herse")
	for i in 10:
		await physics_frame
	var c: Node3D = m.tertre.crypte
	var dj = m.tertre.donjon
	for id in dj.modules:
		var md: Dictionary = dj.modules[id]
		print("MOD ", id, " c=", md["centre"], " y=", md["y"], " dim=", md["dim"], " rot=", md["rot"])
	var ss := m.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.8
	for l in FileAccess.get_file_as_string("res://outils/poses_audit_crypte_corrigees.txt").split("\n"):
		var t := l.split(" ")
		if t.size() < 3: continue
		var f := t[2].split_floats(",")
		var oy := 0.0
		var p := c.to_global(Vector3(f[0], 0.1 if f.size() < 5 else f[4], f[1]))
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p + Vector3(0, -6, 0))
		var r := ss.intersect_ray(q)
		var sol := "AUCUN SOL" if r.is_empty() else "sol à %.2f m sous le point" % (p.y + 3 - 3 - (r["position"] as Vector3).y + 0.0)
		var qs := PhysicsShapeQueryParameters3D.new()
		qs.shape = cap
		qs.transform = Transform3D(Basis(), p + Vector3(0, 1.0, 0))
		var dedans := ss.intersect_shape(qs, 2).size()
		print("POSE %-14s monde=(%.1f,%.1f,%.1f) %s ; capsule dans solide: %d" % [t[0], p.x, p.y, p.z, sol, dedans])
	quit()
