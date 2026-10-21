class_name AbordsVillage
extends Node3D
## Abords d'un village (refonte graphique, prototype « entrée du village ») : chemin de grandes dalles de pierre
## irrégulières à joints enneigés, poteaux à potence et lanterne de fer (lumière orange chaude), barrière de bois
## rustique neigée, pierre levée sculptée d'entrelacs en losange, rochers coiffés de neige, buissons brun-rouge,
## touffes d'herbe sèche givrées, cailloux, congères au pied des objets.
##
## KIT RÉUTILISABLE : tout est exprimé dans le repère du sentier (u = distance depuis la porte vers l'extérieur,
## v = décalage latéral, positif à droite quand on regarde le village) ; la composition « entrée » est jitterée par
## la graine (variantes) et l'on peut habiller n'importe quel segment (`habiller`). RNG propre, `monde.rng` jamais touché.
##
## Coût : tout est fusionné par matériau (dalles, pierre+neige, rondins, bouts, fer, verre, gravure) + MultiMesh pour
## buissons/touffes/cailloux ; ~10 appels de dessin. Lumières : 2 OmniLight sans ombre, portée 6 m, distance_fade
## (au plus une visible avec les 2 torches de la porte) ; les autres lanternes sont émissives seulement.
## Collisions : poteaux, pierre levée et gros rochers seulement (formes simples, hors de la piste).
## `--sans-abords` : désactive tout (A/B).

const PORTEE := 80.0                 # ≤ FIN_MAX + 5 (brouillard)
const DEMI_LARGEUR := 1.3            # demi-largeur du dallage (m)
const VILLAGE_RAYON := 22.0          # palissade (village.gd RAYON)
const COULEUR_LANTERNE := Color(1.0, 0.62, 0.32)   # préréglage « Lanterne » (DIRECTION_ARTISTIQUE §6)
const VITRE_LANTERNE := Color("#fcb53a")

var monde: Node
var rng := RandomNumberGenerator.new()
var origine := Vector2.ZERO          # porte (x, z)
var axe := Vector2.RIGHT             # de la porte vers l'extérieur
var droite := Vector2.DOWN           # à droite en regardant le village
var longueur := 0.0

var _dalles := BatiGeo.Maillage.new()
var _pierre := BatiGeo.Maillage.new()   # rochers, pierre levée, congères, neige posée sur le bois (alpha 0 = neige)
var _bois := BatiGeo.Maillage.new()
var _bouts := BatiGeo.Maillage.new()
var _fer := BatiGeo.Maillage.new()
var _verre := BatiGeo.Maillage.new()
var _gravure := BatiGeo.Maillage.new()
var _buissons: Array = []
var _touffes: Array = []
var _cailloux: Array = []
var _occupe: Array = []                 # [Vector2, rayon] : pas de buisson ni de touffe dedans
var _corps: StaticBody3D
var _lumieres: Array = []               # [OmniLight3D, énergie, phase]
var _t := 0.0
var _nb_sapins := 0

## Habille l'entrée du village de `monde` (sentier feu → porte). `graine` = variante.
static func creer(monde_: Node, graine := 0) -> AbordsVillage:
	var a := AbordsVillage.new()
	a.name = "AbordsVillage"
	a.monde = monde_
	a.rng.seed = (graine if graine != 0 else hash("abords_village")) & 0x7fffffff
	var seg := Chemins.axe_village(monde_)
	a._repere(seg[1], seg[0])
	monde_.add_child(a)
	a._corps = StaticBody3D.new()
	a.add_child(a._corps)
	a._entree()
	a._finaliser()
	return a

func _repere(porte: Vector2, exterieur: Vector2) -> void:
	origine = porte
	longueur = porte.distance_to(exterieur)
	axe = (exterieur - porte) / longueur
	var vers_village := -axe
	droite = Vector2(-vers_village.y, vers_village.x)
	position = Vector3(origine.x, 0.0, origine.y)

# --- repère ------------------------------------------------------------------------------------------------------

func _p(u: float, v: float) -> Vector2:
	return origine + axe * u + droite * v

func _sol(p: Vector2) -> float:
	return DetailsSol.hauteur_maillage(monde, p.x, p.y)

func _sol_bas(p: Vector2, r: float) -> float:
	return minf(minf(_sol(p + Vector2(r, 0)), _sol(p - Vector2(r, 0))), minf(minf(_sol(p + Vector2(0, r)), _sol(p - Vector2(0, r))), _sol(p)))

## Point du monde (x, y, z) → repère local du nœud.
func _l(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x - origine.x, y, p.y - origine.y)

## Lacet (rotation autour de Y) qui envoie +X sur la direction `d` (x, z).
static func _lacet_x(d: Vector2) -> float:
	return atan2(-d.y, d.x)

static func _base_axe(x: Vector3) -> Basis:
	x = x.normalized()
	var ref := Vector3.UP if absf(x.y) < 0.9 else Vector3.RIGHT
	var z := x.cross(ref).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)

static func _ajouter(dst: BatiGeo.Maillage, src: BatiGeo.Maillage, xf: Transform3D) -> void:
	var b := xf.basis.orthonormalized()
	for i in src.v.size():
		dst.v.append(xf * src.v[i])
		dst.n.append((b * src.n[i]).normalized())
		dst.uv.append(src.uv[i])
		dst.c.append(src.c[i])

# --- composition « entrée du village » ------------------------------------------------------------------------------

func _j(x: float, a: float) -> float:
	return x + rng.randf_range(-a, a)

