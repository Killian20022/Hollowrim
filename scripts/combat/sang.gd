class_name Sang
## Sang et traces (combat gore, option « Sang / gore » des options : 2 complet, 1 réduit, 0 désactivé).
##   Sang.giclee(noeud, point, direction, intensite, couleur)   giclée directionnelle (particules pixel) + traces au sol/au mur
##   Sang.jet(attache, transform_local, couleur, duree)          jet pulsé (cou tranché) qui goutte au sol
##   Sang.flaque(noeud, position, couleur, taille, croissance)   flaque qui s'étale sous un corps
##   Sang.trace(noeud, position, normale, direction, taille, couleur, sorte)   trace collée (flaque, giclure, trainee)
## Traces = petits plans texturés (texels nets, découpe alpha, aspect mouillé) posés sur la surface touchée (rayon), gérés par un
## nœud « GestionSang » de la scène : au plus MAX_TRACES (les plus anciennes disparaissent), chacune s'efface après DUREE_TRACE s.
## (Pas de Decal pour le sol : le rendu Mobile limite les décals par maillage, or le terrain est un seul grand maillage.)

const MAX_TRACES := 48
const DUREE_TRACE := 150.0
const MAX_GOUTTES_JET := 6
## Niveau imposé (tests, captures) ; -1 = option du joueur.
static var niveau_force := -1
static var _tex := {}
static var _mats := {}
static var _mat_part := {}
static var _plan: PlaneMesh

static func niveau() -> int:
	if niveau_force >= 0:
		return niveau_force
	return clampi(int(Jeu.option("combat", "gore")), 0, 2)

static func actif() -> bool:
	return niveau() > 0

# ------------------------------------------------------------------ giclées

static func giclee(n: Node, point: Vector3, direction: Vector3, intensite: float, couleur: Color, traces := true) -> void:
	var niv := niveau()
	if niv == 0 or n == null or not n.is_inside_tree():
		return
	var k := intensite * (1.0 if niv == 2 else 0.35)
	var dir := direction.normalized() if direction.length() > 0.01 else Vector3.UP
	_burst(n, point, (dir + Vector3.UP * 0.3).normalized(), clampi(int(18.0 * k), 4, 110), 22.0, 1.8 * sqrt(k), 5.2 * sqrt(k), couleur, Vector3(0.022, 0.06, 0.022))
	# brume fine (gouttelettes) plus large, moins loin
	_burst(n, point, (dir + Vector3.UP * 0.6).normalized(), clampi(int(10.0 * k), 2, 50), 55.0, 0.8, 2.6 * sqrt(k), couleur * 1.15, Vector3(0.02, 0.02, 0.02))
	if traces:
		_traces_giclee(n, point, dir, k, couleur, niv)

## Éclats non sanglants (os, bois, sang désactivé) : même geste, autre matière.
static func eclats_matiere(n: Node, point: Vector3, direction: Vector3, intensite: float, couleur: Color) -> void:
	if n == null or not n.is_inside_tree():
		return
	var dir := direction.normalized() if direction.length() > 0.01 else Vector3.UP
	# lot L6 : gerbe de GROS PIXELS CARRÉS en palette (GerbePixels, pool sans allocation) au lieu des cubes de 2 cm
	GerbePixels.emettre(n, point, (dir + Vector3.UP * 0.5).normalized(), matiere_de(couleur), clampf(intensite, 0.6, 3.0))

## Matière de gerbe (GerbePixels.MATIERES) d'après la couleur passée à eclats_matiere : gris = poussière (gore coupé),
## clair = os (squelette), brun clair = bois (mannequin, échardes), sinon sang.
static func matiere_de(c: Color) -> String:
	if c.s < 0.2:
		return "poussiere"
	if c.v > 0.66:
		return "os"
	if c.r > 0.5 and c.g > 0.4:
		return "bois"
	return "sang" if niveau() > 0 else "poussiere"

