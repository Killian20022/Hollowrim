class_name ArcModele
extends Node3D
## Modèle de l'ARC DE CHASSEUR (fait main dans Blender : sources_blender/scripts/arc_chasseur.py, d'après
## Desktop/photos_tripo/arc/arc_trois_vues.png) : arc recourbé de bois brun sombre, poignée de cuir, ligatures de cordelette, runes,
## pointes de corne. Il PLIE : clé de forme « bande » (pleine allonge) ; la corde (deux segments) est tendue entre les attaches des
## branches et le point d'encoche, et garde sa longueur : plus l'encoche recule, plus les branches se plient.
## Repère : arc debout (axe y, centre de la poignée à l'origine), corde côté +z (l'archer), la flèche part vers -z.
##   regler(allonge, encoche)  allonge 0..1 = recul de l'encoche (0 = corde au repos, 1 = pleine allonge du modèle) ;
##                             encoche = flèche posée sur la corde.
##   claquer()                 la corde claque au départ de la flèche (dépasse sa position de repos et vibre, amortie).
##   repere_poignee            repère de la poignée pour la main gauche (+y = de l'auriculaire vers l'index, +x = jointures) ;
##   repere_encoche            idem pour la main droite, au point d'encoche (suit la corde).
##   fleche_libre              repère local imposé à la flèche (rechargement : elle suit la main droite), null = sur la corde.
##   pointe() / encoche_monde() positions monde de la pointe de la flèche encochée et du point d'encoche.
##   ArcModele.creer_fleche()  la flèche seule (encoche à l'origine, pointe vers -z) : en main, en vol (Projectile), plantée.

const ARC := preload("res://assets/modeles/armes/arc_chasseur.glb")
const FLECHE := preload("res://assets/modeles/armes/fleche_chasseur.glb")
const ATLAS := preload("res://assets/modeles/armes/arc_chasseur.png")
const INFOS := "res://assets/modeles/armes/arc_chasseur.json"
## La flèche repose sur le poing, à gauche de la poignée (archer droitier) et au-dessus de son centre.
const APPUI := Vector3(-0.024, 0.045, 0.0)
const RAYON_CORDE := 0.0034
## Appui de CE modèle (APPUI par défaut) : la 1re personne passe la flèche à droite de la poignée en visée (composition Skyrim).
var appui := APPUI
## Allonge permise (1 = celle du modèle ; au-delà la corde suit l'encoche, branches à pleine flexion) ; dépassement de la pointe
## au-delà de l'appui (local) : la flèche s'allonge côté encoche quand l'allonge dépasse sa longueur (1re personne en visée).
var allonge_max := 1.0
var depasse_fleche := 0.0

var mi_arc: MeshInstance3D
var mi_corde: MeshInstance3D
var fleche: Node3D
var repere_poignee: Node3D
var repere_encoche: Node3D
var allonge := 0.0
var encoche := false
var fleche_libre: Variant = null
var _poids := 0.0
var _z_encoche := 0.0
var _claque := -1.0
var _cle := -1

static var _infos := {}
static var _mat: ShaderMaterial

static func infos() -> Dictionary:
	if _infos.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(INFOS))
		_infos = d if d is Dictionary else {}
	return _infos

static func _v(cle: String) -> Vector3:
	var a: Array = infos().get(cle, [0, 0, 0])
	return Vector3(a[0], a[1], a[2])

static func materiau() -> ShaderMaterial:
	if _mat == null:
		_mat = Palette.materiau(ATLAS, Vector2.ONE, Color(1.0, 0.97, 0.94), true)
		_mat.set_shader_parameter("tex_neige", ATLAS)
	return _mat

static func _habiller(racine: Node) -> void:
	for mi: MeshInstance3D in racine.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = materiau()

## La flèche seule (fleche_chasseur.glb habillée) : encoche à l'origine, pointe vers -z (à longueur_pointe()).
static func creer_fleche() -> Node3D:
	var f: Node3D = FLECHE.instantiate()
	_habiller(f)
	return f

static func longueur_pointe() -> float:
	return -float(infos().get("pointe_fleche_z", -0.8))

func _init() -> void:
	var a: Node3D = ARC.instantiate()
	a.name = "arc"
	add_child(a)
	_habiller(a)
	mi_arc = a.find_children("*", "MeshInstance3D", true, false)[0]
	mi_arc.extra_cull_margin = 0.5
	_cle = mi_arc.find_blend_shape_by_name(&"bande")
	mi_corde = MeshInstance3D.new()
	mi_corde.name = "corde"
	mi_corde.material_override = materiau()
	add_child(mi_corde)
	fleche = creer_fleche()
	fleche.name = "fleche"
	fleche.visible = false
	add_child(fleche)
	repere_poignee = Node3D.new()
	repere_poignee.name = "poignee"
	# poing gauche : index en haut (+y), jointures vers l'avant et un peu vers l'extérieur (-z, -x)
	repere_poignee.basis = repere_main(Vector3(-0.35, 0.0, -1.0))
	add_child(repere_poignee)
	repere_encoche = Node3D.new()
	repere_encoche.name = "encoche"
	repere_encoche.basis = repere_main(Vector3(0.25, 0.0, -1.0))
	add_child(repere_encoche)
	set_process(true)
	regler(0.0, false)

