extends Node3D
## Skarnholt : hameau nordique entouré d'une palissade.
## Repère local : sol plat en y = 0, +Z = la porte (tournée vers le feu de camp).
## Expose `lieux` (postes des villageois, en coordonnées monde) et `promenade`.

const RAYON := 22.0          # palissade
const DEMI_PORTE := 2.4      # demi-largeur de l'ouverture

var lieux := {}
var promenade: Array[Vector3] = []
var sedentaires: Array[String] = ["forge"]   # postes intérieurs : on n'en sort pas se promener

var corps: StaticBody3D
var rng := RandomNumberGenerator.new()
var _flammes: Array = []  # [OmniLight3D, énergie de base, décalage]
var _t := 0.0

var m_planches: ShaderMaterial
var m_poutres: ShaderMaterial
var m_poutres_h: ShaderMaterial
var m_neige: ShaderMaterial
var m_toit: ShaderMaterial
var m_rondins: ShaderMaterial
var m_bout: ShaderMaterial
var m_ame: ShaderMaterial
var m_roche: ShaderMaterial
var m_brute: ShaderMaterial
var m_pierre_fine: ShaderMaterial
var m_fer: ShaderMaterial
var m_foin: ShaderMaterial
var m_cuir: ShaderMaterial
var m_ecorce: ShaderMaterial
var m_fenetre: ShaderMaterial
var m_braises: ShaderMaterial
var m_eau: ShaderMaterial
var m_glace: ShaderMaterial
var mats_int: Dictionary                 # matières d'intérieur (Interieurs.materiaux)
var interieurs: Array[Interieur] = []    # un par bâtiment enterable : longue maison, 3 maisons, forge
var _nuit_vitre := -1.0
## Le mobilier des intérieurs se construit APRÈS le chargement, une maison par image (≈ 40-150 ms chacune) : le temps de
## chargement ne grandit pas (les maisons sont invisibles de loin, et le joueur démarre à plus de 13 m des portes).
var _differes: Array[Callable] = []
var prets := false           # vrai quand tous les intérieurs sont construits
signal interieurs_prets

func _ready() -> void:
	rng.seed = 99
	corps = StaticBody3D.new()
	add_child(corps)
	# Lot 5 (2e passe) : matières peintes à 32 texels/m, relief sur la normale, mipmaps nearest (TexturesBati)
	m_planches = TexturesBati.m_planches(Color(0.95, 0.93, 0.92))      # planches horizontales
	m_poutres = TexturesBati.m_bois_debout(Color(0.92, 0.9, 0.88))      # poteaux, portes, caisses (fil vertical)
	m_poutres_h = TexturesBati.m_planches(Color(0.9, 0.87, 0.85))       # solives, rives, dessous de toit
	m_rondins = TexturesBati.m_rondins(Color(1.3, 1.24, 1.18))
	m_bout = TexturesBati.m_bout_rondin()
	m_ame = TexturesBati.m_planches(Color(0.3, 0.29, 0.32))             # fond sombre derrière les rondins (joints)
	m_neige = TexturesBati.m_neige_toit()
	m_toit = TexturesBati.m_tourbe()                                    # toits : alpha 0 = neige, 1 = tourbe sombre
	m_roche = TexturesBati.m_pierre_seche(Color(1.3, 1.28, 1.32))
	m_brute = TexturesBati.m_pierre_brute(Color(1.18, 1.16, 1.2))
	m_pierre_fine = TexturesBati.m_pierre_fine(Color(1.25, 1.23, 1.27))
	m_fer = TexturesBati.m_fer(Color(0.8, 0.82, 0.9))
	m_foin = TexturesBati.m_foin(Color(0.85, 0.85, 0.8))
	m_cuir = TexturesBati.m_cuir(Color(1.3, 1.15, 1.0))
	m_ecorce = TexturesBati.m_ecorce()
	m_fenetre = TexturesBati.m_fenetre()
	m_braises = TexturesBati.m_braises()
	m_glace = TexturesBati.m_glace()
	m_eau = Palette.materiau(Palette.tex("eau", ["#05070c", "#0a0f18", "#101824", "#162030"], 4, 0.3))

	Chrono.marque("  village : matières bâti")
	mats_int = Interieurs.materiaux()
	Chrono.marque("  village : matières intérieur")
	_palissade()
	_porte()
	Chrono.marque("  village : palissade+porte")
	_maison(Vector3(0, 0, -12), 0.0, 14.0, 7.0, 2.2, 3.2, "halle")        # longue maison de la cheffe
	_maison(Vector3(-11.5, 0, -3), PI * 0.5, 8.0, 5.5, 2.0, 2.4, "sigrun")      # la voyante
	_maison(Vector3(11.5, 0, 7.5), -PI * 0.5, 8.0, 5.5, 2.0, 2.4, "chasseurs") # famille de chasseurs
	_maison(Vector3(-9.5, 0, 13.0), PI * 0.62, 7.0, 5.0, 1.9, 2.2, "grima")    # la doyenne
	Chrono.marque("  village : 4 maisons")
	_forge(Vector3(-12.5, 0, 6.0))
	Chrono.marque("  village : forge")
	_puits(Vector3(4.5, 0, 1.5))
	_brasero(Vector3(-2.5, 0, -2.5))
	_enclos(Vector3(11.5, 0, -6.5))
	_accessoires()
	Chrono.marque("  village : puits/enclos/accessoires")
	_finaliser()
	Chrono.marque("  village : maillages fusionnés")

	var postes := {
		"longue_maison": Vector3(1.2, 0, -7.4),
		"forge": Vector3(-12.15, 0.0, 5.65),   # dans la forge, à côté de l'enclume
		"puits": Vector3(6.0, 0, 2.6),
		"place": Vector3(-1.2, 0, -0.4),
		"enclos": Vector3(9.0, 0, -3.0),
		"porte": Vector3(2.2, 0, RAYON - 2.4),
	}
	for nom in postes:
		lieux[nom] = to_global(postes[nom])
		if nom != "forge":
			promenade.append(lieux[nom])   # personne d'autre ne se promène dans la forge
	for p in [Vector3(0, 0, 6), Vector3(-5, 0, 3), Vector3(6, 0, -5), Vector3(-4, 0, -7)]:
		promenade.append(to_global(p))

## Pose les objets « porte » (touche E) des bâtiments ; appelé par le monde quand joueur et dialogue existent.
func activer_interieurs(joueur: CharacterBody3D, dialogue: Control) -> void:
	for ip in interieurs:
		ip.activer(joueur, dialogue)

## Intérieur dont le nom d'id est `id` (« halle », « sigrun », « chasseurs », « grima », « forge »).
func interieur(id: String) -> Interieur:
	for ip in interieurs:
		if ip.nom == NOMS_BATIMENTS[id]:
			return ip
	return null

