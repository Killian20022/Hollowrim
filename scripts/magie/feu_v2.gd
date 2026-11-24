class_name FeuV2
extends RefCounted
## FEU v2 (branche magie/feu_v2, docs/MAGIE_FEU_V2.md) : orbe, explosion et léchage de surface STRUCTURÉS, d'après la méthode de la
## foudre v2 (formes nettes, couches, détail fin, paliers de couleur francs, largeur de trait entière en pixels) :
##   - ORBE : trois coques de bruit (shaders/feu_v2_corps.gdshader : cœur blanc-jaune, gaine orange, peau rouge déchirée) + une
##     gerbe de flammèches en rubans qui s'ENROULENT autour et filent vers la queue (shaders/feu_v2_langue.gdshader, mode 0) ;
##     la queue s'allonge avec `etire` (0 = orbe assise entre les mains, 1 = en vol) ; braises fines (préréglages existants) ;
##   - EXPLOSION : flash, boule qui s'ouvre (mêmes coques, `age`), éclats radiaux en rubans (mode 2), braises, fumée légère ;
##   - LÉCHAGE : langues qui rampent sur la surface touchée par un jet (mode 1) + roussi discret posé sur la surface.
## Tout vit dans le calque de la couche fine (CoucheMagie.CALQUE). Aucun état de jeu : pure présentation.

const SH_CORPS := preload("res://shaders/feu_v2_corps.gdshader")
const SH_LANGUE := preload("res://shaders/feu_v2_langue.gdshader")
const SH_ROUSSI := preload("res://shaders/feu_v2_roussi.gdshader")
const PAL := ["#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"]
## Plafonds (jamais dépassés : coûts bornés).
const BRINS_ORBE := 9
const POINTS_BRIN := 14
## Rayons des coques (repère local : l'orbe entière a le rayon 1).
const R_CORPS := [0.34, 0.68, 1.0]

static var _mats := {}
static var _sphere: SphereMesh
static var _rubans := {}
## Compteur (tests) : nombre de nœuds créés par type.
static var crees := {"orbe": 0, "explosion": 0, "lechage": 0, "jet": 0}

static func _couleurs(m: ShaderMaterial) -> void:
	for i in 5:
		m.set_shader_parameter("c%d" % i, Color(PAL[i]))

static func _mat_corps(coque: int, axe: Vector3) -> ShaderMaterial:
	var cle := "c%d|%s" % [coque, axe]
	if not _mats.has(cle):
		var m := ShaderMaterial.new()
		m.shader = SH_CORPS
		_couleurs(m)
		m.set_shader_parameter("coque", coque)
		m.set_shader_parameter("axe", axe)
		m.render_priority = -1 if coque == 2 else (0 if coque == 1 else 1)
		_mats[cle] = m
	return _mats[cle]

static func _mat_langue(mode: int, axe: Vector3, largeur_px: float, force := 1.5) -> ShaderMaterial:
	var cle := "l%d|%s|%s|%s" % [mode, axe, largeur_px, force]
	if not _mats.has(cle):
		var m := ShaderMaterial.new()
		m.shader = SH_LANGUE
		_couleurs(m)
		m.set_shader_parameter("mode", mode)
		m.set_shader_parameter("axe", axe)
		m.set_shader_parameter("largeur_px", largeur_px)
		m.set_shader_parameter("force", force)
		_mats[cle] = m
	return _mats[cle]

static func _maillage_sphere() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 1.0
		_sphere.height = 2.0
		_sphere.radial_segments = 18
		_sphere.rings = 9
	return _sphere

## Maillage de `n` rubans de `pts` points : UV = (t, côté), COLOR = (graine, graine2, 1, 1). Les positions sont calculées par le shader.
static func rubans(n: int, pts: int, germe: int) -> ArrayMesh:
	var cle := "%d|%d|%d" % [n, pts, germe]
	if _rubans.has(cle):
		return _rubans[cle]
	var rng := RandomNumberGenerator.new()
	rng.seed = germe
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for b in n:
		# graines réparties (stratifiées) : jamais deux brins identiques, couverture régulière
		var s := (float(b) + rng.randf() * 0.7) / n
		var s2 := fposmod(float(b) * 0.618034 + rng.randf() * 0.2, 1.0)
		var k0 := v.size()
		for i in pts:
			var t := float(i) / (pts - 1)
			for side in [-1.0, 1.0]:
				v.append(Vector3.ZERO)
				uv.append(Vector2(t, side))
				col.append(Color(s, s2, 1.0, 1.0))
		for i in pts - 1:
			var q := k0 + i * 2
			idx.append_array([q, q + 1, q + 3, q, q + 3, q + 2])
	var ar := []
	ar.resize(Mesh.ARRAY_MAX)
	ar[Mesh.ARRAY_VERTEX] = v
	ar[Mesh.ARRAY_TEX_UV] = uv
	ar[Mesh.ARRAY_COLOR] = col
	ar[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ar)
	m.custom_aabb = AABB(Vector3(-4, -4, -12), Vector3(8, 8, 24))
	_rubans[cle] = m
	return m

