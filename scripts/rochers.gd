class_name Rochers
## Rochers dispersés dans la forêt (4 formes, MultiMesh + colliders convexes).
## Les exclusions (`continue`) sont AVANT les tirages d'échelle/rotation : ne pas en ajouter
## ici sans filtrer a posteriori, sinon l'ordre du RNG `monde.rng` change.

const NB_ROCHERS := 160

static func creer(monde: Node) -> void:
	var rng: RandomNumberGenerator = monde.rng
	var village: Vector3 = monde.VILLAGE
	var clairiere: float = monde.RAYON_CLAIRIERE
	var m := Palette.materiau(monde.tex_roche)
	var modeles: Array[ArrayMesh] = []
	for g in 4:
		var mesh := rocher_mesh(40 + g)
		mesh.surface_set_material(0, m)
		modeles.append(mesh)
	var parts: Array[Array] = [[], [], [], []]
	for i in NB_ROCHERS:
		var x := rng.randf_range(-112.0, 112.0)
		var z := rng.randf_range(-112.0, 112.0)
		if Vector2(x, z).length() < clairiere or Vector2(x - village.x, z - village.z).length() < 28.0 or monde._pres_du_chemin(x, z, 2.0):
			continue
		var s := rng.randf_range(0.4, 2.2) * (2.0 if rng.randf() < 0.12 else 1.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.8, 1.2)))
		parts[i % 4].append(Transform3D(b, Vector3(x, monde.hauteur(x, z) - s * 0.25, z)))
	var corps := StaticBody3D.new()
	for g in 4:
		var forme_modele := modeles[g].create_convex_shape()
		for t: Transform3D in parts[g]:
			var forme := CollisionShape3D.new()
			forme.shape = forme_modele
			forme.transform = t
			corps.add_child(forme)
		Instanciation.repartir(monde, modeles[g], parts[g])
	monde.add_child(corps)

static func rocher_mesh(graine: int) -> ArrayMesh:
	var n := FastNoiseLite.new()
	n.seed = graine
	n.frequency = 1.4
	var sphere := SphereMesh.new()
	sphere.radial_segments = 7
	sphere.rings = 4
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in verts.size():
		var v := verts[i]
		verts[i] = v * (1.0 + n.get_noise_3dv(v * 2.0) * 0.45)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, index.size(), 3):
		var a := verts[index[t]]
		var b := verts[index[t + 1]]
		var c := verts[index[t + 2]]
		var normale := (c - a).cross(b - a).normalized()
		# neige sur les faces tournées vers le ciel
		var col := Color(1, 1, 1, 0.0 if normale.y > 0.55 else 1.0)
		for k in 3:
			st.set_color(col)
			st.set_uv(uvs[index[t + k]] * 2.0)
			st.add_vertex(verts[index[t + k]])
	st.generate_normals()
	return st.commit()
