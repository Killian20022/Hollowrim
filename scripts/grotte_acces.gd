class_name GrotteAcces
extends Node3D
## Entrée de la grotte des bandits dans le monde : bouche de roche sur le flanc est de la cuvette (≈ (92, -27)), passage
## fondu dedans / dehors, construction de la grotte en fil d'exécution, sauvegarde sous terre. Même schéma que le tertre.
##
## Repère local : origine = centre du seuil de la bouche, au niveau du sol plané ; +Z = vers l'extérieur (l'ouest du monde),
## -Z = dans la colline ; +X local = +Z monde (lacet -90°). La bouche est creusée dans le flanc : le terrain est aplani en
## terrasse devant (`aplani`, appelé par `monde.hauteur`), la roche (mur à strates, toit, congères) recouvre la colline.
##
## Description (règle Lead Technical Artist) :
##  1. Murs / Structure : front de roche à 4 strates en retrait / surplomb (linteau saillant au-dessus de l'ouverture), toit
##     facetté qui se fond dans la pente, jambages en voûte irrégulière à 9 pans, boyau de 3 m qui s'assombrit jusqu'au noir,
##     bouchon noir en fond (la grotte réelle est sous le monde).
##  2. Mobilier : congères, glaçons au linteau, pieux et crâne sur pique, chevaux de frise, caisses, sac, foyer éteint, étendard
##     de peau, brasero allumé ; piste de pieux à crâne et de cairns qui mène à la bouche depuis l'ouest.
##  3. Éclairage : le jour / la lune du monde ; un seul brasero (rayon 5,8 m, vacille) visible de nuit de loin.

signal entree(dedans: bool)

const SITE := Vector2(92.0, -27.0)            # centre du seuil (monde x, z)
const LACET := -PI * 0.5                      # +Z local → -X monde
const CENTRE_PLAT := Vector2(91.0, -27.0)     # centre de la terrasse (1 m devant le seuil)
const R_PLAT := 6.5                           # demi-largeur de la terrasse / de la rampe
const RAMPE := 30.0                           # longueur de la rampe devant le seuil (m)
const PENTE := 0.16                           # pente de la rampe (≈ 9°)
const R_FONDU := 14.0                         # fin du raccord avec le relief
const ARRIVEE_S := 5.0                        # abscisse d'arrivée dans la grotte (pente d'entrée)
const SORTIE_S := 1.9                         # abscisse de l'interactif de sortie
const SEUIL_Y := -182.0                       # au-dessous : sauvegardé dans la grotte (la crypte est à -140)
const DELAI_PREPARATION := 6.0                # secondes après l'arrivée dans le monde : la grotte se construit en fond même loin
const DEPART_FIL := 85.0                      # le fil de construction part quand le joueur est à moins de 85 m

var monde: Node3D
var joueur: CharacterBody3D
var dialogue: Control
var quetes: Node
var hud: Control
var porte_dehors := Vector3.ZERO              # devant la bouche (posé dans _ready)
var orientation := 0.0                        # lacet du joueur en sortant
var dedans := false
var grotte: Grotte
var decor: GrotteDecor
var corps: StaticBody3D
var temps_ms := 0
var nb_facettes := 0

var morts_charges: Array = []                 # bandits tués dans une partie chargée (posé par le monde) : on ne les refait pas
var jeu: GrotteJeu                            # gameplay de la grotte (ennemis, coffres, ressources…) : voir grotte_jeu.gd
var _tache := -1
var _tache_ext := -1                          # fil d'exécution de l'extérieur (bouche, décor)
var _cont: Node3D                             # extérieur bâti hors de l'arbre, posé quand le fil a fini
var pret := false                             # l'extérieur est dans la scène
var _g_fil: Grotte
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _y0 := 0.0

# ------------------------------------------------------------------ fonctions statiques (utilisées par le monde)
## Terrasse devant la bouche puis rampe douce vers l'ouest (la « piste », pente PENTE) : le relief rejoint la surface cible dans
## R_PLAT m de l'axe (segment de 1 à RAMPE m devant le seuil) et se raccorde au terrain naturel jusqu'à R_FONDU m.
static func aplani(x: float, z: float, h: float, h_ent: float) -> float:
	var xl := z - SITE.y
	var zl := SITE.x - x
	var zc := clampf(zl, 1.0, RAMPE)
	var d := sqrt(xl * xl + (zl - zc) * (zl - zc))
	var cible := h_ent - PENTE * maxf(0.0, zc - 3.5)
	return lerpf(cible, h, smoothstep(R_PLAT, R_FONDU, d))

## Zone dégagée d'arbres et de rochers : disque devant la bouche, masse rocheuse, et une piste de 5 m de large vers l'ouest.
static func exclu(x: float, z: float) -> bool:
	if Vector2(x, z).distance_to(CENTRE_PLAT) < 11.0:
		return true
	if x > 89.0 and x < 105.0 and absf(z - SITE.y) < 11.0:
		return true
	return x > 50.0 and x < 90.0 and absf(z - axe_piste(x)) < 2.6

