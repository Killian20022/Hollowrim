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
var m_neige: ShaderMaterial
var m_roche: ShaderMaterial
var m_fer: ShaderMaterial
var m_foin: ShaderMaterial
var m_cuir: ShaderMaterial
var m_ecorce: ShaderMaterial
var m_fenetre: ShaderMaterial
var m_braises: ShaderMaterial
var m_eau: ShaderMaterial

func _ready() -> void:
	rng.seed = 99
	corps = StaticBody3D.new()
	add_child(corps)
	m_planches = Palette.materiau(Palette.tex("planches", Palette.PLANCHES, 4, 0.5), Vector2(3, 0.6))
	m_poutres = Palette.materiau(Palette.tex("planches", Palette.PLANCHES, 4, 0.5), Vector2(0.5, 2), Color(0.75, 0.72, 0.7))
	m_neige = Palette.materiau(Palette.tex_neige, Vector2(2, 2))
	m_roche = Palette.materiau(Palette.tex("roche", Palette.ROCHE, 4, 0.45), Vector2(2, 1))
	m_fer = Palette.materiau(Palette.tex("acier", Palette.ACIER, 4, 0.3), Vector2.ONE, Color(0.45, 0.47, 0.55))
	m_foin = Palette.materiau(Palette.tex("foin", Palette.FOIN, 8, 0.6), Vector2(2, 2))
	m_cuir = Palette.materiau(Palette.tex("peau", Palette.CUIR, 4, 0.5), Vector2.ONE, Color(1.3, 1.15, 1.0))
	m_ecorce = Palette.materiau(Palette.tex("ecorce", Palette.ECORCE, 4, 0.4), Vector2(1, 3))
	m_fenetre = Palette.materiau(Palette.tex("fenetre", ["#3a1c08", "#6a3410", "#8a4a18", "#a8622a"], 4, 0.3))
	m_fenetre.set_shader_parameter("emission", Color(1.6, 0.7, 0.2))
	m_braises = Palette.materiau(Palette.tex("braises", ["#2a0800", "#6a1800", "#b83a08", "#f07020"], 8, 0.8))
	m_braises.set_shader_parameter("emission", Color(2.2, 0.7, 0.15))
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

