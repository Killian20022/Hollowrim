class_name SousBois
## Sous-bois de la zone témoin (lot E) : souches, branches tombées, touffes sèches, semis.
## Tout est en MultiMesh via Instanciation, SANS ombre, SANS collision, à portée courte, ancré sur la
## pente (le plus bas de 4 points). RNG propre `ZoneBiome.graine("sous_bois")` : `monde.rng` n'est jamais touché.
## Appelé par monde.gd APRÈS Rochers.creer (les touffes se collent aux rochers). Les MultiMesh portent
## la meta `sous_bois` (genre) et `transforms` ; leurs instances sont toutes dans la zone, donc ignorées par `test_biome --sans-zone`.
## Pas de champignons ni de fougères vertes : incohérent avec un sol enneigé.

const HERBE := preload("res://shaders/ps1_herbe.gdshader")

const NB_SOUCHES := 35
const NB_BRANCHES := 90
const NB_TOUFFES := 400
const NB_SEMIS := 60
const PORTEE_SOUCHES := 50.0
const PORTEE_BRANCHES := 50.0
const PORTEE_TOUFFES := 30.0
const PORTEE_SEMIS := 45.0
const DIST_CHEMIN_TOUFFE := 0.8   # centre d'une touffe à plus de 0,8 m de l'axe du chemin
const DIST_CHEMIN_BRANCHE := 1.5  # jamais sur le chemin
const RAYON_TOUFFE_ARBRE := 1.5   # touffes à moins de 1,5 m d'un arbre ou d'un rocher

# --- maillages -----------------------------------------------------------------

## Souche : prisme à 6 côtés brisé au sommet + calotte de neige (24 triangles). Surfaces : 0 écorce, 1 neige.
static func mesh_souche(graine: int, materiaux: Array) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var bois := SurfaceTool.new()
	bois.begin(Mesh.PRIMITIVE_TRIANGLES)
	var neige := SurfaceTool.new()
	neige.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cotes := 6
	var bas: Array[Vector3] = []
	var haut: Array[Vector3] = []
	for k in cotes:
		var a := TAU * k / cotes
		bas.append(Vector3(cos(a) * 0.36, -0.15, sin(a) * 0.36))
		haut.append(Vector3(cos(a) * 0.27, rng.randf_range(0.3, 0.5), sin(a) * 0.27))
	var sombre := Color(0.6, 0.6, 0.6)
	var w := Color.WHITE
	var coeur := Vector3(0, 0.42, 0)
	for k in cotes:
		var k2 := (k + 1) % cotes
		Arbres._tri(bois, bas[k], bas[k2], haut[k2], Vector2(k, 4), Vector2(k + 1, 4), Vector2(k + 1, 1), sombre, sombre, w)
		Arbres._tri(bois, bas[k], haut[k2], haut[k], Vector2(k, 4), Vector2(k + 1, 1), Vector2(k, 1), sombre, w, w)
		# dessus de la souche (bois clair), puis calotte de neige un peu plus haute et plus petite
		Arbres._tri(bois, coeur, haut[k], haut[k2], Vector2(0, 0), Vector2(k, 1), Vector2(k + 1, 1), w, w, w)
		var n0 := haut[k] * Vector3(0.75, 1, 0.75) + Vector3(0, 0.05, 0)
		var n1 := haut[k2] * Vector3(0.75, 1, 0.75) + Vector3(0, 0.05, 0)
		Arbres._tri(neige, coeur + Vector3(0, 0.07, 0), n0, n1, Vector2(0, 0), Vector2(k, 1), Vector2(k + 1, 1), w, w, w)
	return _valider(bois, neige, materiaux, [0, 2])

