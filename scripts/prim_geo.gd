class_name PrimGeo
extends RefCounted
## Boîte et cylindre en tableaux de maillage, calculés à la main : même disposition, mêmes UV que `BoxMesh` / `CylinderMesh` du
## moteur (vérifié par outils/test_primitives.gd). Aucune ressource de rendu n'est créée : sans danger dans un fil (la création
## de `PrimitiveMesh` en fil concurrent donnait « Attempting to initialize the wrong RID ») et plus rapide.
## Sortie : tableau `Mesh.ARRAY_MAX` (sommets, normales, UV, indices ; pas de tangentes) comme `get_mesh_arrays()`.

static func _tableau(v: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array) -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = n
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_INDEX] = idx
	return a

## Boîte centrée (sans subdivision) : avant/arrière, droite/gauche, haut/bas, UV en 3 × 2 comme le moteur.
static func boite(taille: Vector3) -> Array:
	var h := taille * 0.5
	var t1 := 1.0 / 3.0
	var t2 := 2.0 / 3.0
	# (signe x, signe y, signe z, u, v) par sommet, dans l'ordre du moteur (24 sommets)
	var p := [
		[-1, 1, 1, 0.0, 0.0], [1, 1, -1, t2, 0.0], [1, 1, 1, t1, 0.0], [-1, 1, -1, 1.0, 0.0],
		[-1, -1, 1, 0.0, 0.5], [1, -1, -1, t2, 0.5], [1, -1, 1, t1, 0.5], [-1, -1, -1, 1.0, 0.5],
		[1, 1, 1, t1, 0.0], [-1, 1, -1, 0.0, 0.5], [1, 1, -1, t2, 0.0], [-1, 1, 1, t1, 0.5],
		[1, -1, 1, t1, 0.5], [-1, -1, -1, 0.0, 1.0], [1, -1, -1, t2, 0.5], [-1, -1, 1, t1, 1.0],
		[1, 1, 1, t1, 0.5], [-1, -1, 1, t2, 0.5], [-1, 1, 1, t2, 0.5], [1, -1, 1, 1.0, 0.5],
		[1, 1, -1, t1, 1.0], [-1, -1, -1, t2, 1.0], [-1, 1, -1, t2, 1.0], [1, -1, -1, 1.0, 1.0],
	]
	var nrm := [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0)]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	v.resize(24)
	n.resize(24)
	uv.resize(24)
	for i in 24:
		var e: Array = p[i]
		v[i] = Vector3(e[0] * h.x, e[1] * h.y, e[2] * h.z)
		uv[i] = Vector2(e[3], e[4])
	# normales : avant/arrière (0-7) alternées, droite/gauche (8-15), haut/bas (16-23)
	for i in 8:
		n[i] = nrm[i % 2]
		n[8 + i] = nrm[2 + i % 2]
		n[16 + i] = nrm[4 + i % 2]
	var idx := PackedInt32Array([
		0, 2, 4, 2, 6, 4, 1, 3, 5, 3, 7, 5, 8, 10, 12, 10, 14, 12, 9, 11, 13, 11, 15, 13,
		16, 18, 20, 18, 22, 20, 17, 19, 21, 19, 23, 21])
	return _tableau(v, n, uv, idx)

## Cylindre (ou tronc de cône) centré, `cotes` pans, 1 anneau (2 rangées de faces), capuchons si le rayon est > 0.
static func cylindre(r_haut: float, r_bas: float, h: float, cotes: int) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var pente := (r_bas - r_haut) / h
	var point := 0
	var prev := 0
	var cur := 0
	for j in 3:
		var vv := j / 2.0
		var rayon := r_haut + (r_bas - r_haut) * vv
		var y := h * 0.5 - h * vv
		for i in cotes + 1:
			var u := float(i) / cotes
			var x := sin(u * TAU)
			var z := cos(u * TAU)
			v.append(Vector3(x * rayon, y, z * rayon))
			n.append(Vector3(x, pente, z).normalized())
			uv.append(Vector2(u, vv * 0.5))
			point += 1
			if i > 0 and j > 0:
				idx.append_array([prev + i - 1, prev + i, cur + i - 1, prev + i, cur + i, cur + i - 1])
		prev = cur
		cur = point
	if r_haut > 0.0:
		var y := h * 0.5
		cur = point
		v.append(Vector3(0, y, 0))
		n.append(Vector3.UP)
		uv.append(Vector2(0.25, 0.75))
		point += 1
		for i in cotes + 1:
			var r := float(i) / cotes
			var x := sin(r * TAU)
			var z := cos(r * TAU)
			v.append(Vector3(x * r_haut, y, z * r_haut))
			n.append(Vector3.UP)
			uv.append(Vector2((x + 1.0) * 0.25, 0.5 + (z + 1.0) * 0.25))
			point += 1
			if i > 0:
				idx.append_array([cur, point - 1, point - 2])
	if r_bas > 0.0:
		var y := h * -0.5
		cur = point
		v.append(Vector3(0, y, 0))
		n.append(Vector3.DOWN)
		uv.append(Vector2(0.75, 0.75))
		point += 1
		for i in cotes + 1:
			var r := float(i) / cotes
			var x := sin(r * TAU)
			var z := cos(r * TAU)
			v.append(Vector3(x * r_bas, y, z * r_bas))
			n.append(Vector3.DOWN)
			uv.append(Vector2(0.5 + (x + 1.0) * 0.25, 0.5 + (1.0 - z) * 0.25))
			point += 1
			if i > 0:
				idx.append_array([cur, point - 2, point - 1])
	return _tableau(v, n, uv, idx)

## Plan (comme `QuadMesh` : face +Z, `decalage` = center_offset), 4 sommets, 2 triangles.
static func plan(taille: Vector2, decalage := Vector3.ZERO) -> Array:
	var hx := taille.x * 0.5
	var hy := taille.y * 0.5
	var v := PackedVector3Array([Vector3(hx, -hy, 0) + decalage, Vector3(-hx, -hy, 0) + decalage, Vector3(hx, hy, 0) + decalage, Vector3(-hx, hy, 0) + decalage])
	var n := PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var uv := PackedVector2Array([Vector2(1, 1), Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)])
	return _tableau(v, n, uv, PackedInt32Array([0, 1, 2, 1, 3, 2]))

## ArrayMesh d'un tableau de ce fichier (création de ressource : ni plus ni moins sûre qu'un `add_surface_from_arrays`).
static func maillage(arrays: Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
