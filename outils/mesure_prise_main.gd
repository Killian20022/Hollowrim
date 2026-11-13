extends SceneTree
## Mesure de la PRISE sur la vraie main (hand_r) de chaque corps d'ennemi, dans le repère de repos de hand_r :
##   - poing = sommets de la main (poids >= 0,5 sur hand_r) à 50-90 % de la portée du poignet (comme EnnemiTripo.centre_poing) ;
##   - axe du manche = direction qui traverse le poing : (a) trou franc du maillage (cases vides entourées de main, projection sur un plan) s'il y en a un,
##     sinon (b) ligne des articulations : axe principal du poing dans le plan perpendiculaire aux doigts ;
##   - affiche centre, axe, trou, et l'écart avec l'axe actuel de l'arme (PRISE.y incliné de INCL).
##   godot --headless --path . --script res://outils/mesure_prise_main.gd -- [--json=<fichier>]
const CAS := ["draugr", "draugr_ancien", "bandit", "bandit_costaud", "squelette", "jarl", "gobelin"]
const N := 40          # cases par côté de la grille de projection
var _sortie := {}

func _init() -> void:
	_go.call_deferred()

func _modele(nom: String) -> Node3D:
	match nom:
		"draugr": return EnnemisNordiques.creer({"type": "sbire", "ident": "m_d", "apparence": {"corps": "homme", "draugr": true, "tenue": {}}})
		"draugr_ancien": return EnnemisNordiques.creer({"type": "guerrier", "ident": "m_g", "apparence": EnnemisNordiques.apparence_defaut("guerrier")})
		"bandit": return EnnemisNordiques.creer({"type": "sbire", "ident": "m_b", "apparence": GrotteJeu.apparence_humain(1, "")})
		"bandit_costaud": return EnnemisNordiques.creer({"type": "sbire", "ident": "m_c", "apparence": GrotteJeu.apparence_humain(2, "casque_nasal")})
		"squelette": return EnnemisNordiques.squelette({"type": "squelette", "ident": "m_s"})
		"jarl": return EnnemisNordiques.creer({"type": "guerrier", "boss": "jarl", "ident": "jarl", "apparence": EnnemisNordiques.apparence_defaut("guerrier")})
	return EnnemiTripo.creer("gobelin", "dague_acier", "gobelin")

## Triangles + sommets de la main dans le repère de repos de hand_r : {pts, tris}
func _main(sq: Skeleton3D) -> Dictionary:
	var os_main := sq.find_bone("hand_r")
	var inv := sq.get_bone_global_rest(os_main).affine_inverse()
	var pts: Array[Vector3] = []
	var tris: Array = []
	for mi: MeshInstance3D in sq.find_children("*", "MeshInstance3D", false, false):
		if mi.mesh == null or mi.skin == null:
			continue
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var b: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			if b.is_empty():
				continue
			var par := b.size() / maxi(v.size(), 1)
			var main := PackedByteArray()
			main.resize(v.size())
			for i in v.size():
				var p := 0.0
				for k in par:
					if mi.skin.get_bind_name(b[i * par + k]) == "hand_r":
						p += w[i * par + k]
				main[i] = 1 if p >= 0.5 else 0
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var loc := PackedVector3Array()
			loc.resize(v.size())
			for i in v.size():
				loc[i] = inv * (mi.transform * v[i])
				if main[i] == 1:
					pts.append(loc[i])
			for t in range(0, idx.size() - 2, 3):
				if main[idx[t]] == 1 and main[idx[t + 1]] == 1 and main[idx[t + 2]] == 1:
					tris.append([loc[idx[t]], loc[idx[t + 1]], loc[idx[t + 2]]])
	return {"pts": pts, "tris": tris}

