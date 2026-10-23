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
## Coût : tout est fusionné par matériau (dalles, pierre+neige, stèle, rondins, bouts, fer, verre, flaques de lumière) + MultiMesh pour
## buissons/touffes/cailloux ; ~10 appels de dessin. Lumières : 2 OmniLight sans ombre, portée 6 m, distance_fade
## (au plus une visible avec les 2 torches de la porte) ; les autres lanternes sont émissives seulement.
## Collisions : poteaux, pierre levée et gros rochers seulement (formes simples, hors de la piste).
## `--sans-abords` : désactive tout (A/B).

const PORTEE := 80.0                 # ≤ FIN_MAX + 5 (brouillard)
const DEMI_LARGEUR := 1.3            # demi-largeur du dallage (m)
const VILLAGE_RAYON := 22.0          # palissade (village.gd RAYON)
## Palettes communes (DIRECTION_ARTISTIQUE §2) : dalles gris-brun (pierre froide réchauffée), granit « Pierre froide ».
const PALETTE_DALLE := ["#3e3a3b", "#4d4747", "#5c5653", "#6c6560", "#7d766f", "#8e877f", "#a39b91"]
const PALETTE_GRANIT := ["#1c1c1f", "#303035", "#3d434f", "#4c5566", "#5e6880", "#737e98", "#8a94ad"]
## Passe 4 : roche des abords brun-gris (granit mouchetée de brun, fissures), la teinte froide du sommet la refroidit à l'écran.
const PALETTE_ROCHE := ["#1f1c1b", "#322e2c", "#443f3c", "#58524d", "#6d655f", "#847b73", "#9c928a"]
const FLAQUE := Color(1.0, 0.52, 0.22)   # flaque de lumière des lanternes (additive)
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
var _stele := BatiGeo.Maillage.new()
var _flaques := BatiGeo.Maillage.new()
var _mat_flaque: StandardMaterial3D
var _buissons: Array = []
var _touffes: Array = []
var _cailloux: Array = []
var _occupe: Array = []                 # [Vector2, rayon] : pas de buisson ni de touffe dedans
var _corps: StaticBody3D
var _lumieres: Array = []               # [OmniLight3D, énergie, phase]
var _t := 0.0
var _nb_sapins := 0
## C1b : maille des pavés (m, le long / en travers du sentier) ; 0,7 × 0,74 avant (grandes dalles plates)
var dalle_su := 0.5
var dalle_sv := 0.5

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
	var avec_sapins := not OS.get_cmdline_user_args().has("--sans-sapins-abords")   # A/B de coût
	# grands sapins du tout premier plan, à gauche et à droite : ils coupent le bord de l'image (pose commune)
	if avec_sapins: _sapins([[4.6, -5.6, 1.45, true], [5.6, 5.1, 1.5, true]], 0, 0.0, 0.0, false)   # sans ombre (coût : ils couvrent l'écran)
	if avec_sapins: _sapins([[7.6, -6.6, 1.2], [3.0, -6.6, 1.0], [10.6, -5.6, 1.1], [14.0, -7.6, 1.3], [18.2, -5.4, 1.0], [22.0, -6.8, 1.2], [26.0, -5.6, 1.0], [30.0, -7.2, 1.1],
			[6.4, 6.9, 1.15], [2.4, 7.4, 1.0], [11.2, 7.2, 1.2], [16.6, 6.3, 1.0], [21.0, 7.6, 1.3], [25.2, 5.8, 1.0], [29.2, 6.8, 1.2], [33.0, 5.8, 1.0]], 6, 2.0, longueur + 4.0)
	_semer_bords(0.5, longueur - 1.5)
	_semer_premier_plan()