func _entree() -> void:
	var cote := 1.0 if rng.randf() < 0.85 else -1.0   # variante miroir (rare : la vue de référence a la lanterne à gauche)
	_dalles_segment(-1.6, longueur - 1.0)
	# poteaux à lanterne : A au premier plan (vraie lumière), B près de la porte (émissive), C plus bas sur le sentier (vraie lumière)
	_poteau_lanterne(_j(4.8, 0.2), -2.3 * cote, cote, true)
	_poteau_lanterne(_j(1.9, 0.15), 2.8 * cote, -cote, false)
	_poteau_lanterne(_j(17.0, 1.0), 2.5 * cote, -cote, true)
	_poteau_lanterne(_j(26.5, 0.8), -2.4 * cote, cote, false)
	# barrières : à gauche vers la porte, à droite plus bas sur le sentier
	_barriere([Vector2(6.0, -4.4 * cote), Vector2(4.1, -3.75 * cote), Vector2(2.3, -3.35 * cote), Vector2(0.7, -3.05 * cote)])
	_barriere([Vector2(9.6, 3.9 * cote), Vector2(11.6, 4.3 * cote), Vector2(13.5, 4.5 * cote), Vector2(15.4, 4.3 * cote)])
	_barriere([Vector2(20.5, -3.8 * cote), Vector2(22.4, -4.2 * cote), Vector2(24.2, -4.0 * cote)])
	# pierre levée sculptée, face tournée vers ceux qui arrivent
	var ps := Vector2(_j(3.6, 0.15), 3.3 * cote)
	_pierre_levee(_p(ps.x, ps.y), (axe * 1.0 - droite * cote * 0.8).normalized())
	# rochers coiffés de neige [u, v, taille]
	for r in [[5.1, -3.45, 1.4], [6.8, -5.3, 1.6], [2.9, -5.0, 0.8], [5.0, 3.65, 1.35], [7.0, 5.2, 1.0], [1.9, 4.8, 0.75],
			[11.0, -3.5, 0.9], [14.2, -4.9, 1.3], [9.4, 4.4, 0.7], [19.6, 3.9, 1.1], [23.0, -3.4, 0.8], [27.5, 3.6, 1.0]]:
		_rocher(_j(r[0], 0.3), _j(r[1] * cote, 0.15), r[2] * rng.randf_range(0.88, 1.12))
	# buissons brun-rouge : quelques-uns placés (cadrage), d'autres semés le long des bords
	for b in [[6.1, -2.95], [3.7, -4.4], [4.5, 4.7], [2.6, 4.0], [6.4, 3.3], [1.2, -3.9], [8.0, -3.3], [10.4, 3.5], [12.6, -4.0], [16.2, 3.6], [6.9, -4.3], [4.3, 3.0]]:
		_buisson(_p(_j(b[0], 0.2), _j(b[1] * cote, 0.15)), rng.randf_range(0.75, 1.15))
	# sapins chargés de neige de part et d'autre, du premier plan jusqu'à la porte (la porte reste visible au bout)
	_sapins([[7.6, -6.6, 1.2], [3.0, -6.6, 1.0], [10.6, -5.6, 1.1], [14.0, -7.6, 1.3], [18.2, -5.4, 1.0], [22.0, -6.8, 1.2], [26.0, -5.6, 1.0], [30.0, -7.2, 1.1],
			[6.4, 6.9, 1.15], [2.4, 7.4, 1.0], [11.2, 7.2, 1.2], [16.6, 6.3, 1.0], [21.0, 7.6, 1.3], [25.2, 5.8, 1.0], [29.2, 6.8, 1.2], [33.0, 5.8, 1.0]], 14, 2.0, longueur + 4.0)
	_semer_bords(0.5, longueur - 1.5)

## Sapins qui encadrent le sentier : les épicéas validés du lot 2 (API `Arbres`, mêmes graines et mêmes réglages de portée,
## d'ombre et de silhouette lointaine que la forêt), une liste de cadrage [u, v, échelle] puis un remplissage au hasard.
## Hors de la palissade, hors du dallage (|v| ≥ 3,6 m), loin des autres objets. Collision : le tronc (comme la forêt).
## Ils ne sont pas ajoutés à `monde.arbres` (carte de sol et brume locale inchangées).
func _sapins(liste: Array, nb_remplir: int, u0: float, u1: float) -> void:
	var centre_village := Vector2(monde.VILLAGE.x, monde.VILLAGE.z)
	var r_min: float = VILLAGE_RAYON + 2.2
	var pris: Array[Vector2] = []
	var lots: Array = [[], [], []]
	var essais: Array = []
	for t in liste:
		essais.append([_j(t[0], 0.4), _j(t[1], 0.3), float(t[2])])
	for i in nb_remplir * 4:
		essais.append([rng.randf_range(u0, u1), rng.randf_range(5.0, 13.0) * (1.0 if rng.randf() < 0.5 else -1.0), rng.randf_range(0.85, 1.3)])
	var remplis := 0
	for k in essais.size():
		var e: Array = essais[k]
		var forme := rng.randi() % 3
		var lacet := rng.randf() * TAU
		var pench := rng.randf_range(-0.04, 0.04)
		var sy := rng.randf_range(0.9, 1.2)
		if k >= liste.size() and remplis >= nb_remplir:
			break
		var p := _p(e[0], e[1])
		if absf(e[1]) < 3.6 or p.distance_to(centre_village) < r_min or not _libre(p, 1.0):
			continue
		var serre := false
		for q in pris:
			if q.distance_to(p) < 2.6:
				serre = true
				break
		if serre:
			continue
		if k >= liste.size():
			remplis += 1
		pris.append(p)
		var s: float = e[2]
		var b := Basis(Vector3(1, 0, 0), pench) * Basis(Vector3.UP, lacet)
		b = b.scaled(Vector3(s, s * sy, s))
		lots[forme].append(Transform3D(b, Vector3(p.x, monde.hauteur(p.x, p.y) - 0.15, p.y)))
		_occupe.append([p, 0.8])
		var forme_col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.35
		cyl.height = 4.0
		forme_col.shape = cyl
		forme_col.position = _l(p, monde.hauteur(p.x, p.y) + 2.0)
		_corps.add_child(forme_col)
	var mats := Arbres.materiaux_epicea()
	var pp: float = Vegetation.PORTEE_PLEINE
	for f in 3:
		if lots[f].is_empty():
			continue
		Instanciation.repartir(monde, Arbres.epicea(f, 11 + f, mats), lots[f], {"portee": pp, "marge": 4.0, "ombre_proche": pp,
			"lod_mesh": Arbres.epicea_lointain(f, 11 + f, mats), "ombre_mesh": Arbres.epicea_ombre(f, 11 + f, mats[0]),
			"lod_debut": pp - 4.0, "lod_portee": Vegetation.PORTEE_LOD})
		_nb_sapins += lots[f].size()

