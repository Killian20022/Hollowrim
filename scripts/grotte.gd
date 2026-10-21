class_name Grotte
extends Node3D
## Générateur de grottes EN ARBRE (kit « grotte »). Une grotte = des données (GrotteDonnees : branches, profils, jonctions, zones) ;
## ce script ne contient plus aucune table propre à un lieu.
##
## Construction : chaque BRANCHE est un TUBE de 18 sommets par anneau le long d'une ligne médiane (spline de points de passage), dont
## les anneaux changent de largeur, de hauteur, de relief (bruit facetté) et de profil. Les anneaux sont fermés et reliés : aucun trou.
## JONCTIONS ÉTANCHES (fourche / confluent) : le tube parent s'arrête sur un anneau de 18 sommets ; chaque branche enfant PREND UNE
## MOITIÉ de cet anneau (sommets 0-9 à droite, 0 et 9-17 à gauche) et replie l'autre moitié sur la verticale du centre (le « nez » du
## pilier qui sépare les deux galeries) ; puis sa largeur intérieure s'ouvre peu à peu (pilier de 2 x PILIER m). La branche enfant
## démarre dans l'axe du parent (même tangente) : les anneaux restent presque parallèles, pas de recoupement des parois. Un confluent
## (deux branches qui rejoignent un tube) est la même opération prise à l'envers.
## Chaque facette est plate (normale propre), colorée aux sommets (occlusion ambiante peinte) et porte un masque de neige / glace /
## mousse que le shader compare à un seuil de texture. La collision est le maillage exact (trimesh).
##
## Le décor vient de GrotteModules (thème x rôle, une graine par zone) ; les points d'accroche du gameplay (ennemis, coffres, ressources,
## interactions, mécanismes, lieux) sont listés dans `accroches` et animés par GrotteJeu.
##
## Description (règle Lead Technical Artist) :
##  1. Murs / Structure : coque facettée à strates, ruptures de pente, marches naturelles (palier 32 cm, contremarche ≤ 35°),
##     stalagmites / stalactites / colonnes comme repères, étais de bois, parois couvertes de givre ou de mousse, piliers de jonction,
##     dalles de corniche praticables (rampe d'accès), îlot du lac.
##  2. Mobilier : voir GrotteModules (rails, chariots, filons, champignons, campement, coffres, restes de l'expédition, cristaux).
##  3. Éclairage : OmniLight3D courtes sans ombre, quelques-unes par zone, teinte tirée dans une plage par la graine de la zone ;
##     GrotteJeu n'allume que les plus proches. Jour froid à l'entrée, rai oblique + projecteur sous la faille, ambiante bleu-gris.

const NB := 18
const TUILE_COQUE := 2.0           # mètres par tuile de 128 px = 64 texels/m sur les parois (32 visés : jamais moins)
const Q := 0.32                    # hauteur d'une marche naturelle (m)
const PILIER := 1.1                # demi-épaisseur maximale du pilier entre deux galeries (m)
const ZONE_PINCE := 9.0            # longueur sur laquelle une jonction ouvre / ferme sa moitié intérieure (m)
const AO := [1.0, 0.92, 0.7, 0.8, 0.9, 0.95, 0.92, 0.82, 0.74, 0.7, 0.74, 0.82, 0.92, 0.95, 0.9, 0.8, 0.7, 0.92]

var def: Dictionary = {}
var decor: GrotteDecor
var corps: StaticBody3D
var joueur: Node
var rng := RandomNumberGenerator.new()
var _bruit := FastNoiseLite.new()
var _fixes := {}
var _idx := {}                            # cellule 2 m -> Array d'indices de triangles de la coque
var _t := 0.0
var _flamme_pixel: MeshInstance3D
var temps_ms := 0
var nb_lumieres := 0
var etapes := {}
var lac_y := -4.7
var br := {}                              # id -> branche d'exécution (Dictionary)
var ordre: Array = []
var _anneaux: Array = []                  # tous les anneaux de toutes les branches (tests)
var accroches: Array = []                 # points d'accroche du gameplay (voir _accroches_zone)
var corniches := {}                       # id -> { "top": y, "b": branche, ... }
var zones := {}                           # id -> données de la zone
var projecteurs: Array = []
var reserves: Array = []                  # zones de passage à garder libres de décor solide : [branche, s0, s1, lat0, lat1]
const VOIE_LIBRE := 0.55                  # demi-largeur du couloir central réservé le long de chaque branche (m)

## Crée la grotte sous le monde. `parent` : le monde. `def_` : table de données (défaut : le repaire de Hrafn).
static func creer(parent: Node3D, joueur_: Node = null, def_: Dictionary = {}) -> Grotte:
	var g := nouvelle(joueur_, def_)
	parent.add_child(g)
	g.construire()
	return g

## Grotte non construite et hors de l'arbre : `construire()` peut tourner dans un fil d'exécution (voir GrotteAcces).
static func nouvelle(joueur_: Node = null, def_: Dictionary = {}) -> Grotte:
	var g := Grotte.new()
	g.joueur = joueur_
	g.def = def_ if not def_.is_empty() else GrotteDonnees.repaire_hrafn()
	g.position = g.def["pos_monde"]
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

func longueur(id: String) -> float:
	return float((br[id] as Dictionary)["L"])

func y_net(b: Dictionary, s: float) -> float:
	var lin := _interp(b["profil"], s, 1, false)
	var tz := _interp(b["marches"], s, 1, false)
	if tz < 0.001:
		return lin
	var u := lin / Q
	var f := u - floorf(u)
	var terrasse := (floorf(u) + _lisse(clampf(f / 0.55, 0.0, 1.0))) * Q
	return lerpf(lin, terrasse, tz)

## Spline de Catmull-Rom par les points de passage, tangentes d'extrémité imposées, rééchantillonnée tous les 0,1 m.
static func _spline(wp: Array, t0: Vector2, t1: Vector2) -> PackedVector2Array:
	var P: Array = [wp[0] - t0 * 8.0]
	P.append_array(wp)
	P.append(wp[wp.size() - 1] + t1 * 8.0)
	var dense: Array = []
	for i in range(1, P.size() - 2):
		var p0: Vector2 = P[i - 1]
		var p1: Vector2 = P[i]
		var p2: Vector2 = P[i + 1]
		var p3: Vector2 = P[i + 2]
		for k in 40:
			var t := float(k) / 40.0
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	dense.append(wp[wp.size() - 1])
	var out := PackedVector2Array()
	out.append(dense[0])
	var reste := 0.1
	var a: Vector2 = dense[0]
	for i in range(1, dense.size()):
		var b: Vector2 = dense[i]
		var seg := a.distance_to(b)
		while seg >= reste and seg > 0.0:
			a = a.lerp(b, reste / seg)
			out.append(a)
			seg = a.distance_to(b)
			reste = 0.1
		reste -= seg
		a = b
	return out

