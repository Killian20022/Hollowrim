class_name ElecCorps
## Comportement « électricité sur le corps » du socle ImpactCorps (docs/MAGIE_IMPACT_CORPS.md, agent B) — référence :
## references/magie/electricite_fps_1100.jpg et Sparks de Skyrim. Pas de nuage bleu posé devant l'ennemi :
##   - le FAISCEAU de l'arc électrique finit SUR la surface du corps et s'y divise : 2-3 fourches vont saisir d'autres points
##     du corps autour de l'impact (le générateur du jet est remplacé tant que ce corps est visé) ;
##   - des ARCS RAMPENT sur la surface (chaînes de points voisins de SurfaceCorps, zigzag, brindilles), SAUTENT entre deux
##     os (bras ↔ torse, bouclier ↔ bras) et descendent au SOL ; ils sont accrochés aux points du corps à chaque image
##     (shaders/magie_corps_arcs.gdshader) et changent de forme ~20 fois par seconde ;
##   - le voile fait crépiter le CONTOUR et courir des veines bleues ; étincelles tangentes au point touché, crépitements aux
##     points où les arcs touchent, étincelles au sol ;
##   - statut « choc » (titube) : le corps reste parcouru de petites décharges (moins d'arcs, papillotants) ;
##   - après : TRACES DE CHOC (figures sombres autour du point touché, petite fumée, arcs de plus en plus rares) qui
##     s'estompent en 3,5 s.
## Impact ponctuel (chaîne d'éclairs, rebonds) : salve d'arcs 0,35 s depuis le point touché, puis le statut.

const ELEC := ["#ffffff", "#f0f2ff", "#b4c0ff", "#7a7af0", "#4a3ad0"]
## Pas de coque (COQUE = -1) : le contour qui crépite est fait par le voile (la coque école 2 de
## magie_corps_coque_ecoles reste disponible : 12 copies skinnées de plus par corps pour un gain faible, écartée pour la perf).
const COQUE := -1
## Arcs : couleurs du référentiel (halo violet-bleu, cœur blanc bleuté), largeurs en pixels (halo, cœur).
const ARCS := {"halo": "#4a3ad0", "coeur": "#f0f2ff", "halo_px": 3.0, "coeur_px": 1.0, "eclat": 1.7, "ampl": 0.24}