## Dallage en pierres irrégulières (cellules de Voronoï sur une grille décalée et bruitée, rétrécies d'un joint, coins
## rabotés) de u0 à u1 ; les dalles s'espacent vers u1 (le dallage se perd dans la neige). Bords de piste irréguliers :
## les cellules du bord gardent leur contour naturel.
func _dalles_segment(u0: float, u1: float) -> void:
	var bruit := FastNoiseLite.new()
	bruit.seed = rng.randi()
	bruit.frequency = 0.12
	var sites: Array[Vector2] = []
	var joints := PackedFloat32Array()
	var grille := {}
	var su := 0.7
	var sv := 0.74
	var rang := 0
	var u := u0
	while u < u1 + su:
		var c := bruit.get_noise_1d(u + 100.0) * 0.18
		var v := c - DEMI_LARGEUR - 0.9 + (sv * 0.5 if rang % 2 == 1 else 0.0)
		while v < c + DEMI_LARGEUR + 0.9:
			var s := Vector2(u + rng.randf_range(-0.24, 0.24) * su, v + rng.randf_range(-0.26, 0.26) * sv)
			var cle := Vector2i(floori(s.x), floori(s.y))
			if not grille.has(cle):
				grille[cle] = []
			grille[cle].append(sites.size())
			sites.append(s)
			joints.append(rng.randf_range(0.035, 0.065))
			v += sv * rng.randf_range(0.85, 1.2)
		u += su * rng.randf_range(0.85, 1.15)
		rang += 1
	for i in sites.size():
		var s := sites[i]
		var c := bruit.get_noise_1d(s.x + 100.0) * 0.18
		var demi := DEMI_LARGEUR + bruit.get_noise_1d(s.x) * 0.25
		var tirage := rng.randf()
		var rare := smoothstep(u1 - 7.0, u1, s.x)
		if absf(s.y - c) > demi or s.x < u0 or s.x > u1 or tirage < 0.04 + rare * 0.6:
			continue
		var r := 0.5
		var poly: Array[Vector2] = [s + Vector2(-r, -r), s + Vector2(r, -r), s + Vector2(r, r), s + Vector2(-r, r)]
		var cle := Vector2i(floori(s.x), floori(s.y))
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				for jq in grille.get(cle + Vector2i(dx, dy), []):
					if jq == i:
						continue
					var q := sites[jq]
					if q.distance_squared_to(s) > 2.6:
						continue
					var nrm := (q - s).normalized()
					var lim := (q - s).length() * 0.5 - (joints[i] + joints[jq]) * 0.5
					poly = _couper(poly, s, nrm, lim)
					if poly.size() < 3:
						break
		if poly.size() < 3:
			continue
		# coins rabotés (Chaikin, une passe) : pierres arrondies
		var douce: Array[Vector2] = []
		for k in poly.size():
			var a := poly[k]
			var b := poly[(k + 1) % poly.size()]
			douce.append(a.lerp(b, 0.22))
			douce.append(a.lerp(b, 0.78))
		var aire := 0.0
		for k in douce.size():
			aire += (douce[k] - s).cross(douce[(k + 1) % douce.size()] - s) * 0.5
		if absf(aire) < 0.07:
			continue
		_dalle(douce, s, c)

## Garde la partie du polygone où (x - s)·n <= lim (Sutherland-Hodgman, un demi-plan).
static func _couper(poly: Array[Vector2], s: Vector2, n: Vector2, lim: float) -> Array[Vector2]:
	var res: Array[Vector2] = []
	var m := poly.size()
	for k in m:
		var a := poly[k]
		var b := poly[(k + 1) % m]
		var da := (a - s).dot(n) - lim
		var db := (b - s).dot(n) - lim
		if da <= 0.0:
			res.append(a)
		if (da <= 0.0) != (db <= 0.0):
			res.append(a.lerp(b, da / (da - db)))
	return res

## Une dalle : dessus en éventail (léger bombé, bascule), flancs jusque sous le sol. Neige : le bas des flancs (alpha 0)
## remplit les joints ; certains bords du dessus sont poudrés (plus sur les bords de la piste qu'au milieu, piétiné).
func _dalle(poly: Array[Vector2], c2: Vector2, centre_v: float) -> void:
	var kt := rng.randf_range(0.82, 1.12)
	var chaud := rng.randf_range(-0.03, 0.05)
	var col_haut := Color(kt + chaud, kt, kt - chaud * 0.5, 1.0)
	var col_flanc := Color(kt * 0.62, kt * 0.62, kt * 0.64, 1.0)
	var col_pied := Color(0.9, 0.9, 0.95, 0.0)
	var p_neige := 0.15 + 0.5 * smoothstep(0.3, 1.25, absf(c2.y - centre_v))
	var bascule := Vector2(rng.randf_range(-0.025, 0.025), rng.randf_range(-0.025, 0.025))
	var epais := rng.randf_range(0.025, 0.045)
	var haut: Array[Vector3] = []
	var bas: Array[Vector3] = []
	var cols: Array[Color] = []
	var y_moy := 0.0
	for q in poly:
		var w := _p(q.x, q.y)
		var y := _sol(w) + epais + (q - c2).dot(bascule)
		y_moy += y
		haut.append(_l(w, y))
		var d := (q - c2).normalized() * 0.035
		var wb := _p(q.x + d.x, q.y + d.y)
		bas.append(_l(wb, _sol(wb) - 0.03))
		var t := rng.randf()
		cols.append(Color(col_haut.r, col_haut.g, col_haut.b, 0.0 if t < p_neige * 0.3 else (0.3 if t < p_neige else 1.0)))
	y_moy /= poly.size()
	var cw := _p(c2.x, c2.y)
	var ctr := _l(cw, y_moy + 0.012)
	var dessous := ctr - Vector3(0, 1.0, 0)
	var n := poly.size()
	for i in n:
		var i2 := (i + 1) % n
		_dalles.tri(haut[i], haut[i2], ctr, cols[i], cols[i2], col_haut, dessous)
		_dalles.quad(bas[i], bas[i2], haut[i2], haut[i], col_pied, col_pied, col_flanc, col_flanc, ctr - Vector3(0, 0.03, 0))

