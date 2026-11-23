class_name Sang
## Sang et traces (combat gore, option « Sang et démembrement » des options : 2 complet, 1 réduit, 0 désactivé).
##   Sang.giclee(noeud, point, direction, intensite, couleur)   giclée directionnelle (particules pixel) + traces au sol/au mur
##   Sang.jet(attache, transform_local, couleur, duree)          jet pulsé (cou tranché) qui goutte au sol
##   Sang.flaque(noeud, position, couleur, taille, croissance)   flaque qui s'étale sous un corps
##   Sang.trace(noeud, position, normale, direction, taille, couleur, sorte)   trace collée (flaque, giclure, trainee)
## SANG V3 (2026-11-23, docs/SANG_V3.md) : mêmes signatures (paramètres optionnels ajoutés en fin), moteur dans SangV3 ; ajouts :
##   Sang.giclee(..., traces, sorte)                         sorte "impact" (défaut), "sortie" (plaie de sortie), "entree"
##   Sang.traversee(noeud, entree, sortie, direction, intensite, couleur)   arme qui traverse : entrée + sortie + brume + murs
##   Sang.sortie(noeud, point, direction, intensite, couleur)               plaie de sortie seule
##   Sang.trainee_corps(corps, couleur, duree)                traînée d'un corps qui glisse / est projeté
##   Sang.saigner(noeud, point, couleur, duree)               blessé qui goutte (gouttes + taches au sol)
## `--sans-sang-v3` : comportement v2.
## Traces = petits plans texturés (texels nets, découpe alpha, aspect mouillé) posés sur la surface touchée (rayon), gérés par un
## nœud « GestionSang » de la scène : au plus MAX_TRACES (les plus anciennes disparaissent), chacune s'efface après DUREE_TRACE s.
## (Pas de Decal pour le sol : le rendu Mobile limite les décals par maillage, or le terrain est un seul grand maillage.)

const MAX_TRACES := 48
const DUREE_TRACE := 150.0
const MAX_GOUTTES_JET := 6
## Sang v3 : plafond des traces (giclures, flaques, traînées, coulures : chacune ≤ 25 triangles une fois projetée) et durées.
const MAX_TRACES_V3 := MAX_TRACES
const SECHE_TRACE := 45.0
const SECHE_FLAQUE := 90.0
## Temps CPU cumulé des giclées / traces (µs, mesures et tests).
static var cout_us := 0
static var _imbrique := 0

## Compte le temps d'un appel seulement au niveau le plus extérieur (une giclée qui pose des traces n'est pas comptée deux fois).
static func _compter(t_us: int) -> void:
	_imbrique -= 1
	if _imbrique <= 0:
		_imbrique = 0
		cout_us += Time.get_ticks_usec() - t_us
## Niveau imposé (tests, captures) ; -1 = option du joueur.
static var niveau_force := -1
static var _tex := {}
static var _mats := {}
static var _mat_part := {}
static var _plan: PlaneMesh
static var _liberation := not OS.get_cmdline_user_args().has("--sans-opti-sang-liberation")

static func niveau() -> int:
	if niveau_force >= 0:
		return niveau_force
	return clampi(int(Jeu.option("combat", "gore")), 0, 2)

static func actif() -> bool:
	return niveau() > 0

# ------------------------------------------------------------------ giclées

static func giclee(n: Node, point: Vector3, direction: Vector3, intensite: float, couleur: Color, traces := true, sorte := "impact") -> void:
	var niv := niveau()
	if niv == 0 or n == null or not n.is_inside_tree():
		return
	var t_us := Time.get_ticks_usec()
	_imbrique += 1
	if SangV3.actif:
		if matiere_de(couleur) != "sang":
			# squelette, bois, poussière : pas de sang, la même gerbe que eclats_matiere (appelant qui ne trie pas)
			eclats_matiere(n, point, direction, intensite * 0.8, couleur)
		else:
			SangV3.giclee(n, point, direction, intensite, couleur, traces, sorte)
		_compter(t_us)
		return
	var k := intensite * (1.0 if niv == 2 else 0.35)
	var dir := direction.normalized() if direction.length() > 0.01 else Vector3.UP
	_burst(n, point, (dir + Vector3.UP * 0.3).normalized(), clampi(int(18.0 * k), 4, 110), 22.0, 1.8 * sqrt(k), 5.2 * sqrt(k), couleur, Vector3(0.022, 0.06, 0.022))
	# brume fine (gouttelettes) plus large, moins loin
	_burst(n, point, (dir + Vector3.UP * 0.6).normalized(), clampi(int(10.0 * k), 2, 50), 55.0, 0.8, 2.6 * sqrt(k), couleur * 1.15, Vector3(0.02, 0.02, 0.02))
	if traces:
		_traces_giclee(n, point, dir, k, couleur, niv)
	_compter(t_us)