## Une giclée = un GPUParticles3D éphémère. Ses ressources (matériau de processus, rampe de couleur, cube) sont PARTAGÉES
## (caches par réglage) : en créer de neuves à chaque coup coûtait des allocations et un envoi de texture par giclée. La direction
## n'est pas dans le matériau : c'est l'orientation du nœud (la vitesse initiale suit le repère de l'émetteur, la gravité reste
## celle du monde : local_coords = false).
static var _pm_cache := {}
static var _cube_cache := {}
static var _rampe: GradientTexture1D

static func _burst(n: Node, point: Vector3, dir: Vector3, nombre: int, ecart: float, vmin: float, vmax: float, couleur: Color, taille: Vector3, aligne := true) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = nombre
	p.lifetime = 0.8
	p.explosiveness = 0.95
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = _pm_giclee(ecart, vmin, vmax, aligne)
	p.draw_pass_1 = _cube(taille, couleur)
	var scene := n.get_tree().current_scene
	(scene if scene else n.get_tree().root).add_child(p)
	p.global_transform = Transform3D(_vers(dir), point)
	p.emitting = true
	p.finished.connect(p.queue_free)

## Base dont le +Y pointe vers `dir`.
static func _vers(dir: Vector3) -> Basis:
	var y := dir.normalized() if dir.length() > 0.001 else Vector3.UP
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))

static func _pm_giclee(ecart: float, vmin: float, vmax: float, aligne: bool) -> ParticleProcessMaterial:
	var cle := "%d|%.1f|%.1f|%s" % [roundi(ecart), vmin, vmax, aligne]
	if _pm_cache.has(cle):
		return _pm_cache[cle]
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = ecart
	pm.initial_velocity_min = snappedf(vmin, 0.1)
	pm.initial_velocity_max = snappedf(vmax, 0.1)
	pm.gravity = Vector3(0, -11.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	pm.particle_flag_align_y = aligne
	pm.color = Color.WHITE
	if _rampe == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.25, 1.25, 1.25))
		g.set_color(1, Color(0.6, 0.6, 0.6))
		_rampe = GradientTexture1D.new()
		_rampe.gradient = g
	pm.color_initial_ramp = _rampe
	if _pm_cache.size() > 64:
		_pm_cache.clear()
	_pm_cache[cle] = pm
	return pm

static func _cube(taille: Vector3, couleur: Color) -> BoxMesh:
	var cle := "%s|%s" % [taille, couleur]
	if not _cube_cache.has(cle):
		var b := BoxMesh.new()
		b.size = taille
		b.material = _mat_particule(couleur)
		if _cube_cache.size() > 64:
			_cube_cache.clear()
		_cube_cache[cle] = b
	return _cube_cache[cle]

static func _mat_particule(c: Color) -> StandardMaterial3D:
	var cle := str(c)
	if not _mat_part.has(cle):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = c
		m.roughness = 0.3
		m.emission_enabled = true
		m.emission = c * 0.35   # lisible dans la pénombre sans briller
		_mat_part[cle] = m
	return _mat_part[cle]

