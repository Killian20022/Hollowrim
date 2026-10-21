extends SceneTree
## Test headless de la grotte en arbre : étanchéité (rayons depuis chaque anneau de CHAQUE branche), sol sous chaque point, séparation des
## galeries (aucun recoupement de parois entre branches), puis une capsule (r 0,35 ; h 1,8, comme le joueur) qui PARCOURT TOUTES LES
## BRANCHES (T1 → A → T2 → C puis T1 → B → T2 → H) et atteint chaque point d'accroche (coffre, ressource, interaction, mur fragile,
## poste d'ennemi, lieu), y compris ceux des corniches (par la rampe) et de l'îlot.
##   godot --headless --path . --script outils/test_grotte.gd
const VITESSE := 4.0

var g: Grotte
var _echecs := 0

func _init() -> void:
	_lancer.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

## Écart horizontal entre un point (repère local) et l'obstacle solide le plus proche (cylindres et boîtes du décor).
func _degagement(p: Vector3) -> float:
	var mini := 99.0
	for n in g.corps.get_children():
		var cs := n as CollisionShape3D
		if cs == null:
			continue
		var r := 0.0
		if cs.shape is CylinderShape3D:
			r = (cs.shape as CylinderShape3D).radius
		elif cs.shape is BoxShape3D:
			var b := (cs.shape as BoxShape3D).size
			r = maxf(b.x, b.z) * 0.5
		else:
			continue
		if absf(cs.position.y - p.y) > 3.0:
			continue
		mini = minf(mini, Vector2(cs.position.x - p.x, cs.position.z - p.z).length() - r)
	return mini

## Décalage latéral « naturel » : près d'une jonction, la moitié extérieure de la galerie (le nez du pilier ne se longe pas).
func _lat_pref(id: String, s: float) -> float:
	var d: Dictionary = (g.br[id] as Dictionary)["d"]
	var L := g.longueur(id)
	var lat := 0.0
	if d.has("pince_deb") and s < Grotte.ZONE_PINCE:
		var c: float = float((d["pince_deb"] as Dictionary)["cote"])
		var dl := g.demi_l(id, s)
		lat = c * 0.5 * (dl.y if c > 0.0 else dl.x) * (1.0 - s / Grotte.ZONE_PINCE)
	if d.has("pince_fin") and s > L - Grotte.ZONE_PINCE:
		var c2: float = float((d["pince_fin"] as Dictionary)["cote"])
		var dl2 := g.demi_l(id, s)
		lat = c2 * 0.5 * (dl2.y if c2 > 0.0 else dl2.x) * (1.0 - (L - s) / Grotte.ZONE_PINCE)
	return lat

## Points du parcours d'une branche (s de 1 à L-1, tous les 1 m), avec décalage latéral qui contourne le mobilier.
func _route_branche(id: String, s0 := 1.0, s1 := -1.0) -> Array[Vector3]:
	var L := g.longueur(id)
	if s1 < 0.0:
		s1 = L - 1.0
	var route: Array[Vector3] = []
	var lat_prec := 0.0
	var s := s0
	while s <= s1 + 0.001:
		var best_lat := 0.0
		var best_d := -99.0
		var base := _lat_pref(id, s)
		for dlat in [0.0, lat_prec - base, 1.0, -1.0, 1.8, -1.8, 2.6, -2.6, 0.5, -0.5, 3.4, -3.4]:
			var lat: float = base + float(dlat)
			var dl := g.demi_l(id, s)
			if lat > dl.y - 0.9 or lat < -(dl.x - 0.9):
				continue
			var p := g.sol_en(id, s, lat)
			var d := _degagement(p)
			if d > 0.8:
				best_lat = lat
				best_d = d
				break
			if d > best_d:
				best_d = d
				best_lat = lat
		lat_prec = best_lat
		route.append(g.to_global(g.sol_en(id, s, best_lat)) + Vector3(0, 0.1, 0))
		if best_d < 0.55:
			print("   passage serré %s s=%.0f (dégagement %.2f m)" % [id, s, best_d])
		s += 1.0
	return route

func _capsule(pere: Node3D) -> CharacterBody3D:
	var capsule := CharacterBody3D.new()
	var cs2 := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs2.shape = cap
	cs2.position.y = 0.9
	capsule.add_child(cs2)
	capsule.floor_snap_length = 0.4
	pere.add_child(capsule)
	return capsule

