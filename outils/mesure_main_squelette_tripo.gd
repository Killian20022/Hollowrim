extends SceneTree
## Mains du squelette Tripo dans le repère de l'os de la main (pose de liaison du skin) : boîte, portée, centres par tranches le long de l'os.
## Sert à mesurer la prise de l'arc (EnnemiTripo.paume) sur la VRAIE main.
##   godot --headless --path . --script res://outils/mesure_main_squelette_tripo.gd [-- --modele=squelette|archer]
func _init() -> void:
	var id := "squelette"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--modele="):
			id = a.substr(9)
	var h: Node3D = (EnnemiTripo.MODELES[id] as PackedScene).instantiate()
	root.add_child(h)
	var sq: Skeleton3D = h.find_child("Skeleton3D", true, false)
	for cote in ["l", "r"]:
		var nom_main: String = "hand_" + cote
		var pts: Array[Vector3] = []
		for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
			if mi.skin == null:
				continue
			for s in mi.mesh.get_surface_count():
				var a := mi.mesh.surface_get_arrays(s)
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var b: PackedInt32Array = a[Mesh.ARRAY_BONES]
				var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
				var k := b.size() / maxi(v.size(), 1)
				for i in v.size():
					var p := 0.0
					var bind := -1
					for q in k:
						if mi.skin.get_bind_name(b[i * k + q]) == nom_main:
							p += w[i * k + q]
							bind = b[i * k + q]
					if p >= 0.5:
						pts.append(mi.skin.get_bind_pose(bind) * v[i])
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := -lo
		for q in pts:
			lo = lo.min(q)
			hi = hi.max(q)
		var ds: Array[float] = []
		for q in pts:
			ds.append(q.length())
		ds.sort()
		print("MAIN %s : %d sommets ; boîte %s .. %s ; portée 95e %.3f ; os main longueur rest -> enfant ?" % [cote, pts.size(), lo, hi, ds[int(ds.size() * 0.95)] if ds.size() > 0 else 0.0])
		for tr: Array in [[0.0, 0.2], [0.2, 0.4], [0.4, 0.6], [0.6, 0.8], [0.8, 1.0], [0.25, 0.55], [0.5, 0.9]]:
			var c := Vector3.ZERO
			var n := 0
			var blo := Vector3(1e9, 1e9, 1e9)
			var bhi := -blo
			for q in pts:
				var t: float = (q.y - lo.y) / maxf(hi.y - lo.y, 1e-6)
				if t >= tr[0] and t <= tr[1]:
					c += q
					n += 1
					blo = blo.min(q)
					bhi = bhi.max(q)
			print("   tranche y %s : n=%d centre %s boîte %s .. %s" % [tr, n, (c / maxf(n, 1)).snapped(Vector3.ONE * 0.001), blo.snapped(Vector3.ONE * 0.001), bhi.snapped(Vector3.ONE * 0.001)])
		# ACP de la paume (tranche 0,2-0,55) et de toute la main : axe de plus petite étendue = normale de la paume
		for tr2: Array in [[0.2, 0.55], [0.0, 1.0]]:
			var sel: Array[Vector3] = []
			for q in pts:
				var t2: float = (q.y - lo.y) / maxf(hi.y - lo.y, 1e-6)
				if t2 >= tr2[0] and t2 <= tr2[1]:
					sel.append(q)
			var mu := Vector3.ZERO
			for q in sel:
				mu += q
			mu /= maxf(sel.size(), 1)
			var cxx := 0.0; var cyy := 0.0; var czz := 0.0; var cxy := 0.0; var cxz := 0.0; var cyz := 0.0
			for q in sel:
				var d := q - mu
				cxx += d.x * d.x; cyy += d.y * d.y; czz += d.z * d.z; cxy += d.x * d.y; cxz += d.x * d.z; cyz += d.y * d.z
			# plus petit vecteur propre par itération inverse approchée : on teste des directions sur la sphère
			var best := Vector3.ZERO
			var bv := INF
			for ia in 90:
				for ib in 180:
					var th := deg_to_rad(ia * 2.0)
					var ph := deg_to_rad(ib * 2.0)
					var u := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
					var var_ := u.x * u.x * cxx + u.y * u.y * cyy + u.z * u.z * czz + 2.0 * (u.x * u.y * cxy + u.x * u.z * cxz + u.y * u.z * cyz)
					if var_ < bv:
						bv = var_
						best = u
			print("   ACP tranche %s : centre %s normale (plus petite étendue) %s écart-type %.3f" % [tr2, mu.snapped(Vector3.ONE * 0.001), best.snapped(Vector3.ONE * 0.01), sqrt(bv / maxf(sel.size(), 1))])
		# coupe x-z de la paume (perpendiculaire à l'os) : grand axe = ligne des jointures (où passe la poignée), petit axe = normale de la paume
		for tr3: Array in [[0.15, 0.45], [0.3, 0.6], [0.45, 0.75]]:
			var sxx := 0.0; var szz := 0.0; var sxz := 0.0; var mx := 0.0; var mz := 0.0; var nn := 0
			for q in pts:
				var t3: float = (q.y - lo.y) / maxf(hi.y - lo.y, 1e-6)
				if t3 >= tr3[0] and t3 <= tr3[1]:
					mx += q.x; mz += q.z; nn += 1
			mx /= maxf(nn, 1); mz /= maxf(nn, 1)
			for q in pts:
				var t4: float = (q.y - lo.y) / maxf(hi.y - lo.y, 1e-6)
				if t4 >= tr3[0] and t4 <= tr3[1]:
					sxx += (q.x - mx) * (q.x - mx); szz += (q.z - mz) * (q.z - mz); sxz += (q.x - mx) * (q.z - mz)
			var ang := 0.5 * atan2(2.0 * sxz, sxx - szz)
			print("   coupe xz tranche %s : centre (%.3f, %.3f) grand axe (%.2f, 0, %.2f) = %.0f° depuis +x ; étendues %.3f / %.3f" % [tr3, mx, mz, cos(ang), sin(ang), rad_to_deg(ang),
				sqrt(maxf((sxx + szz) * 0.5 + sqrt(pow((sxx - szz) * 0.5, 2) + sxz * sxz), 0.0) / maxf(nn, 1)), sqrt(maxf((sxx + szz) * 0.5 - sqrt(pow((sxx - szz) * 0.5, 2) + sxz * sxz), 0.0) / maxf(nn, 1))])
		print("   centre_poing (EnnemiTripo, main droite seulement) ", EnnemiTripo.centre_poing(sq, sq.find_children("*", "MeshInstance3D", false, false)[0], id) if cote == "r" else "")
	quit(0)
