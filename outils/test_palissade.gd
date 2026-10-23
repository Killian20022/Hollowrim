extends SceneTree
## Palissade prolongée du village v2 (lot C7b, plan docs/PLAN_VILLAGE_V2.md : 228 m, ReliefVillage.PALISSADE) — visuel
## validé (pieux bas ~1,5 m, passe 3) et COLLISION d'origine conservée pieu par pieu : un CylinderShape3D (rayon 0,22,
## hauteur 3,6) centré 1,8 m au-dessus du pied de chaque pieu, qui suit le terrain. Vérifie :
##   1. une forme par pieu, au bon endroit, mêmes dimensions ; > 450 pieux ; longueur ≈ 228 m ;
##   2. rayons horizontaux de l'extérieur vers l'intérieur, tout le long (hors portes), de 0,3 à 3,4 m au-dessus du sol :
##      tous arrêtés (comptés depuis le pied le plus bas des pieux voisins) ; aux 2 grilles d'eau, de 0,3 m au-dessus de
##      l'eau à 3 m au-dessus du fond, une sphère de 0,25 m lancée à travers : toutes arrêtées ;
##   3. un marcheur (capsule du joueur) qui fonce vers l'intérieur en sautant sans arrêt, en 16+ points du pourtour et dans le
##      lit de la rivière devant chaque grille : ne passe jamais ;
##   4. les 3 portes (SO, N, E) se franchissent ;
##   5. le visuel reste bas (< 2 m au-dessus du pied de chaque pieu).
##   godot --headless --path . --script outils/test_palissade.gd -- --nouvelle
const SCENE := preload("res://scenes/foret_test.tscn")
const VILLAGE_GD := preload("res://scripts/village.gd")
const JOUEUR_GD := preload("res://scripts/joueur.gd")

var m: Node3D
var v: Node3D
var _echecs := 0

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _pres(q: Vector2, indices: Array, r: float) -> bool:
	for i in indices:
		if q.distance_to(ReliefVillage.PALISSADE[i]) < r:
			return true
	return false

## Normale horizontale vers l'intérieur de l'enceinte au point `q` du segment de direction `d`.
func _vers_dedans(q: Vector2, d: Vector2) -> Vector2:
	var nn := Vector2(-d.y, d.x)
	return nn if ReliefVillage.dans_enceinte(q.x + nn.x * 0.8, q.y + nn.y * 0.8) else -nn

func _marcheur() -> CharacterBody3D:
	var w := CharacterBody3D.new()
	var cap := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	cap.shape = capsule
	cap.position.y = 0.9
	w.add_child(cap)
	root.add_child(w)
	return w

## Fait foncer `w` depuis `dep` (monde, posé au sol) dans la direction `dir`, `n` images (en sautant ou non) ; positions.
func _foncer(w: CharacterBody3D, dep: Vector2, dir: Vector2, n := 240, sauter := true) -> Array:
	w.global_position = Vector3(dep.x, m.hauteur(dep.x, dep.y) + 0.5, dep.y)
	w.velocity = Vector3.ZERO
	var pos: Array = []
	for i in n:
		w.velocity.x = dir.x * 7.0
		w.velocity.z = dir.y * 7.0
		w.velocity.y -= JOUEUR_GD.GRAVITE / 60.0
		if w.is_on_floor() and sauter:
			w.velocity.y = JOUEUR_GD.SAUT
		w.move_and_slide()
		pos.append(w.global_position)
		await physics_frame
	return pos