static func _traces_giclee(n: Node, point: Vector3, dir: Vector3, k: float, couleur: Color, niv: int) -> void:
	var plat := Vector3(dir.x, 0, dir.z)
	plat = plat.normalized() if plat.length() > 0.05 else Vector3.FORWARD
	var nb := clampi(int(1.0 + k * 0.9), 1, 5)
	var arbre := n.get_tree()
	var espace := (n as Node3D).get_world_3d().direct_space_state if n is Node3D else null
	if espace == null:
		return
	var exclus := _exclus(arbre)
	# au mur (le long du geste) — seulement en sang complet
	if niv == 2 and k >= 1.2:
		var q := PhysicsRayQueryParameters3D.create(point, point + dir * 2.4, 1, exclus)
		var r := espace.intersect_ray(q)
		if not r.is_empty() and absf((r["normal"] as Vector3).y) < 0.6 and _surface(r):
			trace(n, r["position"], r["normal"], Vector3.DOWN, randf_range(0.35, 0.6) * minf(k, 2.5) * 0.6, couleur, "giclure")
	for j in nb:
		var de := point + plat * (0.35 + j * 0.5 * clampf(k, 0.6, 2.2)) + plat.cross(Vector3.UP) * randf_range(-0.2, 0.2)
		var q := PhysicsRayQueryParameters3D.create(de + Vector3.UP * 0.4, de + Vector3.DOWN * 3.0, 1, exclus)
		var r := espace.intersect_ray(q)
		if r.is_empty() or not _surface(r):
			continue
		var sorte := "giclure" if j < nb - 1 or k < 1.5 else "trainee"
		trace(n, r["position"], r["normal"], plat, randf_range(0.28, 0.5) * clampf(k, 0.5, 2.0) * (1.0 if niv == 2 else 0.6), couleur, sorte, 0.0, 0.12 + j * 0.08)

static func _surface(r: Dictionary) -> bool:
	var c: Object = r.get("collider")
	return c != null and not (c is CharacterBody3D) and not (c is RigidBody3D) and not (c is PhysicalBone3D)

static func _exclus(arbre: SceneTree) -> Array[RID]:
	var ex: Array[RID] = []
	for e in arbre.get_nodes_in_group("ennemis"):
		if e is CollisionObject3D:
			ex.append((e as CollisionObject3D).get_rid())
	return ex

## Sol sous `pos` (rayon vertical) : {position, normal} ou {}.
static func sol_sous(n: Node3D, pos: Vector3, haut := 0.6, bas := 3.0) -> Dictionary:
	if n == null or not n.is_inside_tree():
		return {}
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * haut, pos + Vector3.DOWN * bas, 1, _exclus(n.get_tree()))
	var r := n.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty() or not _surface(r):
		return {}
	return r

# ------------------------------------------------------------------ jets (cou tranché)

## Matériau de processus des jets, partagé (un neuf par jet : ~12 ms de shader recompilé au premier jet suivant).
static var _pm_jets := {}
static func pm_jet(niv: int) -> ParticleProcessMaterial:
	if not _pm_jets.has(niv):
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3.UP
		pm.spread = 10.0
		pm.initial_velocity_min = 2.2
		pm.initial_velocity_max = 4.2 if niv == 2 else 2.8
		pm.gravity = Vector3(0, -11.0, 0)
		pm.scale_min = 0.7
		pm.scale_max = 1.6
		pm.particle_flag_align_y = true
		_pm_jets[niv] = pm
	return _pm_jets[niv]

## Jet pulsé (battements) attaché à `attache` (ex. BoneAttachment3D du cou) ; +Y local de `local` = sens du jet.
static func jet(attache: Node3D, local: Transform3D, couleur: Color, duree := 2.4) -> GPUParticles3D:
	var niv := niveau()
	if niv == 0 or attache == null or not attache.is_inside_tree():
		return null
	var p := GPUParticles3D.new()
	p.name = "JetSang"
	p.amount = 70 if niv == 2 else 22
	p.lifetime = 0.7
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = pm_jet(niv)
	p.draw_pass_1 = _cube(Vector3(0.03, 0.08, 0.03), couleur)
	attache.add_child(p)
	p.transform = local
	p.emitting = true
	var d := duree if niv == 2 else duree * 0.4
	var tw := p.create_tween()
	var t := 0.0
	var battement := 0.42
	while t < d:
		var force := 1.0 - t / d * 0.75
		tw.tween_property(p, "amount_ratio", force, 0.06)
		tw.tween_property(p, "amount_ratio", 0.18 * force, battement - 0.06)
		t += battement
	tw.tween_callback(func() -> void: p.emitting = false)
	tw.tween_interval(p.lifetime + 0.1)
	tw.tween_callback(p.queue_free)
	# gouttes au sol sous le jet
	var gouttes := MAX_GOUTTES_JET if niv == 2 else 2
	var tg := p.create_tween()
	for g in gouttes:
		tg.tween_interval(d / gouttes)
		tg.tween_callback(func() -> void:
			if not is_instance_valid(p) or not p.is_inside_tree():
				return
			var dir_jet := p.global_transform.basis.y.normalized()
			var vers := p.global_position + Vector3(dir_jet.x, 0, dir_jet.z) * randf_range(0.3, 0.9)
			var r := sol_sous(p, vers, 1.5, 3.0)
			if not r.is_empty():
				trace(p, r["position"], r["normal"], Vector3(dir_jet.x, 0, dir_jet.z), randf_range(0.2, 0.38), couleur, "giclure"))
	return p