static func _mi(parent: Node, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	mi.layers = CoucheMagie.CALQUE
	parent.add_child(mi)
	return mi

# ====================================================================== orbe

## Orbe de feu de rayon 1 (à mettre à l'échelle avec `racine.scale`). `axe` : sens de la queue dans le repère du parent.
## Renvoie le nœud racine ; ses réglages passent par FeuV2.regler().
static func orbe(parent: Node3D, axe := Vector3.BACK, germe := 0.0) -> Node3D:
	crees["orbe"] = int(crees["orbe"]) + 1
	var r := Node3D.new()
	r.name = "OrbeFeuV2"
	parent.add_child(r)
	var a := axe.normalized()
	var corps: Array = []
	for c in 3:
		var mi := _mi(r, _maillage_sphere(), _mat_corps(c, a))
		mi.scale = Vector3.ONE * float(R_CORPS[c])
		mi.set_instance_shader_parameter("graine", germe)
		corps.append(mi)
	var lg := _mi(r, rubans(BRINS_ORBE, POINTS_BRIN, 11), _mat_langue(0, a, 2.0, 1.5))
	r.set_meta("corps", corps)
	r.set_meta("langues", lg)
	regler(r, 1.0, 0.0)
	return r

## eclat : 0 éteint .. 1 normal (jusqu'à 1,4) ; etire : 0 assise .. 1 en vol.
static func regler(o: Node3D, eclat: float, etire: float) -> void:
	if o == null or not is_instance_valid(o) or not o.has_meta("corps"):
		return
	for mi in o.get_meta("corps"):
		(mi as MeshInstance3D).set_instance_shader_parameter("eclat", eclat)
		(mi as MeshInstance3D).set_instance_shader_parameter("etire", etire)
	var lg: MeshInstance3D = o.get_meta("langues")
	lg.set_instance_shader_parameter("eclat", eclat)
	lg.set_instance_shader_parameter("etire", etire)
	o.visible = eclat > 0.01

# ====================================================================== explosion

## Explosion à `pos` (monde), `normale` de la surface touchée (le +Y local de l'effet), `force` ~1 (0,3 à 3), `k` = rayon max en m.
## Vit ~0,7 s puis se libère seule. `parent` : nœud de la scène.
static func explosion(parent: Node, pos: Vector3, normale: Vector3, force: float) -> Node3D:
	crees["explosion"] = int(crees["explosion"]) + 1
	var racine := Node3D.new()
	racine.name = "ExplosionFeuV2"
	parent.add_child(racine)
	var up := normale.normalized() if normale.length() > 0.1 else Vector3.UP
	racine.global_transform = Transform3D(_base_y(up), pos)
	var k := clampf(0.55 + 0.4 * force, 0.5, 1.9)
	racine.scale = Vector3.ONE * k
	# boule : cœur et gaine qui s'ouvrent (pas de peau rouge : de grandes plaques plates à cette taille)
	var corps: Array = []
	for c in 2:
		var mi := _mi(racine, _maillage_sphere(), _mat_corps(c, Vector3.UP))
		mi.scale = Vector3.ONE * float(R_CORPS[c]) * 0.5
		mi.position = Vector3.UP * 0.2
		mi.set_instance_shader_parameter("graine", randf() * 10.0)
		mi.set_instance_shader_parameter("etire", 0.6)
		corps.append(mi)
	var ec := _mi(racine, rubans(16, 10, 23), _mat_langue(2, Vector3.UP, 3.0, 1.6))
	var flash := _mi(racine, _maillage_sphere(), _mat_corps(0, Vector3.UP))
	flash.scale = Vector3.ONE * 0.2
	flash.position = Vector3.UP * 0.15
	var tw := racine.create_tween()
	tw.tween_method(func(a: float) -> void:
		var e := 1.0 - pow(1.0 - a, 2.0)
		for c in 2:
			var mi: MeshInstance3D = corps[c]
			mi.scale = Vector3.ONE * float(R_CORPS[c]) * ((0.5 + 1.5 * e) if c == 1 else ((0.5 + 0.5 * e) * (1.0 - 0.5 * a)))
			mi.position = Vector3.UP * (0.2 + 0.5 * e)
			mi.set_instance_shader_parameter("age", a)
			mi.set_instance_shader_parameter("etire", 0.4 + 0.9 * a)
		ec.set_instance_shader_parameter("age", a)
		flash.visible = a < 0.1
		flash.scale = Vector3.ONE * (0.2 + 0.9 * a)
		, 0.0, 1.0, 0.9)
	tw.tween_callback(racine.queue_free)
	return racine

static func _base_y(y: Vector3) -> Basis:
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y).normalized())

