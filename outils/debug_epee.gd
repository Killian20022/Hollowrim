extends SceneTree
## Direction réelle de la lame (repère caméra) comparée à la cible, pour chaque pose.
const SCENE := preload("res://scenes/foret_test.tscn")
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var m: Node = SCENE.instantiate()
	root.add_child(m)
	for i in 20:
		await process_frame
	var mains = m.joueur.mains
	var cam: Camera3D = m.joueur.camera
	var epee: Node3D = mains._accroche_d.get_child(0)
	var aabb := AABB()
	for mi: MeshInstance3D in epee.find_children("*", "MeshInstance3D", true, false):
		aabb = aabb.merge(epee.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb())
	print("AABB épée (local) ", aabb)
	for p in ["repos", "armer", "frappe", "garde"]:
		mains._pose_figee = p
		for i in 10:
			await process_frame
		var inv := cam.global_transform.affine_inverse()
		var e := inv * epee.global_transform
		var c: Transform3D = inv * mains.pivot_epee.global_transform
		print(p, "  lame Y réelle=", e.basis.y.normalized().snapped(Vector3.ONE * 0.01), " voulue=", c.basis.y.normalized().snapped(Vector3.ONE * 0.01), "  pos réelle=", e.origin.snapped(Vector3.ONE * 0.01), " voulue=", c.origin.snapped(Vector3.ONE * 0.01))
	quit()
