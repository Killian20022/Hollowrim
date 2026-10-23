class_name PosesDecor
## Passe D : règles de pose communes du petit décor SANS collision (touffes, cailloux, souches, branches, semis, buissons).
## Appliquées APRÈS les tirages (les flux de RNG ne changent pas) par chaque semeur, juste avant Instanciation.repartir.
## Interdit : dans le tertre (dôme, perron, allée de dalles), dans les pavés du village (place, rues, paliers, escalier),
## sur l'axe des chemins pour ce qui dépasse (souche, branche, semis, buisson), dans le lac et le lit de la rivière.
## Contrôle : outils/audit_interpenetrations.gd (--lieu=village|exterieur).

const DOME_DECALAGE := Vector3(0, 0, -15.0)   # centre de la butte du tertre (tertre.gd : butte.position)
const DOME_RAYON := 7.6                       # sphère r 7,5 (échelle y 0,6) coupée par le sol
## Rayon d'encombrement par sorte (m) ; 0 = n'empiète pas (touffe et caillou peuvent border un chemin).
const RAYONS := {"touffe": 0.0, "caillou": 0.0, "touffe_haute": 0.4, "semis": 0.45, "souche": 0.4, "branche": 0.6, "buisson": 0.45}

static func interdit(monde: Node, x: float, z: float, sorte: String) -> bool:
	var r: float = RAYONS.get(sorte, 0.3)
	var p := Vector2(x, z)
	# tertre : dôme (le pied serait enfoui sous la butte) et perron + allée de dalles (cailloux dans les marches)
	var t: Vector3 = monde.TUMULUS
	if p.distance_to(Vector2(t.x + DOME_DECALAGE.x, t.z + DOME_DECALAGE.z)) < DOME_RAYON + r:
		return true
	if absf(x - t.x) < 2.6 + r and z - t.z > -1.2 - r and z - t.z < 7.5 + r:
		return true
	# pavés du village
	if Geometry2D.is_point_in_polygon(p, PackedVector2Array(RuesVillage.PLACE)) or RuesVillage._d_polygone(p, RuesVillage.PLACE) < 0.3:
		return true
	for rue: Array in RuesVillage.RUES:
		if RuesVillage._d_polyligne(p, rue[0]) < float(rue[1]) * 0.5 + 0.2:
			return true
	for pr: Rect2 in RuesVillage.PALIERS:
		if pr.grow(0.2).has_point(p):
			return true
	if RuesVillage.COULOIR.grow(0.3).has_point(p):
		return true
	# chemins : ce qui dépasse reste hors de la bande roulée
	if r > 0.0:
		if monde.chemins != null and monde.chemins.distance(x, z) < 1.2 + r:
			return true
		if monde._pres_du_chemin(x, z, 1.3 + r):
			return true
		for c: Array in RuesVillage.CHEMINS_TERRE:
			if RuesVillage._d_polyligne(p, c[0]) < float(c[1]) * 0.5 + r:
				return true
	# eau : lac (et sa rive immédiate) et lit de la rivière
	if EauVillage.sous_le_lac(x, z, monde.hauteur(x, z) + 0.1):
		return true
	var rv := ReliefVillage.riviere(x, z)
	if not rv.is_empty() and float(rv["distance"]) < float(rv["demi_largeur"]) + 0.2:
		return true
	return false

## Copie filtrée d'une liste de Transform3D (ordre conservé).
static func filtrer(monde: Node, xfs: Array, sorte: String) -> Array:
	var res: Array = []
	for t: Transform3D in xfs:
		if not interdit(monde, t.origin.x, t.origin.z, sorte):
			res.append(t)
	return res

## Copie filtrée d'une liste de points (x, z).
static func filtrer_points(monde: Node, points: Array, sorte: String) -> Array:
	var res: Array = []
	for q: Vector2 in points:
		if not interdit(monde, q.x, q.y, sorte):
			res.append(q)
	return res
