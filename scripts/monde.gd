extends Node3D
## Test visuel : forêt nordique de nuit (brouillard, neige, aurore, rendu PS1).
## Tout est généré par code pour l'instant ; les vrais modèles viendront de Blender.
##
## Capture d'écran sans jouer (pour les tests) :
##   godot --path . -- --capture=C:/chemin/image.png [--pose=x,z,lacet,tangage] [--sans-ps1]

const TAILLE := 240.0           # côté du terrain (m)
const CASES := 120              # cases par côté
const RAYON_CLAIRIERE := 9.0
const CERCLE := Vector3(-38.0, 0.0, -34.0)  # cercle de pierres runiques
const NB_SAPINS := 1500
const NB_ROCHERS := 160

const CIEL := preload("res://shaders/ciel_nuit.gdshader")
const POST := preload("res://shaders/ps1_post.gdshader")
const JOUEUR := preload("res://scripts/joueur.gd")
const DRAUGR := preload("res://scripts/draugr.gd")
const HUD := preload("res://scripts/hud.gd")

var bruit := FastNoiseLite.new()
var bruit_detail := FastNoiseLite.new()
var bruit_densite := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var h_centre := 0.0
var h_cercle := 0.0

var tex_neige: ImageTexture
var tex_roche: ImageTexture
var tex_aiguilles: ImageTexture
var tex_ecorce: ImageTexture

var joueur: CharacterBody3D
var neige: GPUParticles3D
var feu_lumiere: OmniLight3D
var post: ShaderMaterial
var aide: Label
var hud: Control
var sbire: CharacterBody3D
var depart_joueur := Vector3.ZERO
var _t := 0.0

var _audio_vent: AudioStreamGeneratorPlayback
var _audio_feu: AudioStreamGeneratorPlayback
var _brun := 0.0
var _brun2 := 0.0
var _crepite := 0.0
var _t_audio := 0.0

func _ready() -> void:
	rng.seed = 1234
	bruit.seed = 7
	bruit.frequency = 0.009
	bruit.fractal_octaves = 4
	bruit_detail.seed = 11
	bruit_detail.frequency = 0.06
	bruit_densite.seed = 3
	bruit_densite.frequency = 0.02
	h_centre = _hauteur_brute(0.0, 0.0)
	for k in 8:
		var a := TAU * k / 8.0
		h_cercle += _hauteur_brute(CERCLE.x + cos(a) * 16.0, CERCLE.z + sin(a) * 16.0) / 8.0

	tex_neige = Palette.texture(32, Palette.NEIGE, 4, 1, 0.35, rng)
	Palette.tex_neige = tex_neige
	tex_roche = Palette.texture(32, Palette.ROCHE, 4, 2, 0.45, rng)
	tex_aiguilles = Palette.texture(32, Palette.AIGUILLES, 8, 3, 0.7, rng)
	tex_ecorce = Palette.texture(32, Palette.ECORCE, 4, 4, 0.4, rng)

	_environnement()
	_lune()
	_terrain()
	_foret()
	_rochers()
	_cercle_runique()
	_feu_de_camp()
	_joueur()
	_neige()
	_interface()
	_draugrs()
	if not _arguments().has("capture"):
		_audio()
	_capture()

# --- relief ---------------------------------------------------------------

func _hauteur_brute(x: float, z: float) -> float:
	var h := bruit.get_noise_2d(x, z) * 14.0 + bruit_detail.get_noise_2d(x, z) * 1.0
	# collines sur le pourtour : une cuvette boisée
	h += smoothstep(70.0, 118.0, Vector2(x, z).length()) * 24.0
	return h

func hauteur(x: float, z: float) -> float:
	var h := _hauteur_brute(x, z)
	# clairière du feu et clairière du cercle aplanies
	h = lerpf(h_centre, h, smoothstep(RAYON_CLAIRIERE, RAYON_CLAIRIERE + 14.0, Vector2(x, z).length()))
	h = lerpf(h_cercle, h, smoothstep(9.0, 26.0, Vector2(x - CERCLE.x, z - CERCLE.z).length()))
	return h

