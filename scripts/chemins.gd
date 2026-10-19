class_name Chemins
extends RefCounted
## Sentiers de la zone témoin (feu → cercle → tumulus). API figée : `distance`, `profil`, `points`, `dans_cone_vue`.
## Deux polylignes (Catmull-Rom, 1 point/m, décalage latéral bruité), RNG propre `ZoneBiome.graine("chemin")`.
## `_pres_du_chemin` de monde.gd (feu → village) reste à part.

const PAS := 1.0               # espacement des points de l'axe (m)
const DECALAGE := 1.2          # décalage latéral bruité maximal (m)
const SEAU := 8.0              # côté des seaux de recherche (m)
const LISSAGE := 4             # demi-fenêtre de la moyenne glissante du profil (4 → 9 m)
const PENTE_MAX_DEG := 12.0    # pente maximale du profil de l'axe
const LARGEUR_PROFIL := Vector2(4.0, 1.2)  # le sol rejoint le profil entre 4 m (0) et 1,2 m (1) de l'axe
const ORNIERE := 0.10          # creux au centre (m)
const BORD_NIVEAU := 11.0      # rayon (depuis le centre d'un plateau) jusqu'où l'intérieur ne bouge pas
const BORD_AMPLITUDE := 3.5    # amplitude du bruit des bords de plateau (m)
const BORD_FREQ := 0.08
const CONE_ORIGINE := Vector2(-18.5, -16.5)
const CONE_CIBLE := Vector2(-38.0, -34.0)   # stèle du cercle
const CONE_ANGLE_DEG := 7.0
const CONE_DIST := Vector2(4.0, 24.0)
const CONE_COULOIR := 1.5

## Points de contrôle (x, z) des deux sentiers.
const LIGNE_CERCLE := [Vector2(-6, -6.5), Vector2(-10.5, -9), Vector2(-13.5, -13), Vector2(-18.5, -16.5), Vector2(-22, -21.5), Vector2(-26.5, -23), Vector2(-29.5, -26), Vector2(-33.2, -29.4)]
const LIGNE_TUMULUS := [Vector2(-34.8, -39.8), Vector2(-35.8, -43), Vector2(-38, -45.2)]

var points := PackedVector2Array()  # axe des chemins (polylignes aplaties)
var debuts := PackedInt32Array()    # indices de `points` où commence chaque polyligne
var monde: Node
var temps_ms := 0                   # durée de l'initialisation (mesure)

var _profil_axe := PackedFloat64Array()  # hauteur lissée de l'axe, un échantillon par point
var _seaux := {}                    # Vector2i → PackedInt32Array (indices de segments)
var _bruit_lat := FastNoiseLite.new()
var _bruit_bord := FastNoiseLite.new()
var _cx := INF
var _cz := INF
var _d := INF
var _h := 0.0

func _init(monde_: Node = null) -> void:
	monde = monde_
	if monde == null or not ZoneBiome.actif:
		return
	var t0 := Time.get_ticks_msec()
	var g := ZoneBiome.graine("chemin")
	_bruit_lat.seed = g
	_bruit_lat.frequency = 1.0
	_bruit_bord.seed = g + 1
	_bruit_bord.frequency = 1.0
	monde.set("chemins", self)
	for ligne in [LIGNE_CERCLE, LIGNE_TUMULUS]:
		debuts.append(points.size())
		points.append_array(_polyligne(ligne))
	_indexer()
	_profiler()
	temps_ms = Time.get_ticks_msec() - t0

# --- construction -----------------------------------------------------------

static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

## Catmull-Rom → rééchantillonnage à 1 m → décalage latéral bruité (nul aux deux bouts).
func _polyligne(ctrl: Array) -> PackedVector2Array:
	var dense := PackedVector2Array()
	for i in ctrl.size() - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, ctrl.size() - 1)]
		for k in 24:
			dense.append(_catmull(p0, p1, p2, p3, k / 24.0))
	dense.append(ctrl[ctrl.size() - 1])
	# rééchantillonnage à pas constant
	var axe := PackedVector2Array()
	axe.append(dense[0])
	var reste := PAS
	for i in range(1, dense.size()):
		var a := dense[i - 1]
		var b := dense[i]
		var l := a.distance_to(b)
		var pos := reste
		while pos <= l:
			axe.append(a.lerp(b, pos / l))
			pos += PAS
		reste = pos - l
	if axe[axe.size() - 1].distance_to(dense[dense.size() - 1]) > 0.3:
		axe.append(dense[dense.size() - 1])
	# décalage latéral
	var sortie := PackedVector2Array()
	var n := axe.size()
	for i in n:
		var tang := axe[mini(i + 1, n - 1)] - axe[maxi(i - 1, 0)]
		var nor := Vector2(-tang.y, tang.x).normalized()
		var bout := minf(float(mini(i, n - 1 - i)) / 3.0, 1.0)
		var dec := clampf(_bruit_lat.get_noise_1d(float(i) * PAS * 0.09), -1.0, 1.0) * DECALAGE * smoothstep(0.0, 1.0, bout)
		sortie.append(axe[i] + nor * dec)
	return sortie

