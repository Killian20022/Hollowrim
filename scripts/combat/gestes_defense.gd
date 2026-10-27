class_name GestesDefense
## Gestes de la phase 3 (contre-attaque, finishers) et clips de défense (garde, encaisse, parade, garde brisée) en vue FPS,
## À PART des profils d'attaque : mêmes CLIPS À IMAGES CLÉS du bras droit (AnimateurBras, poses dans
## sources_blender/scripts/gestes_bras_epee.py). Garde : épée en travers devant, pointe vers la gauche (Skyrim) ; parade
## parfaite = petit choc de la garde (clip « parade ») ; coup bloqué = « encaisse » ; garde brisée = « garde_brisee ».

const GESTES := {
	# contre-attaque après une parade parfaite : la lame part de la garde, monte à gauche et fend en grande diagonale
	# jusqu'en bas à droite, plus ample et plus rapide qu'un coup léger (préparation courte : l'épée est déjà levée)
	"contre": {"clip": "contre", "fenetre": [0.0, 1.0], "cotes": [-1, 1], "enchainement": [0.08, 0.8], "force": 1.4, "tassement": 0.6},
	# finisher de taille (décapitation) : élan à droite, coupe HORIZONTALE qui traverse le centre de l'écran — là où la
	# caméra verrouillée a mis le cou de la cible — et finit à gauche
	"finisher_taille": {"clip": "finisher_taille"},
	# finisher au sol (coup de grâce) : épée levée haut, abattue verticalement à travers le centre sur le corps à terre
	"finisher_sol": {"clip": "finisher_sol"},
}

## Pose tenue → [clip, temps] (outils, tests) ; pose(nom) la calcule si les bras du joueur sont chargés.
const POSES := {"garde": ["garde", 0.0], "encaisse": ["encaisse", 0.05], "parade": ["parade", 0.04], "garde_brisee": ["garde_brisee", 0.12]}

## Finishers : durées (s, temps de jeu ; ralenti léger en plus) — élan, coup, suivi. Total ≤ 0,8 s. Le clip suit les
## mêmes instants (marqueurs frappe = 0,26, fin_frappe = 0,38, fin = 0,72).
const FINISHER := {"elan": 0.26, "coup": 0.12, "suivi": 0.34}
## Échelle de temps pendant l'élan du finisher (ralenti léger ; le profil d'impact « finisher » ajoute le sien à l'impact).
const FINISHER_RALENTI := 0.7
## Vitesse de verrouillage de la caméra sur la cible (1/s) et part de la séquence pendant laquelle il dure (élan + coup).
const FINISHER_VERROU := 14.0

## Animateur des bras du joueur (posé par mains.gd) : sert à pose().
static var animateur: AnimateurBras

static func geste(nom: String) -> Dictionary:
	return GESTES[nom]

## Pose de l'épée (repère des mains) d'une pose de défense, lue dans son clip.
static func pose(nom: String) -> Transform3D:
	if animateur == null:
		return Transform3D()
	var c: Array = POSES[nom]
	return animateur.pose_arme(c[0], c[1])

## Geste de finisher selon la catégorie de CombatEnnemi.finisher_possible.
static func geste_finisher(categorie: String) -> String:
	return "finisher_sol" if categorie == "sol" else "finisher_taille"
