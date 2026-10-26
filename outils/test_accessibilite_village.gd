extends SceneTree
## Accessibilité autour du village (piège du moulin, 2026-10-26) : aucune POCHE où l'on entre sans pouvoir en ressortir.
##
## 1. Grille de 0,5 m sur toute la boîte du village v2 (palissade, rivière, berges et rive est du lac) : par case, la surface
##    de collision la plus haute (rayon vertical) et sa pente. Graphe ORIENTÉ entre cases voisines (8 voisins) :
##    - descendre : toujours permis (on tombe ou on glisse) ;
##    - monter : seulement vers une case où l'on tient debout (pente ≤ PENTE_MAX) depuis une case où l'on tient debout,
##      de MONTEE m au plus (pente marchable ou petit saut) ;
##    - jamais à travers un obstacle : deux sphères de 0,3 m lancées de A vers B (genoux et poitrine, au-dessus du plus haut des
##      deux sols ; le terrain lui-même est jugé par les hauteurs). Une case où la sphère ne tient pas (pieu, mur) est exclue.
##    Graines : le bord de la boîte (le monde continue au-delà) + la place du village. Poche = case atteignable depuis les
##    graines mais d'où l'on ne peut plus les rejoindre. Les poches de ≥ SEUIL_POCHE cases (0,25 m² chacune) sont des ÉCHECS.
## 2. Position de la sauvegarde de l'utilisateur coincé (18,09 ; 1,03 ; 57,28) : la case rejoint les graines, et le VRAI
##    joueur, posé là, rejoint la place du village en courant d'un point de passage à l'autre.
##   godot --headless --fixed-fps 60 --path . --script outils/test_accessibilite_village.gd -- --nouvelle --paisible [--carte]
##   --carte : imprime la carte des poches (caractères) autour de chacune.
const SCENE := preload("res://scenes/foret_test.tscn")
const PAS := 0.5
const X0 := -8.0
const X1 := 102.0
const Z0 := 6.0
const Z1 := 100.0
const PENTE_MAX := 44.0          # degrés (le joueur : floor_max_angle 45°)
const MONTEE := 0.45             # m entre deux cases voisines (orthogonales ; ×√2 en diagonale)
const SEUIL_POCHE := 4           # cases : 1 m²
const COINCE := Vector3(18.09, 1.03, 57.28)   # sauvegarde de l'utilisateur (captures_tmp/save_coince_moulin.json)
const PLACE := Vector2(44.0, 40.0)

var m: Node3D
var _echecs := 0
var nx := 0
var nz := 0
var hs := PackedFloat32Array()     # hauteur de la surface (NAN = rien)
var debout := PackedByteArray()    # 1 = pente marchable
var adj := PackedInt32Array()      # 8 bits par case : voisin k atteignable (A → B)
var angles := PackedFloat32Array() # pente de la surface (degrés)
const VOIS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]

func _init() -> void:
	_tester.call_deferred()