## Axe de la piste (z monde) à l'abscisse x : ondule doucement.
static func piste_z(x: float) -> float:
	return SITE.y + 1.4 * sin((x - 50.0) * 0.11)

## Local → monde (xz).
static func vers_monde(xl: float, zl: float) -> Vector2:
	return Vector2(SITE.x - zl, SITE.y + xl)

# ------------------------------------------------------------------ construction de l'extérieur
func _hl(xl: float, zl: float) -> float:
	var w := vers_monde(xl, zl)
	return monde.hauteur(w.x, w.y) - _y0

func _toit(xl: float, zl: float) -> float:
	var terr := _hl(xl, zl) + 0.15
	var pr := 7.0 * pow(clampf(1.0 - pow(xl / 10.5, 2.0), 0.0, 1.0), 0.75)
	pr *= 1.0 - 0.55 * clampf(-zl / 10.0, 0.0, 1.0)
	pr += 0.7 * (GrotteDecor.hash2(xl * 1.3, zl * 0.9 + 4.0) - 0.5)
	return maxf(terr, pr)

## Triangle de roche : normale tournée vers `ref`, neige sur les faces qui regardent le haut, AO peinte par sommet.
func _roche(a: Vector3, b: Vector3, c: Vector3, ref: Vector3, ao: Array, nom := "c_roche_bouche", neige := 1.0) -> void:
	var n := (b - a).cross(c - a).normalized()
	var ct := (a + b + c) / 3.0
	if n.dot(ref - ct) < 0.0:
		n = -n
	var m := 0.12
	if n.y > 0.55:
		m = 1.0
	elif n.y > 0.25:
		m = 0.55
	m *= (0.8 + 0.4 * GrotteDecor.hash2(ct.x * 0.7, ct.z * 1.3 + ct.y)) * neige
	decor.facette(nom, a, b, c, ref, [GrotteDecor.col(ao[0], m), GrotteDecor.col(ao[1], m), GrotteDecor.col(ao[2], m)], true, 4.0, true)

## Tourne dans un fil d'exécution : ne touche qu'à `_cont` (hors de l'arbre) et aux lectures du relief (`monde.hauteur`, sans état hors zone témoin).
func _construire() -> void:
	FilVerrou.prendre()
	var t0 := Time.get_ticks_msec()
	_rng.seed = 9031
	corps = StaticBody3D.new()
	corps.name = "CorpsEntree"
	_cont.add_child(corps)
	decor = GrotteDecor.new(_cont, corps)
	_mur_toit_tunnel()
	_neige_glacons()
	_signes_des_bandits()
	_ruban_piste()
	_piste()
	decor.finir()
	nb_facettes = decor.nb_facettes
	var forme := ConcavePolygonShape3D.new()
	forme.backface_collision = true
	forme.set_faces(decor.coll)
	var cs := CollisionShape3D.new()
	cs.shape = forme
	cs.name = "RocheSolide"
	corps.add_child(cs)
	temps_ms = Time.get_ticks_msec() - t0
	FilVerrou.rendre()

## Points de la voûte (x, y) : demi-ellipse irrégulière de 2,4 m de demi-largeur et ~3 m de haut, 9 sommets.
func _voute() -> Array:
	var pts: Array = []
	for j in 9:
		var th := PI - PI * j / 8.0
		var x := 2.4 * cos(th)
		var y := 3.0 * pow(maxf(sin(th), 0.0), 0.75)
		if j > 0 and j < 8:
			x += (GrotteDecor.hash2(float(j), 3.3) - 0.5) * 0.18
			y += (GrotteDecor.hash2(float(j), 7.1) - 0.5) * 0.3
		pts.append(Vector2(x, y))
	return pts

