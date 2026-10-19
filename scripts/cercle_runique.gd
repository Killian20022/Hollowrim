class_name CercleRunique
## Cercle de sept pierres dressées autour d'une stèle gravée de runes qui luisent.
## Les hauteurs et inclinaisons des pierres consomment `monde.rng` : ne pas changer l'ordre.
## Lot F (zone témoin seulement) : pierres enneigées (boîte SurfaceTool) + composition autour du cercle
## (menhirs couchés, rochers bas, arbres morts, os), RNG propre `ZoneBiome.graine("composition")`.

const MENHIRS := [[11.0, 2.6], [11.4, 4.2]]  # [rayon, angle] ; hors anneaux r = 9 ± 0,8 et 14 ± 0,8 du test sanctuaire
const ROCHERS := [[8.6, 1.3], [9.4, 2.2], [10.6, 2.9], [8.6, 3.8], [9.8, 0.1], [8.4, 5.9]]
const ARBRES := [[11.5, 1.8], [12.2, 3.3], [11.0, 5.9]]

## Boîte centrée de taille `taille` : dessus enneigé (alpha de sommet 0), liseré tramé en haut des côtés,
## le reste en matière de base (alpha 1). Normales à plat ; UV 0..1 par face. `graine` fixe le liseré.
static func boite_neige(taille: Vector3, graine: int, liseré := 0.25) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := taille * 0.5
	var base := Color(1, 1, 1, 1)
	var neige := Color(1, 1, 1, 0)
	var bande := minf(liseré, taille.y * 0.45)
	# côtés : [normale, tangente horizontale, largeur]
	for cote in [[Vector3.RIGHT, Vector3.BACK, taille.z], [Vector3.LEFT, Vector3.FORWARD, taille.z], [Vector3.BACK, Vector3.LEFT, taille.x], [Vector3.FORWARD, Vector3.RIGHT, taille.x]]:
		var n: Vector3 = cote[0]
		var t: Vector3 = cote[1]
		var w: float = cote[2]
		var c := n * (h.x if absf(n.x) > 0.5 else h.z)
		var y_bande := h.y - bande
		_quad(st, c + t * (-w * 0.5) + Vector3(0, -h.y, 0), c + t * (w * 0.5) + Vector3(0, -h.y, 0), c + t * (w * 0.5) + Vector3(0, y_bande, 0), c + t * (-w * 0.5) + Vector3(0, y_bande, 0), n, base, base, base, base, Vector2(w, taille.y - bande))
		var cols := maxi(2, roundi(w / 0.18))
		for k in cols:
			var x0 := -w * 0.5 + w * k / cols
			var x1 := -w * 0.5 + w * (k + 1) / cols
			# la frontière neige/base passe à `part` de la hauteur du liseré (alpha interpolé, seuil 0,5)
			var part := rng.randf_range(0.45, 0.95)
			var bas := Color(1, 1, 1, 0.5 / part)
			_quad(st, c + t * x0 + Vector3(0, y_bande, 0), c + t * x1 + Vector3(0, y_bande, 0), c + t * x1 + Vector3(0, h.y, 0), c + t * x0 + Vector3(0, h.y, 0), n, bas, bas, neige, neige, Vector2(w / cols, bande))
	_quad(st, Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3.UP, neige, neige, neige, neige, Vector2(taille.x, taille.z))
	_quad(st, Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3.DOWN, base, base, base, base, Vector2(taille.x, taille.z))
	st.generate_normals()
	return st.commit()

## Quad p0 p1 p2 p3 (bas gauche, bas droit, haut droit, haut gauche), tourné vers `n` (sens horaire = face avant).
static func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, c0: Color, c1: Color, c2: Color, c3: Color, uv_taille: Vector2) -> void:
	var ps := [p0, p1, p2, p3]
	var cs := [c0, c1, c2, c3]
	var uvs := [Vector2(0, 1), Vector2(uv_taille.x, 1), Vector2(uv_taille.x, 1.0 - uv_taille.y), Vector2(0, 1.0 - uv_taille.y)]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector3 = ps[tri[0]]
		var b: Vector3 = ps[tri[1]]
		var c: Vector3 = ps[tri[2]]
		var ordre: Array = tri if (c - a).cross(b - a).dot(n) > 0.0 else [tri[0], tri[2], tri[1]]
		for i in ordre:
			st.set_color(cs[i])
			st.set_uv(uvs[i])
			st.add_vertex(ps[i])

## Matériau des runes qui luisent (quad à texture de runes, sans ombrage).
static func materiau_runes() -> StandardMaterial3D:
	var mr := StandardMaterial3D.new()
	mr.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mr.albedo_texture = texture_runes()
	mr.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mr

