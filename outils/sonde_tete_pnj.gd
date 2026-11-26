extends SceneTree
## [pnj/realisme_v1] Mesures (pose de repos) pour la passe 2 : os, boîte de la tête (sommets de la peau pesés sur Head), cou, mains.
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	CachePersos.actif = false
	for id in ["hab_paysan_a", "hab_paysan_b", "hab_paysanne_a", "forgeron", "volva"]:
		var n := PnjNordique._creer(id)
		var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
		print("== ", id, " os=", sq.get_bone_count())
		if id == "hab_paysan_a":
			var noms := []
			for b in sq.get_bone_count():
				noms.append("%d:%s" % [b, sq.get_bone_name(b)])
			print(" ".join(noms))
		for b in ["Head", "neck_01", "spine_03", "clavicle_l", "upperarm_l", "hand_l", "index_01_l"]:
			var i := sq.find_bone(b)
			if i >= 0:
				print("  os %s %s" % [b, sq.get_bone_global_rest(i).origin.snapped(Vector3.ONE * 0.001)])
		var mi := sq.get_node("peau") as MeshInstance3D
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bo: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var nb := bo.size() / v.size()
		var head := sq.find_bone("Head")
		var bmin := Vector3.ONE * 9; var bmax := -Vector3.ONE * 9
		var umin := Vector2.ONE * 9; var umax := -Vector2.ONE * 9
		var hmin := Vector2.ONE * 9; var hmax := -Vector2.ONE * 9
		var skin := mi.skin
		for k in v.size():
			var wh := 0.0
			var hand := 0.0
			for j in nb:
				var bi := bo[k * nb + j]
				var nom := sq.get_bone_name(skin.get_bind_bone(bi)) if skin and bi < skin.get_bind_count() and skin.get_bind_bone(bi) >= 0 else sq.get_bone_name(bi)
				if nom == "Head": wh += w[k * nb + j]
				if nom.ends_with("_l") and (nom.begins_with("hand") or nom.begins_with("index") or nom.begins_with("middle") or nom.begins_with("ring") or nom.begins_with("pinky") or nom.begins_with("thumb")): hand += w[k * nb + j]
			if wh > 0.6:
				bmin = bmin.min(v[k]); bmax = bmax.max(v[k]); umin = umin.min(uv[k]); umax = umax.max(uv[k])
			if hand > 0.6:
				hmin = hmin.min(uv[k]); hmax = hmax.max(uv[k])
		print("  tete aabb %s .. %s  uv %s .. %s  main_l uv %s .. %s" % [bmin.snapped(Vector3.ONE*0.001), bmax.snapped(Vector3.ONE*0.001), umin.snapped(Vector2.ONE*0.001), umax.snapped(Vector2.ONE*0.001), hmin.snapped(Vector2.ONE*0.001), hmax.snapped(Vector2.ONE*0.001)])
		var h := sq.get_node_or_null("Hair_Long") as MeshInstance3D
		if h: print("  Hair_Long aabb ", h.get_aabb())
		var m := sq.get_node_or_null("mante") as MeshInstance3D
		if m:
			var am := m.mesh.surface_get_arrays(0)
			var mv: PackedVector3Array = am[Mesh.ARRAY_VERTEX]
			var muv: PackedVector2Array = am[Mesh.ARRAY_TEX_UV]
			var ymin := 9.0; var ymax := -9.0
			for k in mv.size():
				if muv[k].y < 0.22:
					ymin = minf(ymin, mv[k].y); ymax = maxf(ymax, mv[k].y)
			print("  mante bande v<0.22 : y %.3f..%.3f (%d sommets)" % [ymin, ymax, mv.size()])
		n.free()
	quit()