## Fait marcher la capsule le long de `route` ; renvoie [arrivée atteinte, indice atteint, pente max].
func _marcher(capsule: CharacterBody3D, route: Array[Vector3], libelle: String) -> bool:
	capsule.global_position = route[0]
	capsule.velocity = Vector3.ZERO
	for i in 6:
		await physics_frame
	var t := 0.0
	var cible := 1
	var depuis := 0.0
	var pos_ref := capsule.global_position
	var ok := true
	var pente_max := 0.0
	var y_min := 1e9
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	while cible < route.size() and t < 200.0:
		var p := capsule.global_position
		if Vector2(p.x - route[cible].x, p.z - route[cible].z).length() < 0.6:
			cible += 1
			continue
		var dir := Vector3(route[cible].x - p.x, 0, route[cible].z - p.z).normalized()
		capsule.velocity.x = dir.x * VITESSE
		capsule.velocity.z = dir.z * VITESSE
		capsule.velocity.y -= 20.0 * dt
		capsule.move_and_slide()
		if capsule.is_on_floor():
			pente_max = maxf(pente_max, rad_to_deg(capsule.get_floor_angle()))
		y_min = minf(y_min, capsule.global_position.y)
		await physics_frame
		t += dt
		depuis += dt
		if depuis >= 2.0:
			if capsule.global_position.distance_to(pos_ref) < 0.5:
				print("   bloqué près de ", g.to_local(capsule.global_position), " (point ", cible, "/", route.size(), ")")
				ok = false
				break
			pos_ref = capsule.global_position
			depuis = 0.0
	var fin := ok and cible >= route.size()
	_verif(fin, "capsule %s : arrivée en %.1f s (point %d/%d, pente max %.1f°)" % [libelle, t, cible, route.size(), pente_max])
	return fin

## Plus petite distance horizontale entre le point (x, z) et les anneaux de la branche `id`.
func _dist_axe(id: String, x: float, z: float) -> float:
	var m := 1e9
	for r: Dictionary in (g.br[id] as Dictionary)["anneaux"]:
		var P: Vector3 = r["P"]
		m = minf(m, Vector2(P.x - x, P.z - z).length())
	return m