func xz(id: String, s: float) -> Vector2:
	return _xz(br[id], s)

func _xz(b: Dictionary, s: float) -> Vector2:
	var ch: PackedVector2Array = b["chemin"]
	var f := clampf(s, 0.0, float(b["L"])) * 10.0
	var i := mini(int(f), ch.size() - 2)
	return ch[i].lerp(ch[i + 1], f - i)

func tang(id: String, s: float) -> Vector3:
	return _tang(br[id], s)

func _tang(b: Dictionary, s: float) -> Vector3:
	var a := _xz(b, s - 0.25)
	var c := _xz(b, s + 0.25)
	var d := (c - a).normalized()
	return Vector3(d.x, 0.0, d.y)

func droite(id: String, s: float) -> Vector3:
	return _tang(br[id], s).cross(Vector3.UP)

func _n(b: Dictionary, s: float, k: int, ch: float) -> float:
	var o: float = b["bn"]
	return _bruit.get_noise_2d(s * 0.5 + ch * 13.7 + o, float(k) * 5.3 + o * 0.37)

func _courbe(tab: Variant, s: float) -> float:
	if not (tab is Array) or (tab as Array).size() < 4:
		return 0.0
	var a: Array = tab
	return _lisse(clampf((s - float(a[0])) / maxf(float(a[1]) - float(a[0]), 0.001), 0.0, 1.0)) * (1.0 - _lisse(clampf((s - float(a[2])) / maxf(float(a[3]) - float(a[2]), 0.001), 0.0, 1.0)))

func lac_f(b: Dictionary, s: float) -> float:
	return _courbe(b["d"].get("lac", null), s)

func faille_f(b: Dictionary, s: float) -> float:
	return _courbe(b["d"].get("faille", null), s)

## Demi-largeurs (gauche, droite) à l'abscisse s, variante et pincement des jonctions compris.
func demi_l(id: String, s: float) -> Vector2:
	var b: Dictionary = br[id]
	var m := _mult_larg(b, s)
	var wl := _interp(b["profil"], s, 2) * m
	var wr := _interp(b["profil"], s, 3) * m
	return _pince_l(b, s, _xz(b, s), _tang(b, s), wl, wr)

func _mult_larg(b: Dictionary, s: float) -> float:
	var m: float = b["m_larg"]
	var d: Dictionary = b["d"]
	var f := 1.0
	if d.has("pince_deb") or s < 0.001:
		f = minf(f, _lisse(clampf(s / ZONE_PINCE, 0.0, 1.0)))
	if d.has("pince_fin") or s > float(b["L"]) - 0.001:
		f = minf(f, _lisse(clampf((float(b["L"]) - s) / ZONE_PINCE, 0.0, 1.0)))
	return lerpf(1.0, m, f)

# ------------------------------------------------------------------ anneaux
## Pincement d'une jonction : largeur intérieure de la branche près du parent (le pilier entre les deux galeries).
func _pince_l(b: Dictionary, s: float, c2: Vector2, T: Vector3, wl: float, wr: float) -> Vector2:
	var d: Dictionary = b["d"]
	for fin in [false, true]:
		var cle := "pince_fin" if fin else "pince_deb"
		if not d.has(cle):
			continue
		var dist: float = (float(b["L"]) - s) if fin else s
		if dist >= ZONE_PINCE:
			continue
		var pr: Dictionary = b["pr_fin"] if fin else b["pr_deb"]
		var cote: float = float((d[cle] as Dictionary)["cote"])
		var F: Vector3 = pr["P"]
		var Rp: Vector3 = pr["R"]
		var Tp: Vector3 = pr["T"]
		var xc := (c2.x - F.x) * Rp.x * cote + (c2.y - F.z) * Rp.z * cote
		var cphi := maxf(absf(T.x * Tp.x + T.z * Tp.z), 0.35)
		var p := minf(PILIER * smoothstep(0.0, 5.0, dist), 0.55 * maxf(xc, 0.0))
		var u := maxf((xc - p) / cphi, 0.05)
		if cote > 0.0:
			wl = minf(wl, u)
		else:
			wr = minf(wr, u)
	return Vector2(wl, wr)

