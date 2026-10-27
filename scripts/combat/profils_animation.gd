class_name ProfilsAnimation
## Profils d'animation des armes en vue FPS : gestes d'attaque (préparation → phase active → récupération), poses de garde,
## de sprint. Chaque pose = [position de la poignée, direction de la lame, côté du tranchant] dans le repère caméra
## (+X droite, +Y haut, -Z devant). Un geste actif passe par trois poses (départ armé, milieu bras tendu, fin) :
## la poignée suit une courbe de Bézier qui passe par le milieu, l'orientation un double slerp (de Casteljau).
## Les durées sont en secondes pour une arme de vitesse 1 (DonneesArme.vitesse les divise).
## Les mêmes fonctions servent à l'image affichée ET au tracé de lame : ce que l'on voit est ce qui touche.

## Gestes d'attaque : quatre CLÉS par geste (armer = A, milieu, fin = B, suivi = dépassement après B), chacune
## [position de la poignée, direction de la lame, pôle du coude] (repère caméra). Le tranchant n'est PAS authoré : il suit
## la TANGENTE de l'arc décrit par la pointe (tranchant devant, aucune rotation de la lame sur elle-même) ; le pôle du coude
## est animé avec la main pour que l'avant-bras porte la lame : POIGNET RIGIDE (déviation bornée à ±15° pendant les coups,
## mains.gd), le mouvement vient de l'épaule et du coude. Pôles réglés par outils/regler_gestes.gd (écart image / tracé).
## Rythme d'un coup : préparation (vers A) → tenue (A lisible, 2-3 images) → frappe A → B très rapide (courbe d'accélération
## `acceleration`) → suivi bref qui dépasse B (`suivi`, s) → retour au repos ou coup suivant.
## « cotes » = [côté de départ, côté d'arrivée] (+1 droite, -1 gauche, 0 centre) ; « enchainement » = fenêtre de combo
## [début (s), fin (part de la récupération)] ; « force » = multiplicateur de dégâts du geste ; « fenetre » = part de la
## frappe où la lame blesse.
const PROFILS := {
	"epee_longue": {
		# enchaînement de base à l'arrêt : 1 diagonale → 2 horizontal (revers) → 3 vertical (le plus fort)
		"combo": ["diag_dg", "horizontale_gd", "verticale_l"],
		"lourd": "verticale",
		"gestes": {
			# coup 1 : diagonale haut-droite → bas-gauche, armée au-dessus de l'épaule droite
			"diag_dg": {
				"armer": [Vector3(0.34, -0.02, -0.34), Vector3(0.67, 0.67, -0.32), Vector3(0.2, -0.4, 0.4), Vector3(-0.33, -0.11, -0.94)],
				"milieu": [Vector3(0.1, -0.14, -0.5), Vector3(-0.2, 0.0, -0.98), Vector3(0.05, -0.4, 0.4), Vector3(0.75, 0.64, -0.15)],
				"fin": [Vector3(-0.12, -0.38, -0.4), Vector3(-0.77, -0.48, -0.42), Vector3(0.05, -0.4, 0.4), Vector3(0.14, 0.52, -0.84)],
				"suivi": [Vector3(-0.18, -0.45, -0.32), Vector3(-0.62, -0.78, -0.1), Vector3(0.05, -0.4, 0.4), Vector3(-0.41, 0.43, -0.8)],
				"preparation": 0.09, "tenue": 0.04, "active": 0.13, "acceleration": 2.4, "suivi_duree": 0.07, "recuperation": 0.30,
				"fenetre": [0.08, 1.0], "cotes": [1, -1], "enchainement": [0.04, 0.9], "force": 1.0,
			},
			# coup 2 : horizontal gauche → droite (revers), lame à plat à hauteur de poitrine ; repart d'où le 1 a fini
			"horizontale_gd": {
				"armer": [Vector3(-0.2, -0.14, -0.4), Vector3(-0.99, 0.08, 0.1), Vector3(0.05, 0.15, -0.55), Vector3(-0.05, 0.52, -0.85)],
				"milieu": [Vector3(0.08, -0.16, -0.52), Vector3(0.25, 0.03, -0.97), Vector3(0.05, 0.15, -0.55), Vector3(-0.85, 0.49, -0.2)],
				"fin": [Vector3(0.36, -0.18, -0.4), Vector3(0.99, 0.0, 0.1), Vector3(0.05, 0.15, -0.55), Vector3(0.1, 0.09, -0.99)],
				"suivi": [Vector3(0.42, -0.2, -0.32), Vector3(0.86, -0.05, 0.51), Vector3(0.05, 0.15, -0.55), Vector3(0.51, -0.01, -0.86)],
				"preparation": 0.10, "tenue": 0.05, "active": 0.15, "acceleration": 1.8, "suivi_duree": 0.08, "recuperation": 0.32,
				"fenetre": [0.08, 1.0], "cotes": [-1, 1], "enchainement": [0.04, 0.9], "force": 1.0,
			},
			# coup 3 : vertical, épée levée au-dessus de la tête, frappe droite au centre, finit basse devant (le plus fort)
			"verticale_l": {
				"armer": [Vector3(0.18, 0.1, -0.36), Vector3(0.11, 0.89, 0.45), Vector3(0.2, -0.8, -0.4), Vector3(-0.2, 0.46, -0.86)],
				"milieu": [Vector3(0.08, -0.04, -0.52), Vector3(0.0, 0.3, -0.95), Vector3(0.2, -0.25, 0.95), Vector3(-0.42, 0.87, 0.27)],
				"fin": [Vector3(0.06, -0.32, -0.5), Vector3(0.0, -0.55, -0.83), Vector3(0.2, -0.25, 0.95), Vector3(-0.06, 0.83, -0.55)],
				"suivi": [Vector3(0.06, -0.4, -0.44), Vector3(0.0, -0.8, -0.6), Vector3(0.2, -0.25, 0.95), Vector3(0.27, 0.58, -0.77)],
				"preparation": 0.13, "tenue": 0.06, "active": 0.14, "acceleration": 3.0, "suivi_duree": 0.08, "recuperation": 0.36,
				"fenetre": [0.08, 1.0], "cotes": [1, 0], "enchainement": [0.06, 0.85], "force": 1.25,
			},
			# variantes contextuelles : diagonale revers (miroir du coup 1), horizontal droite → gauche (miroir du coup 2)
			"diag_gd": {
				"armer": [Vector3(-0.3, 0.02, -0.25), Vector3(-0.35, 0.75, 0.55), Vector3(0.05, -0.4, 0.65), Vector3(-0.82, 0.04, -0.57)],
				"milieu": [Vector3(-0.08, -0.15, -0.5), Vector3(0.36, 0.42, -0.83), Vector3(0.05, -0.4, 0.65), Vector3(-0.93, 0.26, -0.28)],
				"fin": [Vector3(0.12, -0.38, -0.4), Vector3(0.76, -0.46, -0.46), Vector3(0.05, -0.4, 0.65), Vector3(0.01, 0.72, -0.7)],
				"suivi": [Vector3(0.18, -0.45, -0.32), Vector3(0.73, -0.27, -0.63), Vector3(0.05, -0.4, 0.65), Vector3(-0.13, 0.85, -0.51)],
				"preparation": 0.11, "tenue": 0.04, "active": 0.13, "acceleration": 2.4, "suivi_duree": 0.07, "recuperation": 0.30,
				"fenetre": [0.08, 1.0], "cotes": [-1, 1], "enchainement": [0.04, 0.9], "force": 1.0},
			"horizontale": {
				"armer": [Vector3(0.15, -0.22, -0.32), Vector3(0.97, 0.17, 0.16), Vector3(0.05, -0.65, 0.95), Vector3(0.13, 0.16, -0.98)],
				"milieu": [Vector3(-0.08, -0.2, -0.52), Vector3(-0.04, 0.0, -1.0), Vector3(0.05, -0.65, 0.95), Vector3(-0.91, 0.42, 0.04)],
				"fin": [Vector3(-0.36, -0.22, -0.38), Vector3(-0.93, 0.05, 0.36), Vector3(0.05, -0.65, 0.95), Vector3(-0.36, 0.09, -0.93)],
				"suivi": [Vector3(-0.42, -0.24, -0.28), Vector3(-0.82, 0.01, 0.58), Vector3(0.05, -0.65, 0.95), Vector3(-0.58, 0.09, -0.81)],
				"preparation": 0.10, "tenue": 0.05, "active": 0.15, "acceleration": 1.8, "suivi_duree": 0.08, "recuperation": 0.32,
				"fenetre": [0.08, 1.0], "cotes": [1, -1], "enchainement": [0.04, 0.9], "force": 1.0},
			# estoc (en reculant) : la lame part de la hanche et pique droit devant (tranchant imposé : l'arc est rectiligne)
			"estoc": {
				"armer": [Vector3(0.24, -0.3, -0.22), Vector3(-0.04, 0.18, -0.98), Vector3(0.5, -0.4, 0.65), Vector3(-1.0, -0.04, 0.03)],
				"milieu": [Vector3(0.14, -0.22, -0.52), Vector3(0.01, 0.1, -1.0), Vector3(0.5, -0.4, 0.65), Vector3(-1.0, 0.02, -0.01)],
				"fin": [Vector3(0.08, -0.2, -0.62), Vector3(0.06, -0.25, -0.97), Vector3(0.5, -0.4, 0.65), Vector3(-0.34, 0.9, -0.25)],
				"suivi": [Vector3(0.08, -0.21, -0.65), Vector3(0.06, -0.27, -0.96), Vector3(0.5, -0.4, 0.65), Vector3(-0.35, 0.89, -0.28)],
				"fil": Vector3(-1.0, 0.0, 0.0),
				"preparation": 0.11, "tenue": 0.04, "active": 0.12, "acceleration": 2.0, "suivi_duree": 0.05, "recuperation": 0.30,
				"fenetre": [0.25, 1.0], "cotes": [0, 0], "enchainement": [0.06, 0.8], "force": 1.0,
			},
			# coup lourd : armé large derrière l'épaule droite (pose de charge), abattu de haut en bas
			"verticale": {
				"armer": [Vector3(0.3, 0.06, -0.18), Vector3(0.25, 0.38, 0.89), Vector3(0.35, 0.0, -0.4), Vector3(0.03, 0.92, -0.39)],
				"milieu": [Vector3(0.08, -0.04, -0.52), Vector3(-0.05, 0.2, -0.98), Vector3(0.05, -0.4, -0.25), Vector3(-0.22, 0.95, 0.2)],
				"fin": [Vector3(0.0, -0.42, -0.42), Vector3(-0.1, -0.73, -0.68), Vector3(0.05, -0.4, -0.25), Vector3(0.04, 0.68, -0.73)],
				"suivi": [Vector3(-0.02, -0.5, -0.32), Vector3(-0.1, -0.95, -0.3), Vector3(0.05, -0.4, -0.25), Vector3(0.25, 0.27, -0.93)],
				"preparation": 0.06, "tenue": 0.0, "active": 0.20, "acceleration": 2.6, "suivi_duree": 0.10, "recuperation": 0.46,
				"fenetre": [0.06, 1.0], "cotes": [1, 0], "enchainement": [0.08, 0.8], "force": 1.0,
			},
		},
		# poses tenues [poignée, lame, tranchant]
		"garde": [Vector3(0.10, -0.20, -0.50), Vector3(-0.85, 0.42, -0.25), Vector3(0.0, 0.5, -1.0)],
		"encaisse": [Vector3(0.14, -0.13, -0.42), Vector3(-0.85, 0.52, -0.08), Vector3(0.0, 0.5, -1.0)],
		# sprint : épée abaissée le long du corps, pointe vers l'avant-bas
		"sprint": [Vector3(0.34, -0.50, -0.36), Vector3(-0.15, 0.30, -0.94), Vector3(-0.5, 0.0, -1.0)],
	},
}

