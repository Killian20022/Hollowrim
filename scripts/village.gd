extends Node3D
## Skarnholt : hameau nordique entouré d'une palissade.
## Repère local : sol plat en y = 0, +Z = la porte (tournée vers le feu de camp).
## Expose `lieux` (postes des villageois, en coordonnées monde) et `promenade`.

const RAYON := 22.0          # palissade
const DEMI_PORTE := 2.4      # demi-largeur de l'ouverture

var lieux := {}
var promenade: Array[Vector3] = []

var corps: StaticBody3D
var rng := RandomNumberGenerator.new()
var _flammes: Array = []  # [OmniLight3D, énergie de base, décalage]
var _t := 0.0

var m_planches: ShaderMaterial
var m_poutres: ShaderMaterial
var m_poutres_h: ShaderMaterial
var m_neige: ShaderMaterial
var m_roche: ShaderMaterial
var m_pierre_fine: ShaderMaterial
var m_fer: ShaderMaterial
var m_foin: ShaderMaterial
var m_cuir: ShaderMaterial
var m_ecorce: ShaderMaterial
var m_fenetre: ShaderMaterial
var m_braises: ShaderMaterial
var m_eau: ShaderMaterial
var m_glace: ShaderMaterial

func _ready() -> void:
	rng.seed = 99
	corps = StaticBody3D.new()
	add_child(corps)
	# Lot 5 : matières pixel art en coordonnées d'objet (16 texels/m partout), mipmaps nearest (TexturesBati)
	m_planches = TexturesBati.m_planches()                       # murs, planches horizontales
	m_poutres = TexturesBati.m_bois_debout(Color(0.9, 0.88, 0.86))  # poteaux, portes, caisses (fil vertical)
	m_poutres_h = TexturesBati.m_planches(Color(0.88, 0.85, 0.83))  # solives, rives, dessous de toit
	m_neige = TexturesBati.m_neige_toit()
	m_roche = TexturesBati.m_pierre_seche()
	m_pierre_fine = TexturesBati.m_pierre_fine()
	m_fer = TexturesBati.m_fer(Color(0.8, 0.82, 0.9))
	m_foin = TexturesBati.m_foin(Color(0.85, 0.85, 0.8))
	m_cuir = TexturesBati.m_cuir(Color(1.3, 1.15, 1.0))
	m_ecorce = TexturesBati.m_ecorce()
	m_fenetre = TexturesBati.m_fenetre()
	m_braises = TexturesBati.m_braises()
	m_glace = TexturesBati.materiau(TexturesBati.tex_neige(), Color(0.78, 0.92, 1.05))
	m_eau = Palette.materiau(Palette.tex("eau", ["#05070c", "#0a0f18", "#101824", "#162030"], 4, 0.3))

	_palissade()
	_porte()
	_maison(Vector3(0, 0, -12), 0.0, 14.0, 7.0, 2.2, 3.2, true)       # longue maison de la cheffe
	_maison(Vector3(-11.5, 0, -3), PI * 0.5, 8.0, 5.5, 2.0, 2.4, false)
	_maison(Vector3(11.5, 0, 7.5), -PI * 0.5, 8.0, 5.5, 2.0, 2.4, false)
	_maison(Vector3(-9.5, 0, 13.0), PI * 0.62, 7.0, 5.0, 1.9, 2.2, false)
	_forge(Vector3(-12.5, 0, 6.0))
	_puits(Vector3(4.5, 0, 1.5))
	_brasero(Vector3(-2.5, 0, -2.5))
	_enclos(Vector3(11.5, 0, -6.5))
	_accessoires()
	_finaliser()

	var postes := {
		"longue_maison": Vector3(1.2, 0, -7.4),
		"forge": Vector3(-11.0, 0, 7.8),
		"puits": Vector3(6.0, 0, 2.6),
		"place": Vector3(-1.2, 0, -0.4),
		"enclos": Vector3(9.0, 0, -3.0),
		"porte": Vector3(2.2, 0, RAYON - 2.4),
	}
	for nom in postes:
		lieux[nom] = to_global(postes[nom])
		promenade.append(lieux[nom])
	for p in [Vector3(0, 0, 6), Vector3(-5, 0, 3), Vector3(6, 0, -5), Vector3(-4, 0, -7)]:
		promenade.append(to_global(p))

func _process(dt: float) -> void:
	_t += dt
	for f in _flammes:
		var l: OmniLight3D = f[0]
		var k: float = f[2]
		l.light_energy = f[1] * (0.9 + sin(_t * 9.0 + k) * 0.06 + sin(_t * 21.3 + k * 2.0) * 0.04 + randf() * 0.06)

# --- briques ---------------------------------------------------------------------

## Lots fusionnés (socle technique §1) : chaque pièce de bâtiment est ajoutée à un maillage unique par
## (pivot, matériau) au lieu d'un MeshInstance3D par pièce ; `_finaliser()` crée les maillages à la fin.
var _lots := {}   # "pivot|matériau" -> {"parent", "mat", "v", "n", "i"}
var _arrays_cache := {}

func _arrays_de(cle: String, fabrique: Callable) -> Array:
	if not _arrays_cache.has(cle):
		_arrays_cache[cle] = fabrique.call().get_mesh_arrays()
	return _arrays_cache[cle]