func _mur_toit_tunnel() -> void:
	var voute := _voute()
	# colonnes du front : bord gauche, voûte (9), bord droit ; fond enterré sous le terrain, sauf dans la voûte
	var xs: Array = [-10.0, -8.0, -6.0, -4.5, -3.2]
	var bas: Array = []
	for x: float in xs:
		bas.append(_hl(x, 0.0) - 0.9)
	for v: Vector2 in voute:
		xs.append(v.x)
		bas.append(v.y)
	for x: float in [3.2, 4.5, 6.0, 8.0, 10.0]:
		xs.append(x)
		bas.append(_hl(x, 0.0) - 0.9)
	var n := xs.size()
	var K := 4
	var colonnes: Array = []      # par colonne : Array de Vector3 (K+1 niveaux)
	var alt := [0.0, 0.18, -0.12, 0.2, 0.0]
	for i in n:
		var x: float = xs[i]
		var haut := _toit(x, 0.0)
		var col: Array = []
		for k in K + 1:
			var f := float(k) / K
			var y := lerpf(float(bas[i]), haut, f)
			var dz := 0.0
			if k > 0 and k < K:
				dz = alt[k] + (GrotteDecor.hash2(x * 2.1, float(k) * 5.3) - 0.5) * 0.3
				if k == 1:
					dz += 0.55 * clampf(1.0 - absf(x) / 4.2, 0.0, 1.0)      # linteau saillant au-dessus de l'ouverture
			col.append(Vector3(x, y, dz))
		colonnes.append(col)
	for i in n - 1:
		for k in K:
			var a: Vector3 = colonnes[i][k]
			var b: Vector3 = colonnes[i + 1][k]
			var c: Vector3 = colonnes[i + 1][k + 1]
			var d: Vector3 = colonnes[i][k + 1]
			var ref := Vector3((a.x + b.x) * 0.5, (a.y + c.y) * 0.5, 30.0)
			var fa := 0.62 + 0.38 * float(k) / K
			var fb := 0.62 + 0.38 * float(k + 1) / K
			# plus sombre à l'arête de l'ouverture (occlusion du creux)
			var proche := 0.9 if (absf(a.x) < 3.3 and absf(b.x) < 3.3) else 1.0
			_roche(a, b, c, ref, [fa * proche, fa * proche, fb * proche])
			_roche(a, c, d, ref, [fa * proche, fb * proche, fb * proche])
	# toit : grille de 19 colonnes × 5 rangées, rejoint la pente ; jupes de 0,8 m sous le terrain aux bords
	var zs: Array = [0.0, -2.5, -5.0, -7.5, -10.0]
	var g: Array = []
	for r in zs.size():
		var rang: Array = []
		for i in n:
			var x: float = xs[i]
			var z: float = zs[r]
			var y := _toit(x, z)
			if r == 0:
				y = (colonnes[i][K] as Vector3).y
			rang.append(Vector3(x, y, z))
		g.append(rang)
	for r in zs.size() - 1:
		for i in n - 1:
			var a: Vector3 = g[r][i]
			var b: Vector3 = g[r][i + 1]
			var c: Vector3 = g[r + 1][i + 1]
			var d: Vector3 = g[r + 1][i]
			var ref := Vector3((a.x + c.x) * 0.5, 60.0, (a.z + c.z) * 0.5)
			var ao := 0.9 + 0.1 * float(r) / (zs.size() - 1)
			if (i + r) % 2 == 0:
				_roche(a, b, c, ref, [ao, ao, ao])
				_roche(a, c, d, ref, [ao, ao, ao])
			else:
				_roche(a, b, d, ref, [ao, ao, ao])
				_roche(b, c, d, ref, [ao, ao, ao])
	var cote_g: Array = []
	var cote_d: Array = []
	for r in zs.size():
		cote_g.append(g[r][0])
		cote_d.append(g[r][n - 1])
	for r in zs.size() - 1:
		_jupe(cote_g[r], cote_g[r + 1], Vector3(-30, 8, 0))
		_jupe(cote_d[r], cote_d[r + 1], Vector3(30, 8, 0))
	for i in n - 1:
		_jupe(g[zs.size() - 1][i], g[zs.size() - 1][i + 1], Vector3(0, 8, -30))
	# boyau : 4 anneaux de la voûte qui s'assombrissent jusqu'au noir, sol, bouchon
	var anneaux: Array = []
	var ombre := [0.8, 0.3, 0.1, 0.03]
	for m in 4:
		var ring: Array = []
		for j in 9:
			var v: Vector2 = voute[j]
			var e := 1.0 - 0.07 * m
			var jit := 0.0 if (j == 0 or j == 8) else (GrotteDecor.hash2(float(j) + m * 9.0, 2.2) - 0.5) * 0.25
			ring.append(Vector3(v.x * e, v.y * e + jit, -1.0 * m))
		anneaux.append(ring)
	var centre_int := Vector3(0, 1.2, -1.5)
	for m in 3:
		for j in 8:
			var a: Vector3 = anneaux[m][j]
			var b: Vector3 = anneaux[m][j + 1]
			var c: Vector3 = anneaux[m + 1][j + 1]
			var d: Vector3 = anneaux[m + 1][j]
			var o0: float = ombre[m]
			var o1: float = ombre[m + 1]
			_roche(a, b, c, centre_int, [o0, o0, o1], "c_roche_nu", 0.0)
			_roche(a, c, d, centre_int, [o0, o1, o1], "c_roche_nu", 0.0)
	var fin: Array = anneaux[3]
	var fond := Vector3(0, 1.3, -3.4)
	for j in 8:
		_roche(fin[j], fin[j + 1], fond, Vector3(0, 1.2, 0), [0.04, 0.04, 0.02], "c_roche_nu", 0.0)
	_roche(fin[8], fin[0], fond, Vector3(0, 1.2, 0), [0.03, 0.03, 0.02], "c_roche_nu", 0.0)      # le bouchon descend jusqu'au sol
	# sol du boyau : 2 cm au-dessus de la terrasse, neige poudrée qui s'efface dans l'ombre
	var sx: Array = [-2.4, -0.8, 0.8, 2.4]
	for m in 3:
		for i in 3:
			var a := Vector3(sx[i], 0.02, -1.0 * m)
			var b := Vector3(sx[i + 1], 0.02, -1.0 * m)
			var c := Vector3(sx[i + 1], 0.02, -1.0 * (m + 1))
			var d := Vector3(sx[i], 0.02, -1.0 * (m + 1))
			var o0: float = ombre[m]
			var o1: float = ombre[m + 1]
			var m0 := 1.0 - 0.3 * m
			var m1 := 1.0 - 0.3 * (m + 1)
			var refh := Vector3(0, 5.0, a.z)
			decor.facette("c_sol_neige", a, b, c, refh, [GrotteDecor.col(o0, m0), GrotteDecor.col(o0, m0), GrotteDecor.col(o1, m1)], true, 4.0, false)
			decor.facette("c_sol_neige", a, c, d, refh, [GrotteDecor.col(o0, m0), GrotteDecor.col(o1, m1), GrotteDecor.col(o1, m1)], true, 4.0, false)
	# interactif : au fond du boyau, dans l'obscurité
	var it := _interactif(Vector3(0, 1.3, -1.9), "Grotte des bandits", "Entrer dans la grotte", func() -> Array: return _passer(true), _cont)
	it.rayon = 4.2