const CLES := ["armer", "milieu", "fin", "suivi"]
## Longueur de lame utilisée pour la tangente de l'arc (pointe approchée).
const LAME_TANGENTE := 0.8

static func profil(nom: String) -> Dictionary:
	return PROFILS.get(nom, PROFILS["epee_longue"])

## Geste résolu (les gestes « miroir » sont recopiés côté opposé : poignée et lame en miroir, pôle du coude gardé du
## côté droit, le bras qui tient l'épée).
static func geste(nom_profil: String, nom_geste: String) -> Dictionary:
	var gestes: Dictionary = profil(nom_profil)["gestes"]
	var g: Dictionary = gestes[nom_geste]
	if g.has("miroir"):
		var src: Dictionary = gestes[g["miroir"]]
		var r := g.duplicate()
		for k in CLES:
			var c: Array = src[k]
			r[k] = [Vector3(-c[0].x, c[0].y, c[0].z), Vector3(-c[1].x, c[1].y, c[1].z), c[2]]
		if g.has("coudes"):
			for i in CLES.size():
				r[CLES[i]][2] = g["coudes"][i]
		return r
	return g

## Geste miroir (diagonales, horizontales) ou le même s'il n'en a pas.
const MIROIRS := {"diag_dg": "diag_gd", "diag_gd": "diag_dg", "horizontale": "horizontale_gd", "horizontale_gd": "horizontale"}

