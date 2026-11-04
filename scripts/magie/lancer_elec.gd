class_name LancerElec
extends LancerEcole
## LANCER D'ÉLECTRICITÉ (orbe d'arcs, arc, chaîne, orage runique) : les ARCS de la main (mêmes traits que les éclairs de Force,
## GestionMagie.eclair / foudre_ramifiee, mêmes tons violets, mêmes runes) se TENDENT vers la cible et deviennent le sort
## sans coupure :
##   naissance : les arcs qui crépitaient autour de la paume s'allongent d'un coup vers la tête (arcs épais main → tête) pendant que la
##               boule de plasma se resserre en tête ;
##   vol       : orbe d'arcs ramifiés (cœur de plasma violet + runes en orbite) tirant une CHAÎNE d'arcs entre ses positions
##               passées (la traînée est un éclair vivant qui s'éteint de la queue vers la tête) ;
##   fin       : la tête se défait en éclats d'arcs ; `reformer(main)` : les arcs refluent dans la main.
## Sorts sans projectile : `tension(main, vers, k, duree)` : arcs épais qui partent de la paume et rejoignent la cible en 0,12 s,
## puis s'effacent pendant que l'arc / la chaîne / l'orage de GestionMagie prend le relais (aucune coupure).
## Double : deux arcs (un par main) convergent sur le point de fusion et se rejoignent en UN seul arc, plus épais.

const PAL_PLASMA := ["#2a1a6a", "#4a3ad0", "#9aa8ff", "#f0f2ff"]
const SH_NOYAU := preload("res://shaders/magie_noyau_ecole.gdshader")
const PAL_NOYAU := ["#ffffff", "#f0f2ff", "#b4c0ff", "#7a7af0", "#4a3ad0", "#2a1a6a"]
const NB_ADD := 60
const PAS_HIST := 0.6        # m entre deux points de la chaîne d'arcs
const NB_HIST := 6

var _quad: MeshInstance3D
var _arc: Dictionary = {}
var _hist: Array[Vector3] = []
var _tension := false
var _vers := Vector3.ZERO
var _duree := 0.5
var _rep := false
var _alpha_fin := 1.0

func _construire() -> void:
	_add = nuage(NB_ADD, mat_bouffee(1, PAL_PLASMA, 0.6, 1.2))
	if not _tension and not _rep:
		_quad = _carre()
		runes_tete(2.8 * (1.3 if double else 1.0))
	var g := GestionMagie.obtenir()
	if g != null:
		_arc = g.eclair(self, "electricite", 2.0, -1.0, 0.04, _gen)

func _exit_tree() -> void:
	super._exit_tree()
	var g := GestionMagie.instance
	if g != null and is_instance_valid(g):
		g.eclair_fin(_arc)

## Carré procédural de la boule d'arcs (même shader que le repos : magie_noyau_ecole, école 2).
func _carre() -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = SH_NOYAU
	mat.set_shader_parameter("ecole", 2)
	for k in 6:
		mat.set_shader_parameter("c%d" % k, Color(PAL_NOYAU[k]))
	mat.set_shader_parameter("eclat", 1.1)
	var qd := QuadMesh.new()
	qd.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = qd
	mi.material_override = mat
	mi.layers = CoucheMagie.CALQUE
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	mi.set_instance_shader_parameter("rayon", 0.27)
	mi.set_instance_shader_parameter("graine", _graine)
	mi.set_instance_shader_parameter("avance", 0.0)
	add_child(mi)
	return mi

# ---------------------------------------------------------------- arcs (générateur appelé par GestionMagie toutes les 0,04 s)

func _gen() -> Array:
	var g := GestionMagie.obtenir()
	var traits: Array = []
	if g == null:
		return traits
	var o := global_position
	if _rep:
		return _gen_reforme(g, traits, o)
	if _tension:
		return _gen_tension(g, traits, o)
	var s := naiss() if phase != Phase.FIN else 1.0
	var ech := intensite_k() * (1.0 if forme != "orbe" else 0.85) * (1.35 if double else 1.0)
	var vif := _alpha_fin
	if phase != Phase.FIN:
		# arcs de la tête : ramifiés, ils crépitent autour du cœur (plus longs vers l'arrière : ils tirent la chaîne)
		var n := 5 + (2 if double else 0)
		for _k in n:
			var a := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * 0.02
			var d := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			var b := d * randf_range(0.12, 0.26) * ech - dir * 0.05 * ech
			var p := g.foudre(a, b, 0.05 * ech, 3)
			traits.append([p, randf_range(0.7, 1.2), vif])
			if p.size() > 6 and randf() < 0.6:
				var i := randi_range(p.size() / 4, p.size() - 3)
				var fin := p[i] + (d * 0.5 + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()).normalized() * randf_range(0.04, 0.09) * ech
				traits.append([g.foudre(p[i], fin, 0.025 * ech, 2), 0.5, 0.6 * vif])
		# naissance : arcs ÉPAIS de la paume à la tête (le crépitement du repos se tend et part)
		var vn := 1.0 - smoothstep(DUREE_NAISSANCE * 0.5, DUREE_NAISSANCE * 1.5, t)
		if vn > 0.02:
			for i in maxi(mains.size(), 1):
				var src := pos_main(i, origine) - o
				if src.length() > 0.12:
					for _q in 2:
						g.foudre_ramifiee(traits, src + Vector3.UP * 0.05, Vector3.ZERO, src.length() * 0.12, 2.0, 1, 4)
					for q in traits.size():
						if q >= traits.size() - 4:
							traits[q][2] = float(traits[q][2]) * vn
	# chaîne d'arcs entre les positions passées : s'éteint de la queue vers la tête
	var nh := _hist.size()
	for i in range(nh - 1):
		var a2 := _hist[i] - o
		var b2 := _hist[i + 1] - o
		var f := 1.0 - float(i) / float(maxi(nh - 1, 1))
		var av := traits.size()
		g.foudre_ramifiee(traits, a2, b2, a2.distance_to(b2) * 0.14, 1.2, 1, 3)
		for q in range(av, traits.size()):
			traits[q][2] = float(traits[q][2]) * f * vif
	return traits