func _process(dt: float) -> void:
	_t += dt
	if not _differes.is_empty():
		_differes.pop_front().call()
		if _differes.is_empty():
			prets = true
			interieurs_prets.emit()
	# vitrages : s'allument la nuit (vus du dehors)
	var cyc = get_parent().get("cycle") if get_parent() != null else null
	if cyc != null and mats_int.has("vitre"):
		var n: float = 1.0 - cyc.clarte()
		if absf(n - _nuit_vitre) > 0.01:
			_nuit_vitre = n
			(mats_int["vitre"] as ShaderMaterial).set_shader_parameter("nuit", n)
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

## Occlusion peinte au pied de tout ce qui touche le sol (y local 0 = sol du village) : le bas des murs, des
## poteaux et des pierres s'assombrit (éclaboussures, ombre de contact).
func _ao_pied(y: float) -> float:
	return 0.66 + 0.34 * smoothstep(0.0, 0.8, y)

func _ajouter(parent: Node3D, arrays: Array, xf: Transform3D, mat: Material, ao_sol := true) -> void:
	var cle := "%d|%d" % [parent.get_instance_id(), mat.get_instance_id()]
	if not _lots.has(cle):
		_lots[cle] = {"parent": parent, "mat": mat, "v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
	var lot: Dictionary = _lots[cle]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	# les tableaux « Packed » sont des valeurs : on les sort du dictionnaire, on les remplit, on les range
	var v: PackedVector3Array = lot["v"]
	var n: PackedVector3Array = lot["n"]
	var uvs: PackedVector2Array = lot["u"]
	var cols: PackedColorArray = lot["c"]
	var uv_src: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var c_src: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var ii: PackedInt32Array = lot["i"]
	var base := v.size()
	var pivot_y := 0.0   # le pivot du bâtiment est posé au sol : y local = hauteur au-dessus du sol
	for k in verts.size():
		var pw := xf * verts[k]
		v.append(pw)
		n.append((xf.basis * norms[k]).normalized())
		uvs.append(uv_src[k] if k < uv_src.size() else Vector2.ZERO)
		var c := c_src[k] if k < c_src.size() else Color.WHITE
		if ao_sol:
			var g := _ao_pied(pw.y - pivot_y)
			c = Color(c.r * g, c.g * g, c.b * g, c.a)
		cols.append(c)
	if index.is_empty():
		for k in verts.size():
			ii.append(base + k)
	else:
		for k in index:
			ii.append(base + k)
	lot["v"] = v
	lot["n"] = n
	lot["u"] = uvs
	lot["c"] = cols
	lot["i"] = ii

func _finaliser() -> void:
	for cle in _lots:
		var lot: Dictionary = _lots[cle]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = lot["v"]
		arrays[Mesh.ARRAY_NORMAL] = lot["n"]
		arrays[Mesh.ARRAY_TEX_UV] = lot["u"]
		arrays[Mesh.ARRAY_COLOR] = lot["c"]
		arrays[Mesh.ARRAY_INDEX] = lot["i"]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = lot["mat"]
		if (lot["parent"] as Node3D).get_parent() is Interieur:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # l'intérieur ne projette rien (coût de l'ombre du soleil)
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
	_ajouter(parent, arrays, Transform3D(), m_poutres)

# --- bâtiments ---------------------------------------------------------------------
# Lot 5. Structure modulaire (grille de 2 m : contreforts, bouts de solives, poteaux) ; textures en mètres
# (TexturesBati) : la même densité de pixels sur la pierre, le bois et la neige.

## Pile de moellons : `taille` (x, y, z) en rangs de ~42 cm de blocs irréguliers aux joints décalés ; collision = une boîte.
func _pile(parent: Node3D, pos: Vector3, taille: Vector3, graine: int, mat: Material, solide := false, neige_haut := 0.5, lacet := 0.0) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var rangs := maxi(1, roundi(taille.y / 0.42))
	var hh := taille.y / rangs
	var basis := Basis(Vector3.UP, lacet)
	for k in rangs:
		var x := -taille.x * 0.5 - r.randf_range(0.0, 0.4)
		while x < taille.x * 0.5:
			var w := r.randf_range(0.55, 0.95)
			var x0 := maxf(x, -taille.x * 0.5)
			var x1 := minf(x + w, taille.x * 0.5)
			x += w * 0.97
			if x1 - x0 < 0.2:
				continue
			var c := Vector3((x0 + x1) * 0.5, -taille.y * 0.5 + hh * (k + 0.5), r.randf_range(-0.03, 0.03))
			_ajouter(parent, BatiGeo.bloc(Vector3(x1 - x0, hh * 1.04, taille.z), r.randi(), 0.2, 0.06, neige_haut if k == rangs - 1 else 0.0).arrays(), Transform3D(basis, pos + basis * c), mat)
	if solide:
		_collision(parent, BoxShape3D.new(), Transform3D(basis, pos), taille)

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
	Torche.flamme_fixe(parent, haut + Vector3(0, 0.2, 0), 1.3, absf(sin(pos.x * 12.9898 + pos.z * 78.233)) * 4.0)   # même flamme que partout (lot 6bis)
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

## Bloc de pierre irrégulier (chanfreiné, facettes plates) ajouté au lot (parent, matière).
func _bloc(parent: Node3D, taille: Vector3, graine: int, pos: Vector3, mat: Material, lacet := 0.0, neige := 0.0, chanfrein := 0.22, jitter := 0.07, solide := false) -> void:
	_ajouter(parent, BatiGeo.bloc(taille, graine, chanfrein, jitter, neige).arrays(), Transform3D(Basis(Vector3.UP, lacet), pos), mat)
	if solide:
		_collision(parent, BoxShape3D.new(), Transform3D(Basis(Vector3.UP, lacet), pos), taille)

## Rondin à 8 pans : fût (matière rondins) + deux bouts (matière bout_rondin). `lacet` PI/2 = le long de Z.
## Si `interieur` est donné (rondin d'un mur de maison), le fût est coupé en deux : la moitié tournée vers `dehors`
## (+1 ou -1 selon Z local du rondin) reste à l'extérieur, l'autre (vue de la pièce) rejoint l'intérieur et prend la
## matière « intérieur » (pas de lumière ambiante du ciel dans la pièce).
func _rondin(parent: Node3D, pos: Vector3, lacet: float, longueur: float, rayon: float, graine: int, teinte := 1.0, sag := 0.02, interieur: Interieur = null, dehors := 1.0) -> void:
	var rr := RandomNumberGenerator.new()
	rr.seed = graine
	var r := BatiGeo.rondin(longueur, rayon, graine, sag, rr.randi_range(0, 3), rr.randf() * 8.0, teinte)
	var xf := Transform3D(Basis(Vector3.UP, lacet), pos)
	if interieur == null:
		_ajouter(parent, (r[0] as BatiGeo.Maillage).arrays(), xf, m_rondins)
	else:
		var fut: BatiGeo.Maillage = r[0]
		var ext := BatiGeo.Maillage.new()
		var dedans := BatiGeo.Maillage.new()
		for i in range(0, fut.v.size(), 3):
			var cible := ext if fut.n[i].z * dehors > -0.3 else dedans
			for k in 3:
				cible.v.append(fut.v[i + k])
				cible.n.append(fut.n[i + k])
				cible.uv.append(fut.uv[i + k])
				cible.c.append(fut.c[i + k])
		_ajouter(parent, ext.arrays(), xf, m_rondins)
		_ajouter(interieur.racine, dedans.arrays(), xf, mats_int["rondin"])
	_ajouter(parent, (r[1] as BatiGeo.Maillage).arrays(), xf, m_bout)

## Soubassement : remplissage en retrait + pierres brutes en saillie irrégulière (5 à 15 cm), dessus à ~0,4 m.
func _soubassement(p: Node3D, L: float, W: float, graine: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	_boite(p, Vector3(L + 0.42, 0.75, W + 0.42), Transform3D(Basis(), Vector3(0, 0.025, 0)), m_pierre_fine)
	for cote in 4:
		var horiz := cote < 2
		var sgn := -1.0 if cote % 2 == 0 else 1.0
		var long_ := (L if horiz else W) + 0.5
		var demi := (W if horiz else L) * 0.5
		var t := -long_ * 0.5
		while t < long_ * 0.5:
			var lg := r.randf_range(0.55, 1.05)
			var hh := r.randf_range(0.55, 0.72)
			var prof := r.randf_range(0.36, 0.52)
			var saillie := r.randf_range(0.02, 0.15)
			var haut := r.randf_range(0.38, 0.5)
			var a := t + lg * 0.5
			t += lg * 0.96
			if horiz and sgn > 0.0 and absf(a) < 1.45:
				continue   # les marches de la porte
			var ext := demi + 0.15 + saillie - prof * 0.5 + 0.05
			var pos := Vector3(a, haut - hh * 0.5, sgn * ext) if horiz else Vector3(sgn * ext, haut - hh * 0.5, a)
			var taille := Vector3(lg, hh, prof) if horiz else Vector3(prof, hh, lg)
			_bloc(p, taille, r.randi(), pos, m_brute, 0.0, 0.22, 0.2, 0.08)

## Hauteur d'une rangée de rondins (lit k) et rangées traversées par les fenêtres.
const LITS_FENETRE := [4, 5]
func _y_lit(k: int, h_murs: float) -> float:
	var nk := roundi((h_murs - 0.30) / 0.25) + 1
	return 0.4 + 0.15 + k * (h_murs - 0.30) / (nk - 1)

## Intervalles [a, b] d'une rangée de longueur [-xl, xl] une fois ôtées les ouvertures `coupes` ([x0, x1]).
func _segments(xl: float, coupes: Array) -> Array:
	var segs := []
	var x := -xl
	var tri := coupes.duplicate()
	tri.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for c in tri:
		if c[0] > x + 0.05:
			segs.append([x, c[0]])
		x = maxf(x, c[1])
	if xl > x + 0.05:
		segs.append([x, xl])
	return segs

## Murs en rondins de 30 cm à 8 pans, empilés tous les 25 cm, croisés aux angles (bouts qui dépassent de 28 cm,
## alternés d'un lit à l'autre) ; ouverture de la porte (1,2 × 2 m) dans le long pan +Z, fenêtres de 0,7 × 0,55 m
## (lits 4 et 5) aux abscisses `fenetres` des deux longs pans. Chaque rondin est coupé aux ouvertures ; sa moitié
## visible de la pièce passe dans `ip` (matière d'intérieur).
func _murs_rondins(p: Node3D, ip: Interieur, L: float, W: float, h_murs: float, graine: int, fenetres: Array, demi_porte := 0.62) -> int:
	var nk := roundi((h_murs - 0.30) / 0.25) + 1
	for k in nk:
		var y := _y_lit(k, h_murs)
		var long_deborde := k % 2 == 0
		var xl := L * 0.5 + (0.15 + 0.28 if long_deborde else 0.0)
		var zl := W * 0.5 + (0.0 if long_deborde else 0.15 + 0.28)
		# sous les rives : le haut des murs est dans l'ombre du toit, le pied est sali
		var teinte := 1.0 - 0.2 * smoothstep(nk - 4.0, nk - 1.0, k)
		var g := graine * 100 + k * 8
		var fen: Array = []
		if k in LITS_FENETRE:
			for x in fenetres:
				fen.append([x - 0.35, x + 0.35])
		for cote in [-1.0, 1.0]:
			var coupes := fen.duplicate()
			if cote > 0.0 and k <= nk - 2:
				coupes.append([-demi_porte, demi_porte])
			var n := 0
			for seg in _segments(xl, coupes):
				_rondin(p, Vector3((seg[0] + seg[1]) * 0.5, y, cote * W * 0.5), 0.0, seg[1] - seg[0], 0.15, g + 1 + n * 3 + int(cote + 1.0) * 11, teinte, 0.02, ip, cote)
				n += 1
			_rondin(p, Vector3(cote * L * 0.5, y, 0), PI * 0.5, zl * 2.0, 0.15, g + 5 + int(cote), teinte, 0.02, ip, cote)
	return nk

## Âme du mur (fond sombre vu dans les joints entre rondins) : quatre cloisons de 20 cm au plan des murs, percées de
## la porte et des fenêtres (le mur n'est plus un bloc plein : la pièce est creuse).
func _ame(p: Node3D, L: float, W: float, h_murs: float, fenetres: Array, demi_porte := 0.62) -> void:
	var y_haut := 0.4 + h_murs
	var fy0 := _y_lit(LITS_FENETRE[0], h_murs) - 0.15
	var fy1 := _y_lit(LITS_FENETRE[1], h_murs) + 0.15
	for cote in [-1.0, 1.0]:
		var coupes: Array = []
		for x in fenetres:
			coupes.append([x - 0.35, x + 0.35, fy0, fy1])
		if cote > 0.0:
			coupes.append([-demi_porte, demi_porte, 0.4, 0.4 + 2.0])
		var bords := [-L * 0.5, L * 0.5]
		for c in coupes:
			bords.append(c[0])
			bords.append(c[1])
		bords.sort()
		for i in bords.size() - 1:
			var xa: float = bords[i]
			var xb: float = bords[i + 1]
			if xb - xa < 0.01:
				continue
			var xm := (xa + xb) * 0.5
			var morceaux := [[0.4, y_haut]]
			for c in coupes:
				if xm > c[0] and xm < c[1]:
					morceaux = []
					if c[2] > 0.41:
						morceaux.append([0.4, c[2]])
					morceaux.append([c[3], y_haut])
			for mo in morceaux:
				_boite(p, Vector3(xb - xa, mo[1] - mo[0], 0.2), Transform3D(Basis(), Vector3(xm, (mo[0] + mo[1]) * 0.5, cote * W * 0.5)), m_ame)
	for cote in [-1.0, 1.0]:
		_boite(p, Vector3(0.2, h_murs, W), Transform3D(Basis(), Vector3(cote * L * 0.5, 0.4 + h_murs * 0.5, 0)), m_ame)

## Fenêtre encadrée de 0,7 × 0,55 m (linteau, appui en saillie, jambages), vitrage TRANSLUCIDE (plan `ps1_vitre`) et
## volet entrouvert ; `face` = +1 (côté +Z) ou -1. Le cadre côté pièce est posé par `Interieurs.fenetre_cadre`.
func _fenetre_cadre(p: Node3D, x: float, y: float, z: float, face: float) -> void:
	_vitre(p, Vector3(x, y, z - 0.17 * face), Vector2(0.7, 0.55), 0.0 if face > 0.0 else PI)
	_boite(p, Vector3(0.92, 0.1, 0.16), Transform3D(Basis(), Vector3(x, y + 0.325, z + 0.05 * face)), m_poutres_h)
	_boite(p, Vector3(0.96, 0.08, 0.26), Transform3D(Basis(Vector3.RIGHT, 0.12 * face), Vector3(x, y - 0.33, z + 0.09 * face)), m_poutres_h)
	for fx in [-0.4, 0.4]:
		_boite(p, Vector3(0.1, 0.62, 0.15), Transform3D(Basis(), Vector3(x + fx, y, z + 0.045 * face)), m_poutres_h)
	# volet entrouvert
	_boite(p, Vector3(0.34, 0.56, 0.04), Transform3D(Basis(Vector3.UP, 1.1 * face * signf(x + 0.001)), Vector3(x + 0.62 * signf(x + 0.001), y, z + 0.18 * face)), m_poutres)

## Un pan de toit : planches dessous, chevrons qui dépassent, dalle de neige à épaisseur (BatiGeo.dalle_neige),
## rives croisées en cornes. `Rp` = point du faîte, `d` = vecteur faîte → égout (x nul). Renvoie le repère du pan.
## `trou` = (x0, x1) : trou à fumée au faîte (premier rang de la dalle, planches et chevrons coupés).
func _pan(p: Node3D, Rp: Vector3, d: Vector3, Lx: float, graine: int, L_murs: float, cornes := true, trou := Vector2.ZERO) -> Transform3D:
	var Sl := d.length()
	var t := d / Sl
	var nrm := Vector3(0, t.z, -t.y)
	if nrm.y < 0.0:
		nrm = -nrm
	var bx := Vector3.RIGHT * (1.0 if d.z > 0.0 else -1.0)
	var xf := Transform3D(Basis(bx, nrm, t), Rp)
	var sh := Sl / 5.0     # profondeur du trou : un rang de la dalle
	if trou == Vector2.ZERO:
		_boite(p, Vector3(Lx - 0.1, 0.09, Sl + 0.12), xf * Transform3D(Basis(), Vector3(0, -0.05, Sl * 0.5)), m_poutres_h)
	else:
		var xa := -Lx * 0.5 + 0.05
		var xb := Lx * 0.5 - 0.05
		_boite(p, Vector3(trou.x - xa, 0.09, Sl + 0.12), xf * Transform3D(Basis(), Vector3((xa + trou.x) * 0.5, -0.05, Sl * 0.5)), m_poutres_h)
		_boite(p, Vector3(xb - trou.y, 0.09, Sl + 0.12), xf * Transform3D(Basis(), Vector3((trou.y + xb) * 0.5, -0.05, Sl * 0.5)), m_poutres_h)
		var lm := Sl + 0.06 - sh
		_boite(p, Vector3(trou.y - trou.x, 0.09, lm), xf * Transform3D(Basis(), Vector3((trou.x + trou.y) * 0.5, -0.05, sh + lm * 0.5)), m_poutres_h)
	var x := -Lx * 0.5 + 0.2
	while x <= Lx * 0.5 - 0.15:
		var dans := trou != Vector2.ZERO and x > trou.x - 0.06 and x < trou.y + 0.06
		var l_ch := Sl + 0.3 - (sh if dans else 0.0)
		var s_c := Sl * 0.5 + 0.04 + (sh * 0.5 if dans else 0.0)
		_boite(p, Vector3(0.11, 0.17, l_ch), xf * Transform3D(Basis(), Vector3(x, -0.15, s_c)), m_poutres_h)
		x += 0.9
	_ajouter(p, BatiGeo.dalle_neige(Lx, Sl, graine, 0.22, 0.05, trou).surface_get_arrays(0), xf, m_toit)
	if cornes:
		for bout in [-1.0, 1.0]:
			var rive := Transform3D(Basis(bx, nrm, t), Rp + bx * (bout * (Lx * 0.5 - 0.1)) + nrm * 0.02)
			_boite(p, Vector3(0.14, 0.3, Sl + 0.5), rive * Transform3D(Basis(), Vector3(0, -0.02, Sl * 0.5 - 0.15)), m_poutres_h)
	return xf

## Toit en deux pans (lot 5, 2e passe) : chevrons qui dépassent, planches dessous, dalle de neige à épaisseur et à
## bord irrégulier (tourbe sombre à la lèvre), faîtière en rondin dont les bouts sortent des pignons et rouleau
## de neige au faîte ; rives croisées en cornes. `trou` : trou à fumée (voir `_pan`) ; la faîtière et le rouleau
## s'interrompent de part et d'autre.
func _toit(p: Node3D, L: float, W: float, y0: float, faite: float, graine: int, trou := Vector2.ZERO) -> Vector2:
	var avancee := 0.78
	var Rp := Vector3(0, y0 + faite, 0)
	var eave_z := W * 0.5 + avancee
	var Lx := L + 1.5
	var bas_y := y0 - 0.5
	for cote in [-1.0, 1.0]:
		_pan(p, Rp, Vector3(0, bas_y - Rp.y, cote * eave_z), Lx, graine * 7 + int(cote) + 3, L, true, trou)
		_stalactites(p, -L * 0.5 - 0.5, L * 0.5 + 0.5, bas_y - 0.12, cote * (eave_z + 0.06), graine * 31 + int(cote))
	# faîtière : rondin qui dépasse des pignons + rouleau de neige
	var morceaux: Array = [[-(L + 2.1) * 0.5, (L + 2.1) * 0.5]]
	var rouleaux: Array = [[-(L + 1.5) * 0.5, (L + 1.5) * 0.5]]
	if trou != Vector2.ZERO:
		morceaux = [[-(L + 2.1) * 0.5, trou.x - 0.05], [trou.y + 0.05, (L + 2.1) * 0.5]]
		rouleaux = [[-(L + 1.5) * 0.5, trou.x - 0.1], [trou.y + 0.1, (L + 1.5) * 0.5]]
	var k := 0
	for m in morceaux:
		_rondin(p, Rp + Vector3((m[0] + m[1]) * 0.5, 0.02, 0), 0.0, m[1] - m[0], 0.13, graine + 9 + k, 1.0, 0.03)
		k += 1
	for m in rouleaux:
		var roul := BatiGeo.rondin(m[1] - m[0], 0.19, graine + 11 + k, 0.05, 0, 0.0, 1.0)
		_ajouter(p, (roul[0] as BatiGeo.Maillage).arrays(), Transform3D(Basis(), Rp + Vector3((m[0] + m[1]) * 0.5, 0.2, 0)), m_neige)
		k += 1
	return Vector2(eave_z, bas_y)

## Cheminée de pierre : fût en petits moellons, chaînages d'angle en gros blocs alternés, base évasée, chapeau
## enneigé qui déborde.
func _cheminee(p: Node3D, xch: float, y_base: float, h_ch: float, graine: int) -> void:
	_boite(p, Vector3(0.72, h_ch, 0.72), Transform3D(Basis(), Vector3(xch, y_base + h_ch * 0.5, 0)), m_pierre_fine)
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var n := int(h_ch / 0.4)
	for i in n:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var gros := (i + (0 if sx * sz > 0 else 1)) % 2 == 0
				var sc := Vector3(0.34 if gros else 0.26, 0.38, 0.26 if gros else 0.34)
				_bloc(p, sc, r.randi(), Vector3(xch + sx * 0.33, y_base + 0.2 + i * 0.4, sz * 0.33), m_brute, 0.0, 0.0, 0.2, 0.09)
	_bloc(p, Vector3(1.05, 0.5, 1.05), r.randi(), Vector3(xch, y_base + 0.0, 0), m_brute, 0.0, 0.0, 0.18, 0.05)
	_bloc(p, Vector3(1.12, 0.2, 1.12), r.randi(), Vector3(xch, y_base + h_ch + 0.05, 0), m_brute, 0.0, 1.0, 0.25, 0.04)

## Noms affichés (porte) des bâtiments enterables.
const NOMS_BATIMENTS := {
	"halle": "Halle de Gunnhild",
	"sigrun": "Maison de Sigrún la Voyante",
	"chasseurs": "Maison des chasseurs",
	"grima": "Maison de Grima Cendrefroide",
	"forge": "Forge de Brodd",
}

## Abscisses des fenêtres (sur les deux longs pans) d'une maison de longueur L.
func _fenetres_de(longueur: float) -> Array:
	return [-longueur * 0.26, longueur * 0.26]

## Maison nordique (lot 5, 2e passe) : soubassement de pierres brutes en saillie, murs de rondins à 8 pans croisés
## aux angles sur âme sombre, contreforts de pierre, toit à épaisseur (chevrons, faîtière, rives en cornes,
## stalactites), cheminée de pierre appareillée, porte renforcée de fer dans un cadre épais, deux marches,
## fenêtres encadrées à volet, torche murale et fumée.
## Lot « kit intérieur » : la maison est CREUSE et ENTERABLE (murs de rondins vus des deux côtés, plancher, plafond sous
## charpente, porte sur charnière, fenêtres ouvertes aux carreaux translucides) ; l'intérieur (`Interieur` + `Interieurs`)
## dépend de `id` : halle (longue maison), sigrun, chasseurs, grima.
func _maison(centre: Vector3, lacet: float, longueur: float, largeur: float, h_murs: float, faite: float, id: String) -> void:
	var cheffe := id == "halle"
	var p := _pivot(centre, lacet)
	p.name = "Maison_" + id
	h_murs = maxf(h_murs, 2.3)   # porte de 2 m + linteau : 9 lits de rondins
	var y0 := 0.4 + h_murs
	var graine := int(absf(centre.x) * 13.0 + absf(centre.z) * 7.0) + 1
	var ip := Interieur.new()
	ip.name = "Interieur"
	ip.nom = NOMS_BATIMENTS[id]
	ip.demi = Vector2(longueur * 0.5 - 0.15, largeur * 0.5 - 0.15)
	ip.porte_locale = Vector3(0, 1.4, largeur * 0.5 + 0.05)
	p.add_child(ip)
	interieurs.append(ip)
	var ib := Interieurs.new(self, ip, mats_int, longueur, largeur, h_murs, faite)
	var fen := _fenetres_de(longueur)
	_soubassement(p, longueur, largeur, graine)
	_ame(p, longueur, largeur, h_murs, fen)
	_murs_rondins(p, ip, longueur, largeur, h_murs, graine, fen)
	for cote in [-1.0, 1.0]:
		_pignon(p, cote * longueur * 0.5, y0, largeur * 0.5 + 0.1, faite)
	# contreforts de pierre sur les longs pans, à (L/2 - 1)
	var rc := RandomNumberGenerator.new()
	rc.seed = graine + 77
	for cote in [-1.0, 1.0]:
		for xc in [-(longueur * 0.5 - 1.0), longueur * 0.5 - 1.0]:
			var zc: float = cote * (largeur * 0.5 + 0.15 + 0.3)
			for i in 4:
				var s := 0.64 - i * 0.05
				_bloc(p, Vector3(s, 0.44 - i * 0.02, s * 0.9), rc.randi(), Vector3(xc + rc.randf_range(-0.03, 0.03), 0.3 + i * 0.4, zc), m_brute, rc.randf_range(-0.06, 0.06), 0.05, 0.2, 0.07)
			_bloc(p, Vector3(0.72, 0.2, 0.66), rc.randi(), Vector3(xc, 1.95, zc), m_brute, 0.0, 1.0, 0.3, 0.05)
			_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(xc, 1.1, zc)), Vector3(0.76, 2.2, 0.72))
	_coque_collisions(p, longueur, largeur, y0, faite)
	# trou à fumée de la halle : deux cases de la dalle, de part et d'autre du faîte
	var trou := Vector2.ZERO
	if cheffe:
		trou = BatiGeo.trou_cases(longueur + 1.5, -1.0, 2)
	var eave := _toit(p, longueur, largeur, y0, faite, graine, trou)
	if cheffe:
		ib.gaine_fumee(trou)
		_fumee(p, Vector3((trou.x + trou.y) * 0.5, y0 + faite + 1.3, 0))
	else:
		var xch := longueur * 0.15
		var h_ch := faite + 0.7
		_cheminee(p, xch, y0 - 0.2, h_ch, graine + 5)
		_fumee(p, Vector3(xch, y0 + h_ch + 0.2, 0))
	# porte (côté +Z) : cadre épais, vantail sur charnière (planches debout, bandes de fer, anneau), marches de 20 cm
	var zf := largeur * 0.5 + 0.17
	for jx in [-0.7, 0.7]:
		_boite(p, Vector3(0.2, 2.05, 0.34), Transform3D(Basis(), Vector3(jx, 0.4 + 1.02, largeur * 0.5 + 0.01)), m_poutres_h)
	_boite(p, Vector3(1.8, 0.2, 0.36), Transform3D(Basis(), Vector3(0, 0.4 + 2.1, largeur * 0.5 + 0.01)), m_poutres_h)
	var charniere := _vantail(p, Vector3(-0.6, 0.4, largeur * 0.5), 1.2, 2.0)
	ip.vantaux.append([charniere, -1.75])
	_bloc(p, Vector3(1.95, 0.2, 0.62), rc.randi(), Vector3(0, 0.1, zf + 0.5), m_brute, 0.0, 0.5, 0.2, 0.05)
	_bloc(p, Vector3(1.65, 0.2, 0.42), rc.randi(), Vector3(0, 0.3, zf + 0.26), m_brute, 0.0, 0.5, 0.2, 0.05)
	_rampe_porte(p, Vector3(0, 0, largeur * 0.5), 1.8)
	_bloc_porte(ip, p, Vector3(0, 0.4 + 1.25, largeur * 0.5), Vector3(1.24, 2.5, 0.3))
	# fenêtres (cadre extérieur ici, cadre intérieur par Interieurs)
	var yf := (_y_lit(LITS_FENETRE[0], h_murs) + _y_lit(LITS_FENETRE[1], h_murs)) * 0.5
	for x in fen:
		for face in [1.0, -1.0]:
			_fenetre_cadre(p, x, yf, face * (largeur * 0.5 + 0.17), face)
			ib.fenetre_cadre(x, yf, face * (largeur * 0.5 + 0.17), face)
	# torche murale à droite de la porte
	_torche_murale(p, Vector3(1.25, 0.4 + 1.45, zf + 0.03), 1.0, cheffe)   # une vraie lumière à la porte de la halle (comme avant)
	if cheffe:
		# boucliers peints accrochés au mur, de part et d'autre de la porte, et bancs
		for x in [-2.6, -1.7, 1.9, 2.7]:
			_cylindre(p, 0.38, 0.38, 0.06, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.4 + 1.3, zf + 0.06)), m_cuir if x < 0 else m_fer, 8)
			_cylindre(p, 0.09, 0.09, 0.09, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.4 + 1.3, zf + 0.1)), m_fer, 8)
		_banc(p, Vector3(-2.2, 0, zf + 0.75), 2.0)
		_banc(p, Vector3(2.2, 0, zf + 0.75), 2.0)
	# l'intérieur (plafond, mobilier, lumières) : construit après le chargement, une maison par image
	Chrono.marque("  maison %s : coque extérieure" % id)
	_differes.append(func() -> void:
		ib.coque(id)
		ib.contenu(id)
		ib.finir()
		_finaliser())