## Un anneau : 18 sommets (sol au centre, paroi droite, plafond, paroi gauche) à l'abscisse s de la branche.
func _anneau(b: Dictionary, s: float) -> Dictionary:
	var prof: Array = b["profil"]
	var y0 := y_net(b, s)
	var mult := _mult_larg(b, s)
	var wl := _interp(prof, s, 2) * mult
	var wr := _interp(prof, s, 3) * mult
	var h := _interp(prof, s, 4)
	var jit := _interp(prof, s, 5) * float(b["m_relief"])
	var amp := _interp(prof, s, 6)
	var lam := lac_f(b, s)
	var kap := faille_f(b, s)
	var T := _tang(b, s)
	var R := T.cross(Vector3.UP)
	var c2 := _xz(b, s)
	var wlr := _pince_l(b, s, c2, T, wl, wr)
	wl = wlr.x
	wr = wlr.y
	var P := Vector3(c2.x, y0, c2.y)
	var a: Array = []
	var bb: Array = []
	a.resize(NB)
	bb.resize(NB)
	a[0] = 0.0
	bb[0] = 0.0
	var lac_b := lac_y - y0
	for cote in 2:
		var sg := 1.0 if cote == 0 else -1.0
		var w := wr if cote == 0 else wl
		var sc := clampf(w / 1.3, 0.04, 1.0)          # le relief latéral s'éteint quand la paroi se replie sur le nez d'un pilier
		var ch := float(cote) * 7.0
		var ids: Array = [1, 2, 3, 4, 5, 6, 7, 8] if cote == 0 else [17, 16, 15, 14, 13, 12, 11, 10]
		var jf := 0.04 + 0.03 * jit
		# sol proche, pied de paroi
		var a1 := 0.45 * w * (1.0 + 0.1 * _n(b, s, ids[0], ch) * sc)
		var b1 := jf * _n(b, s, ids[0] + 20, ch)
		var a2 := 0.93 * w + 0.3 * jit * _n(b, s, ids[1], ch) * sc
		var b2 := 0.14 + 0.1 * absf(_n(b, s, ids[1] + 20, ch)) * (1.0 + jit)
		if cote == 1 and lam > 0.0:
			b1 = lerpf(b1, lac_b, lam)
			b2 = lerpf(b2, lac_b + 0.22, lam)
			a2 = 0.95 * w
		a[ids[0]] = sg * a1
		bb[ids[0]] = b1
		a[ids[1]] = sg * a2
		bb[ids[1]] = b2
		# parois : 4 sommets, décalage alterné (strates : surplombs et retraits)
		var fr := [0.2, 0.42, 0.64, 0.84]
		var alt := [1.0, -0.45, 1.0, -0.45]
		for j in 4:
			var id: int = ids[2 + j]
			bb[id] = b2 + fr[j] * (h * 0.93 - b2) + jit * 0.3 * _n(b, s, id + 40, ch)
			a[id] = sg * (w * (1.0 + 0.06 * jit * _n(b, s, id, ch) * sc) + amp * alt[j] * sc + jit * 0.55 * _n(b, s, id + 60, ch) * sc)
		# épaule et sommet du plafond (la faille remplace ces trois sommets par un conduit étroit)
		var e1 := lerpf(w * 0.74, 1.3, kap)
		var e2 := lerpf(w * 0.36, 0.9, kap)
		a[ids[6]] = sg * e1
		bb[ids[6]] = lerpf(0.93 * h + jit * 0.4 * _n(b, s, ids[6] + 80, ch), h * 0.99, kap)
		a[ids[7]] = sg * e2
		bb[ids[7]] = lerpf(h + jit * 0.5 * _n(b, s, ids[7] + 80, ch), h + 6.2, kap)
	a[9] = 0.0
	bb[9] = lerpf(h + jit * 0.45 * _n(b, s, 9, 3.0) + 1.4 * jit * maxf(_n(b, s, 29, 5.0), 0.0), h + 7.0, kap)
	# la faille penche vers la droite en montant (rai oblique)
	for id in [7, 8, 9, 10, 11]:
		a[id] += kap * 3.0
	var pts: Array = []
	for k in NB:
		pts.append(P + R * float(a[k]) + Vector3.UP * float(bb[k]))
	return {"s": s, "y": y0, "pts": pts, "R": R, "T": T, "h": h, "wl": wl, "wr": wr, "lam": lam, "kap": kap, "P": P, "b": b["id"], "forcee": false}

## Anneau d'extrémité d'une branche raccordée à une jonction : la moitié extérieure est celle du parent (sommets partagés), la moitié
## intérieure est repliée sur le segment vertical (sol → plafond) du centre du parent : le nez du pilier.
func _forcer(b: Dictionary, fin: bool) -> Dictionary:
	var pr: Dictionary = b["pr_fin"] if fin else b["pr_deb"]
	var cle := "pince_fin" if fin else "pince_deb"
	var cote: float = float(((b["d"] as Dictionary)[cle] as Dictionary)["cote"])
	var pts: Array = (pr["pts"] as Array).duplicate()
	var p0: Vector3 = pts[0]
	var p9: Vector3 = pts[9]
	var interieur: Array = range(10, 18) if cote > 0.0 else range(1, 9)
	for id: int in interieur:
		var f := float(id - 9) / 9.0 if cote > 0.0 else float(9 - id) / 9.0
		pts[id] = p9.lerp(p0, f)
	var r: Dictionary = pr.duplicate()
	r["pts"] = pts
	r["s"] = float(b["L"]) if fin else 0.0
	r["forcee"] = true
	r["b"] = b["id"]
	return r

func _liste_s(b: Dictionary) -> Array:
	var d: Dictionary = b["d"]
	var L: float = b["L"]
	var res: Array = [0.0]
	var cles_s: Array = []
	for c: Array in b["profil"]:
		if float(c[0]) < L:
			cles_s.append(float(c[0]))
	for k in ["lac", "faille"]:
		if d.has(k):
			for v: float in (d[k] as Array):
				cles_s.append(v + 0.0)
	var pas: Array = d.get("pas", [[0.0, 2.0]])
	var last := 0.0
	var s := 0.0
	var etat_prec := false
	while s < L - 0.001:
		var s_pre := s
		s = minf(s + 0.1, L)
		var pente := absf(y_net(b, s) - y_net(b, s_pre)) / 0.1
		var etat := pente > 0.14
		var ds := 2.0
		for p: Array in pas:
			if s >= float(p[0]):
				ds = float(p[1])
		if d.has("pince_deb") and s < ZONE_PINCE:
			ds = minf(ds, 0.9)
		if d.has("pince_fin") and s > L - ZONE_PINCE:
			ds = minf(ds, 0.9)
		var emet := (s - last) >= ds
		for cs: float in cles_s:
			if s_pre < cs and s >= cs and (s - last) > 0.05:
				emet = true
		if etat != etat_prec and (s - last) >= 0.35:
			emet = true
		etat_prec = etat
		if s >= L - 0.001:
			emet = true
		if emet:
			res.append(s)
			last = s
	return res

# ------------------------------------------------------------------ matière d'une facette
## [nom de matière, masque, assombrissement]
func _matiere(b: Dictionary, s: float, n: Vector3, hrel: float, k: int, lam: float) -> Array:
	var style := "nu"
	for m: Array in (b["d"] as Dictionary).get("matieres", [[999.0, "nu"]]):
		style = String(m[1])
		if s < float(m[0]):
			break
	var sol_ := n.y > 0.55
	var plaf := n.y < -0.45
	match style:
		"neige":
			var fade := 1.0 - _lisse(clampf((s - 7.0) / 10.5, 0.0, 1.0)) * 0.75
			if sol_:
				return ["c_sol_neige", 1.15 * fade + 0.1, 1.0]
			if plaf:
				return ["c_roche_neige", 0.12 * fade, 1.0]
			return ["c_roche_neige", clampf(0.2 + 0.85 * (n.y + 0.3), 0.0, 1.0) * fade, 1.0]
		"mousse":
			if sol_:
				return ["c_sol_mousse", 0.4, 1.0]
			if plaf:
				return ["c_roche_nu", 0.0, 1.0]
			return ["c_roche_mousse", 0.42 if hrel < 1.3 else 0.1, 1.0]
		"glace":
			if k == 16 and lam > 0.5:
				return ["c_glace", 0.0, 1.0]
			if sol_:
				return ["c_sol_glace", 0.85, 1.0]
			if plaf:
				return ["c_roche_glace", 0.25, 1.0]
			return ["c_roche_glace", 0.62 if hrel < 3.0 else 0.4, 1.0]
		"strate":
			if sol_:
				return ["c_sol_mousse" if hrel < 0.5 else "c_sol_nu", 0.2, 1.0]
			if plaf:
				return ["c_strate_mousse", 0.08, 1.0]
			return ["c_strate_mousse", 0.42 if hrel < 1.2 else 0.12, 1.0]
		"camp":
			if sol_:
				return ["c_sol_camp", 0.0, 1.0]
			return ["c_strate_suie", 0.0, 0.94]
		"goulot":      # roche nue, givre léger (le bleu des cristaux ne doit pas « fuir » dans le camp)
			if sol_:
				return ["c_sol_nu", 0.2, 1.0]
			return ["c_roche_nu", 0.0, 1.0]
		"cristaux":
			if sol_:
				return ["c_sol_glace", 0.9, 1.0]
			if plaf:
				return ["c_roche_glace", 0.85, 1.0]
			return ["c_roche_glace", 0.95, 1.0]
	if sol_:
		return ["c_sol_nu", 0.1, 1.0]
	return ["c_roche_nu", 0.0, 1.0]