func _gen_tension(g: GestionMagie, traits: Array, o: Vector3) -> Array:
	var src := pos_main(0, o)
	var fade := 1.0 - smoothstep(_duree * 0.55, _duree, t)
	var avance := clampf(t / 0.12, 0.0, 1.0)
	if mains.size() > 1:
		# DOUBLE (point de fusion commun, comme le feu) : les arcs des deux sources se rejoignent d'abord au point de fusion
		# (0,06 s), puis UN seul arc, plus épais, part de ce point vers la cible
		var src2 := pos_main(1, o)
		var pf := (src + src2) * 0.5 + Vector3.UP * 0.05
		var conv := clampf(t / 0.06, 0.0, 1.0)
		for sx: Vector3 in [src, src2]:
			if sx.distance_to(pf) > 0.03:
				var av0 := traits.size()
				g.foudre_ramifiee(traits, sx - o, sx.lerp(pf, conv) - o, sx.distance_to(pf) * 0.18 + 0.01, 1.6, 1, 3)
				for q in range(av0, traits.size()):
					traits[q][2] = float(traits[q][2]) * fade
		src = pf
		avance = clampf((t - 0.04) / 0.12, 0.0, 1.0)
		if avance <= 0.0:
			return traits
	var l := src.distance_to(_vers)
	if l < 0.05:
		return traits
	var d := (_vers - src) / l
	# le bout avance de la source vers la cible en 0,12 s ; l'arc reste tendu, puis s'efface
	var front := src + d * l * avance
	var n := 3 + (1 if double else 0)   # double : un seul faisceau plus épais (pas une pelote blanche au point de fusion)
	for i in n:
		var av := traits.size()
		var dec := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * (0.045 if double else 0.03)
		g.foudre_ramifiee(traits, src + dec - o, front - o, l * avance * 0.07 + 0.03, (2.4 if double else 2.0) if i == 0 else 1.2, 2, 4)
		for q in range(av, traits.size()):
			traits[q][2] = float(traits[q][2]) * fade
	return traits

func _gen_reforme(g: GestionMagie, traits: Array, o: Vector3) -> Array:
	var p := clampf(t / 0.32, 0.0, 1.0)
	var r := lerpf(0.34, 0.02, p * p)
	var fade := 1.0 - smoothstep(0.7, 1.0, p)
	for _k in 6:
		var d := Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)).normalized()
		var a := d * r
		var b := d * r * 0.35
		var tr := g.foudre(a, b, r * 0.18, 3)
		traits.append([tr, 1.0, fade])
	if p > 0.85:
		for _k in 3:
			traits.append([g.foudre(Vector3.ZERO, Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * 0.1, 0.03, 3), 1.0, 0.8])
	return traits

# ---------------------------------------------------------------- vie

func _naissance() -> void:
	if _tension or _rep:
		return
	var p0 := pos_main(0, origine)
	# étincelles de la paume qui partent avec l'arc
	for k in 16:
		semer({"pos": p0 + Vector3(h(k * 3) - 0.5, h(k * 5) - 0.2, h(k * 7) - 0.5) * 0.18, "vie": 0.4, "sorte": 3, "s0": 0.014, "s1": 0.006, "a": 1.0, "ton": 0.6 + 0.4 * h(k),
			"suit": DUREE_NAISSANCE * 0.8, "vel2": dir * 3.0, "delai": h(k * 11) * 0.08})