static func texture_runes() -> ImageTexture:
	var img := Image.create(12, 34, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(0.5, 1.6, 2.0)
	for r in 3:
		var y0 := 1 + r * 11
		for y in range(y0, y0 + 10):
			img.set_pixel(5, y, c)
		# branches façon futhark
		var motifs := [[[5, 1, 9, 5]], [[5, 2, 9, 0], [5, 6, 9, 4]], [[5, 4, 1, 0], [5, 4, 9, 0]], [[5, 1, 9, 5], [9, 5, 5, 9]]]
		for seg in motifs[(r * 3 + 1) % motifs.size()]:
			var a := Vector2(seg[0], y0 + seg[1])
			var b := Vector2(seg[2], y0 + seg[3])
			var pas := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
			for k in pas + 1:
				var p := a.lerp(b, float(k) / maxf(pas, 1))
				img.set_pixel(clampi(roundi(p.x), 0, 11), clampi(roundi(p.y), 0, 33), c)
	return ImageTexture.create_from_image(img)

static func creer(monde: Node) -> void:
	var rng: RandomNumberGenerator = monde.rng
	var cercle: Vector3 = monde.CERCLE
	var centre := Vector3(cercle.x, monde.h_cercle, cercle.z)
	var m := Palette.materiau(monde.tex_roche, Vector2(1, 2))
	var corps := StaticBody3D.new()
	monde.add_child(corps)
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var haut := rng.randf_range(2.2, 3.4)
		var taille := Vector3(1.0, haut, 0.45)
		var mi := MeshInstance3D.new()
		if ZoneBiome.actif:
			mi.mesh = boite_neige(taille, 100 + i)
			mi.set_meta("pierre_taille", taille)  # lu par outils/test_biome.gd (signature)
		else:
			var boite := BoxMesh.new()
			boite.size = taille
			mi.mesh = boite
		mi.material_override = m
		var p := centre + Vector3(cos(a) * 6.5, haut * 0.5 - 0.3, sin(a) * 6.5)
		mi.transform = Transform3D(Basis(Vector3.UP, -a + PI * 0.5).rotated(Vector3(cos(a), 0, sin(a)), rng.randf_range(-0.08, 0.08)), p)
		monde.add_child(mi)
		var forme := CollisionShape3D.new()
		var bf := BoxShape3D.new()
		bf.size = taille
		forme.shape = bf
		forme.transform = mi.transform
		corps.add_child(forme)

	# pierre centrale gravée de runes qui luisent
	var stele := MeshInstance3D.new()
	var taille_s := Vector3(1.3, 3.6, 0.5)
	if ZoneBiome.actif:
		stele.mesh = boite_neige(taille_s, 200)
		stele.set_meta("pierre_taille", taille_s)
	else:
		var bs := BoxMesh.new()
		bs.size = taille_s
		stele.mesh = bs
	stele.material_override = m
	stele.position = centre + Vector3(0, 1.5, 0)
	stele.rotation.y = 0.5
	monde.add_child(stele)
	var forme_s := CollisionShape3D.new()
	var bfs := BoxShape3D.new()
	bfs.size = taille_s
	forme_s.shape = bfs
	forme_s.transform = stele.transform
	corps.add_child(forme_s)
	var runes := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.75, 2.1)
	runes.mesh = q
	var mr := StandardMaterial3D.new()
	mr.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mr.albedo_texture = texture_runes()
	mr.cull_mode = BaseMaterial3D.CULL_DISABLED
	runes.material_override = mr
	for cote in [1.0, -1.0]:
		var r := runes.duplicate() as MeshInstance3D
		r.position = Vector3(0, 0.2, 0.256 * cote)
		stele.add_child(r)
	runes.free()  # gabarit, jamais ajouté à la scène
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.35, 0.8, 1.0)
	lueur.light_energy = 1.2
	lueur.omni_range = 7.0
	lueur.position = Vector3(0, 0.3, 0)
	stele.add_child(lueur)
	if ZoneBiome.actif:
		_composition(monde, centre, m)

# --- lot F : composition autour du cercle ---------------------------------------------

static func _polaire(centre: Vector3, r: float, a: float) -> Vector2:
	return Vector2(centre.x + cos(a) * r, centre.z + sin(a) * r)

