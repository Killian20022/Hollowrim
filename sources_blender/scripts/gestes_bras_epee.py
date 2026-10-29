# Poses clés et instants des gestes FPS de l'épée (lu par anim_bras_epee.py). Repère caméra du jeu : +X droite, +Y haut,
# -Z devant (m). Une clé : t (s), poing (centre du poing ; E(x, y, z) = point vu à la position écran x, y ∈ [-1, 1] à la
# profondeur z), lame (direction voulue), roulis (pose tenue : angle du plat avec l'œil, 0 = plat face caméra, 90 =
# tranche) OU mouvement (frappe : direction du mouvement, le tranchant mène), coude (direction du coude), clav (avance°,
# monte° de l'épaule), epaule (glissement de l'épaule hors écran, m), torsion (avant-bras préféré, + supination),
# interp ("amorti" : la clé amortit ; "passe" : la lame la traverse à pleine vitesse ; "lin" : choc).
# Le solveur respecte les butées du poignet et de l'avant-bras ; le rapport POIGNET donne l'écart à la lame voulue.
# Gestes de référence : Skyrim, épée à une main (voir docs/COMBAT.md, « Coups animés à la main »).

TAN_V = 0.7265
# tenue « tranche » (retour utilisateur 2026-10-27) : plat de la lame à 75-80° de l'œil, on voit le fil, le plat en
# léger biais (~20 % de sa largeur)
TRANCHE = 78
# poses TENUES (repos, marche, sprint, garde, retours en garde) : un peu plus de plat vu (retour utilisateur 2026-10-27,
# « tourne un tout petit peu plus l'épée ») — plat à ~71° de l'œil (~32 % de sa largeur) ; les armés et frappes gardent
# TRANCHE (trajectoires inchangées)
TRANCHE_TENUE = 71
TAN_H = TAN_V * 16 / 9


def E(x, y, z):
    return (x * TAN_H * z, y * TAN_V * z, -z)


def cle(base, t, **k):
    d = dict(base)
    d.update(k)
    d["t"] = t
    return d


# --- poses tenues -----------------------------------------------------------------------------------------------------
# repos : épée DROITE (référence references/combat_epee/tenue_epee_droite_1100.jpg) — lame presque verticale à l'écran
# (pointe ~12° vers le centre), pointe en haut du cadre, garde et poing en bas à droite (x ≈ 0,5, y ≈ -0,6), tranche face
# à l'œil
REPOS = dict(nom="repos", poing=E(0.5, -0.64, 0.55), lame=(-0.1, 0.95, -0.3), roulis=TRANCHE_TENUE, coude=(1, -0.8, 0.2),
             k=52, f=-11, r=-32, phi=0)   # poignet fixé : la même pose de repos au bout de chaque clip (pas de saut au retour)
SPRINT = dict(nom="sprint", poing=E(0.72, -0.9, 0.42), lame=(-0.25, 0.4, -0.88), roulis=TRANCHE_TENUE, coude=(0.6, -1, 0.4))
# garde : épée en travers devant, pointe vers la gauche (un peu haute), tranchant vers l'ennemi, poing à droite
# (cible TRANCHE_TENUE + 4 : à 71 pile le solveur sacrifie la direction de la lame de ~15° ; à 75 elle reste à <1° et le
# plat obtenu tombe à ~71°)
GARDE = dict(nom="garde", poing=E(0.42, -0.3, 0.46), lame=(-0.88, 0.42, -0.2), roulis=TRANCHE_TENUE + 4, poids_roulis=1.5, coude=(0.5, -1, 0.1), clav=(10, 4), epaule=(-0.02, 0, -0.03))
ENCAISSE = dict(GARDE, nom="encaisse", poing=E(0.44, -0.34, 0.41), lame=(-0.86, 0.5, -0.1))
PARADE = dict(GARDE, nom="parade", poing=E(0.48, -0.3, 0.45), lame=(-0.62, 0.74, -0.25))
BRISEE = dict(nom="brisee", poing=E(0.66, -0.95, 0.42), lame=(-0.3, 0.25, -0.92), roulis=TRANCHE_TENUE, coude=(0.7, -1, 0.3))

# --- coup léger A : diagonale haut-droite -> bas-gauche ------------------------------------------------------------
A_ARME = dict(nom="A_arme", poing=E(0.62, 0.0, 0.5), lame=(0.4, 0.8, -0.4), roulis=TRANCHE, coude=(1, -0.5, 0.3), clav=(0, 8))
A_TENSION = dict(A_ARME, nom="A_tension", poing=E(0.66, 0.05, 0.49), lame=(0.45, 0.75, -0.4))
A_ENTREE = dict(nom="A_entree", poing=E(0.45, -0.08, 0.55), lame=(-0.25, 0.8, -0.5), mouvement=(-0.7, -0.6, 0), coude=(1, -0.6, 0.2), clav=(10, 6), epaule=(-0.01, 0.0, -0.02), interp="passe")
A_MILIEU = dict(nom="A_milieu", poing=E(0.2, -0.28, 0.58), lame=(-0.85, 0.3, -0.4), mouvement=(-0.4, -0.9, 0), coude=(0.6, -1, 0.0), clav=(18, 4), epaule=(-0.04, 0.0, -0.05), interp="passe")
A_FIN = dict(nom="A_fin", poing=E(-0.15, -0.5, 0.56), lame=(-0.75, -0.45, -0.4), mouvement=(-0.6, -0.6, 0.2), coude=(0.3, -1, -0.2), clav=(28, 0), epaule=(-0.10, 0.02, -0.10))
A_SUIVI = dict(A_FIN, nom="A_suivi", poing=E(-0.25, -0.58, 0.55), lame=(-0.65, -0.6, -0.4), clav=(30, -2), epaule=(-0.11, 0.02, -0.11))

# --- coup léger B : revers gauche -> droite, légèrement montant (repart de la fin de A) -------------------------------
B_ARME = dict(nom="B_arme", poing=E(-0.32, -0.5, 0.55), lame=(-0.85, 0.45, -0.2), mouvement=(1, 0.2, 0), coude=(0.3, -1, -0.2), clav=(30, 0), epaule=(-0.11, 0.02, -0.11))
B_TENSION = dict(B_ARME, nom="B_tension", poing=E(-0.36, -0.52, 0.54), lame=(-0.9, 0.35, -0.2))
B_MILIEU = dict(nom="B_milieu", poing=E(0.1, -0.35, 0.6), lame=(0.35, 0.25, -0.9), mouvement=(1, 0.25, 0), coude=(0.5, -1, -0.1), clav=(18, 2), epaule=(-0.05, 0.01, -0.06), interp="passe")
B_FIN = dict(nom="B_fin", poing=E(0.45, -0.35, 0.58), lame=(0.85, 0.2, -0.45), mouvement=(0.8, 0.3, 0.3), coude=(1, -1, 0.2), clav=(8, 4), epaule=(-0.02, 0.0, -0.03))
B_SUIVI = dict(B_FIN, nom="B_suivi", poing=E(0.55, -0.38, 0.56), lame=(0.88, 0.1, -0.4), mouvement=(0.6, 0.1, 0.5))