func _ajouter(parent: Node3D, arrays: Array, xf: Transform3D, mat: Material) -> void:
	var cle := "%d|%d" % [parent.get_instance_id(), mat.get_instance_id()]
	if not _lots.has(cle):
		_lots[cle] = {"parent": parent, "mat": mat, "v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array(), "i": PackedInt32Array()}
	var lot: Dictionary = _lots[cle]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	# les tableaux « Packed » sont des valeurs : on les sort du dictionnaire, on les remplit, on les range
	var v: PackedVector3Array = lot["v"]
	var n: PackedVector3Array = lot["n"]
	var uvs: PackedVector2Array = lot["u"]
	var uv_src: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var ii: PackedInt32Array = lot["i"]
	var base := v.size()
	for k in verts.size():
		v.append(xf * verts[k])
		n.append((xf.basis * norms[k]).normalized())
		uvs.append(uv_src[k] if k < uv_src.size() else Vector2.ZERO)
	if index.is_empty():
		for k in verts.size():
			ii.append(base + k)
	else:
		for k in index:
			ii.append(base + k)
	lot["v"] = v
	lot["n"] = n
	lot["u"] = uvs
	lot["i"] = ii

func _finaliser() -> void:
	for cle in _lots:
		var lot: Dictionary = _lots[cle]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = lot["v"]
		arrays[Mesh.ARRAY_NORMAL] = lot["n"]
		arrays[Mesh.ARRAY_TEX_UV] = lot["u"]
		arrays[Mesh.ARRAY_INDEX] = lot["i"]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = lot["mat"]
		(lot["parent"] as Node3D).add_child(mi)
	_lots.clear()
	_arrays_cache.clear()

func _boite(parent: Node3D, taille: Vector3, xf: Transform3D, mat: Material, solide := false) -> void:
	var arrays := _arrays_de("boite%s" % taille, func() -> Mesh:
		var b := BoxMesh.new()
		b.size = taille
		return b)
	_ajouter(parent, arrays, xf, mat)
	if solide:
		_collision(parent, BoxShape3D.new(), xf, taille)

func _cylindre(parent: Node3D, r_haut: float, r_bas: float, h: float, xf: Transform3D, mat: Material, cotes := 6, solide := false) -> void:
	var arrays := _arrays_de("cyl%f|%f|%f|%d" % [r_haut, r_bas, h, cotes], func() -> Mesh:
		var c := CylinderMesh.new()
		c.top_radius = r_haut
		c.bottom_radius = r_bas
		c.height = h
		c.radial_segments = cotes
		c.rings = 1
		return c)
	_ajouter(parent, arrays, xf, mat)
	if solide:
		var forme := CylinderShape3D.new()
		forme.radius = maxf(r_haut, r_bas)
		forme.height = h
		_collision(parent, forme, xf, Vector3.ZERO)

func _collision(parent: Node3D, forme: Shape3D, xf: Transform3D, taille: Vector3) -> void:
	if forme is BoxShape3D:
		forme.size = taille
	var cs := CollisionShape3D.new()
	cs.shape = forme
	corps.add_child(cs)
	# la forme est rangée sous le corps du village : on repasse en repère du village
	cs.transform = corps.global_transform.affine_inverse() * parent.global_transform * xf

func _pivot(position_: Vector3, lacet: float) -> Node3D:
	var n := Node3D.new()
	n.position = position_
	n.rotation.y = lacet
	add_child(n)
	return n

func _feu(parent: Node3D, position_: Vector3, taille: float, energie: float, portee: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.22)
	l.light_energy = energie
	l.omni_range = portee
	l.omni_attenuation = 1.3
	l.position = position_ + Vector3(0, 0.25, 0)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 22.0
	l.distance_fade_length = 8.0
	parent.add_child(l)
	_flammes.append([l, energie, rng.randf() * 10.0])
	var p := GPUParticles3D.new()
	p.amount = int(18 * taille) + 8
	p.lifetime = 0.5 + taille * 0.3
	p.position = position_
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08 * taille
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5 * taille
	pm.initial_velocity_max = 0.9 * taille
	pm.gravity = Vector3(0, 0.6, 0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 0.75, 1.0])
	g.colors = PackedColorArray([Color(3.0, 2.3, 0.9), Color(2.6, 1.0, 0.25), Color(1.2, 0.25, 0.05), Color(0.3, 0.05, 0.0, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09) * taille
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.vertex_color_use_as_albedo = true
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mq
	p.draw_pass_1 = q
	parent.add_child(p)

func _fumee(parent: Node3D, position_: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.position = position_
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 14, 12))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0.25, 0.05, 0.1)
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	var courbe := Curve.new()
	courbe.add_point(Vector2(0, 0.4))
	courbe.add_point(Vector2(1, 2.2))
	var ct := CurveTexture.new()
	ct.curve = courbe
	pm.scale_curve = ct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(0.22, 0.24, 0.3, 0.0), Color(0.22, 0.24, 0.3, 0.22), Color(0.16, 0.18, 0.24, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.45)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.vertex_color_use_as_albedo = true
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mq
	p.draw_pass_1 = q
	parent.add_child(p)

