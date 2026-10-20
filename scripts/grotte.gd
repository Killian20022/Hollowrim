class_name Grotte
extends Node3D
## Grotte vitrine (futur donjon naturel), ~124 m de parcours : entrée en pente (neige soufflée, jour froid), boyau,
## grande caverne au lac gelé (faille au plafond, rai de lumière), galerie à strates (marches naturelles, dénivelés),
## campement de bandits, fond aux cristaux de glace.
##
## Construction : un TUBE de 18 sommets par anneau le long d'une ligne médiane (cap + dénivelé), dont les anneaux changent de
## largeur, de hauteur, de relief (bruit facetté) et de profil le long du parcours. Les anneaux sont fermés et reliés : aucun
## trou, aucune fuite de ciel (l'extérieur n'est qu'une carte « jour » sans éclairage au bout de l'entrée, la faille est fermée
## par une bande de ciel). Chaque facette est plate (normale propre), colorée aux sommets (occlusion ambiante peinte) et porte un
## masque de neige / glace / mousse que le shader compare à un seuil de texture. La collision est le maillage exact (trimesh).
##
## Description (règle Lead Technical Artist) :
##  1. Murs / Structure : coque facettée à strates, ruptures de pente, marches naturelles (palier 32 cm, contremarche ≤ 35°),
##     stalagmites / stalactites / colonnes comme repères, étais de bois au passage des bandits, parois couvertes de givre ou de mousse.
##  2. Mobilier : (campement) feu cerclé de pierres et marmite, 4 couchages, caisses empilées, tonneaux, sacs, table et tabourets,
##     2 râteliers d'armes, 2 coffres au butin ouvert, trophées de crânes, ossements ; (galerie) squelette et lame rouillée.
##  3. Éclairage : OmniLight3D courtes sans ombre, 3 à 6 par salle ; jour froid à l'entrée, vert mousse dans le boyau et la
##     galerie, bleu glacial sur le lac et les cristaux, feu chaud au campement ; rai oblique + flaque + projecteur étroit sous la
##     faille ; émissif pour les cristaux ; ambiante bleu-gris : jamais noir total.

const NB := 18
const LONGUEUR := 124.0
const LAC_Y := -4.7
const Q := 0.32                 # hauteur d'une marche naturelle (m)
const POS_MONDE := Vector3(20.0, -220.0, 100.0)

# s (m le long du parcours), y (m, net), demi-largeur gauche, demi-largeur droite, hauteur au centre, relief, amplitude des strates
const CLES := [
	[0.0, 5.5, 7.5, 7.5, 8.5, 0.5, 0.0],
	[5.0, 4.3, 7.0, 7.0, 8.0, 0.5, 0.0],
	[7.0, 3.55, 3.4, 3.6, 4.4, 0.4, 0.0],
	[9.0, 3.0, 3.6, 3.8, 4.8, 0.4, 0.0],
	[14.0, 0.9, 3.2, 3.4, 4.3, 0.35, 0.0],
	[18.0, 0.0, 1.9, 1.9, 3.0, 0.3, 0.0],
	[22.0, -0.6, 1.3, 1.5, 2.5, 0.28, 0.0],
	[24.5, -1.0, 1.5, 1.2, 2.2, 0.28, 0.0],
	[27.0, -1.4, 1.8, 1.6, 3.0, 0.3, 0.0],
	[31.0, -2.0, 1.4, 1.6, 2.6, 0.3, 0.0],
	[34.6, -2.5, 1.5, 1.7, 3.0, 0.3, 0.0],
	[35.3, -2.6, 4.5, 3.4, 6.5, 0.5, 0.0],
	[36.0, -2.7, 12.0, 3.4, 9.0, 0.9, 0.0],
	[38.0, -2.9, 13.5, 3.6, 10.5, 1.0, 0.0],
	[48.0, -3.3, 14.0, 3.6, 12.5, 1.1, 0.0],
	[56.0, -3.65, 14.0, 3.4, 11.5, 1.1, 0.0],
	[64.0, -4.0, 12.5, 3.4, 10.0, 1.0, 0.0],
	[66.8, -4.2, 11.0, 3.0, 8.5, 0.8, 0.0],
	[67.4, -4.3, 2.8, 2.8, 4.2, 0.3, 0.3],
	[68.5, -4.4, 2.6, 2.7, 4.0, 0.25, 0.35],
	[72.0, -4.8, 2.9, 3.1, 4.6, 0.25, 0.4],
	[78.0, -6.4, 3.2, 3.0, 4.8, 0.25, 0.4],
	[84.0, -5.6, 3.4, 3.0, 5.2, 0.25, 0.4],
	[88.0, -6.6, 2.6, 2.8, 4.2, 0.25, 0.35],
	[91.2, -7.0, 3.0, 3.0, 4.4, 0.25, 0.3],
	[92.2, -7.0, 5.5, 5.5, 5.0, 0.3, 0.3],
	[96.0, -7.0, 6.0, 6.0, 5.5, 0.35, 0.35],
	[102.5, -7.0, 6.0, 6.0, 5.5, 0.35, 0.35],
	[106.0, -7.0, 3.6, 3.6, 4.4, 0.3, 0.3],
	[108.5, -7.0, 2.4, 2.4, 3.4, 0.3, 0.0],
	[110.0, -7.0, 2.4, 2.4, 3.6, 0.3, 0.0],
	[112.0, -7.4, 3.0, 3.0, 5.0, 0.4, 0.0],
	[114.0, -7.9, 5.5, 5.0, 8.0, 0.6, 0.0],
	[120.0, -9.0, 5.5, 5.0, 9.0, 0.6, 0.0],
	[123.0, -9.4, 4.0, 4.0, 7.0, 0.5, 0.0],
	[124.0, -9.4, 3.2, 3.2, 5.5, 0.4, 0.0],
]
# cap (degrés ; 0 = vers -Z, positif = vers +X)
const CAP := [[0.0, 0.0], [14.0, 0.0], [18.0, 16.0], [24.0, -18.0], [30.0, -10.0], [34.0, 0.0], [68.0, 0.0], [72.0, -18.0], [80.0, 12.0], [86.0, 22.0], [91.0, 0.0], [97.0, 0.0], [103.0, -40.0], [108.0, -40.0], [113.0, -40.0], [119.0, 6.0], [124.0, 6.0]]
# part de « marches naturelles » (0 = pente lisse, 1 = paliers)
const MARCHES := [[0.0, 0.0], [17.0, 0.0], [20.0, 0.8], [34.0, 0.8], [35.2, 0.0], [38.0, 1.0], [66.0, 1.0], [67.5, 0.0], [69.0, 1.0], [91.0, 1.0], [92.0, 0.0], [108.0, 0.0], [110.0, 1.0], [124.0, 1.0]]
const AO := [1.0, 0.92, 0.7, 0.8, 0.9, 0.95, 0.92, 0.82, 0.74, 0.7, 0.74, 0.82, 0.92, 0.95, 0.9, 0.8, 0.7, 0.92]