## Trou franc : pour chaque direction d (hémisphère), projette les triangles du poing sur le plan ⊥ d, compte les cases vides ENTOURÉES de matière.
func _trou(tris: Array, centre: Vector3, rayon: float) -> Dictionary:
	var meilleur := {"aire": 0, "dir": Vector3.ZERO, "centre": centre}
	var cell := 2.0 * rayon / N
	for el in range(-80, 81, 8):
		var nb := maxi(1, int(round(36.0 * cos(deg_to_rad(el)))))
		for k in nb:
			var az := PI * k / nb
			var d := Vector3(cos(deg_to_rad(el)) * cos(az), sin(deg_to_rad(el)), cos(deg_to_rad(el)) * sin(az)).normalized()
			var u := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
			var vv := d.cross(u)
			var g := PackedByteArray()
			g.resize(N * N)
			for t: Array in tris:
				var p: Array = []
				for q: Vector3 in t:
					var r := q - centre
					p.append(Vector2(r.dot(u) / cell + N * 0.5, r.dot(vv) / cell + N * 0.5))
				var x0 := maxi(0, int(floor(minf(p[0].x, minf(p[1].x, p[2].x)))))
				var x1 := mini(N - 1, int(ceil(maxf(p[0].x, maxf(p[1].x, p[2].x)))))
				var y0 := maxi(0, int(floor(minf(p[0].y, minf(p[1].y, p[2].y)))))
				var y1 := mini(N - 1, int(ceil(maxf(p[0].y, maxf(p[1].y, p[2].y)))))
				for y in range(y0, y1 + 1):
					for x in range(x0, x1 + 1):
						if g[y * N + x] == 0 and Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, y + 0.5), p[0], p[1], p[2]):
							g[y * N + x] = 1
			# flood fill du vide depuis le bord
			var ext := PackedByteArray()
			ext.resize(N * N)
			var pile: Array[int] = []
			for i in N:
				for e: int in [i, (N - 1) * N + i, i * N, i * N + N - 1]:
					if g[e] == 0 and ext[e] == 0:
						ext[e] = 1
						pile.append(e)
			while not pile.is_empty():
				var c: int = pile.pop_back()
				var cx := c % N
				var cy := c / N
				for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := cx + dd.x
					var ny := cy + dd.y
					if nx >= 0 and ny >= 0 and nx < N and ny < N and g[ny * N + nx] == 0 and ext[ny * N + nx] == 0:
						ext[ny * N + nx] = 1
						pile.append(ny * N + nx)
			var aire := 0
			var sx := 0.0
			var sy := 0.0
			for i in N * N:
				if g[i] == 0 and ext[i] == 0:
					aire += 1
					sx += i % N + 0.5
					sy += i / N + 0.5
			if aire > int(meilleur["aire"]):
				var cx2 := (sx / aire - N * 0.5) * cell
				var cy2 := (sy / aire - N * 0.5) * cell
				meilleur = {"aire": aire, "dir": d, "centre": centre + u * cx2 + vv * cy2, "cell": cell}
	return meilleur

func _go() -> void:
	var cur := Basis(Vector3.RIGHT, deg_to_rad(EnnemiTripo.INCL)) * EnnemiTripo.PRISE.basis
	print("axe actuel de l'arme (repère de hand_r) : %s" % cur.y)
	for nom: String in CAS:
		var n := _modele(nom)
		if n == null:
			print("%s : modèle absent" % nom)
			continue
		root.add_child(n)
		var sq := n.find_child("Skeleton3D", true, false) as Skeleton3D
		var m := _main(sq)
		var pts: Array = m["pts"]
		var tris: Array = m["tris"]
		var ds: Array[float] = []
		for q: Vector3 in pts:
			ds.append(q.length())
		ds.sort()
		var r: float = ds[int(ds.size() * 0.95)]
		var poing: Array[Vector3] = []
		var somme := Vector3.ZERO
		for q: Vector3 in pts:
			var d := q.length()
			if d >= 0.5 * r and d <= 0.9 * r:
				poing.append(q)
				somme += q
		var c := somme / maxi(poing.size(), 1)
		var f := c.normalized()      # doigts : du poignet vers le poing
		# axe principal du poing dans le plan ⊥ f (covariance 2x2)
		var u := f.cross(Vector3.UP if absf(f.y) < 0.9 else Vector3.RIGHT).normalized()
		var v := f.cross(u)
		var sxx := 0.0
		var sxy := 0.0
		var syy := 0.0
		for q: Vector3 in poing:
			var a := (q - c).dot(u)
			var b := (q - c).dot(v)
			sxx += a * a
			sxy += a * b
			syy += b * b
		var th := 0.5 * atan2(2.0 * sxy, sxx - syy)
		var larg := u * cos(th) + v * sin(th)
		var epais := -u * sin(th) + v * cos(th)
		if larg.dot(cur.y) < 0.0:
			larg = -larg
		var tr := _trou(tris, c, r)
		var axe_trou: Vector3 = tr["dir"]
		if axe_trou.dot(cur.y) < 0.0:
			axe_trou = -axe_trou
		print("%s : portée main %.1f cm, %d sommets, %d tris, poing %s (%d pts)" % [nom, r * 100.0, pts.size(), tris.size(), c, poing.size()])
		print("    largeur (ligne des articulations) %s ; épaisseur %s ; doigts %s" % [larg, epais, f])
		print("    trou : %d cases (%.1f mm de côté), axe %s, centre %s ; écart axe actuel : largeur %.0f°, trou %.0f°" % [int(tr["aire"]), float(tr.get("cell", 0.0)) * 1000.0, axe_trou, tr["centre"], rad_to_deg(larg.angle_to(cur.y)), rad_to_deg(axe_trou.angle_to(cur.y)) if int(tr["aire"]) > 0 else -1.0])
		_sortie[nom] = {"centre": [c.x, c.y, c.z], "largeur": [larg.x, larg.y, larg.z], "trou_cases": int(tr["aire"]), "trou_axe": [axe_trou.x, axe_trou.y, axe_trou.z], "trou_centre": [tr["centre"].x, tr["centre"].y, tr["centre"].z]}
		n.queue_free()
		await process_frame
	var js := OS.get_cmdline_user_args()
	for a in js:
		if a.begins_with("--json="):
			var f := FileAccess.open(a.substr(7), FileAccess.WRITE)
			f.store_string(JSON.stringify(_sortie, "\t"))
	quit()