func _segment_valide(i: int) -> bool:
	return i >= 0 and i + 1 < points.size() and not debuts.has(i + 1)

func _indexer() -> void:
	for i in points.size() - 1:
		if not _segment_valide(i):
			continue
		var milieu := (points[i] + points[i + 1]) * 0.5
		var cle := Vector2i(floori(milieu.x / SEAU), floori(milieu.y / SEAU))
		var l: PackedInt32Array = _seaux.get(cle, PackedInt32Array())
		l.append(i)
		_seaux[cle] = l  # tableau packé = copie : on le réécrit

## Profil de l'axe : hauteur « sans chemin » à chaque point, moyenne glissante, pente plafonnée.
func _profiler() -> void:
	var brut := PackedFloat64Array()
	for p in points:
		brut.append(monde.hauteur_sans_chemin(p.x, p.y))
	_profil_axe.resize(points.size())
	var pente := tan(deg_to_rad(PENTE_MAX_DEG))
	for d in debuts.size():
		var a := debuts[d]
		var b := (debuts[d + 1] if d + 1 < debuts.size() else points.size()) - 1
		var lisse := PackedFloat64Array()
		for i in range(a, b + 1):
			var s := 0.0
			var c := 0
			for j in range(maxi(i - LISSAGE, a), mini(i + LISSAGE, b) + 1):
				s += brut[j]
				c += 1
			lisse.append(s / c)
		# plafonnement de la pente, aller puis retour
		for i in range(1, lisse.size()):
			var dm := points[a + i].distance_to(points[a + i - 1]) * pente
			lisse[i] = clampf(lisse[i], lisse[i - 1] - dm, lisse[i - 1] + dm)
		for i in range(lisse.size() - 2, -1, -1):
			var dm := points[a + i].distance_to(points[a + i + 1]) * pente
			lisse[i] = clampf(lisse[i], lisse[i + 1] - dm, lisse[i + 1] + dm)
		for i in lisse.size():
			_profil_axe[a + i] = lisse[i]

# --- requêtes ----------------------------------------------------------------

## Cherche le segment le plus proche dans les 9 seaux voisins ; pose _d (distance) et _h (hauteur du profil).
func _chercher(x: float, z: float) -> void:
	if x == _cx and z == _cz:
		return
	_cx = x
	_cz = z
	_d = INF
	_h = 0.0
	if _seaux.is_empty():
		return
	var p := Vector2(x, z)
	var bx := floori(x / SEAU)
	var bz := floori(z / SEAU)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var l = _seaux.get(Vector2i(bx + dx, bz + dz))
			if l == null:
				continue
			for i: int in l:
				var a := points[i]
				var ab := points[i + 1] - a
				var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
				var d := p.distance_to(a + ab * t)
				if d < _d:
					_d = d
					_h = lerpf(_profil_axe[i], _profil_axe[i + 1], t)

## Distance de (x, z) à l'axe du chemin le plus proche (m) ; INF au-delà de ~7 m (seaux de 8 m, O(1)).
func distance(x: float, z: float) -> float:
	_chercher(x, z)
	return _d

## Poids du chemin en (x, z) : 0 loin (> 4 m), 1 sur l'axe (< 1,2 m). Sert au sol (lot D).
func profil(x: float, z: float) -> float:
	_chercher(x, z)
	if _d == INF:
		return 0.0
	return smoothstep(LARGEUR_PROFIL.x, LARGEUR_PROFIL.y, _d)

## Hauteur lissée de l'axe au point le plus proche (valable si distance() < INF).
func hauteur_axe(x: float, z: float) -> float:
	_chercher(x, z)
	return _h

## Vrai si (x, z) est dans le cône de vue dégagé vers le cercle (7° autour de l'axe origine → stèle,
## à 4-24 m de l'origine du cône) ou à moins de 1,5 m de cet axe.
func dans_cone_vue(x: float, z: float) -> bool:
	var axe := CONE_CIBLE - CONE_ORIGINE
	var v := Vector2(x, z) - CONE_ORIGINE
	var l := v.length()
	if l > 0.001 and l >= CONE_DIST.x and l <= CONE_DIST.y:
		if absf(v.angle_to(axe)) < deg_to_rad(CONE_ANGLE_DEG):
			return true
	var t := clampf(v.dot(axe) / axe.length_squared(), 0.0, 1.0)
	return v.distance_to(axe * t) < CONE_COULOIR

## Perturbation des bords de plateau : distance au centre modifiée seulement au-delà de BORD_NIVEAU.
func distance_bruitee(x: float, z: float, d: float, masque: float) -> float:
	return d + BORD_AMPLITUDE * _bruit_bord.get_noise_2d(x * BORD_FREQ, z * BORD_FREQ) * smoothstep(BORD_NIVEAU, BORD_NIVEAU + 4.0, d) * masque