# --- coup léger C : vertical par-dessus (épée levée au-dessus de la tête, descend à travers le centre) ----------------
C_ARME = dict(nom="C_arme", poing=E(0.6, 0.3, 0.56), lame=(-0.3, 0.9, 0.05), roulis=TRANCHE, coude=(1, -0.6, 0.0), clav=(0, 12), epaule=(0, 0.05, 0.0))
C_TENSION = dict(C_ARME, nom="C_tension", poing=E(0.62, 0.36, 0.55), lame=(-0.25, 0.92, 0.12))
C_ENTREE = dict(nom="C_entree", poing=E(0.35, 0.22, 0.55), lame=(-0.6, 0.5, -0.6), mouvement=(-0.1, -1, -0.3), coude=(0.8, -1, 0.0), clav=(8, 16), epaule=(-0.02, 0.04, -0.04), interp="passe")
C_MILIEU = dict(nom="C_milieu", poing=E(0.2, -0.1, 0.6), lame=(-0.75, 0.1, -0.65), mouvement=(-0.1, -1, 0), coude=(0.6, -1, 0.0), clav=(16, 8), epaule=(-0.04, 0.02, -0.07), interp="passe")
C_FIN = dict(nom="C_fin", poing=E(0.08, -0.45, 0.58), lame=(-0.15, -0.55, -0.8), mouvement=(-0.1, -0.8, 0.4), coude=(0.4, -1, 0.0), clav=(22, 0), epaule=(-0.07, 0.0, -0.09))
C_SUIVI = dict(C_FIN, nom="C_suivi", poing=E(0.04, -0.55, 0.56), lame=(-0.1, -0.75, -0.6), mouvement=(-0.2, -0.6, 0.7))

# --- horizontal léger droite -> gauche (pas de côté vers la gauche) ---------------------------------------------------
H_ARME = dict(nom="H_arme", poing=E(0.7, -0.15, 0.5), lame=(-0.15, 0.0, -0.98), roulis=TRANCHE, coude=(1, -0.6, 0.3), clav=(-2, 6), torsion=-80)
H_TENSION = dict(H_ARME, nom="H_tension", poing=E(0.74, -0.13, 0.49), lame=(-0.1, 0.05, -0.99))
H_ENTREE = dict(nom="H_entree", poing=E(0.5, -0.18, 0.56), lame=(-0.4, 0.0, -0.9), mouvement=(-1, 0, 0), coude=(0.8, -1, 0.2), clav=(8, 4), epaule=(-0.02, 0.0, -0.03), interp="passe", torsion=-80)
H_MILIEU = dict(nom="H_milieu", poing=E(0.2, -0.2, 0.58), lame=(-0.85, 0.05, -0.5), mouvement=(-1, 0, 0), coude=(0.6, -1, 0.0), clav=(18, 2), epaule=(-0.04, 0.0, -0.05), interp="passe", torsion=-80)
H_FIN = dict(nom="H_fin", poing=E(-0.2, -0.3, 0.56), lame=(-0.95, -0.1, -0.2), mouvement=(-0.8, 0, 0.4), coude=(0.3, -1, -0.2), clav=(28, 0), epaule=(-0.10, 0.02, -0.10), torsion=-80)
H_SUIVI = dict(H_FIN, nom="H_suivi", poing=E(-0.3, -0.38, 0.55), lame=(-0.85, -0.2, -0.1), torsion=-80)

# --- coup léger B du combo : horizontal droite -> gauche à hauteur de poitrine (repart de la fin de A, en bas à gauche :
# l'épée remonte à droite en passant devant, puis balaie à plat) ------------------------------------------------------
B_RETOUR = dict(nom="B_retour", poing=E(0.3, -0.45, 0.55), lame=(-0.6, 0.5, -0.6), roulis=TRANCHE_TENUE, coude=(0.6, -1, 0.1), clav=(10, 2), epaule=(-0.04, 0.0, -0.05), torsion=-80)

# --- diagonale revers haut-gauche -> bas-droite (miroir de A dans un enchaînement ; base de la contre-attaque) -------
R_ARME = dict(nom="R_arme", poing=E(-0.25, 0.0, 0.5), lame=(-0.6, 0.6, -0.5), mouvement=(0.6, -0.7, 0), coude=(0.3, -1, -0.4), clav=(28, 10), epaule=(-0.10, 0.03, -0.09))
R_TENSION = dict(R_ARME, nom="R_tension", poing=E(-0.3, 0.04, 0.49), lame=(-0.65, 0.55, -0.5))
R_MILIEU = dict(nom="R_milieu", poing=E(0.12, -0.3, 0.6), lame=(0.55, 0.35, -0.75), mouvement=(0.6, -0.8, 0), coude=(0.5, -1, -0.1), clav=(16, 4), epaule=(-0.04, 0.01, -0.05), interp="passe")
R_FIN = dict(nom="R_fin", poing=E(0.48, -0.5, 0.55), lame=(0.85, 0.0, -0.5), mouvement=(0.6, -0.5, 0.3), coude=(1, -1, 0.2), clav=(6, 0))
R_SUIVI = dict(R_FIN, nom="R_suivi", poing=E(0.56, -0.58, 0.53), lame=(0.85, -0.15, -0.5))

# --- estoc (en reculant) : le poing part de la hanche droite et pique vers le centre ----------------------------------
E_ARME = dict(nom="E_arme", poing=E(0.62, -0.72, 0.36), lame=(-0.45, 0.4, -0.8), roulis=TRANCHE, coude=(0.8, -1, 0.5), clav=(-6, 0))
E_FIN = dict(nom="E_fin", poing=E(0.2, -0.4, 0.6), lame=(-0.55, 0.45, -0.7), roulis=TRANCHE, coude=(0.6, -1, 0.1), clav=(20, 2), epaule=(-0.05, 0.0, -0.08))
E_SUIVI = dict(E_FIN, nom="E_suivi", poing=E(0.18, -0.38, 0.62), epaule=(-0.05, 0.0, -0.09))