## Flaque qui s'étale sous un corps (sol trouvé par rayon sous `pos`).
static func flaque(n: Node3D, pos: Vector3, couleur: Color, taille := 0.9, croissance := 4.0) -> Node3D:
	if niveau() == 0:
		return null
	var r := sol_sous(n, pos, 0.8, 3.0)
	if r.is_empty():
		return null
	var t := taille if niveau() == 2 else taille * 0.45
	return trace(n, r["position"], r["normal"], Vector3.ZERO, t, couleur, "flaque", croissance)

# ------------------------------------------------------------------ traces collées

static func gestion(n: Node) -> Node3D:
	var arbre := n.get_tree()
	var g := arbre.get_first_node_in_group("gestion_sang") as Node3D
	if g == null:
		g = Node3D.new()
		g.name = "GestionSang"
		g.add_to_group("gestion_sang")
		g.set_meta("traces", [])
		var scene := arbre.current_scene
		(scene if scene else arbre.root).add_child(g)
	return g

## Nombre de traces vivantes dans la scène (tests du plafond).
static func nombre_traces(n: Node) -> int:
	var g := n.get_tree().get_first_node_in_group("gestion_sang")
	if g == null:
		return 0
	var l: Array = g.get_meta("traces")
	return l.filter(func(x: Variant) -> bool: return is_instance_valid(x)).size()

