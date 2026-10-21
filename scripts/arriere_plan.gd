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
const SHADER_PLANS := preload("res://shaders/plans_peints.gdshader")
## 4e passe : au-delà de ~600 m, le relief 3D est remplacé par 5 PLANS PEINTS (cylindres centrés sur la carte, image
## dessinée par plans_peints.gdshader). --lointain-3d rétablit l'ancien relief 3D lointain et le château 3D (A/B).
var lointain_3d := OS.get_cmdline_user_args().has("--lointain-3d")
## [rayon (m), genre (0 montagnes, 1 forêt, 2 forêt + château), voile, pied (°), dentelure (°), graine, pics visibles]
## pics : [azimut °, sommet °, demi-largeur °, dissymétrie] ; vue de l'entrée : cap ≈ 48°, château à 24° (à droite).
## La forêt 3D proche monte jusqu'à ~25-30° d'élévation depuis l'entrée : les sommets peints montent à 30-38°.
const PLANS := [
	[2400.0, 0, 0.52, 14.0, 0.35, 5.0, [[50.0, 38.0, 17.0, 0.2], [32.0, 33.0, 13.0, -0.3], [68.0, 32.0, 14.0, 0.4], [12.0, 28.0, 12.0, 0.0], [88.0, 27.0, 13.0, -0.2]]],
	[1800.0, 0, 0.37, 12.0, 0.30, 11.0, [[43.0, 34.0, 11.0, -0.2], [58.0, 28.0, 9.0, 0.3], [26.0, 25.0, 9.5, 0.2], [78.0, 24.0, 10.0, -0.3]]],
	[1300.0, 0, 0.25, 10.0, 0.25, 17.0, [[66.0, 24.0, 9.0, 0.3], [20.0, 21.0, 8.0, -0.2], [86.0, 20.0, 8.5, 0.0], [4.0, 18.0, 7.0, 0.3]]],
	[900.0, 2, 0.24, 9.0, 0.6, 23.0, [[24.0, 13.5, 14.0, 0.0], [70.0, 11.0, 12.0, 0.2]]],
	[650.0, 1, 0.16, 6.0, 0.8, 29.0, [[80.0, 8.0, 14.0, 0.0]]],
]
var _plans: Array[ShaderMaterial] = []
const R_MIN := 150.0
const R_MAX := 2500.0
const LIGNES := 72        # rangées radiales (pas géométrique)
const COLONNES := 512     # colonnes angulaires
const COUPURES := [0, 26, 50, 71]   # rangées de début/fin des 3 bandes (chevauchement d'une rangée)
const NB_SAPINS := 5200
const R_SAPINS := Vector2(165.0, 1150.0)   # 3e passe : bandes boisées jusque dans la vallée

