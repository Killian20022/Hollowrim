class_name ProfilsAnimation
## Profils d'animation des armes en vue FPS : gestes d'attaque (préparation → phase active → récupération), poses de garde,
## de sprint. Chaque pose = [position de la poignée, direction de la lame, côté du tranchant] dans le repère caméra
## (+X droite, +Y haut, -Z devant). Un geste actif passe par trois poses (départ armé, milieu bras tendu, fin) :
## la poignée suit une courbe de Bézier qui passe par le milieu, l'orientation un double slerp (de Casteljau).
## Les durées sont en secondes pour une arme de vitesse 1 (DonneesArme.vitesse les divise).
## Les mêmes fonctions servent à l'image affichée ET au tracé de lame : ce que l'on voit est ce qui touche.

## Gestes d'attaque CONÇUS EN ESPACE ÉCRAN (passe 4) : un viewmodel FPS (Skyrim, Mordhau, Chivalry) fait balayer la
## lame EN TRAVERS de l'écran, jamais vers la cible en profondeur (elle serait vue en bout). Quatre CLÉS par geste
## (armer = A, milieu, fin = B, suivi = dépassement après B), chacune un dictionnaire écran :
##   g : position ÉCRAN de la garde (coordonnées normalisées : x -1 gauche → +1 droite, y -1 bas → +1 haut) ;
##   z : profondeur de la garde devant la caméra (m) ;
##   t : position ÉCRAN de la pointe (même repère) ; sa profondeur découle de la longueur de la lame (0,87 m).
## Garde et pointe dans l'écran = lame entière visible ; écartées à l'écran = lame vue de travers (angle avec le
## rayon de visée ≥ 50°, mesuré par l'outil).
## La main se déduit de la garde ; le tranchant suit la TANGENTE de l'arc décrit par la pointe (le tranchant mène, la
## lame ne tourne pas sur elle-même) ; le coude est placé à chaque image pour que l'avant-bras prolonge la poignée À
## L'ÉCRAN (mains._pole_ecran) : pas de poignet cassé visible. Mesures : outils/captures_combat_epee.gd -- --mesures.
## Rythme d'un coup : préparation (vers A) → tenue (A lisible, 2-3 images) → frappe A → B très rapide (courbe d'accélération
## `acceleration`) → suivi bref qui dépasse B (`suivi_duree`, s) → retour au repos ou coup suivant.
## « cotes » = [côté de départ, côté d'arrivée] (+1 droite, -1 gauche, 0 centre) ; « enchainement » = fenêtre de combo
## [début (s), fin (part de la récupération)] ; « force » = multiplicateur de dégâts du geste ; « fenetre » = part de la
## frappe où la lame blesse ; « tassement » = petit tassement de la caméra à la fin de la frappe (coup 3, lourd).
const PROFILS := {
	"epee_longue": {
		# enchaînement de base à l'arrêt : 1 diagonale → 2 horizontal → 3 vertical (le plus fort)
		"combo": ["diag_dg", "horizontale_gd", "verticale_l"],
		"lourd": "verticale",
		"gestes": {
			# coup 1 : armé en haut à droite, la lame balaie en DIAGONALE à travers le centre jusqu'en bas à gauche
			"diag_dg": {
				"armer": {"g": Vector2(0.6, -0.1), "z": 0.63, "t": Vector2(0.38, 1.15)},
				"milieu": {"g": Vector2(0.2, -0.4), "z": 0.55, "t": Vector2(-0.34, 1.07)},
				"fin": {"g": Vector2(-0.22, -0.72), "z": 0.69, "t": Vector2(-1.11, -0.09)},
				"suivi": {"g": Vector2(-0.28, -0.74), "z": 0.72, "t": Vector2(-0.98, -0.28)},
				"preparation": 0.10, "tenue": 0.04, "active": 0.09, "acceleration": 2.6, "suivi_duree": 0.07, "recuperation": 0.30,
				"fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.04, 0.9], "force": 1.0,
			},
			# coup 2 : repart de bas-gauche, lame à plat, la pointe balaie HORIZONTALEMENT de gauche à droite (poitrine)
			"horizontale_gd": {
				"armer": {"g": Vector2(-0.38, -0.6), "z": 0.69, "t": Vector2(-1.08, 0.44)},
				"milieu": {"g": Vector2(0.0, -0.68), "z": 0.55, "t": Vector2(0.0, 0.92)},
				"fin": {"g": Vector2(0.38, -0.6), "z": 0.69, "t": Vector2(1.08, 0.44)},
				"suivi": {"g": Vector2(0.47, -0.64), "z": 0.75, "t": Vector2(1.07, -0.15)},
				"preparation": 0.11, "tenue": 0.04, "active": 0.09, "acceleration": 2.2, "suivi_duree": 0.07, "recuperation": 0.30,
				"fenetre": [0.0, 1.0], "cotes": [-1, 1], "enchainement": [0.04, 0.9], "force": 1.0,
			},
			# coup 3 : armé haut (main en haut, un peu à droite du centre, lame dressée), frappe VERTICALE de haut en bas à
			# travers le centre, finit basse ; le plus fort, un peu plus lent, tassement de la caméra à l'impact
			"verticale_l": {
				"armer": {"g": Vector2(0.25, 0.0), "z": 0.73, "t": Vector2(0.0, 1.15)},
				"milieu": {"g": Vector2(0.14, -0.24), "z": 0.64, "t": Vector2(-0.71, 0.08)},
				"fin": {"g": Vector2(0.06, -0.74), "z": 0.55, "t": Vector2(-0.85, -0.02)},
				"suivi": {"g": Vector2(0.03, -0.8), "z": 0.55, "t": Vector2(-0.78, -0.06)},
				"preparation": 0.12, "tenue": 0.05, "active": 0.10, "acceleration": 3.0, "suivi_duree": 0.08, "recuperation": 0.34,
				"fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.06, 0.85], "force": 1.25, "tassement": 1.0,
			},
			# variantes contextuelles : diagonale revers (main partie de l'épaule gauche, finit en bas à droite, lame toujours
			# levée : un vrai miroir du coup 1 tordrait le bras droit), horizontal droite → gauche (miroir du coup 2)
			"diag_gd": {
				"armer": {"g": Vector2(-0.42, -0.12), "z": 0.67, "t": Vector2(-0.29, 1.15)},
				"milieu": {"g": Vector2(-0.05, -0.42), "z": 0.59, "t": Vector2(0.32, 1.14)},
				"fin": {"g": Vector2(0.28, -0.68), "z": 0.55, "t": Vector2(0.61, 0.91)},
				"suivi": {"g": Vector2(0.35, -0.74), "z": 0.55, "t": Vector2(0.76, 0.72)},
				"preparation": 0.11, "tenue": 0.04, "active": 0.09, "acceleration": 2.6, "suivi_duree": 0.07, "recuperation": 0.30,
				"fenetre": [0.0, 1.0], "cotes": [-1, 1], "enchainement": [0.04, 0.9], "force": 1.0},
			"horizontale": {"miroir": "horizontale_gd",
				"preparation": 0.11, "tenue": 0.04, "active": 0.09, "acceleration": 2.2, "suivi_duree": 0.07, "recuperation": 0.30,
				"fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.04, 0.9], "force": 1.0},
			# estoc (en reculant) : la main part de la hanche droite et pique vers le centre en s'enfonçant ; la lame garde son
			# angle à l'écran (≥ 50° avec le rayon de visée : jamais vue en bout), tranchant à plat (fil imposé)
			"estoc": {
				"armer": {"g": Vector2(0.5, -0.62), "z": 0.55, "t": Vector2(-0.06, 0.21)},
				"milieu": {"g": Vector2(0.34, -0.5), "z": 0.55, "t": Vector2(-0.24, 0.36)},
				"fin": {"g": Vector2(0.24, -0.42), "z": 0.56, "t": Vector2(-0.37, 0.5)},
				"suivi": {"g": Vector2(0.22, -0.4), "z": 0.57, "t": Vector2(-0.4, 0.54)},
				"fil": Vector3(0.0, 1.0, 0.0),
				"preparation": 0.11, "tenue": 0.04, "active": 0.10, "acceleration": 2.0, "suivi_duree": 0.05, "recuperation": 0.30,
				"fenetre": [0.25, 1.0], "cotes": [0, 0], "enchainement": [0.06, 0.8], "force": 1.0,
			},
			# coup lourd : armé large au-dessus de l'épaule droite (pose de charge), abattu en grand arc à travers l'écran
			"verticale": {
				"armer": {"g": Vector2(0.62, -0.12), "z": 0.71, "t": Vector2(0.65, 1.16)},
				"milieu": {"g": Vector2(0.2, -0.38), "z": 0.55, "t": Vector2(-0.41, 1.01)},
				"fin": {"g": Vector2(-0.12, -0.72), "z": 0.63, "t": Vector2(-1.07, -0.11)},
				"suivi": {"g": Vector2(-0.2, -0.76), "z": 0.68, "t": Vector2(-0.98, -0.42)},
				"preparation": 0.06, "tenue": 0.0, "active": 0.14, "acceleration": 2.8, "suivi_duree": 0.10, "recuperation": 0.46,
				"fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.08, 0.8], "force": 1.0, "tassement": 1.0,
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

## Optique de la caméra du joueur (joueur.gd : fov 72° vertical, écran 16:9) : conversion des clés écran.
const TAN_V := 0.7265
const TAN_H := 0.7265 * 16.0 / 9.0
## Distance de l'origine de l'objet (pommeau) à la garde, le long de la lame (épées longues : 0,096-0,1).
const GARDE_Y := 0.098
static var _cache := {}

## Point (repère caméra) vu à la position écran `e` (normalisée) et à la profondeur z.
static func point_ecran(e: Vector2, z: float) -> Vector3:
	return Vector3(e.x * TAN_H * z, e.y * TAN_V * z, -z)

## Position écran normalisée d'un point du repère caméra.
static func vers_ecran(p: Vector3) -> Vector2:
	var z := maxf(-p.z, 0.001)
	return Vector2(p.x / z / TAN_H, p.y / z / TAN_V)

## Longueur de lame (garde → pointe) des épées longues.
const LONGUEUR_LAME := 0.87

## Clé écran {g, z, t} → [position de l'objet (pommeau), direction de la lame, pôle (calculé à l'image : ZERO)].
## La pointe est sur le rayon de visée de `t`, à la distance de la garde qui donne la longueur de la lame (racine la
## plus lointaine : la pointe part en profondeur, jamais vers la caméra).
static func cle_ecran(c: Dictionary) -> Array:
	var garde := point_ecran(c["g"], float(c["z"]))
	var d := point_ecran(c["t"], 1.0)
	var dd := d.dot(d)
	var dg := d.dot(garde)
	var disc := dg * dg - dd * (garde.dot(garde) - LONGUEUR_LAME * LONGUEUR_LAME)
	var k := (dg + sqrt(maxf(disc, 0.0))) / dd
	var lame := (d * k - garde).normalized()
	return [garde - lame * GARDE_Y, lame, Vector3.ZERO]

## Geste résolu : clés écran converties en [poignée, lame, pôle] ; les gestes « miroir » sont recopiés côté opposé
## (poignée et lame en miroir de l'écran).
static func geste(nom_profil: String, nom_geste: String) -> Dictionary:
	var cle := nom_profil + "/" + nom_geste
	if _cache.has(cle):
		return _cache[cle]
	var gestes: Dictionary = profil(nom_profil)["gestes"]
	var g: Dictionary = gestes[nom_geste]
	var r := g.duplicate()
	var src: Dictionary = gestes[g["miroir"]] if g.has("miroir") else g
	for k in CLES:
		var c = src[k]
		var v: Array = cle_ecran(c) if c is Dictionary else c
		if g.has("miroir"):
			v = [Vector3(-v[0].x, v[0].y, v[0].z), Vector3(-v[1].x, v[1].y, v[1].z), v[2]]
		r[k] = v
	if g.has("miroir") and src.has("fil"):
		r["fil"] = src["fil"]
	if g.has("miroir") and src.has("tassement"):
		r["tassement"] = src["tassement"]
	_cache[cle] = r
	return r

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