const REGLAGES := [
	# 0 étincelles TANGENTES au point touché (elles giclent le long de la surface puis tombent)
	{"mode": "eclabousse", "add": true, "n": 30, "vie": 0.24, "vitesse": Vector2(2.0, 5.0), "gravite": Vector3(0, -9.0, 0), "amorti": Vector2(1.0, 2.0),
		"ouvert": 0.3, "ecarte": 0.03, "taille": Vector2(0.012, 0.02), "courbe": 1, "alea": 0.4, "chaud": 0.6, "rampe": ELEC, "cap": 3.0, "eclat": 1.7,
		"fin": {"n": 60, "taille": Vector2(0.004, 0.008), "etire": 3.5}},
	# 1 crépitements aux points d'accroche des arcs (foyers = extrémités des arcs) et sur les bords
	{"mode": "escarbilles", "add": true, "n": 40, "vie": 0.18, "vitesse": Vector2(0.8, 2.6), "gravite": Vector3(0, -6.0, 0), "amorti": Vector2(1.0, 2.0),
		"ouvert": 0.6, "suit_jet": 0.2, "taille": Vector2(0.01, 0.018), "courbe": 1, "alea": 0.4, "chaud": 0.5, "rampe": ELEC, "cap": 3.0, "eclat": 1.8,
		"fin": {"n": 70, "taille": Vector2(0.004, 0.008), "etire": 3.0}},
	# 2 étincelles qui rebondissent au sol, sous les arcs qui descendent
	{"mode": "sol", "add": true, "n": 24, "vie": 0.32, "vitesse": Vector2(1.0, 3.0), "gravite": Vector3(0, -9.0, 0), "amorti": Vector2(0.8, 1.5),
		"ouvert": 0.5, "suit_jet": 0.2, "taille": Vector2(0.01, 0.018), "courbe": 1, "alea": 0.4, "chaud": 0.0, "rampe": ELEC, "cap": 3.0, "eclat": 2.0,
		"fin": {"n": 70, "taille": Vector2(0.004, 0.008), "etire": 3.0}},
	# 3 ions : fines lueurs qui flottent près de la surface électrisée
	{"mode": "langues", "add": true, "n": 20, "vie": 0.45, "vitesse": Vector2(0.05, 0.3), "gravite": Vector3(0, 0.4, 0), "amorti": Vector2(1.0, 2.0),
		"ouvert": 0.6, "ecarte": 0.04, "turb": 2.0, "suit_jet": 0.0, "taille": Vector2(0.008, 0.014), "courbe": 2, "alea": 0.4, "chaud": 0.0,
		"rampe": ["#f0f2ff", "#b4c0ff", "#7a7af0"], "cap": 3.0, "eclat": 1.8,
		"fin": {"n": 60, "taille": Vector2(0.004, 0.007)}},
	# 4 fumée légère des traces de choc (cuir et tissu roussis)
	{"mode": "fumee", "n": 10, "vie": 1.1, "vitesse": Vector2(0.2, 0.5), "gravite": Vector3(0, 0.7, 0), "amorti": Vector2(0.8, 1.4),
		"ouvert": 0.3, "turb": 1.5, "taille": Vector2(0.08, 0.15), "courbe": 3, "alea": 0.3, "chaud": 0.0,
		"rampe": ["#00000000", "#3a3a4a70", "#2a2a3650", "#1a1a2430"], "cap": 10.0, "eclat": 1.0,
		"fin": {"n": 24, "taille": Vector2(0.06, 0.12), "cap": 14.0}},
	{},
]

const SOUS_JET := [1.0, 1.0, 1.0, 1.0, 0.0, 0.0]
const CHOC := [0.0, 0.7, 0.0, 0.6, 0.0, 0.0]
const TRACES := [0.0, 0.0, 0.0, 0.0, 1.0, 0.0]
const RETOMBEE := 0.12
const TRACES_DUREE := 3.5       # s : les traces de choc s'estompent
const SALVE := 0.35             # s : salve d'arcs d'un impact ponctuel (chaîne d'éclairs)
const PAS_JET := 0.066          # s : nouvelle forme des arcs sous le jet (15 fois par seconde : l'éclair papillote)
const PAS_CHOC := 0.1           # s : … sous le statut choc

static func debut(_ic: ImpactCorps, f: ImpactCorps.Foyer) -> void:
	f.d = {"jets": {}, "vu": -INF, "dir": Vector3.FORWARD, "imp_i": -1, "k_jet": 0.0, "choc_fin": -INF, "k_choc": 0.0,
		"salve_fin": -INF, "k_salve": 0.0, "traces": 0.0, "t_forme": -INF, "ancres": PackedInt32Array(), "dbl": false,
		"graine": randf() * 100.0, "eteint": -INF}

static func jet(ic: ImpactCorps, f: ImpactCorps.Foyer, info: Dictionary) -> void:
	var d := f.d
	var jets: Dictionary = d.jets
	jets[info.id] = {"o": info.o, "dir": info.dir, "dbl": info.dbl, "vu": ic.gm.horloge}
	d.vu = ic.gm.horloge
	var j: Variant = info.get("j")
	if j is Dictionary:
		_brancher_faisceau(ic, f, j)

## Le faisceau du jet (GestionMagie._gen_jet_arc) finit sur la surface et s'y divise : son générateur est remplacé tant que
## ce foyer suit la cible du jet (sinon celui d'origine reprend la main).
static func _brancher_faisceau(ic: ImpactCorps, f: ImpactCorps.Foyer, j: Dictionary) -> void:
	var s := f.surface
	var o := f.origine()
	s.actualiser(o, false)   # (perf) normales : celles de l'image d'avant, ImpactCorps les refait
	var i: int = f.d.imp_i
	if i >= 0 and i < s.nb:
		j.fin_pos = o + s.pos[i] + s.nor[i] * 0.04
	var e: Variant = j.get("eclair")
	if not (e is Dictionary) or (e as Dictionary).is_empty():
		return
	if not j.has("_gen0"):
		j["_gen0"] = e.gen
	if not j.has("_gen_corps"):
		j["_gen_corps"] = _gen_faisceau.bind(ic, j)
	e.gen = j._gen_corps