## Vantail de porte sur charnière : planches debout, deux bandes de fer cloutées, anneau. `pos` = axe de la charnière.
func _vantail(parent: Node3D, pos: Vector3, larg: float, haut: float, cote := 1.0) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	parent.add_child(h)
	var x := cote * larg * 0.5
	_boite(h, Vector3(larg - 0.06, haut, 0.1), Transform3D(Basis(), Vector3(x, haut * 0.5, 0)), m_poutres)
	for by in [0.22, haut * 0.74]:
		_boite(h, Vector3(larg - 0.06, 0.13, 0.04), Transform3D(Basis(), Vector3(x, by, 0.07)), m_fer)
		_boite(h, Vector3(larg - 0.06, 0.13, 0.04), Transform3D(Basis(), Vector3(x, by, -0.07)), m_fer)
		for rx in [-0.4, 0.0, 0.4]:
			_boite(h, Vector3(0.04, 0.04, 0.03), Transform3D(Basis(), Vector3(x + rx * larg / 1.2, by, 0.09)), m_fer)
	_boite(h, Vector3(0.09, 0.22, 0.05), Transform3D(Basis(), Vector3(x + cote * (larg * 0.5 - 0.2), haut * 0.5, 0.1)), m_fer)
	_boite(h, Vector3(0.09, 0.22, 0.05), Transform3D(Basis(), Vector3(x + cote * (larg * 0.5 - 0.2), haut * 0.5, -0.1)), m_fer)
	return h