## Pignon triangulaire plein (visible des deux côtés), dans le plan YZ.
func _pignon(parent: Node3D, x: float, y0: float, demi_largeur: float, hauteur_: float) -> void:
	var a := Vector3(x, y0, -demi_largeur)
	var b := Vector3(x, y0, demi_largeur)
	var c := Vector3(x, y0 + hauteur_, 0)
	var v := PackedVector3Array([a, b, c, b, a, c])
	var n := PackedVector3Array()
	var n1 := (b - a).cross(c - a).normalized()
	for k in 3:
		n.append(n1)
	for k in 3:
		n.append(-n1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	_ajouter(parent, arrays, Transform3D(), m_planches)

# --- bâtiments ---------------------------------------------------------------------
# Lot 5. Structure modulaire (grille de 2 m : contreforts, bouts de solives, poteaux) ; textures en mètres
# (TexturesBati) : la même densité de pixels sur la pierre, le bois et la neige.

## Corps du poteau : cylindre à 8 pans (pas de cube ni de colonne ronde lisse).
func _poteau(parent: Node3D, pos: Vector3, rayon: float, h: float, mat: Material, solide := false) -> void:
	_cylindre(parent, rayon, rayon, h, Transform3D(Basis(), pos + Vector3(0, h * 0.5, 0)), mat, 8, solide)

## Torche murale : console de fer, manche, flamme ÉMISSIVE (pas de lumière : budget du socle technique §2) ;
## `reelle` = vraie OmniLight (une seule dans le village : la lanterne de la longue maison).
func _torche_murale(parent: Node3D, pos: Vector3, vers: float, reelle := false) -> void:
	# `vers` = +1 (mur vers +Z) ou -1 : sens de la saillie
	_boite(parent, Vector3(0.07, 0.07, 0.3), Transform3D(Basis(), pos + Vector3(0, -0.15, 0.13 * vers)), m_fer)
	_boite(parent, Vector3(0.07, 0.5, 0.07), Transform3D(Basis(Vector3.RIGHT, 0.25 * vers), pos + Vector3(0, 0.05, 0.28 * vers)), m_poutres)
	var haut := pos + Vector3(0, 0.38, 0.34 * vers)
	_boite(parent, Vector3(0.14, 0.2, 0.14), Transform3D(Basis(Vector3.UP, 0.4), haut), m_braises)
	_boite(parent, Vector3(0.08, 0.14, 0.08), Transform3D(Basis(Vector3.UP, 0.2), haut + Vector3(0, 0.15, 0)), m_braises)
	if reelle:
		_feu(parent, haut, 0.6, 1.4, 7.0)

## Stalactites de glace sous un égout : pyramides pendantes, une par ~35 cm.
func _stalactites(parent: Node3D, x0: float, x1: float, y: float, z: float, graine: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := x0
	while x < x1:
		var l := r.randf_range(0.1, 0.32)
		var w := r.randf_range(0.04, 0.06)
		var h := Vector3(x, y, z)
		var c := [h + Vector3(-w, 0, -w), h + Vector3(w, 0, -w), h + Vector3(w, 0, w), h + Vector3(-w, 0, w)]
		var pointe := h + Vector3(0, -l, 0)
		for i in 4:
			st.add_vertex(c[i])
			st.add_vertex(c[(i + 1) % 4])
			st.add_vertex(pointe)
		x += r.randf_range(0.28, 0.5)
	st.generate_normals()
	_ajouter(parent, st.commit_to_arrays(), Transform3D(), m_glace)

## Maison nordique : plinthe de pierre sèche, contreforts, murs de planches sous sablière, toit de neige
## épaisse à deux pans avec stalactites, rives croisées en cornes, cheminée de pierre, porte renforcée de
## fer dans un cadre épais, fenêtres encadrées éclairées, torche murale et fumée.
func _maison(centre: Vector3, lacet: float, longueur: float, largeur: float, h_murs: float, faite: float, cheffe: bool) -> void:
	var p := _pivot(centre, lacet)
	h_murs = maxf(h_murs, 2.3)   # porte de 2 m + linteau sous la sablière : murs de 2,3 m au minimum
	var y0 := 0.4 + h_murs
	# plinthe : 10 cm de saillie, dessus à 0,4 m (le pied des murs)
	_boite(p, Vector3(longueur + 0.5, 0.6, largeur + 0.5), Transform3D(Basis(), Vector3(0, 0.1, 0)), m_roche)
	for cote in [-1.0, 1.0]:
		_boite(p, Vector3(longueur, h_murs, 0.3), Transform3D(Basis(), Vector3(0, 0.4 + h_murs * 0.5, cote * largeur * 0.5)), m_planches)
		_boite(p, Vector3(0.3, h_murs, largeur), Transform3D(Basis(), Vector3(cote * longueur * 0.5, 0.4 + h_murs * 0.5, 0)), m_planches)
		_pignon(p, cote * longueur * 0.5, y0, largeur * 0.5, faite)
		# sablière : poutre au sommet des murs, en saillie
		_boite(p, Vector3(longueur + 0.5, 0.24, 0.44), Transform3D(Basis(), Vector3(0, y0 - 0.12, cote * largeur * 0.5)), m_poutres_h)
		_boite(p, Vector3(0.44, 0.24, largeur + 0.5), Transform3D(Basis(), Vector3(cote * longueur * 0.5, y0 - 0.12, 0)), m_poutres_h)
		# poteaux d'angle
		for cote2 in [-1.0, 1.0]:
			_boite(p, Vector3(0.36, h_murs + 0.1, 0.36), Transform3D(Basis(), Vector3(cote * longueur * 0.5, 0.4 + h_murs * 0.5, cote2 * largeur * 0.5)), m_poutres)
	# grille de 2 m : bouts de solives sous la sablière et contreforts de pierre sur les longs pans
	var xs: Array[float] = []
	var xb := -longueur * 0.5 + 2.0
	while xb < longueur * 0.5 - 1.0:
		xs.append(snappedf(xb, 2.0) if absf(snappedf(xb, 2.0)) < longueur * 0.5 - 1.0 else xb)
		xb += 2.0
	for cote in [-1.0, 1.0]:
		for x in xs:
			if cote > 0.0 and absf(x) < 1.1:
				continue   # la porte
			_boite(p, Vector3(0.2, 0.22, 0.55), Transform3D(Basis(), Vector3(x, y0 - 0.42, cote * (largeur * 0.5 + 0.2))), m_poutres_h)
		for xc in [-(longueur * 0.5 - 1.0), longueur * 0.5 - 1.0]:
			_boite(p, Vector3(0.55, 1.6, 0.55), Transform3D(Basis(), Vector3(xc, 0.6, cote * (largeur * 0.5 + 0.43))), m_pierre_fine)
			_boite(p, Vector3(0.68, 0.14, 0.68), Transform3D(Basis(), Vector3(xc, 1.47, cote * (largeur * 0.5 + 0.43))), m_pierre_fine)
	_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, (y0 + faite * 0.5) * 0.5, 0)), Vector3(longueur + 0.3, y0 + faite * 0.5, largeur + 0.3))

	# toit : deux pans qui débordent, planches dessous, neige épaisse dessus (la normale `rot * UP` regarde vers
	# le bas pour ces rotations : le dessus est `-normale`), stalactites à l'égout
	var avancee := 0.75
	var bas := Vector2(largeur * 0.5 + avancee, y0 - 0.5)  # (z, y) de l'égout
	var haut := Vector2(0.0, y0 + faite + 0.12)
	var pan := haut - bas
	var angle := atan2(pan.y, pan.x)
	for cote in [-1.0, 1.0]:
		var milieu := Vector3(0, (bas.y + haut.y) * 0.5, cote * bas.x * 0.5)
		var rot := Basis(Vector3.RIGHT, -angle * cote)
		var dessus := -(rot * Vector3.UP)
		_boite(p, Vector3(longueur + 1.3, 0.16, pan.length() + 0.1), Transform3D(rot, milieu), m_poutres_h)
		_boite(p, Vector3(longueur + 1.4, 0.3, pan.length() + 0.18), Transform3D(rot, milieu + dessus * 0.2), m_neige)
		# rives croisées : prolongées au-delà du faîte, elles forment des cornes
		for bout in [-1.0, 1.0]:
			var pente := rot * Vector3(0, 0, -cote)
			_boite(p, Vector3(0.12, 0.26, pan.length() + 0.7), Transform3D(rot, milieu - pente * 0.35 + dessus * 0.2 + Vector3(bout * (longueur * 0.5 + 0.78), 0, 0)), m_poutres_h)
		_stalactites(p, -longueur * 0.5 - 0.5, longueur * 0.5 + 0.5, bas.y - 0.08, cote * (bas.x + 0.02), int(centre.x * 31.0 + centre.z * 17.0) + int(cote))
	# faîtage enneigé
	_boite(p, Vector3(longueur + 1.5, 0.22, 0.5), Transform3D(Basis(), Vector3(0, haut.y + 0.16, 0)), m_neige)

	# cheminée de pierre (la fumée sort au-dessus)
	var xch := longueur * 0.15
	var h_ch := faite + 0.5
	_boite(p, Vector3(0.8, h_ch, 0.8), Transform3D(Basis(), Vector3(xch, y0 + h_ch * 0.5 - 0.1, 0)), m_pierre_fine)
	_boite(p, Vector3(1.0, 0.16, 1.0), Transform3D(Basis(), Vector3(xch, y0 + h_ch - 0.02, 0)), m_neige)

	# porte (côté +Z) : cadre épais, planches debout, deux bandes de fer, anneau ; deux marches de pierre
	var zf := largeur * 0.5 + 0.17
	_boite(p, Vector3(1.15, 1.95, 0.08), Transform3D(Basis(), Vector3(0, 0.4 + 0.98, zf)), m_poutres)
	for jx in [-0.69, 0.69]:
		_boite(p, Vector3(0.24, 2.1, 0.3), Transform3D(Basis(), Vector3(jx, 0.4 + 1.05, zf + 0.04)), m_poutres)
	_boite(p, Vector3(1.75, 0.3, 0.34), Transform3D(Basis(), Vector3(0, 0.4 + 2.2, zf + 0.04)), m_poutres_h)
	for by in [0.45, 1.5]:
		_boite(p, Vector3(1.15, 0.12, 0.04), Transform3D(Basis(), Vector3(0, 0.4 + by, zf + 0.06)), m_fer)
	_boite(p, Vector3(0.07, 0.2, 0.05), Transform3D(Basis(), Vector3(0.38, 0.4 + 1.0, zf + 0.08)), m_fer)
	_boite(p, Vector3(1.9, 0.2, 0.6), Transform3D(Basis(), Vector3(0, 0.1, zf + 0.5)), m_pierre_fine)
	_boite(p, Vector3(1.6, 0.2, 0.4), Transform3D(Basis(), Vector3(0, 0.3, zf + 0.25)), m_pierre_fine)
	# fenêtres encadrées, volet ouvert d'un côté
	for x in [-longueur * 0.26, longueur * 0.26]:
		for zz in [zf, -zf]:
			var yw := 0.4 + h_murs * 0.62
			_vitre(p, Vector3(x, yw, zz - 0.012 * signf(zz)), Vector2(0.55, 0.36), 0.0 if zz > 0.0 else PI)
			_boite(p, Vector3(0.74, 0.09, 0.12), Transform3D(Basis(), Vector3(x, yw + 0.24, zz)), m_poutres_h)
			_boite(p, Vector3(0.74, 0.09, 0.14), Transform3D(Basis(), Vector3(x, yw - 0.24, zz)), m_poutres_h)
			for fx in [-0.33, 0.33]:
				_boite(p, Vector3(0.09, 0.5, 0.12), Transform3D(Basis(), Vector3(x + fx, yw, zz)), m_poutres_h)
	_fumee(p, Vector3(xch, y0 + h_ch + 0.2, 0))
	# torche murale à droite de la porte
	_torche_murale(p, Vector3(1.25, 0.4 + 1.45, zf + 0.03), 1.0, cheffe)
	if cheffe:
		# boucliers peints accrochés au mur, de part et d'autre de la porte, et banc
		for x in [-2.6, -1.7, 1.9, 2.7]:
			_cylindre(p, 0.38, 0.38, 0.06, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.4 + 1.3, zf + 0.04)), m_cuir if x < 0 else m_fer, 8)
			_cylindre(p, 0.09, 0.09, 0.09, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.4 + 1.3, zf + 0.08)), m_fer, 8)
		_banc(p, Vector3(-2.2, 0, zf + 0.75), 2.0)
		_banc(p, Vector3(2.2, 0, zf + 0.75), 2.0)