# ====================================================================== léchage (jet sur une surface)

## Langues qui lèchent la surface touchée par un jet : à créer une fois, puis placer chaque image avec placer_lechage.
static func lechage(parent: Node) -> Node3D:
	crees["lechage"] = int(crees["lechage"]) + 1
	var racine := Node3D.new()
	racine.name = "LechageFeuV2"
	parent.add_child(racine)
	var lg := _mi(racine, rubans(9, 10, 5), _mat_langue(1, Vector3.UP, 3.0, 1.5))
	racine.set_meta("langues", lg)
	var lueur := _mi(racine, _maillage_sphere(), _mat_corps(1, Vector3.UP))
	lueur.scale = Vector3(0.28, 0.12, 0.28)
	lueur.position = Vector3.UP * 0.06
	lueur.set_instance_shader_parameter("graine", randf() * 10.0)
	racine.set_meta("lueur", lueur)
	return racine

static func placer_lechage(n: Node3D, pos: Vector3, normale: Vector3, force: float, echelle := 1.0) -> void:
	if n == null or not is_instance_valid(n):
		return
	var up := normale.normalized() if normale.length() > 0.1 else Vector3.UP
	# décalé de 10 cm de la surface : plus près, l'occlusion de la couche fine coupe les langues contre le mur
	n.global_transform = Transform3D(_base_y(up).scaled(Vector3.ONE * echelle), pos + up * 0.1)
	var lg: MeshInstance3D = n.get_meta("langues")
	lg.set_instance_shader_parameter("eclat", clampf(force, 0.0, 1.2))
	var lu: MeshInstance3D = n.get_meta("lueur")
	lu.set_instance_shader_parameter("eclat", clampf(force, 0.0, 1.0))

# ====================================================================== filets d'accompagnement d'un jet

## Filets fins qui suivent le jet (mode 3) : à créer par jet, placer chaque image avec placer_jet.
static func jet(parent: Node) -> Node3D:
	crees["jet"] = int(crees["jet"]) + 1
	var racine := Node3D.new()
	racine.name = "FiletsJetFeuV2"
	parent.add_child(racine)
	var lg := _mi(racine, rubans(14, 16, 31), _mat_langue(3, Vector3.UP, 2.0, 1.4))
	racine.set_meta("langues", lg)
	return racine

static func placer_jet(n: Node3D, origine: Vector3, direction: Vector3, longueur: float, evase: float, eclat: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	var d := direction.normalized()
	# repère : -Z local = sens du jet
	var z := -d
	var x := Vector3.UP.cross(z).normalized() if absf(d.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var y := z.cross(x).normalized()
	n.global_transform = Transform3D(Basis(x, y, z), origine)
	var lg: MeshInstance3D = n.get_meta("langues")
	lg.set_instance_shader_parameter("longueur", longueur)
	lg.set_instance_shader_parameter("evase", evase)
	lg.set_instance_shader_parameter("eclat", eclat)

# ====================================================================== roussi

static var _plan: PlaneMesh
static var _mat_roussi: ShaderMaterial
## Tache de roussi posée sur une surface (monde, calque normal) ; s'efface en 7 s puis se libère.
static func roussi(parent: Node, pos: Vector3, normale: Vector3) -> Node3D:
	if _plan == null:
		_plan = PlaneMesh.new()
		_plan.size = Vector2(1.0, 1.0)
		_mat_roussi = ShaderMaterial.new()
		_mat_roussi.shader = SH_ROUSSI
		_mat_roussi.render_priority = -2
	var mi := MeshInstance3D.new()
	mi.name = "RoussiFeuV2"
	mi.mesh = _plan
	mi.material_override = _mat_roussi
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var up := normale.normalized() if normale.length() > 0.1 else Vector3.UP
	var taille := randf_range(0.42, 0.7)
	mi.global_transform = Transform3D(_base_y(up).rotated(up, randf() * TAU).scaled(Vector3.ONE * taille), pos + up * 0.015)
	mi.set_instance_shader_parameter("graine", randf() * 20.0)
	var tw := mi.create_tween()
	tw.tween_method(func(a: float) -> void: mi.set_instance_shader_parameter("age", a), 0.0, 1.0, 7.0)
	tw.tween_callback(mi.queue_free)
	return mi