## Rocher arrondi coiffé d'une épaisse calotte de neige (débordante), posé sur la pente ; congère du côté opposé à la piste.
func _rocher(u: float, v: float, s: float) -> void:
	var p := _p(u, v)
	var y0 := _sol_bas(p, s * 0.35)
	var n := FastNoiseLite.new()
	n.seed = rng.randi()
	n.frequency = 1.1
	var sx := s * 0.5 * rng.randf_range(0.85, 1.15)
	var sz := s * 0.5 * rng.randf_range(0.7, 0.95)
	var sy := s * 0.42 * rng.randf_range(0.8, 1.15)
	var base := Basis(Vector3.UP, rng.randf() * TAU)
	var S := 9
	var R := 5
	var anneaux: Array = []
	var alphas: Array = []
	for r in R:
		var phi := lerpf(-0.32 * PI, 0.40 * PI, float(r) / (R - 1))
		var ring := PackedVector3Array()
		var al := PackedFloat32Array()
		for k in S:
			var a := TAU * k / S + r * 0.3
			var d := Vector3(cos(phi) * cos(a), sin(phi), cos(phi) * sin(a))
			var f := 1.0 + n.get_noise_3dv(d * 2.0) * 0.32
			var q := Vector3(d.x * sx, d.y * sy + sy * 0.3, d.z * sz) * f
			if q.y < 0.0:
				q.y *= 0.5
			var neige := d.y + n.get_noise_3dv(d * 3.0 + Vector3(9, 9, 9)) * 0.3 > 0.42
			if neige:   # calotte : gonflée et débordante
				q += Vector3(d.x * 0.05, 0.06, d.z * 0.05) * s
			ring.append(q)
			al.append(0.0 if neige else 1.0)
		anneaux.append(ring)
		alphas.append(al)
	var sommet := Vector3(0, sy * 1.3 + 0.07 * s, 0) + Vector3(n.get_noise_1d(5.0), 0, n.get_noise_1d(7.0)) * 0.1 * s
	var centre := Vector3(0, sy * 0.3, 0)
	var xf := Transform3D(base, _l(p, y0 - 0.04 * s))
	var col := func(r: int, al: float) -> Color:
		var kk := lerpf(0.5, 1.0, float(r) / (R - 1))
		return Color(kk, kk, kk * 1.02, al)
	for r in R - 1:
		var a: PackedVector3Array = anneaux[r]
		var b: PackedVector3Array = anneaux[r + 1]
		var aa: PackedFloat32Array = alphas[r]
		var ab: PackedFloat32Array = alphas[r + 1]
		for k in S:
			var k2 := (k + 1) % S
			_pierre.tri(xf * a[k], xf * a[k2], xf * b[k2], col.call(r, aa[k]), col.call(r, aa[k2]), col.call(r + 1, ab[k2]), xf * centre)
			_pierre.tri(xf * a[k], xf * b[k2], xf * b[k], col.call(r, aa[k]), col.call(r + 1, ab[k2]), col.call(r + 1, ab[k]), xf * centre)
	var dernier: PackedVector3Array = anneaux[R - 1]
	var neige_c := Color(1, 1, 1, 0.0)
	for k in S:
		var k2 := (k + 1) % S
		_pierre.tri(xf * dernier[k], xf * dernier[k2], xf * sommet, col.call(R - 1, 0.0), col.call(R - 1, 0.0), neige_c, xf * centre)
	# congère au pied, du côté opposé à la piste
	var dehors := (droite * signf(v)).normalized()
	var dir := dehors.rotated(rng.randf_range(-0.6, 0.6))
	_congere(p + dir * (minf(sx, sz) * 0.75), dir.orthogonal(), s * 0.95, s * 0.55, s * 0.2)
	_occupe.append([p, maxf(sx, sz) * 0.9])
	if s >= 0.7:
		var forme := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = minf(sx, sz) * 0.85
		cyl.height = sy * 1.3
		forme.shape = cyl
		forme.position = _l(p, y0 + sy * 0.55)
		_corps.add_child(forme)
	# touffes et buissons collés au rocher (côté dehors)
	for i in rng.randi_range(1, 3):
		var a2 := dehors.rotated(rng.randf_range(-1.4, 1.4))
		_touffe(p + a2 * (maxf(sx, sz) + rng.randf_range(0.05, 0.3)), rng.randf_range(0.7, 1.1))

## Congère : butte de neige allongée (L le long de `dir`), plus raide côté vent, collée au relief.
func _congere(c: Vector2, dir: Vector2, L: float, W: float, H: float) -> void:
	dir = dir.normalized()
	var perp := dir.orthogonal()
	var S := 10
	var fr: Array[float] = [1.0, 0.72, 0.4]
	var hs: Array[float] = [-0.05, 0.62, 0.92]
	var anneaux: Array = []
	var ph := rng.randf() * TAU
	for r in fr.size():
		var ring := PackedVector3Array()
		for k in S:
			var a := TAU * k / S
			var ca := cos(a)
			var sa := sin(a) * (0.75 if sin(a) < 0.0 else 1.0)   # côté vent plus court (plus raide)
			var jit := 1.0 + 0.12 * sin(a * 3.0 + ph)
			var w: Vector2 = c + dir * (ca * L * 0.5 * fr[r] * jit) + perp * (sa * W * 0.5 * fr[r] * jit)
			ring.append(_l(w, _sol(w) + H * hs[r]))
		anneaux.append(ring)
	var top := _l(c, _sol(c) + H)
	var dessous := _l(c, _sol(c) - 1.0)
	var blanc := Color(0.96, 0.96, 0.98, 0.0)
	var pied := Color(0.86, 0.86, 0.9, 0.0)
	for r in fr.size() - 1:
		var a: PackedVector3Array = anneaux[r]
		var b: PackedVector3Array = anneaux[r + 1]
		for k in S:
			var k2 := (k + 1) % S
			_pierre.quad(a[k], a[k2], b[k2], b[k], pied if r == 0 else blanc, pied if r == 0 else blanc, blanc, blanc, dessous)
	var d2: PackedVector3Array = anneaux[fr.size() - 1]
	for k in S:
		_pierre.tri(d2[k], d2[(k + 1) % S], top, blanc, blanc, blanc, dessous)