## Vitrage : quad orienté vers +Z (lacet 0) ou -Z (lacet PI), UV 0..1 (la texture de fenêtre le couvre exactement).
func _vitre(parent: Node3D, pos: Vector3, taille: Vector2, lacet: float) -> void:
	var arrays := _arrays_de("quad%s" % taille, func() -> Mesh:
		var q := QuadMesh.new()
		q.size = taille
		return q)
	_ajouter(parent, arrays, Transform3D(Basis(Vector3.UP, lacet), pos), m_fenetre)

## Banc : planche épaisse sur deux pieds.
func _banc(parent: Node3D, pos: Vector3, longueur: float) -> void:
	_boite(parent, Vector3(longueur, 0.1, 0.4), Transform3D(Basis(), pos + Vector3(0, 0.5, 0)), m_poutres_h)
	for dx in [-0.42, 0.42]:
		_boite(parent, Vector3(0.1, 0.5, 0.36), Transform3D(Basis(), pos + Vector3(dx * longueur * 0.5 / 0.42 * 0.8, 0.25, 0)), m_poutres)

func _palissade() -> void:
	var nombre := int(TAU * RAYON / 0.42)
	var rondins := MultiMesh.new()
	rondins.transform_format = MultiMesh.TRANSFORM_3D
	var c := CylinderMesh.new()
	c.top_radius = 0.17
	c.bottom_radius = 0.19
	c.height = 1.0
	c.radial_segments = 6
	c.rings = 1
	c.material = m_ecorce
	rondins.mesh = c
	var pointes := MultiMesh.new()
	pointes.transform_format = MultiMesh.TRANSFORM_3D
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.17
	cone.height = 0.55
	cone.radial_segments = 6
	cone.rings = 1
	cone.material = m_ecorce
	pointes.mesh = cone
	var xf_r: Array[Transform3D] = []
	var xf_p: Array[Transform3D] = []
	var forme := CylinderShape3D.new()
	forme.radius = 0.22
	forme.height = 3.6
	var ouverture := asin(DEMI_PORTE / RAYON)
	for i in nombre:
		var a := TAU * i / nombre
		# angle 0 = +Z (la porte)
		if absf(wrapf(a, -PI, PI)) < ouverture:
			continue
		var pos := Vector3(sin(a) * RAYON, 0, cos(a) * RAYON)
		var h := rng.randf_range(3.2, 3.9)
		var penche := Basis(Vector3(cos(a), 0, -sin(a)), rng.randf_range(-0.03, 0.03))
		xf_r.append(Transform3D(penche.scaled(Vector3(1, h, 1)), pos + Vector3(0, h * 0.5 - 0.2, 0)))
		xf_p.append(Transform3D(penche, pos + penche * Vector3(0, h - 0.2 + 0.27, 0)))
		var cs := CollisionShape3D.new()
		cs.shape = forme
		cs.position = pos + Vector3(0, 1.8, 0)
		corps.add_child(cs)
	rondins.instance_count = xf_r.size()
	pointes.instance_count = xf_p.size()
	for i in xf_r.size():
		rondins.set_instance_transform(i, xf_r[i])
		pointes.set_instance_transform(i, xf_p[i])
	for mm in [rondins, pointes]:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
	_liens_palissade(ouverture)

