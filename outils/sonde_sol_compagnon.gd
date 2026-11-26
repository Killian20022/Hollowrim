extends SceneTree
## Sonde : autour du compagnon mort (crypte, salle barricadée), hauteur de chaque objet du journal (bas de sa boîte) contre le sol
## mesuré par rayon vers le bas, et hauteur de chaque os physique du ragdoll figé contre le sol. Repère : la crypte.
##   godot --headless --path . --script res://outils/sonde_sol_compagnon.gd -- --nouvelle --paisible
const SCENE := "res://scenes/foret_test.tscn"
const CENTRE := Vector3(-16.0, -6.0, -53.0)

func _init() -> void:
	CrypteDecor.journal_actif = true
	_go.call_deferred()

func _sol(crypte: Node3D, p: Vector3, exclure: Array) -> float:
	var w := crypte.to_global(Vector3(p.x, -4.5, p.z))
	var q := PhysicsRayQueryParameters3D.create(w, w + Vector3.DOWN * 4.0)
	q.exclude = exclure
	var r := crypte.get_world_3d().direct_space_state.intersect_ray(q)
	return crypte.to_local(r["position"]).y if r else NAN

func _go() -> void:
	var m: Node3D = (load(SCENE) as PackedScene).instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 30:
		await physics_frame
	m.tertre.attendre_donjon()
	var crypte: Node3D = m.tertre.crypte
	var c := crypte.find_child("CorpsCompagnon", true, false) as Node3D
	var rd: Ragdoll = c.get_node_or_null("Ragdoll")
	for i in 600:
		await physics_frame
		if rd == null or rd.est_fige():
			break
	var excl: Array = []
	if rd:
		for pb in rd.find_children("*", "PhysicsBody3D", true, false):
			excl.append((pb as CollisionObject3D).get_rid())
	for dec: CrypteDecor in [m.tertre.d, m.tertre.d2]:
		for e: Dictionary in dec.journal:
			var a: float = e["lacet"]
			var mn := Basis(Vector3.UP, a) * (e["min"] as Vector3)
			var mx := Basis(Vector3.UP, a) * (e["max"] as Vector3)
			var ce := (mn + mx) * 0.5
			if Vector2(ce.x - CENTRE.x, ce.z - CENTRE.z).length() > 3.0 or absf(ce.y - CENTRE.y) > 2.5:
				continue
			var s := _sol(crypte, ce, excl)
			print("OBJ %-16s c=(%.2f, %.2f) bas=%.3f sol=%.3f ecart=%.3f%s" % [e["t"], ce.x, ce.z, minf(mn.y, mx.y), s, minf(mn.y, mx.y) - s, "  PARTIE" if e.get("partie", false) else ""])
	if rd:
		for nom: String in rd.os.keys():
			var t: Variant = rd.pose_monde(nom)
			if t == null:
				continue
			var p := crypte.to_local((t as Transform3D).origin)
			print("OS %-14s (%.2f, %.2f) y=%.3f sol=%.3f" % [nom, p.x, p.z, p.y, _sol(crypte, p, excl)])
	for n: Node in crypte.find_children("*", "Node3D", true, false):
		var n3 := n as Node3D
		if n3.is_ancestor_of(c) or c.is_ancestor_of(n3) or n3 == c:
			continue
		var p := crypte.to_local(n3.global_position)
		if Vector2(p.x - CENTRE.x, p.z - CENTRE.z).length() < 2.2 and absf(p.y - CENTRE.y) < 2.0 and not (n3 is MeshInstance3D and (n3 as MeshInstance3D).mesh is ArrayMesh and n3.get_parent().name.begins_with("Corps")):
			var info := ""
			if n3 is MeshInstance3D and (n3 as MeshInstance3D).mesh:
				var bb := (n3 as MeshInstance3D).global_transform * (n3 as MeshInstance3D).get_aabb()
				info = "bas=%.3f haut=%.3f sol=%.3f" % [crypte.to_local(bb.position).y, crypte.to_local(bb.end).y, _sol(crypte, p, excl)]
			print("NOEUD %-28s %-18s parent=%-20s (%.2f, %.2f, %.2f) %s" % [n3.name, n3.get_class(), n3.get_parent().name, p.x, p.y, p.z, info])
	var sq := c.find_child("Skeleton3D", true, false) as Skeleton3D
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if mi.visible and mi.mesh:
			var bb := mi.global_transform * mi.get_aabb()
			print("MI %-22s parent=%-18s taille=%s" % [mi.name, mi.get_parent().name, bb.size])
	quit(0)