func _boite(parent: Node3D, taille: Vector3, xf: Transform3D, mat: Material, solide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	if solide:
		_collision(parent, BoxShape3D.new(), xf, taille)
	return mi

func _cylindre(parent: Node3D, r_haut: float, r_bas: float, h: float, xf: Transform3D, mat: Material, cotes := 6, solide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_haut
	c.bottom_radius = r_bas
	c.height = h
	c.radial_segments = cotes
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	if solide:
		var forme := CylinderShape3D.new()
		forme.radius = maxf(r_haut, r_bas)
		forme.height = h
		_collision(parent, forme, xf, Vector3.ZERO)
	return mi

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
	g.colors = PackedColorArray([Color(0.3, 0.32, 0.38, 0.0), Color(0.3, 0.32, 0.38, 0.45), Color(0.2, 0.22, 0.28, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
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
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(x, y0, -demi_largeur)
	var b := Vector3(x, y0, demi_largeur)
	var c := Vector3(x, y0 + hauteur_, 0)
	for tri in [[a, b, c], [b, a, c]]:
		st.set_uv(Vector2(tri[0].z, -tri[0].y) * 0.5); st.add_vertex(tri[0])
		st.set_uv(Vector2(tri[1].z, -tri[1].y) * 0.5); st.add_vertex(tri[1])
		st.set_uv(Vector2(tri[2].z, -tri[2].y) * 0.5); st.add_vertex(tri[2])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m_planches
	parent.add_child(mi)

# --- bâtiments ---------------------------------------------------------------------

## Maison nordique : soubassement de pierre, murs de planches, toit de neige à deux pans,
## rives croisées en cornes au-dessus du faîte, porte et fenêtres éclairées, fumée.
func _maison(centre: Vector3, lacet: float, longueur: float, largeur: float, h_murs: float, faite: float, cheffe: bool) -> void:
	var p := _pivot(centre, lacet)
	var y0 := 0.4 + h_murs
	_boite(p, Vector3(longueur + 0.3, 0.45, largeur + 0.3), Transform3D(Basis(), Vector3(0, 0.2, 0)), m_roche)
	for cote in [-1.0, 1.0]:
		_boite(p, Vector3(longueur, h_murs, 0.3), Transform3D(Basis(), Vector3(0, 0.4 + h_murs * 0.5, cote * largeur * 0.5)), m_planches)
		_boite(p, Vector3(0.3, h_murs, largeur), Transform3D(Basis(), Vector3(cote * longueur * 0.5, 0.4 + h_murs * 0.5, 0)), m_planches)
		_pignon(p, cote * longueur * 0.5, y0, largeur * 0.5, faite)
		# poteaux d'angle
		for cote2 in [-1.0, 1.0]:
			_boite(p, Vector3(0.36, h_murs + 0.1, 0.36), Transform3D(Basis(), Vector3(cote * longueur * 0.5, 0.4 + h_murs * 0.5, cote2 * largeur * 0.5)), m_poutres)
	_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, (y0 + faite * 0.5) * 0.5, 0)), Vector3(longueur + 0.3, y0 + faite * 0.5, largeur + 0.3))

	# toit : deux pans qui débordent, planches dessous, neige dessus
	var avancee := 0.75
	var bas := Vector2(largeur * 0.5 + avancee, y0 - 0.5)  # (z, y) de l'égout
	var haut := Vector2(0.0, y0 + faite + 0.12)
	var pan := haut - bas
	var angle := atan2(pan.y, pan.x)
	for cote in [-1.0, 1.0]:
		var milieu := Vector3(0, (bas.y + haut.y) * 0.5, cote * bas.x * 0.5)
		var rot := Basis(Vector3.RIGHT, -angle * cote)
		var normale := rot * Vector3.UP
		_boite(p, Vector3(longueur + 1.3, 0.16, pan.length() + 0.1), Transform3D(rot, milieu), m_poutres)
		_boite(p, Vector3(longueur + 1.4, 0.16, pan.length() + 0.18), Transform3D(rot, milieu + normale * 0.15), m_neige)
		# rives croisées : prolongées au-delà du faîte, elles forment des cornes
		for bout in [-1.0, 1.0]:
			var pente := rot * Vector3(0, 0, -cote)
			_boite(p, Vector3(0.1, 0.24, pan.length() + 1.0), Transform3D(rot, milieu + pente * 0.5 + Vector3(bout * (longueur * 0.5 + 0.72), 0.12, 0)), m_poutres)

	# porte (côté +Z) et fenêtres
	var zf := largeur * 0.5 + 0.17
	_boite(p, Vector3(1.15, 1.95, 0.08), Transform3D(Basis(), Vector3(0, 0.4 + 0.98, zf)), m_poutres)
	_boite(p, Vector3(1.55, 0.22, 0.2), Transform3D(Basis(), Vector3(0, 0.4 + 2.05, zf)), m_poutres)
	for x in [-longueur * 0.3, longueur * 0.3]:
		_boite(p, Vector3(0.55, 0.32, 0.06), Transform3D(Basis(), Vector3(x, 0.4 + h_murs * 0.62, zf)), m_fenetre)
		_boite(p, Vector3(0.55, 0.32, 0.06), Transform3D(Basis(), Vector3(x, 0.4 + h_murs * 0.62, -zf)), m_fenetre)
	_fumee(p, Vector3(longueur * 0.15, y0 + faite + 0.3, 0))
	if cheffe:
		# lanterne au-dessus de la porte et boucliers peints accrochés au mur
		_feu(p, Vector3(0.95, 0.4 + 2.0, zf + 0.25), 0.6, 1.4, 7.0)
		_boite(p, Vector3(0.06, 0.5, 0.06), Transform3D(Basis(), Vector3(0.95, 0.4 + 1.75, zf + 0.25)), m_fer)
		for i in 4:
			var x := -5.0 + i * 1.1 + (2.6 if i > 1 else 0.0)
			_cylindre(p, 0.38, 0.38, 0.06, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.4 + 1.3, zf + 0.04)), m_cuir if i % 2 == 0 else m_fer, 8)

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