## Château : azimut (degrés depuis +Z vers +X) et distance. Visible depuis l'entrée du village (cap sud-est) et
## depuis le chemin du tumulus (cap sud-sud-est).
const CHATEAU_AZIMUT := 24.0
const CHATEAU_DIST := 600.0
## Sommets marquants : azimut (° depuis +Z vers +X), distance, hauteur, rayon (m)
const PICS := [
	[10.0, 1500.0, 1200.0, 440.0],   # grand sommet derrière le château
	[-32.0, 1650.0, 640.0, 360.0],
	[148.0, 1500.0, 700.0, 380.0],   # nord-est, côté lune
	[238.0, 1700.0, 620.0, 340.0],
	[80.0, 1100.0, 430.0, 260.0],
	[-95.0, 1000.0, 380.0, 240.0],
	# refonte « lumière » (3e passe) : quelques GRANDS massifs aux pentes longues, un sommet franc chacun, de part et
	# d'autre d'une vallée ouverte dans l'axe de l'entrée (cap ≈ 46°) ; le plus haut au fond de la vallée
	[46.0, 2150.0, 1700.0, 950.0],
	[56.0, 2000.0, 1250.0, 700.0],   # épaule du massif central
	[66.0, 1550.0, 1250.0, 800.0],
	[82.0, 1200.0, 800.0, 600.0],
	[32.0, 1800.0, 1250.0, 850.0],
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
	if not lointain_3d:
		_creer_plans()
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
	var cho = ciel.get_shader_parameter("horizon_chaud")
	if cho != null:
		_mat.set_shader_parameter("horizon_chaud", cho)
	var da = ciel.get_shader_parameter("dir_astre")
	if da != null:
		_mat.set_shader_parameter("dir_astre", da)
	_mat.set_shader_parameter("crep", monde.cycle.chaleur())
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
	for m in _plans:
		for nom in ["horizon", "horizon_chaud", "dir_astre", "crep", "haut", "dir_lum", "col_lum", "ambiant", "jour"]:
			m.set_shader_parameter(nom, _mat.get_shader_parameter(nom))

# --- construction des nœuds (fil principal) ------------------------------------------------------------------

func _creer_noeuds() -> void:
	var noms := ["collines", "montagnes", "lointain", "sapins", "chateau"] if lointain_3d else ["collines", "montagnes", "sapins"]
	for nom in noms:
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
	h += ef * 16.0 * _ridge(wx, wz, 0.006, 2)
	# 3e passe : crêtes douces (3 octaves au lieu de 6 : plus d'aiguilles), pentes longues
	h += em * (30.0 + 95.0 * pow(_ridge(wx, wz, 0.0028, 3), 1.6))
	h += eb * (210.0 * pow(_ridge(wx + 500.0, wz - 300.0, 0.0015, 3), 1.4))   # chaîne continue qui relie les massifs
	# vallée qui s'ouvre au centre de la vue de l'entrée (cap ≈ 46°), entre 300 m et 1 800 m
	var dv := absf(wrapf(rad_to_deg(atan2(x, z)) - 46.0, -180.0, 180.0))
	var vallee := (1.0 - smoothstep(5.0, 20.0, dv)) * smoothstep(260.0, 520.0, r) * (1.0 - smoothstep(1500.0, 1900.0, r))
	if not lointain_3d:
		# 5e passe : la vallée s'ouvre dès 200 m et plus franchement (les plans peints prennent le relais au fond)
		vallee = (1.0 - smoothstep(6.0, 18.0, dv)) * smoothstep(190.0, 380.0, r)
		var dc := absf(wrapf(rad_to_deg(atan2(x, z)) - 24.0, -180.0, 180.0))
		vallee = maxf(vallee, 0.8 * (1.0 - smoothstep(4.0, 12.0, dc)) * smoothstep(230.0, 420.0, r))
	h = lerpf(h, 22.0 + ef * 18.0, (0.7 if lointain_3d else 0.85) * vallee)
	for p in PICS:
		var c := _pos_polaire(p[0], p[1])
		var t := maxf(0.0, 1.0 - Vector2(x - c.x, z - c.y).length() / p[3])
		if t > 0.0:
			# massif large (t^1,15) aux crêtes ridées (deux échelles) : arêtes et couloirs lisibles, pas une aiguille isolée
			# profil concave (pentes longues, sommet franc), crête modulée à basse fréquence seulement
			h += p[2] * 0.42 * (0.6 * pow(t, 1.8) + 0.4 * pow(t, 4.0)) * (0.8 + 0.4 * _ridge(wx, wz, 0.004, 2))
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
	_res["montagnes"] = _bande(pos, nor, col, COUPURES[1], COUPURES[2] if lointain_3d else 35)   # plans peints au-delà de ~600 m
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
		var r_max := R_SAPINS.y if lointain_3d else 580.0   # au-delà : bandes de sapins peintes
		var r := R_SAPINS.x + (r_max - R_SAPINS.x) * pow(rng.randf(), 1.7)
		var a := rng.randf() * TAU
		var e := _echant(pos, nor, col, log(r / R_MIN) / lr * (LIGNES - 1), a / TAU * COLONNES)
		var nm0: Vector3 = e[1]
		# 5e passe : axes dégagés (vallée de l'entrée ≈ 46°, château ≈ 24°) pour qu'on lise la bande dorée, les forêts
		# peintes et la falaise du château ; quelques sapins épars restent
		if not lointain_3d:
			var az := rad_to_deg(a)
			var degage := maxf(1.0 - smoothstep(6.0, 12.0, absf(az - 46.0)), 1.0 - smoothstep(5.0, 10.0, absf(az - 24.0)))
			if rng.randf() < 0.9 * degage:
				continue
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
	# 3e passe : château sur falaise lisible en silhouette à 640x360 : socle rocheux sombre et abrupt, enceinte crénelée,
	# 4 tours carrées de hauteurs différentes (2 à toit pointu enneigé, 2 crénelées), donjon, fenêtres chaudes.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var p := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var pierre := Color(0.0, 0.5, 2.0 / 5.0, 1.0)
	var toit := Color(1.0, 0.5, 2.0 / 5.0, 1.0)     # R = 1 : pierre neigée (toits)
	var roche := Color(0.0, 0.5, 4.0 / 5.0, 1.0)
	var fenetre := Color(0.0, 0.5, 1.0, 1.0)
	var centre := _pos_polaire(CHATEAU_AZIMUT, CHATEAU_DIST)
	var vue := Vector2(centre.x, centre.y).normalized()
	var lat := Vector3(-vue.y, 0.0, vue.x)          # perpendiculaire à la ligne de vue : l'enceinte s'étale à l'écran
	var sol := _y0 + _h(centre.x, centre.y) - 18.0
	var hauteur_a := 205.0
	var rayon_a := 95.0
	var o_a := Vector3(centre.x, sol, centre.y)
	_falaise(p, n, c, o_a, rayon_a, hauteur_a, rng, roche)
	var top := o_a + Vector3.UP * hauteur_a
	var yaw := atan2(lat.x, lat.z)
	# enceinte : rectangle allongé face au village (125 x 40 m), murs de 16 m crénelés
	var L := 125.0
	var P := 40.0
	var av := Vector3(vue.x, 0.0, vue.y)
	var coins: Array[Vector3] = [top - lat * L * 0.5 - av * P * 0.5, top + lat * L * 0.5 - av * P * 0.5,
		top + lat * L * 0.5 + av * P * 0.5, top - lat * L * 0.5 + av * P * 0.5]
	for k in 4:
		var a: Vector3 = coins[k]
		var b: Vector3 = coins[(k + 1) % 4]
		var d := b - a
		var lg := d.length()
		var ang := atan2(d.x, d.z)
		_boite(p, n, c, (a + b) * 0.5, 5.0, 16.0, lg, ang, pierre)
		var nb_m := int(lg / 6.0)
		for q in nb_m:
			var m := a + d * ((q + 0.5) / nb_m)
			_boite(p, n, c, m + Vector3.UP * 16.0, 5.0, 3.5, 3.0, ang, pierre)
	# tours aux coins + donjon : hauteurs différentes, 2 toits pointus
	var tours := [[coins[0], 40.0, true], [coins[1], 50.0, false], [coins[2], 34.0, false], [coins[3], 44.0, true],
		[top + lat * 18.0, 66.0, true], [top - lat * 30.0 - av * 20.0, 30.0, false]]
	for t in tours:
		var base: Vector3 = t[0]
		var ht: float = t[1]
		var larg := 13.0 if ht < 80.0 else 18.0
		_boite(p, n, c, base, larg, ht, larg, yaw, pierre)
		if t[2]:
			_pyramide(p, n, c, base + Vector3.UP * ht, larg * 1.15, larg * 1.5, yaw, toit)
		else:
			for q in 4:
				var ox := -0.38 * larg if q % 2 == 0 else 0.38 * larg
				var oz := -0.38 * larg if q < 2 else 0.38 * larg
				_boite(p, n, c, base + Vector3.UP * ht + Basis(Vector3.UP, yaw) * Vector3(ox, 0.0, oz), 3.4, 4.5, 3.4, yaw, pierre)
		_fenetre_sur(p, n, c, base + Vector3(0.0, ht * 0.72, 0.0), larg, fenetre)
		if ht > 50.0:
			_fenetre_sur(p, n, c, base + Vector3(0.0, ht * 0.45, 0.0), larg, fenetre)
	# logis contre le mur du fond, toit à deux pans enneigé (pyramide allongée)
	var logis := top - lat * 14.0 + av * 8.0
	_boite(p, n, c, logis, 30.0, 24.0, 14.0, yaw, pierre)
	_pyramide(p, n, c, logis + Vector3.UP * 24.0, 31.0, 10.0, yaw, toit, 15.0)
	_fenetre_sur(p, n, c, logis + Vector3(0.0, 14.0, 0.0), 30.0, fenetre)
	return {"pos": p, "nor": n, "col": c}

## Toit pyramidal (ou à deux pans si `prof` > 0 : base largeur x prof) posé sur `base`.
func _pyramide(p: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, base: Vector3, larg: float, haut: float, yaw: float, col: Color, prof := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	var dz := (prof if prof > 0.0 else larg) * 0.5
	var dx := larg * 0.5
	var pts: Array[Vector3] = [base + b * Vector3(-dx, 0, -dz), base + b * Vector3(dx, 0, -dz), base + b * Vector3(dx, 0, dz), base + b * Vector3(-dx, 0, dz)]
	var s0 := base + b * Vector3(-dx * (0.0 if prof <= 0.0 else 0.8), haut, 0.0)
	var s1 := base + b * Vector3(dx * (0.0 if prof <= 0.0 else 0.8), haut, 0.0)
	# 4 pans (deux triangles + deux trapèzes si deux pans)
	_tri(p, n, c, pts[0], pts[1], s1, ((pts[1] - pts[0]).cross(s1 - pts[0])).normalized() * -1.0, col)
	_tri(p, n, c, pts[0], s1, s0, ((pts[1] - pts[0]).cross(s1 - pts[0])).normalized() * -1.0, col)
	_tri(p, n, c, pts[2], pts[3], s0, ((pts[3] - pts[2]).cross(s0 - pts[2])).normalized() * -1.0, col)
	_tri(p, n, c, pts[2], s0, s1, ((pts[3] - pts[2]).cross(s0 - pts[2])).normalized() * -1.0, col)
	_tri(p, n, c, pts[1], pts[2], s1, ((pts[2] - pts[1]).cross(s1 - pts[1])).normalized() * -1.0, col)
	_tri(p, n, c, pts[3], pts[0], s0, ((pts[0] - pts[3]).cross(s0 - pts[3])).normalized() * -1.0, col)

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

## Carrés allumés (crépuscule et nuit) sur la face tournée vers le sud-est de `centre`.
func _fenetre_sur(p: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, centre: Vector3, largeur: float, col: Color) -> void:
	var vue := Vector3(centre.x, 0.0, centre.z).normalized()
	var lat := Vector3(-vue.z, 0.0, vue.x)
	var f := centre - vue * (largeur * 0.52)
	for k in 2:
		var o := f + lat * (-largeur * 0.22 + k * largeur * 0.44)
		# 4 x 5 m : 2 à 3 pixels à 600 m en 640x360 (l'ancienne 1,8 x 2,6 m tombait sous le pixel)
		_quad(p, n, c, o - lat * 2.0, o + lat * 2.0, o + lat * 2.0 + Vector3.UP * 5.0, o - lat * 2.0 + Vector3.UP * 5.0, col)

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

# --- plans peints (4e passe) ------------------------------------------------------------------------------------

# élévation (°) au-dessus de laquelle le plan peint n'a plus rien à dessiner autour de l'azimut `a` (majorant du profil de
# plans_peints.gdshader sur ± 1 pan : pics élargis ×1,5, dissymétrie, dentelure, sapins, château)
func _haut_profil(a: float, d: Array, pics: Array) -> float:
	var h: float = float(d[3]) + float(d[4]) + 2.5
	for k in 7:
		var x := a + (float(k) - 3.0) * 0.5
		for p in pics:
			var dd := absf(wrapf(x - float(p[0]), -180.0, 180.0))
			var w := 1.5 * float(p[2]) * (1.0 + 0.35 * absf(float(p[3])))
			var f := maxf(1.0 - dd / w, 0.82 * (1.0 - maxf(dd - 0.42 * w, 0.0) / (0.3 * w)))   # pic, sous-sommet
			f = maxf(f, 0.62 * (1.0 - maxf(dd - 0.45 * w, 0.0) / (0.55 * w)))                      # épaule
			h = maxf(h, float(p[1]) * f + 0.17 * maxf(float(p[1]) - float(d[3]), 1.0) + 1.5 * float(d[4]))
	if int(d[1]) == 2 and absf(wrapf(a - CHATEAU_AZIMUT, -180.0, 180.0)) < 16.0:
		h = maxf(h, 12.0 + 70.0 * 1.7 / 6.0)
	return minf(h + 1.5, 60.0)


func _creer_plans() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for d in PLANS:
		var r: float = d[0]
		var m := ShaderMaterial.new()
		m.shader = SHADER_PLANS
		m.set_shader_parameter("rayon", r)
		m.set_shader_parameter("niveau0", _y0)
		m.set_shader_parameter("genre", d[1])
		m.set_shader_parameter("voile", d[2])
		m.set_shader_parameter("base_el", d[3])
		m.set_shader_parameter("dentelure", d[4])
		m.set_shader_parameter("graine", d[5])
		m.set_shader_parameter("chateau_az", CHATEAU_AZIMUT)
		m.set_shader_parameter("chateau_el", 12.0)   # sur la butte peinte à 24°
		m.set_shader_parameter("chateau_ech", 1.7)
		# pics : ceux de la vue de l'entrée + des pics tirés au hasard sur le reste du tour (hors 0-100°)
		var pics: Array = (d[6] as Array).duplicate()
		if d[1] == 0:
			# 5e passe : pics secondaires de largeurs et de hauteurs très variées qui chevauchent ceux de la vue
			var hmax: float = d[6][0][1]
			for k in 5:
				pics.append([rng.randf_range(-8.0, 100.0), lerpf(float(d[3]) + 3.0, hmax * 0.9, pow(rng.randf(), 0.8)),
					rng.randf_range(2.5, 11.0), rng.randf_range(-0.6, 0.6)])
			var a := 110.0
			while a < 350.0 and pics.size() < 16:
				var e: float = (d[6][0][1] as float) * rng.randf_range(0.55, 0.9)
				pics.append([a, e, rng.randf_range(7.0, 13.0), rng.randf_range(-0.4, 0.4)])
				a += rng.randf_range(22.0, 38.0)
		var v: Array[Vector4] = []
		for p in pics:
			v.append(Vector4(float(p[0]), float(p[1]), float(p[2]), float(p[3])))
		while v.size() < 16:
			v.append(Vector4.ZERO)
		m.set_shader_parameter("pics", v)
		m.set_shader_parameter("nb_pics", pics.size())
		# cylindre : 256 pans, du dessous de l'horizon jusqu'au-dessus du profil peint (bord haut qui épouse les pics,
		# avec marge) : le ciel n'est pas recouvert de fragments rejetés (perf : 5 couches de surdessin évitées)
		var pos := PackedVector3Array()
		var idx := PackedInt32Array()
		var bas := _y0 - 60.0
		for i in 257:
			var a := TAU * float(i) / 256.0
			var haut := _y0 + r * tan(deg_to_rad(_haut_profil(rad_to_deg(a), d, pics)))
			pos.append(Vector3(sin(a) * r, bas, cos(a) * r))
			pos.append(Vector3(sin(a) * r, haut, cos(a) * r))
		for i in 256:
			var k := i * 2
			idx.append_array([k, k + 1, k + 2, k + 2, k + 1, k + 3])
		var tab := []
		tab.resize(Mesh.ARRAY_MAX)
		tab[Mesh.ARRAY_VERTEX] = pos
		tab[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tab)
		mesh.custom_aabb = AABB(Vector3(-R_MAX, -200.0, -R_MAX), Vector3(2.0 * R_MAX, 2000.0, 2.0 * R_MAX))
		var mi := MeshInstance3D.new()
		mi.name = "plan_%d" % int(r)
		mi.mesh = mesh
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.extra_cull_margin = 16384.0
		add_child(mi)
		_plans.append(m)
