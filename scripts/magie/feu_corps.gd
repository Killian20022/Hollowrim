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
	# (2026-10-28, intensité) plus hautes et plus denses : vie 0,5 → 0,66 s, flottabilité 2,6 → 3,8, plus grosses
	{"mode": "langues", "n": 170, "vie": 0.66, "vitesse": Vector2(0.7, 1.7), "gravite": Vector3(0, 3.8, 0), "amorti": Vector2(1.2, 2.2),
		"ouvert": 0.12, "ecarte": 0.025, "turb": 3.5, "suit_jet": 0.4, "taille": Vector2(0.06, 0.12), "courbe": 2, "alea": 0.35,
		"chaud": 0.45, "rampe": FEU6, "cap": 9.0, "eclat": 1.55,
		"fin": {"n": 460, "taille": Vector2(0.022, 0.046), "cap": 13.0, "etire": 4.5, "eclat": 1.6}},
	# 1 contour : le flux contourne la silhouette et en ressort sur les côtés, dans le sens du jet
	{"mode": "contour", "n": 100, "vie": 0.38, "vitesse": Vector2(1.8, 3.2), "gravite": Vector3(0, 1.6, 0), "amorti": Vector2(2.0, 3.0),
		"ouvert": 0.12, "ecarte": 0.03, "turb": 4.0, "taille": Vector2(0.06, 0.11), "courbe": 2, "alea": 0.3, "chaud": 0.5,
		"rampe": ["#fff0a8", "#fcb53a", "#ec6a1f", "#ec6a1f", "#b3341f", "#5a1a1c"], "cap": 9.0, "eclat": 1.45,
		"fin": {"n": 260, "taille": Vector2(0.02, 0.042), "cap": 12.0, "etire": 2.5, "eclat": 1.5}},
	# 2 éclaboussure : cœur blanc-jaune qui s'étale sur la surface autour du point touché
	{"mode": "eclabousse", "add": true, "n": 56, "vie": 0.24, "vitesse": Vector2(1.2, 2.6), "gravite": Vector3(0, 0.8, 0), "amorti": Vector2(5.0, 8.0),
		"ouvert": 0.15, "ecarte": 0.02, "taille": Vector2(0.04, 0.08), "courbe": 1, "alea": 0.3, "chaud": 0.0,
		"rampe": ["#ffffff", "#fffbe8", "#fff0a8", "#fcb53a"], "cap": 7.0, "eclat": 1.8,
		"fin": {"n": 150, "taille": Vector2(0.018, 0.034), "cap": 10.0, "etire": 3.0, "eclat": 2.1}},
	# 3 escarbilles : fines, s'échappent par les bords
	{"mode": "escarbilles", "add": true, "n": 30, "vie": 0.9, "vitesse": Vector2(1.0, 3.0), "gravite": Vector3(0, 0.5, 0), "amorti": Vector2(0.8, 1.5),
		"ouvert": 0.45, "turb": 6.0, "suit_jet": 0.6, "taille": Vector2(0.012, 0.022), "courbe": 0, "alea": 0.4, "chaud": 0.0,
		"rampe": ["#ffffff", "#fff0a8", "#fcb53a", "#ec6a1f", "#b3341f"], "cap": 3.0, "eclat": 2.0,
		"fin": {"n": 45, "taille": Vector2(0.006, 0.011), "cap": 3.0, "etire": 2.0}},
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
const BRULURE := [0.55, 0.0, 0.0, 0.45, 1.0, 0.22]
const MONTEE := 0.15            # s : le corps prend feu
const RETOMBEE := 0.12          # s : fin du jet → brûlure
const FOYERS_BRULURE := 3
const CARBO_MAX := 0.55
const CARBO_TENUE := 3.0        # s : la carbonisation reste après l'extinction…
const CARBO_FONDU := 4.0        # … puis s'estompe
## Couverture : le feu GAGNE le corps tant que le jet dure (0 → 1 en COUV_MONTEE s), puis recule après l'arrêt.
## Elle élargit la zone des langues (rayon du jet × 1 + COUV_RAYON × couverture) et celle de la coque (mc_autre.x).
const COUV_MONTEE := 1.4
const COUV_DESCENTE := 2.5
const COUV_RAYON := 1.1