## Liens de corde : deux rubans autour de la palissade (côté intérieur), à 1,0 m et 2,3 m ; coupés à la porte.
func _liens_palissade(ouverture: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pas := 96
	for hy in [1.0, 2.3]:
		for i in pas:
			var a0 := TAU * i / pas
			var a1 := TAU * (i + 1) / pas
			if absf(wrapf(a0, -PI, PI)) < ouverture or absf(wrapf(a1, -PI, PI)) < ouverture:
				continue
			var r := RAYON - 0.2
			var p0 := Vector3(sin(a0) * r, hy, cos(a0) * r)
			var p1 := Vector3(sin(a1) * r, hy, cos(a1) * r)
			var d := Vector3(0, 0.07, 0)
			for tri in [[p0 - d, p1 - d, p1 + d], [p0 - d, p1 + d, p0 + d]]:
				for v: Vector3 in tri:
					st.set_normal(Vector3(-v.x, 0, -v.z).normalized())
					st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m_foin
	add_child(mi)

func _porte() -> void:
	var p := _pivot(Vector3(0, 0, RAYON), 0.0)
	for cote in [-1.0, 1.0]:
		var x: float = cote * (DEMI_PORTE + 0.15)
		# poteau octogonal sur un socle de pierre, tête de dragon sculptée au sommet
		_boite(p, Vector3(1.0, 0.5, 1.0), Transform3D(Basis(), Vector3(x, 0.15, 0)), m_pierre_fine)
		_cylindre(p, 0.3, 0.34, 5.4, Transform3D(Basis(), Vector3(x, 2.5, 0)), m_poutres, 8, true)
		_boite(p, Vector3(0.3, 0.3, 0.8), Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(x, 5.3, 0.35)), m_poutres_h)
		_boite(p, Vector3(0.22, 0.22, 0.4), Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(x, 5.45, 0.75)), m_poutres_h)
		# contrefiche : jambe de force entre le poteau et la poutre
		_boite(p, Vector3(0.16, 1.3, 0.16), Transform3D(Basis(Vector3.BACK, -cote * 0.75), Vector3(x - cote * 0.55, 4.2, 0)), m_poutres)
		# torche fixée au poteau, côté intérieur
		_boite(p, Vector3(0.07, 0.6, 0.07), Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(x - cote * 0.05, 2.5, -0.42)), m_ecorce)
		_feu(p, Vector3(x - cote * 0.05, 2.9, -0.55), 0.8, 1.5, 9.0)
	_boite(p, Vector3(DEMI_PORTE * 2 + 1.2, 0.42, 0.42), Transform3D(Basis(), Vector3(0, 4.7, 0)), m_poutres_h)
	_boite(p, Vector3(DEMI_PORTE * 2 + 1.4, 0.22, 0.66), Transform3D(Basis(), Vector3(0, 5.0, 0)), m_neige)