static func _composition(monde: Node, centre: Vector3, m: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = ZoneBiome.graine("composition")
	var racine := Node3D.new()
	racine.name = "Composition"
	monde.add_child(racine)
	var corps := StaticBody3D.new()
	racine.add_child(corps)
	# menhirs couchés et brisés (collision) : long axe tangent, enfouis de 0,2 m, inclinés d'environ 4°
	for k in MENHIRS.size():
		var a: float = MENHIRS[k][1]
		var p := _polaire(centre, MENHIRS[k][0], a)
		var pieces := [[Vector3(2.6, 0.45, 0.9), 0.0, 0.0]]
		if k == 1:
			pieces.append([Vector3(1.1, 0.4, 0.8), 2.1, 0.5])  # un fragment, plus loin le long de la tangente
		for pc in pieces:
			var taille: Vector3 = pc[0]
			var tang := Vector2(-sin(a), cos(a))
			var q: Vector2 = p + tang * float(pc[1])
			var lacet := -(a + PI * 0.5) + rng.randf_range(-0.3, 0.3) + float(pc[2])
			var inclin := deg_to_rad(4.0) * (1.0 if k == 0 else -1.0) * rng.randf_range(0.8, 1.2)
			var b := Basis(Vector3.UP, lacet) * Basis(Vector3.BACK, inclin) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-2.0, 2.0)))
			var y := minf(monde.hauteur(q.x, q.y), minf(monde.hauteur(q.x + tang.x * 1.2, q.y + tang.y * 1.2), monde.hauteur(q.x - tang.x * 1.2, q.y - tang.y * 1.2)))
			var mi := MeshInstance3D.new()
			mi.mesh = boite_neige(taille, 300 + k * 10 + pieces.find(pc))
			mi.material_override = m
			mi.transform = Transform3D(b, Vector3(q.x, y - 0.2 + taille.y * 0.5, q.y))
			racine.add_child(mi)
			var forme := CollisionShape3D.new()
			var bf := BoxShape3D.new()
			bf.size = taille
			forme.shape = bf
			forme.transform = mi.transform
			corps.add_child(forme)
	# rochers bas, sans collision (on les enjambe)
	for k in ROCHERS.size():
		var p := _polaire(centre, ROCHERS[k][0], ROCHERS[k][1])
		var s := rng.randf_range(0.7, 1.2)
		var mesh := Rochers.rocher_mesh(60 + k)
		mesh.surface_set_material(0, m)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.45, s * rng.randf_range(0.8, 1.2))), Vector3(p.x, monde.hauteur(p.x, p.y) - s * 0.1, p.y))
		racine.add_child(mi)
	# arbres morts : silhouette lisible au-dessus des pierres (collision mince)
	var rng_tex := RandomNumberGenerator.new()
	rng_tex.seed = ZoneBiome.graine("composition") + 1
	var m_tronc := Palette.materiau(monde.tex_roche, Vector2(1, 2), Color(0.95, 0.92, 0.88))
	var m_neige := Palette.materiau(Palette.texture(32, ["#8c9cb8", "#a9b7cf", "#c3cfe2", "#dde5f1"], 4, 9, 0.25, rng_tex), Vector2(1, 1))
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.25
	cyl.height = 4.0
	for k in ARBRES.size():
		var p := _polaire(centre, ARBRES[k][0], ARBRES[k][1])
		var s := rng.randf_range(1.05, 1.3)
		var mi := MeshInstance3D.new()
		mi.mesh = Arbres.arbre_mort(14 + k, [m_tronc, null, m_neige])
		mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, monde.hauteur(p.x, p.y) - 0.15, p.y))
		racine.add_child(mi)
		var forme := CollisionShape3D.new()
		forme.shape = cyl
		forme.position = Vector3(p.x, monde.hauteur(p.x, p.y) + 1.8, p.y)
		corps.add_child(forme)
	_offrandes(monde, racine, centre, rng, rng_tex)

## Os et bois de cerf au pied de la stèle (sobre, sans collision).
static func _offrandes(monde: Node, racine: Node3D, centre: Vector3, rng: RandomNumberGenerator, rng_tex: RandomNumberGenerator) -> void:
	var m_os := Palette.materiau(Palette.texture(16, Palette.OSSEMENT, 3, 7, 0.2, rng_tex))
	var pied := Node3D.new()
	pied.name = "Offrandes"
	racine.add_child(pied)
	var a0 := 0.9  # côté du chemin du feu : visible en arrivant
	# bois de cerf : une perche et trois andouillers
	var bois := Node3D.new()
	var p := _polaire(centre, 2.3, a0)
	bois.position = Vector3(p.x, monde.hauteur(p.x, p.y) + 0.04, p.y)
	bois.rotation.y = rng.randf() * TAU
	pied.add_child(bois)
	_os(bois, Vector3(0.9, 0.05, 0.06), Vector3(0, 0.02, 0), 0.0, 0.0, m_os)
	for t in 3:
		_os(bois, Vector3(0.3, 0.04, 0.045), Vector3(-0.3 + t * 0.3, 0.03, 0.12), 0.0, 0.9 + t * 0.2, m_os)
	# trois os épars
	for k in 3:
		var q := _polaire(centre, rng.randf_range(2.0, 3.0), a0 + rng.randf_range(-0.9, 0.9))
		var os := Node3D.new()
		os.position = Vector3(q.x, monde.hauteur(q.x, q.y) + 0.03, q.y)
		os.rotation.y = rng.randf() * TAU
		pied.add_child(os)
		_os(os, Vector3(rng.randf_range(0.25, 0.45), 0.05, 0.05), Vector3.ZERO, 0.0, 0.0, m_os)

static func _os(parent: Node3D, taille: Vector3, pos: Vector3, _x: float, lacet: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = lacet
	parent.add_child(mi)
