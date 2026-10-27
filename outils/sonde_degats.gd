extends SceneTree
## Sonde (combat/degats_gore) : animations de la bibliothèque, os sous la tête, maillages et accroches des modèles ennemis.
func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	print("ANIMS: ", " ".join(Humain.bibliotheque().get_animation_list()))
	for spec in [{"type": "guerrier"}, {"type": "squelette"}, {"type": "sbire"}]:
		var m: Node3D
		if String(spec["type"]).begins_with("squelette"):
			m = EnnemisNordiques.squelette({"type": spec["type"], "archer": false, "ident": "", "variante": ""})
		else:
			m = EnnemisNordiques.creer({"type": spec["type"], "archer": false, "boss": "", "ident": "", "apparence": EnnemisNordiques.apparence_defaut(spec["type"])})
		root.add_child(m)
		var sq: Skeleton3D = m.find_child("Skeleton3D", true, false)
		var h := sq.find_bone("Head")
		var sous := []
		for i in sq.get_bone_count():
			var p := i
			while p >= 0 and p != h:
				p = sq.get_bone_parent(p)
			if p == h:
				sous.append(sq.get_bone_name(i))
		print("== ", spec["type"], " os=", sq.get_bone_count(), " sous Head: ", sous, " parent(Head)=", sq.get_bone_name(sq.get_bone_parent(h)))
		for n in sq.get_children():
			var info := ""
			if n is MeshInstance3D:
				var mi := n as MeshInstance3D
				info = " vis=%s skin=%s surf=%d" % [mi.visible, mi.skin != null, mi.mesh.get_surface_count() if mi.mesh else 0]
				if mi.skin:
					info += " binds=%d nom0=%s" % [mi.skin.get_bind_count(), mi.skin.get_bind_name(0)]
			elif n is BoneAttachment3D:
				info = " os=" + (n as BoneAttachment3D).bone_name + " enfants=" + str(n.get_children().map(func(c): return c.name))
			print("   ", n.name, " (", n.get_class(), ")", info)
		print("   tete y=", (sq.global_transform * sq.get_bone_global_pose(h)).origin, " cou=", (sq.global_transform * sq.get_bone_global_pose(sq.find_bone("neck_01"))).origin)
	quit()
