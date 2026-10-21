class_name ArrierePlan
extends Node3D
## Arrière-plan lointain : anneau de collines boisées et de montagnes enneigées (150 à 2 500 m du centre de la carte),
## un château en ruine sur une falaise avec un pont en arche, et des sapins lointains en silhouettes.
## Référence visuelle : docs/captures de référence (montagnes dentelées en couches pâlissantes, sapins sombres, château).
##
## - Tout est calculé en tâche de fond (WorkerThreadPool) : relief polaire, normales, sapins, château. Le fil principal ne
##   fait que créer les 3 maillages (collines / montagnes / lointain) + sapins + château : 5 appels de dessin.
## - Matériau `arriere_plan.gdshader` : hors brouillard Godot, profondeur truquée (derrière le monde, devant le ciel,
##   non coupé par camera.far), perspective atmosphérique PROPRE lue chaque image dans le ciel (cycle.gd) :
##   horizon/haut du ciel, lumière et ambiant du cycle jour/nuit.
## - Rien à moins de 150 m du centre ; invisible sous terre (monde._sous_terre).

const SHADER := preload("res://shaders/arriere_plan.gdshader")
const R_MIN := 150.0
const R_MAX := 2500.0
const LIGNES := 72        # rangées radiales (pas géométrique)
const COLONNES := 512     # colonnes angulaires
const COUPURES := [0, 26, 50, 71]   # rangées de début/fin des 3 bandes (chevauchement d'une rangée)
const NB_SAPINS := 4200
const R_SAPINS := Vector2(165.0, 820.0)

## Château : azimut (degrés depuis +Z vers +X) et distance. Visible depuis l'entrée du village (cap sud-est) et
## depuis le chemin du tumulus (cap sud-sud-est).
const CHATEAU_AZIMUT := 24.0
const CHATEAU_DIST := 600.0
## Sommets marquants : azimut (° depuis +Z vers +X), distance, hauteur, rayon (m)
const PICS := [
	[10.0, 1250.0, 760.0, 420.0],    # grand sommet derrière le château
	[-32.0, 1450.0, 640.0, 360.0],
	[148.0, 1250.0, 700.0, 380.0],   # nord-est, côté lune
	[238.0, 1500.0, 620.0, 340.0],
	[80.0, 900.0, 430.0, 260.0],
	[-95.0, 800.0, 380.0, 240.0],
]

var monde: Node
var _y0 := 0.0
var _tache := -1
var _res := {}
var _mat: ShaderMaterial
var _fini := false
var _noeuds: Array[MeshInstance3D] = []
var _n1 := FastNoiseLite.new()
var _n2 := FastNoiseLite.new()
var _n3 := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()

static func creer(m: Node) -> ArrierePlan:
	var a := ArrierePlan.new()
	a.monde = m
	a.name = "ArrierePlan"
	return a

func _ready() -> void:
	_y0 = float(monde.h_centre) if monde != null else 0.0
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("niveau0", _y0)
	for n in [_n1, _n2, _n3]:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 1.0
	_n1.seed = 4141
	_n2.seed = 99
	_n3.seed = 2718
	_rng.seed = 31337
	_actualiser()
	_tache = WorkerThreadPool.add_task(_calculer, false, "arriere-plan")

func _exit_tree() -> void:
	if _tache >= 0 and not _fini:
		WorkerThreadPool.wait_for_task_completion(_tache)

func _process(_dt: float) -> void:
	if not _fini:
		if _tache >= 0 and WorkerThreadPool.is_task_completed(_tache):
			WorkerThreadPool.wait_for_task_completion(_tache)
			_fini = true
			_creer_noeuds()
		return
	if visible:
		_actualiser()