# --- attaques puissantes ----------------------------------------------------------------------------------------------
# à l'arrêt : armé large derrière l'épaule droite, grand balayage horizontal droite -> gauche
P_ARME = dict(nom="P_arme", poing=E(0.85, -0.12, 0.48), lame=(-0.05, 0.05, -1), roulis=TRANCHE, coude=(1, -0.5, 0.4), clav=(-10, 6), epaule=(0.02, 0.0, 0.01), torsion=-80)
P_TENSION = dict(P_ARME, nom="P_tension", poing=E(0.9, -0.1, 0.47), lame=(0.0, 0.05, -1))
P_ENTREE = dict(nom="P_entree", poing=E(0.55, -0.18, 0.55), lame=(-0.4, 0.0, -0.9), mouvement=(-1, -0.15, 0), coude=(1, -0.7, 0.3), clav=(6, 6), interp="passe", torsion=-80)
P_MILIEU = dict(nom="P_milieu", poing=E(0.15, -0.22, 0.6), lame=(-0.85, 0.1, -0.5), mouvement=(-1, -0.15, 0), coude=(0.6, -1, 0.0), clav=(20, 2), epaule=(-0.05, 0.0, -0.06), interp="passe", torsion=-80)
P_FIN = dict(nom="P_fin", poing=E(-0.25, -0.35, 0.56), lame=(-0.9, -0.15, -0.25), mouvement=(-0.8, -0.3, 0.4), coude=(0.3, -1, -0.2), clav=(30, 0), epaule=(-0.12, 0.02, -0.11), torsion=-80)
P_SUIVI = dict(P_FIN, nom="P_suivi", poing=E(-0.35, -0.45, 0.55), lame=(-0.8, -0.35, -0.2))
# en avançant : vertical puissant par-dessus
V_ARME = dict(C_ARME, nom="V_arme", poing=E(0.62, 0.4, 0.52), clav=(-4, 16), epaule=(0, 0.06, 0.0))
V_TENSION = dict(V_ARME, nom="V_tension", poing=E(0.62, 0.48, 0.51), lame=(-0.05, 0.9, 0.1))
# de côté vers la droite : balayage gauche -> droite (armé à gauche)
G_ARME = dict(nom="G_arme", poing=E(-0.34, -0.42, 0.52), lame=(-0.85, 0.45, -0.2), mouvement=(1, 0, 0), coude=(0.3, -1, -0.3), clav=(30, 4), epaule=(-0.12, 0.02, -0.10))
G_TENSION = dict(G_ARME, nom="G_tension", poing=E(-0.4, -0.44, 0.51), lame=(-0.9, 0.35, -0.2))
G_MILIEU = dict(nom="G_milieu", poing=E(0.1, -0.35, 0.6), lame=(0.35, 0.25, -0.9), mouvement=(1, 0.1, 0), coude=(0.5, -1, -0.1), clav=(18, 2), epaule=(-0.05, 0.01, -0.06), interp="passe")
G_FIN = dict(nom="G_fin", poing=E(0.5, -0.35, 0.57), lame=(0.85, 0.2, -0.45), mouvement=(0.8, 0.2, 0.4), coude=(1, -1, 0.2), clav=(6, 4))
G_SUIVI = dict(G_FIN, nom="G_suivi", poing=E(0.62, -0.4, 0.55), lame=(0.88, 0.1, -0.4))
# en reculant : coup de pommeau (le poing frappe vers l'avant, pommeau en tête, lame dressée)
Q_ARME = dict(nom="Q_arme", poing=E(0.55, -0.55, 0.3), lame=(0.2, 0.8, 0.55), roulis=TRANCHE, coude=(0.8, -1, 0.6), clav=(-8, 0))
Q_TENSION = dict(Q_ARME, nom="Q_tension", poing=E(0.6, -0.6, 0.29))
Q_FIN = dict(nom="Q_fin", poing=E(0.12, -0.25, 0.6), lame=(-0.35, 0.85, 0.35), roulis=TRANCHE, coude=(0.5, -1, 0.0), clav=(22, 4), epaule=(-0.06, 0.0, -0.10))
Q_SUIVI = dict(Q_FIN, nom="Q_suivi", poing=E(0.1, -0.24, 0.62), epaule=(-0.06, 0.0, -0.11))

# --- contre-attaque (depuis la garde) ----------------------------------------------------------------------------------
C_PRE = dict(nom="C_pre", poing=E(0.5, 0.0, 0.55), lame=(0.1, 0.95, -0.2), roulis=TRANCHE, coude=(0.8, -1, 0.0), clav=(0, 10))
K_ARME = dict(R_ARME, nom="K_arme", poing=E(-0.24, 0.18, 0.42))


# =====================================================================================================================
# COMBO REFAIT (retour utilisateur 2026-10-27 : « un vrai coup en diagonale, un autre de gauche à droite, le dernier un
# pointé ») — clés « large » : butées du poignet levées (anim_bras_epee.LIM_*_L), l'épaule (clav, epaule) porte l'ampleur.
# --- 1 : VRAIE diagonale, épée levée au-dessus de l'épaule droite, fend haut-droite -> bas-gauche à travers le centre ---
# armé (2026-10-27, combat/vertical) : même poing, lame penchée VERS L'AVANT (z -0,45 au lieu de +0,12) : la pointe reste
# sous le bord haut (1re image de la frappe : 28 % -> 84 % de lame dans le cadre), trajectoire de la frappe inchangée
D_ARME = dict(nom="D_arme", poing=E(0.78, 0.40, 0.58), lame=(-0.60, 0.62, -0.45), roulis=TRANCHE, coude=(1, -0.3, 0.3), clav=(-4, 14), epaule=(0.03, 0.07, 0.0), large=1, torsion=30, poids_torsion=0.15)
D_TENSION = dict(D_ARME, nom="D_tension", poing=E(0.82, 0.46, 0.57), lame=(-0.56, 0.66, -0.42))
D_ENTREE = dict(nom="D_entree", poing=E(0.52, 0.22, 0.64), lame=(-0.62, 0.62, -0.45), mouvement=(-0.7, -0.7, 0), coude=(1, -0.5, 0.2), clav=(6, 12), epaule=(-0.01, 0.03, -0.02), interp="passe", large=1, torsion=-10, poids_torsion=0.15)
D_MILIEU = dict(nom="D_milieu", poing=E(0.12, -0.10, 0.60), lame=(-0.62, 0.45, -0.65), mouvement=(-0.7, -0.72, 0), coude=(0.6, -1, 0.0), clav=(18, 6), epaule=(-0.05, 0.01, -0.06), interp="passe", large=1, torsion=-60, poids_torsion=0.15)
D_FIN = dict(nom="D_fin", poing=E(-0.26, -0.50, 0.58), lame=(-0.70, 0.05, -0.71), mouvement=(-0.6, -0.7, 0.3), coude=(0.3, -1, -0.2), clav=(30, 0), epaule=(-0.12, 0.0, -0.11), large=1, torsion=-95, poids_torsion=0.15)
D_SUIVI = dict(D_FIN, nom="D_suivi", poing=E(-0.32, -0.60, 0.56), lame=(-0.66, -0.18, -0.72), clav=(32, -2), epaule=(-0.13, 0.0, -0.12))

# --- 2 : HORIZONTAL GAUCHE -> DROITE (revers) : repart de la fin de 1 (bas gauche), armé à gauche à hauteur de poitrine,
# lame à plat (normale du plat verticale), balaie vers la droite ---------------------------------------------------------
# armé (2026-10-27, combat/vertical) : poing un peu moins loin à gauche (-0,40 -> -0,30) : la lame (qui ne peut pas
# pointer plus vers l'avant, butée de pronation) sortait du cadre par la gauche (1re image de la frappe : 28 %)
HG_ARME = dict(nom="HG_arme", poing=E(-0.30, -0.22, 0.55), lame=(-0.85, 0.04, -0.52), mouvement=(1, 0, 0), normale=(0, 1, 0), coude=(0.3, -1, -0.3), clav=(32, 4), epaule=(-0.13, 0.02, -0.11), large=1, torsion=-95, poids_torsion=0.4)
HG_TENSION = dict(HG_ARME, nom="HG_tension", poing=E(-0.28, -0.21, 0.56), lame=(-0.88, 0.04, -0.46))
HG_ENTREE = dict(nom="HG_entree", poing=E(-0.14, -0.22, 0.58), lame=(-0.80, 0.03, -0.60), mouvement=(1, 0, 0), normale=(0, 1, 0), coude=(0.4, -1, -0.2), clav=(24, 3), epaule=(-0.09, 0.01, -0.09), interp="passe", large=1, torsion=-90, poids_torsion=0.4)
HG_MILIEU = dict(nom="HG_milieu", poing=E(0.16, -0.22, 0.60), lame=(-0.62, 0.03, -0.78), mouvement=(1, 0, 0), normale=(0, 1, 0), coude=(0.6, -1, 0.0), clav=(14, 3), epaule=(-0.04, 0.0, -0.06), interp="passe", large=1, torsion=-90, poids_torsion=0.4)
HG_FIN = dict(nom="HG_fin", poing=E(0.52, -0.22, 0.57), lame=(-0.38, 0.04, -0.92), mouvement=(1, 0, 0.3), normale=(0, 1, 0), coude=(1, -1, 0.2), clav=(4, 4), epaule=(0.0, 0.0, -0.02), large=1, torsion=-90, poids_torsion=0.4)
HG_SUIVI = dict(HG_FIN, nom="HG_suivi", poing=E(0.62, -0.28, 0.54), lame=(-0.25, 0.04, -0.97), mouvement=(0.6, 0, 0.6), torsion=-90)