## Rampe de collision sous les deux marches de la porte (le joueur n'a pas de montée de marche) : de 0 à F sur 1 m.
func _rampe_porte(p: Node3D, plan: Vector3, larg: float) -> void:
	var f := ConvexPolygonShape3D.new()
	var y := Interieurs.F
	f.points = PackedVector3Array([
		Vector3(-larg * 0.5, 0, 1.0), Vector3(larg * 0.5, 0, 1.0), Vector3(-larg * 0.5, y, 0.0), Vector3(larg * 0.5, y, 0.0),
		Vector3(-larg * 0.5, 0, 0.0), Vector3(larg * 0.5, 0, 0.0)])
	_collision(p, f, Transform3D(Basis(), plan + Vector3(0, 0, 0.1)), Vector3.ZERO)

## Blocage de la porte fermée (désactivé à l'ouverture).
func _bloc_porte(ip: Interieur, p: Node3D, pos: Vector3, taille: Vector3) -> void:
	_collision(p, BoxShape3D.new(), Transform3D(Basis(), pos), taille)
	ip.bloc_porte = corps.get_child(corps.get_child_count() - 1) as CollisionShape3D

## Collisions de la coque : plancher, quatre murs creux (ouverture de la porte côté +Z), linteau, sommet.
func _coque_collisions(p: Node3D, L: float, W: float, y0: float, faite: float, demi_porte := 0.62, epaisseur := 0.5) -> void:
	var haut := y0 + faite + 0.5
	_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, Interieurs.F * 0.5 - 0.3, 0)), Vector3(L - 0.2, Interieurs.F + 0.6, W + 0.3))
	# longs pans (le long de X) : décalés vers l'extérieur de 0,1 m pour ne pas rogner la pièce
	for cote in [-1.0, 1.0]:
		var zc: float = cote * (W * 0.5 + 0.1)
		if cote > 0.0:
			var xa := demi_porte
			var xb := L * 0.5 + 0.3
			for sx in [-1.0, 1.0]:
				_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(sx * (xa + xb) * 0.5, haut * 0.5, zc)), Vector3(xb - xa, haut, epaisseur))
			_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, (2.4 + haut) * 0.5, zc)), Vector3(demi_porte * 2.0, haut - 2.4, epaisseur))
		else:
			_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(0, haut * 0.5, zc)), Vector3(L + 0.6, haut, epaisseur))
		_collision(p, BoxShape3D.new(), Transform3D(Basis(), Vector3(cote * (L * 0.5 + 0.1), haut * 0.5, 0)), Vector3(epaisseur, haut, W + 0.6))