# --- ambiance ----------------------------------------------------------------

func _environnement() -> void:
	var ciel := ShaderMaterial.new()
	ciel.shader = CIEL
	var sky := Sky.new()
	sky.sky_material = ciel
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.4, 0.62)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.14, 0.22)
	env.fog_density = 0.024
	env.fog_sky_affect = 0.15
	env.fog_height = h_centre + 1.5
	env.fog_height_density = 0.12
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 0.9

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _lune() -> void:
	# lune haute au nord-est, face au joueur à l'apparition : contre-jour sur la neige
	var vers_lune := Vector3(0.35, 0.55, -0.75).normalized()
	var lune := DirectionalLight3D.new()
	lune.basis = Basis.looking_at(-vers_lune, Vector3.UP)
	lune.light_color = Color(0.62, 0.72, 1.0)
	lune.light_energy = 0.75
	lune.shadow_enabled = true
	lune.shadow_bias = 0.08
	lune.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	lune.directional_shadow_max_distance = 70.0
	add_child(lune)

# --- terrain -----------------------------------------------------------------

func _terrain() -> void:
	var n := CASES + 1
	var pas := TAILLE / CASES
	var demi := TAILLE * 0.5
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = hauteur(i * pas - demi, j * pas - demi)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var hg := hs[j * n + maxi(i - 1, 0)]
			var hd := hs[j * n + mini(i + 1, n - 1)]
			var hh := hs[maxi(j - 1, 0) * n + i]
			var hb := hs[mini(j + 1, n - 1) * n + i]
			var normale := Vector3(hg - hd, 2.0 * pas, hh - hb).normalized()
			var x := i * pas - demi
			var z := j * pas - demi
			# la roche affleure sur les pentes raides ; un peu de bruit casse la limite
			var roche := 1.0 - normale.y + bruit_detail.get_noise_2d(x * 3.0, z * 3.0) * 0.12
			var clair := 0.93 + bruit_detail.get_noise_2d(x * 0.7, z * 0.7) * 0.07
			st.set_color(Color(clair, clair, clair, 1.0 if roche > 0.2 else 0.0))
			st.set_normal(normale)
			st.add_vertex(Vector3(x, hs[j * n + i], z))
	for j in CASES:
		for i in CASES:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d); st.add_index(c)
	var mesh := st.commit()

	var m := Palette.materiau(tex_roche)
	m.set_shader_parameter("uv_monde", true)
	m.set_shader_parameter("monde_echelle", 0.22)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	add_child(mi)

	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	forme.shape = mesh.create_trimesh_shape()
	corps.add_child(forme)
	add_child(corps)

# --- sapins ------------------------------------------------------------------

func _cone(st: SurfaceTool, y0: float, y1: float, r: float, cotes: int, rot: float, sous := true) -> void:
	var sommet := Vector3(0.0, y1, 0.0)
	var centre := Vector3(0.0, y0, 0.0)
	for k in cotes:
		var a0 := rot + TAU * k / cotes
		var a1 := rot + TAU * (k + 1) / cotes
		var p0 := Vector3(cos(a0) * r, y0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, y0, sin(a1) * r)
		_tri(st, p0, p1, sommet, Vector2(float(k) / cotes * 2.0, 1.0), Vector2(float(k + 1) / cotes * 2.0, 1.0), Vector2(float(k + 0.5) / cotes * 2.0, 0.0))
		if sous:
			_tri(st, p1, p0, centre, Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.5))

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua); st.add_vertex(a)
	st.set_uv(ub); st.add_vertex(b)
	st.set_uv(uc); st.add_vertex(c)

