# COUPS À UNE MAIN, lot coups_v5 (2026-10-30) : clips en capture de mouvement AJOUTÉS au jeu d'épée longue, séparés de
# gestes_bras_epee.py pour que la fusion avec la branche des coups à deux mains (gestes_2mains.py) reste simple.
# Fusionnés dans CLIPS_MIXAMO / MARQUEURS par gestes_bras_epee.py (dernières lignes) ; même format, même retarget
# (anim_bras_epee.creer_action_mixamo). Sources « q_* » : Quaternius Universal Animation Library 2 [Standard], CC0
# (sources_blender/mixamo/coups_quaternius.json, extrait par extraire_quaternius.py ; le .glb reste hors du dépôt).

CLIPS_MIXAMO_UNE_MAIN = {
    # taille HORIZONTALE droite -> gauche (coup 3 du combo, repart de la fin du revers, à droite) : « Sword_Regular_Combo »,
    # 3e coup, images 30 -> 41 : poing haut à droite, la lame balaie à plat à hauteur de poitrine jusqu'à gauche (la pointe
    # reste à ±0,1 m de hauteur sur tout l'arc). L'armé derrière l'épaule (images 23-29) est réduit par l'amplitude.
    # Retouches vue FPS (essais mesurés : trajet du milieu de lame à l'écran, « fil » = angle plat / mouvement) : roulis -25°
    # du bras (trajet à plat), balayage 0 -> 40° autour de l'épaule pendant la frappe (la lame traverse tout l'écran),
    # prise tournée de 150° et main relevée de 30° / tournée de 20° vers la droite (le TRANCHANT mène, fil ~75° au lieu de
    # 21° sans retouche) ; déplacement de l'épaule réduit à 40 % (le buste Quaternius tourne de 0,37 m vers la gauche : en vue
    # FPS l'avant-bras passait en gros plan au bas de l'écran) ; milieu de lame (1,09 ; -0,46) -> (-0,78 ; -0,31), fil ~72°.
    "coup_t": dict(source="q_Sword_Regular_Combo", ref=90, temps=[(27, 0.0), (31.5, 0.10), (33, 0.13), (38, 0.23), (38.5, 0.30), (38.5, 0.54)],
                   fondu=(0.09, 0.26), cadrage=(0, 12, -25), decalage=(0.0, 0.06, -0.15), plein=(0.09, 0.32), amplitude=0.55, centre=35, balayage=(0, 40, 0.11, 0.23),
                   roulis_prise=150, main=(-20, 30, 0), echelle_epaule=0.4),
}

MARQUEURS_UNE_MAIN = {
    "coup_t": {"arme": 0.10, "frappe": 0.13, "fin_frappe": 0.23, "suivi": 0.30, "fin": 0.54},
}

# =====================================================================================================================
# COUPS V6 (2026-10-30) : les 4 coups validés de coups_v5 (mêmes captures, mêmes retouches) + trois SURCOUCHES
# (anim_bras_epee.creer_action_mixamo), clips « <nom>6 » à côté des clips v5 (gardés intacts pour comparaison) :
#   - « poignet » ((flexion), (inclinaison))° : POIGNET VERROUILLÉ autour de la tenue (repos : f -11, r -32 ; v5 : la main
#     cassait jusqu'à 54° de flexion pendant les coups) ; l'épée prolonge l'avant-bras, la torsion (pronation / supination)
#     reste libre dans l'avant-bras (os de torsion, TorsionAvantBras) ;
#   - « arc » (t0, t1, poids) : pendant la frappe, la pointe est ramenée vers un ARC DE CERCLE propre autour de l'épaule
#     (plan ajusté sur la capture, même sens, vitesse angulaire constante : idée de COBRA FPS Feelkit, MIT) ;
#   - « creux » (m) : l'épaule descend un peu au milieu de la frappe (le poids de la lame, COBRA : sin(pi u)).
# Essayé et ÉCARTÉ (mesures + planches du 2026-10-30) : les autres coups des combos Quaternius UAL2 (Sword_Regular_Combo
# coups 2 et 4, Sword_Heavy_Combo coup 4) retargetés tels quels : en vue FPS l'armé passe derrière la tête (lame qui
# traverse la caméra) et la frappe devient un « hachoir » vertical, lame droite qui descend sans balayer.
POIGNET_V6 = ((-28, 8), (-29, -18))



def surcouche_v6(spec, arc=None, creux=0.03):
    s = dict(spec)
    s["poignet"] = POIGNET_V6
    if arc is not None:
        s["arc"] = arc
        s["creux"] = creux
    return s