## Lit le ciel et la lumière du cycle (jour/nuit/crépuscule) : couleurs de perspective atmosphérique et éclairage.
func _actualiser() -> void:
	if monde == null or monde.cycle == null:
		return
	var ciel: ShaderMaterial = monde._ciel
	var hor = ciel.get_shader_parameter("horizon_courant")
	var hau = ciel.get_shader_parameter("haut_courant")
	if hor != null:
		_mat.set_shader_parameter("horizon", hor)
	if hau != null:
		_mat.set_shader_parameter("haut", hau)
	var lum: DirectionalLight3D = monde.cycle.lumiere
	var e: Environment = monde._env
	_mat.set_shader_parameter("dir_lum", lum.global_basis.z)
	var energie := lum.light_energy if lum.visible else 0.0
	_mat.set_shader_parameter("col_lum", Vector3(lum.light_color.r, lum.light_color.g, lum.light_color.b) * energie)
	var amb := e.ambient_light_color
	_mat.set_shader_parameter("ambiant", Vector3(amb.r, amb.g, amb.b) * e.ambient_light_energy)
	_mat.set_shader_parameter("jour", monde.cycle.clarte())

# --- construction des nœuds (fil principal) ------------------------------------------------------------------

func _creer_noeuds() -> void:
	for nom in ["collines", "montagnes", "lointain", "sapins", "chateau"]:
		var d: Dictionary = _res[nom]
		var mesh := ArrayMesh.new()
		var tab := []
		tab.resize(Mesh.ARRAY_MAX)
		tab[Mesh.ARRAY_VERTEX] = d["pos"]
		tab[Mesh.ARRAY_NORMAL] = d["nor"]
		tab[Mesh.ARRAY_COLOR] = d["col"]
		if d.has("idx"):
			tab[Mesh.ARRAY_INDEX] = d["idx"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tab)
		mesh.custom_aabb = AABB(Vector3(-R_MAX, -200.0, -R_MAX), Vector3(2.0 * R_MAX, 1400.0, 2.0 * R_MAX))
		var mi := MeshInstance3D.new()
		mi.name = nom
		mi.mesh = mesh
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.extra_cull_margin = 16384.0   # camera.far = 90 m : sans cela tout serait coupé par le plan lointain
		add_child(mi)
		_noeuds.append(mi)
	_res.clear()

# --- calcul pur (tâche de fond) --------------------------------------------------------------------------------

func _ridge(x: float, z: float, f0: float, oct: int) -> float:
	var s := 0.0
	var a := 1.0
	var f := f0
	var w := 1.0
	var tot := 0.0
	for o in oct:
		var n := 1.0 - absf(_n1.get_noise_2d(x * f + o * 17.3, z * f - o * 9.1))
		n *= n
		s += n * a * w
		tot += a
		w = clampf(n * 2.0, 0.0, 1.0)
		a *= 0.5
		f *= 2.1
	return s / tot

func _pos_polaire(az_deg: float, dist: float) -> Vector2:
	var a := deg_to_rad(az_deg)
	return Vector2(sin(a) * dist, cos(a) * dist)   # azimut 0 = +Z (sud), 90 = +X (est)

