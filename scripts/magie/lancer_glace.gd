class_name LancerGlace
extends LancerEcole
## LANCER DE GLACE (éclat, lance, geste de souffle) : naît de la grappe de cristaux et du givre de la main (mêmes cristaux
## hexagonaux, mêmes tons, même brume, mêmes runes de glace) :
##   naissance : les petits cristaux qui flottaient autour de la main et un nuage de brume se rassemblent sur la tête ; la grappe
##               de 12 cristaux (celle du repos) se REDRESSE et s'ALLONGE en un éclat qui part (lance : plus long, plus massif) ;
##   vol       : bouquet de cristaux effilé vers l'avant, traînée de brume froide qui retombe, petits cristaux semés qui fondent,
##               scintillements, runes de glace en orbite ;
##   fin       : la tête se rétracte, la traînée s'efface seule ; `reformer(main)` : givre et cristaux se reforment dans la main.
## Double : deux bouquets (un par main) convergent et fusionnent en UN bouquet plus large (un seul anneau de runes).

const PAL_BRUME := ["#4a78c0", "#8cc0f0", "#d8f0ff", "#ffffff"]
const PAL_ETINC := ["#1b2c5a", "#5f9fe8", "#a8d8f8", "#ffffff"]
const NB_BRUME := 70
const NB_ETINC := 56
const NB_SEMES := 16
const ECH := 1.3

var _mat: ShaderMaterial
var _bouquet: Node3D
var _pieds: Array = []          # [{n, incl, az, l}]
var _petits: Array = []         # cristaux flottants / semés : [{n, mode, pos, vel, rot, spin, s, age, vie, vers}]
var _bq2: Node3D                # deuxième bouquet (double magie : flux de la 2e main, avant la fusion)
var _pieds2: Array = []
var _rep := false               # instance de « reformation » (fin du lancer)
var _rep_centre := Vector3.ZERO
var _rep_cibles: Array = []

func _construire() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/magie_cristal.gdshader")
	_mat.set_shader_parameter("c_ombre", Color("#1a3a78"))
	_mat.set_shader_parameter("c_milieu", Color("#4a9ae8"))
	_mat.set_shader_parameter("c_clair", Color("#a8dcff"))
	_mat.set_shader_parameter("c_reflet", Color("#f4fbff"))
	_mat.set_shader_parameter("eclat", 1.1)
	_bouquet = _faire_bouquet(_pieds)
	_bq2 = _faire_bouquet(_pieds2)
	_bq2.visible = false
	for k in NB_SEMES:
		var mi := _cristal(0.0085 + 0.006 * h(k * 3 + 1), 0.03 + 0.028 * h(k * 5 + 2))
		mi.visible = false
		add_child(mi)
		mi.top_level = true
		_petits.append({"n": mi, "mode": 0, "pos": Vector3.ZERO, "vel": Vector3.ZERO, "rot": Vector3(h(k * 7), h(k * 11), h(k * 13)) * TAU,
			"spin": Vector3(h(k * 17) - 0.5, h(k * 19) - 0.5, h(k * 23) - 0.5) * 9.0, "s": 1.0, "age": 0.0, "vie": 0.6, "vers": Vector3.ZERO})
	_mix = nuage(NB_BRUME, mat_bouffee(0, PAL_BRUME, 0.9))
	_add = nuage(NB_ETINC, mat_bouffee(1, PAL_ETINC, 0.7, 1.4))
	if not _rep:
		runes_tete((3.4 if forme == "lance" else 2.8) * (1.3 if double else 1.0))

func _faire_bouquet(pieds: Array) -> Node3D:
	var b := Node3D.new()
	b.top_level = true
	add_child(b)
	for k in NoyauEcole.GRAPPE.size():
		var g: Array = NoyauEcole.GRAPPE[k]
		var mi := _cristal(float(g[3]), float(g[2]))
		b.add_child(mi)
		pieds.append({"n": mi, "incl": float(g[0]), "az": float(g[1]), "l": float(g[2]), "haut": float(g[4])})
	return b

