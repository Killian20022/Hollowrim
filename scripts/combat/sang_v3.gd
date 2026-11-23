class_name SangV3
## SANG V3 (2026-11-23, combat/sang_v3) — moteur des effets derrière la façade `Sang` (API publique inchangée, docs/SANG_V3.md).
## - Giclées : jet principal dans le sens du coup (traits alignés sur la vitesse) + gouttelettes de tailles variées + (sortie) brume fine ;
##   émetteurs GPUParticles3D en POOL plafonné (POOL_* par sorte, quantité fixe, amount_ratio par coup : aucune allocation, aucun
##   matériau neuf ; rien ne tourne hors combat).
## - Gouttes balistiques (GouttesSang) : de vraies gouttes partent avec la giclée, volent, et tachent là où elles tombent
##   (sol, mur, prop), tache allongée dans le sens du vol.
## - Traces : plans ou petites grilles PROJETÉES (rayons) qui épousent le relief, shader propre (couleur fraîche → sèche, reflet
##   mouillé qui s'éteint, effacement par épaisseur : le film mince disparaît d'abord, jamais de fondu ni de tramage) ;
##   sur la neige, un liseré de sang dilué (rose sombre) fait ressortir la tache.
## - Palettes par sang (couleur passée par l'appelant = ProfilCible.couleur_sang) : vif (humains, bêtes), draugr (noirâtre, froid),
##   troll (sombre violacé), araignee (verdâtre). Squelette / bois : pas de sang (Sang.eclats_matiere).
## `--sans-sang-v3` : comportement v2 exact.

static var actif := not OS.get_cmdline_user_args().has("--sans-sang-v3")
## Temps CPU par poste (µs, mesures) : émetteurs, gouttes, rayons + traces de la giclée.
static var prof := {"emetteurs": 0, "gouttes": 0, "traces": 0, "grilles": 0, "plans": 0, "us_grilles": 0}

const POOL_JET := 8
const POOL_GOUTTELETTES := 8
const POOL_BRUME := 4
const AMOUNT := {"jet": 48, "gouttelettes": 40, "brume": 56}
## Gouttes balistiques par giclée (× intensité, plafonnées) : celles qui tachent vraiment où elles tombent.
const GOUTTES_MAX := 9

# ------------------------------------------------------------------ palettes

const PALETTES := {
	# frais : sang qui vient de couler ; sec : brun-noir après séchage ; halo : sang dilué dans la neige ; vol : particules en vol
	"vif": {"frais": Color(0.38, 0.03, 0.024), "sec": Color(0.12, 0.03, 0.024), "halo": Color(0.55, 0.19, 0.19), "vol": Color(0.34, 0.032, 0.026), "brille": 0.75},
	"draugr": {"frais": Color(0.19, 0.05, 0.042), "sec": Color(0.075, 0.05, 0.045), "halo": Color(0.36, 0.25, 0.24), "vol": Color(0.18, 0.045, 0.038), "brille": 0.6},
	"troll": {"frais": Color(0.22, 0.035, 0.065), "sec": Color(0.10, 0.035, 0.05), "halo": Color(0.48, 0.24, 0.32), "vol": Color(0.26, 0.04, 0.075), "brille": 0.65},
	"araignee": {"frais": Color(0.20, 0.24, 0.06), "sec": Color(0.11, 0.12, 0.045), "halo": Color(0.48, 0.52, 0.30), "vol": Color(0.24, 0.28, 0.07), "brille": 0.7},
}

## Sorte de sang d'après la couleur du profil (araignée : vert dominant ; troll : bleu > vert ; vif : r ≥ 0,33 ; sinon draugr).
static func sorte_sang(c: Color) -> String:
	if c.g > c.r:
		return "araignee"
	if c.b > c.g * 1.25 and c.b > 0.05:
		return "troll"
	if c.r >= 0.33:
		return "vif"
	return "draugr"

static func palette(c: Color) -> Dictionary:
	return PALETTES[sorte_sang(c)]

## Couleur à donner aux anciens consommateurs (plaies, lame) pour la sorte de sang : le draugr devient noirâtre.
static func couleur(c: Color) -> Color:
	if not actif:
		return c
	return palette(c)["frais"]

# ------------------------------------------------------------------ giclées