## Vitrage : quad orienté vers +Z (lacet 0) ou -Z (lacet PI), UV 0..1 (la texture de vitrage le couvre exactement).
func _vitre(parent: Node3D, pos: Vector3, taille: Vector2, lacet: float) -> void:
	var q := QuadMesh.new()
	q.size = taille
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mats_int["vitre"]
	mi.transform = Transform3D(Basis(Vector3.UP, lacet), pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

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
		_bloc(p, Vector3(1.05, 0.55, 1.05), 4500 + int(x * 3.0), Vector3(x, 0.1, 0), m_brute, 0.1, 0.4, 0.2, 0.07)
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

## Forge de Brodd (lot « kit intérieur » : fermée et enterable). Appentis de 5 × 4 m : quatre poteaux octogonaux, toit à
## une pente, mur de fond en pierre, murs latéraux de pierre sèche, façade de planches (double porte à deux vantaux,
## fenêtre à volet relevé). Foyer, enclume, soufflet, bac de trempe, réserves : `InterieurForge`.
## Repère local : -Z = le fond (foyer), +Z = la façade ; le sol est au niveau du village (y = 0), sans marche.
func _forge(centre: Vector3) -> void:
	var p := _pivot(centre, PI * 0.5)
	p.name = "Forge"
	var ip := Interieur.new()
	ip.name = "Interieur"
	ip.nom = NOMS_BATIMENTS["forge"]
	ip.demi = Vector2(2.1, 1.7)
	ip.porte_locale = Vector3(1.35, 1.3, 1.85)
	ip.sol_y = 0.04
	p.add_child(ip)
	interieurs.append(ip)
	var ib := Interieurs.new(self, ip, mats_int, 4.2, 3.4, 2.0, 0.6)
	# poteaux octogonaux (le mur de pierre les enserre) et toit à une pente
	for x in [-2.4, 2.4]:
		for z in [-1.8, 1.8]:
			_poteau(p, Vector3(x, 0, z), 0.13, 2.7 if z < 0 else 2.2, m_poutres, false)
	_pan(p, Vector3(0, 2.72, -2.3), Vector3(0, -0.63, 4.55), 5.9, 4242, 5.0, false)
	for z in [-1.8, 1.8]:   # sablières
		_boite(p, Vector3(5.2, 0.22, 0.26), Transform3D(Basis(), Vector3(0, 2.7 if z < 0 else 2.2, z) + Vector3(0, -0.12, 0)), m_poutres_h)
	# mur de fond en pierre derrière le foyer, avec contreforts
	_pile(p, Vector3(0, 1.2, -2.0), Vector3(4.8, 2.4, 0.5), 4301, m_brute, true)
	for x in [-2.4, 0.0, 2.4]:
		_pile(p, Vector3(x, 1.0, -2.4), Vector3(0.6, 2.0, 0.3), 4310 + int(x), m_brute, false, 1.0)   # contreforts : côté dehors seulement
	# murs latéraux : pierre sèche en trois tronçons qui suivent la pente du toit (plein haut sous les chevrons)
	var tronc := [[-2.0, -0.6, 2.4], [-0.6, 0.8, 2.2], [0.8, 1.9, 2.04]]
	for sx in [-1.0, 1.0]:
		var k := 0
		for t in tronc:
			var zc: float = (t[0] + t[1]) * 0.5
			_pile(p, Vector3(sx * 2.4, t[2] * 0.5, zc), Vector3(0.4, t[2], t[1] - t[0]), 4400 + k + int(sx + 1.0) * 5, m_roche, true, 0.0)
			k += 1
	# façade de planches : de part et d'autre de la porte (x de 0,55 à 2,15), fenêtre à gauche (x de -1,9 à -0,9)
	var haut_f := 2.05
	var fe := [-1.9, -0.9, 1.1, 1.85]    # fenêtre : x0, x1, y0, y1
	_boite(p, Vector3(0.55, haut_f, 0.16), Transform3D(Basis(), Vector3(-2.175, haut_f * 0.5, 1.8)), m_poutres, true)
	_boite(p, Vector3(1.45, haut_f, 0.16), Transform3D(Basis(), Vector3(-0.175, haut_f * 0.5, 1.8)), m_poutres, true)
	_boite(p, Vector3(1.0, fe[2], 0.16), Transform3D(Basis(), Vector3(-1.4, fe[2] * 0.5, 1.8)), m_poutres, true)
	_boite(p, Vector3(1.0, haut_f - fe[3], 0.16), Transform3D(Basis(), Vector3(-1.4, (haut_f + fe[3]) * 0.5, 1.8)), m_poutres, false)
	_boite(p, Vector3(0.3, haut_f, 0.16), Transform3D(Basis(), Vector3(2.3, haut_f * 0.5, 1.8)), m_poutres, true)
	_boite(p, Vector3(1.6, haut_f - 1.95, 0.16), Transform3D(Basis(), Vector3(1.35, (haut_f + 1.95) * 0.5, 1.8)), m_poutres_h, false)   # linteau
	# vitrage translucide (plan ps1_vitre) + meneau : la fenêtre n'est plus un trou
	_vitre(p, Vector3(-1.4, (fe[2] + fe[3]) * 0.5, 1.8), Vector2(1.0, fe[3] - fe[2]), 0.0)
	_boite(p, Vector3(0.05, fe[3] - fe[2], 0.08), Transform3D(Basis(), Vector3(-1.4, (fe[2] + fe[3]) * 0.5, 1.8)), m_poutres)
	# volet de la fenêtre : relevé en auvent sur un bâton
	_boite(p, Vector3(1.0, 0.04, 0.7), Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(-1.4, fe[3] + 0.28, 2.1)), m_poutres_h)
	_boite(p, Vector3(0.04, 0.04, 0.6), Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(-1.85, 1.65, 2.2)), m_poutres)
	_boite(p, Vector3(1.0, 0.1, 0.22), Transform3D(Basis(), Vector3(-1.4, fe[2] - 0.03, 1.86)), m_poutres_h)   # appui
	for fx in [-1.95, -0.85]:
		_boite(p, Vector3(0.1, fe[3] - fe[2] + 0.2, 0.2), Transform3D(Basis(), Vector3(fx, (fe[2] + fe[3]) * 0.5, 1.82)), m_poutres_h)
	# double porte (deux vantaux sur charnière) : 1,6 m × 1,95 m, blocage de collision tant qu'elle est fermée
	var ha := _vantail(p, Vector3(0.55, 0.0, 1.8), 0.8, 1.95, 1.0)
	var hb := _vantail(p, Vector3(2.15, 0.0, 1.8), 0.8, 1.95, -1.0)
	ip.vantaux.append([ha, -1.75])
	ip.vantaux.append([hb, 1.75])
	_bloc_porte(ip, p, Vector3(1.35, 1.0, 1.8), Vector3(1.6, 2.0, 0.3))
	# dalle de seuil
	_bloc(p, Vector3(2.0, 0.08, 0.7), 4470, Vector3(1.35, 0.03, 2.25), m_brute, 0.0, 0.3, 0.2, 0.04)
	# cheminée au-dessus de la hotte (la hotte et le foyer sont dans l'intérieur)
	_pile(p, Vector3(-0.8, 2.3, -1.5), Vector3(0.7, 1.6, 0.7), 4322, m_brute, false, 1.0)
	_fumee(p, Vector3(-0.8, 3.2, -1.5))
	# torche à gauche de la porte, au dehors
	_torche_murale(p, Vector3(0.2, 1.5, 1.93), 1.0, false)
	# doublage intérieur (pierre sèche, matière d'intérieur) et mobilier : après le chargement
	_differes.append(func() -> void:
		for sx in [-1.0, 1.0]:
			var k := 0
			for t in tronc:
				ib.bx(Vector3(sx * 2.155, t[2] * 0.5, (t[0] + t[1]) * 0.5), Vector3(0.1, t[2], t[1] - t[0]), "seche")   # doublage plat : la texture de pierre (64 texels/m) porte les joints ; l'ancien `pile` ne posait aucun bloc (épaisseur en X < 0,2 m) et laissait voir la pierre du dehors
				k += 1
		ib.bx(Vector3(0, 1.2, -1.7), Vector3(4.2, 2.4, 0.1), "seche")
		for x in [-2.4, 0.0, 2.4]:      # contreforts côté pièce : matière d'intérieur, sans neige
			ib.pile(Vector3(x, 1.0, -1.5), Vector3(0.6, 2.0, 0.3), 4310 + int(x), "brute")
		ib.fenetre_cadre(-1.4, (fe[2] + fe[3]) * 0.5, 1.72, 1.0, 0.5, (fe[3] - fe[2]) * 0.5)
		ib.contenu("forge")
		ib.finir()
		_finaliser())