func _porte() -> void:
	var p := _pivot(Vector3(0, 0, RAYON), 0.0)
	for cote in [-1.0, 1.0]:
		var x: float = cote * (DEMI_PORTE + 0.15)
		_cylindre(p, 0.3, 0.34, 5.4, Transform3D(Basis(), Vector3(x, 2.5, 0)), m_ecorce, 7, true)
		# tête de dragon sculptée au sommet des poteaux
		_boite(p, Vector3(0.3, 0.3, 0.8), Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(x, 5.3, 0.35)), m_poutres)
		_boite(p, Vector3(0.22, 0.22, 0.4), Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(x, 5.45, 0.75)), m_poutres)
		# torche fixée au poteau, côté intérieur
		_boite(p, Vector3(0.07, 0.6, 0.07), Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(x - cote * 0.05, 2.5, -0.42)), m_ecorce)
		_feu(p, Vector3(x - cote * 0.05, 2.9, -0.55), 0.8, 1.5, 9.0)
	_boite(p, Vector3(DEMI_PORTE * 2 + 1.2, 0.42, 0.42), Transform3D(Basis(), Vector3(0, 4.7, 0)), m_poutres)
	_boite(p, Vector3(DEMI_PORTE * 2 + 1.4, 0.14, 0.6), Transform3D(Basis(), Vector3(0, 4.98, 0)), m_neige)

func _forge(centre: Vector3) -> void:
	var p := _pivot(centre, PI * 0.5)
	# appentis ouvert : quatre poteaux et un toit à une pente
	for x in [-2.4, 2.4]:
		for z in [-1.8, 1.8]:
			_boite(p, Vector3(0.24, 2.7 if z < 0 else 2.2, 0.24), Transform3D(Basis(), Vector3(x, (2.7 if z < 0 else 2.2) * 0.5, z)), m_poutres, true)
	var rot := Basis(Vector3.RIGHT, 0.14)
	_boite(p, Vector3(5.6, 0.14, 4.4), Transform3D(rot, Vector3(0, 2.55, 0)), m_poutres)
	_boite(p, Vector3(5.7, 0.14, 4.5), Transform3D(rot, Vector3(0, 2.7, 0)), m_neige)
	# foyer de pierre et braises
	_boite(p, Vector3(1.6, 0.9, 1.1), Transform3D(Basis(), Vector3(-0.8, 0.45, -1.2)), m_roche, true)
	_boite(p, Vector3(1.1, 0.08, 0.7), Transform3D(Basis(), Vector3(-0.8, 0.92, -1.2)), m_braises)
	_boite(p, Vector3(0.7, 1.6, 0.7), Transform3D(Basis(), Vector3(-0.8, 1.7, -1.45)), m_roche)
	_feu(p, Vector3(-0.8, 0.95, -1.2), 0.7, 2.6, 9.0)
	_fumee(p, Vector3(-0.8, 2.9, -1.45))
	# enclume, billot, tonneau d'eau
	_boite(p, Vector3(0.4, 0.5, 0.4), Transform3D(Basis(), Vector3(1.0, 0.25, 0.2)), m_poutres, true)
	_boite(p, Vector3(0.22, 0.2, 0.62), Transform3D(Basis(), Vector3(1.0, 0.6, 0.2)), m_fer)
	_boite(p, Vector3(0.16, 0.12, 0.22), Transform3D(Basis(), Vector3(1.0, 0.62, 0.6)), m_fer)
	_tonneau(p, Vector3(2.0, 0, -1.2))
	# lames en attente contre le mur
	for i in 3:
		_boite(p, Vector3(0.05, 0.8, 0.012), Transform3D(Basis(Vector3.FORWARD, 0.12), Vector3(1.6 + i * 0.22, 0.5, -1.7)), m_fer)