## Sang v2 (2026-10-30) : la giclée TACHE LES VOISINS. Ennemis à moins de PORTEE_TACHE m du point d'impact, dans le sens de la
## lame (ou tout contre la victime) : un jet de pixels part vers eux et, le temps du vol, une éclaboussure se pose sur leur corps
## (Plaies.tacher, côté tourné vers la victime, à la hauteur du coup). Au plus MAX_VOISINS par coup. Rend le nombre de voisins tachés.
const PORTEE_TACHE := 1.8
const MAX_VOISINS := 2

static func tacher_voisins(source: Node3D, point: Vector3, direction: Vector3, intensite: float, couleur: Color) -> int:
	if not SangLame.actif or niveau() == 0 or source == null or not source.is_inside_tree():
		return 0
	var t_us := Time.get_ticks_usec()
	var plat := Vector3(direction.x, 0, direction.z)
	plat = plat.normalized() if plat.length() > 0.05 else Vector3.ZERO
	var portee := PORTEE_TACHE * clampf(0.75 + intensite * 0.12, 0.85, 1.35)
	var n := 0
	for e in source.get_tree().get_nodes_in_group("ennemis"):
		if n >= MAX_VOISINS:
			break
		if e == source or not (e is Node3D) or not (e as Node3D).is_inside_tree():
			continue
		var autre := e as Node3D
		var vers := autre.global_position - point
		vers.y = 0.0
		var dist := vers.length()
		if dist > portee or dist < 0.05:
			continue
		if plat != Vector3.ZERO and dist > 0.9 and vers.normalized().dot(plat) < 0.1:
			continue
		var c := autre.get_node_or_null("Combat")
		var modele: Node3D = c.get("modele") if c != null else autre.get("modele")
		if modele == null:
			continue
		var vn := vers.normalized()
		var h := clampf(point.y - autre.global_position.y + randf_range(-0.2, 0.15), 0.45, 1.6)
		var decalage := Vector3.UP * h - vn * 0.2   # relatif à l'ennemi : il peut bouger pendant le vol
		var normale := (-vn + Vector3.UP * 0.15).normalized()
		var taille := clampf(0.2 + intensite * 0.05, 0.2, 0.42) * clampf(1.4 - dist / portee, 0.6, 1.2)
		GerbePixels.emettre(source, point, (vn + Vector3.UP * 0.25).normalized(), "sang_jet" if couleur.r >= 0.3 else "draugr_jet", clampf(0.6 + intensite * 0.2, 0.7, 1.5))
		var delai := 0.06 + dist / 4.5
		# références faibles : libérés avant l'échéance, `autre` et `modele` feraient échouer l'appel du lambda (« Lambda capture was freed »)
		var autre_ref: WeakRef = weakref(autre)
		var modele_ref: WeakRef = weakref(modele)
		source.get_tree().create_timer(delai).timeout.connect(func() -> void:
			var a: Node3D = autre_ref.get_ref()
			var mo: Node3D = modele_ref.get_ref()
			if a != null and mo != null and mo.is_inside_tree():
				var t1 := Time.get_ticks_usec()
				Plaies.tacher(mo, a.global_position + decalage, normale, taille, couleur)
				SangLame.cout_us += Time.get_ticks_usec() - t1)
		n += 1
	SangLame.cout_us += Time.get_ticks_usec() - t_us
	return n

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
	# opti 2026-11-20 : `finished` n'est pas toujours émis (giclée que le rendu n'a pas traitée, hors champ) : sans ce minuteur, les
	# giclées finies restaient dans la scène tout le combat (85 relevées après 1 min de combat à 6 ennemis). Toutes les particules
	# sont mortes à 0,84 s (vie 0,8, explosivité 0,95) : rien de visible ne change. --sans-opti-sang-liberation : comportement d'avant.
	if _liberation:
		n.get_tree().create_timer(2.0, false).timeout.connect(p.queue_free)

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