## Branche tombée : ruban de 3 segments tordu + 2 brindilles, double face (16 triangles), longueur ~1,6 m le long de X.
static func mesh_branche(graine: int, materiaux: Array) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	var lat: Array[Vector3] = []
	for i in 4:
		pts.append(Vector3(-0.8 + 1.6 * i / 3.0, 0.04 + rng.randf_range(0.0, 0.05), rng.randf_range(-0.07, 0.07)))
		lat.append(Vector3(0, 0.5, 0.87) * lerpf(0.07, 0.025, i / 3.0))
	var c := Color(0.85, 0.85, 0.85)
	for i in 3:
		var a0 := pts[i] - lat[i]
		var a1 := pts[i] + lat[i]
		var b0 := pts[i + 1] - lat[i + 1]
		var b1 := pts[i + 1] + lat[i + 1]
		var u0 := Vector2(i * 0.5, 0)
		_double(st, a0, a1, b1, Vector2(u0.x, 0), Vector2(u0.x, 1), Vector2(u0.x + 0.5, 1), c)
		_double(st, a0, b1, b0, Vector2(u0.x, 0), Vector2(u0.x + 0.5, 1), Vector2(u0.x + 0.5, 0), c)
	for n in 2:
		var i := 1 + n
		var cote := Vector3(0, 0.3, 0.95 if n == 0 else -0.95)
		var bout := pts[i] + Vector3(rng.randf_range(0.1, 0.3), 0.0, 0.0) + cote * rng.randf_range(0.25, 0.4)
		_double(st, pts[i] - lat[i] * 0.6, pts[i] + lat[i] * 0.6, bout, Vector2(0, 0), Vector2(0, 1), Vector2(1, 0.5), c)
	st.generate_normals()
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, materiaux[0])
	return mesh

static func _double(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, col: Color) -> void:
	Arbres._tri(st, a, b, c, ua, ub, uc, col, col, col)
	Arbres._tri(st, a, c, b, ua, uc, ub, col, col, col)

## Touffe sèche : 3 quads croisés (6 triangles), texture découpée par l'alpha.
static func mesh_touffe(materiau: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pied := Color(0.62, 0.62, 0.62)
	var tete := Color.WHITE
	for k in 3:
		var a := PI * k / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		var b0 := d * -0.55 + Vector3(0, -0.02, 0)
		var b1 := d * 0.55 + Vector3(0, -0.02, 0)
		var h0 := d * -0.42 + Vector3(0, 0.62, 0)
		var h1 := d * 0.42 + Vector3(0, 0.62, 0)
		Arbres._tri(st, b0, b1, h1, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), pied, pied, tete)
		Arbres._tri(st, b0, h1, h0, Vector2(0, 1), Vector2(1, 0), Vector2(0, 0), pied, tete, tete)
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, materiau)
	return mesh