## Giclée v3. `sorte` : "impact" (coup), "sortie" (plaie de sortie : jet arrière plus fort + brume), "entree" (petite, vers l'attaquant).
static func giclee(n: Node, point: Vector3, direction: Vector3, intensite: float, couleur_sang: Color, traces: bool, sorte := "impact") -> void:
	var niv := Sang.niveau()
	var k := intensite * (1.0 if niv == 2 else 0.35)
	var dir := direction.normalized() if direction.length() > 0.01 else Vector3.UP
	var pal := palette(couleur_sang)
	var arbre := n.get_tree()
	var sortie := sorte == "sortie"
	var entree := sorte == "entree"
	var sk := sqrt(maxf(k, 0.05))
	var t0 := Time.get_ticks_usec()
	# jet principal : cône serré dans le sens du coup, un peu relevé (le sang « suit » la lame)
	var d_jet := (dir + Vector3.UP * (0.12 if sortie else 0.22)).normalized()
	var force := "fort" if (k > 2.0 or sortie) else ("moyen" if k > 0.9 else "faible")
	_tirer(arbre, "jet", force, point, d_jet, clampf(k * (0.5 if sortie else 0.36) * (0.5 if entree else 1.0), 0.15, 1.0), pal)
	# gouttelettes de tailles variées, plus larges, plus lentes
	_tirer(arbre, "gouttelettes", force, point, (dir + Vector3.UP * 0.45).normalized(), clampf(k * 0.28 * (0.6 if entree else 1.0), 0.15, 1.0), pal)
	# brume fine (sortie, gros coups) : nuage de points qui dérive et retombe à peine
	if sortie or k > 2.4:
		_tirer(arbre, "brume", "faible", point + dir * 0.05, dir, clampf(k * (0.45 if sortie else 0.22), 0.25, 1.0), pal)
	var t1 := Time.get_ticks_usec()
	prof["emetteurs"] += t1 - t0
	# vraies gouttes (balistiques) : tachent là où elles tombent (sol, mur, prop)
	var nb := clampi(int(round(k * (3.2 if sortie else 2.3))), 2, GOUTTES_MAX)
	if niv < 2:
		nb = mini(nb, 2)
	for j in nb:
		var v := (d_jet + Vector3(randf_range(-0.28, 0.28), randf_range(-0.1, 0.3), randf_range(-0.28, 0.28))).normalized()
		v *= randf_range(2.2, 4.6) * clampf(sk, 0.7, 1.6) * (1.3 if sortie else 1.0)
		GouttesSang.lacher_balistique(n, point + dir * 0.05, pal["vol"], v, randf_range(0.8, 1.7) * (1.2 if sortie else 1.0))
	var t2 := Time.get_ticks_usec()
	prof["gouttes"] += t2 - t1
	if traces:
		_traces(n, point, dir, k, couleur_sang, niv, sortie)
	prof["traces"] += Time.get_ticks_usec() - t2

## Émetteur du pool (le plus ancien est repris), réglé et relancé.
static func _tirer(arbre: SceneTree, sorte: String, force: String, point: Vector3, dir: Vector3, ratio: float, pal: Dictionary) -> void:
	var g := Sang.gestion_racine(arbre)
	if g == null:
		return
	var cle := "pool_" + sorte
	var pool: Array = g.get_meta(cle, [])
	var maxi := POOL_JET if sorte == "jet" else (POOL_GOUTTELETTES if sorte == "gouttelettes" else POOL_BRUME)
	var p: GPUParticles3D
	if pool.size() < maxi:
		p = GPUParticles3D.new()
		p.name = "Giclee_" + sorte
		p.one_shot = true
		p.amount = AMOUNT[sorte]
		p.explosiveness = 0.9 if sorte != "brume" else 0.8
		p.lifetime = 0.9 if sorte != "brume" else 0.75
		p.local_coords = false
		p.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.emitting = false
		g.add_child(p)
		pool.append(p)
		g.set_meta(cle, pool)
		g.set_meta("tour_" + sorte, 0)
	else:
		var t: int = g.get_meta("tour_" + sorte, 0)
		p = pool[t % pool.size()]
		g.set_meta("tour_" + sorte, t + 1)
	p.process_material = pm(sorte, force)
	p.draw_pass_1 = maille(sorte, pal)
	p.amount_ratio = clampf(ratio, 0.05, 1.0)
	p.global_transform = Transform3D(_vers(dir), point)
	p.restart()
	p.emitting = true

