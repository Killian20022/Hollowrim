extends SceneTree
## Variante corps homme de la Chasseresse (archers bandits) : mêmes 65 os, clips, budget, surfaces, shader PS1 ; défaut inchangé.
##   godot --headless --path . --script res://outils/test_chasseresse_homme.gd -- --nouvelle
var echecs := 0
func ok(c: bool, m: String) -> void:
	print(("OK     " if c else "ECHEC  ") + m)
	if not c:
		echecs += 1
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	for corps in ["femme", "homme"]:
		var n := ChasseresseNordique.creer({"corps": corps})
		root.add_child(n)
		var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
		ok(sq.get_bone_count() == 65, "%s : 65 os" % corps)
		var ap := n.get_node("Animations") as AnimationPlayer
		for a in ["Idle", "Walk", "Pistol_Aim_Neutral", "Pistol_Shoot", "Death01"]:
			ok(ap.has_animation(a), "%s : clip %s" % [corps, a])
		var tris := 0
		var surf := 0
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.is_visible_in_tree():
				for s in mi.mesh.get_surface_count():
					surf += 1
					tris += (mi.mesh.surface_get_array_index_len(s) if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else mi.mesh.surface_get_array_len(s)) / 3
		ok(tris <= 7500, "%s : %d triangles (<= 7500)" % [corps, tris])
		ok(surf <= 10, "%s : %d surfaces (<= 10)" % [corps, surf])
		ok(sq.get_node_or_null("accessoires") != null, "%s : accessoires" % corps)
		n.queue_free()
	print("TEST CHASSERESSE HOMME : ", "OK" if echecs == 0 else "ECHEC (%d)" % echecs)
	quit(echecs)
