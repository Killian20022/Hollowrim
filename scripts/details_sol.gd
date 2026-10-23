class_name DetailsSol
## Petits détails 3D du sol de la zone témoin (lot 3) : cailloux à moitié enfouis, coiffés de neige,
## au bord des chemins, autour des rochers et des pierres du cercle, et quelques-uns épars.
## MultiMesh (Instanciation.repartir) sans ombre ni collision, portée courte ; RNG propre
## `ZoneBiome.graine("details_sol")` (monde.rng n'est jamais touché). Rien hors zone.

const NB_CHEMIN := 170      # cailloux au bord des chemins (0,7-1,8 m de l'axe)
const NB_ROCHERS := 110     # en couronne au pied des rochers et des pierres
const NB_EPARS := 90        # épars (neige nue, lisières)
const PORTEE := 32.0
const TAILLE := Vector2(0.05, 0.15)  # demi-taille des cailloux (m)

## Caillou bas : anneau de 5 sommets bruités + sommet + base (10 triangles) ; dessus en neige
## (alpha 0 = tex_neige) si `neige`, flancs en roche.
static func mesh_caillou(graine: int, neige: bool) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anneau: Array[Vector3] = []
	for i in 5:
		var a := TAU * i / 5.0 + r.randf_range(-0.3, 0.3)
		var rr := r.randf_range(0.75, 1.15)
		anneau.append(Vector3(cos(a) * rr, r.randf_range(0.25, 0.5), sin(a) * rr * r.randf_range(0.7, 1.0)))
	var haut := Vector3(r.randf_range(-0.2, 0.2), r.randf_range(0.75, 1.0), r.randf_range(-0.2, 0.2))
	var bas := Vector3(0, -0.4, 0)
	var c_roche := Color(r.randf_range(0.85, 1.0), r.randf_range(0.85, 1.0), r.randf_range(0.9, 1.0), 1.0)
	var c_haut := Color(1, 1, 1, 0.0 if neige else 1.0)  # calotte de neige au sommet
	for i in 5:
		var p0 := anneau[i]
		var p1 := anneau[(i + 1) % 5]
		for tri in [[haut, p1, p0, c_haut, c_roche, c_roche], [bas, p0, p1, c_roche, c_roche, c_roche]]:
			var centre: Vector3 = ((tri[0] as Vector3) + (tri[1] as Vector3) + (tri[2] as Vector3)) / 3.0
			var n: Vector3 = ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3)).normalized()
			var ordre := [0, 2, 1]
			if n.dot(centre) > 0.0:
				ordre = [0, 1, 2]  # face avant orientée vers l'extérieur (vérifié en capture)
			else:
				n = -n
			for k: int in ordre:
				var p: Vector3 = tri[k]
				st.set_color(tri[k + 3])
				st.set_normal(n.lerp(p.normalized(), 0.4).normalized())
				st.set_uv(Vector2(p.x + p.y, p.z + p.y) * 0.5)
				st.add_vertex(p)
	return st.commit()

## Hauteur exacte du maillage du terrain (cases de 2 m, deux triangles a-b-c / b-d-c).
static func hauteur_maillage(monde: Node, x: float, z: float) -> float:
	var pas: float = monde.TAILLE / monde.CASES
	var demi: float = monde.TAILLE * 0.5
	var u := (x + demi) / pas
	var v := (z + demi) / pas
	var i := floori(u)
	var j := floori(v)
	var fu := u - i
	var fv := v - j
	var x0 := i * pas - demi
	var z0 := j * pas - demi
	var ha: float = monde.hauteur(x0, z0)
	var hb: float = monde.hauteur(x0 + pas, z0)
	var hc: float = monde.hauteur(x0, z0 + pas)
	if fu + fv <= 1.0:
		return ha + (hb - ha) * fu + (hc - ha) * fv
	var hd: float = monde.hauteur(x0 + pas, z0 + pas)
	return hd + (hc - hd) * (1.0 - fu) + (hb - hd) * (1.0 - fv)