func _sapin() -> ArrayMesh:
	var tronc := SurfaceTool.new()
	tronc.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var a0 := TAU * k / 5.0
		var a1 := TAU * (k + 1) / 5.0
		var p0 := Vector3(cos(a0) * 0.2, -0.5, sin(a0) * 0.2)
		var p1 := Vector3(cos(a1) * 0.2, -0.5, sin(a1) * 0.2)
		var h0 := Vector3(cos(a0) * 0.12, 2.2, sin(a0) * 0.12)
		var h1 := Vector3(cos(a1) * 0.12, 2.2, sin(a1) * 0.12)
		_tri(tronc, p0, p1, h1, Vector2(k, 3), Vector2(k + 1, 3), Vector2(k + 1, 0))
		_tri(tronc, p0, h1, h0, Vector2(k, 3), Vector2(k + 1, 0), Vector2(k, 0))

	var feuillage := SurfaceTool.new()
	feuillage.begin(Mesh.PRIMITIVE_TRIANGLES)
	var neige_st := SurfaceTool.new()
	neige_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var etages := 5
	for e in etages:
		var y0 := 1.1 + e * 1.25
		var y1 := y0 + 2.6 - e * 0.25
		var r := 2.1 - e * 0.38
		var rot := e * 0.7
		_cone(feuillage, y0, y1, r, 7, rot)
		# calotte de neige : couvre le haut de l'étage, bord irrégulier qui « coule »
		var ys := y1 - (y1 - y0) * 0.5
		var rs := r * 0.5 + 0.07
		var sommet := Vector3(0.0, y1 + 0.04, 0.0)
		var n := 14
		for k in n:
			var a0 := rot + TAU * k / n
			var a1 := rot + TAU * (k + 1) / n
			var d0 := 0.22 if k % 2 == 1 else 0.0
			var d1 := 0.22 if (k + 1) % 2 == 1 else 0.0
			var p0 := Vector3(cos(a0) * (rs + d0 * 0.45), ys - d0, sin(a0) * (rs + d0 * 0.45))
			var p1 := Vector3(cos(a1) * (rs + d1 * 0.45), ys - d1, sin(a1) * (rs + d1 * 0.45))
			_tri(neige_st, p0, p1, sommet, Vector2(k * 0.3, 1), Vector2((k + 1) * 0.3, 1), Vector2(k * 0.3, 0))

	var mesh := ArrayMesh.new()
	for paire in [[tronc, Palette.materiau(tex_ecorce)], [feuillage, Palette.materiau(tex_aiguilles)], [neige_st, Palette.materiau(tex_neige)]]:
		var st: SurfaceTool = paire[0]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, paire[1])
	return mesh

func _foret() -> void:
	var positions: Array[Vector3] = []
	var grille := {}
	var essais := 0
	while positions.size() < NB_SAPINS and essais < NB_SAPINS * 20:
		essais += 1
		var x := rng.randf_range(-116.0, 116.0)
		var z := rng.randf_range(-116.0, 116.0)
		var d := Vector2(x, z).length()
		if d < RAYON_CLAIRIERE + 2.5 or Vector2(x - CERCLE.x, z - CERCLE.z).length() < 11.0:
			continue
		# la forêt s'épaissit et s'éclaircit par plaques
		var densite := bruit_densite.get_noise_2d(x, z) * 0.5 + 0.6 + smoothstep(14.0, 30.0, d) * 0.2
		if rng.randf() > densite:
			continue
		var cle := Vector2i(floori(x / 3.0), floori(z / 3.0))
		if grille.has(cle):
			continue
		grille[cle] = true
		positions.append(Vector3(x, hauteur(x, z) - 0.15, z))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _sapin()
	mm.instance_count = positions.size()
	var corps := StaticBody3D.new()
	var cylindre := CylinderShape3D.new()
	cylindre.radius = 0.35
	cylindre.height = 4.0
	for i in positions.size():
		var p := positions[i]
		var s := rng.randf_range(0.65, 1.35)
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		b = Basis(Vector3(1, 0, 0), rng.randf_range(-0.04, 0.04)) * b
		b = b.scaled(Vector3(s, s * rng.randf_range(0.9, 1.25), s))
		mm.set_instance_transform(i, Transform3D(b, p))
		var forme := CollisionShape3D.new()
		forme.shape = cylindre
		forme.position = p + Vector3(0, 2, 0)
		corps.add_child(forme)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	add_child(corps)