# --- FINISHERS ---------------------------------------------------------------------------------------------------------
# épée plantée : le poing recule à la hanche droite (pointe vers le torse, au centre), estoc profond, la lame RESTE dans
# le corps (le poing pousse encore, puis tourne la lame dans la plaie), retrait net vers la hanche
FP_ARME = dict(nom="FP_arme", poing=E(0.64, -0.70, 0.44), lame=(-0.31, 0.18, -0.93), roulis=TRANCHE, coude=(0.8, -1, 0.5), clav=(-8, 0), large=1)
FP_TENSION = dict(FP_ARME, nom="FP_tension", poing=E(0.68, -0.74, 0.41))
FP_DEDANS = dict(nom="FP_dedans", poing=E(0.36, -0.52, 0.62), lame=(-0.31, 0.16, -0.94), roulis=TRANCHE, coude=(0.6, -1, 0.1), clav=(22, 2), epaule=(-0.05, 0.0, -0.09), large=1)
FP_ENFONCE = dict(FP_DEDANS, nom="FP_enfonce", poing=E(0.33, -0.50, 0.66), epaule=(-0.05, 0.0, -0.11))
FP_TOURNE = dict(FP_ENFONCE, nom="FP_tourne", roulis=48)
FP_RETRAIT = dict(FP_ARME, nom="FP_retrait", poing=E(0.62, -0.68, 0.42))
# coup de grâce au sol (caméra baissée sur le corps) : poing levé en haut à droite, lame plongée à travers le centre
FS_ARME = dict(nom="FS_arme", poing=E(0.40, 0.30, 0.40), lame=(-0.18, 0.05, -0.98), roulis=TRANCHE, coude=(1, -0.6, 0.3), clav=(0, 14), epaule=(0.0, 0.06, 0.02), large=1)
FS_TENSION = dict(FS_ARME, nom="FS_tension", poing=E(0.42, 0.36, 0.38))
FS_DEDANS = dict(FP_DEDANS, nom="FS_dedans", poing=E(0.30, -0.42, 0.62), lame=(-0.26, 0.14, -0.95))
FS_ENFONCE = dict(FS_DEDANS, nom="FS_enfonce", poing=E(0.28, -0.44, 0.66), epaule=(-0.05, -0.02, -0.11))
FS_RETRAIT = dict(FS_ARME, nom="FS_retrait", poing=E(0.40, 0.18, 0.42))

# --- VERTICAL refait (2026-10-27, directionnel : souris tirée vers le bas, en avançant) : épée levée AU-DESSUS de la
# tête (poing haut, près du centre), la lame descend droit à travers le centre, tranche face à l'œil (plat de côté),
# finit basse devant ; l'épaule (clav, epaule) monte puis plonge, le coude passe sous le poing ---------------------------
V2_ARME = dict(nom="V2_arme", poing=E(0.32, 0.36, 0.60), lame=(-0.05, 0.75, 0.66), roulis=88, coude=(1, -0.4, 0.4), clav=(-6, 18), epaule=(0.0, 0.10, -0.06), large=1, torsion=40, poids_torsion=0.4)
V2_TENSION = dict(V2_ARME, nom="V2_tension", poing=E(0.32, 0.42, 0.58), lame=(-0.04, 0.70, 0.71))
V2_ENTREE = dict(nom="V2_entree", poing=E(0.22, 0.30, 0.64), lame=(-0.10, 0.90, -0.42), mouvement=(0, -1, -0.2), coude=(0.9, -0.6, 0.2), clav=(4, 14), epaule=(-0.02, 0.05, -0.03), interp="passe", large=1, torsion=70, poids_torsion=0.4)
V2_MILIEU = dict(nom="V2_milieu", poing=E(0.12, -0.05, 0.66), lame=(-0.15, 0.55, -0.82), mouvement=(0, -1, 0), coude=(0.6, -1, 0.0), clav=(16, 6), epaule=(-0.05, 0.01, -0.07), interp="passe", large=1, torsion=95, poids_torsion=0.4)
V2_FIN = dict(nom="V2_fin", poing=E(0.06, -0.50, 0.62), lame=(-0.08, -0.72, -0.69), mouvement=(0, -0.8, -0.5), coude=(0.4, -1, 0.0), clav=(24, 0), epaule=(-0.08, -0.02, -0.10), large=1, torsion=90, poids_torsion=0.4)
V2_SUIVI = dict(V2_FIN, nom="V2_suivi", poing=E(0.03, -0.62, 0.60), lame=(-0.08, -0.86, -0.50), mouvement=(0, -0.6, -0.6), clav=(26, -2), epaule=(-0.09, -0.03, -0.11), torsion=85)

# --- VERTICAL V3 (2026-10-27, combat/vertical ; clip coup_v, geste verticale_l) : V2 montrait la lame en bout pendant le
# suivi (lame pointée vers le fond, derrière le poing) et un avant-bras énorme à l'armé (poing au-dessus de la tête).
# Ici : armé court au coin haut droit, lame dressée et penchée vers l'avant (la pointe reste sous le bord haut, au-dessus
# du centre) ; la lame descend dans un plan vertical un peu à droite du centre, tranchant vers le bas (on voit la tranche) ;
# à l'impact le poignet casse (flexion), la pointe finit en bas un peu à droite du centre, AU-DESSOUS du poing (jamais
# derrière lui) ; récupération par une clé qui ramène la lame dressée à droite sans balayer l'écran.
V3_ARME = dict(nom="V3_arme", poing=E(0.57, 0.09, 0.52), lame=(-0.38, 0.72, -0.56), roulis=TRANCHE, coude=(1, -0.4, 0.3), clav=(-4, 12), epaule=(0.0, 0.05, -0.02), large=1)
V3_TENSION = dict(V3_ARME, nom="V3_tension", poing=E(0.58, 0.13, 0.51), lame=(-0.32, 0.80, -0.50), roulis=84)
V3_ENTREE = dict(nom="V3_entree", poing=E(0.46, 0.04, 0.57), lame=(-0.12, 0.30, -0.95), mouvement=(0, -0.9, -0.4), normale=(1, 0, 0.5), poids_normale=1.0, coude=(1, -0.6, 0.2), clav=(8, 10), epaule=(-0.02, 0.03, -0.04), interp="passe", large=1)
V3_MILIEU = dict(nom="V3_milieu", poing=E(0.36, -0.08, 0.62), lame=(-0.04, -0.45, -0.89), mouvement=(0, -1, 0.3), coude=(0.8, -1, 0.0), clav=(16, 6), epaule=(-0.05, 0.01, -0.07), interp="passe", large=1)
V3_FIN = dict(nom="V3_fin", poing=E(0.34, -0.14, 0.60), lame=(-0.48, -0.68, -0.55), roulis=TRANCHE, coude=(0.6, -1, 0.0), clav=(22, 0), epaule=(-0.07, -0.01, -0.09), large=1)
V3_SUIVI = dict(V3_FIN, nom="V3_suivi", poing=E(0.33, -0.16, 0.58), lame=(-0.55, -0.67, -0.48), clav=(24, -2), epaule=(-0.08, -0.02, -0.10))
V3_RETOUR = dict(nom="V3_retour", poing=E(0.36, -0.42, 0.57), lame=(-0.05, 0.12, -0.99), roulis=TRANCHE_TENUE, coude=(0.8, -1, 0.2), clav=(14, 0), epaule=(-0.05, 0.0, -0.06), large=1, torsion=-50, poids_torsion=0.2)