## Bourrelet de neige posé sur une pièce horizontale de a à b (dessus à y), largeur `l`.
func _neige_sur(a: Vector3, b: Vector3, l: float, h: float) -> void:
	var d := b - a
	var lat := Vector3(-d.z, 0, d.x).normalized() * l * 0.5
	var n := maxi(2, ceili(d.length() / 0.35))
	var blanc := Color(1, 1, 1, 0.0)
	var prec: Array = []
	for i in n + 1:
		var t := float(i) / n
		var bout := smoothstep(0.0, 0.12, t) * smoothstep(1.0, 0.88, t)
		var p := a.lerp(b, t)
		var hh := h * (0.45 + 0.55 * bout) * rng.randf_range(0.75, 1.15)
		var cur := [p + lat * 1.05 - Vector3(0, 0.012, 0), p + Vector3(0, hh, 0) + lat * rng.randf_range(-0.2, 0.2), p - lat * 1.05 - Vector3(0, 0.012, 0)]
		if not prec.is_empty():
			var ctr := p - Vector3(0, 0.3, 0)
			_pierre.quad(prec[0], cur[0], cur[1], prec[1], blanc, blanc, blanc, blanc, ctr)
			_pierre.quad(prec[1], cur[1], cur[2], prec[2], blanc, blanc, blanc, blanc, ctr)
		prec = cur
	# bouchons aux extrémités
	pass

## Calotte de neige (pyramide basse à 6 pans) sur le dessus d'un poteau de rayon r.
func _calotte(c: Vector3, r: float, h: float) -> void:
	var blanc := Color(1, 1, 1, 0.0)
	var top := c + Vector3(rng.randf_range(-0.2, 0.2) * r, h, rng.randf_range(-0.2, 0.2) * r)
	var anneau: Array[Vector3] = []
	for k in 6:
		var a := TAU * k / 6.0
		anneau.append(c + Vector3(cos(a), 0, sin(a)) * r * 1.15 + Vector3(0, -0.015, 0))
	for k in 6:
		_pierre.tri(anneau[k], anneau[(k + 1) % 6], top, blanc, blanc, blanc, c - Vector3(0, 0.3, 0))

## Rondin (fût + bouts) de a à b, rayon r.
func _rondin(a: Vector3, b: Vector3, r: float, sag := 0.0, teinte := 1.0) -> void:
	var l := a.distance_to(b)
	var res: Array = BatiGeo.rondin(l, r, rng.randi() % 100000, sag, rng.randi() % 4, rng.randf() * 3.0, teinte)
	var xf := Transform3D(_base_axe(b - a), (a + b) * 0.5)
	_ajouter(_bois, res[0], xf)
	_ajouter(_bouts, res[1], xf)

## Boîte orientée (fer ou verre) : UV 0..1 par face.
func _boite(m: BatiGeo.Maillage, c: Vector3, taille: Vector3, b: Basis, col: Color) -> void:
	var h := taille * 0.5
	var faces := [[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP], [Vector3.BACK, Vector3.LEFT, Vector3.UP],
		[Vector3.FORWARD, Vector3.RIGHT, Vector3.UP], [Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD]]
	for f in faces:
		var nn: Vector3 = f[0]
		var tu: Vector3 = f[1]
		var tv: Vector3 = f[2]
		var o := nn * h
		var eu := tu * h
		var ev := tv * h
		var p0 := c + b * (o - eu - ev)
		var p1 := c + b * (o + eu - ev)
		var p2 := c + b * (o + eu + ev)
		var p3 := c + b * (o - eu + ev)
		m.tri(p0, p1, p2, col, col, col, c, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0))
		m.tri(p0, p2, p3, col, col, col, c, Vector2(0, 1), Vector2(1, 0), Vector2(0, 0))