static var _pm := {}
static func pm(sorte: String, force: String) -> ParticleProcessMaterial:
	var cle := sorte + force
	if _pm.has(cle):
		return _pm[cle]
	var f := {"faible": 0.7, "moyen": 1.0, "fort": 1.35}[force] as float
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.gravity = Vector3(0, -9.8, 0)
	m.color = Color.WHITE
	match sorte:
		"jet":
			m.spread = 9.0
			m.initial_velocity_min = 2.4 * f
			m.initial_velocity_max = 5.2 * f
			m.particle_flag_align_y = true   # traits allongés le long de la vitesse
			m.scale_min = 0.55
			m.scale_max = 1.5
			m.damping_min = 0.4
			m.damping_max = 1.2
		"gouttelettes":
			m.spread = 34.0
			m.initial_velocity_min = 0.8 * f
			m.initial_velocity_max = 3.4 * f
			m.particle_flag_align_y = true
			m.scale_min = 0.35
			m.scale_max = 1.9   # tailles très variées : poussière de gouttes et quelques grosses
			m.damping_min = 0.2
			m.damping_max = 0.8
		_:
			m.spread = 60.0
			m.initial_velocity_min = 0.25
			m.initial_velocity_max = 1.5
			m.gravity = Vector3(0, -1.6, 0)   # brume : retombe à peine, freinée par l'air
			m.damping_min = 2.2
			m.damping_max = 4.0
			m.scale_min = 0.6
			m.scale_max = 1.3
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.05
	# rampe : un poil plus clair à la sortie (sang qui accroche la lumière), plus sombre en retombant (pas de rouge fluo)
	var g := Gradient.new()
	g.set_color(0, Color(1.12, 1.12, 1.12))
	g.set_color(1, Color(0.62, 0.62, 0.62))
	var rt := GradientTexture1D.new()
	rt.gradient = g
	m.color_initial_ramp = rt
	if sorte == "brume":
		# la brume rétrécit en mourant (les points disparaissent un à un : pas de transparence)
		var c := Curve.new()
		c.add_point(Vector2(0, 1))
		c.add_point(Vector2(0.7, 0.8))
		c.add_point(Vector2(1, 0))
		var ct := CurveTexture.new()
		ct.curve = c
		m.scale_curve = ct
	_pm[cle] = m
	return m

static var _mailles := {}
static func maille(sorte: String, pal: Dictionary) -> BoxMesh:
	var c: Color = pal["vol"]
	var cle := sorte + c.to_html()
	if _mailles.has(cle):
		return _mailles[cle]
	var b := BoxMesh.new()
	match sorte:
		"jet":
			b.size = Vector3(0.016, 0.055, 0.016)
		"gouttelettes":
			b.size = Vector3(0.016, 0.024, 0.016)
		_:
			b.size = Vector3(0.011, 0.011, 0.011)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c if sorte != "brume" else c * 1.15
	m.roughness = 0.18
	m.metallic_specular = 0.8   # humide : petit reflet sur les grosses gouttes
	m.emission_enabled = true
	m.emission = c * 0.18      # lisible dans la pénombre sans briller (v2 : 0,35)
	b.material = m
	_mailles[cle] = b
	return b

static func _vers(dir: Vector3) -> Basis:
	var y := dir.normalized() if dir.length() > 0.001 else Vector3.UP
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))

# ------------------------------------------------------------------ éclaboussures derrière la cible