static func trace(n: Node, pos: Vector3, normale: Vector3, direction: Vector3, taille: float, couleur: Color, sorte := "giclure", croissance := 0.0, delai := 0.0) -> MeshInstance3D:
	if niveau() == 0 or n == null or not n.is_inside_tree():
		return null
	var g := gestion(n)
	var l: Array = g.get_meta("traces")
	l = l.filter(func(x: Variant) -> bool: return is_instance_valid(x))
	while l.size() >= MAX_TRACES:
		var vieux: Node = l.pop_front()
		vieux.queue_free()
	if _plan == null:
		_plan = PlaneMesh.new()
		_plan.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = _plan
	mi.material_override = _mat_trace(sorte, couleur)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	l.append(mi)
	g.set_meta("traces", l)
	var y := normale.normalized() if normale.length() > 0.01 else Vector3.UP
	var x := direction - y * direction.dot(y)
	if x.length() < 0.05:
		x = y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).rotated(y, randf() * TAU)
	x = x.normalized()
	var z := x.cross(y)
	var allonge := 2.6 if sorte == "trainee" else (1.35 if sorte == "giclure" else 1.0)
	var ordre := float(l.size() % 16) * 0.0009   # traces superposées : pas de scintillement
	var base := Basis(x * taille * allonge, y, z * taille)
	mi.global_transform = Transform3D(base, pos + y * (0.012 + ordre))
	var tw := mi.create_tween()
	if croissance > 0.0 or delai > 0.0:
		var depart := 0.2 if croissance > 0.0 else 0.6
		mi.scale = Vector3(depart, 1.0, depart) * mi.scale
		var fin := mi.scale / Vector3(depart, 1.0, depart)
		mi.visible = delai <= 0.0
		if delai > 0.0:
			tw.tween_interval(delai)
			tw.tween_callback(func() -> void: mi.visible = true)
		tw.tween_property(mi, "scale", fin, croissance if croissance > 0.0 else 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(DUREE_TRACE)
	tw.tween_callback(mi.queue_free)
	return mi

static func _mat_trace(sorte: String, c: Color) -> StandardMaterial3D:
	var v := randi() % 3
	var cle := "%s|%d|%s" % [sorte, v, c.to_html()]
	if not _mats.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_texture = texture(sorte, v)
		m.albedo_color = Color(minf(c.r * 1.7, 1.0), minf(c.g * 1.7, 1.0), minf(c.b * 1.7, 1.0))
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.roughness = 0.22
		m.metallic_specular = 0.75   # mouillé
		_mats[cle] = m
	return _mats[cle]

# ------------------------------------------------------------------ textures (peintes par code, texels nets, jamais de tramage)

## Textures en niveaux de gris (teintées par le matériau) : flaque, giclure, trainee, entaille, fissure, copeau.
static func texture(sorte: String, variante := 0) -> ImageTexture:
	var cle := "%s%d" % [sorte, variante]
	if not _tex.has(cle):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(cle)
		var img: Image
		match sorte:
			"flaque":
				img = _img_flaque(rng, 32, 0.0)
			"giclure":
				img = _img_flaque(rng, 32, 1.0)
			"trainee":
				img = _img_trainee(rng)
			"entaille":
				img = _img_entaille(rng)
			"fissure":
				img = _img_fissure(rng)
			_:
				img = _img_copeau(rng)
		_tex[cle] = ImageTexture.create_from_image(img)
	return _tex[cle]

static func _img_flaque(rng: RandomNumberGenerator, n: int, eclabousse: float) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bruit := FastNoiseLite.new()
	bruit.seed = rng.randi()
	bruit.frequency = 0.18
	var c := Vector2(n, n) * 0.5 - Vector2(eclabousse * n * 0.12, 0)
	var r0 := n * (0.36 if eclabousse < 0.5 else 0.22)
	for y in n:
		for x in n:
			var v := Vector2(x + 0.5, y + 0.5) - c
			var a := atan2(v.y, v.x)
			var rr := r0 * (0.72 + 0.45 * (bruit.get_noise_2d(cos(a) * 9.0, sin(a) * 9.0) * 0.5 + 0.5))
			var d := v.length()
			if d < rr:
				var bord := clampf((rr - d) / 2.2, 0.0, 1.0)
				var l := lerpf(1.0, 0.55, bord) * (0.9 + 0.1 * bruit.get_noise_2d(x * 3.0, y * 3.0))
				img.set_pixel(x, y, Color(l, l, l, 1.0))
	# gouttes satellites (vers +X pour une giclure : la direction du coup)
	var nb := 6 + int(eclabousse * 14.0)
	for k in nb:
		var ang := rng.randf_range(-0.6, 0.6) if eclabousse > 0.5 else rng.randf() * TAU
		var dist := rng.randf_range(r0 * 1.05, n * 0.48)
		var p := c + Vector2(cos(ang), sin(ang)) * dist
		var t := 1 if rng.randf() < 0.7 else 2
		for yy in t:
			for xx in t + (1 if eclabousse > 0.5 and rng.randf() < 0.5 else 0):
				var px := int(p.x) + xx
				var py := int(p.y) + yy
				if px >= 0 and py >= 0 and px < n and py < n:
					img.set_pixel(px, py, Color(0.85, 0.85, 0.85, 1.0))
	return img

static func _img_trainee(rng: RandomNumberGenerator) -> Image:
	# traînée de giclure : chapelet de gouttes ovales de plus en plus petites (pas un cône lisse), quelques gouttes perdues
	var w := 64
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var x := 4.0
	var cy := h * 0.5
	while x < w - 3:
		var k := x / w
		var r := lerpf(5.0, 1.2, k) * rng.randf_range(0.7, 1.15)
		cy = clampf(cy + rng.randf_range(-1.2, 1.2), 5.0, h - 6.0)
		for yy in range(int(cy - r) - 1, int(cy + r) + 2):
			for xx in range(int(x - r * 1.4) - 1, int(x + r * 1.4) + 2):
				if xx < 0 or yy < 0 or xx >= w or yy >= h:
					continue
				var d := Vector2((xx + 0.5 - x) / 1.4, yy + 0.5 - cy).length()
				if d < r:
					var l := lerpf(0.6, 1.0, d / r)
					img.set_pixel(xx, yy, Color(l, l, l, 1.0))
		x += r * rng.randf_range(1.6, 3.2)
		if rng.randf() < 0.5:
			var py := clampi(int(cy + rng.randf_range(-8, 8)), 0, h - 1)
			var px := clampi(int(x + rng.randf_range(-3, 3)), 0, w - 1)
			img.set_pixel(px, py, Color(0.8, 0.8, 0.8, 1.0))
	return img

static func _img_entaille(rng: RandomNumberGenerator) -> Image:
	# plaie : fente sombre (chair ouverte) bordée de lèvres rouges vives, éclaboussée autour, coulures vers le bas (+Y de l'image)
	var w := 32
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pente := rng.randf_range(-0.15, 0.15)
	for x in range(1, w - 1):
		var k := float(x - 1) / (w - 2)
		var ep := sin(k * PI) * rng.randf_range(3.2, 4.2) + 0.6
		var cy := 8.0 + (x - w * 0.5) * pente
		for y in h:
			var d := absf(y + 0.5 - cy)
			if d < ep:
				var l := 0.12 if d < ep * 0.4 else (1.0 if d < ep * 0.75 else 0.7)
				img.set_pixel(x, y, Color(l, l, l, 1.0))
		# coulures
		if rng.randf() < 0.3 and k > 0.15 and k < 0.85:
			var lg := rng.randi_range(4, 13)
			var y0 := int(cy + ep)
			for y in range(y0, mini(y0 + lg, h)):
				var l := 0.85 if y < y0 + lg - 1 else 0.65
				img.set_pixel(x, y, Color(l, l, l, 1.0))
				if y == y0 + lg - 1 and x + 1 < w:
					img.set_pixel(x + 1, y, Color(l, l, l, 1.0))
		# éclaboussures autour
		if rng.randf() < 0.18:
			var py := clampi(int(cy + rng.randf_range(-ep - 4, ep + 4)), 0, h - 1)
			img.set_pixel(x, py, Color(0.8, 0.8, 0.8, 1.0))
	return img

static func _img_fissure(rng: RandomNumberGenerator) -> Image:
	var n := 32
	var m := 16
	var img := Image.create(n, m, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var p := Vector2(2, n * 0.25)
	for i in 40:
		p += Vector2(0.75, rng.randf_range(-0.9, 0.9))
		p.y = clampf(p.y, 1, m - 2)
		img.set_pixel(clampi(int(p.x), 0, n - 1), int(p.y), Color(0.18, 0.18, 0.18, 1.0))
		if rng.randf() < 0.18:
			var q := p
			for j in rng.randi_range(2, 5):
				q += Vector2(rng.randf_range(0.0, 1.0), rng.randf_range(-1.2, 1.2))
				var qx := clampi(int(q.x), 0, n - 1)
				var qy := clampi(int(q.y), 0, m - 1)
				img.set_pixel(qx, qy, Color(0.3, 0.3, 0.3, 1.0))
	return img

static func _img_copeau(rng: RandomNumberGenerator) -> Image:
	var w := 32
	var h := 12
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(3, w - 3):
		var ep := sin(float(x - 3) / (w - 6) * PI) * 2.6 + 0.3
		for y in h:
			var d := absf(y + 0.5 - h * 0.5)
			if d < ep:
				var l := 1.0 if d < ep * 0.6 else 0.35
				img.set_pixel(x, y, Color(l, l, l, 1.0) * rng.randf_range(0.9, 1.0))
	return img