# --- LOURD à l'arrêt refait : armé plus loin derrière l'épaule (contre-mouvement), grande accélération, suivi qui dépasse
# loin à gauche puis RETOUR amorti en deux temps (le poids de la lame) -----------------------------------------------
P2_ARME = dict(P_ARME, nom="P2_arme", poing=E(0.92, -0.10, 0.47), lame=(0.10, 0.08, -0.99), large=1)
P2_TENSION = dict(P2_ARME, nom="P2_tension", poing=E(0.98, -0.06, 0.45), lame=(0.18, 0.10, -0.98))
P2_SUIVI = dict(P_FIN, nom="P2_suivi", poing=E(-0.42, -0.50, 0.54), lame=(-0.75, -0.42, -0.5), clav=(32, -2), epaule=(-0.13, 0.02, -0.12), large=1)
P2_RETOUR = dict(nom="P2_retour", poing=E(0.05, -0.62, 0.52), lame=(-0.45, 0.35, -0.8), roulis=TRANCHE_TENUE, coude=(0.6, -1, 0.1), clav=(16, 0), epaule=(-0.05, 0.0, -0.05), large=1)

# =====================================================================================================================
# POIGNET QUI FOUETTE (retour utilisateur 2026-10-27 ~23h25, references/combat_epee/prompt_poignet_fouet.md : « les coups
# partent en inversé ») : la main ne descend plus d'un bloc avec la lame raide (levier, pointe qui traîne) ; à l'armé le
# poignet se plie et la lame part en arrière / au-dessus, à la frappe il claque vers l'avant : la lame part du haut et
# FOUETTE en passant DEVANT la main (la pointe va plus vite que le poing et le dépasse), à l'impact la lame est en avant
# de la main dans le sens du coup. Le poing fait un trajet plus court, la lame tourne dans le plan du coup (normale du
# plat = normale du plan : le tranchant mène). Mesure : anim_bras_epee.py -- --fouet (FOUET_RESUME).
# --- 1 : diagonale haut-droite -> bas-gauche ; plan du coup de normale (1, -1, 0) -------------------------------------
N_DIAG = (0.7, -0.7, 0.0)
D4_ARME = dict(nom="D4_arme", poing=E(0.55, 0.10, 0.55), lame=(0.45, 0.65, -0.60), mouvement=(-0.7, -0.7, 0), normale=N_DIAG, poids_normale=0.3, coude=(1, -0.4, 0.3), clav=(-4, 12), epaule=(0.03, 0.06, 0.0), large=1, torsion=80, poids_torsion=0.5, k=90, f=15, r=-40, phi=45)
D4_TENSION = dict(D4_ARME, nom="D4_tension", poing=E(0.60, 0.18, 0.54), lame=(0.55, 0.62, -0.52), torsion=85, k=93, f=9, r=-40, phi=48)
D4_ENTREE = dict(nom="D4_entree", poing=E(0.48, 0.08, 0.60), lame=(0.15, 0.55, -0.82), mouvement=(-0.7, -0.7, 0), normale=N_DIAG, poids_normale=0.3, coude=(1, -0.5, 0.2), clav=(6, 10), epaule=(-0.01, 0.03, -0.02), interp="passe", large=1, torsion=30, poids_torsion=0.5, k=21, f=-20, r=-40, phi=-13)
D4_MILIEU = dict(nom="D4_milieu", poing=E(0.38, 0.02, 0.62), lame=(-0.35, -0.15, -0.92), mouvement=(-0.7, -0.7, 0), normale=N_DIAG, poids_normale=0.3, coude=(0.7, -1, 0.0), clav=(16, 6), epaule=(-0.04, 0.01, -0.06), interp="passe", large=1, torsion=-30, poids_torsion=0.5, k=-43, f=-23, r=-7, phi=-16)
D4_FIN = dict(nom="D4_fin", poing=E(0.22, -0.16, 0.60), lame=(-0.62, -0.55, -0.55), mouvement=(-0.7, -0.7, 0), normale=N_DIAG, poids_normale=0.3, coude=(0.4, -1, -0.1), clav=(26, 2), epaule=(-0.09, 0.0, -0.10), large=1, torsion=-80, poids_torsion=0.5, k=-58, f=42, r=27, phi=-14)
D4_SUIVI = dict(D4_FIN, nom="D4_suivi", poing=E(0.16, -0.24, 0.58), lame=(-0.50, -0.78, -0.38), clav=(30, -2), epaule=(-0.11, 0.0, -0.11), k=-60, f=46, r=27, phi=-14)
# --- 2 : horizontal gauche -> droite : poignet armé (lame pointée à gauche, en arrière), puis la lame fouette vers la
# droite en devançant le poing ; plat horizontal (normale verticale) -------------------------------------------------
N_HORIZ = (0.0, 1.0, 0.0)
HG4_ARME = dict(nom="HG4_arme", poing=E(-0.22, -0.22, 0.55), lame=(-0.97, 0.06, -0.20), mouvement=(1, 0, 0), normale=N_HORIZ, coude=(0.3, -1, -0.3), clav=(30, 4), epaule=(-0.12, 0.02, -0.11), large=1, torsion=-90, poids_torsion=0.6)
HG4_TENSION = dict(HG4_ARME, nom="HG4_tension", poing=E(-0.25, -0.21, 0.55), lame=(-0.99, 0.06, -0.05))
HG4_ENTREE = dict(nom="HG4_entree", poing=E(-0.10, -0.22, 0.58), lame=(-0.85, 0.04, -0.52), mouvement=(1, 0, 0), normale=N_HORIZ, coude=(0.4, -1, -0.2), clav=(24, 3), epaule=(-0.09, 0.01, -0.09), interp="passe", large=1, torsion=-90, poids_torsion=0.6)
HG4_MILIEU = dict(nom="HG4_milieu", poing=E(0.10, -0.22, 0.60), lame=(-0.55, 0.03, -0.83), mouvement=(1, 0, 0), normale=N_HORIZ, coude=(0.6, -1, 0.0), clav=(14, 3), epaule=(-0.04, 0.0, -0.06), interp="passe", large=1, torsion=-90, poids_torsion=0.6)
HG4_FIN = dict(nom="HG4_fin", poing=E(0.28, -0.22, 0.58), lame=(-0.18, 0.03, -0.98), mouvement=(1, 0, 0.3), normale=N_HORIZ, coude=(1, -1, 0.2), clav=(6, 4), epaule=(-0.01, 0.0, -0.03), large=1, torsion=-90, poids_torsion=0.6)
HG4_SUIVI = dict(HG4_FIN, nom="HG4_suivi", poing=E(0.38, -0.26, 0.55), lame=(0.0, 0.0, -1.0), clav=(2, 4), epaule=(0.0, 0.0, -0.02))
# --- lourd à l'arrêt (droite -> gauche) : armé poignet cassé (lame vers la droite, en arrière), coup sec où la lame
# fouette vers la gauche et dépasse le poing ; P_* restent ceux de finisher_taille --------------------------------------
P4_ARME = dict(nom="P4_arme", poing=E(0.72, -0.06, 0.50), lame=(0.20, 0.78, -0.59), mouvement=(-1, 0, 0), normale=N_HORIZ, poids_normale=0.3, coude=(1, -0.5, 0.4), clav=(-10, 6), epaule=(0.02, 0.0, 0.01), large=1, torsion=85, poids_torsion=0.5, k=90, f=15, r=-40, phi=45)
# charge tenue (0,6 s) : lame dressée penchée vers le centre, ENTIÈRE dans le cadre (armée vers l'arrière, poing au bord
# droit, elle sortait du cadre : 16-32 % visibles) ; au relâchement le poignet s'arme en arrière (P4_ARME) puis claque
P4_CHARGE = dict(P4_ARME, nom="P4_charge", lame=(-0.49, 0.67, -0.56), k=0, f=40, r=-40, phi=45)
P4_TENSION = dict(P4_ARME, nom="P4_tension", poing=E(0.78, -0.02, 0.48), lame=(0.32, 0.74, -0.59), torsion=90, k=95, f=5, r=-40, phi=55)
P4_ENTREE = dict(nom="P4_entree", poing=E(0.66, -0.14, 0.54), lame=(0.2, 0.3, -0.93), mouvement=(-1, -0.15, 0), normale=N_HORIZ, poids_normale=0.3, coude=(1, -0.7, 0.3), clav=(6, 6), interp="passe", large=1, torsion=30, poids_torsion=0.5, k=36, f=23, r=-40, phi=-33)
P4_MILIEU = dict(nom="P4_milieu", poing=E(0.40, -0.20, 0.60), lame=(-0.55, 0.0, -0.83), mouvement=(-1, -0.15, 0), normale=N_HORIZ, poids_normale=0.3, coude=(0.6, -1, 0.0), clav=(20, 2), epaule=(-0.05, 0.0, -0.06), interp="passe", large=1, torsion=-40, poids_torsion=0.5, k=-33, f=21, r=-14, phi=-14)
P4_FIN = dict(nom="P4_fin", poing=E(0.10, -0.30, 0.57), lame=(-0.93, -0.12, -0.34), mouvement=(-0.8, -0.3, 0.4), normale=N_HORIZ, poids_normale=0.3, coude=(0.3, -1, -0.2), clav=(30, 0), epaule=(-0.12, 0.02, -0.11), large=1, torsion=-80, poids_torsion=0.5, k=-93, f=9, r=10, phi=-1)
P4_SUIVI = dict(P2_SUIVI, nom="P4_suivi", k=-95, f=66, r=-40, phi=-15)