## Murs / props derrière la cible : un éventail de rayons dans le sens du coup ; sol : 1-2 giclures au pied (les gouttes
## balistiques font le reste là où elles tombent).
static func _traces(n: Node, point: Vector3, dir: Vector3, k: float, c: Color, niv: int, sortie: bool) -> void:
	if not (n is Node3D):
		return
	var espace := (n as Node3D).get_world_3d().direct_space_state
	var exclus := Sang._exclus(n.get_tree())
	var portee := clampf(1.6 + k * 0.6, 1.8, 3.6) * (1.3 if sortie else 1.0)
	var nb := (3 if sortie else (2 if k >= 1.0 else 1)) if niv == 2 else 1
	var poses := 0
	for j in nb:
		var ecart := Vector3(randf_range(-0.3, 0.3), randf_range(-0.25, 0.1), randf_range(-0.3, 0.3)) * (0.0 if j == 0 else 1.0)
		var d := (dir + ecart).normalized()
		var q := PhysicsRayQueryParameters3D.create(point, point + d * portee, 1, exclus)
		var r := espace.intersect_ray(q)
		if r.is_empty() or not Sang._surface(r, true):
			continue
		var dist := point.distance_to(r["position"])
		var t := clampf(0.22 + k * 0.08, 0.22, 0.55) * clampf(1.25 - dist / portee * 0.6, 0.6, 1.2) * (1.25 if sortie else 1.0)
		var nrm: Vector3 = r["normal"]
		var sup: Node3D = r["collider"] if r["collider"] is RigidBody3D else null   # prop mobile : la tache le suit
		Sang.trace(n, r["position"], nrm, d, t, c, "giclure", 0.0, 0.05 + dist / 7.0, sup)
		poses += 1
		# mur : un filet coule sous la giclure (Liquides : vraie coulure qui descend le mur, se dépose et finit au sol)
		if absf(nrm.y) < 0.5 and Liquides.actif and sup == null:
			var l := Liquides.obtenir(n)
			if l != null:
				var ml := clampf(1.5 + k * 1.6, 1.5, 6.0) * (1.4 if sortie else 1.0)
				l.get_tree().create_timer(0.05 + dist / 7.0).timeout.connect(func() -> void:
					if is_instance_valid(l):
						l.coulure(l, r["position"] as Vector3 + (Vector3.DOWN - nrm * Vector3.DOWN.dot(nrm)).normalized() * t * 0.2, nrm, Liquides.sang_de(c), ml, c))
		elif absf(nrm.y) < 0.5 and niv == 2 and randf() < 0.5:
			var bas := (Vector3.DOWN - nrm * Vector3.DOWN.dot(nrm)).normalized()
			Sang.trace(n, r["position"] + bas * t * 0.35, nrm, bas, t * 0.55, c, "coulure", 3.5, 0.4 + dist / 7.0, sup)
	# au pied : une giclure dans le sens du coup
	var plat := Vector3(dir.x, 0, dir.z)
	plat = plat.normalized() if plat.length() > 0.05 else Vector3.FORWARD
	# au sol, dans le sens du coup : 1 à 3 giclures de plus en plus loin et petites (là où tombe le gros du jet)
	var nb_sol := clampi(1 + int(k * 0.6), 1, 3) if niv == 2 else 1
	for j in nb_sol:
		var de := point + plat * (0.4 + j * 0.45 * clampf(k, 0.6, 2.0)) + plat.cross(Vector3.UP) * randf_range(-0.18, 0.18)
		var r2 := Sang.sol_sous(n as Node3D, de, 0.4, 3.0)
		if not r2.is_empty():
			# (liquides : un peu plus larges, le sang au sol d'un intérieur sombre restait trop discret)
			Sang.trace(n, r2["position"], r2["normal"], plat, randf_range(0.3, 0.42) * clampf(k, 0.6, 1.6) * (1.0 - j * 0.22) * (1.0 if niv == 2 else 0.6) * (1.2 if Liquides.actif else 1.0), c, "giclure", 0.0, 0.12 + j * 0.07)

# ------------------------------------------------------------------ traces : matériau, relief

static var _mat_trace := {}
static var _shader: Shader

## Matériau partagé (sorte de trace, variante de texture, sorte de sang, neige) ; l'âge de CHAQUE trace passe par des uniformes
## d'instance (`seche`, `efface`).
static func materiau_trace(forme: String, variante: int, c: Color, neige: bool) -> ShaderMaterial:
	var s := sorte_sang(c)
	var cle := "%s|%d|%s|%s" % [forme, variante, s, neige]
	if _mat_trace.has(cle):
		return _mat_trace[cle]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE_TRACE
	var pal: Dictionary = PALETTES[s]
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("masque", texture(forme, variante))
	var fr: Color = pal["frais"]
	var se: Color = pal["sec"]
	if neige:
		# sur la neige : le sang ressort plus saturé (la neige blanche le fait « claquer »), halo de sang dilué autour
		fr = Color(minf(fr.r * 1.12, 1.0), fr.g * 0.9, fr.b * 0.9)
	m.set_shader_parameter("frais", fr)
	m.set_shader_parameter("sec", se)
	m.set_shader_parameter("halo", pal["halo"])
	m.set_shader_parameter("neige", 1.0 if neige else 0.0)
	m.set_shader_parameter("brille", float(pal["brille"]))
	m.render_priority = -1
	_mat_trace[cle] = m
	return m

