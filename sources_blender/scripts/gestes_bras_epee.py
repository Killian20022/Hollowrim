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
REPOS = dict(nom="repos", poing=E(0.5, -0.64, 0.55), lame=(-0.1, 0.95, -0.3), roulis=TRANCHE, coude=(1, -0.8, 0.2),
             k=44, f=-20, r=-35, phi=0)   # poignet fixé : la même pose de repos au bout de chaque clip (pas de saut au retour)
SPRINT = dict(nom="sprint", poing=E(0.72, -0.9, 0.42), lame=(-0.25, 0.4, -0.88), roulis=TRANCHE, coude=(0.6, -1, 0.4))
# garde : épée en travers devant, pointe vers la gauche (un peu haute), tranchant vers l'ennemi, poing à droite
GARDE = dict(nom="garde", poing=E(0.42, -0.42, 0.46), lame=(-0.88, 0.42, -0.2), roulis=TRANCHE, coude=(0.5, -1, 0.1), clav=(10, 4), epaule=(-0.02, 0, -0.03))
ENCAISSE = dict(GARDE, nom="encaisse", poing=E(0.44, -0.34, 0.41), lame=(-0.86, 0.5, -0.1))
PARADE = dict(GARDE, nom="parade", poing=E(0.48, -0.3, 0.45), lame=(-0.62, 0.74, -0.25))
BRISEE = dict(nom="brisee", poing=E(0.66, -0.8, 0.42), lame=(-0.3, 0.25, -0.92), roulis=TRANCHE, coude=(0.7, -1, 0.3))

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
B_RETOUR = dict(nom="B_retour", poing=E(0.3, -0.45, 0.55), lame=(-0.6, 0.5, -0.6), roulis=TRANCHE, coude=(0.6, -1, 0.1), clav=(10, 2), epaule=(-0.04, 0.0, -0.05), torsion=-80)

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

