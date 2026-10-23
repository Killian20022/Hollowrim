extends SceneTree
## AUDIT DES BUGS — extérieur : trous de collision, falaises, pièges, poches inaccessibles, hauteur minimale.
##   godot --headless --path . --script outils/audit_terrain.gd -- --nouvelle --paisible
## Grille de 1 m sur toute la carte (±120 m) : empilement de rayons verticaux (terrain + objets), capsule du joueur par case,
## puis accessibilité orientée depuis le point d'apparition (marche ≤ 45°, saut 0,7 m) : cases ATTEINTES mais d'où l'on ne revient pas = pièges.
const SCENE := preload("res://scenes/foret_test.tscn")
const Base := preload("res://outils/audit_base.gd")
const PAS := 1.0
const DEMI := 120
const MONTEE_MAX := 1.0         # m de dénivelé gravissable par mètre (floor_max_angle 45°)

var m: Node3D
var R := Base.Rapport.new("terrain")

func _init() -> void:
	_lancer.call_deferred()

func _lancer() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 6:
		await physics_frame
	var ss := m.get_world_3d().direct_space_state
	var terrain: StaticBody3D = null
	for c in m.get_children():
		if c is StaticBody3D and c.get_child_count() == 16 and (c.get_child(0) as CollisionShape3D).shape is ConcavePolygonShape3D:
			terrain = c
	if terrain == null:
		R.ajouter("outil", "bloquant", Vector3.ZERO, "StaticBody du terrain introuvable")
		R.ecrire()
		quit(1)
		return
	var vivants: Array[RID] = [terrain.get_rid()]
	var eau: Node = m.get_node_or_null("EauVillage")
	for n in m.find_children("*", "CharacterBody3D", true, false):
		vivants.append((n as CharacterBody3D).get_rid())
	var N := 2 * DEMI + 1
	var yt := PackedFloat32Array()
	yt.resize(N * N)
	var libre := PackedByteArray()
	libre.resize(N * N)
	var obstacle: Array = []
	obstacle.resize(N * N)
	var trous := {}
	var ecarts := {}
	var raides := {}
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	var y_min := INF
	var y_max := -INF
	var qs := PhysicsShapeQueryParameters3D.new()
	qs.shape = cap
	qs.exclude = vivants
	qs.collide_with_bodies = true
	var t0 := Time.get_ticks_msec()
	for j in N:
		for i in N:
			var x := (i - DEMI) * PAS
			var z := (j - DEMI) * PAS
			var h: float = m.hauteur(x, z)
			var k := j * N + i
			# terrain seul : rayon qui ignore les objets rencontrés
			var excl: Array[RID] = []
			var y_t := NAN
			for essai in 8:
				var q := PhysicsRayQueryParameters3D.create(Vector3(x, 90.0, z), Vector3(x, -60.0, z))
				q.exclude = excl
				var r := ss.intersect_ray(q)
				if r.is_empty():
					break
				if r["rid"] == terrain.get_rid():
					y_t = (r["position"] as Vector3).y
					break
				excl.append(r["rid"])
			if is_nan(y_t):
				trous[Vector2i(i, j)] = true
				yt[k] = h
				continue
			if absf(y_t - h) > 0.5:
				ecarts[Vector2i(i, j)] = true
			# passe D : sol marchable posé sur le relief (rampes invisibles, perron, marches, glace et fond du lac) : on y marche
			var y_sol := y_t
			var qr := PhysicsRayQueryParameters3D.create(Vector3(x, y_t + 0.6, z), Vector3(x, y_t - 0.05, z))
			qr.exclude = vivants
			var rs := ss.intersect_ray(qr)
			if not rs.is_empty():
				var nr: Vector3 = rs["normal"]
				var dy: float = (rs["position"] as Vector3).y - y_t
				if nr.y >= 0.7 and (nr.y < 0.995 or dy <= 0.12):   # rampe inclinée, ou sol mince affleurant (pas une caisse)
					y_sol = maxf(y_t, (rs["position"] as Vector3).y)
			if eau != null and eau.dans_lac(x, z):
				var yl: float = eau._sol_lac(x, z)
				if not is_nan(yl):
					y_sol = maxf(y_sol, yl)
			y_t = y_sol
			yt[k] = y_t
			y_min = minf(y_min, y_t)
			y_max = maxf(y_max, y_t)
			# capsule posée sur le sol (hors terrain, exclu) : un autre corps la gêne-t-il ?
			qs.transform = Transform3D(Basis(), Vector3(x, y_t + 0.15 + 0.9, z))
			var gene := ss.intersect_shape(qs, 4)
			libre[k] = 1 if gene.is_empty() else 0
			if not gene.is_empty():
				var co := gene[0]["collider"] as Node
				obstacle[k] = "%s/%s" % [co.get_parent().name if co.get_parent() != null else "?", co.name]
	print("balayage %d cases en %d ms ; y terrain de %.1f à %.1f" % [N * N, Time.get_ticks_msec() - t0, y_min, y_max])
	R.stats["y_min"] = snappedf(y_min, 0.01)
	R.stats["y_max"] = snappedf(y_max, 0.01)
	# --- pentes
	var pente_nb := 0
	for j in range(1, N - 1):
		for i in range(1, N - 1):
			var k := j * N + i
			var dx := (yt[k + 1] - yt[k - 1]) * 0.5
			var dz := (yt[k + N] - yt[k - N]) * 0.5
			if sqrt(dx * dx + dz * dz) > MONTEE_MAX and absf(i - DEMI) < 108 and absf(j - DEMI) < 108:
				raides[Vector2i(i, j)] = true
				pente_nb += 1
	R.stats["cases_pente_sup_45"] = pente_nb
	# --- accessibilité orientée
	var dep: Vector3 = m.joueur.global_position
	var si := clampi(roundi(dep.x / PAS) + DEMI, 0, N - 1)
	var sj := clampi(roundi(dep.z / PAS) + DEMI, 0, N - 1)
	# départ = case libre la plus proche (le feu de camp occupe la case d'apparition)
	var meilleur := INF
	var depart := sj * N + si
	for dj in range(-8, 9):
		for di in range(-8, 9):
			var kk := (sj + dj) * N + si + di
			if libre[kk] == 1 and Vector2(di, dj).length() < meilleur:
				meilleur = Vector2(di, dj).length()
				depart = kk
	si = depart % N
	sj = depart / N
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var arete := func(a: int, b: int) -> bool:
		return libre[b] == 1 and (yt[b] - yt[a]) <= MONTEE_MAX
	var avant := {}
	var pile: Array = [sj * N + si]
	avant[sj * N + si] = true
	while not pile.is_empty():
		var a: int = pile.pop_back()
		var ai := a % N
		var aj := a / N
		for d: Vector2i in dirs:
			var ni := ai + d.x
			var nj := aj + d.y
			if ni < 0 or nj < 0 or ni >= N or nj >= N or absf(ni - DEMI) > 108 or absf(nj - DEMI) > 108:
				continue  # la zone jouable s'arrête à ±108 (joueur.LIMITE)
			var b := nj * N + ni
			if not avant.has(b) and arete.call(a, b):
				avant[b] = true
				pile.append(b)
	# retour : BFS sur le graphe inverse, limité aux cases atteintes
	var retour := {}
	pile = [sj * N + si]
	retour[sj * N + si] = true
	while not pile.is_empty():
		var b: int = pile.pop_back()
		var bi := b % N
		var bj := b / N
		for d: Vector2i in dirs:
			var ai := bi + d.x
			var aj := bj + d.y
			if ai < 0 or aj < 0 or ai >= N or aj >= N:
				continue
			var a := aj * N + ai
			if avant.has(a) and not retour.has(a) and arete.call(a, b):
				retour[a] = true
				pile.append(a)
	var pieges := {}
	for a in avant:
		if not retour.has(a):
			pieges[Vector2i(a % N, a / N)] = true
	var isoles := {}
	for j in range(DEMI - 108, DEMI + 109):
		for i in range(DEMI - 108, DEMI + 109):
			var k := j * N + i
			if libre[k] == 1 and not avant.has(k) and not trous.has(Vector2i(i, j)):
				isoles[Vector2i(i, j)] = true
	R.stats["cases_atteintes"] = avant.size()
	R.stats["cases_pieges"] = pieges.size()
	R.stats["cases_libres_inaccessibles"] = isoles.size()
	var surf_jouable := 217 * 217
	R.stats["part_atteinte_pct"] = snappedf(100.0 * avant.size() / surf_jouable, 0.1)
	# --- rapport
	var org := Vector2(-DEMI, -DEMI)
	for g in Base.grappes(trous):
		var b := Base.boite(g, PAS, org)
		var c: Vector2 = b["centre"]
		R.ajouter("trou_collision", "bloquant", Vector3(c.x, y_min, c.y), "aucun sol sous %d case(s) de 1 m (de %.0f,%.0f à %.0f,%.0f)" % [g.size(), b["min"].x, b["min"].y, b["max"].x, b["max"].y])
	for g in Base.grappes(ecarts):
		if g.size() < 3:
			continue
		var b := Base.boite(g, PAS, org)
		var c: Vector2 = b["centre"]
		R.ajouter("ecart_visuel_collision", "cosmetique", Vector3(c.x, m.hauteur(c.x, c.y), c.y), "collision à plus de 0,5 m de hauteur() sur %d cases" % g.size())
	for g in Base.grappes(pieges):
		var b := Base.boite(g, PAS, org)
		var c: Vector2 = b["centre"]
		var gr := "bloquant" if g.size() >= 4 else "gênant"
		R.ajouter("piege_sans_retour", gr, Vector3(c.x, yt[(roundi(c.y) + DEMI) * N + roundi(c.x) + DEMI], c.y), "%d case(s) atteignable(s) d'où l'on ne peut pas revenir à pied (x %.0f..%.0f, z %.0f..%.0f)" % [g.size(), b["min"].x, b["max"].x, b["min"].y, b["max"].y])
	for g in Base.grappes(isoles):
		var b := Base.boite(g, PAS, org)
		var c: Vector2 = b["centre"]
		var ci := roundi(c.x) + DEMI
		var cj := roundi(c.y) + DEMI
		if g.size() < 6:
			continue
		R.ajouter("poche_inaccessible", "info" if g.size() < 40 else "gênant", Vector3(c.x, yt[cj * N + ci], c.y), "%d cases libres non atteignables à pied (x %.0f..%.0f, z %.0f..%.0f)" % [g.size(), b["min"].x, b["max"].x, b["min"].y, b["max"].y])
	# falaises/raides : grappes importantes seulement
	var n_raides := 0
	for g in Base.grappes(raides):
		if g.size() < 12:
			continue
		n_raides += 1
		var b := Base.boite(g, PAS, org)
		var c: Vector2 = b["centre"]
		R.ajouter("pente_raide", "info", Vector3(c.x, m.hauteur(c.x, c.y), c.y), "zone de %d cases à plus de 45° (glissade/infranchissable) x %.0f..%.0f z %.0f..%.0f" % [g.size(), b["min"].x, b["max"].x, b["min"].y, b["max"].y])
	R.stats["grappes_pente_raide"] = n_raides
	# objets qui gênent un chemin : cases du chemin (distance à l'axe < 1 m) occupées par un obstacle
	var sur_chemin := {}
	for j in range(DEMI - 108, DEMI + 109):
		for i in range(DEMI - 108, DEMI + 109):
			var k := j * N + i
			if libre[k] == 0 and m.chemins != null and m.chemins.distance(float(i - DEMI), float(j - DEMI)) < 1.0 and obstacle[k] != null:
				sur_chemin[Vector2i(i, j)] = obstacle[k]
	for c: Vector2i in sur_chemin:
		R.ajouter("obstacle_sur_chemin", "gênant", Vector3(c.x - DEMI, yt[c.y * N + c.x], c.y - DEMI), "« %s » sur l'axe d'un chemin" % sur_chemin[c])
	# carte brute pour la carte PNG : 0 = libre atteint, 1 = libre non atteint, 2 = obstacle, 3 = piège, 4 = trou
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for j in N:
		for i in N:
			var k := j * N + i
			var h01 := clampf((yt[k] - y_min) / maxf(y_max - y_min, 0.1), 0.0, 1.0)
			var col := Color(0.18 + 0.5 * h01, 0.2 + 0.5 * h01, 0.25 + 0.55 * h01)
			if trous.has(Vector2i(i, j)):
				col = Color.BLACK
			elif libre[k] == 0:
				col = col.darkened(0.55)
			img.set_pixel(i, j, col)
	Base.dossier()
	img.save_png(ProjectSettings.globalize_path("res://captures/audit/fond_terrain.png"))
	var obs := {}
	for k in N * N:
		if obstacle[k] != null:
			obs[str(obstacle[k])] = int(obs.get(str(obstacle[k]), 0)) + 1
	R.stats["cases_obstruees_par"] = obs
	# --- relief pour l'eau future : histogramme des hauteurs (zone jouable) et bas-fonds (cuvettes à moins de 1,5 m du point le plus bas)
	var histo := {}
	var bas := {}
	var seuil_bas := y_min + 1.5
	for j in range(DEMI - 108, DEMI + 109):
		for i in range(DEMI - 108, DEMI + 109):
			var yy := yt[j * N + i]
			var bin := int(floorf(yy))
			histo[bin] = int(histo.get(bin, 0)) + 1
			if yy < seuil_bas:
				bas[Vector2i(i, j)] = true
	R.stats["histogramme_hauteurs_m_par_metre"] = histo
	for g in Base.grappes(bas):
		if g.size() < 8:
			continue
		var b := Base.boite(g, PAS, org)
		var c: Vector2 = b["centre"]
		R.ajouter("bas_fond", "info", Vector3(c.x, y_min, c.y), "cuvette de %d cases à moins de 1,5 m du point le plus bas (%.1f m) : sol sous l'eau future ? x %.0f..%.0f z %.0f..%.0f" % [g.size(), y_min, b["min"].x, b["max"].x, b["min"].y, b["max"].y])
	R.ecrire()
	quit(0)