static func _surface(r: Dictionary, props := false) -> bool:
	var c: Object = r.get("collider")
	if c is RigidBody3D and props and SangV3.actif:
		return not (c as Node).is_in_group("ennemis")   # prop mobile (tonneau, table) : la trace lui est attachée (Sang.trace)
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
	p.draw_pass_1 = _cube(Vector3(0.03, 0.08, 0.03), SangV3.palette(couleur)["vol"] if SangV3.actif else couleur)
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
	if SangV3.actif:
		# v3 : la flaque s'étale LENTEMENT (le sang s'écoule du corps pendant ~20 s), un peu plus large
		return trace(n, r["position"], r["normal"], Vector3.ZERO, t * 1.25, couleur, "flaque", maxf(croissance * 2.4, 12.0))
	return trace(n, r["position"], r["normal"], Vector3.ZERO, t, couleur, "flaque", croissance)

# ------------------------------------------------------------------ traces collées

static func gestion(n: Node) -> Node3D:
	return gestion_racine(n.get_tree())

static func gestion_racine(arbre: SceneTree) -> Node3D:
	if arbre == null:
		return null
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

static func trace(n: Node, pos: Vector3, normale: Vector3, direction: Vector3, taille: float, couleur: Color, sorte := "giclure", croissance := 0.0, delai := 0.0, support: Node3D = null) -> MeshInstance3D:
	if niveau() == 0 or n == null or not n.is_inside_tree():
		return null
	var t_us := Time.get_ticks_usec()
	_imbrique += 1
	if SangV3.actif:
		var mi := _trace_v3(n, pos, normale, direction, taille, couleur, sorte, croissance, delai, support)
		_compter(t_us)
		return mi
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
	# disparition lente : la trace se résorbe (rétrécit) en quelques secondes au lieu de s'éteindre d'un coup
	tw.tween_property(mi, "scale", mi.scale * Vector3(0.05, 1.0, 0.05), 6.0).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	_compter(t_us)
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

# ------------------------------------------------------------------ sang v3 : traces projetées, traversée, traînées

static func _trace_v3(n: Node, pos: Vector3, normale: Vector3, direction: Vector3, taille: float, couleur: Color, sorte: String, croissance: float, delai: float, support: Node3D) -> MeshInstance3D:
	var g := gestion(n)
	var l: Array = g.get_meta("traces")
	# plein : la plus ancienne trace est RECYCLÉE (même nœud, rien d'alloué ni libéré en plein combat)
	var mi: MeshInstance3D = null
	if l.size() >= MAX_TRACES_V3:
		l = l.filter(func(x: Variant) -> bool: return is_instance_valid(x) and not (x as Node).is_queued_for_deletion())
		while l.size() >= MAX_TRACES_V3:
			var vieux: MeshInstance3D = l.pop_front()
			if mi == null and vieux.get_parent() == g:
				mi = vieux
				var tw0: Variant = mi.get_meta("tween") if mi.has_meta("tween") else null
				if tw0 is Tween and (tw0 as Tween).is_valid():
					(tw0 as Tween).kill()
				mi.visible = true
				mi.scale = Vector3.ONE
				mi.set_instance_shader_parameter("seche", 0.0)
				mi.set_instance_shader_parameter("efface", 0.0)
			else:
				vieux.queue_free()
	var y := normale.normalized() if normale.length() > 0.01 else Vector3.UP
	var x := direction - y * direction.dot(y)
	if x.length() < 0.05:
		x = y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).rotated(y, randf() * TAU)
	x = x.normalized()
	var z := x.cross(y)
	var allonge := {"trainee": 2.6, "giclure": 1.35, "coulure": 2.0}.get(sorte, 1.0) as float
	var neige := SangV3.sur_neige(pos, y)
	var ordre := float(l.size() % 16) * 0.0009   # traces superposées : pas de scintillement
	# sol : le shader ps1 du sol (neige qui tient, relief) dessine la surface ~2 cm AU-DESSUS de sa collision : à 1 cm la trace
	# était enterrée (invisible) ; murs : 1,2 cm suffisent
	var leve := (0.035 if y.y > 0.6 else 0.012) + ordre
	var origine := pos + y * leve
	var xf_unite := Transform3D(Basis(x, y, z), origine)
	var forme := sorte if sorte in ["flaque", "giclure", "trainee", "coulure", "goutte"] else "giclure"
	var neuf := mi == null
	if neuf:
		mi = MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# petite tache (goutte) : plan sans sonde (le relief ne se voit pas à cette taille)
	mi.mesh = SangV3.maille_projetee(n as Node3D if n is Node3D and taille * allonge > 0.14 else null, xf_unite, taille * allonge * 0.5, taille * 0.5, leve)
	mi.material_override = SangV3.materiau_trace(forme, randi() % 3, couleur, neige)
	var parent: Node = support if is_instance_valid(support) and support.is_inside_tree() else g
	if neuf:
		parent.add_child(mi)
		# uniformes d'instance posés APRÈS l'entrée dans l'arbre (sinon le rendu lit une valeur non initialisée : trace invisible)
		mi.set_instance_shader_parameter("seche", 0.0)
		mi.set_instance_shader_parameter("efface", 0.0)
	elif parent != g:
		mi.reparent(parent, false)
	l.append(mi)
	g.set_meta("traces", l)
	mi.global_transform = Transform3D(Basis(x * taille * allonge, y, z * taille), origine)
	if croissance > 0.0 or delai > 0.0:
		var tw := mi.create_tween()
		mi.set_meta("tween", tw)
		var depart := 0.3 if croissance > 0.0 else 0.6
		var fin := mi.scale
		mi.scale = Vector3(depart, 1.0, depart) * fin
		mi.visible = delai <= 0.0
		if delai > 0.0:
			tw.tween_interval(delai)
			tw.tween_callback(mi.show)
		var tr := tw.tween_property(mi, "scale", fin, croissance if croissance > 0.0 else 0.1).set_ease(Tween.EASE_OUT)
		tr.set_trans(Tween.TRANS_QUART if croissance > 0.0 else Tween.TRANS_CUBIC)
	# séchage par paliers (bords minces d'abord), puis la trace « boit » (le film mince part avant le cœur) : un seul nœud
	# (SangV3.Vieillissement, deux fois par seconde, seulement tant qu'il reste des traces) au lieu d'un tween par trace
	SangV3.vieillissement(g).ajouter(mi, SECHE_FLAQUE if sorte == "flaque" else SECHE_TRACE)
	return mi

