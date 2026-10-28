class_name FeuCorps
## Comportement « feu sur le corps » du socle ImpactCorps (docs/MAGIE_IMPACT_CORPS.md) — référence :
## references/magie/feu_fps_1100.jpg. Le jet ne s'arrête pas sur un plan devant l'ennemi : au contact il se DÉVIE autour du
## corps (mode contour : langues nées sur le bord de la silhouette qui filent dans le sens du jet), le corps PREND FEU
## (langues de surface côté impact, qui montent), le point touché est un petit cœur blanc-jaune qui s'étale sur la
## surface (éclaboussure tangente), des escarbilles fines s'échappent par les bords, des flammes lèchent le sol aux pieds ;
## le voile éclaire le corps de l'intérieur (braises, contours rougeoyants) puis le carbonise légèrement.
## Après l'arrêt du jet : brûlure (statut existant) = petites flammes sur 3 foyers accrochés à des os, braises, fumée
## légère ; puis les braises s'éteignent et la carbonisation s'estompe.

const FEU6 := ["#fffbe8", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f", "#5a1a1c"]

## Un réglage par émetteur du foyer (ordre = index de l'émetteur). Valeurs « rétro » (640x360) ; "fin" = couche fine.
const REGLAGES := [
	# 0 langues de surface : côté impact, montent en collant au corps (flottabilité), penchées dans le souffle du jet
	{"mode": "langues", "n": 130, "vie": 0.5, "vitesse": Vector2(0.6, 1.5), "gravite": Vector3(0, 2.6, 0), "amorti": Vector2(1.2, 2.2),
		"ouvert": 0.14, "ecarte": 0.02, "turb": 3.5, "suit_jet": 0.45, "taille": Vector2(0.05, 0.1), "courbe": 2, "alea": 0.35,
		"chaud": 0.4, "rampe": FEU6, "cap": 8.0, "eclat": 1.5,
		"fin": {"n": 420, "taille": Vector2(0.016, 0.034), "cap": 12.0, "etire": 4.5, "eclat": 1.55}},
	# 1 contour : le flux contourne la silhouette et en ressort sur les côtés, dans le sens du jet
	{"mode": "contour", "n": 100, "vie": 0.34, "vitesse": Vector2(2.4, 4.2), "gravite": Vector3(0, 1.6, 0), "amorti": Vector2(2.0, 3.0),
		"ouvert": 0.1, "ecarte": 0.03, "turb": 2.0, "taille": Vector2(0.06, 0.11), "courbe": 2, "alea": 0.3, "chaud": 0.5,
		"rampe": ["#fff0a8", "#fcb53a", "#ec6a1f", "#ec6a1f", "#b3341f", "#5a1a1c"], "cap": 9.0, "eclat": 1.45,
		"fin": {"n": 300, "taille": Vector2(0.016, 0.034), "cap": 12.0, "etire": 5.0, "eclat": 1.5}},
	# 2 éclaboussure : cœur blanc-jaune qui s'étale sur la surface autour du point touché
	{"mode": "eclabousse", "add": true, "n": 40, "vie": 0.2, "vitesse": Vector2(1.2, 2.6), "gravite": Vector3(0, 0.8, 0), "amorti": Vector2(5.0, 8.0),
		"ouvert": 0.15, "ecarte": 0.02, "taille": Vector2(0.04, 0.08), "courbe": 1, "alea": 0.3, "chaud": 0.0,
		"rampe": ["#ffffff", "#fffbe8", "#fff0a8", "#fcb53a"], "cap": 7.0, "eclat": 1.8,
		"fin": {"n": 120, "taille": Vector2(0.014, 0.028), "cap": 10.0, "etire": 3.0, "eclat": 2.0}},
	# 3 escarbilles : fines, s'échappent par les bords
	{"mode": "escarbilles", "add": true, "n": 30, "vie": 0.9, "vitesse": Vector2(1.0, 3.0), "gravite": Vector3(0, 0.5, 0), "amorti": Vector2(0.8, 1.5),
		"ouvert": 0.45, "turb": 6.0, "suit_jet": 0.6, "taille": Vector2(0.012, 0.022), "courbe": 0, "alea": 0.4, "chaud": 0.0,
		"rampe": ["#ffffff", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"], "cap": 3.0, "eclat": 2.0,
		"fin": {"n": 80, "taille": Vector2(0.006, 0.011), "cap": 3.0, "etire": 4.0}},
	# 4 fumée légère au-dessus des foyers
	{"mode": "fumee", "n": 16, "vie": 1.3, "vitesse": Vector2(0.3, 0.7), "gravite": Vector3(0, 0.9, 0), "amorti": Vector2(0.8, 1.4),
		"ouvert": 0.3, "turb": 2.0, "taille": Vector2(0.12, 0.22), "courbe": 3, "alea": 0.3, "chaud": 0.0,
		"rampe": ["#00000000", "#2c2424a0", "#1d191980", "#0f0b0840"], "cap": 12.0, "eclat": 1.0,
		"fin": {"n": 40, "taille": Vector2(0.08, 0.16), "cap": 16.0}},
	# 5 sol : flammes qui lèchent le sol aux pieds
	{"mode": "sol", "n": 36, "vie": 0.5, "vitesse": Vector2(0.4, 1.2), "gravite": Vector3(0, 2.4, 0), "amorti": Vector2(1.5, 2.5),
		"ouvert": 0.15, "turb": 3.0, "suit_jet": 0.4, "taille": Vector2(0.06, 0.12), "courbe": 2, "alea": 0.3, "chaud": 0.5,
		"rampe": FEU6, "cap": 8.0, "eclat": 1.45,
		"fin": {"n": 100, "taille": Vector2(0.016, 0.034), "cap": 12.0, "etire": 4.0}},
]

## Parts actives (amount_ratio) sous le jet / pendant la brûlure.
const SOUS_JET := [1.0, 1.0, 1.0, 1.0, 0.25, 1.0]
const BRULURE := [0.42, 0.0, 0.0, 0.45, 1.0, 0.18]
const MONTEE := 0.15            # s : le corps prend feu
const RETOMBEE := 0.12          # s : fin du jet → brûlure
const FOYERS_BRULURE := 3
const CARBO_MAX := 0.55
const CARBO_TENUE := 3.0        # s : la carbonisation reste après l'extinction…
const CARBO_FONDU := 4.0        # … puis s'estompe

static func debut(_ic: ImpactCorps, f: ImpactCorps.Foyer) -> void:
	f.d = {"k_jet": 0.0, "vu": -INF, "jets": {}, "dir": Vector3.FORWARD, "imp": Vector3(0, 1.1, 0), "imp_i": -1,
		"rayon": 0.45, "dbl": false, "brule_fin": -INF, "k_brule": 0.0, "foyers": PackedInt32Array(), "carbo": 0.0,
		"chaleur": 0.0, "eteint": -INF}

## Le jet (une main) touche le corps cette image.
static func jet(ic: ImpactCorps, f: ImpactCorps.Foyer, info: Dictionary) -> void:
	var d := f.d
	var jets: Dictionary = d.jets
	jets[info.id] = {"o": info.o, "dir": info.dir, "rayon": info.rayon, "dbl": info.dbl, "vu": ic.gm.horloge}
	d.vu = ic.gm.horloge

static func statut(ic: ImpactCorps, f: ImpactCorps.Foyer, _nom: String, duree: float) -> bool:
	var d := f.d
	if duree <= 0.0:
		d.brule_fin = ic.gm.horloge
		return true
	d.brule_fin = maxf(float(d.brule_fin), ic.gm.horloge + duree)
	return true

static func embraser(ic: ImpactCorps, f: ImpactCorps.Foyer, point: Vector3, direction: Vector3, force: float, duree: float) -> void:
	var d := f.d
	var o := f.origine()
	f.surface.actualiser(o)
	d.dir = direction.normalized() if direction.length() > 0.001 else Vector3.FORWARD
	var i := f.surface.point_vise(point - o - d.dir * 1.5, d.dir)
	d.imp = f.surface.pos[i] if i >= 0 else point - o
	d.imp_i = i
	d.chaleur = maxf(float(d.chaleur), clampf(0.6 * force, 0.3, 1.0))
	d.carbo = minf(float(d.carbo) + 0.15 * force, CARBO_MAX)
	statut(ic, f, "brulure", duree)

static func _choisir_foyers(ic: ImpactCorps, f: ImpactCorps.Foyer) -> void:
	var d := f.d
	f.surface.actualiser(f.origine())
	var p: Vector3 = f.surface.pos[d.imp_i] if int(d.imp_i) >= 0 and int(d.imp_i) < f.surface.nb else d.imp
	d.foyers = f.surface.foyers_pres_de(p, FOYERS_BRULURE, ic.rng)

static func maj(ic: ImpactCorps, f: ImpactCorps.Foyer, dt: float) -> bool:
	var d := f.d
	var h := ic.gm.horloge
	var s := f.surface
	# jets de l'image (deux mains en double incantation) : direction et rayon moyens, impact sur la surface
	var jets: Dictionary = d.jets
	var n_jets := 0
	var dir := Vector3.ZERO
	var o := Vector3.ZERO
	var rayon := 0.0
	var dbl := false
	for k in jets.keys():
		var jj: Dictionary = jets[k]
		if h - float(jj.vu) > RETOMBEE:
			jets.erase(k)
			continue
		n_jets += 1
		dir += jj.dir
		o += jj.o
		rayon = maxf(rayon, float(jj.rayon))
		dbl = dbl or bool(jj.dbl)
	var sous_jet := n_jets > 0
	var org := f.origine()
	if sous_jet:
		dir = dir.normalized()
		o /= n_jets
		d.dir = dir
		d.rayon = rayon * (1.15 if n_jets > 1 else 1.0)
		d.dbl = dbl or n_jets > 1
		var i := s.point_vise(o - org, dir)
		if i >= 0:
			d.imp = d.imp.lerp(s.pos[i], 1.0 - exp(-dt * 25.0)) if float(d.k_jet) > 0.05 else s.pos[i]
			d.imp_i = i
		d.k_jet = minf(float(d.k_jet) + dt / MONTEE, 1.0)
		d.chaleur = minf(float(d.chaleur) + dt / MONTEE, 1.2 if d.dbl else 1.0)
		d.carbo = minf(float(d.carbo) + dt * 0.25, CARBO_MAX)
		d.eteint = -INF
		d.foyers = PackedInt32Array()   # choisis à la fin du jet, autour du dernier point touché
	else:
		d.k_jet = maxf(float(d.k_jet) - dt / RETOMBEE, 0.0)
		# l'impact suit le point de surface (le corps bouge, tombe)
		if int(d.imp_i) >= 0 and int(d.imp_i) < s.nb:
			d.imp = s.pos[d.imp_i]
	var brule := h < float(d.brule_fin)
	if brule and (d.foyers as PackedInt32Array).is_empty() and float(d.k_jet) < 0.5:
		_choisir_foyers(ic, f)
	d.k_brule = clampf(float(d.k_brule) + (dt / 0.3 if brule else -dt / 0.6), 0.0, 1.0)
	var kj := float(d.k_jet)
	var kb := float(d.k_brule) * (1.0 - kj)
	# chaleur du voile : 1 sous le jet, ~0,4 pendant la brûlure, puis les braises s'éteignent (1,5 s)
	var ch_cible := 0.0
	if kj > 0.0:
		ch_cible = 1.0 * (1.2 if d.dbl else 1.0)
	elif brule:
		ch_cible = 0.4 + 0.08 * sin(h * 13.0) * sin(h * 5.0)
	var ch := float(d.chaleur)
	ch = move_toward(ch, ch_cible, dt * (6.0 if ch_cible > ch else 0.65))
	d.chaleur = ch
	if brule and kj <= 0.0:
		d.carbo = minf(float(d.carbo) + dt * 0.04, CARBO_MAX)
	if not sous_jet and not brule and ch <= 0.01:
		if d.eteint == -INF:
			d.eteint = h
		var t := h - float(d.eteint)
		if t > CARBO_TENUE:
			d.carbo = maxf(float(d.carbo) - dt * CARBO_MAX / CARBO_FONDU, 0.0)
	# uniformes du foyer (jet + foyers de brûlure)
	ic.uniformes(f, "dir_jet", d.dir)
	ic.uniformes(f, "point_impact", d.imp)
	ic.uniformes(f, "rayon_jet", float(d.rayon))
	ic.uniformes(f, "k_jet", kj)
	ic.uniformes(f, "k_foyers", kb)
	ic.uniformes(f, "sol_y", minf(s.bas, 0.0) + 0.02)
	var fo: Array = []
	var ids: PackedInt32Array = d.foyers
	for k in 4:
		if k < ids.size() and ids[k] < s.nb and kb > 0.0:
			fo.append(Vector4(s.pos[ids[k]].x, s.pos[ids[k]].y, s.pos[ids[k]].z, 0.12 + 0.03 * k))
		else:
			fo.append(Vector4.ZERO)
	ic.uniformes(f, "foyers", fo)
	# parts actives des émetteurs
	for k in f.em.size():
		var r := maxf(SOUS_JET[k] * kj, BRULURE[k] * kb)
		if k == 0 and d.dbl:
			r = minf(r * 1.15, 1.0)
		ic.activer(f.em[k], r)
	# voile : chaleur au point touché, direction, carbonisation
	var imp_monde: Vector3 = org + d.imp
	ic.voile(f, "mc_feu", Vector4(imp_monde.x, imp_monde.y, imp_monde.z, ch))
	ic.voile(f, "mc_dir", Vector4(d.dir.x, d.dir.y, d.dir.z, float(d.carbo)))
	ic.voile(f, "mc_autre", Vector4(0.0, 0.0, 0.0, kj))
	ic.repousser(f, kj)
	# le corps éclaire le décor pendant la brûlure (sous le jet, la lumière du jet est déjà au contact)
	if kb > 0.05:
		var sc := 0.85 + 0.25 * sin(h * 19.0 + f.id) * sin(h * 6.3)
		ic.gm.lumiere("corps%d" % f.id, org + s.centre + Vector3.UP * 0.2, GestionMagie.LUMIERE.feu, 1.6 * kb * sc, 3.2, 1.0)
	if not (d.foyers as PackedInt32Array).is_empty() and not brule and kb <= 0.0:
		d.foyers = PackedInt32Array()
	# fini : plus de jet, plus de brûlure, braises éteintes, carbonisation estompée
	return sous_jet or brule or kj > 0.0 or kb > 0.0 or ch > 0.01 or float(d.carbo) > 0.005