## Sapins qui encadrent le sentier : les épicéas validés du lot 2 (API `Arbres`, mêmes graines et mêmes réglages de portée,
## d'ombre et de silhouette lointaine que la forêt), une liste de cadrage [u, v, échelle] puis un remplissage au hasard.
## Hors de la palissade, hors du dallage (|v| ≥ 3,6 m), loin des autres objets. Collision : le tronc (comme la forêt).
## Ils ne sont pas ajoutés à `monde.arbres` (carte de sol et brume locale inchangées).
func _sapins(liste: Array, nb_remplir: int, u0: float, u1: float, ombre := true) -> void:
	var centre_village := Vector2(monde.VILLAGE.x, monde.VILLAGE.z)
	var r_min: float = VILLAGE_RAYON + 2.2
	var pris: Array[Vector2] = []
	var lots: Array = [[], [], []]
	var essais: Array = []
	for t in liste:
		essais.append([_j(t[0], 0.2), _j(t[1], 0.2), float(t[2]), t.size() > 3])
	for i in nb_remplir * 4:
		essais.append([rng.randf_range(u0, u1), rng.randf_range(5.0, 13.0) * (1.0 if rng.randf() < 0.5 else -1.0), rng.randf_range(0.85, 1.3), false])
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
		var force: bool = e[3]   # premier plan : posé tel quel (coupe le bord de l'image), seulement hors piste
		if absf(e[1]) < 3.6 or p.distance_to(centre_village) < r_min or (not force and not _libre(p, 1.0)):
			continue
		var serre := false
		for q in pris:
			if q.distance_to(p) < 2.6 and not force:
				serre = true
				break
		for t: Transform3D in monde.arbres:   # passe D : pas dans le tronc d'un arbre de la forêt (deux troncs imbriqués)
			if Vector2(t.origin.x - p.x, t.origin.z - p.y).length() < 1.3:
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
		var reg := {"portee": pp, "marge": 4.0, "ombre_proche": pp, "lod_mesh": Arbres.epicea_lointain(f, 11 + f, mats),
			"ombre_mesh": Arbres.epicea_ombre(f, 11 + f, mats[0]), "lod_debut": pp - 4.0, "lod_portee": Vegetation.PORTEE_LOD}
		if not ombre:
			reg = {"portee": pp, "marge": 4.0, "ombre": false}
		Instanciation.repartir(monde, Arbres.epicea(f, 11 + f, mats), lots[f], reg)
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
	var su := dalle_su
	var sv := dalle_sv
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
			joints.append(rng.randf_range(0.03, 0.055))
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
	# C1b (référence exterieurs_v2 vue 1) : pavé gris-bleu (parfois gris-brun), bombé (anneau intérieur + sommet : facettes
	# éclairées / à l'ombre), bord plus sombre, liseré de neige ; ~15 % à moitié enfouis (un bord passe sous la neige du sol)
	var kt := rng.randf_range(0.82, 1.1)
	var chaud := rng.randf() < 0.25
	var tc := Vector3(1.07, 1.0, 0.9) if chaud else Vector3(0.93, 0.97, 1.05)
	var col_sommet := Color(kt * 1.12 * tc.x, kt * 1.12 * tc.y, kt * 1.12 * tc.z, 1.0)
	var col_haut := Color(kt * tc.x, kt * tc.y, kt * tc.z, 1.0)
	var col_bord := Color(kt * 0.74 * tc.x, kt * 0.74 * tc.y, kt * 0.76 * tc.z, 1.0)
	var col_flanc := Color(kt * 0.5, kt * 0.5, kt * 0.54, 1.0)
	var col_pied := Color(0.88, 0.88, 0.93, 0.0)
	var enfouie := rng.randf() < 0.15
	var p_neige := 0.22 + 0.45 * smoothstep(0.3, 1.25, absf(c2.y - centre_v))
	var pente := 0.07 if enfouie else 0.025
	var bascule := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * rng.randf_range(0.3, 1.0) * pente
	var epais := rng.randf_range(-0.01, 0.01) if enfouie else rng.randf_range(0.02, 0.035)
	var rayon := 0.0
	for q in poly:
		rayon = maxf(rayon, q.distance_to(c2))
	var bombe := clampf(rayon * rng.randf_range(0.07, 0.12), 0.012, 0.04)
	var haut: Array[Vector3] = []
	var mil: Array[Vector3] = []
	var bas: Array[Vector3] = []
	var cols: Array[Color] = []
	var y_moy := 0.0
	for q in poly:
		var w := _p(q.x, q.y)
		var y := _sol(w) + epais + (q - c2).dot(bascule) * 2.0
		y_moy += y
		haut.append(_l(w, y))
		var qm := c2.lerp(q, 0.6)
		var wm := _p(qm.x, qm.y)
		mil.append(_l(wm, _sol(wm) + epais + (qm - c2).dot(bascule) * 2.0 + bombe))
		var d := (q - c2).normalized() * 0.035
		var wb := _p(q.x + d.x, q.y + d.y)
		bas.append(_l(wb, _sol(wb) - 0.03))
		var t := rng.randf()
		# liseré de neige sur le bord : alpha 0,3 (la neige mord ~30 % vers le centre), parfois plus
		cols.append(Color(col_bord.r, col_bord.g, col_bord.b, 0.0 if t < p_neige * 0.25 else (0.3 if t < p_neige else 1.0)))
	y_moy /= poly.size()
	var cw := _p(c2.x, c2.y)
	var ctr := _l(cw, y_moy + bombe * 1.35)
	var dessous := ctr - Vector3(0, 1.0, 0)
	var n := poly.size()
	for i in n:
		var i2 := (i + 1) % n
		var ch := col_haut if cols[i].a > 0.5 else Color(col_haut.r, col_haut.g, col_haut.b, 0.6)
		var ch2 := col_haut if cols[i2].a > 0.5 else Color(col_haut.r, col_haut.g, col_haut.b, 0.6)
		_dalles.quad(haut[i], haut[i2], mil[i2], mil[i], cols[i], cols[i2], ch2, ch, dessous)
		_dalles.tri(mil[i], mil[i2], ctr, col_haut, col_haut, col_sommet, dessous)
		_dalles.quad(bas[i], bas[i2], haut[i2], haut[i], col_pied, col_pied, col_flanc, col_flanc, ctr - Vector3(0, 0.03, 0))

