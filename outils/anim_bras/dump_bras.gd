extends SceneTree
## Extrait du jeu le repère caméra des bras FPS, les repos des os, la pose des poings et les prises (épée, torche) vers
## sources_blender/scripts/bras_godot.json, lu par sources_blender/scripts/anim_bras_epee.py (animations du bras droit).
##   godot --headless --path . --script res://outils/anim_bras/dump_bras.gd -- --nouvelle
const SCENE := preload("res://scenes/test_combat.tscn")
func _init() -> void:
	_go.call_deferred()
func _t(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]
func _go() -> void:
	var s = SCENE.instantiate()
	s.options = {"draugr": "aucun", "sans-aide": ""}
	root.add_child(s)
	for i in 5:
		await physics_frame
	var m = s.joueur.mains
	var sq: Skeleton3D = m._sq
	var rel := Transform3D()
	var n: Node = sq
	while n != null and n != m.bras:
		rel = (n as Node3D).transform * rel
		n = n.get_parent()
	var os := {}
	for i in sq.get_bone_count():
		os[sq.get_bone_name(i)] = {"rest_global": _t(sq.get_bone_global_rest(i)), "rest": _t(sq.get_bone_rest(i)), "parent": sq.get_bone_parent(i)}
	var doigts := {}
	for i in m._doigts:
		var q: Quaternion = m._doigts[i]
		doigts[sq.get_bone_name(i)] = [q.x, q.y, q.z, q.w]
	var d := {"bras": _t(m.bras.transform), "rel": _t(rel), "prise_d": _t(m.PRISE_D), "prise_g": _t(m.PRISE_G),
		"os": os, "doigts": doigts, "garde": [m._garde_lame.x, m._garde_lame.y, m._garde_lame.z], "pointe": [m._pointe_lame.x, m._pointe_lame.y, m._pointe_lame.z],
		"modele": m.arme.modele, "repos_pivot": _t(m._pose_repos()), "pivot_torche": _t(m.pivot_torche.transform), "fov": s.joueur.camera.fov}
	var f := FileAccess.open("res://sources_blender/scripts/bras_godot.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	print("DUMP OK")
	quit(0)
