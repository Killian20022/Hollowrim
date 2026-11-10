extends SceneTree
## Lot tripo/gardiens, prise d'épée : géométrie du poing droit du garde Tripo à l'épée (sommets liés à lowerarm_r, repère de l'os au repos)
## et de l'épée du jeu (epee_nordique.glb : poignée « cuir », garde/pommeau « fer », lame) dans son repère.
##   godot --headless --path . --script res://outils/mesure_prise_garde_tripo.gd
func _init() -> void:
	var h: Node3D = (GardeTripo.MODELES["tripo_garde_epee"] as PackedScene).instantiate()
	root.add_child(h)
	var sq: Skeleton3D = h.find_child("Skeleton3D", true, false)
	var ib := sq.find_bone("lowerarm_r")
	print("hand_r dans lowerarm_r : ", sq.get_bone_rest(sq.find_bone("hand_r")).origin)
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		var pts: Array = []
		var par_uv := {}
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var b: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var k := b.size() / maxi(v.size(), 1)
			for i in v.size():
				var best := -1
				var bw := 0.0
				for q in k:
					if w[i * k + q] > bw:
						bw = w[i * k + q]
						best = b[i * k + q]
				if mi.skin.get_bind_bone(best) != ib and mi.skin.get_bind_name(best) != "lowerarm_r":
					continue
				pts.append(mi.skin.get_bind_pose(best) * v[i])
				var uv: Vector2 = (a[Mesh.ARRAY_TEX_UV] as PackedVector2Array)[i]
				var cle := "%.4f,%.4f" % [uv.x, uv.y]
				if not par_uv.has(cle):
					par_uv[cle] = []
				par_uv[cle].append(pts[-1])
		# poing plein de tripo_rig.py : sphère UV dont tous les sommets portent la même UV (le groupe le plus nombreux)
		var gros := ""
		for cle: String in par_uv:
			if gros == "" or par_uv[cle].size() > par_uv[gros].size():
				gros = cle
		var lo0 := Vector3(1e9, 1e9, 1e9)
		var hi0 := -lo0
		var c0 := Vector3.ZERO
		for p: Vector3 in par_uv[gros]:
			lo0 = lo0.min(p)
			hi0 = hi0.max(p)
			c0 += p
		print("POING (uv %s) n=%d centre %s min %s max %s" % [gros, par_uv[gros].size(), c0 / par_uv[gros].size(), lo0, hi0])
		# tranches de 2 cm le long de l'avant-bras (+y) : centre et étendue x / z
		for y0 in range(-2, 20, 2):
			var c := Vector3.ZERO
			var n := 0
			var lo := Vector3(1e9, 1e9, 1e9)
			var hi := -lo
			for p: Vector3 in pts:
				if p.y >= y0 / 100.0 and p.y < (y0 + 2) / 100.0:
					c += p
					n += 1
					lo = lo.min(p)
					hi = hi.max(p)
			if n > 0:
				print("Y %3d-%3d cm n=%3d centre (%.3f %.3f %.3f) x[%.3f %.3f] z[%.3f %.3f]" % [y0, y0 + 2, n, c.x / n, c.y / n, c.z / n, lo.x, hi.x, lo.z, hi.z])
	var e: Node3D = GardeTripo.EPEE.instantiate()
	root.add_child(e)
	for mi: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var lo := Vector3(1e9, 1e9, 1e9)
			var hi := -lo
			var t := e.global_transform.affine_inverse() * mi.global_transform
			for p in v:
				lo = lo.min(t * p)
				hi = hi.max(t * p)
			var mat := mi.mesh.surface_get_material(s)
			print("EPEE %s surf %d (%s) min %s max %s" % [mi.name, s, mat.resource_name if mat else "?", lo, hi])
	quit()