## Rocher arrondi et bosselé (16 × 9 sommets, deux octaves de bruit) en granit gris-bleu, coiffé d'une calotte de neige
## épaisse à bord irrégulier qui coule sur les flancs ; posé sur la pente ; congère du côté opposé à la piste.
func _rocher(u: float, v: float, s: float) -> void:
	var p := _p(u, v)
	var y0 := _sol_bas(p, s * 0.35)
	var n := FastNoiseLite.new()
	n.seed = rng.randi()
	n.frequency = 1.0
	var sx := s * 0.5 * rng.randf_range(0.85, 1.15)
	var sz := s * 0.5 * rng.randf_range(0.7, 0.95)
	var sy := s * 0.42 * rng.randf_range(0.8, 1.15)
	var base := Basis(Vector3.UP, rng.randf() * TAU)
	# passe 4 : bloc de granit à FACETTES (intersection de demi-espaces à arêtes adoucies) au lieu d'une boule bosselée ;
	# plans tirés par un générateur privé (la graine du bruit) : le `rng` partagé n'est pas touché.
	var S := 20
	var R := 11
	var pr := RandomNumberGenerator.new()
	pr.seed = int(n.seed) * 7 + 13
	var plans: Array[Vector4] = []   # (nx, ny, nz, distance)
	for i in 11:
		var ang := pr.randf() * TAU
		var ny := pr.randf_range(-0.2, 0.95) if i < 6 else pr.randf_range(-0.35, 0.35)
		var nr := sqrt(maxf(0.0, 1.0 - ny * ny))
		plans.append(Vector4(cos(ang) * nr, ny, sin(ang) * nr, pr.randf_range(0.92, 1.12)))
	var anneaux: Array = []
	var cols: Array = []
	for r in R + 1:
		var ring := PackedVector3Array()
		var cl := PackedColorArray()
		var phi := lerpf(-0.3 * PI, 0.5 * PI, float(r) / R)
		for k in S:
			var a := TAU * k / S
			var d := Vector3(cos(phi) * cos(a), sin(phi), cos(phi) * sin(a))
			if r == R:
				d = Vector3(0.02 * cos(a), 1.0, 0.02 * sin(a)).normalized()
			# rayon du polyèdre : norme -k douce des distances aux plans (arêtes vives mais non tranchantes)
			var somme := 0.0
			var domin := 0
			var meilleur := 99.0
			for pi in plans.size():
				var pl := plans[pi]
				var dn := d.x * pl.x + d.y * pl.y + d.z * pl.z
				var x := pl.w / maxf(dn, 0.05)
				somme += pow(x, -9.0)
				if x < meilleur:
					meilleur = x
					domin = pi
			var rf := pow(somme, -1.0 / 9.0)
			var f := clampf(rf, 0.55, 1.3) * (1.0 + n.get_noise_3dv(d * 4.5 + Vector3(3, 1, 7)) * 0.05) * (1.0 + n.get_noise_3dv(d * 1.2) * 0.1)
			var q := Vector3(d.x * sx, d.y * sy + sy * 0.3, d.z * sz) * f
			if q.y < 0.0:
				q.y *= 0.5
			# masque de neige : le haut, bord irrégulier qui descend en coulures sur les flancs
			var m := d.y + n.get_noise_3dv(d * 2.4 + Vector3(9, 9, 9)) * 0.42 + n.get_noise_3dv(Vector3(cos(a) * 3.0, 0, sin(a) * 3.0)) * 0.18
			var neige := m > 0.56   # passe 4 : calotte plus petite, le granit fissuré se voit (passe 3 : 0,47)  ;  passe 3 : calotte resserrée sur le haut, flancs de granit sombre visibles
			var ao := lerpf(0.55, 1.0, clampf((d.y + 0.6) / 1.4, 0.0, 1.0))
			if neige:
				var ep := smoothstep(0.56, 0.9, m)   # épaisseur : nulle au bord, ~12 % de la taille au sommet
				q += (d * 0.6 + Vector3(0, 0.6, 0)) * ep * 0.145 * s
				var kn := lerpf(0.8, 1.0, clampf(d.y, 0.0, 1.0)) * (0.94 + n.get_noise_3dv(d * 6.0) * 0.08)
				cl.append(Color(kn, kn, kn * 1.02, 0.0))
			else:
				# ton propre à chaque facette (granit non uniforme) + arêtes assombries (fissures de gel)
				var ton := 1.0 + 0.32 * fposmod(sin(float(domin) * 12.9898 + n.seed) * 43758.5, 1.0)
				var kk := ao * ton * (0.95 + n.get_noise_3dv(d * 5.0 + Vector3(1, 2, 3)) * 0.1)
				cl.append(Color(kk, kk, kk * 1.03, 1.0))
			ring.append(q)
		anneaux.append(ring)
		cols.append(cl)
	var centre := Vector3(0, sy * 0.3, 0)
	var xf := Transform3D(base, _l(p, y0 - 0.04 * s))
	for r in R:
		var a: PackedVector3Array = anneaux[r]
		var b: PackedVector3Array = anneaux[r + 1]
		var ca: PackedColorArray = cols[r]
		var cb: PackedColorArray = cols[r + 1]
		for k in S:
			var k2 := (k + 1) % S
			_pierre.tri(xf * a[k], xf * a[k2], xf * b[k2], ca[k], ca[k2], cb[k2], xf * centre)
			_pierre.tri(xf * a[k], xf * b[k2], xf * b[k], ca[k], cb[k2], cb[k], xf * centre)
	var dernier: PackedVector3Array = anneaux[R]
	var sommet := Vector3.ZERO
	for q in dernier:
		sommet += q / S
	sommet.y += 0.01 * s
	var cs: PackedColorArray = cols[R]
	for k in S:
		_pierre.tri(xf * dernier[k], xf * dernier[(k + 1) % S], xf * sommet, cs[k], cs[(k + 1) % S], cs[k], xf * centre)
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
	_flaque(Vector2(lc.x + origine.x, lc.z + origine.y), 2.3 if reelle else 1.7, 0.29 if reelle else 0.22)
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
## Gravure PEINTE dans la texture (brins en relief clairs, creux sombres, arêtes éclairées par le haut) : UV en projection
## plane sur la face (faces ±Z planes, `plat`), matériau ps1_bati en `uv_maillage`. Plus de quad en alpha.
func _pierre_levee(p: Vector2, face: Vector2) -> void:
	var taille := Vector3(0.85, 2.3, 0.42)
	var m := BatiGeo.pierre_levee(taille, 7000 + rng.randi() % 1000, true)
	for i in m.v.size():
		var q := m.v[i]
		m.uv[i] = Vector2(clampf(q.x / taille.x + 0.5, 0.0, 1.0), clampf(0.5 - q.y / taille.y, 0.0, 1.0))
	var y0 := _sol_bas(p, 0.4)
	var b := Basis(Vector3.UP, atan2(face.x, face.y)) * Basis(Vector3.BACK, rng.randf_range(-0.03, 0.03))
	var c := _l(p, y0 + taille.y * 0.5 - 0.22)
	_ajouter(_stele, m, Transform3D(b, c))
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