func _verif(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		_echecs += 1

func _xz(i: int, j: int) -> Vector2:
	return Vector2(X0 + i * PAS, Z0 + j * PAS)

func _case(x: float, z: float) -> int:
	var i := roundi((x - X0) / PAS)
	var j := roundi((z - Z0) / PAS)
	return j * nx + i

func _tester() -> void:
	m = SCENE.instantiate()
	m.set_meta("test", true)
	root.add_child(m)
	for i in 10:
		await physics_frame
	# personnages hors des rayons (villageois, gardes, joueur) : seul le décor statique compte
	for c in root.find_children("*", "CharacterBody3D", true, false):
		(c as CollisionObject3D).set_meta("couche", (c as CollisionObject3D).collision_layer)
		(c as CollisionObject3D).collision_layer = 0
	for c in root.find_children("*", "RigidBody3D", true, false):
		(c as CollisionObject3D).collision_layer = 0
	await physics_frame
	var t0 := Time.get_ticks_msec()
	var esp := m.get_world_3d().direct_space_state
	nx = int((X1 - X0) / PAS) + 1
	nz = int((Z1 - Z0) / PAS) + 1
	var n := nx * nz
	hs.resize(n)
	debout.resize(n)
	adj.resize(n)
	angles.resize(n)
	var cos_max := cos(deg_to_rad(PENTE_MAX))
	var q := PhysicsRayQueryParameters3D.new()
	# corps du terrain (monde._terrain : le StaticBody3D enfant du monde qui porte le plus de maillages de collision)
	var terrain: StaticBody3D = null
	var nmax := 0
	for c in m.get_children():
		if c is StaticBody3D:
			var nf := 0
			for f in c.get_children():
				if f is CollisionShape3D and (f as CollisionShape3D).shape is ConcavePolygonShape3D:
					nf += 1
			if nf > nmax:
				nmax = nf
				terrain = c
	var sph := SphereShape3D.new()
	sph.radius = 0.3
	var oq := PhysicsShapeQueryParameters3D.new()
	oq.shape = sph
	oq.exclude = [terrain.get_rid()]
	for j in nz:
		for i in nx:
			var p := _xz(i, j)
			q.from = Vector3(p.x, 60.0, p.y)
			q.to = Vector3(p.x, -12.0, p.y)
			var r := esp.intersect_ray(q)
			var k := j * nx + i
			if r.is_empty():
				hs[k] = NAN
				debout[k] = 0
			else:
				hs[k] = (r.position as Vector3).y
				# la capsule du joueur (r 0,35) doit tenir là : sphère de 0,3 m aux genoux et à la poitrine, hors terrain
				for dy in [0.75, 1.45]:
					oq.transform = Transform3D(Basis(), Vector3(p.x, hs[k] + dy, p.y))
					if not esp.intersect_shape(oq, 1).is_empty():
						hs[k] = NAN
						break
				if is_nan(hs[k]):
					debout[k] = 0
					continue
				debout[k] = 1 if (r.normal as Vector3).y >= cos_max else 0
				angles[k] = rad_to_deg(acos(clampf((r.normal as Vector3).y, -1.0, 1.0)))
	# arêtes : obstacle testé une fois par paire (symétrique), sens selon les hauteurs
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = sph
	sq.exclude = [terrain.get_rid()]
	var n_cast := 0
	for j in nz:
		for i in nx:
			var a := j * nx + i
			if is_nan(hs[a]):
				continue
			for kv: int in [0, 2, 4, 6]:
				var v: Vector2i = VOIS[kv]
				var i2 := i + v.x
				var j2 := j + v.y
				if i2 < 0 or j2 < 0 or i2 >= nx or j2 >= nz:
					continue
				var b := j2 * nx + i2
				if is_nan(hs[b]):
					continue
				var ha := hs[a]
				var hb := hs[b]
				var diag := v.x != 0 and v.y != 0
				var montee := MONTEE * (1.4142 if diag else 1.0)
				var a_vers_b := hb <= ha + 0.02 or (debout[a] == 1 and debout[b] == 1 and hb - ha <= montee)
				var b_vers_a := ha <= hb + 0.02 or (debout[a] == 1 and debout[b] == 1 and ha - hb <= montee)
				if not a_vers_b and not b_vers_a:
					continue
				var pa := _xz(i, j)
				var pb := _xz(i2, j2)
				var base := maxf(ha, hb)
				var libre := true
				for dy in [0.75, 1.45]:
					sq.transform = Transform3D(Basis(), Vector3(pa.x, base + dy, pa.y))
					sq.motion = Vector3(pb.x - pa.x, 0.0, pb.y - pa.y)
					n_cast += 1
					var f := esp.cast_motion(sq)
					if f.is_empty() or f[0] < 1.0:
						libre = false
						break
				if not libre:
					continue
				var kinv: int = kv + 1   # VOIS[kv + 1] = −VOIS[kv]
				if a_vers_b:
					adj[a] |= 1 << kv
				if b_vers_a:
					adj[b] |= 1 << kinv
	# graines : bord de la boîte + place
	var graines: Array[int] = []
	for j in nz:
		for i in nx:
			if (i == 0 or j == 0 or i == nx - 1 or j == nz - 1) and not is_nan(hs[j * nx + i]):
				graines.append(j * nx + i)
	graines.append(_case(PLACE.x, PLACE.y))
	var avant := _parcours(graines, false)
	var arriere := _parcours(graines, true)
	print("Grille %d × %d (%.1f m), %d lancers de sphère, %d ms" % [nx, nz, PAS, n_cast, Time.get_ticks_msec() - t0])
	# poches
	var poche := PackedByteArray()
	poche.resize(n)
	var nb := 0
	for k in n:
		if avant[k] == 1 and arriere[k] == 0 and not is_nan(hs[k]):   # pentes trop raides comprises (on y glisse sans fin)
			poche[k] = 1
			nb += 1
	var vu := PackedByteArray()
	vu.resize(n)
	var graves := 0
	var amas: Array = []
	for k in n:
		if poche[k] == 0 or vu[k] == 1:
			continue
		var pile: Array[int] = [k]
		vu[k] = 1
		var cases: Array[int] = []
		while not pile.is_empty():
			var c: int = pile.pop_back()
			cases.append(c)
			var ci := c % nx
			var cj := c / nx
			for v: Vector2i in VOIS:
				var i2 := ci + v.x
				var j2 := cj + v.y
				if i2 < 0 or j2 < 0 or i2 >= nx or j2 >= nz:
					continue
				var d := j2 * nx + i2
				if poche[d] == 1 and vu[d] == 0:
					vu[d] = 1
					pile.append(d)
		var mn := Vector2(INF, INF)
		var mx := -mn
		var hmin := INF
		for c in cases:
			var p := _xz(c % nx, c / nx)
			mn = mn.min(p)
			mx = mx.max(p)
			hmin = minf(hmin, hs[c])
		amas.append([cases.size(), mn, mx, hmin])
		if cases.size() >= SEUIL_POCHE:
			graves += 1
	amas.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for e in amas:
		var tag := "POCHE" if int(e[0]) >= SEUIL_POCHE else "poche mineure"
		print("%s : %d cases (%.2f m²), x %.1f..%.1f z %.1f..%.1f, sol mini %.2f, palissade %.2f" % [tag, e[0], e[0] * PAS * PAS,
			e[1].x, e[2].x, e[1].y, e[2].y, e[3], ReliefVillage.distance_palissade((e[1].x + e[2].x) * 0.5, (e[1].y + e[2].y) * 0.5)])
		if OS.get_cmdline_user_args().has("--carte") and int(e[0]) >= SEUIL_POCHE:
			_carte(e[1], e[2], poche, avant, arriere)
	_verif(graves == 0, "poches fermées (≥ %d cases) dans la boîte du village : %d (cases piégées en tout : %d, amas : %d)" % [SEUIL_POCHE, graves, nb, amas.size()])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zone="):
			var v := a.substr(7).split_floats(",")
			print("ZONE : hauteur/pente° (B = rejoint les graines) ; lignes z décroissants")
			var z := v[3]
			while z >= v[1]:
				var s := "z%5.1f " % z
				var x := v[0]
				while x <= v[2]:
					var k := _case(x, z)
					s += " %5.2f/%2d%s" % [hs[k], int(angles[k]), "B" if arriere[k] == 1 else ("F" if avant[k] == 1 else "-")]
					x += PAS
				print(s)
				z -= PAS
	var kc := _case(COINCE.x, COINCE.z)
	var dmin := INF
	for dj in range(-2, 3):   # la case la plus proche où le joueur tient (celle du point exact touche un pieu)
		for di in range(-2, 3):
			var kk := _case(COINCE.x + di * PAS, COINCE.z + dj * PAS)
			var pk := _xz(kk % nx, kk / nx)
			var dd := pk.distance_to(Vector2(COINCE.x, COINCE.z))
			if not is_nan(hs[kk]) and dd < dmin:
				dmin = dd
				kc = kk
	_verif(arriere[kc] == 1, "case de la sauvegarde coincée (%.2f ; %.2f), case libre la plus proche %s : sol %.2f, pente %d°, rejoint le village sur la grille : %s" % [COINCE.x, COINCE.z, _xz(kc % nx, kc / nx), hs[kc], int(angles[kc]), arriere[kc] == 1])
	# vrai joueur depuis la position de l'utilisateur
	for c in root.find_children("*", "CharacterBody3D", true, false):
		if (c as Node).has_meta("couche"):
			(c as CollisionObject3D).collision_layer = (c as Node).get_meta("couche")
	await physics_frame
	var r: Dictionary = await _rejoindre([Vector2(18.6, 53.0), Vector2(24.0, 50.5), Vector2(34.0, 44.0), PLACE])
	_verif(r["ok"], "vrai joueur depuis (%.2f ; %.2f ; %.2f) : place du village atteinte %s en %.1f s, fin %s" % [COINCE.x, COINCE.y, COINCE.z, r["ok"], r["t"], r["p"]])
	print("ECHECS : %d" % _echecs)
	quit(_echecs)

## Parcours en largeur (arriere : arêtes inversées). Rend 1 par case atteinte.
func _parcours(graines: Array[int], arriere: bool) -> PackedByteArray:
	var vu := PackedByteArray()
	vu.resize(nx * nz)
	var file := PackedInt32Array()
	for g in graines:
		if vu[g] == 0:
			vu[g] = 1
			file.append(g)
	var t := 0
	while t < file.size():
		var c := file[t]
		t += 1
		var ci := c % nx
		var cj := c / nx
		for kv in 8:
			var v: Vector2i = VOIS[kv]
			var i2 := ci + v.x
			var j2 := cj + v.y
			if i2 < 0 or j2 < 0 or i2 >= nx or j2 >= nz:
				continue
			var d := j2 * nx + i2
			if vu[d] == 1:
				continue
			# avant : c → d si adj[c] a le bit kv ; arrière : d → c si adj[d] a le bit de (−v) = kv ^ 1
			var ok := (adj[d] & (1 << (kv ^ 1))) != 0 if arriere else (adj[c] & (1 << kv)) != 0
			if ok:
				vu[d] = 1
				file.append(d)
	return vu

func _carte(mn: Vector2, mx: Vector2, poche: PackedByteArray, avant: PackedByteArray, arriere: PackedByteArray) -> void:
	print("  carte (# poche, . libre, - inatteignable, ' ' rien) ; lignes z décroissants, colonnes x croissants depuis %.1f" % (mn.x - 3.0))
	var z := mx.y + 3.0
	while z >= mn.y - 3.0:
		var s := "  z%5.1f " % z
		var x := mn.x - 3.0
		while x <= mx.x + 3.0:
			var k := _case(x, z)
			if k < 0 or k >= nx * nz or is_nan(hs[k]):
				s += " "
			elif poche[k] == 1:
				s += "#"
			elif avant[k] == 1 and arriere[k] == 1:
				s += "."
			else:
				s += "-"
			x += PAS
		print(s)
		z -= PAS

## Le vrai joueur court de point en point (cap recalculé à chaque image, sauts réguliers).
func _rejoindre(points: Array) -> Dictionary:
	var j: CharacterBody3D = m.joueur
	j.set_physics_process(true)
	j.global_position = COINCE + Vector3(0, 0.05, 0)
	j.velocity = Vector3.ZERO
	for i in 5:
		await physics_frame
	Input.action_press("avant")
	Input.action_press("course")
	var t := 0.0
	var idx := 0
	var f := 0
	while t < 30.0 and idx < points.size():
		var p := j.global_position
		var cible: Vector2 = points[idx]
		var d := cible - Vector2(p.x, p.z)
		if d.length() < 1.2:
			idx += 1
			continue
		j.rotation.y = atan2(-d.x, -d.y)   # avant = −Z du joueur
		f += 1
		if f % 45 == 30:
			Input.action_press("saut")
		elif f % 45 == 31:
			Input.action_release("saut")
		j.set("vigueur", 1000.0)
		await physics_frame
		t += 1.0 / 60.0
	Input.action_release("avant")
	Input.action_release("course")
	Input.action_release("saut")
	return {"ok": idx >= points.size(), "t": t, "p": j.global_position}