func _jupe(a: Vector3, b: Vector3, ref: Vector3) -> void:
	var ba := Vector3(a.x, a.y - 1.4, a.z)
	var bb := Vector3(b.x, b.y - 1.4, b.z)
	_roche(a, b, bb, ref, [0.8, 0.8, 0.5])
	_roche(a, bb, ba, ref, [0.8, 0.5, 0.5])

func _sol(x: float, z: float) -> Vector3:
	return Vector3(x, _hl(x, z), z)

func _neige_glacons() -> void:
	# glaçons au linteau : suspendus à la voûte, plus longs au milieu
	var voute := _voute()
	for j in range(1, 8):
		var v: Vector2 = voute[j]
		var l := 0.45 + 0.7 * sin(PI * j / 8.0) * (0.5 + 0.5 * GrotteDecor.hash2(float(j), 1.7))
		decor.pointe("c_roche_glace", Vector3(v.x * 0.97, v.y - 0.02, 0.18), 0.05 + 0.05 * GrotteDecor.hash2(float(j), 5.0), -l, 4000 + j, 1.0, 5)
	for k in 5:
		var x := -9.0 + 4.5 * k + _rng.randf_range(-0.8, 0.8)
		decor.pointe("c_roche_glace", Vector3(x, _toit(x, 0.0) * 0.55 + 0.3, 0.12), 0.06, -_rng.randf_range(0.3, 0.7), 4100 + k, 1.0, 5)
	# congères : contre le front de roche et devant le seuil (sans collision)
	for p: Array in [[-4.2, 2.2, 2.0, 0.5], [4.6, 1.6, 2.3, 0.55], [-7.4, 0.8, 2.6, 0.7], [7.2, 1.2, 2.4, 0.65], [0.6, 3.6, 1.7, 0.32], [-2.2, 5.6, 1.4, 0.28], [9.0, 5.0, 2.0, 0.4], [-9.5, 4.0, 2.2, 0.45]]:
		decor.congere(_sol(p[0], p[1]), p[2], p[3], _rng.randi())
	# talus de neige au pied du front, de part et d'autre de la voûte
	for x: float in [-3.6, 3.6]:
		decor.congere(_sol(x, 0.5), 1.1, 0.4, _rng.randi())