static func _gen_faisceau(ic: ImpactCorps, j: Dictionary) -> Array:
	var gm := ic.gm
	var f: ImpactCorps.Foyer = ic.trouver(j.cible, "electricite") if gm.valide(j.cible) else null
	if f == null or not gm.valide(j.origine) or f.surface == null:
		return (j._gen0 as Callable).call()
	var traits: Array = []
	var s := f.surface
	var org := f.origine()
	var o: Vector3 = (j.origine as Node3D).global_position
	var b: Vector3 = j.fin_pos
	var l := o.distance_to(b)
	var dbl: bool = j.dbl
	# faisceau principal (zigzag) + brindilles COURTES le long du trajet (pas de grandes branches qui partent dans le vide)
	var p := gm.foudre(o, b, l * 0.08, 5)
	traits.append([p, 1.0, 1.0])
	for k in (4 if dbl else 3):
		var q := p[gm.rng.randi_range(1, maxi(1, p.size() - 2))]
		var dv := Vector3(gm.rng.randf_range(-1, 1), gm.rng.randf_range(-1, 1), gm.rng.randf_range(-1, 1)).normalized()
		traits.append([gm.foudre(q, q + ((b - o).normalized() + dv).normalized() * gm.rng.randf_range(0.08, 0.22), 0.03, 2), 0.5, 0.67])
	# fourches : le faisceau se divise près du corps et saisit d'autres points de sa surface autour de l'impact
	var imp: int = f.d.imp_i
	for k in (3 if dbl else 2):
		var i := _voisin(s, imp, 0.15, 0.5, Vector3.ZERO, gm.rng) if imp >= 0 else -1
		if i < 0:
			continue
		var c := org + s.pos[i] + s.nor[i] * 0.04
		var dep := o.lerp(b, gm.rng.randf_range(0.7, 0.9))
		traits.append([gm.foudre(dep, c, dep.distance_to(c) * 0.12, 3), 0.5, 0.67])
	return traits

static func statut(ic: ImpactCorps, f: ImpactCorps.Foyer, _nom: String, duree: float) -> bool:
	var d := f.d
	if duree <= 0.0:
		d.choc_fin = ic.gm.horloge
		return true
	d.choc_fin = maxf(float(d.choc_fin), ic.gm.horloge + duree)
	if int(d.imp_i) < 0 and f.surface != null:
		f.surface.actualiser(f.origine())
		d.imp_i = _point_au_hasard(f.surface, ic.rng, 0.8)
	return true

static func embraser(ic: ImpactCorps, f: ImpactCorps.Foyer, point: Vector3, direction: Vector3, force: float, duree: float) -> void:
	var d := f.d
	var o := f.origine()
	f.surface.actualiser(o)
	d.dir = direction.normalized() if direction.length() > 0.001 else Vector3.FORWARD
	var i := f.surface.point_vise(point - o - d.dir * 1.5, d.dir)
	d.imp_i = i if i >= 0 else _point_au_hasard(f.surface, ic.rng, 0.8)
	d.salve_fin = maxf(float(d.salve_fin), ic.gm.horloge + SALVE * clampf(force, 0.6, 1.6))
	d.t_forme = -INF
	d.traces = maxf(float(d.traces), 0.6)
	if duree > 0.0:
		statut(ic, f, "choc", duree)
	ic.gm.lumiere("corps%d" % f.id, o + f.surface.masse_centre - d.dir * 0.5, GestionMagie.LUMIERE.electricite, 5.0 * clampf(force, 0.6, 1.5), 4.5, 6.0, 0.25)