static func debut(_ic: ImpactCorps, f: ImpactCorps.Foyer) -> void:
	f.d = {"k_jet": 0.0, "vu": -INF, "jets": {}, "dir": Vector3.FORWARD, "imp": Vector3(0, 1.1, 0), "imp_i": -1,
		"rayon": 0.45, "dbl": false, "brule_fin": -INF, "k_brule": 0.0, "foyers": PackedInt32Array(), "carbo": 0.0,
		"chaleur": 0.0, "eteint": -INF, "couv": 0.0}

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
	var _p0 := Time.get_ticks_usec()
	var d := f.d
	var h := ic.gm.horloge
	var s := f.surface
	# (fusion, API de B) surface remplacée (repli en capsules → vrais maillages) : les index gardés désignent d'autres
	# points ; le point touché est retrouvé par sa position, les foyers de brûlure sont retirés autour de lui
	if ic.surface_changee(f):
		if int(d.imp_i) >= 0:
			d.imp_i = ImpactCorps.plus_proche(s, d.imp)
		if not (d.foyers as PackedInt32Array).is_empty():
			_choisir_foyers(ic, f)
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
		# point touché refait au plus toutes les 3 images, et pas avant 0,08 s si le jet n'a pas tourné (cache de B)
		var i := ic.point_vise(f, o - org, dir) if (f.image % 3 == 0 or int(d.imp_i) < 0) else int(d.imp_i)
		if i >= 0 and i < s.nb:
			d.imp = d.imp.lerp(s.pos[i], 1.0 - exp(-dt * 25.0)) if float(d.k_jet) > 0.05 else s.pos[i]
			d.imp_i = i
		d.k_jet = minf(float(d.k_jet) + dt / MONTEE, 1.0)
		d.couv = minf(float(d.couv) + dt / COUV_MONTEE * (1.3 if d.dbl else 1.0), 1.0)
		d.chaleur = minf(float(d.chaleur) + dt / MONTEE, 1.2 if d.dbl else 1.0)
		d.carbo = minf(float(d.carbo) + dt * 0.25, CARBO_MAX)
		d.eteint = -INF
		d.foyers = PackedInt32Array()   # choisis à la fin du jet, autour du dernier point touché
	else:
		d.k_jet = maxf(float(d.k_jet) - dt / RETOMBEE, 0.0)
		d.couv = maxf(float(d.couv) - dt / COUV_DESCENTE, 0.0)
		# l'impact suit le point de surface (le corps bouge, tombe)
		if int(d.imp_i) >= 0 and int(d.imp_i) < s.nb:
			d.imp = s.pos[d.imp_i]
	ImpactCorps.prof("feu jets", _p0); _p0 = Time.get_ticks_usec()
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
	ImpactCorps.prof("feu etat", _p0); _p0 = Time.get_ticks_usec()
	# paramètres du foyer (jet + foyers de brûlure), écrits dans la texture des points
	var couv := float(d.couv)
	ic.regler_jet(f, d.dir, kj, d.imp, float(d.rayon) * (1.0 + COUV_RAYON * couv))
	var fo: Array = []
	var ids: PackedInt32Array = d.foyers
	for k in 4:
		if k < ids.size() and ids[k] < s.nb and kb > 0.0:
			fo.append(Vector4(s.pos[ids[k]].x, s.pos[ids[k]].y, s.pos[ids[k]].z, 0.15 + 0.04 * k))
		else:
			fo.append(Vector4.ZERO)
	ic.regler_foyers(f, kb, minf(s.bas, 0.0) + 0.02, fo)
	# parts actives des émetteurs
	for k in f.em.size():
		var r := maxf(SOUS_JET[k] * kj, BRULURE[k] * kb)
		if k == 0:
			# langues : 70 % au contact, toutes quand le feu a gagné le corps
			r *= 0.7 + 0.3 * maxf(couv, 1.0 - kj)
			if d.dbl:
				r = minf(r * 1.15, 1.0)
		ic.activer(f.em[k], r)
	ImpactCorps.prof("feu params+activer", _p0); _p0 = Time.get_ticks_usec()
	# voile : chaleur au point touché, direction, carbonisation
	if f.image % 2 == 0 or f.image < 4:
		# valeurs arrondies (2 cm, 1/50) : le voile n'est renvoyé que si elles changent vraiment
		var imp_monde: Vector3 = (org + d.imp).snappedf(0.02)
		var dq: Vector3 = (d.dir as Vector3).snappedf(0.02)
		ic.voile(f, "mc_feu", Vector4(imp_monde.x, imp_monde.y, imp_monde.z, snappedf(ch, 0.02)))
		ic.voile(f, "mc_dir", Vector4(dq.x, dq.y, dq.z, snappedf(float(d.carbo), 0.02)))
		# x : couverture (coque et voile : zone chaude qui grandit avec la durée du jet) ; w : part du jet
		ic.voile(f, "mc_autre", Vector4(snappedf(couv, 0.05), 0.0, 0.0, snappedf(kj, 0.02)))
	ImpactCorps.prof("feu voile", _p0); _p0 = Time.get_ticks_usec()
	ic.repousser(f, kj)
	# le corps éclaire le décor pendant la brûlure (sous le jet, la lumière du jet est déjà au contact)
	if kb > 0.05:
		var sc := 0.85 + 0.25 * sin(h * 19.0 + f.id) * sin(h * 6.3)
		ic.gm.lumiere("corps%d" % f.id, org + s.centre + Vector3.UP * 0.2, GestionMagie.LUMIERE.feu, 1.6 * kb * sc, 3.2, 1.0)
	ImpactCorps.prof("feu repousse+lum", _p0)
	if not (d.foyers as PackedInt32Array).is_empty() and not brule and kb <= 0.0:
		d.foyers = PackedInt32Array()
	# fini : plus de jet, plus de brûlure, braises éteintes, carbonisation estompée
	return sous_jet or brule or kj > 0.0 or kb > 0.0 or ch > 0.01 or float(d.carbo) > 0.005