func _tri_coque(a: Vector3, b: Vector3, c: Vector3, ka: int, kb: int, kc: int, ra: Dictionary, rb: Dictionary, k_seg: int, ref: Vector3, br_: Dictionary) -> void:
	var n := (b - a).cross(c - a).normalized()
	var ct := (a + b + c) / 3.0
	if n.dot(ref - ct) < 0.0:
		n = -n
	var s: float = (float(ra["s"]) + float(rb["s"])) * 0.5
	var hrel: float = ct.y - (float(ra["y"]) + float(rb["y"])) * 0.5
	var lam: float = (float(ra["lam"]) + float(rb["lam"])) * 0.5
	var nom := "c_roche_nu"
	var masque := 0.0
	var sombre := 1.0
	var kap_a: float = ra["kap"]
	var kap_b: float = rb["kap"]
	if kap_a > 0.85 and kap_b > 0.85 and (k_seg == 8 or k_seg == 9):
		nom = "ciel"
	else:
		var m := _matiere(br_, s, n, hrel, k_seg, lam)
		nom = m[0]
		masque = m[1]
		sombre = m[2]
		masque *= 0.8 + 0.4 * GrotteDecor.hash2(ct.x * 0.7, ct.z * 1.3 + ct.y)
	if nom == "ciel":
		var cl := Color(1, 1, 1, 0)
		decor.facette(nom, a, b, c, ref, [cl, cl, cl], true, 4.0, true)
		return
	var etroit := minf(float(ra["wl"]) + float(ra["wr"]), float(rb["wl"]) + float(rb["wr"]))
	var cols: Array = []
	for k in [ka, kb, kc]:
		var ao: float = AO[k] * (0.93 + 0.07 * GrotteDecor.hash2(float(k) * 3.7, s * 5.1 + float(ra["s"]))) * sombre
		if etroit < 5.5:
			ao *= 0.9
		cols.append(GrotteDecor.col(ao, masque))
	_subdiviser(nom, a, b, c, ref, cols, 1)      # niveau constant : deux niveaux différents côte à côte laisseraient des fissures (T)

## Relief méso : le triangle est coupé en 4 (facettes de 0,4 à 1,5 m) ; chaque milieu d'arête est déplacé d'un petit vecteur
## qui ne dépend que de sa POSITION (deux triangles voisins déplacent donc le même point : aucune fissure). Le masque de
## neige / glace / mousse reçoit aussi un bruit au milieu : taches nettes plutôt que blocs. Densité de texture : tuile de 2 m.
func _subdiviser(nom: String, a: Vector3, b: Vector3, c: Vector3, ref: Vector3, cols: Array, niveau: int, amp := 1.0) -> void:
	if niveau <= 0:
		decor.facette(nom, a, b, c, ref, cols, true, TUILE_COQUE, true)
		return
	var m0 := _milieu(a, b, amp)
	var m1 := _milieu(b, c, amp)
	var m2 := _milieu(c, a, amp)
	var c0: Color = cols[0]
	var c1: Color = cols[1]
	var c2: Color = cols[2]
	var q0 := _couleur_milieu(c0, c1, a, b)
	var q1 := _couleur_milieu(c1, c2, b, c)
	var q2 := _couleur_milieu(c2, c0, c, a)
	if niveau == 1:        # cas courant : les quatre sous-triangles sont posés directement (pas de récursion ni de tableaux)
		decor.facette(nom, a, m0, m2, ref, [c0, q0, q2], true, TUILE_COQUE, true)
		decor.facette(nom, m0, b, m1, ref, [q0, c1, q1], true, TUILE_COQUE, true)
		decor.facette(nom, m2, m1, c, ref, [q2, q1, c2], true, TUILE_COQUE, true)
		decor.facette(nom, m0, m1, m2, ref, [q0, q1, q2], true, TUILE_COQUE, true)
		return
	_subdiviser(nom, a, m0, m2, ref, [c0, q0, q2], niveau - 1, amp)
	_subdiviser(nom, m0, b, m1, ref, [q0, c1, q1], niveau - 1, amp)
	_subdiviser(nom, m2, m1, c, ref, [q2, q1, c2], niveau - 1, amp)
	_subdiviser(nom, m0, m1, m2, ref, [q0, q1, q2], niveau - 1, amp)

## Milieu d'arête déplacé (ne dépend que de la POSITION : les deux triangles voisins déplacent le même point).
func _milieu(p: Vector3, q: Vector3, amp: float) -> Vector3:
	var mid := (p + q) * 0.5
	if _fixes.has(p) and _fixes.has(q):       # arête d'un anneau d'extrémité ou de jonction (raccord) : pas de déplacement
		return mid
	var l := p.distance_to(q)
	var d := Vector3(GrotteDecor.hash2(mid.x * 3.1, mid.y * 1.7 + mid.z) - 0.5, GrotteDecor.hash2(mid.y * 2.3, mid.z * 1.9 + mid.x) - 0.5, GrotteDecor.hash2(mid.z * 2.9, mid.x * 1.3 + mid.y) - 0.5)
	return mid + Vector3(d.x, d.y * 0.35, d.z) * (0.14 * minf(l, 2.4) * amp)