func _lancer() -> void:
	var t0 := Time.get_ticks_msec()
	var pere := Node3D.new()
	root.add_child(pere)
	g = Grotte.creer(pere)
	print("grotte construite en %d ms (%s), %d lumières, %d facettes, %d anneaux" % [Time.get_ticks_msec() - t0, g.etapes, g.nb_lumieres, g.decor.nb_facettes, g._anneaux.size()])
	var tot := 0.0
	for id: String in g.ordre:
		print("   branche %s : %.2f m, %d anneaux, largeur x%.3f, relief x%.3f" % [id, g.longueur(id), (g.br[id]["anneaux"] as Array).size(), g.br[id]["m_larg"], g.br[id]["m_relief"]])
		tot += g.longueur(id)
	print("   %.0f m de galeries, %d accroches" % [tot, g.accroches.size()])
	for i in 6:
		await physics_frame
	var ss := g.get_world_3d().direct_space_state
	# 1. étanchéité : depuis chaque anneau de chaque branche, 40 rayons en tous sens doivent toucher la coque
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var manques := 0
	var tirs := 0
	for r: Dictionary in g._anneaux:
		var o: Vector3 = g.to_global((r["P"] as Vector3) + Vector3(0, 0.45 * float(r["h"]), 0))
		for k in 40:
			var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
			var q := PhysicsRayQueryParameters3D.create(o, o + d * 90.0)
			tirs += 1
			if ss.intersect_ray(q).is_empty():
				manques += 1
				if manques < 6:
					print("   rayon sans impact depuis %s s=%.1f dir %s" % [r["b"], r["s"], d])
	_verif(manques == 0, "étanchéité : %d rayons depuis %d anneaux, %d sans impact" % [tirs, g._anneaux.size(), manques])
	# 1 bis. étanchéité fine : rayons depuis des points du sol de chaque branche (y compris les nez de pilier)
	var manques2 := 0
	var tirs2 := 0
	for id: String in g.ordre:
		var s := 0.5
		while s < g.longueur(id):
			var o2: Vector3 = g.to_global(g.sol_en(id, s, 0.0) + Vector3(0, 1.0, 0))
			for k in 24:
				var d2 := Vector3(rng.randfn(), rng.randfn() * 0.5, rng.randfn()).normalized()
				tirs2 += 1
				if ss.intersect_ray(PhysicsRayQueryParameters3D.create(o2, o2 + d2 * 90.0)).is_empty():
					manques2 += 1
			s += 2.5
	_verif(manques2 == 0, "étanchéité (sol de chaque branche) : %d rayons, %d sans impact" % [tirs2, manques2])
	# 2. séparation des galeries : les parois d'une branche ne doivent pas entrer dans l'espace d'une autre (hors zones de jonction)
	var polys := {}
	var murs := {}
	for id: String in g.ordre:
		var gauche := PackedVector2Array()
		var droite := PackedVector2Array()
		var tous := PackedVector2Array()
		for r: Dictionary in (g.br[id]["anneaux"] as Array):
			var s_r: float = r["s"]
			if s_r < 10.0 or s_r > g.longueur(id) - 10.0:
				continue
			var R: Vector3 = r["R"]
			var P: Vector3 = r["P"]
			var lmin := 1e9
			var lmax := -1e9
			var pmin := Vector3.ZERO
			var pmax := Vector3.ZERO
			for q: Vector3 in r["pts"]:
				var l := (q - P).dot(R)
				if l < lmin:
					lmin = l
					pmin = q
				if l > lmax:
					lmax = l
					pmax = q
			gauche.append(Vector2(pmin.x, pmin.z))
			droite.append(Vector2(pmax.x, pmax.z))
			tous.append(Vector2(pmin.x, pmin.z))
			tous.append(Vector2(pmax.x, pmax.z))
		droite.reverse()
		var poly := PackedVector2Array()
		poly.append_array(gauche)
		poly.append_array(droite)
		polys[id] = poly
		murs[id] = tous
	var dedans := 0
	var pire_txt := ""
	for ia: String in g.ordre:
		for ib: String in g.ordre:
			if ia == ib:
				continue
			for q: Vector2 in (murs[ia] as PackedVector2Array):
				if (polys[ib] as PackedVector2Array).size() >= 3 and Geometry2D.is_point_in_polygon(q, polys[ib]):
					dedans += 1
					pire_txt = "%s dans %s près de (%.1f, %.1f)" % [ia, ib, q.x, q.y]
	_verif(dedans == 0, "séparation des galeries : %d points de paroi dans l'espace d'une autre branche (hors 10 m de jonction) %s" % [dedans, pire_txt])
	# 3. sol sous chaque point des routes
	var routes := {}
	var sans_sol := 0
	var nb_pts := 0
	for id: String in g.ordre:
		routes[id] = _route_branche(id)
		for p: Vector3 in routes[id]:
			nb_pts += 1
			var r := ss.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p - Vector3(0, 2.0, 0)))
			if r.is_empty() or absf(float(r["position"].y) - (p.y - 0.1)) > 0.4:
				sans_sol += 1
				print("   sans sol en %s (impact : %s)" % [p, r.get("position", "aucun")])
	_verif(sans_sol == 0, "sol sous chacun des %d points des routes (%d sans sol)" % [nb_pts, sans_sol])
	# 4. la capsule parcourt TOUTES les branches : T1+A+T2+C, puis T1+B+T2+H
	var capsule := _capsule(pere)
	var chemin_a: Array[Vector3] = []
	for id in ["T1", "A", "T2", "C"]:
		chemin_a.append_array(routes[id])
	var chemin_b: Array[Vector3] = []
	for id in ["T1", "B", "T2", "H"]:
		chemin_b.append_array(routes[id])
	var ok_a: bool = await _marcher(capsule, chemin_a, "T1 → mine (A) → camp (T2) → cristaux (C)")
	var ok_b: bool = await _marcher(capsule, chemin_b, "T1 → lac (B) → camp (T2) → cache (H)")
	var bas := g.to_local(capsule.global_position).y
	_verif(bas > -14.0, "la capsule n'est pas tombée sous la grotte (y local final %.2f)" % bas)
	capsule.queue_free()
	# 5. chaque point d'accroche est atteignable : graphe de marche (capsule libre de collision à chaque nœud, marches ≤ 0,45 m)
	_graphe_marche()
	var vus := _bfs(g.to_global(g.sol_en("T1", 3.0, 0.0)))
	var nb_valides := _noeuds.size()
	var par_br := {}
	var vus_br := {}
	for k in _noeuds.size():
		var idb: String = _noeuds[k]["id"]
		par_br[idb] = int(par_br.get(idb, 0)) + 1
		if vus.has(k):
			vus_br[idb] = int(vus_br.get(idb, 0)) + 1
	print("   nœuds par branche : ", par_br, " atteints : ", vus_br)
	for sx in [10.25, 10.75, 11.25, 11.75, 12.25, 12.75]:
		var lst := []
		for k in _noeuds.size():
			if _noeuds[k]["id"] == "B" and absf(_noeuds[k]["s"] - sx) < 0.01:
				lst.append("%.1f/%.2f%s" % [_noeuds[k]["lat"], _noeuds[k]["p"].y + 220.0, "*" if vus.has(k) else ""])
		print("   B s=%.2f : %s" % [sx, lst])
	for id_dbg in ["T1", "B"]:
		var smax_v := 0.0
		var smin_nv := 999.0
		for k in _noeuds.size():
			if _noeuds[k]["id"] != id_dbg:
				continue
			if vus.has(k):
				smax_v = maxf(smax_v, _noeuds[k]["s"])
			else:
				smin_nv = minf(smin_nv, _noeuds[k]["s"])
		print("   %s : s max atteint %.1f ; s min non atteint %.1f" % [id_dbg, smax_v, smin_nv])
	print("   graphe de marche : %d nœuds libres, %d atteints depuis l'entrée" % [nb_valides, vus.size()])
	var nb_acc := 0
	var nb_ok := 0
	for a: Dictionary in g.accroches:
		var type: String = a["type"]
		var cible_loc: Vector3 = a["pos"]
		if type == "coffre":
			cible_loc = a["lieu"]
		var but := g.to_global(cible_loc)
		var rayon := 1.2 if type == "ennemi" else 2.0
		if type == "meca":
			rayon = 3.0
		var n := _plus_proche(vus, but, rayon)
		nb_acc += 1
		if n >= 0:
			nb_ok += 1
		else:
			print("ECHEC accroche %s (%s) : aucun point de marche atteignable à moins de %.1f m de %s" % [a["id"], type, rayon, g.to_local(but)])
			_echecs += 1
	_verif(nb_ok == nb_acc, "points d'accroche atteignables à pied depuis l'entrée : %d / %d" % [nb_ok, nb_acc])
	# 5 bis. trajets réels de la capsule vers les cibles « difficiles » (corniches, îlot, baie de l'éboulis, cache)
	var capsule2 := _capsule(pere)
	var difficiles := ["corniche", "bandit_archer_2", "bandit_archer_0", "ilot", "journal_sigrun", "mine_eboulis", "argent_rare", "registre_hrafn", "fond"]
	for a: Dictionary in g.accroches:
		if not difficiles.has(String(a["id"])):
			continue
		var cible_loc: Vector3 = a["lieu"] if a["type"] == "coffre" else a["pos"]
		var but := g.to_global(cible_loc)
		var n := _plus_proche(vus, but, 2.0)
		if n < 0:
			continue
		var chemin := _chemin_vers(n)
		var simple: Array[Vector3] = []
		for k in range(0, chemin.size(), 2):
			simple.append(chemin[k] + Vector3(0, 0.1, 0))
		simple.append(chemin[chemin.size() - 1] + Vector3(0, 0.1, 0))
		if simple.size() >= 2:
			await _marcher(capsule2, simple, "vers %s (%.0f m)" % [a["id"], chemin.size() * 0.5])
	var nb_cs := 0
	for n in g.corps.get_children():
		if n is CollisionShape3D:
			nb_cs += 1
	print("collisions : %d formes (dont la coque trimesh de %d triangles)" % [nb_cs, g.decor.coll.size() / 3])
	print("TOUT OK" if _echecs == 0 else "ECHECS : %d" % _echecs)
	quit(_echecs)

