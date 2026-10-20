class_name BatiGeo
## Lot 5, 2e passe : géométrie « profondeur » du bâti (budget de sommets PS1) : rondins à 8 pans, blocs de
## pierre chanfreinés et irréguliers, pierres levées taillées, dalles de toit à épaisseur. Tout est en
## triangles à normales plates (facettes franches), couleur de sommet = occlusion ambiante peinte, alpha 0 =
## neige (voir shader `ps1_bati`). Les UV des rondins sont en MÈTRES (u le long du fût, v autour).

## Liste de triangles prête à fusionner (village.gd `_ajouter`) ou à convertir en ArrayMesh.
class Maillage:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	## Triangle orienté vers l'extérieur de `centre` (normale plate).
	func tri(a: Vector3, b: Vector3, d: Vector3, ca: Color, cb: Color, cd: Color, centre: Vector3, ua := Vector2.ZERO, ub := Vector2.ZERO, ud := Vector2.ZERO) -> void:
		var nn := (d - a).cross(b - a)
		if nn.length_squared() < 1e-10:
			return
		nn = nn.normalized()
		var cg := (a + b + d) / 3.0
		if nn.dot(cg - centre) < 0.0:
			# on inverse l'ordre : la normale sortante est (d-a)×(b-a) pour l'ordre (a,b,d)
			var t := b
			b = d
			d = t
			var tc := cb
			cb = cd
			cd = tc
			var tu := ub
			ub = ud
			ud = tu
			nn = -nn
		for k in [[a, ca, ua], [b, cb, ub], [d, cd, ud]]:
			v.append(k[0])
			n.append(nn)
			c.append(k[1])
			uv.append(k[2])
	func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, ca: Color, cb: Color, cd: Color, ce: Color, centre: Vector3) -> void:
		tri(a, b, d, ca, cb, cd, centre)
		tri(a, d, e, ca, cd, ce, centre)
	func arrays() -> Array:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_TEX_UV] = uv
		a[Mesh.ARRAY_COLOR] = c
		return a
	func mesh() -> ArrayMesh:
		var m := ArrayMesh.new()
		if v.size() > 0:
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays())
		return m