func _puits(centre: Vector3) -> void:
	var p := _pivot(centre, 0.3)
	# margelle : deux rangs de moellons posés en cercle (collision d'origine : cylindre)
	var forme := CylinderShape3D.new()
	forme.radius = 1.0
	forme.height = 0.85
	_collision(p, forme, Transform3D(Basis(), Vector3(0, 0.42, 0)), Vector3.ZERO)
	var r := RandomNumberGenerator.new()
	r.seed = 4401
	for rang in 2:
		var n := 11
		for i in n:
			var a := TAU * (i + rang * 0.5) / n + r.randf_range(-0.05, 0.05)
			var pos := Vector3(sin(a) * 0.98, 0.2 + rang * 0.4, cos(a) * 0.98)
			_bloc(p, Vector3(0.62, 0.42, 0.42), r.randi(), pos, m_brute, a, 0.5 if rang == 1 else 0.0, 0.2, 0.08)
	_cylindre(p, 0.78, 0.78, 0.04, Transform3D(Basis(), Vector3(0, 0.78, 0)), m_eau, 8)
	for x in [-1.05, 1.05]:
		_poteau(p, Vector3(x, 0, 0), 0.1, 2.0, m_poutres)
	_cylindre(p, 0.09, 0.09, 2.3, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 1.7, 0)), m_poutres_h, 8)
	_pan(p, Vector3(0, 2.4, 0), Vector3(0, -0.55, 0.85), 2.7, 4402, 2.2, false)
	_pan(p, Vector3(0, 2.4, 0), Vector3(0, -0.55, -0.85), 2.7, 4403, 2.2, false)
	_cylindre(p, 0.16, 0.13, 0.25, Transform3D(Basis(), Vector3(0.3, 1.25, 0)), m_poutres, 8)
	_boite(p, Vector3(0.02, 0.4, 0.02), Transform3D(Basis(), Vector3(0.3, 1.5, 0)), m_cuir)   # corde du seau