func _maj(dt: float, cb: Basis) -> void:
	if _rep or _tension:
		if _tension:
			tete = pos_main(0, tete)
		var fin_t := 0.34 if _rep else _duree
		if t > fin_t:
			queue_free()
			return
		if _tension:
			lumiere(Color(0.55, 0.5, 1.0), 2.4 * (1.0 - smoothstep(0.0, _duree, t)), 5.0)
		puffs(dt, cb)
		return
	var s := naiss() if phase != Phase.FIN else 1.0
	var ech := intensite_k() * (0.85 if forme == "orbe" else 1.0) * (1.35 if double else 1.0)
	_alpha_fin = 1.0 - smoothstep(0.0, duree_fin * 0.55, t_fin) if phase == Phase.FIN else 1.0
	if phase != Phase.FIN:
		# historique de la chaîne (positions espacées de PAS_HIST, la plus récente en tête)
		if _hist.is_empty() or _hist[0].distance_to(tete) >= PAS_HIST:
			_hist.push_front(tete)
			if _hist.size() > NB_HIST:
				_hist.pop_back()
		var rq := 0.27 * ech * (0.55 + 0.45 * s)
		_quad.global_position = tete
		_quad.set_instance_shader_parameter("rayon", rq * (1.0 - 0.15 * float(phase == Phase.NAISSANCE)))
		_quad.set_instance_shader_parameter("force", 0.95 + 0.1 * sin(t * 30.0))
		_quad.set_instance_shader_parameter("charge", 0.3)
		_quad.visible = true
		# masse de plasma : bouffées violettes qui flottent autour du cœur
		for _q in 2:
			var a := randf() * TAU
			semer({"pos": tete + Vector3(cos(a), randf_range(-1, 1), sin(a)) * 0.07 * ech, "vie": 0.1, "sorte": 2, "s0": randf_range(0.05, 0.1) * ech, "s1": randf_range(0.05, 0.1) * ech, "a": 0.16})
		# étincelles semées le long du trajet
		var semis := func(pos: Vector3) -> void:
			if randf() < 0.5:
				var d := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
				semer({"pos": pos + d * 0.05, "vel": d * 1.8 - dir * 0.8, "vie": randf_range(0.2, 0.45), "sorte": 3, "s0": 0.016, "s1": 0.005, "a": 1.0, "ton": randf(), "freine": 2.0})
		le_long(semis, 0.14)
		lumiere(Color(0.55, 0.5, 1.0), 3.0 * ech, 6.0)
	else:
		_quad.visible = false
		if not _hist.is_empty():
			_hist.pop_back()
	puffs(dt, cb)
	if _runes != null and is_instance_valid(_runes):
		_runes.visible = phase != Phase.FIN
		_runes.echelle = 2.8 * (1.3 if double else 1.0)

func _fin() -> void:
	# la tête se défait en éclats d'arcs
	for k in 14:
		var d := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		semer({"pos": tete, "vel": d * randf_range(1.0, 3.0), "vie": 0.4, "sorte": 3, "s0": 0.018, "s1": 0.006, "a": 1.0, "ton": randf(), "freine": 2.0})
	semer({"pos": tete, "vie": 0.2, "sorte": 2, "s0": 0.12, "s1": 0.3, "a": 0.6})

# ---------------------------------------------------------------- sorts sans projectile, fin

## Arcs épais de la paume à `vers` (le bout y arrive en 0,12 s), qui s'effacent en `duree` s : à lancer juste avant (ou avec) le
## sort d'arc / chaîne / orage. `main` : la paume ; plusieurs mains (double) : passer `mains2`.
static func tension(main: Node3D, vers: Vector3, k := 1.0, duree := 0.5, main2: Node3D = null, depart_pos := Vector3.INF) -> LancerElec:
	if (main == null or not is_instance_valid(main)) and depart_pos == Vector3.INF:
		return null
	var n := LancerElec.new()
	n.ecole = "electricite"
	n._tension = true
	n._vers = vers
	n._duree = duree
	n.fixe = true
	n.duree_geste = duree + 0.1
	if main != null and is_instance_valid(main):
		n.mains = [main]
		# double magie posée par MainSort : meneuse puis suiveuse, sources au point de fusion commun
		var dbl := LancerEcole.double_transition("electricite", main.global_position)
		if not dbl.is_empty():
			n._poser_double(dbl.meneuse, dbl.suiveuse, dbl.point)
			main2 = null
	elif depart_pos != Vector3.INF:
		var dbl2 := LancerEcole.double_transition("electricite", depart_pos, 0.6)
		if not dbl2.is_empty():
			n._poser_double(dbl2.meneuse, dbl2.suiveuse, dbl2.point)
	if main2 != null and is_instance_valid(main2):
		n.mains.append(main2)
		n.double = true
	n.name = "TensionElec"
	LancerEcole._scene().add_child(n)
	var p0 := main.global_position if main != null and is_instance_valid(main) else depart_pos
	n.global_position = p0
	n.tete = p0
	n.intensite = k
	n.phase = Phase.VOL
	n._debut_fait = true
	n.origine = n.tete
	return n

## Les arcs refluent dans la main (retour au repos).
static func reformer(main: Node3D, centre := Vector3.INF) -> LancerElec:
	if main == null or not is_instance_valid(main):
		return null
	var n := LancerElec.new()
	n.ecole = "electricite"
	n._rep = true
	n.mains = [main]
	n.name = "ReformeElec"
	LancerEcole._scene().add_child(n)
	var c := centre if centre != Vector3.INF else main.global_position + Vector3.UP * 0.12
	n.global_position = c
	n.tete = c
	n.phase = Phase.VOL
	n._debut_fait = true
	n.fixe = true
	return n
