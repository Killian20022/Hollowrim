class_name GestesDefense
## Gestes et poses de la phase 3 (défense, contre-attaque, finishers) en vue FPS, À PART des profils d'attaque
## (ProfilsAnimation.PROFILS : coups légers / lourds et pose de repos, réglés sur une autre branche) : ce fichier ne
## dépend pas de leurs clés, on peut refaire les coups sans toucher à la défense et inversement.
## Même approche que les coups (ProfilsAnimation, passe 4) : gestes CONÇUS EN ESPACE ÉCRAN, quatre clés {g : garde à
## l'écran (x -1 → +1, y -1 → +1), z : profondeur de la garde (m), t : pointe à l'écran} résolues par
## ProfilsAnimation.cle_ecran ; la lame balaie EN TRAVERS de l'écran (jamais vue en bout), le tranchant suit l'arc, le
## coude est placé à chaque image par mains._pole_ecran (pas de poignet cassé). Poses tenues [poignée, lame, tranchant].
## Durées pour une arme de vitesse 1 (DonneesArme.vitesse les divise, sauf les finishers : durée fixe, ≤ 0,8 s).

const GESTES := {
	# contre-attaque après une parade parfaite : la lame part de la garde (haut gauche) et fend en grande diagonale jusqu'en
	# bas à droite, plus ample et plus rapide qu'un coup léger (préparation courte : l'épée est déjà levée)
	"contre": {
		"armer": {"g": Vector2(-0.5, -0.05), "z": 0.7, "t": Vector2(-0.55, 1.15)},
		"milieu": {"g": Vector2(-0.02, -0.4), "z": 0.56, "t": Vector2(0.45, 1.05)},
		"fin": {"g": Vector2(0.34, -0.7), "z": 0.6, "t": Vector2(1.05, 0.35)},
		"suivi": {"g": Vector2(0.4, -0.76), "z": 0.63, "t": Vector2(1.08, 0.1)},
		"preparation": 0.06, "tenue": 0.03, "active": 0.09, "acceleration": 2.8, "suivi_duree": 0.09, "recuperation": 0.34,
		"fenetre": [0.0, 1.0], "cotes": [-1, 1], "enchainement": [0.08, 0.8], "force": 1.4, "tassement": 0.6,
	},
	# finisher de taille (décapitation) : élan à droite, lame dressée vers l'extérieur, puis coupe HORIZONTALE qui traverse
	# le centre de l'écran — là où la caméra verrouillée a mis le cou de la cible — et finit à gauche
	"finisher_taille": {
		"armer": {"g": Vector2(0.55, -0.35), "z": 0.75, "t": Vector2(1.12, 0.3)},
		"milieu": {"g": Vector2(0.05, -0.32), "z": 0.55, "t": Vector2(-0.25, 0.32)},
		"fin": {"g": Vector2(-0.4, -0.45), "z": 0.75, "t": Vector2(-1.1, 0.08)},
		"suivi": {"g": Vector2(-0.48, -0.52), "z": 0.8, "t": Vector2(-1.1, -0.15)},
		"acceleration": 2.6,
	},
	# finisher au sol (coup de grâce) : épée levée haut, abattue verticalement à travers le centre sur le corps à terre
	"finisher_sol": {
		"armer": {"g": Vector2(0.25, 0.02), "z": 0.73, "t": Vector2(0.02, 1.15)},
		"milieu": {"g": Vector2(0.14, -0.24), "z": 0.64, "t": Vector2(-0.68, 0.1)},
		"fin": {"g": Vector2(0.06, -0.74), "z": 0.55, "t": Vector2(-0.85, -0.02)},
		"suivi": {"g": Vector2(0.03, -0.8), "z": 0.55, "t": Vector2(-0.78, -0.06)},
		"acceleration": 2.2,
	},
}

## Poses tenues [poignée, lame, tranchant]. Garde : épée EN TRAVERS devant la poitrine (poing bas à droite, pointe à gauche
## un peu plus haute, tranchant vers l'ennemi), assez basse pour laisser le centre de l'écran libre.
const POSES := {
	"garde": [Vector3(0.22, -0.22, -0.42), Vector3(-0.78, 0.5, -0.36), Vector3(0.0, 0.35, -1.0)],
	# coup bloqué : la lame recule vers le joueur et remonte sous le choc
	"encaisse": [Vector3(0.24, -0.18, -0.36), Vector3(-0.76, 0.58, -0.25), Vector3(0.0, 0.4, -1.0)],
	# parade parfaite : la lame chasse l'arme ennemie vers l'extérieur et le haut (bref coup de poignet)
	"parade": [Vector3(0.25, -0.14, -0.42), Vector3(-0.55, 0.78, -0.3), Vector3(0.1, 0.35, -1.0)],
	# garde brisée : l'épée est rabattue en bas à droite, pointe vers le sol devant
	"garde_brisee": [Vector3(0.32, -0.42, -0.3), Vector3(-0.32, 0.22, -0.92), Vector3(-0.9, 0.0, -0.4)],
}

## Finishers : durées (s, temps de jeu ; ralenti léger en plus) — élan, coup, suivi. Total ≤ 0,8 s.
const FINISHER := {"elan": 0.26, "coup": 0.12, "suivi": 0.34}
## Échelle de temps pendant l'élan du finisher (ralenti léger ; le profil d'impact « finisher » ajoute le sien à l'impact).
const FINISHER_RALENTI := 0.7
## Vitesse de verrouillage de la caméra sur la cible (1/s) et part de la séquence pendant laquelle il dure (élan + coup).
const FINISHER_VERROU := 14.0

static var _cache := {}

## Geste résolu (clés écran → [poignée, lame, pôle]) au format de ProfilsAnimation.pose_cle / pose_active.
static func geste(nom: String) -> Dictionary:
	if not _cache.has(nom):
		var r: Dictionary = GESTES[nom].duplicate()
		for k in ProfilsAnimation.CLES:
			r[k] = ProfilsAnimation.cle_ecran(r[k])
		_cache[nom] = r
	return _cache[nom]

static func pose(nom: String) -> Transform3D:
	return ProfilsAnimation.transform_pose(POSES[nom])

## Geste de finisher selon la catégorie de CombatEnnemi.finisher_possible.
static func geste_finisher(categorie: String) -> String:
	return "finisher_sol" if categorie == "sol" else "finisher_taille"