## Shader des traces : masque RGBA (R épaisseur 0-1, G = liseré « dilué » (neige seulement), A = couverture). Effacement par
## l'épaisseur (le film mince part d'abord) ; séchage par paliers (les bords minces sèchent avant le cœur). Découpe alpha nette.
const CODE_TRACE := """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;
uniform sampler2D masque : filter_nearest, repeat_disable;
uniform vec3 frais : source_color;
uniform vec3 sec : source_color;
uniform vec3 halo : source_color;
uniform float neige = 0.0;
uniform float brille = 0.7;
instance uniform float seche = 0.0;
instance uniform float efface = 0.0;
void fragment() {
	vec4 m = texture(masque, UV);
	float ep = m.r;
	float lisere = step(0.5, m.g);
	float garde = step(0.5, m.a) * (1.0 - lisere * (1.0 - neige));
	// effacement : l'épaisseur doit dépasser le seuil qui monte (paliers nets, jamais de fondu)
	garde *= step(efface * 1.02, ep + 0.001 - lisere * 0.35);
	// séchage : un texel sèche quand l'âge dépasse son épaisseur (les bords minces avant le cœur)
	float s = step(ep * 0.85 + 0.1, seche);
	vec3 c = mix(frais, sec, s);
	c *= mix(1.15, 0.94, ep);                      // film mince un peu plus clair, cœur épais plus sombre (caillot)
	c = mix(c, halo, lisere);
	ALBEDO = c;
	ALPHA = garde;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	float mouille = (1.0 - s) * (1.0 - lisere);
	ROUGHNESS = mix(0.85, 0.14, mouille);
	SPECULAR = mix(0.25, brille, mouille);
	METALLIC = 0.0;
}
"""

## Les quatre coins et le centre sont projetés sur la surface : si elle est plane (écart < 1,5 cm), plan partagé ; sinon grille
## 5 x 5 dont chaque sommet est posé sur la surface par un rayon (la tache épouse marches, pierres, bosses de neige).
const GRILLE := 5
static var _plan: PlaneMesh

static func maille_projetee(n: Node3D, xf: Transform3D, demi_x: float, demi_z: float, leve := 0.0) -> Mesh:
	if _plan == null:
		_plan = PlaneMesh.new()
		_plan.size = Vector2.ONE
	if n == null or not n.is_inside_tree():
		return _plan
	var espace := n.get_world_3d().direct_space_state
	var exclus := Sang._exclus(n.get_tree())
	var y := xf.basis.y.normalized()
	var x := xf.basis.x.normalized()
	var z := xf.basis.z.normalized()
	var o := xf.origin
	var sonde := func(u: float, v: float) -> Variant:
		var p := o + x * u * demi_x + z * v * demi_z
		var q := PhysicsRayQueryParameters3D.create(p + y * 0.18, p - y * 0.3, 1, exclus)
		var r := espace.intersect_ray(q)
		if r.is_empty() or r["collider"] is PhysicalBone3D or r["collider"] is CharacterBody3D:
			return null   # un corps (ragdoll) n'est pas le sol : la flaque passe dessous, elle ne le recouvre pas
		return (r["position"] as Vector3 - p).dot(y)
	# la trace flotte un peu au-dessus de la surface (décalage anti-scintillement) : on compare chaque coin au centre
	var h0: Variant = sonde.call(0.0, 0.0)
	var plat := h0 != null
	if plat:
		for uv: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var h: Variant = sonde.call(uv.x, uv.y)
			if h == null or absf(float(h) - float(h0)) > 0.015:
				plat = false
				break
	if plat:
		prof["plans"] += 1
		return _plan
	prof["grilles"] += 1
	var tg := Time.get_ticks_usec()
	var hauts := PackedFloat32Array()
	hauts.resize(GRILLE * GRILLE)
	for j in GRILLE:
		for i in GRILLE:
			var u := float(i) / (GRILLE - 1) * 2.0 - 1.0
			var v := float(j) / (GRILLE - 1) * 2.0 - 1.0
			var h: Variant = sonde.call(u, v)
			# chaque sommet sur la surface, relevé de `leve` (le décalage de la trace au-dessus de sa surface)
			hauts[j * GRILLE + i] = clampf(float(h) + leve, -0.3, 0.18) if h != null else 0.0
	var m := grille(hauts)
	prof["us_grilles"] += Time.get_ticks_usec() - tg
	return m