## Arme (ou objet) qui TRAVERSE : petite giclée à l'entrée (vers l'attaquant), jet arrière fort + brume à la sortie, éclaboussures
## sur ce qui est derrière. Squelette / bois : poussière d'os / échardes des deux côtés. `direction` = sens de l'objet.
static func traversee(n: Node, entree: Vector3, sortie_pt: Vector3, direction: Vector3, intensite: float, couleur: Color) -> void:
	if n == null or not n.is_inside_tree():
		return
	var dir := direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD
	if niveau() == 0 or matiere_de(couleur) != "sang":
		eclats_matiere(n, entree, -dir, intensite * 0.6, couleur)
		eclats_matiere(n, sortie_pt, dir, intensite * 1.1, couleur)
		return
	if not SangV3.actif:
		giclee(n, entree, -dir, intensite * 0.5, couleur, false)
		giclee(n, sortie_pt, dir, intensite * 1.3, couleur)
		return
	giclee(n, entree, (-dir + Vector3.UP * 0.2).normalized(), intensite * 0.45, couleur, false, "entree")
	giclee(n, sortie_pt, dir, intensite * 1.4, couleur, true, "sortie")

## Plaie de sortie seule (point de sortie, sens de l'objet) : jet arrière fort, brume rouge fine, éclaboussures derrière.
static func sortie(n: Node, point: Vector3, direction: Vector3, intensite: float, couleur: Color) -> void:
	giclee(n, point, direction, intensite * 1.4, couleur, true, "sortie")

## Traînée d'un corps qui glisse ou est projeté (ragdoll : suit le bassin) pendant `duree` s.
static func trainee_corps(corps: Node3D, couleur: Color, duree := 3.0) -> Node:
	if niveau() == 0 or corps == null or not corps.is_inside_tree() or not SangV3.actif or matiere_de(couleur) != "sang":
		return null
	return SangV3.trainee_corps(corps, couleur, duree)