## Couleur au milieu d'une arête (bruit au milieu : taches nettes de neige / glace / mousse plutôt que blocs).
func _couleur_milieu(c0: Color, c1: Color, p: Vector3, q: Vector3) -> Color:
	var mid := (p + q) * 0.5
	var cm := c0.lerp(c1, 0.5)
	cm.a = clampf(cm.a + (GrotteDecor.hash2(mid.x * 5.3, mid.z * 4.1 + mid.y * 2.0) - 0.5) * 0.5 * (1.0 if cm.a > 0.01 else 0.0), 0.0, 1.5)
	return cm

# ------------------------------------------------------------------ construction
func construire() -> void:
	var t0 := Time.get_ticks_msec()
	rng.seed = int(def.get("graine", 1))
	_bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_bruit.frequency = 1.0
	_bruit.seed = int(def.get("bruit", 424))
	lac_y = float(def.get("lac_y", -4.7))
	corps = StaticBody3D.new()
	corps.name = "Corps"
	add_child(corps)
	decor = GrotteDecor.new(self, corps)
	decor.rng.seed = int(def.get("graine", 1))
	var t1 := Time.get_ticks_msec()
	_preparer()
	for id: String in ordre:
		_batir(br[id])
	etapes["anneaux"] = Time.get_ticks_msec() - t1
	var tp := Time.get_ticks_msec()
	_coque()
	_caps()
	_indexer()
	etapes["coque"] = Time.get_ticks_msec() - tp
	tp = Time.get_ticks_msec()
	_decorer()
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

func _preparer() -> void:
	ordre = def["ordre"]
	for d: Dictionary in def["branches"]:
		var id: String = d["id"]
		var rg := RandomNumberGenerator.new()
		rg.seed = int(d.get("graine", 0)) * 7919 + int(def.get("graine", 0))
		var v: Dictionary = d.get("variante", {})
		var lr: Array = v.get("largeur", [1.0, 1.0])
		var rr: Array = v.get("relief", [1.0, 1.0])
		br[id] = {"id": id, "d": d, "profil": d["profil"], "marches": d.get("marches", [[0.0, 0.0]]), "anneaux": [],
			"m_larg": rg.randf_range(float(lr[0]), float(lr[1])), "m_relief": rg.randf_range(float(rr[0]), float(rr[1])),
			"bn": float(int(d.get("graine", 0))) * 37.1, "decalage": float(d.get("decalage", 0.0))}
	for z: Dictionary in def.get("zones", []):
		zones[z["id"]] = z

func _batir(b: Dictionary) -> void:
	var d: Dictionary = b["d"]
	var wp: Array = (d["wp"] as Array).duplicate()
	var t0: Vector2 = (d.get("debut", Vector2(0, -1)) as Vector2).normalized()
	var t1: Vector2 = (d.get("fin", Vector2(0, -1)) as Vector2).normalized()
	if d.has("pince_deb"):
		var par: Dictionary = br[(d["pince_deb"] as Dictionary)["de"]]
		var pr: Dictionary = (par["anneaux"] as Array)[(par["anneaux"] as Array).size() - 1]
		b["pr_deb"] = pr
		var P: Vector3 = pr["P"]
		var T: Vector3 = pr["T"]
		wp[0] = Vector2(P.x, P.z)
		t0 = Vector2(T.x, T.z)
	if d.has("pince_fin"):
		var par2: Dictionary = br[(d["pince_fin"] as Dictionary)["vers"]]
		var pr2: Dictionary = (par2["anneaux"] as Array)[0]
		b["pr_fin"] = pr2
		var P2: Vector3 = pr2["P"]
		var T2: Vector3 = pr2["T"]
		wp[wp.size() - 1] = Vector2(P2.x, P2.z)
		t1 = Vector2(T2.x, T2.z)
	b["chemin"] = _spline(wp, t0, t1)
	b["L"] = float((b["chemin"] as PackedVector2Array).size() - 1) * 0.1
	var rings: Array = []
	var liste := _liste_s(b)
	for i in liste.size():
		var s: float = liste[i]
		if i == 0 and d.has("pince_deb"):
			rings.append(_forcer(b, false))
		elif i == liste.size() - 1 and d.has("pince_fin"):
			rings.append(_forcer(b, true))
		else:
			rings.append(_anneau(b, s))
	b["anneaux"] = rings
	_anneaux.append_array(rings)

func _centroide(r: Dictionary) -> Vector3:
	var c := Vector3.ZERO
	for p: Vector3 in r["pts"]:
		c += p
	return c / float(NB)

func _coque() -> void:
	_fixes.clear()
	for id: String in ordre:
		var rings: Array = br[id]["anneaux"]
		for r: Dictionary in [rings[0], rings[rings.size() - 1]]:
			for p: Vector3 in r["pts"]:
				_fixes[p] = true
		for r: Dictionary in rings:             # sol (centre et pieds de paroi) : plat, il porte le chemin et le lac
			for k in [0, 1, 17, 2, 16]:
				_fixes[(r["pts"] as Array)[k]] = true
	for id: String in ordre:
		var b: Dictionary = br[id]
		var rings: Array = b["anneaux"]
		for i in rings.size() - 1:
			var ra: Dictionary = rings[i]
			var rb: Dictionary = rings[i + 1]
			var pa: Array = ra["pts"]
			var pb: Array = rb["pts"]
			var ref: Vector3 = ((ra["P"] as Vector3) + (rb["P"] as Vector3)) * 0.5 + Vector3(0, 0.45 * (float(ra["h"]) + float(rb["h"])) * 0.5, 0)
			if ra["forcee"]:
				ref = _centroide(rb)
			elif rb["forcee"]:
				ref = _centroide(ra)
			for k in NB:
				var j := (k + 1) % NB
				_tri_coque(pa[k], pa[j], pb[j], k, j, j, ra, rb, k, ref, b)
				_tri_coque(pa[k], pb[j], pb[k], k, j, k, ra, rb, k, ref, b)

## Extrémités libres : bouche ouverte sur le jour (carte sans éclairage découpée par la bouche rocheuse) ; fond en dôme de glace.
func _caps() -> void:
	for id: String in ordre:
		var b: Dictionary = br[id]
		var d: Dictionary = b["d"]
		var rings: Array = b["anneaux"]
		if d.get("cap_deb", "") == "jour":
			_cap_jour(rings[0])
		if d.get("cap_fin", "") == "dome":
			_cap_dome(rings[rings.size() - 1])

