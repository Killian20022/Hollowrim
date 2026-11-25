extends SceneTree
## [pnj/realisme_v1] Proportions des PNJ maison au repos : hauteur totale, hauteur de tête (menton -> sommet du crâne, sommets de peau
## dont l'os dominant est Head, menton = plus bas sommet de la face avant), ratio taille/tête (cible ~7,5), longueur main / avant-bras.
##   godot --headless --path . --script res://outils/mesure_proportions_pnj.gd -- [--ids=chef,forgeron,...]
func _initialize() -> void:
	_lancer.call_deferred()

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.substr(nom.length() + 3)
	return defaut

func _lancer() -> void:
	var ids: Array = _arg("ids", "forgeron,chasseuse,volva,ancienne,garde,garde_lance,eirik,hab_paysan_a,hab_paysan_b,hab_paysanne_a,hab_chasseur_a,hab_receleur").split(",")
	for id: String in ids:
		var n := PnjNordique.creer(id)
		root.add_child(n)
		var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
		sq.reset_bone_poses()
		var r := mesurer(n)
		print("PROP %-16s H=%.3f tete=%.3f ratio=%.2f main/avb=%.2f larg_tete=%.3f" % [id, r.h, r.tete, r.h / maxf(r.tete, 0.01), r.main / maxf(r.avb, 0.01), r.larg])
		n.free()
	quit(0)

## Mesure sur le squelette au repos courant (pose = repos) d'un perso Humain.
static func mesurer(n: Node3D) -> Dictionary:
	var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
	var i_tete := sq.find_bone("Head")
	var ymax := -9.0
	var ymin := 9.0
	var tete_max := -9.0
	var menton := 9.0
	var xs := [9.0, -9.0]
	var o_tete := sq.get_bone_global_pose(i_tete).origin
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var skin := mi.skin
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bo = a[Mesh.ARRAY_BONES]
			var we = a[Mesh.ARRAY_WEIGHTS]
			var nb: int = 0 if bo == null or v.size() == 0 else int(bo.size() / v.size())
			for k in v.size():
				var p := _pose(sq, skin, v[k], bo, we, k, nb)
				ymax = maxf(ymax, p.y)
				ymin = minf(ymin, p.y)
				if String(mi.name) == "peau" and nb > 0:
					var dom := -1
					var wm := 0.0
					for j in nb:
						if we[k * nb + j] > wm:
							wm = we[k * nb + j]
							dom = bo[k * nb + j]
					var os_: int = dom if skin == null else skin.get_bind_bone(dom)
					if os_ == i_tete:
						tete_max = maxf(tete_max, p.y)
						if p.z > o_tete.z + 0.04 and absf(p.x) < 0.03:
							menton = minf(menton, p.y)
						xs[0] = minf(xs[0], p.x)
						xs[1] = maxf(xs[1], p.x)
	var main := sq.get_bone_global_pose(sq.find_bone("middle_03_r")).origin.distance_to(sq.get_bone_global_pose(sq.find_bone("hand_r")).origin) + 0.025
	var avb := sq.get_bone_global_pose(sq.find_bone("lowerarm_r")).origin.distance_to(sq.get_bone_global_pose(sq.find_bone("hand_r")).origin)
	return {"h": ymax - ymin, "tete": tete_max - menton, "main": main, "avb": avb, "larg": xs[1] - xs[0]}

static func _pose(sq: Skeleton3D, skin: Skin, p: Vector3, bo, we, k: int, nb: int) -> Vector3:
	if nb == 0:
		return p
	var r := Vector3.ZERO
	var tw := 0.0
	for j in nb:
		var w: float = we[k * nb + j]
		if w <= 0.0:
			continue
		var b: int = bo[k * nb + j]
		var os_ := b
		var bind := Transform3D.IDENTITY
		if skin != null:
			os_ = skin.get_bind_bone(b)
			if os_ < 0:
				os_ = sq.find_bone(skin.get_bind_name(b))
			bind = skin.get_bind_pose(b)
		r += (sq.get_bone_global_pose(os_) * bind * p) * w
		tw += w
	return r / maxf(tw, 1e-6)