func _signes_des_bandits() -> void:
	# crânes sur piques de part et d'autre de la voûte
	decor.trophee(_sol(-3.4, 2.4), 1.9, 0.5)
	decor.trophee(_sol(3.5, 2.9), 1.65, -0.4)
	# chevaux de frise : cinq pieux taillés, penchés vers l'extérieur, devant la terrasse
	for k in 5:
		var x := -7.6 + k * 1.2
		var z := 5.2 + 0.4 * sin(k * 1.7)
		var pied := _sol(x, z)
		decor.prisme("bois", pied + Vector3(0, -0.1, 0), pied + Vector3(0.06 * (k % 2 - 0.5), 1.35 + 0.15 * (k % 3), 0.55), 0.06, 5, 0.012)
		decor.solide_rond(pied + Vector3(0, 0.6, 0.15), 0.1, 1.2)
	# butin et campement léger à droite de la voûte
	var c := _sol(5.2, 1.4)
	decor.caisse(c, Vector3(0.85, 0.55, 0.6), 0.35)
	decor.caisse(c + Vector3(0.1, 0.55, 0.0), Vector3(0.6, 0.45, 0.5), -0.3)
	decor.sac(_sol(6.2, 2.6), 1.0)
	decor.sac(_sol(5.6, 3.0), 0.8)
	# foyer éteint : cercle de pierres, bûches noircies, os
	var f := _sol(-1.6, 5.3)
	for k in 7:
		var a := TAU * k / 7.0
		decor.rocher("c_roche_nu", f + Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.62), 0.2, 0.18, 4200 + k, 0.35, false, 5)
	for k in 3:
		var a := 0.5 + k * 2.1
		decor.prisme("fer", f + Vector3(cos(a) * 0.35, 0.1, sin(a) * 0.35), f + Vector3(-cos(a) * 0.3, 0.16, -sin(a) * 0.3), 0.05, 5)
	decor.os_tas(f + Vector3(0.9, 0, 0.6), 3, 0.35)
	decor.arme(_sol(2.4, 4.2) + Vector3(0, 0.03, 0), 0.9)
	# torche éteinte plantée dans la neige (tête noircie)
	var t := _sol(-5.0, 1.9)
	decor.prisme("bois", t + Vector3(0, -0.1, 0), t + Vector3(0, 1.75, 0), 0.04, 5)
	decor.prisme("fer", t + Vector3(0, 1.55, 0), t + Vector3(0, 1.82, 0), 0.065, 6, 0.08)
	decor.solide_rond(t + Vector3(0, 0.9, 0), 0.07, 1.8)
	# étendard de peau tendue sur deux perches, à gauche
	var e := _sol(-6.4, 2.6)
	decor.prisme("bois", e + Vector3(0, -0.1, 0), e + Vector3(0, 3.2, 0), 0.045, 5)
	decor.prisme("bois", e + Vector3(0, 3.0, 0), e + Vector3(1.0, 3.05, 0), 0.03, 5)
	decor.boite_b("peau", e + Vector3(0.5, 2.45, 0.03), Vector3(0.9, 1.1, 0.03), Basis(Vector3(0, 0, 1), 0.04))
	decor.solide_rond(e + Vector3(0, 1.5, 0), 0.07, 3.0)
	# brasero allumé : repère de nuit, rayon court
	_brasero(_sol(3.0, 4.6))
	_portique()

## C2 : portique de bois à la bouche (poteaux, linteau, jambes de force) et lanterne chaude pendue au linteau, comme la planche
## grotte_v2 (vues 1-2) : la bouche se lit de loin par sa lueur orange au milieu des roches froides, et la lumière se prolonge dedans.
func _portique() -> void:
	var zp := 1.3
	var xg := -3.0
	var xd := 3.0
	var h := 3.5
	var pg := _sol(xg, zp)
	var pd := _sol(xd, zp)
	decor.prisme("bois", pg + Vector3(0, -0.2, 0), pg + Vector3(0, h, 0), 0.15, 6)
	decor.prisme("bois", pd + Vector3(0, -0.2, 0), pd + Vector3(0, h, 0), 0.15, 6)
	decor.solide_rond(pg + Vector3(0, 1.5, 0), 0.17, 3.0)
	decor.solide_rond(pd + Vector3(0, 1.5, 0), 0.17, 3.0)
	var yl := maxf(pg.y, pd.y) + h - 0.1
	decor.prisme("bois", Vector3(xg - 0.35, yl, zp), Vector3(xd + 0.35, yl, zp), 0.13, 6)
	for s: float in [-1.0, 1.0]:
		var p := pg if s < 0.0 else pd
		decor.prisme("bois", p + Vector3(0, h - 0.9, 0), Vector3(p.x - s * 0.9, yl - 0.05, zp), 0.07, 5)
		decor.boite("fer", Vector3(p.x, yl, zp), Vector3(0.34, 0.05, 0.3))
	var lx := 1.7
	var ch := decor.lanterne(Vector3(lx, yl - 0.1, zp + 0.1), 0.45)
	decor.lumiere(ch + Vector3(0.0, 0.0, 1.0), CrypteDecor.FEU, 2.2, 9.0, 1.5)
	decor.lumiere(Vector3(0.0, 1.4, -1.0), CrypteDecor.FEU, 1.0, 5.0, 1.5)

## Brasero de fer sur trois pieds (le « mur0 » du brasero de la crypte n'existe pas dans la grotte) : cuve de fer, braises, flamme, lueur.
func _brasero(pos: Vector3) -> void:
	decor.objet("g_brasero", pos)     # lot L5 : trépied forgé, cerclage, cuve rivetée à bord roulé, braises (module g_brasero)
	decor.flamme(pos + Vector3(0, 0.9, 0), 1.7)
	decor.carte("halo", pos + Vector3(0, 0.03, 0), Vector3.UP, 3.4, 3.4)
	decor.lumiere(pos + Vector3(0, 1.5, 0), CrypteDecor.FEU, 2.6, 6.5, 1.7)
	decor.solide_rond(pos + Vector3(0, 0.55, 0), 0.46, 1.1)

