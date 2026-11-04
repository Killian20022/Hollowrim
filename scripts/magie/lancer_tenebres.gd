class_name LancerTenebres
extends LancerEcole
## LANCER DE TÉNÈBRES (trait d'ombre, drain, rayon du néant) : la FUMÉE VOLUMÉTRIQUE de la main (mêmes bouffées sombres bordées de
## violet, même cœur violet, mêmes braises, mêmes runes) s'étire en volute :
##   naissance : la fumée de la main, enroulée en spirale autour de la paume, est aspirée vers la tête et s'étire en filaments le
##               long du tir ; le cœur violet se resserre en tête de comète ;
##   vol       : tête sombre (cœur violet + runes en orbite) tirant une VOLUTE de fumée qui s'enroule en hélice autour de l'axe,
##               filaments effilochés, braises violettes ;
##   fin       : la tête se dissipe en fumée, la traînée s'étire et s'efface ; `reformer(main)` : la fumée revient s'enrouler dans la main.
## Rayon du néant : `volute_rayon(...)` : la fumée de la main s'engouffre dans le cercle runique et s'extrude le long du rayon
## (RayonNeant fait ensuite grandir le faisceau depuis ce même point : plus d'apparition d'un coup).
## Double : deux colonnes de fumée (une par main) convergent et se fondent en une seule, plus large.

const PAL_FUMEE := ["#07030c", "#4a1a78", "#b070f0", "#f0d8ff"]
const PAL_BRAISE := ["#07030c", "#9a3ae0", "#d08aff", "#f6e4ff"]
const NB_FUMEE := 260
const NB_ADD := 70

var _rayon := false
var _rep := false
var _acc := 0.0
var _vers_rayon := Vector3.ZERO

func _construire() -> void:
	_mix = nuage(NB_FUMEE, mat_bouffee(0, PAL_FUMEE, 0.85))
	_add = nuage(NB_ADD, mat_bouffee(1, PAL_BRAISE, 0.7, 1.35))
	if not _rayon and not _rep:
		runes_tete(2.8 * (1.3 if double else 1.0))

# ---------------------------------------------------------------- naissance

## Spirale de fumée autour de la paume (comme au repos : rayon ~0,15, aspirée vers le centre), aspirée vers `vers`.
func _spirale_main(src: Vector3, n: int, vers: Vector3, suit: float, vel2: Vector3, delai_max: float) -> void:
	var pr := LancerEcole.perp(dir)
	for k in n:
		var a := TAU * h(k * 3 + 1)
		var r := (0.04 + 0.12 * h(k * 5 + 2))
		var off: Vector3 = (pr[0] * cos(a) + pr[1] * sin(a)) * r + Vector3.UP * (h(k * 7 + 3) - 0.3) * 0.1
		var tang: Vector3 = (pr[1] * cos(a) - pr[0] * sin(a))
		semer({"pos": src + Vector3.UP * 0.06 + off, "vel": tang * 0.6, "vie": 0.5 + 0.35 * h(k * 9 + 4), "suit": suit * (0.7 + 0.3 * h(k)),
			"vers": vers, "vel2": vel2 + tang * 1.2 + dir * h(k * 11) * 2.0, "s0": 0.12, "s1": 0.22, "a": 0.85, "ton": 0.25 + 0.5 * h(k * 13), "freine": 1.6,
			"delai": h(k * 17 + 5) * delai_max})
	# braises aspirées avec elle
	for k in int(n / 3):
		var a2 := TAU * h(k * 19 + 2)
		semer({"pos": src + Vector3.UP * 0.1 + Vector3(cos(a2), 0.2 * (h(k) - 0.5), sin(a2)) * (0.07 + 0.08 * h(k * 3)), "vie": 0.5, "sorte": 3, "s0": 0.012, "s1": 0.006, "a": 1.0,
			"ton": 0.4 + 0.6 * h(k), "suit": suit, "vers": vers, "vel2": vel2 * 0.8, "delai": h(k * 23) * delai_max})

func _naissance() -> void:
	if _rep or _rayon:
		return
	var p0 := pos_main(0, origine)
	_spirale_main(p0, 34, Vector3.INF, DUREE_NAISSANCE, dir * 2.0, 0.07)
	if mains.size() > 1:
		_spirale_main(pos_main(1, origine), 34, Vector3.INF, DUREE_NAISSANCE * 1.1, dir * 2.0, 0.07)

# ---------------------------------------------------------------- vie