# ------------------------------------------------------------------ graphe de marche
var _noeuds: Array = []                   # { "p": Vector3 global (pied), "id": branche, "v": [indices voisins] }
var _cle := {}                            # (branche, i, j) -> indice
var _hash := {}                           # cellule 0,5 m -> [indices]

func _graphe_marche() -> void:
	var ss := g.get_world_3d().direct_space_state
	var forme := CapsuleShape3D.new()
	forme.radius = 0.32
	forme.height = 1.8
	_noeuds.clear()
	_cle.clear()
	_hash.clear()
	var pas := 0.5
	for id: String in g.ordre:
		var L := g.longueur(id)
		var i := 0
		var s := 0.25
		while s < L - 0.2:
			var dl := g.demi_l(id, s)
			var j := ceili((-dl.x - 0.3) / pas)
			var j1 := floori((dl.y + 0.3) / pas)
			while j <= j1:
				var lat := float(j) * pas
				var c := g.xz(id, s) + Vector2(g.droite(id, s).x, g.droite(id, s).z) * lat
				var origines: Array = [g.sol_en(id, s, lat).y + 1.3]
				for cid: String in g.corniches:
					var cn: Dictionary = g.corniches[cid]
					if cn["b"] != id or not cn.has("rampe"):
						continue
					var lr: float = cn["rampe_l"]
					var u0: float = float(cn["s"]) - (lr if cn["rampe"] == "debut" else 0.0)
					var u1: float = float(cn["s"]) + float(cn["longueur"]) + (lr if cn["rampe"] == "fin" else 0.0)
					if s >= u0 and s <= u1 and lat >= float(cn["lat"]) - 0.1 and lat <= float(cn["lat"]) + float(cn["largeur"]) + 0.1:
						origines.append(float(cn["top"]) + 1.3)
				var niveau := 0
				for y_dep: float in origines:
					var de := g.to_global(Vector3(c.x, y_dep, c.y))
					var r := ss.intersect_ray(PhysicsRayQueryParameters3D.create(de, de - Vector3(0, 14.0, 0)))
					if not r.is_empty():
						var f: Vector3 = r["position"]
						var q := PhysicsShapeQueryParameters3D.new()
						q.shape = forme
						q.transform = Transform3D(Basis.IDENTITY, f + Vector3(0, 0.9 + 0.05, 0))
						q.collide_with_bodies = true
						if ss.intersect_shape(q, 1).is_empty():
							var idx := _noeuds.size()
							_noeuds.append({"p": f, "id": id, "v": [], "s": s, "lat": lat})
							_cle[Vector3i(_h_br(id) * 2 + niveau, i, j)] = idx
							var hk := Vector2i(floori(f.x / pas), floori(f.z / pas))
							if not _hash.has(hk):
								_hash[hk] = []
							(_hash[hk] as Array).append(idx)
					niveau += 1
				j += 1
			s += pas
			i += 1
	# voisinages : dans la grille de la branche (s, lat), puis entre branches (même endroit, même niveau)
	for k: Vector3i in _cle:
		var a: int = _cle[k]
		for d in [Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(0, 1, 1), Vector3i(0, 1, -1)]:
			var k2: Vector3i = k + d
			if _cle.has(k2):
				_lier(a, _cle[k2])
	for hk: Vector2i in _hash:
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var hk2 := Vector2i(hk.x + dx, hk.y + dz)
				if not _hash.has(hk2):
					continue
				for a: int in _hash[hk]:
					for b: int in _hash[hk2]:
						if a < b:
							_lier(a, b)