## Axe de la piste au sol (z monde) : ondule à l'ouest, rejoint l'axe de la rampe (z = SITE.y) près de la terrasse.
static func axe_piste(x: float) -> float:
	return SITE.y + (piste_z(x) - SITE.y) * clampf((90.0 - x) / 14.0, 0.0, 1.0)

## Ruban de neige tassée posé sur la piste (ornières, pas, cailloux : texture « piste », bords tramés par bruit), de l'ouest
## jusqu'au seuil ; il s'élargit en terrasse piétinée devant la bouche. Pas de 1 m, 7 sommets en travers, 7 cm au-dessus du relief.
func _ruban_piste() -> void:
	var x0 := 46.0
	var x1 := SITE.x - 0.8
	var n := int((x1 - x0) / 1.0)
	var lignes: Array = []
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		var hw := 1.55 + 0.25 * sin(x * 0.7) + 2.6 * smoothstep(80.0, 88.0, x)
		var fin_o := smoothstep(x0, x0 + 8.0, x)                     # le ruban s'efface en s'éloignant vers l'ouest
		var ligne: Array = []
		for j in range(-3, 4):
			var lat := hw * float(j) / 3.0
			var zw := axe_piste(x) + lat
			var xl := zw - SITE.y
			var zl := SITE.x - x
			var p := _sol(xl, zl) + Vector3(0, 0.07, 0)
			var masque := clampf((3.0 - absf(float(j))) * 0.75, 0.0, 1.0) * (0.92 + 0.16 * GrotteDecor.hash2(x * 1.9, float(j) * 3.1)) * fin_o
			ligne.append([p, Vector2((SITE.x - x) / 4.0, lat / 4.0 + 0.5), GrotteDecor.col(1.0, clampf(masque, 0.0, 1.0))])
		lignes.append(ligne)
	for i in n:
		for j in 6:
			var a: Array = lignes[i][j]
			var b: Array = lignes[i][j + 1]
			var c: Array = lignes[i + 1][j + 1]
			var d: Array = lignes[i + 1][j]
			var ref: Vector3 = (a[0] as Vector3) + Vector3(0, 5, 0)
			decor.facette("c_piste", a[0], b[0], c[0], ref, [a[2], b[2], c[2]], true, 4.0, false, [a[1], b[1], c[1]])
			decor.facette("c_piste", a[0], c[0], d[0], ref, [a[2], c[2], d[2]], true, 4.0, false, [a[1], c[1], d[1]])

## Piste vers l'ouest : pieux à crâne tous les ~12 m, un cairn entre deux (repérables de loin).
func _piste() -> void:
	var k := 0
	for xm in [78.0, 68.0, 58.0]:
		var side := 1.0 if k % 2 == 0 else -1.0
		var zm := axe_piste(xm) + side * 2.1
		var w := Vector2(xm, zm)
		var xl := w.y - SITE.y
		var zl := SITE.x - w.x
		decor.trophee(_sol(xl, zl), 1.8 + 0.2 * k, 0.7 * k)
		k += 1
	k = 0
	for xm in [73.0, 63.0]:
		var side := -1.0 if k % 2 == 0 else 1.0
		var w := Vector2(xm, axe_piste(xm) + side * 2.0)
		var xl := w.y - SITE.y
		var zl := SITE.x - w.x
		var base := _sol(xl, zl)
		decor.rocher("c_roche_neige", base, 0.62, 0.5, 4300 + k, 0.6, true, 6)
		decor.rocher("c_roche_neige", base + Vector3(0.05, 0.42, 0.0), 0.42, 0.4, 4310 + k, 0.7, false, 6)
		decor.rocher("c_roche_neige", base + Vector3(-0.03, 0.74, 0.02), 0.26, 0.3, 4320 + k, 0.9, false, 5)
		k += 1

# ------------------------------------------------------------------ vie et passage
func _ready() -> void:
	_y0 = position.y
	_cont = Node3D.new()
	_cont.name = "Entree"
	_tache_ext = WorkerThreadPool.add_task(_construire)
	var p := vers_monde(0.0, 4.0)
	porte_dehors = Vector3(p.x, monde.hauteur(p.x, p.y), p.y)
	orientation = PI * 0.5            # en sortant, on regarde vers l'ouest (-X monde = +Z local) : avant = (-sin, -cos) du lacet