## Repère « objet dans le poing » (convention mains._calculer_prise) : +y = axe de la prise (auriculaire -> index), +x = jointures.
static func repere_main(jointures: Vector3, axe := Vector3.UP) -> Basis:
	var y := axe.normalized()
	var x := (jointures - y * jointures.dot(y)).normalized()
	return Basis(x, y, x.cross(y))

## Corde à l'encoche (z local) et poids de la clé de forme qui gardent la longueur de corde pour une allonge 0..1.
func _resoudre(u: float) -> void:
	var z0 := float(infos().get("encoche_repos_z", 0.195))
	var z1 := float(infos().get("encoche_pleine_z", 0.595))
	var cible := lerpf(z0, z1, clampf(u, 0.0, allonge_max))
	var lo := 0.0
	var hi := 1.0
	for i in 18:
		var m := (lo + hi) * 0.5
		if _z_pour(m) < cible:
			lo = m
		else:
			hi = m
	_poids = (lo + hi) * 0.5
	_z_encoche = cible

func _z_pour(w: float) -> float:
	var p := _v("attache_repos").lerp(_v("attache_bande"), w)
	var demi := float(infos().get("demi_corde", 0.567))
	return p.z + sqrt(maxf(0.0, demi * demi - p.y * p.y))

func attache(w: float, haut := true) -> Vector3:
	var p := _v("attache_repos").lerp(_v("attache_bande"), w)
	return p if haut else Vector3(p.x, -p.y, p.z)

func encoche_locale() -> Vector3:
	return Vector3(appui.x - APPUI.x, appui.y, _z_encoche + _vibration())

## Point d'encoche (local) pour une allonge donnée, sans changer l'état du modèle.
func encoche_pour(u: float) -> Vector3:
	return Vector3(appui.x - APPUI.x, appui.y, lerpf(float(infos().get("encoche_repos_z", 0.195)), float(infos().get("encoche_pleine_z", 0.595)), u))

func regler(u: float, encoche_ := false) -> void:
	allonge = clampf(u, 0.0, allonge_max)
	encoche = encoche_
	_resoudre(allonge)
	_appliquer()

func claquer() -> void:
	_claque = 0.0

func claque_en_cours() -> bool:
	return _claque >= 0.0

func _vibration() -> float:
	if _claque < 0.0:
		return 0.0
	# la corde dépasse sa position de repos (vers l'arc) puis vibre, amortie en ~0,25 s
	return -0.04 * exp(-_claque * 16.0) * cos(_claque * 75.0)

func _process(dt: float) -> void:
	if _claque >= 0.0:
		_claque += dt
		if _claque > 0.4:
			_claque = -1.0
		_appliquer()

func _appliquer() -> void:
	if _cle >= 0:
		var w := _poids
		if _claque >= 0.0:
			w += -0.07 * exp(-_claque * 16.0) * cos(_claque * 75.0)   # les branches rebondissent un peu au-delà du repos
		mi_arc.set_blend_shape_value(_cle, clampf(w, -0.2, 1.0))
	var n := encoche_locale()
	mi_corde.mesh = _maille_corde(attache(_poids, true), n, attache(_poids, false))
	repere_encoche.position = n
	fleche.visible = encoche or fleche_libre != null
	if fleche_libre != null:
		fleche.transform = fleche_libre
	else:
		# encoche sur la corde, fût posé sur l'appui (à gauche de la poignée, sur le poing)
		var dir := (appui - n).normalized()
		var k := maxf(1.0, (appui.distance_to(n) + depasse_fleche) / longueur_pointe())
		fleche.transform = Transform3D(Basis.looking_at(dir, Vector3.UP) * Basis.from_scale(Vector3(1.0, 1.0, k)), n)

func _maille_corde(haut: Vector3, noeud: Vector3, bas: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uv: Array = infos().get("uv_corde", [0.375, 0.5, 0.5, 1.0])
	_prisme(st, bas, noeud, RAYON_CORDE, uv)
	_prisme(st, noeud, haut, RAYON_CORDE, uv)
	st.generate_normals()
	return st.commit()

## Prisme à 4 pans entre a et b (rayon r) ; UV dans le rectangle d'atlas uv = [u0, v0, u1, v1].
static func _prisme(st: SurfaceTool, a: Vector3, b: Vector3, r: float, uv: Array) -> void:
	var ax := (b - a).normalized()
	var x := ax.cross(Vector3.FORWARD if absf(ax.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(ax).normalized()
	var ca: Array[Vector3] = [a + x * r, a + z * r, a - x * r, a - z * r]
	var cb: Array[Vector3] = [b + x * r, b + z * r, b - x * r, b - z * r]
	for k in 4:
		var k1 := (k + 1) % 4
		var u0 := lerpf(uv[0], uv[2], k * 0.25)
		var u1 := lerpf(uv[0], uv[2], (k + 1) * 0.25)
		var q := [ca[k], ca[k1], cb[k1], cb[k]]
		var t := [Vector2(u0, uv[1]), Vector2(u1, uv[1]), Vector2(u1, uv[3]), Vector2(u0, uv[3])]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_uv(t[idx])
			st.add_vertex(q[idx])

## Pointe de la flèche encochée (monde) : départ du tir.
func pointe() -> Vector3:
	return fleche.global_transform * Vector3(0.0, 0.0, -longueur_pointe())

func encoche_monde() -> Vector3:
	return global_transform * encoche_locale()

## Direction de la flèche encochée (monde).
func direction_fleche() -> Vector3:
	return -fleche.global_transform.basis.z.normalized()