static func maj(ic: ImpactCorps, f: ImpactCorps.Foyer, dt: float) -> bool:
	var d := f.d
	var h := ic.gm.horloge
	var s := f.surface
	var org := f.origine()
	if ic.surface_changee(f):
		s.actualiser(org)
		d.imp_i = ImpactCorps.plus_proche(s, d.get("imp_p", s.centre)) if int(d.imp_i) >= 0 else -1
		d.ancres = PackedInt32Array()
		d.t_forme = -INF
	var jets: Dictionary = d.jets
	var n_jets := 0
	var dir := Vector3.ZERO
	var o := Vector3.ZERO
	var dbl := false
	for k in jets.keys():
		var jj: Dictionary = jets[k]
		if h - float(jj.vu) > RETOMBEE:
			jets.erase(k)
			continue
		n_jets += 1
		dir += jj.dir
		o += jj.o
		dbl = dbl or bool(jj.dbl)
	var sous_jet := n_jets > 0
	if sous_jet:
		dir = dir.normalized()
		o /= n_jets
		d.dir = dir
		d.dbl = dbl or n_jets > 1
		var i := ic.point_vise(f, o - org, dir)
		if i >= 0:
			d.imp_i = i
		d.k_jet = minf(float(d.k_jet) + dt / 0.08, 1.0)
		d.traces = minf(float(d.traces) + dt * 0.8, 1.0)
	else:
		d.k_jet = maxf(float(d.k_jet) - dt / RETOMBEE, 0.0)
	var salve := h < float(d.salve_fin)
	d.k_salve = clampf(float(d.k_salve) + (dt / 0.04 if salve else -dt / 0.12), 0.0, 1.0)
	var choc := h < float(d.choc_fin)
	d.k_choc = clampf(float(d.k_choc) + (dt / 0.06 if choc else -dt / 0.3), 0.0, 1.0)
	var kj := float(d.k_jet)
	var ks := float(d.k_salve)
	var kc := float(d.k_choc)
	var actif := maxf(maxf(kj, ks), kc)
	if actif > 0.02:
		d.eteint = -INF
	else:
		if d.eteint == -INF:
			d.eteint = h
		d.traces = maxf(float(d.traces) - dt / TRACES_DUREE, 0.0)
	var tr := float(d.traces)
	var reste := tr * (1.0 - actif)            # phase « traces » : plus rien de vif
	# ------------------------------------------------ forme des arcs (accrochés aux points : le shader les suit)
	var pas := PAS_JET if maxf(kj, ks) > 0.3 else PAS_CHOC
	var _p0 := Time.get_ticks_usec()
	if h - float(d.t_forme) >= pas:
		d.t_forme = h
		_former(ic, f, kj, ks, kc, reste)
	ImpactCorps.prof("elec former", _p0); _p0 = Time.get_ticks_usec()
	ic.arcs_regler(f)
	# ------------------------------------------------ émetteurs, paramètres du foyer (texture des points)
	# (2026-10-28, perf) deux appels directs (regler_jet / regler_foyers) au lieu de sept passages par uniformes()
	var imp := s.pos[int(d.imp_i)] if int(d.imp_i) >= 0 and int(d.imp_i) < s.nb else s.centre
	d.imp_p = imp
	ic.regler_jet(f, d.dir, maxf(kj, ks), imp, 0.3)
	var fo: Array = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	var anc: PackedInt32Array = d.ancres
	for k in mini(anc.size(), 4):
		if anc[k] < s.nb:
			var q := s.pos[anc[k]]
			fo[k] = Vector4(q.x, q.y, q.z, 0.09)
	ic.regler_foyers(f, maxf(kc, reste * 0.6), minf(s.bas, 0.0) + 0.02, fo)
	for k in f.em.size():
		var r := maxf(SOUS_JET[k] * maxf(kj, ks), maxf(CHOC[k] * kc, TRACES[k] * reste))
		ic.activer(f.em[k], r)
	# ------------------------------------------------ voile et coque : contour qui crépite, veines, traces
	# (le papillotement est fait par le shader : les canaux ne changent pas à chaque image → pas réécrits)
	ic.ecoles(f, 0.0, snappedf(clampf(maxf(maxf(kj, ks), kc * 0.75), 0.0, 1.0), 0.05), 0.0, snappedf(tr * (0.35 + 0.65 * (1.0 - actif)), 0.02), 0.0, org + imp, 0.0)
	ImpactCorps.prof("elec reste", _p0)
	# le corps éclaire le décor par à-coups pendant le choc (sous le jet, la lumière du jet est déjà au contact)
	# (2026-10-28, budget) une seule lumière par CORPS : sous la brûlure, celle du feu reste (pas une 2e omni par corps)
	if kc > 0.05 and kj < 0.5 and not ic.brule(f.cible):
		if ic.rng.randf() < 0.6:
			ic.gm.lumiere("corps%d" % f.cible.get_instance_id(), org + s.masse_centre, GestionMagie.LUMIERE.electricite, (0.8 + 1.6 * ic.rng.randf()) * kc, 3.5, 1.0)
	return sous_jet or choc or salve or actif > 0.0 or tr > 0.003

