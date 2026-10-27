class_name ProfilsAnimation
## Profils d'animation des armes en vue FPS : gestes d'attaque (préparation → phase active → récupération), poses de garde,
## de sprint. Chaque pose = [position de la poignée, direction de la lame, côté du tranchant] dans le repère caméra
## (+X droite, +Y haut, -Z devant). Un geste actif passe par trois poses (départ armé, milieu bras tendu, fin) :
## la poignée suit une courbe de Bézier qui passe par le milieu, l'orientation un double slerp (de Casteljau).
## Les durées sont en secondes pour une arme de vitesse 1 (DonneesArme.vitesse les divise).
## Les mêmes fonctions servent à l'image affichée ET au tracé de lame : ce que l'on voit est ce qui touche.

## Coups légers enchaînés (combo 1, 2, 3 puis retour au 1) ; le coup lourd a son propre geste.
const PROFILS := {
	"epee_longue": {
		"combo": ["diag_dg", "diag_gd", "horizontale"],
		"lourd": "verticale",
		"gestes": {
			# diagonale droite → gauche : armée au-dessus de l'épaule droite, finit en bas à gauche
			"diag_dg": {
				"armer": [Vector3(0.36, -0.10, -0.50), Vector3(0.45, 0.85, 0.30), Vector3(0.28, 0.0, -0.45)],
				"milieu": [Vector3(0.10, -0.17, -0.68), Vector3(-0.45, 0.25, -0.86), Vector3(-0.8, -0.5, 0.25)],
				"fin": [Vector3(-0.16, -0.32, -0.56), Vector3(-0.85, -0.15, -0.45), Vector3(-0.45, 0.0, 0.85)],
				"preparation": 0.10, "active": 0.17, "recuperation": 0.30, "fenetre": [0.10, 0.92],
			},
			# diagonale gauche → droite : revers, armée au-dessus de l'épaule gauche (miroir du précédent)
			"diag_gd": {"miroir": "diag_dg", "preparation": 0.12, "active": 0.17, "recuperation": 0.30, "fenetre": [0.10, 0.92]},
			# balayage horizontal de droite à gauche à hauteur de poitrine
			"horizontale": {
				"armer": [Vector3(0.40, -0.17, -0.42), Vector3(0.91, 0.12, 0.40), Vector3(0.40, 0.0, -0.9)],
				"milieu": [Vector3(0.06, -0.20, -0.70), Vector3(-0.15, 0.06, -1.0), Vector3(-1.0, 0.0, 0.1)],
				"fin": [Vector3(-0.28, -0.24, -0.50), Vector3(-0.87, 0.02, 0.50), Vector3(0.5, 0.0, 0.87)],
				"preparation": 0.13, "active": 0.19, "recuperation": 0.34, "fenetre": [0.10, 0.92],
			},
			# coup lourd : abattu de haut en bas, légèrement en diagonale (main droite)
			"verticale": {
				"armer": [Vector3(0.30, 0.0, -0.40), Vector3(0.12, 0.80, 0.58), Vector3(0.0, 0.58, -0.80)],
				"milieu": [Vector3(0.10, -0.10, -0.72), Vector3(-0.06, 0.10, -1.0), Vector3(0.0, -1.0, 0.1)],
				"fin": [Vector3(-0.02, -0.42, -0.55), Vector3(-0.18, -0.85, -0.50), Vector3(0.0, -0.5, 0.87)],
				"preparation": 0.16, "active": 0.24, "recuperation": 0.46, "fenetre": [0.08, 0.94],
			},
		},
		# poses tenues
		"charge": [Vector3(0.33, 0.0, -0.42), Vector3(0.14, 0.78, 0.62), Vector3(0.0, 0.6, -0.80)],
		"garde": [Vector3(0.10, -0.20, -0.50), Vector3(-0.85, 0.42, -0.25), Vector3(0.0, 0.5, -1.0)],
		"encaisse": [Vector3(0.14, -0.13, -0.42), Vector3(-0.85, 0.52, -0.08), Vector3(0.0, 0.5, -1.0)],
		# sprint : épée abaissée le long du corps, pointe vers l'avant-bas
		"sprint": [Vector3(0.36, -0.40, -0.40), Vector3(-0.12, 0.45, -0.88), Vector3(-0.3, 0.0, -1.0)],
	},
}

static func profil(nom: String) -> Dictionary:
	return PROFILS.get(nom, PROFILS["epee_longue"])

## Geste résolu (les gestes « miroir » sont recopiés côté opposé).
static func geste(nom_profil: String, nom_geste: String) -> Dictionary:
	var gestes: Dictionary = profil(nom_profil)["gestes"]
	var g: Dictionary = gestes[nom_geste]
	if g.has("miroir"):
		var src: Dictionary = gestes[g["miroir"]]
		var r := g.duplicate()
		for k in ["armer", "milieu", "fin"]:
			r[k] = miroir(src[k])
		return r
	return g

static func miroir(p: Array) -> Array:
	var r := []
	for v: Vector3 in p:
		r.append(Vector3(-v.x, v.y, v.z))
	return r

## Transform d'une pose [poignée, lame, tranchant] : +Y le long de la lame, +X vers le tranchant.
static func transform_pose(p: Array, sens := 1.0) -> Transform3D:
	var pos: Vector3 = p[0]
	var lame: Vector3 = p[1]
	var fil: Vector3 = p[2]
	if sens < 0.0:
		pos.x = -pos.x
		lame.x = -lame.x
		fil.x = -fil.x
	var y := lame.normalized()
	var x := fil - y * fil.dot(y)
	if x.length_squared() < 1e-6:
		x = y.cross(Vector3.FORWARD)
	x = x.normalized()
	return Transform3D(Basis(x, y, x.cross(y)), pos)

## Pose de la phase active à l'avancement s (0 → 1) : Bézier de la poignée par le milieu, double slerp de l'orientation.
static func pose_active(g: Dictionary, s: float) -> Transform3D:
	var a := transform_pose(g["armer"])
	var m := transform_pose(g["milieu"])
	var b := transform_pose(g["fin"])
	var c := m.origin * 2.0 - (a.origin + b.origin) * 0.5   # point de contrôle : la courbe passe par le milieu à s = 0,5
	var u := 1.0 - s
	var pos := a.origin * (u * u) + c * (2.0 * u * s) + b.origin * (s * s)
	var qa := a.basis.get_rotation_quaternion()
	var qm := m.basis.get_rotation_quaternion()
	var qb := b.basis.get_rotation_quaternion()
	var q := qa.slerp(qm, s).slerp(qm.slerp(qb, s), s)
	return Transform3D(Basis(q), pos)

## Avancement de la lame dans la phase active : lent au départ, vif au milieu, freiné à la fin (poids de l'arme).
static func courbe_active(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)