# --- rochers -----------------------------------------------------------------

func _rocher_mesh(graine: int) -> ArrayMesh:
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

func _rochers() -> void:
	var m := Palette.materiau(tex_roche)
	var modeles: Array[ArrayMesh] = []
	for g in 4:
		var mesh := _rocher_mesh(40 + g)
		mesh.surface_set_material(0, m)
		modeles.append(mesh)
	var parts: Array[Array] = [[], [], [], []]
	for i in NB_ROCHERS:
		var x := rng.randf_range(-112.0, 112.0)
		var z := rng.randf_range(-112.0, 112.0)
		if Vector2(x, z).length() < RAYON_CLAIRIERE:
			continue
		var s := rng.randf_range(0.4, 2.2) * (2.0 if rng.randf() < 0.12 else 1.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.8, 1.2)))
		parts[i % 4].append(Transform3D(b, Vector3(x, hauteur(x, z) - s * 0.25, z)))
	var corps := StaticBody3D.new()
	for g in 4:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = modeles[g]
		mm.instance_count = parts[g].size()
		var forme_modele := modeles[g].create_convex_shape()
		for i in parts[g].size():
			mm.set_instance_transform(i, parts[g][i])
			var forme := CollisionShape3D.new()
			forme.shape = forme_modele
			forme.transform = parts[g][i]
			corps.add_child(forme)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
	add_child(corps)

# --- cercle de pierres runiques ----------------------------------------------

func _texture_runes() -> ImageTexture:
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

func _cercle_runique() -> void:
	var centre := Vector3(CERCLE.x, h_cercle, CERCLE.z)
	var m := Palette.materiau(tex_roche, Vector2(1, 2))
	var corps := StaticBody3D.new()
	add_child(corps)
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var haut := rng.randf_range(2.2, 3.4)
		var boite := BoxMesh.new()
		boite.size = Vector3(1.0, haut, 0.45)
		var mi := MeshInstance3D.new()
		mi.mesh = boite
		mi.material_override = m
		var p := centre + Vector3(cos(a) * 6.5, haut * 0.5 - 0.3, sin(a) * 6.5)
		mi.transform = Transform3D(Basis(Vector3.UP, -a + PI * 0.5).rotated(Vector3(cos(a), 0, sin(a)), rng.randf_range(-0.08, 0.08)), p)
		add_child(mi)
		var forme := CollisionShape3D.new()
		var bf := BoxShape3D.new()
		bf.size = boite.size
		forme.shape = bf
		forme.transform = mi.transform
		corps.add_child(forme)

	# pierre centrale gravée de runes qui luisent
	var stele := MeshInstance3D.new()
	var bs := BoxMesh.new()
	bs.size = Vector3(1.3, 3.6, 0.5)
	stele.mesh = bs
	stele.material_override = m
	stele.position = centre + Vector3(0, 1.5, 0)
	stele.rotation.y = 0.5
	add_child(stele)
	var forme_s := CollisionShape3D.new()
	var bfs := BoxShape3D.new()
	bfs.size = bs.size
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
	mr.albedo_texture = _texture_runes()
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

# --- feu de camp ---------------------------------------------------------------