## Altitude relative au sol du village (m) du relief lointain en (x, z).
func _h(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var wx := x + 150.0 * _n2.get_noise_2d(x * 0.0012, z * 0.0012)
	var wz := z + 150.0 * _n2.get_noise_2d(x * 0.0012 + 31.0, z * 0.0012 - 17.0)
	var ef := smoothstep(110.0, 430.0, r)
	var em := smoothstep(380.0, 950.0, r)
	var eb := smoothstep(850.0, 1700.0, r)
	var colline := _n3.get_noise_2d(wx * 0.004, wz * 0.004) * 0.5 + 0.5
	var h := 22.0 + ef * (22.0 + 50.0 * colline * colline)
	h += ef * 20.0 * _ridge(wx, wz, 0.006, 3)
	h += em * (45.0 + 200.0 * pow(_ridge(wx, wz, 0.0034, 6), 1.9))
	h += eb * (280.0 * pow(_ridge(wx + 500.0, wz - 300.0, 0.0018, 6), 1.9))
	for p in PICS:
		var c := _pos_polaire(p[0], p[1])
		var t := maxf(0.0, 1.0 - Vector2(x - c.x, z - c.y).length() / p[3])
		if t > 0.0:
			h += p[2] * 0.72 * pow(t, 1.3) * (0.7 + 0.6 * _ridge(wx, wz, 0.012, 3))
	return h

func _calculer() -> void:
	var cols := COLONNES + 1
	var pos := PackedVector3Array()
	pos.resize(LIGNES * cols)
	for j in LIGNES:
		var r := R_MIN * pow(R_MAX / R_MIN, float(j) / float(LIGNES - 1))
		for i in cols:
			var a := TAU * float(i) / float(COLONNES)
			var x := sin(a) * r
			var z := cos(a) * r
			pos[j * cols + i] = Vector3(x, _y0 + _h(x, z), z)
	# normales par différences centrées sur la grille polaire
	var nor := PackedVector3Array()
	nor.resize(LIGNES * cols)
	for j in LIGNES:
		for i in cols:
			var im := (i - 1 + COLONNES) % COLONNES
			var ip := (i + 1) % COLONNES
			if i == 0 or i == COLONNES:
				im = COLONNES - 1
				ip = 1
			var da: Vector3 = pos[j * cols + ip] - pos[j * cols + im]
			var dr: Vector3 = pos[mini(j + 1, LIGNES - 1) * cols + i] - pos[maxi(j - 1, 0) * cols + i]
			var n := dr.cross(da).normalized()   # vers le haut (dr vers l'extérieur, da dans le sens de l'azimut croissant)
			if n.y < 0.0:
				n = -n
			nor[j * cols + i] = n
	# couleurs : densité de forêt, grain, catégorie
	var col := PackedColorArray()
	col.resize(LIGNES * cols)
	for j in LIGNES:
		for i in cols:
			var p: Vector3 = pos[j * cols + i]
			var n: Vector3 = nor[j * cols + i]
			var alt := p.y - _y0
			var dens := smoothstep(0.55, 0.25, 1.0 - n.y) * smoothstep(190.0, 100.0, alt)
			dens *= 0.55 + 0.45 * (_n3.get_noise_2d(p.x * 0.011, p.z * 0.011) * 0.5 + 0.5)
			col[j * cols + i] = Color(dens, _rng.randf(), 0.0, 1.0)
	_res["collines"] = _bande(pos, nor, col, COUPURES[0], COUPURES[1])
	_res["montagnes"] = _bande(pos, nor, col, COUPURES[1], COUPURES[2])
	_res["lointain"] = _bande(pos, nor, col, COUPURES[2], COUPURES[3])
	_res["sapins"] = _sapins(pos, nor, col)
	_res["chateau"] = _chateau()

func _bande(pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray, j0: int, j1: int) -> Dictionary:
	var cols := COLONNES + 1
	var p := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	for j in range(j0, j1 + 1):
		for i in cols:
			p.append(pos[j * cols + i])
			n.append(nor[j * cols + i])
			c.append(col[j * cols + i])
	var idx := PackedInt32Array()
	for j in j1 - j0:
		for i in COLONNES:
			var a := j * cols + i
			var b := a + 1
			var cc := a + cols
			var d := cc + 1
			idx.append_array([a, cc, b, b, cc, d])
	return {"pos": p, "nor": n, "col": c, "idx": idx}

# --- sapins lointains : silhouettes à deux étages, deux plans croisés ------------------------------------------

func _echant(pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray, fj: float, fi: float) -> Array:
	var cols := COLONNES + 1
	var j := clampi(int(fj), 0, LIGNES - 2)
	var i := clampi(int(fi), 0, COLONNES - 1)
	var tj := fj - j
	var ti := fi - i
	var k00 := j * cols + i
	var k10 := k00 + cols
	var y := lerpf(lerpf(pos[k00].y, pos[k00 + 1].y, ti), lerpf(pos[k10].y, pos[k10 + 1].y, ti), tj)
	var nn := (nor[k00].lerp(nor[k00 + 1], ti)).lerp(nor[k10].lerp(nor[k10 + 1], ti), tj)
	var d := lerpf(lerpf(col[k00].r, col[k00 + 1].r, ti), lerpf(col[k10].r, col[k10 + 1].r, ti), tj)
	return [y, nn.normalized(), d]

func _sapins(pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var p := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var essais := 0
	var poses := 0
	var lr := log(R_MAX / R_MIN)
	while poses < NB_SAPINS and essais < NB_SAPINS * 14:
		essais += 1
		var r := R_SAPINS.x + (R_SAPINS.y - R_SAPINS.x) * pow(rng.randf(), 1.7)
		var a := rng.randf() * TAU
		var e := _echant(pos, nor, col, log(r / R_MIN) / lr * (LIGNES - 1), a / TAU * COLONNES)
		var nm0: Vector3 = e[1]
		if e[0] - _y0 > 175.0 or nm0.y < 0.8 or rng.randf() > float(e[2]) * 1.15:
			continue
		poses += 1
		var ht := rng.randf_range(16.0, 30.0) * (1.0 + r / 1400.0)
		var base := Vector3(sin(a) * r, float(e[0]) - 1.0, cos(a) * r)
		var nm := (nm0 + Vector3.UP).normalized()
		var grain := rng.randf()
		var yaw := rng.randf() * PI
		var cl := Color(0.0, grain, 1.0 / 5.0, 1.0)
		for k in 2:
			var ax := Vector3(cos(yaw + k * PI * 0.5), 0.0, sin(yaw + k * PI * 0.5))
			var w0 := ht * 0.20
			var w1 := ht * 0.12
			_tri(p, n, c, base - ax * w0, base + ax * w0, base + Vector3.UP * ht * 0.64, nm, cl)
			_tri(p, n, c, base + Vector3.UP * ht * 0.40 - ax * w1, base + Vector3.UP * ht * 0.40 + ax * w1, base + Vector3.UP * ht, nm, cl)
	return {"pos": p, "nor": n, "col": c}

func _tri(p: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, a: Vector3, b: Vector3, d: Vector3, nm: Vector3, col: Color) -> void:
	p.append(a)
	p.append(b)
	p.append(d)
	for k in 3:
		n.append(nm)
		c.append(col)

# --- château en ruine sur une falaise, pont en arche -------------------------------------------------------------

func _quad(p: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color) -> void:
	# quad a-b-d-e (sens direct) : deux triangles à normale plate ; la normale est orientée vers l'extérieur du solide
	var nm := (b - a).cross(e - a).normalized()
	_tri(p, n, c, a, b, d, nm, col)
	_tri(p, n, c, a, d, e, nm, col)

## Boîte posée sur `base` (centre du bas), `yaw` autour de Y ; 4 côtés + dessus.
func _boite(p: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, base: Vector3, sx: float, sy: float, sz: float, yaw: float, col: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	var pts: Array[Vector3] = []
	for k in 4:
		var sxk := -1.0 if (k == 0 or k == 3) else 1.0
		var szk := -1.0 if k < 2 else 1.0
		pts.append(base + b * Vector3(sxk * sx * 0.5, 0.0, szk * sz * 0.5))
	# bas : 0 (-,-) 1 (+,-) 2 (+,+) 3 (-,+)
	for k in 4:
		var k2 := (k + 1) % 4
		_quad(p, n, c, pts[k], pts[k2], pts[k2] + Vector3.UP * sy, pts[k] + Vector3.UP * sy, col)
		# les quads ci-dessus sont orientés selon le sens de parcours ; cull_disabled + normale corrigée dans le shader
	_quad(p, n, c, pts[0] + Vector3.UP * sy, pts[3] + Vector3.UP * sy, pts[2] + Vector3.UP * sy, pts[1] + Vector3.UP * sy, col)

func _chateau() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var p := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var pierre := Color(0.0, 0.5, 2.0 / 5.0, 1.0)
	var roche := Color(0.0, 0.5, 4.0 / 5.0, 1.0)
	var fenetre := Color(0.0, 0.5, 1.0, 1.0)
	var centre := _pos_polaire(CHATEAU_AZIMUT, CHATEAU_DIST)
	# axe du pont : perpendiculaire à la ligne de vue (on voit l'arche de profil)
	var vue := Vector2(centre.x, centre.y).normalized()
	var axe := Vector3(-vue.y, 0.0, vue.x)
	var sol := _y0 + _h(centre.x, centre.y) - 18.0
	var hauteur_a := 170.0
	var rayon_a := 75.0
	var o_a := Vector3(centre.x, sol, centre.y)
	var hauteur_b := 158.0
	var rayon_b := 34.0
	var o_b := o_a + axe * 165.0
	var sol_b := _y0 + _h(o_b.x, o_b.z) - 18.0
	o_b.y = sol_b
	_falaise(p, n, c, o_a, rayon_a, hauteur_a, rng, roche)
	_falaise(p, n, c, o_b, rayon_b, hauteur_b - (sol_b - sol), rng, roche)
	# --- sommet de la falaise A : enceinte, tours, donjon
	var top_a := o_a + Vector3.UP * hauteur_a
	var sommets: Array[Vector3] = []
	var nb := 7
	for k in nb:
		var a := TAU * k / nb + rng.randf_range(-0.12, 0.12)
		var rr := rayon_a * 0.50 * rng.randf_range(0.9, 1.1)
		sommets.append(top_a + Vector3(cos(a) * rr, 0.0, sin(a) * rr))
	for k in nb:
		var a: Vector3 = sommets[k]
		var b: Vector3 = sommets[(k + 1) % nb]
		if k == 3:
			# brèche : mur effondré, deux moignons
			var d := b - a
			_boite(p, n, c, a, 6.0, 6.0, d.length() * 0.3, atan2(d.x, d.z), pierre)
			continue
		var mid := (a + b) * 0.5
		var d := b - a
		var h_mur := 15.0 if k != 5 else 9.0
		_boite(p, n, c, mid, 6.0, h_mur, d.length(), atan2(d.x, d.z), pierre)
	for k in nb:
		var h_t := rng.randf_range(32.0, 44.0)
		if k == 2 or k == 5:
			h_t *= 0.62   # tours écrêtées (ruine)
		_boite(p, n, c, sommets[k], 13.0, h_t, 13.0, rng.randf() * 0.5, pierre)
		if k != 2 and k != 5:
			for q in 4:
				var ox := -4.8 if q % 2 == 0 else 4.8
				var oz := -4.8 if q < 2 else 4.8
				_boite(p, n, c, sommets[k] + Vector3(ox, h_t, oz), 3.2, 4.5, 3.2, 0.0, pierre)
		_fenetre_sur(p, n, c, sommets[k] + Vector3(0.0, h_t * 0.7, 0.0), 13.0, fenetre)
	# donjon central, haut, brisé d'un côté
	var dj := top_a + Vector3(-6.0, 0.0, 4.0)
	_boite(p, n, c, dj, 26.0, 62.0, 22.0, 0.35, pierre)
	_boite(p, n, c, dj + Vector3(0.0, 62.0, 0.0), 26.0, 8.0, 5.0, 0.35, pierre)
	for q in 5:
		_boite(p, n, c, dj + Basis(Vector3.UP, 0.35) * Vector3(-10.0 + q * 5.0, 62.0, -9.0), 3.5, 5.0, 3.5, 0.35, pierre)
	_fenetre_sur(p, n, c, dj + Vector3(0.0, 38.0, 0.0), 22.0, fenetre)
	_boite(p, n, c, top_a + Vector3(14.0, 0.0, -18.0), 20.0, 30.0, 16.0, -0.4, pierre)   # logis
	# --- tour sur la falaise B et pont
	var top_b := o_b + Vector3.UP * (hauteur_b - (sol_b - sol))
	_boite(p, n, c, top_b, 14.0, 40.0, 14.0, 0.2, pierre)
	for q in 4:
		_boite(p, n, c, top_b + Vector3(-4.8 + (q % 2) * 9.6, 40.0, -4.8 + (q / 2) * 9.6), 3.2, 4.5, 3.2, 0.2, pierre)
	_fenetre_sur(p, n, c, top_b + Vector3(0.0, 26.0, 0.0), 14.0, fenetre)
	_pont(p, n, c, top_a + axe * (rayon_a * 0.64), top_b - axe * (rayon_b * 0.62), pierre)
	return {"pos": p, "nor": n, "col": c}

## Falaise facettée : colonne irrégulière à 4 anneaux (pied évasé, tête étroite), dessus plat accidenté.
func _falaise(p: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, o: Vector3, rayon: float, hauteur: float, rng: RandomNumberGenerator, col: Color) -> void:
	var cotes := 11
	var hs := [-14.0, hauteur * 0.34, hauteur * 0.70, hauteur]
	var rs := [1.18, 1.0, 0.80, 0.66]
	var anneaux: Array = []
	for j in 4:
		var an: Array[Vector3] = []
		for k in cotes:
			var a := TAU * k / cotes + (rng.randf() - 0.5) * 0.35 + j * 0.15
			var rr: float = rayon * rs[j] * rng.randf_range(0.82, 1.14)
			an.append(o + Vector3(cos(a) * rr, hs[j] + (rng.randf() - 0.5) * 6.0, sin(a) * rr))
		anneaux.append(an)
	for j in 3:
		for k in cotes:
			var k2 := (k + 1) % cotes
			_quad(p, n, c, anneaux[j][k], anneaux[j][k2], anneaux[j + 1][k2], anneaux[j + 1][k], col)
	var haut: Array = anneaux[3]
	var cm := o + Vector3.UP * (hauteur + 3.0)
	for k in cotes:
		_tri(p, n, c, haut[k], haut[(k + 1) % cotes], cm, Vector3.UP, col)

## Petits carrés allumés (visibles la nuit seulement) sur la face tournée vers le sud-est de `centre`.
func _fenetre_sur(p: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, centre: Vector3, largeur: float, col: Color) -> void:
	var vue := Vector3(centre.x, 0.0, centre.z).normalized()
	var lat := Vector3(-vue.z, 0.0, vue.x)
	var f := centre - vue * (largeur * 0.52)
	for k in 2:
		var o := f + lat * (-largeur * 0.22 + k * largeur * 0.44)
		_quad(p, n, c, o - lat * 0.9, o + lat * 0.9, o + lat * 0.9 + Vector3.UP * 2.6, o - lat * 0.9 + Vector3.UP * 2.6, col)

## Pont en arche entre deux têtes de falaise : tablier, arche (anneau) et tympans pleins.
func _pont(p: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, a: Vector3, b: Vector3, col: Color) -> void:
	var long := Vector2(b.x - a.x, b.z - a.z).length()
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var lat := Vector3(-dir.z, 0.0, dir.x)
	var niveau := minf(a.y, b.y)
	var demi := long * 0.5
	var mil := Vector3(a.x + b.x, 0.0, a.z + b.z) * 0.5
	var larg := 8.0
	# tablier + parapets
	_boite(p, n, c, Vector3(mil.x, niveau, mil.z), larg, 3.0, long, atan2(dir.x, dir.z), col)
	_boite(p, n, c, Vector3(mil.x, niveau + 3.0, mil.z) + lat * (larg * 0.5 - 0.6), 1.2, 2.2, long, atan2(dir.x, dir.z), col)
	_boite(p, n, c, Vector3(mil.x, niveau + 3.0, mil.z) - lat * (larg * 0.5 - 0.6), 1.2, 2.2, long, atan2(dir.x, dir.z), col)
	# arche : demi-ellipse sous le tablier
	var rayon := demi
	var creux := minf(rayon * 0.95, 44.0)
	var pas := 12
	for s in 2:
		var cote := lat * (larg * 0.5 if s == 0 else -larg * 0.5)
		for k in pas:
			var t0 := PI * k / pas
			var t1 := PI * (k + 1) / pas
			var e0 := Vector3(mil.x, niveau, mil.z) + cote - dir * cos(t0) * rayon + Vector3.DOWN * (creux - sin(t0) * creux)
			var e1 := Vector3(mil.x, niveau, mil.z) + cote - dir * cos(t1) * rayon + Vector3.DOWN * (creux - sin(t1) * creux)
			# tympan : de l'arc extérieur au tablier
			_quad(p, n, c, e0, e1, Vector3(e1.x, niveau, e1.z), Vector3(e0.x, niveau, e0.z), col)
	# intrados : épaisseur de l'arche vue en dessous
	for k in pas:
		var t0 := PI * k / pas
		var t1 := PI * (k + 1) / pas
		var base := Vector3(mil.x, niveau, mil.z)
		var e0 := base - dir * cos(t0) * rayon + Vector3.DOWN * (creux - sin(t0) * creux)
		var e1 := base - dir * cos(t1) * rayon + Vector3.DOWN * (creux - sin(t1) * creux)
		_quad(p, n, c, e0 + lat * larg * 0.5, e1 + lat * larg * 0.5, e1 - lat * larg * 0.5, e0 - lat * larg * 0.5, col)