func _process(dt: float) -> void:
	_t += dt
	if joueur == null:
		return
	if _tache_ext >= 0 and WorkerThreadPool.is_task_completed(_tache_ext):
		attendre_exterieur()
	if not pret:
		return
	var d := Vector2(joueur.global_position.x - SITE.x, joueur.global_position.z - SITE.y).length()
	if not dedans:
		if d < 60.0:
			decor.vaciller(_t)
		# Construite en avance : dès que l'extérieur est posé et que le jeu a fini de charger (délai), ou plus tôt si on s'approche.
		if _tache < 0 and grotte == null and (d < DEPART_FIL or _t > DELAI_PREPARATION):
			_lancer_fil()
		if d < 10.0 and quetes != null:
			quetes.signaler("lieu:grotte")
	if _tache >= 0 and WorkerThreadPool.is_task_completed(_tache):
		_integrer()
	elif not _coque_a_poser.is_empty():
		grotte.add_child(_coque_a_poser.pop_back())    # un morceau de coque solide par image (forme Jolt construite à l'entrée dans le monde)
	if jeu != null:
		if dedans:
			jeu.tick(dt)
		else:
			jeu.surface(dt)       # joueur dehors : les ennemis de la grotte sont gelés

## Pose l'extérieur dans la scène (attend le fil s'il tourne encore).
func attendre_exterieur() -> void:
	if _tache_ext < 0:
		return
	FilVerrou.attendre(_tache_ext)
	_tache_ext = -1
	add_child(_cont)
	pret = true

func _creer_grotte() -> Grotte:
	var g := Grotte.nouvelle(joueur)
	return g

func _lancer_fil() -> void:
	_g_fil = _creer_grotte()
	_tache = WorkerThreadPool.add_task(_batir.bind(_g_fil))

## Le fil ne touche qu'à son argument (jamais à la scène ni aux membres de l'accès).
func _batir(g: Grotte) -> void:
	FilVerrou.prendre()
	g.construire()
	var meca: Array = []
	for a: Dictionary in g.accroches:
		if String(a.get("type", "")) == "meca":
			var d: Dictionary = (a["d"] as Dictionary).duplicate()
			d["materiau"] = true          # GrotteJeu._meca : murs dans la roche voisine (pas de pierre fissurée propre)
			meca.append(d)
	Mecanisme.peindre_textures(meca)      # textures des mécanismes peintes ici, pas à l'intégration (fil principal)
	FilVerrou.rendre()

func _integrer() -> void:
	if _tache < 0:
		return
	FilVerrou.attendre(_tache)
	_tache = -1
	_poser(_g_fil)
	_g_fil = null

var prechauffe: PrechauffeRendu
var _coque_a_poser: Array = []         # morceaux de coque solide pas encore dans l'arbre (posés un par image)

## Tous les morceaux de coque solide tout de suite (entrée, obtenir() synchrone des tests et des captures).
func _poser_coque() -> void:
	while not _coque_a_poser.is_empty():
		grotte.add_child(_coque_a_poser.pop_back())

## Points de vue du préchauffage : l'entrée, puis un point tous les 22 m le long de chaque branche (caméra à hauteur d'yeux, vers l'avant).
func _points_prechauffe() -> Array:
	var res: Array = []
	var routes: Dictionary = grotte.routes_test()
	for id: String in routes:
		var l: Array = routes[id]
		var k := 0
		while k < l.size() - 2:
			var a: Vector3 = l[k] + Vector3(0, 1.6, 0)
			var b: Vector3 = l[mini(k + 6, l.size() - 1)] + Vector3(0, 1.4, 0)
			if a.distance_to(b) > 0.5:
				res.append(Transform3D(Basis.looking_at(b - a, Vector3.UP), a))
			k += 22
	return res

func _poser(g: Grotte) -> void:
	grotte = g
	grotte.visible = false
	grotte.process_mode = Node.PROCESS_MODE_DISABLED
	# Corps statiques : gardés dans le monde physique pendant que la grotte est gelée (mode REMOVE par défaut : chaque bascule de
	# process_mode les retirait / remettait dans Jolt, 200-250 ms d'image figée à l'entrée et autant à la sortie ; ils sont à 200 m
	# sous le sol, rien de dehors ne les touche). Les morceaux de la coque solide (Grotte.coque_corps) entrent un par image (_process).
	for b in grotte.find_children("*", "StaticBody3D", true, false):
		(b as StaticBody3D).disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	_coque_a_poser = grotte.coque_corps.duplicate()
	for b in _coque_a_poser:
		grotte.remove_child(b)
	_coque_a_poser.reverse()           # pop_back = ordre d'origine
	monde.add_child(grotte)
	if not OS.get_cmdline_user_args().has("--sans-prechauffe"):
		var e: Environment = monde.env_prechauffe()
		grotte.ambiance(e)
		prechauffe = PrechauffeRendu.lancer(grotte, self, _points_prechauffe(), monde.cycle.lumiere, e)   # pipelines compilés avant l'entrée (1re image ~80-130 ms sinon)
	jeu = GrotteJeu.new()
	jeu.installer(self, grotte)
	_interactif_sortie()

