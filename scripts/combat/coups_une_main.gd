class_name CoupsUneMain
## Coups à UNE MAIN ajoutés au lot coups_v5 (2026-10-30), à part de ProfilsAnimation pour que la fusion avec les coups à deux
## mains (combat/claymore_2mains) reste simple. ProfilsAnimation.geste() cherche ici un geste absent du profil.
## Combo de l'épée longue (4 coups, au rythme des clics : un clic dans la fenêtre « enchainement » du coup précédent
## enchaîne le suivant, sinon on repart au coup 1) :
##   1 diag_dg     diagonale descendante haut-droite → bas-gauche   (Mixamo « Sword And Shield Slash (1) »)
##   2 revers_gd   revers horizontal gauche → droite, lame à plat    (Mixamo « Sword And Shield Slash (2) »)
##   3 taille_dg   taille HORIZONTALE droite → gauche               (Quaternius UAL2 « Sword_Regular_Combo », CC0)
##   4 estoc_combo estoc, le plus fort                               (Mixamo « Stabbing »)
## COUPS V6 (2026-10-30, retour utilisateur : « le poignet qui se casse et pas de mouvement d'épée fluide ») : les MÊMES 4
## coups (mêmes captures, mêmes règles de jeu), clips « <clip>6 » : poignet verrouillé autour de la tenue (l'épée prolonge
## l'avant-bras, la torsion passe dans l'avant-bras), frappe ramenée sur un arc de cercle propre autour de l'épaule (vitesse
## angulaire constante), léger creux de poids au milieu de la frappe (sources_blender/scripts/gestes_une_main.py, « coups v6 »).
## COMBO = v6 ; COMBO_V5 garde les gestes v5 (clips intacts) pour comparaison.
## Le coup puissant (clic maintenu) reste celui de coups_v4 (ProfilsAnimation, « lourd » / « lourds »).
## Clips : sources_blender/scripts/gestes_une_main.py (retarget anim_bras_epee.py → assets/animations/bras_epee.tres).

const COMBO := ["diag_dg6", "revers_gd6", "taille_dg6", "estoc_combo6"]
const COMBO_V5 := ["diag_dg", "revers_gd", "taille_dg", "estoc_combo"]

const GESTES := {
	# coup 3 : repart de la fin du revers (à droite), poing haut à droite, la lame balaie à plat à hauteur de poitrine jusqu'à
	# gauche (le combo repart ensuite du centre avec l'estoc)
	"taille_dg": {"clip": "coup_t", "fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.04, 1.0], "force": 1.1, "elan": 0.35},
	# coups v6 : mêmes règles que les gestes v5 (ProfilsAnimation « diag_dg », « revers_gd », « estoc_combo » ; « taille_dg »
	# ci-dessus), clips à poignet verrouillé et arc guidé
	"diag_dg6": {"clip": "coup_a6", "fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.04, 1.0], "force": 1.0, "elan": 0.35},
	"revers_gd6": {"clip": "coup_b6", "fenetre": [0.0, 1.0], "cotes": [0, 1], "enchainement": [0.04, 1.0], "force": 1.0, "elan": 0.3},
	"taille_dg6": {"clip": "coup_t6", "fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.04, 1.0], "force": 1.1, "elan": 0.35},
	"estoc_combo6": {"clip": "coup_c6", "fenetre": [0.25, 1.0], "cotes": [0, 0], "enchainement": [0.06, 0.8], "force": 1.25, "tassement": 0.6, "elan": 0.55},
}