# --- garde : réaction de l'épée au contact (coup bloqué : la lame est repoussée, rebondit, se replace — résistance) ----
ENCAISSE2 = dict(GARDE, nom="encaisse2", poing=E(0.48, -0.40, 0.38), lame=(-0.80, 0.58, 0.05))
ENC_REBOND = dict(GARDE, nom="enc_rebond", poing=E(0.41, -0.28, 0.48), lame=(-0.90, 0.38, -0.22))
PARADE2 = dict(GARDE, nom="parade2", poing=E(0.52, -0.26, 0.47), lame=(-0.50, 0.82, -0.28))
PAR_REBOND = dict(GARDE, nom="par_rebond", poing=E(0.40, -0.31, 0.46), lame=(-0.92, 0.36, -0.15))


CLIPS = {
    "repos": [cle(REPOS, 0.0), cle(REPOS, 0.5)],
    "sprint": [cle(SPRINT, 0.0), cle(SPRINT, 0.5)],
    "garde": [cle(GARDE, 0.0), cle(GARDE, 0.5)],
    # coup bloqué : choc (lame repoussée vers l'œil, poing qui recule), rebond qui dépasse, replacement amorti
    "encaisse": [cle(GARDE, 0.0), cle(ENCAISSE2, 0.04, interp="lin"), cle(ENCAISSE, 0.08), cle(ENC_REBOND, 0.15), cle(GARDE, 0.26)],
    # parade parfaite : la lame chasse l'arme adverse vers le haut-dehors, revient avec un léger dépassement
    "parade": [cle(GARDE, 0.0), cle(PARADE2, 0.035, interp="lin"), cle(PARADE, 0.08), cle(PAR_REBOND, 0.13), cle(GARDE, 0.22)],
    "garde_brisee": [cle(GARDE, 0.0), cle(BRISEE, 0.035, interp="lin"), cle(BRISEE, 0.22), cle(REPOS, 0.45)],
    # combo 2026-10-27 : 1 diagonale (coup_a), 2 horizontal gauche -> droite (coup_b), 3 estoc (coup_c)
    # poignet qui fouette (2026-10-27, combat/poignet_fouet) : mêmes instants (latence et marqueurs inchangés)
    # coup_a, coup_b, charge_lourd, lourd : capture Mixamo retargetée (CLIPS_MIXAMO plus bas, 2026-10-29) ; l'estoc du
    # combo reste à la main (aucun estoc dans les fichiers Mixamo fournis)
    # estoc fait main (avant « Stabbing » Mixamo), gardé pour comparaison
    "coup_c_main": [cle(REPOS, 0.0), cle(E_ARME, 0.11), cle(E_ARME, 0.15), cle(E_FIN, 0.25), cle(E_SUIVI, 0.30), cle(REPOS, 0.50)],
    # poignet qui fouette (2026-10-27, combat/poignet_fouet, poignet hors butées) : gardé pour comparaison
    "coup_a_fouet": [cle(REPOS, 0.0), cle(D4_ARME, 0.13), cle(D4_TENSION, 0.16), cle(D4_ENTREE, 0.185), cle(D4_MILIEU, 0.21),
               cle(D4_FIN, 0.26), cle(D4_SUIVI, 0.33), cle(V3_RETOUR, 0.44), cle(REPOS, 0.54)],
    "coup_b_fouet": [cle(D4_SUIVI, 0.0), cle(HG4_ARME, 0.10), cle(HG4_TENSION, 0.13), cle(HG4_ENTREE, 0.155), cle(HG4_MILIEU, 0.18),
               cle(HG4_FIN, 0.23), cle(HG4_SUIVI, 0.30), cle(REPOS, 0.50)],
    # combo « levier » d'avant le poignet qui fouette (main qui descend d'un bloc, lame raide) : gardé pour comparaison
    "coup_a_levier": [cle(REPOS, 0.0), cle(D_ARME, 0.13), cle(D_TENSION, 0.16), cle(D_ENTREE, 0.185), cle(D_MILIEU, 0.21),
               cle(D_FIN, 0.26), cle(D_SUIVI, 0.33), cle(REPOS, 0.54)],
    "coup_b_levier": [cle(D_SUIVI, 0.0), cle(HG_ARME, 0.10), cle(HG_TENSION, 0.13), cle(HG_ENTREE, 0.155), cle(HG_MILIEU, 0.18),
               cle(HG_FIN, 0.23), cle(HG_SUIVI, 0.30), cle(REPOS, 0.50)],
    "lourd_levier": [cle(P2_ARME, 0.0), cle(P2_TENSION, 0.10), cle(P_ENTREE, 0.165), cle(P_MILIEU, 0.20), cle(P_FIN, 0.25),
              cle(P2_SUIVI, 0.42), cle(P2_RETOUR, 0.70), cle(REPOS, 0.96)],
    # anciens coups du combo (avant 2026-10-27) : gardés pour comparaison
    # vertical refait (directionnel) : levée au-dessus de la tête, descente droite à travers le centre
    # vertical V3 (2026-10-27) : mêmes instants que coup_c_ancien (latence inchangée) ; l'essai V2 reste dans coup_v2
    "coup_v": [cle(REPOS, 0.0), cle(V3_ARME, 0.13), cle(V3_TENSION, 0.16), cle(V3_ENTREE, 0.19), cle(V3_MILIEU, 0.215),
               cle(V3_FIN, 0.26), cle(V3_SUIVI, 0.34), cle(V3_RETOUR, 0.45), cle(REPOS, 0.56)],
    "coup_v2": [cle(REPOS, 0.0), cle(V2_ARME, 0.14), cle(V2_TENSION, 0.17), cle(V2_ENTREE, 0.195), cle(V2_MILIEU, 0.22),
               cle(V2_FIN, 0.27), cle(V2_SUIVI, 0.34), cle(REPOS, 0.56)],
    "coup_a_ancien": [cle(REPOS, 0.0), cle(A_ARME, 0.12), cle(A_TENSION, 0.15), cle(A_ENTREE, 0.175), cle(A_MILIEU, 0.20),
               cle(A_FIN, 0.25), cle(A_SUIVI, 0.32), cle(REPOS, 0.52)],
    # combo B : horizontal droite -> gauche ; coup_gd : revers gauche -> droite (pas à droite, miroir de l'horizontal)
    "coup_b_ancien": [cle(A_SUIVI, 0.0), cle(B_RETOUR, 0.08), cle(H_ARME, 0.14), cle(H_TENSION, 0.17), cle(H_ENTREE, 0.195),
               cle(H_MILIEU, 0.22), cle(H_FIN, 0.27), cle(H_SUIVI, 0.34), cle(REPOS, 0.54)],
    "coup_gd": [cle(B_ARME, 0.0), cle(B_ARME, 0.08), cle(B_TENSION, 0.11), cle(B_MILIEU, 0.16), cle(B_FIN, 0.21),
                cle(B_SUIVI, 0.28), cle(REPOS, 0.50)],
    "coup_c_ancien": [cle(C_PRE, 0.0), cle(C_ARME, 0.13), cle(C_TENSION, 0.16), cle(C_ENTREE, 0.19), cle(C_MILIEU, 0.215),
               cle(C_FIN, 0.26), cle(C_SUIVI, 0.34), cle(REPOS, 0.56)],
    "coup_horizontal": [cle(REPOS, 0.0), cle(H_ARME, 0.11), cle(H_TENSION, 0.14), cle(H_ENTREE, 0.165), cle(H_MILIEU, 0.19), cle(H_FIN, 0.24),
                        cle(H_SUIVI, 0.31), cle(REPOS, 0.50)],
    "coup_revers": [cle(REPOS, 0.0), cle(R_ARME, 0.11), cle(R_TENSION, 0.14), cle(R_MILIEU, 0.19), cle(R_FIN, 0.24),
                    cle(R_SUIVI, 0.31), cle(REPOS, 0.50)],
    "estoc": [cle(REPOS, 0.0), cle(E_ARME, 0.11), cle(E_ARME, 0.15), cle(E_FIN, 0.25), cle(E_SUIVI, 0.30), cle(REPOS, 0.50)],
    # puissantes : armé (tenu pendant la charge), puis coup au relâchement
    "charge_lourd_fouet": [cle(REPOS, 0.0), cle(P_ARME, 0.30), cle(P4_CHARGE, 0.60)],
    "lourd_fouet": [cle(P4_CHARGE, 0.0), cle(P4_ARME, 0.06), cle(P4_TENSION, 0.10), cle(P4_ENTREE, 0.165), cle(P4_MILIEU, 0.20), cle(P4_FIN, 0.25),
              cle(P4_SUIVI, 0.42), cle(P2_RETOUR, 0.70), cle(REPOS, 0.96)],
    # lourd vertical (en avançant) refait sur le vertical V2 : levée plus haute tenue pendant la charge
    "charge_vertical": [cle(REPOS, 0.0), cle(V2_ARME, 0.30), cle(V2_TENSION, 0.60)],
    "lourd_vertical": [cle(V2_TENSION, 0.0), cle(V2_ENTREE, 0.11), cle(V2_MILIEU, 0.15), cle(V2_FIN, 0.21),
                       cle(V2_SUIVI, 0.40), cle(P2_RETOUR, 0.66), cle(REPOS, 0.92)],
    "charge_gd": [cle(REPOS, 0.0), cle(G_ARME, 0.30), cle(G_ARME, 0.60)],
    "lourd_gd": [cle(G_ARME, 0.0), cle(G_TENSION, 0.08), cle(G_MILIEU, 0.18), cle(G_FIN, 0.26), cle(G_SUIVI, 0.40),
                 cle(REPOS, 0.92)],
    "charge_revers": [cle(REPOS, 0.0), cle(Q_ARME, 0.30), cle(Q_ARME, 0.60)],
    "lourd_revers": [cle(Q_ARME, 0.0), cle(Q_TENSION, 0.08), cle(Q_FIN, 0.22), cle(Q_SUIVI, 0.36), cle(REPOS, 0.86)],
    "contre": [cle(GARDE, 0.0), cle(K_ARME, 0.06), cle(R_TENSION, 0.09), cle(R_MILIEU, 0.135), cle(R_FIN, 0.18),
               cle(R_SUIVI, 0.27), cle(REPOS, 0.52)],
    "finisher_taille": [cle(REPOS, 0.0), cle(P_ARME, 0.20), cle(P_TENSION, 0.26), cle(P_MILIEU, 0.32), cle(P_FIN, 0.38),
                        cle(P_SUIVI, 0.48), cle(REPOS, 0.72)],
    "finisher_sol": [cle(REPOS, 0.0), cle(V_ARME, 0.20), cle(V_TENSION, 0.26), cle(C_MILIEU, 0.32), cle(C_FIN, 0.38),
                     cle(C_SUIVI, 0.48), cle(REPOS, 0.72)],
}