static func miroir(p: Array) -> Array:
	var r := []
	for v: Vector3 in p:
		r.append(Vector3(-v.x, v.y, v.z))
	return r

## Pointe approchée d'une clé.
static func _pointe(c: Array) -> Vector3:
	return (c[0] as Vector3) + (c[1] as Vector3).normalized() * LAME_TANGENTE

## Repère d'une clé : +Y le long de la lame, +X (tranchant) le long de la tangente de l'arc de la pointe.
static func _repere_cle(g: Dictionary, k: String) -> Transform3D:
	var c: Array = g[k]
	var t := Vector3.ZERO
	match k:
		"armer":
			t = _pointe(g["milieu"]) - _pointe(g["armer"])
		"milieu":
			t = _pointe(g["fin"]) - _pointe(g["armer"])
		"fin":
			t = _pointe(g["fin"]) - _pointe(g["milieu"])
		"suivi":
			t = _pointe(g["suivi"]) - _pointe(g["milieu"])
	var y := (c[1] as Vector3).normalized()
	var x := t - y * t.dot(y)
	if c.size() >= 4:
		x = (c[3] as Vector3) - y * (c[3] as Vector3).dot(y)   # tranchant naturel du poignet rigide (outils/regler_gestes.gd)
	elif g.has("fil") or x.length_squared() < 1e-4:
		var f: Vector3 = g.get("fil", y.cross(Vector3.FORWARD))
		x = f - y * f.dot(y)
	return Transform3D(Basis(x.normalized(), y, x.normalized().cross(y)), c[0])

