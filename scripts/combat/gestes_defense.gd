class_name GestesDefense
## Gestes et poses de la phase 3 (défense, contre-attaque, finishers) en vue FPS, À PART des profils d'attaque
## (ProfilsAnimation.PROFILS : coups légers / lourds et pose de repos, réglés sur une autre branche) : ce fichier ne
## dépend pas de leurs clés, on peut refaire les coups sans toucher à la défense et inversement.
## Même format que ProfilsAnimation : gestes à quatre clés [poignée, lame, pôle du coude, tranchant] (repère caméra :
## +X droite, +Y haut, -Z devant) jouées par ProfilsAnimation.pose_cle / pose_active ; poses tenues [poignée, lame, tranchant].
## Durées pour une arme de vitesse 1 (DonneesArme.vitesse les divise, sauf les finishers : durée fixe, ≤ 0,8 s).

const GESTES := {
	# contre-attaque après une parade parfaite : la lame part de la garde (à gauche, haute) et fend en diagonale vers le bas à
	# droite, bras tendu, plus ample et plus rapide qu'un coup léger (préparation courte : l'épée est déjà levée)
	"contre": {
		"armer": [Vector3(-0.32, 0.06, -0.26), Vector3(-0.38, 0.78, 0.5), Vector3(0.05, -0.4, 0.65), Vector3(-0.82, 0.04, -0.57)],
		"milieu": [Vector3(-0.06, -0.13, -0.56), Vector3(0.38, 0.4, -0.83), Vector3(0.05, -0.4, 0.65), Vector3(-0.93, 0.26, -0.28)],
		"fin": [Vector3(0.16, -0.4, -0.42), Vector3(0.78, -0.48, -0.4), Vector3(0.05, -0.4, 0.65), Vector3(0.01, 0.72, -0.7)],
		"suivi": [Vector3(0.24, -0.48, -0.32), Vector3(0.74, -0.32, -0.6), Vector3(0.05, -0.4, 0.65), Vector3(-0.13, 0.85, -0.51)],
		"preparation": 0.06, "tenue": 0.03, "active": 0.12, "acceleration": 2.8, "suivi_duree": 0.10, "recuperation": 0.34,
		"fenetre": [0.06, 1.0], "cotes": [-1, 1], "enchainement": [0.08, 0.8], "force": 1.4,
	},
	# finisher de taille (décapitation) : élan large derrière l'épaule droite, coupe horizontale à hauteur du cou, de droite à
	# gauche ; la caméra est verrouillée sur le cou de la cible pendant l'élan et le coup
	"finisher_taille": {
		"armer": [Vector3(0.26, -0.1, -0.2), Vector3(0.92, 0.28, 0.28), Vector3(0.05, -0.65, 0.95), Vector3(0.13, 0.16, -0.98)],
		"milieu": [Vector3(-0.06, -0.1, -0.54), Vector3(-0.04, 0.02, -1.0), Vector3(0.05, -0.65, 0.95), Vector3(-0.91, 0.42, 0.04)],
		"fin": [Vector3(-0.38, -0.14, -0.38), Vector3(-0.93, 0.05, 0.36), Vector3(0.05, -0.65, 0.95), Vector3(-0.36, 0.09, -0.93)],
		"suivi": [Vector3(-0.46, -0.2, -0.26), Vector3(-0.8, -0.05, 0.6), Vector3(0.05, -0.65, 0.95), Vector3(-0.58, 0.09, -0.81)],
		"acceleration": 2.6,
	},
	# finisher au sol (coup de grâce) : épée levée haut, abattue vers le corps à terre
	"finisher_sol": {
		"armer": [Vector3(0.24, 0.12, -0.2), Vector3(0.2, 0.5, 0.84), Vector3(0.35, 0.0, -0.4), Vector3(0.03, 0.92, -0.39)],
		"milieu": [Vector3(0.08, -0.06, -0.52), Vector3(-0.05, 0.1, -0.99), Vector3(0.05, -0.4, -0.25), Vector3(-0.22, 0.95, 0.2)],
		"fin": [Vector3(0.02, -0.44, -0.46), Vector3(-0.06, -0.7, -0.71), Vector3(0.05, -0.4, -0.25), Vector3(0.04, 0.68, -0.73)],
		"suivi": [Vector3(0.0, -0.5, -0.4), Vector3(-0.06, -0.85, -0.52), Vector3(0.05, -0.4, -0.25), Vector3(0.25, 0.27, -0.93)],
		"acceleration": 2.2,
	},
}

## Poses tenues [poignée, lame, tranchant]. Garde : épée EN TRAVERS devant la poitrine (poing bas à droite, pointe à gauche
## un peu plus haute, tranchant vers l'ennemi), assez basse pour laisser le centre de l'écran libre.
const POSES := {
	"garde": [Vector3(0.14, -0.27, -0.46), Vector3(-0.88, 0.30, -0.36), Vector3(0.0, 0.45, -1.0)],
	# coup bloqué : la lame recule vers le joueur et remonte sous le choc
	"encaisse": [Vector3(0.17, -0.22, -0.38), Vector3(-0.86, 0.44, -0.2), Vector3(0.0, 0.5, -1.0)],
	# parade parfaite : la lame chasse l'arme ennemie vers l'extérieur et le haut (bref coup de poignet)
	"parade": [Vector3(0.2, -0.17, -0.44), Vector3(-0.66, 0.68, -0.32), Vector3(0.1, 0.4, -1.0)],
	# garde brisée : l'épée est rabattue en bas à droite, pointe vers le sol devant
	"garde_brisee": [Vector3(0.32, -0.42, -0.3), Vector3(-0.32, 0.22, -0.92), Vector3(-0.9, 0.0, -0.4)],
}

## Finishers : durées (s, temps de jeu ; ralenti léger en plus) — élan, coup, suivi. Total ≤ 0,8 s.
const FINISHER := {"elan": 0.26, "coup": 0.12, "suivi": 0.34}
## Échelle de temps pendant l'élan du finisher (ralenti léger ; le profil d'impact « finisher » ajoute le sien à l'impact).
const FINISHER_RALENTI := 0.7
## Vitesse de verrouillage de la caméra sur la cible (1/s) et part de la séquence pendant laquelle il dure (élan + coup).
const FINISHER_VERROU := 14.0

static func geste(nom: String) -> Dictionary:
	return GESTES[nom]

static func pose(nom: String) -> Transform3D:
	return ProfilsAnimation.transform_pose(POSES[nom])

## Geste de finisher selon la catégorie de CombatEnnemi.finisher_possible.
static func geste_finisher(categorie: String) -> String:
	return "finisher_sol" if categorie == "sol" else "finisher_taille"