func _cap_jour(r0: Dictionary) -> void:
	var p0: Array = r0["pts"]
	var c0: Vector3 = r0["P"] + Vector3(0, 0.5 * float(r0["h"]), 0)
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

## Fond : dôme en anneaux concentriques décalés (pas d'étoile de triangles), glace uniforme.
func _cap_dome(rn: Dictionary) -> void:
	var pn: Array = rn["pts"]
	var Tn: Vector3 = rn["T"]
	var c_plan: Vector3 = (rn["P"] as Vector3) + Vector3(0, 0.45 * float(rn["h"]), 0)
	var refn: Vector3 = c_plan - Tn * 4.0
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
					_idx[key] = []                  # un Array (référence) : un PackedInt32Array lu depuis le dictionnaire est une COPIE
				(_idx[key] as Array).append(t)

## Hauteurs de la coque au-dessus de (x, z) (repère local) : [plus bas, plus haut] parmi les facettes non verticales.
func _hauteurs(x: float, z: float) -> Vector2:
	var key := Vector2i(floori(x / 2.0), floori(z / 2.0))
	var bas := 1e9
	var haut := -1e9
	if not _idx.has(key):
		return Vector2(bas, haut)
	var c := decor.coll
	for t: int in (_idx[key] as Array):
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

## Point du sol (repère local) à l'abscisse s de la branche `id` et au décalage latéral lat (+ = droite).
func sol_en(id: String, s: float, lat: float) -> Vector3:
	var b: Dictionary = br[id]
	var c := _xz(b, s) + Vector2(droite(id, s).x, droite(id, s).z) * lat
	var h := _hauteurs(c.x, c.y)
	var yn := y_net(b, s)
	return Vector3(c.x, h.x if (h.x < 1e8 and h.x < yn + 3.0) else yn, c.y)       # hors de la galerie (dans la roche) : pas de « sol » trouvé

func plafond_en(id: String, s: float, lat: float) -> Vector3:
	var b: Dictionary = br[id]
	var c := _xz(b, s) + Vector2(droite(id, s).x, droite(id, s).z) * lat
	var h := _hauteurs(c.x, c.y)
	return Vector3(c.x, h.y if h.y > -1e8 else y_net(b, s) + 4.0, c.y)

## Point de la paroi à hauteur 0 (repère local), côté sign (+1 droite, -1 gauche).
func mur_en(id: String, s: float, sign_: float) -> Vector3:
	var dl := demi_l(id, s)
	var w := (dl.y if sign_ > 0 else dl.x) * 0.97
	var p := sol_en(id, s, sign_ * w)
	return Vector3(p.x, 0, p.z) - droite(id, s) * sign_ * 0.04

## Lacet (repère local) d'un personnage qui regarde dans le sens de la branche en s.
func lacet_en(id: String, s: float) -> float:
	var T := tang(id, s)
	return atan2(-T.x, -T.z)

## (branche, s local) pour une abscisse « globale » (branche->decalage) : les captures et l'accès n'ont qu'un nombre à donner.
func resoudre(s_glob: float, id := "") -> Array:
	if id != "" and br.has(id):
		return [id, s_glob]
	var best := ""
	var bd := -1.0
	for k: String in ordre:
		var dc: float = br[k]["decalage"]
		if dc <= s_glob + 0.0001 and dc > bd:
			bd = dc
			best = k
	return [best, s_glob - bd]

## Position monde / point d'observation (pour captures et tests). `s` global (voir `resoudre`) ou local si `id` est donné.
func monde_sol(s: float, lat: float, id := "") -> Vector3:
	var r := resoudre(s, id)
	return to_global(sol_en(r[0], r[1], lat))

func cap_monde(s: float, id := "") -> float:
	var r := resoudre(s, id)
	return lacet_en(r[0], r[1]) + global_rotation.y

# ------------------------------------------------------------------ décor : modules par zone
func _r(a: float, b: float) -> float:
	return rng.randf_range(a, b)

func _cailloux() -> void:
	# micro : éclats de roche et gravats sur le sol, sans collision (fusionnés dans la coque)
	for id: String in ordre:
		var b: Dictionary = br[id]
		var L: float = b["L"]
		var n := int(L * 1.2)
		for k in n:
			var s := _r(1.0, L - 1.0)
			var dl := demi_l(id, s)
			var lat := _r(-minf(dl.x, 7.0) * 0.9, minf(dl.y, 7.0) * 0.9)
			var nom := "c_roche_nu"
			var sty := "nu"
			for m: Array in (b["d"] as Dictionary).get("matieres", [[999.0, "nu"]]):
				sty = String(m[1])
				if s < float(m[0]):
					break
			if sty == "neige":
				nom = "c_roche_neige"
			elif sty == "glace" or sty == "cristaux":
				nom = "c_roche_glace"
			decor.caillou(nom, sol_en(id, s, lat), _r(0.05, 0.2), _r(0.04, 0.16), rng.randi(), 0.7 if sty == "neige" else 0.4)

func _decorer() -> void:
	_cailloux()
	for z: Dictionary in def.get("zones", []):
		_corniches_zone(z)
	for z: Dictionary in def.get("zones", []):
		GrotteModules.poser(self, z)
		_accroches_zone(z)
		GrotteModules.lumieres(self, z)

