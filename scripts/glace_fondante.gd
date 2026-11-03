class_name GlaceFondante
extends Node3D
## Amas de glace posé par un sort de glace (EffetsSol.bloc_glace) : un bloc taillé à facettes et/ou des pics, en volume,
## low-poly, avec la matière cristal de la magie (shaders/magie_cristal.gdshader : 3 tons plats, reflet de bord, fonte par
## cases de bruit). Vie : surgit (0,25 s), tient ~7 s, puis FOND (~13 s) : il rétrécit, se troue par cases, laisse tomber des
## gouttes et une flaque qui sèche (masque du sol). Près du feu (`chauffer`), il fond environ 6 fois plus vite.
## Purement visuel (aucune collision).

const POUSSE := 0.25
const TENUE := 7.0
const FONTE := 13.0
const VITESSE_CHAUD := 6.0
const CHAUD_DUREE := 1.5          # s de fonte rapide après un coup de chaleur

static var _meshes := {}          # "bloc0".."bloc2", "pic0".."pic2" -> ArrayMesh (unité : 1 m de large, 1 m de haut)

var age := 0.0
var rayon := 0.5                  # m : emprise (pour la chaleur)
var _pieces: Array = []           # {mi: MeshInstance3D, base: Transform3D}
var _chaud := 0.0
var _prochaine_goutte := 0.0
var _flaque := 0                   # nombre de stades de flaque posés

static func creer(parent: Node, pos: Vector3, normale: Vector3, echelle: float, pics: int, avec_bloc: bool, graine: int) -> GlaceFondante:
	var g := GlaceFondante.new()
	g.name = "GlaceFondante"
	parent.add_child(g)
	g.global_position = pos
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var base := GestionMagie.obtenir()._mat_cristal("glace", false)
	var haut := normale.normalized() if normale.length() > 0.1 else Vector3.UP
	if avec_bloc:
		g._ajouter("bloc%d" % rng.randi_range(0, 2), base, Vector3(rng.randf_range(-0.1, 0.1), 0.0, rng.randf_range(-0.1, 0.1)) * echelle,
			rng.randf() * TAU, Vector3(0.8, 0.7, 0.8) * echelle * rng.randf_range(0.9, 1.15), haut, rng)
	for k in pics:
		var a := TAU * (k + rng.randf() * 0.6) / maxi(pics, 1) + rng.randf() * 0.5
		var d := rng.randf_range(0.25, 0.55) * echelle
		var h := rng.randf_range(0.6, 0.9)
		g._ajouter("pic%d" % rng.randi_range(0, 2), base, Vector3(cos(a) * d, 0.0, sin(a) * d),
			rng.randf() * TAU, Vector3(0.28, h, 0.28) * echelle * rng.randf_range(0.9, 1.4), (haut + Vector3(cos(a), 0, sin(a)) * 0.25).normalized(), rng)
	g.rayon = 0.45 * echelle + (0.5 * echelle if pics > 0 else 0.0)
	g._prochaine_goutte = TENUE + 0.3
	g.vieillir(0.0)
	return g