# =====================================================================================================================
# COUPS EN CAPTURE DE MOUVEMENT (Mixamo, décision utilisateur 2026-10-29 : plus de coups inventés à la main) ; données
# converties : sources_blender/mixamo/coups_mixamo.json (extraire_mixamo.py), retarget : anim_bras_epee.creer_action_mixamo.
# temps = [(image source à 30 i/s, instant du clip en s)] : les instants des marqueurs restent ceux du jeu (la phase de
# frappe garde à peu près la vitesse réelle de la capture, l'armé est accéléré) ; image None = la garde de référence
# (fondu en S). cadrage = (lacet, tangage, roulis)° autour de l'épaule, en cloche sur « plein ».
CLIPS_MIXAMO = {
    # 1 : diagonale haut-droite -> bas-gauche (« Sword And Shield Slash (1) », images 17 -> 23 : l'armé derrière la tête
    # (images 8-16, hors champ en vue FPS) est sauté, le fondu monte directement de la garde à l'armé ; amplitude 0,6 :
    # tout l'arc reste dans le champ)
    "coup_a": dict(source="slash_1", ref=0, temps=[(17, 0.0), (17, 0.10), (17.5, 0.16), (21, 0.26), (22.5, 0.33), (23, 0.44), (23, 0.54)], fondu=(0.12, 0.28),
                   cadrage=(15, 35, 0), decalage=(0.0, 0.06, -0.15), plein=(0.12, 0.36), amplitude=0.6, centre=19, main=(-20,0,0)),
    # 2 : gauche -> droite (« Sword And Shield Slash (2) », début : la lame monte à gauche puis balaie vers le bas à droite,
    # images 12 -> 19 ; la suite du fichier, une vrille sautée, n'est pas utilisée : retour en garde par fondu) ; roulis 65
    # + balayage (le bras tourne de 50° à gauche vers 0 autour de l'épaule) = trajet horizontal, lame inclinée vers
    # l'avant (main) pour que le tranchant mène
    "coup_b": dict(source="slash_2", ref=0, temps=[(4, 0.0), (10, 0.10), (12, 0.13), (19, 0.23), (20, 0.30), (20, 0.50)], fondu=(0.09, 0.24),
                   cadrage=(0,25,65), decalage=(0.0, 0.06, -0.15), plein=(0.09, 0.32), amplitude=0.6, centre=15, balayage=(50,0,0.12,0.25), main=(0,-20,0)),
    # 3 : estoc (« Stabbing », images 2 -> 14 : le poing recule, puis pousse vers le centre ; tenue tendue jusqu'au fondu ;
    # amplitude 0,3 vers l'extension, main inclinée pour pointer le buste ; continuité de torsion renforcée)
    "coup_c": dict(source="estoc", ref=0, temps=[(2, 0.0), (6, 0.11), (8, 0.15), (14, 0.25), (14, 0.30), (14, 0.50)], fondu=(0.10, 0.30),
                   cadrage=(-15, -18, 0), decalage=(0.0, 0.06, -0.15), plein=(0.10, 0.50), amplitude=0.3, centre=14, main=(20, 10, 20), continuite=0.3),
    # coup puissant : frappe verticale de haut en bas (« Standing Melee Attack Downward », armé images 2 -> 21, frappe 21 -> 27) ;
    # charge et coup partagent cadrage et amplitude (enchaînés sans saut). Ancien : « Sword And Shield Slash » (slash_0).
    # Revers essayés pour le coup 2 (« Stable Sword Outward Slash », « Standing Melee Attack Backhand ») : poing bas à la
    # hanche et lame vers l'arrière à l'armé, trajet court et tranchant à 40-66° en vue FPS -> coup 2 v2 gardé.
    "charge_lourd": dict(source="vertical", ref=0, temps=[(2, 0.0), (19, 0.30), (21, 0.60)], fondu=(0.30, 0.60), cadrage=(30, -35, 0), decalage=(0.0, 0.06, -0.15), plein=(0.30, 0.60), amplitude=0.4, centre=23),
    "lourd": dict(source="vertical", ref=0, temps=[(21, 0.0), (21.5, 0.10), (26, 0.25), (27, 0.42), (27, 0.70), (27, 0.96)], fondu=(0.0, 0.30), cadrage=(30, -35, 0), decalage=(0.0, 0.06, -0.15), plein=(0.0, 0.45), amplitude=0.4, centre=23),
}