## Flaque de lumière chaude au sol sous une lanterne : disque collé au relief (au-dessus des dalles), couleur de sommet
## décroissante en paliers doux et bord bruité ; rendu additif, sans éclairage (un seul maillage pour toutes les flaques).
func _flaque(c: Vector2, rayon: float, force: float) -> void:
	var anneaux := 6
	var S := 18
	var prec: Array = []
	var pc: Array = []
	var ph := rng.randf() * TAU
	var centre_bas := _l(c, _sol(c) - 1.0)
	for r in anneaux + 1:
		var t := float(r) / anneaux
		var ring: Array = []
		var cr: Array = []
		for k in S:
			var a := TAU * k / S
			var jr := 1.0 + 0.12 * sin(a * 3.0 + ph) + 0.06 * sin(a * 7.0 + ph * 2.0)
			var w := c + Vector2(cos(a), sin(a)) * rayon * t * jr
			ring.append(_l(w, _sol(w) + 0.075))
			var i := force * pow(1.0 - t, 1.8)
			cr.append(Color(i, i, i, 1.0))
		if r == 0:
			ring = [ring[0]]
			cr = [cr[0]]
		if not prec.is_empty():
			for k in S:
				var k2 := (k + 1) % S
				if prec.size() == 1:
					_flaques.tri(prec[0], ring[k], ring[k2], pc[0], cr[k], cr[k2], centre_bas)
				else:
					_flaques.quad(prec[k], prec[k2], ring[k2], ring[k], pc[k], pc[k2], cr[k2], cr[k], centre_bas)
		prec = ring
		pc = cr

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