static func _h3(x: int, y: int, z: int, g: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (g * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0

# --- blocs de pierre ----------------------------------------------------------------------------------------

## Bloc chanfreiné et irrégulier (24 points : 3 par coin), centré sur l'origine. `neige` = probabilité d'un
## dessus enneigé ; `bas` = teinte au pied (occlusion). Facettes plates.
static func bloc(taille: Vector3, graine: int, chanfrein := 0.22, jitter := 0.07, neige := 0.0, bas := 0.62) -> Maillage:
	var m := Maillage.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var h := taille * 0.5
	var ch := chanfrein * minf(h.x, minf(h.y, h.z)) * 2.0
	var j := taille * jitter
	var pts := {}   # clé (sx,sy,sz,face) -> Vector3
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				for f in 3:
					var p: Vector3
					match f:
						0: p = Vector3(sx * h.x, sy * (h.y - ch), sz * (h.z - ch))
						1: p = Vector3(sx * (h.x - ch), sy * h.y, sz * (h.z - ch))
						_: p = Vector3(sx * (h.x - ch), sy * (h.y - ch), sz * h.z)
					p += Vector3(_h3(sx, sy, sz * 3 + f, graine) - 0.5, _h3(sx + 5, sy, sz + f, graine + 1) - 0.5, _h3(sx, sy + 7, sz + f * 2, graine + 2) - 0.5) * 2.0 * j
					pts[Vector3i(sx, sy, sz * 4 + f)] = p
	var teinte := rng.randf_range(0.9, 1.06)
	var enneige := rng.randf() < neige
	var col := func(p: Vector3, haut: bool) -> Color:
		var k := teinte * lerpf(bas, 1.0, clampf((p.y + h.y) / (2.0 * h.y), 0.0, 1.0))
		return Color(k, k, k, 0.0 if (haut and enneige) else 1.0)
	var P := func(sx: int, sy: int, sz: int, f: int) -> Vector3:
		return pts[Vector3i(sx, sy, sz * 4 + f)]
	# 6 faces
	for sgn in [-1, 1]:
		# X
		var q: Array = [P.call(sgn, -1, -1, 0), P.call(sgn, 1, -1, 0), P.call(sgn, 1, 1, 0), P.call(sgn, -1, 1, 0)]
		m.quad(q[0], q[1], q[2], q[3], col.call(q[0], false), col.call(q[1], false), col.call(q[2], false), col.call(q[3], false), Vector3.ZERO)
		# Y
		q = [P.call(-1, sgn, -1, 1), P.call(1, sgn, -1, 1), P.call(1, sgn, 1, 1), P.call(-1, sgn, 1, 1)]
		var haut: bool = sgn > 0
		m.quad(q[0], q[1], q[2], q[3], col.call(q[0], haut), col.call(q[1], haut), col.call(q[2], haut), col.call(q[3], haut), Vector3.ZERO)
		# Z
		q = [P.call(-1, -1, sgn, 2), P.call(1, -1, sgn, 2), P.call(1, 1, sgn, 2), P.call(-1, 1, sgn, 2)]
		m.quad(q[0], q[1], q[2], q[3], col.call(q[0], false), col.call(q[1], false), col.call(q[2], false), col.call(q[3], false), Vector3.ZERO)
	# 12 biseaux d'arête
	for s1 in [-1, 1]:
		for s2 in [-1, 1]:
			# arête XY (sx=s1, sy=s2), sz varie
			var a1: Vector3 = P.call(s1, s2, -1, 0)
			var a2: Vector3 = P.call(s1, s2, 1, 0)
			var b1: Vector3 = P.call(s1, s2, -1, 1)
			var b2: Vector3 = P.call(s1, s2, 1, 1)
			var hh: bool = s2 > 0
			m.quad(a1, a2, b2, b1, col.call(a1, false), col.call(a2, false), col.call(b2, hh), col.call(b1, hh), Vector3.ZERO)
			# arête XZ (sx=s1, sz=s2), sy varie
			a1 = P.call(s1, -1, s2, 0)
			a2 = P.call(s1, 1, s2, 0)
			b1 = P.call(s1, -1, s2, 2)
			b2 = P.call(s1, 1, s2, 2)
			m.quad(a1, a2, b2, b1, col.call(a1, false), col.call(a2, false), col.call(b2, false), col.call(b1, false), Vector3.ZERO)
			# arête YZ (sy=s1, sz=s2), sx varie
			a1 = P.call(-1, s1, s2, 1)
			a2 = P.call(1, s1, s2, 1)
			b1 = P.call(-1, s1, s2, 2)
			b2 = P.call(1, s1, s2, 2)
			var hy: bool = s1 > 0
			m.quad(a1, a2, b2, b1, col.call(a1, hy), col.call(a2, hy), col.call(b2, false), col.call(b1, false), Vector3.ZERO)
	# 8 coins
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var a: Vector3 = P.call(sx, sy, sz, 0)
				var b: Vector3 = P.call(sx, sy, sz, 1)
				var d: Vector3 = P.call(sx, sy, sz, 2)
				m.tri(a, b, d, col.call(a, false), col.call(b, sy > 0), col.call(d, false), Vector3.ZERO)
	return m

# --- pierre levée --------------------------------------------------------------------------------------------

## Pierre levée taillée : 7 anneaux de 8 sommets (section rectangulaire arrondie, irrégulière), fût qui s'effile et
## se penche, renflements, sommet en pointe asymétrique ; facettes plates. `plat` : faces ±Z planes (stèle gravée :
## les runes sont des quads plaqués). Centrée sur l'origine, boîte englobante ≈ `taille`. Neige sur les facettes
## tournées vers le haut (alpha 0).
static func pierre_levee(taille: Vector3, graine: int, plat := false) -> Maillage:
	var m := Maillage.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var R := 7
	var S := 8
	var h := taille * 0.5
	var lean := rng.randf_range(-0.05, 0.05) * taille.y
	var anneaux: Array = []   # Array de PackedVector3Array
	var phase := rng.randf() * 0.2
	for r in R:
		var t := float(r) / (R - 1)
		var y := -h.y + taille.y * 0.86 * t
		var ty := t * t
		var hx := h.x * (1.0 - 0.2 * ty) * (1.0 + (rng.randf() - 0.5) * 0.1)
		var hz := h.z * (1.0 - (0.0 if plat else 0.15) * ty) * (1.0 + (0.0 if plat else (rng.randf() - 0.5) * 0.1))
		var cx := lean * t + (rng.randf() - 0.5) * 0.03 * taille.x
		var ring := PackedVector3Array()
		for k in S:
			var a := TAU * k / S + PI / S + phase
			var cs := cos(a)
			var sn := sin(a)
			# section en rectangle arrondi (superellipse d'exposant 4)
			var ex := signf(cs) * pow(absf(cs), 0.5)
			var ez := signf(sn) * pow(absf(sn), 0.5)
			var jx := 1.0 + (rng.randf() - 0.5) * 0.14
			var jz := 1.0 + (0.0 if plat else (rng.randf() - 0.5) * 0.14)
			if plat:
				jz = 1.0 - rng.randf() * 0.02
			ring.append(Vector3(cx + ex * hx * jx * 1.05, y, ez * hz * jz * 1.05))
		anneaux.append(ring)
	# sommet : pointe asymétrique au-dessus du dernier anneau
	var dernier: PackedVector3Array = anneaux[R - 1]
	var ctr := Vector3(lean + rng.randf_range(-0.6, 0.6) * h.x, -h.y + taille.y * 0.86 + taille.y * rng.randf_range(0.05, 0.12), rng.randf_range(-0.3, 0.3) * h.z)
	var base_c := Vector3(lean * 0.0, -h.y, 0)
	var col := func(p: Vector3, up: bool) -> Color:
		var k := lerpf(0.55, 1.0, clampf((p.y + h.y) / (taille.y * 0.5), 0.0, 1.0)) * (0.93 + 0.07 * sin(p.y * 3.0))
		return Color(k, k, k, 0.0 if up else 1.0)
	var centre := Vector3(lean * 0.5, 0, 0)
	for r in R - 1:
		var a: PackedVector3Array = anneaux[r]
		var b: PackedVector3Array = anneaux[r + 1]
		for k in S:
			var k2 := (k + 1) % S
			var haut := false
			m.tri(a[k], a[k2], b[k2], col.call(a[k], haut), col.call(a[k2], haut), col.call(b[k2], haut), centre)
			m.tri(a[k], b[k2], b[k], col.call(a[k], haut), col.call(b[k2], haut), col.call(b[k], haut), centre)
	for k in S:
		var k2 := (k + 1) % S
		var up := true
		m.tri(dernier[k], dernier[k2], ctr, col.call(dernier[k], up), col.call(dernier[k2], up), col.call(ctr, up), centre)
	# la pente d'un fût qui s'effile ne regarde jamais vers le haut : la neige se pose sur la pointe seulement
	var bas: PackedVector3Array = anneaux[0]
	for k in S:
		var k2 := (k + 1) % S
		m.tri(bas[k], bas[k2], base_c, col.call(bas[k], false), col.call(bas[k2], false), col.call(base_c, false), centre)
	return m

# --- rondins ---------------------------------------------------------------------------------------------------

## Rondin à 8 pans le long de +X (centré), `sag` = affaissement au milieu, rayon (apothème) `r`. Renvoie
## [fût, bouts] (deux Maillage : matières « rondins » et « bout_rondin »). `strate` 0..3 = bande de texture,
## `u0` = décalage de texture (m). `teinte` : tableau (k de 0..1) multiplié aux couleurs de sommet.
static func rondin(longueur: float, r: float, graine: int, sag := 0.02, strate := 0, u0 := 0.0, teinte := 1.0) -> Array:
	var fut := Maillage.new()
	var bouts := Maillage.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var stations := maxi(2, ceili(longueur / 2.2) + 1)
	var R := r / cos(PI / 8.0)
	var anneaux: Array = []
	for s in stations:
		var t := float(s) / (stations - 1)
		var x := -longueur * 0.5 + longueur * t
		var dy := -sag * 4.0 * t * (1.0 - t) + (rng.randf() - 0.5) * 0.012
		var dz := (rng.randf() - 0.5) * 0.015
		var rad := R * (1.0 + (rng.randf() - 0.5) * 0.07)
		var ring := PackedVector3Array()
		for k in 8:
			var a := PI / 8.0 + TAU * k / 8.0
			var jr := 1.0 + (rng.randf() - 0.5) * 0.05
			ring.append(Vector3(x, dy + sin(a) * rad * jr, dz + cos(a) * rad * jr))
		anneaux.append(ring)
	for s in stations - 1:
		var a: PackedVector3Array = anneaux[s]
		var b: PackedVector3Array = anneaux[s + 1]
		var cen_a := Vector3(a[0].x, (a[0].y + a[4].y) * 0.5, (a[0].z + a[4].z) * 0.5)
		for k in 8:
			var k2 := (k + 1) % 8
			var ang := PI / 8.0 + TAU * (k + 0.5) / 8.0
			var ny := sin(ang)
			# occlusion peinte : le dessous et le dessus du rondin se creusent contre ses voisins
			var ao := 0.62 if ny < -0.5 else (0.84 if ny < -0.2 else (0.9 if ny > 0.5 else 1.0))
			ao *= teinte
			var c := Color(ao, ao, ao, 1.0)
			var v0 := strate * 1.0 + 0.93 * k / 8.0
			var v1 := strate * 1.0 + 0.93 * (k + 1) / 8.0
			var ua := u0 + a[k].x + longueur * 0.5
			var ub := u0 + b[k].x + longueur * 0.5
			fut.tri(a[k], b[k], b[k2], c, c, c, cen_a, Vector2(ua, v0), Vector2(ub, v0), Vector2(ub, v1))
			fut.tri(a[k], b[k2], a[k2], c, c, c, cen_a, Vector2(ua, v0), Vector2(ub, v1), Vector2(ua, v1))
	# bouts : éventail de 8 triangles, UV en mètres (texture 64 texels/m, tuile de 0,5 m : cernes centrés)
	for fin in [0, stations - 1]:
		var a: PackedVector3Array = anneaux[fin]
		var ctr := Vector3(a[0].x, (a[0].y + a[4].y) * 0.5, (a[0].z + a[4].z) * 0.5)
		var dehors := Vector3(-1.0 if fin == 0 else 1.0, 0, 0)
		var cc := Color(0.92, 0.92, 0.92, 1.0)
		for k in 8:
			var k2 := (k + 1) % 8
			var uc := Vector2(0.25, 0.25)
			var u1 := Vector2(0.25 + a[k].z - ctr.z, 0.25 + a[k].y - ctr.y)
			var u2 := Vector2(0.25 + a[k2].z - ctr.z, 0.25 + a[k2].y - ctr.y)
			bouts.tri(a[k], a[k2], ctr, cc, cc, cc, ctr - dehors, u1, u2, uc)
	# les triangles du fût sont orientés par rapport à l'axe : recalage ci-dessous
	return [_orienter_fut(fut, anneaux), bouts]

## Réoriente chaque triangle du fût vers l'extérieur de l'axe du rondin (le centre de référence est l'axe local).
static func _orienter_fut(fut: Maillage, anneaux: Array) -> Maillage:
	var o := Maillage.new()
	for i in range(0, fut.v.size(), 3):
		var cg := (fut.v[i] + fut.v[i + 1] + fut.v[i + 2]) / 3.0
		var axe := Vector3(cg.x, 0.0, 0.0)
		# l'axe passe par le centre moyen des anneaux (y ≈ 0 ± affaissement) : on utilise l'anneau le plus proche
		var best := 0
		var bd := 1e9
		for s in anneaux.size():
			var d := absf((anneaux[s] as PackedVector3Array)[0].x - cg.x)
			if d < bd:
				bd = d
				best = s
		var a: PackedVector3Array = anneaux[best]
		axe = Vector3(cg.x, (a[0].y + a[4].y) * 0.5, (a[0].z + a[4].z) * 0.5)
		o.tri(fut.v[i], fut.v[i + 1], fut.v[i + 2], fut.c[i], fut.c[i + 1], fut.c[i + 2], axe, fut.uv[i], fut.uv[i + 1], fut.uv[i + 2])
	return o

# --- dalle de toit à épaisseur ---------------------------------------------------------------------------------

## Pan de toit en neige : repère local = (x le long du faîte, y normale du pan vers le haut, z le long de la pente
## depuis le faîte). Épaisseur ~ 18-26 cm, dessus bosselé (neige soufflée), faîte qui ondule et qui s'affaisse,
## lèvre d'égout et rives à bord irrégulier (neige puis tourbe sombre, alpha de sommet 1). `Lx` longueur, `Sl`
## longueur de pente. Normales lissées (SurfaceTool) : la neige est molle.
static func dalle_neige(Lx: float, Sl: float, graine: int, epaisseur := 0.22, ondule := 0.05, trou := Vector2.ZERO) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var nx := maxi(4, ceili(Lx / 0.9))
	var ns := 5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var sag := rng.randf_range(0.03, 0.07)
	var neige := Color(1, 1, 1, 0.0)
	var terre := Color(0.55, 0.52, 0.5, 1.0)
	var haut := func(x: float, s: float) -> Vector3:
		var tx := x / Lx + 0.5
		var ts := s / Sl
		var y := epaisseur * 0.5 + epaisseur * 0.5 * ts * ts
		y += (sin(x * 1.3 + s * 0.8 + p1) * 0.5 + sin(x * 2.9 - s * 1.7 + p2) * 0.3) * 0.03
		y += ondule * sin(x * 0.8 + p1) * (1.0 - ts) - sag * 4.0 * tx * (1.0 - tx) * (1.0 - ts * 0.5)
		return Vector3(x, y, s)
	var grid: Array = []
	for i in nx + 1:
		var x := -Lx * 0.5 + Lx * i / nx
		var col: Array = []
		for j in ns + 1:
			col.append(haut.call(x, Sl * j / ns))
		grid.append(col)
	for i in nx:
		for j in ns:
			# trou à fumée (lot intérieurs) : les cases du premier rang (au faîte) dont le centre est dans [trou.x, trou.y] manquent
			if trou != Vector2.ZERO and j == 0:
				var xc := -Lx * 0.5 + Lx * (i + 0.5) / nx
				if xc > trou.x and xc < trou.y:
					continue
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i + 1][j]
			var c: Vector3 = grid[i + 1][j + 1]
			var d: Vector3 = grid[i][j + 1]
			for tri_ in [[a, b, d], [b, c, d]]:
				for p: Vector3 in tri_:
					st.set_color(neige)
					st.add_vertex(p)
	# lèvre d'égout : glisse vers l'avant et pend de longueurs irrégulières, tourbe dessous
	var prec_mid := Vector3.ZERO
	var prec_bas := Vector3.ZERO
	var prec_top := Vector3.ZERO
	var drop_prec := 0.0
	for i in nx + 1:
		var top: Vector3 = grid[i][ns]
		var drop := rng.randf_range(0.09, 0.3)
		var mid := top + Vector3(0, -top.y * 0.1 - 0.06, 0.07)
		var bas := Vector3(top.x, top.y - epaisseur * 0.75 - drop * 0.5, top.z + 0.03 + rng.randf() * 0.04)
		if i > 0:
			# haut de lèvre (neige) puis bande de tourbe
			for tri_ in [[prec_top, top, prec_mid], [top, mid, prec_mid]]:
				for p: Vector3 in tri_:
					st.set_color(neige)
					st.add_vertex(p)
			for tri_ in [[prec_mid, mid, prec_bas], [mid, bas, prec_bas]]:
				for k in 3:
					var p: Vector3 = tri_[k]
					st.set_color(neige if k == 0 or (tri_[0] == prec_mid and k < 2) else terre)
					st.add_vertex(p)
		prec_top = top
		prec_mid = mid
		prec_bas = bas
		drop_prec = drop
	# rives (bords en x) : bande verticale qui pend
	for cote in [-1, 1]:
		var pt := Vector3.ZERO
		var pb := Vector3.ZERO
		for j in ns + 1:
			var top: Vector3 = grid[0 if cote < 0 else nx][j]
			var bas := Vector3(top.x + 0.04 * cote, top.y - epaisseur * 0.7 - rng.randf_range(0.0, 0.14), top.z)
			if j > 0:
				var q := [pt, top, pb, bas]
				var tris := [[pt, pb, top], [top, pb, bas]] if cote < 0 else [[pt, top, pb], [top, bas, pb]]
				for tri_ in tris:
					for p: Vector3 in tri_:
						st.set_color(neige if p.y > (top.y - epaisseur * 0.45) else terre)
						st.add_vertex(p)
			pt = top
			pb = bas
	st.generate_normals()
	return st.commit()

## Intervalle [x0, x1] de `nb` cases de dalle (voir `dalle_neige`) le plus proche de `centre_x` : les bords du trou à fumée
## tombent exactement sur les arêtes de la grille de la dalle.
static func trou_cases(Lx: float, centre_x: float, nb: int) -> Vector2:
	var nx := maxi(4, ceili(Lx / 0.9))
	var dx := Lx / nx
	var i0 := roundi((centre_x + Lx * 0.5) / dx - nb * 0.5)
	var x0 := -Lx * 0.5 + i0 * dx
	return Vector2(x0, x0 + nb * dx)