func _maj(dt: float, cb: Basis) -> void:
	if _rayon:
		_maj_rayon(dt, cb)
		puffs(dt, cb)
		return
	if _rep:
		puffs(dt, cb)
		if t > 0.5 and _p.is_empty():
			queue_free()
		return
	var s := naiss() if phase != Phase.FIN else 1.0
	var ech := (0.7 + 0.3 * s) * intensite_k() * (1.3 if double else 1.0) * (1.25 if forme == "trait" else 1.0)
	var fin_k := 1.0 - smoothstep(0.0, 0.18, t_fin) if phase == Phase.FIN else 1.0
	var pr := LancerEcole.perp(dir)
	if phase != Phase.FIN:
		# cœur violet qui bat, en tête de comète ; plus resserré tant que la fumée s'étire encore
		var bat := 0.9 + 0.1 * sin(t * 24.0)
		var rc := 0.05 * bat * ech * (0.8 + 0.4 * s)
		semer({"pos": tete, "vie": 0.045, "sorte": 2, "s0": rc, "s1": rc, "a": 0.8})
		semer({"pos": tete, "vie": 0.045, "sorte": 2, "s0": rc * 2.3, "s1": rc * 2.3, "a": 0.2})
		# corps de la tête : nuage dense de fumée (même densité que le repos), plus gros qu'un point
		for q in 3:
			var a0 := randf() * TAU
			var o0: Vector3 = (pr[0] * cos(a0) + pr[1] * sin(a0)) * randf_range(0.0, 0.07) * ech + pr[0] * 0.0
			semer({"pos": tete + o0 - dir * randf_range(0.0, 0.12) * ech, "vel": o0 * 3.0 - dir * 0.3, "vie": randf_range(0.2, 0.32), "s0": 0.13 * ech, "s1": 0.2 * ech, "a": 0.9, "ton": randf() * 0.5, "freine": 3.0})
		# colonne de la 2e main (double) : aspirée vers la tête
		if double and mains.size() > 1 and t < DUREE_NAISSANCE * 1.4:
			var pd := pos_main(1, origine)
			var fus := tete
			for q in 2:
				var f := randf()
				var a := randf() * TAU
				semer({"pos": pd.lerp(fus, f * 0.7) + (pr[0] * cos(a) + pr[1] * sin(a)) * 0.05, "vel": (fus - pd) * 0.9, "vie": 0.45, "s0": 0.08, "s1": 0.15, "a": 0.7, "ton": randf() * 0.6, "freine": 1.2})
		# naissance : la fumée s'étire en filaments entre la main et la tête
		if t < DUREE_NAISSANCE * 1.4:
			var src := pos_main(0, origine)
			var l := src.distance_to(tete)
			if l > 0.1:
				var f2 := randf()
				var a2 := randf() * TAU
				var o: Vector3 = (pr[0] * cos(a2) + pr[1] * sin(a2)) * 0.05
				semer({"pos": src.lerp(tete, f2) + o, "vel": (tete - src).normalized() * 0.5, "vie": 0.3, "sorte": 1, "long": minf(l * 0.15, 0.3), "ton": 0.3 + 0.4 * randf(), "a": 0.9})
		# volute : la fumée s'enroule en hélice autour de l'axe
		var dens := (0.6 + 0.4 * s)
		var semis := func(pos: Vector3) -> void:
			_acc += 2.3
			var a3 := _acc
			var off2: Vector3 = (pr[0] * cos(a3) + pr[1] * sin(a3)) * 0.11 * ech
			var tang: Vector3 = (pr[1] * cos(a3) - pr[0] * sin(a3))
			semer({"pos": pos + off2, "vel": tang * 1.1 - dir * 0.45 + off2 * 2.5, "vie": randf_range(0.8, 1.2), "s0": 0.12 * ech, "s1": 0.36 * ech, "a": 0.9 * dens,
				"ton": randf() * 0.7, "freine": 1.3, "grav": -0.15})
			if randf() < 0.45:
				# filaments effilochés : ils restent dans la volute (léger recul, freinés) au lieu de filer vers l'œil, où un trait de
				# 0,3 m devenait une longue aiguille blanche en travers de l'écran ; tons violets (pas de blanc pur)
				semer({"pos": pos + off2 * 1.3, "vel": tang * 1.2 - dir * 0.35, "vie": randf_range(0.28, 0.42), "sorte": 1, "long": randf_range(0.1, 0.17) * ech, "ton": 0.3 + 0.45 * randf(), "a": 0.85, "freine": 3.0})
			if randf() < 0.35:
				semer({"pos": pos + off2 * 1.5, "vel": off2 * 4.0 - dir * 0.5, "vie": randf_range(0.3, 0.6), "sorte": 3, "s0": 0.014, "s1": 0.006, "a": 1.0, "ton": randf(), "freine": 2.0})
		le_long(semis, 0.07)
	lumiere(Color(0.62, 0.25, 1.0), 2.4 * fin_k, 5.0)
	puffs(dt, cb)
	if _runes != null and is_instance_valid(_runes):
		_runes.visible = phase != Phase.FIN
		_runes.echelle = 2.8 * (1.3 if double else 1.0)