## Cristal hexagonal (même maillage que la grappe du repos : NoyauEcole._mesh_cristal) : prisme à 6 pans, deux pointes.
func _cristal(r: float, l: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pointe := l * 0.32
	var corps := l - pointe
	var bas: Array[Vector3] = []
	var haut: Array[Vector3] = []
	for s in 6:
		var a := TAU * s / 6.0
		bas.append(Vector3(cos(a) * r, corps * 0.18, sin(a) * r))
		haut.append(Vector3(cos(a) * r * 0.92, corps, sin(a) * r * 0.92))
	var pied := Vector3(0.0, -r * 0.35, 0.0)
	var tete_c := Vector3(0.0, l, 0.0)
	for s in 6:
		var s2 := (s + 1) % 6
		for v in [bas[s], haut[s], haut[s2], bas[s], haut[s2], bas[s2], haut[s], tete_c, haut[s2], bas[s2], pied, bas[s]]:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat
	mi.layers = CoucheMagie.CALQUE
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.0
	return mi

# ---------------------------------------------------------------- naissance

func _naissance() -> void:
	if _rep:
		return
	var p0 := pos_main(0, origine)
	var haut := Vector3.UP * 0.06
	# les petits cristaux qui flottaient autour de la main (orbites du repos : rayon 0,085-0,145, hauteur -0,08..0,15)
	for k in _petits.size():
		var e: Dictionary = _petits[k]
		var src := p0 if (k % 2 == 0 or mains.size() < 2) else pos_main(1, origine)
		var a := TAU * h(k * 7 + 3)
		var rr := (0.085 + 0.06 * h(k * 13 + 5)) * ECH
		e.pos = src + haut + Vector3(cos(a) * rr, lerpf(-0.08, 0.15, h(k * 17 + 6)) * ECH, sin(a) * rr)
		e.mode = 1
		e.age = 0.0
		e.vie = DUREE_NAISSANCE * (0.7 + 0.5 * h(k * 5 + 1)) if k < 11 else 0.5
		e.s = 1.0
		if k >= 11:
			e.mode = 0
		(e.n as MeshInstance3D).visible = int(e.mode) == 1
	# nuage de givre de la main : brume qui se rassemble sur la tête
	for k in 18:
		var src2 := p0 if (k % 2 == 0 or mains.size() < 2) else pos_main(1, origine)
		var a2 := TAU * h(k * 3 + 1)
		var r2 := 0.06 + 0.1 * h(k * 5 + 2)
		semer({"pos": src2 + haut + Vector3(cos(a2) * r2, (h(k * 7) - 0.4) * 0.14, sin(a2) * r2), "vie": 0.55 + 0.25 * h(k), "suit": DUREE_NAISSANCE * 0.9,
			"s0": 0.07, "s1": 0.13, "a": 0.3, "ton": 0.4 + 0.6 * h(k * 9), "grav": 0.3, "freine": 2.0, "vel2": dir * 1.5, "delai": h(k * 11) * 0.06})
	# éclats qui scintillent au départ
	for k in 14:
		semer({"pos": p0 + haut + Vector3(h(k * 3) - 0.5, h(k * 5) - 0.3, h(k * 7) - 0.5) * 0.2, "vie": 0.5, "sorte": 3, "s0": 0.014, "s1": 0.006, "a": 0.9, "ton": 0.8,
			"suit": DUREE_NAISSANCE * 0.8, "vel2": dir * 2.0, "delai": h(k * 13) * 0.08})

# ---------------------------------------------------------------- vie

func _regler_bouquet(b: Node3D, pieds: Array, centre: Vector3, d: Vector3, s: float, ech: float, vis: float) -> void:
	b.visible = vis > 0.01
	if not b.visible:
		return
	var bd := LancerEcole.base_y(d)
	# la grappe du repos se REDRESSE (inclinaisons → 0) et s'ALLONGE (jusqu'à x3,4, lance x4,6) en partant ; le pied reste derrière la tête
	var allonge := (1.0 + (3.2 if forme == "lance" else 2.2) * s)
	var redresse := 1.0 - 0.86 * s
	var tour := t * (2.5 + 6.0 * s)
	b.global_transform = Transform3D(bd * Basis.IDENTITY.scaled(Vector3.ONE * vis), centre - d * (0.11 * ECH * ech * allonge))
	for k in pieds.size():
		var p: Dictionary = pieds[k]
		var base := Basis(Vector3.UP, float(p.az) + tour * (1.0 if k % 2 == 0 else -1.0)) * Basis(Vector3.BACK, -float(p.incl) * redresse)
		var lg := (1.0 if k == 0 else (0.8 if float(p.l) > 0.09 else 0.6)) * allonge
		var larg := ech * (1.0 + (0.2 if forme == "lance" else 0.0)) * (1.0 - 0.15 * s)
		(p.n as MeshInstance3D).transform = Transform3D(base * Basis.IDENTITY.scaled(Vector3(larg, ech * lg, larg)), Vector3(0.0, float(p.haut) * ech, 0.0))

func _maj(dt: float, cb: Basis) -> void:
	if _rep:
		_maj_reforme(dt, cb)
		return
	var s := naiss() if phase != Phase.FIN else 1.0
	var ech := ECH * intensite_k() * (1.0 + 0.15 * float(phase == Phase.FIN)) * (1.6 if forme == "lance" else 1.0) * (1.35 if double else 1.0)
	var fin_k := 1.0 - smoothstep(0.0, 0.14, t_fin) if phase == Phase.FIN else 1.0
	var tt := tete
	# DOUBLE : deux bouquets (un par main) convergent vers le point de fusion puis n'en font plus qu'un, plus large
	var u := 1.0
	if double and mains.size() > 1 and phase != Phase.FIN:
		u = smoothstep(0.0, DUREE_NAISSANCE * 1.15, t)
		var pg := pos_main(0, origine)
		var pd := pos_main(1, origine)
		var fus := tete
		var g := pg.lerp(fus, u)
		var d := pd.lerp(fus, u)
		var sep := 1.0 - u
		_regler_bouquet(_bq2, _pieds2, d, (fus - pd).normalized() if sep > 0.02 else dir, s * 0.7, ech * 0.7, sep)
		_regler_bouquet(_bouquet, _pieds, g, (fus - pg).normalized() if sep > 0.02 else dir, s * 0.7 + 0.3 * u, ech * (0.7 + 0.3 * u), 1.0)
		_semer_flux(pd, fus, sep)
	else:
		_bq2.visible = false
		_regler_bouquet(_bouquet, _pieds, tt, dir, s, ech, fin_k)
	# traînée : brume froide qui retombe, scintillements, petits cristaux qui fondent
	if phase != Phase.FIN:
		var dens := (0.5 + 0.5 * s) * (1.3 if double else 1.0)
		var semis := func(pos: Vector3) -> void:
			var a := randf() * TAU
			var pr := LancerEcole.perp(dir)
			var off: Vector3 = (pr[0] * cos(a) + pr[1] * sin(a)) * randf_range(0.02, 0.1) * ech
			semer({"pos": pos + off - dir * 0.1, "vel": -dir * 0.3 + off * 2.0, "freine": 1.5, "vie": randf_range(0.7, 1.1), "s0": 0.05 * ech, "s1": 0.17 * ech,
				"a": 0.26 * dens, "ton": randf(), "grav": 0.35})
			if randf() < 0.55:
				semer({"pos": pos + off * 1.5, "vel": off * 3.0 - dir * 0.6, "freine": 3.0, "vie": randf_range(0.25, 0.5), "sorte": 3, "s0": 0.016, "s1": 0.005, "a": 0.9, "ton": 0.8})
			if randf() < 0.1:
				_semer_cristal(pos + off, off * 2.5 - dir * 0.8)
		le_long(semis)
	_maj_petits(dt)
	puffs(dt, cb, 1.0)
	if phase != Phase.FIN:
		lumiere(Color(0.45, 0.7, 1.0), 2.6 * ech / ECH, 6.0)
	if _runes != null and is_instance_valid(_runes):
		_runes.visible = phase != Phase.FIN
		_runes.echelle = (3.4 if forme == "lance" else 2.8) * (1.3 if double else 1.0)

## Flux de brume + cristaux de la 2e main vers le point de fusion (double).
func _semer_flux(src: Vector3, vers: Vector3, k: float) -> void:
	if k < 0.05:
		return
	if randf() < 0.9:
		var a := randf() * TAU
		var pr := LancerEcole.perp((vers - src).normalized())
		var pos := src.lerp(vers, randf() * 0.6) + (pr[0] * cos(a) + pr[1] * sin(a)) * 0.05
		semer({"pos": pos, "vel": (vers - src) * 0.6, "freine": 1.0, "vie": 0.5, "s0": 0.05, "s1": 0.11, "a": 0.28 * k, "ton": randf(), "grav": 0.2})

func _semer_cristal(pos: Vector3, vel: Vector3) -> void:
	for e: Dictionary in _petits:
		if int(e.mode) == 0:
			e.mode = 2
			e.pos = pos
			e.vel = vel
			e.age = 0.0
			e.vie = randf_range(0.5, 0.9)
			e.s = randf_range(0.8, 1.4)
			(e.n as MeshInstance3D).visible = true
			return

func _maj_petits(dt: float) -> void:
	for e: Dictionary in _petits:
		var m: int = e.mode
		if m == 0:
			continue
		var n: MeshInstance3D = e.n
		e.age = float(e.age) + dt
		var a: float = e.age
		var rot: Vector3 = e.rot
		rot += (e.spin as Vector3) * dt
		e.rot = rot
		var sc := 1.0
		if m == 1:
			# se rassemble sur la tête (accélère), rétrécit en s'y fondant
			var p := clampf(a / float(e.vie), 0.0, 1.0)
			e.pos = (e.pos as Vector3).lerp(tete, 1.0 - exp(-dt * (6.0 + 22.0 * p)))
			sc = 1.0 - smoothstep(0.6, 1.0, p)
			if p >= 1.0:
				e.mode = 0
				n.visible = false
				continue
		else:
			# semé : retombe lentement et fond
			var v: Vector3 = e.vel
			v *= exp(-dt * 2.0)
			v.y -= 1.2 * dt
			e.vel = v
			e.pos = (e.pos as Vector3) + v * dt
			var p2 := a / float(e.vie)
			sc = float(e.s) * (1.0 - smoothstep(0.5, 1.0, p2))
			if p2 >= 1.0:
				e.mode = 0
				n.visible = false
				continue
		n.global_transform = Transform3D(Basis.from_euler(rot) * Basis.IDENTITY.scaled(Vector3.ONE * maxf(sc, 0.01) * ECH * 1.4), e.pos)

# ---------------------------------------------------------------- fin : le givre se reforme dans la main

func _fin() -> void:
	# à l'impact, quelques éclats jaillissent de la tête qui se rétracte
	for k in 10:
		var a := randf() * TAU
		var pr := LancerEcole.perp(dir)
		var v := (pr[0] * cos(a) + pr[1] * sin(a)) * randf_range(0.6, 2.0) - dir * randf_range(0.0, 1.0)
		semer({"pos": tete, "vel": v, "freine": 2.0, "vie": 0.4, "sorte": 3, "s0": 0.02, "s1": 0.006, "a": 1.0, "ton": 0.9})

## Le repos se reforme dans la main : givre et petits cristaux reviennent des abords vers leurs orbites du repos, brume qui
## retombe sur la paume. À appeler à la fin du lancer (récupération). `centre` : centre de l'énergie tenue (RunesOrbite.global_position).
static func reformer(main: Node3D, centre := Vector3.INF) -> LancerGlace:
	if main == null or not is_instance_valid(main):
		return null
	var n := LancerGlace.new()
	n.ecole = "glace"
	n._rep = true
	n.mains = [main]
	n.name = "ReformeGlace"
	LancerEcole._scene().add_child(n)
	n._rep_centre = centre if centre != Vector3.INF else main.global_position + Vector3.UP * 0.12
	n.global_position = n._rep_centre
	n.tete = n._rep_centre
	n.demarrer(1.0)
	n.set_meta("reforme", true)
	return n

func _maj_reforme(dt: float, cb: Basis) -> void:
	var main := pos_main(0, _rep_centre)
	var haut: float = _rep_centre.y - main.y
	var centre := main + Vector3.UP * haut
	tete = centre
	global_position = centre
	_bouquet.visible = false
	_bq2.visible = false
	var cam := get_viewport().get_camera_3d()
	if t < 0.02 and _rep_cibles.is_empty():
		var avant := (-cam.global_basis.z) if cam != null else Vector3.FORWARD
		for k in _petits.size():
			var a := TAU * h(k * 7 + 3)
			var rr := (0.085 + 0.06 * h(k * 13 + 5)) * ECH
			var y := lerpf(-0.08, 0.15, h(k * 17 + 6)) * ECH
			var e: Dictionary = _petits[k]
			var cible_loc := Vector3(cos(a) * rr, y, sin(a) * rr)
			e.pos = centre + cible_loc + (avant * 0.5 + Vector3(h(k * 3) - 0.5, h(k * 5) - 0.2, h(k * 9) - 0.5) * 0.4)
			e.vers = cible_loc
			e.mode = 3
			e.age = -h(k * 19) * 0.12
			e.vie = 0.38
			(e.n as MeshInstance3D).visible = true
		_rep_cibles = [true]
		for k in 16:
			var a2 := TAU * h(k * 3 + 1)
			semer({"pos": centre + Vector3(cos(a2) * 0.2, 0.18, sin(a2) * 0.2), "vel": Vector3(0, -0.4, 0), "vie": 0.6, "s0": 0.06, "s1": 0.1, "a": 0.28, "ton": 0.3 + 0.7 * h(k), "freine": 1.0, "delai": h(k * 5) * 0.2})
	for e: Dictionary in _petits:
		if int(e.mode) != 3:
			continue
		var n: MeshInstance3D = e.n
		e.age = float(e.age) + dt
		var p := clampf(float(e.age) / float(e.vie), 0.0, 1.0)
		var cible: Vector3 = centre + (e.vers as Vector3)
		e.pos = (e.pos as Vector3).lerp(cible, 1.0 - exp(-dt * (5.0 + 16.0 * p)))
		var rot: Vector3 = e.rot + (e.spin as Vector3) * dt * (1.0 - p)
		e.rot = rot
		n.visible = float(e.age) > 0.0
		n.global_transform = Transform3D(Basis.from_euler(rot) * Basis.IDENTITY.scaled(Vector3.ONE * (0.2 + 0.8 * p) * ECH * 1.4), e.pos)
		if p >= 1.0 and float(e.age) > float(e.vie) + 0.05:
			n.visible = false
			e.mode = 0
	if t > 0.34 and not get_meta("flash", false):
		set_meta("flash", true)
		semer({"pos": centre, "vie": 0.25, "sorte": 2, "s0": 0.05, "s1": 0.14, "a": 0.7})
	puffs(dt, cb, 1.0)
	var vivants := 0
	for e: Dictionary in _petits:
		if int(e.mode) == 3:
			vivants += 1
	if t > 0.9 and vivants == 0 and _p.is_empty():
		queue_free()