func _feu_de_camp() -> void:
	var sol := Vector3(0, h_centre, 0)
	var m_bois := Palette.materiau(tex_ecorce, Vector2(1, 2))
	var m_pierre := Palette.materiau(tex_roche)
	var buche := CylinderMesh.new()
	buche.top_radius = 0.08
	buche.bottom_radius = 0.1
	buche.height = 1.1
	buche.radial_segments = 6
	buche.rings = 1
	for i in 5:
		var a := TAU * i / 5.0
		var mi := MeshInstance3D.new()
		mi.mesh = buche
		mi.material_override = m_bois
		var b := Basis(Vector3(-sin(a), 0, cos(a)), 0.55)
		mi.transform = Transform3D(b, sol + Vector3(cos(a) * 0.25, 0.42, sin(a) * 0.25))
		add_child(mi)
	var caillou := SphereMesh.new()
	caillou.radius = 0.16
	caillou.height = 0.22
	caillou.radial_segments = 6
	caillou.rings = 3
	for i in 9:
		var a := TAU * i / 9.0
		var mi := MeshInstance3D.new()
		mi.mesh = caillou
		mi.material_override = m_pierre
		mi.position = sol + Vector3(cos(a) * 0.62, 0.04, sin(a) * 0.62)
		mi.rotation.y = a
		add_child(mi)
	# deux troncs couchés pour s'asseoir
	var banc := CylinderMesh.new()
	banc.top_radius = 0.22
	banc.bottom_radius = 0.24
	banc.height = 2.4
	banc.radial_segments = 7
	banc.rings = 1
	var corps := StaticBody3D.new()
	add_child(corps)
	for a in [0.4, 2.6]:
		var mi := MeshInstance3D.new()
		mi.mesh = banc
		mi.material_override = m_bois
		# couché (axe X), tangent au cercle autour du feu
		var b := Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3(0, 0, 1), PI * 0.5)
		mi.transform = Transform3D(b, sol + Vector3(cos(a) * 2.6, 0.18, sin(a) * 2.6))
		add_child(mi)
		var forme := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.23
		cyl.height = 2.4
		forme.shape = cyl
		forme.transform = mi.transform
		corps.add_child(forme)

	feu_lumiere = OmniLight3D.new()
	feu_lumiere.light_color = Color(1.0, 0.55, 0.22)
	feu_lumiere.light_energy = 3.0
	feu_lumiere.omni_range = 14.0
	feu_lumiere.omni_attenuation = 1.4
	feu_lumiere.position = sol + Vector3(0, 0.9, 0)
	add_child(feu_lumiere)

	add_child(_particules_feu(sol, 70, 1.0, Vector2(0.32, 0.32), 1.6, 0.25, [Color(3.0, 2.2, 0.8), Color(2.6, 1.0, 0.25), Color(1.2, 0.25, 0.05), Color(0.3, 0.05, 0.0, 0.0)]))
	add_child(_particules_feu(sol, 18, 2.8, Vector2(0.06, 0.06), 1.8, 0.35, [Color(3.0, 1.8, 0.6), Color(2.0, 0.6, 0.1), Color(1.0, 0.2, 0.0, 0.0)]))