## Pose d'une clé (préparation vers « armer », suivi vers « suivi »).
static func pose_cle(g: Dictionary, k: String) -> Transform3D:
	return _repere_cle(g, k)

static func coude_cle(g: Dictionary, k: String) -> Vector3:
	return g[k][2]

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

## Pose de la frappe à l'avancement s (0 = A, 1 = B) : Bézier de la poignée par le milieu, slerp de l'orientation
## A → milieu → B entre les repères des clés.
static func pose_active(g: Dictionary, s: float) -> Transform3D:
	var a := _repere_cle(g, "armer")
	var m := _continuer(a, _repere_cle(g, "milieu"))
	var b := _continuer(m, _repere_cle(g, "fin"))
	var pos := _bezier(a.origin, m.origin, b.origin, s)
	var qa := a.basis.get_rotation_quaternion()
	var qm := m.basis.get_rotation_quaternion()
	var qb := b.basis.get_rotation_quaternion()
	# deux slerps successifs A → milieu → B : la lame passe EXACTEMENT par la clé du milieu (un double slerp de Casteljau la
	# manquait et pouvait faire passer la lame derrière la tête)
	var q := qa.slerp(qm, s * 2.0) if s < 0.5 else qm.slerp(qb, s * 2.0 - 1.0)
	return Transform3D(Basis(q), pos)

## Lame à deux tranchants : le repère suivant garde le tranchant du même côté que le précédent (transporté par la
## rotation minimale de la lame) — sinon le slerp ferait pivoter la lame sur elle-même et sortir de son plan de coupe.
static func _continuer(prec: Transform3D, t: Transform3D) -> Transform3D:
	var porte := Quaternion(prec.basis.y.normalized(), t.basis.y.normalized())
	if (porte * prec.basis.x).dot(t.basis.x) < 0.0:
		return Transform3D(Basis(-t.basis.x, t.basis.y, -t.basis.z), t.origin)
	return t

## Pôle du coude pendant la frappe (même courbe que la poignée).
static func coude_actif(g: Dictionary, s: float) -> Vector3:
	return _bezier(g["armer"][2], g["milieu"][2], g["fin"][2], s)

static func _bezier(a: Vector3, m: Vector3, b: Vector3, s: float) -> Vector3:
	var c := m * 2.0 - (a + b) * 0.5   # point de contrôle : la courbe passe par le milieu à s = 0,5
	var u := 1.0 - s
	return a * (u * u) + c * (2.0 * u * s) + b * (s * s)

## Avancement de la lame pendant la frappe : départ lent, ACCÉLÉRATION forte (exposant `k` du geste), arrivée encore
## rapide en B (le suivi absorbe l'élan). k = 1 : vitesse constante.
static func courbe_active(u: float, k := 2.4) -> float:
	u = clampf(u, 0.0, 1.0)
	return 0.75 * pow(u, k) + 0.25 * u