## Grille 5 x 5 du repère unitaire d'une trace, hauteurs (le long de la normale) en mètres. (Aussi : préchauffage du format.)
static var _indices := PackedInt32Array()
static var _uvs := PackedVector2Array()
static var _normales := PackedVector3Array()

static func grille(hauts: PackedFloat32Array) -> ArrayMesh:
	if hauts.size() < GRILLE * GRILLE:
		hauts.resize(GRILLE * GRILLE)
	if _indices.is_empty():
		for jj in GRILLE:
			for ii in GRILLE:
				_uvs.append(Vector2(float(ii) / (GRILLE - 1), float(jj) / (GRILLE - 1)))
				_normales.append(Vector3.UP)
		for jj in GRILLE - 1:
			for ii in GRILLE - 1:
				var a := jj * GRILLE + ii
				_indices.append_array([a, a + 1, a + GRILLE, a + 1, a + GRILLE + 1, a + GRILLE])
	# repère local d'une trace : plan unitaire (x, z ∈ [-0,5 ; 0,5]), hauteur en mètres (l'axe y de la trace n'est pas mis à l'échelle)
	var v := PackedVector3Array()
	v.resize(GRILLE * GRILLE)
	for k in GRILLE * GRILLE:
		v[k] = Vector3(_uvs[k].x - 0.5, hauts[k], _uvs[k].y - 0.5)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = _normales
	arr[Mesh.ARRAY_TEX_UV] = _uvs
	arr[Mesh.ARRAY_INDEX] = _indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

# ------------------------------------------------------------------ textures (peintes par code, RGBA : épaisseur, liseré, couverture)

static var _tex := {}
static func texture(forme: String, variante: int) -> ImageTexture:
	var cle := "%s%d" % [forme, variante]
	if _tex.has(cle):
		return _tex[cle]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("v3" + cle)
	var img: Image
	match forme:
		"flaque":
			img = _img_tache(rng, 48, 0.0)
		"giclure":
			img = _img_tache(rng, 40, 1.0)
		"trainee":
			img = _img_trainee(rng)
		"coulure":
			img = _img_coulure(rng)
		_:
			img = _img_tache(rng, 16, 0.4)   # « goutte » : petite tache ronde
	_lisere(img)
	_tex[cle] = ImageTexture.create_from_image(img)
	return _tex[cle]

