class_name Doigts
## [pnj/realisme_v1, passe 2] Doigts lisibles sur la peau des PNJ maison (les mains faisaient « moufles » : une seule tache de peau).
## Les sommets de la main pesés sur PLUSIEURS os de doigt sont ceux des creux entre les doigts et des plis des phalanges : ils sont
## repérés sur le maillage de peau (poids, pose de repos), puis leurs triangles sont assombris dans l'atlas (VisagePnj.doigts).

## Triangles de la main : [uv0, uv1, uv2, d0, d1, d2] (d = part de poids hors de l'os principal, 0 = au milieu d'une phalange).
static func traits(mi: MeshInstance3D, s: int) -> Array:
	var res: Array = []
	if mi == null or mi.mesh == null or s >= mi.mesh.get_surface_count():
		return res
	var sq := mi.get_parent() as Skeleton3D
	if sq == null:
		return res
	var a := mi.mesh.surface_get_arrays(s)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var bo: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	if bo.is_empty() or uv.size() != v.size():
		return res
	var nb := bo.size() / v.size()
	var main := {}
	var skin := mi.skin
	for bi in (skin.get_bind_count() if skin != null else sq.get_bone_count()):
		var os_ := os_de(sq, skin, bi)
		var nom := sq.get_bone_name(os_) if os_ >= 0 else ""
		main[bi] = nom.begins_with("hand") or nom.begins_with("index") or nom.begins_with("middle") or nom.begins_with("ring") \
			or nom.begins_with("pinky") or nom.begins_with("thumb")
	var d := PackedFloat32Array()
	d.resize(v.size())
	var dans := PackedByteArray()
	dans.resize(v.size())
	for k in v.size():
		var tot := 0.0
		var mx := 0.0
		for j in nb:
			var bi := bo[k * nb + j]
			var ww := w[k * nb + j]
			if ww > 0.0 and main.get(bi, false):
				tot += ww
				mx = maxf(mx, ww)
		dans[k] = 1 if tot > 0.6 else 0
		d[k] = (1.0 - mx / tot) if tot > 0.0 else 0.0
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		idx.resize(v.size())
		for i in v.size():
			idx[i] = i
	for t in range(0, idx.size(), 3):
		var i0 := idx[t]
		var i1 := idx[t + 1]
		var i2 := idx[t + 2]
		if dans[i0] == 0 or dans[i1] == 0 or dans[i2] == 0:
			continue
		if maxf(d[i0], maxf(d[i1], d[i2])) < 0.12:
			continue
		res.append([uv[i0], uv[i1], uv[i2], d[i0], d[i1], d[i2]])
	return res

## Os du squelette d'un indice de liaison de la peau (liaison par indice ou par NOM, selon l'import).
static func os_de(sq: Skeleton3D, skin: Skin, bi: int) -> int:
	if skin == null or bi >= skin.get_bind_count():
		return bi
	var b := skin.get_bind_bone(bi)
	if b < 0:
		b = sq.find_bone(skin.get_bind_name(bi))
	return b