static func _valider(bois: SurfaceTool, neige: SurfaceTool, materiaux: Array, indices: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for i in 2:
		var st: SurfaceTool = [bois, neige][i]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(i, materiaux[indices[i]])
	return mesh

## Texture de touffe sèche : brins foin / roux sur fond transparent (32 px, alpha 0 ou 1).
static func texture_touffe(graine: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var t := 32
	var img := Image.create(t, t, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var couleurs: Array[Color] = []
	for hex in Palette.FOIN + ["#8a5a2a", "#a06a32"]:
		couleurs.append(Color(hex))
	for n in 30:
		var x := rng.randf_range(2.0, t - 3.0)
		var h := rng.randi_range(9, 29)
		var pente := rng.randf_range(-0.3, 0.3)
		var teinte := rng.randi_range(0, 5)
		for k in h:
			var y := t - 1 - k
			var px := int(round(x + pente * k))
			if px < 0 or px >= t:
				break
			var ton := clampi(teinte + (1 if k > h / 2 else 0) - (1 if k < 4 else 0), 0, couleurs.size() - 1)
			img.set_pixel(px, y, couleurs[ton])
			if h > 20 and k < h - 6 and px + 1 < t:
				img.set_pixel(px + 1, y, couleurs[clampi(ton - 1, 0, couleurs.size() - 1)])
	return ImageTexture.create_from_image(img)

## Matériau PS1 « herbe » enregistré dans Palette : suit la bascule PS1 (touche P).
static func materiau_herbe(tex: Texture2D, teinte := Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HERBE
	m.set_shader_parameter("tex_base", tex)
	m.set_shader_parameter("teinte", teinte)
	Palette._appliquer(m, Palette._ps1_actif)
	Palette.materiaux.append(m)
	return m

# --- placement -------------------------------------------------------------------

## Le plus bas de 4 points autour de (x, z) à rayon r.
static func _bas(monde: Node, x: float, z: float, r: float) -> float:
	var h := minf(minf(monde.hauteur(x - r, z), monde.hauteur(x + r, z)), minf(monde.hauteur(x, z - r), monde.hauteur(x, z + r)))
	for d: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:   # passe D : sur une bosse, le maillage
		h = minf(h, DetailsSol.hauteur_maillage(monde, x + d.x, z + d.y))                              # (cases de 2 m) passe sous le relief exact
	return h

## Position hors exclusions de décor et du cône de vue ? (dans la zone, hors axe du chemin à `marge` m)
static func _libre(monde: Node, x: float, z: float, marge_chemin: float) -> bool:
	if ZoneBiome.masque(x, z) <= 0.0 or Vegetation.exclu_decor(x, z):
		return false
	return monde.chemins.distance(x, z) >= marge_chemin and not monde._pres_du_chemin(x, z, 1.0)

static func _tf(x: float, y: float, z: float, yaw: float, s: float, sy := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s * sy, s)), Vector3(x, y, z))

## Rochers de la zone [{pos: Vector2, r: float}], lus dans les collisions créées par Rochers.creer.
static func _rochers(monde: Node) -> Array:
	var l: Array = []
	for nd in monde.get_children():
		if nd is StaticBody3D:
			for f in nd.get_children():
				if f is CollisionShape3D and f.shape is ConvexPolygonShape3D:
					var p: Vector3 = f.position
					if ZoneBiome.masque(p.x, p.z) > 0.0:
						var r := 0.0
						for q in (f.shape as ConvexPolygonShape3D).points:
							r = maxf(r, Vector2(q.x, q.z).length())
						l.append({"pos": Vector2(p.x, p.z), "r": r})
	return l

static func _pres_d_un_arbre(arbres: Array, x: float, z: float, d: float) -> bool:
	for a in arbres:
		var p: Vector3 = a["pos"]
		if Vector2(p.x - x, p.z - z).length() < d + 0.35 * a["s"]:
			return true
	return false

static func creer(monde: Node) -> void:
	if not ZoneBiome.actif or not monde.has_meta("arbres_zone"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = ZoneBiome.graine("sous_bois")
	var bruit := Vegetation.nouveau_bruit_amas()
	var arbres: Array = monde.get_meta("arbres_zone")
	var rochers := _rochers(monde)
	var morts: Array = []
	var lisieres: Array = []
	for a in arbres:
		if a["forme"] == 3:
			morts.append(a)
		if a["lisiere"]:
			lisieres.append(a)

	# matériaux
	var mat_ecorce := Palette.materiau(monde.tex_ecorce, Vector2(1, 1), Color(0.95, 0.9, 0.85))
	var mat_neige := Palette.materiau(Arbres.texture_neige_branches(9), Vector2(1, 1))
	var mat_aig := Palette.materiau(Arbres.texture_aiguilles(3), Vector2(1, 1), Color(1.25, 1.3, 1.25))
	var mat_touffe := materiau_herbe(texture_touffe(31), Color(1.35, 1.25, 1.1))

	# --- souches : près des arbres morts et en lisière
	var refs: Array = morts + lisieres
	var souches: Array = []
	var essais := 0
	while souches.size() < NB_SOUCHES and essais < 6000 and not refs.is_empty():
		essais += 1
		var r: Dictionary = refs[rng.randi() % refs.size()]
		var a := rng.randf() * TAU
		var d := rng.randf_range(1.2, 3.2)
		var x: float = r["pos"].x + cos(a) * d
		var z: float = r["pos"].z + sin(a) * d
		var s := rng.randf_range(0.8, 1.4)
		if not _libre(monde, x, z, 1.8) or monde.chemins.dans_cone_vue(x, z) or _pres_d_un_arbre(arbres, x, z, 0.9):
			continue
		souches.append(_tf(x, _bas(monde, x, z, 0.3 * s) - 0.05, z, rng.randf() * TAU, s, rng.randf_range(0.8, 1.2)))

	# --- branches tombées : sous les amas (D élevé), près d'un arbre, jamais sur le chemin
	var branches: Array = []
	essais = 0
	while branches.size() < NB_BRANCHES and essais < 8000:
		essais += 1
		var x := rng.randf_range(ZoneBiome.X0, ZoneBiome.X1)
		var z := rng.randf_range(ZoneBiome.Z0, ZoneBiome.Z1)
		var yaw := rng.randf() * TAU
		var s := rng.randf_range(0.7, 1.3)
		if Vegetation.densite_amas(bruit, x, z) < 0.55 or not _libre(monde, x, z, DIST_CHEMIN_BRANCHE) or not _pres_d_un_arbre(arbres, x, z, 3.0):
			continue
		var dx := cos(yaw) * 0.8 * s
		var dz := -sin(yaw) * 0.8 * s
		if monde.chemins.distance(x + dx, z + dz) < DIST_CHEMIN_BRANCHE or monde.chemins.distance(x - dx, z - dz) < DIST_CHEMIN_BRANCHE:
			continue
		if _pres_d_un_arbre(arbres, x, z, 0.5) or Vegetation.exclu_decor(x + dx, z + dz) or Vegetation.exclu_decor(x - dx, z - dz):
			continue
		var y := minf(minf(monde.hauteur(x + dx, z + dz), monde.hauteur(x - dx, z - dz)), minf(monde.hauteur(x, z), _bas(monde, x, z, 0.35))) - 0.02
		branches.append(_tf(x, y, z, yaw, s))

	# --- touffes sèches : < 1,5 m des arbres et rochers, plus denses en lisière et clairière
	var touffes: Array = []
	var sources: Array = []
	for a in arbres:
		sources.append({"pos": Vector2(a["pos"].x, a["pos"].z), "r": 0.35 * a["s"]})
		if a["lisiere"]:
			sources.append({"pos": Vector2(a["pos"].x, a["pos"].z), "r": 0.35 * a["s"]})
	for r in rochers:
		sources.append(r)
	essais = 0
	while touffes.size() < NB_TOUFFES and essais < 20000 and not sources.is_empty():
		essais += 1
		var r: Dictionary = sources[rng.randi() % sources.size()]
		var a := rng.randf() * TAU
		var d: float = r["r"] + rng.randf_range(0.25, RAYON_TOUFFE_ARBRE - 0.1)
		var x: float = r["pos"].x + cos(a) * d
		var z: float = r["pos"].y + sin(a) * d
		var D := Vegetation.densite_amas(bruit, x, z)
		var dens := 1.0 if D < 0.4 else 0.55
		var sel := rng.randf()
		var s := rng.randf_range(0.45, 0.95)
		var yaw := rng.randf() * TAU
		if sel > dens or not _libre(monde, x, z, DIST_CHEMIN_TOUFFE) or _pres_d_un_arbre(arbres, x, z, 0.1):
			continue
		touffes.append(_tf(x, _bas(monde, x, z, 0.5 * s) - 0.04, z, yaw, s, rng.randf_range(0.8, 1.2)))

	# --- semis : lisières (D bas) et bords du chemin
	var semis: Array = []
	essais = 0
	while semis.size() < NB_SEMIS and essais < 12000:
		essais += 1
		var x := rng.randf_range(ZoneBiome.X0, ZoneBiome.X1)
		var z := rng.randf_range(ZoneBiome.Z0, ZoneBiome.Z1)
		var D := Vegetation.densite_amas(bruit, x, z)
		var s := rng.randf_range(0.6, 1.1)
		var yaw := rng.randf() * TAU
		if not _libre(monde, x, z, 1.5) or monde.chemins.dans_cone_vue(x, z):
			continue
		var dc: float = monde.chemins.distance(x, z)
		var lisiere := (D >= Vegetation.D_CLAIRIERE - 0.05 and D <= 0.45) or (dc >= 1.5 and dc <= 6.0)
		if not lisiere or rng.randf() > 0.5 or _pres_d_un_arbre(arbres, x, z, 1.0):
			continue
		semis.append(_tf(x, _bas(monde, x, z, 0.3 * s) - 0.06, z, yaw, s))

	_poser(monde, "souche", mesh_souche(61, [mat_ecorce, null, mat_neige]), souches, PORTEE_SOUCHES)
	_poser(monde, "branche", mesh_branche(62, [mat_ecorce]), branches, PORTEE_BRANCHES)
	_poser(monde, "touffe", mesh_touffe(mat_touffe), touffes, PORTEE_TOUFFES)
	_poser(monde, "semis", Arbres.semis(63, [null, mat_aig, mat_neige]), semis, PORTEE_SEMIS)
	print("Sous-bois : %d souches, %d branches, %d touffes, %d semis (%d rochers de zone)" % [souches.size(), branches.size(), touffes.size(), semis.size(), rochers.size()])

static func _poser(monde: Node, genre: String, mesh: Mesh, xfs0: Array, portee: float) -> void:
	var xfs := PosesDecor.filtrer(monde, xfs0, genre, mesh)   # passe D : règles de pose (après les tirages)
	if genre == "souche" or genre == "branche":
		var l: Array = monde.get_meta("sous_bois_gros", [])
		l.append_array(xfs)
		monde.set_meta("sous_bois_gros", l)   # SolV2 n'y pose pas de rocher
	if xfs.is_empty():
		return
	for mmi in Instanciation.repartir(monde, mesh, xfs, {"portee": portee, "ombre": false}):
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.set_meta("sous_bois", genre)
		mmi.set_meta("transforms", xfs)  # copie lisible par les tests (le rendu headless ne relit pas le MultiMesh)