func _forge(centre: Vector3) -> void:
	var p := _pivot(centre, PI * 0.5)
	# appentis ouvert : quatre poteaux octogonaux et un toit à une pente
	for x in [-2.4, 2.4]:
		for z in [-1.8, 1.8]:
			_poteau(p, Vector3(x, 0, z), 0.13, 2.7 if z < 0 else 2.2, m_poutres, true)
	var rot := Basis(Vector3.RIGHT, 0.14)
	_boite(p, Vector3(5.6, 0.16, 4.4), Transform3D(rot, Vector3(0, 2.55, 0)), m_poutres_h)
	_boite(p, Vector3(5.7, 0.3, 4.5), Transform3D(rot, Vector3(0, 2.8, 0)), m_neige)
	for z in [-1.8, 1.8]:   # sablières
		_boite(p, Vector3(5.2, 0.22, 0.26), Transform3D(Basis(), Vector3(0, 2.7 if z < 0 else 2.2, z) + Vector3(0, -0.12, 0)), m_poutres_h)
	# mur de fond en pierre sèche derrière le foyer, avec contreforts
	_boite(p, Vector3(4.8, 2.4, 0.4), Transform3D(Basis(), Vector3(0, 1.2, -2.0)), m_roche, true)
	for x in [-2.4, 0.0, 2.4]:
		_boite(p, Vector3(0.5, 2.0, 0.5), Transform3D(Basis(), Vector3(x, 1.0, -1.7)), m_roche)
	# foyer de pierre et braises, hotte et cheminée
	_boite(p, Vector3(1.8, 0.9, 1.2), Transform3D(Basis(), Vector3(-0.8, 0.45, -1.2)), m_pierre_fine, true)
	_boite(p, Vector3(1.1, 0.08, 0.7), Transform3D(Basis(), Vector3(-0.8, 0.92, -1.2)), m_braises)
	_boite(p, Vector3(1.2, 0.5, 0.9), Transform3D(Basis(), Vector3(-0.8, 1.55, -1.45)), m_pierre_fine)
	_boite(p, Vector3(0.7, 1.6, 0.7), Transform3D(Basis(), Vector3(-0.8, 2.2, -1.5)), m_pierre_fine)
	_feu(p, Vector3(-0.8, 0.95, -1.2), 0.7, 2.6, 9.0)
	_fumee(p, Vector3(-0.8, 3.1, -1.5))
	# enclume sur son billot, tonneau d'eau, soufflet de cuir
	_poteau(p, Vector3(1.0, 0, 0.2), 0.24, 0.5, m_poutres, true)
	_boite(p, Vector3(0.3, 0.14, 0.62), Transform3D(Basis(), Vector3(1.0, 0.57, 0.2)), m_fer)
	_boite(p, Vector3(0.18, 0.14, 0.3), Transform3D(Basis(), Vector3(1.0, 0.68, 0.2)), m_fer)
	_boite(p, Vector3(0.3, 0.1, 0.5), Transform3D(Basis(), Vector3(1.0, 0.79, 0.2)), m_fer)
	_boite(p, Vector3(0.14, 0.1, 0.3), Transform3D(Basis(), Vector3(1.0, 0.8, 0.62)), m_fer)
	_tonneau(p, Vector3(2.0, 0, -1.2))
	_boite(p, Vector3(0.5, 0.3, 0.7), Transform3D(Basis(Vector3.UP, 0.2), Vector3(-1.9, 0.55, -1.2)), m_cuir)
	# établi avec ses outils, lingots en pile
	_boite(p, Vector3(1.5, 0.1, 0.7), Transform3D(Basis(), Vector3(-0.2, 0.85, 1.4)), m_poutres_h, true)
	for dx in [-0.65, 0.65]:
		_boite(p, Vector3(0.12, 0.8, 0.6), Transform3D(Basis(), Vector3(-0.2 + dx, 0.4, 1.4)), m_poutres)
	for i in 3:
		_boite(p, Vector3(0.05, 0.3, 0.02), Transform3D(Basis(Vector3.FORWARD, 0.1 * i), Vector3(-0.6 + i * 0.12, 0.98, 1.3)), m_fer)
	for i in 3:
		_boite(p, Vector3(0.28, 0.07, 0.12), Transform3D(Basis(), Vector3(0.3, 0.94 + i * 0.07, 1.5)), m_fer)
	# lames en attente contre le mur de fond
	for i in 3:
		_boite(p, Vector3(0.05, 0.8, 0.012), Transform3D(Basis(Vector3.FORWARD, 0.12), Vector3(1.6 + i * 0.22, 0.5, -1.74)), m_fer)