## Dalle praticable (corniche) : profil extrudé (rampe puis plateau) posé sur le sol, collisions comprises. Le dessus est horizontal
## (altitude `top`), les pieds suivent le sol ; la rampe fait ≈ 17° (3,4 x la hauteur).
func _corniches_zone(z: Dictionary) -> void:
	for c: Dictionary in z.get("corniches", []):
		var id: String = z["branche"]
		var s0: float = c["s"]
		var lg: float = c["longueur"]
		var lat0: float = c["lat"]
		var lar: float = c["largeur"]
		var haut: float = c["haut"]
		var rampe: String = c.get("rampe", "fin")
		var lr := haut * 3.4
		var Lb := longueur(id)
		# la rampe doit tenir dans la branche (au-delà de ses extrémités la ligne médiane n'existe plus) : sinon elle est raccourcie
		if rampe == "debut":
			lr = minf(lr, s0 - 0.6)
		else:
			lr = minf(lr, Lb - 0.6 - (s0 + lg))
		# la dalle reste sur le sol praticable : jamais plus loin que 0,9 de la demi-largeur (au-delà, la paroi monte)
		var lat_max := 99.0
		var u_c := s0 - lr if rampe == "debut" else s0
		var u_fin := s0 + lg if rampe == "debut" else s0 + lg + lr
		while u_c <= u_fin + 0.01:
			var dlc := demi_l(id, clampf(u_c, 0.0, Lb))
			lat_max = minf(lat_max, 0.9 * (dlc.y if lat0 > 0.0 else dlc.x))
			u_c += 1.0
		if lat0 > 0.0:
			lar = minf(lar, lat_max - lat0)
		if lr < haut * 2.0:
			push_warning("corniche %s : rampe trop courte (%.1f m pour %.1f m de haut)" % [c["id"], lr, haut])
		var top := sol_en(id, s0 + lg * 0.5, lat0 + lar * 0.5).y + haut
		reserves.append([id, (s0 - lr - 2.5) if rampe == "debut" else s0, (s0 + lg) if rampe == "debut" else (s0 + lg + lr + 2.5), lat0 - 1.4, lat0 + lar + 0.4])
		corniches[c["id"]] = {"b": id, "top": top, "s": s0, "lat": lat0, "longueur": lg, "largeur": lar, "haut": haut, "rampe": rampe, "rampe_l": lr}
		# stations le long de la branche : t = fraction de hauteur (0 = pied de rampe sur le sol, 1 = dessus de la dalle)
		var st: Array = []
		var u0 := s0
		var u1 := s0 + lg
		if rampe == "debut":
			var nr := maxi(2, ceili(lr / 1.5))
			for k in nr:
				st.append([s0 - lr + lr * float(k) / nr, float(k) / nr])
			var np := maxi(1, ceili(lg / 2.5))
			for k in np + 1:
				st.append([s0 + lg * float(k) / np, 1.0])
		else:
			var np2 := maxi(1, ceili(lg / 2.5))
			for k in np2 + 1:
				st.append([s0 + lg * float(k) / np2, 1.0])
			var nr2 := maxi(2, ceili(lr / 1.5))
			for k in range(1, nr2 + 1):
				st.append([s0 + lg + lr * float(k) / nr2, 1.0 - float(k) / nr2])
		var TL: Array = []
		var TR: Array = []
		var BL: Array = []
		var BR: Array = []
		for q: Array in st:
			var u: float = q[0]
			var t: float = q[1]
			var pl := sol_en(id, u, lat0)
			var pr := sol_en(id, u, lat0 + lar)
			TL.append(Vector3(pl.x, pl.y + t * (top - pl.y), pl.z))
			TR.append(Vector3(pr.x, pr.y + t * (top - pr.y), pr.z))
			BL.append(Vector3(pl.x, pl.y - 0.25, pl.z))
			BR.append(Vector3(pr.x, pr.y - 0.25, pr.z))
		var R := droite(id, s0 + lg * 0.5)
		var T := tang(id, s0 + lg * 0.5)
		var sty := GrotteModules._style(self, id, s0 + lg * 0.5)
		var nm := GrotteModules._roche(sty)
		var mk := GrotteModules._masque(sty) * 0.8
		var cc := GrotteDecor.col(0.9, mk)
		var cs := GrotteDecor.col(0.74, mk)
		for k in st.size() - 1:
			var cen: Vector3 = ((TL[k] as Vector3) + (TR[k + 1] as Vector3)) * 0.5
			decor.facette(nm, TL[k], TL[k + 1], TR[k + 1], cen + Vector3(0, 3.0, 0), [cc, cc, cc], true, TUILE_COQUE, true)
			decor.facette(nm, TL[k], TR[k + 1], TR[k], cen + Vector3(0, 3.0, 0), [cc, cc, cc], true, TUILE_COQUE, true)
			decor.facette(nm, TL[k], BL[k], BL[k + 1], cen - R * 3.0, [cs, cs, cs], true, TUILE_COQUE, true)
			decor.facette(nm, TL[k], BL[k + 1], TL[k + 1], cen - R * 3.0, [cs, cs, cs], true, TUILE_COQUE, true)
			decor.facette(nm, TR[k], TR[k + 1], BR[k + 1], cen + R * 3.0, [cs, cs, cs], true, TUILE_COQUE, true)
			decor.facette(nm, TR[k], BR[k + 1], BR[k], cen + R * 3.0, [cs, cs, cs], true, TUILE_COQUE, true)
		# front vertical (extrémité haute de la dalle)
		var haut_k := 0 if rampe == "fin" else st.size() - 1
		var sgn := -1.0 if rampe == "fin" else 1.0
		var cf: Vector3 = ((TL[haut_k] as Vector3) + (TR[haut_k] as Vector3)) * 0.5
		decor.facette(nm, TL[haut_k], TR[haut_k], BR[haut_k], cf + T * sgn * 3.0, [cs, cs, cs], true, TUILE_COQUE, true)
		decor.facette(nm, TL[haut_k], BR[haut_k], BL[haut_k], cf + T * sgn * 3.0, [cs, cs, cs], true, TUILE_COQUE, true)
		u0 = u0
		u1 = u1

## Îlot : tronc de cône octogonal très évasé (pente ≈ 20°), praticable, posé sur le sol de la glace.
func ilot(id: String, s: float, lat: float, r_haut: float, h: float) -> void:
	var c := sol_en(id, s, lat)
	var r_bas := r_haut + h * 2.8
	var N := 10
	var bas: Array = []
	var haut: Array = []
	for i in N:
		var a := TAU * (float(i) + 0.35 * GrotteDecor.hash2(float(i), s)) / N
		var rb := r_bas * (0.9 + 0.2 * GrotteDecor.hash2(float(i) * 1.7, lat))
		bas.append(c + Vector3(cos(a) * rb, -0.25, sin(a) * rb))
		haut.append(c + Vector3(cos(a) * r_haut * (0.92 + 0.16 * GrotteDecor.hash2(float(i), 4.4)), h, sin(a) * r_haut * (0.92 + 0.16 * GrotteDecor.hash2(float(i), 8.8))))
	var ctr := c + Vector3(0, h, 0)
	var ref := c + Vector3(0, h + 3.0, 0)
	var cc := GrotteDecor.col(0.9, 0.5)
	var cf := GrotteDecor.col(0.78, 0.35)
	for i in N:
		var j := (i + 1) % N
		decor.facette("c_roche_glace", ctr, haut[i], haut[j], ref, [cc, cc, cc], true, TUILE_COQUE, true)
		decor.facette("c_roche_glace", bas[i], bas[j], haut[j], ref, [cf, cf, cc], true, TUILE_COQUE, true)
		decor.facette("c_roche_glace", bas[i], haut[j], haut[i], ref, [cf, cc, cc], true, TUILE_COQUE, true)
	corniches[id + "_ilot"] = {"b": id, "top": c.y + h, "s": s, "lat": lat}