CLIPS = {
    "repos": [cle(REPOS, 0.0), cle(REPOS, 0.5)],
    "sprint": [cle(SPRINT, 0.0), cle(SPRINT, 0.5)],
    "garde": [cle(GARDE, 0.0), cle(GARDE, 0.5)],
    "encaisse": [cle(GARDE, 0.0), cle(ENCAISSE, 0.05, interp="lin"), cle(GARDE, 0.18)],
    "parade": [cle(GARDE, 0.0), cle(PARADE, 0.04, interp="lin"), cle(GARDE, 0.16)],
    "garde_brisee": [cle(GARDE, 0.0), cle(BRISEE, 0.05, interp="lin"), cle(BRISEE, 0.22), cle(REPOS, 0.45)],
    "coup_a": [cle(REPOS, 0.0), cle(A_ARME, 0.12), cle(A_TENSION, 0.15), cle(A_ENTREE, 0.175), cle(A_MILIEU, 0.20),
               cle(A_FIN, 0.25), cle(A_SUIVI, 0.32), cle(REPOS, 0.52)],
    # combo B : horizontal droite -> gauche ; coup_gd : revers gauche -> droite (pas à droite, miroir de l'horizontal)
    "coup_b": [cle(A_SUIVI, 0.0), cle(B_RETOUR, 0.08), cle(H_ARME, 0.14), cle(H_TENSION, 0.17), cle(H_ENTREE, 0.195),
               cle(H_MILIEU, 0.22), cle(H_FIN, 0.27), cle(H_SUIVI, 0.34), cle(REPOS, 0.54)],
    "coup_gd": [cle(B_ARME, 0.0), cle(B_ARME, 0.08), cle(B_TENSION, 0.11), cle(B_MILIEU, 0.16), cle(B_FIN, 0.21),
                cle(B_SUIVI, 0.28), cle(REPOS, 0.50)],
    "coup_c": [cle(C_PRE, 0.0), cle(C_ARME, 0.13), cle(C_TENSION, 0.16), cle(C_ENTREE, 0.19), cle(C_MILIEU, 0.215),
               cle(C_FIN, 0.26), cle(C_SUIVI, 0.34), cle(REPOS, 0.56)],
    "coup_horizontal": [cle(REPOS, 0.0), cle(H_ARME, 0.11), cle(H_TENSION, 0.14), cle(H_ENTREE, 0.165), cle(H_MILIEU, 0.19), cle(H_FIN, 0.24),
                        cle(H_SUIVI, 0.31), cle(REPOS, 0.50)],
    "coup_revers": [cle(REPOS, 0.0), cle(R_ARME, 0.11), cle(R_TENSION, 0.14), cle(R_MILIEU, 0.19), cle(R_FIN, 0.24),
                    cle(R_SUIVI, 0.31), cle(REPOS, 0.50)],
    "estoc": [cle(REPOS, 0.0), cle(E_ARME, 0.11), cle(E_ARME, 0.15), cle(E_FIN, 0.25), cle(E_SUIVI, 0.30), cle(REPOS, 0.50)],
    # puissantes : armé (tenu pendant la charge), puis coup au relâchement
    "charge_lourd": [cle(REPOS, 0.0), cle(P_ARME, 0.30), cle(P_ARME, 0.60)],
    "lourd": [cle(P_ARME, 0.0), cle(P_TENSION, 0.08), cle(P_ENTREE, 0.15), cle(P_MILIEU, 0.20), cle(P_FIN, 0.26),
              cle(P_SUIVI, 0.40), cle(REPOS, 0.92)],
    "charge_vertical": [cle(REPOS, 0.0), cle(V_ARME, 0.30), cle(V_ARME, 0.60)],
    "lourd_vertical": [cle(V_ARME, 0.0), cle(V_TENSION, 0.08), cle(C_ENTREE, 0.15), cle(C_MILIEU, 0.195),
                       cle(C_FIN, 0.26), cle(C_SUIVI, 0.40), cle(REPOS, 0.92)],
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

# instants (s, vitesse 1) : arme = fin de l'armé, frappe = début de la phase active (la lame blesse), fin_frappe,
# suivi = fin du suivi (dépassement), fin = retour au repos. Charges : arme = armé atteint (tenu ensuite).
MARQUEURS = {
    "coup_a": {"arme": 0.12, "frappe": 0.15, "fin_frappe": 0.25, "suivi": 0.32, "fin": 0.52},
    "coup_b": {"arme": 0.14, "frappe": 0.17, "fin_frappe": 0.27, "suivi": 0.34, "fin": 0.54},
    "coup_gd": {"arme": 0.08, "frappe": 0.11, "fin_frappe": 0.21, "suivi": 0.28, "fin": 0.50},
    "coup_c": {"arme": 0.13, "frappe": 0.16, "fin_frappe": 0.26, "suivi": 0.34, "fin": 0.56},
    "coup_horizontal": {"arme": 0.11, "frappe": 0.14, "fin_frappe": 0.24, "suivi": 0.31, "fin": 0.50},
    "coup_revers": {"arme": 0.11, "frappe": 0.14, "fin_frappe": 0.24, "suivi": 0.31, "fin": 0.50},
    "estoc": {"arme": 0.11, "frappe": 0.15, "fin_frappe": 0.25, "suivi": 0.30, "fin": 0.50},
    "charge_lourd": {"arme": 0.30, "fin": 0.60},
    "lourd": {"arme": 0.08, "frappe": 0.08, "fin_frappe": 0.26, "suivi": 0.40, "fin": 0.92},
    "charge_vertical": {"arme": 0.30, "fin": 0.60},
    "lourd_vertical": {"arme": 0.08, "frappe": 0.08, "fin_frappe": 0.26, "suivi": 0.40, "fin": 0.92},
    "charge_gd": {"arme": 0.30, "fin": 0.60},
    "lourd_gd": {"arme": 0.08, "frappe": 0.08, "fin_frappe": 0.26, "suivi": 0.40, "fin": 0.92},
    "charge_revers": {"arme": 0.30, "fin": 0.60},
    "lourd_revers": {"arme": 0.08, "frappe": 0.08, "fin_frappe": 0.22, "suivi": 0.36, "fin": 0.86},
    "contre": {"arme": 0.06, "frappe": 0.09, "fin_frappe": 0.18, "suivi": 0.27, "fin": 0.52},
    "finisher_taille": {"arme": 0.26, "frappe": 0.26, "fin_frappe": 0.38, "suivi": 0.48, "fin": 0.72},
    "finisher_sol": {"arme": 0.26, "frappe": 0.26, "fin_frappe": 0.38, "suivi": 0.48, "fin": 0.72},
    "encaisse": {"fin": 0.18},
    "parade": {"fin": 0.16},
    "garde_brisee": {"fin": 0.45},
}
