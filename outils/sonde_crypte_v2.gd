extends SceneTree
## Sonde crypte v2 (lot C4) : par module, ce que le mode auto a posé (statues, candélabres, lumières, piliers, bannières, flaques)
## et la liste des emplacements d'eau (tertre.eau_slots) pour le lot eau C5. Sans fenêtre :
##   godot --headless --path . --script res://outils/sonde_crypte_v2.gd -- --nouvelle
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
	var dj = m.tertre.donjon
	for id in dj.modules:
		print("V2 %-16s %s" % [id, str(dj.v2_stats.get(id, {}))])
	var par_genre := {}
	for s: Dictionary in m.tertre.eau_slots():
		par_genre[s["genre"]] = int(par_genre.get(s["genre"], 0)) + 1
		print("EAU %-14s %-14s c=%s r=%.2f t=%s" % [s["module"], s["genre"], str(s["centre"]), s["rayon"], str(s["taille"])])
	print("EAU total %d %s" % [m.tertre.eau_slots().size(), str(par_genre)])
	# lumières par zone (comme test_crypte) : détail de la zone demandée par --zone=<id>
	var zq := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zone="):
			zq = a.substr(7)
	for z in dj.zones:
		if z["nom"] != zq:
			continue
		var rr: Rect2 = z["rect"]
		for l: OmniLight3D in m.tertre.d2.toutes:
			var lp: Vector3 = m.tertre.crypte.to_local(l.global_position)
			if rr.grow(0.4).has_point(Vector2(lp.x, lp.z)) and absf(lp.y - float(z["y"])) < 5.5:
				print("LUM %s %s e=%.2f portee=%.1f" % [zq, str(lp), l.light_energy, l.omni_range])
	# --maillage=<nom> : AABB du maillage et lumières qui le touchent (même règle que test_crypte)
	var mq := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--maillage="):
			mq = a.substr(11)
	if mq != "":
		for mi in m.tertre.crypte.find_children(mq, "MeshInstance3D", true, false):
			var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			print("MAILLAGE %s aabb=%s" % [mi.name, str(bb)])
			for l: OmniLight3D in m.tertre.d.toutes + m.tertre.d2.toutes:
				var pt := l.global_position
				var pr := Vector3(clampf(pt.x, bb.position.x, bb.end.x), clampf(pt.y, bb.position.y, bb.end.y), clampf(pt.z, bb.position.z, bb.end.z))
				if pr.distance_to(pt) <= l.omni_range:
					print("  LUM %s portee=%.1f" % [str(m.tertre.crypte.to_local(pt)), l.omni_range])
	quit(0)