func _puits(centre: Vector3) -> void:
	var p := _pivot(centre, 0.3)
	_cylindre(p, 0.95, 1.0, 0.85, Transform3D(Basis(), Vector3(0, 0.42, 0)), m_pierre_fine, 8, true)
	_cylindre(p, 1.06, 1.06, 0.14, Transform3D(Basis(), Vector3(0, 0.9, 0)), m_pierre_fine, 8)
	_cylindre(p, 0.78, 0.78, 0.04, Transform3D(Basis(), Vector3(0, 0.84, 0)), m_eau, 8)
	for x in [-1.05, 1.05]:
		_poteau(p, Vector3(x, 0, 0), 0.09, 2.0, m_poutres)
	_cylindre(p, 0.09, 0.09, 2.3, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 1.7, 0)), m_poutres_h, 8)
	for cote in [-1.0, 1.0]:
		var rot := Basis(Vector3.RIGHT, 0.6 * cote)
		_boite(p, Vector3(2.5, 0.08, 0.9), Transform3D(rot, Vector3(0, 2.15, 0.33 * cote)), m_poutres_h)
		_boite(p, Vector3(2.6, 0.2, 0.95), Transform3D(rot, Vector3(0, 2.3, 0.36 * cote)), m_neige)
	_cylindre(p, 0.16, 0.13, 0.25, Transform3D(Basis(), Vector3(0.3, 1.25, 0)), m_poutres, 8)
	_boite(p, Vector3(0.02, 0.4, 0.02), Transform3D(Basis(), Vector3(0.3, 1.5, 0)), m_cuir)   # corde du seau