static func creer(monde: Node) -> void:
	if not ZoneBiome.actif or monde.chemins == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = ZoneBiome.graine("details_sol")
	var pts: PackedVector2Array = monde.chemins.points
	var centres: Array = []  # [Vector2, rayon] : rochers, pierres du cercle, occupations
	for r in SousBois._rochers(monde):
		centres.append([r["pos"], r["r"] * 0.85])
	var c: Vector3 = monde.CERCLE
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		centres.append([Vector2(c.x + cos(a) * 6.5, c.z + sin(a) * 6.5), 0.6])
	for o in ZoneBiome.OCCUPATIONS:
		centres.append([o[0], minf(o[1] * 0.45, 1.2)])
	var candidats: Array = []
	for n in NB_CHEMIN:
		var k := rng.randi_range(0, pts.size() - 2)
		var p := pts[k].lerp(pts[k + 1], rng.randf())
		var t := (pts[k + 1] - pts[k]).normalized()
		var cote := 1.0 if rng.randf() < 0.5 else -1.0
		candidats.append(p + Vector2(-t.y, t.x) * cote * rng.randf_range(0.75, 1.8))
	for n in NB_ROCHERS:
		var o: Array = centres[rng.randi() % centres.size()]
		candidats.append((o[0] as Vector2) + Vector2.RIGHT.rotated(rng.randf() * TAU) * (float(o[1]) * rng.randf_range(1.05, 1.6) + 0.15))
	for n in NB_EPARS:
		candidats.append(Vector2(rng.randf_range(ZoneBiome.X0, ZoneBiome.X1), rng.randf_range(ZoneBiome.Z0, ZoneBiome.Z1)))
	var meshes: Array[ArrayMesh] = []
	# double face : quelle que soit l'orientation des triangles, le caillou est plein (vérifié en capture)
	var m := Palette.materiau(monde.tex_roche, Vector2.ONE, Color(1.15, 1.15, 1.2), true)
	for g in 4:
		var me := mesh_caillou(910 + g, g < 2)
		me.surface_set_material(0, m)
		meshes.append(me)
	var parts: Array[Array] = [[], [], [], []]
	for p: Vector2 in candidats:
		# tirages d'abord, filtrage ensuite (le nombre de tirages ne dépend pas du décor)
		var s := rng.randf_range(TAILLE.x, TAILLE.y) * (1.6 if rng.randf() < 0.1 else 1.0)
		var lacet := rng.randf() * TAU
		var g := rng.randi() % 4
		var sy := rng.randf_range(0.6, 0.9)
		if ZoneBiome.masque(p.x, p.y) < 0.99:
			continue
		if monde.chemins.distance(p.x, p.y) < 0.65 or p.length() < 2.0:
			continue  # pas sur la piste ni dans le feu
		var y := minf(hauteur_maillage(monde, p.x, p.y), monde.hauteur(p.x, p.y)) - s * 0.15   # cuvette : le maillage dépasse le relief exact
		parts[g].append(Transform3D(Basis(Vector3.UP, lacet).scaled(Vector3(s, s * sy, s)), Vector3(p.x, y, p.y)))
	var total := 0
	for g in 4:
		parts[g] = PosesDecor.filtrer(monde, parts[g], "caillou")   # passe D : pas dans le perron du tertre ni dans l'eau
		if parts[g].is_empty():
			continue
		total += parts[g].size()
		for mmi in Instanciation.repartir(monde, meshes[g], parts[g], {"portee": PORTEE, "ombre": false}):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.set_meta("details_sol", g)
			mmi.set_meta("transforms", parts[g])
	print("Détails du sol : %d cailloux" % total)

## Kit réutilisable (abords du village, plus tard toute la carte) : sème des cailloux à demi enfouis aux positions
## `points` (x, z), mêmes maillages et matériau que la zone témoin, RNG propre `graine` ; MultiMesh sans ombre ni
## collision, portée courte. Rien n'est filtré ici : l'appelant choisit des points hors de la piste. Renvoie le nombre posé.
static func semer(parent: Node, monde: Node, points: Array, graine: int, taille := TAILLE) -> int:
	if points.is_empty():
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var m := Palette.materiau(monde.tex_roche, Vector2.ONE, Color(1.15, 1.15, 1.2), true)
	var parts: Array[Array] = [[], [], [], []]
	for p: Vector2 in points:
		var s := rng.randf_range(taille.x, taille.y) * (1.6 if rng.randf() < 0.1 else 1.0)
		var y := hauteur_maillage(monde, p.x, p.y) - s * 0.15
		parts[rng.randi() % 4].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.6, 0.9), s)), Vector3(p.x, y, p.y)))
	for g in 4:
		if parts[g].is_empty():
			continue
		var me := mesh_caillou(910 + g, g < 2)
		me.surface_set_material(0, m)
		for mmi in Instanciation.repartir(parent, me, parts[g], {"portee": PORTEE, "ombre": false}):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.set_meta("details_sol", g)
			mmi.set_meta("transforms", parts[g])
	return points.size()