## Passe 3 : bouquets d'herbes sèches givrées et buissons brun-rouge au premier plan (bords du dallage, pieds des rochers,
## comme la référence). Générateur à part : aucun tirage de `rng` n'est décalé (dalles, textures et rochers inchangés).
func _semer_premier_plan() -> void:
	var sauve := rng
	rng = RandomNumberGenerator.new()
	rng.seed = sauve.seed ^ 0x5a17
	for g in 16:
		var c := Vector2(rng.randf_range(0.6, 11.0), rng.randf_range(1.6, 4.6) * (1.0 if rng.randf() < 0.5 else -1.0))
		for i in rng.randi_range(3, 6):
			var q := c + Vector2(rng.randf_range(-0.55, 0.55), rng.randf_range(-0.4, 0.4))
			if absf(q.y) < 1.5:
				continue
			var p := _p(q.x, q.y)
			if _libre(p, 0.08):
				_touffe(p, rng.randf_range(0.75, 1.25))
	for i in 10:
		var p := _p(rng.randf_range(1.0, 9.0), rng.randf_range(2.6, 5.2) * (1.0 if rng.randf() < 0.5 else -1.0))
		if _libre(p, 0.2):
			_buisson(p, rng.randf_range(0.6, 1.0))
	rng = sauve

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
	_mesh(_dalles, materiau_dalles(rng), false, "Dalles")
	var tg: Array = texture_pierre(PALETTE_ROCHE, 4300 + rng.randi() % 100, 7, 300, 4)   # passe 4 : brun-gris moucheté, fissures
	# passe 3 : la teinte froide (0,74 ; 0,76 ; 0,82) ne s'applique plus qu'au granit (couleur de sommet) ; la neige
	# (alpha 0) n'est plus grisée par elle : elle rejoint le blanc bleuté du sol au lieu d'un gris terne.
	for i in _pierre.c.size():
		var c: Color = _pierre.c[i]
		if c.a >= 0.5:
			_pierre.c[i] = Color(c.r * 0.74, c.g * 0.76, c.b * 0.82, c.a)
		else:
			_pierre.c[i] = Color(c.r * 0.9, c.g * 0.93, c.b * 0.98, c.a)
	_mesh(_pierre, materiau_kit(tg[0], tg[1], 64.0, Color.WHITE), true, "PierreNeige")
	_mesh(_stele, materiau_kit(texture_stele(4500 + rng.randi() % 100), TexturesBati.relief_neutre(), 64.0, Color(1.05, 1.05, 1.08), true), true, "Stele")
	_mat_flaque = StandardMaterial3D.new()
	_mat_flaque.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_flaque.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_flaque.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_flaque.vertex_color_use_as_albedo = true
	_mat_flaque.albedo_color = FLAQUE
	_mat_flaque.disable_receive_shadows = true
	_mesh(_flaques, _mat_flaque, false, "Flaques")
	var mr := TexturesBati.m_rondins_e(Color(0.95, 0.88, 0.8))
	_mesh(_bois, mr, true, "Bois")
	_mesh(_bouts, TexturesBati.m_bout_rondin(), true, "Bouts")
	_mesh(_fer, TexturesBati.m_fer_e(Color(0.7, 0.7, 0.75)), true, "Fer")
	var mv := TexturesBati.m_fenetre()
	mv.set_shader_parameter("emission", Color(VITRE_LANTERNE.r * 1.6, VITRE_LANTERNE.g * 1.6, VITRE_LANTERNE.b * 1.6))
	_mesh(_verre, mv, false, "Verre")
	var mb := SousBois.materiau_herbe(texture_buisson(rng.randi() % 10000), Color(1.05, 1.0, 1.0))
	_buissons = PosesDecor.filtrer(monde, _buissons, "buisson")   # passe D : règles de pose (après les tirages)
	_touffes = PosesDecor.filtrer(monde, _touffes, "touffe_haute")   # grandes touffes givrées (≈ 1 m) : hors de la bande du sentier
	_cailloux = PosesDecor.filtrer_points(monde, _cailloux, "caillou")
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
	_t += dt
	var cyc = monde.get("cycle") if monde != null else null
	var nuit := 1.0 - (float(cyc.clarte()) if cyc != null else 0.0)
	var f := lerpf(0.35, 1.0, nuit)
	if _mat_flaque != null:
		_mat_flaque.albedo_color = FLAQUE * lerpf(0.12, 1.0, nuit) * (1.0 + sin(_t * 2.1) * 0.03)
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