func _particules_feu(sol: Vector3, nombre: int, duree: float, taille: Vector2, vitesse: float, rayon: float, couleurs: Array) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = nombre
	p.lifetime = duree
	p.position = sol + Vector3(0, 0.15, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = rayon
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = vitesse * 0.6
	pm.initial_velocity_max = vitesse
	pm.gravity = Vector3(0.15, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var g := Gradient.new()
	var decalages := PackedFloat32Array()
	for i in couleurs.size():
		decalages.append(float(i) / (couleurs.size() - 1))
	g.offsets = decalages
	g.colors = PackedColorArray(couleurs)
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = taille
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.vertex_color_use_as_albedo = true
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mq
	p.draw_pass_1 = q
	return p

# --- joueur, neige, interface ------------------------------------------------

func _joueur() -> void:
	joueur = CharacterBody3D.new()
	joueur.set_script(JOUEUR)
	add_child(joueur)
	var depart := Vector3(2.5, 0, 8.5)
	var lacet := atan2(depart.x, depart.z)  # regarde le feu
	var tangage := 0.12
	var pose: String = _arguments().get("pose", "")
	if pose != "":
		var v := pose.split_floats(",")
		depart = Vector3(v[0], 0, v[1])
		lacet = deg_to_rad(v[2])
		tangage = deg_to_rad(v[3]) if v.size() > 3 else 0.0
	joueur.position = Vector3(depart.x, hauteur(depart.x, depart.z) + 0.1, depart.z)
	joueur.rotation.y = lacet
	joueur.tete.rotation.x = tangage
	depart_joueur = joueur.position
	joueur.touche.connect(_joueur_touche)
	joueur.deces.connect(_joueur_mort)

func _joueur_touche(_degats: float) -> void:
	var t := create_tween()
	t.tween_method(func(v: float) -> void: post.set_shader_parameter("degat", v), 0.8, 0.0, 0.6)

func _joueur_mort() -> void:
	var t := create_tween()
	t.tween_method(func(v: float) -> void: post.set_shader_parameter("fondu", v), 0.0, 1.0, 2.0)
	t.tween_interval(1.5)
	t.tween_callback(func() -> void: joueur.ressusciter(depart_joueur, atan2(depart_joueur.x, depart_joueur.z)))
	t.tween_method(func(v: float) -> void: post.set_shader_parameter("fondu", v), 1.0, 0.0, 1.5)

# --- draugrs ---------------------------------------------------------------------

func _draugr(type: String, x: float, z: float, dort: bool, lacet := 0.0) -> CharacterBody3D:
	var d := CharacterBody3D.new()
	d.set_script(DRAUGR)
	d.type = type
	d.dort = dort and not _arguments().has("reveiller")
	d.joueur = joueur
	d.position = Vector3(x, hauteur(x, z) + 0.05, z)
	d.rotation.y = lacet
	add_child(d)
	return d

func _draugrs() -> void:
	# trois gardiens endormis au cercle de pierres, un guerrier debout à l'entrée
	_draugr("guerrier", CERCLE.x + 2.6, CERCLE.z + 1.2, true, 2.0)
	_draugr("sbire", CERCLE.x - 2.2, CERCLE.z + 2.6, true, -0.6)
	_draugr("sbire", CERCLE.x + 0.6, CERCLE.z - 3.0, true, 3.4)
	_draugr("guerrier", CERCLE.x + 9.0, CERCLE.z + 9.0, false, 0.8)
	# un rôdeur dans la forêt, entre le feu et le cercle
	sbire = _draugr("sbire", -16.0, -15.0, false, 0.6)

func _neige() -> void:
	neige = GPUParticles3D.new()
	neige.amount = 5000
	neige.lifetime = 9.0
	neige.preprocess = 9.0
	neige.local_coords = false
	neige.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 50, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 1, 28)
	pm.direction = Vector3(0.35, -1, 0.15)
	pm.spread = 15.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0.1, -0.25, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.0
	pm.turbulence_noise_scale = 6.0
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.06
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	neige.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mq.albedo_color = Color(0.85, 0.9, 1.0)
	# un flocon collé à l'objectif deviendrait un gros carré : il s'efface en tramage
	mq.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	mq.distance_fade_min_distance = 0.4
	mq.distance_fade_max_distance = 1.5
	q.material = mq
	neige.draw_pass_1 = q
	add_child(neige)
	neige.global_position = joueur.global_position + Vector3(0, 10, 0)

func _interface() -> void:
	var calque := CanvasLayer.new()
	add_child(calque)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = POST
	rect.material = post
	calque.add_child(rect)
	aide = Label.new()
	aide.text = "ZQSD : marcher   Maj : courir   Espace : sauter\nClic gauche : frapper (maintenir = coup puissant)\nClic droit : garde   T : torche   P : effet PS1   Échap : souris"
	aide.add_theme_font_size_override("font_size", 8)
	aide.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.85))
	aide.position = Vector2(6, 18)
	hud = Control.new()
	hud.set_script(HUD)
	hud.joueur = joueur
	hud.lieux = [[Vector3(CERCLE.x, 0, CERCLE.z), Color("#6fd8ff")], [Vector3.ZERO, Color("#e8a64a")]]
	calque.add_child(hud)
	calque.add_child(aide)
	if _arguments().has("capture"):
		aide.visible = false
	if _arguments().has("sans-ps1"):
		_basculer_ps1()

func _basculer_ps1() -> void:
	var actif: bool = not post.get_shader_parameter("actif")
	post.set_shader_parameter("actif", actif)
	Palette.regler_ps1(actif)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_P:
		_basculer_ps1()