## Poteau de bois massif à potence + lanterne de fer. `bras` = +1 : la potence part vers +v. `reelle` : vraie lumière.
func _poteau_lanterne(u: float, v: float, bras: float, reelle: bool) -> void:
	var p := _p(u, v)
	var y0 := _sol_bas(p, 0.2)
	var H := rng.randf_range(2.9, 3.2)
	var r := rng.randf_range(0.12, 0.14)
	var pied := _l(p, y0 - 0.25)
	var tete := _l(p, y0 + H)
	tete += Vector3(rng.randf_range(-0.04, 0.04), 0, rng.randf_range(-0.04, 0.04))
	_rondin(pied, tete, r, 0.0, 0.95)
	_calotte(tete, r, 0.1)
	# potence : bras horizontal qui dépasse un peu derrière le poteau, contrefiche
	var d3 := Vector3(droite.x, 0, droite.y) * bras
	d3 = d3.rotated(Vector3.UP, rng.randf_range(-0.12, 0.12))
	var yb := H - 0.28
	var b0 := _l(p, y0 + yb) - d3 * 0.22
	var b1 := _l(p, y0 + yb) + d3 * 1.05
	_rondin(b0, b1, 0.075, 0.015, 0.9)
	_neige_sur(b0 + Vector3(0, 0.07, 0), b1 + Vector3(0, 0.06, 0), 0.15, 0.07)
	_rondin(_l(p, y0 + yb - 0.8) + d3 * 0.1, _l(p, y0 + yb - 0.04) + d3 * 0.62, 0.05, 0.0, 0.85)
	# colliers de fer sur le poteau
	for hy in [yb - 0.15, 0.9]:
		_boite(_fer, _l(p, y0 + hy), Vector3(r * 2.25, 0.06, r * 2.25), Basis(Vector3.UP, rng.randf() * TAU), Color(0.8, 0.8, 0.8, 1))
	# lanterne : crochet, cage de fer, verre émissif
	var cro := _l(p, y0 + yb) + d3 * 0.92
	var bl := Basis(Vector3.UP, _lacet_x(droite) + rng.randf_range(-0.3, 0.3))
	_boite(_fer, cro - Vector3(0, 0.1, 0), Vector3(0.025, 0.16, 0.025), bl, Color(0.7, 0.7, 0.7, 1))
	var lc := cro - Vector3(0, 0.42, 0)
	var gris := Color(0.85, 0.85, 0.85, 1)
	_boite(_verre, lc, Vector3(0.17, 0.24, 0.17), bl, Color(1, 1, 1, 1))
	_boite(_fer, lc + Vector3(0, 0.135, 0), Vector3(0.23, 0.035, 0.23), bl, gris)      # toit
	_boite(_fer, lc + Vector3(0, 0.175, 0), Vector3(0.15, 0.05, 0.15), bl, gris)
	_boite(_fer, lc + Vector3(0, 0.215, 0), Vector3(0.07, 0.04, 0.07), bl, gris)
	_boite(_fer, lc - Vector3(0, 0.135, 0), Vector3(0.21, 0.03, 0.21), bl, gris)      # socle
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_boite(_fer, lc + bl * Vector3(sx * 0.09, 0, sz * 0.09), Vector3(0.025, 0.25, 0.025), bl, gris)
	_calotte(lc + Vector3(0, 0.155, 0), 0.11, 0.05)
	if reelle:
		var l := OmniLight3D.new()
		l.light_color = COULEUR_LANTERNE
		l.light_energy = 1.1
		l.light_indirect_energy = 0.0
		l.omni_range = 6.0
		l.omni_attenuation = 1.6
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 18.0
		l.distance_fade_length = 6.0
		l.position = lc
		add_child(l)
		_lumieres.append([l, l.light_energy, rng.randf() * 10.0])
	# congère au pied, collision du poteau
	_congere(p + axe * 0.1, droite, 0.75, 0.6, 0.16)
	_occupe.append([p, 0.35])
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r + 0.04
	cyl.height = H
	forme.shape = cyl
	forme.position = _l(p, y0 + H * 0.5)
	_corps.add_child(forme)

## Barrière rustique : piquets à chaque point (u, v), deux lisses irrégulières par travée, neige sur le dessus,
## congère le long de la travée. Collision : les piquets seulement.
func _barriere(pts: Array) -> void:
	var tetes: Array[Vector3] = []
	var pieds: Array[Vector2] = []
	for q: Vector2 in pts:
		var p := _p(q.x + rng.randf_range(-0.08, 0.08), q.y + rng.randf_range(-0.05, 0.05))
		var y0 := _sol_bas(p, 0.1)
		var h := rng.randf_range(1.0, 1.2)
		var pen := Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))
		var r := rng.randf_range(0.075, 0.095)
		var tete := _l(p, y0 + h) + pen
		_rondin(_l(p, y0 - 0.2), tete, r, 0.0, 0.92)
		_calotte(tete, r, 0.08)
		tetes.append(tete)
		pieds.append(p)
		_occupe.append([p, 0.25])
		var forme := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r + 0.03
		cyl.height = h + 0.1
		forme.shape = cyl
		forme.position = _l(p, y0 + h * 0.5)
		_corps.add_child(forme)
	for i in pts.size() - 1:
		var pa := pieds[i]
		var pb := pieds[i + 1]
		var ya := _sol(pa)
		var yb := _sol(pb)
		var d := (pb - pa).normalized()
		for niv in [0.42, 0.82]:
			var ha: float = niv + rng.randf_range(-0.06, 0.06)
			var hb: float = niv + rng.randf_range(-0.06, 0.06)
			var off := Vector3(-d.y, 0, d.x) * 0.1   # lisse posée devant les piquets
			var a := _l(pa - d * rng.randf_range(0.05, 0.25), ya + ha) + off
			var b := _l(pb + d * rng.randf_range(0.05, 0.25), yb + hb) + off
			var rr := rng.randf_range(0.045, 0.06)
			_rondin(a, b, rr, 0.03, 0.88)
			_neige_sur(a + Vector3(0, rr * 0.9, 0), b + Vector3(0, rr * 0.9, 0), rr * 2.6, 0.06)
		var mil := (pa + pb) * 0.5
		_congere(mil + Vector2(-d.y, d.x) * rng.randf_range(-0.15, 0.15), d, pa.distance_to(pb) * 1.05, 0.7, 0.2)
		for t in rng.randi_range(1, 3):
			_touffe(pa.lerp(pb, rng.randf()) + Vector2(-d.y, d.x) * rng.randf_range(-0.4, 0.4), rng.randf_range(0.8, 1.2))

## Pierre levée sculptée d'entrelacs en losange, coiffée de neige, face gravée tournée vers `face` (x, z).
func _pierre_levee(p: Vector2, face: Vector2) -> void:
	var taille := Vector3(0.85, 2.3, 0.42)
	var m := BatiGeo.pierre_levee(taille, 7000 + rng.randi() % 1000, true)
	var y0 := _sol_bas(p, 0.4)
	var b := Basis(Vector3.UP, atan2(face.x, face.y)) * Basis(Vector3.BACK, rng.randf_range(-0.03, 0.03))
	var c := _l(p, y0 + taille.y * 0.5 - 0.22)
	_ajouter(_pierre, m, Transform3D(b, c))
	# gravure : quad plaqué sur la face +Z (et une plus petite au dos)
	for cote in [1.0, -1.0]:
		var zq: float = 0.226 * cote
		var w := 0.5 if cote > 0.0 else 0.4
		var hq := 1.42 if cote > 0.0 else 1.1
		var yq := -0.08
		var p0 := c + b * Vector3(-w * 0.5 * cote, yq - hq * 0.5, zq)
		var p1 := c + b * Vector3(w * 0.5 * cote, yq - hq * 0.5, zq)
		var p2 := c + b * Vector3(w * 0.5 * cote, yq + hq * 0.5, zq)
		var p3 := c + b * Vector3(-w * 0.5 * cote, yq + hq * 0.5, zq)
		var blanc := Color.WHITE
		var ctr := c
		_gravure.tri(p0, p1, p2, blanc, blanc, blanc, ctr, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0))
		_gravure.tri(p0, p2, p3, blanc, blanc, blanc, ctr, Vector2(0, 1), Vector2(1, 0), Vector2(0, 0))
	_congere(p - face * 0.15, face.orthogonal(), 1.3, 0.9, 0.24)
	_occupe.append([p, 0.6])
	var forme := CollisionShape3D.new()
	var bf := BoxShape3D.new()
	bf.size = Vector3(taille.x * 0.9, taille.y * 0.95, taille.z)
	forme.shape = bf
	forme.transform = Transform3D(b, c)
	_corps.add_child(forme)
	for i in 3:
		_touffe(p + face.rotated(rng.randf_range(-2.0, 2.0)) * rng.randf_range(0.5, 0.8), rng.randf_range(0.8, 1.2))