## Matériau ps1_bati sur une texture du kit (neige `neige_e` des extérieurs, fondu 64 → 32 texels/m entre 4 et 14 m).
## C1b : matériau des pavés (gris-bleu froid à moucheture discrète, référence exterieurs_v2 vue 1) ; la « neige qui tient »
## n'y pose que quelques plaques (le kit dessine déjà le liseré de neige des bords).
const PALETTE_PAVE := ["#30343c", "#3d424b", "#4a5059", "#575d66", "#646a73", "#737982", "#858a92"]
const NEIGE_DALLES := 0.16
static func materiau_dalles(r: RandomNumberGenerator) -> ShaderMaterial:
	var td: Array = texture_pierre(PALETTE_PAVE, 4100 + r.randi() % 100, 4, 50)
	var m := materiau_kit(td[0], td[1], 64.0, Color(1.3, 1.3, 1.3))
	m.set_shader_parameter("neige_tient", NEIGE_DALLES)
	return m

static func materiau_kit(tex: Texture2D, relief: Texture2D, texels: float, teinte := Color.WHITE, uv_maillage := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TexturesBati.SHADER
	m.set_shader_parameter("tex_base", tex)
	m.set_shader_parameter("tex_relief", relief)
	var nn := TexturesBati.charge("neige_e")
	m.set_shader_parameter("tex_neige", nn[0])
	m.set_shader_parameter("tex_neige_relief", nn[1])
	m.set_shader_parameter("neige_propre", true)
	m.set_shader_parameter("teinte", teinte)
	m.set_shader_parameter("texels_par_m", texels)
	m.set_shader_parameter("proche", Vector2(4.0, 14.0))
	m.set_shader_parameter("relief", 0.8)
	m.set_shader_parameter("uv_maillage", uv_maillage)
	Palette._appliquer(m, Palette._ps1_actif)
	Palette.materiaux.append(m)
	return m

## Pierre mouchetée tuilable (64 px) : bruit périodique 3 octaves quantifié dans `palette` (6-7 tons), moucheture en amas de
## 2-3 px (clairs et sombres), arêtes de grain. Renvoie [albédo avec mips « vote de couleur », relief].
static func texture_pierre(palette: Array, graine: int, periode := 6, nb_moucheture := 150, nb_fissures := 0) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var T := 64
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var hs := PackedFloat32Array()
	hs.resize(T * T)
	var cols: Array[Color] = []
	for h in palette:
		cols.append(Color(h))
	for y in T:
		for x in T:
			var v := 0.0
			var amp := 0.5
			var per := periode
			for o in 3:
				v += Palette._valeur_periodique(float(x) / T * per, float(y) / T * per, per, graine * 10 + o) * amp
				amp *= 0.5
				per *= 2
			v = v / 0.875 + (r.randf() - 0.5) * 0.12
			hs[y * T + x] = v
	# moucheture : amas de 2-3 px
	for i in nb_moucheture:
		var x0 := r.randi() % T
		var y0 := r.randi() % T
		var dv := 0.22 if r.randf() < 0.5 else -0.25
		for k in r.randi_range(2, 4):
			var x := (x0 + (k % 2)) % T
			var y := (y0 + (k / 2)) % T
			hs[y * T + x] += dv
	# fissures (passe 4) : marches aléatoires de 20-40 px, creux de 1 px (ton le plus sombre) + lèvre claire d'un côté
	for i in nb_fissures:
		var fx := r.randf() * T
		var fy := r.randf() * T
		var dir := r.randf() * TAU
		for k in r.randi_range(20, 40):
			dir += r.randf_range(-0.55, 0.55)
			fx += cos(dir)
			fy += sin(dir)
			var ix := posmod(int(fx), T)
			var iy := posmod(int(fy), T)
			hs[iy * T + ix] = -0.4
			hs[iy * T + posmod(ix + 1, T)] += 0.18
	for y in T:
		for x in T:
			img.set_pixel(x, y, cols[clampi(int(hs[y * T + x] * cols.size()), 0, cols.size() - 1)])
	return [PeintureBati.avec_mips(img), _relief_de(hs, T, T, 2.5)]

## Relief (gradient de hauteur encodé en rg, 0,5 = plat) d'un champ de hauteurs périodique.
static func _relief_de(hs: PackedFloat32Array, W: int, H: int, k: float) -> ImageTexture:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var gx := hs[y * W + (x + 1) % W] - hs[y * W + (x + W - 1) % W]
			var gy := hs[((y + 1) % H) * W + x] - hs[((y + H - 1) % H) * W + x]
			img.set_pixel(x, y, Color(clampf(0.5 + gx * k * 0.5, 0.0, 1.0), clampf(0.5 + gy * k * 0.5, 0.0, 1.0), 0.5, 1.0))
	return PeintureBati.relief_mips(img)

## Texture de la stèle (56 × 152 px pour 0,85 × 2,3 m) : granit moucheté, cadre gravé, deux brins entrelacés en zigzag qui
## forment une chaîne de losanges (dessus/dessous alternés aux croisements), petits losanges au centre. Relief peint :
## brins clairs à arête haute éclairée, creux quasi noirs, pied de brin plus sombre.
static func texture_stele(graine: int) -> ImageTexture:
	var W := 56
	var H := 152
	var base: Array = texture_pierre(PALETTE_GRANIT, graine)
	var src: Image = (base[0] as ImageTexture).get_image()
	src.clear_mipmaps()
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			img.set_pixel(x, y, src.get_pixel(x % 64, y % 64))
	var creux := Color("#14161a")
	var ombre := Color("#303035")
	var brin := Color("#8a94ad")
	var arete := Color("#a7adbf")
	var brin_bas := Color("#626c86")
	var cx := (W - 1) * 0.5
	var y0 := 22
	var y1 := 128
	var x0 := 9
	var x1 := W - 10
	# cadre : creux de 1 px, arête claire dessous/à droite
	for y in range(y0 - 3, y1 + 4):
		for x in range(x0 - 3, x1 + 4):
			var bord: bool = (x == x0 - 3 or x == x1 + 3 or y == y0 - 3 or y == y1 + 3)
			if bord:
				img.set_pixel(x, y, creux)
				if x + 1 < W and (y == y0 - 3):
					img.set_pixel(x, y + 1, arete)
	var P := 35.0
	# quatre brins : deux grands zigzags (chaîne de losanges) et deux petits décalés d'une demi-période (losanges intérieurs)
	var brins := [[13.0, 0.0], [-13.0, 0.0], [6.0, 0.5], [-6.0, 0.5]]
	for y in range(y0, y1 + 1):
		var croisement := int(floor((y - y0) / (P * 0.5) + 0.5))
		for x in range(x0, x1 + 1):
			var meilleur := -1
			var prio := -1
			var xs := 0.0
			var dmin := 99.0
			var sillon := false
			for bi in brins.size():
				var A: float = brins[bi][0]
				var t := absf(fposmod((y - y0) / P + float(brins[bi][1]), 1.0) - 0.5) * 4.0 - 1.0
				var xb := cx + A * t
				var corr := sqrt(1.0 + pow(4.0 * A / P, 2.0))
				var d := absf(x - xb) / corr
				var lim := 1.5 if absf(A) > 8.0 else 1.1
				if d < lim:
					var pr := (bi + croisement) % brins.size()
					if pr > prio:
						prio = pr
						meilleur = bi
						xs = xb
						dmin = d / lim
				elif d < lim + 1.1:
					sillon = true
			var c: Color
			if meilleur >= 0:
				c = arete if (x < xs and dmin > 0.45) else (brin_bas if (x > xs and dmin > 0.45) else brin)
			elif sillon:
				c = creux
			else:
				c = img.get_pixel(x, y).darkened(0.35)
			img.set_pixel(x, y, c)
	return PeintureBati.avec_mips(img)