func _fin() -> void:
	# la tête se dissipe : volute de fumée qui s'ouvre et braises
	var pr := LancerEcole.perp(dir)
	for k in 12:
		var a := TAU * h(k * 3 + 7)
		var v := (pr[0] * cos(a) + pr[1] * sin(a)) * randf_range(0.5, 1.6) - dir * randf_range(0.0, 0.8)
		semer({"pos": tete, "vel": v, "vie": 0.7, "s0": 0.1, "s1": 0.22, "a": 0.8, "ton": randf() * 0.6, "freine": 2.0})
	for k in 10:
		var a2 := randf() * TAU
		semer({"pos": tete, "vel": (pr[0] * cos(a2) + pr[1] * sin(a2)) * randf_range(1.0, 2.6), "vie": 0.45, "sorte": 3, "s0": 0.016, "s1": 0.006, "a": 1.0, "ton": randf(), "freine": 2.0})

# ---------------------------------------------------------------- fin : la fumée revient dans la main

## La fumée s'enroule de nouveau dans la main (repos) : colonne qui s'enfonce dans la paume. `centre` : centre de l'énergie tenue.
static func reformer(main: Node3D, centre := Vector3.INF) -> LancerTenebres:
	if main == null or not is_instance_valid(main):
		return null
	var n := LancerTenebres.new()
	n.ecole = "tenebres"
	n._rep = true
	n.mains = [main]
	n.name = "ReformeTenebres"
	LancerEcole._scene().add_child(n)
	var c := centre if centre != Vector3.INF else main.global_position + Vector3.UP * 0.12
	n.global_position = c
	n.tete = c
	n.demarrer(1.0)
	var cam := n.get_viewport().get_camera_3d()
	var avant := (-cam.global_basis.z) if cam != null else Vector3.FORWARD
	var pr := LancerEcole.perp(avant)
	for k in 26:
		var a := TAU * h(k * 3 + 1)
		var r := 0.12 + 0.2 * h(k * 5 + 2)
		var pos := c + avant * (0.15 + 0.25 * h(k)) + (pr[0] * cos(a) + pr[1] * sin(a)) * r
		n.semer({"pos": pos, "vie": 0.6 + 0.15 * h(k * 9), "suit": 0.4 + 0.1 * h(k * 7), "vers": c, "s0": 0.1, "s1": 0.07, "a": 0.7, "ton": 0.2 + 0.5 * h(k * 11), "delai": h(k * 13) * 0.15, "freine": 3.0})
	return n

# ---------------------------------------------------------------- rayon du néant

## La fumée de la main entre dans le cercle runique (centre `debut`) et s'extrude le long de `avant` ; vit `duree` s.
static func volute_rayon(main: Node3D, debut: Vector3, avant: Vector3, largeur := 1.0, duree := 0.85, k := 1.0) -> LancerTenebres:
	var n := LancerTenebres.new()
	n.ecole = "tenebres"
	n._rayon = true
	n.fixe = true
	n.duree_geste = duree
	n.set_meta("geste", true)
	n.name = "VoluteRayon"
	if main != null and is_instance_valid(main):
		n.mains = [main]
	LancerEcole._scene().add_child(n)
	n.global_position = debut
	n.tete = debut
	n.dir = avant.normalized()
	n._vers_rayon = debut
	n.set_meta("largeur", largeur)
	n.demarrer(k)
	n._spirale_main(n.pos_main(0, debut - avant.normalized() * 0.5), 46, debut, 0.17, avant.normalized() * 24.0, 0.1)
	return n

func _maj_rayon(dt: float, cb: Basis) -> void:
	if phase == Phase.FIN:
		return
	var larg: float = get_meta("largeur", 1.0)
	var pr := LancerEcole.perp(dir)
	var vif := 1.0 - smoothstep(duree_geste * 0.55, duree_geste, t)
	# la bouche du cercle : fumée qui se déverse dans le faisceau, enroulée en hélice
	_acc += dt * 60.0
	var n := int(randf() * 3.0 + 2.0 * vif)
	for _q in n:
		var a := randf() * TAU
		var r := 0.2 * randf_range(0.3, 1.0) * larg
		var off: Vector3 = (pr[0] * cos(a) + pr[1] * sin(a)) * r
		var tang: Vector3 = (pr[1] * cos(a) - pr[0] * sin(a))
		semer({"pos": tete + off, "vel": dir * randf_range(14.0, 28.0) + tang * 1.5 + off * 3.0, "vie": randf_range(0.28, 0.5), "s0": 0.1 * larg, "s1": 0.26 * larg, "a": 0.75 * vif,
			"ton": randf() * 0.7, "freine": 1.5})
	if randf() < 0.7:
		var a2 := randf() * TAU
		semer({"pos": tete + (pr[0] * cos(a2) + pr[1] * sin(a2)) * 0.2 * larg, "vel": dir * randf_range(20.0, 34.0), "vie": 0.25, "sorte": 1, "long": randf_range(0.5, 1.1) * larg, "ton": 0.3 + 0.7 * randf(), "a": 0.9 * vif, "freine": 0.5})
	lumiere(Color(0.62, 0.25, 1.0), 2.5 * vif, 6.0)