func _buisson(p: Vector2, s: float) -> void:
	_buissons.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.15), s)), Vector3(p.x, _sol_bas(p, 0.3 * s) - 0.05, p.y)))
	_occupe.append([p, 0.35 * s])

func _touffe(p: Vector2, s: float) -> void:
	_touffes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s) * 0.62), Vector3(p.x, _sol_bas(p, 0.25 * s) - 0.04, p.y)))

func _libre(p: Vector2, marge: float) -> bool:
	for o in _occupe:
		if p.distance_to(o[0]) < float(o[1]) + marge:
			return false
	return true

## Touffes, buissons et cailloux semés le long des bords du sentier.
func _semer_bords(u0: float, u1: float) -> void:
	for i in 70:
		var u := rng.randf_range(u0, u1)
		var v := rng.randf_range(1.55, 4.8) * (1.0 if rng.randf() < 0.5 else -1.0)
		var p := _p(u, v)
		var s := rng.randf_range(0.7, 1.2)
		if _libre(p, 0.15):
			_touffe(p, s)
	for i in 14:
		var u := rng.randf_range(u0 + 6.0, u1)
		var v := rng.randf_range(2.3, 5.5) * (1.0 if rng.randf() < 0.5 else -1.0)
		var p := _p(u, v)
		var s := rng.randf_range(0.7, 1.1)
		if _libre(p, 0.4):
			_buisson(p, s)
	for i in 90:
		var u := rng.randf_range(-1.0, u1)
		var v := rng.randf_range(1.3, 2.6) * (1.0 if rng.randf() < 0.5 else -1.0)
		var p := _p(u, v)
		if _libre(p, 0.05):
			_cailloux.append(p)

# --- finalisation -------------------------------------------------------------------------------------------------

func _mesh(m: BatiGeo.Maillage, mat: Material, ombre: bool, nom: String) -> MeshInstance3D:
	if m.v.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = m.mesh()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombre else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = PORTEE
	add_child(mi)
	return mi

func _finaliser() -> void:
	_mesh(_dalles, TexturesBati.m_pierre_brute_e(Color(0.9, 0.9, 0.95)), false, "Dalles")
	_mesh(_pierre, TexturesPetites.m_roche_e(Color(0.95, 0.95, 1.0)), true, "PierreNeige")
	var mr := TexturesBati.m_rondins_e(Color(0.95, 0.88, 0.8))
	_mesh(_bois, mr, true, "Bois")
	_mesh(_bouts, TexturesBati.m_bout_rondin(), true, "Bouts")
	_mesh(_fer, TexturesBati.m_fer_e(Color(0.7, 0.7, 0.75)), true, "Fer")
	var mv := TexturesBati.m_fenetre()
	mv.set_shader_parameter("emission", Color(VITRE_LANTERNE.r * 1.6, VITRE_LANTERNE.g * 1.6, VITRE_LANTERNE.b * 1.6))
	_mesh(_verre, mv, false, "Verre")
	_mesh(_gravure, materiau_gravure(), false, "Gravure")
	var mb := SousBois.materiau_herbe(texture_buisson(rng.randi() % 10000), Color(1.05, 1.0, 1.0))
	if not _buissons.is_empty():
		for mmi in Instanciation.repartir(monde, mesh_buisson(mb), _buissons, {"portee": 50.0, "ombre": false}):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.set_meta("abords", "buisson")
	var mt := SousBois.materiau_herbe(texture_touffe_givree(rng.randi() % 10000), Color(0.92, 0.86, 0.82))
	if not _touffes.is_empty():
		for mmi in Instanciation.repartir(monde, SousBois.mesh_touffe(mt), _touffes, {"portee": 35.0, "ombre": false}):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.set_meta("abords", "touffe")
	DetailsSol.semer(monde, monde, _cailloux, rng.randi())
	print("Abords du village : %d triangles de dalles, %d triangles de pierre/neige, %d sapins, %d buissons, %d touffes, %d cailloux, %d lumières" % [
		_dalles.v.size() / 3, _pierre.v.size() / 3, _nb_sapins, _buissons.size(), _touffes.size(), _cailloux.size(), _lumieres.size()])

func _process(dt: float) -> void:
	if _lumieres.is_empty():
		return
	_t += dt
	var cyc = monde.get("cycle") if monde != null else null
	var nuit := 1.0 - (float(cyc.clarte()) if cyc != null else 0.0)
	var f := lerpf(0.35, 1.0, nuit)
	for l in _lumieres:
		var k: float = l[2]
		(l[0] as OmniLight3D).light_energy = float(l[1]) * f * (1.0 + sin(_t * 2.1 + k) * 0.04 + sin(_t * 5.3 + k * 2.0) * 0.02)

# --- matières et maillages du kit ---------------------------------------------------------------------------------