## Liseré d'un texel autour de la tache (G = 1, A = 1) : sang dilué, visible seulement sur la neige.
static func _lisere(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			var voisin := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var px := x + d.x
				var py := y + d.y
				if px >= 0 and py >= 0 and px < w and py < h and src.get_pixel(px, py).a > 0.5 and src.get_pixel(px, py).g < 0.5:
					voisin = true
					break
			if voisin:
				img.set_pixel(x, y, Color(0.3, 1.0, 0.0, 1.0))

## Tache organique : contour bruité, épaisseur qui monte vers le cœur (R), gouttes satellites minces (vers +X pour une giclure).
static func _img_tache(rng: RandomNumberGenerator, n: int, eclabousse: float) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bruit := FastNoiseLite.new()
	bruit.seed = rng.randi()
	bruit.frequency = 0.16
	var c := Vector2(n, n) * 0.5 - Vector2(eclabousse * n * 0.14, 0)
	var r0 := n * (0.34 if eclabousse < 0.5 else 0.2)
	for y in n:
		for x in n:
			var v := Vector2(x + 0.5, y + 0.5) - c
			# giclure : la tache s'étire dans le sens du coup (+X), arrondie à l'arrière
			if eclabousse > 0.5 and v.x > 0.0:
				v.x *= 0.62
			var a := atan2(v.y, v.x)
			var rr := r0 * (0.7 + 0.5 * (bruit.get_noise_2d(cos(a) * 8.0, sin(a) * 8.0) * 0.5 + 0.5))
			var d := v.length()
			if d < rr:
				var ep := clampf((rr - d) / (rr * 0.8), 0.0, 1.0)
				ep = clampf(ep + bruit.get_noise_2d(x * 2.6, y * 2.6) * 0.18, 0.05, 1.0)
				img.set_pixel(x, y, Color(ep, 0.0, 0.0, 1.0))
	# satellites (minces : ils sèchent et s'effacent les premiers)
	var nb := 5 + int(eclabousse * 16.0)
	for k in nb:
		var ang := rng.randf_range(-0.5, 0.5) if eclabousse > 0.5 else rng.randf() * TAU
		var dist := rng.randf_range(r0 * 1.15, n * 0.47)
		var p := c + Vector2(cos(ang), sin(ang)) * dist
		var t := 1 if rng.randf() < 0.65 else 2
		for yy in t:
			for xx in t + (1 if eclabousse > 0.5 and rng.randf() < 0.6 else 0):
				var px := int(p.x) + xx
				var py := int(p.y) + yy
				if px >= 1 and py >= 1 and px < n - 1 and py < n - 1:
					img.set_pixel(px, py, Color(rng.randf_range(0.15, 0.4), 0.0, 0.0, 1.0))
	return img

static func _img_trainee(rng: RandomNumberGenerator) -> Image:
	# traînée (corps traîné, giclée rasante) : bande irrégulière qui s'amincit, stries dans le sens du mouvement, gouttes perdues
	var w := 64
	var h := 20
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bruit := FastNoiseLite.new()
	bruit.seed = rng.randi()
	bruit.frequency = 0.12
	for x in range(2, w - 2):
		var k := float(x) / w
		var demi := lerpf(6.5, 1.6, k) * (0.8 + 0.35 * (bruit.get_noise_1d(x * 1.3) * 0.5 + 0.5))
		var cy := h * 0.5 + bruit.get_noise_1d(x * 0.7 + 50.0) * 2.0
		for y in h:
			var d := absf(y + 0.5 - cy)
			if d < demi:
				var strie := bruit.get_noise_2d(x * 0.25, y * 3.0)
				if strie < -0.45 and d > demi * 0.3:
					continue   # stries : le sol transparaît entre les filets
				var ep := clampf((1.0 - d / demi) * lerpf(1.0, 0.45, k) + strie * 0.15, 0.08, 1.0)
				img.set_pixel(x, y, Color(ep, 0.0, 0.0, 1.0))
	for g in 8:
		var px := rng.randi_range(4, w - 3)
		var py := rng.randi_range(1, h - 2)
		if img.get_pixel(px, py).a == 0.0:
			img.set_pixel(px, py, Color(0.25, 0.0, 0.0, 1.0))
	return img

static func _img_coulure(rng: RandomNumberGenerator) -> Image:
	# coulures sur un mur : 3-4 filets d'un à deux texels vers +X (le bas de la trace), terminés par une perle
	var w := 40
	var h := 20
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f in rng.randi_range(3, 4):
		var y := rng.randi_range(3, h - 4)
		var lg := rng.randi_range(14, w - 5)
		var large := 2 if rng.randf() < 0.4 else 1
		for x in range(1, lg):
			if rng.randf() < 0.12:
				y = clampi(y + (1 if rng.randf() < 0.5 else -1), 1, h - 3)
			for yy in large:
				img.set_pixel(x, y + yy, Color(lerpf(0.9, 0.35, float(x) / lg), 0.0, 0.0, 1.0))
		for dy in 2:
			for dx in 2:
				img.set_pixel(clampi(lg + dx - 1, 0, w - 1), clampi(y + dy, 0, h - 1), Color(1.0, 0.0, 0.0, 1.0))
	return img

# ------------------------------------------------------------------ vieillissement des traces

static func vieillissement(g: Node) -> Vieillissement:
	var v := g.get_node_or_null("Vieillissement") as Vieillissement
	if v == null:
		v = Vieillissement.new()
		v.name = "Vieillissement"
		g.add_child(v)
	return v

## Âge des traces sur l'horloge du jeu (pause et ralenti compris) : séchage en 6 paliers sur `seche` s, puis après
## Sang.DUREE_TRACE s, effacement en 6 paliers d'1 s et libération. Inactif quand il n'y a plus de trace.
class Vieillissement extends Node:
	var traces: Array = []
	var horloge := 0.0
	var _acc := 0.0
	var _par := {}

	## `vie` : âge (s) où l'effacement commence (défaut Sang.DUREE_TRACE ; liquides : selon la sorte et la surface).
	func ajouter(mi: MeshInstance3D, seche: float, vie := -1.0) -> void:
		var e: Variant = _par.get(mi.get_instance_id())
		var v := vie if vie > 0.0 else Sang.DUREE_TRACE
		if e != null and is_instance_valid((e as Array)[0]):
			# trace recyclée : son âge repart de zéro
			(e as Array)[1] = horloge
			(e as Array)[2] = seche
			(e as Array)[3] = 0
			(e as Array)[4] = 0
			(e as Array)[5] = v
		else:
			e = [mi, horloge, seche, 0, 0, v]
			traces.append(e)
			_par[mi.get_instance_id()] = e
		set_process(true)

	func _process(dt: float) -> void:
		horloge += dt
		_acc += dt
		if _acc < 0.5:
			return
		_acc = 0.0
		var i := 0
		while i < traces.size():
			var e: Array = traces[i]
			var mi: MeshInstance3D = e[0] if is_instance_valid(e[0]) else null
			if mi == null:
				_par.erase(e[0].get_instance_id() if is_instance_valid(e[0]) else -1)
				traces.remove_at(i)
				continue
			var age: float = horloge - float(e[1])
			var es := clampi(int(age / float(e[2]) * 6.0), 0, 6)
			if es != int(e[3]):
				mi.set_instance_shader_parameter("seche", es / 6.0)
				e[3] = es
			if age > float(e[5]):
				var ee := clampi(int(age - float(e[5])) + 1, 1, 7)
				if ee >= 7:
					_par.erase(mi.get_instance_id())
					mi.queue_free()
					traces.remove_at(i)
					continue
				if ee != int(e[4]):
					mi.set_instance_shader_parameter("efface", ee / 6.0)
					e[4] = ee
			i += 1
		if traces.is_empty():
			set_process(false)

	## Avance l'horloge (tests, captures).
	func avancer(s: float) -> void:
		horloge += s
		_acc = 1.0
		_process(0.0)

# ------------------------------------------------------------------ neige

static func sur_neige(pos: Vector3, normale: Vector3) -> bool:
	return normale.y > 0.6 and EffetsSol.est_neige(pos.x, pos.z)

# ------------------------------------------------------------------ traînées de corps

const MAX_SUIVIS := 3

## Traînée laissée par un corps qui glisse ou est projeté : pendant `duree` s, à chaque ~0,32 m parcouru près du sol, une trace
## « trainee » orientée selon le mouvement. Au plus MAX_SUIVIS corps suivis à la fois (le plus ancien cède sa place).
static func trainee_corps(corps: Node3D, c: Color, duree: float) -> Node:
	var g := Sang.gestion_racine(corps.get_tree())
	if g == null:
		return null
	var suivis: Array = g.get_meta("suivis", [])
	suivis = suivis.filter(func(x: Variant) -> bool: return is_instance_valid(x))
	while suivis.size() >= MAX_SUIVIS:
		(suivis.pop_front() as Node).queue_free()
	var s := SuiviTrainee.new()
	s.name = "SuiviTrainee"
	s.cible = weakref(corps)
	s.couleur = c
	s.reste = duree
	g.add_child(s)
	suivis.append(s)
	g.set_meta("suivis", suivis)
	return s

class SuiviTrainee extends Node:
	var cible: WeakRef
	var couleur := Color.RED
	var reste := 4.0
	var _dernier := Vector3.INF
	var _poses := 0
	var _os: Node3D
	var _cherche := false

	func _physics_process(dt: float) -> void:
		reste -= dt
		var c: Node3D = cible.get_ref()
		if reste <= 0.0 or c == null or not c.is_inside_tree() or _poses >= 14:
			queue_free()
			return
		var p := _point(c)
		if _dernier == Vector3.INF:
			_dernier = p
			return
		var d := p - _dernier
		d.y = 0.0
		if d.length() < 0.32:
			return
		var r := Sang.sol_sous(c, p, 0.25, 0.6)   # seulement si le corps touche presque le sol
		_dernier = p
		if r.is_empty():
			return
		_poses += 1
		Sang.trace(c, r["position"], r["normal"], d.normalized(), randf_range(0.24, 0.34), couleur, "trainee")

	## Bassin du ragdoll s'il existe (le corps lui-même reste parfois immobile pendant le ragdoll).
	func _point(c: Node3D) -> Vector3:
		if not _cherche:
			_cherche = true
			for nom in ["pelvis", "spine_01", "Hips"]:
				var o := c.find_child(nom, true, false)
				if o is PhysicalBone3D:
					_os = o
					break
		if is_instance_valid(_os) and _os.is_inside_tree():
			return _os.global_position
		return c.global_position