func _process(dt: float) -> void:
	_t += dt
	neige.global_position = joueur.global_position + Vector3(0, 10, 0)
	# le feu vacille : deux sinus désaccordés + un peu de hasard
	feu_lumiere.light_energy = 3.2 + sin(_t * 11.0) * 0.25 + sin(_t * 23.7) * 0.18 + randf() * 0.25
	if _t > 14.0 and aide.modulate.a > 0.0:
		aide.modulate.a = maxf(0.0, aide.modulate.a - dt * 0.5)
	_remplir_audio()

# --- son : vent et crépitement générés en direct -------------------------------

func _audio() -> void:
	var vent := AudioStreamPlayer.new()
	var gv := AudioStreamGenerator.new()
	gv.mix_rate = 22050
	gv.buffer_length = 0.25
	vent.stream = gv
	vent.volume_db = -8.0
	add_child(vent)
	vent.play()
	_audio_vent = vent.get_stream_playback()

	var feu := AudioStreamPlayer3D.new()
	var gf := AudioStreamGenerator.new()
	gf.mix_rate = 22050
	gf.buffer_length = 0.25
	feu.stream = gf
	feu.unit_size = 2.5
	feu.position = feu_lumiere.position
	add_child(feu)
	feu.play()
	_audio_feu = feu.get_stream_playback()

func _remplir_audio() -> void:
	if _audio_vent == null:
		return
	var n := mini(_audio_vent.get_frames_available(), _audio_feu.get_frames_available())
	for i in n:
		_t_audio += 1.0 / 22050.0
		var blanc := randf() * 2.0 - 1.0
		# vent : bruit brun filtré, rafales lentes
		_brun = clampf(_brun * 0.996 + blanc * 0.03, -1.0, 1.0)
		_brun2 = _brun2 * 0.9 + _brun * 0.1
		var rafale := 0.45 + 0.55 * absf(sin(_t_audio * 0.23) * sin(_t_audio * 0.071 + 1.3))
		var v := _brun2 * 1.6 * rafale
		_audio_vent.push_frame(Vector2(v, v * 0.92))
		# feu : petits claquements secs sur un souffle grave
		_crepite *= 0.93
		if randf() < 0.0012:
			_crepite = randf_range(0.3, 1.0)
		var f := blanc * _crepite * 0.8 + _brun * 0.25
		_audio_feu.push_frame(Vector2(f, f))

# --- capture pour les tests ------------------------------------------------------

func _arguments() -> Dictionary:
	var res := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var parts := a.substr(2).split("=", true, 1)
			res[parts[0]] = parts[1] if parts.size() > 1 else ""
	return res

func _capture() -> void:
	var chemin: String = _arguments().get("capture", "")
	if chemin == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in (int(_arguments().get("attente", "90"))):
		await get_tree().process_frame
	if _arguments().has("test-combat"):
		await _test_combat()
	print("FPS : ", Engine.get_frames_per_second())
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(chemin)
	get_tree().quit()

## Test automatique : le joueur se place face au rôdeur et enchaîne des coups.
func _test_combat() -> void:
	var cible := sbire.global_position + Vector3(0, 0, 2.2).rotated(Vector3.UP, sbire.rotation.y)
	joueur.global_position = cible
	joueur.look_at(Vector3(sbire.global_position.x, joueur.global_position.y, sbire.global_position.z))
	joueur.tete.rotation.x = -0.1
	for i in 30:
		await get_tree().physics_frame
	print("draugr : etat=", sbire.etat, " vie=", sbire.vie)
	var coups: Array = _arguments().get("test-combat", "lpll").split("")
	for c in coups:
		joueur.mains.attaquer(c == "p")
		await get_tree().create_timer(0.75).timeout
		print("coup ", c, " -> draugr etat=", sbire.etat, " vie=", sbire.vie, " | joueur vie=", snappedf(joueur.vie, 0.1), " vigueur=", snappedf(joueur.vigueur, 0.1))
	joueur.mains.attaquer(false)
	await get_tree().create_timer(0.16).timeout