## Nouvelle forme des arcs du foyer : rampes depuis le point touché (jet, salve), sauts entre os, descentes au sol ; sous le
## seul statut choc, petites décharges au hasard qui papillotent ; pendant les traces, une décharge de temps en temps.
static func _former(ic: ImpactCorps, f: ImpactCorps.Foyer, kj: float, ks: float, kc: float, reste: float) -> void:
	var d := f.d
	var s := f.surface
	var rng := ic.rng
	var fin := ic.gm.fin_actif
	ic.arcs_debut(f)
	var anc := PackedInt32Array()
	var g := float(d.graine) + rng.randf() * 50.0
	var vif := maxf(kj, ks)
	var imp := int(d.imp_i)
	if s.nb > 8:
		if vif > 0.05 and imp >= 0:
			var dbl: bool = d.dbl
			var n_rampes := (4 if fin else 3) + (1 if dbl else 0)
			for k in n_rampes:
				# une part du point touché, les autres d'un point voisin (l'impact « s'étale » sans s'entasser au centre)
				var dep := imp if k == 0 else _voisin(s, imp, 0.14, 0.45, Vector3.ZERO, rng)
				if dep < 0:
					dep = imp
				var bout := _ramper(ic, f, dep, rng.randi_range(4, 7), g + k * 9.1, 1.0 if k < 2 else 0.7, 1.0 if k < 2 else 0.67)
				anc.append(bout)
			# sauts entre os (bras ↔ torse, bouclier ↔ bras) et descentes au sol
			for k in (3 if fin else 2):
				var a := _voisin(s, imp, 0.0, 0.6, Vector3.ZERO, rng)
				var b := _autre_os(s, a, 0.18, 0.62, rng) if a >= 0 else -1
				if b >= 0:
					ic.arc(f, a, b, 4, 4, g + 40.0 + k, 0.8, 0.85)
					anc.append(b)
			for k in (2 if fin else 1):
				var p := _point_bas(s, rng)
				if p >= 0:
					ic.arc(f, p, -1, 1, 4, g + 60.0 + k, 0.8, 0.85)
		elif kc > 0.05:
			# statut choc : petites décharges qui parcourent le corps et papillotent (une forme sur quatre est vide)
			if rng.randf() < 0.75:
				for k in (3 if fin else 2):
					var dep := _point_au_hasard(s, rng, 0.0)
					var bout := _ramper(ic, f, dep, rng.randi_range(2, 4), g + k * 7.3, 0.7, 0.67 if k > 0 else 1.0)
					anc.append(dep)
					anc.append(bout)
				if rng.randf() < 0.5:
					var a := _point_au_hasard(s, rng, 0.0)
					var b := _autre_os(s, a, 0.15, 0.5, rng)
					if b >= 0:
						ic.arc(f, a, b, 4, 3, g + 30.0, 0.7, 0.67)
				if rng.randf() < 0.3:
					var p := _point_bas(s, rng)
					if p >= 0:
						ic.arc(f, p, -1, 1, 3, g + 50.0, 0.6, 0.67)
		elif reste > 0.05 and rng.randf() < 0.18 * reste:
			# traces : une dernière petite décharge près du point touché, de plus en plus rare
			var dep := _voisin(s, imp, 0.0, 0.3, Vector3.ZERO, rng) if imp >= 0 else _point_au_hasard(s, rng, 0.0)
			if dep >= 0:
				anc.append(_ramper(ic, f, dep, rng.randi_range(1, 3), g, 0.6, 0.67))
	d.ancres = anc
	ic.arcs_fin(f)

