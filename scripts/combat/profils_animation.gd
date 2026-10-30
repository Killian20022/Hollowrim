class_name ProfilsAnimation
## Profils d'animation des armes en vue FPS : quels CLIPS (animations à images clés du bras droit, AnimateurBras) jouent
## les gestes d'attaque, et leurs règles de jeu (fenêtre de dégâts, côtés, combo, force, tassement de caméra).
## Les DURÉES viennent des marqueurs des clips (arme, frappe, fin_frappe, suivi, fin ; s à vitesse 1), divisées par la
## vitesse de l'arme (DonneesArme.vitesse) : préparation = arme, tenue = frappe − arme, phase active = fin_frappe −
## frappe, suivi = suivi − fin_frappe, récupération = fin − fin_frappe.
## Les poses clés des clips se règlent dans sources_blender/scripts/gestes_bras_epee.py (voir docs/COMBAT.md,
## « Coups animés à la main »), puis `anim_bras_epee.py -- --godot` réécrit assets/animations/bras_epee.tres.
## « cotes » = [côté de départ, côté d'arrivée] (+1 droite, -1 gauche, 0 centre) ; « enchainement » = fenêtre de combo
## [début (s), fin (part de la récupération)] ; « force » = multiplicateur de dégâts du geste ; « fenetre » = part de la
## frappe où la lame blesse ; « tassement » = petit tassement de la caméra à la fin de la frappe (coup 3, lourds) ;
## « charge » (attaques puissantes) = clip de l'armé tenu pendant la charge ; « elan » = avancée du joueur sur l'armé (m, coups_v4 :
## AccompagnementCoup ; 0 pour l'estoc en reculant).
const PROFILS := {
	"epee_longue": {
		# enchaînement de base à l'arrêt (retour utilisateur 2026-10-27) : 1 VRAIE diagonale haut-droite → bas-gauche,
		# 2 horizontal GAUCHE → DROITE (revers à plat, repart d'en bas à gauche), 3 ESTOC (le plus fort)
		"combo": CoupsUneMain.COMBO,   # coups_v5 : 4 coups (diagonale, revers, taille horizontale, estoc), voir CoupsUneMain
		"lourd": "lourd",
		# attaque puissante selon le déplacement au début de la charge (mains._choisir_lourd)
		"lourds": {"arret": "lourd", "avant": "verticale", "gauche": "lourd", "droite": "lourd_gd", "arriere": "lourd_revers"},
		"gestes": {
			# coup 1 : épée levée au-dessus de l'épaule droite (poing au coin haut droit), fend en DIAGONALE à travers le
			# centre de l'écran jusqu'en bas à gauche, pronation progressive de l'avant-bras (sans retournement)
			"diag_dg": {"clip": "coup_a", "fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.04, 1.0], "force": 1.0, "elan": 0.35},
			# coup 2 : repart de la fin du 1 (en bas à gauche), armé à gauche à hauteur de poitrine, revers HORIZONTAL vers
			# la droite, lame à plat (normale du plat verticale), avant-bras en pronation tout du long (départ « 0 » :
			# jamais remplacé par un miroir)
			"revers_gd": {"clip": "coup_b", "fenetre": [0.0, 1.0], "cotes": [0, 1], "enchainement": [0.04, 1.0], "force": 1.0, "elan": 0.3},
			# coup 3 : ESTOC du combo (même geste que l'estoc en reculant, qui plaît), part de la fin du 2 (à droite) ;
			# le plus fort, petit tassement de la caméra
			"estoc_combo": {"clip": "coup_c", "fenetre": [0.25, 1.0], "cotes": [0, 0], "enchainement": [0.06, 0.8], "force": 1.25, "tassement": 0.6, "elan": 0.55},
			# anciens coups du combo (avant 2026-10-27, « le coup du haut est mauvais ») : plus choisis, gardés pour comparaison
			"horizontale_b": {"clip": "coup_b_ancien", "fenetre": [0.0, 1.0], "cotes": [0, -1], "enchainement": [0.04, 1.0], "force": 1.0, "elan": 0.3},
			# revers horizontal gauche → droite, légèrement montant (pas à droite, miroir de « horizontale »)
			"horizontale_gd": {"clip": "coup_gd", "fenetre": [0.0, 1.0], "cotes": [-1, 1], "enchainement": [0.04, 1.0], "force": 1.0, "elan": 0.3},
			# vertical (souris tirée vers le bas, en avançant) : clip coup_v (V3, 2026-10-27) : armé court au coin haut droit,
			# la lame descend dans un plan vertical un peu à droite du centre, tranchant en bas, poignet qui casse à l'impact ;
			# le plus fort, tassement de la caméra à l'impact (ancien clip : coup_c_ancien, une diagonale raide)
			"verticale_l": {"clip": "coup_v", "fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.06, 1.0], "force": 1.25, "tassement": 1.0, "elan": 0.45},
			# variantes contextuelles : horizontal droite → gauche (pas de côté à gauche), diagonale revers haut-gauche →
			# bas-droite (miroir de A quand la lame est déjà à gauche), estoc (en reculant)
			"horizontale": {"clip": "coup_horizontal", "fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.04, 1.0], "force": 1.0, "elan": 0.3},
			"diag_gd": {"clip": "coup_revers", "fenetre": [0.0, 1.0], "cotes": [-1, 1], "enchainement": [0.04, 1.0], "force": 1.0, "elan": 0.3},
			"estoc": {"clip": "estoc", "fenetre": [0.25, 1.0], "cotes": [0, 0], "enchainement": [0.06, 0.8], "force": 1.0, "elan": 0.0},
			# attaques puissantes (maintien) : plus lentes, du poids ; armé tenu pendant la charge (« charge »)
			"lourd": {"clip": "lourd", "charge": "charge_lourd", "fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.08, 0.8], "force": 1.0, "tassement": 0.7, "elan": 0.5},
			"verticale": {"clip": "lourd_vertical", "charge": "charge_vertical", "fenetre": [0.0, 1.0], "cotes": [1, 0], "enchainement": [0.08, 0.8], "force": 1.0, "tassement": 1.0, "elan": 0.6},
			"lourd_gd": {"clip": "lourd_gd", "charge": "charge_gd", "fenetre": [0.0, 1.0], "cotes": [-1, 1], "enchainement": [0.08, 0.8], "force": 1.0, "tassement": 0.7, "elan": 0.45},
			"lourd_revers": {"clip": "lourd_revers", "charge": "charge_revers", "fenetre": [0.0, 1.0], "cotes": [0, 0], "enchainement": [0.08, 0.8], "force": 1.0, "tassement": 0.5, "elan": 0.15},
		},
	},
}

## Geste miroir (diagonales, horizontales) ou le même s'il n'en a pas.
const MIROIRS := {"diag_dg": "diag_gd", "diag_gd": "diag_dg", "horizontale": "horizontale_gd", "horizontale_gd": "horizontale"}

static func profil(nom: String) -> Dictionary:
	return PROFILS.get(nom, PROFILS["epee_longue"])

static func geste(nom_profil: String, nom_geste: String) -> Dictionary:
	var g: Dictionary = profil(nom_profil)["gestes"]
	return g[nom_geste] if g.has(nom_geste) else CoupsUneMain.GESTES[nom_geste]   # coups_v5 : gestes à une main ajoutés

## Optique de la caméra du joueur (joueur.gd : fov 72° vertical, écran 16:9).
const TAN_V := 0.7265
const TAN_H := 0.7265 * 16.0 / 9.0

## Point (repère caméra) vu à la position écran `e` (normalisée) et à la profondeur z.
static func point_ecran(e: Vector2, z: float) -> Vector3:
	return Vector3(e.x * TAN_H * z, e.y * TAN_V * z, -z)

## Position écran normalisée d'un point du repère caméra.
static func vers_ecran(p: Vector3) -> Vector2:
	var z := maxf(-p.z, 0.001)
	return Vector2(p.x / z / TAN_H, p.y / z / TAN_V)

## Transform d'une pose [poignée, lame, tranchant] : +Y le long de la lame, +X vers le tranchant (torche, main gauche).
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