func _brasero(centre: Vector3) -> void:
	var p := _pivot(centre, 0.0)
	_cylindre(p, 0.35, 0.45, 0.8, Transform3D(Basis(), Vector3(0, 0.4, 0)), m_pierre_fine, 8, true)
	_cylindre(p, 0.6, 0.35, 0.3, Transform3D(Basis(), Vector3(0, 0.95, 0)), m_fer, 8)
	_boite(p, Vector3(0.6, 0.06, 0.6), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 1.08, 0)), m_braises)
	_feu(p, Vector3(0, 1.12, 0), 1.6, 2.4, 11.0)
	# poteau sculpté octogonal sur un socle de pierre
	_boite(p, Vector3(0.7, 0.3, 0.7), Transform3D(Basis(), Vector3(1.6, 0.05, -0.6)), m_pierre_fine)
	_cylindre(p, 0.16, 0.2, 3.6, Transform3D(Basis(), Vector3(1.6, 1.8, -0.6)), m_poutres, 8, true)
	for i in 3:
		_boite(p, Vector3(0.44, 0.22, 0.44), Transform3D(Basis(Vector3.UP, i * 0.6), Vector3(1.6, 1.4 + i * 0.85, -0.6)), m_poutres_h)

func _enclos(centre: Vector3) -> void:
	var p := _pivot(centre, 0.0)
	var demi := Vector2(3.5, 2.5)
	for x in range(-7, 8):
		for z in [-demi.y, demi.y]:
			if x % 2 == 0 and not (z > 0 and absi(x) < 2):
				_boite(p, Vector3(0.14, 1.2, 0.14), Transform3D(Basis(), Vector3(x * 0.5, 0.6, z)), m_poutres)
	for z in range(-5, 6):
		for x in [-demi.x, demi.x]:
			if z % 2 == 0:
				_boite(p, Vector3(0.14, 1.2, 0.14), Transform3D(Basis(), Vector3(x, 0.6, z * 0.5)), m_poutres)
	for y in [0.5, 1.0]:
		_boite(p, Vector3(demi.x * 2, 0.1, 0.1), Transform3D(Basis(), Vector3(0, y, -demi.y)), m_poutres_h, y < 0.6)
		_boite(p, Vector3(0.1, 0.1, demi.y * 2), Transform3D(Basis(), Vector3(-demi.x, y, 0)), m_poutres_h, y < 0.6)
		_boite(p, Vector3(0.1, 0.1, demi.y * 2), Transform3D(Basis(), Vector3(demi.x, y, 0)), m_poutres_h, y < 0.6)
		for cote in [-1.0, 1.0]:
			_boite(p, Vector3(2.2, 0.1, 0.1), Transform3D(Basis(), Vector3(cote * 2.4, y, demi.y)), m_poutres_h, y < 0.6)
	# meules de foin et séchoir à peaux
	for pos in [Vector3(-2.0, 0, -1.2), Vector3(-0.6, 0, -1.6), Vector3(1.8, 0, -1.0)]:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.8
		s.height = 1.1
		s.radial_segments = 8
		s.rings = 4
		mi.mesh = s
		mi.material_override = m_foin
		mi.position = pos + Vector3(0, 0.35, 0)
		p.add_child(mi)
	for x in [-1.2, 1.2]:
		_poteau(p, Vector3(x, 0, demi.y + 2.2), 0.07, 2.0, m_poutres)
	_boite(p, Vector3(2.6, 0.1, 0.1), Transform3D(Basis(), Vector3(0, 1.95, demi.y + 2.2)), m_poutres_h)
	for x in [-0.6, 0.6]:
		_boite(p, Vector3(0.9, 1.2, 0.04), Transform3D(Basis(Vector3.FORWARD, x * 0.1), Vector3(x, 1.3, demi.y + 2.2)), m_cuir)

func _tonneau(parent: Node3D, pos: Vector3) -> void:
	_cylindre(parent, 0.3, 0.3, 0.8, Transform3D(Basis(), pos + Vector3(0, 0.4, 0)), m_poutres, 8, true)
	for y in [0.15, 0.65]:
		_cylindre(parent, 0.315, 0.315, 0.05, Transform3D(Basis(), pos + Vector3(0, y, 0)), m_fer, 8)

func _accessoires() -> void:
	var racine := _pivot(Vector3.ZERO, 0.0)
	for pos in [Vector3(-7.4, 0, -9.0), Vector3(-6.7, 0, -9.4), Vector3(13.5, 0, 3.2), Vector3(-14.5, 0, 9.0)]:
		_tonneau(racine, pos)
	for pos in [Vector3(7.5, 0, -8.6), Vector3(-13.2, 0, 2.0), Vector3(3.0, 0, 16.5)]:
		var t := rng.randf_range(0.5, 0.75)
		_boite(racine, Vector3(t, t, t), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos + Vector3(0, t * 0.5, 0)), m_poutres, true)
		# coffre ferré : cerclage de fer
		_boite(racine, Vector3(t + 0.02, 0.06, t + 0.02), Transform3D(Basis(Vector3.UP, 0.0), pos + Vector3(0, t * 0.5, 0)), m_fer)
	# tas de bois de chauffage contre les maisons
	for base in [Vector3(-7.6, 0, -15.6), Vector3(8.6, 0, 9.8)]:
		for rang in 3:
			for k in 6 - rang:
				var pos: Vector3 = base + Vector3((k + rang * 0.5) * 0.3, 0.14 + rang * 0.26, 0)
				_cylindre(racine, 0.13, 0.13, 1.1, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), pos), m_ecorce, 6)
		_collision(racine, BoxShape3D.new(), Transform3D(Basis(), base + Vector3(0.8, 0.4, 0)), Vector3(2.0, 0.8, 1.1))
