# COUPS À UNE MAIN, lot coups_v5 (2026-10-30) : clips en capture de mouvement AJOUTÉS au jeu d'épée longue, séparés de
# gestes_bras_epee.py pour que la fusion avec la branche des coups à deux mains (gestes_2mains.py) reste simple.
# Fusionnés dans CLIPS_MIXAMO / MARQUEURS par gestes_bras_epee.py (dernières lignes) ; même format, même retarget
# (anim_bras_epee.creer_action_mixamo). Sources « q_* » : Quaternius Universal Animation Library 2 [Standard], CC0
# (sources_blender/mixamo/coups_quaternius.json, extrait par extraire_quaternius.py ; le .glb reste hors du dépôt).

CLIPS_MIXAMO_UNE_MAIN = {
    # taille HORIZONTALE droite -> gauche (coup 3 du combo, repart de la fin du revers, à droite) : « Sword_Regular_Combo »,
    # 3e coup, images 30 -> 41 : poing haut à droite, la lame balaie à plat à hauteur de poitrine jusqu'à gauche (la pointe
    # reste à ±0,1 m de hauteur sur tout l'arc). L'armé derrière l'épaule (images 23-29) est réduit par l'amplitude.
    "coup_t": dict(source="q_Sword_Regular_Combo", ref=90, temps=[(27, 0.0), (31, 0.10), (32.5, 0.13), (38, 0.23), (38.5, 0.30), (38.5, 0.50)],
                   fondu=(0.09, 0.26), cadrage=(0, 8, -15), decalage=(0.0, 0.06, -0.15), plein=(0.09, 0.32), amplitude=0.55, centre=35, balayage=(-10, 30, 0.10, 0.24)),
}

MARQUEURS_UNE_MAIN = {
    "coup_t": {"arme": 0.10, "frappe": 0.13, "fin_frappe": 0.23, "suivi": 0.30, "fin": 0.50},
}