func _plus_dedans(traj: Array) -> float:
	var dmin := INF
	for p: Vector3 in traj:
		dmin = minf(dmin, ReliefVillage.distance_palissade(p.x, p.z))
	return dmin

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 10:
		await physics_frame
	v = m.village
	var pts: Array = ReliefVillage.PALISSADE
	var n := pts.size()

	# 1. formes de collision : un cylindre r 0,22 × h 3,6 à 1,8 m au-dessus du pied de chaque pieu
	# rangées par case de 0,5 m (recherche du plus proche dans les 9 cases voisines : pas d'erreur d'arrondi sur la clé)
	var formes := {}
	for cs in (v.corps as StaticBody3D).get_children():
		if cs is CollisionShape3D and cs.shape is CylinderShape3D:
			var g: Vector3 = (v.corps as Node3D).global_transform * (cs as CollisionShape3D).position
			var kc := Vector2i(floori(g.x * 2.0), floori(g.z * 2.0))
			if not formes.has(kc):
				formes[kc] = []
			formes[kc].append([cs, g])
	var pieux: Array = v.pieux_v2
	var bons := 0
	for p: Vector3 in pieux:
		var k := Vector2i(floori(p.x * 2.0), floori(p.z * 2.0))
		var pres: Array = []
		var dmin := 0.02
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for f in formes.get(k + Vector2i(dx, dz), []):
					var dd := Vector2((f[1] as Vector3).x - p.x, (f[1] as Vector3).z - p.z).length()
					if dd < dmin:
						dmin = dd
						pres = f
		if not pres.is_empty():
			var s: CylinderShape3D = (pres[0] as CollisionShape3D).shape
			var g: Vector3 = pres[1]
			if is_equal_approx(s.radius, 0.22) and is_equal_approx(s.height, 3.6) and absf(g.y - (p.y + 1.8)) < 0.01:
				bons += 1
	var long := 0.0
	var cumul: Array[float] = [0.0]
	for i in n:
		long += (pts[i] as Vector2).distance_to(pts[(i + 1) % n])
		cumul.append(long)
	_verif(pieux.size() > 450, "pieux posés le long de la palissade : %d" % pieux.size())
	_verif(bons == pieux.size(), "chaque pieu a son cylindre r 0,22 × h 3,6 centré 1,8 m au-dessus de son pied : %d / %d" % [bons, pieux.size()])
	_verif(absf(long - 228.0) < 6.0, "longueur de la palissade : %.1f m (plan : 228 m)" % long)
	_verif(v.grilles_v2.size() >= 8, "pieux fins des 2 grilles d'eau : %d" % v.grilles_v2.size())

	# 2. rayons horizontaux de l'extérieur vers l'intérieur, tous les 1,5 m hors portes
	var esp := m.get_world_3d().direct_space_state
	var n_r := 0
	var n_tou := 0
	var rates: Array = []
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var d := (b - a).normalized()
		var nb := int(a.distance_to(b) / 1.5)
		for k in range(1, nb):
			var q := a.lerp(b, float(k) / nb)
			if _pres(q, VILLAGE_GD.PORTES_V2, 3.0):
				continue
			var dd := _vers_dedans(q, d)
			var r := ReliefVillage.riviere(q.x, q.y)
			var grille: bool = _pres(q, VILLAGE_GD.GRILLES_V2, 7.0) and not r.is_empty() and float(r["distance"]) < float(r["demi_largeur"]) + 0.35
			var sol: float = DetailsSol.hauteur_maillage(m, q.x, q.y)
			# sur une marche du terrain (murs de terrasse de la haute rue), la palissade suit le pied le plus BAS des pieux
			# voisins : les hauteurs hautes se comptent depuis lui (un pieu plus haut d'un cran ne couvre pas 3,4 m au-dessus du bas)
			var bas := sol
			for p: Vector3 in pieux:
				if absf(p.x - q.x) < 0.5 and absf(p.z - q.y) < 0.5 and Vector2(p.x - q.x, p.z - q.y).length() < 0.45:
					bas = minf(bas, p.y)
			var hauteurs := [0.3, 1.0, 1.8, 2.6 + bas - sol, 3.4 + bas - sol]
			if grille:
				var eau: float = r["eau"]
				hauteurs = [eau - sol + 0.3, eau - sol + 1.0, 2.2, 3.0]
			for hy in hauteurs:
				var o := Vector3(q.x - dd.x, sol + hy, q.y - dd.y)
				var f := Vector3(q.x + dd.x, sol + hy, q.y + dd.y)
				n_r += 1
				if grille:
					# grille d'eau : l'eau passe entre les pieux fins (jour de 0,12 m) → on lance une sphère de 0,25 m
					# (le joueur est une capsule de 0,4 m de rayon) au lieu d'un rayon
					var sp := SphereShape3D.new()
					sp.radius = 0.25
					var qs := PhysicsShapeQueryParameters3D.new()
					qs.shape = sp
					qs.transform = Transform3D(Basis(), o)
					qs.motion = f - o
					qs.collide_with_areas = false
					var fr := esp.cast_motion(qs)
					if fr[0] < 1.0:
						n_tou += 1
					elif rates.size() < 6:
						rates.append("(%.1f;%.1f) h %.1f grille" % [q.x, q.y, hy])
					continue
				var qq := PhysicsRayQueryParameters3D.create(o, f)
				qq.collide_with_areas = false
				var h := esp.intersect_ray(qq)
				if not h.is_empty() and h["collider"] == v.corps:
					n_tou += 1
				elif rates.size() < 6:
					rates.append("(%.1f;%.1f) h %.1f%s" % [q.x, q.y, hy, " grille" if grille else ""])
	_verif(n_tou == n_r, "rayons horizontaux arrêtés par la palissade et les grilles : %d / %d %s" % [n_tou, n_r, str(rates) if not rates.is_empty() else ""])

	# 3. marcheur sautant vers l'intérieur : points répartis sur le pourtour (hors portes et grilles) + le lit aux grilles
	var w := _marcheur()
	var passes := 0
	var essais := 0
	var pire := INF
	for j in 32:
		var s := long * (j + 0.5) / 32.0
		var i := 0
		while cumul[i + 1] < s:
			i += 1
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var q := a.lerp(b, (s - cumul[i]) / a.distance_to(b))
		if _pres(q, VILLAGE_GD.PORTES_V2, 4.0) or _pres(q, VILLAGE_GD.GRILLES_V2, 6.0):
			continue
		var dd := _vers_dedans(q, (b - a).normalized())
		essais += 1
		var dmin := _plus_dedans(await _foncer(w, q - dd * 1.6, dd))
		pire = minf(pire, dmin)
		if dmin < -0.3:
			passes += 1
			print("  passage en (%.1f ; %.1f)" % [q.x, q.y])
	_verif(essais >= 16 and passes == 0, "marcheur sautant (saut %.1f, gravité %.0f) : %d / %d passages ; au plus près : %.2f m de la palissade" % [JOUEUR_GD.SAUT, JOUEUR_GD.GRAVITE, passes, essais, pire])
	for gi in VILLAGE_GD.GRILLES_V2:
		var g: Vector2 = pts[gi]
		var r := ReliefVillage.riviere(g.x, g.y)
		var aval: Vector2 = r["direction"]
		# grille E : on arrive de l'amont (dehors) ; grille O : de l'aval (le lac)
		var dehors: Vector2 = g - aval * 3.0 if gi == VILLAGE_GD.GRILLES_V2[0] else g + aval * 3.0
		var dmin := _plus_dedans(await _foncer(w, dehors, (g - dehors).normalized()))
		_verif(dmin > -0.3, "grille d'eau (%.1f ; %.1f) : le marcheur reste dehors dans le lit (au plus près : %.2f m)" % [g.x, g.y, dmin])

	# 4. les 3 portes se franchissent (marche droite, sans saut)
	for gi in VILLAGE_GD.PORTES_V2:
		var g: Vector2 = pts[gi]
		var d := ((pts[(gi + 1) % n] as Vector2) - (pts[(gi - 1 + n) % n] as Vector2)).normalized()
		var dd := _vers_dedans(g, d)
		var traj: Array = await _foncer(w, g - dd * 3.0, dd, 90, false)
		var fin: Vector3 = traj[-1]
		_verif(ReliefVillage.distance_palissade(fin.x, fin.z) < -2.0, "porte (%.1f ; %.1f) franchie : arrivée à %.1f m dedans" % [g.x, g.y, -ReliefVillage.distance_palissade(fin.x, fin.z)])
	w.queue_free()

	# 5. visuel : les pieux bas dépassent de moins de 2 m de leur pied
	var haut := 0.0
	var n_mm := 0
	for c in v.get_children():
		if c is MultiMeshInstance3D and String(c.name).begins_with("PieuxBas"):
			n_mm += 1
			var mm: MultiMesh = (c as MultiMeshInstance3D).multimesh
			var bb := mm.mesh.get_aabb()
			for i in mm.instance_count:
				var xf := mm.get_instance_transform(i)
				haut = maxf(haut, (xf * bb).end.y - xf.origin.y)
	_verif(n_mm > 0 and haut < 2.0, "pieux visibles bas : %d lots, au plus %.2f m au-dessus du pied (< 2 m)" % [n_mm, haut])

	print("ECHECS : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)
