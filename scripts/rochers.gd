class_name Rochers
## Rochers dispersés dans la forêt (4 formes, MultiMesh + colliders convexes).
## Les exclusions (`continue`) sont AVANT les tirages d'échelle/rotation : ne pas en ajouter
## ici sans filtrer a posteriori, sinon l'ordre du RNG `monde.rng` change.
## Lot B : exclusions de la zone témoin filtrées APRÈS les tirages ; colliders convexes par
## instance, points du modèle déjà transformés (jamais d'échelle sur un CollisionShape3D).

const NB_ROCHERS := 160
const COLLISION_MIN := 0.6      # en dessous de cette échelle : pas de collision (rochers enfouis)
const R_CERCLE := 11.0          # zone : pas de rocher à moins de 11 m du centre du cercle
const CENTRE_CERCLE := Vector2(-38.0, -34.0)
const ELLIPSE_TUMULUS := Vector2(-38.0, -54.5)  # centre ; rayons 10 (x) × 12 (z)
const RAYON_ELLIPSE := Vector2(10.0, 12.0)
const MARGE_CHEMIN := 2.5

## Vrai si la zone témoin interdit un rocher en (x, z) (toujours faux hors zone).
static func exclu_zone(monde: Node, x: float, z: float) -> bool:
	if ZoneBiome.masque(x, z) <= 0.0:
		return false
	if Vector2(x, z).distance_to(CENTRE_CERCLE) < R_CERCLE:
		return true
	var e := Vector2((x - ELLIPSE_TUMULUS.x) / RAYON_ELLIPSE.x, (z - ELLIPSE_TUMULUS.y) / RAYON_ELLIPSE.y)
	if e.length_squared() < 1.0:
		return true
	for o in ZoneBiome.OCCUPATIONS:
		if Vector2(x, z).distance_to(o[0]) < o[1]:
			return true
	return monde.chemins != null and monde.chemins.distance(x, z) < MARGE_CHEMIN

static func creer(monde: Node) -> void:
	var rng: RandomNumberGenerator = monde.rng
	var village: Vector3 = monde.VILLAGE
	var clairiere: float = monde.RAYON_CLAIRIERE
	var m := TexturesBati.m_roche()   # lot 5 : roche feuilletée, 16 texels/m, mipmaps nearest
	var modeles: Array[ArrayMesh] = []
	for g in 4:
		var mesh := rocher_mesh(40 + g)
		mesh.surface_set_material(0, m)
		modeles.append(mesh)
	var parts: Array[Array] = [[], [], [], []]
	var echelles: Array[Array] = [[], [], [], []]
	for i in NB_ROCHERS:
		var x := rng.randf_range(-112.0, 112.0)
		var z := rng.randf_range(-112.0, 112.0)
		if Vector2(x, z).length() < clairiere or Vector2(x - village.x, z - village.z).length() < 28.0 or monde._pres_du_chemin(x, z, 2.0):
			continue
		var s := rng.randf_range(0.4, 2.2) * (2.0 if rng.randf() < 0.12 else 1.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.8, 1.2)))
		if exclu_zone(monde, x, z):
			continue  # filtré APRÈS tous les tirages de ce rocher
		parts[i % 4].append(Transform3D(b, Vector3(x, monde.hauteur(x, z) - s * 0.25, z)))
		echelles[i % 4].append(s)
	var corps := StaticBody3D.new()
	for g in 4:
		var points_modele: PackedVector3Array = modeles[g].create_convex_shape().points
		for k in parts[g].size():
			if echelles[g][k] < COLLISION_MIN:
				continue
			var t: Transform3D = parts[g][k]
			var pts := PackedVector3Array()
			for p in points_modele:
				pts.append(t.basis * p)
			var convexe := ConvexPolygonShape3D.new()
			convexe.points = pts
			var forme := CollisionShape3D.new()
			forme.shape = convexe
			forme.position = t.origin  # translation seule, aucune échelle
			corps.add_child(forme)
		Instanciation.repartir(monde, modeles[g], parts[g], {"portee": 120.0, "marge": 10.0})
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