# instants (s, vitesse 1) : arme = fin de l'armé, frappe = début de la phase active (la lame blesse), fin_frappe,
# suivi = fin du suivi (dépassement), fin = retour au repos. Charges : arme = armé atteint (tenu ensuite).
MARQUEURS = {
    "coup_a": {"arme": 0.13, "frappe": 0.16, "fin_frappe": 0.26, "suivi": 0.33, "fin": 0.54},
    "coup_b": {"arme": 0.10, "frappe": 0.13, "fin_frappe": 0.23, "suivi": 0.30, "fin": 0.50},
    "coup_c": {"arme": 0.11, "frappe": 0.15, "fin_frappe": 0.25, "suivi": 0.30, "fin": 0.50},
    "coup_c_main": {"arme": 0.11, "frappe": 0.15, "fin_frappe": 0.25, "suivi": 0.30, "fin": 0.50},
    "coup_a_fouet": {"arme": 0.13, "frappe": 0.16, "fin_frappe": 0.26, "suivi": 0.33, "fin": 0.54},
    "coup_b_fouet": {"arme": 0.10, "frappe": 0.13, "fin_frappe": 0.23, "suivi": 0.30, "fin": 0.50},
    "charge_lourd_fouet": {"arme": 0.30, "fin": 0.60},
    "lourd_fouet": {"arme": 0.10, "frappe": 0.10, "fin_frappe": 0.25, "suivi": 0.42, "fin": 0.96},
    "coup_a_levier": {"arme": 0.13, "frappe": 0.16, "fin_frappe": 0.26, "suivi": 0.33, "fin": 0.54},
    "coup_b_levier": {"arme": 0.10, "frappe": 0.13, "fin_frappe": 0.23, "suivi": 0.30, "fin": 0.50},
    "lourd_levier": {"arme": 0.10, "frappe": 0.10, "fin_frappe": 0.25, "suivi": 0.42, "fin": 0.96},
    "coup_a_ancien": {"arme": 0.12, "frappe": 0.15, "fin_frappe": 0.25, "suivi": 0.32, "fin": 0.52},
    "coup_b_ancien": {"arme": 0.14, "frappe": 0.17, "fin_frappe": 0.27, "suivi": 0.34, "fin": 0.54},
    "coup_gd": {"arme": 0.08, "frappe": 0.11, "fin_frappe": 0.21, "suivi": 0.28, "fin": 0.50},
    "coup_c_ancien": {"arme": 0.13, "frappe": 0.16, "fin_frappe": 0.26, "suivi": 0.34, "fin": 0.56},
    "coup_horizontal": {"arme": 0.11, "frappe": 0.14, "fin_frappe": 0.24, "suivi": 0.31, "fin": 0.50},
    "coup_revers": {"arme": 0.11, "frappe": 0.14, "fin_frappe": 0.24, "suivi": 0.31, "fin": 0.50},
    "estoc": {"arme": 0.11, "frappe": 0.15, "fin_frappe": 0.25, "suivi": 0.30, "fin": 0.50},
    "charge_lourd": {"arme": 0.30, "fin": 0.60},
    "lourd": {"arme": 0.10, "frappe": 0.10, "fin_frappe": 0.25, "suivi": 0.42, "fin": 0.96},
    "coup_v": {"arme": 0.13, "frappe": 0.16, "fin_frappe": 0.26, "suivi": 0.34, "fin": 0.56},
    "coup_v2": {"arme": 0.14, "frappe": 0.17, "fin_frappe": 0.27, "suivi": 0.34, "fin": 0.56},
    "charge_vertical": {"arme": 0.30, "fin": 0.60},
    "lourd_vertical": {"arme": 0.06, "frappe": 0.06, "fin_frappe": 0.21, "suivi": 0.40, "fin": 0.92},
    "charge_gd": {"arme": 0.30, "fin": 0.60},
    "lourd_gd": {"arme": 0.08, "frappe": 0.08, "fin_frappe": 0.26, "suivi": 0.40, "fin": 0.92},
    "charge_revers": {"arme": 0.30, "fin": 0.60},
    "lourd_revers": {"arme": 0.08, "frappe": 0.08, "fin_frappe": 0.22, "suivi": 0.36, "fin": 0.86},
    "contre": {"arme": 0.06, "frappe": 0.09, "fin_frappe": 0.18, "suivi": 0.27, "fin": 0.52},
    "finisher_taille": {"arme": 0.26, "frappe": 0.26, "fin_frappe": 0.38, "suivi": 0.48, "fin": 0.72},
    "finisher_sol": {"arme": 0.26, "frappe": 0.26, "fin_frappe": 0.38, "suivi": 0.48, "fin": 0.72},
    "encaisse": {"fin": 0.26},
    "parade": {"fin": 0.22},
    "garde_brisee": {"fin": 0.45},
}