func _ajouter(nom: String, base: ShaderMaterial, decalage: Vector3, lacet: float, echelle: Vector3, haut: Vector3, rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(nom)
	var m := base.duplicate() as ShaderMaterial      # un matériau par pièce : sa propre fonte
	m.set_shader_parameter("fonte", 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var b := GestionMagie.base_normale(haut) * Basis(Vector3.UP, lacet)
	var xf := Transform3D(b.scaled_local(echelle), decalage)
	mi.transform = xf
	add_child(mi)
	_pieces.append({"mi": mi, "base": xf})

func _process(dt: float) -> void:
	vieillir(dt)

## Fait avancer la vie de `dt` s (fonte accélérée près d'une source de chaleur).
func vieillir(dt: float) -> void:
	if _chaud > 0.0:
		_chaud -= dt
		age += dt * VITESSE_CHAUD
		if age < TENUE:
			age = TENUE
	else:
		age += dt
	var fin := TENUE + FONTE
	if age >= fin:
		queue_free()
		return
	var pousse := 1.0
	if age < POUSSE:
		var u := age / POUSSE
		pousse = 1.0 + 0.12 * sin(u * PI) - (1.0 - u) * (1.0 - u) * 0.85    # surgit avec un léger dépassement
	var p := clampf((age - TENUE) / FONTE, 0.0, 1.0)
	var fonte := smoothstep(0.3, 1.0, p)
	var k := Vector3(1.0 - 0.3 * p, pousse * (1.0 - 0.85 * p), 1.0 - 0.3 * p)
	for d in _pieces:
		var mi: MeshInstance3D = d["mi"]
		var xf: Transform3D = d["base"]
		mi.transform = Transform3D(xf.basis * Basis.from_scale(k), xf.origin * Vector3(k.x, 1.0, k.z))
		(mi.material_override as ShaderMaterial).set_shader_parameter("fonte", fonte)
	if age >= TENUE:
		_fondre(p)

func _fondre(p: float) -> void:
	var e := EffetsSol.instance
	if e == null:
		return
	# flaque : trois stades qui s'élargissent à mesure que le bloc disparaît (elle sèche ensuite : 28 s)
	while _flaque < 3 and p >= 0.08 + 0.3 * _flaque:
		_flaque += 1
		e.fondre(global_position.x, global_position.z, rayon * (0.5 + 0.28 * _flaque), true, 28.0)
	if age >= _prochaine_goutte:
		_prochaine_goutte = age + (0.5 if _chaud <= 0.0 else 0.15 * VITESSE_CHAUD)
		var bout := global_position + Vector3(randf_range(-0.2, 0.2), 0.7 * (1.0 - 0.7 * p), randf_range(-0.2, 0.2)) * rayon * 2.0
		GerbePixels.emettre(self, bout, Vector3.DOWN, "goutte", 1.0)
		if _chaud > 0.0:
			e.vapeur(global_position + Vector3(0, 0.3, 0), 0.7)

func chauffer() -> void:
	_chaud = CHAUD_DUREE

# ------------------------------------------------------------------ maillages (facettes à plat, unité 1 m)

static func _mesh(nom: String) -> ArrayMesh:
	if not _meshes.has(nom):
		var v := int(nom.substr(nom.length() - 1))
		_meshes[nom] = _bloc(v) if nom.begins_with("bloc") else _pic(v)
	return _meshes[nom]

## Bloc taillé : socle à 7 côtés irréguliers, épaule, dessus biseauté incliné (3 variantes).
static func _bloc(v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + v
	var cote := 7
	var bas: Array[Vector3] = []
	var mil: Array[Vector3] = []
	var haut: Array[Vector3] = []
	for i in cote:
		var a := TAU * i / cote
		var r := rng.randf_range(0.8, 1.0) * 0.5
		bas.append(Vector3(cos(a) * r, -0.15, sin(a) * r))
		mil.append(Vector3(cos(a + 0.1) * r * 1.05, 0.55 + rng.randf_range(-0.08, 0.08), sin(a + 0.1) * r * 1.05))
		haut.append(Vector3(cos(a + 0.2) * r * 0.55, 0.95 + rng.randf_range(-0.07, 0.07) + 0.12 * cos(a - v), sin(a + 0.2) * r * 0.55))
	var centre := Vector3(0.0, 1.02 + 0.06 * v, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in cote:
		var j := (i + 1) % cote
		st.add_vertex(bas[i]); st.add_vertex(mil[i]); st.add_vertex(mil[j])
		st.add_vertex(bas[i]); st.add_vertex(mil[j]); st.add_vertex(bas[j])
		st.add_vertex(mil[i]); st.add_vertex(haut[i]); st.add_vertex(haut[j])
		st.add_vertex(mil[i]); st.add_vertex(haut[j]); st.add_vertex(mil[j])
		st.add_vertex(haut[i]); st.add_vertex(centre); st.add_vertex(haut[j])
	st.generate_normals()
	return st.commit()

## Pic : pyramide à 5 côtés irrégulière, pointe légèrement déportée (3 variantes), base sous le sol.
static func _pic(v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 200 + v
	var cote := 5
	var bas: Array[Vector3] = []
	var mil: Array[Vector3] = []
	for i in cote:
		var a := TAU * i / cote
		var r := rng.randf_range(0.8, 1.0)
		bas.append(Vector3(cos(a) * r, -0.15, sin(a) * r))
		mil.append(Vector3(cos(a + 0.3) * r * 0.55, 0.5, sin(a + 0.3) * r * 0.55))
	var pointe := Vector3(rng.randf_range(-0.12, 0.12), 1.0, rng.randf_range(-0.12, 0.12))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in cote:
		var j := (i + 1) % cote
		st.add_vertex(bas[i]); st.add_vertex(mil[i]); st.add_vertex(mil[j])
		st.add_vertex(bas[i]); st.add_vertex(mil[j]); st.add_vertex(bas[j])
		st.add_vertex(mil[i]); st.add_vertex(pointe); st.add_vertex(mil[j])
	st.generate_normals()
	return st.commit()