## Buisson : 4 quads croisés en éventail, texture découpée par l'alpha.
static func mesh_buisson(mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pied := Color(0.55, 0.55, 0.55)
	var tete := Color.WHITE
	for k in 4:
		var a := PI * k / 4.0 + 0.2
		var d := Vector3(cos(a), 0, sin(a))
		var b0 := d * -0.5 + Vector3(0, -0.02, 0)
		var b1 := d * 0.5 + Vector3(0, -0.02, 0)
		var h0 := d * -0.55 + Vector3(0, 0.78, 0)
		var h1 := d * 0.55 + Vector3(0, 0.78, 0)
		Arbres._tri(st, b0, b1, h1, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), pied, pied, tete)
		Arbres._tri(st, b0, h1, h0, Vector2(0, 1), Vector2(1, 0), Vector2(0, 0), pied, tete, tete)
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, mat)
	return mesh

## Texture de buisson brun-rouge : rameaux ramifiés, feuilles mortes, pointes givrées (48 × 40 px, alpha 0/1).
static func texture_buisson(graine: int) -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var W := 48
	var H := 40
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# palette « Végétation sèche » (DIRECTION_ARTISTIQUE §2)
	var bois := [Color("#351520"), Color("#4a1a24"), Color("#5c1f2b")]
	var feuilles := [Color("#5c1f2b"), Color("#7a3a2a"), Color("#8a5a2a"), Color("#a06a32"), Color("#6a2a26")]
	var givre := [Color("#98a1be"), Color("#cdd7ec")]
	var bouts: Array[Vector2] = []
	var pile: Array = []
	for i in 9:
		pile.append([Vector2(W * 0.5 + r.randf_range(-7, 7), H - 1), -PI * 0.5 + r.randf_range(-1.0, 1.0), r.randf_range(14, 26), 0])
	while not pile.is_empty():
		var b: Array = pile.pop_back()
		var p: Vector2 = b[0]
		var a: float = b[1]
		var l: float = b[2]
		var gen: int = b[3]
		var n := int(l)
		for k in n:
			p += Vector2(cos(a), sin(a))
			a += r.randf_range(-0.12, 0.12)
			var x := int(p.x)
			var y := int(p.y)
			if x < 0 or x >= W or y < 0 or y >= H:
				break
			img.set_pixel(x, y, bois[clampi(gen + (1 if k > n / 2 else 0), 0, 2)])
			if gen < 2 and k > 3 and r.randf() < 0.12:
				pile.append([p, a + r.randf_range(0.4, 0.9) * (1.0 if r.randf() < 0.5 else -1.0), l * r.randf_range(0.4, 0.65), gen + 1])
		bouts.append(p)
	# feuilles mortes en grappes autour des rameaux (plus denses en haut)
	for i in 260:
		var c: Vector2 = bouts[r.randi() % bouts.size()] + Vector2(r.randf_range(-6, 6), r.randf_range(-5, 7))
		var x := int(c.x)
		var y := int(c.y)
		if x < 0 or x >= W - 1 or y < 2 or y >= H:
			continue
		var t: Color = feuilles[r.randi() % feuilles.size()]
		img.set_pixel(x, y, t)
		if r.randf() < 0.6:
			img.set_pixel(x + 1, y, t.darkened(0.15))
	# givre : sur le dessus des feuilles et des rameaux
	for y in range(1, H):
		for x in W:
			if img.get_pixel(x, y).a > 0.5 and img.get_pixel(x, y - 1).a < 0.5 and r.randf() < (0.4 if y < H * 0.5 else 0.15):
				img.set_pixel(x, y - 1, givre[r.randi() % 2])
	return ImageTexture.create_from_image(img)

## Touffe d'herbe sèche givrée : la touffe du sous-bois, pointes des brins blanchies.
static func texture_touffe_givree(graine: int) -> ImageTexture:
	var img := SousBois.texture_touffe(graine).get_image()
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var gv := [Color("#98a1be"), Color("#cdd7ec"), Color("#8089a6")]
	for y in range(1, img.get_height()):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5 and img.get_pixel(x, y - 1).a < 0.5:
				if r.randf() < 0.75:
					img.set_pixel(x, y, gv[r.randi() % 3])
				if y + 1 < img.get_height() and r.randf() < 0.35:
					img.set_pixel(x, y + 1, gv[2])
	return ImageTexture.create_from_image(img)

## Gravure d'entrelacs en losange (texture 32 × 90 px : creux sombres, arêtes claires, transparent ailleurs).
static func texture_gravure() -> ImageTexture:
	var W := 32
	var H := 90
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var creux := Color(0.16, 0.15, 0.17)
	var arete := Color(0.62, 0.62, 0.66)
	var cx := (W - 1) * 0.5
	# bordure en torsade sur les deux bords
	for y in H:
		for x in [1, W - 2]:
			if (y / 2) % 2 == 0:
				img.set_pixel(x, y, creux)
			elif (y % 4) == 1:
				img.set_pixel(x, y, arete)
	# losanges entrelacés : chaîne de losanges + losanges intérieurs, brins qui passent dessus/dessous
	var hl := 22.0   # hauteur d'un losange
	var n := int((H - 4) / hl)
	var y0 := (H - n * hl) * 0.5
	for i in n:
		var cy := y0 + hl * (i + 0.5)
		for y in H:
			for x in W:
				var dx := absf(x - cx)
				var dy := absf(y - cy)
				var e1 := dx / 12.5 + dy / (hl * 0.62)       # grand losange (déborde sur les voisins : entrelacs)
				var e2 := dx / 6.0 + dy / (hl * 0.3)         # losange intérieur
				var sur1 := absf(e1 - 1.0) < 0.075
				var sur2 := absf(e2 - 1.0) < 0.13
				var croise := (int(y) + i) % 6 < 3 and absf(dx - 6.0) < 1.5
				if sur1 and not (croise and dy > hl * 0.35):
					img.set_pixel(x, y, creux)
					if y + 1 < H and img.get_pixel(x, y + 1).a < 0.5:
						img.set_pixel(x, y + 1, arete)
				elif sur2:
					img.set_pixel(x, y, creux)
		# point central
		img.set_pixel(int(cx), int(cy), creux)
		img.set_pixel(int(cx) + 1, int(cy), creux)
	return ImageTexture.create_from_image(img)

static func materiau_gravure() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture_gravure()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	return m