# ------------------------------------------------------------------ points d'accroche du gameplay
## Tout ce qui est posé dans le repère local de la grotte ; GrotteJeu crée les nœuds (ennemis, interactions, mécanismes).
func _pos_zone(z: Dictionary, e: Dictionary) -> Vector3:
	var lat := float(e["lat"])
	var su := float(e["s"])
	var haut := -1e9
	if e.has("sur") and corniches.has(e["sur"]):          # sur une dalle : toujours sur la dalle, quelle que soit la variante de largeur
		var cn: Dictionary = corniches[e["sur"]]
		lat = clampf(lat, float(cn["lat"]) + 0.45, float(cn["lat"]) + float(cn["largeur"]) - 0.45)
		su = clampf(su, float(cn["s"]) + 0.5, float(cn["s"]) + float(cn["longueur"]) - 0.5)
		haut = float(cn["top"])
	else:                                                   # jamais dans la paroi
		var dl := demi_l(z["branche"], su)
		lat = clampf(lat, -dl.x * 0.82, dl.y * 0.82)
	var p := sol_en(z["branche"], su, lat)
	if haut > -1e8:
		p.y = haut
	return p

func _accroches_zone(z: Dictionary) -> void:
	var id: String = z["branche"]
	for e: Dictionary in z.get("ennemis", []):
		var p := _pos_zone(z, e)
		var lac := lacet_en(id, float(e["s"])) + PI                # par défaut : face à l'entrée de la branche
		if e.get("face", "") == "centre":
			var c := sol_en(id, float(e["s"]), 0.0)
			lac = atan2(-(c.x - p.x), -(c.z - p.z))
		var pat: Array = []
		for q: Array in e.get("patrouille", []):
			pat.append(sol_en(id, float(q[0]), float(q[1])))
		accroches.append({"type": "ennemi", "id": e["id"], "zone": z["id"], "pos": p + Vector3(0, 0.05, 0), "lacet": lac, "d": e, "patrouille": pat})
	for c: Dictionary in z.get("coffres", []):
		var p := _pos_zone(z, c)
		decor.coffre(p, float(c.get("lacet", 0.0)))
		accroches.append({"type": "coffre", "id": c["id"], "zone": z["id"], "pos": p + Vector3(0, 0.8, 0), "lieu": p, "d": c})
	for r: Dictionary in z.get("ressources", []):
		var p := _pos_zone(z, r)
		GrotteModules.prop_ressource(self, r, p, z)
		accroches.append({"type": "ressource", "id": r["id"], "zone": z["id"], "pos": p + Vector3(0, 0.7, 0), "d": r})
	for i: Dictionary in z.get("interactions", []):
		var p := _pos_zone(z, i)
		GrotteModules.prop_interaction(self, i, p, z)
		accroches.append({"type": "interaction", "id": i["id"], "zone": z["id"], "pos": p + Vector3(0, 0.6, 0), "d": i})
	for m: Dictionary in z.get("meca", []):
		var p := sol_en(id, float(m["s"]), float(m["lat"]))
		accroches.append({"type": "meca", "id": m["id"], "zone": z["id"], "pos": p, "lacet": lacet_en(id, float(m["s"])), "d": m})
	if z.has("lieu"):
		var l: Dictionary = z["lieu"]
		var s_l: float = float(l.get("s", (float(z["s"][0]) + float(z["s"][1])) * 0.5))
		accroches.append({"type": "lieu", "id": z["id"], "zone": z["id"], "pos": sol_en(id, s_l, float(l.get("lat", 0.0))), "d": l})

## Vrai si un décor solide de rayon `r` posé en (s, lat) ne gêne ni le couloir central de la branche ni une zone réservée (rampes, accès).
func libre(id: String, s: float, lat: float, r: float) -> bool:
	if absf(lat) < VOIE_LIBRE + r or not hors_jonction(id, s):
		return false
	for z: Array in reserves:
		if z[0] == id and s >= float(z[1]) - r and s <= float(z[2]) + r and lat >= float(z[3]) - r and lat <= float(z[4]) + r:
			return false
	return true

## Vrai si s est hors des zones de jonction de la branche (pas de décor solide dans le pilier, ni dans l'évasement des confluents).
func hors_jonction(id: String, s: float) -> bool:
	var b: Dictionary = br[id]
	var d: Dictionary = b["d"]
	if d.has("pince_deb") and s < ZONE_PINCE:
		return false
	if d.has("pince_fin") and s > float(b["L"]) - ZONE_PINCE:
		return false
	return true

## Centre d'une zone (repère local), pour l'apparition des ennemis et les tests.
func centre_zone(z: Dictionary) -> Vector3:
	var s := (float(z["s"][0]) + float(z["s"][1])) * 0.5
	return sol_en(z["branche"], s, 0.0)

# ------------------------------------------------------------------ lumières, neige
func _l(id: String, s: float, lat: float, haut: float, c: Color, e: float, portee: float, att := 1.6, vacille := false) -> void:
	var p := sol_en(id, s, lat) + Vector3(0, haut, 0)
	decor.lumiere(p, c, e, portee, att, vacille)
	nb_lumieres += 1

func _neige_soufflee() -> void:
	if not def.has("neige"):
		return
	var nv: Dictionary = def["neige"]
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 4.5
	p.position = sol_en(nv["branche"], float(nv["s"]), 0.0) + Vector3(0, 2.0, 0)
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

## Réglages d'environnement propres à la grotte (après `_sous_terre(true)` du monde).
func ambiance(env: Environment) -> void:
	env.ambient_light_color = Color(0.5, 0.58, 0.72)
	env.ambient_light_energy = 1.15
	env.fog_light_color = Color(0.05, 0.08, 0.13)
	env.fog_density = 0.012

## Routes de test : pour chaque branche, des points du sol (monde) tous les 1 m (décalage latéral 0).
func routes_test() -> Dictionary:
	var res := {}
	for id: String in ordre:
		var L: float = br[id]["L"]
		var pts: Array[Vector3] = []
		var s := 1.0
		while s < L - 1.5:
			pts.append(to_global(sol_en(id, s, 0.0)) + Vector3(0, 0.1, 0))
			s += 1.0
		res[id] = pts
	return res