## Blessé qui goutte : pendant `duree` s, des gouttes tombent du point (relatif au nœud, qui peut bouger) et tachent le sol.
static func saigner(n: Node3D, point: Vector3, couleur: Color, duree := 6.0) -> void:
	if niveau() == 0 or n == null or not n.is_inside_tree() or not SangV3.actif or matiere_de(couleur) != "sang":
		return
	var maintenant := Time.get_ticks_msec() / 1000.0
	if float(n.get_meta("sang_saigne_jusqu_a", 0.0)) > maintenant:
		return   # déjà en train de goutter : pas de deuxième file de gouttes
	n.set_meta("sang_saigne_jusqu_a", maintenant + duree)
	var local := n.global_transform.affine_inverse() * point
	var nref: WeakRef = weakref(n)
	var tw := n.create_tween()
	var t := 0.0
	var pal := SangV3.palette(couleur)
	while t < duree:
		var pas := randf_range(0.35, 0.8)
		t += pas
		tw.tween_interval(pas)
		tw.tween_callback(func() -> void:
			var o: Node3D = nref.get_ref()
			if o != null and o.is_inside_tree():
				GouttesSang.lacher(o, o.global_transform * local + Vector3(randf_range(-0.04, 0.04), 0, randf_range(-0.04, 0.04)), pal["vol"], Vector3.ZERO, randf() < 0.5))

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

## Sang v2 (2026-10-30) : entaille DÉTAILLÉE qui coule, image `etape` sur Plaies.ETAPES (32 x 40, la fente au rang 8) :
## fente irrégulière (bords déchiquetés au texel), cœur noir de la chair ouverte, lèvres de chair claire d'un texel, chair à vif,
## pourtour tuméfié d'un texel, film de sang en plaques (pas un bandeau), coulures (1-2 texels) qui s'allongent d'une image à
## l'autre et finissent par un caillot (2 x 2) ; gouttelettes projetées ; un éclat mouillé.
## Retouche 2026-10-30 : texture EN COULEURS (palette par sang : « sombre » = draugr, « vif » = vivants), le décal n'est plus
## teinté (modulate blanc) — les lèvres et le pourtour des draugrs ressortent sur leur chair sombre sans virer au rose.
const PALETTE_PLAIE := {
	"sombre": {"coeur": "#1c0806", "fond": "#3a100c", "levre": "#c27a5c", "chair": "#9a3424", "tumefie": "#7a5444",
		"film": "#7e1610", "coulure": "#721410", "coulure2": "#8a1c14", "caillot": "#3e0806", "eclat": "#e0a080"},
	"vif": {"coeur": "#1e0404", "fond": "#3e0c08", "levre": "#b0503a", "chair": "#a8261c", "tumefie": "#7e4234",
		"film": "#8e1810", "coulure": "#801610", "coulure2": "#9c2016", "caillot": "#4a0806", "eclat": "#f0b090"},
}

static func texture_entaille(variante: int, etape: int, vif := false) -> ImageTexture:
	var cle := "entaille_v2_%d_%d_%s" % [variante, etape, vif]
	if not _tex.has(cle):
		_tex[cle] = ImageTexture.create_from_image(_img_entaille_v2(variante, etape, PALETTE_PLAIE["vif" if vif else "sombre"]))
	return _tex[cle]