func _puits(centre: Vector3) -> void:
	var p := _pivot(centre, 0.3)
	_cylindre(p, 0.95, 1.0, 0.85, Transform3D(Basis(), Vector3(0, 0.42, 0)), m_roche, 9, true)
	_cylindre(p, 0.78, 0.78, 0.04, Transform3D(Basis(), Vector3(0, 0.84, 0)), m_eau, 9)
	for x in [-1.05, 1.05]:
		_boite(p, Vector3(0.16, 2.0, 0.16), Transform3D(Basis(), Vector3(x, 1.0, 0)), m_poutres)
	_cylindre(p, 0.09, 0.09, 2.3, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 1.7, 0)), m_poutres)
	for cote in [-1.0, 1.0]:
		var rot := Basis(Vector3.RIGHT, 0.6 * cote)
		_boite(p, Vector3(2.5, 0.08, 0.9), Transform3D(rot, Vector3(0, 2.15, 0.33 * cote)), m_poutres)
		_boite(p, Vector3(2.6, 0.08, 0.95), Transform3D(rot, Vector3(0, 2.23, 0.36 * cote)), m_neige)
	_cylindre(p, 0.16, 0.13, 0.25, Transform3D(Basis(), Vector3(0.3, 1.25, 0)), m_poutres, 6)

func _brasero(centre: Vector3) -> void:
	var p := _pivot(centre, 0.0)
	_cylindre(p, 0.35, 0.45, 0.8, Transform3D(Basis(), Vector3(0, 0.4, 0)), m_roche, 7, true)
	_cylindre(p, 0.6, 0.35, 0.3, Transform3D(Basis(), Vector3(0, 0.95, 0)), m_fer, 8)
	_boite(p, Vector3(0.6, 0.06, 0.6), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 1.08, 0)), m_braises)
	_feu(p, Vector3(0, 1.12, 0), 1.6, 2.4, 11.0)
	# poteau sculpté
	_cylindre(p, 0.16, 0.2, 3.6, Transform3D(Basis(), Vector3(1.6, 1.8, -0.6)), m_poutres, 6, true)
	for i in 3:
		_boite(p, Vector3(0.44, 0.22, 0.44), Transform3D(Basis(Vector3.UP, i * 0.6), Vector3(1.6, 1.4 + i * 0.85, -0.6)), m_poutres)

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
		_boite(p, Vector3(demi.x * 2, 0.08, 0.08), Transform3D(Basis(), Vector3(0, y, -demi.y)), m_poutres, y < 0.6)
		_boite(p, Vector3(0.08, 0.08, demi.y * 2), Transform3D(Basis(), Vector3(-demi.x, y, 0)), m_poutres, y < 0.6)
		_boite(p, Vector3(0.08, 0.08, demi.y * 2), Transform3D(Basis(), Vector3(demi.x, y, 0)), m_poutres, y < 0.6)
		for cote in [-1.0, 1.0]:
			_boite(p, Vector3(2.2, 0.08, 0.08), Transform3D(Basis(), Vector3(cote * 2.4, y, demi.y)), m_poutres, y < 0.6)
	# meules de foin et séchoir à peaux
	for pos in [Vector3(-2.0, 0, -1.2), Vector3(-0.6, 0, -1.6), Vector3(1.8, 0, -1.0)]:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.8
		s.height = 1.1
		s.radial_segments = 7
		s.rings = 4
		mi.mesh = s
		mi.material_override = m_foin
		mi.position = pos + Vector3(0, 0.35, 0)
		p.add_child(mi)
	for x in [-1.2, 1.2]:
		_boite(p, Vector3(0.12, 2.0, 0.12), Transform3D(Basis(), Vector3(x, 1.0, demi.y + 2.2)), m_poutres)
	_boite(p, Vector3(2.6, 0.1, 0.1), Transform3D(Basis(), Vector3(0, 1.95, demi.y + 2.2)), m_poutres)
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
	# tas de bois de chauffage contre les maisons
	for base in [Vector3(-7.6, 0, -15.6), Vector3(8.6, 0, 9.8)]:
		for rang in 3:
			for k in 6 - rang:
				var pos: Vector3 = base + Vector3((k + rang * 0.5) * 0.3, 0.14 + rang * 0.26, 0)
				_cylindre(racine, 0.13, 0.13, 1.1, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), pos), m_ecorce, 6)
		_collision(racine, BoxShape3D.new(), Transform3D(Basis(), base + Vector3(0.8, 0.4, 0)), Vector3(2.0, 0.8, 1.1))