var decor: GrotteDecor
var corps: StaticBody3D
var joueur: Node
var rng := RandomNumberGenerator.new()
var _bruit := FastNoiseLite.new()
var _chemin := PackedVector2Array()      # xz tous les 0,1 m
var _anneaux: Array = []
var _idx := {}                            # cellule 4 m -> indices de triangles de la coque
var _t := 0.0
var _flamme_pixel: MeshInstance3D
var temps_ms := 0
var nb_lumieres := 0
var etapes := {}

## Crée la grotte sous le monde (y = -220), loin de la crypte. `parent` : le monde.
static func creer(parent: Node3D, joueur_: Node = null) -> Grotte:
	var g := Grotte.new()
	g.joueur = joueur_
	g.position = POS_MONDE
	parent.add_child(g)
	g.construire()
	return g

# ------------------------------------------------------------------ fonctions de forme
static func _lisse(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

static func _interp(tab: Array, s: float, col: int, lisse := true) -> float:
	if s <= tab[0][0]:
		return tab[0][col]
	for i in tab.size() - 1:
		var a: Array = tab[i]
		var b: Array = tab[i + 1]
		if s <= b[0]:
			var t: float = (s - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			if lisse:
				t = _lisse(t)
			return lerpf(a[col], b[col], t)
	return tab[tab.size() - 1][col]

func y_net(s: float) -> float:
	var lin := _interp(CLES, s, 1, false)
	var tz := _interp(MARCHES, s, 1, false)
	if tz < 0.001:
		return lin
	var u := lin / Q
	var f := u - floorf(u)
	var terrasse := (floorf(u) + _lisse(clampf(f / 0.55, 0.0, 1.0))) * Q
	return lerpf(lin, terrasse, tz)

func _cap_deg(s: float) -> float:
	return _interp(CAP, s, 1, true)

func _integrer_chemin() -> void:
	var p := Vector2.ZERO
	var n := int(LONGUEUR * 10.0) + 12
	_chemin.resize(n)
	for i in n:
		_chemin[i] = p
		var th := deg_to_rad(_cap_deg(float(i) * 0.1))
		p += Vector2(sin(th), -cos(th)) * 0.1

func xz(s: float) -> Vector2:
	var f := clampf(s, 0.0, LONGUEUR) * 10.0
	var i := mini(int(f), _chemin.size() - 2)
	return _chemin[i].lerp(_chemin[i + 1], f - i)

func tangente(s: float) -> Vector3:
	var th := deg_to_rad(_cap_deg(s))
	return Vector3(sin(th), 0.0, -cos(th))

func droite(s: float) -> Vector3:
	return tangente(s).cross(Vector3.UP)

func _n(s: float, k: int, ch: float) -> float:
	return _bruit.get_noise_2d(s * 0.5 + ch * 13.7, float(k) * 5.3)

func lac_f(s: float) -> float:
	return _lisse(clampf((s - 36.5) / 3.5, 0.0, 1.0)) * (1.0 - _lisse(clampf((s - 58.0) / 4.0, 0.0, 1.0)))

func faille_f(s: float) -> float:
	return _lisse(clampf((s - 46.0) / 1.2, 0.0, 1.0)) * (1.0 - _lisse(clampf((s - 51.8) / 1.2, 0.0, 1.0)))

## Un anneau : 18 sommets (sol au centre, paroi droite, plafond, paroi gauche) à l'abscisse s.
func _anneau(s: float) -> Dictionary:
	var y0 := y_net(s)
	var wl := _interp(CLES, s, 2)
	var wr := _interp(CLES, s, 3)
	var h := _interp(CLES, s, 4)
	var jit := _interp(CLES, s, 5)
	var amp := _interp(CLES, s, 6)
	var lam := lac_f(s)
	var kap := faille_f(s)
	var T := tangente(s)
	var R := droite(s)
	var c2 := xz(s)
	var P := Vector3(c2.x, y0, c2.y)
	var a: Array = []
	var b: Array = []
	a.resize(NB)
	b.resize(NB)
	a[0] = 0.0
	b[0] = 0.0
	var lac_b := LAC_Y - y0
	for cote in 2:
		var sg := 1.0 if cote == 0 else -1.0
		var w := wr if cote == 0 else wl
		var ch := float(cote) * 7.0
		var ids: Array = [1, 2, 3, 4, 5, 6, 7, 8] if cote == 0 else [17, 16, 15, 14, 13, 12, 11, 10]
		var jf := 0.04 + 0.03 * jit
		# sol proche, pied de paroi
		var a1 := 0.45 * w * (1.0 + 0.1 * _n(s, ids[0], ch))
		var b1 := jf * _n(s, ids[0] + 20, ch)
		var a2 := 0.93 * w + 0.3 * jit * _n(s, ids[1], ch)
		var b2 := 0.14 + 0.1 * absf(_n(s, ids[1] + 20, ch)) * (1.0 + jit)
		if cote == 1 and lam > 0.0:
			b1 = lerpf(b1, lac_b, lam)
			b2 = lerpf(b2, lac_b + 0.22, lam)
			a2 = 0.95 * w
		a[ids[0]] = sg * a1
		b[ids[0]] = b1
		a[ids[1]] = sg * a2
		b[ids[1]] = b2
		# parois : 4 sommets, décalage alterné (strates : surplombs et retraits)
		var fr := [0.2, 0.42, 0.64, 0.84]
		var alt := [1.0, -0.45, 1.0, -0.45]
		for j in 4:
			var id: int = ids[2 + j]
			b[id] = b2 + fr[j] * (h * 0.93 - b2) + jit * 0.3 * _n(s, id + 40, ch)
			a[id] = sg * (w * (1.0 + 0.06 * jit * _n(s, id, ch)) + amp * alt[j] + jit * 0.55 * _n(s, id + 60, ch))
		# épaule et sommet du plafond (la faille remplace ces trois sommets par un conduit étroit)
		var e1 := lerpf(w * 0.74, 1.3, kap)
		var e2 := lerpf(w * 0.36, 0.9, kap)
		a[ids[6]] = sg * e1
		b[ids[6]] = lerpf(0.93 * h + jit * 0.4 * _n(s, ids[6] + 80, ch), h * 0.99, kap)
		a[ids[7]] = sg * e2
		b[ids[7]] = lerpf(h + jit * 0.5 * _n(s, ids[7] + 80, ch), h + 6.2, kap)
	a[9] = 0.0
	b[9] = lerpf(h + jit * 0.45 * _n(s, 9, 3.0) + 1.4 * jit * maxf(_n(s, 29, 5.0), 0.0), h + 7.0, kap)
	# la faille penche vers la droite en montant (rai oblique)
	for id in [7, 8, 9, 10, 11]:
		a[id] += kap * 3.0
	var pts: Array = []
	for k in NB:
		pts.append(P + R * a[k] + Vector3.UP * b[k])
	return {"s": s, "y": y0, "pts": pts, "R": R, "T": T, "h": h, "wl": wl, "wr": wr, "lam": lam, "kap": kap, "P": P}

func _liste_s() -> Array:
	var res: Array = [0.0]
	var cles_s: Array = []
	for c: Array in CLES:
		cles_s.append(c[0])
	for extra in [40.0, 46.0, 47.2, 49.6, 51.8, 53.0, 58.0, 62.0]:
		cles_s.append(extra)
	var last := 0.0
	var s := 0.0
	var etat_prec := false
	while s < LONGUEUR - 0.001:
		var s_pre := s
		s = minf(s + 0.1, LONGUEUR)
		var pente := absf(y_net(s) - y_net(s_pre)) / 0.1
		var etat := pente > 0.14
		var ds := 2.4
		if s >= 17.0 and s < 35.0:
			ds = 1.6
		elif s >= 35.0 and s < 67.0:
			ds = 3.0
		elif s >= 67.0 and s < 91.5:
			ds = 1.7
		elif s >= 108.0:
			ds = 2.2
		var emet := (s - last) >= ds
		for cs: float in cles_s:
			if s_pre < cs and s >= cs and (s - last) > 0.05:
				emet = true
		if etat != etat_prec and (s - last) >= 0.35:
			emet = true
		etat_prec = etat
		if s >= LONGUEUR - 0.001:
			emet = true
		if emet:
			res.append(s)
			last = s
	return res

# ------------------------------------------------------------------ matière d'une facette
## [nom de matière, masque]
func _matiere(s: float, n: Vector3, hrel: float, k: int, lam: float) -> Array:
	var sol_ := n.y > 0.55
	var plaf := n.y < -0.45
	if s < 17.5:
		var fade := 1.0 - _lisse(clampf((s - 7.0) / 10.5, 0.0, 1.0)) * 0.75
		if sol_:
			return ["c_sol_neige", 1.15 * fade + 0.1]
		if plaf:
			return ["c_roche_neige", 0.12 * fade]
		return ["c_roche_neige", clampf(0.2 + 0.85 * (n.y + 0.3), 0.0, 1.0) * fade]
	if s < 35.2:
		if sol_:
			return ["c_sol_mousse", 0.4 if s > 20.0 else 0.65 * (1.0 - (s - 17.5) / 2.0) + 0.3]
		if plaf:
			return ["c_roche_nu", 0.0]
		return ["c_roche_mousse", 0.42 if hrel < 1.3 else 0.1]
	if s < 67.2:
		if k == 16 and lam > 0.5:
			return ["c_glace", 0.0]
		if sol_:
			return ["c_sol_glace", 0.85]
		if plaf:
			return ["c_roche_glace", 0.25]
		return ["c_roche_glace", 0.62 if hrel < 3.0 else 0.4]
	if s < 91.7:
		if sol_:
			return ["c_sol_mousse" if hrel < 0.5 and s > 70.0 else "c_sol_nu", 0.2]
		if plaf:
			return ["c_strate_mousse", 0.08]
		return ["c_strate_mousse", 0.42 if hrel < 1.2 else 0.12]
	if s < 108.2:
		if sol_:
			return ["c_sol_camp", 0.0]
		return ["c_strate_suie", 0.0]
	if s < 111.5:                      # goulot : roche nue, givre léger (le bleu des cristaux ne doit pas « fuir » dans le camp)
		if sol_:
			return ["c_sol_nu", 0.2]
		return ["c_roche_nu", 0.0]
	if sol_:
		return ["c_sol_glace", 0.9]
	if plaf:
		return ["c_roche_glace", 0.85]
	return ["c_roche_glace", 0.95]

func _tri_coque(a: Vector3, b: Vector3, c: Vector3, ka: int, kb: int, kc: int, ra: Dictionary, rb: Dictionary, k_seg: int, ref: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	var ct := (a + b + c) / 3.0
	if n.dot(ref - ct) < 0.0:
		n = -n
	var s: float = (ra["s"] + rb["s"]) * 0.5
	var hrel: float = ct.y - (ra["y"] + rb["y"]) * 0.5
	var lam: float = (ra["lam"] + rb["lam"]) * 0.5
	var nom := "c_roche_nu"
	var masque := 0.0
	var kap_a: float = ra["kap"]
	var kap_b: float = rb["kap"]
	if kap_a > 0.85 and kap_b > 0.85 and (k_seg == 8 or k_seg == 9):
		nom = "ciel"
	else:
		var m := _matiere(s, n, hrel, k_seg, lam)
		nom = m[0]
		masque = m[1]
		masque *= 0.8 + 0.4 * GrotteDecor.hash2(ct.x * 0.7, ct.z * 1.3 + ct.y)
	var sombre := 0.94 if (s >= 91.7 and s < 108.2 and not (n.y > 0.55)) else 1.0
	if nom == "ciel":
		var cl := Color(1, 1, 1, 0)
		decor.facette(nom, a, b, c, ref, [cl, cl, cl], true, 4.0, true)
		return
	var cols: Array = []
	for k in [ka, kb, kc]:
		var ao: float = AO[k] * (0.93 + 0.07 * GrotteDecor.hash2(float(k) * 3.7, s * 5.1 + float(ra["s"]))) * sombre
		var etroit := minf(ra["wl"] + ra["wr"], rb["wl"] + rb["wr"])
		if etroit < 5.5:
			ao *= 0.9
		cols.append(GrotteDecor.col(ao, masque))
	decor.facette(nom, a, b, c, ref, cols, true, 4.0, true)

# ------------------------------------------------------------------ construction
func construire() -> void:
	var t0 := Time.get_ticks_msec()
	rng.seed = 2610
	_bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_bruit.frequency = 1.0
	_bruit.seed = 424
	_integrer_chemin()
	corps = StaticBody3D.new()
	corps.name = "Corps"
	add_child(corps)
	decor = GrotteDecor.new(self, corps)
	var t1 := Time.get_ticks_msec()
	for s in _liste_s():
		_anneaux.append(_anneau(s))
	etapes["anneaux"] = Time.get_ticks_msec() - t1
	var tp := Time.get_ticks_msec()
	_coque()
	_caps()
	_indexer()
	etapes["coque"] = Time.get_ticks_msec() - tp
	tp = Time.get_ticks_msec()
	_decorer()
	_lumieres()
	_neige_soufflee()
	etapes["decor"] = Time.get_ticks_msec() - tp
	tp = Time.get_ticks_msec()
	nb_lumieres = 0
	for n in get_children():
		if n is OmniLight3D:
			nb_lumieres += 1
	decor.finir()
	etapes["finir"] = Time.get_ticks_msec() - tp
	var forme := ConcavePolygonShape3D.new()
	forme.backface_collision = true
	forme.set_faces(decor.coll)
	var cs := CollisionShape3D.new()
	cs.shape = forme
	cs.name = "CoqueSolide"
	corps.add_child(cs)
	temps_ms = Time.get_ticks_msec() - t0

func _coque() -> void:
	for i in _anneaux.size() - 1:
		var ra: Dictionary = _anneaux[i]
		var rb: Dictionary = _anneaux[i + 1]
		var pa: Array = ra["pts"]
		var pb: Array = rb["pts"]
		var ref: Vector3 = ((ra["P"] as Vector3) + (rb["P"] as Vector3)) * 0.5 + Vector3(0, 0.45 * (float(ra["h"]) + float(rb["h"])) * 0.5, 0)
		for k in NB:
			var j := (k + 1) % NB
			_tri_coque(pa[k], pa[j], pb[j], k, j, j, ra, rb, k, ref)
			_tri_coque(pa[k], pb[j], pb[k], k, j, k, ra, rb, k, ref)

## Extrémités : l'entrée donne sur le jour (carte sans éclairage découpée par la bouche rocheuse) ; le fond est un dôme de glace.
func _caps() -> void:
	var r0: Dictionary = _anneaux[0]
	var p0: Array = r0["pts"]
	var c0: Vector3 = r0["P"] + Vector3(0, 0.5 * float(r0["h"]), 0) - (r0["T"] as Vector3) * 0.0
	var R0: Vector3 = r0["R"]
	var ref0: Vector3 = c0 + (r0["T"] as Vector3) * 6.0
	var blanc := Color(1, 1, 1, 0)
	for k in NB:
		var j := (k + 1) % NB
		var pts: Array = [c0 - (r0["T"] as Vector3) * 0.2, p0[k], p0[j]]
		var uvs: Array = []
		for p: Vector3 in pts:
			var lat := (p - c0).dot(R0)
			uvs.append(Vector2(0.5 + lat / 17.0, 1.0 - (p.y - (float(r0["y"]) - 1.5)) / 8.5))
		decor.facette("jour", pts[0], pts[1], pts[2], ref0, [blanc, blanc, blanc], true, 4.0, true, uvs)
	# fond : dôme en anneaux concentriques décalés (pas d'étoile de triangles), glace uniforme
	var rn: Dictionary = _anneaux[_anneaux.size() - 1]
	var pn: Array = rn["pts"]
	var Tn: Vector3 = rn["T"]
	var c_plan: Vector3 = (rn["P"] as Vector3) + Vector3(0, 0.45 * float(rn["h"]), 0)
	var refn: Vector3 = (rn["P"] as Vector3) + Vector3(0, 0.45 * float(rn["h"]), 0) - Tn * 4.0
	var anneaux_d: Array = [pn]
	for e in [[0.66, 0.9], [0.33, 1.7]]:
		var rg: Array = []
		for k in NB:
			var j: float = GrotteDecor.hash2(float(k) * 2.3 + float(e[0]) * 10.0, 9.0)
			rg.append(c_plan.lerp(pn[k], e[0]) + Tn * (e[1] + 0.45 * j) + Vector3(0, 0.25 * (j - 0.5), 0))
		anneaux_d.append(rg)
	var cn: Vector3 = c_plan + Tn * 2.5
	for r in anneaux_d.size():
		var A: Array = anneaux_d[r]
		var cc := GrotteDecor.col(AO[(r * 3) % NB] * 0.92, 0.9)
		for k in NB:
			var j := (k + 1) % NB
			if r + 1 < anneaux_d.size():
				var B: Array = anneaux_d[r + 1]
				decor.facette("c_roche_glace", A[k], A[j], B[j], refn, [cc, cc, cc], true, 4.0, true)
				decor.facette("c_roche_glace", A[k], B[j], B[k], refn, [cc, cc, cc], true, 4.0, true)
			else:
				decor.facette("c_roche_glace", A[k], A[j], cn, refn, [cc, cc, cc], true, 4.0, true)

# ------------------------------------------------------------------ index spatial de la coque
func _indexer() -> void:
	var c := decor.coll
	var n := c.size() / 3
	for t in n:
		var a := c[t * 3]
		var b := c[t * 3 + 1]
		var d := c[t * 3 + 2]
		var x0 := floori(minf(a.x, minf(b.x, d.x)) / 2.0)
		var x1 := floori(maxf(a.x, maxf(b.x, d.x)) / 2.0)
		var z0 := floori(minf(a.z, minf(b.z, d.z)) / 2.0)
		var z1 := floori(maxf(a.z, maxf(b.z, d.z)) / 2.0)
		for cx in range(x0, x1 + 1):
			for cz in range(z0, z1 + 1):
				var key := Vector2i(cx, cz)
				if not _idx.has(key):
					_idx[key] = PackedInt32Array()
				(_idx[key] as PackedInt32Array).append(t)

## Hauteurs de la coque au-dessus de (x, z) (repère local) : [plus bas, plus haut] parmi les facettes non verticales.
func _hauteurs(x: float, z: float) -> Vector2:
	var key := Vector2i(floori(x / 2.0), floori(z / 2.0))
	var bas := 1e9
	var haut := -1e9
	if not _idx.has(key):
		return Vector2(bas, haut)
	var c := decor.coll
	for t: int in (_idx[key] as PackedInt32Array):
		var a := c[t * 3]
		var b := c[t * 3 + 1]
		var d := c[t * 3 + 2]
		var n := (b - a).cross(d - a)
		if absf(n.y) < 0.25 * n.length():
			continue
		var den := (b.z - d.z) * (a.x - d.x) + (d.x - b.x) * (a.z - d.z)
		if absf(den) < 1e-9:
			continue
		var l1 := ((b.z - d.z) * (x - d.x) + (d.x - b.x) * (z - d.z)) / den
		var l2 := ((d.z - a.z) * (x - d.x) + (a.x - d.x) * (z - d.z)) / den
		var l3 := 1.0 - l1 - l2
		if l1 < -0.0001 or l2 < -0.0001 or l3 < -0.0001:
			continue
		var y := l1 * a.y + l2 * b.y + l3 * d.y
		bas = minf(bas, y)
		haut = maxf(haut, y)
	return Vector2(bas, haut)

## Point du sol (repère local) à l'abscisse s et au décalage latéral lat (+ = droite).
func sol_en(s: float, lat: float) -> Vector3:
	var c := xz(s) + Vector2(droite(s).x, droite(s).z) * lat
	var h := _hauteurs(c.x, c.y)
	return Vector3(c.x, h.x if h.x < 1e8 else y_net(s), c.y)

func plafond_en(s: float, lat: float) -> Vector3:
	var c := xz(s) + Vector2(droite(s).x, droite(s).z) * lat
	var h := _hauteurs(c.x, c.y)
	return Vector3(c.x, h.y if h.y > -1e8 else y_net(s) + 4.0, c.y)

## Position monde / point d'observation (pour captures et tests).
func monde_sol(s: float, lat: float) -> Vector3:
	return to_global(sol_en(s, lat))

func cap_monde(s: float) -> float:
	return atan2(-tangente(s).x, -tangente(s).z) + global_rotation.y

# ------------------------------------------------------------------ décor : concrétions, rochers, cristaux, mobilier
func _r(a: float, b: float) -> float:
	return rng.randf_range(a, b)

func _pointes(s0: float, s1: float, lat0: float, lat1: float, n: int, nom: String, rmax: float, lmax: float, masque: float, sol_: bool, ecart_chemin := 0.0) -> void:
	for k in n:
		var s := _r(s0, s1)
		var lat := _r(lat0, lat1)
		if absf(lat) < ecart_chemin:
			continue
		var p := sol_en(s, lat) if sol_ else plafond_en(s, lat)
		if sol_:
			decor.pointe(nom, p + Vector3(0, -0.05, 0), _r(0.12, rmax), _r(0.4, lmax), rng.randi(), masque)
		else:
			if faille_f(s) > 0.02:
				continue
			decor.pointe(nom, p + Vector3(0, 0.12, 0), _r(0.1, rmax), -_r(0.4, lmax), rng.randi(), masque)

func _cailloux() -> void:
	# micro : éclats de roche et gravats sur le sol, sans collision (fusionnés dans la coque)
	for k in 150:
		var s := _r(1.0, 123.0)
		var w := _interp(CLES, s, 3)
		var wl := _interp(CLES, s, 2)
		var lat := _r(-minf(wl, 7.0) * 0.9, w * 0.9)
		var nom := "c_roche_nu"
		if s < 17.0:
			nom = "c_roche_neige"
		elif s > 108.0 or (s > 36.0 and s < 67.0):
			nom = "c_roche_glace"
		decor.caillou(nom, sol_en(s, lat), _r(0.05, 0.2), _r(0.04, 0.16), rng.randi(), 0.7 if s < 17.0 else 0.4)

func _decorer() -> void:
	_cailloux()
	_entree()
	_boyau()
	_caverne()
	_galerie()
	_camp()
	_rideau(109.4)
	_fond()

func _entree() -> void:
	# congères et rochers enneigés contre les parois (macro), glaçons à la bouche (méso), marqueur des bandits (micro)
	for k in 9:
		var s := _r(1.0, 15.0)
		var cote := 1.0 if k % 2 == 0 else -1.0
		var w := _interp(CLES, s, 3 if cote > 0 else 2)
		decor.congere(sol_en(s, cote * w * _r(0.5, 0.85)), _r(1.3, 2.6), _r(0.25, 0.5), rng.randi())
	for k in 5:
		var s := _r(2.0, 13.0)
		var cote := 1.0 if k % 2 == 0 else -1.0
		var w := _interp(CLES, s, 3 if cote > 0 else 2)
		decor.rocher("c_roche_neige", sol_en(s, cote * w * _r(0.4, 0.8)), _r(0.6, 1.2), _r(0.6, 1.3), rng.randi(), 0.4, true, 7)
	_pointes(5.0, 11.0, -3.5, 3.5, 12, "c_roche_glace", 0.2, 1.6, 1.0, false)
	_pointes(17.0, 20.0, -1.2, 1.2, 3, "c_roche_nu", 0.18, 0.8, 0.0, false)
	decor.trophee(sol_en(13.0, -2.2), 1.7, 0.4)
	decor.os_tas(sol_en(12.6, 1.4), 3, 0.5)
	decor.arme(sol_en(11.0, 1.9) + Vector3(0, 0.02, 0), 0.8)
	decor.caisse(sol_en(9.5, -2.6), Vector3(0.8, 0.55, 0.55), 0.5)

func _boyau() -> void:
	_pointes(18.5, 34.0, -1.4, 1.4, 22, "c_roche_nu", 0.16, 0.9, 0.0, false)
	_pointes(19.0, 34.0, -1.5, 1.5, 12, "c_roche_mousse", 0.14, 0.5, 0.5, true, 0.7)
	for k in 5:
		var s := _r(19.0, 33.0)
		var cote := 1.0 if k % 2 == 0 else -1.0
		var w := _interp(CLES, s, 3 if cote > 0 else 2)
		decor.rocher("c_roche_mousse", sol_en(s, cote * w * 0.75), _r(0.3, 0.55), _r(0.25, 0.5), rng.randi(), 0.7, false, 5)
	decor.os_tas(sol_en(28.5, 0.3), 5, 0.5)
	decor.arme(sol_en(21.0, -0.6), 2.4)
	decor.caisse(sol_en(31.5, 1.0), Vector3(0.6, 0.42, 0.45), 0.2)

func _caverne() -> void:
	# colonnes (repères) entre la glace et le plafond
	for c in [[42.0, -6.5, 0.8], [47.0, -11.0, 1.0], [56.0, -9.0, 0.9], [61.0, -5.5, 0.75]]:
		var pb := sol_en(c[0], c[1])
		var pt := plafond_en(c[0], c[1])
		decor.colonne("c_roche_glace", pb.x, pb.z, pb.y - 0.2, pt.y + 0.1, c[2], rng.randi(), 0.7)
	_pointes(37.0, 66.0, -12.5, 3.2, 34, "c_roche_glace", 0.5, 2.8, 0.8, false)
	_pointes(37.5, 66.0, -12.5, 3.2, 30, "c_roche_glace", 0.4, 1.9, 0.75, true, 1.4)
	# blocs sur la glace et le rivage
	for k in 12:
		var s := _r(38.0, 62.0)
		var lat := _r(-12.0, 3.0)
		if absf(lat) < 1.3:
			continue
		decor.rocher("c_roche_glace", sol_en(s, lat), _r(0.4, 1.3), _r(0.35, 1.1), rng.randi(), 0.7, true, 6)
	# cristaux isolés au bord du lac
	for c in [[41.5, -3.5], [53.0, -4.4], [60.0, -3.0], [45.0, -9.0], [58.0, -8.0]]:
		var p := sol_en(c[0], c[1])
		for j in 4:
			decor.cristal(p + Vector3(_r(-0.35, 0.35), -0.05, _r(-0.35, 0.35)), _r(0.07, 0.18), _r(0.5, 1.4), rng.randi(), 0.6)
	decor.os_tas(sol_en(44.0, 2.0), 4, 0.6)
	decor.arme(sol_en(50.5, 2.5), 4.0)
	decor.caisse(sol_en(39.0, 2.4), Vector3(0.7, 0.5, 0.5), 0.9)

func _galerie() -> void:
	_pointes(68.0, 91.0, -3.0, 3.0, 26, "c_strate_mousse", 0.2, 1.0, 0.2, false)
	_pointes(68.5, 91.0, -3.1, 3.1, 14, "c_strate_mousse", 0.2, 0.8, 0.3, true, 1.0)
	for k in 8:
		var s := _r(69.0, 90.0)
		var cote := 1.0 if k % 2 == 0 else -1.0
		var w := _interp(CLES, s, 3 if cote > 0 else 2)
		decor.rocher("c_strate_mousse", sol_en(s, cote * w * _r(0.6, 0.85)), _r(0.35, 0.8), _r(0.3, 0.7), rng.randi(), 0.3, true, 6)
	# étais de bois des bandits : deux cadres (poteaux + linteau + chapeaux), modules de 1 m
	for s in [75.0, 85.5]:
		var w1 := _interp(CLES, s, 2) - 0.25
		var w2 := _interp(CLES, s, 3) - 0.25
		var h := _interp(CLES, s, 4)
		var pa := sol_en(s, -w1)
		var pb := sol_en(s, w2)
		var R := droite(s)
		var haut := minf(pa.y, pb.y) + h - 0.55
		decor.prisme("bois", pa + Vector3(0, -0.1, 0), pa + Vector3(0, haut - pa.y, 0), 0.15, 8)
		decor.prisme("bois", pb + Vector3(0, -0.1, 0), pb + Vector3(0, haut - pb.y, 0), 0.15, 8)
		decor.prisme("bois", pa + Vector3(0, haut - pa.y, 0) - R * 0.3, pb + Vector3(0, haut - pb.y, 0) + R * 0.3, 0.17, 8)
		decor.solide_rond(pa + Vector3(0, 1.0, 0), 0.15, 2.4)
		decor.solide_rond(pb + Vector3(0, 1.0, 0), 0.15, 2.4)
	# squelette d'un aventurier et sa lame rouillée ; bougie sur une corniche
	decor.os_tas(sol_en(80.0, -1.0), 7, 0.7)
	decor.crane(sol_en(80.3, -0.6), 1.0)
	decor.arme(sol_en(80.6, 0.3), 3.6)
	decor.os_tas(sol_en(71.0, 1.4), 3, 0.4)
	decor.caisse(sol_en(82.0, 2.1), Vector3(0.8, 0.5, 0.5), 0.15)
	decor.caisse(sol_en(82.8, 2.2), Vector3(0.6, 0.42, 0.45), 0.5)
	decor.tonneau(sol_en(87.0, -2.0), 1.0)
	decor.solide_rond(sol_en(87.0, -2.0) + Vector3(0, 0.5, 0), 0.38, 1.0)

func _camp() -> void:
	var feu_s := 100.0
	var feu := sol_en(feu_s, 0.4)
	decor.feu_camp(feu)
	# marmite sur trépied
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		decor.prisme("bois", feu + Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.62), feu + Vector3(0, 1.25, 0), 0.028, 5)
	decor.tour("fer", feu + Vector3(0, 0.7, 0), [Vector2(0.15, 0.0), Vector2(0.24, 0.1), Vector2(0.27, 0.26), Vector2(0.24, 0.34), Vector2(0.2, 0.36)], 8, 0.0, false)
	decor.prisme("fer", feu + Vector3(0, 1.25, 0), feu + Vector3(0, 1.0, 0), 0.01, 4)
	# couchages le long de la paroi gauche et un à droite
	for c in [[96.8, -4.6, 1.57], [100.4, -4.7, 1.62], [104.0, -4.4, 1.5], [97.5, 4.5, -1.55]]:
		decor.couchage(sol_en(c[0], c[1]), c[2], rng.randf() < 0.6)
	# caisses empilées et tonneaux au fond droit, sacs
	var base := sol_en(105.2, 4.4)
	decor.caisse(base, Vector3(0.9, 0.6, 0.6), 0.1)
	decor.caisse(base + Vector3(1.0, 0, 0.1), Vector3(0.7, 0.5, 0.5), -0.2)
	decor.caisse(base + Vector3(0.1, 0.6, 0), Vector3(0.7, 0.5, 0.5), 0.35)
	decor.caisse(base + Vector3(-1.1, 0, -0.2), Vector3(0.8, 0.55, 0.55), 0.6)
	for k in 4:
		var p := sol_en(102.0 + k * 1.0, 5.2 + (k % 2) * 0.3)
		decor.tonneau(p, 1.0)
		decor.solide_rond(p + Vector3(0, 0.5, 0), 0.38, 1.0)
	decor.tonneau(sol_en(103.0, 4.6) + Vector3(0, 1.0, 0.0) * 0.0, 0.9)
	decor.solide_rond(sol_en(103.0, 4.6) + Vector3(0, 0.45, 0), 0.34, 0.9)
	for c in [[99.0, -5.4], [101.6, -5.5], [95.0, 5.0], [104.0, -5.3], [106.0, 3.0]]:
		var p := sol_en(c[0], c[1])
		decor.sac(p, _r(0.9, 1.3))
	# table, tabourets, plats, bougie (lumière chaude) ; carte étalée
	var tp := sol_en(95.0, 3.3)
	decor.table(tp, 0.4)
	decor.tabouret(tp + Vector3(-0.8, 0, 0.6))
	decor.tabouret(tp + Vector3(0.8, 0, -0.5))
	decor.bougie(tp + Vector3(0.0, 0.8, 0.0))
	decor.solide(tp + Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 0.8))
	# râteliers d'armes contre la paroi droite
	decor.ratelier(sol_en(100.0, 5.45), PI * 0.5)
	decor.ratelier(sol_en(97.0, 5.45), PI * 0.5)
	# butin : deux coffres ouverts, tas de pièces, gobelets
	var cb := sol_en(106.0, -3.2)
	decor.coffre_ouvert(cb, 0.3)
	decor.coffre_ouvert(sol_en(106.8, -4.4), -0.4)
	decor.pieces(cb + Vector3(0.9, 0, 0.5), 18, 0.35)
	decor.pieces(sol_en(105.0, -4.8), 12, 0.3)
	decor.urne(sol_en(103.5, -5.2), 0.9)
	# trophées de crânes sur piques à l'entrée du camp, ossements, armes au sol
	decor.trophee(sol_en(93.4, -3.8), 1.9, 0.5)
	decor.trophee(sol_en(93.2, 3.7), 1.7, -0.6)
	decor.trophee(sol_en(94.0, 1.0), 1.5, 3.0)
	decor.os_tas(sol_en(98.0, 1.8), 6, 0.6)
	decor.os_tas(sol_en(102.4, -1.4), 4, 0.5)
	decor.arme(sol_en(98.8, -1.2), 0.9)
	decor.arme(sol_en(101.5, 1.6), 3.9)
	decor.crane(sol_en(99.0, 1.5), 2.0)
	decor.crane(sol_en(101.0, -2.0), 0.6)
	decor.crane(sol_en(103.5, 1.2), 4.0)
	# appliques (bois résineux au mur) et rochers d'éboulis
	decor.applique(_mur(95.0, -1.0), droite(95.0), sol_en(95.0, -3.0).y + 2.0, 5.0, 1.8, true)
	decor.applique(_mur(105.0, 1.0), -droite(105.0), sol_en(105.0, 3.0).y + 2.0, 5.0, 1.8, true)
	_pointes(92.5, 107.5, -5.5, 5.5, 14, "c_strate_suie", 0.25, 1.0, 0.0, false)
	for k in 5:
		var s := _r(93.0, 106.0)
		var cote := 1.0 if k % 2 == 0 else -1.0
		decor.rocher("c_strate_suie", sol_en(s, cote * _r(5.4, 6.2)), _r(0.45, 0.9), _r(0.4, 0.9), rng.randi(), 0.0, true, 6)

## Goulet du camp : portique de bois et rideau de peaux fendu (on passe par la fente, sans collision) : il ferme la vue
## sur la salle des cristaux, dont le bleu se découpait comme un portail depuis le camp.
func _rideau(s: float) -> void:
	var T := tangente(s)
	var lacet := atan2(T.x, T.z)
	var wl := _interp(CLES, s, 2)
	var wr := _interp(CLES, s, 3)
	var haut := _interp(CLES, s, 4)
	var bas := sol_en(s, 0.0)
	var d := droite(s)
	for sg in [-1.0, 1.0]:
		var w: float = wr if sg > 0.0 else wl
		var pied: Vector3 = bas + d * sg * (w - 0.12)
		decor.boite("bois", pied + Vector3(0, (haut - 0.3) * 0.5, 0), Vector3(0.24, haut - 0.3, 0.24), lacet)
		# panneau de peaux : de la paroi jusqu'à 0,25 m AU-DELÀ de l'axe, les deux panneaux décalés en profondeur : pas de jour
		# direct, on passe en les traversant (aucune collision)
		var larg := w - 0.12 + 0.25
		var centre: Vector3 = bas + d * sg * ((w - 0.12 - 0.25) * 0.5 + 0.0) + T * sg * 0.1
		decor.boite("peau", centre + Vector3(0, 1.65, 0), Vector3(larg, 3.3, 0.07), lacet)
		decor.boite("peau", centre + T * sg * 0.07 + Vector3(0, 1.4, 0), Vector3(larg * 0.9, 2.8, 0.05), lacet + sg * 0.04)
	var centre_h: Vector3 = bas + d * (wr - wl) * 0.5
	decor.boite("bois", centre_h + Vector3(0, haut - 0.5, 0), Vector3(wl + wr, 0.22, 0.24), lacet)
	decor.boite("peau", centre_h + Vector3(0, haut - 1.05, 0), Vector3(wl + wr - 0.3, 0.9, 0.07), lacet)

func _anneau_proche(s: float) -> Dictionary:
	var best: Dictionary = _anneaux[0]
	for r: Dictionary in _anneaux:
		if absf(float(r["s"]) - s) < absf(float(best["s"]) - s):
			best = r
	return best

## Point de la paroi (repère local) à l'abscisse s, côté sign (+1 droite, -1 gauche), à hauteur de torche.
func _mur(s: float, sign_: float) -> Vector3:
	var w := _interp(CLES, s, 3 if sign_ > 0 else 2) * 0.97
	var p := sol_en(s, sign_ * w)
	return Vector3(p.x, 0, p.z) - droite(s) * sign_ * 0.04

func _fond() -> void:
	# amas de cristaux sur le sol et les parois : prismes hexagonaux émissifs (macro : monolithe, méso : amas, micro : éclats)
	var mono := sol_en(120.0, -0.5)
	for k in 5:
		decor.cristal(mono + Vector3(_r(-0.5, 0.5), -0.1, _r(-0.5, 0.5)), _r(0.35, 0.6), _r(2.6, 4.6), rng.randi(), 0.35)
	for c in [[114.5, -3.4], [116.5, 3.2], [118.0, -4.0], [121.5, 3.0], [112.5, 1.2], [122.5, -2.4], [117.0, 0.2], [119.5, 2.0]]:
		var p := sol_en(c[0], c[1])
		var n := rng.randi_range(4, 7)
		for j in n:
			decor.cristal(p + Vector3(_r(-0.6, 0.6), -0.08, _r(-0.6, 0.6)), _r(0.1, 0.32), _r(0.7, 2.4), rng.randi(), 0.7)
	# cristaux sortant des parois et du plafond : amas posés sur les sommets de la coque, penchés vers l'intérieur
	for k in 9:
		var r: Dictionary = _anneau_proche(_r(112.5, 123.0))
		var vtx: int = [3, 4, 5, 6, 7, 11, 12, 13, 14, 15][rng.randi() % 10]
		var pv: Vector3 = (r["pts"] as Array)[vtx]
		var vers_centre: Vector3 = ((r["P"] as Vector3) + Vector3(0, float(r["h"]) * 0.4, 0) - pv).normalized()
		for j in rng.randi_range(2, 4):
			decor.cristal(pv + vers_centre * 0.05, _r(0.1, 0.28), _r(0.6, 2.0), rng.randi(), 0.5, (vers_centre + Vector3(0, 0.15, 0)).normalized())
	_pointes(111.0, 123.0, -5.0, 5.0, 26, "c_roche_glace", 0.35, 2.4, 0.95, false)
	_pointes(112.0, 123.0, -5.0, 5.0, 12, "c_roche_glace", 0.25, 1.2, 0.95, true, 1.3)
	for k in 6:
		var s := _r(111.0, 122.0)
		var cote := 1.0 if k % 2 == 0 else -1.0
		var w := _interp(CLES, s, 3 if cote > 0 else 2)
		decor.rocher("c_roche_glace", sol_en(s, cote * w * _r(0.6, 0.85)), _r(0.4, 0.9), _r(0.4, 0.9), rng.randi(), 0.9, true, 6)
	# micro : cairn et coffre fermé d'un explorateur, lame plantée
	decor.coffre(sol_en(121.0, 3.1), -0.5)
	decor.os_tas(sol_en(121.2, 2.0), 5, 0.5)
	decor.arme(sol_en(118.6, 1.6), 2.2)
	decor.crane(sol_en(119.0, -1.6), 2.5)

# ------------------------------------------------------------------ lumières, rais, neige
const FEU_C := Color(1.0, 0.56, 0.24)
const JOUR_C := Color(0.74, 0.86, 1.0)
const GLACE_C := Color(0.52, 0.74, 1.0)
const MOUSSE_C := Color(0.56, 0.8, 0.68)

func _l(s: float, lat: float, haut: float, c: Color, e: float, portee: float, att := 1.6, vacille := false) -> void:
	var p := sol_en(s, lat) + Vector3(0, haut, 0)
	decor.lumiere(p, c, e, portee, att, vacille)
	nb_lumieres += 1

func _lumieres() -> void:
	# entrée : jour froid (2 lumières)
	_l(3.0, 0.0, 4.2, JOUR_C, 2.6, 13.0, 1.3)
	_l(10.0, 0.0, 2.6, Color(0.7, 0.82, 1.0), 1.5, 8.5, 1.5)
	# boyau : vert mousse (2)
	_l(24.0, 0.5, 0.9, MOUSSE_C, 1.5, 6.0)
	_l(31.0, -0.3, 1.0, MOUSSE_C, 1.4, 6.0)
	# caverne : bleu glacial sur le lac, jour sous la faille, mousse près du boyau (5 + 1 projecteur)
	_l(38.5, 0.8, 1.8, MOUSSE_C, 1.2, 7.0)
	_l(43.0, -5.0, 2.2, GLACE_C, 1.7, 10.5)
	_l(58.0, -6.0, 2.2, GLACE_C, 1.7, 10.5)
	_l(63.0, 0.5, 2.0, GLACE_C, 1.5, 8.0)
	var haut_f := plafond_en(50.0, 2.0)
	decor.lumiere(haut_f + Vector3(0, 3.0, 0), Color(0.82, 0.9, 1.0), 1.6, 11.0, 1.4, false)
	nb_lumieres += 1
	var bas_f := sol_en(50.0, -5.2)
	decor.projecteur(haut_f + Vector3(0.0, 4.5, 0.0), bas_f, Color(0.85, 0.93, 1.0), 6.0, 30.0, 17.0)
	decor.rai_oblique(haut_f + Vector3(0.0, 5.2, 0.0), bas_f + Vector3(0, 0.05, 0), 1.9, 3.8)
	decor.carte("flaque_g", bas_f + Vector3(0, 0.04, 0), Vector3.UP, 6.5, 6.5)
	# galerie : vert-bleu des mousses, torche des bandits au loin (3)
	_l(71.0, 0.4, 1.4, Color(0.4, 0.85, 0.7), 1.4, 6.5)
	_l(80.0, -0.4, 1.4, Color(0.38, 0.8, 0.72), 1.3, 6.5)
	_l(89.5, 0.0, 1.8, Color(1.0, 0.6, 0.28), 1.5, 6.5, 1.7, true)
	# campement : feu + deux appliques (lumières déjà posées par applique) + bougie (table)
	_l(100.0, 0.4, 1.0, FEU_C, 4.6, 13.0, 1.4, true)
	# fond : bleu glacial autour des cristaux (3)
	_l(115.0, 0.5, 2.0, GLACE_C, 2.4, 8.5)
	_l(118.5, -2.0, 2.4, Color(0.36, 0.62, 1.0), 2.4, 9.0)
	_l(122.0, 1.5, 2.0, Color(0.5, 0.8, 1.0), 2.0, 8.0)

func _neige_soufflee() -> void:
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 4.5
	p.position = sol_en(5.0, 0.0) + Vector3(0, 2.0, 0)
	p.visibility_aabb = AABB(Vector3(-9, -4, -12), Vector3(18, 12, 24))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(6.0, 2.8, 1.0)
	pm.direction = Vector3(0.1, -0.12, -1.0)
	pm.spread = 22.0
	pm.initial_velocity_min = 2.4
	pm.initial_velocity_max = 4.6
	pm.gravity = Vector3(0, -0.2, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_noise_scale = 2.0
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.albedo_color = Color(0.95, 0.98, 1.0, 0.9)
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mq.disable_fog = true
	q.material = mq
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)

# ------------------------------------------------------------------ vie, ambiance, interface avec le monde
func _process(dt: float) -> void:
	_t += dt
	if decor != null:
		decor.vaciller(_t)
	_torche()

## Sous terre, la flamme de la torche tenue devient le sprite pixel art (comme dans la crypte, sans toucher à tertre.gd).
func _torche() -> void:
	if joueur == null or not is_instance_valid(joueur):
		return
	var mains: Node = joueur.get("mains")
	if mains == null or mains.porte_torche == null:
		return
	if _flamme_pixel == null:
		_flamme_pixel = decor.flamme_sur(mains.porte_torche, Vector3(0, 0.53, 0.0), 0.5)
	_flamme_pixel.visible = mains.torche_lumiere.visible
	for i in mains.flammes.size():
		if i != 3:
			mains.flammes[i].visible = false

## Réglages d'environnement propres à la grotte (après `_sous_terre(true)` du monde).
func ambiance(env: Environment) -> void:
	env.ambient_light_color = Color(0.5, 0.58, 0.72)
	env.ambient_light_energy = 1.15
	env.fog_light_color = Color(0.05, 0.08, 0.13)
	env.fog_density = 0.012

## Points du sol (monde) à 1 m d'écart le long du parcours, pour le test de marche.
func points_test() -> Array[Vector3]:
	var res: Array[Vector3] = []
	var s := 1.0
	while s < LONGUEUR - 2.0:
		res.append(to_global(sol_en(s, 0.0)) + Vector3(0, 0.1, 0))
		s += 1.0
	return res