## Arc qui rampe sur la surface : `sauts` liens entre points voisins (7 à 26 cm), en gardant à peu près sa direction ; une
## brindille de temps en temps. Renvoie le dernier point.
static func _ramper(ic: ImpactCorps, f: ImpactCorps.Foyer, depart: int, sauts: int, graine: float, largeur: float, alpha: float) -> int:
	var s := f.surface
	var cur := depart
	var dp := Vector3.ZERO
	for k in sauts:
		var nx := _voisin(s, cur, 0.07, 0.26, dp, ic.rng)
		if nx < 0:
			break
		if not ic.arc(f, cur, nx, 0, 2, graine + k * 1.37, largeur, alpha):
			break
		dp = s.pos[nx] - s.pos[cur]
		cur = nx
		if ic.rng.randf() < 0.28:
			ic.arc(f, cur, -1, 2, 2, graine + k * 3.1 + 0.5, largeur * 0.6, alpha * 0.67)
	return cur

## Point voisin de `i` entre dmin et dmax (tirages au hasard ; préfère la direction `dp`) ; -1 si aucun.
static func _voisin(s: SurfaceCorps, i: int, dmin: float, dmax: float, dp: Vector3, rng: RandomNumberGenerator) -> int:
	if i < 0 or i >= s.nb:
		return -1
	var pos := s.pos
	var p := pos[i]
	var meilleur := -1
	var score := INF
	var dn := dp.normalized() if dp.length() > 0.001 else Vector3.ZERO
	for k in 10:
		var j := rng.randi_range(0, s.nb - 1)
		if j == i:
			continue
		var v := pos[j] - p
		var l := v.length()
		if l < dmin or l > dmax:
			continue
		var sc := rng.randf() - (dn.dot(v / l) * 0.7 if dn != Vector3.ZERO else 0.0)
		if sc < score:
			score = sc
			meilleur = j
	return meilleur

## Point d'un AUTRE os que celui de `i`, entre dmin et dmax (saut d'arc entre deux membres) ; -1 si aucun.
static func _autre_os(s: SurfaceCorps, i: int, dmin: float, dmax: float, rng: RandomNumberGenerator) -> int:
	if i < 0 or i >= s.nb:
		return -1
	var od := s.os_de
	var pos := s.pos
	var os := od[i] if i < od.size() else -1
	for k in 14:
		var j := rng.randi_range(0, s.nb - 1)
		var oj := od[j] if j < od.size() else -1
		if oj == os:
			continue
		var l := pos[j].distance_to(pos[i])
		if l >= dmin and l <= dmax:
			return j
	return -1

static func _point_bas(s: SurfaceCorps, rng: RandomNumberGenerator) -> int:
	for k in 24:
		var j := rng.randi_range(0, s.nb - 1)
		if s.pos[j].y < s.bas + 0.3:
			return j
	return -1

## Point au hasard ; `haut` > 0 : plutôt dans le haut du corps (torse, tête).
static func _point_au_hasard(s: SurfaceCorps, rng: RandomNumberGenerator, haut: float) -> int:
	if s == null or s.nb <= 0:
		return -1
	var j := rng.randi_range(0, s.nb - 1)
	if haut > 0.0:
		for k in 8:
			if s.pos[j].y > lerpf(s.bas, s.haut, 0.45):
				break
			j = rng.randi_range(0, s.nb - 1)
	return j
