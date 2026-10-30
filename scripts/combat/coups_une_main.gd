class_name CoupsUneMain
## Coups à UNE MAIN ajoutés au lot coups_v5 (2026-10-30), à part de ProfilsAnimation pour que la fusion avec les coups à deux
## mains (combat/claymore_2mains) reste simple. ProfilsAnimation.geste() cherche ici un geste absent du profil.
## Combo de l'épée longue (4 coups, au rythme des clics : un clic dans la fenêtre « enchainement » du coup précédent
## enchaîne le suivant, sinon on repart au coup 1) :
##   1 diag_dg     diagonale descendante haut-droite → bas-gauche   (Mixamo « Sword And Shield Slash (1) »)
##   2 revers_gd   revers horizontal gauche → droite, lame à plat    (Mixamo « Sword And Shield Slash (2) »)
##   3 taille_dg   taille HORIZONTALE droite → gauche (NOUVEAU)      (Quaternius UAL2 « Sword_Regular_Combo », CC0)
##   4 estoc_combo estoc, le plus fort                               (Mixamo « Stabbing »)
## Le coup puissant (clic maintenu) reste celui de coups_v4 (ProfilsAnimation, « lourd » / « lourds »).
## Clips : sources_blender/scripts/gestes_une_main.py (retarget anim_bras_epee.py → assets/animations/bras_epee.tres).

const COMBO := ["diag_dg", "revers_gd", "taille_dg", "estoc_combo"]

const GESTES := {
	# coup 3 : repart de la fin du revers (à droite), poing haut à droite, la lame balaie à plat à hauteur de poitrine jusqu'à
	# gauche (le combo repart ensuite du centre avec l'estoc)
	"taille_dg": {"clip": "coup_t", "fenetre": [0.0, 1.0], "cotes": [1, -1], "enchainement": [0.04, 1.0], "force": 1.1, "elan": 0.35},
}