## Sortie du jeu pendant la construction : on attend le fil (sinon fuites de ressources).
func _exit_tree() -> void:
	if jeu != null:
		jeu._ennemis_prets(true)       # fil de préparation des modèles d'ennemis
	if _tache_ext >= 0:
		FilVerrou.attendre(_tache_ext)
		_tache_ext = -1
		if _cont != null and is_instance_valid(_cont) and not _cont.is_inside_tree():
			_cont.free()
	if _tache >= 0:
		FilVerrou.attendre(_tache)
		_tache = -1
		if _g_fil != null and is_instance_valid(_g_fil) and not _g_fil.is_inside_tree():
			_g_fil.free()
		_g_fil = null
	for b in _coque_a_poser:
		if is_instance_valid(b) and not b.is_inside_tree():
			b.free()
	_coque_a_poser.clear()

## La grotte construite (attend le fil s'il tourne, la construit tout de suite sinon).
func obtenir() -> Grotte:
	if grotte != null:
		_poser_coque()
		return grotte
	if _tache >= 0:
		_integrer()
	else:
		var g := _creer_grotte()
		g.construire()
		_poser(g)
	_poser_coque()
	return grotte

func _interactif_sortie() -> void:
	var p := grotte.sol_en("T1", SORTIE_S, 0.0) + Vector3(0, 1.5, 0)
	var it := _interactif(p, "Sortie de la grotte", "Sortir de la grotte", func() -> Array: return _passer(false), grotte)
	it.rayon = 3.4

## Affiche / cache la grotte (sans fondu) : passage, restauration, captures.
func montrer(oui: bool) -> void:
	obtenir()
	dedans = oui
	if prechauffe != null and is_instance_valid(prechauffe):
		prechauffe.annuler()   # sinon son recachage de fin masquerait la grotte que le joueur vient d'ouvrir
	prechauffe = null
	grotte.visible = oui
	grotte.process_mode = Node.PROCESS_MODE_INHERIT if oui else Node.PROCESS_MODE_DISABLED

func _passer(vers_dedans: bool) -> Array:
	var t := create_tween()
	t.tween_method(func(v: float) -> void: monde.post.set_shader_parameter("fondu", v), 0.0, 1.0, 0.5)
	t.tween_callback(func() -> void:
		montrer(vers_dedans)
		if vers_dedans:
			joueur.global_position = grotte.monde_sol(ARRIVEE_S, 0.0) + Vector3(0, 0.1, 0)
			joueur.rotation.y = grotte.cap_monde(ARRIVEE_S)
		else:
			_rendre_flammes()
			joueur.global_position = porte_dehors + Vector3(0, 0.2, 0)
			joueur.rotation.y = orientation
		joueur.tete.rotation.x = 0.0
		joueur.velocity = Vector3.ZERO
		entree.emit(vers_dedans))
	t.tween_method(func(v: float) -> void: monde.post.set_shader_parameter("fondu", v), 1.0, 0.0, 0.6)
	Sons.jouer(self, ["doorOpen_1", "creak1"], -4.0)
	return []

## Dehors, la torche tenue retrouve ses flammes (la grotte les remplaçait par le sprite pixel art).
func _rendre_flammes() -> void:
	var mains: Node = joueur.get("mains")
	if mains == null:
		return
	for i in mains.flammes.size():
		if i != 3:
			mains.flammes[i].visible = true
	if grotte != null and grotte._flamme_pixel != null:
		grotte._flamme_pixel.visible = false

## Mort du joueur sous terre : il ressuscite dehors, la grotte se referme sans fondu.
func reinitialiser() -> void:
	if not dedans:
		return
	montrer(false)
	if jeu != null:
		jeu.reinitialiser(_morts_sauvegardes())
	_rendre_flammes()
	entree.emit(false)

## Ennemis tués dans le fichier de sauvegarde (la mort du joueur ne les ressuscite pas).
func _morts_sauvegardes() -> Array:
	var f: String = monde.fichier_sauvegarde()
	if FileAccess.file_exists(f):
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		if d is Dictionary:
			return d.get("draugrs_morts", [])
	return []

## Partie sauvegardée dans la grotte : on y revient exactement là (la position est celle du fichier).
func restaurer() -> void:
	if joueur.global_position.y < SEUIL_Y:
		montrer(true)
		entree.emit.call_deferred(true)

func _interactif(pos: Vector3, nom: String, verbe: String, action: Callable, parent: Node3D) -> Node3D:
	var it := Node3D.new()
	it.set_script(preload("res://scripts/interactif.gd"))
	it.joueur = joueur
	it.dialogue = dialogue
	it.nom = nom
	it.verbe = verbe
	it.action = action
	it.rayon = 3.0
	it.position = pos
	parent.add_child(it)
	return it