func _h_br(id: String) -> int:
	return g.ordre.find(id)

func _lier(a: int, b: int) -> void:
	var pa: Vector3 = _noeuds[a]["p"]
	var pb: Vector3 = _noeuds[b]["p"]
	if absf(pa.y - pb.y) > 0.45:
		return
	if Vector2(pa.x - pb.x, pa.z - pb.z).length() > 0.75:
		return
	(_noeuds[a]["v"] as Array).append(b)
	(_noeuds[b]["v"] as Array).append(a)

var _parent := {}

func _bfs(depart: Vector3) -> Dictionary:
	_parent.clear()
	var d0 := 1e9
	var n0 := -1
	for k in _noeuds.size():
		var p: Vector3 = _noeuds[k]["p"]
		var dd := p.distance_to(depart)
		if dd < d0:
			d0 = dd
			n0 = k
	var vus := {n0: true}
	_parent[n0] = -1
	var file: Array = [n0]
	var tete := 0
	while tete < file.size():
		var a: int = file[tete]
		tete += 1
		for b: int in _noeuds[a]["v"]:
			if not vus.has(b):
				vus[b] = true
				_parent[b] = a
				file.append(b)
	return vus

func _plus_proche(vus: Dictionary, but: Vector3, rayon: float) -> int:
	var best := -1
	var bd := rayon
	for k: int in vus:
		var p: Vector3 = _noeuds[k]["p"]
		if absf(p.y - but.y) > 1.9:
			continue
		var dd := Vector2(p.x - but.x, p.z - but.z).length()
		if dd < bd:
			bd = dd
			best = k
	return best

func _chemin_vers(n: int) -> Array[Vector3]:
	var res: Array[Vector3] = []
	var k := n
	while k >= 0:
		res.append(_noeuds[k]["p"])
		k = _parent[k]
	res.reverse()
	return res