static func _img_entaille_v2(variante: int, etape: int, pal: Dictionary) -> Image:
	var c := {}
	for k: String in pal:
		c[k] = Color(pal[k])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("entaille_v2_%d" % variante)
	var w := 32
	var h := 40
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bruit := FastNoiseLite.new()
	bruit.seed = rng.randi()
	bruit.frequency = 0.21
	var pente := rng.randf_range(-0.14, 0.14)
	var ep0 := rng.randf_range(1.9, 2.6)
	var k_et := float(etape) / maxf(Plaies.ETAPES - 1, 1)
	var cy_de := func(x: float) -> float: return 8.0 + (x - w * 0.5) * pente + bruit.get_noise_1d(x * 1.7) * 0.9
	var coulures := []
	for n in rng.randi_range(4, 6):
		coulures.append({"x": rng.randi_range(6, w - 7), "lg": rng.randf_range(7.0, 27.0), "l2": rng.randf() < 0.35, "vit": rng.randf_range(0.6, 1.0)})
	var gouttelettes := []
	for g in rng.randi_range(5, 9):
		gouttelettes.append(Vector2i(rng.randi_range(1, w - 2), clampi(int(8 + rng.randf_range(-6, 7)), 0, h - 1)))
	# pourtour tuméfié (1 texel) puis film de sang EN PLAQUES, surtout sous la fente (retouche : plus de bandeau rouge)
	for y in range(0, 20):
		for x in range(1, w - 1):
			var cy: float = cy_de.call(float(x))
			var kx := sin(float(x - 1) / (w - 2) * PI)
			var d := y + 0.5 - cy
			var ep := ep0 * kx + 0.35
			var nb := bruit.get_noise_2d(x * 2.3, y * 2.3)
			var portee := ep + (0.4 + 1.1 * k_et) * kx + nb * 1.3
			if d > 0.0 and absf(d) < portee and nb > -0.15:
				img.set_pixel(x, y, c["film"])
			elif absf(d) < ep + 1.2 and kx > 0.3:
				img.set_pixel(x, y, c["tumefie"])
	# coulures
	for cl: Dictionary in coulures:
		var lg := float(cl["lg"]) * clampf(k_et * float(cl["vit"]) * 1.25, 0.0, 1.0)
		var x: int = cl["x"]
		var y0 := int(cy_de.call(float(x)) + ep0 * 0.6)
		var yb := y0
		for y in range(y0, mini(y0 + int(lg), h - 2)):
			var xx := x + (1 if bruit.get_noise_2d(x * 3.0, y * 0.6) > 0.35 else 0)
			img.set_pixel(xx, y, c["coulure"])
			if cl["l2"] and y < y0 + int(lg * 0.6):
				img.set_pixel(xx + 1, y, c["coulure2"])
			yb = y
		if lg >= 3.0:
			for dy in 2:
				for dx in 2:
					if x + dx < w and yb + dy < h:
						img.set_pixel(x + dx, yb + dy, c["caillot"])
	# la fente : bords déchiquetés, cœur presque noir (fond de chair sombre par endroits), chair à vif, lèvres claires, éclat
	for x in range(2, w - 2):
		var k := float(x - 2) / (w - 4)
		var ep := sin(k * PI) * ep0 * (0.85 + 0.3 * (bruit.get_noise_1d(x * 3.1 + 40.0) * 0.5 + 0.5)) + 0.35
		var cy: float = cy_de.call(float(x))
		for y in range(0, 20):
			var d := absf(y + 0.5 - cy)
			if d < ep:
				var col: Color = c["coeur"] if d < ep * 0.42 else (c["chair"] if d < ep * 0.62 else c["levre"])
				if d < ep * 0.42 and rng.randf() < 0.1:
					col = c["fond"]
				img.set_pixel(x, y, col)
		if k > 0.25 and k < 0.75 and rng.randf() < 0.18:
			img.set_pixel(x, clampi(int(cy - ep * 0.6), 0, h - 1), c["eclat"])
	for p: Vector2i in gouttelettes:
		if img.get_pixel(p.x, p.y).a == 0.0:
			img.set_pixel(p.x, p.y, c["film"])
	return img

static func _img_entaille(rng: RandomNumberGenerator) -> Image:
	# entaille (lot gore 2026-10-29) : fente fine et nette, cœur presque noir (chair ouverte), lèvres claires d'un texel,
	# chair à vif autour, quelques coulures vers le bas (+Y de l'image) ; lisible en gros pixels, pas un aplat rouge
	var w := 32
	var h := 16
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pente := rng.randf_range(-0.12, 0.12)
	for x in range(2, w - 2):
		var k := float(x - 2) / (w - 4)
		var ep := sin(k * PI) * rng.randf_range(2.0, 2.6) + 0.4
		var cy := 5.0 + (x - w * 0.5) * pente
		for y in h:
			var d := absf(y + 0.5 - cy)
			if d < ep:
				var l := 0.08 if d < ep * 0.45 else (1.0 if d < ep * 0.75 else 0.62)
				img.set_pixel(x, y, Color(l, l, l, 1.0))
		if rng.randf() < 0.22 and k > 0.2 and k < 0.8:
			var lg := rng.randi_range(3, 9)
			var y0 := int(cy + ep)
			for y in range(y0, mini(y0 + lg, h)):
				img.set_pixel(x, y, Color(0.7, 0.7, 0.7, 1.0))
		if rng.randf() < 0.12:
			var py := clampi(int(cy + rng.randf_range(-ep - 3, ep + 3)), 0, h - 1)
			img.set_pixel(x, py, Color(0.62, 0.62, 0.62, 1.0))
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