func _brasero(centre: Vector3) -> void:
	var p := _pivot(centre, 0.0)
	_cylindre(p, 0.35, 0.45, 0.8, Transform3D(Basis(), Vector3(0, 0.4, 0)), m_pierre_fine, 8, true)
	_cylindre(p, 0.6, 0.35, 0.3, Transform3D(Basis(), Vector3(0, 0.95, 0)), m_fer, 8)
	_boite(p, Vector3(0.6, 0.06, 0.6), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 1.08, 0)), m_braises)
	_feu(p, Vector3(0, 1.12, 0), 1.6, 2.4, 11.0)
	# poteau sculpté octogonal sur un socle de pierre
	_bloc(p, Vector3(0.75, 0.34, 0.75), 4510, Vector3(1.6, 0.05, -0.6), m_brute, 0.3, 0.4, 0.2, 0.07)
	_cylindre(p, 0.16, 0.2, 3.6, Transform3D(Basis(), Vector3(1.6, 1.8, -0.6)), m_poutres, 8, true)
	for i in 3:
		_boite(p, Vector3(0.44, 0.22, 0.44), Transform3D(Basis(Vector3.UP, i * 0.6), Vector3(1.6, 1.4 + i * 0.85, -0.6)), m_poutres_h)

func _enclos(centre: Vector3) -> void:
	var p := _pivot(centre, 0.0)
	var demi := Vector2(3.5, 2.5)
	for x in range(-7, 8):
		for z in [-demi.y, demi.y]:
			if x % 2 == 0 and not (z > 0 and absi(x) < 2):
				_poteau(p, Vector3(x * 0.5, 0, z), 0.08, 1.2, m_poutres)
	for z in range(-5, 6):
		for x in [-demi.x, demi.x]:
			if z % 2 == 0:
				_poteau(p, Vector3(x, 0, z * 0.5), 0.08, 1.2, m_poutres)
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
